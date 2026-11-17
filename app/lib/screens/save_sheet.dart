import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../data/models.dart';
import '../data/titles.dart';
import '../data/store.dart';
import '../mascot/mascot_svg.dart';
import '../mascot/mascot_view.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';
import '../widgets/kit.dart';
import '../widgets/cover.dart';
import '../services/haptics.dart';
import '../services/link_meta.dart';

// =============================================================================
// Link understanding (v7 KIND/parse) + real page titles

class LinkInfo {
  LinkInfo({required this.url, required this.domain, required this.title, required this.kind, this.folderKind, required this.line});
  final String url, domain, kind, line;
  String title;
  String image = '';
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
  return LinkInfo(url: s, domain: d, title: t.isEmpty ? 'Link from $d' : t[0].toUpperCase() + t.substring(1), kind: k?.$2 ?? 'Link', folderKind: k?.$3, line: k?.$4 ?? 'Nice find!');
}

/// Best-effort real title (YouTube oEmbed, else og:title / <title>).
/// Fetch the real title and cover image into [info]. Returns the title.
Future<String?> fetchTitle(LinkInfo info) async {
  final m = await fetchMeta(info.url);
  if (m.image != null) info.image = m.image!;
  return m.title;
}

/// Folder suggestion for a link kind ('hobby', 'work', …) among the user's folders.
Folder? suggestFolder(AppStore s, String? kind) {
  if (kind == null) return null;
  for (final f in s.folders) {
    if (f.kind == kind || f.iconKey == const {'hobby': 'spark', 'work': 'bag', 'love': 'heart', 'trip': 'plane'}[kind]) return f;
  }
  return null;
}

// =============================================================================
// When: Today / Tomorrow / a date (up to 3 months), always with a time you pick.

enum When { today, tomorrow, date, none }

/// Next sensible time today: about an hour from now, on a 5-minute step.
DateTime defaultWhen(When k) {
  final n = AppStore.now();
  if (k == When.tomorrow) return DateTime(n.year, n.month, n.day + 1, 9);
  final d = n.add(const Duration(hours: 1));
  final r = DateTime(d.year, d.month, d.day, d.hour, ((d.minute + 4) ~/ 5) * 5);
  if (k == When.today && r.day != n.day) return DateTime(n.year, n.month, n.day, 23, 55);
  return r;
}

When whenKindOf(DateTime d) {
  final x = fmtDay(d);
  return x == 'Today'
      ? When.today
      : x == 'Tomorrow'
      ? When.tomorrow
      : When.date;
}

class WhenChoice {
  const WhenChoice(this.kind, this.at);
  const WhenChoice.none() : kind = When.none, at = null;
  final When kind;
  final DateTime? at;
}

/// Once / Every day / Mon–Fri / Pick days, with day toggles for custom.
class RepeatPicker extends StatefulWidget {
  const RepeatPicker({super.key, required this.days, required this.onChanged});
  final List<int> days;
  final ValueChanged<List<int>> onChanged;
  @override
  State<RepeatPicker> createState() => _RepeatPickerState();
}

class _RepeatPickerState extends State<RepeatPicker> {
  static const _all = [1, 2, 3, 4, 5, 6, 7], _week = [1, 2, 3, 4, 5];
  late bool _custom = widget.days.isNotEmpty && widget.days.length != 7 && !(widget.days.length == 5 && widget.days.every(_week.contains));

