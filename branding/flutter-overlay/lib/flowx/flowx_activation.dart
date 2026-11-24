// FlowXDesk: ativação por licença do FlowX Hub. Sem licença válida, o app mostra só esta tela
// (o serviço também recusa conexões). Se o build não tem licenciamento, deixa passar direto.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/models/platform_model.dart';

import 'flowx_theme.dart';

Map<String, dynamic> flowxLicenseStatus() {
  try {
    return jsonDecode(bind.mainFlowxLicenseStatus()) as Map<String, dynamic>;
  } catch (_) {
    return const {'ok': true};
  }
}

class FlowXLicenseGate extends StatefulWidget {
  const FlowXLicenseGate({super.key, required this.child});
  final Widget child;

  @override
  State<FlowXLicenseGate> createState() => _FlowXLicenseGateState();
}

class _FlowXLicenseGateState extends State<FlowXLicenseGate> {
  late bool _ok = flowxLicenseStatus()['ok'] == true;

  @override
  Widget build(BuildContext context) {
    if (_ok) return widget.child;
    return FlowXActivation(onActivated: () => setState(() => _ok = true));
  }
}

class FlowXActivation extends StatefulWidget {
  const FlowXActivation({super.key, required this.onActivated});
  final VoidCallback onActivated;

  @override
  State<FlowXActivation> createState() => _FlowXActivationState();
}

class _FlowXActivationState extends State<FlowXActivation> {
  final _key = TextEditingController();
  String _error = '';
  bool _busy = false;

  Future<void> _activate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    final err = await bind.mainFlowxActivate(key: _key.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err.isEmpty) widget.onActivated();
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = FlowX.isDark(context);
    return Material(
      color: dark ? FlowX.ink : FlowX.ivory,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Image.asset('assets/icon.png', width: 64, height: 64),
              const SizedBox(height: 24),
              Text('ATIVAR O FLOWXDESK',
                  style: TextStyle(
                      fontFamily: FlowX.sans,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: FlowX.accentText(context))),
              const SizedBox(height: 10),
              Text('Informe a chave de licença enviada pela FlowX Sistemas.',
                  style: TextStyle(fontFamily: FlowX.sans, fontSize: 20, height: 1.35, color: dark ? FlowX.textOnDark : FlowX.ink)),
              const SizedBox(height: 24),
              TextField(
                controller: _key,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _activate(),
                style: const TextStyle(fontFamily: FlowX.mono, fontWeight: FontWeight.w700, fontSize: 20, letterSpacing: 1.5),
                decoration: const InputDecoration(hintText: 'FXD-XXXX-XXXX-XXXX', labelText: 'Chave de licença'),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error, style: const TextStyle(fontFamily: FlowX.sans, color: FlowX.danger, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _busy ? null : _activate,
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                      : const Text('Ativar'),
                ),
              ),
              const SizedBox(height: 18),
              Text('Não tem a chave? Fale com o suporte da FlowX.',
                  style: TextStyle(fontFamily: FlowX.sans, color: FlowX.muted(context))),
            ]),
          ),
        ),
      ),
    );
  }
}
