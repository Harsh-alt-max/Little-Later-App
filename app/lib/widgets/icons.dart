import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// Stroke icon sprite ported from v7 (`<symbol id="i-…">`). Drawn at 24x24, recoloured with [color].
const Map<String, String> kIconPaths = {
  'home': '<path d="M4 10.5 12 4l8 6.5V19a1.5 1.5 0 0 1-1.5 1.5H15v-5.5H9v5.5H5.5A1.5 1.5 0 0 1 4 19z"/>',
  'saved': '<path d="M7 4h10a1 1 0 0 1 1 1v15l-6-4-6 4V5a1 1 0 0 1 1-1z"/>',
  'folder': '<path d="M3.5 7a1.5 1.5 0 0 1 1.5-1.5h4.4l2 2.2H19a1.5 1.5 0 0 1 1.5 1.5v8.3A1.5 1.5 0 0 1 19 19H5a1.5 1.5 0 0 1-1.5-1.5z"/>',
  'user': '<circle cx="12" cy="8.5" r="3.6"/><path d="M5 20c1.2-3.4 3.9-5 7-5s5.8 1.6 7 5"/>',
  'plus': '<path d="M12 5v14M5 12h14"/>',
  'x': '<path d="M6 6l12 12M18 6 6 18"/>',
  'bell': '<path d="M6.5 16.5V11a5.5 5.5 0 0 1 11 0v5.5l1.5 1.5H5z"/><path d="M10 20.5a2.2 2.2 0 0 0 4 0"/>',
  'search': '<circle cx="11" cy="11" r="6.5"/><path d="m20 20-4.2-4.2"/>',
  'sliders': '<path d="M7 4v6M7 14v6M17 4v3M17 11v9M4 10h6M14 7h6"/>',
  'link': '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3A4 4 0 0 0 11 18.7l1-1"/>',
  'check': '<path d="m5.5 12.5 4 4 9-9"/>',
  'snooze': '<circle cx="12" cy="13" r="7"/><path d="M12 9.5V13l2.2 1.4M5 4.5 3 6.5M19 4.5l2 2"/>',
  'arrow': '<path d="M7 17 17 7M9 7h8v8"/>',
  'right': '<path d="M5 12h14M13 6l6 6-6 6"/>',
  'bag': '<rect x="3.5" y="7.5" width="17" height="12" rx="2.5"/><path d="M9 7.5V6a1.5 1.5 0 0 1 1.5-1.5h3A1.5 1.5 0 0 1 15 6v1.5M3.5 12.5h17"/>',
  'heart': '<path d="M12 19.5s-7.5-4.4-7.5-10A4.2 4.2 0 0 1 12 7a4.2 4.2 0 0 1 7.5 2.5c0 5.6-7.5 10-7.5 10z"/>',
  'spark': '<path d="M12 3.5c.6 4.3 2.2 5.9 6.5 6.5-4.3.6-5.9 2.2-6.5 6.5-.6-4.3-2.2-5.9-6.5-6.5 4.3-.6 5.9-2.2 6.5-6.5z"/>',
  'moon': '<path d="M19.5 14.5A8 8 0 0 1 9.5 4.5a8 8 0 1 0 10 10z"/>',
  'sunrise': '<path d="M5 17a7 7 0 0 1 14 0M3 20.5h18M12 3.5v4M8.5 6 12 3.5 15.5 6"/>',
  'clock': '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
  'sun': '<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M4.6 4.6 6 6M18 18l1.4 1.4M2.5 12h2M19.5 12h2M4.6 19.4 6 18M18 6l1.4-1.4"/>',
  'users': '<circle cx="9" cy="8.5" r="3.3"/><path d="M3 19c.9-3 3.2-4.5 6-4.5s5.1 1.5 6 4.5M15.5 5.6a3.2 3.2 0 0 1 0 5.8M17.5 14.8c1.7.6 2.9 2 3.5 4.2"/>',
  'book': '<path d="M4.5 5.5a2 2 0 0 1 2-2h12v15h-12a2 2 0 0 0-2 2zM4.5 20.5a2 2 0 0 1 2-2h12v2.5"/>',
  'music': '<path d="M9 18V5.5l11-2V16"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="17.5" cy="16" r="2.5"/>',
  'cup': '<path d="M5 8.5h11v6a5 5 0 0 1-5 5h-1a5 5 0 0 1-5-5zM16 10h1.5a2.5 2.5 0 0 1 0 5H16M8 3.5v2M11 3.5v2"/>',
  'pen': '<path d="M4 20h4L19 9a2.8 2.8 0 0 0-4-4L4 16z"/>',
  'plane': '<path d="M10.5 13.5 3 11l1.5-1.5 8 .5 4-4.5a2.1 2.1 0 0 1 3 3L15 12.5l.5 8L14 22l-2.5-7.5-3 2.5v2.5L7 21l-1.5-3.5L2 16l1.5-1.5H6z"/>',
  'chev': '<path d="m9.5 6 6 6-6 6"/>',
  'back': '<path d="M19 12H5M11 6l-6 6 6 6"/>',
  'dots': '<circle cx="6" cy="12" r="1.3"/><circle cx="12" cy="12" r="1.3"/><circle cx="18" cy="12" r="1.3"/>',
  'trash': '<path d="M4.5 7h15M9.5 7V5h5v2M6.5 7l1 12.5h9l1-12.5"/>',
  'snow': '<path d="M12 3v18M4.2 7.5l15.6 9M4.2 16.5l15.6-9M9.5 4.5 12 7l2.5-2.5M9.5 19.5 12 17l2.5 2.5"/>',
  'sync': '<path d="M19.5 12a7.5 7.5 0 0 1-13 5.1M4.5 12a7.5 7.5 0 0 1 13-5.1M17.5 3.5v3.4h-3.4M6.5 20.5v-3.4h3.4"/>',
  'mail': '<rect x="3.5" y="5.5" width="17" height="13" rx="3"/><path d="m4.5 7.5 7.5 5.5 7.5-5.5"/>',
  'lock': '<rect x="5" y="10.5" width="14" height="10" rx="3"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5"/>',
  'off': '<path d="M6.5 16.5V11a5.5 5.5 0 0 1 8.2-4.8M17.5 11v5.5l1.5 1.5H8M3.5 3.5l17 17"/>',
};

