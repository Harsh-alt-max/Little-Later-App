// Lil: a soft peach creature with ears. Ported from the Midnight prototype.
//
// One body for everyone; outfits are accessories. [MascotStyle] is kept so old
// saved data still loads, but every style draws the same Lil.

enum Mood { idle, happy, sleep, wow, listen }

enum MascotStyle { girl, teen, man }

/// Outfit names and heart costs (index 0 is free).
const kLilOutfits = ['Everyday', 'Cozy scarf', 'Headphones', 'Star crown'];
const kLilOutfitCost = [0, 5, 10, 18];

const _lilA = '#FFCDB8', _lilB = '#EE7E5E', _ear = '#F59274', _ink = '#0B0E22';

/// Festival hats, drawn over everything else.
String hatSvg(String hat) {
  if (hat == 'santa') {
    return '<path d="M62 52 C66 20 96 6 124 14 C140 18 152 30 156 46 L150 50 C146 36 136 28 124 26 C112 32 106 46 104 56 Z" fill="#D9363E"/>'
        '<path d="M56 50 Q100 34 146 50 L148 62 Q100 46 54 62 Z" fill="#FFFFFF"/>'
        '<circle cx="154" cy="50" r="10" fill="#FFFFFF"/>';
  }
  if (hat == 'party') {
    return '<path d="M80 48 L100 0 L120 48 Z" fill="#F5C451"/><path d="M86 34 L114 34 L117 41 L83 41 Z" fill="#FF7FB0"/><path d="M93 18 L107 18 L109 24 L91 24 Z" fill="#7E8CFF"/>'
        '<circle cx="100" cy="0" r="7" fill="#FF9F7E"/><circle cx="40" cy="30" r="4" fill="#7ED492"/><circle cx="168" cy="26" r="4" fill="#FF7FB0"/><circle cx="160" cy="62" r="3" fill="#F5C451"/><circle cx="34" cy="70" r="3" fill="#5FC8E8"/>';
  }
  return '';
}

String outfitSvg(int n, {String accent = '#FF9F7E'}) {
  switch (n) {
    case 1:
      return '<path d="M33 144 q67 28 134 0 v19 q-67 28 -134 0z" fill="#E4573D"/><path d="M38 152 q62 25 124 0" stroke="#FFD9C9" stroke-width="3" fill="none" stroke-opacity=".55" stroke-dasharray="10 8"/><path d="M121 167 l15 -2 l7 30 l-16 4z" fill="#C9432C"/>';
    case 2:
      return '<path d="M34 96 C34 12 166 12 166 96" fill="none" stroke="#26262E" stroke-width="11" stroke-linecap="round"/><rect x="16" y="80" width="28" height="50" rx="13" fill="#26262E"/><rect x="156" y="80" width="28" height="50" rx="13" fill="#26262E"/><rect x="23" y="89" width="9" height="32" rx="4.5" fill="$accent"/><rect x="168" y="89" width="9" height="32" rx="4.5" fill="$accent"/>';
    case 3:
      return '<path d="M72 48 L77 16 L91 32 L100 8 L109 32 L123 16 L128 48 Z" fill="#FFC94A" stroke="#E0A526" stroke-width="2.5" stroke-linejoin="round"/><circle cx="100" cy="38" r="4.5" fill="#E4573D"/><circle cx="83" cy="41" r="3" fill="#fff" fill-opacity=".8"/><circle cx="117" cy="41" r="3" fill="#fff" fill-opacity=".8"/>';
  }
  return '';
}

