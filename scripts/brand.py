"""Aplica a marca FlowXDesk num checkout limpo do RustDesk (src/).

Idempotente: um trecho já trocado é pulado. Se o RustDesk mudar e um trecho
original sumir, o script PARA com erro: confira o arquivo e ajuste a lista.
Uso: python -I scripts/brand.py [caminho_src]
"""
import pathlib
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "src"
ASSETS = ROOT / "branding"

# Servidor e key NÃO ficam no código (repo é público): o build exige as variáveis de ambiente
# RENDEZVOUS_SERVER e RS_PUB_KEY (env! falha a compilação se faltarem). Ver scripts/build-windows.ps1.
SOURCE_URL = "https://github.com/FlowX-Sistemas/flowxdesk"  # repositório público exigido pela AGPL
SITE_URL = "https://flowxsistemas.com.br"

# Cores FlowX (branding/flowxdesk-cores.json). O champanhe #e0c48a com texto branco dá contraste 1,7:1,
# então o acento de botões/links usa um dourado escuro da mesma família: branco sobre #8F6A2C = 4,9:1 (WCAG AA).
ACCENT = "0xFF8F6A2C"

EDITS = [
    ("libs/hbb_common/src/config.rs",
     'RwLock::new("RustDesk".to_owned());',
     'RwLock::new("FlowXDesk".to_owned());'),
    ("libs/hbb_common/src/config.rs",
     'pub const RENDEZVOUS_SERVERS: &[&str] = &["rs-ny.rustdesk.com"];',
     # RENDEZVOUS_SERVER_LAN (opcional): 2º servidor; o cliente mede a latência e usa o que responder
     # (o roteador da FlowX não faz NAT loopback, então PCs da rede interna só alcançam o IP interno).
     'const RS_PUBLIC: &str = env!("RENDEZVOUS_SERVER");\n'
     'const RS_LAN: &str = match option_env!("RENDEZVOUS_SERVER_LAN") {\n'
     '    Some(s) => s,\n'
     '    None => "",\n'
     '};\n'
     'pub const RENDEZVOUS_SERVERS: &[&str] = if RS_LAN.is_empty() {\n'
     '    &[RS_PUBLIC]\n'
     '} else {\n'
     '    &[RS_PUBLIC, RS_LAN]\n'
     '};'),
    ("libs/hbb_common/src/config.rs",
     'pub const RS_PUB_KEY: &str = "OeVuKk5nlHiXp+APNn0Y3pC1Iwpwn44JGqrQCsWqmBw=";',
     'pub const RS_PUB_KEY: &str = env!("RS_PUB_KEY");'),
    # Metadados do .exe
    ("flutter/windows/runner/Runner.rc", 'VALUE "InternalName", "rustdesk" "\\0"',
     'VALUE "InternalName", "flowxdesk" "\\0"'),
    ("flutter/windows/runner/Runner.rc", 'VALUE "OriginalFilename", "rustdesk.exe" "\\0"',
     'VALUE "OriginalFilename", "FlowXDesk.exe" "\\0"'),
    ("flutter/windows/runner/Runner.rc", 'VALUE "CompanyName", "Purslane Tech Pte. Ltd." "\\0"',
     'VALUE "CompanyName", "FlowX Sistemas" "\\0"'),
    ("flutter/windows/runner/Runner.rc", 'VALUE "FileDescription", "RustDesk Remote Desktop" "\\0"',
     'VALUE "FileDescription", "FlowXDesk - Acesso remoto FlowX" "\\0"'),
    ("flutter/windows/runner/Runner.rc", 'VALUE "ProductName", "RustDesk" "\\0"',
     'VALUE "ProductName", "FlowXDesk" "\\0"'),
    # Copyright original mantido (AGPL exige preservar avisos); só acrescenta a FlowX.
    ("flutter/windows/runner/Runner.rc", 'Purslane Tech Pte. Ltd. All rights reserved." "\\0"',
     'Purslane Tech Pte. Ltd.; modificado por FlowX Sistemas (AGPL-3.0)" "\\0"'),
    *[(f, old, new) for f in ("Cargo.toml", "libs/portable/Cargo.toml") for old, new in (
        ('ProductName = "RustDesk"', 'ProductName = "FlowXDesk"'),
        ('FileDescription = "RustDesk Remote Desktop"', 'FileDescription = "FlowXDesk - Acesso remoto FlowX"'),
        ('OriginalFilename = "rustdesk.exe"', 'OriginalFilename = "FlowXDesk.exe"'),
        ('Purslane Tech Pte. Ltd. All rights reserved."',
         'Purslane Tech Pte. Ltd.; modificado por FlowX Sistemas (AGPL-3.0)"'),
    )],
    # Tela "Sobre" (desktop): site da FlowX + link do código-fonte (AGPL)
    ("flutter/lib/desktop/pages/desktop_setting_page.dart",
     "launchUrlString('https://rustdesk.com');\n                  },\n                  child: Text(\n                    translate('Website'),",
     f"launchUrlString('{SITE_URL}');\n                  }},\n                  child: Text(\n                    translate('Website'),"),
    ("flutter/lib/desktop/pages/desktop_setting_page.dart",
     "              SelectionArea(\n                  child: Text('${translate('ID')}: $myId')\n                      .marginSymmetric(vertical: 4.0)),\n",
     "              SelectionArea(\n                  child: Text('${translate('ID')}: $myId')\n                      .marginSymmetric(vertical: 4.0)),\n"
     f"              InkWell(\n                  onTap: () => launchUrlString('{SOURCE_URL}'),\n"
     "                  child: Text('Código-fonte (AGPL-3.0, baseado no RustDesk)', style: linkStyle)\n"
     "                      .marginSymmetric(vertical: 4.0)),\n"),
    # Celular: site
    ("flutter/lib/mobile/pages/settings_page.dart", "const url = 'https://rustdesk.com/';",
     f"const url = '{SITE_URL}';"),
    ("flutter/lib/mobile/pages/settings_page.dart", "child: Text('rustdesk.com',",
     "child: Text('flowxsistemas.com.br',"),
    ("flutter/android/app/src/main/AndroidManifest.xml", 'android:label="RustDesk"',
     'android:label="FlowXDesk"'),
    # ID próprio: instala ao lado do RustDesk oficial (namespace do código Kotlin fica igual)
    ("flutter/android/app/build.gradle", 'applicationId "com.carriez.flutter_hbb"',
     'applicationId "br.com.flowxsistemas.flowxdesk"'),
    ("flutter/android/app/src/main/AndroidManifest.xml", 'android:label="RustDesk Input"',
     'android:label="FlowXDesk Input"'),
]

