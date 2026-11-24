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
    # Sem "Desenvolvido por RustDesk" na tela inicial; crédito, licença e código-fonte ficam na tela Sobre
    ("flutter/lib/common.dart",
     'Widget loadPowered(BuildContext context) {\n  if (bind.mainGetBuildinOption(key: "hide-powered-by-me") == \'Y\') {',
     'Widget loadPowered(BuildContext context) {\n  if (true) { // FlowXDesk'),
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
# Chave PÚBLICA que assina as licenças no Hub (a privada fica só no Hub: segredo FLOWXDESK_LICENSE_SIGNING_KEY)
LICENSE_PUBLIC_KEY = [198, 151, 239, 68, 146, 39, 99, 138, 71, 190, 147, 151, 169, 72, 147, 15,
                      168, 25, 95, 174, 22, 112, 86, 167, 164, 118, 11, 177, 175, 93, 190, 141]
# Chave PÚBLICA do técnico FlowX (a privada fica em _segredos e só entra no build técnico, nunca no público)
TECH_PUBLIC_KEY = [65, 246, 247, 251, 53, 42, 93, 241, 50, 63, 45, 34, 138, 16, 101, 47,
                   168, 36, 130, 9, 229, 252, 216, 136, 79, 186, 190, 87, 114, 150, 49, 129]
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
    # também ao voltar para o app (o Android costuma manter a activity viva)
    ("flutter/android/app/src/main/kotlin/com/carriez/flutter_hbb/MainActivity.kt",
     "    override fun onResume() {\n        super.onResume()\n",
     "    override fun onResume() {\n        super.onResume()\n        FlowXUpdater.maybeCheck(this)\n"),
    ("flutter/android/app/src/main/AndroidManifest.xml",
     '    <uses-permission android:name="android.permission.INTERNET" />\n',
     '    <uses-permission android:name="android.permission.INTERNET" />\n'
     '    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />\n'),
    ("flutter/android/app/src/main/AndroidManifest.xml", "    </application>",
     '        <receiver android:name=".FlowXUpdateReceiver" android:exported="false" />\n    </application>'),
    # Acesso de técnico sem senha (branding/rust-src/flowx_tech.rs)
    ("src/lib.rs", "mod keyboard;\n", "mod keyboard;\npub mod flowx_tech;\n"),
    ("src/client.rs",
     "    let password = if password.is_empty() {\n        // login without password, the remote side can click accept\n",
     "    // FlowXDesk Técnico: sem senha, assina o desafio do PC (no build público sign_login devolve None)\n"
     "    let flowx_sig = if password.is_empty() {\n"
     "        crate::flowx_tech::sign_login(&lc.read().unwrap().id, hash.challenge.as_bytes())\n"
     "    } else {\n        None\n    };\n"
     "    let password = if let Some(sig) = flowx_sig {\n        sig\n    } else if password.is_empty() {\n"
     "        // login without password, the remote side can click accept\n"),
    ("src/server/connection.rs",
     "    fn validate_password(&mut self, allow_permanent_password: bool) -> bool {\n",
     "    fn validate_password(&mut self, allow_permanent_password: bool) -> bool {\n"
     "        if crate::flowx_tech::verify_login(&Config::get_id(), self.hash.challenge.as_bytes(), &self.lr.password) {\n"
     "            log::info!(\"FlowXDesk: acesso de técnico FlowX (assinatura válida)\");\n"
     "            self.set_conn_audit_primary_auth(ConnAuditPrimaryAuth::PermanentPassword);\n"
     "            return true;\n        }\n"),
    # Auto-elevar: aberto sem estar instalado no Windows, instala-se como serviço sozinho (um "Sim" no UAC),
    # igual a clicar em "Instalar" com as opções padrão. Depois o técnico controla telas de admin/UAC.
    ("flutter/lib/desktop/pages/desktop_home_page.dart",
     "  void initState() {\n    super.initState();\n    _updateTimer = periodic_immediate(",
     "  void initState() {\n    super.initState();\n"
     "    if (isWindows && !bind.isDisableInstallation() && !bind.mainIsInstalled() && !bind.isOutgoingOnly()) {\n"
     "      Future.delayed(const Duration(milliseconds: 800), () async {\n"
     "        await rustDeskWinManager.closeAllSubWindows();\n"
     "        bind.installInstallMe(options: ' startmenu desktopicon', path: bind.installInstallPath());\n"
     "      });\n    }\n"
     "    _updateTimer = periodic_immediate("),
    # Sem conta/login do RustDesk nem catálogo na nuvem dele: o FlowXDesk usa licença do Hub FlowX
    ("libs/hbb_common/src/config.rs",
     "pub static ref HARD_SETTINGS: RwLock<HashMap<String, String>> = Default::default();",
     'pub static ref HARD_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from([\n'
     '        ("disable-account".to_owned(), "Y".to_owned()),\n'
     '        ("disable-ab".to_owned(), "Y".to_owned()),\n    ]));'),
    # Atualização automática ligada por padrão (o usuário ainda pode desligar nas configurações)
    ("libs/hbb_common/src/config.rs",
     "pub static ref DEFAULT_SETTINGS: RwLock<HashMap<String, String>> = Default::default();",
     'pub static ref DEFAULT_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from([(\n'
     '        "allow-auto-update".to_owned(), "Y".to_owned())]));'),
]

