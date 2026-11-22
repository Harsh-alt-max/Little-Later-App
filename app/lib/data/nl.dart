// Natural-language time parsing for "call mom 9pm tomorrow", Hinglish
// ("kal dopahar 12 baje doodh lana hai") and Hindi script. Ported 1:1 from the
// Midnight prototype so the app and the preview understand the same sentences.

import 'models.dart';
import 'store.dart';

class NL {
  NL({required this.found, required this.ranges, required this.date, required this.title, required this.repeat});
  final bool found;
  final List<(int, int)> ranges;
  final DateTime? date;
  final String title;

  /// Weekdays (1 = Mon … 7 = Sun); empty = once.
  final List<int> repeat;

  String get repeatText => repeat.isEmpty ? '' : repeatLabel(repeat);
}

const _wdKeys = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];

/// JS getDay index (0 = Sun) → Dart weekday (7 = Sun).
int _dw(int js) => js == 0 ? 7 : js;

NL parseNL(String text, {DateTime? now}) {
  final src = text;
  final nowD = now ?? AppStore.now();
  var work = src.toLowerCase();
  final ranges = <(int, int)>[];
  void take(RegExp re, void Function(RegExpMatch m) fn) {
    final m = re.firstMatch(work);
    if (m == null || m.end == m.start) return;
    ranges.add((m.start, m.end));
    work = work.substring(0, m.start) + ' ' * (m.end - m.start) + work.substring(m.end);
    fn(m);
  }

  var rep = <int>[];
  int? dayOff, wd, h, inMin, part;
  var mi = 0;
  const wdRe = r'(sun|mon|tue|tues|wed|wednes|thu|thur|thurs|fri|sat|satur)(?:day)?';

  // ---- Hindi / Hinglish
  {
    const hb = r'(?<![\p{L}\p{M}\d])', he = r'(?![\p{L}\p{M}])';
    const partRe = '(subah|subha|subeh|savere|sawere|सुबह|सवेरे|dopahar|dopehar|dophar|dupahar|dopaher|दोपहर|shaam|sham|शाम|raat|रात)';
    const fr = '(saade|sade|saadhe|साढ़े|साढे|sava|sawa|सवा|paune|pone|पौने)';
    const num = '(\\d{1,2}|dedh|dhai|डेढ़|ढाई)';
    const baje = '(?:baje|bje|बजे)';
    const ko = r'(?:\s*(?:ko|को|ke|के|mein|में))?';
    RegExp u(String s) => RegExp(s, unicode: true);
    bool isMorning(String p) => RegExp(r'^(su|sa|सु|सव)').hasMatch(p) && !RegExp(r'^(sh|शा)').hasMatch(p);
    (int, int) hrs(String n, String? mm) {
      if (RegExp(r'^(dedh|डेढ़)$').hasMatch(n)) return (1, 30);
      if (RegExp(r'^(dhai|ढाई)$').hasMatch(n)) return (2, 30);
      return (int.parse(n), int.tryParse(mm ?? '') ?? 0);
    }

    (int, int) frac(String? f, int hh, int m0) {
      if (f == null) return (hh, m0);
      if (RegExp(r'^(saa|sad|सा)').hasMatch(f)) return (hh, 30);
      if (RegExp(r'^(sav|saw|सवा)').hasMatch(f)) return (hh, 15);
      return (hh - 1 == 0 ? 12 : hh - 1, 45);
    }

    int fix(String? p, int hh) {
      if (p == null) return hh < 8 ? hh + 12 : hh;
      if (isMorning(p)) return hh == 12 ? 0 : hh;
      if (RegExp(r'^(do|du|दो)').hasMatch(p)) return hh == 12 ? 12 : hh < 7 ? hh + 12 : hh;
      if (RegExp(r'^(sh|शा)').hasMatch(p)) return hh < 12 ? hh + 12 : hh;
      return hh == 12 ? 24 : hh >= 5 && hh < 12 ? hh + 12 : hh;
    }

    void setH(String? p, String? f, String n, String? mm) {
      var (a, b) = hrs(n, mm);
      (a, b) = frac(f, a, b);
      a = fix(p, a);
      if (a >= 24) {
        h = 23;
        mi = 59;
      } else {
        h = a;
        mi = b;
      }
    }

    take(u('$hb(?:har\\s*roz|har\\s*din|rozana|roz|roj|रोज़ाना|रोज़|रोज|हर\\s*दिन|हर\\s*रोज़?)$he'), (_) => rep = [1, 2, 3, 4, 5, 6, 7]);
    const hwd = [
      ('ravivar|itvaar|itwar|रविवार|इतवार', 0),
      ('somvar|somwar|सोमवार', 1),
      ('mangalvar|mangalwar|मंगलवार', 2),
      ('budhvar|budhwar|बुधवार', 3),
      ('guruvar|guruwar|brihaspativar|veervar|गुरुवार|बृहस्पतिवार', 4),
      ('shukravar|shukrawar|शुक्रवार', 5),
      ('shanivar|shaniwar|शनिवार', 6),
    ];
    for (final (w, k) in hwd) {
      take(u('$hb(har\\s*|हर\\s*)?(?:$w)(?:\\s*(?:ko|को))?$he'), (m) {
        wd = k;
        if (m.group(1) != null) rep = [_dw(k)];
      });
    }
    take(u('$hb(\\d+)\\s*(minute|minat|mint|min|मिनट|ghante|ghanta|ghnte|घंटे|घंटा)\\s*(?:mein|me|में|baad|बाद)$he'),
        (m) => inMin = int.parse(m.group(1)!) * (RegExp(r'^(gh|घं)').hasMatch(m.group(2)!) ? 60 : 1));
    take(u('$hb$partRe$ko\\s*(?:$fr\\s*)?$num(?::(\\d{2}))?(?:\\s*$baje)?$he'), (m) => setH(m.group(1), m.group(2), m.group(3)!, m.group(4)));
    if (h == null) take(u('$hb(?:$fr\\s*)?$num(?::(\\d{2}))?\\s*$baje(?:\\s*$partRe$ko)?$he'), (m) => setH(m.group(4), m.group(1), m.group(2)!, m.group(3)));
    if (h == null) {
      take(u('$hb$partRe$ko$he'), (m) {
        final p = m.group(1)!;
        part = isMorning(p) ? 9 : RegExp(r'^(do|du|दो)').hasMatch(p) ? 14 : RegExp(r'^(sh|शा)').hasMatch(p) ? 18 : 21;
      });
    }
    take(u('$hb(parso|parson|parsun|परसों|परसो|पर्सन|पर्सों)$he'), (_) => dayOff = 2);
    take(u('$hb(kal|कल)$he'), (_) => dayOff = 1);
    take(u('$hb(aaj|आज)$he'), (_) => dayOff = 0);
  }

  // ---- English
  take(RegExp(r'\b(every\s*day|daily)\b'), (_) => rep = [1, 2, 3, 4, 5, 6, 7]);
  take(RegExp(r'\b(weekdays|every\s+weekday|mon\s*-\s*fri)\b'), (_) => rep = [1, 2, 3, 4, 5]);
  take(RegExp('\\bevery\\s+$wdRe\\b'), (m) {
    final k = _wdKeys.indexWhere((x) => m.group(1)!.startsWith(x));
    rep = [_dw(k)];
    wd = k;
  });
  var weekly = false;
  take(RegExp(r'\b(every\s+week|weekly)\b'), (_) => weekly = true);
  take(RegExp(r'\bin\s+(\d+)\s*(min|mins|minutes|minute|m|hour|hours|hr|hrs|h)\b'), (m) => inMin = int.parse(m.group(1)!) * (m.group(2)!.startsWith('h') ? 60 : 1));
  take(RegExp(r'\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s?(am|pm)\b'), (m) {
    h = (int.parse(m.group(1)!) % 12) + (m.group(3) == 'pm' ? 12 : 0);
    mi = int.tryParse(m.group(2) ?? '') ?? 0;
  });
  if (h == null) {
    take(RegExp(r'\bat\s+(\d{1,2})(?::(\d{2}))?\b'), (m) {
      h = int.parse(m.group(1)!);
      mi = int.tryParse(m.group(2) ?? '') ?? 0;
      if (h! < 8) h = h! + 12;
    });
  }
  // "12:00", "7:30" with no am/pm (speech often writes times like this).
  if (h == null) {
    take(RegExp(r'(?<![\d:])(\d{1,2}):(\d{2})(?![\d:])'), (m) {
      h = int.parse(m.group(1)!);
      mi = int.parse(m.group(2)!);
      if (h! < 8 && part == null) h = h! + 12;
    });
  }
  take(RegExp(r'\b(?:at\s+)?(noon|midnight)\b'), (m) {
    h = m.group(1) == 'noon' ? 12 : 23;
    mi = m.group(1) == 'noon' ? 0 : 59;
  });
  take(RegExp(r'\b(tonight)\b'), (_) {
    dayOff = 0;
    part = 21;
  });
  take(RegExp(r'\b(today)\b'), (_) => dayOff = 0);
  take(RegExp(r'\b(tomorrow|tmrw|tmr)\b'), (_) => dayOff = 1);
  take(RegExp(r'\b(this\s+)?weekend\b'), (_) {
    wd = 6;
    part ??= 10;
  });
  take(RegExp('\\b(?:on\\s+|next\\s+|this\\s+)?$wdRe\\b'), (m) => wd = _wdKeys.indexWhere((x) => m.group(1)!.startsWith(x)));
  take(RegExp(r'\b(?:in\s+the\s+)?(morning|afternoon|evening)\b'), (m) => part = const {'morning': 9, 'afternoon': 14, 'evening': 19}[m.group(1)]);

  final found = ranges.isNotEmpty;
  DateTime? date;
  if (found) {
    if (inMin != null) {
      date = nowD.add(Duration(minutes: inMin!));
    } else {
      final hh = h ?? part ?? 9;
      var d = DateTime(nowD.year, nowD.month, nowD.day);
      if (dayOff != null) {
        d = DateTime(d.year, d.month, d.day + dayOff!);
      } else if (wd != null) {
        var add = (wd! - (d.weekday % 7) + 7) % 7;
        if (add == 0 && hh * 60 + mi <= nowD.hour * 60 + nowD.minute) add = 7;
        d = DateTime(d.year, d.month, d.day + add);
      }
      date = DateTime(d.year, d.month, d.day, hh, h != null ? mi : 0);
      if (dayOff == null && wd == null && !date.isAfter(nowD)) date = date.add(const Duration(days: 1));
      if (dayOff == 0 && !date.isAfter(nowD) && h != null && h! < 12 && h! + 12 > nowD.hour) date = DateTime(date.year, date.month, date.day, h! + 12, mi);
    }
  }
  if (weekly && date != null) rep = [date.weekday];
  ranges.sort((a, b) => a.$1.compareTo(b.$1));
  final sb = StringBuffer();
  var last = 0;
  for (final (a, b) in ranges) {
    if (a > last) sb.write(src.substring(last, a));
    if (b > last) last = b;
  }
  sb.write(src.substring(last.clamp(0, src.length)));
  var title = sb.toString().replaceAll(RegExp(r'\s{2,}'), ' ').replaceAll(RegExp(r'\s+(at|on|by|in|the|-|,)\s*$', caseSensitive: false), '').replaceAll(RegExp(r'^\s*(at|on|by)\s+', caseSensitive: false), '').trim();
  if (title.isNotEmpty) title = title[0].toUpperCase() + title.substring(1);
  return NL(found: found, ranges: ranges, date: date, title: title, repeat: rep);
}

