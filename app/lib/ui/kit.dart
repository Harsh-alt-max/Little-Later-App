// Building blocks of the Midnight / Daylight design.
import 'dart:async';
import 'dart:io';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../mascot/mascot_svg.dart';
import '../mascot/mascot_view.dart';
import '../services/haptics.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';

export '../widgets/common.dart' show Tap, AppScope, fmtT, fmtDay, shortText, spawnSparks;
export '../widgets/icons.dart' show LLIcon;

/// Lil, wearing the chosen outfit.
class Lil extends StatelessWidget {
  const Lil({super.key, this.size = 120, this.mood = Mood.idle, this.controller, this.outfit, this.live = true});
  final double size;
  final Mood mood;
  final MascotController? controller;
  final int? outfit;
  final bool live;
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context).store;
    return SizedBox(
      width: size,
      height: size,
      child: MascotView(stage: 3, controller: controller, outfit: outfit ?? st.outfitNow, staticMood: mood, live: live),
    );
  }
}

class MarkLogo extends StatelessWidget {
  const MarkLogo({super.key, this.size = 34});
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.string(markSvg(), width: size, height: size);
}

/// Card surface. In Daylight a hairline keeps white cards visible on paper.
class Surface extends StatelessWidget {
  const Surface({super.key, required this.child, this.padding = EdgeInsets.zero, this.radius = 24, this.color, this.margin = EdgeInsets.zero});
  final Widget child;
  final EdgeInsetsGeometry padding, margin;
  final double radius;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? ll.surface,
        borderRadius: BorderRadius.circular(radius),
        border: ll.dark ? null : Border.all(color: const Color(0x0D17130F)),
      ),
      child: child,
    );
  }
}

class Mono extends StatelessWidget {
  const Mono(this.text, {super.key, this.color, this.size = 11});
  final String text;
  final Color? color;
  final double size;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: mono(color ?? LL.of(context).ink2, size: size), maxLines: 1, overflow: TextOverflow.ellipsis);
}

/// Peach primary button.
class AccentBtn extends StatelessWidget {
  const AccentBtn({super.key, required this.label, this.onTap, this.icon, this.height = 52, this.enabled = true, this.progress});
  final String label;
  final VoidCallback? onTap;
  final String? icon;
  final double height;
  final bool enabled;

  /// 0..1 fill shown over the button (auto-add countdown).
  final Animation<double>? progress;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    Widget body = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (icon != null) ...[LLIcon(icon!, size: 18, color: ll.onAccent, stroke: 2.2), const SizedBox(width: 8)],
      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(15, FontWeight.w600, ll.onAccent))),
    ]);
    if (progress != null) {
      body = Stack(fit: StackFit.expand, children: [
        AnimatedBuilder(
          animation: progress!,
          builder: (_, _) => FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: progress!.value, child: Container(color: Colors.white.withValues(alpha: .35))),
        ),
        Center(child: body),
      ]);
    }
    return Opacity(
      opacity: enabled ? 1 : .4,
      child: Tap(
        onTap: enabled ? onTap : null,
        child: Container(
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: ll.blue, borderRadius: BorderRadius.circular(99)),
          child: body,
        ),
      ),
    );
  }
}

/// Ink pill (Done).
class InkBtn extends StatelessWidget {
  const InkBtn({super.key, required this.label, this.onTap, this.icon = 'check', this.height = 52, this.trailing});
  final String label;
  final VoidCallback? onTap;
  final String? icon;
  final double height;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Tap(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(color: ll.ink, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[LLIcon(icon!, size: 18, color: ll.onInk, stroke: 2.2), const SizedBox(width: 8)],
          Text(label, style: t(15, FontWeight.w600, ll.onInk)),
          ?trailing,
        ]),
      ),
    );
  }
}

class GhostBtn extends StatelessWidget {
  const GhostBtn({super.key, required this.label, this.onTap, this.height = 52, this.icon});
  final String label;
  final VoidCallback? onTap;
  final double height;
  final String? icon;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Tap(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[LLIcon(icon!, size: 17, color: ll.ink), const SizedBox(width: 6)],
          Text(label, style: t(15, FontWeight.w500, ll.ink)),
        ]),
      ),
    );
  }
}