/// Build Lil's SVG. [stage] 1..5 grows the body (Tiny → Mega).
String mascotSvg({
  int stage = 3,
  MascotStyle style = MascotStyle.girl,
  int outfit = 0,
  Mood mood = Mood.idle,
  bool blink = false,
  bool cover = false,
  String zzColor = '#8A90A8',
  String accent = '#FF9F7E',
  bool scaleByStage = false,
  String hat = '',
}) {
  final ear = 'fill="$_ear"';
  final String ears;
  switch (mood) {
    case Mood.listen:
      ears = '<ellipse cx="50" cy="40" rx="23" ry="36" transform="rotate(-34 50 40)" $ear/><ellipse cx="150" cy="40" rx="23" ry="36" transform="rotate(34 150 40)" $ear/>'
          '<g fill="none" stroke="$accent" stroke-width="5" stroke-linecap="round"><path d="M16 34 q-9 15 0 30"/><path d="M4 24 q-15 25 0 50" stroke-opacity=".55"/><path d="M184 34 q9 15 0 30"/><path d="M196 24 q15 25 0 50" stroke-opacity=".55"/></g>';
    case Mood.happy:
    case Mood.wow:
      ears = '<ellipse cx="58" cy="46" rx="17" ry="24" transform="rotate(-30 58 46)" $ear/><ellipse cx="142" cy="46" rx="17" ry="24" transform="rotate(30 142 46)" $ear/>';
    case Mood.sleep:
      ears = '<ellipse cx="56" cy="58" rx="17" ry="24" transform="rotate(-50 56 58)" $ear/><ellipse cx="144" cy="58" rx="17" ry="24" transform="rotate(50 144 58)" $ear/>';
    case Mood.idle:
      ears = '<ellipse cx="62" cy="50" rx="17" ry="24" transform="rotate(-20 62 50)" $ear/><ellipse cx="138" cy="50" rx="17" ry="24" transform="rotate(20 138 50)" $ear/>';
  }
  const openEyes = '<ellipse cx="76" cy="108" rx="21" ry="27" fill="$_ink"/><ellipse cx="76" cy="123" rx="14" ry="11" fill="$_lilA"/><circle cx="69" cy="97" r="6.5" fill="#fff"/><circle cx="83" cy="112" r="2.4" fill="#fff"/>'
      '<ellipse cx="124" cy="108" rx="21" ry="27" fill="$_ink"/><ellipse cx="124" cy="123" rx="14" ry="11" fill="$_lilA"/><circle cx="117" cy="97" r="6.5" fill="#fff"/><circle cx="131" cy="112" r="2.4" fill="#fff"/>';
  const wowEyes = '<ellipse cx="76" cy="106" rx="23" ry="30" fill="$_ink"/><circle cx="68" cy="94" r="8" fill="#fff"/><circle cx="84" cy="114" r="3" fill="#fff"/>'
      '<ellipse cx="124" cy="106" rx="23" ry="30" fill="$_ink"/><circle cx="116" cy="94" r="8" fill="#fff"/><circle cx="132" cy="114" r="3" fill="#fff"/><ellipse cx="100" cy="146" rx="7" ry="8" fill="$_ink"/>';
  const happyEyes = '<path d="M58 112 q18 -24 36 0" fill="none" stroke="$_ink" stroke-width="9" stroke-linecap="round"/><path d="M106 112 q18 -24 36 0" fill="none" stroke="$_ink" stroke-width="9" stroke-linecap="round"/><path d="M90 138 q10 9 20 0" fill="none" stroke="$_ink" stroke-width="6" stroke-linecap="round"/>';
  const sleepEyes = '<path d="M58 112 q18 14 36 0" fill="none" stroke="$_ink" stroke-width="8" stroke-linecap="round"/><path d="M106 112 q18 14 36 0" fill="none" stroke="$_ink" stroke-width="8" stroke-linecap="round"/>';
  const blinkEyes = '<path d="M58 110 q18 6 36 0" fill="none" stroke="$_ink" stroke-width="8" stroke-linecap="round"/><path d="M106 110 q18 6 36 0" fill="none" stroke="$_ink" stroke-width="8" stroke-linecap="round"/>';
  final eyes = switch (mood) {
    Mood.happy => happyEyes,
    Mood.sleep => sleepEyes,
    Mood.wow => wowEyes,
    _ => blink ? blinkEyes : openEyes,
  };
  final zz = mood == Mood.sleep ? '<text x="162" y="40" font-size="26" font-weight="700" fill="$zzColor" font-family="sans-serif">z</text><text x="180" y="18" font-size="18" font-weight="700" fill="$zzColor" font-family="sans-serif">z</text>' : '';
  final paws = cover ? '<ellipse cx="74" cy="112" rx="30" ry="22" fill="$_ear"/><ellipse cx="126" cy="112" rx="30" ry="22" fill="$_ear"/>' : '';
  final sc = scaleByStage ? const [.7, .8, .9, 1.0, 1.1][stage.clamp(1, 5) - 1] : 1.0;
  final body = '$ears<rect x="28" y="40" width="144" height="146" rx="64" fill="url(#b)"/><rect x="28" y="40" width="144" height="146" rx="64" fill="url(#h)"/>$eyes$paws${outfitSvg(outfit, accent: accent)}${hatSvg(hat)}$zz';
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-6 -6 212 212">'
      '<defs><linearGradient id="b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="$_lilA"/><stop offset="1" stop-color="$_lilB"/></linearGradient>'
      '<radialGradient id="h" cx=".35" cy=".2" r=".5"><stop offset="0" stop-color="#fff" stop-opacity=".45"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient></defs>'
      '${sc == 1.0 ? body : '<g transform="translate(100 186) scale($sc) translate(-100 -186)">$body</g>'}</svg>';
}

/// App mark: Lil peeking over a line, on a light tile.
String markSvg({String fg = '#F08A6C', String bg = '#FFFFFF', String line = '#16161A'}) {
  String eye(double x, double y, double r) =>
      '<ellipse cx="$x" cy="$y" rx="${6.2 * r}" ry="${8 * r}" fill="$_ink"/><ellipse cx="$x" cy="${y + 4.4 * r}" rx="${4 * r}" ry="${3 * r}" fill="$_lilA"/><circle cx="${x - 1.8 * r}" cy="${y - 2.8 * r}" r="${2 * r}" fill="#fff"/>';
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><clipPath id="c"><rect width="100" height="100" rx="26"/></clipPath><g clip-path="url(#c)"><rect width="100" height="100" fill="$bg"/>'
      '<ellipse cx="36" cy="42" rx="6" ry="9.5" transform="rotate(-24 36 42)" fill="$fg"/><ellipse cx="64" cy="42" rx="6" ry="9.5" transform="rotate(24 64 42)" fill="$fg"/>'
      '<path d="M23 78V61a27 27 0 0 1 54 0v17z" fill="$fg"/>${eye(41.5, 61, 1.05)}${eye(58.5, 61, 1.05)}'
      '<rect x="0" y="71.5" width="100" height="30" fill="$bg"/><rect x="13" y="70" width="74" height="3.6" rx="1.8" fill="$line"/></g></svg>';
}

const kStarSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-12 -12 24 24"><polygon points="0.0,-11.0 2.9,-4.0 10.5,-3.4 4.8,1.5 6.5,8.9 0.0,5.0 -6.5,8.9 -4.8,1.5 -10.5,-3.4 -2.9,-4.0" fill="#FFD54A" stroke="#EBA700" stroke-width="2" stroke-linejoin="round"/></svg>';
