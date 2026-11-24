// FlowXDesk (Android): cartão "Atualizar agora" quando há versão nova nas Releases da FlowX.
// O download/instalação é feito pelo FlowXUpdater.kt (confere sha256 e assinatura do APK).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
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
  static String? _apkUrl;
  String _status = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid && _latest == null) _fetch();
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
        if (a['platform'] == 'android' && a['format'] == 'apk') _apkUrl = a['url'] as String;
      }
      if (mounted) setState(() => _latest = latest);
    } catch (_) {}
  }

  Future<void> _update() async {
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
      if (_apkUrl != null) launchUrl(Uri.parse(_apkUrl!), mode: LaunchMode.externalApplication);
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_latest == null) return const SizedBox.shrink();
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
        Text('ATUALIZAÇÃO DISPONÍVEL',
            style: TextStyle(
                fontFamily: FlowX.sans, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.6, color: FlowX.accentText(context))),
        const SizedBox(height: 6),
        Text('FlowXDesk $_latest (você tem $version)',
            style: TextStyle(fontFamily: FlowX.sans, fontSize: 16, color: dark ? FlowX.textOnDark : FlowX.ink)),
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_status, style: TextStyle(fontFamily: FlowX.sans, color: FlowX.muted(context))),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _busy ? null : _update,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                : const Text('Atualizar agora'),
          ),
        ),
      ]),
    );
  }
}