# Atualização automática (Windows): reaproveita o atualizador do RustDesk (download + sha256 + metadados
# assinados em ed25519 + instalação silenciosa), trocando a origem para as Releases da FlowX e a chave.
# A chave privada fica fora do repositório (secret UPDATE_SIGNING_KEY); scripts/release.py assina.
UPDATE_REPO = ("FlowX-Sistemas", "flowxdesk")
UPDATE_KEY_ID = "flowx-2026-ed25519"
UPDATE_PUBLIC_KEY = [57, 127, 57, 166, 94, 128, 166, 167, 245, 178, 40, 61, 76, 243, 148, 187,
                     168, 240, 145, 128, 123, 1, 44, 240, 250, 2, 69, 115, 103, 214, 234, 198]
_O, _R = UPDATE_REPO
UPDATE_EDITS = [
    # Versão mais nova = asset flowxdesk-version.json da release "latest" ({"url": ".../releases/tag/X.Y.Z"})
    ("libs/hbb_common/src/lib.rs", 'const URL: &str = "https://api.rustdesk.com/version/latest";',
     f'const URL: &str = "https://github.com/{_O}/{_R}/releases/latest/download/flowxdesk-version.json";'),
    ("src/common.rs", "client.post(&url).json(&request).send().await",
     "client.get(&url).send().await"),
    ("src/common.rs", '["rustdesk", "rustdesk", "releases", "tag",', f'["{_O}", "{_R}", "releases", "tag",'),
    ("src/updater/artifact.rs", 'format!("https://github.com/rustdesk/rustdesk/releases/download/{release_id}/");',
     f'format!("https://github.com/{_O}/{_R}/releases/download/{{release_id}}/");'),
    ("src/updater/artifact.rs", '"{expected_artifact_url_prefix}rustdesk-update.json"',
     '"{expected_artifact_url_prefix}flowxdesk-update.json"'),
    ("src/updater/artifact.rs", 'if owner != "rustdesk"\n        || repo != "rustdesk"',
     f'if owner != "{_O}"\n        || repo != "{_R}"'),
    ("src/update_metadata.rs", 'key_id: "2026-ed25519-main",', f'key_id: "{UPDATE_KEY_ID}",'),
    ("src/update_metadata.rs",
     "public_key: [\n        52, 214, 32, 65, 191, 134, 137, 75, 157, 74, 67, 221, 150, 161, 118, 215, 218, 35, 236,\n"
     "        156, 127, 120, 133, 156, 197, 141, 37, 22, 47, 106, 181, 177,\n    ],",
     f"public_key: {UPDATE_PUBLIC_KEY},"),
    ("src/update_metadata.rs", 'const UPDATE_APP: &str = "rustdesk";', 'const UPDATE_APP: &str = "flowxdesk";'),
    ("src/update_metadata.rs", 'PUBLIC_UPDATE_PACKAGE_ID: &str = "rustdesk";',
     'PUBLIC_UPDATE_PACKAGE_ID: &str = "flowxdesk";'),
    # Android: atualizador próprio (branding/android-src/FlowXUpdater.kt), checado ao abrir o app
    ("flutter/android/app/src/main/kotlin/com/carriez/flutter_hbb/MainActivity.kt",
     "    override fun onCreate(savedInstanceState: Bundle?) {\n        super.onCreate(savedInstanceState)\n",
     "    override fun onCreate(savedInstanceState: Bundle?) {\n        super.onCreate(savedInstanceState)\n"
     "        FlowXUpdater.maybeCheck(this)\n"),
    ("flutter/android/app/src/main/AndroidManifest.xml",
     '    <uses-permission android:name="android.permission.INTERNET" />\n',
     '    <uses-permission android:name="android.permission.INTERNET" />\n'
     '    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />\n'),
    ("flutter/android/app/src/main/AndroidManifest.xml", "    </application>",
     '        <receiver android:name=".FlowXUpdateReceiver" android:exported="false" />\n    </application>'),
    # Atualização automática ligada por padrão (o usuário ainda pode desligar nas configurações)
    ("libs/hbb_common/src/config.rs",
     "pub static ref DEFAULT_SETTINGS: RwLock<HashMap<String, String>> = Default::default();",
     'pub static ref DEFAULT_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from([(\n'
     '        "allow-auto-update".to_owned(), "Y".to_owned())]));'),
]

