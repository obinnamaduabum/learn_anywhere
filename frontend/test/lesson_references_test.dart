import 'package:flutter_test/flutter_test.dart';
import 'package:learn_anywhere/lesson_references.dart';

void main() {
  test(
    'merged lessons keep all distinct references without repeating primary',
    () {
      final references = lessonReferences({
        'sourceName': 'Primary source',
        'sourceUrl': 'https://example.org/primary',
        'sources': [
          {'name': 'Primary source', 'url': 'https://example.org/primary'},
          {'name': 'Second source', 'url': 'https://example.org/second'},
          {
            'name': 'Duplicate second source',
            'url': 'https://example.org/second',
          },
        ],
      });
      expect(references, [
        {'name': 'Primary source', 'url': 'https://example.org/primary'},
        {'name': 'Second source', 'url': 'https://example.org/second'},
      ]);
    },
  );

  test('legacy packs retain their primary reference', () {
    expect(
      lessonReferences({
        'sourceName': 'Legacy source',
        'sourceUrl': 'https://example.org/legacy',
      }),
      [
        {'name': 'Legacy source', 'url': 'https://example.org/legacy'},
      ],
    );
  });
}
