// FlowXDesk: cartão "Atualizar agora" quando há versão nova nas Releases da FlowX.
// Android: FlowXUpdater.kt baixa e instala (confere sha256 e assinatura do APK).
// Windows: o atualizador do próprio app (metadados assinados ed25519), mesmo caminho da atualização automática.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/widgets/update_progress.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'flowx_theme.dart';

const _metaUrl = 'https://github.com/FlowX-Sistemas/flowxdesk/releases/latest/download/flowxdesk-update.json';

int flowxVersionNumber(String v) {
  final p = v.split('.');
  if (p.length != 3) return -1;
  try {
    return int.parse(p[0]) * 1000000 + int.parse(p[1]) * 1000 + int.parse(p[2]);
  } catch (_) {
    return -1;
  }
}

class FlowXUpdateCard extends StatefulWidget {
  const FlowXUpdateCard({super.key});

  @override
  State<FlowXUpdateCard> createState() => _FlowXUpdateCardState();
}

class _FlowXUpdateCardState extends State<FlowXUpdateCard> {
  static String? _latest; // guardado entre reconstruções da tela
  static String? _fileUrl;
  String _status = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if ((Platform.isAndroid || Platform.isWindows) && _latest == null) _fetch();
  }

  Future<void> _fetch() async {
    try {
      final r = await http.get(Uri.parse(_metaUrl)).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return;
      final m = jsonDecode(r.body) as Map<String, dynamic>;
      if (m['app'] != 'flowxdesk') return;
      final latest = m['version'] as String;
      if (flowxVersionNumber(latest) <= flowxVersionNumber(version)) return;
      for (final a in (m['artifacts'] as List)) {
        if (a['platform'] == (Platform.isAndroid ? 'android' : 'windows')) _fileUrl = a['url'] as String;
      }
      if (mounted) setState(() => _latest = latest);
    } catch (_) {}
  }

  Future<void> _update() async {
    if (Platform.isWindows) {
      if (bind.mainIsInstalled()) {
        handleUpdate('https://github.com/FlowX-Sistemas/flowxdesk/releases/tag/$_latest');
      } else if (_fileUrl != null) {
        launchUrl(Uri.parse(_fileUrl!));
      }
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Baixando a versão $_latest…';
    });
    String res;
    try {
      res = await gFFI.invokeMethodWithResult<String>('flowx_update_now') ?? 'erro';
    } catch (e) {
      res = 'erro';
    }
    if (!mounted) return;
    if (res == 'ok') {
      setState(() => _status = 'Pronto. Confirme a instalação na tela do Android.');
    } else {
      // plano B: baixa o APK pelo navegador
      setState(() => _status = 'Não deu para instalar daqui; abrindo o download…');
      if (_fileUrl != null) launchUrl(Uri.parse(_fileUrl!), mode: LaunchMode.externalApplication);
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_latest == null) return const SizedBox.shrink();
    return _card(context, 'ATUALIZAÇÃO DISPONÍVEL', 'FlowXDesk $_latest (você tem $version)', _status,
        _busy ? null : _update, 'Atualizar agora', busy: _busy);
  }
}

/// Avisos do RustDesk (instalar, versão desatualizada, permissões) no visual FlowX.
Widget flowXNoticeCard(BuildContext context, String title, String content, String btnText, VoidCallback onPressed,
    {String? help, String? link, VoidCallback? onClose}) {
  final label = title.isEmpty ? 'AVISO' : translate(title).toUpperCase();
  return _card(context, label, translate(content), '', onPressed, btnText.isEmpty ? null : translate(btnText),
      help: help == null ? null : translate(help), link: link, onClose: onClose);
}

Widget _card(BuildContext context, String label, String text, String status, VoidCallback? onPressed, String? btn,
    {bool busy = false, String? help, String? link, VoidCallback? onClose}) {
  final dark = FlowX.isDark(context);
  return Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: dark ? FlowX.surface : FlowX.paper,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: FlowX.champagneStrong.withOpacity(0.6)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontFamily: FlowX.sans, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.6, color: FlowX.accentText(context))),
        ),
        if (onClose != null)
          IconButton(
              tooltip: translate('Close'),
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
              icon: Icon(Icons.close, size: 18, color: FlowX.muted(context))),
      ]),
      if (text.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(text, style: TextStyle(fontFamily: FlowX.sans, fontSize: 16, height: 1.4, color: dark ? FlowX.textOnDark : FlowX.ink)),
      ],
      if (status.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(status, style: TextStyle(fontFamily: FlowX.sans, color: FlowX.muted(context))),
      ],
      if (btn != null) ...[
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: onPressed,
            child: busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                : Text(btn),
          ),
        ),
      ],
      if (help != null && link != null)
        TextButton(onPressed: () => launchUrl(Uri.parse(link)), child: Text(help)),
    ]),
  );
}
