import 'dart:math' as math;

/// Dart port of v7's `mascot(cfg)` SVG builder.
/// CSS-driven states (mood, blink, cover paws) are resolved here by emitting
/// only the visible parts, because flutter_svg has no CSS.

enum Mood { idle, happy, sleep, wow }

enum MascotStyle { girl, teen, man }

String _star(double cx, double cy, double rr, double r) {
  final p = <String>[];
  for (var i = 0; i < 10; i++) {
    final a = -math.pi / 2 + i * math.pi / 5;
    final q = i.isOdd ? r : rr;
    p.add('${(cx + q * math.cos(a)).toStringAsFixed(1)},${(cy + q * math.sin(a)).toStringAsFixed(1)}');
  }
  return p.join(' ');
}

String _shirt(String c) => '<path d="M58 138 Q100 122 142 138 Q149 172 138 197 L62 197 Q51 172 58 138Z" fill="$c"/>';

final Map<MascotStyle, List<String>> _body = {
  MascotStyle.girl: [
    '',
    '<path d="M60 136 Q100 123 140 136 Q147 170 136 196 L64 196 Q53 170 60 136Z" fill="#FFC9DC"/><path d="M100 128V196" stroke="#F29BBD" stroke-width="3"/><circle cx="107" cy="150" r="2.6" fill="#F29BBD"/><circle cx="107" cy="166" r="2.6" fill="#F29BBD"/><circle cx="107" cy="182" r="2.6" fill="#F29BBD"/><path d="M66 150q5 3 10 0M66 162q5 3 10 0M124 150q5 3 10 0M124 162q5 3 10 0" stroke="#F4AECA" stroke-width="2" fill="none"/>',
    '<path d="M66 133 Q100 122 134 133 L153 198 Q100 211 47 198Z" fill="#6E56F7"/><path d="M47 198 Q100 211 153 198" stroke="#A996FF" stroke-width="4" fill="none"/><polygon points="${_star(80, 178, 4, 1.7)}" fill="#fff"/><polygon points="${_star(120, 188, 3.5, 1.5)}" fill="#fff"/><polygon points="${_star(108, 160, 3, 1.3)}" fill="#FFE68A"/>',
  ],
  MascotStyle.teen: [
    '',
    '${_shirt('#2E3352')}<rect x="76" y="174" width="48" height="16" rx="6" fill="#252A45"/><path d="M92 134v18M108 134v18" stroke="#E9ECFF" stroke-width="2.5" stroke-linecap="round"/>',
    '${_shirt('#EEF2FF')}<rect x="82" y="162" width="36" height="20" rx="6" fill="#4C6FFF"/><circle cx="91" cy="172" r="3" fill="#FFD54A"/><circle cx="100" cy="172" r="3" fill="#FF6A8A"/><circle cx="109" cy="172" r="3" fill="#41D9A0"/><path d="M58 150H142" stroke="#C9D3FF" stroke-width="3"/>',
  ],
  MascotStyle.man: [
    '',
    '${_shirt('#C8414F')}<path d="M57 154H143M55 174H145M78 130V197M122 130V197" stroke="#8E2733" stroke-width="4" opacity=".5"/><path d="M84 131 L100 146 L116 131 L110 129 L100 138 L90 129Z" fill="#E86A77"/>',
    '${_shirt('#1B1F35')}<path d="M88 131 L100 170 L112 131Z" fill="#F4F6FF"/><path d="M86 131 L98 166 L78 148Z M114 131 L102 166 L122 148Z" fill="#2B3152"/><path d="M88 136 L100 141 L88 146Z M112 136 L100 141 L112 146Z" fill="#FF5C7A"/><circle cx="100" cy="141" r="3" fill="#E04563"/><path d="M122 154h10l-2 6h-8z" fill="#FF5C7A"/>',
  ],
};