  void _set(List<int> d, {bool custom = false}) {
    Haptics.tick();
    setState(() => _custom = custom);
    widget.onChanged(d);
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final d = widget.days;
    final daily = d.length == 7, week = !_custom && d.length == 5 && d.every(_week.contains);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        LLChip(label: 'Once', on: d.isEmpty && !_custom, onTap: () => _set(const [])),
        LLChip(label: 'Every day', icon: 'repeat', on: daily && !_custom, onTap: () => _set(_all)),
        LLChip(label: 'Mon–Fri', on: week, onTap: () => _set(_week)),
        LLChip(label: 'Pick days', on: _custom, onTap: () => _set(d.isEmpty || daily ? [DateTime.now().weekday] : d, custom: true)),
      ]),
      AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: !_custom
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(children: [
                  for (var i = 1; i <= 7; i++) ...[
                    Expanded(
                      child: Tap(
                        onTap: () {
                          final n = [...d];
                          n.contains(i) ? n.remove(i) : n.add(i);
                          if (n.isEmpty) return;
                          _set(n..sort(), custom: true);
                        },
                        semanticLabel: const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][i - 1],
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: d.contains(i) ? ll.blue : ll.surface),
                          child: Text('MTWTFSS'[i - 1], style: t(14, FontWeight.w800, d.contains(i) ? Colors.white : ll.ink2)),
                        ),
                      ),
                    ),
                    if (i < 7) const SizedBox(width: 6),
                  ],
                ]),
              ),
      ),
    ]);
  }
}

/// Sheet to change how an existing to-do or reminder repeats.
Future<List<int>?> pickRepeat(BuildContext context, List<int> days) {
  var d = [...days];
  return showLLSheet<List<int>>(context, builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetTitle('Repeat'),
          RepeatPicker(days: d, onChanged: (v) => set(() => d = v)),
          const SizedBox(height: 22),
          BigButton(label: 'Done', onTap: () => Navigator.pop(ctx, d)),
        ]),
      ));
}

/// 2x2 tiles: Today, Tomorrow, Pick date, No reminder. Tapping a day opens the
/// time wheels for that day.
class WhenTiles extends StatelessWidget {
  const WhenTiles({super.key, required this.value, required this.onChanged, this.noneLabel = 'No reminder', this.compact = false});
  final WhenChoice value;
  final ValueChanged<WhenChoice> onChanged;
  final String noneLabel;
  final bool compact;

  Future<void> _tap(BuildContext context, When k) async {
    Haptics.tick();
    if (k == When.none) {
      onChanged(const WhenChoice.none());
      return;
    }
    final init = value.kind == k && value.at != null ? value.at! : (k == When.date ? defaultWhen(When.tomorrow).add(const Duration(days: 1)) : defaultWhen(k));
    final d = await pickTime(
      context,
      initial: init,
      lockDay: k == When.today
          ? 0
          : k == When.tomorrow
          ? 1
          : null,
      title: k == When.today
          ? 'Today at…'
          : k == When.tomorrow
          ? 'Tomorrow at…'
          : 'Pick a day and time',
    );
    if (d != null) onChanged(WhenChoice(whenKindOf(d), d));
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    Widget tile(When k, String label, String icon) {
      final on = value.kind == k;
      final at = on ? value.at : null;
      final sub = switch (k) {
        When.none => 'Just keep it',
        When.date => at != null ? '${fmtDay(at)}, ${fmtT(at)}' : 'Up to 3 months',
        _ => at != null ? fmtT(at) : 'Pick a time',
      };
      return Tap(
        onTap: () => _tap(context, k),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: EdgeInsets.all(compact ? 8 : 10),
          decoration: BoxDecoration(color: on ? ll.blue : ll.surface2, borderRadius: BorderRadius.circular(compact ? 18 : 22)),
          child: Row(
            children: [
              Container(
                width: compact ? 34 : 40,
                height: compact ? 34 : 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: on ? Colors.white.withValues(alpha: .2) : ll.surface),
                child: LLIcon(icon, size: compact ? 16 : 19, color: on ? Colors.white : ll.ink2),
              ),
              SizedBox(width: compact ? 9 : 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(compact ? 13.5 : 14.5, FontWeight.w800, on ? Colors.white : ll.ink)),
                    Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(12, FontWeight.w600, on ? Colors.white.withValues(alpha: .8) : ll.ink3)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final gap = compact ? 8.0 : 10.0;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tile(When.today, 'Today', 'sun')),
            SizedBox(width: gap),
            Expanded(child: tile(When.tomorrow, 'Tomorrow', 'sunrise')),
          ],
        ),
        SizedBox(height: gap),
        Row(
          children: [
            Expanded(child: tile(When.date, 'Pick date', 'clock')),
            SizedBox(width: gap),
            Expanded(child: tile(When.none, noneLabel, 'off')),
          ],
        ),
      ],
    );
  }
}

