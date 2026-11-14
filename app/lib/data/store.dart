import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mascot/mascot_svg.dart';
import 'models.dart';

class Level {
  const Level(this.n, this.name, this.min);
  final int n;
  final String name;
  final int min;
}

const kLevels = [Level(1, 'Tiny', 0), Level(2, 'Little', 50), Level(3, 'Growing', 150), Level(4, 'Big', 300), Level(5, 'Mega', 500)];

/// Streak days on which hearts can be collected (v7 MILES).
const kMiles = [3, 5, 10, 21, 33];

/// Outfit names per style and heart cost per outfit slot (v7 OUTFITS / COST).
const kOutfits = {
  MascotStyle.girl: ['Everyday', 'Cozy cardigan', 'Starlight dress'],
  MascotStyle.teen: ['Everyday', 'Hoodie and beats', 'Space explorer'],
  MascotStyle.man: ['Everyday', 'Weekend flannel', 'Sharp suit'],
};
const kOutfitCost = [0, 10, 23];

Level levelOf(int xp) => kLevels.lastWhere((l) => xp >= l.min);

String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String newId() => '${DateTime.now().millisecondsSinceEpoch}${math.Random().nextInt(9999).toString().padLeft(4, '0')}';

class HiResult {
  const HiResult(this.streak, this.line, {this.freezeEarned = false, this.freezesUsed = 0});
  final int streak;
  final String line;
  final bool freezeEarned;
  final int freezesUsed;
}

/// In-app notification (bell sheet).
class Note {
  Note({required this.text, required this.icon, int? ts, this.unread = true, this.itemId = '', this.avatar = ''}) : ts = ts ?? DateTime.now().millisecondsSinceEpoch;
  final String text, icon, itemId, avatar;
  final int ts;
  bool unread;
  factory Note.fromJson(Map j) =>
      Note(text: '${j['text']}', icon: '${j['icon'] ?? 'bell'}', ts: (j['ts'] as num?)?.toInt(), unread: j['unread'] == true, itemId: '${j['itemId'] ?? ''}', avatar: '${j['avatar'] ?? ''}');
  Map<String, dynamic> toJson() => {'text': text, 'icon': icon, 'ts': ts, 'unread': unread, 'itemId': itemId, 'avatar': avatar};
}

