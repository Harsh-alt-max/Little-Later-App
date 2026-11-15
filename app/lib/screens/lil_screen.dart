import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../data/store.dart';
import '../mascot/mascot_svg.dart';
import '../mascot/mascot_view.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';
import '../widgets/kit.dart';
import 'profile_screen.dart';
import '../services/haptics.dart';

/// v7 Lil panel: style, outfits (unlock with hearts), streak path, growth.
class LilScreen extends StatefulWidget {
  const LilScreen({super.key, this.scrollToStreak = false});
  final bool scrollToStreak;
  @override
  State<LilScreen> createState() => _LilScreenState();
}

class _LilScreenState extends State<LilScreen> {
  final _m = MascotController();
  final _scroll = ScrollController();
  final _heartsKey = GlobalKey();
  int? _preview;
  int _heartBump = 0;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _m.play(MascotAct.hop);
      _m.mood(Mood.happy, const Duration(milliseconds: 1000));
      if (widget.scrollToStreak && _scroll.hasClients) _scroll.animateTo(430, duration: const Duration(milliseconds: 600), curve: Motion.smooth);
    });
  }

  @override
  void dispose() {
    _m.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _tapOutfit(AppStore st, int i) {
    Haptics.tick();
    if (st.ownedOutfits.contains(i)) {
      st.wear(i);
      setState(() => _preview = null);
      _m.play(MascotAct.hop);
      _m.mood(Mood.happy, const Duration(milliseconds: 900));
      AppScope.of(context).toast.show('${st.mascotName} is wearing ${kOutfits[st.mascotStyle]![i].toLowerCase()}');
    } else {
      setState(() => _preview = _preview == i ? null : i);
      if (_preview != null) {
        _m.mood(Mood.wow, const Duration(milliseconds: 900));
        _m.play(MascotAct.squish);
      }
    }
  }

  void _unlock(AppStore st) {
    final i = _preview;
    if (i == null || !st.unlock(i)) return;
    Haptics.heavy();
    setState(() => _preview = null);
    _m.play(MascotAct.hop);
    _m.mood(Mood.happy, const Duration(milliseconds: 1400));
    final box = context.findRenderObject() as RenderBox?;
    if (box != null) spawnSparks(Overlay.of(context), Offset(box.size.width / 2, 200), 18, LL.of(context).blue);
    AppScope.of(context).toast.show('Unlocked ${kOutfits[st.mascotStyle]![i].toLowerCase()} for every style');
  }

  void _collect(AppStore st, int m) {
    final got = st.collect(m);
    if (got == 0) return;
    Haptics.heavy();
    _m.play(MascotAct.hop);
    _m.mood(Mood.happy, const Duration(milliseconds: 1200));
    setState(() => _heartBump++);
    AppScope.of(context).toast.show('+$got hearts');
  }

  Future<void> _rename(AppStore st) async {
    final c = TextEditingController(text: st.mascotName);
    final n = await showLLSheet<String>(context, builder: (ctx) {
      final ll = LL.of(ctx);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SheetTitle('Name your mascot'),
        LLInput(controller: c, hint: 'Name', icon: 'pen', maxLength: 12, autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, v)),
        const SizedBox(height: 12),
        Text('This name shows across the app and on your reminders.', style: t(13, FontWeight.w600, ll.ink3)),
        const SizedBox(height: 16),
        BigButton(label: 'Save', onTap: () => Navigator.pop(ctx, c.text)),
      ]);
    });
    if (n != null && n.trim().isNotEmpty && mounted) {
      st.setMascotName(n);
      AppScope.of(context).toast.show('Say hi to ${n.trim()}!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: ll.bg,
      body: ListenableBuilder(
        listenable: s.store,
        builder: (context, _) {
          final st = s.store;
          final names = kOutfits[st.mascotStyle]!;
          final lvl = st.level, next = st.nextLevel;
          final shown = _preview ?? st.outfitNow;
          return DecoratedBox(
            decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -.6), radius: .9, colors: [ll.headA, ll.bg], stops: const [0, .72])),
            child: Column(children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, 14 + top, 20, 0),
                child: Row(children: [
                  Circ(icon: 'x', label: 'Close', onTap: () => Navigator.pop(context)),
                  const Spacer(),
                  Bump(
                    key: _heartsKey,
                    trigger: _heartBump,
                    peak: 1.25,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.fromLTRB(12, 0, 15, 0),
                      decoration: BoxDecoration(color: ll.surface2, borderRadius: BorderRadius.circular(99)),
                      child: Row(children: [const HeartFill(), const SizedBox(width: 7), Text('${st.hearts}', style: t(16, FontWeight.w800, ll.ink))]),
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 40 + bottom),
                  children: [
                    SizedBox(
                      height: 230,
                      child: Stack(alignment: Alignment.center, children: [
                        GestureDetector(
                          onTap: () {
                            Haptics.light();
                            _m.play(MascotAct.squish);
                            _m.mood(Mood.happy, const Duration(milliseconds: 800));
                          },
                          child: SizedBox(width: 200, height: 220, child: MascotView(stage: lvl.n, controller: _m, style: st.mascotStyle, outfit: shown)),
                        ),
                        Positioned(
                          top: 12,
                          child: AnimatedOpacity(
                            opacity: _preview != null ? 1 : 0,
                            duration: const Duration(milliseconds: 250),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: ll.ink, borderRadius: BorderRadius.circular(99)),
                              child: Text('Preview only', style: t(12.5, FontWeight.w800, ll.onInk)),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(st.mascotName, style: t(28, FontWeight.w800, ll.ink, ls: -.03)),
                      const SizedBox(width: 8),
                      Circ(icon: 'pen', size: 34, iconSize: 16, shadow: false, bg: ll.surface2, label: 'Rename', onTap: () => _rename(st)),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 18),
                      child: Text('${lvl.name} size, ${names[shown].toLowerCase()} look', textAlign: TextAlign.center, style: t(14, FontWeight.w600, ll.ink2)),
                    ),
                    Segmented(
                      labels: const ['Girl', 'Teen', 'Man'],
                      index: st.mascotStyle.index,
                      height: 52,
                      onChanged: (i) {
                        Haptics.tick();
                        st.setStyle(MascotStyle.values[i]);
                        setState(() => _preview = null);
                        _m.play(MascotAct.hop);
                      },
                    ),
                    Lab('Outfits', hint: '${st.ownedOutfits.length} of 3 unlocked'),
                    Row(children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(child: _outfit(ll, st, i, names[i])),
                      ],
                    ]),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 400),
                      curve: Motion.smooth,
                      child: _preview == null || st.ownedOutfits.contains(_preview) ? const SizedBox(width: double.infinity) : _lockBar(ll, st, _preview!),
                    ),
                    _streakCard(ll, st),
                    _growCard(ll, st, lvl, next),
                  ],
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _outfit(LL ll, AppStore st, int i, String name) {
    final own = st.ownedOutfits.contains(i);
    final wear = st.outfitNow == i && _preview == null;
    final prev = _preview == i;
    return Tap(
      scale: .95,
      onTap: () => _tapOutfit(st, i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
        decoration: BoxDecoration(
          color: ll.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: wear ? ll.blue : prev ? ll.ink3 : Colors.transparent, width: 2.5),
          boxShadow: ll.shadow,
        ),
        child: Stack(children: [
          Column(children: [
            SizedBox(
              height: 92,
              child: ColorFiltered(
                colorFilter: own || prev ? const ColorFilter.mode(Colors.transparent, BlendMode.dst) : const ColorFilter.matrix([.3, .5, .1, 0, 0, .3, .5, .1, 0, 0, .3, .5, .1, 0, 0, 0, 0, 0, .7, 0]),
                child: MascotView(stage: 4, style: st.mascotStyle, outfit: i, live: false),
              ),
            ),
            const SizedBox(height: 2),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(13.5, FontWeight.w800, ll.ink)),
            const SizedBox(height: 3),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (!own) ...[const HeartFill(size: 12), const SizedBox(width: 4)],
              Text(wear ? 'Wearing' : own ? 'Wear' : '${kOutfitCost[i]}', style: t(12, FontWeight.w800, wear ? ll.blueInk : ll.ink3)),
            ]),
          ]),
          if (!own)
            Positioned(
              top: 2,
              right: 4,
              child: Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, color: ll.surface2), child: Icon(Icons.lock_rounded, size: 13, color: ll.ink3)),
            ),
        ]),
      ),
    );
  }

  Widget _lockBar(LL ll, AppStore st, int i) {
    final need = kOutfitCost[i];
    final prevOwned = i == 0 || st.ownedOutfits.contains(i - 1);
    final can = st.canUnlock(i);
    final names = kOutfits[st.mascotStyle]!;
    final msg = !prevOwned
        ? 'Unlock ${names[i - 1]} first.'
        : can
            ? 'Unlock for $need hearts. Works for all three styles.'
            : 'You have ${st.hearts} of $need hearts. Keep your streak going to collect more.';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(color: ll.surface2, borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          Expanded(child: Text(msg, style: t(13.5, FontWeight.w600, ll.ink2, h: 1.4))),
          const SizedBox(width: 10),
          Tap(
            onTap: can ? () => _unlock(st) : null,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: can ? ll.blue : ll.surface, borderRadius: BorderRadius.circular(99)),
              child: Text(can ? 'Unlock' : 'Locked', style: t(13.5, FontWeight.w700, can ? Colors.white : ll.ink3)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _streakCard(LL ll, AppStore st) {
    final idx = kMiles.where((m) => st.streak >= m).length;
    final last = idx > 0 ? kMiles[idx - 1] : 0;
    final nx = idx < kMiles.length ? kMiles[idx] : null;
    final frac = nx == null ? 1.0 : ((idx - 1 + (st.streak - last) / (nx - last)) / (kMiles.length - 1)).clamp(0.0, 1.0);
    final ready = st.heartsReady, nm = st.nextMile;
    final hint = ready > 0
        ? '$ready hearts waiting. Tap the pink circle to collect.'
        : nm != null
            ? '${nm - st.streak} more day${nm - st.streak > 1 ? 's' : ''} until your next hearts.'
            : 'All milestones collected. Legend!';
    return _card(ll, [
      Row(children: [
        Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: ll.blueSoft), child: const FlameIcon(size: 26)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${st.streak}', style: t(30, FontWeight.w800, ll.ink, ls: -.03, h: 1)),
            const SizedBox(height: 3),
            Text(st.hiToday ? 'day streak, said hi today' : 'day streak, say hi today!', maxLines: 2, style: t(13, FontWeight.w600, ll.ink2)),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: ll.surface2, borderRadius: BorderRadius.circular(99)),
          child: Row(children: [LLIcon('snow', size: 15, color: ll.blueInk), const SizedBox(width: 6), Text('${st.freezes} freezes', style: t(13, FontWeight.w800, ll.blueInk))]),
        ),
      ]),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth - 48;
        var prev = 0;
        return SizedBox(
          height: 70,
          child: Stack(children: [
            Positioned(left: 24, right: 24, top: 20, height: 3, child: Container(decoration: BoxDecoration(color: ll.inkMix(.10), borderRadius: BorderRadius.circular(9)))),
            Positioned(
              left: 24,
              top: 20,
              height: 3,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: frac * w),
                duration: const Duration(milliseconds: 1000),
                curve: Motion.smooth,
                builder: (_, v, _) => Container(width: v, decoration: BoxDecoration(color: ll.blue, borderRadius: BorderRadius.circular(9))),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (final m in kMiles)
                Builder(builder: (_) {
                  final got = st.collected.contains(m);
                  final rdy = !got && st.streak >= m;
                  final amt = m - prev;
                  prev = m;
                  return GestureDetector(
                    onTap: rdy ? () => _collect(st, m) : null,
                    child: SizedBox(
                      width: 56,
                      child: Column(children: [
                        _Node(got: got, ready: rdy, label: '$m'),
                        const SizedBox(height: 6),
                        FittedBox(fit: BoxFit.scaleDown, child: Text(got ? 'Collected' : rdy ? 'Collect $amt' : 'Day $m', maxLines: 1, style: t(11.5, FontWeight.w800, rdy ? LL.heart : ll.ink3))),
                      ]),
                    ),
                  );
                }),
            ]),
          ]),
        );
      }),
      const SizedBox(height: 14),
      Text(hint, textAlign: TextAlign.center, style: t(13, FontWeight.w600, ll.ink3)),
    ]);
  }

  Widget _growCard(LL ll, AppStore st, Level lvl, Level? next) => _card(ll, [
        Text('${lvl.name} size', style: t(20, FontWeight.w800, ll.ink)),
        const SizedBox(height: 3),
        Text(next != null ? '${next.min - st.xp} points until ${next.name}' : 'Fully grown', style: t(13, FontWeight.w600, ll.ink2)),
        const SizedBox(height: 18),
        SizedBox(
          height: 112,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final l in kLevels)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  SizedBox(
                    height: 40 + l.n * 9.0,
                    child: ColorFiltered(
                      colorFilter: l.n > lvl.n ? ColorFilter.mode(ll.ink.withValues(alpha: ll.dark ? .1 : .18), BlendMode.srcIn) : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                      child: MascotView(stage: 5, style: st.mascotStyle, outfit: st.outfitNow, live: false),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(l.name, style: t(11, FontWeight.w800, l.n == lvl.n ? ll.blueInk : ll.ink3)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Meter(value: st.levelProgress),
        const SizedBox(height: 14),
        Text('Save something: +5. Finish it: +15. Days don’t count here, only what you do.', style: t(13, FontWeight.w600, ll.ink3)),
      ]);

  Widget _card(LL ll, List<Widget> children) => Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(28), boxShadow: ll.shadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class _Node extends StatefulWidget {
  const _Node({required this.got, required this.ready, required this.label});
  final bool got, ready;
  final String label;
  @override
  State<_Node> createState() => _NodeState();
}

class _NodeState extends State<_Node> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final bg = widget.got ? ll.blue : widget.ready ? LL.heart : ll.surface2;
    return AnimatedBuilder(
      animation: c,
      builder: (_, child) {
        final k = widget.ready ? (1 - (c.value * 2 - 1).abs()) : 0.0;
        return Transform.scale(
          scale: 1 + .12 * k,
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: bg, boxShadow: [BoxShadow(color: ll.surface, spreadRadius: 4), if (widget.ready) BoxShadow(color: LL.heart.withValues(alpha: .8 * k), blurRadius: 18)]),
            child: child,
          ),
        );
      },
      child: widget.got
          ? const LLIcon('check', size: 18, color: Colors.white)
          : widget.ready
              ? const HeartFill(size: 18, color: Colors.white)
              : Text(widget.label, style: t(13, FontWeight.w800, ll.ink3)),
    );
  }
}
