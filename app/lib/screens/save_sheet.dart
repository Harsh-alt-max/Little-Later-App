import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../mascot/mascot_svg.dart';
import '../mascot/mascot_view.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';
import '../widgets/kit.dart';

// =============================================================================
// Link understanding (v7 KIND/parse) + real page titles

class LinkInfo {
  LinkInfo({required this.url, required this.domain, required this.title, required this.kind, this.folderKind, required this.line});
  final String url, domain, kind, line;
  String title;
  final String? folderKind;
}

const _kinds = [
  (r'youtube|vimeo|youtu\.be|tiktok|reel', 'Video', 'hobby', 'A video! Hobby, maybe?'),
  (r'docs\.google|notion|figma|github|linkedin', 'Doc', 'work', 'Looks like work stuff.'),
  (r'pinterest|instagram|etsy', 'Inspo', 'love', 'Pretty! Saving for someone?'),
  (r'airbnb|booking|tripadvisor|maps\.google|goo\.gl/maps', 'Travel', 'trip', 'Ooh, a trip idea!'),
  (r'recipe|food|cook', 'Recipe', 'hobby', 'Yum, a recipe!'),
];

/// Pull the first http(s) link out of shared text.
String? extractUrl(String text) => RegExp(r'https?://[^\s<>"]+').firstMatch(text)?.group(0);

LinkInfo? parseLink(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (!s.contains('://') && RegExp(r'^[\w-]+(\.[\w-]+)+(/.*)?$').hasMatch(s)) s = 'https://$s';
  final u = Uri.tryParse(s);
  if (u == null || !(u.scheme == 'http' || u.scheme == 'https') || !u.host.contains('.')) return null;
  final d = u.host.replaceFirst(RegExp(r'^www\.'), '');
  final seg = u.pathSegments.where((e) => e.isNotEmpty).toList();
  var t = seg.isEmpty ? '' : Uri.decodeComponent(seg.last).replaceAll(RegExp(r'[-_+]'), ' ').replaceAll(RegExp(r'\.\w+$'), '').trim();
  if (t.length < 3 || RegExp(r'^[\w]{8,}$').hasMatch(t) && !t.contains(' ')) t = '';
  final k = _kinds.where((k) => RegExp(k.$1).hasMatch('$d${u.path}')).firstOrNull;
  return LinkInfo(
    url: s,
    domain: d,
    title: t.isEmpty ? 'Link from $d' : t[0].toUpperCase() + t.substring(1),
    kind: k?.$2 ?? 'Link',
    folderKind: k?.$3,
    line: k?.$4 ?? 'Nice find!',
  );
}

/// Best-effort real title (YouTube oEmbed, else og:title / <title>).
Future<String?> fetchTitle(LinkInfo info) async {
  try {
    if (RegExp('youtube|youtu.be').hasMatch(info.domain)) {
      final r = await http.get(Uri.parse('https://www.youtube.com/oembed?format=json&url=${Uri.encodeComponent(info.url)}')).timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) return (jsonDecode(r.body) as Map)['title'] as String?;
    }
    final r = await http.get(Uri.parse(info.url), headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android 14) LittleLater/1.4'}).timeout(const Duration(seconds: 5));
    if (r.statusCode != 200) return null;
    final body = r.body.length > 200000 ? r.body.substring(0, 200000) : r.body;
    final og = RegExp(r'''<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)''', caseSensitive: false).firstMatch(body)?.group(1) ??
        RegExp(r'''<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:title''', caseSensitive: false).firstMatch(body)?.group(1);
    final tt = og ?? RegExp(r'<title[^>]*>([^<]{2,200})</title>', caseSensitive: false).firstMatch(body)?.group(1);
    if (tt == null) return null;
    return _unescape(tt.trim());
  } catch (_) {
    return null;
  }
}

