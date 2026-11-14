import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../mascot/mascot_svg.dart';
import '../mascot/mascot_view.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';
import '../widgets/kit.dart';
import 'saved_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListenableBuilder(
      listenable: s.store,
      builder: (context, _) {
        final st = s.store;
        final name = st.userName.isEmpty ? (st.guest ? 'Guest' : st.userEmail.split('@').first) : st.userName;
        return ListView(
          padding: EdgeInsets.only(bottom: 130 + bottom),
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            PageHead(right: Circ(icon: 'pen', label: 'Edit name', onTap: () => _editName(context))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [ll.blue2, ll.blue]),
                      boxShadow: [BoxShadow(color: ll.bg, spreadRadius: 5), BoxShadow(color: ll.blue.withValues(alpha: .5), spreadRadius: 7), ...ll.blueGlow(.3, 40, 18)],
                    ),
                    child: Text(name[0].toUpperCase(), style: t(38, FontWeight.w800, Colors.white)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(name, textAlign: TextAlign.center, style: t(24, FontWeight.w800, ll.ink, ls: -.02)),
                const SizedBox(height: 4),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(99), boxShadow: ll.shadow),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: st.signedIn ? const Color(0xFF43D18E) : ll.ink3, boxShadow: st.signedIn ? const [BoxShadow(color: Color(0xFF43D18E), blurRadius: 8)] : null),
                      ),
                      const SizedBox(width: 7),
                      Text(st.signedIn ? st.userEmail : 'Guest, saved on this phone', style: t(12.5, FontWeight.w700, ll.ink2)),
                    ]),
                  ),
                ),
                if (!st.signedIn) ...[
                  const SizedBox(height: 16),
                  Tap(
                    onTap: s.app.startSignIn,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      decoration: BoxDecoration(color: ll.blueSoft, borderRadius: BorderRadius.circular(24)),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Back up your ideas', style: t(14.5, FontWeight.w800, ll.ink)),
                            Text('Guest ideas live only on this phone', style: t(12.5, FontWeight.w600, ll.ink2)),
                          ]),
                        ),
                        Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: ll.blue, borderRadius: BorderRadius.circular(99)),
                          child: Text('Sign in', style: t(13.5, FontWeight.w700, Colors.white)),
                        ),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(28), boxShadow: ll.shadow),
                  child: IntrinsicHeight(
                    child: Row(children: [
                      _stat(ll, st.items.length, 'Saved'),
                      VerticalDivider(color: ll.line, width: 1),
                      _stat(ll, st.folders.length, 'Folders'),
                      VerticalDivider(color: ll.line, width: 1),
                      _stat(ll, st.revisitedTotal, 'Revisited'),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Tap(
                  scale: .97,
                  onTap: () {
                    s.buzz(0);
                    s.app.openLil();
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 18, 12),
                    decoration: BoxDecoration(
                      color: ll.surface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: ll.shadow,
                      gradient: RadialGradient(center: Alignment.centerLeft, radius: 1.4, colors: [ll.blueSoft, ll.surface], stops: const [0, .7]),
                    ),
                    child: Row(children: [
                      SizedBox(width: 60, height: 66, child: MascotView(stage: st.level.n, style: st.mascotStyle, outfit: st.outfitNow, staticMood: Mood.happy, live: false)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(st.mascotName, style: t(16, FontWeight.w800, ll.ink)),
                          const SizedBox(height: 2),
                          Text('${st.streak}-day streak, ${st.hearts} hearts', style: t(12.5, FontWeight.w600, ll.ink2)),
                          const SizedBox(height: 8),
                          Meter(value: st.levelProgress, height: 6),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      LLIcon('chev', size: 18, color: ll.ink3),
                    ]),
                  ),
                ),
                _lab(ll, 'Reminders'),
                Card28(children: [
                  SetRow(
                    icon: 'bell',
                    title: 'Notifications',
                    sub: 'Nudges when an idea is due',
                    trailing: LLToggle(
                      on: st.notifOn,
                      label: 'Notifications',
                      onChanged: (v) async {
                        s.buzz(0);
                        st.setPrefs(notif: v);
                        if (v) await s.app.reminders.askPermission();
                        s.toast.show(v ? 'Notifications on' : 'Notifications off');
                      },
                    ),
                  ),
                  SetRow(
                    icon: 'sunrise',
                    title: 'Morning reminder',
                    sub: 'When “Tomorrow” rings',
                    value: fmtT(DateTime(2000, 1, 1, st.morningHour)),
                    chev: true,
                    onTap: () {
                      const ts = [7, 8, 9, 10];
                      final h = ts[(ts.indexOf(st.morningHour) + 1) % ts.length];
                      st.setPrefs(morning: h);
                      s.buzz(0);
                      s.toast.show('“Tomorrow” now rings at ${fmtT(DateTime(2000, 1, 1, h))}');
                    },
                  ),
                  SetRow(
                    icon: 'moon',
                    title: 'Quiet hours',
                    sub: 'No pings 11 pm to 7 am',
                    trailing: LLToggle(
                      on: st.quietOn,
                      label: 'Quiet hours',
                      onChanged: (v) {
                        s.buzz(0);
                        st.setPrefs(quiet: v);
                        s.toast.show(v ? 'Quiet hours on, 11 pm to 7 am' : 'Quiet hours off');
                      },
                    ),
                  ),
                ]),
                _lab(ll, 'App'),
                Card28(children: [
                  SetRow(
                    icon: 'spark',
                    title: 'Theme',
                    trailing: SizedBox(
                      width: 140,
                      child: Segmented(labels: const ['Dark', 'Light'], index: st.darkTheme ? 0 : 1, height: 40, onChanged: (i) {
                        s.buzz(0);
                        st.setTheme(i == 0);
                      }),
                    ),
                  ),
                  SetRow(
                    icon: 'music',
                    title: 'Haptics',
                    sub: 'Little taps when you do things',
                    trailing: LLToggle(
                      on: st.haptics,
                      label: 'Haptics',
                      onChanged: (v) {
                        st.setPrefs(haptic: v);
                        if (v) HapticFeedback.mediumImpact();
                      },
                    ),
                  ),
                  SetRow(icon: 'link', title: 'Chrome extension', sub: 'Save from your laptop', chev: true, onTap: () => _chrome(context)),
                  SetRow(icon: 'book', title: 'Privacy and terms', chev: true, onTap: () => launchUrl(Uri.parse('$siteUrl/privacy.html'), mode: LaunchMode.externalApplication)),
                ]),
                const SizedBox(height: 12),
                Card28(children: [
                  if (st.signedIn)
                    SetRow(
                      icon: 'back',
                      title: 'Sign out',
                      danger: true,
                      onTap: () async {
                        if (await confirmSheet(context, title: 'Sign out?', body: 'Your ideas are backed up. They come back when you sign in again.', yes: 'Sign out')) {
                          await s.app.signOut();
                        }
                      },
                    ),
                  SetRow(
                    icon: 'trash',
                    title: st.signedIn ? 'Delete account' : 'Erase everything',
                    danger: true,
                    onTap: () async {
                      if (await confirmSheet(
                        context,
                        title: st.signedIn ? 'Delete your account?' : 'Erase everything?',
                        body: st.signedIn ? 'This removes your account and every idea, folder and streak. It can’t be undone.' : 'Every idea, folder and streak on this phone will be gone. It can’t be undone.',
                        yes: st.signedIn ? 'Delete account' : 'Erase',
                      )) {
                        await s.app.signOut(delete: true);
                      }
                    },
                  ),
                ]),
                const SizedBox(height: 20),
                Text('Little Later 1.4', textAlign: TextAlign.center, style: t(12, FontWeight.w600, ll.ink3)),
              ]),
            ),
          ],
        );
      },
    );
  }

  Widget _stat(LL ll, int n, String l) => Expanded(
        child: Column(children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: n.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text('${v.round()}', style: t(24, FontWeight.w800, ll.ink).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          ),
          Text(l, style: t(12.5, FontWeight.w700, ll.ink3)),
        ]),
      );

  Widget _lab(LL ll, String s) => Padding(padding: const EdgeInsets.fromLTRB(6, 24, 6, 10), child: Text(s, style: t(13, FontWeight.w700, ll.ink3)));

  Future<void> _editName(BuildContext context) async {
    final s = AppScope.of(context);
    final c = TextEditingController(text: s.store.userName);
    final n = await showLLSheet<String>(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetTitle('Your name'),
          LLInput(controller: c, hint: 'Your name', icon: 'user', maxLength: 20, autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, v)),
          const SizedBox(height: 16),
          BigButton(label: 'Save', onTap: () => Navigator.pop(ctx, c.text)),
        ]));
    if (n != null && n.trim().isNotEmpty) {
      s.store.setPrefs(name: n);
      s.toast.show('Name updated');
    }
  }

  Future<void> _chrome(BuildContext context) async {
    final s = AppScope.of(context);
    await showLLSheet(context, builder: (ctx) {
      final ll = LL.of(ctx);
      Widget step(String n, String b, String sub) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(children: [
              Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: ll.blueSoft), child: Text(n, style: t(16, FontWeight.w800, ll.blueInk))),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(b, style: t(15, FontWeight.w800, ll.ink)), Text(sub, style: t(13, FontWeight.w500, ll.ink2))])),
            ]),
          );
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SheetTitle('Chrome extension'),
        Card28(children: [
          step('1', 'Open the Little Later site on your laptop', 'harsh-alt-max.github.io/Little-Later-App'),
          step('2', 'Add to Chrome', 'Sign in with the same account as here'),
          step('3', 'Save from any tab', 'It shows up here instantly'),
        ]),
        const SizedBox(height: 16),
        BigButton(
          label: 'Copy link for laptop',
          onTap: () {
            Clipboard.setData(const ClipboardData(text: siteUrl));
            Navigator.pop(ctx);
            s.toast.show('Link copied');
          },
        ),
      ]);
    });
  }
}

/// .bigmeter progress bar.
class Meter extends StatelessWidget {
  const Meter({super.key, required this.value, this.height = 8});
  final double value, height;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        height: height,
        child: Stack(children: [
          Positioned.fill(child: ColoredBox(color: ll.inkMix(.10))),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0, 1)),
            duration: const Duration(milliseconds: 1000),
            curve: Motion.smooth,
            builder: (_, v, _) => FractionallySizedBox(
              widthFactor: v,
              child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), gradient: LinearGradient(colors: [ll.blue, ll.blue2]))),
            ),
          ),
        ]),
      ),
    );
  }
}
