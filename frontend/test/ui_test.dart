import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_anywhere/main.dart';
import 'package:learn_anywhere/course_catalog.dart';
import 'package:learn_anywhere/store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class RefreshingCatalogStore extends LearningStore {
  RefreshingCatalogStore(super.directory);
  final pendingCatalog = Completer<void>();
  void updateCatalog(List<Map<String, dynamic>> value) {
    catalog = value;
    notifyListeners();
  }

  @override
  Future<void> refreshCatalog() async {
    refreshing = true;
    notifyListeners();
    await pendingCatalog.future;
    catalog = [
      {
        'id': 'new-course',
        'title': 'Newly published course',
        'description': 'Updated content',
        'lessonCount': 5,
        'packs': [
          {'language': 'en', 'version': 2},
        ],
      },
    ];
    refreshing = false;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory dir;
  late LearningStore store;
  testWidgets('Discover category filters combine with search and reset', (
    tester,
  ) async {
    final catalogStore = RefreshingCatalogStore(Directory.systemTemp);
    catalogStore.catalog = [
      {
        'id': 'ai',
        'title': 'AI course',
        'description': 'Learn useful tools',
        'category': 'AI',
        'lessonCount': 5,
        'packs': [
          {'language': 'en', 'version': 2},
        ],
      },
      {
        'id': 'money',
        'title': 'Budgeting course',
        'description': 'Learn useful tools',
        'category': 'Money',
        'lessonCount': 5,
        'packs': [
          {'language': 'en', 'version': 1},
        ],
      },
    ];
    await tester.pumpWidget(
      MaterialApp(home: DiscoverPage(store: catalogStore)),
    );
    await tester.tap(find.byKey(const Key('discover-category-Money')));
    await tester.pumpAndSettle();
    expect(find.text('AI course'), findsNothing);
    expect(find.text('Budgeting course'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  AI  ');
    await tester.pumpAndSettle();
    expect(find.text('Budgeting course'), findsNothing);
    await tester.tap(find.byKey(const Key('discover-category-all')));
    await tester.pumpAndSettle();
    expect(find.text('AI course'), findsOneWidget);
    expect(find.text('English · Available'), findsOneWidget);
    catalogStore.preferredLanguage = 'fr';
    catalogStore.updateCatalog(catalogStore.catalog);
    await tester.pumpAndSettle();
    expect(
      find.text('Français · Not available for this version'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    catalogStore.dispose();
  });
  testWidgets(
    'Discover refresh shows loading and updated catalog without navigation',
    (tester) async {
      final refreshingStore = RefreshingCatalogStore(Directory.systemTemp);
      await tester.pumpWidget(
        MaterialApp(home: DiscoverPage(store: refreshingStore)),
      );
      expect(find.byType(RefreshIndicator), findsOneWidget);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      refreshingStore.pendingCatalog.complete();
      await tester.pumpAndSettle();
      expect(find.text('Newly published course'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox());
      refreshingStore.dispose();
    },
  );
  testWidgets(
    'an open series uses refreshed parts rather than its original catalog snapshot',
    (tester) async {
      final updating = RefreshingCatalogStore(Directory.systemTemp);
      Map<String, dynamic> series(String title, int version) => {
        'id': 'series',
        'title': 'Learning series',
        'lessonCount': 5,
        'parts': [
          {
            'id': 'part',
            'title': title,
            'description': 'Part description',
            'partIndex': 1,
            'lessonCount': 5,
            'packs': [
              {'language': 'en', 'version': version},
            ],
          },
        ],
      };
      final old = series('Original part', 1);
      await tester.pumpWidget(
        MaterialApp(
          home: SeriesPage(store: updating, course: old),
        ),
      );
      expect(find.text('Original part'), findsOneWidget);
      updating.updateCatalog([series('Updated part', 2)]);
      await tester.pumpAndSettle();
      expect(find.text('Updated part'), findsOneWidget);
      expect(find.text('Original part'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      updating.dispose();
    },
  );
  testWidgets('lesson floating explanation button opens saved explanation', (
    tester,
  ) async {
    store.companionHelp[store.explanationPackKey] = {
      'explanationVersion': 1,
      'lessons': List.generate(
        5,
        (id) => {'id': id, 'text': 'Saved explanation $id'},
      ),
    };
    await tester.pumpWidget(MaterialApp(home: LessonPage(store: store, id: 0)));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithIcon(FloatingActionButton, Icons.lightbulb_outline),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Explain this'));
    await tester.pumpAndSettle();
    expect(find.text('Saved explanation 0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('learning-ui-');
    store = LearningStore(dir);
    await store.initialize();
    store.hasChosenLanguage = true;
    store.hasCompletedLearnerProfile = true;
  });
  tearDown(() async {
    await store.database!.close();
    await dir.delete(recursive: true);
  });
  testWidgets('notification icon shows live download progress and completion', (
    tester,
  ) async {
    store.downloadActivity.insert(0, {
      'key': 'ai:1:fr',
      'courseId': 'ai',
      'title': 'Understanding AI',
      'language': 'fr',
      'status': 'downloading',
      'received': 50,
      'total': 100,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DownloadNotificationButton(
            store: store,
            courseIds: {'ai'},
            title: 'Understanding AI',
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Download notifications'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Understanding AI'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.descendant(
              of: find.byType(DownloadActivityPage),
              matching: find.byType(LinearProgressIndicator),
            ),
          )
          .value,
      .5,
    );
    store.finishDownload('ai', 1, 'fr');
    await tester.pump();
    expect(find.text('Ready offline'), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(DownloadActivityPage),
        matching: find.byType(LinearProgressIndicator),
      ),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('language download keeps spinner and progress until completion', (
    tester,
  ) async {
    final downloading = SlowLanguageStore(dir)..lessonLanguage = 'fr';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showLanguages(context, downloading),
              child: const Text('Open language'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply languages'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .5,
    );
    expect(tester.widget<PopScope>(find.byType(PopScope).last).canPop, isFalse);
    expect(find.text('50% downloaded'), findsOneWidget);
    downloading.ready.complete();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(LanguagePanel), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('profile theme control switches to dark teal', (tester) async {
    await tester.pumpWidget(LearningApp(store: store, showStartupLogo: false));
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Teal dark'),
      350,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('Teal dark'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Teal dark'));
      await store.save();
    });
    await tester.pumpAndSettle();
    expect(store.darkTheme, isTrue);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(
      Theme.of(tester.element(find.text('Teal dark'))).brightness,
      Brightness.dark,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('logo loader remains visible until initialization finishes', (
    tester,
  ) async {
    final ready = Completer<LearningStore>();
    await tester.pumpWidget(AppBootstrap(initialize: () => ready.future));
    expect(find.byType(LearnAnywhereLogo), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(AppLoadingScreen), findsOneWidget);
    ready.complete(store);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1250));
    expect(find.byType(HomeShell), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('startup shows logo before asking for preferred language', (
    tester,
  ) async {
    store.hasChosenLanguage = false;
    await tester.pumpWidget(LearningApp(store: store));
    expect(find.byType(LearnAnywhereLogo), findsOneWidget);
    expect(find.text('Choose your preferred language'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1250));
    expect(find.byType(LearnAnywhereLogo), findsNothing);
    expect(find.text('Choose your preferred language'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('first launch asks for all seven preferred languages', (
    tester,
  ) async {
    store.hasChosenLanguage = false;
    tester.view.physicalSize = const Size(750, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(LearningApp(store: store, showStartupLogo: false));
    expect(find.text('Choose your preferred language'), findsOneWidget);
    for (final name in LearningStore.lessonLanguages.values) {
      expect(find.text(name), findsOneWidget);
    }
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('English'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test('weekly packs form one sorted course with deduplicated languages', () {
    final grouped = groupCourses(
      List.generate(
        16,
        (i) => {
          'id': 'understanding-ai-week-${16 - i}',
          'title': 'Understanding AI — Week ${16 - i}: Topic',
          'description': 'Topic',
          'lessonCount': 5,
          'packs': [
            {'language': 'en', 'version': 1},
          ],
        },
      ),
    );
    expect(grouped.length, 1);
    expect(grouped.single['title'], 'Understanding AI');
    expect(grouped.single['lessonCount'], 80);
    expect((grouped.single['packs'] as List).length, 1);
    expect((grouped.single['parts'] as List).first['partIndex'], 1);
  });
  testWidgets('series opens its parts without downloading a pack', (
    tester,
  ) async {
    final course = groupCourses([
      {
        'id': 'understanding-ai-week-01',
        'title': 'Understanding AI — Week 1: Recognising AI',
        'description': 'Topic',
        'lessonCount': 5,
        'packs': [
          {'language': 'en'},
        ],
      },
    ]).single;
    await tester.pumpWidget(
      MaterialApp(
        home: SeriesPage(store: store, course: course),
      ),
    );
    expect(find.text('Understanding AI'), findsOneWidget);
    expect(
      find.text('Understanding AI — Week 1: Recognising AI'),
      findsOneWidget,
    );
    expect(store.courseId, 'digital-safety-v1');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('home, downloads and language panel render on a small iPhone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(LearningApp(store: store, showStartupLogo: false));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Your learning adventure'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.download_outlined));
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.text('Lessons, answers and progress saved offline'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(LanguageButton));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Preferred language'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('final quiz numbering continues across lesson groups', (
    tester,
  ) async {
    for (final id in [0, 1, 4]) {
      await tester.pumpWidget(
        MaterialApp(
          home: QuizPage(
            key: ValueKey(id),
            store: store,
            id: id,
            finalAssessment: true,
          ),
        ),
      );
      final preceding = store.lessons
          .take(id)
          .fold<int>(
            0,
            (sum, lesson) => sum + (lesson['questions'] as List).length,
          );
      final total = store.lessons.fold<int>(
        0,
        (sum, lesson) => sum + (lesson['questions'] as List).length,
      );
      expect(find.text('${preceding + 1} of $total'), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('quiz hides feedback until completion and offers answer review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => store.readLesson(0));
    await tester.pumpWidget(MaterialApp(home: QuizPage(store: store, id: 0)));
    await tester.pump();
    final check = tester.widget<FilledButton>(find.byType(FilledButton).first);
    expect(check.onPressed, isNull);
    await tester.tap(find.text('A screen lock'));
    await tester.pump();
    expect(
      tester.getRect(find.byType(FilledButton)).bottom,
      lessThanOrEqualTo(667),
    );
    await tester.tap(find.text('Next question'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Nice work!'), findsNothing);
    expect(
      find.text(store.lessons[0]['questions'][0]['explanation'] as String),
      findsNothing,
    );
    expect(store.answers(0), [0]);
    expect(store.isUnlocked(1), true);
    expect(
      find.text('What helps fix known software problems?'),
      findsOneWidget,
    );
    await tester.runAsync(() async {
      for (var i = 1; i < 3; i++) {
        final question = store.lessons[0]['questions'][i] as Map;
        await store.answer(0, i, question['correct'] as int);
      }
      await store.completeQuiz(0);
    });
    await tester.pumpWidget(
      MaterialApp(home: QuizResultPage(store: store, id: 0)),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.scrollUntilVisible(find.text('3 / 3 correct'), 180);
    expect(find.text('3 / 3 correct'), findsOneWidget);
    expect(
      find.text(store.lessons[0]['questions'][0]['explanation'] as String),
      findsNothing,
    );
    await tester.scrollUntilVisible(find.text('Review answers'), 220);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review answers'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.scrollUntilVisible(
      find.text('Your answer: A screen lock'),
      100,
    );
    expect(find.text('Your answer: A screen lock'), findsOneWidget);
    expect(find.text('Correct answer: A screen lock'), findsOneWidget);
    expect(
      find.text(store.lessons[0]['questions'][0]['explanation'] as String),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

class SlowLanguageStore extends LearningStore {
  SlowLanguageStore(super.directory);
  final ready = Completer<void>();
  @override
  Set<String> get availablePackLanguages => {'en', 'fr'};
  @override
  Future<void> changeLanguages(String app, String lesson) async {
    packDownloadProgress = .5;
    notifyListeners();
    await ready.future;
  }
}
