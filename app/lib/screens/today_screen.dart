import 'package:flutter/services.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../mascot/mascot_svg.dart';
import '../mascot/mascot_view.dart';
import '../services/haptics.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/cover.dart';
import '../widgets/eyes_refresh.dart';
import '../widgets/icons.dart';
import 'save_sheet.dart';

/// v7 "Today" screen (#s-today).
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.scroll, required this.bubble});
  final ScrollController scroll;
  final BubbleController bubble;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

enum _Leave { done, later }

class _TodayScreenState extends State<TodayScreen> {
  final Map<String, _Leave> _leaving = {};
  String? _nextOut; // id of the Next-up card currently animating out
  int _ringBump = 0;
  int _streakPop = 0;
  bool _nextAnimIn = false;
  bool _greeted = false;
  final _flame = GlobalKey();

  AppScope get s => AppScope.of(context);
  AppStore get store => s.store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_greeted) {
      _greeted = true;
      Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        s.hero.play(MascotAct.hop);
        s.hero.mood(Mood.happy, const Duration(milliseconds: 1000));
        widget.bubble.say(store.hiToday ? 'Tap me for your streak' : 'Tap me to say hi and keep your flame', 2600);
      });
    }
  }

  // --------------------------------------------------------------------------
  // Actions (v7 doneNext / laterNext / bindRow / gain)

  void _gain(int n, String line) {
    final (a, b) = store.gainXp(n);
    s.hero.play(MascotAct.catchStar);
    s.hero.play(MascotAct.hop);
    s.hero.mood(Mood.happy, const Duration(milliseconds: 1300));
    if (b.n > a.n) {
      Timer(const Duration(milliseconds: 850), () => s.levelUp(a, b));
      return;
    }
    widget.bubble.say(store.todayQueue.isNotEmpty ? line : 'All done today!');
  }

  void _scrollTopThen(VoidCallback f) {
    final sc = widget.scroll;
    if (sc.hasClients && sc.offset > 60) {
      sc.animateTo(0, duration: const Duration(milliseconds: 380), curve: Motion.smooth);
      Timer(const Duration(milliseconds: 380), f);
    } else {
      f();
    }
  }

  /// Star flies into the mascot; +15 stars land on arrival. Returns a getter
  /// telling whether the stars have landed (so Undo can take them back).
  bool Function() _fly(Offset from, String line) {
    var landed = false;
    _scrollTopThen(() {
      if (!mounted) return;
      flyStarToMascot(
        context,
        from: from,
        target: s.heroKey,
        onDone: () {
          if (!mounted) return;
          landed = true;
          setState(() => _ringBump++);
          _gain(15, line);
        },
      );
    });
    return () => landed;
  }

  VoidCallback _undoDone(VoidCallback undo, bool Function() landed) => () {
    undo();
    if (landed()) store.gainXp(-15);
    setState(() {});
  };

  void _doneNext(Item it, Offset from) {
    s.buzz(2);
    setState(() => _nextOut = it.id);
    final landed = _fly(from, 'Nice, one more done!');
    Timer(const Duration(milliseconds: 430), () {
      if (!mounted) return;
      final undo = store.complete(it.id);
      setState(() {
        _nextOut = null;
        _nextAnimIn = true;
      });
      s.toast.show('“${shortText(it.title)}” revisited', undo: _undoDone(undo, landed));
    });
  }

  Future<bool> _laterNext(Item it) async {
    s.buzz(1);
    final d = await pickLater(context);
    if (d == null || !mounted) return false;
    setState(() => _nextOut = it.id);
    s.hero.mood(Mood.sleep, const Duration(milliseconds: 1400));
    widget.bubble.say('See you ${dayLow(d)}, ${fmtT(d)}.');
    final oldR = it.reminder, oldD = it.dueAt;
    Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      store.snoozeTo(it.id, d);
      setState(() {
        _nextOut = null;
        _nextAnimIn = true;
      });
      s.toast.show(
        'Moved to ${dayLow(d)}, ${fmtT(d)}',
        undo: () => setState(() {
          it.reminder = oldR;
          it.dueAt = oldD;
          store.touchItem(it);
        }),
      );
    });
    return true;
  }

  void _rowDone(Item it, Offset from) {
    s.buzz(2);
    setState(() => _leaving[it.id] = _Leave.done);
    final landed = _fly(from, 'Ooh, another star!');
    Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final undo = store.complete(it.id);
      setState(() => _leaving.remove(it.id));
      s.toast.show('“${shortText(it.title)}” revisited', undo: _undoDone(undo, landed));
    });
  }

  Future<bool> _rowLater(Item it) async {
    s.buzz(1);
    final d = await pickLater(context);
    if (d == null || !mounted) return false;
    s.hero.mood(Mood.sleep, const Duration(milliseconds: 1400));
    setState(() => _leaving[it.id] = _Leave.later);
    final oldR = it.reminder, oldD = it.dueAt;
    Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      store.snoozeTo(it.id, d);
      setState(() => _leaving.remove(it.id));
      s.toast.show(
        'Moved to ${dayLow(d)}, ${fmtT(d)}',
        undo: () => setState(() {
          it.reminder = oldR;
          it.dueAt = oldD;
          store.touchItem(it);
        }),
      );
    });
    return true;
  }

  Future<void> _open(Item it) async {
    s.buzz(0);
    widget.bubble.say('Enjoy! Tick it after.');
    final u = Uri.tryParse(it.url);
    if (u != null && u.hasScheme) {
      final ok = await launchUrl(u, mode: LaunchMode.externalApplication).catchError((_) => false);
      if (!ok) s.toast.show('Couldn’t open ${it.domain}');
    }
  }

  void _tapMascot() {
    final hi = store.sayHi();
    if (hi != null) {
      s.buzz(2);
      s.hero.play(MascotAct.wave);
      s.hero.mood(Mood.happy, const Duration(milliseconds: 1600));
      setState(() => _streakPop++);
      _floatPlusOne();
      widget.bubble.say(hi.line, 2800);
      return;
    }
    s.buzz(1);
    s.hero.play(MascotAct.squish);
    s.hero.mood(Mood.happy, const Duration(milliseconds: 800));
    Timer(const Duration(milliseconds: 180), () => s.app.openLil());
  }

  void _tapStreak() {
    if (!store.hiToday) {
      _tapMascot();
      return;
    }
    s.buzz(0);
    s.app.openLil(streak: true);
  }

  void _floatPlusOne() {
    final box = _flame.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final p = box.localToGlobal(Offset.zero);
    final overlay = Overlay.of(context, rootOverlay: true);
    final c = LL.of(context).blueInk;
    late OverlayEntry e;
    e = OverlayEntry(
      builder: (_) => _FloatUp(at: Offset(p.dx + box.size.width / 2 - 20, p.dy - 6), color: c, onDone: () => e.remove()),
    );
    overlay.insert(e);
  }

  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final queue = store.todayQueue;
        final next = queue.isEmpty ? null : queue.first;
        final rest = queue.skip(1).toList();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) s.hero.setBase(queue.isEmpty ? Mood.happy : Mood.idle);
        });
        final bottom = MediaQuery.paddingOf(context).bottom;
        return EyesRefresh(
          onRefresh: s.app.refresh,
          child: SingleChildScrollView(
            controller: widget.scroll,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(bottom: 130 + bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  ring: _RingData(total: store.todayTotal, done: store.doneToday),
                  ringBump: _ringBump,
                  streakPop: _streakPop,
                  flameKey: _flame,
                  bubble: widget.bubble,
                  queueLen: queue.length,
                  onMascot: _tapMascot,
                  onStreak: _tapStreak,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 6),
                      _Sec(title: 'Next up', trailing: queue.isEmpty ? '' : '${queue.length} left'),
                      if (next != null)
                        _NextCard(
                          key: ValueKey(next.id),
                          item: next,
                          folder: _folderName(next),
                          out: _nextOut == next.id,
                          animateIn: _nextAnimIn,
                          onDone: (o) => _doneNext(next, o),
                          onLater: () => _laterNext(next),
                          onOpen: () => _open(next),
                        )
                      else
                        const _AllClear(),
                      if (rest.isNotEmpty) ...[
                        const _Sec(title: 'Later today', trailing: 'Swipe left for later'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(28), boxShadow: ll.shadow),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (var i = 0; i < rest.length; i++)
                                _LaterRow(
                                  key: ValueKey('row-${rest[i].id}'),
                                  item: rest[i],
                                  folder: _folderName(rest[i]),
                                  first: i == 0,
                                  leaving: _leaving[rest[i].id],
                                  onDone: (o) => _rowDone(rest[i], o),
                                  onLater: () => _rowLater(rest[i]),
                                  onSwipeArm: () => s.buzz(0),
                                ),
                            ],
                          ),
                        ),
                      ],
                      _Sec(
                        title: 'Folders',
                        trailingWidget: Tap(
                          onTap: () => s.goTab(2),
                          child: Text('See all', style: t(13.5, FontWeight.w700, ll.ink3)),
                        ),
                      ),
                      _FolderPills(
                        folders: store.folders,
                        count: store.folderCount,
                        onTap: (f) {
                          s.buzz(0);
                          s.app.openFolder(f);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _folderName(Item it) => store.folderNamed(it.folder)?.name ?? (it.folder.isEmpty ? 'Saved' : it.folder);
}

// ============================================================================
// Header panel (.head)

class _RingData {
  const _RingData({required this.total, required this.done});
  final int total, done;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.ring,
    required this.ringBump,
    required this.streakPop,
    required this.flameKey,
    required this.bubble,
    required this.queueLen,
    required this.onMascot,
    required this.onStreak,
  });

  final _RingData ring;
  final int ringBump, streakPop, queueLen;
  final GlobalKey flameKey;
  final BubbleController bubble;
  final VoidCallback onMascot, onStreak;

  String _greet() {
    final h = AppStore.now().hour;
    return h < 12
        ? 'Good\nmorning'
        : h < 17
        ? 'Good\nafternoon'
        : 'Good\nevening';
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final scope = AppScope.of(context);
    final store = scope.store;
    final top = MediaQuery.paddingOf(context).top;
    final status = queueLen > 0 ? '$queueLen idea${queueLen > 1 ? 's' : ''} want${queueLen > 1 ? '' : 's'} you back today.' : 'You’re all caught up.';
    final initial = store.userName.trim().isEmpty ? null : store.userName.trim()[0].toUpperCase();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(38)),
      child: CustomPaint(
        painter: _HeadPainter(ll),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 14 + top, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // .toprow
              Row(
                children: [
                  Tap(
                    onTap: () {
                      scope.buzz(0);
                      scope.goTab(3);
                    },
                    semanticLabel: 'Open profile',
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [ll.blue2, ll.blue]),
                        boxShadow: [BoxShadow(color: ll.surface, spreadRadius: 3)],
                      ),
                      child: initial != null ? Text(initial, style: t(17, FontWeight.w800, Colors.white)) : const LLIcon('user', size: 20, color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  _StreakChip(key: flameKey, streak: store.streak, cold: !store.hiToday, chest: store.heartsReady > 0, pop: streakPop, onTap: onStreak),
                  const SizedBox(width: 8),
                  Circ(
                    icon: 'bell',
                    label: 'Notifications',
                    dot: store.unreadNotes > 0 || store.todayQueue.any((i) => i.whenTs <= AppStore.now().millisecondsSinceEpoch),
                    onTap: () => scope.app.openNotes(),
                  ),
                ],
              ),
              // .herorow
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 46, bottom: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_greet(), style: t(32, FontWeight.w800, ll.ink, ls: -.03, h: 1.12)),
                            const SizedBox(height: 8),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: Text(status, key: ValueKey(status), style: t(15, FontWeight.w500, ll.ink2, h: 1.4)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(4, 0),
                      child: _MascotWrap(ring: ring, ringBump: ringBump, bubble: bubble, showTapMe: !store.hiToday, onTap: onMascot),
                    ),
                  ],
                ),
              ),
              // Save bar (replaces search; Saved has its own search)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Tap(
                  scale: .98,
                  onTap: () async {
                    scope.buzz(1);
                    final clip = await Clipboard.getData('text/plain');
                    final url = extractUrl(clip?.text ?? '') ?? '';
                    scope.app.openSave(url: url);
                  },
                  semanticLabel: 'Save a link',
                  child: Container(
                    height: 60,
                    padding: const EdgeInsets.fromLTRB(18, 0, 8, 0),
                    decoration: BoxDecoration(
                      color: ll.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: ll.line),
                    ),
                    child: Row(
                      children: [
                        LLIcon('link', color: ll.ink3),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Save a link or idea', style: t(15, FontWeight.w600, ll.ink3))),
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: ll.blue, borderRadius: BorderRadius.circular(15)),
                          child: const LLIcon('plus', size: 22, color: Colors.white, stroke: 2.3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header background: two layered gradients exactly as v7 (.head + dark override).
class _HeadPainter extends CustomPainter {
  _HeadPainter(this.ll);
  final LL ll;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    if (ll.dark) {
      // linear-gradient(180deg,#0A0D1A,transparent)
      canvas.drawRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0A0D1A), Color(0x000A0D1A)]).createShader(r));
      // radial-gradient(60% 70% at 76% 42%, head-a 0%, rgba(77,124,255,.08) 45%, transparent 72%)
      _ellipse(canvas, size, Offset(size.width * .76, size.height * .42), size.width * .6, size.height * .7, [ll.headA, const Color(0x0D4D7CFF), const Color(0x004D7CFF)], [0, .45, .72]);
    } else {
      canvas.drawRect(r, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [ll.headB, ll.bg]).createShader(r));
      _ellipse(canvas, size, Offset(size.width * .92, 0), size.width * 1.1, size.height * .8, [ll.headA, ll.headA.withValues(alpha: 0)], [0, .6]);
    }
  }

  static void _ellipse(Canvas c, Size s, Offset center, double rx, double ry, List<Color> colors, List<double> stops) {
    c.save();
    c.translate(center.dx, center.dy);
    c.scale(1, ry / rx);
    final rect = Rect.fromCircle(center: Offset.zero, radius: rx);
    c.drawRect(Rect.fromLTWH(-center.dx, -center.dy * rx / ry, s.width, s.height * rx / ry), Paint()..shader = RadialGradient(colors: colors, stops: stops).createShader(rect));
    c.restore();
  }

  @override
  bool shouldRepaint(_HeadPainter old) => old.ll != ll;
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({super.key, required this.streak, required this.cold, required this.chest, required this.pop, required this.onTap});
  final int streak, pop;
  final bool cold, chest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Tap(
      onTap: onTap,
      semanticLabel: 'Streak, $streak days',
      child: Bump(
        trigger: pop,
        peak: 1.25,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (cold) Positioned.fill(child: _ColdRing(color: ll.blue)),
            Container(
              height: 46,
              padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
              decoration: BoxDecoration(color: ll.dark ? ll.surface2 : ll.surface, borderRadius: BorderRadius.circular(99), boxShadow: ll.shadow),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FlameIcon(cold: cold, coldColor: ll.ink3),
                  const SizedBox(width: 6),
                  Text('$streak', style: t(15, FontWeight.w800, cold ? ll.ink3 : ll.ink)),
                ],
              ),
            ),
            if (chest)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: LL.heart,
                    border: Border.all(color: ll.bg, width: 2),
                  ),
                  child: const HeartFill(size: 10, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// .sc.cold::after — ring that expands and fades, every 2s.
class _ColdRing extends StatefulWidget {
  const _ColdRing({required this.color});
  final Color color;
  @override
  State<_ColdRing> createState() => _ColdRingState();
}

class _ColdRingState extends State<_ColdRing> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (_, _) => Transform.scale(
      scale: .96 + .22 * c.value,
      child: Opacity(
        opacity: .7 * (1 - c.value),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: widget.color, width: 2),
          ),
        ),
      ),
    ),
  );
}

