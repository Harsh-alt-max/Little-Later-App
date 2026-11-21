// Data models. JSON stays compatible with the v1.2 web app (`ll_items_v1`,
// `ll_folders_v1` and the `backupPayload` in /users/{email}), so cloud sync can
// round-trip without a migration. Unknown keys are preserved in [extra].

class TodoTask {
  TodoTask({required this.id, required this.text, this.done = false, int? updatedAt}) : updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;
  final String id;
  String text;
  bool done;
  int updatedAt;

  factory TodoTask.fromJson(Map<String, dynamic> j) =>
      TodoTask(id: '${j['id']}', text: '${j['text'] ?? ''}', done: j['done'] == true, updatedAt: _int(j['updatedAt']));
  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'done': done, 'updatedAt': updatedAt};
}

enum ItemKind { link, reminder, todoList }

class Item {
  Item({
    required this.id,
    required this.kind,
    required this.title,
    required this.folder,
    this.url = '',
    this.note = '',
    this.thumbnail = '',
    this.reminder = 0,
    this.dueAt = 0,
    List<TodoTask>? tasks,
    int? savedAt,
    int? updatedAt,
    this.completedAt = 0,
    Map<String, dynamic>? extra,
  })  : tasks = tasks ?? [],
        savedAt = savedAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
        extra = extra ?? {};

  final String id;
  ItemKind kind;
  String title;
  String folder; // folder *name*, as in v1.2
  String url;
  String note;
  String thumbnail;
  int reminder; // epoch ms, 0 = none
  int dueAt; // epoch ms, 0 = none (to-dos)
  List<TodoTask> tasks;
  int savedAt;
  int updatedAt;
  int completedAt; // 0 = open
  Map<String, dynamic> extra;

  bool get isDone => completedAt > 0;

  /// The moment this item wants you back (reminder for links/reminders, due for to-dos).
  int get whenTs => reminder > 0 ? reminder : dueAt;

  /// Weekdays this repeats on (1 = Mon … 7 = Sun). Empty = once.
  List<int> get repeatDays => ((extra['repeat'] as List?) ?? const []).map((e) => (e as num).toInt()).where((d) => d >= 1 && d <= 7).toSet().toList()..sort();
  set repeatDays(List<int> d) {
    if (d.isEmpty) {
      extra.remove('repeat');
    } else {
      extra['repeat'] = d.toSet().toList()..sort();
    }
  }
  bool get repeats => repeatDays.isNotEmpty && kind != ItemKind.link && whenTs > 0;

  void setWhenTs(int ts) {
    if (kind == ItemKind.todoList) {
      dueAt = ts;
    } else {
      reminder = ts;
    }
  }

  String get domain {
    if (url.isEmpty) return '';
    final u = Uri.tryParse(url.contains('://') ? url : 'https://$url');
    return (u?.host ?? '').replaceFirst(RegExp(r'^www\.'), '');
  }

  static ItemKind _kind(String? k) => switch (k) {
        'reminder' => ItemKind.reminder,
        'todoList' || 'todo' => ItemKind.todoList,
        _ => ItemKind.link,
      };

  static const _known = {
    'id', 'kind', 'title', 'folder', 'url', 'note', 'thumbnail', 'reminder', 'dueAt', 'tasks', 'savedAt', 'updatedAt', 'completedAt'
  };

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: '${j['id']}',
        kind: _kind(j['kind'] as String?),
        title: '${j['title'] ?? ''}',
        folder: '${j['folder'] ?? ''}',
        url: '${j['url'] ?? ''}',
        note: '${j['note'] ?? ''}',
        thumbnail: '${j['thumbnail'] ?? ''}',
        reminder: _int(j['reminder']),
        dueAt: _int(j['dueAt']),
        tasks: (j['tasks'] is List) ? (j['tasks'] as List).whereType<Map>().map((t) => TodoTask.fromJson(t.cast<String, dynamic>())).toList() : [],
        savedAt: _int(j['savedAt']),
        updatedAt: _int(j['updatedAt']),
        completedAt: _int(j['completedAt']),
        extra: Map.fromEntries(j.entries.where((e) => !_known.contains(e.key))),
      );

  Map<String, dynamic> toJson() => {
        ...extra,
        'id': id,
        'kind': kind.name,
        'title': title,
        'folder': folder,
        'url': url,
        'note': note,
        'thumbnail': thumbnail,
        'reminder': reminder,
        'dueAt': dueAt,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'savedAt': savedAt,
        'updatedAt': updatedAt,
        'completedAt': completedAt,
      };
}

class Folder {
  Folder({required this.name, this.kind = 'folder', this.icon = 'folder', this.collab = false, Map<String, dynamic>? extra}) : extra = extra ?? {};
  String name;
  String kind;
  String icon;
  bool collab;
  Map<String, dynamic> extra; // collabId, ownerEmail, ownerName, collaborators, deletedIds…

  String get collabId => '${extra['collabId'] ?? ''}';
  set collabId(String v) => extra['collabId'] = v;
  String get ownerEmail => '${extra['ownerEmail'] ?? ''}';
  String get ownerName => '${extra['ownerName'] ?? ''}';

  List<Map<String, dynamic>> get collaborators =>
      (extra['collaborators'] is List) ? (extra['collaborators'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList() : [];

  /// Each folder has its own colour (picked, or a stable default from its name).
  static const palette = [0xFFFF9F7E, 0xFFF5C451, 0xFF7ED492, 0xFF5FC8E8, 0xFF7E8CFF, 0xFFC58BFF, 0xFFFF7FB0, 0xFFB9B4AA];
  int get color {
    final c = extra['color'];
    if (c is int) return c;
    var h = 0;
    for (final u in name.toLowerCase().codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    return palette[h % palette.length];
  }

  set color(int v) => extra['color'] = v;

  /// Icon key for the v7 sprite. v1.2 folders carry a `kind` (work/love/hobby).
  String get iconKey {
    const byKind = {'work': 'bag', 'love': 'heart', 'hobby': 'spark', 'trip': 'plane'};
    if (icon != 'folder' && icon.isNotEmpty) return icon;
    return byKind[kind] ?? 'folder';
  }

  factory Folder.fromJson(Map<String, dynamic> j) => Folder(
        name: '${j['name'] ?? 'Folder'}',
        kind: '${j['kind'] ?? 'folder'}',
        icon: '${j['icon'] ?? 'folder'}',
        collab: j['collab'] == true,
        extra: Map.fromEntries(j.entries.where((e) => !const {'name', 'kind', 'icon', 'collab'}.contains(e.key))),
      );

  Map<String, dynamic> toJson() => {...extra, 'name': name, 'kind': kind, 'icon': icon, 'collab': collab};
}

int _int(Object? v) => v is int ? v : v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;


/// "Every day", "Mon–Fri", "Weekends", or "Mon, Wed, Fri".
String repeatLabel(List<int> d) {
  if (d.isEmpty) return 'Once';
  if (d.length == 7) return 'Every day';
  if (d.length == 5 && !d.contains(6) && !d.contains(7)) return 'Mon–Fri';
  if (d.length == 2 && d.contains(6) && d.contains(7)) return 'Weekends';
  const n = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return d.map((x) => n[x - 1]).join(', ');
}

/// The next time on one of [days] at [base]'s clock time, at or after [from].
DateTime nextRepeat(DateTime base, List<int> days, DateTime from) {
  for (var i = 0; i < 8; i++) {
    final d = DateTime(from.year, from.month, from.day + i, base.hour, base.minute);
    if (days.contains(d.weekday) && !d.isBefore(from)) return d;
  }
  return base;
}
