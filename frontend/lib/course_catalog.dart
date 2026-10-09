class CourseLanguageAvailability {
  const CourseLanguageAvailability(this.availableUnits, this.totalUnits);
  final int availableUnits;
  final int totalUnits;
  bool get all => totalUnits > 0 && availableUnits == totalUnits;
  bool get some => availableUnits > 0 && !all;
}

/// Only advertised packs at each unit's latest version count as available.
/// A series parent's union of languages does not prove every part has them.
CourseLanguageAvailability courseLanguageAvailability(
  Map<String, dynamic> course,
  String language,
) {
  final parts = course['parts'] as List?;
  final units = parts ?? [course];
  var available = 0;
  for (final unit in units) {
    final packs = unit['packs'] as List? ?? const [];
    var latestVersion = 0;
    for (final pack in packs) {
      final version = (pack['version'] as num?)?.toInt() ?? 1;
      if (version > latestVersion) latestVersion = version;
    }
    if (packs.any(
      (pack) =>
          pack['language'] == language &&
          ((pack['version'] as num?)?.toInt() ?? 1) == latestVersion,
    )) {
      available++;
    }
  }
  return CourseLanguageAvailability(available, units.length);
}

/// Groups weekly packs into one discoverable course without changing pack IDs.
List<Map<String, dynamic>> groupCourses(List<Map<String, dynamic>> courses) {
  final result = <Map<String, dynamic>>[];
  final groups = <String, Map<String, dynamic>>{};
  for (final course in courses) {
    final match = RegExp(
      r'^(.*)-week-(\d+)$',
    ).firstMatch(course['id'] as String);
    final seriesId = course['seriesId'] as String? ?? match?.group(1);
    if (seriesId == null) {
      result.add(course);
      continue;
    }
    final group = groups.putIfAbsent(seriesId, () {
      final entry = <String, dynamic>{
        'id': seriesId,
        'created_at': course['created_at'],
        'category': course['category'] ?? 'General Learning',
        'title':
            course['seriesTitle'] ??
            (course['title'] as String).split(' — Week ').first,
        'description':
            course['seriesDescription'] ??
            'Learn at your own pace through a series of small offline lesson packs.',
        'lessonCount': 0,
        'packs': <Map<String, dynamic>>[],
        'parts': <Map<String, dynamic>>[],
      };
      result.add(entry);
      return entry;
    });
    (group['parts'] as List).add({
      ...course,
      'partIndex': course['partIndex'] ?? int.parse(match?.group(2) ?? '0'),
    });
    group['lessonCount'] =
        (group['lessonCount'] as int) + (course['lessonCount'] as int);
    final packs = group['packs'] as List;
    for (final pack in course['packs'] as List) {
      if (!packs.any((p) => p['language'] == pack['language'])) packs.add(pack);
    }
  }
  for (final group in groups.values) {
    (group['parts'] as List<Map<String, dynamic>>).sort(
      (a, b) => (a['partIndex'] as int).compareTo(b['partIndex'] as int),
    );
  }
  result.sort((a, b) {
    final aCreated = DateTime.tryParse(a['created_at']?.toString() ?? '');
    final bCreated = DateTime.tryParse(b['created_at']?.toString() ?? '');
    if (aCreated == null && bCreated != null) return 1;
    if (bCreated == null && aCreated != null) return -1;
    final dateOrder = aCreated == null || bCreated == null
        ? 0
        : bCreated.compareTo(aCreated);
    if (dateOrder != 0) return dateOrder;
    return (a['id'] as String).compareTo(b['id'] as String);
  });
  return result;
}
