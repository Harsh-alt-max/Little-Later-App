import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'mascot_svg.dart';

/// One-shot body animations from v7 (.squish, .hop, .nod, .catch, .wave, .twitch).
enum MascotAct { squish, hop, nod, catchStar, wave }

/// Drives one mascot: mood, base mood, one-shot acts. Mirrors v7's `class M`.
class MascotController extends ChangeNotifier {
  MascotController({Mood base = Mood.idle}) : _base = base, _mood = base;

  Mood _base;
  Mood _mood;
  Timer? _moodTimer;
  final _acts = StreamController<MascotAct>.broadcast();

  Mood get current => _mood;
  Stream<MascotAct> get acts => _acts.stream;

  void setBase(Mood m) {
    _base = m;
    _moodTimer?.cancel();
    _set(m);
  }

  void mood(Mood m, [Duration? d]) {
    _moodTimer?.cancel();
    _set(m);
    if (d != null) _moodTimer = Timer(d, () => _set(_base));
  }

  void play(MascotAct a) => _acts.add(a);

  void _set(Mood m) {
    if (_mood == m) return;
    _mood = m;
    notifyListeners();
  }

  @override
  void dispose() {
    _moodTimer?.cancel();
    _acts.close();
    super.dispose();
  }
}

/// Renders the mascot with idle bob + blink and plays acts on demand.
class MascotView extends StatefulWidget {
  const MascotView({
    super.key,
    required this.stage,
    this.controller,
    this.style = MascotStyle.girl,
    this.outfit = 0,
    this.live = true,
    this.cover = false,
    this.staticMood = Mood.idle,
  });

  final int stage;
  final MascotController? controller;
  final MascotStyle style;
  final int outfit;
  final bool live;
  final bool cover;
  final Mood staticMood;

  @override
  State<MascotView> createState() => _MascotViewState();
}

class _MascotViewState extends State<MascotView> with TickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
  late final AnimationController _act = AnimationController(vsync: this);
  MascotAct? _current;
  StreamSubscription<MascotAct>? _sub;
  Timer? _blinkTimer;
  bool _blink = false;
  final _rand = math.Random();

  @override
  void initState() {
    super.initState();
    _attach();
    if (widget.live) {
      _bob.repeat();
      _scheduleBlink();
    }
  }

  void _attach() {
    widget.controller?.addListener(_onCtl);
    _sub = widget.controller?.acts.listen(_play);
  }

  void _detach() {
    widget.controller?.removeListener(_onCtl);
    _sub?.cancel();
  }

  @override
  void didUpdateWidget(MascotView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _detach();
      _attach();
    }
  }

  void _onCtl() => setState(() {});

  void _scheduleBlink() {
    _blinkTimer = Timer(Duration(milliseconds: 2400 + _rand.nextInt(2800)), () {
      if (!mounted) return;
      final m = widget.controller?.current ?? widget.staticMood;
      if (m == Mood.idle) {
        setState(() => _blink = true);
        Timer(const Duration(milliseconds: 120), () {
          if (mounted) setState(() => _blink = false);
        });
      }
      _scheduleBlink();
    });
  }

  void _play(MascotAct a) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    _current = a;
    _act.duration = Duration(milliseconds: switch (a) {
      MascotAct.squish => 550,
      MascotAct.hop => 750,
      MascotAct.nod => 600,
      MascotAct.catchStar => 600,
      MascotAct.wave => 1000,
    });
    _act.forward(from: 0);
  }

  @override
  void dispose() {
    _detach();
    _blinkTimer?.cancel();
    _bob.dispose();
    _act.dispose();
    super.dispose();
  }

  // Keyframe helpers ---------------------------------------------------------
  static double _kf(double t, List<(double, double)> pts, [Curve c = Curves.easeInOut]) {
    for (var i = 1; i < pts.length; i++) {
      if (t <= pts[i].$1) {
        final a = pts[i - 1], b = pts[i];
        final k = ((t - a.$1) / (b.$1 - a.$1)).clamp(0.0, 1.0);
        return a.$2 + (b.$2 - a.$2) * c.transform(k);
      }
    }
    return pts.last.$2;
  }

  Matrix4 _actMatrix(double t, Size s) {
    final ox = s.width / 2, oy = s.height * 205 / 220; // transform-origin 100px 205px
    double sx = 1, sy = 1, ty = 0, rot = 0;
    switch (_current) {
      case MascotAct.squish:
        sx = _kf(t, [(0, 1), (.3, 1.08), (.6, .96), (1, 1)]);
        sy = _kf(t, [(0, 1), (.3, .9), (.6, 1.05), (1, 1)]);
      case MascotAct.hop:
        sx = _kf(t, [(0, 1), (.15, 1.08), (.45, .96), (.78, 1.05), (1, 1)]);
        sy = _kf(t, [(0, 1), (.15, .9), (.45, 1.05), (.78, .95), (1, 1)]);
        ty = _kf(t, [(0, 0), (.15, 0), (.45, -26), (.78, 0), (1, 0)]) * s.height / 220;
      case MascotAct.nod:
        ty = _kf(t, [(0, 0), (.35, 5), (1, 0)]) * s.height / 220;
        rot = _kf(t, [(0, 0), (.35, 2), (1, 0)]);
      case MascotAct.wave:
        rot = _kf(t, [(0, 0), (.15, -8), (.35, 7), (.55, -5), (.75, 3), (1, 0)]);
        ty = _kf(t, [(0, 0), (.35, -8), (.55, 0), (1, 0)]) * s.height / 220;
      case MascotAct.catchStar:
        // star-only in CSS; approximate with a tiny body pop
        sx = sy = _kf(t, [(0, 1), (.4, 1.04), (1, 1)]);
      case null:
        break;
    }
    return Matrix4.identity()
      ..translateByDouble(ox, oy + ty, 0, 1)
      ..rotateZ(rot * math.pi / 180)
      ..scaleByDouble(sx, sy, 1, 1)
      ..translateByDouble(-ox, -oy, 0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final mood = widget.controller?.current ?? widget.staticMood;
    final svg = mascotSvg(
      stage: widget.stage,
      style: widget.style,
      outfit: widget.outfit,
      mood: mood,
      blink: _blink,
      cover: widget.cover,
      zzColor: '#${(ll.ink3.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
    );
    final pic = SvgPicture.string(svg, fit: BoxFit.contain, allowDrawingOutsideViewBox: true);
    final floaty = widget.stage >= 4;
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return AnimatedBuilder(
        animation: Listenable.merge([_bob, _act]),
        builder: (context, child) {
          // .bob: translateY(-3px) scale(1.01,.99) at 50%; levels 4–5 float a further -7px
          final bs = (1 - math.cos(_bob.value * 2 * math.pi)) / 2;
          final bobY = -(floaty ? 7.0 : 3.0) * bs;
          final sq = floaty ? 0.0 : .01 * bs;
          final m = Matrix4.identity()
            ..translateByDouble(size.width / 2, size.height * 205 / 220 + bobY * size.height / 220, 0, 1)
            ..scaleByDouble(1 + sq, 1 - sq, 1, 1)
            ..translateByDouble(-size.width / 2, -size.height * 205 / 220, 0, 1);
          return Transform(transform: m, child: Transform(transform: _actMatrix(_act.value, size), child: child));
        },
        child: pic,
      );
    });
  }
}