/// Single source of truth. Persists locally; [changes] fires on every local edit
/// so cloud sync and reminder scheduling can follow.
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs);

  static const _key = 'll4_state_v1';
  final SharedPreferences? _prefs;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  List<Item> items = [];
  List<Folder> folders = defaultFolders();
  List<String> deletedIds = [];
  List<Note> notes = [];

  static List<Folder> defaultFolders() => [Folder(name: 'Work', kind: 'work'), Folder(name: 'Love', kind: 'love'), Folder(name: 'Hobby', kind: 'hobby')];

  // Account & prefs
  bool onboarded = false;
  String userName = '';
  String userEmail = '';
  bool guest = true;
  bool darkTheme = true;
  bool haptics = true;
  bool notifOn = true;
  bool quietOn = true;
  int morningHour = 9;
  int localUpdatedAt = 0;

  // Game
  int xp = 0;
  int doneToday = 0;
  String doneDay = '';
  int revisitedTotal = 0;
  int streak = 0;
  String lastHiDay = '';
  int freezes = 0;
  int hearts = 0;
  List<int> collected = [];
  List<int> ownedOutfits = [0];

  // Mascot
  String mascotName = 'Lil';
  MascotStyle mascotStyle = MascotStyle.girl;
  Map<MascotStyle, int> outfit = {MascotStyle.girl: 0, MascotStyle.teen: 0, MascotStyle.man: 0};

  static DateTime Function() now = DateTime.now;

  static Future<AppStore> load({bool demo = false}) async {
    SharedPreferences? p;
    try {
      p = await SharedPreferences.getInstance();
    } catch (_) {}
    final s = AppStore._(p);
    final raw = p?.getString(_key);
    if (raw != null) {
      try {
        s.fromJson(jsonDecode(raw) as Map<String, dynamic>, includeAccount: true);
      } catch (_) {}
    } else if (demo) {
      s.seedDemo();
    }
    s._rollover();
    return s;
  }

  factory AppStore.memory() => AppStore._(null);

  // ---------------------------------------------------------------------------
  // Derived

  bool get signedIn => !guest && userEmail.isNotEmpty;
  Level get level => levelOf(xp);
  Level? get nextLevel => level.n < kLevels.length ? kLevels[level.n] : null;
  double get levelProgress {
    final n = nextLevel;
    return n == null ? 1 : (xp - level.min) / (n.min - level.min);
  }

  bool get hiToday => lastHiDay == dayKey(now());
  int get outfitNow => outfit[mascotStyle] ?? 0;
  int get unreadNotes => notes.where((n) => n.unread).length;

  List<Item> get todayQueue {
    _rollover();
    final n = now();
    final end = DateTime(n.year, n.month, n.day + 1).millisecondsSinceEpoch;
    return items.where((i) => !i.isDone && i.whenTs > 0 && i.whenTs < end).toList()..sort((a, b) => a.whenTs.compareTo(b.whenTs));
  }

  int get todayTotal => todayQueue.length + doneToday;

  List<Item> inFolder(String name) => items.where((i) => i.folder.toLowerCase() == name.toLowerCase()).toList();
  int folderCount(String name) => items.where((i) => !i.isDone && i.folder.toLowerCase() == name.toLowerCase()).length;

  Folder? folderNamed(String name) {
    for (final f in folders) {
      if (f.name.toLowerCase() == name.toLowerCase()) return f;
    }
    return null;
  }

  Item? byId(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  int get heartsReady {
    var prev = 0, sum = 0;
    for (final m in kMiles) {
      if (streak >= m && !collected.contains(m)) sum += m - prev;
      prev = m;
    }
    return sum;
  }

  int? get nextMile {
    for (final m in kMiles) {
      if (!collected.contains(m) && streak < m) return m;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Items

  void addItem(Item it) {
    items.insert(0, it);
    _save();
  }

  void touchItem(Item it) {
    it.updatedAt = now().millisecondsSinceEpoch;
    _save();
  }

  VoidCallback deleteItem(String id) {
    final i = items.indexWhere((x) => x.id == id);
    if (i < 0) return () {};
    final it = items.removeAt(i);
    deletedIds.add(id);
    _save();
    return () {
      deletedIds.remove(id);
      items.insert(math.min(i, items.length), it);
      it.updatedAt = now().millisecondsSinceEpoch;
      _save();
    };
  }

  void moveItem(String id, String folder) {
    final it = byId(id);
    if (it == null) return;
    it.folder = folder;
    touchItem(it);
  }

  void setWhen(String id, DateTime? d) {
    final it = byId(id);
    if (it == null) return;
    final ts = d?.millisecondsSinceEpoch ?? 0;
    if (it.kind == ItemKind.todoList) {
      it.dueAt = ts;
      it.reminder = 0;
    } else {
      it.reminder = ts;
      if (ts > 0 && it.kind == ItemKind.link && it.url.isEmpty) it.kind = ItemKind.reminder;
    }
    it.completedAt = 0;
    touchItem(it);
  }

  VoidCallback complete(String id) {
    final it = byId(id)!;
    _rollover();
    final n = now();
    final wasToday = it.whenTs > 0 && it.whenTs < DateTime(n.year, n.month, n.day + 1).millisecondsSinceEpoch;
    it.completedAt = n.millisecondsSinceEpoch;
    it.updatedAt = it.completedAt;
    if (wasToday) doneToday++;
    revisitedTotal++;
    _save();
    return () {
      it.completedAt = 0;
      it.updatedAt = now().millisecondsSinceEpoch;
      if (wasToday && doneToday > 0) doneToday--;
      if (revisitedTotal > 0) revisitedTotal--;
      _save();
    };
  }

  VoidCallback snoozeToTomorrow(String id) {
    final it = byId(id)!;
    final oldR = it.reminder, oldD = it.dueAt;
    final n = now();
    final t = DateTime(n.year, n.month, n.day + 1, morningHour).millisecondsSinceEpoch;
    if (it.reminder > 0 || it.dueAt == 0) {
      it.reminder = t;
    } else {
      it.dueAt = t;
    }
    touchItem(it);
    return () {
      it.reminder = oldR;
      it.dueAt = oldD;
      touchItem(it);
    };
  }

  void snoozeTo(String id, DateTime d) {
    final it = byId(id);
    if (it == null) return;
    if (it.reminder > 0 || it.dueAt == 0) {
      it.reminder = d.millisecondsSinceEpoch;
    } else {
      it.dueAt = d.millisecondsSinceEpoch;
    }
    touchItem(it);
  }

  void toggleTask(String itemId, String taskId) {
    final it = byId(itemId);
    if (it == null) return;
    for (final t in it.tasks) {
      if (t.id == taskId) {
        t.done = !t.done;
        t.updatedAt = now().millisecondsSinceEpoch;
      }
    }
    touchItem(it);
  }

  void addTask(String itemId, String text) {
    final it = byId(itemId);
    if (it == null || text.trim().isEmpty) return;
    it.tasks.add(TodoTask(id: '$itemId-${newId()}', text: text.trim()));
    touchItem(it);
  }

  // ---------------------------------------------------------------------------
  // Folders

  Folder addFolder(String name, String icon, {bool collab = false}) {
    var n = name.trim();
    var k = 2;
    while (folderNamed(n) != null) {
      n = '${name.trim()} ${k++}';
    }
    final f = Folder(name: n, icon: icon, collab: collab);
    folders.add(f);
    _save();
    return f;
  }

  void renameFolder(Folder f, String name) {
    final old = f.name;
    final n = name.trim();
    if (n.isEmpty || n == old) return;
    for (final it in items) {
      if (it.folder.toLowerCase() == old.toLowerCase()) {
        it.folder = n;
        it.updatedAt = now().millisecondsSinceEpoch;
      }
    }
    f.name = n;
    _save();
  }

  VoidCallback deleteFolder(Folder f) {
    final idx = folders.indexOf(f);
    folders.remove(f);
    final moved = items.where((i) => i.folder.toLowerCase() == f.name.toLowerCase()).toList();
    for (final it in moved) {
      it.folder = '';
      it.updatedAt = now().millisecondsSinceEpoch;
    }
    _save();
    return () {
      folders.insert(math.min(idx, folders.length), f);
      for (final it in moved) {
        it.folder = f.name;
        it.updatedAt = now().millisecondsSinceEpoch;
      }
      _save();
    };
  }

  void touchFolder() => _save();

  // ---------------------------------------------------------------------------
  // Game

  (Level, Level) gainXp(int n) {
    final a = level;
    xp = math.max(0, xp + n);
    if (level.n > a.n) addNote(Note(text: 'You reached level ${level.n}, ${level.name}', icon: 'spark'), save: false);
    _save();
    return (a, level);
  }

  HiResult? sayHi() {
    final n = now();
    final today = dayKey(n);
    if (lastHiDay == today) return null;
    var used = 0;
    if (lastHiDay.isEmpty) {
      streak = 1;
    } else {
      final last = DateTime.tryParse(lastHiDay) ?? n;
      final gap = DateTime(n.year, n.month, n.day).difference(DateTime(last.year, last.month, last.day)).inDays;
      if (gap == 1) {
        streak++;
      } else if (gap > 1 && freezes >= gap - 1) {
        used = gap - 1;
        freezes -= used;
        streak++;
      } else {
        streak = 1;
      }
    }
    lastHiDay = today;
    var earned = false;
    var line = userName.isEmpty ? 'Hi! Day $streak' : 'Hi ${userName.split(' ').first}! Day $streak';
    if (streak % 5 == 0) {
      freezes++;
      earned = true;
      line = 'Day $streak! You earned a streak freeze';
    }
    if (kMiles.contains(streak)) line = 'Day $streak! Hearts are ready, tap me';
    _save();
    return HiResult(streak, line, freezeEarned: earned, freezesUsed: used);
  }

  /// Collect the hearts for milestone [m]. Returns hearts gained (0 if not ready).
  int collect(int m) {
    if (streak < m || collected.contains(m)) return 0;
    var prev = 0;
    for (final x in kMiles) {
      if (x == m) break;
      prev = x;
    }
    final amt = m - prev;
    collected.add(m);
    hearts += amt;
    _save();
    return amt;
  }

  bool canUnlock(int i) => !ownedOutfits.contains(i) && (i == 0 || ownedOutfits.contains(i - 1)) && hearts >= kOutfitCost[i];

  bool unlock(int i) {
    if (!canUnlock(i)) return false;
    hearts -= kOutfitCost[i];
    ownedOutfits.add(i);
    outfit[mascotStyle] = i;
    _save();
    return true;
  }

  void wear(int i) {
    if (!ownedOutfits.contains(i)) return;
    outfit[mascotStyle] = i;
    _save();
  }

  void setStyle(MascotStyle s) {
    mascotStyle = s;
    _save();
  }

  void setMascotName(String n) {
    if (n.trim().isEmpty) return;
    mascotName = n.trim();
    _save();
  }

  // ---------------------------------------------------------------------------
  // Account, prefs, notes

  void addNote(Note n, {bool save = true}) {
    notes.insert(0, n);
    if (notes.length > 40) notes = notes.sublist(0, 40);
    if (save) _save();
  }

  void markNotesRead() {
    for (final n in notes) {
      n.unread = false;
    }
    _save();
  }

  void finishOnboarding({required bool asGuest, String name = '', String email = ''}) {
    onboarded = true;
    guest = asGuest;
    if (name.isNotEmpty) userName = name;
    userEmail = email.toLowerCase();
    _save();
  }

  /// Clear everything personal (sign out / delete account). Keeps theme.
  void wipe() {
    items = [];
    folders = defaultFolders();
    deletedIds = [];
    notes = [];
    userName = '';
    userEmail = '';
    guest = true;
    onboarded = false;
    xp = doneToday = revisitedTotal = streak = freezes = hearts = 0;
    lastHiDay = '';
    collected = [];
    ownedOutfits = [0];
    mascotName = 'Lil';
    mascotStyle = MascotStyle.girl;
    outfit = {for (final s in MascotStyle.values) s: 0};
    _save();
  }

  void setPrefs({bool? dark, bool? haptic, bool? notif, bool? quiet, int? morning, String? name}) {
    if (dark != null) darkTheme = dark;
    if (haptic != null) haptics = haptic;
    if (notif != null) notifOn = notif;
    if (quiet != null) quietOn = quiet;
    if (morning != null) morningHour = morning;
    if (name != null && name.trim().isNotEmpty) userName = name.trim();
    _save();
  }

  void setTheme(bool dark) => setPrefs(dark: dark);

  // ---------------------------------------------------------------------------
  // Persistence

  void _rollover() {
    final k = dayKey(now());
    if (doneDay != k) {
      doneDay = k;
      doneToday = 0;
    }
  }

  void _save({bool local = true}) {
    if (local) localUpdatedAt = now().millisecondsSinceEpoch;
    notifyListeners();
    _prefs?.setString(_key, jsonEncode(toJson(includeAccount: true)));
    if (local) _changes.add(null);
  }

  /// Persist after applying a remote change (does not trigger a push back).
  void savedFromRemote() => _save(local: false);

  Map<String, dynamic> toJson({bool includeAccount = false}) => {
        'items': items.map((e) => e.toJson()).toList(),
        'folders': folders.map((e) => e.toJson()).toList(),
        'deletedIds': deletedIds.length > 400 ? deletedIds.sublist(deletedIds.length - 400) : deletedIds,
        'updatedAt': localUpdatedAt,
        if (includeAccount) 'user': {'name': userName, 'email': userEmail, 'guest': guest, 'onboarded': onboarded},
        if (includeAccount) 'notes': notes.map((e) => e.toJson()).toList(),
        'prefs': {'dark': darkTheme, 'haptics': haptics, 'notif': notifOn, 'quiet': quietOn, 'morningHour': morningHour},
        'game': {
          'xp': xp,
          'doneToday': doneToday,
          'doneDay': doneDay,
          'revisited': revisitedTotal,
          'streak': streak,
          'lastHiDay': lastHiDay,
          'freezes': freezes,
          'hearts': hearts,
          'collected': collected,
          'owned': ownedOutfits,
        },
        'mascot': {
          'name': mascotName,
          'style': mascotStyle.name,
          'outfit': {for (final e in outfit.entries) e.key.name: e.value},
        },
      };

  void fromJson(Map<String, dynamic> j, {bool includeAccount = false}) {
    items = ((j['items'] as List?) ?? []).whereType<Map>().map((m) => Item.fromJson(m.cast<String, dynamic>())).toList();
    final fs = ((j['folders'] as List?) ?? []).whereType<Map>().map((m) => Folder.fromJson(m.cast<String, dynamic>())).toList();
    if (fs.isNotEmpty) folders = fs;
    deletedIds = ((j['deletedIds'] as List?) ?? []).map((e) => '$e').toList();
    localUpdatedAt = (j['updatedAt'] as num?)?.toInt() ?? 0;
    if (includeAccount) {
      final u = (j['user'] as Map?) ?? {};
      userName = '${u['name'] ?? ''}';
      userEmail = '${u['email'] ?? ''}';
      guest = u['guest'] != false;
      onboarded = u['onboarded'] == true;
      notes = ((j['notes'] as List?) ?? []).whereType<Map>().map(Note.fromJson).toList();
    }
    _prefsFrom((j['prefs'] as Map?) ?? {});
    _gameFrom((j['game'] as Map?) ?? {});
    _mascotFrom((j['mascot'] as Map?) ?? {});
  }

  void _prefsFrom(Map p) {
    darkTheme = p['dark'] != false;
    haptics = p['haptics'] != false;
    notifOn = p['notif'] != false;
    quietOn = p['quiet'] != false;
    morningHour = (p['morningHour'] as num?)?.toInt() ?? 9;
  }

  void _gameFrom(Map g) {
    xp = (g['xp'] as num?)?.toInt() ?? 0;
    doneToday = (g['doneToday'] as num?)?.toInt() ?? 0;
    doneDay = '${g['doneDay'] ?? ''}';
    revisitedTotal = (g['revisited'] as num?)?.toInt() ?? 0;
    streak = (g['streak'] as num?)?.toInt() ?? 0;
    lastHiDay = '${g['lastHiDay'] ?? ''}';
    freezes = (g['freezes'] as num?)?.toInt() ?? 0;
    hearts = (g['hearts'] as num?)?.toInt() ?? 0;
    collected = ((g['collected'] as List?) ?? []).whereType<num>().map((e) => e.toInt()).toList();
    ownedOutfits = ((g['owned'] as List?) ?? [0]).whereType<num>().map((e) => e.toInt()).toList();
    if (!ownedOutfits.contains(0)) ownedOutfits.insert(0, 0);
  }

  void _mascotFrom(Map m) {
    mascotName = '${m['name'] ?? 'Lil'}';
    mascotStyle = MascotStyle.values.firstWhere((s) => s.name == m['style'], orElse: () => MascotStyle.girl);
    final o = (m['outfit'] as Map?) ?? {};
    for (final s in MascotStyle.values) {
      outfit[s] = (o[s.name] as num?)?.toInt() ?? 0;
    }
  }

  /// Merge a cloud backup (v1.2 or v1.4 shape). Returns true if anything changed.
  bool mergeRemote(Map<String, dynamic> r) {
    var changed = false;
    final remoteAt = (r['updatedAt'] as num?)?.toInt() ?? 0;
    final rDeleted = ((r['deletedIds'] as List?) ?? []).map((e) => '$e').toSet();
    for (final id in rDeleted) {
      if (!deletedIds.contains(id)) {
        deletedIds.add(id);
        changed = true;
      }
    }
    final before = items.length;
    items.removeWhere((i) => rDeleted.contains(i.id));
    if (items.length != before) changed = true;

    for (final m in ((r['folders'] as List?) ?? []).whereType<Map>()) {
      final rf = Folder.fromJson(m.cast<String, dynamic>());
      final lf = folderNamed(rf.name);
      if (lf == null) {
        folders.add(rf);
        changed = true;
      } else if (rf.collab && !lf.collab) {
        lf.collab = true;
        lf.extra.addAll(rf.extra);
        changed = true;
      }
    }
    for (final m in ((r['items'] as List?) ?? []).whereType<Map>()) {
      final ri = Item.fromJson(m.cast<String, dynamic>());
      if (ri.id.isEmpty || deletedIds.contains(ri.id)) continue;
      final li = byId(ri.id);
      if (li == null) {
        items.add(ri);
        changed = true;
      } else if (ri.updatedAt > li.updatedAt) {
        items[items.indexOf(li)] = ri;
        changed = true;
      }
    }
    items.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    if (remoteAt > localUpdatedAt) {
      if (r['game'] is Map) _gameFrom(r['game'] as Map);
      if (r['mascot'] is Map) _mascotFrom(r['mascot'] as Map);
      _rollover();
      changed = true;
    }
    return changed;
  }

  // ---------------------------------------------------------------------------

  void seedDemo() {
    final n = now();
    int at(int dayOff, int h, int m) => DateTime(n.year, n.month, n.day + dayOff, h, m).millisecondsSinceEpoch;
    final soon = DateTime(n.year, n.month, n.day, n.hour + 2, 30);
    final later = DateTime(n.year, n.month, n.day, n.hour + 4);
    folders = [
      Folder(name: 'Hobby', kind: 'hobby'),
      Folder(name: 'Work', kind: 'work'),
      Folder(name: 'Love', kind: 'love'),
      Folder(name: 'Goa trip', kind: 'trip', icon: 'plane'),
    ];
    items = [
      Item(id: 'd1', kind: ItemKind.link, title: 'Slow-roasted tomato pasta', folder: 'Hobby', url: 'https://youtube.com/watch?v=pasta', reminder: n.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch, note: 'Get basil and cherry tomatoes first.'),
      Item(id: 'd2', kind: ItemKind.link, title: 'Anniversary gift ideas', folder: 'Love', url: 'https://pinterest.com/gifts', reminder: soon.millisecondsSinceEpoch),
      Item(id: 'd3', kind: ItemKind.link, title: 'Q4 roadmap doc to review', folder: 'Work', url: 'https://docs.google.com/document/q4', reminder: later.millisecondsSinceEpoch, note: 'Comments due Friday.'),
      Item(id: 'd4', kind: ItemKind.link, title: 'One-pan lemon garlic chicken', folder: 'Hobby', url: 'https://youtube.com/watch?v=chicken', reminder: at(1, 9, 0)),
      Item(id: 'd5', kind: ItemKind.todoList, title: 'Buy oat milk and basil', folder: 'Hobby', tasks: [TodoTask(id: 't1', text: 'Oat milk'), TodoTask(id: 't2', text: 'Basil')]),
      Item(id: 'd6', kind: ItemKind.link, title: 'Design systems talk', folder: 'Work', url: 'https://youtube.com/watch?v=ds'),
      Item(id: 'd7', kind: ItemKind.link, title: 'Beach shacks near Palolem', folder: 'Goa trip', url: 'https://instagram.com/p/palolem', reminder: at(3, 10, 0)),
      Item(id: 'd8', kind: ItemKind.link, title: 'Ceramic mug set for Mom', folder: 'Love', url: 'https://etsy.com/mugs'),
      Item(id: 'd9', kind: ItemKind.link, title: 'Pricing page teardown', folder: 'Work', url: 'https://notion.so/pricing', reminder: at(4, 9, 0)),
      Item(id: 'd10', kind: ItemKind.todoList, title: 'Book train tickets', folder: 'Goa trip'),
      Item(id: 'd11', kind: ItemKind.link, title: 'Sourdough starter guide', folder: 'Hobby', url: 'https://kingarthur.com/sourdough', completedAt: at(-2, 10, 0)),
    ];
    onboarded = true;
    userName = 'Aarav';
    guest = false;
    xp = 140;
    doneToday = 1;
    doneDay = dayKey(n);
    revisitedTotal = 23;
    streak = 9;
    lastHiDay = dayKey(n.subtract(const Duration(days: 1)));
    freezes = 3;
    hearts = 5;
    collected = [3, 5];
    notes = [
      Note(text: '“Slow-roasted tomato pasta” is due now', icon: 'bell', itemId: 'd1'),
      Note(text: 'You reached level 2, Little', icon: 'spark', unread: false, ts: at(-1, 18, 0)),
    ];
  }
}
