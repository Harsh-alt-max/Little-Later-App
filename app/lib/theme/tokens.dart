import 'package:material_ui/material_ui.dart';

/// Design tokens ported 1:1 from little-later-redesign-v7.html (:root vars).
@immutable
class LL extends ThemeExtension<LL> {
  const LL({
    required this.dark,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.onInk,
    required this.blue,
    required this.blue2,
    required this.blueSoft,
    required this.blueInk,
    required this.headA,
    required this.headB,
    required this.glass,
    required this.stripe,
    required this.shadow,
  });

  final bool dark;
  final Color bg, surface, surface2, line, ink, ink2, ink3, onInk;
  final Color blue, blue2, blueSoft, blueInk, headA, headB, glass, stripe;
  final List<BoxShadow> shadow;

  static const heart = Color(0xFFFF6F9C);
  static const gold = Color(0xFFFFD54A);
  static const danger = Color(0xFFFF8A8A);

  static const light = LL(
    dark: false,
    bg: Color(0xFFEEF2FB),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF4F6FC),
    line: Color(0x120E1220),
    ink: Color(0xFF0E1220),
    ink2: Color(0x9E0E1220),
    ink3: Color(0x610E1220),
    onInk: Color(0xFFFFFFFF),
    blue: Color(0xFF3D6BF5),
    blue2: Color(0xFF6A8EFF),
    blueSoft: Color(0xFFE3EAFF),
    blueInk: Color(0xFF2B4FD0),
    headA: Color(0xFFA9C0FF),
    headB: Color(0xFFDCE6FF),
    glass: Color(0xBDFFFFFF),
    stripe: Color(0x123D6BF5),
    shadow: [BoxShadow(color: Color(0x14283C8C), blurRadius: 30, offset: Offset(0, 10))],
  );

  static const darkTheme = LL(
    dark: true,
    bg: Color(0xFF04050A),
    surface: Color(0xFF0D1018),
    surface2: Color(0xFF141824),
    line: Color(0x12ECF0FF),
    ink: Color(0xFFF2F4FA),
    ink2: Color(0x99F2F4FA),
    ink3: Color(0x57F2F4FA),
    onInk: Color(0xFF090B12),
    blue: Color(0xFF4D7CFF),
    blue2: Color(0xFF7C9DFF),
    blueSoft: Color(0x264D7CFF),
    blueInk: Color(0xFFB6C8FF),
    headA: Color(0x574D7CFF),
    headB: Color(0xFF04050A),
    glass: Color(0xB812151E),
    stripe: Color(0x0D8CA5FF),
    shadow: [BoxShadow(color: Color(0x8C000000), blurRadius: 40, offset: Offset(0, 18))],
  );

  /// Shadow under blue buttons/tiles: 0 10px 24px rgba(61,107,245,.35)
  List<BoxShadow> blueGlow([double a = .35, double blur = 24, double y = 10]) =>
      [BoxShadow(color: const Color(0xFF3D6BF5).withValues(alpha: a), blurRadius: blur, offset: Offset(0, y))];

  /// color-mix(in srgb, var(--ink) p%, transparent)
  Color inkMix(double p) => ink.withValues(alpha: p);

  static LL of(BuildContext c) => Theme.of(c).extension<LL>()!;

  @override
  LL copyWith() => this;

  @override
  LL lerp(LL? other, double t) => t < .5 ? this : (other ?? this);
}

/// Motion curves from v7: --spring and --smooth.
class Motion {
  static const spring = Cubic(.34, 1.45, .64, 1);
  static const smooth = Cubic(.22, 1, .36, 1);
  static const fly = Cubic(.5, 0, .2, 1);
}

const kFont = 'Manrope';

TextStyle t(double size, FontWeight w, Color c, {double? ls, double? h}) =>
    TextStyle(fontFamily: kFont, fontSize: size, fontWeight: w, color: c, letterSpacing: ls == null ? null : ls * size, height: h);

ThemeData buildTheme(LL ll) => ThemeData(
      brightness: ll.dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: ll.bg,
      fontFamily: kFont,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(seedColor: ll.blue, brightness: ll.dark ? Brightness.dark : Brightness.light, surface: ll.surface),
      textSelectionTheme: TextSelectionThemeData(cursorColor: ll.blue),
      extensions: [ll],
    );
