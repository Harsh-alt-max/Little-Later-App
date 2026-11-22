// What the voice panel is about to add, as rows you can change: tap a row to
// fix its words or time, remove it, or add another with "+".
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/nl.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import 'actions.dart';
import 'kit.dart';

class Draft {
  Draft(this.title, {this.when, this.repeat = const []});
  String title;
  DateTime? when;
  List<int> repeat;
  Draft copy() => Draft(title, when: when, repeat: repeat);
}

/// Rows for [text]: several things, one thing, or nothing.
({List<Draft> rows, String listTitle, String mode}) draftsFor(AppStore st, String text) {
  final v = text.trim();
  if (v.isEmpty) return (rows: <Draft>[], listTitle: '', mode: 'reminders');
  final p = planFor(st, v);
  final sp = p.split;
  if (sp != null) {
    return (rows: [for (final x in sp.parts) Draft(x.title, when: x.nl.found ? x.nl.date : null, repeat: x.nl.found ? x.nl.repeat : const [])], listTitle: sp.listTitle, mode: sp.def);
  }
  final title = cleanTitle(p.nl.found ? p.nl.title : v);
  return (rows: [Draft(title.isEmpty ? v : title, when: p.nl.date, repeat: p.nl.repeat)], listTitle: '', mode: 'reminders');
}

/// Reminders need a time: a row without one uses the time before it, or the default.
List<DateTime> reminderTimes(List<Draft> rows) {
  final out = <DateTime>[];
  DateTime? last;
  for (final d in rows) {
    final w = d.when ?? last ?? defaultReminderTime();
    if (d.when != null) last = d.when;
    out.add(w);
  }
  return out;
}

String _when(DateTime d) => '${fmtDay(d)}, ${fmtT(d)}';

/// Save the rows. Returns the toast line.
String addDrafts(AppScope s, List<Draft> rows, {required String mode, required String listTitle, String folder = ''}) {
  final st = s.store;
  final made = <Item>[];
  if (mode == 'list') {
    final times = rows.map((d) => d.when).whereType<DateTime>();
    final first = times.fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
    final it = newItem(ItemKind.todoList, listTitle.trim().isEmpty ? 'To-do list' : listTitle.trim(), folder: folder, when: first);
    it.tasks = [for (final d in rows) TodoTask(id: newId(), text: d.when != null ? '${d.title} · ${fmtT(d.when!)}' : d.title)];
    made.add(it);
  } else {
    final times = reminderTimes(rows);
    for (var i = 0; i < rows.length; i++) {
      made.add(newItem(ItemKind.reminder, rows[i].title, folder: folder, when: times[i], repeat: rows[i].repeat));
    }
  }
  for (final it in made.reversed) {
    st.addItem(it);
  }
  s.app.gain(5 * made.length);
  final msg = mode == 'list'
      ? 'Added a to-do list · ${rows.length} ${rows.length == 1 ? 'step' : 'steps'}'
      : made.length == 1
      ? 'Added · ${_when(DateTime.fromMillisecondsSinceEpoch(made.first.whenTs))}'
      : 'Added ${made.length} reminders';
  s.toast.show(
    msg,
    undo: () {
      for (final it in made) {
        st.deleteItem(it.id);
      }
    },
  );
  return msg;
}

