// Turning words into saved things: one reminder, several, a to-do list, or a
// time for a link you already saved. Used by the save sheet and by voice.
import '../data/models.dart';
import '../data/nl.dart';
import '../data/store.dart';
import 'kit.dart';

Item newItem(ItemKind kind, String title, {String folder = '', DateTime? when, List<int> repeat = const [], String url = '', String thumb = '', String note = ''}) {
  final it = Item(id: newId(), kind: kind, title: title, folder: folder, url: url, thumbnail: thumb, note: note);
  if (when != null) it.setWhenTs(when.millisecondsSinceEpoch);
  if (repeat.isNotEmpty) it.repeatDays = repeat;
  return it;
}

/// Default time for a reminder with no time in it: 9 pm today, or tomorrow 9 am late at night.
DateTime defaultReminderTime() {
  final n = AppStore.now();
  final nine = DateTime(n.year, n.month, n.day, 21);
  return nine.isAfter(n.add(const Duration(minutes: 10))) ? nine : DateTime(n.year, n.month, n.day + 1, 9);
}

/// What a sentence would turn into (for previews).
class Plan {
  Plan({this.link, this.split, required this.nl});
  final Item? link;
  final Split? split;
  final NL nl;
}

Plan planFor(AppStore st, String text) {
  final nl = parseNL(text);
  final link = RegExp(r'https?://|www\.').hasMatch(text) ? null : linkTarget(text, st.items, recent: st.recentLink);
  final split = link == null ? splitTasks(text) : null;
  return Plan(link: link, split: split, nl: nl);
}

/// Save [text] as reminders / a list / a link time. [mode] picks 'reminders'
/// or 'list' for sentences with several things. Returns the toast line.
String addFromText(AppScope s, String text, {String? mode, String folder = ''}) {
  final st = s.store;
  final p = planFor(st, text.trim());
  if (p.link != null) {
    final lk = p.link!;
    final when = p.nl.date ?? defaultReminderTime();
    lk.setWhenTs(when.millisecondsSinceEpoch);
    if (p.nl.repeat.isNotEmpty) lk.repeatDays = p.nl.repeat;
    st.touchItem(lk);
    s.app.gain(5);
    final msg = '“${shortText(lk.title, 24)}” comes back ${fmtDay(when).toLowerCase()} ${fmtT(when)}';
    s.toast.show(msg);
    return msg;
  }
  if (p.split != null) {
    final sp = p.split!;
    final m = mode ?? sp.def;
    final made = <Item>[];
    if (m == 'list') {
      final first = sp.parts.map((x) => x.nl.date).whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
      final it = newItem(ItemKind.todoList, sp.listTitle, folder: folder, when: first);
      it.tasks = [
        for (final x in sp.parts) TodoTask(id: newId(), text: x.timed && x.nl.date != null ? '${x.title} · ${fmtT(x.nl.date!)}' : x.title),
      ];
      made.add(it);
    } else {
      NL? last;
      for (final x in sp.parts) {
        final r = x.nl.found ? x.nl : last;
        if (x.nl.found) last = x.nl;
        made.add(newItem(ItemKind.reminder, x.title, folder: folder, when: r?.date ?? defaultReminderTime(), repeat: r?.repeat ?? const []));
      }
    }
    for (final it in made.reversed) {
      st.addItem(it);
    }
    s.app.gain(5 * made.length);
    final msg = m == 'list' ? 'Added a to-do list · ${made.first.tasks.length} steps' : 'Added ${made.length} reminders';
    s.toast.show(msg, undo: () {
      for (final it in made) {
        st.deleteItem(it.id);
      }
    });
    return msg;
  }
  final title = cleanTitle(p.nl.found ? p.nl.title : text);
  final when = p.nl.date ?? defaultReminderTime();
  final it = newItem(ItemKind.reminder, title.isEmpty ? text.trim() : title, folder: folder, when: when, repeat: p.nl.repeat);
  st.addItem(it);
  s.app.gain(5);
  final msg = 'Added · ${fmtDay(when)}, ${fmtT(when)}${p.nl.repeat.isNotEmpty ? ' · ${p.nl.repeatText.toLowerCase()}' : ''}';
  s.toast.show(msg, undo: () => st.deleteItem(it.id));
  return msg;
}
