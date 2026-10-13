import 'dart:convert';
import 'dart:io';
import 'package:learn_anywhere/store.dart';
import 'package:sqflite/sqflite.dart';

Future<void> seedFixtureLanguage(LearningStore store, String language) async {
  final content = await File(
    'test/fixtures/packs/$language.json',
  ).readAsString();
  await store.database!.insert('packs', {
    'pack_key': 'sample-course:1:$language',
    'course_id': 'sample-course',
    'version': 1,
    'language': language,
    'json': content,
    'saved_at': DateTime.now().toIso8601String(),
  }, conflictAlgorithm: ConflictAlgorithm.replace);
  await store.initialize();
}

Future<void> initializeFixture(LearningStore store) async {
  await store.initialize();
  if (store.pack.isEmpty) {
    await seedFixtureLanguage(store, 'en');
    store.courseId = 'sample-course';
    store.courseTitle = 'Digital Safety';
    store.courseVersion = 1;
    store.pack = jsonDecode(
      await File('test/fixtures/packs/en.json').readAsString(),
    );
  }
}