/// Round neutral button with an ink icon.
class RoundBtn extends StatelessWidget {
  const RoundBtn({super.key, required this.icon, this.onTap, this.size = 46, this.iconSize = 20, this.label, this.dot = false, this.bg});
  final String icon;
  final VoidCallback? onTap;
  final double size, iconSize;
  final String? label;
  final bool dot;
  final Color? bg;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Tap(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: bg ?? (ll.dark ? ll.surface2 : ll.surface), border: ll.dark ? null : Border.all(color: const Color(0x0D17130F))),
        child: Stack(alignment: Alignment.center, children: [
          LLIcon(icon, size: iconSize, color: ll.ink),
          if (dot) Positioned(top: size * .2, right: size * .22, child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: ll.ember))),
        ]),
      ),
    );
  }
}

/// Neutral square tile holding an ink icon (never orange).
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 40, this.radius = 12});
  final String icon;
  final double size, radius;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(radius)),
      alignment: Alignment.center,
      child: Opacity(opacity: .75, child: LLIcon(icon, size: size * .45, color: ll.ink)),
    );
  }
}

class PillChip extends StatelessWidget {
  const PillChip({super.key, required this.label, this.on = false, this.onTap, this.icon, this.height = 38});
  final String label;
  final bool on;
  final VoidCallback? onTap;
  final String? icon;
  final double height;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final fg = on ? ll.onInk : ll.ink;
    return Tap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: on ? ll.ink : ll.chip, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[LLIcon(icon!, size: 15, color: fg), const SizedBox(width: 6)],
          Text(label, style: t(13, FontWeight.w500, fg)),
        ]),
      ),
    );
  }
}

/// Segmented control with a sliding knob.
class SegTabs extends StatelessWidget {
  const SegTabs({super.key, required this.options, required this.value, required this.onChanged, this.height = 40});
  final List<(String, String)> options; // (value, label)
  final String value;
  final ValueChanged<String> onChanged;
  final double height;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final i = options.indexWhere((o) => o.$1 == value).clamp(0, options.length - 1);
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: ll.chip, borderRadius: BorderRadius.circular(14)),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / options.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 340),
            curve: Motion.spring,
            left: w * i,
            top: 0,
            bottom: 0,
            width: w,
            child: Container(decoration: BoxDecoration(color: ll.dark ? ll.surface : Colors.white, borderRadius: BorderRadius.circular(10))),
          ),
          Row(children: [
            for (final o in options)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Haptics.tick();
                    onChanged(o.$1);
                  },
                  child: Center(child: Text(o.$2, maxLines: 1, style: t(13, o.$1 == value ? FontWeight.w600 : FontWeight.w500, o.$1 == value ? ll.ink : ll.ink2))),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}

class Toggle extends StatelessWidget {
  const Toggle({super.key, required this.on, this.onTap});
  final bool on;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 46,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: on ? ll.blue : ll.chip, borderRadius: BorderRadius.circular(99)),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          curve: Motion.spring,
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(width: 22, height: 22, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
        ),
      ),
    );
  }
}

/// Settings row: icon tile, title + subtitle, trailing.
class SetRow extends StatelessWidget {
  const SetRow({super.key, required this.icon, required this.title, this.sub, this.trailing, this.onTap, this.trailingText});
  final String icon, title;
  final String? sub, trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Tap(
      onTap: onTap,
      scale: .98,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          IconTile(icon, size: 38, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t(15, FontWeight.w500, ll.ink)),
              if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub!, style: t(13, FontWeight.w400, ll.ink2))),
            ]),
          ),
          if (trailingText != null) Mono(trailingText!),
          ?trailing,
        ]),
      ),
    );
  }
}

/// White/ink rounded group of rows.
class Group extends StatelessWidget {
  const Group({super.key, required this.children, this.margin = const EdgeInsets.fromLTRB(16, 12, 16, 0)});
  final List<Widget> children;
  final EdgeInsetsGeometry margin;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) out.add(Divider(height: 1, thickness: 1, indent: 64, color: ll.line));
      out.add(children[i]);
    }
    return Surface(margin: margin, padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: out));
  }
}

/// A bottom sheet in the app's style: inset, rounded, grab handle.
Future<T?> showLLSheet<T>(BuildContext context, Widget Function(BuildContext) builder, {bool scroll = true}) {
  final ll = LL.of(context);
  final scope = AppScope.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: ll.dark ? .5 : .28),
    elevation: 0,
    builder: (ctx) => AppScope(
      store: scope.store,
      toast: scope.toast,
      hero: scope.hero,
      heroKey: scope.heroKey,
      goTab: scope.goTab,
      levelUp: scope.levelUp,
      app: scope.app,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SheetFrame(scroll: scroll, child: Builder(builder: builder)),
      ),
    ),
  );
}

