// FlowXDesk: "palco" da tela inicial — o número do PC como senha chamada no painel de atendimento.
// Copiado por scripts/brand.py; usado em desktop_home_page.dart e na tela do celular.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart' show OnlineStatusWidget;
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:provider/provider.dart';

import 'flowx_theme.dart';

/// Número grande com troca dígito a dígito (o "chamar" do painel).
class FlowXCalledNumber extends StatelessWidget {
  const FlowXCalledNumber(this.value, {super.key, this.size = 120});
  final String value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = FlowX.isDark(context);
    final digitColor = dark ? FlowX.ivory : FlowX.ink;
    final groups = value.trim().split(RegExp(r'\s+')).where((g) => g.isNotEmpty).toList();
    final style = TextStyle(
      fontFamily: FlowX.mono,
      fontWeight: FontWeight.w800,
      fontSize: size,
      height: 1.0,
      color: digitColor,
      letterSpacing: -size * 0.02,
    );
    final children = <Widget>[];
    for (var g = 0; g < groups.length; g++) {
      if (g > 0) {
        children.add(Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.12),
          child: Container(
            width: size * 0.1,
            height: size * 0.1,
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF5C5764) : const Color(0xFFCFC6B4),
              shape: BoxShape.circle,
            ),
          ),
        ));
      }
      for (var i = 0; i < groups[g].length; i++) {
        children.add(_Digit(char: groups[g][i], style: style, delay: Duration(milliseconds: 40 * (g * 3 + i))));
      }
    }
    return Semantics(
      label: 'Seu número de atendimento: $value',
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _Digit extends StatelessWidget {
  const _Digit({required this.char, required this.style, required this.delay});
  final String char;
  final TextStyle style;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: FlowX.medium + delay,
      switchInCurve: FlowX.curve,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) {
        // entra de cima com um brilho champanhe que se apaga (como o painel chamando)
        final slide = Tween<Offset>(begin: const Offset(0, -0.35), end: Offset.zero).animate(anim);
        return ClipRect(
          child: SlideTransition(
            position: slide,
            child: FadeTransition(
              opacity: anim,
              child: AnimatedBuilder(
                animation: anim,
                builder: (c, w) => DecoratedBox(
                  decoration: BoxDecoration(boxShadow: [
                    if (anim.value < 1)
                      BoxShadow(color: FlowX.champagne.withOpacity(0.35 * (1 - anim.value)), blurRadius: 28),
                  ]),
                  child: w,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: Text(char, key: ValueKey(char), style: style),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.child, this.trailing});
  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final dark = FlowX.isDark(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 220),
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      decoration: BoxDecoration(
        border: Border.all(color: dark ? FlowX.line : FlowX.lineLight),
        borderRadius: BorderRadius.circular(14),
        color: dark ? FlowX.ink.withOpacity(0.35) : FlowX.paper,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontFamily: FlowX.sans,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: dark ? FlowX.faintOnDark : FlowX.mutedOnLight)),
          const SizedBox(height: 4),
          child,
        ]),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ]),
    );
  }
}

/// Palco completo: rótulo, número, instrução, senha, situação e cartões extras (instalar, avisos).
class FlowXStage extends StatelessWidget {
  const FlowXStage({super.key, this.extras = const [], this.compact = false});
  final List<Widget> extras;
  final bool compact; // celular

  @override
  Widget build(BuildContext context) {
    final dark = FlowX.isDark(context);
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Consumer<ServerModel>(builder: (context, model, _) {
        final showOneTime = model.approveMode != 'click' && model.verificationMethod != kUsePermanentPassword;
        final muted = FlowX.muted(context);
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.4, -0.2),
              radius: 1.1,
              colors: dark ? const [FlowX.stageGlow, FlowX.ink] : const [FlowX.paper, FlowX.ivory],
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: compact ? 24 : 56, vertical: compact ? 28 : 40),
          child: _maybeScroll(
            compact,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(height: compact ? 8 : 48),
              Text('SEU NÚMERO DE ATENDIMENTO',
                  style: TextStyle(
                      fontFamily: FlowX.sans,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: FlowX.accentText(context))),
              const SizedBox(height: 18),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: model.serverId,
                builder: (_, v, __) => GestureDetector(
                  onDoubleTap: () => _copy(v.text, 'Número copiado'),
                  child: FlowXCalledNumber(v.text.isEmpty ? '··· ··· ···' : v.text, size: compact ? 64 : 120),
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Text(
                  'Dite este número ao técnico da FlowX. Você acompanha tudo na tela e pode encerrar quando quiser.',
                  style: TextStyle(fontFamily: FlowX.sans, fontSize: compact ? 16 : 20, height: 1.4, color: muted),
                ),
              ),
              const SizedBox(height: 28),
              Wrap(spacing: 16, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [
                _Tile(
                  label: 'Senha desta vez',
                  trailing: showOneTime
                      ? IconButton(
                          tooltip: 'Gerar outra senha',
                          icon: Icon(Icons.refresh_rounded, color: muted),
                          onPressed: () => bind.mainUpdateTemporaryPassword(),
                        )
                      : null,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: model.serverPasswd,
                    builder: (_, v, __) => GestureDetector(
                      onDoubleTap: showOneTime ? () => _copy(v.text, 'Senha copiada') : null,
                      child: Text(showOneTime ? v.text : 'senha fixa',
                          style: TextStyle(
                              fontFamily: FlowX.mono,
                              fontWeight: FontWeight.w700,
                              fontSize: 24,
                              letterSpacing: 2.4,
                              color: dark ? FlowX.ivory : FlowX.ink)),
                    ),
                  ),
                ),
                compact
                    // no celular a tela só aparece com o compartilhamento ligado
                    ? const _Tile(
                        label: 'Situação',
                        child: Text('● Pronto',
                            style: TextStyle(fontFamily: FlowX.sans, fontWeight: FontWeight.w700, fontSize: 18, color: FlowX.ok)))
                    : const _Tile(label: 'Situação', child: OnlineStatusWidget()),
                OutlinedButton.icon(
                  onPressed: () => _copy(model.serverId.text, 'Número copiado'),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copiar número'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), padding: const EdgeInsets.symmetric(horizontal: 20)),
                ),
              ]),
              if (extras.isNotEmpty) ...[const SizedBox(height: 28), ...extras],
            ]),
          ),
        );
      }),
    );
  }

  // no celular o palco já fica dentro da rolagem da página
  static Widget _maybeScroll(bool compact, Widget child) =>
      compact ? child : SingleChildScrollView(child: child);

  static void _copy(String text, String msg) {
    if (text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: text.replaceAll(' ', '')));
    showToast(msg);
  }
}
