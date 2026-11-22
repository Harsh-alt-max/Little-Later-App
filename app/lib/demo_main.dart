// Web demo of the real app for showing people: sample data, no account,
// nothing is saved. Build: flutter build web -t lib/demo_main.dart
import 'dart:js_interop';

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import 'app.dart';
import 'data/models.dart';
import 'data/store.dart';
import 'services/auth.dart';
import 'services/reminders.dart';
import 'services/sync.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore.memory()..seedDemo();
  store.finishOnboarding(asGuest: true, name: 'Harsh');
  // Show off the newer bits: a repeating to-do and a shared folder.
  final n = AppStore.now();
  store.addItem(Item(
    id: 'demo-repeat',
    kind: ItemKind.todoList,
    title: 'Morning routine',
    folder: '',
    dueAt: DateTime(n.year, n.month, n.day + 1, 7, 30).millisecondsSinceEpoch,
    tasks: [TodoTask(id: 'r1', text: 'Stretch for 10 minutes'), TodoTask(id: 'r2', text: 'Drink a glass of water'), TodoTask(id: 'r3', text: 'Plan the top 3 things for today')],
  )..repeatDays = [1, 2, 3, 4, 5]);
  // Sample cover pictures that ship with the preview page.
  for (final id in ['d1', 'd2', 'd3', 'd4', 'd6', 'd7', 'd8', 'd9', 'd11']) {
    store.byId(id)?.thumbnail = Uri.base.resolve('../covers/$id.jpg').toString();
  }
  final goa = store.folders.where((f) => f.name == 'Goa trip').firstOrNull;
  if (goa != null) {
    goa.collab = true;
    goa.extra.addAll({'collabId': 'cf_demo', 'ownerEmail': 'harsh@example.com', 'ownerName': 'Harsh', 'collaborators': ['riya@example.com', 'aman@example.com']});
  }
  final reminders = Reminders(store);
  // The preview page can ask for a reminder to "go off" (there are no real
  // notifications in a browser).
  web.window.addEventListener(
    'message',
    ((web.MessageEvent e) {
      final d = e.data;
      if (d == null || !d.isA<JSString>() || (d as JSString).toDart != 'll-ring') return;
      final it = store.items.where((i) => i.kind == ItemKind.reminder && !i.isDone).firstOrNull ?? store.items.where((i) => i.whenTs > 0 && !i.isDone).firstOrNull;
      if (it != null) reminders.showNow(it.id);
    }).toJS,
  );
  runApp(LittleLaterApp(
    store: store,
    services: Services(auth: AuthService(false), sync: SyncService(store, enabled: false), reminders: reminders, platform: false),
  ));
}
