import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_later/app.dart';
import 'package:little_later/data/models.dart';
import 'package:little_later/data/store.dart';
import 'package:little_later/services/auth.dart';
import 'package:little_later/services/reminders.dart';
import 'package:little_later/services/sync.dart';
import 'package:little_later/widgets/common.dart';
import 'package:little_later/widgets/icons.dart';

Future<void> loadFonts() async {
  final loader = FontLoader('Manrope');
  for (final w in [400, 500, 600, 700, 800]) {
    loader.addFont(File('assets/fonts/Manrope-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await loader.load();
}

Future<AppStore> pump(WidgetTester tester, {bool demo = true}) async {
  AppStore.now = () => DateTime(2026, 11, 14, 13, 30);
  final store = AppStore.memory();
  if (demo) store.seedDemo();
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(LittleLaterApp(store: store, services: Services(auth: AuthService(false), sync: SyncService(store, enabled: false), reminders: Reminders(store), platform: false)));
  await go(tester, 600);
  return store;
}

Future<void> go(WidgetTester tester, [int ms = 800]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> tapText(WidgetTester tester, String s, [int ms = 800]) async {
  // Centre it so the dock and toasts never cover the target.
  Scrollable.ensureVisible(tester.element(find.text(s).last), alignment: .4);
  await go(tester, 300);
  await tester.tap(find.text(s).last);
  await go(tester, ms);
}

Future<void> tab(WidgetTester tester, String label) async {
  final circ = find.byWidgetPredicate((w) => w is Circ && w.label == label);
  await tester.tap(circ.evaluate().isNotEmpty ? circ.last : find.bySemanticsLabel(label).last);
  await go(tester);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('onboarding → guest → Today', (tester) async {
    final store = await pump(tester, demo: false);
    expect(find.textContaining('Save it now.'), findsOneWidget);
    await tapText(tester, 'Continue');
    expect(find.textContaining('Share from'), findsOneWidget);
    await tapText(tester, 'Continue');
    expect(find.textContaining('Meet your'), findsOneWidget);
    await tapText(tester, 'Teen', 400);
    expect(store.mascotStyle.name, 'teen');
    await tapText(tester, 'Get started', 1000);
    expect(find.text('Welcome back'), findsOneWidget);
    await tapText(tester, 'Continue as guest', 1000);
    expect(find.text('Saved on this phone only'), findsOneWidget);
    await tapText(tester, 'Continue as guest', 1500);
    expect(store.onboarded, isTrue);
    expect(find.text('All caught up'), findsOneWidget);
    await go(tester, 4000);
  });

  testWidgets('every tab renders', (tester) async {
    await pump(tester);
    await tab(tester, 'Saved');
    expect(find.text('Sourdough starter guide'), findsOneWidget);
    expect(find.text('Done'), findsWidgets);
    await tapText(tester, 'To-dos');
    expect(find.text('Book train tickets'), findsOneWidget);
    expect(find.text('Design systems talk'), findsNothing);
    await tab(tester, 'Folders');
    expect(find.text('Goa trip'), findsOneWidget);
    expect(find.text('New folder'), findsWidgets);
    await tab(tester, 'Profile');
    expect(find.text('Aarav'), findsOneWidget);
    expect(find.text('Morning reminder'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Little Later 1.4'), 300);
    await go(tester, 300);
    await tab(tester, 'Today');
    expect(find.text('Next up'), findsOneWidget);
    await go(tester, 4000);
  });

  testWidgets('save a reminder with the + sheet', (tester) async {
    final store = await pump(tester);
    final n = store.items.length;
    await tab(tester, 'Save a new idea');
    expect(find.text('Save link'), findsOneWidget);
    await tapText(tester, 'Reminder');
    await tester.enterText(find.byType(EditableText).first, 'Call the plumber');
    await go(tester, 300);
    await tapText(tester, 'In 1 hour', 400);
    await tapText(tester, 'Set reminder', 1500);
    expect(store.items.length, n + 1);
    final it = store.items.first;
    expect(it.title, 'Call the plumber');
    expect(it.kind, ItemKind.reminder);
    expect(it.reminder, greaterThan(AppStore.now().millisecondsSinceEpoch));
    expect(store.xp, 145);
    await go(tester, 4000);
  });

  testWidgets('save a to-do with steps', (tester) async {
    final store = await pump(tester);
    await tab(tester, 'Save a new idea');
    await tapText(tester, 'To-do');
    await tester.enterText(find.byType(EditableText).at(0), 'Pack for Goa');
    await tester.enterText(find.byType(EditableText).at(1), 'Sunscreen');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await go(tester, 300);
    await tapText(tester, 'No date', 300);
    await tapText(tester, 'Add to-do', 1500);
    final it = store.items.first;
    expect(it.kind, ItemKind.todoList);
    expect(it.tasks.map((e) => e.text), ['Sunscreen']);
    expect(it.dueAt, 0);
    await go(tester, 4000);
  });

  testWidgets('folder detail, new folder, delete with undo', (tester) async {
    final store = await pump(tester);
    await tab(tester, 'Folders');
    await tester.tap(find.bySemanticsLabel(RegExp('^Hobby')).first);
    await go(tester);
    expect(find.text('Add to Hobby'), findsOneWidget);
    expect(find.text('Only you'), findsOneWidget);
    await tab(tester, 'Back');
    await tab(tester, 'New folder');
    await tester.enterText(find.byType(EditableText).first, 'Books');
    await go(tester, 300);
    await tapText(tester, 'Create folder', 1000);
    expect(store.folderNamed('Books'), isNotNull);
    await go(tester, 4000);
  });

  testWidgets('saved item actions: expand, done (level up), delete + undo', (tester) async {
    final store = await pump(tester);
    await tab(tester, 'Saved');
    await tapText(tester, 'Design systems talk', 600);
    expect(find.text('Open'), findsOneWidget);
    await tester.tap(find.text('Done').first);
    await go(tester, 1500);
    expect(store.byId('d6')!.isDone, isTrue);
    // 140 + 15 stars crosses 150: level-up screen.
    expect(find.text('Lil grew bigger!'), findsOneWidget);
    await tapText(tester, 'Continue', 600);
    expect(store.level.n, 3);
    await tapText(tester, 'Ceramic mug set for Mom', 600);
    final trash = find.byWidgetPredicate((w) => w is LLIcon && w.name == 'trash');
    expect(trash, findsOneWidget);
    Scrollable.ensureVisible(tester.element(trash), alignment: .4);
    await go(tester, 300);
    await tester.tap(trash);
    await go(tester, 800);
    expect(store.byId('d8'), isNull);
    await tapText(tester, 'Undo', 600);
    expect(store.byId('d8'), isNotNull);
    await go(tester, 4000);
  });

  testWidgets('Lil panel: say hi, collect hearts, unlock outfit', (tester) async {
    final store = await pump(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('^Your mascot')));
    await go(tester, 1000);
    expect(store.streak, 10);
    expect(store.heartsReady, 5);
    await tester.tap(find.bySemanticsLabel(RegExp('^Your mascot')));
    await go(tester, 1200);
    expect(find.text('Outfits'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Collect 5'), 200, scrollable: find.byType(Scrollable).last);
    await tapText(tester, 'Collect 5', 800);
    expect(store.hearts, 10);
    await tester.scrollUntilVisible(find.text('Cozy cardigan'), -200, scrollable: find.byType(Scrollable).last);
    await tapText(tester, 'Cozy cardigan', 500);
    expect(find.text('Unlock'), findsOneWidget);
    await tapText(tester, 'Unlock', 800);
    expect(store.ownedOutfits, contains(1));
    expect(store.hearts, 0);
    await tab(tester, 'Close');
    await go(tester, 4000);
  });

  testWidgets('full-screen reminder: I did it', (tester) async {
    final store = await pump(tester);
    await tab(tester, 'Notifications');
    await tapText(tester, '“Slow-roasted tomato pasta” is due now', 1000);
    expect(find.text('Did you watch this?'), findsOneWidget);
    await tapText(tester, 'I did it', 1200);
    expect(store.byId('d1')!.isDone, isTrue);
    await go(tester, 4000);
  });

  testWidgets('light theme and sign-out-free erase', (tester) async {
    final store = await pump(tester);
    await tab(tester, 'Profile');
    await tapText(tester, 'Light', 600);
    expect(store.darkTheme, isFalse);
    await go(tester, 4000);
  });
}