/// .mwrap: mascot + progress ring + "n/total done" label + bubble + ping dot.
class _MascotWrap extends StatelessWidget {
  const _MascotWrap({required this.ring, required this.ringBump, required this.bubble, required this.showTapMe, required this.onTap});
  final _RingData ring;
  final int ringBump;
  final BubbleController bubble;
  final bool showTapMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final scope = AppScope.of(context);
    final store = scope.store;
    return Semantics(
      button: true,
      label: 'Your mascot, ${store.mascotName}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 150,
          height: 170,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -9,
                top: -7,
                width: 168,
                height: 168,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: ring.done.toDouble()),
                  duration: const Duration(milliseconds: 500),
                  builder: (_, v, _) => CustomPaint(
                    painter: _RingPainter(total: ring.total, done: ring.done, track: ll.inkMix(.12), on: ll.blue),
                  ),
                ),
              ),
              Positioned.fill(
                child: MascotView(key: scope.heroKey, stage: store.level.n, controller: scope.hero, style: store.mascotStyle, outfit: store.outfitNow),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 150,
                child: Center(
                  child: Bump(
                    trigger: ringBump,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(7, 5, 11, 5),
                      decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(99), boxShadow: ll.shadow),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: ll.blue),
                            child: const LLIcon('check', size: 10, color: Colors.white, stroke: 3.2),
                          ),
                          const SizedBox(width: 6),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: '${ring.done}', style: t(12.5, FontWeight.w800, ll.ink)),
                                TextSpan(text: '/${ring.total} done'),
                              ],
                            ),
                            style: t(12.5, FontWeight.w700, ll.ink2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (showTapMe) const Positioned(right: -2, top: 6, child: _TapMe()),
              Positioned(right: 104, top: -30, child: SpeechBubble(controller: bubble, wrap: true, maxWidth: 190)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TapMe extends StatelessWidget {
  const _TapMe();
  @override
  Widget build(BuildContext context) => Ping(color: LL.of(context).blue);
}

/// Segmented progress ring, one arc per idea due today (v7 ring()).
class _RingPainter extends CustomPainter {
  _RingPainter({required this.total, required this.done, required this.track, required this.on});
  final int total, done;
  final Color track, on;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final k = size.width / 150;
    canvas.save();
    canvas.scale(k);
    const r = 68.0, c = Offset(75, 75);
    final circ = 2 * math.pi * r;
    final gap = total > 1 ? 12.0 : 0.0;
    final seg = circ / total - gap;
    final rect = Rect.fromCircle(center: c, radius: r);
    for (var i = 0; i < total; i++) {
      final isDone = i < done;
      final start = -math.pi / 2 + (i * 2 * math.pi / total) + (gap / circ * math.pi);
      final sweep = seg / r;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..color = isDone ? on : track;
      canvas.drawArc(rect, start, total == 1 ? 2 * math.pi : sweep, false, p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.total != total || o.done != done || o.track != track || o.on != on;
}

class _FloatUp extends StatefulWidget {
  const _FloatUp({required this.at, required this.color, required this.onDone});
  final Offset at;
  final Color color;
  final VoidCallback onDone;
  @override
  State<_FloatUp> createState() => _FloatUpState();
}

class _FloatUpState extends State<_FloatUp> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward().whenComplete(widget.onDone);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: c,
      builder: (_, _) {
        final v = Motion.smooth.transform(c.value);
        final y = v < .2 ? 6 - 12 * (v / .2) : -6 - 38 * ((v - .2) / .8);
        final o = v < .2 ? v / .2 : 1 - (v - .2) / .8;
        final s = v < .2 ? .7 + .4 * (v / .2) : 1.1 - .1 * ((v - .2) / .8);
        return Stack(
          children: [
            Positioned(
              left: widget.at.dx,
              top: widget.at.dy + y,
              child: Opacity(
                opacity: o.clamp(0, 1),
                child: Transform.scale(
                  scale: s,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FlameIcon(size: 16),
                      const SizedBox(width: 4),
                      Text('+1', style: t(16, FontWeight.w800, widget.color)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

// ============================================================================
// Sections

class _Sec extends StatelessWidget {
  const _Sec({required this.title, this.trailing, this.trailingWidget});
  final String title;
  final String? trailing;
  final Widget? trailingWidget;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 26, 2, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title, style: t(19, FontWeight.w800, ll.ink, ls: -.02)),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: trailingWidget ?? Text(trailing ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: t(13.5, FontWeight.w600, ll.ink3)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllClear extends StatelessWidget {
  const _AllClear();
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Motion.spring,
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 10),
        decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(30), boxShadow: ll.shadow),
        child: Column(
          children: [
            Text('All caught up', style: t(19, FontWeight.w800, ll.ink)),
            const SizedBox(height: 2),
            Text('Every idea got its moment today.', style: t(14, FontWeight.w500, ll.ink2)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Next up card (.next)

class _NextCard extends StatefulWidget {
  const _NextCard({super.key, required this.item, required this.folder, required this.out, required this.animateIn, required this.onDone, required this.onLater, required this.onOpen});
  final Item item;
  final String folder;
  final bool out, animateIn;
  final void Function(Offset from) onDone;
  final VoidCallback onLater, onOpen;

  @override
  State<_NextCard> createState() => _NextCardState();
}

class _NextCardState extends State<_NextCard> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 600), value: widget.animateIn ? 0 : 1);
  final _doneKey = GlobalKey();
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    if (widget.animateIn) _in.forward();
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final it = widget.item;
    final src = it.domain.isNotEmpty ? it.domain : (it.kind == ItemKind.todoList ? 'To-do' : 'Reminder');

    final card = Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), boxShadow: ll.shadow),
      child: CustomPaint(
        painter: _StripePainter(ll),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (it.url.isNotEmpty && it.thumbnail.isNotEmpty) ...[
              Tap(
                scale: .98,
                onTap: widget.onOpen,
                semanticLabel: 'Open link',
                child: Cover(url: it.thumbnail, letter: it.domain, aspect: 16 / 9, radius: 20),
              ),
              const SizedBox(height: 14),
            ],
            FractionallySizedBox(
              widthFactor: .88,
              alignment: Alignment.centerLeft,
              child: Text(it.title, style: t(21, FontWeight.w800, ll.ink, ls: -.02, h: 1.25)),
            ),
            const SizedBox(height: 4),
            Text('${widget.folder} folder, $src', style: t(13.5, FontWeight.w600, ll.ink3)),
            if (it.note.isNotEmpty) ...[const SizedBox(height: 10), Text(it.note, style: t(14, FontWeight.w500, ll.ink2, h: 1.45))],
            const SizedBox(height: 16),
            Row(
              children: [
                // Buttons keep their natural size and only scale down on very narrow screens.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Btn(
                            key: _doneKey,
                            icon: 'check',
                            label: _pressed ? 'Nice!' : 'Revisited',
                            bg: _pressed ? ll.blue : ll.ink,
                            fg: _pressed ? Colors.white : ll.onInk,
                            pop: _pressed,
                            onTap: () {
                              if (_pressed) return;
                              Haptics.medium();
                              setState(() => _pressed = true);
                              final b = _doneKey.currentContext!.findRenderObject() as RenderBox;
                              final p = b.localToGlobal(Offset(24, b.size.height / 2));
                              Timer(const Duration(milliseconds: 260), () {
                                if (mounted) widget.onDone(p);
                              });
                            },
                          ),
                          const SizedBox(width: 10),
                          _Btn(icon: 'snooze', label: 'Later', bg: ll.surface2, fg: ll.ink2, onTap: widget.onLater),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (it.url.isNotEmpty)
                  Tap(
                    onTap: widget.onOpen,
                    semanticLabel: 'Open link',
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: ll.blue, boxShadow: ll.blueGlow()),
                      child: const LLIcon('arrow', color: Colors.white),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _in,
      builder: (_, child) {
        final v = Motion.spring.transform(_in.value);
        return Opacity(
          opacity: _in.value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - v)),
            child: Transform.scale(scale: .97 + .03 * v, child: child),
          ),
        );
      },
      child: AnimatedSlide(
        offset: widget.out ? const Offset(1.15, -.04) : Offset.zero,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInCubic,
        child: AnimatedRotation(
          turns: widget.out ? .025 : 0,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInCubic,
          child: AnimatedOpacity(opacity: widget.out ? 0 : 1, duration: const Duration(milliseconds: 420), curve: Curves.easeIn, child: card),
        ),
      ),
    );
  }
}

/// repeating-linear-gradient(135deg, surface 0 12px, stripe 12px 13px)
class _StripePainter extends CustomPainter {
  _StripePainter(this.ll);
  final LL ll;

  @override
  void paint(Canvas canvas, Size size) {
    // The child padding sits inside this painter; paint behind the full card.
    final r = Rect.fromLTRB(-20, -18, size.width + 18, size.height + 18);
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(30));
    canvas.save();
    canvas.clipRRect(rr);
    if (ll.dark) {
      canvas.drawRect(r, Paint()..shader = LinearGradient(begin: const Alignment(-.34, -1), end: const Alignment(.34, 1), colors: [const Color(0xFF121726), ll.surface]).createShader(r));
    } else {
      canvas.drawRect(r, Paint()..color = ll.surface);
    }
    final p = Paint()
      ..color = ll.stripe
      ..strokeWidth = 1;
    const step = 13.0 * 1.41421356; // 13px period measured along 135deg → along the x axis
    final h = r.height;
    for (var x = r.left - h; x < r.right + h; x += step) {
      canvas.drawLine(Offset(x, r.bottom), Offset(x + h, r.top), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripePainter o) => o.ll != ll;
}

class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.color});
  final Color color;
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (_, _) => Opacity(
      opacity: 1 - .75 * math.sin(c.value * math.pi),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
      ),
    ),
  );
}

class _Btn extends StatelessWidget {
  const _Btn({super.key, required this.icon, required this.label, required this.bg, required this.fg, required this.onTap, this.pop = false});
  final String icon, label;
  final Color bg, fg;
  final VoidCallback onTap;
  final bool pop;
  @override
  Widget build(BuildContext context) => Tap(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Motion.smooth,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey(pop),
            tween: Tween(begin: pop ? .3 : 1, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Motion.spring,
            builder: (_, v, c) => Transform.scale(scale: pop ? v * 1.15 : 1, child: c),
            child: LLIcon(icon, size: 18, color: fg, stroke: pop ? 2.6 : 1.9),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(label, key: ValueKey(label), maxLines: 1, style: t(14.5, FontWeight.w700, fg)),
          ),
        ],
      ),
    ),
  );
}

