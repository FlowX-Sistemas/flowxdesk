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
  late final Map<String, dynamic> _s = flowxLicenseStatus();
  late final bool _needs = _s['enabled'] == true && _s['licensed'] != true;
  // período de carência (status ok sem licença): a tela abre, mas dá para pular nesta abertura
  late final bool _canSkip = _s['ok'] == true;
  // na carência mostra o app até saber que não é técnico (evita piscar a tela no PC do técnico);
  // com bloqueio mostra a tela até saber que é técnico
  late bool _ok = !_needs || _canSkip;

  @override
  void initState() {
    super.initState();
    if (!_needs) return;
    bind.mainGetCommon(key: 'flowx-tech-build').then((v) {
      if (mounted) setState(() => _ok = v == 'true');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ok) return widget.child;
    return FlowXActivation(
      onActivated: () => setState(() => _ok = true),
      onCancel: _canSkip ? () => setState(() => _ok = true) : null,
    );
  }
}

/// Período de carência: licenciamento ligado mas sem bloqueio. Lembra de ativar até o PC ter licença.
class FlowXLicenseCard extends StatefulWidget {
  const FlowXLicenseCard({super.key});

  @override
  State<FlowXLicenseCard> createState() => _FlowXLicenseCardState();
}

class _FlowXLicenseCardState extends State<FlowXLicenseCard> {
  late bool _show = _needed();

  @override
  void initState() {
    super.initState();
    // técnico entra pela chave do técnico: não precisa de licença nem do aviso
    if (_show) {
      bind.mainGetCommon(key: 'flowx-tech-build').then((v) {
        if (v == 'true' && mounted) setState(() => _show = false);
      });
    }
  }

  static bool _needed() {
    final s = flowxLicenseStatus();
    return s['enabled'] == true && s['licensed'] != true;
  }

  void _open() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: FlowXActivation(
            compact: true,
            onCancel: () => Navigator.of(ctx).pop(),
            onActivated: () {
              Navigator.of(ctx).pop();
              setState(() => _show = _needed());
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
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
        Text('ATIVE SUA LICENÇA',
            style: TextStyle(
                fontFamily: FlowX.sans, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.6, color: FlowX.accentText(context))),
        const SizedBox(height: 6),
        Text('Digite a chave enviada pela FlowX Sistemas. Em breve o FlowXDesk só funcionará com licença ativa.',
            style: TextStyle(fontFamily: FlowX.sans, fontSize: 16, height: 1.4, color: dark ? FlowX.textOnDark : FlowX.ink)),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: _open, child: const Text('Ativar agora'))),
      ]),
    );
  }
}

class FlowXActivation extends StatefulWidget {
  const FlowXActivation({super.key, required this.onActivated, this.onCancel, this.compact = false});
  final VoidCallback onActivated;
  /// Período de carência: mostra "Agora não".
  final VoidCallback? onCancel;
  /// Dentro de uma janela: encolhe ao conteúdo.
  final bool compact;

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
    final inDialog = widget.compact;
    final content = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              Row(children: [
                Expanded(
                  child: Text('Não tem a chave? Fale com o suporte da FlowX.',
                      style: TextStyle(fontFamily: FlowX.sans, color: FlowX.muted(context))),
                ),
                if (widget.onCancel != null) TextButton(onPressed: widget.onCancel, child: const Text('Agora não')),
              ]),
            ]);
    return Material(
      color: dark ? FlowX.ink : FlowX.ivory,
      child: inDialog
          ? Padding(padding: const EdgeInsets.all(28), child: content)
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: content),
              ),
            ),
    );
  }
}
