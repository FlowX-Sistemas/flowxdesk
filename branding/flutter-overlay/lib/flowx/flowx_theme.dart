// FlowXDesk: tema FlowX aplicado sobre os temas do RustDesk (copiado por scripts/brand.py).
// Direção: "senha de atendimento" — grafite, numerais marfim, champanhe para chamada e ação principal.
import 'package:flutter/material.dart';

class FlowX {
  FlowX._();
  // Paleta (branding/flowxdesk-cores.json)
  static const ink = Color(0xFF17161A); // fundo escuro
  static const inkDeep = Color(0xFF111014); // barras
  static const surface = Color(0xFF222025); // superfície escura
  static const surfaceHi = Color(0xFF2A2730); // hover/selecionado
  static const line = Color(0xFF34313A); // bordas no escuro
  static const stageGlow = Color(0xFF26232B); // luz do palco
  static const ivory = Color(0xFFF8F5EF); // fundo claro / numerais
  static const paper = Color(0xFFFFFDF9); // superfície clara
  static const lineLight = Color(0xFFE3DCCD);
  static const textOnDark = Color(0xFFF2EFE8);
  static const mutedOnDark = Color(0xFFB7B0A0);
  static const faintOnDark = Color(0xFF8F887A);
  static const mutedOnLight = Color(0xFF6B6558);
  static const champagne = Color(0xFFE0C48A); // acento (texto escuro em cima)
  static const champagneStrong = Color(0xFFB98F45);
  static const champagneInk = Color(0xFF8F6A2C); // acento legível sobre marfim
  static const ok = Color(0xFF4FC08D);
  static const okInk = Color(0xFF2F7A55);
  static const danger = Color(0xFFE5705F);

  static const sans = 'Inter';
  static const mono = 'JetBrainsMono';

  static const radius = 12.0;
  static const fast = Duration(milliseconds: 120);
  static const medium = Duration(milliseconds: 220);
  static const curve = Curves.easeOutCubic;

  /// Cor de destaque para ícones/bordas/seleção: champanhe no escuro, dourado escuro (AA) no claro.
  static Color accentPrimary(bool dark) => dark ? champagne : champagneInk;
  static Color muted2(bool dark) => dark ? mutedOnDark : mutedOnLight;

  static bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  static Color accentText(BuildContext c) => isDark(c) ? champagne : champagneInk;
  static Color muted(BuildContext c) => isDark(c) ? mutedOnDark : mutedOnLight;
}

TextTheme _text(TextTheme t, Color body) => t
    .apply(fontFamily: FlowX.sans, bodyColor: body, displayColor: body)
    .copyWith(
      titleLarge: t.titleLarge?.copyWith(fontFamily: FlowX.sans, fontWeight: FontWeight.w700, color: body),
      labelLarge: t.labelLarge?.copyWith(fontFamily: FlowX.sans, fontWeight: FontWeight.w600),
    );

