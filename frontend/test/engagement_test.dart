import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:learn_anywhere/store.dart';
import 'package:learn_anywhere/engagement.dart';
import 'package:learn_anywhere/main.dart';
import 'package:learn_anywhere/local_coach.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory directory;
  late LearningStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('engagement-');
    store = LearningStore(directory);
    await store.initialize();
    store.catalog = [
      {
        'id': 'sample',
        'title': 'Sample',
        'category': 'Digital skills',
        'packs': [],
      },
    ];
  });
  tearDown(() async {
    await store.database!.close();
    await directory.delete(recursive: true);
  });

  test(
    'daily challenge deduplicates reading and practice without farming XP',
    () async {
      final xp = store.xp;
      await store.readLesson(0);
      await store.readLesson(0);
      expect(store.lessonsReadToday, 1);
      expect(store.pendingEvents, 1);
      expect(store.dailyChallengeComplete, true);
      await store.recordCheckpoint(0);
      await store.recordCheckpoint(0);
      expect(store.dailyPractice[store.todayKey]!.length, 1);
      expect(store.dailyChallengeComplete, true);
      expect(store.xp, xp);
      expect(store.answers(0), isEmpty);
      expect(store.pendingEvents, 1);
    },
  );

  test('goals, local profile and reading position survive restart', () async {
    await store.saveLearnerProfile(25, 'Non-binary', 'Digital skills');
    await store.setLearningGoals(2, 4, 'Digital skills');
    await store.readLesson(0);
    await store.recordCheckpoint(0);
    await store.saveReadingPosition(1, .45);
    await store.database!.close();
    store = LearningStore(directory);
    await store.initialize();
    expect(store.learnerAge, 25);
    expect(store.learnerGender, 'Non-binary');
    expect(store.hasCompletedLearnerProfile, true);
    expect(store.dailyLessonGoal, 2);
    expect(store.weeklyStudyGoal, 4);
    expect(store.lessonsReadToday, 1);
    expect(store.practicedToday, true);
    expect(store.lessonProgress(1)['readingFraction'], .45);
    await store.saveLearnerProfile(null, '', '');
    expect(store.learnerAge, isNull);
    expect(store.learnerGender, isEmpty);
  });

  test('bookmarks persist without reading or awarding XP', () async {
    final initialXp = store.xp;
    final initialEvents = store.pendingEvents;
    await store.toggleBookmark(0);
    expect(store.isBookmarked(0), true);
    expect(store.isRead(0), false);
    expect(store.xp, initialXp);
    expect(store.pendingEvents, initialEvents);
    await store.database!.close();
    store = LearningStore(directory);
    await store.initialize();
    expect(store.isBookmarked(0), true);
    await store.toggleBookmark(0);
    expect(store.isBookmarked(0), false);
  });

  test(
    'Discover course bookmarks persist independently of lesson bookmarks',
    () async {
      await store.toggleCourseBookmark('digital-safety-v1');
      expect(store.bookmarkedCourses, contains('digital-safety-v1'));
      expect(store.isBookmarked(0), false);
      await store.database!.close();
      store = LearningStore(directory);
      await store.initialize();
      expect(store.bookmarkedCourses, contains('digital-safety-v1'));
      await store.toggleCourseBookmark('digital-safety-v1');
      expect(store.bookmarkedCourses, isEmpty);
    },
  );

  testWidgets('removing a course bookmark immediately removes its saved row', (
    tester,
  ) async {
    await tester.runAsync(() => store.toggleCourseBookmark('sample'));
    await tester.pumpWidget(MaterialApp(home: BookmarksPage(store: store)));
    expect(find.byKey(const ValueKey('saved-course-sample')), findsOneWidget);
    await tester.tap(find.byTooltip('Remove course bookmark'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('saved-course-sample')), findsNothing);
    expect(store.bookmarkedCourses, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  test('invalid age and goals are rejected before saving', () async {
    await expectLater(
      store.saveLearnerProfile(121, 'Woman', ''),
      throwsArgumentError,
    );
    await expectLater(store.setLearningGoals(0, 8, ''), throwsArgumentError);
    expect(store.learnerAge, isNull);
    expect(store.dailyLessonGoal, 1);
  });

  test(
    'recommendations rank interest and language and ignore demographics',
    () async {
      store.learningInterest = 'Digital skills';
      final courses = [
        {
          'id': store.courseId,
          'title': 'Current',
          'category': 'Digital skills',
          'packs': [],
        },
        {
          'id': 'other',
          'title': 'Other',
          'category': 'Business',
          'packs': [
            {'language': 'en'},
          ],
        },
        {
          'id': 'match',
          'title': 'Match',
          'category': 'Digital skills',
          'packs': [
            {'language': 'en'},
          ],
        },
      ];
      final before = store
          .recommendedCourses(courses)
          .map((c) => c['id'])
          .toList();
      store.learnerAge = 12;
      store.learnerGender = 'Man';
      expect(
        store.recommendedCourses(courses).map((c) => c['id']).toList(),
        before,
      );
      expect(before.first, 'match');
      expect(before, isNot(contains(store.courseId)));
    },
  );

  test(
    'local personalization requires enough distinct days and respects feedback',
    () async {
      await store.setAdaptiveCoaching(true);
      final now = DateTime.now();
      for (var i = 0; i < 5; i++) {
        final day = DateTime(now.year, now.month, now.day - i);
        store.coachingActivity.add({
          'key': '$i',
          'day': LearningStore.dateKey(day),
          'hour': 17,
          'kind': 'read',
        });
      }
      expect(CoachSuggestion.forStore(store).preferredHour, 17);
      final before = CoachSuggestion.forStore(store);
      await store.rateCoaching(before.strategy, false);
      await store.rateCoaching(before.strategy, false);
      expect(store.coachingFeedback[before.strategy]!['unhelpful'], 1);
      expect(CoachSuggestion.forStore(store).strategy, isNot(before.strategy));
      await store.setAdaptiveCoaching(false);
      final count = store.coachingActivity.length;
      await store.readLesson(0);
      expect(store.coachingActivity.length, count);
      await store.forgetCoachingPatterns();
      expect(store.coachingActivity, isEmpty);
      expect(store.coachingFeedback, isEmpty);
    },
  );

  testWidgets('Discover search works with all categories selected', (
    tester,
  ) async {
    store.catalog = [
      {
        'id': 'a',
        'title': 'Tech course',
        'description': 'Tech',
        'category': 'Technology',
        'lessonCount': 5,
        'packs': [
          {'language': 'en', 'version': 1},
        ],
      },
      {
        'id': 'b',
        'title': 'Business course',
        'description': 'Business',
        'category': 'Business',
        'lessonCount': 5,
        'packs': [
          {'language': 'en', 'version': 1},
        ],
      },
    ];
    await tester.pumpWidget(MaterialApp(home: DiscoverPage(store: store)));
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('discover-category-all')))
          .selected,
      isTrue,
    );
    await tester.enterText(find.byType(TextField), 'Tech course');
    await tester.pumpAndSettle();
    expect(
      find
          .text('Tech course', skipOffstage: true)
          .evaluate()
          .where((e) => e.widget is Text)
          .length,
      1,
    );
    expect(find.text('Business course'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'lesson resumes at saved reading position without completing it',
    (tester) async {
      await tester.runAsync(() => store.saveReadingPosition(0, .4));
      await tester.pumpWidget(
        MaterialApp(home: LessonPage(store: store, id: 0)),
      );
      await tester.pumpAndSettle();
      final list = tester.widget<ListView>(find.byType(ListView).first);
      expect(list.controller!.offset, greaterThan(0));
      expect(store.isRead(0), false);
      expect(store.pendingEvents, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    },
  );

  testWidgets(
    'checkpoint reveals recap and records practice, not assessment answers',
    (tester) async {
      final prompt = RecallPrompt.fromLesson(store.lessons[0])!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LessonCheckpoint(store: store, id: 0),
            ),
          ),
        ),
      );
      await tester.tap(find.text(prompt.options.first));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(store.practicedToday, true);
      expect(store.answers(0), isEmpty);
      expect(store.pendingEvents, 0);
      await tester.tap(find.byKey(const Key('checkpoint-reveal-0')));
      await tester.pump();
      expect(find.text('Hide recap'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('startup asks for optional profile after language selection', (
    tester,
  ) async {
    store.hasChosenLanguage = true;
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: store,
          builder: (_, _) => StartupPage(store: store, showLogo: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('learner-date-of-birth')), findsOneWidget);
    expect(find.text('Learning categories'), findsNothing);
    await tester.tap(find.text('Skip for now'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(store.hasCompletedLearnerProfile, true);
    expect(store.learnerAge, isNull);
    expect(store.learnerGender, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  test('date of birth persists and rejects future dates', () async {
    await store.saveLearnerProfile(
      null,
      '',
      '',
      dateOfBirth: DateTime(2000, 2, 29),
    );
    await store.database!.close();
    store = LearningStore(directory);
    await store.initialize();
    expect(store.learnerDateOfBirth, DateTime(2000, 2, 29));
    await expectLater(
      store.saveLearnerProfile(
        null,
        '',
        '',
        dateOfBirth: DateTime.now().add(const Duration(days: 1)),
      ),
      throwsArgumentError,
    );
    await store.saveLearnerProfile(null, '', '');
    expect(store.learnerDateOfBirth, isNull);
  });

  testWidgets('daily challenge remains usable on a small RTL screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: LearningMomentum(store: store, onContinue: () {}),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('edit-learning-goals')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
