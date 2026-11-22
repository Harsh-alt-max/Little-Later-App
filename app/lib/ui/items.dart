// Rows and cards for saved things, plus the detail sheet.
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../screens/save_sheet.dart' show pickRepeat, shareText;
import '../services/haptics.dart';
import '../theme/tokens.dart';
import 'kit.dart';

Future<void> openUrl(AppScope s, Item it) async {
  final u = Uri.tryParse(it.url);
  if (u == null || !u.hasScheme) return;
  final ok = await launchUrl(u, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok) s.toast.show('Couldn’t open ${it.domain}');
}

String metaOf(Item it, {bool inFolder = false, bool by = false}) {
  final bits = <String>[
    if (by && byOf(it).isNotEmpty) byOf(it),
    if (it.whenTs > 0) whenLabel(it) else if (it.domain.isNotEmpty) it.domain,
    if (it.repeats) repeatLabel(it.repeatDays),
    if (!inFolder && it.folder.isNotEmpty) it.folder,
  ];
  return bits.join(' · ');
}

void markDone(AppScope s, Item it, {BuildContext? from}) {
  if (from != null) sparksAt(from, n: 12);
  Haptics.medium();
  final undo = s.store.complete(it.id);
  s.app.gain(15);
  s.toast.show(it.repeats ? 'Done · back ${fmtDay(DateTime.fromMillisecondsSinceEpoch(it.whenTs)).toLowerCase()}' : '“${shortText(it.title, 22)}” done', undo: undo);
}

void markLater(AppScope s, Item it) {
  Haptics.light();
  final undo = s.store.snoozeToTomorrow(it.id);
  final d = DateTime.fromMillisecondsSinceEpoch(it.whenTs);
  s.toast.show('Moved to tomorrow, ${fmtT(d)}', undo: undo);
}

class StepsList extends StatelessWidget {
  const StepsList({super.key, required this.item, this.max = 99, this.size = 15});
  final Item item;
  final int max;
  final double size;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final tasks = item.tasks.take(max).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final tk in tasks)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Haptics.tick();
            s.store.toggleTask(item.id, tk.id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(shape: BoxShape.circle, color: tk.done ? ll.blue : Colors.transparent, border: Border.all(color: tk.done ? ll.blue : ll.ink3, width: 1.5)),
                alignment: Alignment.center,
                child: tk.done ? LLIcon('check', size: 12, color: ll.onAccent, stroke: 3) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(tk.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t(size, FontWeight.w400, tk.done ? ll.ink3 : ll.ink).copyWith(decoration: tk.done ? TextDecoration.lineThrough : null, decorationColor: ll.ink3)),
              ),
            ]),
          ),
        ),
      if (item.tasks.length > max) Padding(padding: const EdgeInsets.only(top: 2), child: Text('+${item.tasks.length - max} more', style: t(13, FontWeight.w400, ll.ink2))),
    ]);
  }
}

/// List row.
class ItemRow extends StatelessWidget {
  const ItemRow({super.key, required this.item, this.inFolder = false, this.by = false});
  final Item item;
  final bool inFolder, by;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final hasImg = item.thumbnail.isNotEmpty;
    final due = isDueToday(item) && !item.isDone;
    return Tap(
      scale: .98,
      onTap: () => openDetail(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(crossAxisAlignment: item.tasks.isNotEmpty ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
          hasImg || item.kind == ItemKind.link ? Cover2(item: item, width: 52, height: 52, radius: 14) : IconTile(item.kind == ItemKind.todoList ? 'todo' : item.repeats ? 'repeat' : 'bell', size: 48, radius: 15),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t(15, FontWeight.w600, item.isDone ? ll.ink3 : ll.ink, h: 1.3)),
              const SizedBox(height: 3),
              Mono(metaOf(item, inFolder: inFolder, by: by), color: due ? ll.blueInk : ll.ink2),
              if (item.tasks.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: StepsList(item: item, max: 4)),
            ]),
          ),
          const SizedBox(width: 6),
          Opacity(opacity: .5, child: LLIcon('dots', size: 18, color: ll.ink)),
        ]),
      ),
    );
  }
}

