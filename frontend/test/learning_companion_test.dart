import 'fixture_store.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:learn_anywhere/store.dart';
import 'package:learn_anywhere/identity.dart';
import 'package:learn_anywhere/learning_companion.dart';

class RealHttpOverrides extends HttpOverrides {}

class TestIdentity implements IdentityStorage {
  @override
  Future<String?> read() async => 'test-installation-token';
  @override
  Future<void> write(String token) async {}
}

class DownloadStore extends LearningStore {
  DownloadStore(super.directory);
  final pending = Completer<Map<String, dynamic>>();
  int downloads = 0;
  @override
  Future<Map<String, dynamic>> downloadExplanations() async {
    downloads++;
    final result = await pending.future;
    companionHelp[explanationPackKey] = result;
    return result;
  }
}

void main() {
  final realHttp = RealHttpOverrides();
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory directory;
  late LearningStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('companion-');
    store = LearningStore(directory, identity: TestIdentity());
    await initializeFixture(store);
  });
  tearDown(() async {
    await store.database?.close();
    await directory.delete(recursive: true);
  });
  test(
    'reviewed explanation download persists offline and preserves saved data when unavailable',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var available = true;
      var status = 200;
      server.listen((request) async {
        expect(request.uri.path, contains('/api/v1/explanations/'));
        request.response.statusCode = status;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'courseId': store.courseId,
            'courseVersion': store.courseVersion,
            'language': store.lessonLanguage,
            'available': available,
            if (available) 'explanationVersion': 2,
            if (available)
              'lessons': List.generate(
                5,
                (id) => {'id': id, 'text': 'Reviewed lesson $id'},
              ),
          }),
        );
        await request.response.close();
      });
      await store.database!.close();
      store = LearningStore(
        directory,
        baseUrl: 'http://127.0.0.1:${server.port}',
        identity: TestIdentity(),
      );
      await initializeFixture(store);
      await HttpOverrides.runZoned(
        () => store.downloadExplanations(),
        createHttpClient: (_) => realHttp.createHttpClient(null),
      );
      expect(store.savedExplanations!['explanationVersion'], 2);
      available = false;
      await HttpOverrides.runZoned(
        () => store.downloadExplanations(),
        createHttpClient: (_) => realHttp.createHttpClient(null),
      );
      expect(store.savedExplanations!['explanationVersion'], 2);
      status = 404;
      final missing = await HttpOverrides.runZoned(
        () => store.downloadExplanations(),
        createHttpClient: (_) => realHttp.createHttpClient(null),
      );
      expect(missing['available'], false);
      expect(store.savedExplanations!['explanationVersion'], 2);
      status = 500;
      await expectLater(
        HttpOverrides.runZoned(
          () => store.downloadExplanations(),
          createHttpClient: (_) => realHttp.createHttpClient(null),
        ),
        throwsA(isA<HttpException>()),
      );
      await store.database!.close();
      store = LearningStore(directory, identity: TestIdentity());
      await initializeFixture(store);
      expect(
        store.savedExplanations!['lessons'][0]['text'],
        'Reviewed lesson 0',
      );
      expect(store.isRead(0), false);
    },
  );
  test(
    'API request excludes personal history and answers; cache survives offline restart',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var calls = 0;
      Map<String, dynamic>? payload;
      server.listen((request) async {
        calls++;
        expect(request.uri.path, '/api/v1/learning-companion');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer test-installation-token',
        );
        payload =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'text': 'Suggested preparation: review passwords.',
            'suggestions': ['Review password basics before reading.'],
          }),
        );
        await request.response.close();
      });
      await store.database!.close();
      store = LearningStore(
        directory,
        baseUrl: 'http://127.0.0.1:${server.port}',
        identity: TestIdentity(),
      );
      await initializeFixture(store);
      await store.saveLearnerProfile(
        null,
        'Woman',
        '',
        dateOfBirth: DateTime(2000, 1, 1),
      );
      await store.readLesson(0);
      final reply = await HttpOverrides.runZoned(
        () => store.requestCompanion(0, 'prerequisites'),
        createHttpClient: (_) => realHttp.createHttpClient(null),
      );
      expect(payload!.keys.toSet(), {
        'courseId',
        'version',
        'language',
        'lessonId',
        'action',
      });
      expect(jsonEncode(payload), isNot(contains('Woman')));
      expect(reply['suggestions'], isNotEmpty);
      await store.requestCompanion(0, 'prerequisites');
      expect(calls, 1);
      await store.database!.close();
      store = LearningStore(
        directory,
        baseUrl: 'http://127.0.0.1:1',
        identity: TestIdentity(),
      );
      await initializeFixture(store);
      expect(await store.requestCompanion(0, 'prerequisites'), reply);
      expect(store.isRead(1), false);
    },
  );
  testWidgets(
    'Explain this downloads with loader then reads saved explanation without another call',
    (tester) async {
      final downloading = DownloadStore(directory);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearningCompanionCard(store: downloading, id: 0),
          ),
        ),
      );
      await tester.tap(find.text('Explain this'));
      await tester.pump();
      expect(downloading.downloads, 1);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      downloading.pending.complete({
        'explanationVersion': 1,
        'lessons': [
          {'id': 0, 'text': 'Reviewed explanation'},
        ],
      });
      await tester.pumpAndSettle();
      expect(find.text('Reviewed explanation'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.tap(find.text('Explain this'));
      await tester.pumpAndSettle();
      expect(downloading.downloads, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('cancelling confirmation sends no AI request', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LearningCompanionCard(store: store, id: 0)),
      ),
    );
    await tester.tap(find.text('Before you read'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.companionHelp, isEmpty);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
