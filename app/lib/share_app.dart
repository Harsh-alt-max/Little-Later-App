import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'data/models.dart';
import 'data/store.dart';
import 'mascot/mascot_view.dart';
import 'screens/save_sheet.dart';
import 'services/auth.dart';
import 'services/haptics.dart';
import 'services/reminders.dart';
import 'services/sync.dart';
import 'theme/tokens.dart';
import 'widgets/common.dart';
import 'widgets/icons.dart';
import 'widgets/kit.dart';

/// Is this shared text a Little Later folder invite?
Uri? inviteIn(String text) {
  final m = RegExp(r'(littlelater://join\?\S+|https?://\S+/join\.html\?\S+)').firstMatch(text);
  if (m == null) return null;
  final u = Uri.tryParse(m.group(0)!);
  return (u?.queryParameters['cid'] ?? '').startsWith('cf_') ? u : null;
}

/// The small card shown over another app when you tap Share → Little Later.
/// It never opens the full app: save, and the window closes by itself.
class ShareApp extends StatefulWidget {
  const ShareApp({super.key, required this.store, required this.text, required this.auth, required this.sync, required this.reminders});
  final AppStore store;
  final String text;
  final AuthService auth;
  final SyncService sync;
  final Reminders reminders;
  @override
  State<ShareApp> createState() => _ShareAppState();
}

class _ShareAppState extends State<ShareApp> implements AppActions {
  final _toast = ToastController();
  final _hero = MascotController();
  final _heroKey = GlobalKey();
  bool _shown = false;
  Future<void>? _syncReady;
  String? _joinMsg;

  AppStore get store => widget.store;
  @override
  AuthService get auth => widget.auth;
  @override
  SyncService get sync => widget.sync;
  @override
  Reminders get reminders => widget.reminders;

  @override
  void initState() {
    super.initState();
    if (store.signedIn) _syncReady = sync.startAndWait(store.userEmail);
    final invite = inviteIn(widget.text);
    if (invite != null) _join(invite);
    WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _shown = true));
  }

  Future<void> _join(Uri u) async {
    setState(() => _joinMsg = 'Joining “${u.queryParameters['join'] ?? 'folder'}”…');
    if (!store.signedIn) {
      setState(() => _joinMsg = 'Open Little Later and sign in first, then tap the invite again.');
      return;
    }
    await _syncReady;
    final err = await sync.join(u.queryParameters['cid']!, name: u.queryParameters['join'] ?? '', by: u.queryParameters['by'] ?? '');
    await sync.flush();
    if (!mounted) return;
    setState(() => _joinMsg = err ?? 'You joined “${u.queryParameters['join'] ?? 'the folder'}”');
    Haptics.medium();
    Timer(const Duration(milliseconds: 1600), close);
  }

  Future<void> close() async {
    setState(() => _shown = false);
    await Future.delayed(const Duration(milliseconds: 250));
    await SystemNavigator.pop();
  }

  Future<void> _afterSave() async {
    if (!store.signedIn) return;
    await _syncReady;
    // The cloud copy may have been merged in after the item was added; push all.
    await sync.flush().timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  // AppActions used by the share card (the rest belong to the full app).
  @override
  void gain(int n, {String? line}) => store.gainXp(n);
  @override
  void openSave({String url = '', String folder = ''}) {}
  @override
  void openQuickSave(String url) {}
  @override
  void openLil({bool streak = false}) {}
  @override
  void openReminder(Item item) {}
  @override
  void openFolder(Folder f) {}
  @override
  void openNotes() {}
  @override
  Future<void> signOut({bool delete = false}) async {}
  @override
  void startSignIn() {}

  @override
  Widget build(BuildContext context) {
    final ll = store.darkTheme ? LL.darkTheme : LL.light;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(ll).copyWith(scaffoldBackgroundColor: Colors.transparent),
      home: AppScope(
        store: store,
        toast: _toast,
        hero: _hero,
        heroKey: _heroKey,
        goTab: (_) {},
        levelUp: (_, _) {},
        app: this,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: Stack(children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: close,
                child: AnimatedContainer(duration: const Duration(milliseconds: 250), color: Colors.black.withValues(alpha: _shown ? .35 : 0)),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 450),
              curve: Motion.smooth,
              left: 0,
              right: 0,
              bottom: _shown ? 0 : -700,
              child: _joinMsg != null ? _joinCard(ll) : Builder(builder: (_) => QuickSave(text: widget.text, onDone: close, onSaved: _afterSave)),
            ),
            ToastView(controller: _toast, onUndo: () {}),
          ]),
        ),
      ),
    );
  }

  Widget _joinCard(LL ll) => Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, 12 + MediaQueryData.fromView(View.of(context)).padding.bottom),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(30)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            LLIcon('users', size: 30, color: ll.blueInk),
            const SizedBox(height: 10),
            Text(_joinMsg!, textAlign: TextAlign.center, style: t(16, FontWeight.w800, ll.ink)),
            const SizedBox(height: 14),
            BigButton(label: 'Close', height: 50, dark: true, onTap: close),
          ]),
        ),
      );
}
