// Small sheets: rename, reminder sound, quiet hours, notifications.
import 'package:material_ui/material_ui.dart';

import '../data/store.dart';
import '../mascot/mascot_svg.dart';
import '../services/haptics.dart';
import '../theme/tokens.dart';
import 'kit.dart';
import 'profile.dart' show quietLabel;

enum RenameWho { me, lil }

Future<void> renameSheet(BuildContext context, RenameWho who) {
  final st = AppScope.of(context).store;
  final c = TextEditingController(text: who == RenameWho.lil ? st.mascotName : st.userName);
  c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
  return showLLSheet(context, (ctx) {
    final ll = LL.of(ctx);
    final s = AppScope.of(ctx);
    void save() {
      final v = c.text.trim();
      if (v.isEmpty) return;
      if (who == RenameWho.lil) {
        st.setMascotName(v);
        s.toast.show('Say hi to $v!');
      } else {
        st.setPrefs(name: v);
        s.toast.show('Hi $v!');
      }
      Navigator.of(ctx).pop();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetHead(who == RenameWho.lil ? 'Name your buddy' : 'What should we call you?', sub: who == RenameWho.lil ? 'This name shows across the app and on your reminders.' : 'Used in your greeting and in shared folders.'),
      if (who == RenameWho.lil) const Center(child: Lil(size: 96, mood: Mood.happy)),
      const SizedBox(height: 10),
      Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: ll.dark ? ll.surface : Colors.white, borderRadius: BorderRadius.circular(18)),
        alignment: Alignment.centerLeft,
        child: TextField(controller: c, autofocus: true, maxLength: who == RenameWho.lil ? 14 : 24, onSubmitted: (_) => save(), style: t(17, FontWeight.w500, ll.ink), decoration: const InputDecoration.collapsed(hintText: 'Name').copyWith(counterText: '')),
      ),
      const SizedBox(height: 16),
      Row(children: [GhostBtn(label: 'Cancel', onTap: () => Navigator.of(ctx).pop()), const SizedBox(width: 8), Expanded(child: AccentBtn(label: 'Save', onTap: save))]),
    ]);
  });
}

Future<void> toneSheet(BuildContext context) => showLLSheet(context, (ctx) {
      final s = AppScope.of(ctx);
      final st = s.store;
      final ll = LL.of(ctx);
      return ListenableBuilder(
        listenable: st,
        builder: (ctx, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetHead('Reminder sound', sub: 'Tap one to hear it. It plays 3 times when a reminder is due.'),
          Group(margin: EdgeInsets.zero, children: [
            for (final (i, n, d) in [(0, 'Lil hello', 'A soft little hum'), (1, 'Pop pop', 'Two quick pops'), (2, 'Soft chime', 'A gentle bell')])
              SetRow(
                icon: 'music',
                title: n,
                sub: d,
                onTap: () {
                  Haptics.tick();
                  st.setPrefs(tune: i);
                  s.app.reminders.preview(tone: i);
                },
                trailing: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: st.tone == i ? ll.blue : ll.ink3, width: 2)),
                  alignment: Alignment.center,
                  child: st.tone == i ? Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: ll.blue)) : null,
                ),
              ),
          ]),
          const SizedBox(height: 16),
          AccentBtn(label: 'Done', onTap: () => Navigator.of(ctx).pop()),
        ]),
      );
    });

