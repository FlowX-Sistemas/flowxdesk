# Gera o instalador Windows do FlowXDesk: dist\FlowXDesk-<versão>-x64.exe
# Pré-requisito: scripts\setup-toolchain.ps1 (uma vez) e o arquivo flowxdesk.local.ps1 (servidor/key, fora do git).
# -Tecnico: build INTERNO com a chave privada do técnico (entra direto nos clientes). NUNCA publicar.
param([string]$Tools = 'D:\FlowXDesk-toolchain', [int]$Jobs = 12, [switch]$Tecnico,
      [string]$TechKeyFile = 'D:\FlowX-Ops\segredos\flowxdesk-tecnico-2026b.key')
$ErrorActionPreference = 'Continue'
function Assert-Ok($what) { if ($LASTEXITCODE) { throw "falhou: $what (exit $LASTEXITCODE)" } }
$Root = (Resolve-Path "$PSScriptRoot\..").Path
$Src = "$Root\src"

# Janela de backup da produção (03:15–04:45): não compilar perto dela.
$now = (Get-Date).TimeOfDay
if ($now -ge [TimeSpan]'03:00' -and $now -le [TimeSpan]'05:00') { throw 'Janela de backup (03:00–05:00). Rode depois.' }

. "$Root\flowxdesk.local.ps1"   # define $env:RENDEZVOUS_SERVER e $env:RS_PUB_KEY
if (-not $env:RENDEZVOUS_SERVER -or -not $env:RS_PUB_KEY) { throw 'flowxdesk.local.ps1 precisa definir RENDEZVOUS_SERVER e RS_PUB_KEY' }

$env:PATH = "$Tools\flutter\bin;$Tools\llvm\bin;$env:USERPROFILE\.cargo\bin;$env:PATH"
$env:LIBCLANG_PATH = "$Tools\llvm\bin"
$env:VCPKG_ROOT = "$Tools\vcpkg"
$env:CARGO_BUILD_JOBS = "$Jobs"     # limita CPU/RAM (VM de produção no mesmo host)
$env:PYTHONIOENCODING = 'utf-8'
# Desde a 1.5.11 não existe build do técnico: a chave fica em %ProgramData%\FlowXDesk\tecnico.key no PC dele (scripts\instalar-chave-tecnico.ps1).
if ($Tecnico) { throw '-Tecnico não existe mais: use o instalador público + scripts\instalar-chave-tecnico.ps1 no PC do técnico.' }
Remove-Item Env:FLOWX_TECH_KEY -ErrorAction SilentlyContinue
$env:PUB_CACHE = "$Tools\pub-cache"   # fora do AppData: o terminal do Claude vê um AppData virtual que o compilador do Flutter não enxerga

python -I "$Root\scripts\brand.py" $Src; Assert-Ok 'brand.py'

Push-Location $Src
try {
  # Ponte Rust<->Dart (o CI do RustDesk gera num job separado; aqui é local)
  Push-Location flutter; flutter pub get; Assert-Ok 'pub get'; Pop-Location
  flutter_rust_bridge_codegen --rust-input ./src/flutter_ffi.rs --dart-output ./flutter/lib/generated_bridge.dart --c-output ./flutter/macos/Runner/bridge_generated.h --llvm-path "$Tools\llvm"
  Assert-Ok 'bridge codegen'

  python build.py --portable --flutter --skip-portable-pack --hwcodec --vram; Assert-Ok 'build.py'

  $ver = (Select-String -Path Cargo.toml -Pattern '^version = "(.+)"').Matches[0].Groups[1].Value
  $stage = "$Root\build\FlowXDesk"
  if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
  Copy-Item -Recurse flutter\build\windows\x64\runner\Release $stage
  Rename-Item "$stage\rustdesk.exe" 'FlowXDesk.exe'   # nome = APP_NAME, evita renomear na instalação
  # shortcut: sem driver de tela virtual (usbmmidd) e de impressora; acrescentar se o suporte precisar.

  (Get-Content res\manifest.xml) | Where-Object { $_ -notmatch 'dpiAware' } | Set-Content res\manifest.xml   # igual ao CI
  Push-Location libs\portable
  python -m pip install -q -r requirements.txt
  python generate.py -f $stage -o . -e "$stage\FlowXDesk.exe"; Assert-Ok 'generate.py'
  Pop-Location
  git checkout -- res/manifest.xml

  $distDir = if ($Tecnico) { "$Root\dist\tecnico" } else { "$Root\dist" }
  New-Item -ItemType Directory -Force $distDir | Out-Null
  $out = if ($Tecnico) { "$distDir\FlowXDesk-Tecnico-$ver-x64.exe" } else { "$distDir\FlowXDesk-$ver-x64.exe" }
  Copy-Item target\release\rustdesk-portable-packer.exe $out -Force
  Write-Host "OK: $out"
} finally { Pop-Location }