const Map<MascotStyle, String> _hair = {
  MascotStyle.girl:
      '<g><ellipse cx="55" cy="42" rx="13" ry="9" transform="rotate(-32 55 42)" fill="#FF7FAE"/><ellipse cx="76" cy="33" rx="13" ry="9" transform="rotate(18 76 33)" fill="#FF7FAE"/><circle cx="65.5" cy="38" r="6" fill="#FF5C97"/></g>',
  MascotStyle.teen:
      '<path d="M46 70 Q48 30 100 28 Q152 30 154 70 Q100 54 46 70Z" fill="#2B3566"/><path d="M100 29 V60" stroke="#3B4784" stroke-width="3"/><path d="M122 60 Q162 52 180 66 Q152 74 124 70Z" fill="#1E2550"/><circle cx="100" cy="30" r="4.5" fill="#3D4A8A"/>',
  MascotStyle.man: '<path d="M68 48 Q74 20 104 22 Q134 20 138 46 Q120 33 100 40 Q82 34 68 48Z" fill="#2A3A9E"/>',
};

const _tuft =
    '<path d="M101 42 C96 28 100 17 110 12 C111 23 108 33 106 42 Z" fill="#4C6FFF"/><path d="M98 44 C90 34 82 31 75 33 C82 37 89 42 95 47 Z" fill="#6684FF"/>';

const _ear =
    '<path d="M48 84 C36 52 42 28 56 24 C68 21 82 40 90 56 Z" fill="url(#b)"/><path d="M56 66 C52 50 55 40 60 38 C66 40 73 49 77 57 Z" fill="#A9BCFF" opacity=".45"/>';

const _mug =
    '<rect x="86" y="142" width="28" height="28" rx="6" fill="#F4F6FF"/><path d="M114 148q10 0 10 8t-10 8" stroke="#F4F6FF" stroke-width="4" fill="none"/><rect x="86" y="142" width="28" height="7" rx="3" fill="#6B4A3A"/><path d="M93 136q3-5 0-9M101 136q3-5 0-9" stroke="#fff" stroke-opacity=".6" stroke-width="2" fill="none" stroke-linecap="round"/>';

String _headX(MascotStyle s, int of) {
  switch (s) {
    case MascotStyle.girl:
      return of == 2
          ? '<path d="M82 46 L87 31 L94 41 L100 27 L106 41 L113 31 L118 46 Q100 50 82 46Z" fill="url(#s)" stroke="#E7A200" stroke-width="2" stroke-linejoin="round"/>'
          : '';
    case MascotStyle.teen:
      if (of == 1) {
        return '<path d="M44 94 Q42 24 100 22 Q158 24 156 94" fill="none" stroke="#1C1F33" stroke-width="7" stroke-linecap="round"/><rect x="33" y="82" width="21" height="33" rx="9" fill="#FF6A8A"/><rect x="146" y="82" width="21" height="33" rx="9" fill="#FF6A8A"/>';
      }
      if (of == 2) {
        return '<circle cx="100" cy="90" r="76" fill="#BED7FF" fill-opacity=".13" stroke="#E9EEFF" stroke-width="4"/><path d="M48 62 Q58 34 86 24" stroke="#fff" stroke-width="5" stroke-opacity=".5" fill="none" stroke-linecap="round"/>';
      }
      return '';
    case MascotStyle.man:
      return '';
  }
}

