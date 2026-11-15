import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_svg/flutter_svg.dart';

import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:material_ui/material_ui.dart';

import '../mascot/mascot_svg.dart';
import '../services/haptics.dart';
import 'common.dart';

/// Pull-to-refresh where Lil's big eyes peek over the top edge of the page.
/// Pull down: the page slides down and the eyes rise, following your finger.
/// Let go past the line: the eyes blink once (~0.5 s) while we refresh, then
/// the page springs back up.
class EyesRefresh extends StatefulWidget {
  const EyesRefresh({super.key, required this.child, required this.onRefresh});
  final Widget child;
  final Future<void> Function() onRefresh;

  @override
  State<EyesRefresh> createState() => _EyesRefreshState();
}

class _EyesRefreshState extends State<EyesRefresh> with TickerProviderStateMixin {
  static const _trigger = 118.0, _max = 190.0, _hold = 150.0;

  double _pull = 0; // how far the page is pulled down
  double _lookX = 0; // -1..1, where the finger is
  bool _armed = false, _busy = false;
  late final AnimationController _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final AnimationController _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  double _from = 0, _to = 0;

  @override
  void initState() {
    super.initState();
    _back.addListener(() => setState(() => _pull = _from + (_to - _from) * Curves.easeOutBack.transform(_back.value).clamp(-.2, 1.2)));
  }

  @override
  void dispose() {
    _back.dispose();
    _blink.dispose();
    super.dispose();
  }

  void _animateTo(double v, {Duration? d}) {
    _from = _pull;
    _to = v;
    _back.duration = d ?? const Duration(milliseconds: 420);
    _back.forward(from: 0);
  }

  bool _onScroll(ScrollNotification n) {
    if (_busy || n.metrics.axis != Axis.vertical || n.depth != 0) return false;
    final w = context.size?.width ?? 400;
    if (n is OverscrollNotification && n.overscroll < 0 && n.dragDetails != null && n.metrics.extentBefore == 0) {
      _back.stop();
      // Rubber band: harder to pull the further it goes.
      final add = -n.overscroll * (1 - _pull / (_max * 1.15));
      setState(() {
        _pull = (_pull + add).clamp(0, _max);
        _lookX = ((n.dragDetails!.globalPosition.dx / w) * 2 - 1).clamp(-1.0, 1.0);
      });
      _arm();
    } else if (n is ScrollUpdateNotification && _pull > 0 && n.dragDetails != null && (n.scrollDelta ?? 0) > 0) {
      // Pushing back up while pulled: shrink the pull before the list scrolls.
      setState(() {
        _pull = math.max(0, _pull - n.scrollDelta!);
        _lookX = ((n.dragDetails!.globalPosition.dx / w) * 2 - 1).clamp(-1.0, 1.0);
      });
      _arm();
    } else if (n is ScrollEndNotification || (n is UserScrollNotification && n.direction == ScrollDirection.idle)) {
      _release();
    }
    return false;
  }

  void _arm() {
    final armed = _pull >= _trigger;
    if (armed != _armed) {
      _armed = armed;
      if (armed) Haptics.tick();
    }
  }

  Future<void> _release() async {
    if (_busy || _pull <= 0 || _back.isAnimating) return;
    if (!_armed) {
      _animateTo(0);
      return;
    }
    _busy = true;
    _armed = false;
    Haptics.light();
    _animateTo(_hold, d: const Duration(milliseconds: 220));
    final work = widget.onRefresh().timeout(const Duration(seconds: 6), onTimeout: () {}).catchError((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    await _blink.forward(from: 0); // one blink, 0.5 s
    await work;
    if (!mounted) return;
    _animateTo(0, d: const Duration(milliseconds: 380));
    await Future<void>.delayed(const Duration(milliseconds: 380));
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // Lil lives in the gap above the page: ears, hair and eyes peek over its top edge.
      if (_pull > 0)
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: _pull,
          child: ClipRect(
            child: AnimatedBuilder(animation: _blink, builder: (context, _) => _peek(context)),
          ),
        ),
      Transform.translate(
        offset: Offset(0, _pull),
        child: NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.child),
      ),
    ]);
  }

  Widget _peek(BuildContext context) {
    final st = AppScope.of(context).store;
    final stage = st.level.n.clamp(1, 5);
    final sc = const [.74, .8, .87, .93, 1.0][stage - 1];
    // Same size on every level: about 130 px from ear tips to just under the eyes.
    const visH = 130.0;
    final k = visH / (103 * sc);
    final cropV = 207 - 92 * sc; // just below the eyes, in the mascot's own units
    final shown = (_pull * .95).clamp(0.0, visH);
    final cropY = _pull + (visH - shown);
    final shut = _blinkAmount(_blink.value) > .5;
    final svg = mascotSvg(stage: stage, style: st.mascotStyle, outfit: st.outfitNow, mood: Mood.wow, blink: shut);
    final w = 200 * k, h = 220 * k;
    final x = (MediaQuery.sizeOf(context).width - w) / 2;
    return Stack(clipBehavior: Clip.none, children: [
      Positioned(
        key: const Key('ll-peek'),
        left: x + _lookX * 8,
        top: cropY - cropV * k,
        width: w,
        height: h,
        // Leans towards your finger.
        child: Transform.rotate(
          angle: _lookX * .09,
          alignment: Alignment(0, (cropV / 110) - 1),
          child: SvgPicture.string(svg, fit: BoxFit.contain, allowDrawingOutsideViewBox: true),
        ),
      ),
    ]);
  }

  /// 0 = open, 1 = shut. Close fast, hold a beat, open a little slower.
  static double _blinkAmount(double t) {
    if (t <= 0 || t >= 1) return 0;
    if (t < .35) return Curves.easeIn.transform(t / .35);
    if (t < .5) return 1;
    return 1 - Curves.easeOut.transform((t - .5) / .5);
  }
}