/// "Later": choose a new day and time for an item.
Future<DateTime?> pickLater(BuildContext context, {DateTime? initial}) => pickTime(context, initial: initial ?? defaultWhen(When.today), title: 'Later, when?');

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
  final _note = TextEditingController();
  bool _noteOpen = false;
  final _remF = FocusNode(), _todoF = FocusNode(), _stepF = FocusNode();
  SaveMode _mode = SaveMode.link;
  WhenChoice _when = WhenChoice(When.today, defaultWhen(When.today));
  final List<String> _steps = [];
  String _folder = '';
  bool _folderInit = false, _folderTouched = false;
  List<int> _repeat = [];
  bool _suggested = false;
  LinkInfo? _info;
  bool _loadingTitle = false;
  Timer? _debounce;
  int _titleGen = 0;

  AppScope get s => AppScope.of(context);

  static const _modes = {
    SaveMode.link: ('Got a link for me?', 'Save link', 'Remind me'),
    SaveMode.reminder: ('What should I remind you about?', 'Set reminder', 'When'),
    SaveMode.todo: ('What’s on the list?', 'Add to-do', 'Due'),
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
    if (!_folderInit) {
      _folderInit = true;
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
    for (final c in [_link, _rem, _todo, _step, _note]) {
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
      if (widget.initialFolder.isEmpty && !_folderTouched) _folder = m == SaveMode.link ? (s.store.folders.isEmpty ? '' : s.store.folders.first.name) : '';
      if (m == SaveMode.reminder && _when.kind == When.none) _when = WhenChoice(When.today, defaultWhen(When.today));
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
    if (_mode == SaveMode.reminder && _when.at == null) return false;
    return switch (_mode) {
      SaveMode.link => _info != null,
      SaveMode.reminder => _rem.text.trim().length > 1,
      SaveMode.todo => _todo.text.trim().length > 1,
    };
  }

  void _setWhen(WhenChoice w) {
    setState(() => _when = w);
    if (w.at == null) {
      _m.mood(Mood.sleep, const Duration(milliseconds: 1100));
      _bubble.say(_mode == SaveMode.todo ? 'Whenever works.' : 'I’ll keep it quietly.', 0);
    } else {
      _m.play(MascotAct.nod);
      _bubble.say('${fmtDay(w.at!)}, ${fmtT(w.at!)}. Got it.', 0);
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
    final d = _when.at;
    final id = newId();
    late Item it;
    late String msg;
    switch (_mode) {
      case SaveMode.link:
        final info = _info!;
        it = Item(id: id, kind: ItemKind.link, title: info.title, folder: _folder, url: info.url, thumbnail: info.image, reminder: d?.millisecondsSinceEpoch ?? 0, note: _note.text.trim());
        msg = 'Saved!';
      case SaveMode.reminder:
        it = Item(id: id, kind: ItemKind.reminder, title: _rem.text.trim(), folder: _folder, reminder: d?.millisecondsSinceEpoch ?? 0, note: _note.text.trim());
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
    if (st.userEmail.isNotEmpty) it.extra['senderEmail'] = st.userEmail;
    if (st.userName.isNotEmpty) it.extra['senderName'] = st.userName;
    if (_mode != SaveMode.link && d != null) it.repeatDays = _repeat;
    st.addItem(it);
    if (d != null) s.app.reminders.askPermission();
    final scope = s;
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    Navigator.pop(context);
    scope.app.gain(5, line: 'Got it, safe with me.');
    final fname = _folder.isEmpty ? 'Saved' : _folder;
    final rep = it.repeats ? ', ${repeatLabel(_repeat).toLowerCase()} at ${fmtT(d!)}' : (d != null ? ', ${dayLow(d)} ${fmtT(d)}' : '');
    scope.toast.show('${_mode == SaveMode.todo ? 'Added' : 'Saved'} to $fname$rep');
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
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: 0,
            right: 0,
            height: 320,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [ll.headA, ll.headA.withValues(alpha: 0)], stops: const [0, .7]),
              ),
            ),
          ),
          Column(
            children: [
              // .sh-top
              SizedBox(
                height: kb > 0 ? 120 : 236,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(color: ll.inkMix(.18), borderRadius: BorderRadius.circular(9)),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      top: 22,
                      child: Circ(icon: 'x', size: 44, label: 'Close', onTap: () => Navigator.pop(context)),
                    ),
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
                  ],
                ),
              ),
              // .sh-body
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: ll.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
                  ),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + (kb > 0 ? kb : bottom)),
                    children: [
                      Segmented(labels: const ['Link', 'Reminder', 'To-do'], icons: const ['link', 'bell', 'check'], index: _mode.index, onChanged: (i) => _setMode(SaveMode.values[i])),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (c, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, .1), end: Offset.zero).animate(a),
                            child: c,
                          ),
                        ),
                        child: KeyedSubtree(key: ValueKey(_mode), child: _fields(ll)),
                      ),
                      if (_mode != SaveMode.todo)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Motion.smooth,
                            child: _noteOpen
                                ? LLInput(controller: _note, hint: 'Add a note (ingredients, why you saved it…)', icon: 'pen', height: 54, autofocus: true, maxLength: 200)
                                : Align(
                                    alignment: Alignment.centerLeft,
                                    child: Tap(
                                      onTap: () => setState(() => _noteOpen = true),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            LLIcon('plus', size: 16, color: ll.blueInk),
                                            const SizedBox(width: 6),
                                            Text('Add a note', style: t(14, FontWeight.w800, ll.blueInk)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      Lab('Folder', hint: _suggested ? 'Suggested' : (_folder.isEmpty ? 'None, tap one to add' : 'Optional, tap again to remove')),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: Row(
                          children: [
                            for (final f in st.folders) ...[
                              FolderPill(
                                icon: f.iconKey,
                                label: f.name,
                                on: f.name == _folder,
                                onTap: () {
                                  s.buzz(0);
                                  final off = f.name == _folder;
                                  setState(() {
                                    _folder = off ? '' : f.name;
                                    _folderTouched = true;
                                    _suggested = false;
                                  });
                                  _bubble.say(off ? 'No folder, that’s fine.' : '${f.name} it is.', 0);
                                },
                              ),
                              const SizedBox(width: 10),
                            ],
                            FolderPill(icon: 'plus', label: 'New', dashed: true, onTap: _newFolder),
                          ],
                        ),
                      ),
                      Lab(mode.$3),
                      WhenTiles(value: _when, onChanged: _setWhen, noneLabel: _mode == SaveMode.todo ? 'No date' : 'No reminder'),
                      if (_mode != SaveMode.link && _when.at != null) ...[
                        Lab('Repeat', hint: repeatLabel(_repeat)),
                        RepeatPicker(days: _repeat, onChanged: (d) => setState(() => _repeat = d)),
                      ],
                      const SizedBox(height: 22),
                      BigButton(label: mode.$2, xp: 5, enabled: _valid, onTap: _save),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fields(LL ll) {
    switch (_mode) {
      case SaveMode.link:
        return Column(
          children: [
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.content_paste_rounded, size: 16, color: ll.onInk),
                      const SizedBox(width: 6),
                      Text('Paste', style: t(13.5, FontWeight.w800, ll.onInk)),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 450),
              curve: Motion.smooth,
              child: _info == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: LinkPreview(info: _info!, loading: _loadingTitle),
                    ),
            ),
          ],
        );
      case SaveMode.reminder:
        return LLInput(controller: _rem, focusNode: _remF, hint: 'Remind me to…', icon: 'bell', maxLength: 80, onChanged: (_) => setState(() {}));
      case SaveMode.todo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LLInput(controller: _todo, focusNode: _todoF, hint: 'What needs doing?', icon: 'check', maxLength: 80, onChanged: (_) => setState(() {})),
            const SizedBox(height: 10),
            for (var i = 0; i < _steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                  decoration: BoxDecoration(color: ll.surface2, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: ll.ink3, width: 1.6),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_steps[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: t(14, FontWeight.w600, ll.ink)),
                      ),
                      Tap(
                        onTap: () => setState(() => _steps.removeAt(i)),
                        semanticLabel: 'Remove step',
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: Center(child: LLIcon('x', size: 15, color: ll.ink3)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ll.line, width: 1.5),
              ),
              child: Row(
                children: [
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
                ],
              ),
            ),
          ],
        );
    }
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
        child: Transform.rotate(
          angle: .31 * k,
          child: Icon(Icons.auto_awesome, size: widget.size, color: LL.of(context).blue.withValues(alpha: .55)),
        ),
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
      child: Row(
        children: [
          Cover(url: info.image, letter: info.domain, width: 56, height: 56, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedOpacity(
                  opacity: loading ? .55 : 1,
                  duration: const Duration(milliseconds: 250),
                  child: Text(info.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t(14.5, FontWeight.w800, ll.ink, h: 1.3)),
                ),
                Text(info.domain, style: t(12.5, FontWeight.w600, ll.ink2)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(99)),
            child: Text(info.kind, style: t(12, FontWeight.w800, ll.blueInk)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Time picker: 14-day strip + hour/minute/am-pm wheels

/// Day strip (next 3 months) + hour/minute/am-pm wheels. [lockDay] 0/1 hides
/// the strip and fixes the day to today/tomorrow.
Future<DateTime?> pickTime(BuildContext context, {required DateTime initial, int? lockDay, String title = 'Pick a time'}) {
  return showLLSheet<DateTime>(
    context,
    builder: (_) => _TimePicker(initial: initial, lockDay: lockDay, title: title),
  );
}

class _TimePicker extends StatefulWidget {
  const _TimePicker({required this.initial, this.lockDay, this.title = 'Pick a time'});
  final DateTime initial;
  final int? lockDay;
  final String title;
  @override
  State<_TimePicker> createState() => _TimePickerState();
}

class _TimePickerState extends State<_TimePicker> {
  late final List<DateTime> days;
  late int day, hh, mm, ap;
  late final FixedExtentScrollController _h, _m, _a;
  final _strip = ScrollController();
  static const _dow = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void initState() {
    super.initState();
    final n = AppStore.now();
    days = List.generate(92, (i) => DateTime(n.year, n.month, n.day + i));
    final init = widget.initial;
    day = days.indexWhere((d) => d.year == init.year && d.month == init.month && d.day == init.day);
    if (day < 0) day = 1;
    if (widget.lockDay != null) day = widget.lockDay!;
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
    final d = defaultWhen(widget.lockDay == 1 ? When.tomorrow : When.today);
    if (widget.lockDay == null) setState(() => day = 0);
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
          Haptics.tick();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(widget.title, action: 'Reset', onAction: _reset),
        if (widget.lockDay == null)
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
                    Haptics.tick();
                    setState(() => day = i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 58,
                    height: 70,
                    decoration: BoxDecoration(color: on ? ll.blue : ll.surface2, borderRadius: BorderRadius.circular(20), boxShadow: on ? ll.blueGlow(.32, 22) : null),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          i == 0
                              ? 'Today'
                              : i == 1
                              ? 'Tmrw'
                              : d.day == 1
                              ? _mon[d.month - 1]
                              : _dow[d.weekday - 1],
                          style: t(11.5, FontWeight.w800, on ? Colors.white70 : ll.ink3),
                        ),
                        const SizedBox(height: 3),
                        Text('${d.day}', style: t(20, FontWeight.w800, on ? Colors.white : ll.ink)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
            stops: [0, .3, .7, 1],
          ).createShader(r),
          blendMode: BlendMode.dstIn,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 44,
                decoration: BoxDecoration(color: ll.surface2, borderRadius: BorderRadius.circular(16)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _wheel(_h, [for (var i = 1; i <= 12; i++) '$i'], 78, (i) => hh = i + 1, hh - 1),
                  Text(':', style: t(24, FontWeight.w800, ll.ink)),
                  _wheel(_m, [for (var i = 0; i < 12; i++) (i * 5).toString().padLeft(2, '0')], 78, (i) => mm = i * 5, mm ~/ 5),
                  _wheel(_a, const ['am', 'pm'], 64, (i) => ap = i, ap, fs: 17),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text.rich(
          bad
              ? const TextSpan(text: 'That time has already passed')
              : TextSpan(
                  children: [
                    TextSpan(text: fmtDay(_sel), style: t(15, FontWeight.w800, ll.ink)),
                    const TextSpan(text: ' at '),
                    TextSpan(text: fmtT(_sel), style: t(15, FontWeight.w800, ll.ink)),
                  ],
                ),
          textAlign: TextAlign.center,
          style: t(15, FontWeight.w600, bad ? LL.danger : ll.ink2),
        ),
        const SizedBox(height: 14),
        BigButton(label: 'Set time', enabled: !bad, onTap: () => Navigator.pop(context, _sel)),
      ],
    );
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
      s.toast.show('“${shortText(f.name)}” is shared. Open it to invite friends.');
    } else {
      Navigator.pop(context, f);
      s.toast.show('“${shortText(f.name)}” created');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  Haptics.tick();
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
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Share with friends', style: t(15, FontWeight.w700, ll.ink)),
                    Text('Get an invite link after creating', style: t(12.5, FontWeight.w600, ll.ink3)),
                  ],
                ),
              ),
              LLToggle(on: _shared, label: 'Share with friends', onChanged: (v) => setState(() => _shared = v)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        BigButton(label: _busy ? 'Creating…' : 'Create folder', enabled: _name.text.trim().isNotEmpty && !_busy, onTap: _go),
      ],
    );
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
  final q = {'cid': f.collabId, 'join': f.name, if (st.userName.isNotEmpty) 'by': st.userName};
  return Uri.parse('$siteUrl/join.html').replace(queryParameters: q).toString();
}