String _unescape(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&#x27;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll(RegExp(r'\s+'), ' ');

/// Folder suggestion for a link kind ('hobby', 'work', …) among the user's folders.
Folder? suggestFolder(AppStore s, String? kind) {
  if (kind == null) return null;
  for (final f in s.folders) {
    if (f.kind == kind || f.iconKey == const {'hobby': 'spark', 'work': 'bag', 'love': 'heart', 'trip': 'plane'}[kind]) return f;
  }
  return null;
}

// =============================================================================
// When options (v7 WHEN)

enum When { hour, tonight, today, tomorrow, custom, none }

DateTime _at(int dayOff, int h, [int m = 0]) {
  final n = AppStore.now();
  return DateTime(n.year, n.month, n.day + dayOff, h, m);
}

DateTime? whenDate(When w, AppStore s, DateTime? custom) {
  final n = AppStore.now();
  switch (w) {
    case When.hour:
      final d = n.add(const Duration(hours: 1));
      final m = ((d.minute + 4) ~/ 5) * 5;
      return DateTime(d.year, d.month, d.day, d.hour).add(Duration(minutes: m));
    case When.tonight:
      return _at(n.hour >= 20 ? 1 : 0, 20);
    case When.today:
      return _at(n.hour >= 18 ? 1 : 0, 18);
    case When.tomorrow:
      return _at(1, s.morningHour);
    case When.custom:
      return custom;
    case When.none:
      return null;
  }
}

const _whenMeta = {
  When.hour: ('In 1 hour', 'clock'),
  When.tonight: ('Tonight', 'moon'),
  When.today: ('Later today', 'sun'),
  When.tomorrow: ('Tomorrow', 'sunrise'),
  When.custom: ('Pick time', 'clock'),
  When.none: ('No reminder', 'off'),
};

String fmtDue(DateTime d) => '${fmtDay(d)}, ${fmtT(d)}';
String dayLow(DateTime d) {
  final x = fmtDay(d);
  return x == 'Today' || x == 'Tomorrow' ? x.toLowerCase() : x;
}

// =============================================================================
// Save sheet

enum SaveMode { link, reminder, todo }

Future<void> openSaveSheet(BuildContext context, {String url = '', String folder = ''}) {
  final scope = AppScope.of(context);
  scope.buzz(1);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x7308121E),
    builder: (_) => scope.wrap(_SaveSheet(initialUrl: url, initialFolder: folder)),
  );
}

class _SaveSheet extends StatefulWidget {
  const _SaveSheet({required this.initialUrl, required this.initialFolder});
  final String initialUrl, initialFolder;
  @override
  State<_SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends State<_SaveSheet> {
  final _m = MascotController();
  final _bubble = BubbleController();
  final _link = TextEditingController();
  final _rem = TextEditingController();
  final _todo = TextEditingController();
  final _step = TextEditingController();
  final _remF = FocusNode(), _todoF = FocusNode(), _stepF = FocusNode();
  SaveMode _mode = SaveMode.link;
  When _when = When.tomorrow;
  DateTime? _custom;
  final List<String> _steps = [];
  String _folder = '';
  bool _suggested = false;
  LinkInfo? _info;
  bool _loadingTitle = false;
  Timer? _debounce;
  int _titleGen = 0;

  AppScope get s => AppScope.of(context);

  static const _modes = {
    SaveMode.link: ('Got a link for me?', 'Save link', 'Remind me', [When.tonight, When.tomorrow, When.custom, When.none]),
    SaveMode.reminder: ('What should I remind you about?', 'Set reminder', 'When', [When.hour, When.tonight, When.tomorrow, When.custom]),
    SaveMode.todo: ('What’s on the list?', 'Add to-do', 'Due', [When.today, When.tomorrow, When.custom, When.none]),
  };

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _m.play(MascotAct.hop);
      _bubble.say(_modes[_mode]!.$1, 0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_folder.isEmpty) {
      final st = s.store;
      _folder = widget.initialFolder.isNotEmpty ? widget.initialFolder : (st.folders.isEmpty ? '' : st.folders.first.name);
      if (widget.initialUrl.isNotEmpty) {
        _link.text = widget.initialUrl;
        _onLink(widget.initialUrl, now: true);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _m.dispose();
    _bubble.dispose();
    for (final c in [_link, _rem, _todo, _step]) {
      c.dispose();
    }
    for (final f in [_remF, _todoF, _stepF]) {
      f.dispose();
    }
    super.dispose();
  }

  void _setMode(SaveMode m) {
    if (m == _mode) return;
    s.buzz(0);
    setState(() {
      _mode = m;
      final ws = _modes[m]!.$4;
      if (!ws.contains(_when)) _when = ws.contains(When.tomorrow) ? When.tomorrow : ws.first;
    });
    _m.play(MascotAct.nod);
    _bubble.say(_modes[m]!.$1, 0);
    Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      if (m == SaveMode.reminder) _remF.requestFocus();
      if (m == SaveMode.todo) _todoF.requestFocus();
    });
  }

