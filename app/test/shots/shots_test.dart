// Renders each screen to PNG for visual review: flutter test test/shots --update-goldens
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_later/app.dart';
import 'package:little_later/data/store.dart';
import 'package:little_later/services/auth.dart';
import 'package:little_later/services/reminders.dart';
import 'package:little_later/services/sync.dart';
import 'package:little_later/widgets/common.dart';

Future<void> loadFonts() async {
  final loader = FontLoader('Manrope');
  for (final w in [400, 500, 600, 700, 800]) {
    loader.addFont(File('assets/fonts/Manrope-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await loader.load();
  final m = FontLoader('MaterialIcons')..addFont(File('${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  try {
    await m.load();
  } catch (_) {}
}

Future<void> settle(WidgetTester t, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 2)));
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> shot(WidgetTester t, String name) async {
  await settle(t, 1200);
  await expectLater(find.byType(LittleLaterApp), matchesGoldenFile('out/$name.png'));
}

Future<AppStore> boot(WidgetTester t, {bool demo = true, bool dark = true}) async {
  AppStore.now = () => DateTime(2026, 11, 14, 17, 30);
  final s = AppStore.memory();
  if (demo) s.seedDemo();
  s.darkTheme = dark;
  t.view.physicalSize = const Size(390 * 2, 844 * 2);
  t.view.devicePixelRatio = 2;
  t.view.padding = const FakeViewPadding(top: 48, bottom: 32);
  addTearDown(t.view.reset);
  await t.pumpWidget(LittleLaterApp(store: s, services: Services(auth: AuthService(false), sync: SyncService(s, enabled: false), reminders: Reminders(s), platform: false)));
  await settle(t, 800);
  return s;
}

Future<void> tapCirc(WidgetTester t, String label) async {
  await t.tap(find.byWidgetPredicate((w) => w is Circ && w.label == label).last);
  await settle(t, 900);
}

Future<void> tapSem(WidgetTester t, Pattern label) async {
  await t.tap(find.bySemanticsLabel(label).last);
  await settle(t, 900);
}

void main() {
  setUpAll(loadFonts);
  testWidgets('today dark', (t) async {
    await boot(t);
    await shot(t, '01_today_dark');
  });
  testWidgets('today light', (t) async {
    await boot(t, dark: false);
    await shot(t, '02_today_light');
  });
  testWidgets('save sheet', (t) async {
    await boot(t);
    await tapSem(t, 'Save a new idea');
    await t.enterText(find.byType(EditableText).first, 'https://www.youtube.com/watch/one-pan-lemon-garlic-chicken');
    await settle(t, 900);
    await shot(t, '03_save_link');
    await t.tap(find.text('To-do').last);
    await settle(t, 900);
    await shot(t, '04_save_todo');
  });
  testWidgets('saved', (t) async {
    await boot(t);
    await tapSem(t, 'Saved');
    await t.tap(find.text('Design systems talk'));
    await shot(t, '05_saved');
  });
  testWidgets('saved grid + large', (t) async {
    final s = await boot(t);
    await tapSem(t, 'Saved');
    s.setPrefs(view: 'grid');
    await shot(t, '05b_saved_grid');
    s.setPrefs(view: 'large');
    await shot(t, '05c_saved_large');
  });
  testWidgets('pull to refresh eyes', (t) async {
    await boot(t);
    final g = await t.startGesture(const Offset(200, 300));
    for (var i = 0; i < 24; i++) {
      await g.moveBy(const Offset(0, 16));
      await t.pump(const Duration(milliseconds: 16));
    }
    await expectLater(find.byType(LittleLaterApp), matchesGoldenFile('out/12_pull_eyes.png'));
    await g.up();
    for (var i = 0; i < 9; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    await expectLater(find.byType(LittleLaterApp), matchesGoldenFile('out/13_pull_blink.png'));
    await settle(t, 2500);
  });
  testWidgets('folders', (t) async {
    await boot(t);
    await tapSem(t, 'Folders');
    await shot(t, '06_folders');
    await tapSem(t, RegExp('^Love'));
    await shot(t, '07_folder_detail');
  });
  testWidgets('profile', (t) async {
    await boot(t);
    await tapSem(t, 'Profile');
    await shot(t, '08_profile');
  });
  testWidgets('lil', (t) async {
    await boot(t);
    await tapSem(t, RegExp('^Your mascot'));
    await settle(t, 3000);
    await tapSem(t, RegExp('^Your mascot'));
    await settle(t, 600);
    await shot(t, '09_lil');
  });
  testWidgets('reminder', (t) async {
    await boot(t);
    await tapCirc(t, 'Notifications');
    await shot(t, '10_notifications');
    await t.tap(find.text('“Slow-roasted tomato pasta” is due now'));
    await shot(t, '11_reminder');
  });
  testWidgets('chat', (t) async {
    final s = await boot(t);
    s.userEmail = 'me@x.com';
    s.guest = false;
    final f = s.folderNamed('Love')!..collab = true;
    f.extra.addAll({'collabId': 'cf_me_abc', 'ownerEmail': 'me@x.com', 'collaborators': [{'name': 'Riya', 'email': 'riya@x.com'}]});
    s.byId('d2')!.extra.addAll({'senderEmail': 'riya@x.com', 'senderName': 'Riya'});
    s.byId('d8')!.extra.addAll({'senderEmail': 'me@x.com'});
    await tapSem(t, 'Folders');
    await tapSem(t, RegExp('^Love'));
    await shot(t, '15_chat');
  });
  testWidgets('later picker', (t) async {
    await boot(t);
    await t.tap(find.text('Later').first);
    await shot(t, '16_later');
  });
  testWidgets('onboarding', (t) async {
    await boot(t, demo: false);
    await shot(t, '12_onboarding');
    await t.tap(find.text('Continue'));
    await settle(t);
    await t.tap(find.text('Continue'));
    await shot(t, '13_onboarding_look');
    await t.tap(find.text('Get started'));
    await shot(t, '14_signin');
  });
}