/// Indirection so tests don't need the share plugin.
Future<void> Function(String text) shareText = (_) async {};

// =============================================================================
// Quick save from another app's Share menu (v7 .qs). Also used by the
// standalone share window, so it takes an [onDone] instead of popping routes.

Future<void> openQuickSaveSheet(BuildContext context, String text) {
  final scope = AppScope.of(context);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => scope.wrap(QuickSave(text: text, onDone: () => Navigator.pop(ctx))),
  );
}

class QuickSave extends StatefulWidget {
  const QuickSave({super.key, required this.text, required this.onDone, this.onSaved});
  final String text;
  final VoidCallback onDone;

  /// Called after the item is stored (the share window uses it to sync, then close).
  final Future<void> Function()? onSaved;
  @override
  State<QuickSave> createState() => _QuickSaveState();
}

class _QuickSaveState extends State<QuickSave> {
  final _m = MascotController();
  final _note = TextEditingController();
  LinkInfo? _info;
  String _plain = '';
  String _folder = '';
  WhenChoice _when = const WhenChoice.none();
  bool _noteOpen = false;
  bool _done = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final url = extractUrl(widget.text);
    _info = url == null ? null : parseLink(url);
    _plain = widget.text.replaceAll(url ?? '\u0000', '').trim();
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
    _note.dispose();
    super.dispose();
  }

  Future<void> _newFolder() async {
    final f = await newFolderSheet(context);
    if (f != null && mounted) setState(() => _folder = f.name);
  }

  Future<void> _save() async {
    if (_done) return;
    final s = AppScope.of(context);
    final st = s.store;
    final d = _when.at;
    final title = _info?.title ?? cleanTitle(_plain);
    if (title.isEmpty) return;
    st.addItem(
      Item(
        id: newId(),
        kind: _info != null ? ItemKind.link : ItemKind.reminder,
        title: title,
        folder: _folder,
        url: _info?.url ?? '',
        thumbnail: _info?.image ?? '',
        note: _note.text.trim(),
        reminder: d?.millisecondsSinceEpoch ?? 0,
        extra: {if (st.userEmail.isNotEmpty) 'senderEmail': st.userEmail, if (st.userName.isNotEmpty) 'senderName': st.userName},
      ),
    );
    st.gainXp(5);
    if (d != null) s.app.reminders.askPermission();
    Haptics.medium();
    _m.play(MascotAct.hop);
    _m.mood(Mood.happy);
    FocusScope.of(context).unfocus();
    setState(() => _done = true);
    await Future.wait([Future.delayed(const Duration(milliseconds: 1100)), if (widget.onSaved != null) widget.onSaved!()]);
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final st = s.store;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    final d = _when.at;
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, 12 + (kb > 0 ? kb : bottom)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: ll.surface,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 40, offset: Offset(0, 16))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 58),
                    Expanded(child: Text('Save to Little Later', style: t(16.5, FontWeight.w800, ll.ink))),
                    Circ(icon: 'x', size: 36, iconSize: 16, shadow: false, bg: ll.surface2, label: 'Cancel', onTap: widget.onDone),
                  ],
                ),
                const SizedBox(height: 10),
                if (_info != null)
                  LinkPreview(info: _info!, loading: _loading)
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: ll.blueSoft, borderRadius: BorderRadius.circular(20)),
                    child: Text(_plain, maxLines: 3, overflow: TextOverflow.ellipsis, style: t(14.5, FontWeight.w700, ll.ink)),
                  ),
                const SizedBox(height: 10),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Motion.smooth,
                  child: _noteOpen
                      ? LLInput(controller: _note, hint: 'Add a note (ingredients, why you saved it…)', icon: 'pen', height: 52, autofocus: true, maxLength: 200)
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Tap(
                            onTap: () => setState(() => _noteOpen = true),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  LLIcon('plus', size: 16, color: ll.blueInk),
                                  const SizedBox(width: 6),
                                  Text('Add a note', style: t(14, FontWeight.w800, ll.blueInk)),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
                const Lab('Folder', top: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in st.folders) ...[
                        FolderPill(
                          small: true,
                          icon: f.iconKey,
                          label: f.name,
                          on: f.name == _folder,
                          onTap: () {
                            Haptics.tick();
                            setState(() => _folder = f.name);
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      FolderPill(small: true, icon: 'plus', label: 'New', dashed: true, onTap: _newFolder),
                    ],
                  ),
                ),
                const Lab('Remind me', top: 14),
                WhenTiles(value: _when, compact: true, onChanged: (w) => setState(() => _when = w)),
                const SizedBox(height: 16),
                BigButton(label: 'Save', height: 54, onTap: _save),
              ],
            ),
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 600),
                        curve: Motion.spring,
                        builder: (_, v, c) => Transform.scale(scale: v, child: c),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: ll.blue),
                          child: const Center(child: LLIcon('check', size: 28, color: Colors.white, stroke: 2.6)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('Saved to ${_folder.isEmpty ? 'Little Later' : _folder}', style: t(17, FontWeight.w800, ll.ink)),
                      const SizedBox(height: 4),
                      Text(d != null ? '${st.mascotName} will bring it back ${dayLow(d)} at ${fmtT(d)}' : '${st.mascotName} is keeping it safe', style: t(13.5, FontWeight.w600, ll.ink2)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
