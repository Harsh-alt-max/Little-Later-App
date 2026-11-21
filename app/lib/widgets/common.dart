import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../services/auth.dart';
import '../services/reminders.dart';
import '../services/sync.dart';
import '../mascot/mascot_svg.dart';
import '../mascot/mascot_view.dart';
import '../theme/tokens.dart';
import 'icons.dart';
import '../services/haptics.dart';

// ---------------------------------------------------------------------------
// App scope: shared services every screen reaches for.

class ToastController extends ChangeNotifier {
  String? message;
  VoidCallback? undo;
  int _gen = 0;
  Timer? _t;

  void show(String msg, {VoidCallback? undo}) {
    message = msg;
    this.undo = undo;
    _gen++;
    final g = _gen;
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 3600), () {
      if (g == _gen) hide();
    });
    notifyListeners();
  }

  void hide() {
    message = null;
    undo = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }
}

/// App-wide actions the shell provides to every screen.
abstract class AppActions {
  void openSave({String url = '', String folder = ''});
  void openQuickSave(String url);
  void openLil({bool streak = false});
  void openReminder(Item item);
  void openFolder(Folder f);
  void openNotes();

  /// Add stars; handles the mascot reaction and level-up screen.
  void gain(int n, {String? line});
  AuthService get auth;
  SyncService get sync;
  Reminders get reminders;
  Future<void> signOut({bool delete = false});
  void startSignIn();

  /// Pull-to-refresh: sync, reload, reschedule reminders, fetch missing covers.
  Future<void> refresh();
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required super.child, required this.store, required this.toast, required this.hero, required this.heroKey, required this.goTab, required this.levelUp, required this.app});

  final AppStore store;
  final ToastController toast;
  final MascotController hero;
  final GlobalKey heroKey;
  final void Function(int tab) goTab;
  final void Function(Level from, Level to) levelUp;
  final AppActions app;

  /// Re-provide this scope below a new route (sheets, pushed screens).
  Widget wrap(Widget child) => AppScope(store: store, toast: toast, hero: hero, heroKey: heroKey, goTab: goTab, levelUp: levelUp, app: app, child: child);

  static AppScope of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AppScope>()!;

  void buzz([int strength = 1]) {
    Haptics.enabled = store.haptics;
    switch (strength) {
      case 0:
        Haptics.tick();
      case 1:
        Haptics.light();
      default:
        Haptics.medium();
    }
  }

  @override
  bool updateShouldNotify(AppScope old) => false;
}

// ---------------------------------------------------------------------------
// Formatting (v7 fmtT / fmtDay)

const _dow = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtT(DateTime d) {
  final h = d.hour, m = d.minute;
  return '${h % 12 == 0 ? 12 : h % 12}:${m.toString().padLeft(2, '0')} ${h < 12 ? 'am' : 'pm'}';
}

String fmtDay(DateTime d) {
  final n = AppStore.now();
  final today = DateTime(n.year, n.month, n.day);
  final dd = DateTime(d.year, d.month, d.day);
  final diff = dd.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff > 6 || diff < -6) return '${_dow[d.weekday - 1]} ${d.day} ${_mon[d.month - 1]}';
  return '${_dow[d.weekday - 1]} ${d.day}';
}

String shortText(String s, [int n = 22]) => s.length > n ? '${s.substring(0, n - 2)}…' : s;

// ---------------------------------------------------------------------------
// .tap: spring scale on press

class Tap extends StatefulWidget {
  const Tap({super.key, required this.child, this.onTap, this.scale = .94, this.semanticLabel});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final String? semanticLabel;

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final w = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 100 : 400),
        curve: _down ? Curves.easeOut : Motion.spring,
        child: widget.child,
      ),
    );
    return widget.semanticLabel == null ? w : Semantics(button: true, label: widget.semanticLabel, child: w);
  }
}

