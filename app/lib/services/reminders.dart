import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
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

  static const toneNames = ['Lil hello', 'Pop pop', 'Soft chime'];

  /// Strong ~2 second buzz: long, short break, long, short break, long.
  static final _strong = Int64List.fromList([0, 650, 120, 650, 120, 550]);

  /// Android fixes a channel's sound and vibration when it's created, so each
  /// tune + vibration choice gets its own channel.
  AndroidNotificationDetails _details({int? tone, bool? vibe, String? group}) {
    final tn = tone ?? store.tone;
    final v = vibe ?? store.strongVibe;
    return AndroidNotificationDetails(
      'll_tone${tn + 1}_${v ? 'v' : 'nv'}',
      'Reminders · ${toneNames[tn]}${v ? '' : ' (no vibration)'}',
      channelDescription: 'When a saved idea is due',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.reminder,
      sound: RawResourceAndroidNotificationSound('ll_tone_${tn + 1}'),
      playSound: true,
      enableVibration: v,
      vibrationPattern: v ? _strong : null,
      groupKey: group,
      color: const Color(0xFF3D7BFF),
    );
  }

  /// Plays the chosen tune (and buzz) right now as a preview.
  Future<void> preview({int? tone, bool? vibe}) async {
    if (!_ready || !await askPermission()) return;
    final tn = tone ?? store.tone;
    await _plugin.show(
      id: 3,
      title: '${store.mascotName} says hi',
      body: '“${toneNames[tn]}” is your reminder sound',
      notificationDetails: NotificationDetails(
        android: _details(tone: tn, vibe: vibe),
      ),
    );
  }

  /// Someone added something to a shared folder: tell this phone (unless muted).
  Future<void> sharedAdded(Folder f, Item it) async {
    if (!_ready || !store.notifOn || store.isMuted(f) || it.extra['msg'] == true) return;
    final who = '${it.extra['senderName'] ?? ''}'.isNotEmpty ? '${it.extra['senderName']}' : '${it.extra['senderEmail'] ?? 'Someone'}'.split('@').first;
    final what = it.kind == ItemKind.todoList
        ? 'a to-do'
        : it.url.isNotEmpty
        ? 'a link'
        : 'a reminder';
    try {
      await _plugin.show(
        id: 500000 + (it.id.hashCode & 0xffff),
        title: '${f.name} · $who added $what',
        body: it.title,
        payload: it.id,
        notificationDetails: NotificationDetails(android: _details(group: 'shared_${f.collabId}')),
      );
    } catch (_) {}
  }

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
        await _plugin.initialize(
          settings: const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_stat_ll')),
          onDidReceiveNotificationResponse: onTap,
        );
      } catch (_) {
        // Never let a missing icon switch reminders off: fall back to the app icon.
        await _plugin.initialize(
          settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
          onDidReceiveNotificationResponse: onTap,
        );
      }
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) launchItemId = launch?.notificationResponse?.payload;
      _ready = true;
      // Clear reminders left from the previous run; reschedule() re-adds the current ones.
      await _plugin.cancelAllPendingNotifications();
      try {
        await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.deleteNotificationChannel(channelId: 'reminders');
      } catch (_) {}
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
      notificationDetails: NotificationDetails(android: _details()),
    );
    await _plugin.zonedSchedule(
      id: 2,
      scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
      notificationDetails: NotificationDetails(android: _details()),
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
      final live = store.items.where((i) => !i.isDone && i.extra['msg'] != true && i.whenTs > 0 && !store.isMutedName(i.folder));
      final up = live.where((i) => !i.repeats && i.whenTs > now.millisecondsSinceEpoch).toList()
        ..sort((a, b) => a.whenTs.compareTo(b.whenTs));
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
          notificationDetails: NotificationDetails(android: _details()),
          androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
          title: _sharedFolder(it.folder) != null ? '${_sharedFolder(it.folder)} · ${_question(it)}' : '${store.mascotName} says: ${_question(it)}',
          body: it.title,
          payload: it.id,
        );
      }
      // Repeating to-dos and reminders: Android repeats these by itself.
      for (final it in live.where((i) => i.repeats).take(24)) {
        final base = DateTime.fromMillisecondsSinceEpoch(it.whenTs);
        final from = base.isAfter(now) ? base : now;
        final days = it.repeatDays;
        final every = days.length == 7;
        for (final d in every ? [0] : days) {
          var at = nextRepeat(base, every ? days : [d], from);
          at = _quiet(at);
          final nid = 1000 + ((it.id.hashCode + d * 7919) & 0x3fffffff);
          _scheduled.add(nid);
          await _plugin.zonedSchedule(
            id: nid,
            scheduledDate: tz.TZDateTime.from(at, tz.local),
            notificationDetails: NotificationDetails(android: _details()),
            androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: every ? DateTimeComponents.time : DateTimeComponents.dayOfWeekAndTime,
            title: _sharedFolder(it.folder) != null ? '${_sharedFolder(it.folder)} · ${_question(it)}' : '${store.mascotName} says: ${_question(it)}',
            body: it.title,
            payload: it.id,
          );
        }
      }
    } catch (_) {}
  }

  String? _sharedFolder(String name) {
    for (final f in store.folders) {
      if (f.collab && f.name.toLowerCase() == name.toLowerCase()) return f.name;
    }
    return null;
  }

  static String _question(Item it) {
    if (it.kind == ItemKind.todoList) return 'Done with this?';
    final d = it.domain;
    if (d.isEmpty) return 'Time for this';
    if (RegExp('youtube|youtu.be|vimeo|reels|tiktok|instagram').hasMatch(d)) return 'Time to watch this';
    return 'Time to read this';
  }
}
