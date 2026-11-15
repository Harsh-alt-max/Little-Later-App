import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../mascot/mascot_svg.dart';
import '../mascot/mascot_view.dart';
import '../services/reminders.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';
import '../widgets/kit.dart';
import 'saved_screen.dart';
import '../services/haptics.dart';

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
          physics: const ClampingScrollPhysics(),
          children: [
            const PageHead(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [ll.blue2, ll.blue]),
                        boxShadow: [
                          BoxShadow(color: ll.bg, spreadRadius: 5),
                          BoxShadow(color: ll.blue.withValues(alpha: .35), spreadRadius: 6),
                        ],
                      ),
                      child: Text(name[0].toUpperCase(), style: t(38, FontWeight.w800, Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(name, textAlign: TextAlign.center, style: t(24, FontWeight.w800, ll.ink, ls: -.02)),
                  if (!st.signedIn) ...[
                    const SizedBox(height: 16),
                    Tap(
                      onTap: s.app.startSignIn,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                        decoration: BoxDecoration(color: ll.blueSoft, borderRadius: BorderRadius.circular(24)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Back up your ideas', style: t(14.5, FontWeight.w800, ll.ink)),
                                  Text('Guest ideas live only on this phone', style: t(12.5, FontWeight.w600, ll.ink2)),
                                ],
                              ),
                            ),
                            Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: ll.blue, borderRadius: BorderRadius.circular(99)),
                              child: Text('Sign in', style: t(13.5, FontWeight.w700, Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(28), boxShadow: ll.shadow),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          _stat(ll, st.items.length, 'Saved'),
                          VerticalDivider(color: ll.line, width: 1),
                          _stat(ll, st.folders.length, 'Folders'),
                          VerticalDivider(color: ll.line, width: 1),
                          _stat(ll, st.revisitedTotal, 'Revisited'),
                        ],
                      ),
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
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60,
                            height: 66,
                            child: MascotView(stage: st.level.n, style: st.mascotStyle, outfit: st.outfitNow, staticMood: Mood.happy, live: false),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(st.mascotName, style: t(16, FontWeight.w800, ll.ink)),
                                const SizedBox(height: 2),
                                Text('${st.streak}-day streak, ${st.hearts} hearts', style: t(12.5, FontWeight.w600, ll.ink2)),
                                const SizedBox(height: 8),
                                Meter(value: st.levelProgress, height: 6),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          LLIcon('chev', size: 18, color: ll.ink3),
                        ],
                      ),
                    ),
                  ),
                  _lab(ll, 'Reminders'),
                  Card28(
                    children: [
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
                      SetRow(icon: 'music', title: 'Sound', sub: Reminders.toneNames[st.tone], chev: true, onTap: () => _pickTone(context)),
                      SetRow(
                        icon: 'vibe',
                        title: 'Strong vibration',
                        sub: 'A 2 second buzz with each reminder',
                        trailing: LLToggle(
                          on: st.strongVibe,
                          label: 'Strong vibration',
                          onChanged: (v) {
                            s.buzz(0);
                            st.setPrefs(vibe: v);
                            s.app.reminders.reschedule();
                            if (v) Haptics.strong();
                          },
                        ),
                      ),
                      SetRow(
                        icon: 'bell',
                        title: 'Send a test reminder',
                        sub: 'Check notifications reach you',
                        chev: true,
                        onTap: () async {
                          s.buzz(0);
                          final ok = await s.app.reminders.sendTest();
                          s.toast.show(ok ? 'Sent. Another arrives in 10 seconds.' : 'Notifications are blocked. Allow them for Little Later in phone Settings → Apps.');
                        },
                      ),
                      SetRow(
                        icon: 'moon',
                        title: 'Quiet hours',
                        sub: '${fmtT(DateTime(2000, 1, 1, st.quietFrom))} to ${fmtT(DateTime(2000, 1, 1, st.quietTo))}',
                        chev: true,
                        onTap: () => _quietHours(context),
                        trailing: LLToggle(
                          on: st.quietOn,
                          label: 'Quiet hours',
                          onChanged: (v) {
                            s.buzz(0);
                            st.setPrefs(quiet: v);
                            s.toast.show(v ? 'Quiet hours on' : 'Quiet hours off');
                          },
                        ),
                      ),
                    ],
                  ),
                  _lab(ll, 'App'),
                  Card28(
                    children: [
                      SetRow(
                        icon: 'spark',
                        title: 'Theme',
                        trailing: SizedBox(
                          width: 140,
                          child: Segmented(
                            labels: const ['Dark', 'Light'],
                            index: st.darkTheme ? 0 : 1,
                            height: 40,
                            onChanged: (i) {
                              s.buzz(0);
                              st.setTheme(i == 0);
                            },
                          ),
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
                            if (v) Haptics.medium();
                          },
                        ),
                      ),
                      SetRow(
                        icon: 'link',
                        title: 'Chrome extension',
                        sub: 'Save from your laptop',
                        trailing: Tap(
                          onTap: () => launchUrl(Uri.parse('$siteUrl/#chrome'), mode: LaunchMode.externalApplication),
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: ll.blue, borderRadius: BorderRadius.circular(99)),
                            child: Text('Get it', style: t(13, FontWeight.w800, Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card28(
                    children: [
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
                            body: st.signedIn
                                ? 'This removes your account and every idea, folder and streak. It can’t be undone.'
                                : 'Every idea, folder and streak on this phone will be gone. It can’t be undone.',
                            yes: st.signedIn ? 'Delete account' : 'Erase',
                          )) {
                            await s.app.signOut(delete: true);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Little Later 1.4', textAlign: TextAlign.center, style: t(12, FontWeight.w600, ll.ink3)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _stat(LL ll, int n, String l) => Expanded(
    child: Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: n.toDouble()),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => Text('${v.round()}', style: t(24, FontWeight.w800, ll.ink).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        ),
        Text(l, style: t(12.5, FontWeight.w700, ll.ink3)),
      ],
    ),
  );

  Widget _lab(LL ll, String s) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 24, 6, 10),
    child: Text(s, style: t(13, FontWeight.w700, ll.ink3)),
  );

  Future<void> _quietHours(BuildContext context) async {
    final s = AppScope.of(context);
    final st = s.store;
    var from = st.quietFrom, to = st.quietTo;
    final ok = await showLLSheet<bool>(
      context,
      builder: (ctx) {
        final ll = LL.of(ctx);
        Widget wheel(int init, ValueChanged<int> on) => SizedBox(
          width: 130,
          height: 180,
          child: ListWheelScrollView.useDelegate(
            controller: FixedExtentScrollController(initialItem: init),
            itemExtent: 42,
            physics: const FixedExtentScrollPhysics(),
            diameterRatio: 1.5,
            onSelectedItemChanged: (i) {
              Haptics.tick();
              on(i);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: 24,
              builder: (_, i) => Center(child: Text(fmtT(DateTime(2000, 1, 1, i)), style: t(19, FontWeight.w800, ll.ink))),
            ),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetTitle('Quiet hours'),
            Text('No reminders ring in this window. They wait until it ends.', style: t(14, FontWeight.w500, ll.ink2, h: 1.4)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text('From', style: t(13, FontWeight.w700, ll.ink3)),
                    wheel(from, (v) => from = v),
                  ],
                ),
                Column(
                  children: [
                    Text('Until', style: t(13, FontWeight.w700, ll.ink3)),
                    wheel(to, (v) => to = v),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            BigButton(label: 'Save', onTap: () => Navigator.pop(ctx, true)),
          ],
        );
      },
    );
    if (ok == true) {
      st.setPrefs(qFrom: from, qTo: to, quiet: true);
      s.toast.show('Quiet ${fmtT(DateTime(2000, 1, 1, from))} to ${fmtT(DateTime(2000, 1, 1, to))}');
    }
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
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: ll.inkMix(.10))),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.clamp(0, 1)),
              duration: const Duration(milliseconds: 1000),
              curve: Motion.smooth,
              builder: (_, v, _) => FractionallySizedBox(
                widthFactor: v,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    gradient: LinearGradient(colors: [ll.blue, ll.blue2]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _pickTone(BuildContext context) async {
  final s = AppScope.of(context);
  final st = s.store;
  await showLLSheet<void>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final ll = LL.of(ctx);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetTitle('Reminder sound'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
              child: Text('Each sound plays 3 times, so you know it\'s Little Later. Tap one to hear it.', style: t(14, FontWeight.w600, ll.ink3, h: 1.4)),
            ),
            for (var i = 0; i < Reminders.toneNames.length; i++)
              SetRow(
                icon: 'music',
                title: Reminders.toneNames[i],
                sub: const ['Rising and friendly', 'Bouncy and playful', 'Calm two-note chime'][i],
                trailing: st.tone == i ? LLIcon('check', size: 20, color: ll.blueInk) : null,
                onTap: () {
                  s.buzz(0);
                  st.setPrefs(tune: i);
                  set(() {});
                  s.app.reminders.preview(tone: i);
                },
              ),
            const SizedBox(height: 12),
            BigButton(
              label: 'Done',
              onTap: () {
                s.app.reminders.reschedule();
                Navigator.pop(ctx);
              },
            ),
          ],
        );
      },
    ),
  );
}
