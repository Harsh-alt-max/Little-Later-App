import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_later/data/store.dart';
import 'package:little_later/services/auth.dart';
import 'package:little_later/services/reminders.dart';
import 'package:little_later/services/sync.dart';
import 'package:little_later/share_app.dart';

Future<void> go(WidgetTester t, [int ms = 800]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Manrope');
    for (final w in [400, 500, 600, 700, 800]) {
      loader.addFont(File('assets/fonts/Manrope-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await loader.load();
  });

  test('invite links are detected in shared text', () {
    expect(inviteIn('littlelater://join?cid=cf_hks_gmail_com_fpz7uz&join=Work&by=harsh')?.queryParameters['cid'], 'cf_hks_gmail_com_fpz7uz');
    expect(inviteIn('Hey! Join my “Work” folder https://harsh-alt-max.github.io/Little-Later-App/join.html?cid=cf_a_b&join=Work')?.queryParameters['join'], 'Work');
    expect(inviteIn('https://instagram.com/p/xyz'), isNull);
  });

  testWidgets('share card saves a link with a note and folder, without the full app', (t) async {
    AppStore.now = () => DateTime(2026, 11, 14, 13, 30);
    final st = AppStore.memory()
      ..onboarded = true
      ..seedDemo();
    final n = st.items.length;
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(ShareApp(
      store: st,
      text: 'Check this https://www.instagram.com/reel/abc123/',
      auth: AuthService(false),
      sync: SyncService(st, enabled: false),
      reminders: Reminders(st),
    ));
    await go(t, 1200);
    expect(find.text('Save to Little Later'), findsOneWidget);
    expect(find.text('Next up'), findsNothing); // only the card, not the app
    await t.tap(find.text('Add a note'));
    await go(t, 500);
    await t.enterText(find.byType(EditableText).first, 'try this pose');
    await t.tap(find.text('Love'));
    await go(t, 300);
    await t.tap(find.text('Save'));
    await go(t, 2000);
    expect(st.items.length, n + 1);
    final it = st.items.first;
    expect(it.url, 'https://www.instagram.com/reel/abc123/');
    expect(it.note, 'try this pose');
    expect(it.folder, 'Love');
    await go(t, 3000);
  });
}
