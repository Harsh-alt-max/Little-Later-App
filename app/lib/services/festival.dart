// Festival looks (Christmas, New Year…), delivered over the air.
//
// The app checks website/festival.json when it starts or comes back, at most
// every few hours, and keeps the last copy on the phone. A festival shows
// between its dates; delete it from the JSON and it disappears on the next
// check. Nothing here needs an app update except new app icons.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class Festival {
  Festival(this.j);
  final Map<String, dynamic> j;

  String get id => '${j['id'] ?? ''}';
  String get name => '${j['name'] ?? ''}';
  String get greeting => '${j['greeting'] ?? ''}';

  /// Lil's hat: santa | party | none
  String get hat => '${j['hat'] ?? ''}';
  bool get snow => j['snow'] == true;
  bool get confetti => j['confetti'] == true;

  /// App icon: christmas | newyear | default (icons ship inside the app).
  String get icon => '${j['icon'] ?? 'default'}';
  int? _hex(String k) {
    final v = '${j[k] ?? ''}'.replaceAll('#', '');
    if (v.length != 6) return null;
    return int.tryParse('FF$v', radix: 16);
  }

  int? get accent => _hex('accent');
  int? get accentInk => _hex('accentInk');

  bool activeOn(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final from = DateTime.tryParse('${j['from'] ?? ''}');
    final to = DateTime.tryParse('${j['to'] ?? ''}');
    if (from != null && day.isBefore(from)) return false;
    if (to != null && day.isAfter(to)) return false;
    return true;
  }
}

class Festivals extends ChangeNotifier {
  Festivals._();
  static final Festivals i = Festivals._();

  static const _k = 'festival_json', _kAt = 'festival_at', _kOff = 'festival_off';
  static const _icon = MethodChannel('littlelater/icon');

  List<Festival> _all = [];
  List<Festival> get all => _all;
  bool off = false;

  /// "Try it now" from Profile, until the app closes.
  String? previewId;
  String? _iconWanted;

  /// Today's festival, if any (and the person hasn't turned them off).
  Festival? get now {
    if (previewId != null) {
      for (final f in _all) {
        if (f.id == previewId) return f;
      }
    }
    if (off) return null;
    final d = DateTime.now();
    for (final f in _all) {
      if (f.activeOn(d)) return f;
    }
    return null;
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      off = p.getBool(_kOff) ?? false;
      _parse(p.getString(_k));
      notifyListeners();
    } catch (_) {}
  }

  void _parse(String? raw) {
    if (raw == null || raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _all = [for (final f in (m['festivals'] as List? ?? const [])) if (f is Map<String, dynamic>) Festival(f)];
    } catch (_) {}
  }

  /// Download the latest list (once per few hours, or when forced).
  Future<void> refresh({bool force = false}) async {
    try {
      final p = await SharedPreferences.getInstance();
      final last = p.getInt(_kAt) ?? 0;
      if (!force && DateTime.now().millisecondsSinceEpoch - last < 3 * 3600 * 1000 && p.getString(_k) != null) return;
      final r = await http.get(Uri.parse('$siteUrl/festival.json?t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}')).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return;
      jsonDecode(r.body); // must be valid JSON before we keep it
      await p.setString(_k, r.body);
      await p.setInt(_kAt, DateTime.now().millisecondsSinceEpoch);
      _parse(r.body);
      notifyListeners();
    } catch (_) {
      // Offline: keep using the copy on the phone.
    }
  }

  @visibleForTesting
  void useJson(String raw) {
    _parse(raw);
    notifyListeners();
  }

  void preview(String? id) {
    previewId = id;
    notifyListeners();
  }

  Future<void> setOff(bool v) async {
    off = v;
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setBool(_kOff, v);
    } catch (_) {}
  }

  /// Switch the launcher icon when the app goes to the background (switching
  /// while it's open can close it on some phones).
  Future<void> applyIcon() async {
    if (previewId != null) return; // a preview never changes the home-screen icon
    final want = now?.icon ?? 'default';
    if (want == _iconWanted) return;
    try {
      final ok = await _icon.invokeMethod<bool>('setIcon', {'name': want});
      if (ok == true) _iconWanted = want;
    } catch (_) {}
  }
}
