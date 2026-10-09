import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:learn_anywhere/identity.dart';
import 'package:learn_anywhere/store.dart';

class MemoryIdentity implements IdentityStorage {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    token = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('activity outbox survives restart and a failed upload', () async {
    final dir = await Directory.systemTemp.createTemp('learning-outbox-');
    final identity = MemoryIdentity();
    var store = LearningStore(
      dir,
      baseUrl: 'http://127.0.0.1:9',
      identity: identity,
    );
    await store.initialize();
    await store.readLesson(0);
    await store.answer(0, 0, 0);
    expect(store.pendingEvents, 2);
    final queued = await store.database!.query('outbox');
    await store.database!.close();
    store = LearningStore(
      dir,
      baseUrl: 'http://127.0.0.1:9',
      identity: identity,
    );
    await store.initialize();
    expect(await store.database!.query('outbox'), queued);
    await store.sync();
    expect(store.syncError, isNotNull);
    expect(store.pendingEvents, 2);
    expect(store.xp, 10);
    await store.database!.close();
    await dir.delete(recursive: true);
  });

  const liveApi = String.fromEnvironment('LEARNING_TEST_API');
  test(
    'Flutter SQLite activities sync to live Quarkus and PostgreSQL',
    () async {
      final dir = await Directory.systemTemp.createTemp('learning-live-');
      final identity = MemoryIdentity();
      final store = LearningStore(dir, baseUrl: liveApi, identity: identity);
      await store.initialize();
      await store.refreshCatalog();
      expect(store.catalogError, isNull);
      expect(store.catalog, isNotEmpty);
      await store.savePack('en');
      await store.changeLanguages('en', 'en');
      expect(store.pack['_origin'], 'Backend');
      await store.readLesson(0);
      for (var i = 0; i < 3; i++) {
        await store.answer(0, i, [0, 1, 2][i]);
      }
      await store.completeQuiz(0);
      expect(store.pendingEvents, 5);
      await store.sync();
      expect(store.syncError, isNull);
      expect(store.pendingEvents, 0);
      expect(store.confirmedPoints, 80);
      await store.resetQuiz(0);
      for (var i = 0; i < 3; i++) {
        await store.answer(0, i, [0, 1, 2][i]);
      }
      await store.sync();
      expect(store.syncError, isNull);
      expect(store.confirmedPoints, 80);
      final digital = store.catalog.firstWhere(
        (c) => c['id'] == 'digital-safety-v1',
      );
      final budgeting = store.catalog.firstWhere(
        (c) => c['id'] == 'everyday-budgeting-v1',
      );
      await store.selectCourse(budgeting);
      expect(store.completedCount, 0);
      await store.readLesson(0);
      await store.answer(
        0,
        0,
        (store.lessons[0]['questions'] as List)[0]['correct'] as int,
      );
      expect(store.pendingEvents, 2);
      await store.selectCourse(digital);
      expect(store.isComplete(0), true);
      await store.sync();
      expect(store.syncError, isNull);
      expect(store.confirmedPoints, 90);
      await store.selectCourse(budgeting);
      expect(store.answers(0).length, 1);
      expect(store.isComplete(0), false);
      await store.database!.close();
      await dir.delete(recursive: true);
    },
    skip: liveApi.isEmpty,
  );
}
