import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_later/app.dart';
import 'package:little_later/data/models.dart';
import 'package:little_later/data/store.dart';
import 'package:little_later/services/festival.dart';
import 'package:little_later/services/auth.dart';
import 'package:little_later/services/reminders.dart';
import 'package:little_later/services/sync.dart';
import 'package:little_later/widgets/common.dart';
import 'package:material_ui/material_ui.dart';

AppStore demoStore({bool dark = true}) {
  AppStore.now = () => DateTime(2026, 11, 14, 13, 30);
  final s = AppStore.memory()..seedDemo();
  s.darkTheme = dark;
  return s;
}

Future<void> pumpApp(WidgetTester tester, AppStore store) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(LittleLaterApp(store: store, services: Services(auth: AuthService(false), sync: SyncService(store, enabled: false), reminders: Reminders(store), platform: false)));
  await settle(tester, 1200);
}

Future<void> settle(WidgetTester tester, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> loadFonts() async {
  final geist = FontLoader('Geist');
  for (final w in ['Regular', 'Medium', 'SemiBold']) {
    geist.addFont(File('assets/fonts/Geist-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await geist.load();
  final mono = FontLoader('GeistMono')..addFont(File('assets/fonts/GeistMono-Medium.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  await mono.load();
}

const shots = bool.fromEnvironment('SHOTS');

Future<void> shot(WidgetTester tester, String name) async {
  if (!shots) return;
  await expectLater(find.byType(LittleLaterApp), matchesGoldenFile('v2shots/$name.png'));
}

void main() {
  setUpAll(loadFonts);

  test('Later moves to tomorrow at the same time', () {
    final s = demoStore();
    final it = s.todayQueue.first;
    final was = DateTime.fromMillisecondsSinceEpoch(it.whenTs);
    s.snoozeToTomorrow(it.id);
    final now = DateTime.fromMillisecondsSinceEpoch(it.whenTs);
    expect(now.day, 15);
    expect(now.hour, was.hour);
    expect(now.minute, was.minute);
  });

  test('quiet hours with minutes and days', () {
    final s = demoStore();
    s.setQuiet(fromMin: 22 * 60 + 30, toMin: 6 * 60 + 30, days: 'all', on: true);
    expect(s.inQuiet(DateTime(2026, 11, 14, 23, 0)), isTrue);
    expect(s.inQuiet(DateTime(2026, 11, 14, 6, 0)), isTrue);
    expect(s.inQuiet(DateTime(2026, 11, 14, 7, 0)), isFalse);
    s.setQuiet(days: 'wk');
    expect(s.inQuiet(DateTime(2026, 11, 14, 23, 0)), isFalse); // Saturday
  });

  for (final dark in [true, false]) {
    final look = dark ? 'midnight' : 'daylight';
    testWidgets('walk through the app ($look)', (tester) async {
      final store = demoStore(dark: dark);
      store.lastHiDay = '2026-11-13';
      store.streak = 9;
      await pumpApp(tester, store);
      await settle(tester, 1200);
      // Streak counted on open.
      expect(find.text('Day 10. Welcome back!'), findsOneWidget);
      await shot(tester, '${look}_0_streak');
      await tester.tap(find.text('Keep going'));
      await settle(tester);
      expect(store.streak, 10);
      await shot(tester, '${look}_1_today');

      // Pull down: Lil peeks.
      final g = await tester.startGesture(tester.getCenter(find.text('Paste a link or type a reminder')));
      for (var i = 0; i < 12; i++) {
        await g.moveBy(const Offset(0, 22));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await shot(tester, '${look}_1b_pull');
      await g.up();
      await settle(tester, 800);

      // The Today bar grows into the save sheet.
      await tester.tap(find.text('Paste a link or type a reminder'));
      await settle(tester, 600);
      await shot(tester, '${look}_2_save');
      await tester.enterText(find.byType(EditableText).first, 'dairy at 7 am and school at 10 pm');
      await settle(tester, 600);
      expect(find.text('2 reminders'), findsOneWidget);
      await shot(tester, '${look}_3_split');
      await tester.ensureVisible(find.text('Add 2'));
      await settle(tester, 300);
      await tester.tap(find.text('Add 2'));
      await settle(tester, 1200);
      expect(store.items.where((i) => i.title == 'Dairy' || i.title == 'School').length, 2);
      await settle(tester, 1200);
      if (find.text('Continue').evaluate().isNotEmpty) {
        await shot(tester, '${look}_3b_levelup');
        await tester.tap(find.text('Continue'));
        await settle(tester, 1200);
      }

      // To-do: steps sit under the title; pick a time; save without a reminder.
      await tester.tap(find.byWidgetPredicate((w) => w.runtimeType.toString() == 'Dock2').first.evaluate().isEmpty ? find.text('x') : find.bySemanticsLabel('Save something').first);
      await settle(tester, 800);
      await tester.tap(find.text('To-do'));
      await settle(tester, 500);
      await shot(tester, '${look}_3c_todo');
      await tester.tap(find.text('Cancel').last);
      await settle(tester, 800);

      await tester.tap(find.bySemanticsLabel('Saved'));
      await settle(tester);
      await shot(tester, '${look}_4_saved');
      await tester.tap(find.bySemanticsLabel('Folders'));
      await settle(tester);
      await shot(tester, '${look}_5_folders');
      await tester.tap(find.bySemanticsLabel('Profile'));
      await settle(tester);
      await shot(tester, '${look}_6_profile');

      // Lil's corner from the flame.
      await tester.tap(find.bySemanticsLabel('Today'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('10 day streak')).first);
      await settle(tester, 1200);
      expect(find.text('day streak'), findsWidgets);
      await shot(tester, '${look}_7_lil');
      await tester.dragUntilVisible(find.text('Star crown'), find.byType(Scrollable).last, const Offset(0, -300));
      await settle(tester, 400);
      await tester.tap(find.text('Star crown'));
      await settle(tester, 900);
      expect(find.text('Not now'), findsOneWidget);
      await shot(tester, '${look}_7b_tryon');
      await tester.tap(find.text('Not now'));
      await settle(tester, 400);
      await tester.tap(find.bySemanticsLabel('Close').first);
      await settle(tester, 1200);

      // Full-screen reminder.
      final it = store.items.firstWhere((i) => i.kind == ItemKind.reminder && !i.isDone);
      final ctx = tester.element(find.text('Paste a link or type a reminder'));
      AppScope.of(ctx).app.openReminder(it);
      await settle(tester, 1200);
      expect(find.text('Did you do it?'), findsOneWidget);
      await shot(tester, '${look}_8_ring');
      await tester.tap(find.text('In 15 min'));
      await settle(tester, 1200);
      // A festival look (downloaded JSON), tried from Profile.
      Festivals.i.useJson('{"festivals":[{"id":"x","name":"Christmas","greeting":"Merry Christmas","accent":"#E5484D","accentInk":"#FF8A8F","hat":"santa","snow":true}]}');
      Festivals.i.preview('x');
      await settle(tester, 800);
      expect(find.textContaining('Merry Christmas'), findsOneWidget);
      await shot(tester, '${look}_9_christmas');
      Festivals.i.preview(null);
      await settle(tester, 300);
    });
  }
}