# Cores: troca o azul RustDesk pelo acento FlowX em common.dart
COLOR_EDITS = [
    ("flutter/lib/common.dart", "Color(0xFF0071FF)", f"Color({ACCENT})"),
    ("flutter/lib/common.dart", "Color(0x770071FF)", f"Color(0x77{ACCENT[4:]})"),
    ("flutter/lib/common.dart", "Color(0xAA0071FF)", f"Color(0xAA{ACCENT[4:]})"),
    ("flutter/lib/common.dart", "static const Color button = Color(0xFF2C8CFF);",
     f"static const Color button = Color({ACCENT});"),
    ("flutter/lib/common.dart", "static const Color idColor = Color(0xFF00B6F0);",
     f"static const Color idColor = Color({ACCENT});"),
]

# Ícones: arquivo em branding/ -> destino(s) no src
ICONS = {
    "icon.ico": ["res/icon.ico", "flutter/windows/runner/resources/app_icon.ico"],
    "icon.png": ["res/icon.png", "flutter/assets/icon.png"],
    "tray-icon.ico": ["res/tray-icon.ico"],
    "32x32.png": ["res/32x32.png"],
    "64x64.png": ["res/64x64.png"],
    "128x128.png": ["res/128x128.png"],
    "128x128@2x.png": ["res/128x128@2x.png"],
}


