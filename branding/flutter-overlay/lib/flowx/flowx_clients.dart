// FlowXDesk Técnico: todos os PCs com FlowXDesk. A lista vem do FlowX Hub (aparelhos ativados);
// online/offline vem do servidor de conexão. Só aparece no build do técnico com licenciamento ligado.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';

import 'flowx_activation.dart';
import 'flowx_theme.dart';

const _errors = {
  'nao_tecnico': 'Este FlowXDesk não é de técnico.',
  'nao_autorizado': 'O Hub recusou este técnico.',
  'fora_do_horario': 'O relógio deste PC está errado. Acerte a hora e tente de novo.',
  'sem_conexao': 'Sem conexão com o FlowX Hub.',
};

/// Filtra pelo que o técnico digitou: nome do PC, empresa ou número (com ou sem espaços).
List<Map<String, dynamic>> flowxFilterDevices(List<Map<String, dynamic>> all, String q) {
  final t = q.trim().toLowerCase().replaceAll(' ', '');
  if (t.isEmpty) return all;
  return all.where((d) {
    final s = '${d['hostname'] ?? ''}${d['org'] ?? ''}${d['device_id'] ?? ''}'.toLowerCase().replaceAll(' ', '');
    return s.contains(t);
  }).toList();
}

class FlowXClients extends StatefulWidget {
  const FlowXClients({super.key});

  @override
  State<FlowXClients> createState() => _FlowXClientsState();
}

class _FlowXClientsState extends State<FlowXClients> {
  static const _cb = 'callback_query_onlines';
  static const _listener = 'FlowXClients';
  bool _show = false;
  bool _loading = true;
  String _error = '';
  String _q = '';
  List<Map<String, dynamic>> _devices = [];
  Set<String> _online = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (flowxLicenseStatus()['enabled'] != true) return;
    bind.mainGetCommon(key: 'flowx-tech-build').then((v) {
      if (v != 'true' || !mounted) return;
      setState(() => _show = true);
      platformFFI.registerEventHandler(_cb, _listener, (evt) async {
        Set<String> ids(dynamic s) => (s as String? ?? '').split(',').where((e) => e.isNotEmpty).toSet();
        if (mounted) setState(() => _online = _online.union(ids(evt['onlines'])).difference(ids(evt['offlines'])));
      });
      _load();
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => _queryOnlines());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_show) platformFFI.unregisterEventHandler(_cb, _listener);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    var error = '';
    var devices = <Map<String, dynamic>>[];
    try {
      final v = jsonDecode(await bind.mainFlowxDevices());
      if (v is Map && v['devices'] is List) {
        devices = (v['devices'] as List).whereType<Map>().map((d) => Map<String, dynamic>.from(d)).toList();
      } else {
        error = _errors[v is Map ? v['error'] : null] ?? 'Não foi possível carregar a lista agora.';
      }
    } catch (_) {
      error = 'Não foi possível carregar a lista agora.';
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
      _devices = devices;
    });
    _queryOnlines();
  }

  void _queryOnlines() {
    final ids = _devices.map((d) => '${d['device_id']}').where((id) => id.isNotEmpty).toList();
    if (ids.isNotEmpty) bind.queryOnlines(ids: ids);
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final dark = FlowX.isDark(context);
    final list = flowxFilterDevices(_devices, _q)
      ..sort((a, b) => (_online.contains('${b['device_id']}') ? 1 : 0) - (_online.contains('${a['device_id']}') ? 1 : 0));
    final onlineCount = _devices.where((d) => _online.contains('${d['device_id']}')).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? FlowX.surface : FlowX.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? FlowX.line : FlowX.lineLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('CLIENTES FLOWX · ${_devices.length} PCs, $onlineCount online',
                style: TextStyle(
                    fontFamily: FlowX.sans, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.6, color: FlowX.accentText(context))),
          ),
          IconButton(
              tooltip: 'Atualizar lista',
              onPressed: _loading ? null : _load,
              icon: Icon(Icons.refresh, size: 20, color: FlowX.muted(context))),
        ]),
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: const InputDecoration(
              isDense: true, prefixIcon: Icon(Icons.search, size: 20), hintText: 'Buscar por PC, empresa ou número'),
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)))
        else if (_error.isNotEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error, style: const TextStyle(fontFamily: FlowX.sans, color: FlowX.danger, fontWeight: FontWeight.w600)))
        else if (list.isEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_devices.isEmpty ? 'Nenhum PC ativado ainda.' : 'Nada encontrado.',
                  style: TextStyle(fontFamily: FlowX.sans, color: FlowX.muted(context))))
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: list.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: dark ? FlowX.line : FlowX.lineLight),
              itemBuilder: (context, i) => _row(context, list[i], dark),
            ),
          ),
      ]),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> d, bool dark) {
    final id = '${d['device_id'] ?? ''}';
    final on = _online.contains(id);
    final sub = [d['org'], id, d['app_version'] == null ? null : 'v${d['app_version']}']
        .where((e) => e != null && '$e'.isNotEmpty)
        .join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Tooltip(
          message: on ? 'Online' : 'Offline',
          child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: on ? FlowX.ok : FlowX.muted(context).withOpacity(0.4))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${d['hostname'] ?? id}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: FlowX.sans, fontWeight: FontWeight.w600, color: dark ? FlowX.textOnDark : FlowX.ink)),
            Text(sub, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: FlowX.sans, fontSize: 12, color: FlowX.muted(context))),
          ]),
        ),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: id.isEmpty ? null : () => connect(context, id), child: const Text('Conectar')),
      ]),
    );
  }
}
