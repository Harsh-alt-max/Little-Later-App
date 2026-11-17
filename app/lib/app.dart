import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:material_ui/material_ui.dart';

import 'data/models.dart';
import 'data/store.dart';
import 'mascot/mascot_svg.dart';
import 'mascot/mascot_view.dart';
import 'screens/folders_screen.dart';
import 'screens/lil_screen.dart';
import 'screens/onboarding.dart';
import 'screens/profile_screen.dart';
import 'screens/reminder_screen.dart';
import 'screens/save_sheet.dart';
import 'screens/saved_screen.dart';
import 'screens/today_screen.dart';
import 'services/auth.dart';
import 'services/reminders.dart';
import 'services/sync.dart';
import 'services/link_meta.dart';
import 'theme/tokens.dart';
import 'widgets/common.dart';
import 'widgets/dock.dart';
import 'services/haptics.dart';

class Services {
  Services({required this.auth, required this.sync, required this.reminders, this.platform = true});
  final AuthService auth;
  final SyncService sync;
  final Reminders reminders;

  /// False in tests: skips share intents and deep links.
  final bool platform;
}

class LittleLaterApp extends StatelessWidget {
  const LittleLaterApp({super.key, required this.store, required this.services});
  final AppStore store;
  final Services services;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final ll = store.darkTheme ? LL.darkTheme : LL.light;
      return MaterialApp(
        title: 'Little Later',
        debugShowCheckedModeBanner: false,
        // Drag with a mouse too (the web preview), not just fingers.
        scrollBehavior: const MaterialScrollBehavior().copyWith(dragDevices: PointerDeviceKind.values.toSet()),
        theme: buildTheme(ll),
        home: AnnotatedRegion<SystemUiOverlayStyle>(
          value: (ll.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          ),
          child: Shell(store: store, services: services),
        ),
      );
    },
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.store, required this.services});
  final AppStore store;
  final Services services;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver implements AppActions {
  final _toast = ToastController();
  final _hero = MascotController();
  final _heroKey = GlobalKey();
  final _bubble = BubbleController();
  final _todayScroll = ScrollController();
  final _ctx = GlobalKey();
  int _tab = 0, _prevTab = 0;
  bool _searchFocus = false;
  Folder? _folder;
  (Level, Level)? _levelUp;
  bool _sheetOpen = false;
  final List<StreamSubscription> _subs = [];
  String? _pendingJoin;

  AppStore get store => widget.store;
  @override
  AuthService get auth => widget.services.auth;
  @override
  SyncService get sync => widget.services.sync;
  @override
  Reminders get reminders => widget.services.reminders;

  BuildContext get _c => _ctx.currentContext ?? context;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    sync.onShared = reminders.sharedAdded;
    if (widget.services.platform) Future<void>.delayed(const Duration(seconds: 3), () => backfillCovers(store));
    if (store.signedIn) sync.start(store.userEmail);
    _subs.add(reminders.tapped.listen(_openReminderId));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (store.onboarded && store.notifOn) reminders.askPermission();
      final id = reminders.launchItemId;
      if (id != null) _openReminderId(id);
    });
    if (widget.services.platform) _listenPlatform();
  }

  void _listenPlatform() {
    // Shares from other apps open the small share window (ShareActivity), not
    // this screen. Here we only handle folder-invite links.
    try {
      final links = AppLinks();
      _subs.add(links.uriLinkStream.listen(_onLink, onError: (_) {}));
    } catch (_) {}
  }

  /// littlelater://join?cid=… or https://…/join.html?cid=…
  void _onLink(Uri u) {
    final cid = u.queryParameters['cid'] ?? '';
    if (cid.isEmpty) return;
    if (!store.signedIn) {
      _pendingJoin = u.toString();
      _toast.show('Sign in to join “${u.queryParameters['join'] ?? 'the folder'}”');
      if (store.onboarded) startSignIn();
      return;
    }
    _join(u);
  }

  Future<void> _join(Uri u) async {
    final cid = u.queryParameters['cid'] ?? '';
    final err = await sync.join(cid, name: u.queryParameters['join'] ?? '', by: u.queryParameters['by'] ?? '');
    if (!mounted) return;
    if (err != null) {
      _toast.show(err);
      return;
    }
    final f = store.folders.where((f) => f.collabId == cid).firstOrNull;
    _toast.show('You joined ${f?.name ?? 'the folder'}');
    if (f != null) openFolder(f);
  }

  void _openReminderId(String id) {
    final it = store.byId(id);
    if (it != null && store.onboarded) openReminder(it);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) sync.flush();
    if (s == AppLifecycleState.resumed) {
      store.reloadFromDisk(); // pick up saves made from the share window
      setState(() {}); // refresh "due now", greeting
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subs) {
      s.cancel();
    }
    _toast.dispose();
    _hero.dispose();
    _bubble.dispose();
    _todayScroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // AppActions

  void _goTab(int i) {
    _searchFocus = i == 11;
    if (i == 11) i = 1;
    if (i == _tab && _folder == null) {
      if (i == 0 && _todayScroll.hasClients) _todayScroll.animateTo(0, duration: const Duration(milliseconds: 400), curve: Motion.smooth);
      return;
    }
    setState(() {
      _prevTab = _tab;
      _tab = i;
      _folder = null;
    });
  }

  @override
  void openSave({String url = '', String folder = ''}) async {
    if (_sheetOpen) {
      Navigator.of(_c).maybePop();
      return;
    }
    setState(() => _sheetOpen = true);
    await openSaveSheet(_c, url: url, folder: folder);
    if (mounted) setState(() => _sheetOpen = false);
  }

  @override
  void openQuickSave(String text) {
    openQuickSave2(text);
  }

  Future<void> openQuickSave2(String text) async {
    // Close anything already open so the quick save sits on top of the app.
    Navigator.of(_c).popUntil((r) => r.isFirst);
    await openQuickSaveSheet(_c, text);
  }

  @override
  void openLil({bool streak = false}) {
    Navigator.of(_c).push(_slideUp(_wrap(LilScreen(scrollToStreak: streak))));
  }

  @override
  void openReminder(Item item) {
    Navigator.of(_c).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => _wrap(ReminderScreen(item: item)),
        transitionsBuilder: (_, a, _, c) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(begin: 1.04, end: 1.0).animate(CurvedAnimation(parent: a, curve: Motion.smooth)),
            child: c,
          ),
        ),
      ),
    );
  }

  @override
  void openFolder(Folder f) {
    setState(() {
      _prevTab = _tab;
      _tab = 2;
      _folder = f;
    });
  }

  @override
  void openNotes() => openNotesSheet(_c);

  @override
  void gain(int n, {String? line}) {
    final (a, b) = store.gainXp(n);
    _hero.play(MascotAct.catchStar);
    _hero.play(MascotAct.hop);
    _hero.mood(Mood.happy, const Duration(milliseconds: 1300));
    if (b.n > a.n) {
      Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _levelUp = (a, b));
      });
    } else if (line != null && _tab == 0) {
      _bubble.say(line);
    }
  }

  @override
  void startSignIn() async {
    final ok = await openAuthSheet(_c);
    if (ok) await _afterSignIn();
  }

  Future<void> _afterSignIn() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final email = (u.email ?? '').toLowerCase();
    store.finishOnboarding(asGuest: false, email: email, name: store.userName.isNotEmpty ? store.userName : (u.displayName ?? email.split('@').first));
    sync.start(email);
    _toast.show('Signed in. Your ideas now sync.');
    if (_pendingJoin != null) {
      final link = Uri.parse(_pendingJoin!);
      _pendingJoin = null;
      await _join(link);
    }
  }

  @override
  Future<void> refresh() async {
    final started = DateTime.now();
    try {
      await store.reloadFromDisk();
      if (store.signedIn) await sync.flush();
      await reminders.reschedule();
      unawaited(backfillCovers(store));
    } catch (_) {}
    final left = const Duration(milliseconds: 700) - DateTime.now().difference(started);
    if (left > Duration.zero) await Future<void>.delayed(left);
  }

  @override
  Future<void> signOut({bool delete = false}) async {
    await sync.flush();
    if (delete && store.signedIn) {
      final err = await auth.deleteAccount();
      if (err != null) {
        _toast.show(err);
        return;
      }
    }
    sync.stop();
    await auth.signOut();
    store.wipe();
    if (mounted) {
      setState(() {
        _tab = 0;
        _folder = null;
      });
    }
  }

  Future<void> _onboardDone({required bool guest}) async {
    Timer(const Duration(milliseconds: 1500), () => reminders.askPermission());
    if (guest) {
      store.finishOnboarding(asGuest: true, name: store.userName);
      setState(() {});
    } else {
      await _afterSignIn();
      if (!store.onboarded) store.finishOnboarding(asGuest: false);
      setState(() {});
    }
    Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _hero.play(MascotAct.hop);
      _hero.mood(Mood.happy, const Duration(milliseconds: 1200));
      _bubble.say(guest ? 'Hi! Saving on this phone.' : 'Nice to meet you!', 2600);
    });
    if (_pendingJoin != null && store.signedIn) {
      final l = Uri.parse(_pendingJoin!);
      _pendingJoin = null;
      _join(l);
    }
  }

  Widget _wrap(Widget child) => _scope(child);

  Route _slideUp(Widget page) => PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 600),
    reverseTransitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, a, _, c) => SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Motion.smooth)),
      child: c,
    ),
  );

  AppScope _scope(Widget child) => AppScope(
    store: store,
    toast: _toast,
    hero: _hero,
    heroKey: _heroKey,
    goTab: _goTab,
    levelUp: (a, b) => setState(() => _levelUp = (a, b)),
    app: this,
    child: Stack(
      children: [
        Positioned.fill(child: child),
        ToastView(controller: _toast, onUndo: _undo),
      ],
    ),
  );

  void _undo() {
    _toast.undo?.call();
    _toast.hide();
    if (store.haptics) Haptics.tick();
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    if (!store.onboarded) {
      return AppScope(
        store: store,
        toast: _toast,
        hero: _hero,
        heroKey: _heroKey,
        goTab: _goTab,
        levelUp: (_, _) {},
        app: this,
        child: Stack(
          key: _ctx,
          children: [
            Positioned.fill(child: Onboarding(onDone: _onboardDone)),
            ToastView(controller: _toast, onUndo: _undo),
          ],
        ),
      );
    }
    // Always show the live folder: data can be reloaded (share card, sync),
    // which replaces folder objects. Match by shared id, then by name.
    if (_folder != null && !store.folders.contains(_folder)) {
      final old = _folder!;
      _folder = store.folders.where((f) => old.collabId.isNotEmpty && f.collabId == old.collabId).firstOrNull ?? store.folderNamed(old.name);
    }
    final forward = _tab > _prevTab || _folder != null;
    final Widget screen = switch (_tab) {
      0 => TodayScreen(key: const ValueKey('today'), scroll: _todayScroll, bubble: _bubble),
      1 => SavedScreen(key: ValueKey('saved$_searchFocus'), autofocus: _searchFocus),
      2 => _folder != null ? FolderDetail(key: ValueKey('fd-${_folder!.name}'), folder: _folder!, onBack: () => setState(() => _folder = null)) : const FoldersScreen(key: ValueKey('folders')),
      _ => const ProfileScreen(key: ValueKey('profile')),
    };

    return PopScope(
      canPop: _tab == 0 && _folder == null,
      onPopInvokedWithResult: (did, _) {
        if (did) return;
        if (_folder != null) {
          setState(() => _folder = null);
        } else {
          _goTab(0);
        }
      },
      child: AppScope(
        store: store,
        toast: _toast,
        hero: _hero,
        heroKey: _heroKey,
        goTab: _goTab,
        levelUp: (a, b) => setState(() => _levelUp = (a, b)),
        app: this,
        child: Scaffold(
          key: _ctx,
          backgroundColor: ll.bg,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              if (ll.dark)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(center: Alignment(0, -.32), radius: .9, colors: [Color(0x0A5A7DFF), Color(0x005A7DFF)], stops: [0, .7]),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Motion.smooth,
                  // Only the incoming screen is shown, so screens never overlap.
                  layoutBuilder: (current, _) => current ?? const SizedBox(),
                  transitionBuilder: (child, anim) {
                    final dx = forward ? 40.0 : -30.0;
                    return AnimatedBuilder(
                      animation: anim,
                      builder: (_, c) => Opacity(
                        opacity: anim.value,
                        child: Transform.translate(offset: Offset(dx * (1 - anim.value), 0), child: c),
                      ),
                      child: child,
                    );
                  },
                  child: screen,
                ),
              ),
              if (MediaQuery.viewInsetsOf(context).bottom == 0)
                Builder(
                  builder: (context) => Dock(
                    index: _tab,
                    plusOpen: _sheetOpen,
                    onTab: (i) {
                      AppScope.of(context).buzz(0);
                      _goTab(i);
                    },
                    onPlus: () => openSave(folder: _folder?.name ?? ''),
                  ),
                ),
              // Keeps scrolled content from showing under the status bar.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: MediaQuery.paddingOf(context).top + 14,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, .7, 1],
                        colors: [ll.bg, ll.bg.withValues(alpha: .85), ll.bg.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
              ToastView(controller: _toast, onUndo: _undo),
              if (_levelUp != null)
                Positioned.fill(
                  child: LevelUpOverlay(
                    from: _levelUp!.$1,
                    to: _levelUp!.$2,
                    name: store.mascotName,
                    style: store.mascotStyle,
                    outfit: store.outfitNow,
                    onContinue: () {
                      setState(() => _levelUp = null);
                      _hero.play(MascotAct.hop);
                      _hero.mood(Mood.happy, const Duration(milliseconds: 1200));
                      _bubble.say('Look at me!');
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// v7 .lu: full-screen "Lil grew bigger!" with the evolve flash.
class LevelUpOverlay extends StatefulWidget {
  const LevelUpOverlay({super.key, required this.from, required this.to, required this.name, required this.style, required this.outfit, required this.onContinue});
  final Level from, to;
  final String name;
  final MascotStyle style;
  final int outfit;
  final VoidCallback onContinue;

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _evolve = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool _grown = false;
  bool _on = false;

  @override
  void initState() {
    super.initState();
    Haptics.heavy();
    scheduleMicrotask(() => setState(() => _on = true));
    Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      _evolve.forward(from: 0);
      Timer(const Duration(milliseconds: 380), () {
        if (mounted) setState(() => _grown = true);
      });
    });
  }

  @override
  void dispose() {
    _evolve.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return AnimatedOpacity(
      opacity: _on ? 1 : 0,
      duration: const Duration(milliseconds: 450),
      child: Container(
        decoration: BoxDecoration(
          color: ll.bg,
          gradient: RadialGradient(center: const Alignment(0, -.24), radius: .8, colors: [ll.headA, ll.bg], stops: const [0, .7]),
        ),
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _evolve,
              builder: (_, child) {
                final v = _evolve.value;
                final s = v < .35
                    ? 1 - .18 * (v / .35)
                    : v < .6
                    ? .82 + .28 * ((v - .35) / .25)
                    : 1.1 - .1 * ((v - .6) / .4);
                final glow = v < .35
                    ? v / .35
                    : v < .6
                    ? 1 - (v - .35) / .25
                    : 0.0;
                return Transform.scale(
                  scale: _evolve.isAnimating ? s : 1,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: .6 * glow), BlendMode.srcATop),
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                width: 210,
                height: 230,
                child: MascotView(stage: _grown ? widget.to.n : widget.from.n, style: widget.style, outfit: widget.outfit, staticMood: _grown ? Mood.happy : Mood.wow, live: false),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(color: ll.blueSoft, borderRadius: BorderRadius.circular(99)),
              child: Text('Size ${widget.to.n} of 5', style: t(12.5, FontWeight.w700, ll.blueInk)),
            ),
            const SizedBox(height: 10),
            Text('${widget.name} grew bigger!', textAlign: TextAlign.center, style: t(30, FontWeight.w800, ll.ink, ls: -.03)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text('Now ${widget.to.name} size. Every idea you save and finish helps ${widget.name} grow.', textAlign: TextAlign.center, style: t(15, FontWeight.w500, ll.ink2, h: 1.5)),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: widget.onContinue,
              child: Container(
                width: 230,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: ll.blue, borderRadius: BorderRadius.circular(99), boxShadow: ll.blueGlow(.35, 30, 14)),
                child: Text('Continue', style: t(16.5, FontWeight.w800, Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
