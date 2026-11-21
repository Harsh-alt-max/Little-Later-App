// Bottom dock: a glass bar with 4 tabs, the + button, and the mic above it.
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'kit.dart';

class Dock2 extends StatelessWidget {
  const Dock2({super.key, required this.index, required this.onTab, required this.onPlus, required this.onMic, this.plusOpen = false});
  final int index;
  final ValueChanged<int> onTab;
  final VoidCallback onPlus, onMic;
  final bool plusOpen;

  static const tabs = [('home', 'Today'), ('saved', 'Saved'), ('folder', 'Folders'), ('user', 'Profile')];

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final inset = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 130 + inset,
          child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0, .7], colors: [ll.bg.withValues(alpha: 0), ll.bg])))),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 22 + inset),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            // Mic: tap and speak.
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 12),
              child: Tap(
                onTap: onMic,
                semanticLabel: 'Speak a reminder',
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: ll.glass, border: Border.all(color: ll.line)),
                      alignment: Alignment.center,
                      child: LLIcon('mic', size: 20, color: ll.ink),
                    ),
                  ),
                ),
              ),
            ),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      height: 64,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: ll.glass, borderRadius: BorderRadius.circular(99), border: Border.all(color: ll.line)),
                      child: LayoutBuilder(builder: (context, c) {
                        final w = c.maxWidth / 4;
                        return Stack(children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 450),
                            curve: Motion.spring,
                            left: w * index + (w - 52) / 2,
                            top: 0,
                            child: Container(width: 52, height: 52, decoration: BoxDecoration(shape: BoxShape.circle, color: ll.ink)),
                          ),
                          Row(children: [
                            for (var i = 0; i < 4; i++)
                              Expanded(
                                child: Tap(
                                  scale: .88,
                                  onTap: () => onTab(i),
                                  semanticLabel: tabs[i].$2,
                                  child: SizedBox(
                                    height: 52,
                                    child: Center(
                                      child: TweenAnimationBuilder<Color?>(
                                        tween: ColorTween(end: i == index ? ll.onInk : ll.ink2),
                                        duration: const Duration(milliseconds: 250),
                                        builder: (_, col, _) => LLIcon(tabs[i].$1, size: 21, color: col),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ]),
                        ]);
                      }),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Tap(
                scale: .88,
                onTap: onPlus,
                semanticLabel: 'Save something',
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: ll.blue),
                  child: AnimatedRotation(turns: plusOpen ? 135 / 360 : 0, duration: const Duration(milliseconds: 450), curve: Motion.spring, child: LLIcon('plus', size: 26, color: ll.onAccent, stroke: 2.4)),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
