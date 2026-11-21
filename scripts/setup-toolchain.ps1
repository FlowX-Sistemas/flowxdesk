# Prepara (uma vez) o ambiente de build do FlowXDesk no Windows.
# Idempotente: pode rodar de novo; pula o que já existe.
# Versões = as fixadas pelo CI do RustDesk (src/.github/workflows/flutter-build.yml). Ao subir de versão, confira lá.
param(
  [string]$Tools = 'D:\FlowXDesk-toolchain',
  [string]$Src   = (Join-Path $PSScriptRoot '..\src')
)
# Continue: no PS 5.1 o stderr de rustup/git/cargo vira erro com 'Stop'; checamos $LASTEXITCODE.
$ErrorActionPreference = 'Continue'
function Assert-Ok($what) { if ($LASTEXITCODE) { throw "falhou: $what (exit $LASTEXITCODE)" } }
$FLUTTER_VERSION = '3.24.5'
$LLVM_VERSION    = '15.0.6'
$RUST_VERSION    = '1.75'
$VCPKG_COMMIT    = '9e593bb18ea69cc5095e012465dcd675a822ed0d'
$FRB_VERSION     = '1.80.1'
$EXPAND_VERSION  = '1.0.95'
New-Item -ItemType Directory -Force $Tools | Out-Null
$Src = (Resolve-Path $Src).Path

function Get-File($url, $out) { if (-not (Test-Path $out)) { Write-Host "baixando $url"; curl.exe -sSL --fail -o $out $url; if ($LASTEXITCODE) { throw "falha ao baixar $url" } } }

# 1) Rust fixo do CI (sciter/ABI exigem 1.75)
rustup toolchain install $RUST_VERSION --profile minimal -c rustfmt; Assert-Ok rustup
Push-Location $Src; rustup override set $RUST_VERSION; Pop-Location

# 2) LLVM (bindgen/ffigen)
$llvm = "$Tools\llvm"
if (-not (Test-Path "$llvm\bin\clang.exe")) {
  $exe = "$Tools\LLVM-$LLVM_VERSION-win64.exe"
  Get-File "https://github.com/llvm/llvm-project/releases/download/llvmorg-$LLVM_VERSION/LLVM-$LLVM_VERSION-win64.exe" $exe
  Start-Process $exe -ArgumentList '/S', "/D=$llvm" -Wait
}

# 3) Flutter + engine customizado do RustDesk + patch do dropdown
$flutter = "$Tools\flutter"
if (-not (Test-Path "$flutter\bin\flutter.bat")) {
  $zip = "$Tools\flutter_$FLUTTER_VERSION.zip"
  Get-File "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_$FLUTTER_VERSION-stable.zip" $zip
  tar.exe -xf $zip -C $Tools
  & "$flutter\bin\flutter.bat" config --no-analytics | Out-Null
  & "$flutter\bin\flutter.bat" precache --windows --android; Assert-Ok 'flutter precache'
  $eng = "$Tools\windows-x64-release.zip"
  Get-File 'https://github.com/rustdesk/engine/releases/download/main/windows-x64-release.zip' $eng
  Expand-Archive $eng -DestinationPath "$Tools\engine-x64" -Force
  Copy-Item "$Tools\engine-x64\*" "$flutter\bin\cache\artifacts\engine\windows-x64-release\" -Recurse -Force
  Copy-Item "$Src\.github\patches\flutter_3.24.4_dropdown_menu_enableFilter.diff" $flutter
  git -C $flutter apply flutter_3.24.4_dropdown_menu_enableFilter.diff; Assert-Ok 'patch flutter'
}

# 4) vcpkg na versão do CI + libs nativas (libvpx, opus, aom, ffmpeg...) do vcpkg.json do repo
$vcpkg = "$Tools\vcpkg"
if (-not (Test-Path "$vcpkg\vcpkg.exe")) {
  git clone -q https://github.com/microsoft/vcpkg $vcpkg
  git -C $vcpkg checkout -q $VCPKG_COMMIT
  & "$vcpkg\bootstrap-vcpkg.bat" -disableMetrics; Assert-Ok 'bootstrap vcpkg'
}
$env:VCPKG_ROOT = $vcpkg
$env:VCPKG_MAX_CONCURRENCY = '12'   # limita CPU/RAM para não apertar a VM de produção
$env:VCPKG_DEFAULT_HOST_TRIPLET = 'x64-windows-static'   # ffmpeg é "host" no vcpkg.json; o CI força estático
Push-Location $Src
& "$vcpkg\vcpkg.exe" install --triplet x64-windows-static --x-install-root="$vcpkg\installed"
if ($LASTEXITCODE) { throw 'vcpkg install falhou' }
Pop-Location

# 5) Gerador da ponte Rust<->Dart
if (-not (Get-Command flutter_rust_bridge_codegen -ErrorAction SilentlyContinue)) {
  cargo +$RUST_VERSION install cargo-expand --version $EXPAND_VERSION --locked
  cargo +$RUST_VERSION install flutter_rust_bridge_codegen --version $FRB_VERSION --features uuid --locked; Assert-Ok 'frb codegen'
}
Write-Host "OK. Toolchain em $Tools"