Future<void> quietSheet(BuildContext context) => showLLSheet(context, (ctx) {
      final st = AppScope.of(ctx).store;
      final ll = LL.of(ctx);
      String hm(int m) => fmtT(DateTime(2000, 1, 1, m ~/ 60, m % 60));
      Future<void> pick(bool from) async {
        final m = from ? st.quietFromMin : st.quietToMin;
        final r = await showTimePicker(context: ctx, initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60));
        if (r == null) return;
        from ? st.setQuiet(fromMin: r.hour * 60 + r.minute, on: true) : st.setQuiet(toMin: r.hour * 60 + r.minute, on: true);
      }

      return ListenableBuilder(
        listenable: st,
        builder: (ctx, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetHead('Quiet hours', sub: 'No sound or buzz in this time. Reminders wait until it ends.'),
          Surface(child: SetRow(icon: 'quiet', title: 'Quiet hours', sub: st.quietOn ? 'On' : 'Off', trailing: Toggle(on: st.quietOn, onTap: () => st.setQuiet(on: !st.quietOn)), onTap: () => st.setQuiet(on: !st.quietOn))),
          const SizedBox(height: 10),
          Opacity(
            opacity: st.quietOn ? 1 : .4,
            child: IgnorePointer(
              ignoring: !st.quietOn,
              child: Row(children: [
                for (final from in [true, false]) ...[
                  if (!from) const SizedBox(width: 10),
                  Expanded(
                    child: Tap(
                      onTap: () => pick(from),
                      child: Surface(
                        radius: 18,
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(from ? 'From' : 'To', style: t(13, FontWeight.w500, ll.ink2)),
                          const SizedBox(height: 4),
                          Text(hm(from ? st.quietFromMin : st.quietToMin), style: t(22, FontWeight.w600, ll.ink)),
                        ]),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
          const SheetLabel('Quick picks'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (a, b) in [(22 * 60, 6 * 60), (23 * 60, 7 * 60), (0, 8 * 60)])
              PillChip(label: '${hm(a)} – ${hm(b)}', on: st.quietFromMin == a && st.quietToMin == b, onTap: () => st.setQuiet(fromMin: a, toMin: b, on: true)),
          ]),
          const SheetLabel('Days'),
          Wrap(spacing: 8, children: [
            for (final (v, l) in [('all', 'Every day'), ('wk', 'Weekdays'), ('we', 'Weekends')]) PillChip(label: l, on: st.quietDays == v, onTap: () => st.setQuiet(days: v)),
          ]),
          const SizedBox(height: 18),
          AccentBtn(
            label: 'Save',
            onTap: () {
              Navigator.of(ctx).pop();
              AppScope.of(context).toast.show(st.quietOn ? 'Quiet ${quietLabel(st)}' : 'Quiet hours off');
            },
          ),
        ]),
      );
    });

Future<void> notesSheet(BuildContext context) => showLLSheet(context, (ctx) {
      final s = AppScope.of(ctx);
      final st = s.store;
      final ll = LL.of(ctx);
      final n = AppStore.now();
      String ago(int ts) {
        final d = n.difference(DateTime.fromMillisecondsSinceEpoch(ts));
        if (d.inMinutes < 1) return 'Just now';
        if (d.inMinutes < 60) return '${d.inMinutes} min ago';
        if (d.inHours < 24) return '${d.inHours} h ago';
        if (d.inDays == 1) return 'Yesterday';
        return '${d.inDays} days ago';
      }

      final due = st.todayQueue.where((i) => i.whenTs <= n.millisecondsSinceEpoch).toList();
      return ListenableBuilder(
        listenable: st,
        builder: (ctx, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetHead('Notifications', action: st.unreadNotes > 0 ? 'Mark all read' : null, onAction: st.markNotesRead),
          if (due.isEmpty && st.notes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(children: [const Lil(size: 100, mood: Mood.sleep), const SizedBox(height: 8), Text('Nothing new. ${st.mascotName} is napping.', style: t(15, FontWeight.w400, ll.ink2))]),
            )
          else
            Surface(
              child: Column(children: [
                for (final it in due)
                  _NoteRow(icon: 'bell', text: '“${it.title}” is due now', sub: whenLabel(it), unread: true, onTap: () {
                    Navigator.of(ctx).pop();
                    s.app.openReminder(it);
                  }),
                for (final nt in st.notes.take(30))
                  _NoteRow(
                    icon: nt.icon == 'spark' ? 'star' : nt.icon == 'users' || nt.icon == 'folder' ? 'users' : nt.icon,
                    text: nt.text,
                    sub: ago(nt.ts),
                    unread: nt.unread,
                    onTap: nt.itemId.isEmpty || st.byId(nt.itemId) == null
                        ? null
                        : () {
                            Navigator.of(ctx).pop();
                            s.app.openReminder(st.byId(nt.itemId)!);
                          },
                  ),
              ]),
            ),
          const SizedBox(height: 16),
          AccentBtn(label: 'Close', onTap: () => Navigator.of(ctx).pop()),
        ]),
      );
    });

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.icon, required this.text, required this.sub, this.unread = false, this.onTap});
  final String icon, text, sub;
  final bool unread;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Tap(
      scale: .98,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: unread ? ll.chip : Colors.transparent,
        child: Row(children: [
          IconTile(icon, size: 40, radius: 12),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(text, style: t(15, FontWeight.w500, ll.ink, h: 1.35)), const SizedBox(height: 3), Mono(sub)])),
          if (unread) Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: ll.ember)),
        ]),
      ),
    );
  }
}