/// Folder icon keys a user can pick (v7 ICONS).
const kFolderIcons = ['folder', 'bag', 'heart', 'spark', 'plane', 'book', 'music', 'cup'];

class LLIcon extends StatelessWidget {
  const LLIcon(this.name, {super.key, this.size = 22, this.color, this.stroke = 1.9});
  final String name;
  final double size;
  final Color? color;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color ?? const Color(0xFF000000);
    final body = kIconPaths[name] ?? kIconPaths['folder']!;
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round">$body</svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
    );
  }
}

/// Filled streak flame with the blue "flameG" gradient (v7 #i-flamef).
class FlameIcon extends StatelessWidget {
  const FlameIcon({super.key, this.size = 22, this.cold = false, this.coldColor = const Color(0x57F2F4FA)});
  final double size;
  final bool cold;
  final Color coldColor;

  static const _d = 'M12 22c-4 0-7-2.7-7-6.4 0-3.9 3.4-5.7 4.1-10.1 2.7 1.7 3.9 3.9 3.9 6.3 1.1-.7 1.8-1.8 2-3.2 2.1 1.8 3.7 4.1 3.7 7C18.7 19.3 16 22 12 22z';

  @override
  Widget build(BuildContext context) {
    if (cold) {
      return SvgPicture.string(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="$_d" fill="none" stroke="#000" stroke-width="1.8" stroke-linejoin="round"/></svg>',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(coldColor, BlendMode.srcIn),
      );
    }
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><defs><linearGradient id="g" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#3D6BF5"/><stop offset=".6" stop-color="#6E92FF"/><stop offset="1" stop-color="#C3D3FF"/></linearGradient></defs><path d="$_d" fill="url(#g)"/></svg>',
      width: size,
      height: size,
    );
  }
}

/// Solid heart (for hearts currency).
class HeartFill extends StatelessWidget {
  const HeartFill({super.key, this.size = 20, this.color = const Color(0xFFFF6F9C)});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SvgPicture.string(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 19.5s-7.5-4.4-7.5-10A4.2 4.2 0 0 1 12 7a4.2 4.2 0 0 1 7.5 2.5c0 5.6-7.5 10-7.5 10z" fill="#000"/></svg>',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}