/// The rows, with reminders / to-do list tabs and a "+" row at the end.
class DraftList extends StatelessWidget {
  const DraftList({super.key, required this.rows, required this.mode, required this.listTitle, required this.onMode, required this.onEdit, required this.onAdd, required this.onRename});
  final List<Draft> rows;
  final String mode, listTitle;
  final ValueChanged<String> onMode;
  final ValueChanged<int> onEdit;
  final VoidCallback onAdd, onRename;

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final list = mode == 'list';
    final times = reminderTimes(rows);
    Widget row({required Widget lead, required String title, String right = '', bool step = false, bool head = false, Color? rightColor, VoidCallback? onTap, String? key}) => Tap(
      key: key == null ? null : ValueKey(key),
      scale: .98,
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(left: step ? 18 : 0, top: 3),
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(13)),
        child: Row(
          children: [
            lead,
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t(15, head ? FontWeight.w600 : FontWeight.w500, ll.ink)),
            ),
            if (right.isNotEmpty) ...[const SizedBox(width: 8), Text(right, style: t(13, FontWeight.w500, rightColor ?? ll.blueInk))],
          ],
        ),
      ),
    );
    final circle = Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ll.ink3, width: 1.5),
      ),
    );
    final n = rows.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (n > 0) ...[
          SegTabs(options: [('reminders', n == 1 ? '1 reminder' : '$n reminders'), ('list', '1 to-do list')], value: mode, onChanged: onMode, height: 38),
          const SizedBox(height: 4),
        ],
        if (list && n > 0)
          row(
            lead: Opacity(opacity: .7, child: LLIcon('todo', size: 16, color: ll.ink)),
            title: listTitle.isEmpty ? 'To-do list' : listTitle,
            right: '$n ${n == 1 ? 'step' : 'steps'}',
            head: true,
            onTap: onRename,
            key: 'draft-head',
          ),
        for (var i = 0; i < n; i++)
          list
              ? row(lead: circle, title: rows[i].title, right: rows[i].when == null ? '' : fmtT(rows[i].when!), step: true, onTap: () => onEdit(i), key: 'draft-$i')
              : row(
                  lead: Opacity(opacity: .7, child: LLIcon('bell', size: 16, color: ll.ink)),
                  title: rows[i].title,
                  right: '${_when(times[i])}${rows[i].repeat.isNotEmpty ? ' ↻' : ''}',
                  onTap: () => onEdit(i),
                  key: 'draft-$i',
                ),
        Tap(
          key: const ValueKey('draft-add'),
          scale: .98,
          onTap: onAdd,
          child: Container(
            margin: EdgeInsets.only(left: list && n > 0 ? 18 : 0, top: 3),
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: ll.ink3.withValues(alpha: .35)),
            ),
            child: Row(
              children: [
                LLIcon('plus', size: 16, color: ll.ink2),
                const SizedBox(width: 10),
                Text(list && n > 0 ? 'Add a step' : 'Add a reminder', style: t(15, FontWeight.w500, ll.ink2)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Change one row (or make a new one). Returns the new row, or null when it
/// was removed. Closing the sheet without saving returns [keep].
Future<({Draft? row, bool changed})> editDraftSheet(BuildContext context, {Draft? draft, required bool step, required DateTime suggest}) async {
  final r = await showLLSheet<({Draft? row, bool changed})>(context, (_) => _DraftSheet(draft: draft, step: step, suggest: suggest));
  return r ?? (row: draft, changed: false);
}

class _DraftSheet extends StatefulWidget {
  const _DraftSheet({this.draft, required this.step, required this.suggest});
  final Draft? draft;
  final bool step;
  final DateTime suggest;
  @override
  State<_DraftSheet> createState() => _DraftSheetState();
}

class _DraftSheetState extends State<_DraftSheet> {
  late final _title = TextEditingController(text: widget.draft?.title ?? '');
  late DateTime? _at = widget.draft != null ? widget.draft!.when : (widget.step ? null : widget.suggest);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final v = _title.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (v.isEmpty) return;
    final d = (widget.draft?.copy() ?? Draft(v))
      ..title = v
      ..when = _at;
    Navigator.of(context).pop((row: d, changed: true));
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final isNew = widget.draft == null;
    final shown = _at ?? (widget.step ? null : widget.suggest);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(isNew ? (widget.step ? 'New step' : 'New reminder') : (widget.step ? 'Change step' : 'Change reminder')),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(18)),
          child: TextField(
            key: const ValueKey('draft-title'),
            controller: _title,
            autofocus: true,
            minLines: 1,
            maxLines: 3,
            maxLength: 140,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            onChanged: (_) => setState(() {}),
            style: t(18, FontWeight.w600, ll.ink),
            decoration: InputDecoration.collapsed(hintText: widget.step ? 'What to do' : 'What to remember', hintStyle: t(18, FontWeight.w500, ll.ink3)).copyWith(counterText: ''),
          ),
        ),
        const SizedBox(height: 8),
        Tap(
          key: const ValueKey('draft-time'),
          scale: .98,
          onTap: () async {
            final d = await pickDateTime(context, initial: shown ?? widget.suggest);
            if (d != null && mounted) setState(() => _at = d);
          },
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                LLIcon('clock', size: 17, color: shown == null ? ll.ink2 : ll.blueInk),
                const SizedBox(width: 10),
                Expanded(child: Text(shown == null ? 'No time' : _when(shown), style: t(15, FontWeight.w500, shown == null ? ll.ink2 : ll.blueInk))),
                if (widget.step && _at != null)
                  Tap(
                    onTap: () => setState(() => _at = null),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text('No time', style: t(13, FontWeight.w500, ll.ink2)),
                    ),
                  )
                else
                  Text('Change', style: t(13, FontWeight.w500, ll.ink2)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (!isNew) ...[GhostBtn(label: 'Remove', onTap: () => Navigator.of(context).pop((row: null, changed: true))), const SizedBox(width: 8)],
            Expanded(
              child: KeyedSubtree(key: const ValueKey('draft-save'), child: AccentBtn(label: isNew ? 'Add' : 'Done', enabled: _title.text.trim().isNotEmpty, onTap: _save)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Rename the to-do list.
Future<String?> renameListSheet(BuildContext context, String now) => showLLSheet<String>(context, (ctx) {
  final c = TextEditingController(text: now);
  final ll = LL.of(ctx);
  void done() {
    final v = c.text.trim();
    Navigator.of(ctx).pop(v.isEmpty ? null : v);
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SheetHead('List name'),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(18)),
        child: TextField(
          controller: c,
          autofocus: true,
          maxLength: 60,
          onSubmitted: (_) => done(),
          style: t(18, FontWeight.w600, ll.ink),
          decoration: InputDecoration.collapsed(hintText: 'To-do list', hintStyle: t(18, FontWeight.w500, ll.ink3)).copyWith(counterText: ''),
        ),
      ),
      const SizedBox(height: 16),
      AccentBtn(label: 'Done', onTap: done),
    ],
  );
});
