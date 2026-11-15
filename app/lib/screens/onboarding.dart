import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../mascot/mascot_svg.dart';
import '../mascot/mascot_view.dart';
import '../services/auth.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';
import '../widgets/kit.dart';
import '../services/haptics.dart';

/// v7 onboarding: three steps, pick a look and a name, then sign in.
class Onboarding extends StatefulWidget {
  const Onboarding({super.key, required this.onDone, this.startAtAuth = false});
  final void Function({required bool guest}) onDone;
  final bool startAtAuth;
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  int _step = 0;
  final _m = MascotController();
  final _name = TextEditingController();
  bool _authOpen = false;
  bool _guestOpen = false;

  static const _copy = [
    ('Save it now.\nGet back to it later.', 'Links, reminders and to-dos from any app, brought back right when you need them.'),
    ('Share from\nany app', 'Tap Share, pick Little Later. It lands in the right folder.'),
    ('Meet your\nmascot', 'Pick a look. Say hi every day, finish what you save, and it grows with you.'),
  ];

  @override
  void initState() {
    super.initState();
    _authOpen = widget.startAtAuth;
    Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _m.play(MascotAct.hop);
      _m.mood(Mood.happy, const Duration(milliseconds: 1200));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_name.text.isEmpty) _name.text = AppScope.of(context).store.mascotName;
  }

  @override
  void dispose() {
    _m.dispose();
    _name.dispose();
    super.dispose();
  }

  void _go(int s) {
    if (s < 0 || s > 2) return;
    Haptics.tick();
    setState(() => _step = s);
    if (s == 0) _m.play(MascotAct.hop);
    if (s == 1) _m.play(MascotAct.nod);
  }

  void _next() {
    if (_step < 2) {
      _go(_step + 1);
    } else {
      final st = AppScope.of(context).store;
      st.setMascotName(_name.text.trim().isEmpty ? 'Lil' : _name.text);
      setState(() => _authOpen = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final st = AppScope.of(context).store;
    final pad = MediaQuery.paddingOf(context);
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: ll.bg,
      resizeToAvoidBottomInset: false,
      body: Stack(children: [
        Positioned.fill(
          child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -.32), radius: .9, colors: [ll.headA, ll.bg], stops: const [0, .72]))),
        ),
        AnimatedOpacity(
          opacity: _authOpen || _guestOpen ? .35 : 1,
          duration: const Duration(milliseconds: 500),
          child: Column(children: [
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v < -200) _go(_step + 1);
                  if (v > 200) _go(_step - 1);
                },
                child: Stack(children: [
                  Positioned(
                    right: 20,
                    top: 18 + pad.top,
                    child: Tap(
                      onTap: () => setState(() => _authOpen = true),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(99)),
                        child: Text('Skip', style: t(13.5, FontWeight.w800, ll.ink2)),
                      ),
                    ),
                  ),
                  ..._art(ll, st),
                ]),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 26 + (kb > 0 ? kb - pad.bottom + 10 : pad.bottom)),
              child: Column(children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .1), end: Offset.zero).animate(a), child: c)),
                  child: Column(key: ValueKey(_step), children: [
                    Text(_copy[_step].$1, textAlign: TextAlign.center, style: t(30, FontWeight.w800, ll.ink, ls: -.03, h: 1.12)),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(_copy[_step].$2, textAlign: TextAlign.center, style: t(15.5, FontWeight.w500, ll.ink2, h: 1.5)),
                    ),
                  ]),
                ),
                if (_step == 2) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 260,
                    child: LLInput(controller: _name, hint: 'Lil', icon: 'pen', height: 54, maxLength: 12, center: true),
                  ),
                  const SizedBox(height: 6),
                  Text('Name your mascot. You can change it anytime.', style: t(12, FontWeight.w600, ll.ink3)),
                ],
                const SizedBox(height: 22),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < 3; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 450),
                      curve: Motion.spring,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _step ? 24 : 7,
                      height: 7,
                      decoration: BoxDecoration(color: i == _step ? ll.blue : ll.inkMix(.18), borderRadius: BorderRadius.circular(9)),
                    ),
                ]),
                const SizedBox(height: 22),
                BigButton(label: _step == 2 ? 'Get started' : 'Continue', onTap: _next),
              ]),
            ),
          ]),
        ),
        if (_authOpen)
          Positioned.fill(
            child: GestureDetector(onTap: () => setState(() => _authOpen = false), child: const ColoredBox(color: Colors.transparent)),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 600),
          curve: Motion.smooth,
          left: 0,
          right: 0,
          bottom: _authOpen ? 0 : -720,
          child: AuthSheet(
            onDone: () => widget.onDone(guest: false),
            onGuest: () => setState(() {
              _authOpen = false;
              _guestOpen = true;
            }),
          ),
        ),
        if (_guestOpen)
          Positioned.fill(
            child: GuestScreen(
              onSignIn: () => setState(() {
                _guestOpen = false;
                _authOpen = true;
              }),
              onGuest: () => widget.onDone(guest: true),
            ),
          ),
      ]),
    );
  }

  List<Widget> _art(LL ll, dynamic st) {
    final size = MediaQuery.sizeOf(context);
    Widget chip(String icon, String label, double left, double top, double dx, double dy, int delay) => AnimatedPositioned(
          duration: const Duration(milliseconds: 800),
          curve: Motion.spring,
          left: _step == 0 ? left : left + dx,
          top: _step == 0 ? top : top + dy,
          child: AnimatedOpacity(
            opacity: _step == 0 ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            child: _Drift(
              delay: delay,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 13, 8),
                decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(99), boxShadow: ll.shadow),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 26, height: 26, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: ll.blueSoft), child: LLIcon(icon, size: 14, color: ll.blueInk)),
                  const SizedBox(width: 8),
                  Text(label, style: t(13, FontWeight.w800, ll.ink)),
                ]),
              ),
            ),
          ),
        );
    final h = size.height * .55;
    return [
      chip('link', 'Pasta recipe', 22, h * .22, 120, 80, 0),
      chip('heart', 'Gift ideas', size.width - 150, h * .30, -110, 60, 2),
      chip('bag', 'Roadmap doc', 34, h * .62, 110, -60, 1),
      chip('bell', 'Trip reel', size.width - 140, h * .66, -100, -70, 3),
      AnimatedPositioned(
        duration: const Duration(milliseconds: 700),
        curve: _step == 2 ? Motion.smooth : Motion.spring,
        left: size.width / 2 - 105,
        top: _step == 2 ? -260 : h / 2 - 130 + (_step == 1 ? -30 : 0),
        child: AnimatedOpacity(
          opacity: _step == 2 ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          child: SizedBox(width: 210, height: 230, child: MascotView(stage: 1, controller: _m, style: st.mascotStyle as MascotStyle)),
        ),
      ),
      // Step 1: share sheet mock
      AnimatedPositioned(
        duration: const Duration(milliseconds: 600),
        curve: Motion.spring,
        left: size.width / 2 - 135,
        bottom: _step == 1 ? h * .06 : -40,
        child: AnimatedOpacity(
          opacity: _step == 1 ? 1 : 0,
          duration: const Duration(milliseconds: 400),
          child: Container(
            width: 270,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(26), boxShadow: ll.shadow),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.fromLTRB(4, 0, 0, 10), child: Text('Share to', style: t(12, FontWeight.w800, ll.ink3))),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _app(ll, LLIcon('link', size: 20, color: ll.ink3), 'Copy'),
                _app(ll, LLIcon('book', size: 20, color: ll.ink3), 'Notes'),
                _app(ll, SizedBox(width: 34, height: 38, child: MascotView(stage: 1, style: st.mascotStyle as MascotStyle, live: false, staticMood: Mood.happy)), 'Little Later', hi: true),
                _app(ll, LLIcon('dots', size: 20, color: ll.ink3), 'More'),
              ]),
            ]),
          ),
        ),
      ),
      // Step 2: pick a look
      Positioned(
        left: 0,
        right: 0,
        top: h / 2 - 90,
        child: IgnorePointer(
          ignoring: _step != 2,
          child: AnimatedOpacity(
            opacity: _step == 2 ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            child: AnimatedScale(
              scale: _step == 2 ? 1 : .9,
              duration: const Duration(milliseconds: 600),
              curve: Motion.spring,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final s in MascotStyle.values) ...[
                  _Look(
                    style: s,
                    selected: st.mascotStyle == s,
                    onTap: () {
                      Haptics.tick();
                      AppScope.of(context).store.setStyle(s);
                      setState(() {});
                    },
                  ),
                  if (s != MascotStyle.man) const SizedBox(width: 14),
                ],
              ]),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _app(LL ll, Widget icon, String label, {bool hi = false}) => Column(children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: hi ? ll.blue : ll.surface2, borderRadius: BorderRadius.circular(15), boxShadow: hi ? [BoxShadow(color: ll.blueSoft, spreadRadius: 4)] : null),
          child: icon,
        ),
        const SizedBox(height: 6),
        Text(label, style: t(11, FontWeight.w700, hi ? ll.blueInk : ll.ink3)),
      ]);
}

