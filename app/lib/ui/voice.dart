// Tap the mic and talk. Lil keeps listening, through pauses, until you tap
// Add, Cancel or the mic button. Nothing you said is thrown away until you
// close the panel. Tap the words to fix them.
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

/// Opens the voice panel.
Future<void> openVoice(BuildContext context, {String folder = ''}) => showLLSheet(context, (_) => _Voice(folder: folder), scroll: false);

class _Voice extends StatefulWidget {
  const _Voice({this.folder = ''});
  final String folder;
  @override
  State<_Voice> createState() => _VoiceState();
}

/// listening: mic on. paused: mic off, words kept (tap the mic to go on).
enum _Phase { starting, listening, paused, failed }

class _VoiceState extends State<_Voice> with TickerProviderStateMixin {
  final _text = NLController();
  final _focus = FocusNode();
  final _lil = MascotController(base: Mood.listen);
  late final AnimationController _ears = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  _Phase _phase = _Phase.starting;
  bool _editing = false;
  Timer? _quiet;
  String? _mode; // reminders | list (for sentences with several things)
  bool _closed = false;

  // The phone's recogniser stops after every pause. We keep what was heard
  // (_acc), and start it again straight away, for as long as the panel is open.
  String _acc = '', _cur = '';
  DateTime _heard = DateTime.now();
  bool _restarting = false;
  int _session = 0; // results from an older listening session are ignored

  /// How long the mic stays on with nothing heard before it pauses itself
  /// (the words stay; tap the mic to go on).
  static const _idleLimit = Duration(seconds: 45);

