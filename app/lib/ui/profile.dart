// Profile: your name, your buddy, settings.
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../data/store.dart';
import '../widgets/kit.dart' show confirmSheet;
import '../theme/tokens.dart';
import 'kit.dart';
import 'sheets.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final st = s.store;
    final top = MediaQuery.paddingOf(context).top;
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final name = st.userName.isEmpty ? 'You' : st.userName;
        final monthDone = st.revisitedTotal;
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(0, top + 22, 0, 150),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(children: [
                Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(34, FontWeight.w600, ll.ink, ls: -.03))),
                const SizedBox(width: 8),
                RoundBtn(icon: 'edit', size: 34, iconSize: 15, label: 'Edit your name', onTap: () => renameSheet(context, RenameWho.me)),
                const Spacer(),
                Container(width: 44, height: 44, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: ll.ink), child: Text(name[0].toUpperCase(), style: t(17, FontWeight.w600, ll.onInk))),
              ]),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(22, 4, 22, 0), child: Text(st.signedIn ? st.userEmail : 'Saving on this phone only', style: t(15, FontWeight.w400, ll.ink2))),
            if (!st.signedIn)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Surface(
                  padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                  child: Row(children: [
                    Expanded(child: Text('Sign in to back up, sync with your laptop, and share folders with friends.', style: t(13, FontWeight.w400, ll.ink2, h: 1.4))),
                    const SizedBox(width: 10),
                    SizedBox(width: 96, child: AccentBtn(label: 'Sign in', height: 40, onTap: s.app.startSignIn)),
                  ]),
                ),
              ),
            // Your buddy
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Tap(
                scale: .98,
                onTap: () => s.app.openLil(),
                child: Surface(
                  radius: 26,
                  padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
                  child: Stack(children: [
                    Row(children: [
                      const Lil(size: 92),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(child: Text(st.mascotName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(22, FontWeight.w600, ll.ink, ls: -.02))),
                            const SizedBox(width: 6),
                            Tap(onTap: () => renameSheet(context, RenameWho.lil), child: IconTile('edit', size: 30, radius: 15)),
                          ]),
                          const SizedBox(height: 2),
                          Text('${st.level.name} size · ${kLilOutfitName(st.outfitNow)}', style: t(13, FontWeight.w400, ll.ink2)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, children: [
                            _chip(context, 'flame', '${st.streak}', ll.ember),
                            _chip(context, 'heart', '${st.hearts}', LL.heart),
                            _chip(context, 'snow', '${st.freezes}', null),
                          ]),
                        ]),
                      ),
                    ]),
                    if (st.heartsReady > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: ll.blue, borderRadius: BorderRadius.circular(99)), child: Text('Hearts ready', style: t(11, FontWeight.w600, ll.onAccent))),
                      ),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(children: [
                for (final (v, l) in [('${st.streak}', 'day streak'), ('$monthDone', 'done so far'), ('${st.level.n}', 'level')]) ...[
                  if (l != 'day streak') const SizedBox(width: 8),
                  Expanded(
                    child: Tap(
                      onTap: () => s.app.openLil(),
                      child: Surface(
                        radius: 20,
                        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(v, style: t(22, FontWeight.w600, ll.ink)), Text(l, style: t(13, FontWeight.w400, ll.ink2))]),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
            Group(children: [
              SetRow(icon: 'moon', title: 'Light mode', sub: 'Daylight look. Off = Midnight', trailing: Toggle(on: !st.darkTheme, onTap: () => st.setTheme(!st.darkTheme)), onTap: () => st.setTheme(!st.darkTheme)),
              SetRow(icon: 'music', title: 'Reminder sound', sub: '${const ['Lil hello', 'Pop pop', 'Soft chime'][st.tone]} · plays 3 times', trailingText: 'Change', onTap: () => toneSheet(context)),
              SetRow(icon: 'vibe', title: 'Strong vibration', sub: 'A 2 second buzz', trailing: Toggle(on: st.strongVibe, onTap: () => st.setPrefs(vibe: !st.strongVibe)), onTap: () => st.setPrefs(vibe: !st.strongVibe)),
              SetRow(icon: 'quiet', title: 'Quiet hours', sub: st.quietOn ? quietLabel(st) : 'Off', trailing: Toggle(on: st.quietOn, onTap: () => st.setQuiet(on: !st.quietOn)), onTap: () => quietSheet(context)),
              SetRow(
                icon: 'bell',
                title: 'Try a notification',
                sub: 'See how a reminder arrives',
                trailingText: 'Send',
                onTap: () async {
                  final ok = await s.app.reminders.sendTest();
                  s.toast.show(ok ? 'Sent. Another arrives in 10 seconds.' : 'Notifications are off. Allow them for Little Later in phone Settings → Apps.');
                },
              ),
            ]),
            Group(children: [
              SetRow(icon: 'chrome', title: 'Chrome extension', sub: 'Save from your laptop', trailingText: 'Get it', onTap: () => launchUrl(Uri.parse(siteUrl), mode: LaunchMode.externalApplication)),
              SetRow(icon: 'link', title: 'Save from other apps', sub: 'Share from Instagram, YouTube… → Little Later', onTap: () => s.toast.show('In any app, tap Share → Little Later')),
            ]),
            Group(children: [
              if (st.signedIn)
                SetRow(
                  icon: 'user',
                  title: 'Sign out',
                  onTap: () async {
                    if (await confirmSheet(context, title: 'Sign out?', body: 'Your ideas are backed up. They come back when you sign in again.', yes: 'Sign out')) await s.app.signOut();
                  },
                ),
              SetRow(
                icon: 'trash',
                title: st.signedIn ? 'Delete account' : 'Erase everything',
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
            Center(child: Mono('Little Later 2.0', color: ll.ink3)),
          ],
        );
      },
    );
  }

  Widget _chip(BuildContext context, String icon, String v, Color? c) {
    final ll = LL.of(context);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [LLIcon(icon, size: 13, color: c ?? ll.ink), const SizedBox(width: 4), Text(v, style: t(13, FontWeight.w500, ll.ink))]),
    );
  }
}

String kLilOutfitName(int i) => const ['Everyday', 'Cozy scarf', 'Headphones', 'Star crown'][i.clamp(0, 3)];

String quietLabel(AppStore st) {
  String hm(int m) => fmtT(DateTime(2000, 1, 1, m ~/ 60, m % 60));
  return '${hm(st.quietFromMin)} to ${hm(st.quietToMin)}${st.quietDays == 'wk' ? ' · weekdays' : st.quietDays == 'we' ? ' · weekends' : ''}';
}
