import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_anywhere/main.dart';
import 'package:learn_anywhere/lesson_audio.dart';
import 'package:learn_anywhere/course_catalog.dart';
import 'package:learn_anywhere/store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SwipeLessonStore extends LearningStore {
  SwipeLessonStore() : super(Directory.systemTemp);
  int reads = 0;
  @override
  Future<void> readLesson(int id) async {
    reads++;
    lessonProgress(id)['read'] = true;
    notifyListeners();
  }

  @override
  Future<void> saveReadingPosition(int id, double fraction) async {}
}

class ExplanationUiStore extends SwipeLessonStore {
  final pending = Completer<void>();
  int explanationRequests = 0;
  @override
  Future<void> loadLessonExplanation(int id) async {
    explanationRequests++;
    await pending.future;
    companionHelp[companionCacheKey(id, 'explain')] = {
      'text': 'New AI explanation',
      'suggestions': <String>[],
    };
    notifyListeners();
  }
}

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

class AutoDownloadUiStore extends LearningStore {
  AutoDownloadUiStore() : super(Directory.systemTemp);
  final savedLanguages = <String>[];
  final ready = Completer<void>();
  bool failDownload = false;
  final savedSeriesLanguages = <String>{};
  @override
  bool isSeriesSaved(Map<String, dynamic> course) =>
      savedSeriesLanguages.contains(preferredLanguage);
  @override
  Future<void> setAutoDownload(bool value) async {
    autoDownload = value;
    notifyListeners();
  }

  @override
  Future<void> saveSeries(Map<String, dynamic> course) async {
    savedLanguages.add(preferredLanguage);
    await ready.future;
    if (failDownload) {
      throw const SocketException('private backend unavailable');
    }
    savedSeriesLanguages.add(preferredLanguage);
  }

  void changed() => notifyListeners();
}

