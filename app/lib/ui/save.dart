// The save sheet: Link / Reminder / To-do. Opens from +, or grows out of the
// "Paste a link or type a reminder" bar on Today and shrinks back into it.
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../data/models.dart';
import '../data/nl.dart';
import '../data/store.dart';
import '../screens/save_sheet.dart' show parseLink, fetchTitle, LinkInfo, suggestFolder, pickTime, extractUrl, newFolderSheet;
import '../services/haptics.dart';
import '../theme/tokens.dart';
import 'actions.dart';
import 'kit.dart';
import 'voice.dart' show listenOnce;

// =============================================================================
// Text field that lights up the time words as you type.

class NLController extends TextEditingController {
  NLController({super.text});
  bool enabled = true;
  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final ll = LL.of(context);
    final v = text;
    if (!enabled || v.isEmpty || RegExp(r'https?://|www\.').hasMatch(v)) return TextSpan(text: v, style: style);
    final r = parseNL(v);
    if (!r.found) return TextSpan(text: v, style: style);
    final kids = <InlineSpan>[];
    var last = 0;
    for (final (a, b) in r.ranges) {
      if (a < last) continue;
      if (a > last) kids.add(TextSpan(text: v.substring(last, a)));
      kids.add(TextSpan(text: v.substring(a, b), style: TextStyle(color: ll.blueInk, backgroundColor: ll.blueSoft)));
      last = b;
    }
    if (last < v.length) kids.add(TextSpan(text: v.substring(last)));
    return TextSpan(style: style, children: kids);
  }
}

/// What a sentence will become: a link's new time, several reminders / a
/// list (with a switch), or the detected time chips.
class PlanPreview extends StatelessWidget {
  const PlanPreview({super.key, required this.plan, required this.mode, required this.onMode, this.center = false});
  final Plan plan;
  final String? mode;
  final ValueChanged<String> onMode;
  final bool center;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final r = plan.nl;
    if (plan.link != null) {
      final when = r.date ?? defaultReminderTime();
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Cover2(item: plan.link!, width: 52, height: 52, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(plan.link!.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t(15, FontWeight.w600, ll.ink)),
              const SizedBox(height: 3),
              Row(children: [LLIcon('clock', size: 13, color: ll.blueInk), const SizedBox(width: 5), Flexible(child: Text('comes back ${fmtDay(when)}, ${fmtT(when)}', style: t(13, FontWeight.w500, ll.blueInk)))]),
            ]),
          ),
        ]),
      );
    }
    if (plan.split != null) {
      final sp = plan.split!;
      final m = mode ?? sp.def;
      Widget row(String icon, String title, String right, {bool step = false, bool head = false}) => Container(
            margin: EdgeInsets.only(left: step ? 18 : 0, top: 2),
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              step
                  ? Container(width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ll.ink3, width: 1.5)))
                  : Opacity(opacity: .7, child: LLIcon(icon, size: 16, color: ll.ink)),
              const SizedBox(width: 10),
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(15, head ? FontWeight.w600 : FontWeight.w500, ll.ink))),
              Text(right, style: t(13, FontWeight.w500, ll.blueInk)),
            ]),
          );
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegTabs(options: [('reminders', '${sp.parts.length} reminders'), ('list', '1 to-do list')], value: m, onChanged: onMode, height: 38),
        const SizedBox(height: 6),
        if (m == 'reminders')
          for (final p in sp.parts) row('bell', p.title, p.nl.date == null ? '' : '${fmtDay(p.nl.date!)}, ${fmtT(p.nl.date!)}')
        else ...[
          row('todo', sp.listTitle, '${sp.parts.length} steps', head: true),
          for (final p in sp.parts) row('', p.title, p.timed && p.nl.date != null ? fmtT(p.nl.date!) : '', step: true),
        ],
      ]);
    }
    if (!r.found) return const SizedBox.shrink();
    Widget chip(String? icon, String text, {bool accent = false}) => Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(99)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[LLIcon(icon, size: 14, color: accent ? ll.blueInk : ll.ink), const SizedBox(width: 6)],
            Text(text, style: t(13, FontWeight.w500, accent ? ll.blueInk : ll.ink)),
          ]),
        );
    final title = cleanTitle(r.title);
    return Wrap(alignment: center ? WrapAlignment.center : WrapAlignment.start, spacing: 6, runSpacing: 6, children: [
      if (r.date != null) chip('clock', '${fmtDay(r.date!)}, ${fmtT(r.date!)}', accent: true),
      if (r.repeat.isNotEmpty) chip('repeat', r.repeatText),
      if (title.isNotEmpty) chip(null, '“${shortText(title, 26)}”'),
    ]);
  }
}