// ============================================================================
// Later today rows (.rw / .row): tick to finish, swipe left for tomorrow

class _LaterRow extends StatefulWidget {
  const _LaterRow({super.key, required this.item, required this.folder, required this.first, required this.leaving, required this.onDone, required this.onLater, required this.onSwipeArm});
  final Item item;
  final String folder;
  final bool first;
  final _Leave? leaving;
  final void Function(Offset from) onDone;
  final Future<bool> Function() onLater;
  final VoidCallback onSwipeArm;

  @override
  State<_LaterRow> createState() => _LaterRowState();
}

class _LaterRowState extends State<_LaterRow> with TickerProviderStateMixin {
  late final AnimationController _size = AnimationController(vsync: this, duration: const Duration(milliseconds: 450), value: 1);
  late final AnimationController _snap = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  final _ck = GlobalKey();
  double _dx = 0;
  double _snapFrom = 0, _snapTo = 0;
  bool _armed = false;
  bool _checked = false;
  double _width = 360;

  @override
  void initState() {
    super.initState();
    _snap.addListener(() => setState(() => _dx = _snapFrom + (_snapTo - _snapFrom) * Motion.spring.transform(_snap.value)));
  }

  @override
  void didUpdateWidget(_LaterRow old) {
    super.didUpdateWidget(old);
    if (old.leaving == null && widget.leaving != null) {
      final delay = widget.leaving == _Leave.done ? 380 : 250;
      Timer(Duration(milliseconds: delay), () {
        if (mounted) _size.animateTo(0, curve: Motion.smooth);
      });
    }
    if (old.leaving != null && widget.leaving == null) {
      _size.value = 1;
    }
  }

