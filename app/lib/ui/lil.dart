// Lil's corner: streak, freezes, hearts, growing up, outfits, name.
// Also the "Day 10. Welcome back!" card shown on the first open of the day.
import 'package:material_ui/material_ui.dart';

import '../data/store.dart';
import '../mascot/mascot_svg.dart';
import '../mascot/mascot_view.dart';
import '../services/haptics.dart';
import '../theme/tokens.dart';
import '../widgets/icons.dart' show HeartFill;
import 'kit.dart';
import 'sheets.dart';

class LilCorner extends StatefulWidget {
  const LilCorner({super.key});
  @override
  State<LilCorner> createState() => _LilCornerState();
}

class _LilCornerState extends State<LilCorner> {
  final _m = MascotController();
  int _poke = 0;
  int? _try; // an outfit being tried on before buying

  @override
  void dispose() {
    _m.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final st = s.store;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: ll.bg,
      body: ListenableBuilder(
        listenable: st,
        builder: (context, _) {
          final lv = st.level;
          final next = st.nextLevel;
          final prog = st.levelProgress.clamp(0.0, 1.0);
          final n = AppStore.now();
          final td = n.weekday - 1; // 0 = Mon
          var prev = 0;
          return Stack(children: [
            ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, top + 64, 16, _try != null ? 240 : 40),
              children: [
                GestureDetector(
                  onTap: () {
                    Haptics.light();
                    _m.play(MascotAct.hop);
                    _m.mood(Mood.happy, const Duration(milliseconds: 1200));
                    final lines = ['Hi ${st.userName.isEmpty ? 'there' : st.userName.split(' ').first}!', 'Day ${st.streak}, nice!', 'Got anything for me?', 'I like this outfit', 'Boop!'];
                    s.toast.show(lines[_poke++ % lines.length]);
                  },
                  child: SizedBox(
                    height: 220,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedScale(
                        scale: const [.7, .8, .9, 1.0, 1.1][lv.n - 1],
                        alignment: Alignment.bottomCenter,
                        duration: const Duration(milliseconds: 600),
                        curve: Motion.spring,
                        child: SizedBox(width: 190, height: 190, child: MascotView(stage: lv.n, controller: _m, outfit: _try ?? st.outfitNow)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(st.mascotName, style: t(28, FontWeight.w600, ll.ink, ls: -.02)),
                  const SizedBox(width: 8),
                  RoundBtn(icon: 'edit', size: 34, iconSize: 15, label: 'Rename', onTap: () => renameSheet(context, RenameWho.lil)),
                ]),
                Text('${lv.name} size · wearing ${kLilOutfits[st.outfitNow.clamp(0, 3)].toLowerCase()}', textAlign: TextAlign.center, style: t(15, FontWeight.w400, ll.ink2)),
                const SizedBox(height: 12),
                // Streak
                Surface(
                  radius: 26,
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      LLIcon('flame', size: 40, color: ll.ember, stroke: 2.2),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${st.streak}', style: t(34, FontWeight.w600, ll.ink, h: 1)), Text('day streak', style: t(13, FontWeight.w400, ll.ink2))]),
                      const Spacer(),
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(99)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [LLIcon('snow', size: 15, color: ll.ink), const SizedBox(width: 6), Text('${st.freezes} ${st.freezes == 1 ? 'freeze' : 'freezes'}', style: t(13, FontWeight.w500, ll.ink))]),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Column(children: [
                            Opacity(opacity: i <= td && td - i < st.streak ? 1 : .2, child: LLIcon('flame', size: 22, color: i <= td && td - i < st.streak ? ll.ember : ll.ink, stroke: 2.2)),
                            const SizedBox(height: 4),
                            Text('MTWTFSS'[i], style: t(11, i == td ? FontWeight.w600 : FontWeight.w500, i == td ? ll.ink : ll.ink3)),
                          ]),
                        ),
                    ]),
                    const SizedBox(height: 14),
                    Text('Opening the app once a day keeps the flame. Every 5 days you earn a freeze that saves a missed day.', style: t(13, FontWeight.w400, ll.ink2, h: 1.45)),
                  ]),
                ),
                const SizedBox(height: 20),
                Padding(padding: const EdgeInsets.only(left: 6, bottom: 10), child: Text('Hearts', style: t(13, FontWeight.w600, ll.ink2))),
                Surface(
                  radius: 26,
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      for (final m in kMiles) ...[
                        if (m != kMiles.first) const SizedBox(width: 6),
                        Expanded(child: Builder(builder: (bc) {
                          final amt = m - prev;
                          prev = m;
                          final got = st.collected.contains(m), rdy = !got && st.streak >= m;
                          return Tap(
                            onTap: rdy
                                ? () {
                                    final g = st.collect(m);
                                    if (g > 0) {
                                      sparksAt(bc, n: 14);
                                      Haptics.medium();
                                      s.toast.show('+$g hearts');
                                      _m.play(MascotAct.hop);
                                    }
                                  }
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(color: rdy ? ll.blueSoft : ll.chip, borderRadius: BorderRadius.circular(18), border: Border.all(color: rdy ? ll.blue : Colors.transparent, width: 1.5)),
                              child: Opacity(
                                opacity: got || rdy ? 1 : .5,
                                child: Column(children: [
                                  Opacity(opacity: got ? .5 : 1, child: const HeartFill(size: 18)),
                                  const SizedBox(height: 4),
                                  Text(got ? 'Got it' : rdy ? 'Collect $amt' : '+$amt', style: t(11, FontWeight.w600, rdy ? ll.blueInk : ll.ink)),
                                  Text('Day $m', style: t(11, FontWeight.w400, ll.ink2)),
                                ]),
                              ),
                            ),
                          );
                        })),
                      ],
                    ]),
                    const SizedBox(height: 12),
                    Text('${st.heartsReady > 0 ? 'Tap a glowing heart to collect it. ' : st.nextMile != null ? 'Keep your streak to collect hearts on day ${st.nextMile}. ' : ''}You have ${st.hearts} hearts to spend on outfits.', style: t(13, FontWeight.w400, ll.ink2, h: 1.45)),
                  ]),
                ),
                const SizedBox(height: 20),
                Padding(padding: const EdgeInsets.only(left: 6, bottom: 10), child: Text('Growing up', style: t(13, FontWeight.w600, ll.ink2))),
                Surface(
                  radius: 26,
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SizedBox(
                      height: 100,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        for (final l in kLevels)
                          Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Opacity(opacity: l.n > lv.n ? .28 : 1, child: SizedBox(width: 34 + (l.n - 1) * 9.0, height: 34 + (l.n - 1) * 9.0, child: MascotView(stage: l.n, live: false, outfit: l.n == lv.n ? st.outfitNow : 0))),
                            const SizedBox(height: 4),
                            Text(l.name, style: t(11, l.n == lv.n ? FontWeight.w600 : FontWeight.w500, l.n == lv.n ? ll.ink : ll.ink2)),
                          ]),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: SizedBox(height: 8, child: Stack(children: [Container(color: ll.chip), FractionallySizedBox(widthFactor: prog, child: Container(color: ll.blue))])),
                    ),
                    const SizedBox(height: 12),
                    Text('${next != null ? '${next.min - st.xp} points until ${next.name} size.' : 'Fully grown!'} Save something +5 · finish it +15.', style: t(13, FontWeight.w400, ll.ink2)),
                  ]),
                ),
                const SizedBox(height: 20),
                Padding(padding: const EdgeInsets.only(left: 6, bottom: 10), child: Text('Outfits', style: t(13, FontWeight.w600, ll.ink2))),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: .95,
                  children: [
                    for (var i = 0; i < kLilOutfits.length; i++)
                      Builder(builder: (bc) {
                        final own = st.ownedOutfits.contains(i), wear = st.outfitNow == i, cost = kLilOutfitCost[i];
                        return Tap(
                          onTap: () {
                            if (own) {
                              st.wear(i);
                              _m.play(MascotAct.hop);
                              Haptics.light();
                            } else {
                              // Try it on first; buying is a separate tap.
                              Haptics.light();
                              setState(() => _try = i);
                              _m.play(MascotAct.hop);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: wear || _try == i ? ll.blue : Colors.transparent, width: 1.5)),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              SizedBox(width: 92, height: 92, child: MascotView(stage: 3, live: false, outfit: i)),
                              const SizedBox(height: 6),
                              Text(kLilOutfits[i], style: t(15, FontWeight.w600, ll.ink)),
                              const SizedBox(height: 2),
                              _try == i
                                  ? Text('Trying on', style: t(13, FontWeight.w500, ll.blueInk))
                                  : wear
                                  ? Text('Wearing', style: t(13, FontWeight.w500, ll.blueInk))
                                  : own
                                      ? Text('Wear', style: t(13, FontWeight.w400, ll.ink2))
                                      : Row(mainAxisSize: MainAxisSize.min, children: [const HeartFill(size: 12), const SizedBox(width: 4), Text('$cost${st.hearts >= cost ? '' : ' · locked'}', style: t(13, FontWeight.w400, ll.ink2))]),
                            ]),
                          ),
                        );
                      }),
                  ],
                ),
              ],
            ),
            if (_try != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: MediaQuery.paddingOf(context).bottom + 12,
                child: Builder(builder: (bc) {
                  final i = _try!, cost = kLilOutfitCost[i], can = st.hearts >= cost;
                  return Container(
                    padding: const EdgeInsets.fromLTRB(10, 10, 14, 14),
                    decoration: BoxDecoration(color: ll.dark ? const Color(0xFF16161A) : Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: ll.line)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Row(children: [
                        SizedBox(width: 84, height: 84, child: MascotView(stage: 3, outfit: i, staticMood: Mood.happy)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(kLilOutfits[i], style: t(22, FontWeight.w600, ll.ink, ls: -.02)),
                            const SizedBox(height: 4),
                            Row(children: [const HeartFill(size: 14), const SizedBox(width: 5), Text(can ? '$cost hearts · you have ${st.hearts}' : 'Needs $cost hearts · you have ${st.hearts}', style: t(13, FontWeight.w500, can ? ll.ink2 : ll.blueInk))]),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        GhostBtn(label: 'Not now', onTap: () => setState(() => _try = null)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AccentBtn(
                            label: can ? 'Buy for $cost' : 'Keep your streak to earn more',
                            enabled: can,
                            onTap: () {
                              if (!st.unlock(i)) return;
                              st.wear(i);
                              sparksAt(bc, n: 16);
                              Haptics.medium();
                              s.toast.show('${kLilOutfits[i]} is yours!');
                              _m.play(MascotAct.hop);
                              setState(() => _try = null);
                            },
                          ),
                        ),
                      ]),
                    ]),
                  );
                }),
              ),
            Positioned(
              left: 16,
              right: 16,
              top: top + 10,
              child: Row(children: [
                RoundBtn(icon: 'x', size: 40, iconSize: 18, label: 'Close', onTap: () => Navigator.of(context).maybePop()),
                const Spacer(),
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: ll.dark ? ll.surface2 : ll.surface, borderRadius: BorderRadius.circular(99)),
                  child: Row(children: [const HeartFill(size: 15), const SizedBox(width: 6), Text('${st.hearts}', style: t(13, FontWeight.w600, ll.ink))]),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

/// "Day 10. Welcome back!" — shown once a day when the app opens.
class StreakMoment extends StatefulWidget {
  const StreakMoment({super.key, required this.result, required this.onClose, required this.onOpenLil});
  final HiResult result;
  final VoidCallback onClose, onOpenLil;
  @override
  State<StreakMoment> createState() => _StreakMomentState();
}

class _StreakMomentState extends State<StreakMoment> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  bool _ticked = false;

  @override
  void initState() {
    super.initState();
    Haptics.medium();
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _ticked = true);
    });
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final st = AppScope.of(context).store;
    final r = widget.result;
    final extra = kMiles.contains(r.streak)
        ? 'Hearts are ready to collect'
        : r.freezeEarned
            ? 'You earned a streak freeze'
            : r.freezesUsed > 0
                ? 'A freeze kept your streak safe'
                : 'Come back tomorrow to keep it going';
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black.withValues(alpha: .45),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: GestureDetector(
          onTap: () {},
          child: ScaleTransition(
            scale: CurvedAnimation(parent: _a, curve: Motion.spring).drive(Tween(begin: .9, end: 1.0)),
            child: FadeTransition(
              opacity: _a,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                decoration: BoxDecoration(color: ll.dark ? const Color(0xFF16161A) : const Color(0xFFFAF8F5), borderRadius: BorderRadius.circular(34)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Lil(size: 120, mood: Mood.happy),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    LLIcon('flame', size: 54, color: ll.ember, stroke: 2.2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Motion.spring), child: c),
                      child: Text('${_ticked ? r.streak : (r.streak - 1).clamp(0, 9999)}', key: ValueKey(_ticked), style: t(44, FontWeight.w600, ll.ink, ls: -.03, h: 1)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text('Day ${r.streak}. Welcome back!', style: t(22, FontWeight.w600, ll.ink, ls: -.02)),
                  const SizedBox(height: 4),
                  Text('Your streak counts when you open the app each day.', textAlign: TextAlign.center, style: t(15, FontWeight.w400, ll.ink2)),
                  const SizedBox(height: 14),
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(99)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      kMiles.contains(r.streak) ? const HeartFill(size: 14) : LLIcon('snow', size: 14, color: ll.ink),
                      const SizedBox(width: 6),
                      Text(extra, style: t(13, FontWeight.w500, ll.ink)),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    GhostBtn(label: 'See ${st.mascotName}', onTap: widget.onOpenLil),
                    const SizedBox(width: 8),
                    Expanded(child: AccentBtn(label: 'Keep going', onTap: widget.onClose)),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