// =============================================================================

enum Mode { link, reminder, todo }

/// Open the save sheet. With [from] (the Today bar's rect) it grows out of the
/// bar and shrinks back into it.
Future<void> openSave(BuildContext context, {String text = '', String folder = '', Mode mode = Mode.link, Rect? from, VoidCallback? onClosed}) async {
  final scope = AppScope.of(context);
  final ll = LL.of(context);
  scope.buzz(0);
  await Navigator.of(context).push(PageRouteBuilder(
    opaque: false,
    barrierDismissible: false,
    transitionDuration: Duration(milliseconds: from != null ? 1 : 380),
    reverseTransitionDuration: Duration(milliseconds: from != null ? 1 : 260),
    pageBuilder: (ctx, a, _) => scope.wrap(Theme(data: Theme.of(context), child: _SaveRoute(text: text, folder: folder, mode: mode, from: from, ll: ll, anim: a))),
  ));
  onClosed?.call();
}

class _SaveRoute extends StatefulWidget {
  const _SaveRoute({required this.text, required this.folder, required this.mode, this.from, required this.ll, required this.anim});
  final String text, folder;
  final Mode mode;
  final Rect? from;
  final LL ll;
  final Animation<double> anim;
  @override
  State<_SaveRoute> createState() => _SaveRouteState();
}

class _SaveRouteState extends State<_SaveRoute> with SingleTickerProviderStateMixin {
  late final AnimationController _m = AnimationController(vsync: this, duration: const Duration(milliseconds: 420), reverseDuration: const Duration(milliseconds: 340));
  final _sheetKey = GlobalKey(), _fieldKey = GlobalKey();
  Rect? _sheet, _field;
  bool _closing = false;

  bool get _morph => widget.from != null;

  @override
  void initState() {
    super.initState();
    if (_morph) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure(start: true));
    } else {
      _m.value = 1;
    }
  }

  void _measure({bool start = false}) {
    final sb = _sheetKey.currentContext?.findRenderObject() as RenderBox?;
    final fb = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (sb == null || !sb.attached) return;
    _sheet = sb.localToGlobal(Offset.zero) & sb.size;
    _field = fb != null && fb.attached ? fb.localToGlobal(Offset.zero) & fb.size : null;
    if (start) {
      setState(() {});
      _m.forward(from: 0);
    }
  }

  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_morph) {
      _measure();
      if (_field != null) {
        await _m.reverse();
      } else {
        await _m.animateBack(0, duration: const Duration(milliseconds: 220));
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _m.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final sheet = SaveBody(
      key: _sheetKey,
      fieldKey: _fieldKey,
      text: widget.text,
      folder: widget.folder,
      mode: widget.mode,
      fromBar: _morph,
      onClose: close,
      fade: _morph ? CurvedAnimation(parent: _m, curve: const Interval(.35, 1, curve: Curves.easeOut)) : null,
    );
    final barrier = _morph ? _m : CurvedAnimation(parent: widget.anim, curve: Curves.easeOut);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) {
        if (!did) close();
      },
      child: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: close,
            child: FadeTransition(opacity: barrier, child: Container(color: Colors.black.withValues(alpha: ll.dark ? .5 : .28))),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: inset,
          child: AnimatedBuilder(
              animation: _m,
              child: sheet,
              builder: (context, child) {
                if (!_morph) {
                  final a = CurvedAnimation(parent: widget.anim, curve: Motion.smooth);
                  return SlideTransition(position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(a), child: child);
                }
                if (_sheet == null || _field == null) return Opacity(opacity: 0, child: child);
                if (_m.value >= 1 && !_closing) return child!;
                final tt = Curves.easeOutCubic.transform(_m.value);
                final b = widget.from!, f = _field!, s = _sheet!;
                // Move/scale so the sheet's text field sits exactly on the bar, then grow to the full sheet.
                final dx = (b.left - f.left) * (1 - tt), dy = (b.top - f.top) * (1 - tt);
                final sx = 1 + (b.width / f.width - 1) * (1 - tt), sy = 1 + (b.height / f.height - 1) * (1 - tt);
                final local = f.shift(-s.topLeft);
                final clip = Rect.lerp(local, Offset.zero & s.size, tt)!;
                final r = 20 + (36 - 20) * tt;
                return Transform(
                  transform: Matrix4.identity()
                    ..translateByDouble(dx, dy, 0, 1)
                    ..translateByDouble(local.center.dx, local.center.dy, 0, 1)
                    ..scaleByDouble(sx, sy, 1, 1)
                    ..translateByDouble(-local.center.dx, -local.center.dy, 0, 1),
                  child: ClipPath(clipper: _RRectClip(clip, r), child: child),
                );
              },
            ),
        ),
      ]),
    );
  }
}

