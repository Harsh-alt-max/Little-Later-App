import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../screens/save_sheet.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'icons.dart';
import 'kit.dart';
import 'cover.dart';
import '../services/haptics.dart';

Future<void> openItemUrl(AppScope s, Item it) async {
  final u = Uri.tryParse(it.url);
  if (u == null || !u.hasScheme) return;
  final ok = await launchUrl(u, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok) s.toast.show('Couldn’t open ${it.domain}');
}

/// v7 .si row: icon, title, one-line meta; tap to expand quick actions.
class ItemTile extends StatefulWidget {
  const ItemTile({super.key, required this.item, required this.open, required this.onToggle, this.inFolder = false, this.first = false, this.by});
  final Item item;
  final bool open, inFolder, first;
  final VoidCallback onToggle;

  /// Who saved it (shared folders).
  final String? by;

  @override
  State<ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<ItemTile> with SingleTickerProviderStateMixin {
  late final AnimationController _gone = AnimationController(vsync: this, duration: const Duration(milliseconds: 400), value: 1);

  @override
  void dispose() {
    _gone.dispose();
    super.dispose();
  }

  Future<void> _act(String a) async {
    if (a == 'del') {
      await _gone.animateTo(0, curve: Motion.smooth);
      if (!mounted) return;
    }
    await itemAction(
      context,
      widget.item,
      a,
      onUndoDelete: () {
        if (mounted) _gone.value = 1;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final it = widget.item;
    final done = it.isDone;
    final now = AppStore.now().millisecondsSinceEpoch;
    final due = it.whenTs > 0 ? DateTime.fromMillisecondsSinceEpoch(it.whenTs) : null;
    final overdue = due != null && it.whenTs <= now;
    String line;
    var blue = false;
    if (done) {
      line = 'Done';
    } else if (due != null) {
      line = overdue ? 'Due now' : fmtDue(due);
      blue = true;
    } else if (it.kind == ItemKind.todoList) {
      final n = it.tasks.length, d = it.tasks.where((t) => t.done).length;
      line = n == 0 ? 'To-do' : '$d of $n steps';
    } else {
      line = it.domain.isEmpty ? 'Reminder' : it.domain;
    }
    if (!done && it.repeats) line = '$line · ${repeatLabel(it.repeatDays)}';
    if (!widget.inFolder && it.folder.isNotEmpty) line = '$line · ${it.folder}';
    if (widget.by != null) line = '${widget.by} · $line';

    final Widget ic;
    if (it.kind == ItemKind.todoList) {
      ic = _fv(ll, LLIcon('check', size: 19, color: ll.blueInk), ll.blueSoft);
    } else if (it.url.isEmpty) {
      ic = _fv(ll, LLIcon('bell', size: 19, color: ll.blueInk), ll.blueSoft);
    } else {
      ic = Cover(url: it.thumbnail, letter: it.domain, width: 42, height: 42, radius: 14);
    }

    final actions = <Widget>[
      if (it.url.isNotEmpty) _qa(ll, 'arrow', 'Open', () => _act('open'), pri: true),
      if (!done) _qa(ll, 'check', 'Done', () => _act('done')) else _qa(ll, 'back', 'Not done', () => _act('undone')),
      _qa(ll, 'clock', 'Remind', () => _act('remind')),
      if (it.kind != ItemKind.link && it.whenTs > 0) _qa(ll, 'repeat', it.repeats ? repeatLabel(it.repeatDays) : 'Repeat', () => _act('repeat')),
      if (!widget.inFolder) _qa(ll, 'folder', 'Move', () => _act('move')),
      _qa(ll, 'trash', '', () => _act('del'), del: true),
    ];

    return SizeTransition(
      sizeFactor: _gone,
      child: FadeTransition(
        opacity: _gone,
        child: Container(
          decoration: BoxDecoration(
            border: widget.first ? null : Border(top: BorderSide(color: ll.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  s.buzz(0);
                  widget.onToggle();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    children: [
                      ic,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t(15, FontWeight.w700, done ? ll.ink3 : ll.ink).copyWith(decoration: done ? TextDecoration.lineThrough : null, decorationColor: ll.ink3),
                            ),
                            const SizedBox(height: 2),
                            Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(12.5, FontWeight.w600, blue && !done ? ll.blueInk : ll.ink3)),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: widget.open ? .25 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: LLIcon('chev', size: 16, color: ll.ink3),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 400),
                curve: Motion.smooth,
                alignment: Alignment.topCenter,
                child: !widget.open
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(54, 0, 0, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (it.note.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(it.note, style: t(13.5, FontWeight.w500, ll.ink2, h: 1.4)),
                              ),
                            if (it.kind == ItemKind.todoList) ...[
                              for (final tk in it.tasks)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    Haptics.tick();
                                    s.store.toggleTask(it.id, tk.id);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 250),
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: tk.done ? ll.blue : Colors.transparent,
                                            border: Border.all(color: tk.done ? ll.blue : ll.inkMix(.25), width: 1.6),
                                          ),
                                          child: tk.done ? const Center(child: LLIcon('check', size: 12, color: Colors.white, stroke: 3)) : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(tk.text, style: t(14, FontWeight.w600, tk.done ? ll.ink3 : ll.ink).copyWith(decoration: tk.done ? TextDecoration.lineThrough : null)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              _AddStep(onAdd: (v) => s.store.addTask(it.id, v)),
                              const SizedBox(height: 10),
                            ],
                            Wrap(spacing: 8, runSpacing: 8, children: actions),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fv(LL ll, Widget child, Color bg) => Container(
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
    child: child,
  );

  Widget _qa(LL ll, String icon, String label, VoidCallback onTap, {bool pri = false, bool del = false}) {
    final fg = pri
        ? Colors.white
        : del
        ? (ll.dark ? LL.danger : const Color(0xFFD0453F))
        : ll.ink2;
    return Tap(
      scale: .92,
      onTap: onTap,
      semanticLabel: label.isEmpty ? 'Delete' : null,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(color: pri ? ll.blue : ll.surface2, borderRadius: BorderRadius.circular(99)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LLIcon(icon, size: 15, color: fg),
            if (label.isNotEmpty) ...[const SizedBox(width: 6), Text(label, style: t(13, FontWeight.w700, fg))],
          ],
        ),
      ),
    );
  }
}

class _AddStep extends StatefulWidget {
  const _AddStep({required this.onAdd});
  final ValueChanged<String> onAdd;
  @override
  State<_AddStep> createState() => _AddStepState();
}

class _AddStepState extends State<_AddStep> {
  final c = TextEditingController();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Row(
      children: [
        LLIcon('plus', size: 16, color: ll.ink3),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: c,
            maxLength: 60,
            onSubmitted: (v) {
              widget.onAdd(v);
              c.clear();
            },
            style: t(14, FontWeight.w600, ll.ink),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              counterText: '',
              hintText: 'Add a step',
              hintStyle: t(14, FontWeight.w600, ll.ink3),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}

/// Mascot empty state (.empty).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.body, required this.mascot});
  final String title, body;
  final Widget mascot;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
      child: Column(
        children: [
          SizedBox(width: 110, height: 120, child: mascot),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: t(18, FontWeight.w800, ll.ink)),
          const SizedBox(height: 2),
          Text(body, textAlign: TextAlign.center, style: t(14.5, FontWeight.w500, ll.ink2, h: 1.5)),
        ],
      ),
    );
  }
}

/// Shared item actions (list rows, cards, chat bubbles).
Future<void> itemAction(BuildContext context, Item it, String a, {VoidCallback? onUndoDelete}) async {
  final s = AppScope.of(context);
  final st = s.store;
  s.buzz(0);
  switch (a) {
    case 'open':
      await openItemUrl(s, it);
    case 'done':
      st.complete(it.id);
      s.app.gain(15);
      s.toast.show('“${shortText(it.title)}” done, +15 stars');
    case 'undone':
      it.completedAt = 0;
      st.touchItem(it);
    case 'remind':
      final d = await pickLater(context);
      if (d == null) return;
      st.setWhen(it.id, d);
      s.app.reminders.askPermission();
      s.toast.show('Reminder set, ${dayLow(d)} ${fmtT(d)}');
    case 'move':
      final f = await showLLSheet<String>(
        context,
        builder: (ctx) {
          final ll = LL.of(ctx);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle('Move to'),
              for (final f in st.folders)
                SetRow(
                  icon: f.iconKey,
                  title: f.name,
                  trailing: f.name.toLowerCase() == it.folder.toLowerCase() ? Text('Current', style: t(13, FontWeight.w700, ll.blueInk)) : null,
                  onTap: () => Navigator.pop(ctx, f.name),
                ),
            ],
          );
        },
      );
      if (f == null) return;
      st.moveItem(it.id, f);
      s.toast.show(f.isEmpty ? 'Taken out of the folder' : 'Moved to $f');
    case 'del':
      final undo = st.deleteItem(it.id);
      s.toast.show(
        'Deleted “${shortText(it.title)}”',
        undo: () {
          undo();
          onUndoDelete?.call();
        },
      );
  }
}

/// Bottom sheet with every action for an item.
Future<void> showItemActions(BuildContext context, Item it, {bool inFolder = false}) async {
  final a = await showLLSheet<String>(
    context,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(shortText(it.title, 40)),
        if (it.url.isNotEmpty) SetRow(icon: 'arrow', title: 'Open', onTap: () => Navigator.pop(ctx, 'open')),
        if (!it.isDone) SetRow(icon: 'check', title: 'Mark done', onTap: () => Navigator.pop(ctx, 'done')) else SetRow(icon: 'back', title: 'Not done', onTap: () => Navigator.pop(ctx, 'undone')),
        SetRow(icon: 'clock', title: it.whenTs > 0 ? 'Change reminder' : 'Remind me', onTap: () => Navigator.pop(ctx, 'remind')),
        if (it.kind != ItemKind.link && it.whenTs > 0) SetRow(icon: 'repeat', title: 'Repeat', sub: repeatLabel(it.repeatDays), onTap: () => Navigator.pop(ctx, 'repeat')),
        if (!inFolder) SetRow(icon: 'folder', title: 'Move to folder', onTap: () => Navigator.pop(ctx, 'move')),
        SetRow(icon: 'trash', title: 'Delete', danger: true, onTap: () => Navigator.pop(ctx, 'del')),
      ],
    ),
  );
  if (a != null && context.mounted) await itemAction(context, it, a);
}