class _Look extends StatelessWidget {
  const _Look({required this.style, required this.selected, required this.onTap});
  final MascotStyle style;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.12 : 1,
        duration: const Duration(milliseconds: 500),
        curve: Motion.spring,
        child: AnimatedOpacity(
          opacity: selected ? 1 : .5,
          duration: const Duration(milliseconds: 300),
          child: Column(children: [
            SizedBox(width: 96, height: 106, child: MascotView(stage: 3, style: style, live: selected, staticMood: selected ? Mood.happy : Mood.idle)),
            const SizedBox(height: 4),
            Text(style.name[0].toUpperCase() + style.name.substring(1), style: t(13, FontWeight.w800, selected ? ll.blueInk : ll.ink2)),
          ]),
        ),
      ),
    );
  }
}

class _Drift extends StatefulWidget {
  const _Drift({required this.child, this.delay = 0});
  final Widget child;
  final int delay;
  @override
  State<_Drift> createState() => _DriftState();
}

class _DriftState extends State<_Drift> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: Duration(milliseconds: 5000 + widget.delay * 500))..repeat();
  @override
  void initState() {
    super.initState();
    c.value = widget.delay / 4;
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, child) => Transform.translate(offset: Offset(0, -8 * (1 - (c.value * 2 - 1).abs())), child: child),
        child: widget.child,
      );
}

