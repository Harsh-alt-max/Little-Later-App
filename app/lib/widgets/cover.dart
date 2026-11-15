import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Cover image for a saved link (video thumbnail / og:image), with a calm
/// letter placeholder while loading or when the site gives none.
class Cover extends StatelessWidget {
  const Cover({super.key, required this.url, required this.letter, this.width, this.height, this.radius = 16, this.aspect});
  final String url, letter;
  final double? width, height, aspect;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final ph = Container(
      color: ll.surface2,
      alignment: Alignment.center,
      child: Text(letter.isEmpty ? '•' : letter.replaceFirst(RegExp(r'^www\.'), '')[0].toUpperCase(), style: t(18, FontWeight.w800, ll.ink3)),
    );
    final usable = url.startsWith('http');
    Widget img = usable
        ? Image.network(
            url,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: 720,
            errorBuilder: (_, _, _) => ph,
            frameBuilder: (_, child, frame, sync) => sync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 300), child: frame == null ? ph : child),
          )
        : ph;
    img = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: width, height: height, child: img),
    );
    return aspect != null ? AspectRatio(aspectRatio: aspect!, child: img) : img;
  }
}
