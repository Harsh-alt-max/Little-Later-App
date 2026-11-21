// Full-screen reminder, opened by tapping a notification:
// "Did you do it?" · I did it · In 15 min · In 1 hour · Tonight.
import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../mascot/mascot_svg.dart';
import '../mascot/mascot_view.dart';
import '../services/haptics.dart';
import '../theme/tokens.dart';
import 'items.dart';
import 'kit.dart';

class RingScreen extends StatefulWidget {
  const RingScreen({super.key, required this.item});
  final Item item;
  @override
  State<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends State<RingScreen> {
  final _m = MascotController(base: Mood.happy);
  bool _did = false;

  @override
  void initState() {
    super.initState();
    Haptics.medium();
    Timer(const Duration(milliseconds: 420), () {
      if (mounted) _m.play(MascotAct.hop);
    });
  }

  @override
  void dispose() {
    _m.dispose();
    super.dispose();
  }

  String get _q {
    final it = widget.item;
    if (it.kind == ItemKind.todoList) return 'Done with this?';
    if (it.kind != ItemKind.link) return 'Did you do it?';
    return RegExp('youtube|youtu.be|vimeo|reel|tiktok|instagram').hasMatch(it.domain) ? 'Did you watch this?' : 'Did you read this?';
  }

  Future<void> _done(BuildContext bc) async {
    if (_did) return;
    final s = AppScope.of(context);
    setState(() => _did = true);
    sparksAt(bc, n: 16);
    _m.play(MascotAct.hop);
    Haptics.medium();
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    Navigator.of(context).pop();
    if (!widget.item.isDone) markDone(s, widget.item);
  }

  void _snooze(String k) {
    final s = AppScope.of(context);
    final n = AppStore.now();
    final d = switch (k) {
      '15' => n.add(const Duration(minutes: 15)),
      '60' => n.add(const Duration(hours: 1)),
      _ => DateTime(n.year, n.month, n.day + (n.hour >= 21 ? 1 : 0), 21),
    };
    s.store.snoozeTo(widget.item.id, d);
    Navigator.of(context).pop();
    s.toast.show('${s.store.mascotName} will ask again at ${fmtT(d)}');
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final st = s.store;
    final it = widget.item;
    final link = it.kind == ItemKind.link;
    final pad = MediaQuery.paddingOf(context);
    final g = groupOf(st, it);
    final sub = link ? it.domain : g != null ? '${byOf(it).isEmpty ? 'Shared' : byOf(it)} · ${g.name}' : it.folder.isNotEmpty ? it.folder : it.kind == ItemKind.todoList ? 'To-do' : 'Reminder';
    const dows = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return Scaffold(
      backgroundColor: ll.bg,
      body: Container(
        decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -.4), radius: .9, colors: [ll.blueSoft, ll.bg], stops: const [0, .75])),
        padding: EdgeInsets.fromLTRB(20, pad.top + 12, 20, pad.bottom + 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [RoundBtn(icon: 'x', size: 40, iconSize: 18, label: 'Close', onTap: () => Navigator.of(context).pop()), const Spacer()]),
          Ticker2(builder: (_) {
            final n = AppStore.now();
            final tm = fmtT(n).split(' ');
            return Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(tm.first, style: t(44, FontWeight.w600, ll.ink, ls: -.04, h: 1)),
                const SizedBox(width: 4),
                Text(tm.last, style: t(17, FontWeight.w500, ll.ink2)),
              ]),
              const SizedBox(height: 6),
              Text('${dows[n.weekday - 1]}, ${n.day} ${months[n.month - 1]}', style: t(13, FontWeight.w400, ll.ink2)),
            ]);
          }),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 170, height: 170, child: MascotView(stage: 3, controller: _m, outfit: st.outfitNow)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(color: ll.ink, borderRadius: BorderRadius.circular(20)),
                child: Text(_did ? 'Yay, you did it!' : _q, style: t(17, FontWeight.w600, ll.onInk)),
              ),
            ]),
          ),
          Surface(
            radius: 24,
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              it.thumbnail.isNotEmpty || link ? Cover2(item: it, width: 56, height: 56, radius: 14) : IconTile(it.kind == ItemKind.todoList ? 'todo' : 'bell', size: 48, radius: 15),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t(17, FontWeight.w600, ll.ink, h: 1.3)), Text(sub, style: t(13, FontWeight.w400, ll.ink2))])),
              if (link) RoundBtn(icon: 'ext', size: 44, iconSize: 18, label: 'Open', bg: ll.chip, onTap: () => openUrl(s, it)),
            ]),
          ),
          if (it.tasks.isNotEmpty) Surface(margin: const EdgeInsets.only(top: 8), radius: 20, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: ListenableBuilder(listenable: st, builder: (_, _) => StepsList(item: it))),
          const SizedBox(height: 14),
          Builder(
            builder: (bc) => _did
                ? AccentBtn(label: 'Yay, you did it!', icon: 'check', height: 58)
                : InkBtn(label: link ? 'Done, I saw it' : 'I did it', height: 58, onTap: () => _done(bc), trailing: Padding(padding: const EdgeInsets.only(left: 8), child: Text('+15', style: t(13, FontWeight.w600, ll.onInk.withValues(alpha: .6))))),
          ),
          const SizedBox(height: 10),
          Row(children: [
            for (final (k, l) in [('15', 'In 15 min'), ('60', 'In 1 hour'), ('tonight', 'Tonight')]) ...[
              if (k != '15') const SizedBox(width: 8),
              Expanded(
                child: Tap(
                  onTap: () => _snooze(k),
                  child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: ll.dark ? ll.surface : Colors.white, borderRadius: BorderRadius.circular(16)), child: Text(l, style: t(15, FontWeight.w500, ll.ink))),
                ),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}
