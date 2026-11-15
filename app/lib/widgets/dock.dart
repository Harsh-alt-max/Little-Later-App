import 'dart:async';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'common.dart';
import 'icons.dart';

/// v7 floating capsule nav (.dock / .nav): 4 circles + the blue plus,
/// a sliding ink indicator and a label that pops above the active tab.
class Dock extends StatefulWidget {
  const Dock({super.key, required this.index, required this.onTab, required this.onPlus, this.plusOpen = false});
  final int index;
  final ValueChanged<int> onTab;
  final VoidCallback onPlus;
  final bool plusOpen;

  static const tabs = [('home', 'Today'), ('saved', 'Saved'), ('folder', 'Folders'), ('user', 'Profile')];

  @override
  State<Dock> createState() => _DockState();
}

class _DockState extends State<Dock> {
  bool _label = false;
  Timer? _t;

  // Geometry: padding 7, circles 52, gap 6, plus 60 with 2px side margins.
  static const _pad = 7.0, _nb = 52.0, _gap = 6.0, _plus = 64.0;
  static double _x(int i) => _pad + (i < 2 ? i * (_nb + _gap) : 2 * (_nb + _gap) + _plus + _gap + (i - 2) * (_nb + _gap));
  static double get _width => _x(3) + _nb + _pad;

  @override
  void didUpdateWidget(Dock old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      setState(() => _label = true);
      _t?.cancel();
      _t = Timer(const Duration(milliseconds: 1100), () {
        if (mounted) setState(() => _label = false);
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final inset = MediaQuery.paddingOf(context).bottom;
    final label = Dock.tabs[widget.index].$2;

    Widget nb(int i) {
      final on = i == widget.index;
      return Positioned(
        left: _x(i),
        top: _pad,
        child: Tap(
          scale: .88,
          onTap: () => widget.onTab(i),
          semanticLabel: Dock.tabs[i].$2,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _nb,
            height: _nb,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: on ? Colors.transparent : ll.inkMix(.05)),
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: on ? ll.onInk : ll.ink2),
              duration: const Duration(milliseconds: 300),
              builder: (_, c, _) => LLIcon(Dock.tabs[i].$1, color: c),
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: false,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
          // .dock::before fade
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 120 + inset,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0, .75], colors: [ll.bg.withValues(alpha: 0), ll.bg]),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: 18 + inset),
            child: SizedBox(
              width: _width,
              height: _nb + 2 * _pad,
              child: Stack(clipBehavior: Clip.none, children: [
                // glass capsule
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                      child: Container(
                        decoration: BoxDecoration(
                          color: ll.glass,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: ll.line),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), boxShadow: ll.shadow)))),
                // .nind
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 500),
                  curve: Motion.spring,
                  left: _x(widget.index),
                  top: _pad,
                  child: Container(width: _nb, height: _nb, decoration: BoxDecoration(shape: BoxShape.circle, color: ll.ink)),
                ),
                for (var i = 0; i < 4; i++) nb(i),
                // .nplus
                Positioned(
                  left: _pad + 2 * (_nb + _gap) + 2, // slot is 64 wide: 2px margin each side of the 60px button
                  top: _pad - 4,
                  child: Tap(
                    scale: .88,
                    onTap: widget.onPlus,
                    semanticLabel: 'Save a new idea',
                    child: Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: ll.blue, boxShadow: ll.blueGlow(.45)),
                      child: AnimatedRotation(
                        turns: widget.plusOpen ? 135 / 360 : 0,
                        duration: const Duration(milliseconds: 450),
                        curve: Motion.spring,
                        child: const LLIcon('plus', size: 26, color: Colors.white, stroke: 2.3),
                      ),
                    ),
                  ),
                ),
                // .nlabel
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 500),
                  curve: Motion.spring,
                  left: _x(widget.index) + _nb / 2 - 40,
                  bottom: 72,
                  width: 80,
                  child: IgnorePointer(
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _label ? .6 : 0, // subtle: shows where you are without shouting
                        duration: const Duration(milliseconds: 200),
                        child: AnimatedSlide(
                          offset: _label ? Offset.zero : const Offset(0, .2),
                          duration: const Duration(milliseconds: 350),
                          curve: Motion.spring,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(color: ll.ink, borderRadius: BorderRadius.circular(99)),
                            child: Text(label, style: t(12.5, FontWeight.w800, ll.onInk)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