/// Build the mascot SVG.
/// [stage] 1..5 grows the body. [blink] squashes the open eyes. [cover] shows paws over eyes.
String mascotSvg({
  int stage = 1,
  MascotStyle style = MascotStyle.girl,
  int outfit = 0,
  Mood mood = Mood.idle,
  bool blink = false,
  bool cover = false,
  String zzColor = '#8A90A8',
}) {
  final lv = stage.clamp(1, 5);
  const rr = 19.0;
  final sc = const [.74, .8, .87, .93, 1.0][lv - 1];
  final isGirl = style == MascotStyle.girl;
  final lash = isGirl
      ? '<path d="M68.5 93 l-6 -4 M68 99 l-7 0 M131.5 93 l6 -4 M132 99 l7 0" stroke="#0B0E22" stroke-width="2.6" stroke-linecap="round"/>'
      : '';
  final glass = style == MascotStyle.man
      ? '<g fill="#FFFFFF" fill-opacity=".12" stroke="#0B0E22" stroke-width="3"><rect x="63" y="85" width="34" height="29" rx="12"/><rect x="103" y="85" width="34" height="29" rx="12"/></g><path d="M97 97 Q100 94 103 97" stroke="#0B0E22" stroke-width="3" fill="none"/>'
      : '';
  final held = style == MascotStyle.man && outfit == 1
      ? _mug
      : '<polygon points="${_star(100, 156, rr, rr * .5)}" fill="url(#s)" stroke="#EBA700" stroke-width="3" stroke-linejoin="round"/>';

  // Eyes per mood.
  final open = '<g${cover ? ' opacity="0"' : ''}>'
      '<ellipse cx="80" cy="100" rx="11.5" ry="14" fill="url(#e)"/><ellipse cx="120" cy="100" rx="11.5" ry="14" fill="url(#e)"/>'
      '<circle cx="84.5" cy="94" r="4.6" fill="#fff"/><circle cx="76.5" cy="105.5" r="2" fill="#fff" fill-opacity=".9"/>'
      '<circle cx="124.5" cy="94" r="4.6" fill="#fff"/><circle cx="116.5" cy="105.5" r="2" fill="#fff" fill-opacity=".9"/></g>$lash';
  const happy =
      '<g stroke="#0B0E22" stroke-width="5" fill="none" stroke-linecap="round"><path d="M69 103 Q80 89 91 103"/><path d="M109 103 Q120 89 131 103"/></g>';
  const closed =
      '<g stroke="#0B0E22" stroke-width="4.5" fill="none" stroke-linecap="round"><path d="M69 101 Q80 108 91 101"/><path d="M109 101 Q120 108 131 101"/></g>';
  String eyes;
  switch (mood) {
    case Mood.happy:
      eyes = happy;
    case Mood.sleep:
      eyes = closed;
    case Mood.idle:
    case Mood.wow:
      eyes = open;
  }
  if (blink && (mood == Mood.idle || mood == Mood.wow)) {
    eyes = '<g transform="translate(0 100) scale(1 .1) translate(0 -100)">$eyes</g>';
  }
  final brow = mood == Mood.wow
      ? '<g stroke="#0B0E22" stroke-width="3.5" stroke-linecap="round" fill="none"><path d="M70 80 Q79 74 88 79"/><path d="M112 79 Q121 74 130 80"/></g>'
      : '';
  final mouth = mood == Mood.wow
      ? '<ellipse cx="100" cy="118" rx="4.5" ry="5.5" fill="#0B0E22"/>'
      : '<path d="M95 115 Q100 120 105 115" stroke="#0B0E22" stroke-width="3.2" fill="none" stroke-linecap="round"/>';
  final zz = mood == Mood.sleep
      ? '<g font-family="Manrope" font-weight="800" fill="$zzColor"><text x="150" y="50" font-size="16">z</text><text x="162" y="36" font-size="12">z</text></g>'
      : '';
  final paws = cover
      ? '<g><ellipse cx="79" cy="100" rx="20" ry="16" fill="#5576FF"/><ellipse cx="121" cy="100" rx="20" ry="16" fill="#5576FF"/><path d="M66 92v6M73 89v7M80 89v7M120 89v7M127 89v7M134 92v6" stroke="#3D58E6" stroke-width="2" stroke-linecap="round"/></g>'
      : '';
  final blush = isGirl ? .75 : .5;
  final twinkles = lv >= 5
      ? '<g><polygon points="${_star(64, 200, 6, 2.4)}" fill="#7C9DFF"/><polygon points="${_star(140, 192, 5, 2)}" fill="#A9BCFF"/><polygon points="${_star(150, 120, 4, 1.6)}" fill="#7C9DFF"/></g>'
      : '';
  final halo = lv >= 3 ? '<circle cx="100" cy="156" r="34" fill="url(#h)"/>' : '';
  // Levels 4–5 float above a smaller shadow.
  final floatY = lv >= 4 ? -8 : 0;
  final shadow = lv >= 4
      ? '<ellipse cx="100" cy="207" rx="27" ry="4" fill="#1a2350" opacity=".11"/>'
      : '<ellipse cx="100" cy="207" rx="42" ry="6" fill="#1a2350" opacity=".22"/>';

  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 220"><defs>'
      '<radialGradient id="b" cx="34%" cy="22%" r="85%"><stop offset="0" stop-color="#8EA8FF"/><stop offset=".45" stop-color="#4C6FFF"/><stop offset="1" stop-color="#2236C9"/></radialGradient>'
      '<radialGradient id="f" cx="45%" cy="30%" r="75%"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#DCE4FF"/></radialGradient>'
      '<radialGradient id="e" cx="40%" cy="30%" r="80%"><stop offset="0" stop-color="#2B3366"/><stop offset="1" stop-color="#070915"/></radialGradient>'
      '<radialGradient id="s" cx="40%" cy="30%" r="80%"><stop offset="0" stop-color="#FFE68A"/><stop offset="1" stop-color="#FFB400"/></radialGradient>'
      '<radialGradient id="h"><stop offset="0" stop-color="#FFD54A" stop-opacity=".55"/><stop offset="1" stop-color="#FFD54A" stop-opacity="0"/></radialGradient></defs>'
      '<g transform="translate(100 207) scale($sc) translate(-100 -207)">'
      '$shadow'
      '<g transform="translate(0 $floatY)">'
      '$twinkles'
      '<ellipse cx="80" cy="195" rx="15" ry="9" fill="#2A40D6"/><ellipse cx="120" cy="195" rx="15" ry="9" fill="#2A40D6"/>'
      '<ellipse cx="100" cy="158" rx="42" ry="38" fill="url(#b)"/>'
      '${_body[style]![outfit.clamp(0, 2)]}'
      '<g>'
      '<g>$_ear</g><g transform="translate(200 0) scale(-1 1)">$_ear</g>'
      '${isGirl ? _tuft : ''}'
      '<ellipse cx="100" cy="92" rx="64" ry="54" fill="url(#b)"/>'
      '<ellipse cx="78" cy="56" rx="22" ry="9" fill="#fff" opacity=".16" transform="rotate(-18 78 56)"/>'
      '${_hair[style]}'
      '<ellipse cx="100" cy="102" rx="47" ry="36" fill="url(#f)"/>'
      '$brow$eyes$glass'
      '<ellipse cx="64" cy="114" rx="7" ry="4" fill="#FF9DBB" opacity="$blush"/><ellipse cx="136" cy="114" rx="7" ry="4" fill="#FF9DBB" opacity="$blush"/>'
      '$mouth$paws${_headX(style, outfit.clamp(0, 2))}'
      '</g>'
      '$halo'
      '<g>$held</g>'
      '<ellipse cx="75" cy="159" rx="11" ry="9" fill="#5576FF" transform="rotate(-25 75 159)"/><ellipse cx="125" cy="159" rx="11" ry="9" fill="#5576FF" transform="rotate(25 125 159)"/>'
      '$zz'
      '</g></g></svg>';
}

/// The star that flies into the mascot.
const kStarSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-12 -12 24 24"><polygon points="0.0,-11.0 2.9,-4.0 10.5,-3.4 4.8,1.5 6.5,8.9 0.0,5.0 -6.5,8.9 -4.8,1.5 -10.5,-3.4 -2.9,-4.0" fill="#FFD54A" stroke="#EBA700" stroke-width="2" stroke-linejoin="round"/></svg>';
