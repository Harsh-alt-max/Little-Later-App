import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import 'app.dart';
import 'config.dart';
import 'data/store.dart';
import 'screens/save_sheet.dart';
import 'services/auth.dart';
import 'services/reminders.dart';
import 'services/sync.dart';

/// Build with `--dart-define=LL_DEMO=true` to seed the v7 sample content on first launch.
const kDemo = bool.fromEnvironment('LL_DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  var firebase = false;
  try {
    await Firebase.initializeApp(options: firebaseOptions);
    firebase = true;
  } catch (_) {}

  final store = await AppStore.load(demo: kDemo);
  final reminders = Reminders(store);
  await reminders.init();
  shareText = (text) => SharePlus.instance.share(ShareParams(text: text));

  runApp(LittleLaterApp(
    store: store,
    services: Services(auth: AuthService(firebase), sync: SyncService(store, enabled: firebase), reminders: reminders),
  ));
}