class _RRectClip extends CustomClipper<Path> {
  _RRectClip(this.r, this.radius);
  final Rect r;
  final double radius;
  @override
  Path getClip(Size size) => Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
  @override
  bool shouldReclip(_RRectClip o) => o.r != r || o.radius != radius;
}

// =============================================================================

class SaveBody extends StatefulWidget {
  const SaveBody({super.key, this.fieldKey, this.text = '', this.folder = '', this.mode = Mode.link, this.fromBar = false, required this.onClose, this.fade, this.shared = false, this.onSaved});
  final Key? fieldKey;
  final String text, folder;
  final Mode mode;
  final bool fromBar;
  final Future<void> Function() onClose;
  final Animation<double>? fade;

  /// Opened from another app's Share menu: no mode tabs, quick close.
  final bool shared;
  final Future<void> Function()? onSaved;
  @override
  State<SaveBody> createState() => SaveBodyState();
}

class _Tile {
  const _Tile(this.label, this.sub, this.at);
  final String label, sub;
  final DateTime? Function() at;
}

class SaveBodyState extends State<SaveBody> {
  late Mode _mode = widget.mode;
  final _url = TextEditingController();
  final _title = NLController();
  final _note = TextEditingController();
  final _step = TextEditingController();
  final _urlFocus = FocusNode(), _titleFocus = FocusNode();
  LinkInfo? _info;
  bool _loading = false;
  late String _folder = widget.folder;
  int _tile = 0;
  DateTime? _picked;
  NL? _sayWhen;
  bool _listening = false;
  List<int> _repeat = [];
  bool _pickDays = false;
  final List<String> _steps = [];
  String? _photo;
  String? _splitMode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.text.trim();
    final u = extractUrl(t);
    if (u != null) {
      _mode = Mode.link;
      _setLink(u);
      final rest = t.replaceAll(u, '').trim();
      if (rest.isNotEmpty) {
        final r = parseNL(rest);
        if (r.found) _sayWhen = r;
        if (!r.found || r.title.isNotEmpty) _note.text = r.found ? r.title : rest;
      }
    } else if (t.isNotEmpty) {
      _mode = Mode.reminder;
      _title.text = t;
    }
    _url.addListener(_onUrl);
    _title.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.shared) return;
      if (_mode == Mode.link && _info == null) _urlFocus.requestFocus();
      if (_mode != Mode.link && _title.text.isEmpty) _titleFocus.requestFocus();
    });
  }

  void _onUrl() {
    final v = _url.text;
    if (_info != null) return;
    final u = extractUrl(v) ?? (RegExp(r'^\s*(www\.)?[\w-]+\.(com|in|be|ly|io|co|org|net|app)\b\S*\s*$').hasMatch(v) ? v.trim() : null);
    if (u != null && (v.endsWith(' ') || v.length - u.length < 2)) {
      _setLink(u);
      return;
    }
    // Typed words, not a link: switch to Reminder and keep typing there.
    if (v.trim().isNotEmpty && v.contains(' ') && extractUrl(v) == null) {
      setState(() {
        _mode = Mode.reminder;
        _title.text = v;
        _title.selection = TextSelection.collapsed(offset: v.length);
        _url.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _titleFocus.requestFocus());
    }
  }

  void _setLink(String u) {
    final info = parseLink(u);
    if (info == null) return;
    setState(() {
      _info = info;
      _loading = true;
    });
    final st = AppScope.of(context).store;
    if (_folder.isEmpty) _folder = suggestFolder(st, info.folderKind)?.name ?? '';
    fetchTitle(info).then((tt) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (tt != null && tt.trim().isNotEmpty) info.title = tt.trim();
      });
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    _note.dispose();
    _step.dispose();
    _urlFocus.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  List<_Tile> _tiles() {
    final n = AppStore.now();
    DateTime at(int dd, int h, [int m = 0]) => DateTime(n.year, n.month, n.day + dd, h, m);
    DateTime tonight(int h, int m) => at(0, h, m).isAfter(n) ? at(0, h, m) : at(1, h, m);
    DateTime weekend() {
      final add = (6 - n.weekday) % 7;
      final d = DateTime(n.year, n.month, n.day + (add == 0 && n.hour >= 10 ? 7 : add), 10);
      return d;
    }

    switch (_mode) {
      case Mode.link:
        return [
          _Tile('Tonight', '7:30 pm', () => tonight(19, 30)),
          _Tile('Tomorrow', '9:00 am', () => at(1, 9)),
          _Tile('Weekend', 'Sat 10 am', weekend),
          _Tile('None', 'Just save', () => null),
        ];
      case Mode.reminder:
        final h = n.add(const Duration(hours: 1));
        return [
          _Tile('In 1 hour', fmtT(h), () => n.add(const Duration(hours: 1))),
          _Tile('Tonight', '9:00 pm', () => tonight(21, 0)),
          _Tile('Tomorrow', '9:00 am', () => at(1, 9)),
          _Tile('Pick', _picked != null ? '${fmtDay(_picked!)} ${fmtT(_picked!)}' : 'Any day', () => _picked),
        ];
      case Mode.todo:
        return [
          _Tile('Today', '8:00 pm', () => tonight(20, 0)),
          _Tile('Tomorrow', '9:00 am', () => at(1, 9)),
          _Tile('Weekend', 'Sat 10 am', weekend),
          _Tile('No date', 'Anytime', () => null),
        ];
    }
  }

  Future<void> _sayWhenMic() async {
    setState(() => _listening = true);
    Haptics.light();
    final said = await listenOnce(context);
    if (!mounted) return;
    setState(() {
      _listening = false;
      if (said != null) {
        final r = parseNL(said);
        _sayWhen = r.found ? r : null;
        if (!r.found) AppScope.of(context).toast.show('Didn’t catch a time. Try “tonight” or “kal raat 9 baje”');
      }
    });
  }

  Future<void> _pickPhoto() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 78);
      if (x == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final f = await File(x.path).copy('${dir.path}/ll_${DateTime.now().millisecondsSinceEpoch}.jpg');
      if (mounted) setState(() => _photo = f.path);
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_saving) return;
    final s = AppScope.of(context);
    final st = s.store;
    final text = _title.text.trim();
    // Several things, or a time for a saved link: hand over to addFromText.
    if (_mode != Mode.link && _photo == null && text.isNotEmpty) {
      final p = planFor(st, text);
      if (p.link != null || p.split != null) {
        _saving = true;
        await widget.onClose();
        addFromText(s, text, mode: _splitMode, folder: _folder);
        return;
      }
    }
    final tiles = _tiles();
    DateTime? when;
    var repeat = _repeat;
    String title;
    Item it;
    if (_mode == Mode.link) {
      if (_info == null) return;
      when = _sayWhen?.date ?? tiles[_tile].at();
      if (_sayWhen != null && _sayWhen!.repeat.isNotEmpty) repeat = _sayWhen!.repeat;
      it = newItem(ItemKind.link, _info!.title, folder: _folder, when: when, url: _info!.url, thumb: _info!.image, note: _note.text.trim());
      if (repeat.isNotEmpty) it.repeatDays = repeat;
      title = _info!.title;
    } else {
      if (text.isEmpty) return;
      final r = parseNL(text);
      title = cleanTitle(r.found ? r.title : text);
      if (title.isEmpty) title = text;
      when = r.date ?? tiles[_tile].at();
      if (_mode == Mode.reminder && when == null) {
        when = await pickTime(context, initial: AppStore.now().add(const Duration(hours: 1)));
        if (when == null) return;
      }
      if (r.repeat.isNotEmpty) repeat = r.repeat;
      it = newItem(_mode == Mode.todo ? ItemKind.todoList : ItemKind.reminder, title, folder: _folder, when: when, repeat: repeat);
      if (_mode == Mode.todo) it.tasks = [for (final x in _steps) TodoTask(id: newId(), text: x)];
      if (_photo != null) {
        it.thumbnail = Uri.file(_photo!).toString();
        it.extra['photo'] = true;
      }
    }
    _saving = true;
    st.addItem(it);
    if (it.kind == ItemKind.link) st.markLinkSaved(it);
    Haptics.medium();
    if (widget.onSaved != null) await widget.onSaved!();
    await widget.onClose();
    s.app.gain(5);
    final g = _folder.isEmpty ? null : st.folderNamed(_folder);
    final where = _folder.isEmpty ? 'Saved' : _folder;
    final whenTxt = when == null ? '' : ' · ${fmtDay(when).toLowerCase()} ${fmtT(when)}';
    s.toast.show(
      it.kind == ItemKind.link ? 'Saved to $where$whenTxt' : '${it.kind == ItemKind.todoList ? 'To-do added' : 'Reminder set'}$whenTxt${g != null && g.collab ? ' · ${g.name} gets it too' : ''}',
      undo: () => st.deleteItem(it.id),
    );
  }

  Widget _fade(Widget w) => widget.fade == null ? w : FadeTransition(opacity: widget.fade!, child: w);

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final st = AppScope.of(context).store;
    final text = _title.text;
    final plan = _mode != Mode.link && text.trim().isNotEmpty ? planFor(st, text) : null;
    final nlFound = plan != null && plan.link == null && plan.split == null && plan.nl.date != null;
    final tiles = _tiles();
    final canSave = _mode == Mode.link ? _info != null : text.trim().isNotEmpty;
    final saveLabel = plan?.link != null
        ? 'Set time'
        : plan?.split != null
            ? ((_splitMode ?? plan!.split!.def) == 'list' ? 'Add list' : 'Add ${plan!.split!.parts.length}')
            : switch (_mode) { Mode.link => 'Save for later', Mode.reminder => 'Set reminder', Mode.todo => 'Add to-do' };
    final group = _folder.isEmpty ? null : st.folderNamed(_folder);

    Widget field() {
      if (_mode == Mode.link) {
        if (_info != null) {
          return Container(
            key: widget.fieldKey,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: ll.dark ? ll.surface : Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: _info!.image.isNotEmpty ? Image.network(_info!.image, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: ll.chip)) : Container(color: ll.chip, alignment: Alignment.center, child: Text(_info!.domain[0].toUpperCase(), style: t(20, FontWeight.w600, ll.ink2))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_loading ? 'Getting the title…' : _info!.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t(17, FontWeight.w600, _loading ? ll.ink2 : ll.ink, h: 1.25)),
                  const SizedBox(height: 3),
                  Mono(_info!.domain),
                ]),
              ),
              if (!widget.shared)
                Tap(
                  onTap: () => setState(() {
                    _info = null;
                    _url.clear();
                  }),
                  child: Padding(padding: const EdgeInsets.all(6), child: LLIcon('x', size: 16, color: ll.ink2)),
                ),
            ]),
          );
        }
        return Container(
          key: widget.fieldKey,
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: ll.dark ? ll.surface : Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            Opacity(opacity: .6, child: LLIcon('link', size: 18, color: ll.ink)),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _url,
                focusNode: _urlFocus,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (v) {
                  final u = extractUrl(v) ?? v.trim();
                  if (u.isNotEmpty) _setLink(u);
                },
                style: t(15, FontWeight.w500, ll.ink),
                decoration: InputDecoration.collapsed(hintText: widget.fromBar ? 'Paste a link or type a reminder' : 'Paste a link', hintStyle: t(15, FontWeight.w500, ll.ink3)),
              ),
            ),
            Tap(
              onTap: () async {
                final d = await Clipboard.getData('text/plain');
                final u = extractUrl(d?.text ?? '');
                if (u != null) {
                  _url.text = u;
                  _setLink(u);
                } else {
                  if (context.mounted) AppScope.of(context).toast.show('No link copied yet');
                }
              },
              child: Container(height: 32, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center, decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(99)), child: Text('Paste', style: t(13, FontWeight.w500, ll.ink))),
            ),
          ]),
        );
      }
      return Container(
        key: widget.fieldKey,
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
        decoration: BoxDecoration(color: ll.dark ? ll.surface : Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _title,
              focusNode: _titleFocus,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: t(15, FontWeight.w500, ll.ink, h: 1.4),
              decoration: InputDecoration.collapsed(
                hintText: _mode == Mode.todo ? 'What needs doing? “pack bags friday 8pm”' : 'Remind me to… “call mom 9pm tomorrow”',
                hintStyle: t(15, FontWeight.w500, ll.ink3),
              ),
            ),
          ),
        ]),
      );
    }

    final body = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!widget.shared)
        _fade(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SegTabs(
            options: const [('link', 'Link'), ('reminder', 'Reminder'), ('todo', 'To-do')],
            value: _mode.name,
            onChanged: (m) => setState(() {
              final carry = _mode == Mode.link ? _url.text : _title.text;
              _mode = Mode.values.byName(m);
              _tile = 0;
              if (_mode != Mode.link && _title.text.isEmpty && carry.isNotEmpty && extractUrl(carry) == null) _title.text = carry;
            }),
          ),
        )),
      field(),
      if (plan != null)
        _fade(Padding(padding: const EdgeInsets.only(top: 8), child: PlanPreview(plan: plan, mode: _splitMode, onMode: (m) => setState(() => _splitMode = m)))),
      if (_mode != Mode.link)
        _fade(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 8, children: [
            PillChip(label: _photo == null ? 'Add photo' : 'Change photo', icon: 'photo', onTap: _pickPhoto, height: 34),
          ]),
        )),
      if (_photo != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.file(File(_photo!), height: 140, width: double.infinity, fit: BoxFit.cover)),
            Positioned(top: 8, right: 8, child: RoundBtn(icon: 'x', size: 34, iconSize: 16, onTap: () => setState(() => _photo = null))),
          ]),
        ),
      _fade(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetLabel(_mode == Mode.link ? 'Folder' : 'Folder · optional, tap again to remove'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in st.folders)
            PillChip(
              label: f.name,
              icon: f.collab ? 'users' : null,
              on: _folder.toLowerCase() == f.name.toLowerCase(),
              onTap: () => setState(() => _folder = _folder.toLowerCase() == f.name.toLowerCase() ? '' : f.name),
            ),
          PillChip(
            label: 'New',
            icon: 'plus',
            onTap: () async {
              final f = await newFolderSheet(context);
              if (f != null && mounted) setState(() => _folder = f.name);
            },
          ),
        ]),
        if (group != null && group.collab && _mode != Mode.link)
          Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 0), child: Text('Everyone in ${group.name} gets this reminder. It only shows inside the group.', style: t(13, FontWeight.w400, ll.ink2))),
        SheetLabel(_mode == Mode.todo ? 'When' : _mode == Mode.link ? 'Bring it back' : 'When${nlFound ? ' · set from what you typed' : ''}'),
        if (_mode == Mode.link)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Tap(
              onTap: _sayWhenMic,
              scale: .98,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(16), border: Border.all(color: _listening ? ll.blue : Colors.transparent, width: 1.5)),
                child: Row(children: [
                  LLIcon('mic', size: 18, color: _listening ? ll.blue : ll.ink),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _sayWhen != null
                        ? Text.rich(TextSpan(children: [
                            TextSpan(text: '${fmtDay(_sayWhen!.date!)}, ${fmtT(_sayWhen!.date!)}${_sayWhen!.repeat.isNotEmpty ? ' · ${_sayWhen!.repeatText}' : ''}', style: t(13, FontWeight.w600, ll.blueInk)),
                            TextSpan(text: ' · tap to say again', style: t(13, FontWeight.w400, ll.ink2)),
                          ]))
                        : Text(_listening ? 'Listening… say “Sunday morning”' : 'Say when: “Sunday morning”, “kal raat 9 baje”', maxLines: 1, overflow: TextOverflow.ellipsis, style: t(13, FontWeight.w400, ll.ink2)),
                  ),
                ]),
              ),
            ),
          ),
        IgnorePointer(
          ignoring: nlFound || (_mode == Mode.link && _sayWhen != null),
          child: Opacity(
            opacity: nlFound || (_mode == Mode.link && _sayWhen != null) ? .35 : 1,
            child: Row(children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Tap(
                    onTap: () async {
                      Haptics.tick();
                      if (_mode == Mode.reminder && i == 3) {
                        final d = await pickTime(context, initial: _picked ?? AppStore.now().add(const Duration(hours: 1)));
                        if (d == null || !mounted) return;
                        setState(() => _picked = d);
                      }
                      setState(() => _tile = i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: ll.dark ? ll.surface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _tile == i ? ll.ink : Colors.transparent, width: 1.5),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tiles[i].label, maxLines: 1, style: t(13, FontWeight.w600, ll.ink)),
                        Text(tiles[i].sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(11, FontWeight.w400, ll.ink2)),
                      ]),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ),
        if (_mode != Mode.link) ...[
          const SheetLabel('Repeat'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            PillChip(label: 'Once', on: _repeat.isEmpty && !_pickDays, onTap: () => setState(() => [_repeat = [], _pickDays = false])),
            PillChip(label: 'Every day', icon: 'repeat', on: _repeat.length == 7, onTap: () => setState(() => [_repeat = [1, 2, 3, 4, 5, 6, 7], _pickDays = false])),
            PillChip(label: 'Mon–Fri', on: !_pickDays && _repeat.length == 5, onTap: () => setState(() => [_repeat = [1, 2, 3, 4, 5], _pickDays = false])),
            PillChip(label: 'Pick days', on: _pickDays, onTap: () => setState(() => [_pickDays = true, if (_repeat.isEmpty || _repeat.length == 7) _repeat = [AppStore.now().weekday]])),
          ]),
          if (_pickDays)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                for (var i = 1; i <= 7; i++) ...[
                  if (i > 1) const SizedBox(width: 6),
                  Expanded(
                    child: Tap(
                      onTap: () => setState(() {
                        final n = [..._repeat];
                        n.contains(i) ? n.remove(i) : n.add(i);
                        if (n.isNotEmpty) _repeat = n..sort();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: _repeat.contains(i) ? ll.ink : ll.chip),
                        child: Text('MTWTFSS'[i - 1], style: t(13, FontWeight.w600, _repeat.contains(i) ? ll.onInk : ll.ink2)),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
        ],
        if (_mode == Mode.todo) ...[
          const SheetLabel('Steps'),
          for (var i = 0; i < _steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ll.ink3, width: 1.5))),
                const SizedBox(width: 10),
                Expanded(child: Text(_steps[i], style: t(15, FontWeight.w400, ll.ink))),
                Tap(onTap: () => setState(() => _steps.removeAt(i)), child: Padding(padding: const EdgeInsets.all(4), child: LLIcon('x', size: 14, color: ll.ink3))),
              ]),
            ),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: ll.dark ? ll.surface : Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Opacity(opacity: .5, child: LLIcon('plus', size: 16, color: ll.ink)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _step,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (v) {
                    if (v.trim().isEmpty) return;
                    setState(() => _steps.add(v.trim()));
                    _step.clear();
                  },
                  style: t(15, FontWeight.w400, ll.ink),
                  decoration: InputDecoration.collapsed(hintText: 'Add a step, press enter', hintStyle: t(15, FontWeight.w400, ll.ink3)),
                ),
              ),
            ]),
          ),
        ],
        if (_mode == Mode.link)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: ll.dark ? ll.surface : Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Opacity(opacity: .5, child: LLIcon('note', size: 16, color: ll.ink)),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _note, style: t(15, FontWeight.w400, ll.ink), decoration: InputDecoration.collapsed(hintText: 'Add a note (optional)', hintStyle: t(15, FontWeight.w400, ll.ink3)))),
              ]),
            ),
          ),
        const SizedBox(height: 18),
        Row(children: [
          GhostBtn(label: 'Cancel', onTap: widget.onClose),
          const SizedBox(width: 8),
          Expanded(child: AccentBtn(label: saveLabel, enabled: canSave, onTap: _save)),
        ]),
      ])),
    ]);

    return SheetFrame(child: body);
  }
}

// =============================================================================
// Share window: the small card over Instagram / YouTube. No mode tabs.

class ShareSave extends StatelessWidget {
  const ShareSave({super.key, required this.text, required this.onDone, this.onSaved});
  final String text;
  final VoidCallback onDone;
  final Future<void> Function()? onSaved;
  @override
  Widget build(BuildContext context) => SaveBody(
        text: text,
        shared: extractUrl(text) != null,
        mode: extractUrl(text) != null ? Mode.link : Mode.reminder,
        onClose: () async => onDone(),
        onSaved: onSaved,
      );
}
