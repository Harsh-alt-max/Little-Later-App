// Folders: big soft tiles made from what's inside.
import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../screens/folders_screen.dart' show Avatars, memberLetters;
import '../screens/save_sheet.dart' show newFolderSheet;
import '../theme/tokens.dart';
import '../widgets/eyes_refresh.dart';
import 'kit.dart';

class FoldersView extends StatelessWidget {
  const FoldersView({super.key});
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final st = s.store;
    final top = MediaQuery.paddingOf(context).top;
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final total = st.items.where((i) => !i.isDone && i.extra['msg'] != true && i.folder.isNotEmpty).length;
        return EyesRefresh(
          onRefresh: s.app.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: EdgeInsets.fromLTRB(16, top + 18, 16, 150),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Folders', style: t(34, FontWeight.w600, ll.ink, ls: -.03)),
                      const SizedBox(height: 4),
                      Mono('${st.folders.length} folders · $total saves'),
                    ]),
                  ),
                  RoundBtn(
                    icon: 'plus',
                    label: 'New folder',
                    onTap: () async {
                      final f = await newFolderSheet(context);
                      if (f != null) s.app.openFolder(f);
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: .82,
                children: [for (final f in st.folders) _Tile(folder: f)],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.folder});
  final Folder folder;
  @override
  Widget build(BuildContext context) {
    final ll = LL.of(context);
    final s = AppScope.of(context);
    final st = s.store;
    final its = st.inFolder(folder.name).where((i) => !i.isDone && i.extra['msg'] != true).toList();
    final covers = its.where((i) => i.thumbnail.startsWith('http')).take(3).toList();
    final n = its.length;
    final veil = ll.dark
        ? const [Color(0x0014141A), Color(0x3814141A), Color(0x8014141A)]
        : const [Color(0x00FFFFFF), Color(0x66FFFFFF), Color(0xBFFFFFFF)];
    return Tap(
      scale: .97,
      onTap: () => s.app.openFolder(folder),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(fit: StackFit.expand, children: [
          Container(color: ll.surface),
          if (covers.isNotEmpty)
            // A soft glow made from the covers inside.
            Positioned(
              left: -40,
              right: -40,
              top: -40,
              bottom: 10,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Opacity(opacity: .9, child: Cover2(item: covers.first, radius: 0)),
              ),
            )
          else
            Positioned(
              left: -30,
              right: -30,
              top: -30,
              bottom: 20,
              child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(colors: [ll.blue.withValues(alpha: .45), ll.blue.withValues(alpha: 0)], radius: .7))),
            ),
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [.3, .62, 1], colors: veil)))),
          // Fanned covers.
          if (covers.isNotEmpty)
            Positioned(
              left: 14,
              top: 14,
              right: 14,
              height: 96,
              child: Stack(children: [
                for (var i = covers.length - 1; i >= 0; i--)
                  Positioned(
                    left: i * 22.0,
                    top: i * 6.0,
                    child: Transform.rotate(
                      angle: (i - 1) * .08,
                      child: Container(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: .6), width: 2)),
                        child: Cover2(item: covers[i], width: 70, height: 80, radius: 12),
                      ),
                    ),
                  ),
              ]),
            )
          else
            Positioned(left: 14, top: 14, child: Container(width: 52, height: 52, decoration: BoxDecoration(color: ll.blue, borderRadius: BorderRadius.circular(16)), alignment: Alignment.center, child: LLIcon(folder.iconKey, size: 24, color: ll.onAccent))),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (folder.collab) Padding(padding: const EdgeInsets.only(bottom: 8), child: Avatars(letters: memberLetters(folder, st.userName), size: 22)),
              Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(22, FontWeight.w600, ll.ink, ls: -.02)),
              const SizedBox(height: 2),
              Mono('$n ${n == 1 ? 'save' : 'saves'}${folder.collab ? ' · shared' : ''}${folder.collab && st.isMuted(folder) ? ' · muted' : ''}'),
            ]),
          ),
        ]),
      ),
    );
  }
}
