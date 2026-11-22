// Saved: everything you kept. Search, filter (All / Links / To-dos / Images),
// and three views. Group reminders and to-dos stay inside their groups.
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../mascot/mascot_svg.dart';
import '../theme/tokens.dart';
import '../widgets/eyes_refresh.dart';
import 'items.dart';
import 'kit.dart';

class SavedView extends StatefulWidget {
  const SavedView({super.key, this.autofocus = false});
  final bool autofocus;
  @override
  State<SavedView> createState() => _SavedViewState();
}

class _SavedViewState extends State<SavedView> {
  final _q = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final st = s.store;
    final top = MediaQuery.paddingOf(context).top;
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final q = _q.text.trim().toLowerCase();
        final items = st.items.where((i) {
          if (i.isDone || i.extra['msg'] == true) return false;
          if (groupOf(st, i) != null && i.kind != ItemKind.link) return false;
          final ok = switch (_filter) {
            'links' => i.kind == ItemKind.link,
            'todos' => i.kind != ItemKind.link,
            'images' => i.extra['photo'] == true,
            _ => true,
          };
          if (!ok) return false;
          return q.isEmpty || i.title.toLowerCase().contains(q) || i.folder.toLowerCase().contains(q) || i.domain.contains(q) || i.note.toLowerCase().contains(q);
        }).toList();
        Widget vb(String v, String icon) => Tap(
              onTap: () => st.setPrefs(view: v),
              child: Container(
                width: 36,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: st.viewMode == v ? (ll.dark ? ll.surface : Colors.white) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                child: Opacity(opacity: st.viewMode == v ? 1 : .5, child: LLIcon(icon, size: 17, color: ll.ink)),
              ),
            );
        return EyesRefresh(
          onRefresh: s.app.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(0, top + 18, 0, 150),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(children: [
                  Expanded(child: Text('Saved', style: t(34, FontWeight.w600, ll.ink, ls: -.03))),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(13)),
                    child: Row(children: [vb('list', 'vlist'), vb('grid', 'vgrid'), vb('large', 'vlarge')]),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: ll.dark ? ll.surface : Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    Opacity(opacity: .5, child: LLIcon('search', size: 18, color: ll.ink)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _q,
                        autofocus: widget.autofocus,
                        onChanged: (_) => setState(() {}),
                        style: t(15, FontWeight.w500, ll.ink),
                        decoration: InputDecoration.collapsed(hintText: 'Search', hintStyle: t(15, FontWeight.w500, ll.ink3)),
                      ),
                    ),
                    if (_q.text.isNotEmpty) Tap(onTap: () => setState(_q.clear), child: Opacity(opacity: .5, child: LLIcon('x', size: 16, color: ll.ink))),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: SegTabs(options: const [('all', 'All'), ('links', 'Links'), ('todos', 'To-dos'), ('images', 'Images')], value: _filter, onChanged: (v) => setState(() => _filter = v)),
              ),
              ItemsView(
                items: items,
                view: st.viewMode,
                empty: Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Column(children: [
                    const Lil(size: 100, mood: Mood.sleep),
                    const SizedBox(height: 8),
                    Text(q.isNotEmpty ? 'Nothing matches “${_q.text}”.' : _filter == 'images' ? 'Add a photo to a reminder or to-do and it shows here.' : 'Nothing here yet.', textAlign: TextAlign.center, style: t(15, FontWeight.w400, ll.ink2)),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