  void _onLink(String v, {bool now = false}) {
    _debounce?.cancel();
    if (!now) {
      _m.setBase(Mood.wow);
      _bubble.say('Ooh, what is it?', 0);
    }
    _debounce = Timer(Duration(milliseconds: now ? 0 : 450), () {
      final info = parseLink(extractUrl(v) ?? v);
      setState(() => _info = info);
      if (info == null) {
        _m.setBase(Mood.idle);
        return;
      }
      _m.play(MascotAct.nod);
      _m.setBase(Mood.idle);
      _m.mood(Mood.happy, const Duration(milliseconds: 900));
      _bubble.say(info.line, 0);
      final sug = suggestFolder(s.store, info.folderKind);
      if (sug != null && sug.name != _folder) {
        setState(() {
          _folder = sug.name;
          _suggested = true;
        });
      }
      final gen = ++_titleGen;
      setState(() => _loadingTitle = true);
      fetchTitle(info).then((tt) {
        if (!mounted || gen != _titleGen) return;
        setState(() {
          _loadingTitle = false;
          if (tt != null && tt.isNotEmpty) info.title = tt;
        });
      });
    });
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData('text/plain');
    final txt = d?.text ?? '';
    final u = extractUrl(txt);
    if (u == null) {
      s.toast.show('No link on your clipboard');
      return;
    }
    s.buzz(0);
    _link.text = u;
    _onLink(u, now: true);
  }

  bool get _valid {
    if (_when == When.custom && _custom == null) return false;
    return switch (_mode) {
      SaveMode.link => _info != null,
      SaveMode.reminder => _rem.text.trim().length > 1,
      SaveMode.todo => _todo.text.trim().length > 1,
    };
  }

  Future<void> _pickWhen(When w) async {
    s.buzz(0);
    if (w == When.custom) {
      final d = await pickTime(context, initial: _custom ?? whenDate(When.tomorrow, s.store, null)!);
      if (d == null || !mounted) return;
      setState(() {
        _custom = d;
        _when = When.custom;
      });
      _m.play(MascotAct.nod);
      _bubble.say('${fmtDay(d)}, ${fmtT(d)}. Got it.', 0);
      return;
    }
    setState(() => _when = w);
    if (w == When.none) {
      _m.mood(Mood.sleep, const Duration(milliseconds: 1100));
      _bubble.say(_mode == SaveMode.todo ? 'Whenever works.' : 'I’ll keep it quietly.', 0);
    } else {
      final d = whenDate(w, s.store, null)!;
      _m.play(MascotAct.nod);
      _bubble.say('${fmtDay(d)}, ${fmtT(d)}. Got it.', 0);
    }
  }

  void _addStep() {
    final v = _step.text.trim();
    if (v.isEmpty) return;
    setState(() {
      _steps.add(v);
      _step.clear();
    });
    s.buzz(0);
    if (_steps.length == 3) _bubble.say('Nice, broken into steps!', 0);
    _stepF.requestFocus();
  }

  Future<void> _newFolder() async {
    final f = await newFolderSheet(context);
    if (f != null && mounted) {
      setState(() {
        _folder = f.name;
        _suggested = false;
      });
      _bubble.say('New folder: ${shortText(f.name, 12)}', 0);
    }
  }

