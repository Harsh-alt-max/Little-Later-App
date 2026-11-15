import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';
import '../widgets/item_tile.dart';
import '../widgets/kit.dart';
import 'save_sheet.dart';
import 'saved_screen.dart';
import '../services/haptics.dart';

const _palette = [
  (Color(0xFF2D4FD6), Color(0xFF5C7DFF)),
  (Color(0xFF22328A), Color(0xFF3E56C9)),
  (Color(0xFF1C2550), Color(0xFF33427F)),
  (Color(0xFF3A4BB8), Color(0xFF7C8EFF)),
];

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});
  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  String? _pop;

  Future<void> _new() async {
    final f = await newFolderSheet(context);
    if (f != null && mounted) setState(() => _pop = f.name);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListenableBuilder(
      listenable: s.store,
      builder: (context, _) {
        final fs = s.store.folders;
        return ListView(
          padding: EdgeInsets.only(bottom: 130 + bottom),
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            const PageHead(title: 'Folders'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: fs.length + 1,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 26, crossAxisSpacing: 14, mainAxisExtent: 150),
                itemBuilder: (_, i) => i == fs.length
                    ? _AddFolder(onTap: _new)
                    : FolderCard(
                        folder: fs[i],
                        count: s.store.folderCount(fs[i].name),
                        colors: _palette[i % 4],
                        pop: _pop == fs[i].name,
                        onTap: () {
                          s.buzz(0);
                          s.app.openFolder(fs[i]);
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

String initials(String name) => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

/// Member avatars (.avs).
class Avatars extends StatelessWidget {
  const Avatars({super.key, required this.letters, this.size = 26, this.ring});
  final List<String> letters;
  final double size;
  final Color? ring;
  static const _c = [Color(0xFF5A6FA8), Color(0xFF3D6BF5), Color(0xFF2A3A6E)];
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final shown = letters.take(3).toList();
    return SizedBox(
      height: size,
      width: size + (shown.length - 1) * (size - 8),
      child: Stack(children: [
        for (var i = 0; i < shown.length; i++)
          Positioned(
            left: i * (size - 8),
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _c[i % 3], border: Border.all(color: ring ?? ll.surface, width: 2)),
              child: Text(shown[i], style: t(size * .42, FontWeight.w800, Colors.white)),
            ),
          ),
      ]),
    );
  }
}

List<String> memberLetters(Folder f, String myName) => [
      initials(f.ownerName.isNotEmpty ? f.ownerName : myName),
      for (final c in f.collaborators) initials('${c['name'] ?? c['email'] ?? '?'}'),
    ];

/// v6/v7 folder shape: back tab, two peeking papers, gradient front.
class FolderCard extends StatefulWidget {
  const FolderCard({super.key, required this.folder, required this.count, required this.colors, required this.onTap, this.pop = false});
  final Folder folder;
  final int count;
  final (Color, Color) colors;
  final VoidCallback onTap;
  final bool pop;
  @override
  State<FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<FolderCard> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final (fc, fc2) = widget.colors;
    final f = widget.folder;
    final back = Color.lerp(fc, Colors.black, .38)!;
    final card = GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: Semantics(
        button: true,
        label: '${f.name}, ${widget.count} items',
        child: AnimatedScale(
          scale: _down ? .96 : 1,
          duration: Duration(milliseconds: _down ? 100 : 450),
          curve: _down ? Curves.easeOut : Motion.spring,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(child: Container(decoration: BoxDecoration(color: back, borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(24), bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))))),
            Positioned(left: 0, top: -14, child: Container(width: 84, height: 32, decoration: BoxDecoration(color: back, borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(20))))),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: Motion.spring,
              left: 24,
              right: 20,
              top: _down ? 9 : 15,
              height: 50,
              child: Transform.rotate(angle: _down ? -.07 : -.035, child: Container(decoration: BoxDecoration(color: const Color(0xFFDDE4FF), borderRadius: BorderRadius.circular(12)))),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: Motion.spring,
              left: 14,
              right: 14,
              top: _down ? 0 : 10,
              height: 50,
              child: Container(decoration: BoxDecoration(color: const Color(0xFFF4F6FF), borderRadius: BorderRadius.circular(12))),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: 30,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [fc2, fc]),
                  boxShadow: const [BoxShadow(color: Color(0x59141E5A), blurRadius: 30, offset: Offset(0, 14))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .2)), child: LLIcon(f.iconKey, size: 19, color: Colors.white)),
                    const Spacer(),
                    Text('${widget.count}', style: t(22, FontWeight.w800, Colors.white.withValues(alpha: .95), ls: -.02)),
                  ]),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(16, FontWeight.w800, Colors.white, h: 1.15))),
                    if (f.collab) ...[const SizedBox(width: 6), Avatars(letters: memberLetters(f, AppScope.of(context).store.userName), size: 22, ring: fc)],
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
    if (!widget.pop) return card;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .6, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Motion.spring,
      builder: (_, v, c) => Opacity(opacity: ((v - .6) / .4).clamp(0, 1), child: Transform.scale(scale: v, child: c)),
      child: card,
    );
  }
}

