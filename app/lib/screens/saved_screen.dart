import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../mascot/mascot_svg.dart';
import '../mascot/mascot_view.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/item_tile.dart';
import '../widgets/kit.dart';

/// Shared page header (.pagehead): soft blue glow, optional top row, big title.
class PageHead extends StatelessWidget {
  const PageHead({super.key, this.title, this.left, this.right, this.child});
  final String? title;
  final Widget? left, right, child;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(center: const Alignment(0, -1.2), radius: 1.2, colors: [ll.blue.withValues(alpha: .16), ll.blue.withValues(alpha: 0)], stops: const [0, .7]),
      ),
      padding: EdgeInsets.fromLTRB(20, 16 + top, 20, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: 46, child: Row(children: [left ?? const SizedBox(), const Spacer(), right ?? const SizedBox()])),
        if (title != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(title!, style: t(32, FontWeight.w800, ll.ink, ls: -.03, h: 1.1))),
        ?child,
      ]),
    );
  }
}

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key, this.autofocus = false});
  final bool autofocus;
  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final _q = TextEditingController();
  String _filter = 'all';
  String? _open;

  static const _filters = [('all', 'All'), ('link', 'Links'), ('reminder', 'Reminders'), ('todo', 'To-dos')];

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  bool _pass(Item it) {
    if (it.extra['msg'] == true) return false; // chat messages live in their folder
    final f = switch (_filter) {
      'link' => it.kind == ItemKind.link && it.url.isNotEmpty,
      'reminder' => it.whenTs > 0 && it.kind != ItemKind.todoList,
      'todo' => it.kind == ItemKind.todoList,
      _ => true,
    };
    if (!f) return false;
    final q = _q.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '${it.title} ${it.domain} ${it.folder} ${it.note}'.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: s.store,
      builder: (context, _) {
        final st = s.store;
        final list = st.items.where(_pass).toList();
        final open = list.where((i) => !i.isDone).toList()
          ..sort((a, b) {
            // Due items first (soonest), then newest saves.
            if ((a.whenTs > 0) != (b.whenTs > 0)) return a.whenTs > 0 ? -1 : 1;
            if (a.whenTs > 0) return a.whenTs.compareTo(b.whenTs);
            return b.savedAt.compareTo(a.savedAt);
          });
        final done = list.where((i) => i.isDone).toList()..sort((a, b) => b.completedAt.compareTo(a.completedAt));
        final bottom = MediaQuery.paddingOf(context).bottom;
        Widget group(List<Item> its) => Card28(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              children: [
                for (var i = 0; i < its.length; i++)
                  ItemTile(
                    key: ValueKey(its[i].id),
                    item: its[i],
                    first: true,
                    open: _open == its[i].id,
                    onToggle: () => setState(() => _open = _open == its[i].id ? null : its[i].id),
                  ),
              ],
            );
        return ListView(
          padding: EdgeInsets.only(bottom: 130 + bottom),
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            const PageHead(title: 'Saved'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 16),
                LLInput(controller: _q, hint: 'Search', icon: 'search', height: 56, autofocus: widget.autofocus, onChanged: (_) => setState(() {})),
                SizedBox(
                  height: 60,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    padding: const EdgeInsets.only(top: 14, bottom: 4),
                    children: [
                      for (final f in _filters) ...[
                        LLChip(label: f.$2, on: _filter == f.$1, onTap: () {
                          s.buzz(0);
                          setState(() => _filter = f.$1);
                        }),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (open.isNotEmpty) group(open),
                if (done.isNotEmpty) ...[
                  Padding(padding: const EdgeInsets.fromLTRB(6, 18, 6, 10), child: Text('Done', style: t(13, FontWeight.w700, ll.ink3))),
                  group(done),
                ],
                if (list.isEmpty)
                  EmptyState(
                    title: _q.text.isNotEmpty ? 'No match for “${shortText(_q.text, 16)}”' : 'Nothing here yet',
                    body: _q.text.isNotEmpty ? 'Try a site name, like youtube.' : 'Tap + to add one.',
                    mascot: MascotView(stage: st.level.n, style: st.mascotStyle, outfit: st.outfitNow, staticMood: _q.text.isNotEmpty ? Mood.wow : Mood.sleep, live: false),
                  ),
              ]),
            ),
          ],
        );
      },
    );
  }
}