  Future<void> _save() async {
    if (!_valid) return;
    final st = s.store;
    final d = whenDate(_when, st, _custom);
    final id = newId();
    late Item it;
    late String msg;
    switch (_mode) {
      case SaveMode.link:
        final info = _info!;
        it = Item(id: id, kind: ItemKind.link, title: info.title, folder: _folder, url: info.url, reminder: d?.millisecondsSinceEpoch ?? 0);
        msg = 'Saved!';
      case SaveMode.reminder:
        it = Item(id: id, kind: ItemKind.reminder, title: _rem.text.trim(), folder: _folder, reminder: d?.millisecondsSinceEpoch ?? 0);
        msg = 'I’ll remind you!';
      case SaveMode.todo:
        if (_step.text.trim().isNotEmpty) _steps.add(_step.text.trim());
        it = Item(
          id: id,
          kind: ItemKind.todoList,
          title: _todo.text.trim(),
          folder: _folder,
          dueAt: d?.millisecondsSinceEpoch ?? 0,
          tasks: [for (var i = 0; i < _steps.length; i++) TodoTask(id: '$id-$i', text: _steps[i])],
        );
        msg = 'On the list!';
    }
    s.buzz(2);
    _m.play(MascotAct.hop);
    _m.mood(Mood.happy);
    _bubble.say(msg, 0);
    st.addItem(it);
    if (d != null) s.app.reminders.askPermission();
    final scope = s;
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    Navigator.pop(context);
    scope.app.gain(5, line: 'Got it, safe with me.');
    final fname = _folder.isEmpty ? 'Saved' : _folder;
    scope.toast.show('${_mode == SaveMode.todo ? 'Added' : 'Saved'} to $fname${d != null ? ', ${dayLow(d)} ${fmtT(d)}' : ''}');
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final st = s.store;
    final mode = _modes[_mode]!;
    final top = MediaQuery.paddingOf(context).top;
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      margin: EdgeInsets.only(top: top + 20),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(38)),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0, .45], colors: [ll.headB, ll.bg]),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(
          top: -80,
          left: 0,
          right: 0,
          height: 320,
          child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(colors: [ll.headA, ll.headA.withValues(alpha: 0)], stops: const [0, .7]))),
        ),
        Column(children: [
          // .sh-top
          SizedBox(
            height: kb > 0 ? 120 : 236,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(top: 10, left: 0, right: 0, child: Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: ll.inkMix(.18), borderRadius: BorderRadius.circular(9))))),
              Positioned(left: 18, top: 22, child: Circ(icon: 'x', size: 44, label: 'Close', onTap: () => Navigator.pop(context))),
              if (kb == 0) ...[
                const Positioned(left: 44, top: 120, child: _Floaty(size: 16)),
                const Positioned(right: 46, top: 150, child: _Floaty(size: 12, delay: 2)),
                const Positioned(right: 70, top: 72, child: _Floaty(size: 9, delay: 4)),
              ],
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                left: 0,
                right: 0,
                top: kb > 0 ? 14 : 36,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      _m.play(MascotAct.squish);
                      _m.mood(Mood.happy, const Duration(milliseconds: 700));
                      s.buzz(0);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: kb > 0 ? 92 : 170,
                      height: kb > 0 ? 100 : 186,
                      child: MascotView(stage: st.level.n, controller: _m, style: st.mascotStyle, outfit: st.outfitNow),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: MediaQuery.sizeOf(context).width / 2 + (kb > 0 ? 40 : 52),
                top: kb > 0 ? 10 : 40,
                child: SpeechBubble(controller: _bubble, tailLeft: true, wrap: true, maxWidth: MediaQuery.sizeOf(context).width / 2 - 64),
              ),
            ]),
          ),
          // .sh-body
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: ll.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(34))),
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + (kb > 0 ? kb : bottom)),
                children: [
                  Segmented(labels: const ['Link', 'Reminder', 'To-do'], icons: const ['link', 'bell', 'check'], index: _mode.index, onChanged: (i) => _setMode(SaveMode.values[i])),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .1), end: Offset.zero).animate(a), child: c)),
                    child: KeyedSubtree(key: ValueKey(_mode), child: _fields(ll)),
                  ),
                  Lab('Folder', hint: _suggested ? 'Suggested' : ''),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(children: [
                      for (final f in st.folders) ...[
                        FolderPill(
                          icon: f.iconKey,
                          label: f.name,
                          on: f.name == _folder,
                          onTap: () {
                            s.buzz(0);
                            setState(() {
                              _folder = f.name;
                              _suggested = false;
                            });
                            _bubble.say('${f.name} it is.', 0);
                          },
                        ),
                        const SizedBox(width: 10),
                      ],
                      FolderPill(icon: 'plus', label: 'New', dashed: true, onTap: _newFolder),
                    ]),
                  ),
                  Lab(mode.$3),
                  _whens(ll, mode.$4),
                  const SizedBox(height: 22),
                  BigButton(label: mode.$2, xp: 5, enabled: _valid, onTap: _save),
                ],
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _fields(LL ll) {
    switch (_mode) {
      case SaveMode.link:
        return Column(children: [
          LLInput(
            controller: _link,
            hint: 'Paste a link',
            icon: 'link',
            keyboard: TextInputType.url,
            onChanged: (v) => _onLink(v),
            trailing: Tap(
              onTap: _paste,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: ll.ink, borderRadius: BorderRadius.circular(14)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.content_paste_rounded, size: 16, color: ll.onInk),
                  const SizedBox(width: 6),
                  Text('Paste', style: t(13.5, FontWeight.w800, ll.onInk)),
                ]),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 450),
            curve: Motion.smooth,
            child: _info == null ? const SizedBox(width: double.infinity) : Padding(padding: const EdgeInsets.only(top: 12), child: LinkPreview(info: _info!, loading: _loadingTitle)),
          ),
        ]);
      case SaveMode.reminder:
        return LLInput(controller: _rem, focusNode: _remF, hint: 'Remind me to…', icon: 'bell', maxLength: 80, onChanged: (_) => setState(() {}));
      case SaveMode.todo:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LLInput(controller: _todo, focusNode: _todoF, hint: 'What needs doing?', icon: 'check', maxLength: 80, onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),
          for (var i = 0; i < _steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                decoration: BoxDecoration(color: ll.surface2, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Container(width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ll.ink3, width: 1.6))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_steps[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: t(14, FontWeight.w600, ll.ink))),
                  Tap(
                    onTap: () => setState(() => _steps.removeAt(i)),
                    semanticLabel: 'Remove step',
                    child: SizedBox(width: 30, height: 30, child: Center(child: LLIcon('x', size: 15, color: ll.ink3))),
                  ),
                ]),
              ),
            ),
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: ll.line, width: 1.5)),
            child: Row(children: [
              LLIcon('plus', size: 17, color: ll.ink3),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _step,
                  focusNode: _stepF,
                  maxLength: 60,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _addStep(),
                  style: t(14.5, FontWeight.w600, ll.ink),
                  decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, counterText: '', hintText: 'Add a step, then press enter', hintStyle: t(14.5, FontWeight.w600, ll.ink3)),
                ),
              ),
            ]),
          ),
        ]);
    }
  }

  Widget _whens(LL ll, List<When> ws) {
    final st = s.store;
    Widget tile(When k) {
      final on = _when == k;
      final meta = _whenMeta[k]!;
      String sub;
      if (k == When.custom) {
        sub = _custom != null ? fmtDue(_custom!) : 'Day and time';
      } else if (k == When.none) {
        sub = _mode == SaveMode.todo ? 'Whenever' : 'Just keep it';
      } else {
        final d = whenDate(k, st, null)!;
        final today = fmtDay(d) == 'Today';
        sub = (today || k == When.tomorrow ? '' : '${fmtDay(d)}, ') + fmtT(d);
      }
      final label = k == When.none && _mode == SaveMode.todo ? 'No date' : meta.$1;
      return Tap(
        onTap: () => _pickWhen(k),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: on ? ll.blue : ll.surface2, borderRadius: BorderRadius.circular(22), boxShadow: on ? ll.blueGlow(.3) : null),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: on ? Colors.white.withValues(alpha: .22) : ll.surface),
              child: LLIcon(meta.$2, size: 19, color: on ? Colors.white : ll.ink2),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(14.5, FontWeight.w800, on ? Colors.white : ll.ink)),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(12.5, FontWeight.w600, on ? Colors.white.withValues(alpha: .78) : ll.ink3)),
              ]),
            ),
          ]),
        ),
      );
    }

    return Column(children: [
      Row(children: [Expanded(child: tile(ws[0])), const SizedBox(width: 10), Expanded(child: tile(ws[1]))]),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: tile(ws[2])), const SizedBox(width: 10), Expanded(child: tile(ws[3]))]),
    ]);
  }
}