class _AddFolder extends StatelessWidget {
  const _AddFolder({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    return Tap(
      onTap: onTap,
      semanticLabel: 'New folder',
      child: CustomPaint(
        painter: _Dashed(ll.inkMix(.18)),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: ll.surface2), child: LLIcon('plus', size: 19, color: ll.ink2)),
            const SizedBox(height: 8),
            Text('New folder', style: t(14.5, FontWeight.w800, ll.ink2)),
          ]),
        ),
      ),
    );
  }
}

class _Dashed extends CustomPainter {
  _Dashed(this.c);
  final Color c;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)));
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, d + 5), p);
      }
    }
  }

  @override
  bool shouldRepaint(_Dashed o) => o.c != c;
}

// =============================================================================
// Folder detail

class FolderDetail extends StatefulWidget {
  const FolderDetail({super.key, required this.folder, required this.onBack});
  final Folder folder;
  final VoidCallback onBack;
  @override
  State<FolderDetail> createState() => _FolderDetailState();
}

class _FolderDetailState extends State<FolderDetail> {
  String? _open;
  Folder get f => widget.folder;

  Future<void> _invite() async {
    final s = AppScope.of(context);
    s.buzz(1);
    if (!s.store.signedIn) {
      s.toast.show('Sign in to share folders with friends');
      s.app.startSignIn();
      return;
    }
    await s.app.sync.share(f);
    if (!mounted) return;
    await inviteSheet(context, f);
  }