// =============================================================================
// Sign-in sheet (.auth)

class AuthSheet extends StatefulWidget {
  const AuthSheet({super.key, required this.onDone, required this.onGuest, this.showGuest = true});
  final VoidCallback onDone, onGuest;
  final bool showGuest;
  @override
  State<AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<AuthSheet> {
  final _m = MascotController();
  final _em = TextEditingController();
  final _pw = TextEditingController();
  final _pwF = FocusNode();
  bool _signUp = false, _show = false, _busy = false, _cover = false, _verify = false;
  bool _emErr = false, _pwErr = false;

  @override
  void initState() {
    super.initState();
    _pwF.addListener(() => setState(() => _cover = _pwF.hasFocus && !_show));
  }

  @override
  void dispose() {
    _m.dispose();
    _em.dispose();
    _pw.dispose();
    _pwF.dispose();
    super.dispose();
  }

  void _shake(String msg) {
    Haptics.heavy();
    _m.mood(Mood.wow, const Duration(milliseconds: 900));
    setState(() => _cover = false);
    AppScope.of(context).toast.show(msg);
    Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _emErr = _pwErr = false);
    });
  }

  Future<void> _email() async {
    final ok1 = RegExp(r'^\S+@\S+\.\S+$').hasMatch(_em.text.trim()), ok2 = _pw.text.length >= 6;
    setState(() {
      _emErr = !ok1;
      _pwErr = !ok2;
    });
    if (!ok1 || !ok2) {
      _shake(!ok1 ? 'That email doesn’t look right.' : 'Password needs at least 6 characters.');
      return;
    }
    setState(() => _busy = true);
    final err = await AppScope.of(context).app.auth.email(_em.text, _pw.text, signUp: _signUp);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == AuthService.verify) {
      setState(() => _verify = true);
      _m.mood(Mood.wow, const Duration(milliseconds: 1200));
      return;
    }
    if (err != null) {
      _shake(err);
      return;
    }
    _success();
  }

  Future<void> _checkVerified() async {
    setState(() => _busy = true);
    final ok = await AppScope.of(context).app.auth.checkVerified();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _success();
    } else {
      _shake('Not verified yet. Open the link in your email first.');
    }
  }

  Future<void> _google() async {
    setState(() => _busy = true);
    final err = await AppScope.of(context).app.auth.google();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == 'cancelled') return;
    if (err != null) {
      _shake(err);
      return;
    }
    _success();
  }

  void _success() {
    Haptics.medium();
    _m.play(MascotAct.hop);
    _m.mood(Mood.happy);
    FocusScope.of(context).unfocus();
    Timer(const Duration(milliseconds: 500), widget.onDone);
  }

  Future<void> _forgot() async {
    final s = AppScope.of(context);
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(_em.text.trim())) {
      setState(() => _emErr = true);
      _shake('Type your email first, then tap Forgot.');
      return;
    }
    final err = await s.app.auth.resetPassword(_em.text);
    s.toast.show(err ?? 'Check your email for a reset link.');
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final st = s.store;
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    final pad = MediaQuery.paddingOf(context).bottom;
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        padding: EdgeInsets.fromLTRB(22, 12, 22, 24 + (kb > 0 ? kb : pad)),
        decoration: BoxDecoration(color: ll.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(36)), boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 50, offset: Offset(0, -20))]),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: ll.inkMix(.18), borderRadius: BorderRadius.circular(9)))),
          Text(_signUp ? 'Create your account' : 'Welcome back', textAlign: TextAlign.center, style: t(24, FontWeight.w800, ll.ink, ls: -.02)),
          const SizedBox(height: 4),
          Text(_signUp ? 'Free. Syncs your phone and Chrome.' : 'Sign in to sync your ideas everywhere', textAlign: TextAlign.center, style: t(14.5, FontWeight.w500, ll.ink2)),
          const SizedBox(height: 18),
          if (_verify) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: ll.blueSoft, borderRadius: BorderRadius.circular(22)),
              child: Column(children: [
                LLIcon('mail', size: 28, color: ll.blueInk),
                const SizedBox(height: 8),
                Text('Check your inbox', style: t(17, FontWeight.w800, ll.ink)),
                const SizedBox(height: 4),
                Text('We sent a link to ${_em.text.trim()}. Tap it to confirm it’s really you, then come back here.', textAlign: TextAlign.center, style: t(13.5, FontWeight.w500, ll.ink2, h: 1.45)),
              ]),
            ),
            const SizedBox(height: 14),
            BigButton(label: _busy ? 'Checking…' : 'I’ve confirmed my email', enabled: !_busy, onTap: _checkVerified),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Tap(
                onTap: () async {
                  await s.app.auth.signOut();
                  setState(() => _verify = false);
                },
                child: Text('Use another email', style: t(14, FontWeight.w800, ll.ink2)),
              ),
              Tap(
                onTap: () async {
                  final e = await s.app.auth.resendVerification();
                  s.toast.show(e ?? 'Sent again. Check spam too.');
                },
                child: Text('Resend link', style: t(14, FontWeight.w800, ll.blueInk)),
              ),
            ]),
          ] else ...[
          ...[
            Tap(
              onTap: _busy ? null : _google,
              child: Container(
                height: 56,
                decoration: BoxDecoration(color: ll.ink, borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 26, height: 26, alignment: Alignment.center, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white), child: Text('G', style: t(15, FontWeight.w800, const Color(0xFF4285F4)))),
                  const SizedBox(width: 10),
                  Text('Continue with Google', style: t(15.5, FontWeight.w800, ll.onInk)),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(children: [
                Expanded(child: Divider(color: ll.line)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or with email', style: t(12.5, FontWeight.w700, ll.ink3))),
                Expanded(child: Divider(color: ll.line)),
              ]),
            ),
          ],
          LLInput(controller: _em, hint: 'Email address', icon: 'mail', keyboard: TextInputType.emailAddress, height: 56, error: _emErr, action: TextInputAction.next),
          const SizedBox(height: 10),
          LLInput(
            controller: _pw,
            focusNode: _pwF,
            hint: 'Password',
            icon: 'lock',
            obscure: !_show,
            height: 56,
            error: _pwErr,
            onSubmitted: (_) => _email(),
            trailing: GestureDetector(
              onTap: () {
                setState(() {
                  _show = !_show;
                  _cover = _pwF.hasFocus && !_show;
                });
                if (_show) _m.mood(Mood.wow, const Duration(milliseconds: 900));
              },
              child: SizedBox(width: 40, height: 40, child: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 19, color: ll.ink3)),
            ),
          ),
          const SizedBox(height: 8),
          BigButton(label: _busy ? 'One moment…' : (_signUp ? 'Create account' : 'Sign in'), enabled: !_busy, onTap: _email),
          const SizedBox(height: 14),
          Row(children: [
            if (widget.showGuest) Tap(onTap: widget.onGuest, child: Text('Continue as guest', style: t(14, FontWeight.w800, ll.ink2))) else Tap(onTap: _forgot, child: Text('Forgot password?', style: t(14, FontWeight.w800, ll.ink2))),
            const Spacer(),
            Text(_signUp ? 'Have an account? ' : 'New here? ', style: t(14, FontWeight.w600, ll.ink2)),
            Tap(
              onTap: () {
                Haptics.tick();
                setState(() => _signUp = !_signUp);
                _m.play(MascotAct.nod);
              },
              child: Text(_signUp ? 'Sign in' : 'Sign up', style: t(14, FontWeight.w800, ll.blueInk)),
            ),
          ]),
          if (widget.showGuest && !_signUp) ...[
            const SizedBox(height: 10),
            Center(child: Tap(onTap: _forgot, child: Text('Forgot password?', style: t(13, FontWeight.w700, ll.ink3)))),
          ],
          ],
        ]),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: -82,
        child: IgnorePointer(child: Center(child: SizedBox(width: 104, height: 114, child: MascotView(stage: st.level.n, controller: _m, style: st.mascotStyle, outfit: st.outfitNow, cover: _cover)))),
      ),
    ]);
  }
}