  @override
  void dispose() {
    _size.dispose();
    _snap.dispose();
    super.dispose();
  }

  void _animateTo(double to) {
    _snapFrom = _dx;
    _snapTo = to;
    _snap.forward(from: 0);
  }

  void _tick() {
    if (_checked || widget.leaving != null) return;
    setState(() => _checked = true);
    final b = _ck.currentContext!.findRenderObject() as RenderBox;
    widget.onDone(b.localToGlobal(b.size.center(Offset.zero)));
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final it = widget.item;
    final when = DateTime.fromMillisecondsSinceEpoch(it.whenTs);
    final src = it.domain.isNotEmpty ? it.domain : (it.kind == ItemKind.todoList ? 'To-do' : 'Reminder');
    final done = _checked || widget.leaving == _Leave.done;

    final row = Container(
      color: ll.surface,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Mark revisited',
            child: GestureDetector(
              onTap: _tick,
              child: AnimatedContainer(
                key: _ck,
                duration: const Duration(milliseconds: 300),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? ll.blue : Colors.transparent,
                  border: Border.all(color: done ? ll.blue : ll.inkMix(.22), width: 1.8),
                ),
                alignment: Alignment.center,
                child: AnimatedOpacity(
                  opacity: done ? 1 : 0,
                  duration: const Duration(milliseconds: 350),
                  child: const LLIcon('check', size: 15, color: Colors.white, stroke: 2.8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: t(15.5, FontWeight.w700, done ? ll.ink3 : ll.ink).copyWith(decoration: done ? TextDecoration.lineThrough : null, decorationColor: ll.ink3),
                  child: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 2),
                Text('${widget.folder}, $src', maxLines: 1, overflow: TextOverflow.ellipsis, style: t(13, FontWeight.w600, ll.ink3)),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: ll.surface2, borderRadius: BorderRadius.circular(99)),
            child: Text(fmtT(when), style: t(13, FontWeight.w700, ll.ink2)),
          ),
        ],
      ),
    );

    return SizeTransition(
      sizeFactor: _size,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _size,
        child: Container(
          decoration: BoxDecoration(
            border: widget.first ? null : Border(top: BorderSide(color: ll.line)),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              _width = c.maxWidth;
              return Stack(
                children: [
                  // .under: "Tomorrow" revealed behind the row
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: _dx < -30 ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LLIcon('snooze', size: 18, color: ll.blueInk),
                              const SizedBox(width: 7),
                              Text('Later', style: t(13.5, FontWeight.w700, ll.blueInk)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: (_) => _snap.stop(),
                    onHorizontalDragUpdate: (d) {
                      if (widget.leaving != null) return;
                      setState(() => _dx = math.min(0, _dx + d.delta.dx));
                      if (_dx < -90 && !_armed) {
                        _armed = true;
                        widget.onSwipeArm();
                      } else if (_dx >= -90) {
                        _armed = false;
                      }
                    },
                    onHorizontalDragEnd: (d) async {
                      if (widget.leaving != null) return;
                      if (_dx < -90 || d.primaryVelocity! < -900) {
                        _animateTo(-96);
                        final ok = await widget.onLater();
                        if (!mounted) return;
                        _animateTo(ok ? -_width * 1.1 : 0);
                      } else {
                        _animateTo(0);
                      }
                    },
                    child: Transform.translate(offset: Offset(_dx, 0), child: row),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Folder pills (.fpills)

class _FolderPills extends StatelessWidget {
  const _FolderPills({required this.folders, required this.count, required this.onTap});
  final List<Folder> folders;
  final int Function(String) count;
  final void Function(Folder) onTap;

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Row(
          children: [
            for (final f in folders) ...[
              Tap(
                onTap: () => onTap(f),
                semanticLabel: '${f.name}, ${count(f.name)} items',
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.fromLTRB(6, 0, 18, 0),
                  decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(99), boxShadow: ll.shadow),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: ll.blueSoft),
                        child: LLIcon(f.iconKey, size: 20, color: ll.blueInk),
                      ),
                      const SizedBox(width: 10),
                      Text(f.name, style: t(15, FontWeight.w700, ll.ink)),
                      const SizedBox(width: 5),
                      Text('${count(f.name)}', style: t(13, FontWeight.w700, ll.ink3)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ],
        ),
      ),
    );
  }
}