/// Grid card (2 columns).
class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item, this.inFolder = false, this.by = false, this.large = false});
  final Item item;
  final bool inFolder, by, large;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final hasImg = item.thumbnail.isNotEmpty;
    final due = isDueToday(item) && !item.isDone;
    return Tap(
      scale: .97,
      onTap: () => item.kind == ItemKind.link ? openUrl(s, item) : openDetail(context, item),
      child: Surface(
        radius: 24,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (hasImg || item.kind == ItemKind.link)
            Stack(children: [
              Cover2(item: item, height: large ? 200 : 130, radius: 0),
              Positioned(
                top: 8,
                right: 8,
                child: Tap(
                  onTap: () => openDetail(context, item),
                  child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.black.withValues(alpha: .35), shape: BoxShape.circle), child: const Center(child: LLIcon('dots', size: 16, color: Colors.white))),
                ),
              ),
            ])
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 0),
              child: Row(children: [
                IconTile(item.kind == ItemKind.todoList ? 'todo' : 'bell', size: 40, radius: 12),
                const Spacer(),
                Tap(onTap: () => openDetail(context, item), child: Padding(padding: const EdgeInsets.all(6), child: Opacity(opacity: .5, child: LLIcon('dots', size: 18, color: ll.ink)))),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, maxLines: large ? 3 : 2, overflow: TextOverflow.ellipsis, style: t(large ? 17 : 15, FontWeight.w600, ll.ink, h: 1.3)),
              const SizedBox(height: 4),
              Mono(metaOf(item, inFolder: inFolder, by: by), color: due ? ll.blueInk : ll.ink2),
              if (item.tasks.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: StepsList(item: item, max: large ? 8 : 3, size: 13)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// List / grid / large view of items.
class ItemsView extends StatelessWidget {
  const ItemsView({super.key, required this.items, required this.view, this.inFolder = false, this.by = false, this.empty});
  final List<Item> items;
  final String view;
  final bool inFolder, by;
  final Widget? empty;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    if (items.isEmpty) return empty ?? const SizedBox.shrink();
    if (view == 'grid') {
      final a = <Item>[], b = <Item>[];
      for (var i = 0; i < items.length; i++) {
        (i.isEven ? a : b).add(items[i]);
      }
      Widget col(List<Item> l) => Column(children: [for (final it in l) Padding(padding: const EdgeInsets.only(bottom: 10), child: ItemCard(key: ValueKey(it.id), item: it, inFolder: inFolder, by: by))]);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: col(a)), const SizedBox(width: 10), Expanded(child: col(b))]),
      );
    }
    if (view == 'large') {
      return Column(children: [for (final it in items) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: ItemCard(key: ValueKey(it.id), item: it, inFolder: inFolder, by: by, large: true))]);
    }
    return Surface(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, indent: 78, color: ll.line),
          ItemRow(key: ValueKey(items[i].id), item: items[i], inFolder: inFolder, by: by),
        ],
      ]),
    );
  }
}

// =============================================================================
// Detail sheet: Done / Edit / Share / Delete, When / Repeat / Folder.

Future<void> openDetail(BuildContext context, Item it) => showLLSheet(context, (_) => _Detail(id: it.id));

class _Detail extends StatefulWidget {
  const _Detail({required this.id});
  final String id;
  @override
  State<_Detail> createState() => _DetailState();
}

class _DetailState extends State<_Detail> {
  bool _edit = false;
  late final TextEditingController _t;

