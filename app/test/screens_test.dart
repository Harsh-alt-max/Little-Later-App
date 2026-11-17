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
import 'package:little_later/widgets/item_tile.dart';

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
  // Lazy lists (the save sheet) only build what's on screen: scroll to it first.
  if (find.text(s).evaluate().isEmpty) {
    await tester.dragUntilVisible(find.text(s), find.byType(Scrollable).last, const Offset(0, -200));
  }
  // Centre it so the dock and toasts never cover the target.
  Scrollable.ensureVisible(tester.element(find.text(s).last), alignment: .4);
  await go(tester, 300);
  await tester.tap(find.text(s).last);
  await go(tester, ms);
}

Future<void> tab(WidgetTester tester, String label) async {
  await tester.pump();
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
    expect(find.text('Quiet hours'), findsOneWidget);
    expect(find.text('Morning reminder'), findsNothing);
    expect(find.text('Privacy and terms'), findsNothing);
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
    expect(find.text('Add link, reminder or to-do'), findsOneWidget);
    expect(find.text('Only you'), findsOneWidget);
    await tab(tester, 'Back');
    await tapText(tester, 'New folder');
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

  testWidgets('Next up: Later picks a time, Revisited animates and completes', (tester) async {
    final store = await pump(tester);
    expect(find.text('Save a link or idea'), findsOneWidget);
    expect(find.text('Search your saved ideas'), findsNothing);
    await tester.ensureVisible(find.text('Later').first);
    await tester.pump();
    await tester.tap(find.text('Later').first);
    await go(tester, 900);
    expect(find.text('Later, when?'), findsOneWidget);
    // Move it to tomorrow: pick the "Tmrw" day, then set.
    await tapText(tester, 'Tmrw', 300);
    await tapText(tester, 'Set time', 1200);
    expect(store.todayQueue.first.id, isNot('d1'));
    await tapText(tester, 'Undo', 600);
    expect(store.todayQueue.first.id, 'd1');
    await tester.tap(find.text('Revisited'));
    await go(tester, 200);
    expect(find.text('Nice!'), findsOneWidget);
    await go(tester, 1600);
    expect(store.byId('d1')!.isDone, isTrue);
    await go(tester, 4000);
  });

  testWidgets('shared folder is a chat: send a message', (tester) async {
    final store = await pump(tester);
    store.userEmail = 'me@x.com';
    store.guest = false;
    final f = store.folderNamed('Love')!..collab = true;
    f.extra['collabId'] = 'cf_me_x_com_abc';
    f.extra['ownerEmail'] = 'me@x.com';
    store.byId('d2')!.extra['senderEmail'] = 'riya@x.com';
    store.byId('d2')!.extra['senderName'] = 'Riya';
    await tab(tester, 'Folders');
    await tester.tap(find.bySemanticsLabel(RegExp('^Love')).first);
    await go(tester);
    // Saved is the main view, with who saved each item.
    expect(find.textContaining('Riya ·'), findsOneWidget);
    expect(find.text('Add link, reminder or to-do'), findsOneWidget);
    await tapText(tester, 'Chat');
    expect(find.text('Riya'), findsOneWidget); // friend's bubble shows their name
    await tester.enterText(find.byType(EditableText).last, 'Booked the table for Friday');
    await tester.tap(find.bySemanticsLabel('Send').last);
    await go(tester, 600);
    expect(store.items.first.title, 'Booked the table for Friday');
    expect(store.items.first.extra['msg'], isTrue);
    expect(store.folderCount('Love'), 2); // messages don't count as saved items
    await go(tester, 4000);
  });

  testWidgets('Saved: list → grid → big covers', (tester) async {
    final store = await pump(tester);
    store.byId('d1')!.thumbnail = 'https://i.ytimg.com/vi/x/hqdefault.jpg';
    await tab(tester, 'Saved');
    expect(find.byType(ItemCard), findsNothing);
    await tester.tap(find.byWidgetPredicate((w) => w is Circ && (w.label ?? '').startsWith('View: list')).last);
    await go(tester, 600);
    expect(store.viewMode, 'grid');
    expect(find.byType(ItemCard), findsWidgets);
    await tester.tap(find.byWidgetPredicate((w) => w is Circ && (w.label ?? '').startsWith('View: grid')).last);
    await go(tester, 600);
    expect(store.viewMode, 'large');
    expect(find.byType(ItemCard), findsWidgets);
    await go(tester, 4000);
  });

  testWidgets('pull down on Today: Lil peeks, blinks, page springs back', (tester) async {
    await pump(tester);
    final g = await tester.startGesture(const Offset(200, 300));
    for (var i = 0; i < 24; i++) {
      await g.moveBy(const Offset(0, 16));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final eyes = find.byKey(const Key('ll-peek'));
    expect(eyes, findsWidgets);
    await go(tester, 2500); // still holding: stays down, keeps blinking
    expect(eyes, findsWidgets);
    await g.up();
    await go(tester, 400);
    expect(eyes, findsNothing); // let go: straight back up
    await go(tester, 3000);
  });

  testWidgets('to-dos show their steps in grid view and can be ticked', (tester) async {
    final store = await pump(tester);
    final todo = store.items.firstWhere((i) => i.kind == ItemKind.todoList && i.tasks.isNotEmpty);
    store.setPrefs(view: 'grid');
    await tab(tester, 'Saved');
    await tester.tap(find.text('To-dos').first);
    await go(tester, 600);
    final step = todo.tasks.firstWhere((t) => !t.done);
    expect(find.text(step.text), findsWidgets);
    await tester.tap(find.text(step.text).first);
    await go(tester, 400);
    expect(step.done, isTrue);
    await go(tester, 4000);
  });

  testWidgets('new reminder: no folder by default, repeat Mon–Fri', (tester) async {
    final store = await pump(tester);
    await tab(tester, 'Save a new idea');
    await tapText(tester, 'Reminder');
    await tester.enterText(find.byType(EditableText).first, 'Drink water');
    await go(tester, 300);
    await tester.ensureVisible(find.text('Mon–Fri'));
    await tapText(tester, 'Mon–Fri');
    await tapText(tester, 'Set reminder', 1500);
    final it = store.items.first;
    expect(it.title, 'Drink water');
    expect(it.folder, '');
    expect(it.repeatDays, [1, 2, 3, 4, 5]);
    await go(tester, 4000);
  });

  testWidgets('shared folder ⋯ has Mute group', (tester) async {
    final store = await pump(tester);
    store.userEmail = 'me@x.com';
    store.guest = false;
    final f = store.folderNamed('Love')!..collab = true;
    f.extra['collabId'] = 'cf_me_x_com_m';
    f.extra['ownerEmail'] = 'me@x.com';
    await tab(tester, 'Folders');
    await tester.tap(find.bySemanticsLabel(RegExp('^Love')).first);
    await go(tester);
    await tester.tap(find.bySemanticsLabel('Folder options').last);
    await go(tester, 600);
    await tapText(tester, 'Mute group', 800);
    expect(store.isMuted(f), isTrue);
    await go(tester, 4000);
  });

  testWidgets('save sheet: add a note, Today at a chosen time', (tester) async {
    final store = await pump(tester);
    await tab(tester, 'Save a new idea');
    await tester.enterText(find.byType(EditableText).first, 'https://example.com/recipes/pasta-al-limone');
    await go(tester, 800);
    await tapText(tester, 'Add a note', 500);
    await tester.enterText(find.byType(EditableText).last, 'lemons, parmesan');
    await tapText(tester, 'Tomorrow', 800);
    expect(find.text('Tomorrow at…'), findsOneWidget);
    await tapText(tester, 'Set time', 800);
    await tapText(tester, 'Save link', 1500);
    final it = store.items.first;
    expect(it.note, 'lemons, parmesan');
    expect(DateTime.fromMillisecondsSinceEpoch(it.reminder), DateTime(2026, 11, 15, 9));
    await go(tester, 4000);
  });

  testWidgets('sharing uses the live folder even after data reloads', (tester) async {
    final store = await pump(tester);
    final stale = Folder.fromJson(store.folderNamed('Work')!.toJson()); // a copy, like after a reload
    await SyncService(store, enabled: false).share(stale);
    expect(store.folderNamed('Work')!.collab, isTrue);
    expect(store.folderNamed('Work')!.collabId, startsWith('cf_'));
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