def edit(rel, old, new):
    p = SRC / rel
    s = p.read_text(encoding="utf-8")
    if new in s:  # já aplicado (vale também quando o novo contém o original)
        return "já"
    if old not in s:
        sys.exit(f"ERRO: trecho original não encontrado em {rel}:\n{old[:120]}")
    p.write_text(s.replace(old, new), encoding="utf-8", newline="")
    return "ok"


def set_version():
    """FLOWXDESK_VERSION=X.Y.Z troca a versão (Rust, pacote Windows e Android) sem mexer no RustDesk.
    O atualizador só instala versão MAIOR que a instalada: para uma release só da FlowX, suba o patch."""
    import os
    import re
    v = os.environ.get("FLOWXDESK_VERSION", "").strip()
    if not v:
        return
    if not re.fullmatch(r"\d+\.\d+\.\d+", v):
        sys.exit(f"ERRO: FLOWXDESK_VERSION inválida: {v} (use X.Y.Z)")
    a, b, c = map(int, v.split("."))
    code = a * 10000 + b * 100 + c  # versionCode do Android cresce junto com a versão
    for rel, pat, rep in [
        ("Cargo.toml", r'(?m)\A(\[package\]\nname = "rustdesk"\n)version = "[^"]+"', rf'\g<1>version = "{v}"'),
        ("libs/portable/Cargo.toml", r'(?m)\A(\[package\]\nname = "rustdesk-portable-packer"\n)version = "[^"]+"',
         rf'\g<1>version = "{v}"'),
        ("Cargo.lock", r'(name = "rustdesk"\nversion = )"[^"]+"', rf'\g<1>"{v}"'),
        ("Cargo.lock", r'(name = "rustdesk-portable-packer"\nversion = )"[^"]+"', rf'\g<1>"{v}"'),
        ("flutter/pubspec.yaml", r"(?m)^version: .+$", f"version: {v}+{code}"),
    ]:
        p = SRC / rel
        s = p.read_text(encoding="utf-8")
        s2, n = re.subn(pat, rep, s, count=1)
        if n != 1:
            sys.exit(f"ERRO: versão não encontrada em {rel}")
        p.write_text(s2, encoding="utf-8", newline="")
    print(f"[versão] {v} (android versionCode base {code})")


def main():
    set_version()
    for rel, old, new in EDITS + COLOR_EDITS + UPDATE_EDITS:
        print(f"[{edit(rel, old, new)}] {rel}")
    for name, dests in ICONS.items():
        src = ASSETS / name
        if not src.exists():
            print(f"[falta] branding/{name} (mantido o original)")
            continue
        for d in dests:
            if (SRC / d).parent.exists():
                shutil.copyfile(src, SRC / d)
        print(f"[ícone] {name} -> {', '.join(dests)}")
    kt = (ASSETS / "android-src" / "FlowXUpdater.kt").read_text(encoding="utf-8")
    (SRC / "flutter/android/app/src/main/kotlin/com/carriez/flutter_hbb/FlowXUpdater.kt").write_text(
        kt.replace("__UPDATE_REPO__", f"{_O}/{_R}"), encoding="utf-8", newline="")
    print("[android] FlowXUpdater.kt")
    android = ASSETS / "android"  # res/mipmap-* gerados do logo
    if android.exists():
        shutil.copytree(android, SRC / "flutter/android/app/src/main/res", dirs_exist_ok=True)
        print("[ícone] android mipmaps")


if __name__ == "__main__":
    main()