  @override
  void initState() {
    super.initState();
    _t = TextEditingController();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final st = s.store;
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final it = st.byId(widget.id);
        if (it == null) return const SizedBox(height: 80);
        final link = it.kind == ItemKind.link;
        Widget act(String icon, String label, VoidCallback onTap, {bool danger = false}) => Expanded(
              child: Tap(
                onTap: onTap,
                child: Column(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: ll.chip),
                    alignment: Alignment.center,
                    child: LLIcon(icon, size: 20, color: danger ? const Color(0xFFE5484D) : ll.ink),
                  ),
                  const SizedBox(height: 6),
                  Text(label, style: t(13, FontWeight.w500, ll.ink2)),
                ]),
              ),
            );
        Widget row(String icon, String label, String value, VoidCallback onTap) => SetRow(icon: icon, title: label, trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text(value, style: t(13, FontWeight.w500, ll.ink2)), const SizedBox(width: 4), Opacity(opacity: .4, child: LLIcon('chev', size: 16, color: ll.ink))]), onTap: onTap);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (it.thumbnail.isNotEmpty || link) ...[Cover2(item: it, width: 64, height: 64, radius: 16), const SizedBox(width: 14)],
            Expanded(
              child: _edit
                  ? TextField(
                      controller: _t,
                      autofocus: true,
                      maxLines: 3,
                      minLines: 1,
                      style: t(20, FontWeight.w600, ll.ink),
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) {
                          it.title = v.trim();
                          st.touchItem(it);
                        }
                        setState(() => _edit = false);
                      },
                      decoration: const InputDecoration.collapsed(hintText: 'Title'),
                    )
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(it.title, style: t(20, FontWeight.w600, ll.ink, h: 1.3)),
                      const SizedBox(height: 4),
                      Mono(metaOf(it, by: true)),
                    ]),
            ),
            RoundBtn(icon: 'x', size: 36, iconSize: 16, onTap: () => Navigator.of(context).maybePop()),
          ]),
          if (it.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(it.note, style: t(15, FontWeight.w400, ll.ink2, h: 1.45))),
          if (it.tasks.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: StepsList(item: it)),
          const SizedBox(height: 18),
          Row(children: [
            act(it.isDone ? 'back' : 'check', it.isDone ? 'Not done' : 'Done', () {
              Navigator.of(context).pop();
              if (it.isDone) {
                it.completedAt = 0;
                st.touchItem(it);
              } else {
                markDone(s, it);
              }
            }),
            if (link) act('ext', 'Open', () => openUrl(s, it)),
            act('edit', 'Edit', () => setState(() {
              _t.text = it.title;
              _edit = true;
            })),
            act('share', 'Share', () async {
              final txt = link ? '${it.title}\n${it.url}' : it.title;
              await Clipboard.setData(ClipboardData(text: txt));
              try {
                await shareText(txt);
              } catch (_) {}
            }),
            act('trash', 'Delete', () {
              Navigator.of(context).pop();
              final undo = st.deleteItem(it.id);
              s.toast.show('Deleted', undo: undo);
            }, danger: true),
          ]),
          const SizedBox(height: 14),
          Group(margin: EdgeInsets.zero, children: [
            row('clock', 'When', it.whenTs > 0 ? whenLabel(it) : 'No time', () async {
              final d = await pickDateTime(context, initial: it.whenTs > 0 ? DateTime.fromMillisecondsSinceEpoch(it.whenTs) : null);
              if (d != null) st.setWhen(it.id, d);
            }),
            if (!link)
              row('repeat', 'Repeat', repeatLabel(it.repeatDays), () async {
                final d = await pickRepeat(context, it.repeatDays);
                if (d != null) st.setRepeat(it.id, d);
              }),
            row('folder', 'Folder', it.folder.isEmpty ? 'None' : it.folder, () => _moveSheet(context, it)),
          ]),
        ]);
      },
    );
  }

  void _moveSheet(BuildContext context, Item it) {
    final st = AppScope.of(context).store;
    showLLSheet(
      context,
      (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SheetHead('Move to folder'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (it.kind != ItemKind.link)
            PillChip(label: 'No folder', on: it.folder.isEmpty, onTap: () {
              st.moveItem(it.id, '');
              Navigator.of(ctx).pop();
            }),
          for (final f in st.folders)
            PillChip(label: f.name, icon: f.collab ? 'users' : null, on: f.name == it.folder, onTap: () {
              st.moveItem(it.id, f.name);
              Navigator.of(ctx).pop();
            }),
        ]),
      ]),
    );
  }
}
