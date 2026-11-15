import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';
import '../data/store.dart';

/// Schedules a phone notification for every upcoming reminder / due to-do.
/// Tapping one opens the app on the full-screen reminder for that item.
class Reminders {
  Reminders(this.store);
  final AppStore store;
  final _plugin = FlutterLocalNotificationsPlugin();
  final _tapped = StreamController<String>.broadcast();
  Stream<String> get tapped => _tapped.stream;
  bool _ready = false;
  Timer? _debounce;
  String? launchItemId;
  final Set<int> _scheduled = {};

  static const _channel = AndroidNotificationDetails(
    'reminders',
    'Reminders',
    channelDescription: 'When a saved idea is due',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
  );

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
      void onTap(NotificationResponse r) {
        if ((r.payload ?? '').isNotEmpty) _tapped.add(r.payload!);
      }

      try {
        await _plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_stat_ll')), onDidReceiveNotificationResponse: onTap);
      } catch (_) {
        // Never let a missing icon switch reminders off: fall back to the app icon.
        await _plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')), onDidReceiveNotificationResponse: onTap);
      }
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) launchItemId = launch?.notificationResponse?.payload;
      _ready = true;
      // Clear reminders left from the previous run; reschedule() re-adds the current ones.
      await _plugin.cancelAllPendingNotifications();
      store.changes.listen((_) => reschedule());
      store.addListener(_onAny);
      await reschedule();
    } catch (_) {}
  }

  void _onAny() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), reschedule);
  }

  bool get ready => _ready;

  /// True when Android allows this app to show notifications.
  Future<bool> enabled() async {
    if (!_ready) return false;
    try {
      final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await a?.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Shows one now and one in 10 seconds, so you can check reminders work.
  Future<bool> sendTest() async {
    if (!_ready || !await askPermission()) return false;
    await _plugin.show(
      id: 1,
      title: '${store.mascotName} says hi',
      body: 'Notifications work. A reminder test arrives in 10 seconds.',
      notificationDetails: const NotificationDetails(android: _channel),
    );
    await _plugin.zonedSchedule(
      id: 2,
      scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
      notificationDetails: const NotificationDetails(android: _channel),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      title: '${store.mascotName} says: Time for this',
      body: 'This is how your reminders will look.',
    );
    return true;
  }

  Future<bool> askPermission() async {
    if (!_ready) return false;
    final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    var ok = await a?.areNotificationsEnabled() ?? true;
    if (!ok) ok = await a?.requestNotificationsPermission() ?? false;
    try {
      if (await a?.canScheduleExactNotifications() == false) await a?.requestExactAlarmsPermission();
    } catch (_) {}
    if (ok) await reschedule();
    return ok;
  }

  /// Move a time out of quiet hours (your own hours, e.g. 11 pm–7 am) to when they end.
  DateTime _quiet(DateTime d) {
    if (!store.quietOn || store.quietFrom == store.quietTo) return d;
    final f = store.quietFrom, to = store.quietTo, h = d.hour;
    final inside = f < to ? (h >= f && h < to) : (h >= f || h < to);
    if (!inside) return d;
    final sameDay = f < to || h < to;
    return DateTime(d.year, d.month, d.day + (sameDay ? 0 : 1), to);
  }

  Future<void> reschedule() async {
    if (!_ready) return;
    try {
      for (final id in _scheduled) {
        await _plugin.cancel(id: id);
      }
      _scheduled.clear();
      if (!store.notifOn) return;
      final now = DateTime.now();
      final up = store.items.where((i) => !i.isDone && i.whenTs > now.millisecondsSinceEpoch).toList()..sort((a, b) => a.whenTs.compareTo(b.whenTs));
      final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      var exact = true;
      try {
        exact = await a?.canScheduleExactNotifications() ?? true;
      } catch (_) {}
      for (final it in up.take(48)) {
        final when = _quiet(DateTime.fromMillisecondsSinceEpoch(it.whenTs));
        final nid = 1000 + (it.id.hashCode & 0x3fffffff);
        _scheduled.add(nid);
        await _plugin.zonedSchedule(
          id: nid,
          scheduledDate: tz.TZDateTime.from(when, tz.local),
          notificationDetails: const NotificationDetails(android: _channel),
          androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
          title: '${store.mascotName} says: ${_question(it)}',
          body: it.title,
          payload: it.id,
        );
      }
    } catch (_) {}
  }

  static String _question(Item it) {
    if (it.kind == ItemKind.todoList) return 'Done with this?';
    final d = it.domain;
    if (d.isEmpty) return 'Time for this';
    if (RegExp('youtube|youtu.be|vimeo|reels|tiktok|instagram').hasMatch(d)) return 'Time to watch this';
    return 'Time to read this';
  }
}