class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.child, this.scroll = true});
  final Widget child;
  final bool scroll;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final pad = MediaQuery.paddingOf(context).bottom;
    final body = Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 18), child: child);
    return Material(
      type: MaterialType.transparency,
      child: Container(
      margin: EdgeInsets.fromLTRB(8, 0, 8, 8 + pad),
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height - MediaQuery.viewInsetsOf(context).bottom - MediaQuery.paddingOf(context).top - 24),
      decoration: BoxDecoration(color: ll.dark ? const Color(0xFF121216) : const Color(0xFFFAF8F5), borderRadius: BorderRadius.circular(36)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(height: 24, alignment: Alignment.center, child: Container(width: 36, height: 5, decoration: BoxDecoration(color: ll.ink3, borderRadius: BorderRadius.circular(9)))),
        ),
        Flexible(child: scroll ? SingleChildScrollView(child: body) : body),
      ]),
    ),
    );
  }
}

class SheetHead extends StatelessWidget {
  const SheetHead(this.title, {super.key, this.sub, this.action, this.onAction});
  final String title;
  final String? sub, action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: t(22, FontWeight.w600, ll.ink, ls: -.02))),
          if (action != null) Tap(onTap: onAction, child: Padding(padding: const EdgeInsets.all(6), child: Mono(action!, color: ll.blueInk))),
        ]),
        if (sub != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub!, style: t(15, FontWeight.w400, ll.ink2, h: 1.4))),
      ]),
    );
  }
}

class SheetLabel extends StatelessWidget {
  const SheetLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(4, 18, 4, 10), child: Text(text, style: t(13, FontWeight.w600, LL.of(context).ink2)));
}

/// Sparks burst at a widget's centre.
void sparksAt(BuildContext context, {int n = 10}) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.attached) return;
  final at = box.localToGlobal(box.size.center(Offset.zero));
  spawnSparks(Overlay.of(context), at, n, LL.of(context).blue);
}

/// Cover image: network URL, data URI, or a soft placeholder with the domain.
class Cover2 extends StatelessWidget {
  const Cover2({super.key, required this.item, this.radius = 14, this.width, this.height});
  final Item item;
  final double radius;
  final double? width, height;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final url = item.thumbnail;
    Widget ph() => Container(
          color: ll.chip,
          alignment: Alignment.center,
          child: item.kind == ItemKind.link
              ? Text(item.domain.isEmpty ? '•' : item.domain[0].toUpperCase(), style: t(20, FontWeight.w600, ll.ink2))
              : Opacity(opacity: .7, child: LLIcon(item.kind == ItemKind.todoList ? 'todo' : 'bell', size: 20, color: ll.ink)),
        );
    Widget img;
    if (url.startsWith('http')) {
      img = Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => ph());
    } else if (url.startsWith('file://')) {
      img = Image.file(File(Uri.parse(url).toFilePath()), fit: BoxFit.cover, errorBuilder: (_, _, _) => ph());
    } else if (url.startsWith('data:image')) {
      try {
        img = Image.memory(UriData.parse(url).contentAsBytes(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ph());
      } catch (_) {
        img = ph();
      }
    } else {
      img = ph();
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: SizedBox(width: width, height: height, child: img));
  }
}

/// "Today, 7:30 pm" / "Tomorrow, 9:00 am" / "Mon 23, 10:00 am".
String whenLabel(Item it) {
  if (it.whenTs <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(it.whenTs);
  return '${fmtDay(d)}, ${fmtT(d)}';
}

bool isDueToday(Item it) {
  if (it.whenTs <= 0) return false;
  final n = AppStore.now();
  return it.whenTs < DateTime(n.year, n.month, n.day + 1).millisecondsSinceEpoch;
}

/// Group (shared folder) of an item, if any.
Folder? groupOf(AppStore st, Item it) {
  if (it.folder.isEmpty) return null;
  final f = st.folderNamed(it.folder);
  return (f != null && f.collab) ? f : null;
}

/// Who added it, for shared items.
String byOf(Item it) => '${it.extra['by'] ?? it.extra['byName'] ?? it.extra['senderName'] ?? ''}';

/// Re-run [fn] every [period] while mounted (live clocks).
class Ticker2 extends StatefulWidget {
  const Ticker2({super.key, required this.builder, this.period = const Duration(seconds: 30)});
  final WidgetBuilder builder;
  final Duration period;
  @override
  State<Ticker2> createState() => _Ticker2State();
}

class _Ticker2State extends State<Ticker2> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(widget.period, (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
