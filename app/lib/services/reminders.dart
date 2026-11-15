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
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_stat_ll')),
        onDidReceiveNotificationResponse: (r) {
          if ((r.payload ?? '').isNotEmpty) _tapped.add(r.payload!);
        },
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) launchItemId = launch?.notificationResponse?.payload;
      _ready = true;
      store.changes.listen((_) => reschedule());
      store.addListener(_onAny);
      await reschedule();
    } catch (_) {}
  }

  void _onAny() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), reschedule);
  }

  Future<bool> askPermission() async {
    if (!_ready) return false;
    final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final ok = await a?.requestNotificationsPermission() ?? true;
    try {
      if (await a?.canScheduleExactNotifications() == false) await a?.requestExactAlarmsPermission();
    } catch (_) {}
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
      await _plugin.cancelAll();
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
        await _plugin.zonedSchedule(
          id: it.id.hashCode & 0x7fffffff,
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
