// Link title clean-up shared by the save sheet and data migration.

String _unescape(String s) => s
    .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)))
    .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)))
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&nbsp;', ' ')
    .replaceAll(RegExp(r'\s+'), ' ');

/// Turn a page title into a short, readable name.
/// Instagram/TikTok titles carry the whole caption: keep "Author: first words".
String cleanTitle(String raw) {
  var s = _unescape(raw).trim();
  final social = RegExp(r'^(.{1,60}?) on (Instagram|TikTok|Threads|X|Facebook)\s*[:|-]\s*"?(.*?)"?$', dotAll: true).firstMatch(s);
  if (social != null) {
    final who = social[1]!.trim();
    final cap = social[3]!.replaceAll(RegExp(r'#\S+'), '').replaceAll(RegExp(r'@\S+'), '').trim();
    final first = cap.split(RegExp(r'(?<=[.!?])\s|\n')).first.trim();
    s = first.isEmpty ? '$who on ${social[2]}' : '$who: $first';
  }
  s = s.replaceAll(RegExp(r'\s+[-|·–]\s+(YouTube|Instagram|TikTok)$'), '');
  s = s.replaceAll(RegExp(r'(\s#\S+)+$'), '').trim();
  if (s.length > 70) {
    final cut = s.substring(0, 70);
    final sp = cut.lastIndexOf(' ');
    s = '${(sp > 40 ? cut.substring(0, sp) : cut).trim()}…';
  }
  return s;
}