  Future<void> _more() async {
    final s = AppScope.of(context);
    final a = await showLLSheet<String>(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(f.name),
          SetRow(icon: 'pen', title: 'Rename', onTap: () => Navigator.pop(ctx, 'rename')),
          SetRow(icon: 'users', title: f.collab ? 'Invite more friends' : 'Share with friends', onTap: () => Navigator.pop(ctx, 'invite')),
          SetRow(icon: 'trash', title: f.collab ? 'Leave and delete folder' : 'Delete folder', danger: true, onTap: () => Navigator.pop(ctx, 'del')),
        ]));
    if (!mounted || a == null) return;
    if (a == 'invite') await _invite();
    if (a == 'rename' && mounted) {
      final c = TextEditingController(text: f.name);
      final n = await showLLSheet<String>(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SheetTitle('Rename folder'),
            LLInput(controller: c, hint: 'Folder name', icon: 'pen', maxLength: 18, autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, v)),
            const SizedBox(height: 16),
            BigButton(label: 'Save', onTap: () => Navigator.pop(ctx, c.text)),
          ]));
      if (n != null && n.trim().isNotEmpty) {
        s.store.renameFolder(f, n);
        s.toast.show('Folder renamed');
      }
    }
    if (a == 'del' && mounted) {
      final n = s.store.folderCount(f.name);
      if (n > 0 && !await confirmSheet(context, title: 'Delete “${f.name}”?', body: 'The $n idea${n == 1 ? '' : 's'} inside stay in Saved, without a folder.', yes: 'Delete folder')) return;
      final undo = s.store.deleteFolder(f);
      widget.onBack();
      s.toast.show('Deleted “${shortText(f.name)}”', undo: undo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListenableBuilder(
      listenable: s.store,
      builder: (context, _) {
        final st = s.store;
        final its = st.inFolder(f.name)..sort((a, b) => (a.isDone ? 1 : 0).compareTo(b.isDone ? 1 : 0));
        final n = its.where((i) => !i.isDone).length;
        final names = [
          f.ownerEmail.isEmpty || f.ownerEmail == st.userEmail ? 'You' : (f.ownerName.isEmpty ? f.ownerEmail.split('@').first : f.ownerName),
          for (final c in f.collaborators) ('${c['email']}' == st.userEmail ? 'You' : '${c['name']}'),
        ];
        final namesTxt = names.length == 1 ? 'Just you so far' : names.length == 2 ? '${names[0]} and ${names[1]}' : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
        return ListView(
          padding: EdgeInsets.only(bottom: 130 + bottom),
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            PageHead(
              left: Circ(icon: 'back', label: 'Back', onTap: () {
                s.buzz(0);
                widget.onBack();
              }),
              right: Circ(icon: 'dots', label: 'Folder options', onTap: _more),
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(children: [
                  SizedBox(
                    width: 64,
                    height: 52,
                    child: Stack(children: [
                      Container(width: 32, height: 16, decoration: const BoxDecoration(color: Color(0xFF22328A), borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(10)))),
                      Positioned.fill(
                        top: 7,
                        child: Container(
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(14), bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14)),
                            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6A8EFF), Color(0xFF3D6BF5)]),
                          ),
                          child: Center(child: LLIcon(f.iconKey, color: Colors.white)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(28, FontWeight.w800, ll.ink, ls: -.03, h: 1.1)),
                      const SizedBox(height: 2),
                      Text('$n item${n == 1 ? '' : 's'}', style: t(14.5, FontWeight.w500, ll.ink2)),
                    ]),
                  ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                  decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(99), boxShadow: ll.shadow),
                  child: Row(children: [
                    Avatars(letters: f.collab ? memberLetters(f, st.userName) : [initials(st.userName.isEmpty ? 'You' : st.userName)], size: 32),
                    const SizedBox(width: 12),
                    Expanded(child: Text(f.collab ? namesTxt : 'Only you', maxLines: 1, overflow: TextOverflow.ellipsis, style: t(13.5, FontWeight.w600, ll.ink2))),
                    Tap(
                      onTap: _invite,
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(color: ll.blue, borderRadius: BorderRadius.circular(99)),
                        child: Row(children: [
                          LLIcon(f.collab ? 'plus' : 'users', size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(f.collab ? 'Invite' : 'Share', style: t(13.5, FontWeight.w700, Colors.white)),
                        ]),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                if (f.collab)
                  _Chat(folder: f, items: st.inFolder(f.name).where((i) => !i.isDone || i.extra['msg'] == true).toList()..sort((a, b) => a.savedAt.compareTo(b.savedAt)))
                else ...[
                  if (its.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(28)),
                      child: Text('Empty for now. Tap + to add something.', textAlign: TextAlign.center, style: t(14, FontWeight.w600, ll.ink3)),
                    )
                  else
                    Card28(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      children: [
                        for (final it in its)
                          ItemTile(
                            key: ValueKey(it.id),
                            item: it,
                            inFolder: true,
                            first: true,
                            open: _open == it.id,
                            onToggle: () => setState(() => _open = _open == it.id ? null : it.id),
                          ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  Tap(
                    onTap: () {
                      Haptics.light();
                      s.app.openSave(folder: f.name);
                    },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: ll.inkMix(.15), width: 1.5)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        LLIcon('plus', size: 18, color: ll.ink2),
                        const SizedBox(width: 8),
                        Text('Add to ${shortText(f.name, 16)}', style: t(14.5, FontWeight.w800, ll.ink2)),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Shared folder as a chat: your saves on the right, friends' on the left.

class _Chat extends StatefulWidget {
  const _Chat({required this.folder, required this.items});
  final Folder folder;
  final List<Item> items;
  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool _mine(AppStore st, Item it) {
    final e = '${it.extra['senderEmail'] ?? ''}';
    if (e.isNotEmpty) return e == st.userEmail;
    return widget.folder.ownerEmail.isEmpty || widget.folder.ownerEmail == st.userEmail;
  }

  void _send() {
    final s = AppScope.of(context);
    final st = s.store;
    final txt = _c.text.trim();
    if (txt.isEmpty) return;
    final url = extractUrl(txt);
    final info = url == null ? null : parseLink(url);
    final note = url == null ? '' : txt.replaceAll(url, '').trim();
    final it = Item(
      id: newId(),
      kind: info != null ? ItemKind.link : ItemKind.reminder,
      title: info?.title ?? txt,
      folder: widget.folder.name,
      url: info?.url ?? '',
      note: note,
      extra: {'senderEmail': st.userEmail, 'senderName': st.userName, if (info == null) 'msg': true},
    );
    st.addItem(it);
    _c.clear();
    Haptics.light();
    if (info != null) {
      fetchTitle(info).then((tt) {
        if (tt != null && tt.isNotEmpty) {
          it.title = tt;
          st.touchItem(it);
        }
      });
    }
  }

  Future<void> _actions(Item it) async {
    final s = AppScope.of(context);
    final st = s.store;
    Haptics.tick();
    final a = await showLLSheet<String>(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(shortText(it.title, 40)),
          if (it.url.isNotEmpty) SetRow(icon: 'arrow', title: 'Open', onTap: () => Navigator.pop(ctx, 'open')),
          if (it.extra['msg'] != true) SetRow(icon: 'check', title: 'Mark done', onTap: () => Navigator.pop(ctx, 'done')),
          if (it.extra['msg'] != true) SetRow(icon: 'clock', title: 'Remind me', onTap: () => Navigator.pop(ctx, 'remind')),
          SetRow(icon: 'trash', title: 'Delete', danger: true, onTap: () => Navigator.pop(ctx, 'del')),
        ]));
    if (!mounted || a == null) return;
    switch (a) {
      case 'open':
        await openItemUrl(s, it);
      case 'done':
        st.complete(it.id);
        s.app.gain(15);
        s.toast.show('Done, +15 stars');
      case 'remind':
        final d = await pickLater(context);
        if (d != null) {
          st.setWhen(it.id, d);
          s.toast.show('Reminder set, ${dayLow(d)} ${fmtT(d)}');
        }
      case 'del':
        final undo = st.deleteItem(it.id);
        s.toast.show('Deleted', undo: undo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final st = AppScope.of(context).store;
    final its = widget.items;
    String? lastDay;
    final rows = <Widget>[];
    for (final it in its) {
      final d = DateTime.fromMillisecondsSinceEpoch(it.savedAt);
      final day = fmtDay(d);
      if (day != lastDay) {
        lastDay = day;
        rows.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(child: Text(day, style: t(12, FontWeight.w700, ll.ink3))),
        ));
      }
      rows.add(_bubble(ll, st, it, _mine(st, it), d));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (its.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text('Nothing here yet. Send a link or a message below.', textAlign: TextAlign.center, style: t(14, FontWeight.w600, ll.ink3)),
        ),
      ...rows,
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(26), border: Border.all(color: ll.line)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 12),
              child: TextField(
                controller: _c,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                textInputAction: TextInputAction.newline,
                style: t(15, FontWeight.w600, ll.ink),
                decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, counterText: '', hintText: 'Send a link or message', hintStyle: t(15, FontWeight.w500, ll.ink3)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tap(
            onTap: _send,
            semanticLabel: 'Send',
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: ll.blue, shape: BoxShape.circle),
              child: const LLIcon('right', size: 20, color: Colors.white, stroke: 2.2),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _bubble(LL ll, AppStore st, Item it, bool mine, DateTime d) {
    final name = mine ? 'You' : '${it.extra['senderName'] ?? ''}'.isNotEmpty ? '${it.extra['senderName']}' : '${it.extra['senderEmail'] ?? 'Friend'}'.split('@').first;
    final msg = it.extra['msg'] == true;
    final fg = mine ? Colors.white : ll.ink;
    final sub = mine ? Colors.white.withValues(alpha: .72) : ll.ink3;
    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (!mine) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(name, style: t(12, FontWeight.w800, ll.blueInk))),
      if (!msg && it.url.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: mine ? Colors.white.withValues(alpha: .14) : ll.surface2, borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            LLIcon('link', size: 16, color: sub),
            const SizedBox(width: 8),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t(14, FontWeight.w800, fg, h: 1.3)),
                Text(it.domain, style: t(11.5, FontWeight.w600, sub)),
              ]),
            ),
          ]),
        )
      else
        Text(it.title, style: t(14.5, FontWeight.w600, fg, h: 1.4)),
      if (it.note.isNotEmpty) Text(it.note, style: t(14, FontWeight.w500, fg, h: 1.4)),
      const SizedBox(height: 3),
      Text(
        '${fmtT(d)}${it.isDone ? ' · done' : it.whenTs > 0 ? ' · reminder ${fmtDue(DateTime.fromMillisecondsSinceEpoch(it.whenTs))}' : ''}',
        style: t(11, FontWeight.w600, sub),
      ),
    ]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (!mine) ...[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF5A6FA8)),
            child: Text(initials(name), style: t(12, FontWeight.w800, Colors.white)),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: GestureDetector(
            onTap: () => it.url.isNotEmpty ? openItemUrl(AppScope.of(context), it) : _actions(it),
            onLongPress: () => _actions(it),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .74),
              child: Container(
                padding: const EdgeInsets.fromLTRB(13, 9, 13, 8),
                decoration: BoxDecoration(
                  color: mine ? ll.blue : ll.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(mine ? 20 : 6),
                    bottomRight: Radius.circular(mine ? 6 : 20),
                  ),
                ),
                child: body,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Invite with your own message, sent through any app.
Future<void> inviteSheet(BuildContext context, Folder f) async {
  final s = AppScope.of(context);
  final c = TextEditingController(text: 'Hey! Join my “${f.name}” folder on Little Later so we can save things together.');
  final send = await showLLSheet<bool>(context, builder: (ctx) {
    final ll = LL.of(ctx);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle('Invite to ${f.name}'),
      Text('Your message', style: t(13, FontWeight.w700, ll.ink3)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: ll.surface2, borderRadius: BorderRadius.circular(20)),
        child: TextField(
          controller: c,
          minLines: 3,
          maxLines: 6,
          maxLength: 300,
          style: t(15, FontWeight.w600, ll.ink, h: 1.4),
          decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none, counterText: ''),
        ),
      ),
      const SizedBox(height: 8),
      Text('The invite link is added after your message.', style: t(12.5, FontWeight.w600, ll.ink3)),
      const SizedBox(height: 18),
      BigButton(label: 'Send invite', onTap: () => Navigator.pop(ctx, true)),
    ]);
  });
  if (send != true) return;
  final link = inviteLink(s.store, f);
  await Clipboard.setData(ClipboardData(text: link));
  try {
    await shareText('${c.text.trim()}\n$link');
  } catch (_) {}
  s.toast.show('Invite link copied too');
}