/// v6 guest warning screen.
class GuestScreen extends StatefulWidget {
  const GuestScreen({super.key, required this.onSignIn, required this.onGuest});
  final VoidCallback onSignIn, onGuest;
  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> {
  final _m = MascotController();
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _m.mood(Mood.wow, const Duration(milliseconds: 1600));
      _m.play(MascotAct.squish);
    });
  }

  @override
  void dispose() {
    _m.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final st = AppScope.of(context).store;
    final pad = MediaQuery.paddingOf(context);
    Widget bn(String icon, String b, String sub) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(children: [
            Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: ll.blueSoft), child: LLIcon(icon, size: 20, color: ll.blueInk)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(b, style: t(15, FontWeight.w800, ll.ink)), Text(sub, style: t(13, FontWeight.w500, ll.ink2))])),
          ]),
        );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Motion.smooth,
      builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 30 * (1 - v)), child: c)),
      child: Container(
        decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -.56), radius: .9, colors: [ll.headA, ll.bg], stops: const [0, .72])),
        padding: EdgeInsets.fromLTRB(22, pad.top, 22, 24 + pad.bottom),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          SizedBox(width: 150, height: 164, child: MascotView(stage: st.level.n, controller: _m, style: st.mascotStyle, outfit: st.outfitNow)),
          const SizedBox(height: 14),
          Text('Saved on this phone only', textAlign: TextAlign.center, style: t(27, FontWeight.w800, ll.ink, ls: -.03, h: 1.15)),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 310),
            child: Text('As a guest, your ideas live on this device. If you delete the app or switch phones, they can’t be recovered.', textAlign: TextAlign.center, style: t(15, FontWeight.w500, ll.ink2, h: 1.5)),
          ),
          const SizedBox(height: 22),
          Card28(children: [
            bn('sync', 'See them everywhere', 'Phone and Chrome stay in sync'),
            bn('users', 'Collab with friends', 'Share folders and save together'),
            bn('book', 'Never lose a thing', 'Backed up to your account'),
          ]),
          const SizedBox(height: 20),
          BigButton(label: 'Sign in', dark: true, onTap: widget.onSignIn),
          Tap(onTap: widget.onGuest, child: SizedBox(height: 52, child: Center(child: Text('Continue as guest', style: t(15, FontWeight.w800, ll.ink2))))),
        ]),
      ),
    );
  }
}

/// Sign-in sheet shown later (from Profile or a feature that needs an account).
Future<bool> openAuthSheet(BuildContext context) async {
  final scope = AppScope.of(context);
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.only(top: 90),
      child: scope.wrap(AuthSheet(showGuest: false, onDone: () => Navigator.pop(ctx, true), onGuest: () => Navigator.pop(ctx, false))),
    ),
  );
  return r == true && FirebaseAuth.instance.currentUser != null;
}
