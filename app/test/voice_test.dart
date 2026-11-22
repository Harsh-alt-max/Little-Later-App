// The voice panel with a pretend phone recogniser: pauses must never lose
// words, and nothing is added until you tap Add.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:little_later/data/models.dart';
import 'package:little_later/ui/voice.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

import 'app_test.dart' show demoStore, pumpApp, settle, loadFonts, shot;

class FakeRecogniser extends SpeechToTextPlatform {
  int listens = 0, stops = 0;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> initialize({debugLogging = false, List<SpeechConfigOption>? options}) async => true;
  @override
  Future<bool> listen({String? localeId, partialResults = true, onDevice = false, int listenMode = 0, sampleRate = 0, SpeechListenOptions? options}) async {
    listens++;
    onStatus?.call('listening');
    return true;
  }

  @override
  Future<void> stop() async {
    stops++;
    onStatus?.call('done');
  }

  @override
  Future<void> cancel() async {}
  @override
  Future<List<dynamic>> locales() async => [];

  void say(String words, {bool last = true}) => onTextRecognition?.call(jsonEncode({
        'alternates': [
          {'recognizedWords': words, 'confidence': .9},
        ],
        'resultType': last ? 2 : 0,
      }));

  /// The phone stops listening by itself after a pause.
  void phonePaused() {
    onStatus?.call('notListening');
    onStatus?.call('done');
  }
}

// One for all tests: the app's speech object hooks into it once.
final recogniser = FakeRecogniser();

void main() {
  SpeechToTextPlatform.instance = recogniser;
  setUpAll(loadFonts);

  testWidgets('pauses keep every word; only Add saves', (tester) async {
    final fake = recogniser..listens = 0;
    final store = demoStore();
    await pumpApp(tester, store);
    final before = store.items.length;
    openVoice(tester.element(find.text('Paste a link or type a reminder')));
    await settle(tester, 800);
    expect(fake.listens, 1);

    fake.say('kal 3 baje', last: false);
    await settle(tester, 200);
    fake.say('kal 3 baje doodh lana');
    await settle(tester, 200);
    fake.phonePaused();
    await settle(tester, 600);
    expect(fake.listens, 2, reason: 'the mic starts again after a pause');

    // A long silence: nothing is added and nothing is lost.
    await settle(tester, 12000);
    fake.phonePaused();
    await settle(tester, 600);
    expect(store.items.length, before);
    fake.say('aur 5 baje gym jana');
    await settle(tester, 300);
    expect(find.textContaining('doodh lana aur 5 baje gym jana'), findsOneWidget);

    // Pause the mic, then talk more: the words are added at the end.
    await tester.tap(find.bySemanticsLabel('Pause the mic'));
    await settle(tester, 400);
    expect(find.textContaining('Mic paused'), findsOneWidget);
    expect(find.textContaining('gym jana'), findsOneWidget);
    final n = fake.listens;
    await tester.tap(find.bySemanticsLabel('Talk'));
    await settle(tester, 600);
    expect(fake.listens, n + 1);
    fake.say('phir 7 baje dinner');
    await settle(tester, 300);
    expect(find.textContaining('kal 3 baje doodh lana aur 5 baje gym jana phir 7 baje dinner'), findsOneWidget);
    expect(store.items.length, before, reason: 'never adds by itself');
    await shot(tester, 'midnight_9_voice');

    await tester.tap(find.text('Add 3'));
    await settle(tester, 1500);
    final added = store.items.where((i) => i.kind == ItemKind.reminder).map((i) => i.title).toList();
    expect(added, containsAll(['Doodh lana', 'Gym jana', 'Dinner']));
    await tester.pump(const Duration(seconds: 61)); // let the recogniser's own timers finish
  });

  testWidgets('rows can be added, changed and removed by hand', (tester) async {
    final fake = recogniser..listens = 0;
    final store = demoStore();
    await pumpApp(tester, store);
    final before = store.items.length;
    openVoice(tester.element(find.text('Paste a link or type a reminder')));
    await settle(tester, 800);

    // Say two things, then fix the second by hand.
    fake.say('kal 3 baje doodh lana aur 5 baje gym jana');
    await settle(tester, 300);
    expect(find.text('Add 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('draft-1')));
    await settle(tester, 800);
    expect(find.textContaining('Mic paused'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('draft-title')), 'Gym with Riya');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('draft-save')));
    await settle(tester, 800);
    expect(find.text('Gym with Riya'), findsOneWidget);

    // Add one by hand, then remove it again.
    await tester.tap(find.byKey(const ValueKey('draft-add')));
    await settle(tester, 800);
    await tester.enterText(find.byKey(const ValueKey('draft-title')), 'Pay rent');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('draft-save')));
    await settle(tester, 800);
    expect(find.text('Add 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('draft-2')));
    await settle(tester, 800);
    await tester.tap(find.text('Remove'));
    await settle(tester, 800);
    expect(find.text('Pay rent'), findsNothing);

    // Talk again: new words come in under the hand-made rows.
    await tester.tap(find.bySemanticsLabel('Talk'));
    await settle(tester, 600);
    fake.say('phir 7 baje dinner');
    await settle(tester, 300);
    expect(find.text('Gym with Riya'), findsOneWidget);
    expect(find.text('Add 3'), findsOneWidget);
    expect(find.text('Tomorrow, 7:00 pm'), findsOneWidget, reason: 'same day as the rows above');
    await shot(tester, 'midnight_9b_voice_rows');

    // As a to-do list.
    await tester.tap(find.text('1 to-do list'));
    await settle(tester, 300);
    await tester.tap(find.text('Add list'));
    await settle(tester, 1500);
    expect(store.items.length, before + 1);
    final list = store.items.firstWhere((i) => i.kind == ItemKind.todoList);
    expect(list.tasks.map((t) => t.text).toList(), ['Doodh lana · 3:00 pm', 'Gym with Riya · 5:00 pm', 'Dinner · 7:00 pm']);
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('without speaking: add reminders straight from the panel', (tester) async {
    recogniser.listens = 0;
    final store = demoStore();
    await pumpApp(tester, store);
    openVoice(tester.element(find.text('Paste a link or type a reminder')));
    await settle(tester, 800);
    await tester.tap(find.bySemanticsLabel('Pause the mic'));
    await settle(tester, 400);
    await tester.tap(find.byKey(const ValueKey('draft-add')));
    await settle(tester, 800);
    await tester.enterText(find.byKey(const ValueKey('draft-title')), 'Call mom');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('draft-save')));
    await settle(tester, 800);
    expect(find.text('Call mom'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('voice-add')));
    await settle(tester, 1500);
    expect(store.items.any((i) => i.kind == ItemKind.reminder && i.title == 'Call mom' && i.whenTs > 0), isTrue);
    await tester.pump(const Duration(seconds: 61));
  });
}
