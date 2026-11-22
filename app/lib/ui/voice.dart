// Tap the mic, speak, Lil listens (big ears), then it adds itself.
// Tap the words to fix them: auto-add pauses while you type.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data/nl.dart';
import '../mascot/mascot_svg.dart';
import '../mascot/mascot_view.dart';
import '../services/haptics.dart';
import '../theme/tokens.dart';
import 'actions.dart';
import 'kit.dart';
import 'save.dart' show NLController, PlanPreview;

final _stt = SpeechToText();
bool _sttReady = false;

Future<bool> _initStt() async {
  if (_sttReady) return true;
  try {
    _sttReady = await _stt.initialize(onError: (_) {}, onStatus: (_) {});
  } catch (_) {
    _sttReady = false;
  }
  return _sttReady;
}

/// Opens the voice panel. [onText] (optional) gets the words instead of adding
/// them, for "say when" on a link.
Future<void> openVoice(BuildContext context, {String folder = ''}) => showLLSheet(context, (_) => _Voice(folder: folder), scroll: false);

class _Voice extends StatefulWidget {
  const _Voice({this.folder = ''});
  final String folder;
  @override
  State<_Voice> createState() => _VoiceState();
}

enum _Phase { starting, listening, ready, editing, failed }

class _VoiceState extends State<_Voice> with TickerProviderStateMixin {
  final _text = NLController();
  final _focus = FocusNode();
  final _lil = MascotController(base: Mood.listen);
  late final AnimationController _count = AnimationController(vsync: this, duration: const Duration(seconds: 7));
  late final AnimationController _ears = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  _Phase _phase = _Phase.starting;
  Timer? _silence, _idle;
  String? _mode; // reminders | list (for sentences with several things)
  bool _closed = false;

  String get _lang => AppScope.of(context).store.voiceLang;

