import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models.dart';
import '../data/store.dart';

/// Cloud sync with the same Firestore layout as v1.2:
///   /users/{email}         { name, email, backupPayload: json, lastSeenAt }
///   /collab_folders/{cid}  { version, payload: json{folder, items, deletedIds, updatedAt} }
class SyncService {
  SyncService(this.store, {required this.enabled});

  final AppStore store;
  final bool enabled;
  StreamSubscription? _userSub, _changeSub;
  final Map<String, StreamSubscription> _collabSubs = {};
  final Map<String, Set<String>> _knownIds = {};
  Timer? _debounce;
  String _email = '';
  bool _firstPull = true;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  void start(String email) {
    if (!enabled || email.isEmpty) return;
    stop();
    _email = email.toLowerCase();
    _firstPull = true;
    _userSub = _db.collection('users').doc(_email).snapshots().listen(_onUser, onError: (_) {});
    _changeSub = store.changes.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 1500), pushAll);
    });
    _watchCollabs();
  }

  void stop() {
    _userSub?.cancel();
    _changeSub?.cancel();
    _debounce?.cancel();
    for (final s in _collabSubs.values) {
      s.cancel();
    }
    _collabSubs.clear();
    _knownIds.clear();
    _email = '';
  }

  Future<void> flush() async {
    _debounce?.cancel();
    await pushAll();
  }

  // ---------------------------------------------------------------------------
  // Personal backup

  void _onUser(DocumentSnapshot<Map<String, dynamic>> snap) {
    final raw = snap.data()?['backupPayload'];
    var changed = false;
    if (raw is String && raw.isNotEmpty) {
      try {
        changed = store.mergeRemote(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    if (changed) {
      store.savedFromRemote();
      _watchCollabs();
    }
    if (_firstPull) {
      _firstPull = false;
      // Upload anything that only exists on this phone (e.g. saved as a guest).
      _pushUser();
    }
  }

  Future<void> pushAll() async {
    if (_email.isEmpty) return;
    _watchCollabs();
    await _pushUser();
    for (final f in store.folders.where((f) => f.collab && f.collabId.isNotEmpty)) {
      await _pushCollab(f);
    }
  }

  Future<void> _pushUser() async {
    if (_email.isEmpty) return;
    final payload = store.toJson();
    payload['items'] = store.items.map((i) => i.toJson()..['thumbnail'] = i.thumbnail.startsWith('data:') ? '' : i.thumbnail).toList();
    final body = jsonEncode(payload);
    if (body.length > 880000) return; // Firestore rule caps backupPayload at 900k
    try {
      await _db.collection('users').doc(_email).set({
        'name': store.userName.isEmpty ? _email.split('@').first : store.userName,
        'email': _email,
        'backupPayload': body,
        'lastSeenAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Shared folders

  void _watchCollabs() {
    if (_email.isEmpty) return;
    final want = {for (final f in store.folders.where((f) => f.collab && f.collabId.isNotEmpty)) f.collabId};
    for (final cid in _collabSubs.keys.toList()) {
      if (!want.contains(cid)) _collabSubs.remove(cid)?.cancel();
    }
    for (final cid in want) {
      _collabSubs[cid] ??= _db.collection('collab_folders').doc(cid).snapshots().listen((s) => _onCollab(cid, s), onError: (_) {});
    }
  }

  Folder? _folderFor(String cid) {
    for (final f in store.folders) {
      if (f.collabId == cid) return f;
    }
    return null;
  }

  void _onCollab(String cid, DocumentSnapshot<Map<String, dynamic>> snap) {
    final f = _folderFor(cid);
    if (f == null) return;
    final raw = snap.data()?['payload'];
    if (raw is! String || raw.isEmpty) {
      _pushCollab(f);
      return;
    }
    Map<String, dynamic> p;
    try {
      p = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (_applyCollab(f, p)) store.savedFromRemote();
  }

  bool _applyCollab(Folder f, Map<String, dynamic> p) {
    var changed = false;
    final rf = (p['folder'] as Map?) ?? {};
    for (final k in ['ownerEmail', 'ownerName']) {
      if ((rf[k] ?? '').toString().isNotEmpty && f.extra[k] != rf[k]) {
        f.extra[k] = rf[k];
        changed = true;
      }
    }
    final collabs = _mergeCollaborators([...((rf['collaborators'] as List?) ?? []), ...f.collaborators], f.ownerEmail);
    if (jsonEncode(collabs) != jsonEncode(f.collaborators)) {
      f.extra['collaborators'] = collabs;
      changed = true;
    }
    final del = {...((f.extra['deletedIds'] as List?) ?? []).map((e) => '$e'), ...((p['deletedIds'] as List?) ?? []).map((e) => '$e')};
    f.extra['deletedIds'] = del.toList();
    final before = store.items.length;
    store.items.removeWhere((i) => i.folder.toLowerCase() == f.name.toLowerCase() && del.contains(i.id));
    if (store.items.length != before) changed = true;

    final known = _knownIds.putIfAbsent(f.collabId, () => {});
    for (final m in ((p['items'] as List?) ?? []).whereType<Map>()) {
      final ri = Item.fromJson(m.cast<String, dynamic>())..folder = f.name;
      if (ri.id.isEmpty || del.contains(ri.id) || store.deletedIds.contains(ri.id)) continue;
      known.add(ri.id);
      final li = store.byId(ri.id);
      if (li == null) {
        store.items.insert(0, ri);
        if (!_firstCollabPull(f.collabId)) store.addNote(Note(text: 'New in ${f.name}: “${ri.title}”', icon: 'users', itemId: ri.id), save: false);
        changed = true;
      } else if (ri.updatedAt > li.updatedAt) {
        // Merge to-do steps so a tick on one phone never gets undone by another.
        if (li.kind == ItemKind.todoList) {
          final byId = {for (final t in ri.tasks) t.id: t};
          for (final lt in li.tasks) {
            final rt = byId[lt.id];
            if (rt == null || lt.updatedAt > rt.updatedAt) byId[lt.id] = lt;
          }
          ri.tasks = byId.values.toList();
        }
        store.items[store.items.indexOf(li)] = ri;
        changed = true;
      }
    }
    _seen.add(f.collabId);
    return changed;
  }

  final Set<String> _seen = {};
  bool _firstCollabPull(String cid) => !_seen.contains(cid);

  List<Map<String, dynamic>> _mergeCollaborators(List raw, String ownerEmail) {
    final byKey = <String, Map<String, dynamic>>{};
    for (final c in raw.whereType<Map>()) {
      final email = '${c['email'] ?? ''}'.trim().toLowerCase();
      final name = '${c['name'] ?? ''}'.trim();
      if (!email.contains('@') || email == ownerEmail.toLowerCase()) continue;
      final ex = byKey[email];
      if (ex == null || (ex['name'] == email.split('@').first && name.isNotEmpty)) {
        byKey[email] = {'name': name.isEmpty ? email.split('@').first : name, 'email': email, 'addedAt': c['addedAt'] ?? DateTime.now().millisecondsSinceEpoch};
      }
    }
    return byKey.values.toList();
  }

  Future<void> _pushCollab(Folder f) async {
    if (_email.isEmpty || f.collabId.isEmpty) return;
    final known = _knownIds[f.collabId] ?? {};
    final del = {...((f.extra['deletedIds'] as List?) ?? []).map((e) => '$e'), ...store.deletedIds.where(known.contains)};
    f.extra['deletedIds'] = del.toList();
    final mine = f.ownerEmail.toLowerCase() == _email;
    final collabs = _mergeCollaborators([
      ...f.collaborators,
      if (!mine) {'name': store.userName, 'email': _email},
    ], f.ownerEmail);
    f.extra['collaborators'] = collabs;
    final its = store.inFolder(f.name).where((i) => !del.contains(i.id)).map((i) => i.toJson()..['folder'] = f.name).toList();
    known.addAll(its.map((e) => '${e['id']}'));
    _knownIds[f.collabId] = known;
    final payload = jsonEncode({
      'folder': {
        'name': f.name,
        'kind': 'folder',
        'icon': f.icon,
        'collab': true,
        'collabId': f.collabId,
        'ownerEmail': f.ownerEmail,
        'ownerName': f.ownerName,
        'collaborators': collabs,
      },
      'items': its,
      'deletedIds': del.toList(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    if (payload.length > 880000) return;
    try {
      await _db.collection('collab_folders').doc(f.collabId).set({'version': DateTime.now().millisecondsSinceEpoch, 'payload': payload});
    } catch (_) {}
  }

  /// Turn a folder into a shared one. Returns the collab id.
  Future<String> share(Folder f) async {
    if (f.collabId.isEmpty) {
      final slug = _email.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
      final rnd = List.generate(6, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[math.Random.secure().nextInt(36)]).join();
      f.collabId = 'cf_${slug}_$rnd';
      f.collab = true;
      f.extra['ownerEmail'] = _email;
      f.extra['ownerName'] = store.userName;
      f.extra['collaborators'] = [];
      _seen.add(f.collabId);
      store.touchFolder();
    }
    _watchCollabs();
    await _pushCollab(f);
    return f.collabId;
  }

  /// Join a shared folder from an invite link. Returns an error message or null.
  Future<String?> join(String cid, {String name = '', String by = ''}) async {
    if (_email.isEmpty) return 'Sign in to join shared folders.';
    if (!RegExp(r'^cf_[a-z0-9_]+$').hasMatch(cid)) return 'That invite link looks broken.';
    if (_folderFor(cid) != null) return null;
    try {
      final snap = await _db.collection('collab_folders').doc(cid).get();
      final raw = snap.data()?['payload'];
      if (raw is! String) return 'That shared folder no longer exists.';
      final p = jsonDecode(raw) as Map<String, dynamic>;
      final rf = (p['folder'] as Map?) ?? {};
      var fname = '${rf['name'] ?? (name.isEmpty ? 'Shared' : name)}';
      if (store.folderNamed(fname) != null) fname = '$fname (shared)';
      final f = Folder(name: fname, icon: '${rf['icon'] ?? 'folder'}', collab: true, extra: {
        'collabId': cid,
        'ownerEmail': rf['ownerEmail'] ?? '',
        'ownerName': rf['ownerName'] ?? by,
        'collaborators': rf['collaborators'] ?? [],
      });
      store.folders.add(f);
      _seen.add(cid);
      _applyCollab(f, p);
      store.addNote(Note(text: 'You joined ${f.name}', icon: 'users'), save: false);
      store.touchFolder();
      _watchCollabs();
      await _pushCollab(f);
      return null;
    } catch (_) {
      return 'Couldn’t open that shared folder. Check your internet.';
    }
  }
}
