import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:learn_anywhere/lan_share.dart';
import 'package:learn_anywhere/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'sharing session refuses wrong code and transfers with its code',
    () async {
      final session = LanPackSession();
      final client = RealHttpOverrides().createHttpClient(null);
      try {
        await session.start(utf8.encode('{"course":"example"}'));
        final uri = Uri.parse('${session.address}/bundle');
        final denied = await (await client.getUrl(uri)).close();
        expect(denied.statusCode, HttpStatus.forbidden);
        await denied.drain<void>();
        final request = await client.getUrl(uri);
        request.headers.set('X-Learning-Share', session.code);
        final response = await request.close();
        expect(response.statusCode, HttpStatus.ok);
        expect(
          await utf8.decoder.bind(response).join(),
          '{"course":"example"}',
        );
      } finally {
        client.close(force: true);
        await session.stop();
      }
    },
  );

  test(
    'peer packs import atomically and preserve progress and immutable versions',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'learning-share-',
      );
      final sender = LearningStore(Directory('${directory.path}/a'));
      final receiver = LearningStore(Directory('${directory.path}/b'));
      try {
        await sender.initialize();
        await receiver.initialize();
        await receiver.readLesson(0);
        final progress = jsonEncode(
          receiver.progress.map((k, v) => MapEntry('$k', v)),
        );
        final pack =
            jsonDecode(await File('assets/packs/en.json').readAsString())
                as Map<String, dynamic>;
        pack['id'] = 'peer-course';
        pack['lessons'] = (pack['lessons'] as List).take(3).toList();
        pack['_origin'] = 'Backend';
        final course = <String, dynamic>{
          'id': 'peer-series',
          'type': 'series',
          'title': 'Shared series',
          'lessonCount': 3,
          'parts': [
            {
              'id': 'peer-course',
              'title': 'Shared part',
              'partIndex': 1,
              'lessonCount': 3,
              'packs': [
                {'language': 'en', 'version': 1},
              ],
            },
          ],
        };
        await sender.database!.insert('packs', {
          'pack_key': 'peer-course:1:en',
          'course_id': 'peer-course',
          'version': 1,
          'language': 'en',
          'json': jsonEncode(pack),
          'saved_at': DateTime.now().toIso8601String(),
        });
        final bytes = await exportCourse(sender, course);
        expect(jsonDecode(utf8.decode(bytes)).keys.toSet(), {
          'format',
          'course',
          'packs',
        });
        expect(await importCourse(receiver, bytes), 1);
        expect(
          jsonEncode(receiver.progress.map((k, v) => MapEntry('$k', v))),
          progress,
        );
        expect(await importCourse(receiver, bytes), 1);
        final rows = await receiver.database!.query(
          'packs',
          where: 'pack_key = ?',
          whereArgs: ['peer-course:1:en'],
        );
        expect(rows.length, 1);
        final modified = jsonDecode(utf8.decode(bytes)) as Map;
        modified['packs'][0]['lessons'][0]['body'] =
            'Different published content';
        await expectLater(
          importCourse(receiver, utf8.encode(jsonEncode(modified))),
          throwsFormatException,
        );
        final after = await receiver.database!.query(
          'packs',
          where: 'pack_key = ?',
          whereArgs: ['peer-course:1:en'],
        );
        expect(after.single['json'], rows.single['json']);
      } finally {
        await sender.database?.close();
        await receiver.database?.close();
        await directory.delete(recursive: true);
      }
    },
  );
}

class RealHttpOverrides extends HttpOverrides {}