class _Floaty extends StatefulWidget {
  const _Floaty({required this.size, this.delay = 0});
  final double size;
  final int delay;
  @override
  State<_Floaty> createState() => _FloatyState();
}

class _FloatyState extends State<_Floaty> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  @override
  void initState() {
    super.initState();
    c.value = widget.delay / 6;
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, _) {
          final k = (1 - (c.value * 2 - 1).abs());
          return Transform.translate(
            offset: Offset(0, -10 * k),
            child: Transform.rotate(angle: .31 * k, child: Icon(Icons.auto_awesome, size: widget.size, color: LL.of(context).blue.withValues(alpha: .55))),
          );
        },
      );
}

/// .pv link preview card.
class LinkPreview extends StatelessWidget {
  const LinkPreview({super.key, required this.info, this.loading = false});
  final LinkInfo info;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: ll.blueSoft, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(14)),
          child: Text(info.domain.isEmpty ? '?' : info.domain[0].toUpperCase(), style: t(16, FontWeight.w800, ll.blueInk)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedOpacity(
              opacity: loading ? .55 : 1,
              duration: const Duration(milliseconds: 250),
              child: Text(info.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t(14.5, FontWeight.w800, ll.ink, h: 1.3)),
            ),
            Text(info.domain, style: t(12.5, FontWeight.w600, ll.ink2)),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(99)),
          child: Text(info.kind, style: t(12, FontWeight.w800, ll.blueInk)),
        ),
      ]),
    );
  }
}

// =============================================================================
// Time picker: 14-day strip + hour/minute/am-pm wheels

Future<DateTime?> pickTime(BuildContext context, {required DateTime initial}) {
  return showLLSheet<DateTime>(context, builder: (_) => _TimePicker(initial: initial));
}