  String get _lang => AppScope.of(context).store.voiceLang;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) _pause(editing: true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _resume());
  }

  /// Start (or go on) listening. Whatever is in the box is kept and new words
  /// are added after it.
  Future<void> _resume() async {
    if (_closed) return;
    setState(() {
      _phase = _Phase.starting;
      _editing = false;
    });
    _focus.unfocus();
    final ok = await _initStt();
    if (!mounted || _closed || _phase != _Phase.starting) return;
    if (!ok) {
      setState(() => _phase = _Phase.failed);
      return;
    }
    // Set after initialize(), which replaces them, so a pause always restarts
    // the mic instead of leaving it off.
    _stt.statusListener = (st) {
      if (st == 'done' || st == 'notListening') _sessionEnded();
    };
    _stt.errorListener = (_) => _sessionEnded();
    _acc = _text.text.trim();
    _cur = '';
    _heard = DateTime.now();
    _lil.setBase(Mood.listen);
    setState(() => _phase = _Phase.listening);
    Haptics.light();
    await _listen();
  }

  Future<void> _listen() async {
    if (!mounted || _closed || _phase != _Phase.listening) return;
    final my = ++_session;
    try {
      await _stt.listen(
        onResult: (r) {
          if (!mounted || _phase != _Phase.listening || my != _session) return;
          final w = r.recognizedWords.trim();
          if (w.isEmpty) return;
          _cur = w;
          if (r.finalResult) {
            _acc = mergeSpeech(_acc, _cur);
            _cur = '';
          }
          _text.text = mergeSpeech(_acc, _cur);
          _heard = DateTime.now();
          _lil.setBase(Mood.listen);
          _lil.play(MascotAct.squish);
          // A pause: Lil looks happy, but keeps listening.
          _quiet?.cancel();
          _quiet = Timer(const Duration(milliseconds: 1800), () {
            if (mounted && _phase == _Phase.listening) _lil.setBase(Mood.happy);
          });
          setState(() {});
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          localeId: _lang.replaceAll('-', '_'),
          pauseFor: const Duration(seconds: 5),
          listenFor: const Duration(seconds: 60),
        ),
      );
    } catch (_) {
      _sessionEnded();
    }
  }

  void _sessionEnded() {
    if (!mounted || _closed || _phase != _Phase.listening || _restarting) return;
    // Keep the last words of the session that just ended.
    if (_cur.isNotEmpty) {
      _acc = mergeSpeech(_acc, _cur);
      _cur = '';
      _text.text = _acc;
    }
    if (DateTime.now().difference(_heard) > _idleLimit) {
      _pause();
      return;
    }
    // Listen again straight away.
    _restarting = true;
    Future<void>.delayed(const Duration(milliseconds: 150), () async {
      _restarting = false;
      await _listen();
    });
  }

  /// Mic off. The words stay.
  void _pause({bool editing = false}) {
    _quiet?.cancel();
    final was = _phase;
    if (was == _Phase.listening || was == _Phase.starting) {
      _session++;
      _stt.stop();
      if (_cur.isNotEmpty) {
        _acc = mergeSpeech(_acc, _cur);
        _cur = '';
        _text.text = _acc;
      }
    }
    if (!mounted) return;
    _lil.setBase(Mood.idle);
    setState(() {
      if (was != _Phase.failed) _phase = _Phase.paused;
      _editing = editing;
    });
  }

  void _toggleMic() => _phase == _Phase.listening || _phase == _Phase.starting ? _pause() : _resume();

  void _commit() {
    if (_closed) return;
    final v = _text.text.trim();
    if (v.isEmpty) return;
    _closed = true;
    _session++;
    _stt.stop();
    final s = AppScope.of(context);
    Navigator.of(context).pop();
    addFromText(s, v, mode: _mode, folder: widget.folder);
    Haptics.medium();
  }

  void _switchLang() {
    final st = AppScope.of(context).store;
    st.setVoiceLang(_lang == 'hi-IN' ? 'en-IN' : 'hi-IN');
    final on = _phase == _Phase.listening || _phase == _Phase.starting;
    _pause();
    if (on) Future<void>.delayed(const Duration(milliseconds: 200), _resume);
  }

  @override
  void dispose() {
    _closed = true;
    _session++;
    _quiet?.cancel();
    _stt.cancel();
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
      _Phase.listening => v.isEmpty ? 'Take your time. I keep listening until you tap Add.' : 'Still listening. Pause as long as you like, then tap Add.',
      _Phase.paused => _editing ? 'Fix the words, then tap Add. Tap the mic to say more.' : v.isEmpty ? 'Mic paused. Tap the mic to talk.' : 'Mic paused. Tap the mic to say more, or tap Add.',
      _Phase.failed => 'The mic isn’t available. Type it here, or use the mic on your keyboard.',
    };
    final addLabel = plan?.link != null
        ? 'Set time'
        : plan?.split != null
            ? ((_mode ?? plan!.split!.def) == 'list' ? 'Add list' : 'Add ${plan!.split!.parts.length}')
            : 'Add';
    final editing = _editing || _phase == _Phase.failed;
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
          _pause(editing: true);
          _focus.requestFocus();
        },
        child: editing
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(18)),
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  autofocus: _editing,
                  minLines: 1,
                  maxLines: 4,
                  textAlign: TextAlign.center,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _commit(),
                  style: t(20, FontWeight.w600, ll.ink, h: 1.35),
                  decoration: InputDecoration.collapsed(hintText: hi ? 'kal 12 baje doodh lana hai' : 'call mom 9pm tomorrow', hintStyle: t(20, FontWeight.w500, ll.ink3)),
                ),
              )
            : Container(
                constraints: const BoxConstraints(minHeight: 60),
                alignment: Alignment.center,
                child: v.isEmpty
                    ? Text(_phase == _Phase.listening || _phase == _Phase.starting ? (hi ? 'बोलिए… जैसे “kal 12 baje doodh lana hai”' : 'I’m listening… try “call mom 9pm tomorrow”') : 'Tap the mic to talk', textAlign: TextAlign.center, style: t(17, FontWeight.w500, ll.ink3))
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
        if (_phase != _Phase.failed) ...[
          AnimatedBuilder(
            animation: _ears,
            builder: (_, _) {
              final on = _phase == _Phase.listening;
              return Container(
                decoration: on ? BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: ll.blue.withValues(alpha: .25 + .2 * _ears.value), blurRadius: 6 + 8 * _ears.value)]) : null,
                child: RoundBtn(icon: on ? 'pause' : 'mic', label: on ? 'Pause the mic' : 'Talk', size: 52, iconSize: 22, bg: on ? ll.blue : null, fg: on ? ll.onAccent : null, onTap: _toggleMic),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        Expanded(child: AccentBtn(label: addLabel, enabled: v.trim().isNotEmpty, onTap: _commit)),
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
