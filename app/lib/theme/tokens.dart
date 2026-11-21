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

  /// Daylight: warm paper, ink text, peach accent.
  static const light = LL(
    dark: false,
    bg: Color(0xFFF6F4F1),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEFECE7),
    line: Color(0x1217130F),
    ink: Color(0xFF17130F),
    ink2: Color(0x8017130F),
    ink3: Color(0x4D17130F),
    onInk: Color(0xFFFFFFFF),
    blue: Color(0xFFEE6F47),
    blue2: Color(0xFFF59274),
    blueSoft: Color(0x1FEE6F47),
    blueInk: Color(0xFFC9502A),
    headA: Color(0x1AF0764F),
    headB: Color(0xFFF6F4F1),
    glass: Color(0xDBFFFFFF),
    stripe: Color(0x0F16161A),
    shadow: [],
  );

  /// Midnight: near-black, warm ink, peach accent.
  static const darkTheme = LL(
    dark: true,
    bg: Color(0xFF0A0A0C),
    surface: Color(0xFF141418),
    surface2: Color(0xFF1A1A1F),
    line: Color(0x0FFFFFFF),
    ink: Color(0xFFF4F1EC),
    ink2: Color(0x6BF4F1EC),
    ink3: Color(0x3DF4F1EC),
    onInk: Color(0xFF0A0A0C),
    blue: Color(0xFFFF9F7E),
    blue2: Color(0xFFFFB59A),
    blueSoft: Color(0x24FF9F7E),
    blueInk: Color(0xFFFFB59A),
    headA: Color(0x1FFF9F7E),
    headB: Color(0xFF0A0A0C),
    glass: Color(0xC71A1A1F),
    stripe: Color(0x12FFFFFF),
    shadow: [],
  );

  /// Bottom sheets.
  Color get sheet => dark ? const Color(0xF0121216) : const Color(0xF7FAF8F5);
  /// Neutral tile behind icons, chips and segmented controls.
  Color get chip => stripe;
  /// Text on the accent colour.
  Color get onAccent => const Color(0xFF17130F);
  /// The streak flame.
  Color get ember => dark ? const Color(0xFFF08A55) : const Color(0xFFE0662D);

  /// Shadow under blue buttons/tiles: 0 10px 24px rgba(61,107,245,.35)
  /// Kept very soft on purpose: heavy glows look artificial.
  List<BoxShadow> blueGlow([double a = .35, double blur = 24, double y = 10]) => const [];

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

const kFont = 'Geist';
const kMono = 'GeistMono';

/// Geist in three weights: 400 reading, 500 buttons/labels, 600 titles.
TextStyle t(double size, FontWeight w, Color c, {double? ls, double? h}) => TextStyle(
      fontFamily: kFont,
      fontSize: size,
      fontWeight: w.value >= 600 ? FontWeight.w600 : w.value >= 500 ? FontWeight.w500 : FontWeight.w400,
      color: c,
      letterSpacing: ls == null ? null : ls * size,
      height: h,
    );

/// Tiny uppercase labels (TODAY · 7:30 PM).
TextStyle mono(Color c, {double size = 11}) => TextStyle(fontFamily: kMono, fontSize: size, fontWeight: FontWeight.w500, color: c, letterSpacing: .08 * size, height: 1.3);

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
