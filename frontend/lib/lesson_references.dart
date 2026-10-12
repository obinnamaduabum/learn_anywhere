/// Reads both legacy attribution and multi-source packs for the reference card.
List<Map<String, String>> lessonReferences(Map<String, dynamic> lesson) {
  final byUrl = <String, Map<String, String>>{};
  void add(Object? name, Object? url) {
    if (name is! String || url is! String) return;
    if (name.trim().isEmpty || url.trim().isEmpty) return;
    byUrl.putIfAbsent(url.trim(), () => {'name': name, 'url': url.trim()});
  }

  add(lesson['sourceName'], lesson['sourceUrl']);
  final sources = lesson['sources'];
  if (sources is List) {
    for (final source in sources) {
      if (source is Map) add(source['name'], source['url']);
    }
  }
  return byUrl.values.toList();
}