/// Recebe o tema do RustDesk e devolve a versão FlowX (mesmos componentes, outro mundo).
ThemeData flowxTheme(ThemeData base, Brightness b) {
  final dark = b == Brightness.dark;
  final bg = dark ? FlowX.ink : FlowX.ivory;
  final surface = dark ? FlowX.surface : FlowX.paper;
  final line = dark ? FlowX.line : FlowX.lineLight;
  final text = dark ? FlowX.textOnDark : FlowX.ink;
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(FlowX.radius));
  final primaryButton = ElevatedButton.styleFrom(
    backgroundColor: FlowX.champagne,
    foregroundColor: FlowX.ink,
    disabledBackgroundColor: dark ? Colors.white10 : Colors.black12,
    elevation: 0,
    textStyle: const TextStyle(fontFamily: FlowX.sans, fontWeight: FontWeight.w700),
    shape: shape,
  ).copyWith(
    overlayColor: MaterialStatePropertyAll(FlowX.champagneStrong.withOpacity(0.25)),
  );
  final accent = FlowX.accentPrimary(dark);
  return base.copyWith(
    // Material 2 (useMaterial3: false) ainda pinta muita coisa com primaryColor (azul por padrão):
    // barras de app, abas, navegação do celular, foco e seleção.
    primaryColor: dark ? FlowX.surface : FlowX.champagneInk,
    primaryColorLight: FlowX.champagne,
    primaryColorDark: FlowX.champagneInk,
    indicatorColor: FlowX.champagne,
    focusColor: FlowX.champagne.withOpacity(0.25),
    highlightColor: base.highlightColor == Colors.transparent ? Colors.transparent : FlowX.champagne.withOpacity(0.12),
    secondaryHeaderColor: surface,
    unselectedWidgetColor: FlowX.muted2(dark),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: dark ? FlowX.inkDeep : FlowX.paper,
      foregroundColor: text,
      elevation: 0,
      titleTextStyle: TextStyle(fontFamily: FlowX.sans, fontWeight: FontWeight.w700, fontSize: 18, color: text),
      iconTheme: IconThemeData(color: text),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: dark ? FlowX.inkDeep : FlowX.paper,
      selectedItemColor: accent,
      unselectedItemColor: FlowX.muted2(dark),
      type: BottomNavigationBarType.fixed,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: FlowX.champagne,
      foregroundColor: FlowX.ink,
    ),
    radioTheme: base.radioTheme.copyWith(
      fillColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? accent : null),
    ),
    sliderTheme: base.sliderTheme.copyWith(activeTrackColor: accent, thumbColor: accent, inactiveTrackColor: line),
    textButtonTheme: TextButtonThemeData(
      style: (base.textButtonTheme.style ?? const ButtonStyle()).copyWith(
        foregroundColor: MaterialStatePropertyAll(accent),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? FlowX.ivory : FlowX.ink,
      contentTextStyle: TextStyle(fontFamily: FlowX.sans, color: dark ? FlowX.ink : FlowX.ivory),
      actionTextColor: dark ? FlowX.champagneInk : FlowX.champagne,
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FlowX.radius), side: BorderSide(color: line)),
    ),
    scaffoldBackgroundColor: bg,
    dialogBackgroundColor: surface,
    cardColor: surface,
    canvasColor: bg,
    hoverColor: dark ? FlowX.surfaceHi : const Color(0xFFF1ECE2),
    dividerColor: line,
    textTheme: _text(base.textTheme, text),
    primaryTextTheme: _text(base.primaryTextTheme, text),
    colorScheme: base.colorScheme.copyWith(
      primary: FlowX.accentPrimary(dark),
      secondary: FlowX.accentPrimary(dark),
      background: surface,
      surface: surface,
      error: FlowX.danger,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButton),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: surface,
        foregroundColor: text,
        side: BorderSide(color: line),
        shape: shape,
        textStyle: const TextStyle(fontFamily: FlowX.sans, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: dark ? FlowX.inkDeep : FlowX.paper,
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(FlowX.radius), borderSide: BorderSide(color: line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(FlowX.radius), borderSide: BorderSide(color: line)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FlowX.radius),
        borderSide: BorderSide(color: FlowX.accentPrimary(dark), width: 1.6),
      ),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: line)),
    ),
    tabBarTheme: base.tabBarTheme.copyWith(
      labelColor: text,
      unselectedLabelColor: FlowX.muted2(dark),
      indicatorColor: FlowX.champagne,
    ),
    checkboxTheme: base.checkboxTheme.copyWith(
      fillColor: MaterialStateProperty.resolveWith(
          (s) => s.contains(MaterialState.selected) ? FlowX.accentPrimary(dark) : null),
    ),
    switchTheme: base.switchTheme.copyWith(
      thumbColor: MaterialStateProperty.resolveWith(
          (s) => s.contains(MaterialState.selected) ? FlowX.champagne : null),
      trackColor: MaterialStateProperty.resolveWith(
          (s) => s.contains(MaterialState.selected) ? FlowX.champagneStrong.withOpacity(0.55) : null),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: FlowX.champagne),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: FlowX.accentPrimary(dark),
      selectionColor: FlowX.champagne.withOpacity(0.35),
    ),
    tooltipTheme: base.tooltipTheme.copyWith(
      decoration: BoxDecoration(color: dark ? FlowX.ivory : FlowX.ink, borderRadius: BorderRadius.circular(8)),
      textStyle: TextStyle(fontFamily: FlowX.sans, color: dark ? FlowX.ink : FlowX.ivory, fontSize: 12),
    ),
    scrollbarTheme: base.scrollbarTheme.copyWith(
      thumbColor: MaterialStatePropertyAll(dark ? Colors.white24 : Colors.black26),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
    }),
  );
}