class _TimePicker extends StatefulWidget {
  const _TimePicker({required this.initial});
  final DateTime initial;
  @override
  State<_TimePicker> createState() => _TimePickerState();
}

class _TimePickerState extends State<_TimePicker> {
  late final List<DateTime> days;
  late int day, hh, mm, ap;
  late final FixedExtentScrollController _h, _m, _a;
  final _strip = ScrollController();
  static const _dow = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    final n = AppStore.now();
    days = List.generate(14, (i) => DateTime(n.year, n.month, n.day + i));
    final init = widget.initial;
    day = days.indexWhere((d) => d.year == init.year && d.month == init.month && d.day == init.day);
    if (day < 0) day = 1;
    hh = init.hour % 12 == 0 ? 12 : init.hour % 12;
    mm = ((init.minute / 5).round() * 5) % 60;
    ap = init.hour < 12 ? 0 : 1;
    _h = FixedExtentScrollController(initialItem: hh - 1);
    _m = FixedExtentScrollController(initialItem: mm ~/ 5);
    _a = FixedExtentScrollController(initialItem: ap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_strip.hasClients) _strip.jumpTo((day * 66.0 - 20).clamp(0, _strip.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _h.dispose();
    _m.dispose();
    _a.dispose();
    _strip.dispose();
    super.dispose();
  }

  DateTime get _sel {
    final d = days[day];
    return DateTime(d.year, d.month, d.day, (hh % 12) + (ap == 1 ? 12 : 0), mm);
  }

  void _reset() {
    final d = whenDate(When.hour, AppScope.of(context).store, null)!;
    setState(() => day = 0);
    _h.animateToItem((d.hour % 12 == 0 ? 12 : d.hour % 12) - 1, duration: const Duration(milliseconds: 400), curve: Motion.smooth);
    _m.animateToItem(d.minute ~/ 5, duration: const Duration(milliseconds: 400), curve: Motion.smooth);
    _a.animateToItem(d.hour < 12 ? 0 : 1, duration: const Duration(milliseconds: 400), curve: Motion.smooth);
  }

  Widget _wheel(FixedExtentScrollController c, List<String> items, double w, ValueChanged<int> on, int sel, {double fs = 22}) {
    final ll = LL.of(context);
    return SizedBox(
      width: w,
      height: 220,
      child: ListWheelScrollView.useDelegate(
        controller: c,
        itemExtent: 44,
        physics: const FixedExtentScrollPhysics(),
        diameterRatio: 1.6,
        perspective: .003,
        onSelectedItemChanged: (i) {
          HapticFeedback.selectionClick();
          setState(() => on(i));
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: items.length,
          builder: (_, i) => Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              style: t(fs, i == sel ? FontWeight.w800 : FontWeight.w700, i == sel ? ll.ink : ll.ink3).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              child: Text(items[i]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final bad = _sel.isBefore(AppStore.now());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle('Pick a time', action: 'Reset', onAction: _reset),
      SizedBox(
        height: 74,
        child: ListView.separated(
          controller: _strip,
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: days.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final on = i == day;
            final d = days[i];
            return Tap(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => day = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 58,
                height: 70,
                decoration: BoxDecoration(color: on ? ll.blue : ll.surface2, borderRadius: BorderRadius.circular(20), boxShadow: on ? ll.blueGlow(.32, 22) : null),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(i == 0 ? 'Today' : i == 1 ? 'Tmrw' : _dow[d.weekday - 1], style: t(11.5, FontWeight.w800, on ? Colors.white70 : ll.ink3)),
                  const SizedBox(height: 3),
                  Text('${d.day}', style: t(20, FontWeight.w800, on ? Colors.white : ll.ink)),
                ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      ShaderMask(
        shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent], stops: [0, .3, .7, 1]).createShader(r),
        blendMode: BlendMode.dstIn,
        child: Stack(alignment: Alignment.center, children: [
          Container(height: 44, decoration: BoxDecoration(color: ll.surface2, borderRadius: BorderRadius.circular(16))),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _wheel(_h, [for (var i = 1; i <= 12; i++) '$i'], 78, (i) => hh = i + 1, hh - 1),
            Text(':', style: t(24, FontWeight.w800, ll.ink)),
            _wheel(_m, [for (var i = 0; i < 12; i++) (i * 5).toString().padLeft(2, '0')], 78, (i) => mm = i * 5, mm ~/ 5),
            _wheel(_a, const ['am', 'pm'], 64, (i) => ap = i, ap, fs: 17),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      Text.rich(
        bad
            ? const TextSpan(text: 'That time has already passed')
            : TextSpan(children: [
                TextSpan(text: fmtDay(_sel), style: t(15, FontWeight.w800, ll.ink)),
                const TextSpan(text: ' at '),
                TextSpan(text: fmtT(_sel), style: t(15, FontWeight.w800, ll.ink)),
              ]),
        textAlign: TextAlign.center,
        style: t(15, FontWeight.w600, bad ? LL.danger : ll.ink2),
      ),
      const SizedBox(height: 14),
      BigButton(label: 'Set time', enabled: !bad, onTap: () => Navigator.pop(context, _sel)),
    ]);
  }
}

// =============================================================================
// New folder sheet

Future<Folder?> newFolderSheet(BuildContext context) => showLLSheet<Folder>(context, builder: (_) => const _NewFolder());

class _NewFolder extends StatefulWidget {
  const _NewFolder();
  @override
  State<_NewFolder> createState() => _NewFolderState();
}

class _NewFolderState extends State<_NewFolder> {
  final _name = TextEditingController();
  String _icon = 'folder';
  bool _shared = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final n = _name.text.trim();
    if (n.isEmpty || _busy) return;
    final s = AppScope.of(context);
    if (_shared && !s.store.signedIn) {
      s.toast.show('Sign in to share folders with friends');
      return;
    }
    setState(() => _busy = true);
    final f = s.store.addFolder(n, _icon);
    if (_shared) {
      await s.app.sync.share(f);
      if (!mounted) return;
      Navigator.pop(context, f);
      await shareInvite(s, f);
    } else {
      Navigator.pop(context, f);
      s.toast.show('“${shortText(f.name)}” created');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SheetTitle('New folder'),
      LLInput(controller: _name, hint: 'Folder name', icon: 'folder', maxLength: 18, autofocus: true, onChanged: (_) => setState(() {}), onSubmitted: (_) => _go()),
      const Lab('Icon'),
      GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.35,
        children: [
          for (final i in kFolderIcons)
            Tap(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _icon = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(color: i == _icon ? ll.blue : ll.surface2, borderRadius: BorderRadius.circular(18)),
                child: Center(child: LLIcon(i, color: i == _icon ? Colors.white : ll.ink2)),
              ),
            ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Share with friends', style: t(15, FontWeight.w700, ll.ink)),
              Text('Get an invite link after creating', style: t(12.5, FontWeight.w600, ll.ink3)),
            ]),
          ),
          LLToggle(on: _shared, label: 'Share with friends', onChanged: (v) => setState(() => _shared = v)),
        ]),
      ),
      const SizedBox(height: 18),
      BigButton(label: _busy ? 'Creating…' : 'Create folder', enabled: _name.text.trim().isNotEmpty && !_busy, onTap: _go),
    ]);
  }
}

