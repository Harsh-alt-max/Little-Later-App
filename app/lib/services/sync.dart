import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/store.dart';

/// Cloud sync with the same Firestore layout as v1.2:
///   /users/{email}         { name, email, backupPayload: json, lastSeenAt }
///   /collab_folders/{cid}  { version, payload: json{folder, items, deletedIds, updatedAt} }
class SyncService {
  SyncService(this.store, {required this.enabled});

  final AppStore store;
  final bool enabled;
  StreamSubscription? _userSub, _changeSub, _inviteSub;
  final Map<String, StreamSubscription> _collabSubs = {};
  final Map<String, Set<String>> _knownIds = {};
  Timer? _debounce;
  String _email = '';
  bool _firstPull = true;
  Completer<void>? _firstDone;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Start syncing and wait (up to [timeout]) for the first cloud copy, so a
  /// quick save from the share window never overwrites newer data.
  Future<void> startAndWait(String email, {Duration timeout = const Duration(seconds: 5)}) async {
    start(email);
    final c = _firstDone;
    if (c == null) return;
    await c.future.timeout(timeout, onTimeout: () {});
  }

  void start(String email) {
    if (!enabled || email.isEmpty) return;
    stop();
    _email = email.toLowerCase();
    _firstPull = true;
    _firstDone = Completer<void>();
    _userSub = _db.collection('users').doc(_email).snapshots().listen(_onUser, onError: (_) {});
    // Moves of shared folders (sent when an owner removes someone).
    _inviteSub = _db.collection('user_invites').doc(_email).snapshots().listen(_onInvites, onError: (_) {});
    _changeSub = store.changes.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 1500), pushAll);
    });
    _watchCollabs();
  }

  void stop() {
    _userSub?.cancel();
    _inviteSub?.cancel();
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
      if (!(_firstDone?.isCompleted ?? true)) _firstDone!.complete();
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
    if ((p['folder'] as Map?)?['closed'] == true) {
      _onClosed(f, p);
      return;
    }
    if (_applyCollab(f, p)) store.savedFromRemote();
  }

  /// Someone else added a link / reminder / to-do to a shared folder (never chat).
  void Function(Folder f, Item it)? onShared;

  /// Test hook: apply a shared-folder payload as if it came from the cloud.
  @visibleForTesting
  void debugApplyCollab(String cid, Map<String, dynamic> p, {String me = ''}) {
    if (me.isNotEmpty) _email = me;
    final f = _folderFor(cid);
    if (f == null) return;
    if ((p['folder'] as Map?)?['closed'] == true) {
      _onClosed(f, p);
    } else if (_applyCollab(f, p)) {
      store.savedFromRemote();
    }
  }

  /// The owner removed someone and moved the folder to a new id.
  void _onClosed(Folder f, Map<String, dynamic> p) {
    final removed = ((p['removed'] as List?) ?? []).map((e) => '$e'.toLowerCase());
    if (removed.contains(_email)) {
      // Cut off: keep everything already here as your own, personal folder.
      final name = f.name;
      final owner = f.ownerName;
      f.collab = false;
      for (final k in ['collabId', 'ownerEmail', 'ownerName', 'collaborators', 'deletedIds', 'awaitMove']) {
        f.extra.remove(k);
      }
      _collabSubs.remove('${p['folder']?['collabId'] ?? ''}')?.cancel();
      store.addNote(Note(text: '${owner.isEmpty ? 'The owner' : owner} removed you from $name. It’s now your own folder.', icon: 'users'), save: false);
      store.savedFromRemote();
      store.touchFolder();
      _watchCollabs();
    } else {
      // Still a member: wait for the move notice and don't write to the old copy.
      f.extra['awaitMove'] = true;
    }
  }

  void _onInvites(DocumentSnapshot<Map<String, dynamic>> snap) {
    final raw = snap.data()?['invitesPayload'];
    if (raw is! String) return;
    List moves;
    try {
      moves = jsonDecode(raw) as List;
    } catch (_) {
      return;
    }
    var changed = false;
    for (final m in moves.whereType<Map>()) {
      if (m['type'] != 'move') continue;
      final f = _folderFor('${m['from']}');
      if (f == null) continue;
      f.collabId = '${m['to']}';
      f.extra.remove('awaitMove');
      changed = true;
    }
    if (changed) {
      store.touchFolder();
      _watchCollabs();
    }
  }

  /// Owner only: remove [email] from a shared folder. Everyone else moves to a
  /// fresh folder id the removed person never learns, so they get nothing new.
  /// They keep what they already have, as their own folder.
  Future<String?> removeMember(Folder f, String email) async {
    if (_email.isEmpty || f.collabId.isEmpty) return 'You’re offline.';
    if (f.ownerEmail.toLowerCase() != _email) return 'Only the folder’s owner can remove people.';
    final gone = email.toLowerCase();
    final oldCid = f.collabId;
    final newCid = _newCid();
    final remaining = f.collaborators.where((c) => '${c['email']}'.toLowerCase() != gone).toList();
    try {
      // 1. Tell the old copy who was removed (and close it).
      await _db.collection('collab_folders').doc(oldCid).set({
        'version': DateTime.now().millisecondsSinceEpoch,
        'payload': jsonEncode({
          'folder': {'name': f.name, 'collab': true, 'collabId': oldCid, 'ownerEmail': f.ownerEmail, 'ownerName': f.ownerName, 'closed': true},
          'removed': [gone],
          'items': [],
          'deletedIds': [],
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        }),
      });
      // 2. Move this folder to the new id with the remaining people.
      _collabSubs.remove(oldCid)?.cancel();
      f.collabId = newCid;
      f.extra['collaborators'] = remaining;
      _knownIds[newCid] = _knownIds.remove(oldCid) ?? {};
      _seen.add(newCid);
      store.touchFolder();
      await _pushCollab(f);
      // 3. Privately point each remaining member at the new id.
      final note = jsonEncode([
        {'type': 'move', 'from': oldCid, 'to': newCid, 'name': f.name},
      ]);
      for (final c in remaining) {
        final e = '${c['email']}'.toLowerCase();
        if (!e.contains('@')) continue;
        await _db.collection('user_invites').doc(e).set({'invitesPayload': note, 'updatedAt': DateTime.now().millisecondsSinceEpoch});
      }
      _watchCollabs();
      return null;
    } catch (_) {
      return 'Couldn’t remove them. Check your internet.';
    }
  }

  String _newCid() {
    final slug = _email.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    final rnd = List.generate(8, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[math.Random.secure().nextInt(36)]).join();
    return 'cf_${slug}_$rnd';
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
        if (!_firstCollabPull(f.collabId)) {
          store.addNote(Note(text: 'New in ${f.name}: “${ri.title}”', icon: 'users', itemId: ri.id), save: false);
          final from = '${ri.extra['senderEmail'] ?? ''}';
          if (ri.extra['msg'] != true && from != _email) onShared?.call(f, ri);
        }
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

  /// Why the last shared-folder upload failed (null when it worked).
  String? lastShareError;

  Future<void> _pushCollab(Folder f) async {
    lastShareError = null;
    if (_email.isEmpty || f.collabId.isEmpty || f.extra['awaitMove'] == true) return;
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
      'folder': {'name': f.name, 'kind': 'folder', 'icon': f.icon, 'collab': true, 'collabId': f.collabId, 'ownerEmail': f.ownerEmail, 'ownerName': f.ownerName, 'collaborators': collabs},
      'items': its,
      'deletedIds': del.toList(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    if (payload.length > 880000) {
      lastShareError = 'This folder is too big to share. Move some saves out first.';
      return;
    }
    try {
      await _db.collection('collab_folders').doc(f.collabId).set({'version': DateTime.now().millisecondsSinceEpoch, 'payload': payload});
    } on FirebaseException catch (e) {
      lastShareError = e.code == 'permission-denied'
          ? 'Confirm your email first (check your inbox), or sign in with Google, then share again.'
          : 'Couldn’t share right now. Check your internet and try again.';
    } catch (_) {
      lastShareError = 'Couldn’t share right now. Check your internet and try again.';
    }
  }

  /// Turn a folder into a shared one. Returns the collab id.
  Future<String> share(Folder folder) async {
    // Work on the folder the store holds right now, never a stale copy.
    final f = store.folders.contains(folder) ? folder : (store.folderNamed(folder.name) ?? folder);
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
      var snap = await _db.collection('collab_folders').doc(cid).get();
      if (snap.data()?['payload'] is! String) {
        // The owner may still be uploading it: wait a moment and look again.
        await Future<void>.delayed(const Duration(seconds: 3));
        snap = await _db.collection('collab_folders').doc(cid).get(const GetOptions(source: Source.server));
      }
      final raw = snap.data()?['payload'];
      if (raw is! String) return 'This invite isn’t ready yet. Ask ${by.isEmpty ? 'your friend' : by} to open the folder in Little Later (with internet) and send the link again.';
      final p = jsonDecode(raw) as Map<String, dynamic>;
      final rf = (p['folder'] as Map?) ?? {};
      var fname = '${rf['name'] ?? (name.isEmpty ? 'Shared' : name)}';
      if (store.folderNamed(fname) != null) fname = '$fname (shared)';
      final f = Folder(
        name: fname,
        icon: '${rf['icon'] ?? 'folder'}',
        collab: true,
        extra: {'collabId': cid, 'ownerEmail': rf['ownerEmail'] ?? '', 'ownerName': rf['ownerName'] ?? by, 'collaborators': rf['collaborators'] ?? []},
      );
      store.folders.add(f);
      _seen.add(cid);
      _applyCollab(f, p);
      store.addNote(Note(text: 'You joined ${f.name}', icon: 'users'), save: false);
      store.touchFolder();
      _watchCollabs();
      await _pushCollab(f);
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return 'needs-verify';
      return 'Couldn’t open that shared folder. Check your internet.';
    } catch (_) {
      return 'Couldn’t open that shared folder. Check your internet.';
    }
  }
}