final _lead = RegExp(
  r"^\s*(?:(?:ok(?:ay)?|hey|so|and|also|then|um+|uh+)[\s,]+)*(?:(?:i\s+(?:want|need|have|got|wanna)\s+to|i(?:'m|\s+am)\s+going\s+to|i\s+will|i'll|remind\s+me\s+to|remind\s+me|remember\s+to|don'?t\s+forget\s+to|please|i\s+(?:want|need)|add)\s+)?",
  caseSensitive: false,
);

/// "I want to call mom" → "Call mom"; "mujhe doodh lana hai" → "Doodh lana".
String cleanTitle(String t) {
  var s = t
      .replaceAll(RegExp(r'(^|\s)(mujhe|muje|mujhko|मुझे|मुझको)(?=\s|$)', caseSensitive: false, unicode: true), ' ')
      .replaceAll(RegExp(r'(^|\s)(yaad\s+(?:dila(?:na|\s+dena|o)?|rakhna)|याद\s+दिला(?:ना|\s+देना)?|remind\s+kar(?:na|\s+dena|o)?)(?=\s|$)', caseSensitive: false, unicode: true), ' ')
      .replaceAll(RegExp(r'\s+(hai|hain|he|h|है|हैं|hoga|होगा)\s*[.!।]?\s*$', caseSensitive: false, unicode: true), '')
      .replaceAll(RegExp(r'^\s*(ki|ko|ke|को|के)\s+', caseSensitive: false, unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      // Leftover joiners from speech: "और …", "… and"
      .replaceAll(RegExp(r'^\s*(?:और|aur|and|phir|फिर)\s+|\s+(?:और|aur|and|phir|फिर)\s*$', caseSensitive: false, unicode: true), '')
      .replaceFirst(_lead, '')
      .replaceAll(RegExp(r'\s+(?:and\s+so|etc|and\s+all|so\s+on)\.?$', caseSensitive: false), '')
      .replaceAll(RegExp(r'[.,;]+$'), '')
      .trim();
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

class SplitPart {
  SplitPart(this.text, this.timed, this.nl, this.title);
  final String text;
  final bool timed;
  NL nl;
  String title;
}

class Split {
  Split(this.parts, this.listTitle, this.def);
  final List<SplitPart> parts;
  final String listTitle;

  /// 'reminders' or 'list'
  final String def;
}

final _timed = RegExp(r'\d{1,2}:\d{2}|baje|बजे|subah|dopahar|dophar|shaam|raat|सुबह|दोपहर|शाम|रात|\d\s*(?:am|pm)\b|\bat\s+\d|\bnoon\b|\bmidnight\b|\btonight\b|\bin\s+\d+\s*(?:min|hour|hr)|\b(?:morning|afternoon|evening)\b', caseSensitive: false);
final _dayw = RegExp(r'(?<![\p{L}\p{M}])(kal|aaj|parso|parson|कल|आज|परसों|पर्सन|today|tonight|tomorrow|tmrw|tmr|(?:on\s+)?(?:mon|tues|wednes|thurs|fri|satur|sun)day)(?![\p{L}\p{M}])', caseSensitive: false, unicode: true);

/// True when [text] names a day (kal, tomorrow, Monday…).
bool mentionsDay(String text) => _dayw.hasMatch(text);

/// "dairy at 7 am and school at 10 pm" → 2 reminders (or one to-do list).
/// "buy milk, eggs and bread" → a shopping list. Null for a single thing.
Split? splitTasks(String text, {DateTime? now}) {
  final raw = text.trim();
  if (raw.isEmpty || RegExp(r'https?://|www\.').hasMatch(raw)) return null;
  final segs = raw
      .split(RegExp(r'\s*(?:,|;|\band\s+then\b|\bthen\b|\band\s+also\b|\balso\b|\band\b|\baur\b|\bphir\b|\buske\s+baad\b)\s*|\s+(?:और|फिर|उसके\s+बाद)\s+', caseSensitive: false))
      .map((x) => x.trim())
      .where((x) => x.replaceFirst(_lead, '').replaceAll(RegExp(r'^(so|etc|all|on)$', caseSensitive: false), '').trim().length > 1)
      .toList();
  if (segs.length < 2) return null;
  var carry = '';
  final parts = <SplitPart>[];
  for (final sg in segs) {
    final dm = _dayw.firstMatch(sg);
    if (dm != null) carry = dm.group(0)!;
    final timed = _timed.hasMatch(sg) || dm != null;
    final r = parseNL(timed && dm == null && carry.isNotEmpty ? '$sg $carry' : sg, now: now);
    final p = SplitPart(sg, timed, r, cleanTitle(r.found ? r.title : sg));
    if (p.title.length > 1) parts.add(p);
  }
  if (parts.length < 2) return null;
  // "dairy at 7 am and school at 10" → school is 10 pm, not 10 am.
  DateTime? prev;
  for (final p in parts) {
    final d = p.nl.date;
    if (d != null && prev != null && d.isBefore(prev) && !RegExp(r'\b(am|pm)\b|morning', caseSensitive: false).hasMatch(p.text) && d.hour < 12) {
      final n = d.add(const Duration(hours: 12));
      if (n.isAfter(prev)) p.nl = NL(found: true, ranges: p.nl.ranges, date: n, title: p.nl.title, repeat: p.nl.repeat);
    }
    if (p.nl.date != null) prev = p.nl.date;
  }
  final timedN = parts.where((p) => p.timed).length;
  final cue = RegExp(r'^(to\s*-?\s*do(?:\s+list)?|list|shopping|grocer\w*|buy|get|pick\s+up|pack)\b[:\s]*', caseSensitive: false).firstMatch(raw.replaceFirst(_lead, ''));
  if (timedN < 2 && cue == null && parts.length < 3) return null;
  var listTitle = 'To-do list';
  if (cue != null) {
    final c = cue.group(1)!.toLowerCase();
    listTitle = RegExp('buy|get|shop|grocer|pick').hasMatch(c) ? 'Shopping list' : c.contains('pack') ? 'Packing list' : 'To-do list';
    if (RegExp('^(to|list)').hasMatch(c)) {
      parts[0].title = cleanTitle(parts[0].title.replaceFirst(RegExp(r'^(to\s*-?\s*do(\s+list)?|list)[:\s]*', caseSensitive: false), ''));
    } else if (RegExp('buy|get|pick|pack').hasMatch(c)) {
      parts[0].title = cleanTitle(parts[0].title.replaceFirst(RegExp(r'^(buy|get|pick\s+up|pack)\s+', caseSensitive: false), ''));
    }
  }
  final day = parts.where((p) => p.nl.date != null).firstOrNull;
  if (timedN >= 2 && cue == null && day != null) {
    final same = parts.every((p) => p.nl.date == null || _sameDay(p.nl.date!, day.nl.date!));
    listTitle = same ? 'Plan for ${_dayWord(day.nl.date!, now ?? AppStore.now())}' : 'My plan';
  }
  return Split(parts, listTitle, timedN >= 2 && cue == null ? 'reminders' : 'list');
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String _dayWord(DateTime d, DateTime now) {
  final diff = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (diff == 0) return 'today';
  if (diff == 1) return 'tomorrow';
  return const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][d.weekday - 1];
}

const _lstop = {
  'watch', 'video', 'reel', 'post', 'link', 'read', 'check', 'open', 'look', 'this', 'that', 'with', 'remind', 'later', 'tonight', 'tomorrow', 'morning', 'evening', 'weekend', 'again', 'about',
  'from', 'want', 'need', 'have', 'please', 'recipe', 'article', 'saved', 'dekhna', 'dekh', 'padhna', 'yaad',
};

/// "remind me to watch the pasta video tonight" → the saved pasta video.
/// [recent] is the link saved in the last half hour, for "this"/"that".
Item? linkTarget(String text, List<Item> items, {Item? recent}) {
  final t = text.toLowerCase();
  if (!RegExp('(watch|see|read|open|check|look|dekh|padh|देख|पढ़|reel|video|post|link|recipe|article|vid)').hasMatch(t)) return null;
  final links = items.where((i) => i.kind == ItemKind.link && !i.isDone).toList();
  if (recent != null && links.contains(recent) && RegExp(r'\b(this|that|it|isko|ise|ye|yeh|wo|woh)\b|(इसे|इसको|ये|वो)').hasMatch(t)) return recent;
  final words = t.split(RegExp(r'[^a-z0-9ऀ-ॿ]+')).where((w) => w.length > 3 && !_lstop.contains(w)).toList();
  Item? best;
  var score = 0;
  for (final l in links) {
    final lw = l.title.toLowerCase().split(RegExp(r'[^a-z0-9]+'));
    final sc = words.where((w) => lw.any((x) => x.length > 3 && (x == w || x.startsWith(w) || w.startsWith(x)))).length;
    if (sc > score) {
      score = sc;
      best = l;
    }
  }
  return score > 0 ? best : null;
}


/// Join speech heard in pieces without repeating words: "kal 3 baje" +
/// "3 baje doodh lana" → "kal 3 baje doodh lana".
String mergeSpeech(String acc, String seg) {
  acc = acc.trim();
  seg = seg.trim();
  if (acc.isEmpty) return seg;
  if (seg.isEmpty) return acc;
  final al = acc.toLowerCase(), sl = seg.toLowerCase();
  if (al.endsWith(sl) || al.contains(sl)) return acc;
  if (sl.startsWith(al)) return seg;
  final aw = acc.split(RegExp(r'\s+')), sw = seg.split(RegExp(r'\s+'));
  for (var k = aw.length < sw.length ? aw.length : sw.length; k > 0; k--) {
    var same = true;
    for (var i = 0; i < k; i++) {
      if (aw[aw.length - k + i].toLowerCase() != sw[i].toLowerCase()) {
        same = false;
        break;
      }
    }
    if (same) return [...aw, ...sw.sublist(k)].join(' ');
  }
  return '$acc $seg';
}
