// Gentle snow (Christmas) or confetti (New Year) at the top of Today.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

class FestiveFall extends StatefulWidget {
  const FestiveFall({super.key, this.confetti = false});
  final bool confetti;
  @override
  State<FestiveFall> createState() => _FestiveFallState();
}

class _FestiveFallState extends State<FestiveFall> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  final _r = math.Random(7);
  late final List<List<double>> _p = List.generate(34, (_) => [_r.nextDouble(), _r.nextDouble(), .4 + _r.nextDouble() * .8, _r.nextDouble(), _r.nextInt(5).toDouble()]);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _a,
          builder: (_, _) => CustomPaint(painter: _Fall(_p, _a.value, widget.confetti), size: Size.infinite),
        ),
      );
}

class _Fall extends CustomPainter {
  _Fall(this.p, this.t, this.confetti);
  final List<List<double>> p;
  final double t;
  final bool confetti;
  static const _cols = [Color(0xFFF5C451), Color(0xFFFF7FB0), Color(0xFF7ED492), Color(0xFF5FC8E8), Color(0xFFFF9F7E)];

  @override
  void paint(Canvas c, Size s) {
    for (final q in p) {
      final y = ((q[1] + t * q[2]) % 1.0) * s.height;
      final x = q[0] * s.width + math.sin((t * 2 * math.pi) + q[3] * 6) * 14;
      final fade = 1 - (y / s.height); // fade out towards the bottom
      if (confetti) {
        final paint = Paint()..color = _cols[q[4].toInt()].withValues(alpha: .85 * fade);
        c.save();
        c.translate(x, y);
        c.rotate(t * 8 + q[3] * 6);
        c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-3, -5, 6, 10), const Radius.circular(1.5)), paint);
        c.restore();
      } else {
        c.drawCircle(Offset(x, y), 1.6 + q[2] * 2, Paint()..color = Colors.white.withValues(alpha: .75 * fade));
      }
    }
  }

  @override
  bool shouldRepaint(_Fall o) => o.t != t;
}
