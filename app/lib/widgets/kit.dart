import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'common.dart';
import 'icons.dart';

/// v7 .gsheet: bottom sheet with grab handle, rounded 34px top.
Future<T?> showLLSheet<T>(BuildContext context, {required WidgetBuilder builder, bool full = false}) {
  final ll = LL.of(context);
  final scope = AppScope.of(context);
  scope.buzz(0);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .5),
    builder: (ctx) {
      final inset = MediaQuery.viewInsetsOf(ctx).bottom;
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * (full ? .94 : .88)),
          child: Container(
            decoration: BoxDecoration(color: ll.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(34))),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 22 + bottom),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Center(child: Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: ll.inkMix(.18), borderRadius: BorderRadius.circular(9)))),
                scope.wrap(Builder(builder: builder)),
              ]),
            ),
          ),
        ),
      );
    },
  );
}

/// .gs-t sheet title with an optional action on the right.
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.text, {super.key, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Expanded(child: Text(text, style: t(21, FontWeight.w800, ll.ink, ls: -.02))),
        if (action != null) Tap(onTap: onAction, child: Text(action!, style: t(13.5, FontWeight.w800, ll.blueInk))),
      ]),
    );
  }
}

/// .savebtn: big blue pill button.
class BigButton extends StatelessWidget {
  const BigButton({super.key, required this.label, this.onTap, this.enabled = true, this.xp, this.height = 60, this.icon, this.dark = false});
  final String label;
  final VoidCallback? onTap;
  final bool enabled, dark;
  final int? xp;
  final double height;
  final Widget? icon;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final bg = dark ? ll.ink : ll.blue;
    final fg = dark ? ll.onInk : Colors.white;
    return Tap(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : .4,
        duration: const Duration(milliseconds: 300),
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99), boxShadow: enabled && !dark ? ll.blueGlow(.35, 30, 14) : null),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[icon!, const SizedBox(width: 10)],
            Text(label, style: t(16.5, FontWeight.w800, fg)),
            if (xp != null) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star_rounded, size: 14, color: LL.gold),
                  const SizedBox(width: 3),
                  Text('+$xp', style: t(12.5, FontWeight.w800, Colors.white)),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// .inp: rounded input row with a leading icon.
class LLInput extends StatefulWidget {
  const LLInput({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.obscure = false,
    this.keyboard,
    this.maxLength,
    this.error = false,
    this.height = 60,
    this.focusNode,
    this.center = false,
    this.action = TextInputAction.done,
  });
  final TextEditingController controller;
  final String hint;
  final String? icon;
  final Widget? trailing;
  final ValueChanged<String>? onChanged, onSubmitted;
  final bool autofocus, obscure, error, center;
  final TextInputType? keyboard;
  final int? maxLength;
  final double height;
  final FocusNode? focusNode;
  final TextInputAction action;

  @override
  State<LLInput> createState() => _LLInputState();
}

class _LLInputState extends State<LLInput> {
  late final FocusNode _f = widget.focusNode ?? FocusNode();
  @override
  void initState() {
    super.initState();
    _f.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final focused = _f.hasFocus;
    final border = widget.error ? const Color(0xFFFF6B6B) : focused ? ll.blue : ll.line;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: widget.height,
      padding: EdgeInsets.fromLTRB(widget.icon == null ? 18 : 18, 0, 8, 0),
      decoration: BoxDecoration(
        color: focused ? ll.surface : ll.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: widget.error || focused ? 2 : 1.5),
      ),
      child: Row(children: [
        if (widget.icon != null) ...[LLIcon(widget.icon!, size: 20, color: ll.ink3), const SizedBox(width: 12)],
        Expanded(
          child: TextField(
            controller: widget.controller,
            focusNode: _f,
            autofocus: widget.autofocus,
            obscureText: widget.obscure,
            keyboardType: widget.keyboard,
            textInputAction: widget.action,
            maxLength: widget.maxLength,
            textAlign: widget.center ? TextAlign.center : TextAlign.start,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            style: t(16, FontWeight.w600, ll.ink),
            cursorColor: ll.blue,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              counterText: '',
              hintText: widget.hint,
              hintStyle: t(16, FontWeight.w500, ll.ink3),
            ),
          ),
        ),
        ?widget.trailing,
      ]),
    );
  }
}

/// .tg: iOS-style toggle.
class LLToggle extends StatelessWidget {
  const LLToggle({super.key, required this.on, required this.onChanged, this.label});
  final bool on;
  final ValueChanged<bool> onChanged;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Semantics(
      toggled: on,
      label: label,
      child: GestureDetector(
        onTap: () => onChanged(!on),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 52,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: on ? ll.blue : ll.inkMix(.16), borderRadius: BorderRadius.circular(99)),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 450),
            curve: Motion.spring,
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(width: 26, height: 26, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2))])),
          ),
        ),
      ),
    );
  }
}

