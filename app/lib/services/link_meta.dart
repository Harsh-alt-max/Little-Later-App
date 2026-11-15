import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/store.dart';
import '../data/titles.dart';

class LinkMeta {
  const LinkMeta({this.title, this.image});
  final String? title, image;
}

String? youtubeId(String url) {
  final u = Uri.tryParse(url);
  if (u == null) return null;
  if (u.host.contains('youtu.be')) return u.pathSegments.isEmpty ? null : u.pathSegments.first;
  if (!u.host.contains('youtube')) return null;
  if (u.queryParameters['v'] != null) return u.queryParameters['v'];
  final seg = u.pathSegments;
  final i = seg.indexWhere((s) => s == 'shorts' || s == 'embed' || s == 'live');
  return i >= 0 && i + 1 < seg.length ? seg[i + 1] : null;
}

String? _meta(String body, String prop) {
  final a = RegExp('<meta[^>]+(?:property|name)=["\']$prop["\'][^>]+content=["\']([^"\']+)', caseSensitive: false).firstMatch(body)?.group(1);
  return a ?? RegExp('<meta[^>]+content=["\']([^"\']+)["\'][^>]+(?:property|name)=["\']$prop["\']', caseSensitive: false).firstMatch(body)?.group(1);
}

/// Page title and cover image (YouTube thumbnail, og:image or twitter:image).
Future<LinkMeta> fetchMeta(String url) async {
  try {
    final yt = youtubeId(url);
    if (yt != null) {
      String? title;
      try {
        final r = await http.get(Uri.parse('https://www.youtube.com/oembed?format=json&url=${Uri.encodeComponent(url)}')).timeout(const Duration(seconds: 5));
        if (r.statusCode == 200) title = (jsonDecode(r.body) as Map)['title'] as String?;
      } catch (_) {}
      return LinkMeta(title: title == null ? null : cleanTitle(title), image: 'https://i.ytimg.com/vi/$yt/hqdefault.jpg');
    }
    // Social sites send their preview tags to link-preview bots.
    final social = RegExp('instagram|facebook|threads').hasMatch(url);
    final r = await http
        .get(
          Uri.parse(url),
          headers: {
            'User-Agent': social
                ? 'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)'
                : 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/130 Mobile Safari/537.36 LittleLater/1.4',
            'Accept-Language': 'en',
          },
        )
        .timeout(const Duration(seconds: 6));
    if (r.statusCode != 200) return const LinkMeta();
    final body = r.body.length > 300000 ? r.body.substring(0, 300000) : r.body;
    final tt = _meta(body, 'og:title') ?? RegExp(r'<title[^>]*>([^<]{2,200})</title>', caseSensitive: false).firstMatch(body)?.group(1);
    var img = _meta(body, 'og:image') ?? _meta(body, 'twitter:image') ?? _meta(body, 'og:image:url');
    if (img != null) {
      img = img.replaceAll('&amp;', '&');
      if (img.startsWith('//')) img = 'https:$img';
      if (img.startsWith('/')) img = Uri.parse(url).resolve(img).toString();
    }
    return LinkMeta(title: tt == null ? null : cleanTitle(tt), image: img);
  } catch (_) {
    return const LinkMeta();
  }
}

/// Fill in covers for saved links that don't have one yet (older saves, the extension).
Future<void> backfillCovers(AppStore st, {int max = 12}) async {
  // Also fixes titles of links saved with just their address (e.g. right-click in Chrome).
  final todo = st.items.where((i) => i.url.isNotEmpty && ((i.thumbnail.isEmpty && i.extra['coverTried'] != true) || i.title == i.url) && !i.isDone).take(max).toList();
  for (final it in todo) {
    final m = await fetchMeta(it.url);
    it.extra['coverTried'] = true;
    if (m.image != null && it.thumbnail.isEmpty) it.thumbnail = m.image!;
    if (it.title == it.url && (m.title ?? '').isNotEmpty) it.title = m.title!;
    st.touchItem(it);
  }
}