# Redesenho FlowX (direção "senha de atendimento", ver .impeccable/surfaces/): arquivos próprios em
# branding/flutter-overlay/lib/flowx (tema + palco), fontes embutidas e poucos ganchos abaixo.
UI_EDITS = [
    # âncora única: "  fonts:\n" sozinho também casa com o "      fonts:" de cada família de ícones
    ("flutter/pubspec.yaml", "\n  fonts:\n    - family: GestureIcons\n",
     "\n  fonts:\n"
     "    - family: Inter\n      fonts:\n"
     "        - asset: assets/fonts/Inter-Regular.ttf\n"
     "        - asset: assets/fonts/Inter-Medium.ttf\n          weight: 500\n"
     "        - asset: assets/fonts/Inter-SemiBold.ttf\n          weight: 600\n"
     "        - asset: assets/fonts/Inter-Bold.ttf\n          weight: 700\n"
     "    - family: JetBrainsMono\n      fonts:\n"
     "        - asset: assets/fonts/JetBrainsMono-Medium.ttf\n          weight: 500\n"
     "        - asset: assets/fonts/JetBrainsMono-Bold.ttf\n          weight: 700\n"
     "        - asset: assets/fonts/JetBrainsMono-ExtraBold.ttf\n          weight: 800\n"
     "    - family: GestureIcons\n"),
    ("flutter/lib/common.dart", "import 'package:flutter_hbb/common/formatter/id_formatter.dart';\n",
     "import 'package:flutter_hbb/common/formatter/id_formatter.dart';\nimport 'package:flutter_hbb/flowx/flowx_theme.dart';\n"),
    ("flutter/lib/common.dart", "  static ThemeData lightTheme = ThemeData(",
     "  static ThemeData lightTheme = flowxTheme(_rustdeskLightTheme, Brightness.light);\n"
     "  static ThemeData _rustdeskLightTheme = ThemeData("),
    ("flutter/lib/common.dart", "  static ThemeData darkTheme = ThemeData(",
     "  static ThemeData darkTheme = flowxTheme(_rustdeskDarkTheme, Brightness.dark);\n"
     "  static ThemeData _rustdeskDarkTheme = ThemeData("),
    # Escuro por padrão (o usuário ainda escolhe claro/sistema nas configurações)
    ("flutter/lib/common.dart",
     "    return themeModeFromString(bind.mainGetLocalOption(key: kCommConfKeyTheme));",
     "    final v = bind.mainGetLocalOption(key: kCommConfKeyTheme);\n"
     "    return v.isEmpty ? ThemeMode.dark : themeModeFromString(v);"),
    # Vocabulário do painel de atendimento (pt-BR)
    ("src/lang/pt_BR.rs", '("Control Remote Desktop", "Controle um Computador Remoto"),',
     '("Control Remote Desktop", "Chamar um cliente"),'),
    ("src/lang/pt_BR.rs", '("Enter Remote ID", "Informe o ID Remoto"),', '("Enter Remote ID", "Número do cliente"),'),
    ("src/lang/pt_BR.rs", '("Recent sessions", "Sessões recentes"),', '("Recent sessions", "Chamados recentes"),'),
    ("src/lang/pt_BR.rs", '("One-time Password", "Senha de uso único"),', '("One-time Password", "Senha desta vez"),'),
    # Painel lateral: a situação já aparece no palco
    ("flutter/lib/desktop/pages/connection_page.dart",
     "        if (!isOutgoingOnly) const Divider(height: 1),\n        if (!isOutgoingOnly) OnlineStatusWidget()\n",
     "        // FlowXDesk: situação mostrada no palco da tela inicial\n"),
    # Licença do Hub (branding/rust-src/flowx_license.rs): desligada se o build não tiver FLOWX_LICENSE_URL
    # (o técnico por licença entra pelos mesmos ganchos do acesso técnico: ver flowx_tech.rs)
    ("src/lib.rs", "/// cbindgen:ignore\npub mod platform;\n",
     "pub mod flowx_license;\n/// cbindgen:ignore\npub mod platform;\n"),
    ("src/server/connection.rs",
     "        if let Some(message::Union::LoginRequest(lr)) = msg.union {\n"
     "            if !self.check_login_scope(&lr).await {\n                return false;\n            }\n",
     "        if let Some(message::Union::LoginRequest(lr)) = msg.union {\n"
     "            if !crate::flowx_license::device_licensed() {\n"
     "                self.send_login_error(\"Este computador está sem licença FlowXDesk válida\").await;\n"
     "                return false;\n            }\n"
     "            if !self.check_login_scope(&lr).await {\n                return false;\n            }\n"),
    ("src/rendezvous_mediator.rs", "        check_zombie();\n",
     "        crate::flowx_license::start_refresh_loop();\n        check_zombie();\n"),
    ("src/flutter_ffi.rs", "pub fn main_is_using_public_server() -> bool {\n",
     "pub fn main_flowx_license_status() -> SyncReturn<String> {\n"
     "    SyncReturn(crate::flowx_license::status_json())\n}\n\n"
     "pub fn main_flowx_activate(key: String) -> String {\n"
     "    match hbb_common::tokio::runtime::Runtime::new() {\n"
     "        Ok(rt) => rt.block_on(crate::flowx_license::activate(key)),\n"
     "        Err(e) => e.to_string(),\n    }\n}\n\n"
     "pub fn main_is_using_public_server() -> bool {\n"),
    # Rede: cada lado usa o endereço do relay FlowX que ele alcança (branding/rust-src/flowx_net.rs)
    ("src/lib.rs", "pub mod flowx_tech;\n", "pub mod flowx_tech;\npub mod flowx_net;\n"),
    ("src/client.rs",
     "        let mut conn = connect_tcp(\n            ipv4_to_ipv6(relay_server, ipv4 || use_ws_proxy),\n"
     "            CONNECT_TIMEOUT,\n        )\n        .await\n",
     "        let mut conn = crate::flowx_net::connect_relay(relay_server, ipv4 || use_ws_proxy)\n        .await\n"),
    ("src/server.rs",
     "    let mut stream = socket_client::connect_tcp(\n        socket_client::ipv4_to_ipv6(relay_server, ipv4 || use_ws_proxy),\n"
     "        CONNECT_TIMEOUT,\n    )\n    .await?;",
     "    let mut stream = crate::flowx_net::connect_relay(relay_server, ipv4 || use_ws_proxy).await?;"),
    # O servidor embutido é o da FlowX: sem o aviso "configure seu próprio servidor"
    ("src/common.rs", "pub fn using_public_server() -> bool {\n    crate::get_custom",
     "pub fn using_public_server() -> bool {\n    false && crate::get_custom"),
    # Barra da sessão remota: grafite FlowX, cantos maiores, vermelho FlowX
    ("flutter/lib/desktop/widgets/remote_toolbar.dart",
     "  static Color inactiveColor = Colors.grey[800]!;\n  static Color hoverInactiveColor = Colors.grey[850]!;\n\n"
     "  static const Color redColor = Colors.redAccent;\n  static const Color hoverRedColor = Colors.red;",
     "  static Color inactiveColor = const Color(0xFF2A2730);\n  static Color hoverInactiveColor = const Color(0xFF34313A);\n\n"
     "  static const Color redColor = Color(0xFFE5705F);\n  static const Color hoverRedColor = Color(0xFFC9533F);"),
    ("flutter/lib/desktop/widgets/remote_toolbar.dart", "  static const double iconRadius = 8;",
     "  static const double iconRadius = 10;"),
    ("flutter/lib/desktop/widgets/remote_toolbar.dart", "  static double menuBorderRadius = isWindows ? 5.0 : 7.0;",
     "  static double menuBorderRadius = 12.0;"),
    # Painel lateral estreito: clientes em lista por padrão (o usuário ainda troca para grade)
    ("flutter/lib/common/widgets/peer_tab_page.dart",
     "    if (uiType != '') {\n      peerCardUiType.value = int.parse(uiType) == 0",
     "    if (uiType == '' && isDesktop) {\n      peerCardUiType.value = PeerUiType.list;\n"
     "    } else if (uiType != '') {\n      peerCardUiType.value = int.parse(uiType) == 0"),
    # Sem licença válida do Hub: só a tela de ativação (flowx_activation.dart)
    ("flutter/lib/desktop/pages/desktop_home_page.dart",
     "    return buildRemoteBlock(\n        block: _block, mask: true, use: canBeBlocked, child: child);",
     "    return FlowXLicenseGate(\n        child: buildRemoteBlock(\n            block: _block, mask: true, use: canBeBlocked, child: child));"),
    ("flutter/lib/desktop/pages/desktop_home_page.dart",
     "import 'package:flutter_hbb/consts.dart';\n",
     "import 'package:flutter_hbb/consts.dart';\nimport 'package:flutter_hbb/flowx/flowx_activation.dart';\n"),
    ("flutter/lib/mobile/pages/home_page.dart", "          body: _pages.elementAt(_selectedIndex),",
     "          body: FlowXLicenseGate(child: _pages.elementAt(_selectedIndex)),"),
    ("flutter/lib/mobile/pages/home_page.dart", "import 'package:flutter/material.dart';\n",
     "import 'package:flutter/material.dart';\nimport 'package:flutter_hbb/flowx/flowx_activation.dart';\n"),
    # Celular (cliente compartilhando a tela): o mesmo palco, compacto
    ("flutter/lib/mobile/pages/server_page.dart", "import '../../common.dart';\n",
     "import '../../common.dart';\nimport '../../flowx/flowx_home.dart';\n"),
    ("flutter/lib/mobile/pages/server_page.dart", "                            ? ServerInfo()",
     "                            ? const FlowXStage(compact: true)"),
    # Tela inicial desktop: o palco com o número no lugar do painel estreito; conexão vira painel lateral
    ("flutter/lib/desktop/pages/desktop_home_page.dart", "import 'package:flutter_hbb/common.dart';\n",
     "import 'package:flutter_hbb/common.dart';\nimport 'package:flutter_hbb/flowx/flowx_home.dart';\n"),
    ("flutter/lib/desktop/pages/desktop_home_page.dart",
     "        buildLeftPane(context),\n"
     "        if (!isIncomingOnly) const VerticalDivider(width: 1),\n"
     "        if (!isIncomingOnly) Expanded(child: buildRightPane(context)),\n",
     "        if (isIncomingOnly)\n          buildLeftPane(context)\n        else\n"
     "          Expanded(\n              child: FlowXStage(extras: [\n"
     "            if (!bind.isOutgoingOnly()) buildPresetPasswordWarning(),\n"
     "            Obx(() => buildHelpCards(stateGlobal.updateUrl.value)),\n          ])),\n"
     "        if (!isIncomingOnly) const VerticalDivider(width: 1),\n"
     "        if (!isIncomingOnly) SizedBox(width: MediaQuery.of(context).size.width < 1100 ? 384 : 440, child: buildRightPane(context)),\n"),
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


def recolor_blues():
    """Azuis fixos do RustDesk (Colors.blue, blueAccent, blue[700]!, blue.shade300) -> dourado FlowX (AA com branco)."""
    import re
    pat = re.compile(r"Colors\.(?:blue|lightBlue|indigo)(?:Accent)?(?:\[\d+\]!?|\.shade\d+)?(?![A-Za-z])"
                     r"|(?:const )?Color\(0[xX]FF(?:2C8CFF|2196F3|2F65BA|0071FF)\)")
    n = 0
    for p in (SRC / "flutter/lib").rglob("*.dart"):
        if "flowx" in p.parts:
            continue
        s = p.read_text(encoding="utf-8")
        s2, k = pat.subn("const Color(0xFF8F6A2C)", s)
        if k:
            p.write_text(s2, encoding="utf-8", newline="")
            n += k
    print(f"[cores] {n} azuis fixos trocados")


def main():
    set_version()
    for rel, old, new in EDITS + COLOR_EDITS + UPDATE_EDITS + UI_EDITS:
        print(f"[{edit(rel, old, new)}] {rel}")
    recolor_blues()  # depois das edições: elas procuram as cores originais
    for name, dests in ICONS.items():
        src = ASSETS / name
        if not src.exists():
            print(f"[falta] branding/{name} (mantido o original)")
            continue
        for d in dests:
            if (SRC / d).parent.exists():
                shutil.copyfile(src, SRC / d)
        print(f"[ícone] {name} -> {', '.join(dests)}")
    shutil.copytree(ASSETS / "flutter-overlay" / "lib", SRC / "flutter/lib", dirs_exist_ok=True)
    (SRC / "flutter/assets/fonts").mkdir(parents=True, exist_ok=True)
    for f in (ASSETS / "fonts").glob("*.ttf"):
        shutil.copyfile(f, SRC / "flutter/assets/fonts" / f.name)
    print("[ui] flowx/*.dart + fontes")
    rs = (ASSETS / "rust-src" / "flowx_tech.rs").read_text(encoding="utf-8")
    shutil.copyfile(ASSETS / "rust-src" / "flowx_net.rs", SRC / "src/flowx_net.rs")
    lic = (ASSETS / "rust-src" / "flowx_license.rs").read_text(encoding="utf-8")
    (SRC / "src/flowx_license.rs").write_text(
        lic.replace("__LICENSE_PUBLIC_KEY__", str(LICENSE_PUBLIC_KEY)), encoding="utf-8", newline="")
    (SRC / "src/flowx_tech.rs").write_text(
        rs.replace("__TECH_PUBLIC_KEY__", str(TECH_PUBLIC_KEY)), encoding="utf-8", newline="")
    print("[rust] flowx_tech.rs")
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
