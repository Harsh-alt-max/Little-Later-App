import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../mascot/mascot_svg.dart';
import '../mascot/mascot_view.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';
import '../widgets/item_tile.dart';
import '../widgets/kit.dart';
import '../services/haptics.dart';

/// v7 .rem: full-screen "Did you watch this?" when a reminder fires.
class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key, required this.item});
  final Item item;
  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final _m = MascotController();

  @override
  void initState() {
    super.initState();
    Haptics.heavy();
    Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _m.play(MascotAct.hop);
      _m.mood(Mood.wow, const Duration(milliseconds: 1500));
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
    if (it.url.isEmpty) return 'Did you do it?';
    if (RegExp('youtube|youtu.be|vimeo|reels|tiktok|instagram').hasMatch(it.domain)) return 'Did you watch this?';
    return 'Did you read this?';
  }

  Future<void> _did() async {
    final s = AppScope.of(context);
    _m.play(MascotAct.hop);
    _m.mood(Mood.happy);
    Haptics.medium();
    if (!widget.item.isDone) s.store.complete(widget.item.id);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    Navigator.pop(context);
    s.app.gain(15, line: 'Yay, you did it!');
    s.toast.show('“${shortText(widget.item.title)}” done');
  }

  Future<void> _snooze(String k) async {
    final s = AppScope.of(context);
    final n = AppStore.now();
    final d = k == 'tonight' ? DateTime(n.year, n.month, n.day + (n.hour >= 20 ? 1 : 0), 20) : n.add(Duration(minutes: int.parse(k)));
    _m.mood(Mood.sleep, const Duration(milliseconds: 900));
    Haptics.light();
    s.store.snoozeTo(widget.item.id, d);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.pop(context);
    s.toast.show('${s.store.mascotName} will ask again at ${fmtT(d)}');
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final st = s.store;
    final it = widget.item;
    final n = DateTime.now();
    final pad = MediaQuery.paddingOf(context);
    const dows = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final link = it.url.isNotEmpty;
    return Scaffold(
      backgroundColor: ll.bg,
      body: Container(
        decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -.4), radius: .9, colors: [ll.headA, ll.bg], stops: const [0, .72])),
        padding: EdgeInsets.fromLTRB(22, 30 + pad.top, 22, 26 + pad.bottom),
        child: Column(children: [
          Text(fmtT(n).replaceAll(RegExp(r' (am|pm)'), ''), style: t(54, FontWeight.w800, ll.ink, ls: -.04, h: 1)),
          const SizedBox(height: 6),
          Text('${dows[n.weekday - 1]}, ${n.day} ${months[n.month - 1]}', style: t(14, FontWeight.w600, ll.ink2)),
          const Spacer(),
          SizedBox(width: 190, height: 206, child: MascotView(stage: st.level.n, controller: _m, style: st.mascotStyle, outfit: st.outfitNow)),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Motion.spring,
            builder: (_, v, c) => Opacity(opacity: v.clamp(0, 1), child: Transform.scale(scale: .9 + .1 * v, child: c)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(color: ll.ink, borderRadius: BorderRadius.circular(22)),
              child: Text(_q, style: t(18, FontWeight.w800, ll.onInk)),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(24), boxShadow: ll.shadow),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: link ? ll.surface2 : ll.blueSoft, borderRadius: BorderRadius.circular(16)),
                child: link ? Text(it.domain[0].toUpperCase(), style: t(17, FontWeight.w800, ll.ink2)) : LLIcon(it.kind == ItemKind.todoList ? 'check' : 'bell', color: ll.blueInk),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t(16, FontWeight.w800, ll.ink, h: 1.3)),
                  Text(link ? it.domain : (it.folder.isEmpty ? 'Reminder' : it.folder), style: t(13, FontWeight.w600, ll.ink3)),
                ]),
              ),
              if (link) Circ(icon: 'arrow', size: 46, iconSize: 20, bg: ll.blueSoft, fg: ll.blueInk, shadow: false, label: 'Open', onTap: () => openItemUrl(s, it)),
            ]),
          ),
          for (final tk in it.tasks)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(color: ll.surface2, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Icon(tk.done ? Icons.check_circle_rounded : Icons.circle_outlined, size: 16, color: tk.done ? ll.blue : ll.ink3),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tk.text, style: t(14, FontWeight.w600, ll.ink))),
                ]),
              ),
            ),
          const Spacer(),
          BigButton(label: 'I did it', xp: 15, onTap: _did),
          const SizedBox(height: 10),
          Row(children: [
            for (final k in const [('15', 'In 15 min'), ('60', 'In 1 hour'), ('tonight', 'Tonight')]) ...[
              if (k.$1 != '15') const SizedBox(width: 8),
              Expanded(
                child: Tap(
                  onTap: () => _snooze(k.$1),
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(99), boxShadow: ll.shadow),
                    child: Text(k.$2, style: t(14, FontWeight.w800, ll.ink2)),
                  ),
                ),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

/// Bell sheet: in-app notifications.
Future<void> openNotesSheet(BuildContext context) async {
  final s = AppScope.of(context);
  await showLLSheet(context, builder: (ctx) {
    final ll = LL.of(ctx);
    final notes = s.store.notes;
    String ago(int ts) {
      final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
      if (d.inMinutes < 1) return 'Just now';
      if (d.inMinutes < 60) return '${d.inMinutes} min ago';
      if (d.inHours < 24) return '${d.inHours} hour${d.inHours == 1 ? '' : 's'} ago';
      if (d.inDays == 1) return 'Yesterday';
      return '${d.inDays} days ago';
    }

    // Due reminders always show on top.
    final due = s.store.todayQueue.where((i) => i.whenTs <= DateTime.now().millisecondsSinceEpoch).toList();
    return StatefulBuilder(builder: (ctx, set) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle('Notifications', action: s.store.unreadNotes > 0 ? 'Mark all read' : null, onAction: () {
          s.store.markNotesRead();
          set(() {});
        }),
        if (due.isEmpty && notes.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 30), child: Text('Nothing new. Lil will ping you when an idea is due.', textAlign: TextAlign.center, style: t(14, FontWeight.w600, ll.ink3))),
        for (final it in due)
          _noteRow(ll, icon: 'bell', blue: true, unread: true, text: '“${it.title}” is due now', sub: 'Reminder', onTap: () {
            Navigator.pop(ctx);
            s.app.openReminder(it);
          }),
        for (final n in notes.where((n) => n.itemId.isEmpty || !due.any((d) => d.id == n.itemId)))
          _noteRow(ll, icon: n.icon, blue: n.icon == 'bell', unread: n.unread, text: n.text, sub: ago(n.ts), onTap: () {
            final it = s.store.byId(n.itemId);
            if (it != null && !it.isDone) {
              Navigator.pop(ctx);
              s.app.openReminder(it);
            }
          }),
      ]);
    });
  });
  s.store.markNotesRead();
}

Widget _noteRow(LL ll, {required String icon, required bool blue, required bool unread, required String text, required String sub, VoidCallback? onTap}) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: blue ? ll.blueSoft : ll.surface2), child: LLIcon(icon, size: 18, color: blue ? ll.blueInk : ll.ink2)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (unread) Container(width: 7, height: 7, margin: const EdgeInsets.only(top: 7, right: 7), decoration: BoxDecoration(shape: BoxShape.circle, color: ll.blue)),
                Expanded(child: Text(text, style: t(14.5, FontWeight.w600, ll.ink, h: 1.4))),
              ]),
              const SizedBox(height: 2),
              Text(sub, style: t(12.5, FontWeight.w600, ll.ink3)),
            ]),
          ),
        ]),
      ),
    );