void main() {
  testWidgets('profile identifies course and uses actual lesson total', (
    tester,
  ) async {
    final selected = LearningStore(Directory.systemTemp);
    selected.courseTitle = 'Short AI course';
    selected.pack = {
      'title': 'Short AI course',
      'lessons': [
        {'title': 'One'},
        {'title': 'Two'},
      ],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProgressPage(store: selected)),
      ),
    );
    expect(find.text('Short AI course'), findsOneWidget);
    expect(find.text('0/2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    selected.dispose();
  });
  test('reader adapts legacy quiz navigation without changing source text', () {
    const original =
        'Learn the idea.\n\nComplete all three quiz questions before moving on.';
    expect(
      lessonReadingText(original),
      'Learn the idea.\n\nRead all lessons in this part, then take the final quiz.',
    );
    for (final phrase in [
      'Then complete all three quiz questions to unlock the next lesson.',
      'Complete all three quiz questions to unlock the next lesson.',
    ]) {
      expect(
        lessonReadingText(phrase),
        'Read all lessons in this part, then take the final quiz.',
      );
    }
    expect(original, contains('Complete all three quiz questions'));
  });
  testWidgets(
    'reading sections retain multilingual headings and paragraph text',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LessonReadingBody(
                text:
                    'First paragraph.\n\nOffline practice: Keep this exact activity.\n\nRécapitulatif: Gardez ce texte.\n\nمراجعة: احتفظ بهذا النص.',
              ),
            ),
          ),
        ),
      );
      for (final text in [
        'First paragraph.',
        'Offline practice:',
        'Keep this exact activity.',
        'Récapitulatif:',
        'Gardez ce texte.',
        'مراجعة:',
        'احتفظ بهذا النص.',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'course overview has one toolbar language action and dynamic contents',
    (tester) async {
      final overview = LearningStore(Directory.systemTemp);
      overview.pack = {
        'lessons': [
          {'title': 'First topic'},
          {'title': 'Second topic'},
        ],
      };
      overview.progress[0] = {'read': true};
      await tester.pumpWidget(MaterialApp(home: CoursePage(store: overview)));
      expect(find.byType(LanguageButton), findsOneWidget);
      expect(find.text('Course contents'), findsOneWidget);
      expect(find.text('2 lessons · 1 read'), findsOneWidget);
      expect(find.text('First topic'), findsOneWidget);
      expect(find.text('Second topic'), findsOneWidget);
      expect(
        find.textContaining('Audio and video are optional future formats'),
        findsNothing,
      );
      expect(find.text('Small steps. Real skills.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      overview.dispose();
    },
  );

  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory dir;
  late LearningStore store;
  Map<String, dynamic> autoSeries() => {
    'id': 'auto-series',
    'title': 'Auto series',
    'lessonCount': 5,
    'parts': [
      {
        'id': 'auto-part',
        'title': 'Auto part',
        'partIndex': 1,
        'lessonCount': 5,
        'packs': [
          {'language': 'en', 'version': 1},
          {'language': 'fr', 'version': 1},
        ],
      },
    ],
  };
  testWidgets(
    'auto-download is opt-in and saves opened series once per selected language',
    (tester) async {
      final automatic = AutoDownloadUiStore();
      await tester.pumpWidget(
        MaterialApp(
          home: SeriesPage(store: automatic, course: autoSeries()),
        ),
      );
      await tester.pumpAndSettle();
      expect(automatic.savedLanguages, isEmpty);
      await automatic.setAutoDownload(true);
      await tester.pump();
      await tester.pump();
      expect(automatic.savedLanguages, ['en']);
      expect(find.text('Saving series…'), findsOneWidget);
      automatic.changed();
      await tester.pump();
      expect(automatic.savedLanguages, ['en']);
      automatic.ready.complete();
      await tester.pumpAndSettle();
      automatic.changed();
      await tester.pumpAndSettle();
      expect(automatic.savedLanguages, ['en']);
      automatic.preferredLanguage = 'fr';
      automatic.changed();
      await tester.pumpAndSettle();
      expect(automatic.savedLanguages, ['en', 'fr']);
      await tester.pumpWidget(const SizedBox());
      automatic.dispose();
    },
  );
  testWidgets(
    'series save button hides only when selected language is fully saved',
    (tester) async {
      final saving = AutoDownloadUiStore();
      await tester.pumpWidget(
        MaterialApp(
          home: SeriesPage(store: saving, course: autoSeries()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Save all parts offline'), findsOneWidget);
      saving.savedSeriesLanguages.add('en');
      saving.changed();
      await tester.pumpAndSettle();
      expect(find.text('Save all parts offline'), findsNothing);
      saving.preferredLanguage = 'fr';
      saving.changed();
      await tester.pumpAndSettle();
      expect(find.text('Save all parts offline'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      saving.dispose();
    },
  );
  testWidgets(
    'automatic offline failure stays inline and preserves readable part actions',
    (tester) async {
      final automatic = AutoDownloadUiStore()
        ..autoDownload = true
        ..failDownload = true;
      automatic.ready.complete();
      await tester.pumpWidget(
        MaterialApp(
          home: SeriesPage(store: automatic, course: autoSeries()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Could not save every part. Saved lessons remain available; reconnect to retry.',
        ),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Auto part'), findsOneWidget);
      expect(find.text('Retry download'), findsOneWidget);
      automatic.changed();
      await tester.pumpAndSettle();
      expect(automatic.savedLanguages, ['en']);
      await tester.pumpWidget(const SizedBox());
      automatic.dispose();
    },
  );
  testWidgets(
    'Profile auto-download switch starts off and enables the opt-in',
    (tester) async {
      final automatic = AutoDownloadUiStore();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProgressPage(store: automatic)),
        ),
      );
      final switchFinder = find.byKey(const Key('auto-download-setting'));
      await tester.scrollUntilVisible(
        switchFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(switchFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(automatic.autoDownload, isTrue);
      await tester.pumpWidget(const SizedBox());
      automatic.dispose();
    },
  );
  testWidgets(
    'cached series remains navigable through the app with backend unavailable',
    (tester) async {
      await tester.runAsync(() async {
        await store.database!.close();
        store = LearningStore(dir, baseUrl: 'http://127.0.0.1:9');
        await store.initialize();
        store.selectedCourseIds.add(store.courseId);
        final cachedPack =
            jsonDecode(jsonEncode(store.pack)) as Map<String, dynamic>;
        cachedPack.addAll({'id': 'saved-part', 'version': 1, 'language': 'en'});
        cachedPack['lessons'][0]['title'] = 'Saved offline lesson';
        await store.database!.insert('packs', {
          'pack_key': 'saved-part:1:en',
          'course_id': 'saved-part',
          'version': 1,
          'language': 'en',
          'json': jsonEncode(cachedPack),
          'saved_at': DateTime.now().toIso8601String(),
        });
        store.catalog = [
          {
            'id': 'saved-series',
            'title': 'Saved offline series',
            'description': 'Cached lessons',
            'lessonCount': 5,
            'category': 'AI',
            'packs': [
              {'language': 'en', 'version': 2},
            ],
            'parts': [
              {
                'id': 'saved-part',
                'title': 'Saved first part',
                'description': 'Cached lesson pack',
                'partIndex': 1,
                'lessonCount': 5,
                'packs': [
                  {'language': 'en', 'version': 2},
                ],
              },
            ],
          },
        ];
        store.hasChosenLanguage = true;
        store.hasCompletedLearnerProfile = true;
        store.autoReadAloud = false;
      });
      await tester.pumpWidget(
        LearningApp(store: store, showStartupLogo: false),
      );
      await tester.runAsync(() async {
        await store.refreshCatalog();
        await store.sync();
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('View series'),
        240,
        scrollable: find
            .descendant(
              of: find.byType(DiscoverPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.text('View series'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View series'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Saved first part'));
        final deadline = DateTime.now().add(const Duration(seconds: 3));
        while (store.courseId != 'saved-part' &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(store.courseId, 'saved-part');
      });
      final routeDeadline = DateTime.now().add(const Duration(seconds: 5));
      while (find.byType(CoursePage).evaluate().isEmpty &&
          DateTime.now().isBefore(routeDeadline)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(find.byType(CoursePage), findsOneWidget);
      await tester.pumpAndSettle();
      expect(store.courseVersion, 1);
      await tester.tap(find.text('Saved offline lesson'));
      await tester.pumpAndSettle();
      expect(find.byType(LessonPage), findsOneWidget);
      expect(find.text('Saved offline lesson'), findsOneWidget);
      expect(
        find.textContaining('Could not complete this action'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final error in [
    const SocketException('backend http://private-service is unreachable'),
    TimeoutException('private service timeout'),
  ]) {
    testWidgets(
      'offline action shows saved-learning guidance for ${error.runtimeType}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => safely(context, () async => throw error),
                  child: const Text('Open part'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open part'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'This part is not saved yet. Reconnect to download it; saved lessons remain available.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('private-service'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('expected content availability message is preserved', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => safely(
                context,
                () async => throw const FormatException(
                  'This part is not downloaded yet.',
                ),
              ),
              child: const Text('Open part'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open part'));
    await tester.pumpAndSettle();
    expect(find.text('This part is not downloaded yet.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'language actions are icon-only with a localized current-language tooltip',
    (tester) async {
      store.appLanguage = 'fr';
      store.preferredLanguage = 'fr';
      store.lessonLanguage = 'fr';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: [LanguageButton(store: store)]),
          ),
        ),
      );
      final action = find.descendant(
        of: find.byType(LanguageButton),
        matching: find.byType(IconButton),
      );
      expect(action, findsOneWidget);
      expect(tester.widget<IconButton>(action).tooltip, 'Langue: Français');
      expect(find.text('Français'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byType(LanguagePanel), findsOneWidget);
      expect(find.text('Français'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Discover has compact course categories without filters and uses readable title sizing',
    (tester) async {
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
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(CourseCategoryLabel), findsWidgets);
      expect(tester.widget<Text>(find.text('AI course')).style!.fontSize, 20);
      expect(find.text('AI'), findsOneWidget);
      expect(find.byIcon(Icons.category_outlined), findsNothing);
      expect(find.text('Recommended courses are marked below.'), findsNothing);
      expect(find.text('Recommended'), findsNothing);
      await tester.enterText(find.byType(TextField), '  AI  ');
      await tester.pumpAndSettle();
      expect(find.text('Budgeting course'), findsNothing);
      expect(find.text('AI course'), findsOneWidget);
      expect(find.text('English'), findsNothing);
      expect(find.text('English · Available'), findsNothing);
      expect(find.byIcon(Icons.translate), findsNothing);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Budgeting course'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.enterText(find.byType(TextField), 'AI');
      await tester.pumpAndSettle();
      catalogStore.preferredLanguage = 'fr';
      catalogStore.updateCatalog(catalogStore.catalog);
      await tester.pumpAndSettle();
      expect(find.text('Français'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      catalogStore.dispose();
    },
  );
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
  testWidgets(
    'explanation toggle stays loading and prevents duplicate generation',
    (tester) async {
      final selected = ExplanationUiStore()..pack = store.pack;
      await tester.pumpWidget(
        MaterialApp(home: LessonPage(store: selected, id: 0)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNull,
      );
      expect(
        find.descendant(
          of: find.byType(FloatingActionButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(selected.explanationRequests, 1);
      selected.pending.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<LessonReadingBody>(find.byType(LessonReadingBody)).text,
        'New AI explanation',
      );
      await tester.tap(find.byTooltip('Regular version'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Explained version'));
      await tester.pumpAndSettle();
      expect(selected.explanationRequests, 1);
      await tester.pumpWidget(const SizedBox());
      selected.dispose();
    },
  );
  testWidgets('explanation toggle uses cached AI explanation without network', (
    tester,
  ) async {
    store.companionHelp[store.companionCacheKey(0, 'explain')] = {
      'text': 'Offline AI explanation',
      'suggestions': <String>[],
    };
    await tester.pumpWidget(MaterialApp(home: LessonPage(store: store, id: 0)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Explained version'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<LessonReadingBody>(find.byType(LessonReadingBody)).text,
      'Offline AI explanation',
    );
    expect(find.text('Explained version · AI-generated'), findsOneWidget);
    await tester.tap(find.byTooltip('Regular version'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<LessonReadingBody>(find.byType(LessonReadingBody)).text,
      lessonReadingText(store.lessons[0]['body'] as String),
    );
    await tester.pumpWidget(const SizedBox());
  });
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
    final button = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(button.backgroundColor, teal);
    expect(button.foregroundColor, Colors.white);
    expect(
      find.descendant(
        of: find.byType(FloatingActionButton),
        matching: find.byType(AppText),
      ),
      findsNothing,
    );
    expect((button.child! as Icon).color, Colors.white);
    await tester.tap(find.byTooltip('Explained version'));
    await tester.pumpAndSettle();
    expect(find.text('Saved explanation 0'), findsOneWidget);
    final explainedButton = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(explainedButton.backgroundColor, gold);
    expect(explainedButton.foregroundColor, ink);
    expect((explainedButton.child! as Icon).icon, Icons.lightbulb);
    expect(find.text('Explained version.'), findsOneWidget);
    expect(find.byType(LessonPage), findsOneWidget);
    expect(
      tester.widget<LessonReadingBody>(find.byType(LessonReadingBody)).text,
      'Saved explanation 0',
    );
    expect(store.isRead(0), isFalse);
    await tester.tap(find.byTooltip('Regular version'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<LessonReadingBody>(find.byType(LessonReadingBody)).text,
      lessonReadingText(store.lessons[0]['body'] as String),
    );
    expect(find.byTooltip('Explained version'), findsOneWidget);
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .backgroundColor,
      teal,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'explanation opt-in starts the same lesson page with saved explained content',
    (tester) async {
      store.preferExplained = true;
      store.autoReadAloud = false;
      store.companionHelp[store.explanationPackKey] = {
        'explanationVersion': 1,
        'lessons': List.generate(
          store.lessons.length,
          (id) => {'id': id, 'text': 'Opted-in explanation $id'},
        ),
      };
      await tester.pumpWidget(
        MaterialApp(home: LessonPage(store: store, id: 0)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<LessonReadingBody>(find.byType(LessonReadingBody)).text,
        'Opted-in explanation 0',
      );
      expect(find.byTooltip('Regular version'), findsOneWidget);
      expect(store.isRead(0), isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('learning-ui-');
    store = LearningStore(dir);
    await store.initialize();
    store.selectedCourseIds.add(store.courseId);
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
    expect(find.text('Download completed'), findsWidgets);
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
  testWidgets(
    'profile theme control switches both ways with readable dark headings',
    (tester) async {
      await tester.pumpWidget(
        LearningApp(store: store, showStartupLogo: false),
      );
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
      final heading = tester.widget<Text>(find.text('Appearance'));
      final surface = Theme.of(
        tester.element(find.text('Appearance')),
      ).colorScheme.surface;
      final foreground = heading.style!.color!;
      final contrast =
          (foreground.computeLuminance() + .05) /
          (surface.computeLuminance() + .05);
      expect(contrast, greaterThanOrEqualTo(4.5));
      final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(nav.backgroundColor, surface);
      await tester.ensureVisible(find.text('Teal light'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Teal light'));
        await store.save();
      });
      await tester.pumpAndSettle();
      expect(store.darkTheme, isFalse);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light,
      );
      final saved = await tester.runAsync(() => store.database!.query('state'));
      expect(jsonDecode(saved!.single['json'] as String)['darkTheme'], isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'dark learning-path tiles keep readable titles on dark surfaces',
    (tester) async {
      await tester.runAsync(() => store.setDarkTheme(true));
      await tester.pumpWidget(
        LearningApp(store: store, showStartupLogo: false),
      );
      await tester.pumpAndSettle();
      for (final index in [0, 4]) {
        final tile = find.byKey(ValueKey('learning-path-$index'));
        final decoration =
            tester.widget<Container>(tile).decoration! as BoxDecoration;
        expect(decoration.color!.computeLuminance(), lessThan(.1));
        final label = tester.widget<Text>(
          find.descendant(
            of: tile,
            matching: find.text(store.lessons[index]['title'] as String),
          ),
        );
        expect(
          (label.style!.color!.computeLuminance() + .05) /
              (decoration.color!.computeLuminance() + .05),
          greaterThanOrEqualTo(4.5),
        );
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
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
  for (final language in ['en', 'ar']) {
    testWidgets(
      'unread lesson skip respects $language direction without marking read',
      (tester) async {
        final skip = SwipeLessonStore()
          ..lessonLanguage = language
          ..autoReadAloud = false;
        skip.pack = {
          'lessons': List.generate(
            2,
            (i) => {
              'title': 'Skip lesson $i',
              'subtitle': 'Reading',
              'body': List.filled(30, 'Long paragraph.').join('\n\n'),
              'sourceName': 'Source',
              'sourceUrl': 'https://example.org',
              'questions': [
                {
                  'id': 'q$i',
                  'options': ['A', 'B'],
                  'correct': 0,
                  'prompt': 'Question',
                  'explanation': 'Why',
                },
              ],
            },
          ),
        };
        await tester.pumpWidget(
          MaterialApp(home: LessonPage(store: skip, id: 0)),
        );
        await tester.pump();
        final area = find.byKey(const ValueKey('lesson-swipe-area'));
        final forward = Offset(language == 'ar' ? 180 : -180, 0);
        await tester.drag(area, -forward);
        await tester.pump();
        expect(find.text('Skip lesson 0'), findsOneWidget);
        await tester.drag(area, forward);
        await tester.pumpAndSettle();
        expect(find.text('Skip lesson 1'), findsOneWidget);
        expect(skip.reads, 0);
        expect(skip.isRead(0), isFalse);
        await tester.drag(area, forward);
        await tester.pumpAndSettle();
        expect(find.byType(QuizPage), findsOneWidget);
        expect(skip.reads, 0);
        expect(skip.isRead(1), isFalse);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('scroll resets do not reduce recorded reading progress', (
    tester,
  ) async {
    store.lessonProgress(0)['readingFraction'] = .75;
    await tester.runAsync(() => store.saveReadingPosition(0, 0));
    expect(store.lessonProgress(0)['readingFraction'], .75);
    await tester.runAsync(() => store.saveReadingPosition(0, .9));
    expect(store.lessonProgress(0)['readingFraction'], .9);
  });
  testWidgets('Every lesson opens at top despite saved reading position', (
    tester,
  ) async {
    final store = SwipeLessonStore()..autoReadAloud = false;
    store.pack =
        jsonDecode(File('assets/packs/en.json').readAsStringSync())
            as Map<String, dynamic>;
    store.lessonProgress(0)['readingFraction'] = 1.0;
    store.lessonProgress(1)['readingFraction'] = 1.0;
    await tester.pumpWidget(MaterialApp(home: LessonPage(store: store, id: 0)));
    await tester.pumpAndSettle();
    final current = tester
        .widget<ListView>(find.byType(ListView).first)
        .controller!;
    expect(current.offset, 0);
    expect(store.lessonProgress(0)['readingFraction'], 1.0);
    current.jumpTo(current.position.maxScrollExtent);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Next lesson'));
    await tester.pumpAndSettle();
    final next = tester
        .widget<ListView>(find.byType(ListView).first)
        .controller!;
    expect(next.offset, 0);
    expect(find.text(store.lessons[1]['title'] as String), findsOneWidget);
    expect(store.isRead(1), isFalse);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('course contents opens later unread chapters', (tester) async {
    final skip = SwipeLessonStore()..autoReadAloud = false;
    skip.pack = {
      'lessons': List.generate(
        2,
        (i) => {
          'title': 'Chapter $i',
          'subtitle': 'Reading',
          'body': 'Body',
          'sourceName': 'Source',
          'sourceUrl': 'https://example.org',
        },
      ),
    };
    await tester.pumpWidget(MaterialApp(home: CoursePage(store: skip)));
    expect(find.text('Locked'), findsNothing);
    await tester.tap(find.text('Chapter 1'));
    await tester.pumpAndSettle();
    expect(find.byType(LessonPage), findsOneWidget);
    expect(skip.reads, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('scrolling offscreen retains active lesson narration', (
    tester,
  ) async {
    const channel = MethodChannel('learn_anywhere/speech');
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              const LessonAudio(
                text: 'A long lesson',
                language: 'en',
                autoRead: true,
              ),
              const SizedBox(height: 3000),
              const Text('End of lesson'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, ['speak']);
    await tester.drag(find.byType(ListView), const Offset(0, -1800));
    await tester.pumpAndSettle();
    expect(calls, ['speak']);
    await tester.drag(find.byType(ListView), const Offset(0, 1800));
    await tester.pumpAndSettle();
    expect(calls, ['speak']);
    expect(find.text('Pause'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(calls, ['speak', 'stop']);
  });
  testWidgets('lesson speech uses the same final-quiz instruction as reading', (
    tester,
  ) async {
    store.autoReadAloud = false;
    final lesson = store.lessons.first;
    lesson['body'] =
        'Original teaching paragraph.\n\nOffline practice: Keep the activity.\n\nComplete all three quiz questions before moving on.';
    await tester.pumpWidget(MaterialApp(home: LessonPage(store: store, id: 0)));
    await tester.pump();
    final speech = tester.widget<LessonAudio>(find.byType(LessonAudio));
    expect(
      speech.text,
      contains('Read all lessons in this part, then take the final quiz.'),
    );
    expect(speech.text, isNot(contains('Complete all three quiz questions')));
    expect(lesson['body'], contains('Complete all three quiz questions'));
    expect(find.byType(LanguageButton), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
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
          {'language': 'en', 'version': 1},
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
  testWidgets(
    'Home lists another started saved course and resumes it offline',
    (tester) async {
      final otherPack =
          jsonDecode(jsonEncode(store.pack)) as Map<String, dynamic>;
      otherPack['id'] = 'other-reading-course';
      otherPack['title'] = 'Another course in progress';
      final version = otherPack['version'] as int? ?? 1;
      final language = otherPack['language'] as String? ?? 'en';
      await tester.runAsync(() async {
        await store.database!.insert('packs', {
          'pack_key': 'other-reading-course:$version:$language',
          'course_id': 'other-reading-course',
          'version': version,
          'language': language,
          'json': jsonEncode(otherPack),
          'saved_at': DateTime.now().toIso8601String(),
        });
      });
      store.courseStates['other-reading-course:$version'] = {
        'progress': {
          '0': {'read': true},
        },
        'taskComplete': false,
        'safetyChecklist': <int>[],
      };
      await tester.pumpWidget(
        LearningApp(store: store, showStartupLogo: false),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.text('Another course in progress'), findsOneWidget);
      expect(find.text(store.courseTitle), findsOneWidget);
      await tester.scrollUntilVisible(find.byType(HomeReadingCourseCard), 200);
      final button = find.descendant(
        of: find.byType(HomeReadingCourseCard),
        matching: find.byType(FilledButton),
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(button);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(store.courseId, 'other-reading-course');
      expect(store.isRead(0), isTrue);
      expect(find.byType(LessonPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('new learner discovers courses before choosing one', (
    tester,
  ) async {
    store.selectedCourseIds.clear();
    await tester.pumpWidget(LearningApp(store: store, showStartupLogo: false));
    await tester.pumpAndSettle();
    expect(find.text('Continue learning'), findsNothing);
    expect(find.text(store.courseTitle), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Discover courses'));
    await tester.pumpAndSettle();
    expect(find.byType(DiscoverPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('home reading progress stays separate from quiz completion', (
    tester,
  ) async {
    store.lessonProgress(0)['read'] = true;
    await tester.pumpWidget(LearningApp(store: store, showStartupLogo: false));
    await tester.pumpAndSettle();
    expect(store.completedCount, 0);
    expect(
      find.text('1 / ${store.lessons.length} read · English'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator).first,
          )
          .value,
      1 / store.lessons.length,
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'Final quiz'),
      250,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Final quiz'));
    await tester.pumpAndSettle();
    expect(find.byType(QuizPage), findsOneWidget);
    expect(store.completedCount, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Downloads lists all saved courses without unsaved language rows or sync clutter',
    (tester) async {
      final other = jsonDecode(jsonEncode(store.pack)) as Map<String, dynamic>;
      other['id'] = 'another-saved-course';
      other['title'] = 'Another saved course';
      final version = other['version'] as int? ?? 1;
      await tester.runAsync(
        () => store.database!.insert('packs', {
          'pack_key': 'another-saved-course:$version:en',
          'course_id': 'another-saved-course',
          'version': version,
          'language': 'en',
          'json': jsonEncode(other),
          'saved_at': DateTime.now().toIso8601String(),
        }),
      );
      final original = store.courseId;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DownloadsPage(store: store)),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.text('Another saved course'), findsOneWidget);
      expect(find.text(store.courseTitle), findsOneWidget);
      expect(find.text('Français'), findsNothing);
      expect(find.byTooltip('Download pack'), findsNothing);
      expect(find.text('Sync now'), findsNothing);
      expect(store.courseId, original);
      expect(find.text('Open course'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('home, downloads and language panel render on a small iPhone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(LearningApp(store: store, showStartupLogo: false));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text(store.courseTitle), findsOneWidget);
    expect(find.text('Start course'), findsOneWidget);
    expect(find.byType(ShieldMascot), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.download_outlined));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Courses saved for offline learning'), findsOneWidget);
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
