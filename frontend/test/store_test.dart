import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:learn_anywhere/store.dart';

void main() {
  test(
    'development endpoints allow private addresses but reject public HTTP',
    () {
      for (final host in [
        '192.168.1.32',
        '10.1.2.3',
        '172.16.0.1',
        '127.0.0.1',
      ]) {
        expect(
          LearningStore.isAllowedEndpoint(Uri.parse('http://$host:8084')),
          isTrue,
        );
      }
      for (final url in [
        'http://8.8.8.8',
        'http://172.32.0.1',
        'http://example.com',
        'ftp://192.168.1.32',
      ]) {
        expect(LearningStore.isAllowedEndpoint(Uri.parse(url)), isFalse);
      }
      expect(
        LearningStore.isAllowedEndpoint(Uri.parse('https://example.com')),
        isTrue,
      );
    },
  );

  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory directory;
  late LearningStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('learning-test-');
    store = LearningStore(directory);
    await store.initialize();
  });
  test(
    'explained lesson preference is opt-in and persists across profile edits',
    () async {
      expect(store.preferExplained, isFalse);
      await store.saveLearnerProfile(null, '', '', explainedVersions: true);
      await store.database!.close();
      store = LearningStore(directory);
      await store.initialize();
      expect(store.preferExplained, isTrue);
      await store.saveLearnerProfile(null, '', '');
      expect(store.preferExplained, isTrue);
      await store.saveLearnerProfile(null, '', '', explainedVersions: false);
      expect(store.preferExplained, isFalse);
    },
  );
  test('auto download is opt-in and persists across restarts', () async {
    expect(store.autoDownload, isFalse);
    await store.setAutoDownload(true);
    await store.database!.close();
    store = LearningStore(directory);
    await store.initialize();
    expect(store.autoDownload, isTrue);
    await store.setAutoDownload(false);
    await store.database!.close();
    store = LearningStore(directory);
    await store.initialize();
    expect(store.autoDownload, isFalse);
  });
  test('saved languages are course scoped and update after deletion', () async {
    await store.savePack('fr', bundled: true);
    expect(store.savedLanguageCounts({'id': store.courseId}), {
      'en': 1,
      'fr': 1,
    });
    expect(store.savedLanguageCounts({'id': 'another-course'}), isEmpty);
    expect(
      store.savedLanguageCounts({
        'id': 'series',
        'parts': [
          {'id': store.courseId},
          {'id': 'another-course'},
        ],
      }),
      {'en': 1, 'fr': 1},
    );
    await store.removePack('fr');
    expect(store.savedLanguageCounts({'id': store.courseId}), {'en': 1});
    await store.database!.close();
    store = LearningStore(directory);
    await store.initialize();
    expect(store.savedLanguageCounts({'id': store.courseId}), {'en': 1});
  });
  test('variable lesson counts validate and complete the final task', () async {
    expect(LearningStore.hasValidLessonIds([]), isFalse);
    expect(
      LearningStore.hasValidLessonIds([
        {'id': 1},
      ]),
      isFalse,
    );
    for (final count in [1, 3, 8]) {
      expect(
        LearningStore.hasValidLessonIds(List.generate(count, (i) => {'id': i})),
        isTrue,
      );
    }
    final template = Map<String, dynamic>.from(store.lessons.first);
    store.pack['lessons'] = List.generate(3, (i) => {...template, 'id': i});
    store.progress.clear();
    store.taskComplete = false;
    store.safetyChecklist.addAll([0, 1, 2, 3]);
    for (var i = 0; i < 2; i++) {
      store.lessonProgress(i)['complete'] = true;
    }
    await store.finishTask();
    expect(store.taskComplete, isFalse);
    store.lessonProgress(2)['complete'] = true;
    await store.finishTask();
    expect(store.taskComplete, isTrue);
  });
  test('font size persists and is bounded', () async {
    await store.setFontScale(1.25);
    await store.database!.close();
    store = LearningStore(directory);
    await store.initialize();
    expect(store.fontScale, 1.25);
    await store.setFontScale(10);
    expect(store.fontScale, 1.4);
    await store.setFontScale(.1);
    expect(store.fontScale, .85);
    await expectLater(store.setFontScale(double.nan), throwsFormatException);
  });
  test('theme preference survives restarting the store', () async {
    expect(store.darkTheme, isFalse);
    await store.setDarkTheme(true);
    await store.database!.close();
    store = LearningStore(directory);
    await store.initialize();
    expect(store.darkTheme, isTrue);
  });
  tearDown(() async {
    await store.database?.close();
    await directory.delete(recursive: true);
  });
  test(
    'preferred language and onboarding completion persist offline',
    () async {
      expect(store.hasChosenLanguage, false);
      await store.choosePreferredLanguage('ar');
      await store.database!.close();
      store = LearningStore(directory);
      await store.initialize();
      expect(store.hasChosenLanguage, true);
      expect(store.preferredLanguage, 'ar');
      expect(store.appLanguage, 'ar');
      expect(store.lessonLanguage, 'en');
    },
  );
  test('missing course translation still saves preferred language', () async {
    store.catalog = [
      {
        'id': store.courseId,
        'packs': [
          {'language': 'en'},
        ],
      },
    ];
    await store.changeLanguages('fr', 'fr');
    expect(store.preferredLanguage, 'fr');
    expect(store.appLanguage, 'fr');
    expect(store.lessonLanguage, 'en');
    expect(store.packNotice, contains('preference is saved'));
    await store.database!.close();
    store = LearningStore(directory);
    await store.initialize();
    expect(store.preferredLanguage, 'fr');
    expect(store.lessonLanguage, 'en');
  });

  test('quiz can start without reading and never marks lessons read', () async {
    expect(store.isUnlocked(1), true);
    await store.answer(0, 0, 0);
    expect(store.answers(0), [0]);
    expect(store.isRead(0), false);
    await store.completeQuiz(0);
    expect(store.isUnlocked(1), true);
    await store.answer(0, 1, 1);
    await store.answer(0, 2, 2);
    await store.completeQuiz(0);
    expect(store.isUnlocked(1), true);
    expect(store.xp, 80);
    expect(store.isRead(0), false);
    expect(store.currentLesson, 0);
  });
  test('offline progress and quiz resume survive database reopening', () async {
    await store.readLesson(0);
    await store.answer(0, 0, 0);
    await store.database!.close();
    store = LearningStore(directory);
    await store.initialize();
    expect(store.answers(0), [0]);
    expect(store.lessonProgress(0)['read'], true);
    expect(store.xp, 10);
    expect(store.lessons.length, 5);
    expect(store.downloaded, contains('en'));
  });
  test('practice cannot farm XP or lock completed lessons', () async {
    await store.readLesson(0);
    for (var i = 0; i < 3; i++) {
      await store.answer(0, i, [0, 1, 2][i]);
    }
    await store.completeQuiz(0);
    await store.resetQuiz(0);
    for (var i = 0; i < 3; i++) {
      await store.answer(0, i, [0, 1, 2][i]);
    }
    await store.completeQuiz(0);
    expect(store.xp, 80);
    expect(store.isUnlocked(1), true);
  });
  test(
    'all answered questions unlock the next lesson regardless of score',
    () async {
      await store.readLesson(0);
      for (var i = 0; i < 3; i++) {
        await store.answer(0, i, [1, 2, 0][i]);
      }
      await store.completeQuiz(0);
      expect(store.score(0), 0);
      expect(store.isUnlocked(1), true);
      expect(store.xp, 50);
    },
  );
  test(
    'language conversion uses locally stored content and stable quiz answers',
    () async {
      await store.savePack('fr', bundled: true);
      await store.readLesson(0);
      await store.answer(0, 0, 0);
      await store.changeLanguages('en', 'fr');
      expect(store.appLanguage, 'fr');
      expect(store.lessons[0]['title'], 'Bienvenue dans la sécurité numérique');
      expect(store.answers(0), [0]);
      await store.database!.close();
      store = LearningStore(directory);
      await store.initialize();
      expect(store.lessonLanguage, 'fr');
      expect(store.lessons[0]['questions'].length, 3);
    },
  );
  test('final task needs all lessons and cannot award twice', () async {
    for (var i = 0; i < 4; i++) {
      await store.toggleTask(i, true);
    }
    await store.finishTask();
    expect(store.taskComplete, false);
    for (var lesson = 0; lesson < 5; lesson++) {
      await store.readLesson(lesson);
      final questions = store.lessons[lesson]['questions'] as List;
      for (var q = 0; q < 3; q++) {
        await store.answer(lesson, q, questions[q]['correct'] as int);
      }
      await store.completeQuiz(lesson);
    }
    await store.finishTask();
    await store.finishTask();
    expect(store.taskComplete, true);
    expect(store.xp, 500);
  });
}