enum ViewMode { list, grid, large }

/// Cycles list → grid → large.
class ViewToggle extends StatelessWidget {
  const ViewToggle({super.key, required this.mode, required this.onChanged});
  final ViewMode mode;
  final ValueChanged<ViewMode> onChanged;
  @override
  Widget build(BuildContext context) {
    final next = ViewMode.values[(mode.index + 1) % 3];
    return Circ(
      icon: const {ViewMode.list: 'vlist', ViewMode.grid: 'vgrid', ViewMode.large: 'vlarge'}[mode]!,
      size: 44,
      iconSize: 20,
      label: 'View: ${mode.name}. Tap for ${next.name}',
      onTap: () => onChanged(next),
    );
  }
}

/// Grid / large card with a cover image. Tap opens the link; ⋯ for actions.
class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item, this.large = false, this.inFolder = false, this.by});
  final Item item;
  final bool large, inFolder;
  final String? by;

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final it = item;
    final due = it.whenTs > 0 && !it.isDone ? DateTime.fromMillisecondsSinceEpoch(it.whenTs) : null;
    var meta = it.isDone
        ? 'Done'
        : due != null
        ? fmtDue(due)
        : (it.domain.isNotEmpty
              ? it.domain
              : it.kind == ItemKind.todoList
              ? 'To-do'
              : 'Reminder');
    if (!it.isDone && it.repeats) meta = '$meta · ${repeatLabel(it.repeatDays)}';
    if (!inFolder && it.folder.isNotEmpty) meta = '$meta · ${it.folder}';
    if (by != null) meta = '$by · $meta';
    final dots = GestureDetector(
      onTap: () => showItemActions(context, it, inFolder: inFolder),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: it.url.isNotEmpty ? Colors.black.withValues(alpha: .45) : ll.surface2),
        child: LLIcon('dots', size: 18, color: it.url.isNotEmpty ? Colors.white : ll.ink2),
      ),
    );
    final titleStyle = t(large ? 16 : 14, FontWeight.w800, it.isDone ? ll.ink3 : ll.ink, h: 1.3);
    final metaText = Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis, style: t(12, FontWeight.w600, due != null ? ll.blueInk : ll.ink3));

    // To-dos and reminders: no picture, the content is the card. Steps can be ticked right here.
    if (it.url.isEmpty) {
      final steps = it.tasks;
      final shown = large ? steps : steps.take(4).toList();
      return Tap(
        scale: .98,
        onTap: () => showItemActions(context, it, inFolder: inFolder),
        child: Container(
          decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(large ? 26 : 22)),
          padding: EdgeInsets.fromLTRB(12, 12, 10, large ? 14 : 12),
          child: Opacity(
            opacity: it.isDone ? .55 : 1,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: ll.blueSoft, borderRadius: BorderRadius.circular(11)),
                  child: LLIcon(it.kind == ItemKind.todoList ? 'check' : (it.repeats ? 'repeat' : 'bell'), size: 17, color: ll.blueInk),
                ),
                const Spacer(),
                dots,
              ]),
              const SizedBox(height: 10),
              Text(it.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: titleStyle),
              const SizedBox(height: 3),
              metaText,
              if (shown.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final tk in shown)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      s.buzz(0);
                      s.store.toggleTask(it.id, tk.id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(top: 1),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tk.done ? ll.blue : Colors.transparent,
                            border: Border.all(color: tk.done ? ll.blue : ll.ink3, width: 1.6),
                          ),
                          child: tk.done ? const LLIcon('check', size: 12, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tk.text,
                            maxLines: large ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: t(13, FontWeight.w600, tk.done ? ll.ink3 : ll.ink2, h: 1.35).copyWith(decoration: tk.done ? TextDecoration.lineThrough : null),
                          ),
                        ),
                      ]),
                    ),
                  ),
                if (shown.length < steps.length) Padding(padding: const EdgeInsets.only(top: 2), child: Text('+${steps.length - shown.length} more', style: t(12, FontWeight.w700, ll.ink3))),
              ],
            ]),
          ),
        ),
      );
    }

    return Tap(
      scale: .97,
      onTap: () => openItemUrl(s, it),
      child: Container(
        decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(large ? 26 : 22)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                Opacity(opacity: it.isDone ? .45 : 1, child: Cover(url: it.thumbnail, letter: it.domain, aspect: large ? 16 / 9 : 4 / 3, radius: 0)),
                Positioned(right: 8, top: 8, child: dots),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, large ? 14 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle),
                  const SizedBox(height: 3),
                  metaText,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lays out items as cards in 2 columns (grid) or 1 column (large).
class ItemCards extends StatelessWidget {
  const ItemCards({super.key, required this.items, required this.large, this.inFolder = false, this.by});
  final List<Item> items;
  final bool large, inFolder;
  final String? Function(Item)? by;
  @override
  Widget build(BuildContext context) {
    if (large) {
      return Column(
        children: [
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ItemCard(key: ValueKey(it.id), item: it, large: true, inFolder: inFolder, by: by?.call(it)),
            ),
        ],
      );
    }
    final left = <Widget>[], right = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      (i.isEven ? left : right).add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ItemCard(key: ValueKey(items[i].id), item: items[i], inFolder: inFolder, by: by?.call(items[i])),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: left)),
        const SizedBox(width: 12),
        Expanded(child: Column(children: right)),
      ],
    );
  }
}
