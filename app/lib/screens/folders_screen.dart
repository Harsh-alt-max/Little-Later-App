import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../ui/items.dart' as v2;
import '../widgets/common.dart';
import '../widgets/eyes_refresh.dart';
import '../widgets/icons.dart';
import '../widgets/item_tile.dart';
import '../widgets/kit.dart';
import 'save_sheet.dart';
import 'saved_screen.dart';
import '../services/haptics.dart';

const _palette = [(Color(0xFF2D4FD6), Color(0xFF5C7DFF)), (Color(0xFF22328A), Color(0xFF3E56C9)), (Color(0xFF1C2550), Color(0xFF33427F)), (Color(0xFF3A4BB8), Color(0xFF7C8EFF))];

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
        return EyesRefresh(
          onRefresh: s.app.refresh,
          child: ListView(
            padding: EdgeInsets.only(bottom: 130 + bottom),
            physics: const ClampingScrollPhysics(),
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
          ),
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
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (size - 8),
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _c[i % 3],
                  border: Border.all(color: ring ?? ll.surface, width: 2),
                ),
                child: Text(shown[i], style: t(size * .42, FontWeight.w800, Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}

List<String> memberLetters(Folder f, String myName) => [initials(f.ownerName.isNotEmpty ? f.ownerName : myName), for (final c in f.collaborators) initials('${c['name'] ?? c['email'] ?? '?'}')];

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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: back,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(24), bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: -14,
                child: Container(
                  width: 84,
                  height: 32,
                  decoration: BoxDecoration(
                    color: back,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(20)),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 500),
                curve: Motion.spring,
                left: 24,
                right: 20,
                top: _down ? 9 : 15,
                height: 50,
                child: Transform.rotate(
                  angle: _down ? -.07 : -.035,
                  child: Container(
                    decoration: BoxDecoration(color: const Color(0xFFDDE4FF), borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 500),
                curve: Motion.spring,
                left: 14,
                right: 14,
                top: _down ? 0 : 10,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(color: const Color(0xFFF4F6FF), borderRadius: BorderRadius.circular(12)),
                ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .2)),
                            child: LLIcon(f.iconKey, size: 19, color: Colors.white),
                          ),
                          const Spacer(),
                          Text('${widget.count}', style: t(22, FontWeight.w800, Colors.white.withValues(alpha: .95), ls: -.02)),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(16, FontWeight.w800, Colors.white, h: 1.15)),
                          ),
                          if (f.collab) ...[const SizedBox(width: 6), Avatars(letters: memberLetters(f, AppScope.of(context).store.userName), size: 22, ring: fc)],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!widget.pop) return card;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .6, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Motion.spring,
      builder: (_, v, c) => Opacity(
        opacity: ((v - .6) / .4).clamp(0, 1),
        child: Transform.scale(scale: v, child: c),
      ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: ll.surface2),
                child: LLIcon('plus', size: 19, color: ll.ink2),
              ),
              const SizedBox(height: 8),
              Text('New folder', style: t(14.5, FontWeight.w800, ll.ink2)),
            ],
          ),
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
  int _view = 0; // shared folders: 0 = Saved, 1 = Chat
  final _scroll = ScrollController();
  final _msg = TextEditingController();
  final _msgFocus = FocusNode();
  Folder get f => widget.folder;

  @override
  void dispose() {
    _scroll.dispose();
    _msg.dispose();
    _msgFocus.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 350), curve: Motion.smooth);
    });
  }

  bool _mine(AppStore st, Item it) {
    final e = '${it.extra['senderEmail'] ?? ''}';
    if (e.isNotEmpty) return e == st.userEmail;
    return f.ownerEmail.isEmpty || f.ownerEmail == st.userEmail;
  }

  String _senderName(AppStore st, Item it) {
    if (_mine(st, it)) return 'You';
    final n = '${it.extra['senderName'] ?? ''}';
    if (n.isNotEmpty) return n;
    final e = '${it.extra['senderEmail'] ?? ''}';
    if (e.isNotEmpty) return e.split('@').first;
    return f.ownerName.isEmpty ? 'Friend' : f.ownerName;
  }

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

  void _send() {
    final s = AppScope.of(context);
    final st = s.store;
    final txt = _msg.text.trim();
    if (txt.isEmpty) return;
    final url = extractUrl(txt);
    final info = url == null ? null : parseLink(url);
    final note = url == null ? '' : txt.replaceAll(url, '').trim();
    final it = Item(
      id: newId(),
      kind: info != null ? ItemKind.link : ItemKind.reminder,
      title: info?.title ?? txt,
      folder: f.name,
      url: info?.url ?? '',
      note: note,
      extra: {'senderEmail': st.userEmail, 'senderName': st.userName, if (info == null) 'msg': true},
    );
    st.addItem(it);
    _msg.clear();
    Haptics.light();
    _toBottom();
    if (info != null) {
      fetchTitle(info).then((tt) {
        if (tt != null && tt.isNotEmpty) it.title = tt;
        if (info.image.isNotEmpty) it.thumbnail = info.image;
        st.touchItem(it);
      });
    }
  }

  Future<void> _members() async {
    final s = AppScope.of(context);
    final st = s.store;
    final owner = f.ownerEmail.isEmpty || f.ownerEmail == st.userEmail;
    final gone = await showLLSheet<String>(
      context,
      builder: (ctx) {
        final ll = LL.of(ctx);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetTitle('People'),
            SetRow(icon: 'user', title: owner ? 'You' : (f.ownerName.isEmpty ? f.ownerEmail : f.ownerName), sub: 'Owner'),
            for (final c in f.collaborators)
              SetRow(
                icon: 'user',
                title: '${c['email']}' == st.userEmail ? 'You' : '${c['name']}',
                sub: '${c['email']}',
                trailing: owner && '${c['email']}' != st.userEmail
                    ? Tap(
                        onTap: () => Navigator.pop(ctx, '${c['email']}'),
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: ll.surface2, borderRadius: BorderRadius.circular(99)),
                          child: Text('Remove', style: t(13, FontWeight.w800, ll.dark ? LL.danger : const Color(0xFFD0453F))),
                        ),
                      )
                    : null,
              ),
            if (f.collaborators.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No one has joined yet.', style: t(14, FontWeight.w600, ll.ink3)),
              ),
          ],
        );
      },
    );
    if (gone == null || !mounted) return;
    final name = '${f.collaborators.where((c) => '${c['email']}' == gone).firstOrNull?['name'] ?? gone}';
    if (!await confirmSheet(context, title: 'Remove $name?', body: 'They keep what’s already saved, as their own folder, but won’t see anything new you or others add.', yes: 'Remove')) {
      return;
    }
    final err = await s.app.sync.removeMember(f, gone);
    s.toast.show(err ?? '$name was removed');
  }

  Future<void> _more() async {
    final s = AppScope.of(context);
    final owner = f.ownerEmail.isEmpty || f.ownerEmail == s.store.userEmail;
    final a = await showLLSheet<String>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(f.name),
          SetRow(icon: 'pen', title: 'Rename', onTap: () => Navigator.pop(ctx, 'rename')),
          SetRow(icon: 'users', title: f.collab ? 'Invite more friends' : 'Share with friends', onTap: () => Navigator.pop(ctx, 'invite')),
          if (f.collab) SetRow(icon: 'user', title: owner ? 'People and removing' : 'People', onTap: () => Navigator.pop(ctx, 'people')),
          if (f.collab) SetRow(icon: s.store.isMuted(f) ? 'bell' : 'bell-off', title: s.store.isMuted(f) ? 'Unmute group' : 'Mute group', onTap: () => Navigator.pop(ctx, 'mute')),
          SetRow(
            icon: const {'list': 'vgrid', 'grid': 'vlarge', 'large': 'vlist'}[s.store.viewMode]!,
            title: const {'list': 'Show as grid', 'grid': 'Show big covers', 'large': 'Show as list'}[s.store.viewMode]!,
            onTap: () => Navigator.pop(ctx, 'view'),
          ),
          SetRow(icon: 'trash', title: f.collab ? 'Leave and delete folder' : 'Delete folder', danger: true, onTap: () => Navigator.pop(ctx, 'del')),
        ],
      ),
    );
    if (!mounted || a == null) return;
    if (a == 'invite') await _invite();
    if (a == 'people') await _members();
    if (a == 'view') s.store.setPrefs(view: const {'list': 'grid', 'grid': 'large', 'large': 'list'}[s.store.viewMode]);
    if (a == 'mute') {
      final on = !s.store.isMuted(f);
      s.store.setMuted(f, on);
      s.app.reminders.reschedule();
      s.toast.show(on ? 'Muted. No alerts from “${shortText(f.name)}” on this phone' : 'Unmuted. You will get this group’s alerts again');
    }
    if (a == 'rename' && mounted) {
      final c = TextEditingController(text: f.name);
      final n = await showLLSheet<String>(
        context,
        builder: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetTitle('Rename folder'),
            LLInput(controller: c, hint: 'Folder name', icon: 'pen', maxLength: 18, autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, v)),
            const SizedBox(height: 16),
            BigButton(label: 'Save', onTap: () => Navigator.pop(ctx, c.text)),
          ],
        ),
      );
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
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    return ListenableBuilder(
      listenable: s.store,
      builder: (context, _) {
        final st = s.store;
        final chat = f.collab && _view == 1;
        final its = st.inFolder(f.name).where((i) => i.extra['msg'] != true).toList()..sort((a, b) => (a.isDone ? 1 : 0).compareTo(b.isDone ? 1 : 0));
        final n = its.where((i) => !i.isDone).length;
        final names = [
          f.ownerEmail.isEmpty || f.ownerEmail == st.userEmail ? 'You' : (f.ownerName.isEmpty ? f.ownerEmail.split('@').first : f.ownerName),
          for (final c in f.collaborators) ('${c['email']}' == st.userEmail ? 'You' : '${c['name']}'),
        ];
        final namesTxt = names.length == 1
            ? 'Just you so far'
            : names.length == 2
            ? '${names[0]} and ${names[1]}'
            : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
        // The composer floats above the keyboard (or above the nav bar).
        final composerBottom = kb > 0 ? kb + 10 : 100 + bottom;
        return Stack(
          children: [
            EyesRefresh(
              onRefresh: s.app.refresh,
              child: ListView(
                controller: _scroll,
                padding: EdgeInsets.only(bottom: chat ? composerBottom + 84 : 130 + bottom),
                physics: const ClampingScrollPhysics(),
                children: [
                  PageHead(
                    left: Circ(
                      icon: 'back',
                      label: 'Back',
                      onTap: () {
                        s.buzz(0);
                        widget.onBack();
                      },
                    ),
                    right: Circ(icon: 'dots', label: 'Folder options', onTap: _more),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 64,
                            height: 52,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: ll.stripe),
                                    child: Center(child: LLIcon(f.iconKey, color: ll.ink)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(28, FontWeight.w800, ll.ink, ls: -.03, h: 1.1)),
                                const SizedBox(height: 2),
                                Text('$n item${n == 1 ? '' : 's'}', style: t(14.5, FontWeight.w500, ll.ink2)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 18),
                        GestureDetector(
                          onTap: f.collab ? _members : null,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                            decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(99)),
                            child: Row(
                              children: [
                                Avatars(letters: f.collab ? memberLetters(f, st.userName) : [initials(st.userName.isEmpty ? 'You' : st.userName)], size: 32),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(f.collab ? namesTxt : 'Only you', maxLines: 1, overflow: TextOverflow.ellipsis, style: t(13.5, FontWeight.w600, ll.ink2)),
                                ),
                                Tap(
                                  onTap: _invite,
                                  child: Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(horizontal: 15),
                                    decoration: BoxDecoration(color: ll.blue, borderRadius: BorderRadius.circular(99)),
                                    child: Row(
                                      children: [
                                        LLIcon(f.collab ? 'plus' : 'users', size: 18, color: ll.onAccent),
                                        const SizedBox(width: 8),
                                        Text(f.collab ? 'Invite' : 'Share', style: t(13.5, FontWeight.w700, ll.onAccent)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (f.collab) ...[
                          const SizedBox(height: 14),
                          Segmented(
                            labels: const ['Saved', 'Chat'],
                            icons: const ['saved', 'users'],
                            index: _view,
                            height: 48,
                            onChanged: (i) {
                              s.buzz(0);
                              setState(() => _view = i);
                              if (i == 1) _toBottom();
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (chat)
                          _Chat(folder: f, items: st.inFolder(f.name)..sort((a, b) => a.savedAt.compareTo(b.savedAt)), mine: (it) => _mine(st, it), name: (it) => _senderName(st, it))
                        else ...[
                          if (f.collab)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                              child: Row(children: [
                                Opacity(opacity: .6, child: LLIcon(st.isMuted(f) ? 'quiet' : 'bell', size: 15, color: ll.ink)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(st.isMuted(f) ? 'Muted. Reminders here won’t ping you.' : 'Reminders here ping everyone in the group. They only show inside this group.', style: t(13, FontWeight.w400, ll.ink2))),
                              ]),
                            ),
                          if (its.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 22),
                              decoration: BoxDecoration(color: ll.surface, borderRadius: BorderRadius.circular(28)),
                              child: Text('Empty for now. Add a link, reminder or to-do.', textAlign: TextAlign.center, style: t(14, FontWeight.w600, ll.ink3)),
                            )
                          else
                            Transform.translate(offset: const Offset(-20, 0), child: SizedBox(width: MediaQuery.sizeOf(context).width, child: v2.ItemsView(items: its, view: st.viewMode, inFolder: true, by: f.collab))),
                          const SizedBox(height: 14),
                          Tap(
                            onTap: () {
                              Haptics.light();
                              s.app.openSave(folder: f.name);
                            },
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(color: ll.inkMix(.15), width: 1.5),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  LLIcon('plus', size: 18, color: ll.ink2),
                                  const SizedBox(width: 8),
                                  Text('Add link, reminder or to-do', style: t(14.5, FontWeight.w800, ll.ink2)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (chat)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                left: 16,
                right: 16,
                bottom: composerBottom,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: ll.surface,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: ll.line),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: TextField(
                            controller: _msg,
                            focusNode: _msgFocus,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 500,
                            onTap: _toBottom,
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
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Shared folder chat: your messages and saves on the right, friends' on the left.

class _Chat extends StatelessWidget {
  const _Chat({required this.folder, required this.items, required this.mine, required this.name});
  final Folder folder;
  final List<Item> items;
  final bool Function(Item) mine;
  final String Function(Item) name;

  Future<void> _actions(BuildContext context, Item it) async {
    final s = AppScope.of(context);
    final st = s.store;
    Haptics.tick();
    final a = await showLLSheet<String>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(shortText(it.title, 40)),
          if (it.url.isNotEmpty) SetRow(icon: 'arrow', title: 'Open', onTap: () => Navigator.pop(ctx, 'open')),
          if (it.extra['msg'] != true) SetRow(icon: 'check', title: 'Mark done', onTap: () => Navigator.pop(ctx, 'done')),
          if (it.extra['msg'] != true) SetRow(icon: 'clock', title: 'Remind me', onTap: () => Navigator.pop(ctx, 'remind')),
          SetRow(icon: 'trash', title: 'Delete', danger: true, onTap: () => Navigator.pop(ctx, 'del')),
        ],
      ),
    );
    if (a == null || !context.mounted) return;
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
    String? lastDay;
    final rows = <Widget>[];
    for (final it in items) {
      final d = DateTime.fromMillisecondsSinceEpoch(it.savedAt);
      final day = fmtDay(d);
      if (day != lastDay) {
        lastDay = day;
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(child: Text(day, style: t(12, FontWeight.w700, ll.ink3))),
          ),
        );
      }
      rows.add(_bubble(context, ll, it, mine(it), d));
    }
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text('No messages yet. Say hi, or send a link.', textAlign: TextAlign.center, style: t(14, FontWeight.w600, ll.ink3)),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  Widget _bubble(BuildContext context, LL ll, Item it, bool me, DateTime d) {
    final who = name(it);
    final msg = it.extra['msg'] == true;
    final fg = me ? Colors.white : ll.ink;
    final sub = me ? Colors.white.withValues(alpha: .72) : ll.ink3;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!me)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(who, style: t(12, FontWeight.w800, ll.blueInk)),
          ),
        if (!msg)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: me ? Colors.white.withValues(alpha: .14) : ll.surface2, borderRadius: BorderRadius.circular(14)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LLIcon(
                  it.url.isNotEmpty
                      ? 'link'
                      : it.kind == ItemKind.todoList
                      ? 'check'
                      : 'bell',
                  size: 16,
                  color: sub,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        it.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t(14, FontWeight.w800, fg, h: 1.3).copyWith(decoration: it.isDone ? TextDecoration.lineThrough : null),
                      ),
                      Text(
                        it.url.isNotEmpty
                            ? it.domain
                            : it.kind == ItemKind.todoList
                            ? 'To-do'
                            : 'Reminder',
                        style: t(11.5, FontWeight.w600, sub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Text(it.title, style: t(14.5, FontWeight.w600, fg, h: 1.4)),
        if (it.note.isNotEmpty) Text(it.note, style: t(14, FontWeight.w500, fg, h: 1.4)),
        const SizedBox(height: 3),
        Text(
          '${fmtT(d)}${it.isDone
              ? ' · done'
              : it.whenTs > 0
              ? ' · reminder ${fmtDue(DateTime.fromMillisecondsSinceEpoch(it.whenTs))}'
              : ''}',
          style: t(11, FontWeight.w600, sub),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: me ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!me) ...[
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF5A6FA8)),
              child: Text(initials(who), style: t(12, FontWeight.w800, Colors.white)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onTap: () => it.url.isNotEmpty ? openItemUrl(AppScope.of(context), it) : _actions(context, it),
              onLongPress: () => _actions(context, it),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .74),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(13, 9, 13, 8),
                  decoration: BoxDecoration(
                    color: me ? ll.blue : ll.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(me ? 20 : 6),
                      bottomRight: Radius.circular(me ? 6 : 20),
                    ),
                  ),
                  child: body,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Invite with your own message, sent through any app.
Future<void> inviteSheet(BuildContext context, Folder f) async {
  final s = AppScope.of(context);
  final c = TextEditingController(text: 'Hey! Join my “${f.name}” folder on Little Later so we can save things together.');
  final send = await showLLSheet<bool>(
    context,
    builder: (ctx) {
      final ll = LL.of(ctx);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
        ],
      );
    },
  );
  if (send != true) return;
  final live = s.store.folders.where((x) => x.collabId.isNotEmpty && x.name == f.name).firstOrNull ?? f;
  if (live.collabId.isEmpty) {
    s.toast.show('Couldn’t create the invite. Check your internet and try again.');
    return;
  }
  final link = inviteLink(s.store, live);
  await Clipboard.setData(ClipboardData(text: link));
  try {
    await shareText('${c.text.trim()}\n$link');
  } catch (_) {}
  s.toast.show('Invite link copied too');
}