/// .circ: 46px round surface button.
class Circ extends StatelessWidget {
  const Circ({super.key, required this.icon, this.onTap, this.size = 46, this.iconSize = 22, this.bg, this.fg, this.shadow = true, this.dot = false, this.label});
  final String icon;
  final VoidCallback? onTap;
  final double size, iconSize;
  final Color? bg, fg;
  final bool shadow, dot;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Tap(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: bg ?? (ll.dark ? ll.surface2 : ll.surface), boxShadow: shadow ? ll.shadow : null),
        child: Stack(
          alignment: Alignment.center,
          children: [
            LLIcon(icon, size: iconSize, color: fg ?? ll.ink),
            if (dot)
              Positioned(
                top: 11,
                right: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ll.blue,
                    border: Border.all(color: bg ?? (ll.dark ? ll.surface2 : ll.surface), width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Speech bubble (.bubble)

class BubbleController extends ChangeNotifier {
  String text = '';
  bool on = false;
  Timer? _t;

  void say(String s, [int ms = 2200]) {
    text = s;
    on = false;
    notifyListeners();
    // re-trigger the pop like v7 (remove/reflow/add)
    scheduleMicrotask(() {
      on = true;
      notifyListeners();
    });
    _t?.cancel();
    if (ms > 0) {
      _t = Timer(Duration(milliseconds: ms), () {
        on = false;
        notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }
}

class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.controller, this.tailLeft = false, this.maxWidth = 200, this.wrap = false});
  final BubbleController controller;
  final bool tailLeft, wrap;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => IgnorePointer(
        child: AnimatedOpacity(
          opacity: controller.on ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedScale(
            scale: controller.on ? 1 : .4,
            alignment: tailLeft ? Alignment.bottomLeft : Alignment.bottomRight,
            duration: const Duration(milliseconds: 450),
            curve: Motion.spring,
            child: AnimatedRotation(
              turns: controller.on ? 0 : -6 / 360,
              alignment: tailLeft ? Alignment.bottomLeft : Alignment.bottomRight,
              duration: const Duration(milliseconds: 450),
              curve: Motion.spring,
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: ll.ink,
                  borderRadius: tailLeft
                      ? const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4))
                      : const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(4)),
                ),
                child: Text(controller.text, softWrap: wrap, maxLines: wrap ? 3 : 1, overflow: TextOverflow.visible, style: t(13.5, FontWeight.w800, ll.onInk, h: 1.3)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toast (.toast)

class ToastView extends StatelessWidget {
  const ToastView({super.key, required this.controller, required this.onUndo});
  final ToastController controller;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final on = controller.message != null;
        return Positioned(
          left: 20,
          right: 20,
          top: MediaQuery.paddingOf(context).top + 8,
          child: IgnorePointer(
            ignoring: !on,
            child: AnimatedSlide(
              offset: on ? Offset.zero : const Offset(0, -.6),
              duration: const Duration(milliseconds: 450),
              curve: Motion.spring,
              child: AnimatedOpacity(
                opacity: on ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 350),
                    padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
                    decoration: BoxDecoration(color: ll.ink, borderRadius: BorderRadius.circular(99)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(controller.message ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: t(14, FontWeight.w700, ll.onInk)),
                          ),
                        ),
                        if (controller.undo != null)
                          Tap(
                            onTap: onUndo,
                            child: Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: ll.onInk.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
                              child: Text('Undo', style: t(13.5, FontWeight.w800, ll.onInk)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Reward FX: star flies into the mascot, then sparks (v7 flyTo + sparks)

void flyStarToMascot(BuildContext context, {required Offset from, required GlobalKey target, required VoidCallback onDone}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final box = target.currentContext?.findRenderObject() as RenderBox?;
  if (box == null || (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
    onDone();
    return;
  }
  final tl = box.localToGlobal(Offset.zero);
  final to = Offset(tl.dx + box.size.width / 2, tl.dy + box.size.height * .71);
  final blue = LL.of(context).blue;
  late OverlayEntry e;
  e = OverlayEntry(
    builder: (_) => _FlyStar(
      from: from,
      to: to,
      onDone: () {
        e.remove();
        spawnSparks(overlay, to, 7, blue);
        onDone();
      },
    ),
  );
  overlay.insert(e);
}

void spawnSparks(OverlayState overlay, Offset at, int n, Color color) {
  late OverlayEntry e;
  e = OverlayEntry(
    builder: (_) => _Sparks(at: at, n: n, color: color, onDone: () => e.remove()),
  );
  overlay.insert(e);
}

class _FlyStar extends StatefulWidget {
  const _FlyStar({required this.from, required this.to, required this.onDone});
  final Offset from, to;
  final VoidCallback onDone;
  @override
  State<_FlyStar> createState() => _FlyStarState();
}

class _FlyStarState extends State<_FlyStar> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.from, e = widget.to;
    final mid = Offset((s.dx + e.dx) / 2 - 50, math.min(s.dy, e.dy) - 60);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          final k = Motion.fly.transform(c.value);
          Offset p;
          double sc, rot;
          if (k < .55) {
            final u = k / .55;
            p = Offset.lerp(s, mid, u)!;
            sc = .3 + (1.3 - .3) * u;
            rot = 160 * u;
          } else {
            final u = (k - .55) / .45;
            p = Offset.lerp(mid, e, u)!;
            sc = 1.3 + (.8 - 1.3) * u;
            rot = 160 + 160 * u;
          }
          return Stack(
            children: [
              Positioned(
                left: p.dx - 12,
                top: p.dy - 12,
                child: Transform.rotate(
                  angle: rot * math.pi / 180,
                  child: Transform.scale(scale: sc, child: SvgPicture.string(kStarSvg, width: 24, height: 24)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Sparks extends StatefulWidget {
  const _Sparks({required this.at, required this.n, required this.color, required this.onDone});
  final Offset at;
  final int n;
  final Color color;
  final VoidCallback onDone;
  @override
  State<_Sparks> createState() => _SparksState();
}

class _SparksState extends State<_Sparks> with SingleTickerProviderStateMixin {
  final _r = math.Random();
  late final List<(double, double, double)> parts = List.generate(widget.n, (_) => (_r.nextDouble() * math.pi * 2, 22 + _r.nextDouble() * 30, .7 + _r.nextDouble() * .3));
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 950))..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: c,
      builder: (context, _) => Stack(
        children: [
          for (final p in parts)
            Builder(
              builder: (_) {
                final k = (c.value / p.$3).clamp(0.0, 1.0);
                final e = const Cubic(.2, .8, .3, 1).transform(k);
                final pos = widget.at + Offset(math.cos(p.$1), math.sin(p.$1)) * p.$2 * e;
                return Positioned(
                  left: pos.dx - 3.5,
                  top: pos.dy - 3.5,
                  child: Opacity(
                    opacity: 1 - k,
                    child: Transform.scale(
                      scale: 1 - k,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.color,
                          boxShadow: [BoxShadow(color: widget.color.withValues(alpha: .6), blurRadius: 8, spreadRadius: 1)],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}

/// A one-shot "bump" (scale 1.18 at 40%, spring) driven by a counter.
class Bump extends StatefulWidget {
  const Bump({super.key, required this.trigger, required this.child, this.peak = 1.18});
  final int trigger;
  final Widget child;
  final double peak;
  @override
  State<Bump> createState() => _BumpState();
}

class _BumpState extends State<Bump> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600), value: 1);
  @override
  void didUpdateWidget(Bump old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) c.forward(from: 0);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (_, child) {
      final v = c.value;
      final s = v < .4 ? 1 + (widget.peak - 1) * Curves.easeOut.transform(v / .4) : widget.peak - (widget.peak - 1) * Motion.spring.transform((v - .4) / .6);
      return Transform.scale(scale: s, child: child);
    },
    child: widget.child,
  );
}

/// Pulsing ring (v7 .tapme ping / .sc.cold ring).
class Ping extends StatefulWidget {
  const Ping({super.key, required this.color, this.size = 10});
  final Color color;
  final double size;
  @override
  State<Ping> createState() => _PingState();
}

class _PingState extends State<Ping> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (_, _) {
      final k = (c.value / .7).clamp(0.0, 1.0);
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: .6 * (1 - k)),
              spreadRadius: 10 * k,
            ),
          ],
        ),
      );
    },
  );
}
