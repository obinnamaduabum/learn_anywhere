import 'package:flutter_test/flutter_test.dart';
import 'package:learn_anywhere/course_catalog.dart';

void main() {
  test('language availability uses every part at its current version', () {
    Map<String, dynamic> part(List<Map<String, dynamic>> packs) => {
      'packs': packs,
    };
    final series = <String, dynamic>{
      'packs': [
        {'language': 'fr', 'version': 2},
      ],
      'parts': [
        part([
          {'language': 'en', 'version': 2},
          {'language': 'fr', 'version': 2},
        ]),
        part([
          {'language': 'en', 'version': 2},
          {'language': 'fr', 'version': 1},
        ]),
      ],
    };
    final french = courseLanguageAvailability(series, 'fr');
    expect(french.some, isTrue);
    expect(french.availableUnits, 1);
    expect(french.totalUnits, 2);
    expect(courseLanguageAvailability(series, 'en').all, isTrue);
    expect(courseLanguageAvailability(series, 'ar').availableUnits, 0);
    expect(courseLanguageAvailability({'parts': []}, 'en').all, isFalse);
    expect(
      courseLanguageAvailability(
        part([
          {'language': 'en', 'version': 2},
        ]),
        'en',
      ).all,
      isTrue,
    );
  });
  test('catalog uses newest creation first, stable ties and undated last', () {
    final result = groupCourses([
      {'id': 'old', 'created_at': '2026-01-01T00:00:00Z'},
      {'id': 'unknown'},
      {'id': 'b', 'created_at': '2026-02-01T00:00:00Z'},
      {'id': 'a', 'created_at': '2026-02-01T00:00:00Z'},
    ]);
    expect(result.map((course) => course['id']), ['a', 'b', 'old', 'unknown']);
  });
}
