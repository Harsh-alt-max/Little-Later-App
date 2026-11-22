import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import 'app.dart';
import 'share_app.dart';
import 'config.dart';
import 'data/store.dart';
import 'screens/save_sheet.dart';
import 'services/auth.dart';
import 'services/festival.dart';
import 'services/haptics.dart';
import 'services/reminders.dart';
import 'services/sync.dart';

/// Build with `--dart-define=LL_DEMO=true` to seed the v7 sample content on first launch.
const kDemo = bool.fromEnvironment('LL_DEMO');

Future<({AppStore store, bool firebase})> _boot() async {
  var firebase = false;
  try {
    await Firebase.initializeApp(options: firebaseOptions);
    firebase = true;
  } catch (_) {}
  final store = await AppStore.load(demo: kDemo);
  await Festivals.i.load();
  Festivals.i.refresh();
  Haptics.enabled = store.haptics;
  store.addListener(() => Haptics.enabled = store.haptics);
  shareText = (text) => SharePlus.instance.share(ShareParams(text: text));
  return (store: store, firebase: firebase);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final b = await _boot();
  final reminders = Reminders(b.store);
  await reminders.init();
  runApp(LittleLaterApp(
    store: b.store,
    services: Services(auth: AuthService(b.firebase), sync: SyncService(b.store, enabled: b.firebase), reminders: reminders),
  ));
}

/// Entry point for the Share menu window (see ShareActivity.kt).
@pragma('vm:entry-point')
Future<void> shareMain(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final b = await _boot();
  final reminders = Reminders(b.store);
  await reminders.init();
  final text = args.isEmpty ? '' : args.first;
  if (text.trim().isEmpty) {
    await SystemNavigator.pop();
    return;
  }
  runApp(ShareApp(store: b.store, text: text, auth: AuthService(b.firebase), sync: SyncService(b.store, enabled: b.firebase), reminders: reminders));
}
