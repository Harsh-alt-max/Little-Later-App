// Today: greeting sentence, the save bar, the big card (links first), then
// Saved for later, To-do lists, and a quiet list of reminders.
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../mascot/mascot_svg.dart';
import '../services/haptics.dart';
import '../theme/tokens.dart';
import '../widgets/eyes_refresh.dart';
import '../services/festival.dart';
import 'festive.dart';
import 'items.dart';
import 'kit.dart';
import 'save.dart';
import 'voice.dart';

const _rank = {ItemKind.link: 0, ItemKind.todoList: 1, ItemKind.reminder: 2};

/// Today's own things (group reminders stay inside groups), links first.
List<Item> personalQueue(AppStore st) {
  final q = st.todayQueue.where((i) => groupOf(st, i) == null && i.extra['msg'] != true).toList();
  q.sort((a, b) {
    final r = _rank[a.kind]!.compareTo(_rank[b.kind]!);
    return r != 0 ? r : a.whenTs.compareTo(b.whenTs);
  });
  return q;
}

class TodayView extends StatefulWidget {
  const TodayView({super.key, required this.scroll});
  final ScrollController scroll;
  @override
  State<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<TodayView> {
  final _barKey = GlobalKey();
  bool _barHidden = false;

  Future<void> _openBar() async {
    final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
    final rect = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _barHidden = true);
    await openSave(context, from: rect);
    if (mounted) setState(() => _barHidden = false);
  }

