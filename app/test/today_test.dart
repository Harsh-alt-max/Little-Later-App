import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_later/app.dart';
import 'package:little_later/data/models.dart';
import 'package:little_later/data/store.dart';
import 'package:little_later/services/auth.dart';
import 'package:little_later/services/reminders.dart';
import 'package:little_later/services/sync.dart';
import 'package:little_later/services/link_meta.dart';
import 'package:little_later/mascot/mascot_svg.dart';
import 'package:little_later/data/titles.dart';

AppStore demoStore() {
  AppStore.now = () => DateTime(2026, 11, 14, 13, 30);
  return AppStore.memory()..seedDemo();
}

Future<void> pumpApp(WidgetTester tester, AppStore store) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(LittleLaterApp(store: store, services: Services(auth: AuthService(false), sync: SyncService(store, enabled: false), reminders: Reminders(store), platform: false)));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> settle(WidgetTester tester, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> loadFonts() async {
  final loader = FontLoader('Manrope');
  for (final w in [400, 500, 600, 700, 800]) {
    loader.addFont(File('assets/fonts/Manrope-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(loadFonts);
  group('store', () {
    test('today queue holds overdue and later-today items, earliest first', () {
      final s = demoStore();
      expect(s.todayQueue.map((e) => e.id), ['d1', 'd2', 'd3']);
      expect(s.todayTotal, 4); // 3 left + 1 done
    });

    test('complete and undo', () {
      final s = demoStore();
      final undo = s.complete('d1');
      expect(s.todayQueue.length, 2);
      expect(s.doneToday, 2);
      undo();
      expect(s.todayQueue.length, 3);
      expect(s.doneToday, 1);
    });

    test('snooze moves to tomorrow at the morning hour', () {
      final s = demoStore();
      s.snoozeToTomorrow('d2');
      final it = s.items.firstWhere((e) => e.id == 'd2');
      expect(DateTime.fromMillisecondsSinceEpoch(it.reminder), DateTime(2026, 11, 15, 9));
      expect(s.todayQueue.map((e) => e.id), ['d1', 'd3']);
    });

    test('say hi grows the streak once per day and pays freezes/hearts', () {
      final s = demoStore();
      final r = s.sayHi()!;
      expect(r.streak, 10);
      expect(r.line, contains('Hearts are ready'));
      expect(s.sayHi(), isNull);
      expect(s.freezes, 4); // day 10 is a multiple of 5
      expect(s.heartsReady, 5); // milestone 10 pays 10 - 5
    });

    test('missed day uses a freeze, longer gap resets', () {
      final s = demoStore()..lastHiDay = '2026-11-12';
      expect(s.sayHi()!.freezesUsed, 1);
      final t = demoStore()
        ..lastHiDay = '2026-11-01'
        ..freezes = 0;
      expect(t.sayHi()!.streak, 1);
    });

    test('item JSON round-trips v1.2 fields and keeps unknown keys', () {
      final j = {'id': 7, 'kind': 'todoList', 'title': 'T', 'folder': 'Work', 'tasks': [{'id': 'a', 'text': 'x', 'done': true}], 'folderKind': 'work', 'savedAt': 5};
      final it = Item.fromJson(j);
      expect(it.kind, ItemKind.todoList);
      expect(it.tasks.single.done, isTrue);
      expect(it.toJson()['folderKind'], 'work');
      expect(it.toJson()['id'], '7');
    });

    test('link titles are short and readable', () {
      expect(
        cleanTitle('Vanshika Patliya on Instagram: "The last page of our notebooks had more creativity than we realised. &#x1f602; Funny how those random doodles #CreativeThinking #Creativity"'),
        'Vanshika Patliya: The last page of our notebooks had more creativity…',
      );
      expect(cleanTitle('Aurio Premium dryfruits on Instagram: "&#x1f331;&#x2728; Fresh"'), 'Aurio Premium dryfruits: 🌱✨ Fresh');
      expect(cleanTitle('How to cook pasta - YouTube'), 'How to cook pasta');
      expect(cleanTitle('A' * 100).length, lessThanOrEqualTo(71));
    });

    test('removed member keeps items as their own folder; others just wait for the move', () {
      AppStore.now = () => DateTime(2026, 11, 14, 13, 30);
      for (final removed in [true, false]) {
        final st = AppStore.memory()..seedDemo();
        final f = st.folderNamed('Love')!
          ..collab = true
          ..extra.addAll({'collabId': 'cf_owner_x', 'ownerEmail': 'owner@x.com', 'ownerName': 'Harsh'});
        final sync = SyncService(st, enabled: false);
        sync.debugApplyCollab('cf_owner_x', {
          'folder': {'name': 'Love', 'collabId': 'cf_owner_x', 'closed': true},
          'removed': ['friend@x.com'],
          'items': [],
        }, me: removed ? 'friend@x.com' : 'other@x.com');
        if (removed) {
          expect(f.collab, isFalse);
          expect(f.collabId, isEmpty);
          expect(st.inFolder('Love'), isNotEmpty); // nothing deleted
          expect(st.notes.first.text, contains('removed you'));
        } else {
          expect(f.collab, isTrue);
          expect(f.extra['awaitMove'], isTrue);
        }
      }
    });

    test('shared folder: new links from friends notify, chat and own saves do not; mute works', () {
      final st = AppStore.memory()..seedDemo();
      final f = st.folderNamed('Love')!
        ..collab = true
        ..extra.addAll({'collabId': 'cf_owner_y', 'ownerEmail': 'owner@x.com'});
      final sync = SyncService(st, enabled: false);
      final got = <String>[];
      sync.onShared = (f, it) => got.add(it.id);
      Map<String, dynamic> item(String id, {bool msg = false, String from = 'riya@x.com'}) =>
          {'id': id, 'kind': 'link', 'title': id, 'url': 'https://x.com/$id', 'savedAt': 1, 'updatedAt': 1, 'senderEmail': from, if (msg) 'msg': true};
      sync.debugApplyCollab('cf_owner_y', {'folder': {'name': 'Love'}, 'items': [item('a')]}, me: 'me@x.com'); // first pull: quiet
      sync.debugApplyCollab('cf_owner_y', {'folder': {'name': 'Love'}, 'items': [item('a'), item('b'), item('c', msg: true), item('d', from: 'me@x.com')]}, me: 'me@x.com');
      expect(got, ['b']);
      expect(st.isMuted(f), isFalse);
      st.setMuted(f, true);
      expect(st.isMutedName('love'), isTrue);
      st.setMuted(f, false);
      expect(st.isMuted(f), isFalse);
    });

    test('repeating reminders come back on their next day; links never repeat', () {
      final st = AppStore.memory();
      // Wednesday 18 Nov 2026, 9:00
      final base = DateTime(2026, 11, 18, 9);
      expect(nextRepeat(base, [1, 2, 3, 4, 5], DateTime(2026, 11, 20, 10)), DateTime(2026, 11, 23, 9)); // Fri after 9 → Mon
      expect(nextRepeat(base, [1, 2, 3, 4, 5, 6, 7], DateTime(2026, 11, 19)), DateTime(2026, 11, 19, 9));
      expect(repeatLabel([1, 2, 3, 4, 5]), 'Mon–Fri');
      expect(repeatLabel([1, 2, 3, 4, 5, 6, 7]), 'Every day');
      expect(repeatLabel([1, 3]), 'Mon, Wed');
      final it = Item(id: 'r1', kind: ItemKind.todoList, title: 'Stretch', folder: '', dueAt: (() { final n = AppStore.now().subtract(const Duration(minutes: 5)); return DateTime(n.year, n.month, n.day, n.hour, n.minute).millisecondsSinceEpoch; })(), tasks: [TodoTask(id: 't', text: 'a', done: true)]);
      it.repeatDays = [1, 2, 3, 4, 5, 6, 7];
      st.addItem(it);
      final before = it.whenTs;
      final undo = st.complete('r1');
      expect(it.isDone, isFalse);
      expect(it.whenTs - before, const Duration(days: 1).inMilliseconds);
      expect(it.tasks.first.done, isFalse);
      undo();
      expect(it.whenTs, before);
      final link = Item(id: 'l', kind: ItemKind.link, title: 'x', folder: '', url: 'https://a.b', reminder: before)..repeatDays = [1];
      expect(link.repeats, isFalse);
      // Left from an earlier day: rolls to today or later.
      it.dueAt = AppStore.now().subtract(const Duration(days: 3)).millisecondsSinceEpoch;
      st.rollRepeats();
      final n = AppStore.now();
      expect(it.dueAt >= DateTime(n.year, n.month, n.day).millisecondsSinceEpoch, isTrue);
    });

    test('youtube ids and covers', () {
      expect(youtubeId('https://youtu.be/abc123?t=4'), 'abc123');
      expect(youtubeId('https://www.youtube.com/watch?v=XYZ&list=1'), 'XYZ');
      expect(youtubeId('https://youtube.com/shorts/s0rt'), 's0rt');
      expect(youtubeId('https://example.com/watch?v=1'), isNull);
    });

    test('mascot svg builds for every style, outfit, level and mood', () {
      for (final st in MascotStyle.values) {
        for (var of = 0; of < 3; of++) {
          for (var lv = 1; lv <= 5; lv++) {
            for (final m in Mood.values) {
              final svg = mascotSvg(stage: lv, style: st, outfit: of, mood: m, blink: true);
              expect(svg, startsWith('<svg'));
              expect('<g'.allMatches(svg).length, '</g>'.allMatches(svg).length, reason: '$st $of $lv $m');
            }
          }
        }
      }
    });
  });

  group('Today screen', () {
    testWidgets('renders v7 sections with demo data', (tester) async {
      await pumpApp(tester, demoStore());
      expect(find.text('Next up'), findsOneWidget);
      expect(find.text('Slow-roasted tomato pasta'), findsOneWidget);
      expect(find.text('Due now'), findsNothing); // no pill, the cover shows instead
      expect(find.text('Later today'), findsOneWidget);
      expect(find.text('Anniversary gift ideas'), findsOneWidget);
      expect(find.text('3 ideas want you back today.'), findsOneWidget);
      expect(find.text('Folders'), findsWidgets);
      expect(find.text('Goa trip'), findsOneWidget);
      await settle(tester, 4000);
    });

    testWidgets('Revisited completes the next idea with undo', (tester) async {
      final store = demoStore();
      await pumpApp(tester, store);
      await tester.ensureVisible(find.text('Revisited'));
      await tester.pump();
      await tester.tap(find.text('Revisited'));
      await settle(tester, 1600);
      expect(store.doneToday, 2);
      expect(store.xp, 155);
      expect(store.revisitedTotal, 24);
      expect(find.text('Anniversary gift ideas'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await settle(tester, 600);
      expect(store.doneToday, 1);
      expect(store.xp, 140);
      await settle(tester, 4000);
    });

    testWidgets('swipe left pushes a later row to tomorrow', (tester) async {
      final store = demoStore();
      await pumpApp(tester, store);
      await tester.drag(find.text('Next up'), const Offset(0, -300)); // scroll the row clear of the dock
      await settle(tester, 600);
      await tester.drag(find.text('Q4 roadmap doc to review'), const Offset(-200, 0));
      await settle(tester, 1000);
      expect(find.text('Later, when?'), findsOneWidget);
      await tester.tap(find.text('Set time'));
      await settle(tester, 1500);
      // Default "later" time is an hour from now (14:30), so it stays in today's list.
      expect(DateTime.fromMillisecondsSinceEpoch(store.byId('d3')!.reminder), DateTime(2026, 11, 14, 14, 30));
      await settle(tester, 4000);
    });

    testWidgets('empty day shows all caught up', (tester) async {
      AppStore.now = () => DateTime(2026, 11, 14, 13, 30);
      await pumpApp(tester, AppStore.memory()..onboarded = true);
      expect(find.text('All caught up'), findsOneWidget);
      expect(find.text('You’re all caught up.'), findsOneWidget);
      await settle(tester, 4000);
    });
  });
}
