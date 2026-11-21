import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_svg/flutter_svg.dart';

import 'package:material_ui/material_ui.dart';

import '../mascot/mascot_svg.dart';
import '../services/haptics.dart';
import 'common.dart';

/// Pull-to-refresh where Lil peeks over the top edge of the page.
/// Pull down: the page follows your finger and Lil rises from behind it.
/// Hold past the line: Lil blinks every second for as long as you hold.
/// Let go: the page springs straight back up and the refresh runs quietly.
class EyesRefresh extends StatefulWidget {
  const EyesRefresh({super.key, required this.child, required this.onRefresh});
  final Widget child;
  final Future<void> Function() onRefresh;

  @override
  State<EyesRefresh> createState() => _EyesRefreshState();
}

class _EyesRefreshState extends State<EyesRefresh> with TickerProviderStateMixin {
  static const _trigger = 118.0, _max = 190.0;

  final _pull = ValueNotifier<double>(0); // how far the page is pulled down
  double _lookX = 0; // -1..1, where the finger is
  bool _armed = false, _down = false;
  int _blinks = 0;
  Timer? _blinkTimer;
  late final AnimationController _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  late final AnimationController _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _back.addListener(() => _pull.value = _from * (1 - Curves.easeOutCubic.transform(_back.value)));
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _back.dispose();
    _blink.dispose();
    _pull.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (!_down || n.metrics.axis != Axis.vertical || n.depth != 0) return false;
    final w = context.size?.width ?? 400;
    final p = _pull.value;
    if (n is OverscrollNotification && n.overscroll < 0 && n.metrics.extentBefore == 0) {
      _back.stop();
      // Rubber band: harder to pull the further it goes.
      final add = -n.overscroll * (1 - p / (_max * 1.15));
      if (n.dragDetails != null) _lookX = ((n.dragDetails!.globalPosition.dx / w) * 2 - 1).clamp(-1.0, 1.0);
      _pull.value = (p + add).clamp(0, _max);
      _arm();
    } else if (n is ScrollUpdateNotification && p > 0 && (n.scrollDelta ?? 0) > 0) {
      // Pushing back up while pulled: shrink the pull before the list scrolls.
      _pull.value = math.max(0, p - n.scrollDelta!);
      _arm();
    }
    return false;
  }

  void _arm() {
    final armed = _pull.value >= _trigger;
    if (armed == _armed) return;
    _armed = armed;
    _blinkTimer?.cancel();
    if (armed) {
      Haptics.tick();
      _blinks = 0;
      _blinkOnce();
      // Keep blinking every second while held (sometimes a double blink).
      _blinkTimer = Timer.periodic(const Duration(seconds: 1), (_) => _blinkOnce());
    }
  }

  Future<void> _blinkOnce() async {
    if (!mounted) return;
    _blinks++;
    await _blink.forward(from: 0);
    if (mounted && _blinks.isEven && _armed) {
      await Future<void>.delayed(const Duration(milliseconds: 90));
      if (mounted && _armed) await _blink.forward(from: 0);
    }
  }

  /// Finger lifted: go back up right away. Refresh runs in the background.
  void _release() {
    _down = false;
    _blinkTimer?.cancel();
    final refresh = _armed;
    _armed = false;
    if (_pull.value > 0) {
      _from = _pull.value;
      _back.forward(from: 0);
    }
    if (refresh) {
      Haptics.light();
      unawaited(widget.onRefresh().catchError((_) {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.child);
    return Listener(
      onPointerDown: (_) {
        _down = true;
        _back.stop();
      },
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: ValueListenableBuilder<double>(
        valueListenable: _pull,
        child: page,
        builder: (context, pull, page) => Stack(children: [
          // Lil lives in the gap above the page: ears, hair and eyes peek over its top edge.
          if (pull > 0)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: pull,
              child: ClipRect(child: AnimatedBuilder(animation: _blink, builder: (context, _) => _peek(context, pull))),
            ),
          Transform.translate(offset: Offset(0, pull), child: page),
        ]),
      ),
    );
  }

  // The mascot pictures are made once, not on every frame.
  String? _key;
  Widget? _open, _shut;

  Widget _peek(BuildContext context, double pull) {
    final st = AppScope.of(context).store;
    // Same size every time: about 130 px from ear tips to just under the eyes.
    const visH = 130.0;
    const k = visH / 118;
    const cropV = 142.0; // just below the eyes, in the mascot's own units
    final shown = (pull * .95).clamp(0.0, visH);
    final cropY = pull + (visH - shown);
    final shut = _blinkAmount(_blink.value) > .5;
    final key = '${st.outfitNow}';
    if (key != _key) {
      _key = key;
      _open = SvgPicture.string(mascotSvg(outfit: st.outfitNow), fit: BoxFit.contain, allowDrawingOutsideViewBox: true);
      _shut = SvgPicture.string(mascotSvg(outfit: st.outfitNow, blink: true), fit: BoxFit.contain, allowDrawingOutsideViewBox: true);
    }
    const w = 212 * k, h = 212 * k;
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
          alignment: Alignment(0, (cropV / 106) - 1),
          // Both pictures stay loaded, so blinking never flickers.
          child: IndexedStack(index: shut ? 1 : 0, sizing: StackFit.expand, children: [_open!, _shut!]),
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