  String _greeting() {
    final h = AppStore.now().hour;
    return h < 5
        ? 'Up late'
        : h < 12
        ? 'Good morning'
        : h < 17
        ? 'Good afternoon'
        : 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final st = s.store;
    return ListenableBuilder(
      listenable: Listenable.merge([st, Festivals.i]),
      builder: (context, _) {
        final q = personalQueue(st);
        final hero = q.isEmpty ? null : q.first;
        final links = q.where((i) => i.kind == ItemKind.link).length, tds = q.where((i) => i.kind == ItemKind.todoList).length, rem = q.where((i) => i.kind == ItemKind.reminder).length;
        final name = st.userName.isEmpty ? '' : ', ${st.userName.split(' ').first}';
        final strong = t(30, FontWeight.w600, ll.ink, ls: -.03, h: 1.2), soft = t(30, FontWeight.w600, ll.ink3, ls: -.03, h: 1.2);
        final parts = <(int, String, String)>[if (links > 0) (links, 'link', 'links'), if (tds > 0) (tds, 'to-do', 'to-dos'), if (rem > 0) (rem, 'reminder', 'reminders')];
        final fest = Festivals.i.now;
        final spans = <InlineSpan>[TextSpan(text: '${fest != null && fest.greeting.isNotEmpty ? fest.greeting : _greeting()}$name. ', style: soft)];
        if (q.isEmpty) {
          spans.addAll([TextSpan(text: 'Nothing', style: strong), TextSpan(text: ' is waiting. Enjoy the day.', style: soft)]);
        } else {
          spans.addAll([TextSpan(text: '${q.length} ${q.length == 1 ? 'thing is' : 'things are'}', style: strong), TextSpan(text: ' waiting: ', style: soft)]);
          for (var i = 0; i < parts.length; i++) {
            if (i > 0) spans.add(TextSpan(text: i == parts.length - 1 ? ' and ' : ', ', style: soft));
            spans.add(TextSpan(text: '${parts[i].$1} ${parts[i].$1 == 1 ? parts[i].$2 : parts[i].$3}', style: strong));
          }
          spans.add(TextSpan(text: '.', style: soft));
        }

        final mine = st.items.where((i) => !i.isDone && groupOf(st, i) == null && i != hero && i.extra['msg'] != true).toList();
        int byWhen(Item a, Item b) => (a.whenTs == 0 ? 1 : 0).compareTo(b.whenTs == 0 ? 1 : 0) != 0 ? (a.whenTs == 0 ? 1 : 0).compareTo(b.whenTs == 0 ? 1 : 0) : a.whenTs.compareTo(b.whenTs);
        final saved = mine.where((i) => i.kind == ItemKind.link).toList()..sort(byWhen);
        final todos = mine.where((i) => i.kind == ItemKind.todoList).toList()..sort(byWhen);
        final rems = mine.where((i) => i.kind == ItemKind.reminder && i.whenTs > 0).toList()..sort(byWhen);
        final top = MediaQuery.paddingOf(context).top;
        final n = AppStore.now();

        return Stack(
          children: [
            EyesRefresh(
              onRefresh: s.app.refresh,
              child: ListView(
                controller: widget.scroll,
                physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                padding: EdgeInsets.fromLTRB(0, top + 14, 0, 150),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const MarkLogo(size: 34),
                        const SizedBox(width: 10),
                        Mono(
                          '${const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][n.weekday - 1]}, ${n.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][n.month - 1]}',
                        ),
                        const Spacer(),
                        Tap(
                          onTap: () => s.app.openLil(streak: true),
                          semanticLabel: '${st.streak} day streak',
                          child: Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(color: ll.dark ? ll.surface2 : ll.surface, borderRadius: BorderRadius.circular(99)),
                            child: Row(
                              children: [
                                LLIcon('flame', size: 15, color: ll.ember, stroke: 2.2),
                                const SizedBox(width: 5),
                                Text('${st.streak}', style: t(13, FontWeight.w600, ll.ink)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        RoundBtn(icon: 'bell', size: 34, iconSize: 17, dot: st.unreadNotes > 0, onTap: s.app.openNotes, label: 'Notifications'),
                        const SizedBox(width: 8),
                        Tap(
                          onTap: () => s.goTab(3),
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: ll.ink),
                            child: Text(st.userName.isEmpty ? 'H' : st.userName[0].toUpperCase(), style: t(13, FontWeight.w600, ll.onInk)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                    child: Text.rich(TextSpan(children: spans)),
                  ),
                  // The save bar: tap and it grows into the save sheet.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Opacity(
                      opacity: _barHidden ? 0 : 1,
                      child: Container(
                        key: _barKey,
                        height: 56,
                        padding: const EdgeInsets.only(left: 16, right: 6),
                        decoration: BoxDecoration(
                          color: ll.dark ? ll.surface : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: ll.dark ? Border.all(color: ll.line) : null,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _openBar,
                                child: SizedBox(
                                  height: 56,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text('Paste a link or type a reminder', maxLines: 1, overflow: TextOverflow.ellipsis, style: t(15, FontWeight.w500, ll.ink3)),
                                  ),
                                ),
                              ),
                            ),
                            Tap(
                              onTap: () => openSave(context, mode: Mode.reminder),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Opacity(opacity: .6, child: LLIcon('photo', size: 18, color: ll.ink)),
                              ),
                            ),
                            Tap(
                              onTap: () => openVoice(context),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Opacity(opacity: .6, child: LLIcon('mic', size: 19, color: ll.ink)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Motion.smooth,
                    transitionBuilder: (c, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(a),
                        child: c,
                      ),
                    ),
                    child: hero == null
                        ? Padding(
                            key: const ValueKey('empty'),
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                const Lil(size: 110, mood: Mood.sleep),
                                const SizedBox(height: 8),
                                Text('Nothing left for today. ${st.mascotName} is proud of you.', textAlign: TextAlign.center, style: t(15, FontWeight.w400, ll.ink2)),
                              ],
                            ),
                          )
                        : _Focus(key: ValueKey(hero.id), item: hero, next: q.length > 1 ? q[1] : null),
                  ),
                  if (saved.isNotEmpty) ...[
                    _Head('Saved for later', action: 'See all', onAction: () => s.goTab(1)),
                    SizedBox(
                      height: 190,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: saved.length.clamp(0, 10),
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => _LinkCard(item: saved[i]),
                      ),
                    ),
                  ],
                  if (todos.isNotEmpty) ...[
                    const _Head('To-do lists'),
                    Surface(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          for (var i = 0; i < todos.length; i++) ...[if (i > 0) Divider(height: 1, thickness: 1, indent: 78, color: ll.line), ItemRow(item: todos[i])],
                        ],
                      ),
                    ),
                  ],
                  if (rems.isNotEmpty) ...[
                    const _Head('Reminders', right: 'They’ll ping you'),
                    Surface(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          for (var i = 0; i < rems.length && i < 6; i++) ...[
                            if (i > 0) Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: ll.line),
                            Tap(
                              scale: .98,
                              onTap: () => openDetail(context, rems[i]),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                child: Row(
                                  children: [
                                    SizedBox(width: 70, child: Text(fmtT(DateTime.fromMillisecondsSinceEpoch(rems[i].whenTs)), style: t(13, FontWeight.w600, ll.ink))),
                                    Expanded(
                                      child: Text(rems[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(15, FontWeight.w500, ll.ink)),
                                    ),
                                    Text('${fmtDay(DateTime.fromMillisecondsSinceEpoch(rems[i].whenTs))}${rems[i].repeats ? ' · ${repeatLabel(rems[i].repeatDays)}' : ''}', style: t(13, FontWeight.w400, ll.ink2)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (fest != null && (fest.snow || fest.confetti)) Positioned(left: 0, right: 0, top: 0, height: 320, child: FestiveFall(confetti: fest.confetti)),
          ],
        );
      },
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.title, {this.action, this.onAction, this.right});
  final String title;
  final String? action, right;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 10),
      child: Row(
        children: [
          Mono(title),
          const Spacer(),
          if (action != null)
            Tap(
              onTap: onAction,
              child: Mono(action!, color: ll.ink),
            ),
          if (right != null) Mono(right!, color: ll.ink3),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.item});
  final Item item;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final due = isDueToday(item);
    return Tap(
      onTap: () => openUrl(s, item),
      child: GestureDetector(
        onLongPress: () => openDetail(context, item),
        child: SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Cover2(item: item, width: 150, height: 106, radius: 18),
              const SizedBox(height: 8),
              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t(15, FontWeight.w600, ll.ink, h: 1.25)),
              const SizedBox(height: 3),
              Text(item.whenTs > 0 ? whenLabel(item) : item.domain, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(13, FontWeight.w400, due ? ll.blueInk : ll.ink2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The big card: swipe right for Done, left for Later.
class _Focus extends StatefulWidget {
  const _Focus({super.key, required this.item, this.next});
  final Item item;
  final Item? next;
  @override
  State<_Focus> createState() => _FocusState();
}

class _FocusState extends State<_Focus> with SingleTickerProviderStateMixin {
  double _dx = 0;
  late final AnimationController _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _back.addListener(() => setState(() => _dx = _from * (1 - Curves.easeOutBack.transform(_back.value))));
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _end(DragEndDetails d) {
    final s = AppScope.of(context);
    final w = MediaQuery.sizeOf(context).width;
    if (_dx > w * .3 || d.primaryVelocity! > 900) {
      markDone(s, widget.item, from: context);
    } else if (_dx < -w * .3 || d.primaryVelocity! < -900) {
      markLater(s, widget.item);
    } else {
      _from = _dx;
      _back.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final it = widget.item;
    final link = it.kind == ItemKind.link;
    final d = DateTime.fromMillisecondsSinceEpoch(it.whenTs);
    final tm = fmtT(d).split(' ');
    final meta = [if (it.folder.isNotEmpty) it.folder, if (link) it.domain, if (it.repeats) repeatLabel(it.repeatDays)].join(' · ');
    final w = MediaQuery.sizeOf(context).width;
    final p = (_dx / (w * .3)).clamp(-1.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          GestureDetector(
            onHorizontalDragUpdate: (u) => setState(() => _dx += u.delta.dx),
            onHorizontalDragEnd: _end,
            onTap: () => openDetail(context, it),
            child: Transform.translate(
              offset: Offset(_dx, 0),
              child: Transform.rotate(
                angle: _dx / w * .12,
                child: Stack(
                  children: [
                    Surface(
                      radius: 30,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (link || it.thumbnail.isNotEmpty)
                            Stack(
                              children: [
                                Cover2(item: it, height: 180, radius: 22),
                                if (link)
                                  Positioned(
                                    left: 12,
                                    bottom: 12,
                                    child: Tap(
                                      onTap: () => openUrl(s, it),
                                      child: Container(
                                        height: 30,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: .45), borderRadius: BorderRadius.circular(99)),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const LLIcon('play', size: 12, color: Colors.white, stroke: 2.6),
                                            const SizedBox(width: 6),
                                            Text('Open', style: t(13, FontWeight.w600, Colors.white)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          else
                            Container(
                              height: 120,
                              decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(22)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Opacity(opacity: .7, child: LLIcon(it.kind == ItemKind.todoList ? 'todo' : 'bell', size: 14, color: ll.ink)),
                                      const SizedBox(width: 6),
                                      Text(it.kind == ItemKind.todoList ? 'To-do' : 'Reminder', style: t(13, FontWeight.w600, ll.ink2)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(tm.first, style: t(44, FontWeight.w600, ll.ink, ls: -.04, h: 1)),
                                      const SizedBox(width: 4),
                                      Text(tm.last, style: t(17, FontWeight.w500, ll.ink2)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Mono(meta.isEmpty ? fmtDay(d) : meta),
                                const SizedBox(height: 4),
                                Text(it.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: t(22, FontWeight.w600, ll.ink, ls: -.02, h: 1.25)),
                                if (it.note.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(it.note, maxLines: 2, overflow: TextOverflow.ellipsis, style: t(15, FontWeight.w400, ll.ink2)),
                                  ),
                                if (it.tasks.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: StepsList(item: it, max: 5),
                                  ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Builder(
                                        builder: (bc) => InkBtn(
                                          label: 'Done',
                                          onTap: () => markDone(s, it, from: bc),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    RoundBtn(icon: 'clock', size: 52, label: 'Later', bg: ll.chip, onTap: () => markLater(s, it)),
                                    if (link) ...[const SizedBox(width: 8), RoundBtn(icon: 'ext', size: 52, label: 'Open', bg: ll.chip, onTap: () => openUrl(s, it))],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (p.abs() > .05)
                      Positioned(
                        top: 18,
                        left: p > 0 ? 18 : null,
                        right: p < 0 ? 18 : null,
                        child: Opacity(
                          opacity: p.abs(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(color: p > 0 ? ll.blue : ll.ink, borderRadius: BorderRadius.circular(99)),
                            child: Text(p > 0 ? 'Done' : 'Later', style: t(15, FontWeight.w600, p > 0 ? ll.onAccent : ll.onInk)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.next != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: ll.dark ? ll.surface2 : const Color(0xFFEFECE7),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Text('Next', style: t(13, FontWeight.w400, ll.ink2)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.next!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(13, FontWeight.w600, ll.ink)),
                  ),
                  Text(fmtT(DateTime.fromMillisecondsSinceEpoch(widget.next!.whenTs)), style: t(13, FontWeight.w400, ll.ink2)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Lil's daily hello (streak counted when you open the app).
void haptic() => Haptics.light();