/// .modes / .segs: segmented control with a sliding ink knob.
class Segmented extends StatelessWidget {
  const Segmented({super.key, required this.labels, required this.index, required this.onChanged, this.icons, this.height = 54});
  final List<String> labels;
  final List<String>? icons;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: ll.surface2, borderRadius: BorderRadius.circular(99)),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / labels.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Motion.spring,
            left: w * index,
            top: 0,
            bottom: 0,
            width: w,
            child: Container(decoration: BoxDecoration(color: ll.ink, borderRadius: BorderRadius.circular(99))),
          ),
          Row(children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: Center(
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: i == index ? ll.onInk : ll.ink3),
                      duration: const Duration(milliseconds: 300),
                      builder: (_, col, _) => Row(mainAxisSize: MainAxisSize.min, children: [
                        if (icons != null) ...[LLIcon(icons![i], size: 18, color: col), const SizedBox(width: 7)],
                        Text(labels[i], style: t(14.5, FontWeight.w800, col!)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}

/// .lab: small section label with an optional blue hint on the right.
class Lab extends StatelessWidget {
  const Lab(this.text, {super.key, this.hint = '', this.top = 22});
  final String text, hint;
  final double top;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(2, top, 2, 11),
      child: Row(children: [
        Text(text, style: t(14, FontWeight.w800, ll.ink)),
        const Spacer(),
        Text(hint, style: t(12.5, FontWeight.w700, ll.blueInk)),
      ]),
    );
  }
}

/// Rounded white card group (.setg / .slist / .list).
class Card28 extends StatelessWidget {
  const Card28({super.key, required this.children, this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 2)});
  final List<Widget> children;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(28), boxShadow: ll.shadow),
      child: Column(children: [
        for (var i = 0; i < children.length; i++)
          Container(decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: ll.line))), child: children[i]),
      ]),
    );
  }
}

/// .sr settings/action row.
class SetRow extends StatelessWidget {
  const SetRow({super.key, required this.icon, required this.title, this.sub, this.value, this.trailing, this.onTap, this.danger = false, this.chev = false, this.iconBg});
  final String icon, title;
  final String? sub, value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger, chev;
  final Color? iconBg;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg ?? ll.surface2), child: LLIcon(icon, size: 19, color: ll.ink2)),
        const SizedBox(width: 13),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t(15, FontWeight.w700, danger ? (ll.dark ? LL.danger : const Color(0xFFD0453F)) : ll.ink)),
            if (sub != null) Padding(padding: const EdgeInsets.only(top: 1), child: Text(sub!, style: t(12.5, FontWeight.w600, ll.ink3))),
          ]),
        ),
        if (value != null) Text(value!, style: t(13.5, FontWeight.w700, ll.ink2)),
        ?trailing,
        if (chev) Padding(padding: const EdgeInsets.only(left: 6), child: LLIcon('chev', size: 18, color: ll.ink3)),
      ]),
    );
    return onTap == null ? row : Tap(scale: .98, onTap: onTap, child: row);
  }
}

/// .chip filter chip.
class LLChip extends StatelessWidget {
  const LLChip({super.key, required this.label, required this.on, required this.onTap, this.icon});
  final String label;
  final bool on;
  final VoidCallback onTap;
  final String? icon;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Tap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: on ? ll.ink : ll.surface, borderRadius: BorderRadius.circular(99), boxShadow: on ? null : ll.shadow),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[LLIcon(icon!, size: 16, color: on ? ll.onInk : ll.ink2), const SizedBox(width: 6)],
          Text(label, style: t(14, FontWeight.w700, on ? ll.onInk : ll.ink2)),
        ]),
      ),
    );
  }
}

/// .fp folder pill (used in pickers).
class FolderPill extends StatelessWidget {
  const FolderPill({super.key, required this.icon, required this.label, this.on = false, this.count, this.onTap, this.dashed = false, this.small = false});
  final String icon, label;
  final bool on, dashed, small;
  final int? count;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final h = small ? 46.0 : 56.0, ic = small ? 36.0 : 44.0;
    return Tap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: h,
        padding: const EdgeInsets.fromLTRB(6, 0, 18, 0),
        decoration: BoxDecoration(
          color: dashed ? Colors.transparent : on ? ll.blue : ll.surface,
          borderRadius: BorderRadius.circular(99),
          border: dashed ? Border.all(color: ll.inkMix(.15), width: 1.5) : null,
          boxShadow: dashed ? null : on ? ll.blueGlow(.3) : (ll.dark ? null : ll.shadow),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: ic,
            height: ic,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dashed ? Colors.transparent : on ? Colors.white.withValues(alpha: .22) : ll.blueSoft),
            child: LLIcon(icon, size: 20, color: on ? Colors.white : dashed ? ll.ink2 : ll.blueInk),
          ),
          const SizedBox(width: 10),
          Text(label, style: t(small ? 14 : 15, FontWeight.w700, on ? Colors.white : ll.ink)),
          if (count != null) ...[const SizedBox(width: 5), Text('$count', style: t(13, FontWeight.w700, on ? Colors.white70 : ll.ink3))],
        ]),
      ),
    );
  }
}

/// Simple yes/no confirmation sheet. Returns true if confirmed.
Future<bool> confirmSheet(BuildContext context, {required String title, required String body, required String yes, bool danger = true}) async {
  final r = await showLLSheet<bool>(context, builder: (ctx) {
    final ll = LL.of(ctx);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle(title),
      Text(body, style: t(15, FontWeight.w500, ll.ink2, h: 1.5)),
      const SizedBox(height: 22),
      Tap(
        onTap: () => Navigator.pop(ctx, true),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: danger ? const Color(0xFFE5484D) : ll.blue, borderRadius: BorderRadius.circular(99)),
          child: Text(yes, style: t(16, FontWeight.w800, Colors.white)),
        ),
      ),
      const SizedBox(height: 8),
      Tap(onTap: () => Navigator.pop(ctx, false), child: SizedBox(height: 50, child: Center(child: Text('Cancel', style: t(15, FontWeight.w800, ll.ink2))))),
    ]);
  });
  return r == true;
}