/// Share an invite link for a shared folder via the Android share sheet.
Future<void> shareInvite(AppScope s, Folder f) async {
  final link = inviteLink(s.store, f);
  await Clipboard.setData(ClipboardData(text: link));
  s.toast.show('Invite link copied. Send it to a friend.');
  try {
    await shareText('Join my “${f.name}” folder on Little Later: $link');
  } catch (_) {}
}

String inviteLink(AppStore st, Folder f) {
  final q = {
    'cid': f.collabId,
    'join': f.name,
    if (st.userName.isNotEmpty) 'by': st.userName,
  };
  return Uri.parse('$siteUrl/join.html').replace(queryParameters: q).toString();
}

/// Indirection so tests don't need the share plugin.
Future<void> Function(String text) shareText = (_) async {};

// =============================================================================
// Quick save from another app's Share menu (v7 .qs)

Future<void> openQuickSaveSheet(BuildContext context, String text) {
  final scope = AppScope.of(context);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => scope.wrap(_QuickSave(text: text)),
  );
}

class _QuickSave extends StatefulWidget {
  const _QuickSave({required this.text});
  final String text;
  @override
  State<_QuickSave> createState() => _QuickSaveState();
}

class _QuickSaveState extends State<_QuickSave> {
  final _m = MascotController();
  LinkInfo? _info;
  String _note = '';
  String _folder = '';
  When _when = When.tonight;
  DateTime? _custom;
  bool _done = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final url = extractUrl(widget.text);
    _info = url == null ? null : parseLink(url);
    _note = widget.text.replaceAll(url ?? '\u0000', '').trim();
    Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _m.play(MascotAct.hop);
        _m.mood(Mood.happy, const Duration(milliseconds: 900));
      }
    });
    if (_info != null) {
      _loading = true;
      fetchTitle(_info!).then((tt) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          if (tt != null && tt.isNotEmpty) _info!.title = tt;
        });
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_folder.isEmpty) {
      final st = AppScope.of(context).store;
      _folder = suggestFolder(st, _info?.folderKind)?.name ?? (st.folders.isEmpty ? '' : st.folders.first.name);
    }
  }

  @override
  void dispose() {
    _m.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = AppScope.of(context);
    final st = s.store;
    final d = whenDate(_when, st, _custom);
    final title = _info?.title ?? (_note.length > 80 ? '${_note.substring(0, 78)}…' : _note);
    if (title.isEmpty) return;
    st.addItem(Item(
      id: newId(),
      kind: _info != null ? ItemKind.link : ItemKind.reminder,
      title: title,
      folder: _folder,
      url: _info?.url ?? '',
      note: _info != null && _note.isNotEmpty && _note != title ? _note : '',
      reminder: d?.millisecondsSinceEpoch ?? 0,
    ));
    if (d != null) s.app.reminders.askPermission();
    HapticFeedback.mediumImpact();
    _m.play(MascotAct.hop);
    setState(() => _done = true);
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    Navigator.pop(context);
    s.app.gain(5);
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final st = s.store;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final d = whenDate(_when, st, _custom);
    const chips = [(When.tonight, 'Tonight', 'moon'), (When.tomorrow, 'Tomorrow', 'sunrise'), (When.custom, 'Pick time', 'clock'), (When.none, 'No reminder', 'off')];
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, 12 + bottom),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 70, offset: Offset(0, 30))]),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const SizedBox(width: 58),
              Expanded(child: Text('Save to Little Later', style: t(16.5, FontWeight.w800, ll.ink))),
              Circ(icon: 'x', size: 36, iconSize: 16, shadow: false, bg: ll.surface2, label: 'Cancel', onTap: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 10),
            if (_info != null)
              LinkPreview(info: _info!, loading: _loading)
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: ll.blueSoft, borderRadius: BorderRadius.circular(20)),
                child: Text(_note, maxLines: 3, overflow: TextOverflow.ellipsis, style: t(14.5, FontWeight.w700, ll.ink)),
              ),
            const Lab('Folder', hint: 'Suggested', top: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final f in st.folders) ...[
                  FolderPill(small: true, icon: f.iconKey, label: f.name, on: f.name == _folder, onTap: () => setState(() => _folder = f.name)),
                  const SizedBox(width: 8),
                ],
              ]),
            ),
            const Lab('Remind me', top: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final c in chips) ...[
                  Tap(
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      if (c.$1 == When.custom) {
                        final p = await pickTime(context, initial: _custom ?? whenDate(When.tomorrow, st, null)!);
                        if (p != null) {
                          setState(() {
                            _custom = p;
                            _when = When.custom;
                          });
                        }
                        return;
                      }
                      setState(() => _when = c.$1);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(color: _when == c.$1 ? ll.blue : ll.surface2, borderRadius: BorderRadius.circular(99)),
                      child: Row(children: [
                        LLIcon(c.$3, size: 16, color: _when == c.$1 ? Colors.white : ll.ink2),
                        const SizedBox(width: 6),
                        Text(c.$1 == When.custom && _custom != null ? fmtDue(_custom!) : c.$2, style: t(13.5, FontWeight.w800, _when == c.$1 ? Colors.white : ll.ink2)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ]),
            ),
            const SizedBox(height: 16),
            BigButton(label: 'Save', height: 54, onTap: _save),
          ]),
        ),
        Positioned(
          left: 12,
          top: -26,
          width: 54,
          height: 58,
          child: MascotView(stage: st.level.n, controller: _m, style: st.mascotStyle, outfit: st.outfitNow),
        ),
        if (_done)
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 300),
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: Container(
                decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(30)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 56, height: 56, decoration: BoxDecoration(shape: BoxShape.circle, color: ll.blue), child: const Center(child: LLIcon('check', size: 28, color: Colors.white, stroke: 2.6))),
                  const SizedBox(height: 8),
                  Text('Saved to ${_folder.isEmpty ? 'Little Later' : _folder}', style: t(17, FontWeight.w800, ll.ink)),
                  const SizedBox(height: 4),
                  Text(d != null ? '${st.mascotName} will bring it back ${dayLow(d)} at ${fmtT(d)}' : '${st.mascotName} is keeping it safe', style: t(13.5, FontWeight.w600, ll.ink2)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}