  @override
  void initState() {
    super.initState();
    _count.addStatusListener((s) {
      if (s == AnimationStatus.completed) _commit();
    });
    _focus.addListener(() {
      if (_focus.hasFocus) _pauseForEdit();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  // Android stops listening after a short pause, so we keep the words heard so
  // far (_acc) and quietly start listening again until you stop talking.
  String _acc = '', _cur = '';
  DateTime _began = DateTime.now();
  bool _restarting = false;

  Future<void> _start() async {
    final ok = await _initStt();
    if (!mounted || _closed) return;
    if (!ok) {
      setState(() => _phase = _Phase.failed);
      return;
    }
    _acc = '';
    _cur = '';
    _began = DateTime.now();
    setState(() => _phase = _Phase.listening);
    Haptics.light();
    _stt.statusListener = (st) {
      if (st == 'done' || st == 'notListening') _sessionEnded();
    };
    _stt.errorListener = (_) => _sessionEnded();
    await _listen();
  }

  Future<void> _listen() async {
    if (!mounted || _closed || _phase != _Phase.listening) return;
    try {
      await _stt.listen(
        onResult: (r) {
          if (!mounted || _phase != _Phase.listening) return;
          _cur = r.recognizedWords;
          if (r.finalResult) {
            _acc = '$_acc $_cur'.trim();
            _cur = '';
          }
          _text.text = '$_acc $_cur'.trim();
          _lil.play(MascotAct.squish);
          // Done when nothing new has been heard for 2 seconds.
          _silence?.cancel();
          _silence = Timer(const Duration(milliseconds: 2000), _ready);
          setState(() {});
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          localeId: _lang.replaceAll('-', '_'),
          pauseFor: const Duration(seconds: 4),
          listenFor: const Duration(seconds: 60),
        ),
      );
    } catch (_) {
      if (mounted && _text.text.isEmpty) setState(() => _phase = _Phase.failed);
    }
  }

  void _sessionEnded() {
    if (!mounted || _closed || _phase != _Phase.listening || _restarting) return;
    if (_cur.isNotEmpty) {
      _acc = '$_acc $_cur'.trim();
      _cur = '';
    }
    final waited = DateTime.now().difference(_began);
    if (_text.text.trim().isEmpty && waited > const Duration(seconds: 10)) {
      setState(() => _phase = _Phase.failed);
      return;
    }
    // Still talking (or not started yet): listen again.
    _restarting = true;
    Future<void>.delayed(const Duration(milliseconds: 120), () async {
      _restarting = false;
      await _listen();
    });
  }

  void _ready() {
    if (!mounted || _phase != _Phase.listening || _text.text.trim().isEmpty) return;
    _silence?.cancel();
    _stt.stop();
    Haptics.light();
    _lil.setBase(Mood.happy);
    _lil.play(MascotAct.hop);
    setState(() => _phase = _Phase.ready);
    _count.forward(from: 0);
  }

  void _pauseForEdit() {
    _silence?.cancel();
    _idle?.cancel();
    if (_phase == _Phase.listening) _stt.stop();
    _count.stop();
    _count.value = 0;
    _lil.setBase(Mood.idle);
    if (_phase != _Phase.editing) setState(() => _phase = _Phase.editing);
  }

  void _typed() {
    _idle?.cancel();
    _count.stop();
    _count.value = 0;
    setState(() {});
    // Start the countdown again 1 second after typing stops.
    _idle = Timer(const Duration(seconds: 1), () {
      if (!mounted || _text.text.trim().isEmpty) return;
      _lil.setBase(Mood.happy);
      _count.forward(from: 0);
      setState(() {});
    });
  }

  void _commit() {
    if (_closed) return;
    final v = _text.text.trim();
    if (v.isEmpty) return;
    _closed = true;
    final s = AppScope.of(context);
    Navigator.of(context).pop();
    addFromText(s, v, mode: _mode, folder: widget.folder);
    Haptics.medium();
  }

  void _switchLang() {
    final st = AppScope.of(context).store;
    st.setVoiceLang(_lang == 'hi-IN' ? 'en-IN' : 'hi-IN');
    _stt.cancel();
    _silence?.cancel();
    _count.stop();
    _count.value = 0;
    _text.clear();
    _lil.setBase(Mood.listen);
    setState(() => _phase = _Phase.starting);
    _start();
  }

  @override
  void dispose() {
    _closed = true;
    _silence?.cancel();
    _idle?.cancel();
    _stt.cancel();
    _count.dispose();
    _ears.dispose();
    _lil.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final st = AppScope.of(context).store;
    final hi = _lang == 'hi-IN';
    final v = _text.text;
    final plan = v.trim().isEmpty ? null : planFor(st, v);
    final status = switch (_phase) {
      _Phase.starting => 'Getting the mic ready…',
      _Phase.listening => 'Speak, then pause. Tap the words to fix them.',
      _Phase.ready => 'Got it! Adding in a few seconds. Tap the words to fix them.',
      _Phase.editing => 'Editing. It adds 1 second after you stop typing.',
      _Phase.failed => v.isEmpty ? 'Couldn’t hear anything. Type it here instead, or try again.' : 'Tap the words to fix them.',
    };
    final addLabel = plan?.link != null
        ? 'Set time'
        : plan?.split != null
            ? ((_mode ?? plan!.split!.def) == 'list' ? 'Add list' : 'Add ${plan!.split!.parts.length}')
            : 'Add';
    final editing = _phase == _Phase.editing || _phase == _Phase.failed;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Spacer(),
        Tap(
          onTap: _switchLang,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(hi ? 'हि' : 'EN', style: t(13, FontWeight.w600, ll.ink)),
              const SizedBox(width: 6),
              Text(hi ? 'Hindi' : 'English', style: t(11, FontWeight.w500, ll.ink2)),
            ]),
          ),
        ),
      ]),
      SizedBox(
        height: 130,
        child: Center(
          child: AnimatedBuilder(
            animation: _ears,
            builder: (_, c) => Transform.scale(scale: _phase == _Phase.listening ? 1 + .03 * _ears.value : 1, child: c),
            child: SizedBox(width: 124, height: 124, child: MascotView(stage: 3, controller: _lil, outfit: st.outfitNow)),
          ),
        ),
      ),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () {
          _pauseForEdit();
          _focus.requestFocus();
        },
        child: editing
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(18)),
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  autofocus: _phase == _Phase.editing,
                  minLines: 1,
                  maxLines: 4,
                  textAlign: TextAlign.center,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => _typed(),
                  onSubmitted: (_) => _commit(),
                  style: t(20, FontWeight.w600, ll.ink, h: 1.35),
                  decoration: InputDecoration.collapsed(hintText: hi ? 'kal 12 baje doodh lana hai' : 'call mom 9pm tomorrow', hintStyle: t(20, FontWeight.w500, ll.ink3)),
                ),
              )
            : Container(
                constraints: const BoxConstraints(minHeight: 60),
                alignment: Alignment.center,
                child: v.isEmpty
                    ? Text(hi ? 'बोलिए… जैसे “kal 12 baje doodh lana hai”' : 'I’m listening… try “call mom 9pm tomorrow”', textAlign: TextAlign.center, style: t(17, FontWeight.w500, ll.ink3))
                    : Text.rich(
                        TextSpan(children: [
                          _text.buildTextSpan(context: context, style: t(22, FontWeight.w600, ll.ink, ls: -.015, h: 1.35), withComposing: false),
                          WidgetSpan(alignment: PlaceholderAlignment.middle, child: Padding(padding: const EdgeInsets.only(left: 6), child: Opacity(opacity: .7, child: IconTile('edit', size: 26, radius: 13)))),
                        ]),
                        textAlign: TextAlign.center,
                      ),
              ),
      ),
      if (plan != null) Padding(padding: const EdgeInsets.only(top: 10), child: PlanPreview(plan: plan, mode: _mode, onMode: (m) => setState(() => _mode = m), center: true)),
      Padding(padding: const EdgeInsets.only(top: 12), child: Text(status, textAlign: TextAlign.center, style: t(13, FontWeight.w400, ll.ink2))),
      const SizedBox(height: 16),
      Row(children: [
        GhostBtn(label: 'Cancel', onTap: () => Navigator.of(context).pop()),
        const SizedBox(width: 8),
        Expanded(
          child: _phase == _Phase.failed && v.isEmpty
              ? AccentBtn(label: 'Try again', icon: 'mic', onTap: () {
                  setState(() => _phase = _Phase.starting);
                  _lil.setBase(Mood.listen);
                  _start();
                })
              : AccentBtn(label: addLabel, enabled: v.trim().isNotEmpty, onTap: _commit, progress: _phase == _Phase.ready || _phase == _Phase.editing ? _count : null),
        ),
      ]),
    ]);
  }
}

/// Listen once for a time ("Sunday morning", "kal raat 9 baje"). Returns the words.
Future<String?> listenOnce(BuildContext context) async {
  final st = AppScope.of(context).store;
  if (!await _initStt()) return null;
  final c = Completer<String?>();
  var said = '';
  Timer? done;
  void finish() {
    if (c.isCompleted) return;
    _stt.stop();
    c.complete(said.trim().isEmpty ? null : said);
  }

  await _stt.listen(
    onResult: (r) {
      said = r.recognizedWords;
      done?.cancel();
      done = Timer(const Duration(milliseconds: 1200), finish);
      if (r.finalResult) finish();
    },
    listenOptions: SpeechListenOptions(partialResults: true, localeId: st.voiceLang.replaceAll('-', '_'), pauseFor: const Duration(seconds: 3), listenFor: const Duration(seconds: 12), cancelOnError: true),
  );
  _stt.statusListener = (s) {
    if (s == 'done' || s == 'notListening') finish();
  };
  Timer(const Duration(seconds: 14), finish);
  return c.future;
}

/// Quick check used by the save sheet: does this text contain a time?
bool hasTime(String s) => parseNL(s).found;
