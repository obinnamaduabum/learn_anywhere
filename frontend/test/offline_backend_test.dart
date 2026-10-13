import 'fixture_store.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learn_anywhere/identity.dart';
import 'package:learn_anywhere/store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class OfflineIdentity implements IdentityStorage {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async => token = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'whole series saves without switching progress and skips cached packs',
    () async {
      final dir = await Directory.systemTemp.createTemp('series-download-');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final store = LearningStore(
        dir,
        baseUrl: 'http://127.0.0.1:${server.port}',
        identity: OfflineIdentity(),
      );
      var requests = 0;
      try {
        await initializeFixture(store);
        await store.readLesson(0);
        final originalCourse = store.courseKey;
        final template = jsonEncode(store.pack);
        server.listen((request) async {
          requests++;
          expect(request.uri.pathSegments.last, 'en');
          if (requests == 1) store.preferredLanguage = 'fr';
          final pack = jsonDecode(template) as Map<String, dynamic>;
          pack.addAll({
            'id': request.uri.pathSegments[3],
            'version': 2,
            'language': 'en',
          });
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(pack));
          await request.response.close();
        });
        final series = <String, dynamic>{
          'parts': [
            for (var i = 1; i <= 2; i++)
              {
                'id': 'download-part-$i',
                'title': 'Part $i',
                'packs': [
                  {'language': 'en', 'version': 2},
                ],
              },
          ],
        };
        expect(store.isSeriesSaved(series), isFalse);
        await store.saveSeries(series);
        expect(requests, 2);
        expect(store.courseKey, originalCourse);
        expect(store.isRead(0), isTrue);
        expect(
          store.downloadActivity.where(
            (d) =>
                d['courseId'].toString().startsWith('download-part-') &&
                d['status'] == 'complete',
          ),
          hasLength(2),
        );
        expect(store.isSeriesSaved(series), isFalse);
        store.preferredLanguage = 'en';
        expect(store.isSeriesSaved(series), isTrue);
        await store.saveSeries(series);
        expect(requests, 2);
        await server.close(force: true);
        for (final part in series['parts'] as List) {
          await store.selectCourse(part as Map<String, dynamic>);
          expect(store.lessons, hasLength(5));
        }
      } finally {
        await server.close(force: true);
        await store.database?.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test('all saved series parts reopen after restart with backend down', () async {
    final dir = await Directory.systemTemp.createTemp('offline-series-');
    final identity = OfflineIdentity();
    var store = LearningStore(
      dir,
      baseUrl: 'http://127.0.0.1:9',
      identity: identity,
    );
    try {
      await initializeFixture(store);
      final template = jsonEncode(store.pack);
      final parts = <Map<String, dynamic>>[];
      for (var i = 1; i <= 16; i++) {
        final id = 'offline-part-$i';
        final pack = jsonDecode(template) as Map<String, dynamic>;
        pack.addAll({
          'id': id,
          'version': 1,
          'language': 'fr',
          'title': 'Part $i',
        });
        await store.database!.insert('packs', {
          'pack_key': '$id:1:fr',
          'course_id': id,
          'version': 1,
          'language': 'fr',
          'json': jsonEncode(pack),
          'saved_at': DateTime.now().toIso8601String(),
        });
        // Simulate a catalog updated online after the cached version was saved.
        parts.add({
          'id': id,
          'title': 'Part $i',
          'lessonCount': 5,
          'partIndex': i,
          'packs': [
            {'language': 'en', 'version': 2},
          ],
        });
      }
      final catalog = [
        {'id': 'offline-series', 'title': 'Saved series', 'parts': parts},
      ];
      await store.database!.insert('catalog', {
        'id': 1,
        'json': jsonEncode(catalog),
      });
      store.preferredLanguage = 'fr';
      for (final part in parts) {
        await store.selectCourse(part);
        expect(store.courseVersion, 1);
        expect(store.lessonLanguage, 'fr');
        for (var i = 0; i < 5; i++) {
          await store.readLesson(i);
        }
      }
      final events = await store.database!.query('outbox');
      expect(events.length, 80);
      await store.database!.close();
      store = LearningStore(
        dir,
        baseUrl: 'http://127.0.0.1:9',
        identity: identity,
      );
      await initializeFixture(store);
      expect(store.courseId, 'offline-part-16');
      expect(store.lessonLanguage, 'fr');
      expect(store.downloaded, {'fr'});
      await store.refreshCatalog();
      expect(store.catalog.single['parts'], hasLength(16));
      expect(store.catalogError, contains('offline'));
      expect(store.catalogError, isNot(contains('127.0.0.1')));
      await store.sync();
      expect(await store.database!.query('outbox'), events);
      for (final part in parts) {
        await store.selectCourse(part);
        expect(store.lessons, hasLength(5));
        expect(List.generate(5, store.isRead), everyElement(isTrue));
      }
      final before = store.courseId;
      await expectLater(
        store.selectCourse({
          'id': 'not-downloaded',
          'title': 'Missing',
          'packs': [
            {'language': 'fr', 'version': 1},
          ],
        }),
        throwsA(isA<SocketException>()),
      );
      expect(store.courseId, before);
      expect(store.lessons, hasLength(5));
    } finally {
      await store.database?.close();
      await dir.delete(recursive: true);
    }
  });
}
