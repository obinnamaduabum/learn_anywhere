import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'store.dart';

const maxShareBytes = 25 * 1024 * 1024;

bool privateAddress(String host) {
  final address = InternetAddress.tryParse(host);
  if (address == null || address.type != InternetAddressType.IPv4) return false;
  final b = address.rawAddress;
  return b[0] == 10 ||
      (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
      (b[0] == 192 && b[1] == 168);
}

class LanPackSession {
  HttpServer? server;
  String? address;
  final code = base64Url
      .encode(List.generate(18, (_) => Random.secure().nextInt(256)))
      .replaceAll('=', '');

  Future<void> start(List<int> bundle) async {
    if (bundle.length > maxShareBytes) {
      throw const FormatException('Share one smaller course at a time.');
    }
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    final candidates = interfaces
        .expand((i) => i.addresses)
        .where((a) => privateAddress(a.address))
        .toList();
    if (candidates.isEmpty) {
      throw const SocketException('Connect to a Wi-Fi network first.');
    }
    final wifi = interfaces
        .where((i) => i.name == 'en0' || i.name.startsWith('wlan'))
        .expand((i) => i.addresses)
        .where((a) => privateAddress(a.address))
        .firstOrNull;
    final ip = wifi ?? candidates.first;
    server = await HttpServer.bind(ip, 0);
    address = 'http://${ip.address}:${server!.port}';
    server!.listen((request) async {
      if (request.method != 'GET' ||
          request.uri.path != '/bundle' ||
          request.headers.value('X-Learning-Share') != code) {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.contentLength = bundle.length;
      try {
        for (var offset = 0; offset < bundle.length; offset += 64 * 1024) {
          request.response.add(
            bundle.sublist(offset, min(offset + 64 * 1024, bundle.length)),
          );
          await request.response.flush();
        }
      } catch (_) {
        /* Receiver disconnected; keep the sharing session available. */
      }
      await request.response.close();
    });
  }

  Future<void> stop() async {
    await server?.close(force: true);
    server = null;
  }
}

Future<List<int>> exportCourse(
  LearningStore store,
  Map<String, dynamic> course,
) async {
  final ids = ((course['parts'] as List?) ?? [course])
      .map((p) => p['id'])
      .toSet();
  final rows = await store.database!.query('packs');
  final packs = rows
      .where((row) {
        if (!ids.contains(row['course_id'])) return false;
        final pack = jsonDecode(row['json'] as String) as Map;
        return pack['_origin'] == 'Backend' || pack['_origin'] == 'Local share';
      })
      .map((row) => jsonDecode(row['json'] as String))
      .toList();
  if (packs.isEmpty) {
    throw const FormatException(
      'Download at least one published part before sharing.',
    );
  }
  return utf8.encode(
    jsonEncode({'format': 1, 'course': course, 'packs': packs}),
  );
}

Future<List<int>> exportLibrary(LearningStore store) async {
  final bundles = <dynamic>[];
  for (final course in store.catalog) {
    try {
      bundles.add(jsonDecode(utf8.decode(await exportCourse(store, course))));
    } on FormatException {
      // Courses without downloaded published packs have nothing to transfer.
    }
  }
  if (bundles.isEmpty) {
    throw const FormatException('No downloaded courses to share.');
  }
  return utf8.encode(jsonEncode({'format': 2, 'courses': bundles}));
}

Future<int> importCourse(LearningStore store, List<int> bytes) async {
  if (bytes.length > maxShareBytes) {
    throw const FormatException('The shared course is too large.');
  }
  final bundle = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  if (bundle['format'] == 2) {
    final courses = bundle['courses'] as List;
    int count = 0;
    for (final course in courses) {
      if ((course as Map)['format'] != 1) {
        throw const FormatException('Invalid library.');
      }
      count += await importCourse(store, utf8.encode(jsonEncode(course)));
    }
    return count;
  }
  if (bundle['format'] != 1) {
    throw const FormatException('Unsupported sharing format.');
  }
  final course = bundle['course'] as Map<String, dynamic>;
  final parts = ((course['parts'] as List?) ?? [course])
      .cast<Map<String, dynamic>>();
  final packs = (bundle['packs'] as List).cast<Map<String, dynamic>>();
  if (packs.isEmpty || packs.length > 500) {
    throw const FormatException('Invalid shared packs.');
  }
  final seen = <String>{};
  for (final pack in packs) {
    final part = parts.where((p) => p['id'] == pack['id']).firstOrNull;
    final language = pack['language'];
    final version = pack['version'];
    if (part == null ||
        language is! String ||
        !LearningStore.lessonLanguages.containsKey(language) ||
        version is! int ||
        version < 1 ||
        !(part['packs'] as List).any(
          (p) => p['language'] == language && p['version'] == version,
        ) ||
        !seen.add('${pack['id']}:$version:$language')) {
      throw const FormatException('Invalid shared course identities.');
    }
    final lessons = pack['lessons'] as List;
    if (lessons.isEmpty) {
      throw const FormatException('Invalid lesson count.');
    }
    final questions = <String>{};
    for (var i = 0; i < lessons.length; i++) {
      final lesson = lessons[i] as Map;
      if (lesson['id'] != i ||
          (lesson['body'] as String).trim().isEmpty ||
          Uri.parse(lesson['sourceUrl'] as String).scheme != 'https') {
        throw const FormatException('Invalid shared lesson.');
      }
      for (final q in lesson['questions'] as List) {
        final options = q['options'] as List;
        if (!questions.add(q['id'] as String) ||
            options.length < 2 ||
            q['correct'] is! int ||
            q['correct'] < 0 ||
            q['correct'] >= options.length) {
          throw const FormatException('Invalid shared question.');
        }
      }
    }
  }
  // Advertise copied languages for transferred parts so offline selection
  // does not try to fetch an uncopied preferred language from the backend.
  final localCourse = jsonDecode(jsonEncode(course)) as Map<String, dynamic>;
  final localParts = ((localCourse['parts'] as List?) ?? [localCourse])
      .cast<Map<String, dynamic>>();
  for (final part in localParts) {
    final copied = packs.where((p) => p['id'] == part['id']).toList();
    if (copied.isNotEmpty) {
      part['packs'] = (part['packs'] as List)
          .where(
            (meta) => copied.any(
              (p) =>
                  p['language'] == meta['language'] &&
                  p['version'] == meta['version'],
            ),
          )
          .toList();
    }
  }
  final updatedCatalog = [
    for (final c in store.catalog)
      if (c['id'] != course['id']) c,
    localCourse,
  ];
  await store.database!.transaction((txn) async {
    for (final pack in packs) {
      final key = '${pack['id']}:${pack['version']}:${pack['language']}';
      final existing = await txn.query(
        'packs',
        where: 'pack_key = ?',
        whereArgs: [key],
      );
      if (existing.isNotEmpty) {
        final previous = jsonDecode(existing.single['json'] as String) as Map;
        final incoming = Map<String, dynamic>.from(pack);
        previous.remove('_origin');
        incoming.remove('_origin');
        if (!mapsEqual(previous, incoming)) {
          throw const FormatException(
            'A shared pack conflicts with an existing version.',
          );
        }
        continue;
      }
      final local = {...pack, '_origin': 'Local share'};
      await txn.insert('packs', {
        'pack_key': key,
        'course_id': pack['id'],
        'version': pack['version'],
        'language': pack['language'],
        'json': jsonEncode(local),
        'saved_at': DateTime.now().toIso8601String(),
      });
    }
    await txn.insert('catalog', {
      'id': 1,
      'json': jsonEncode(updatedCatalog),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });
  store.catalog = updatedCatalog;
  for (final pack in packs) {
    final key = '${pack['id']}:${pack['version']}:${pack['language']}';
    store.downloadActivity.removeWhere((d) => d['key'] == key);
    store.downloadActivity.insert(0, {
      'key': key,
      'courseId': pack['id'],
      'title': parts.firstWhere((p) => p['id'] == pack['id'])['title'],
      'language': pack['language'],
      'status': 'complete',
      'received': 0,
      'total': 0,
    });
    if (pack['id'] == store.courseId &&
        pack['version'] == store.courseVersion) {
      store.downloaded.add(pack['language'] as String);
    }
  }
  store.notifyLocalContentChanged();
  return packs.length;
}

bool mapsEqual(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && mapsEqual(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => i).every((i) => mapsEqual(a[i], b[i]));
  }
  return a == b;
}

class LanSharePage extends StatefulWidget {
  const LanSharePage({super.key, required this.store, this.course});
  final LearningStore store;
  final Map<String, dynamic>? course;
  @override
  State<LanSharePage> createState() => _LanSharePageState();
}

class _LanSharePageState extends State<LanSharePage>
    with WidgetsBindingObserver {
  final address = TextEditingController();
  final code = TextEditingController();
  final session = LanPackSession();
  HttpClient? client;
  bool busy = false;
  double? progress;
  String? status;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(
        session.stop().then((_) {
          if (mounted) setState(() {});
        }),
      );
      client?.close(force: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(session.stop());
    client?.close(force: true);
    address.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> receive() async {
    setState(() {
      busy = true;
      status = null;
      progress = null;
    });
    try {
      final uri = Uri.parse(address.text.trim());
      if (uri.scheme != 'http' ||
          !privateAddress(uri.host) ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException(
          'Enter the sender’s private Wi-Fi address.',
        );
      }
      client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final request = await client!
          .getUrl(uri.replace(path: '/bundle', query: '', fragment: ''))
          .timeout(const Duration(seconds: 10));
      request.followRedirects = false;
      request.headers.set('X-Learning-Share', code.text.trim());
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != 200) {
        throw const FormatException('Check the sharing code and try again.');
      }
      if (response.contentLength > maxShareBytes) {
        throw const FormatException('Share a smaller course.');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        bytes.addAll(chunk);
        if (bytes.length > maxShareBytes) {
          throw const FormatException('Share a smaller course.');
        }
        if (mounted) {
          setState(
            () => progress = response.contentLength > 0
                ? (bytes.length / response.contentLength).clamp(0.0, 1.0)
                : null,
          );
        }
      }
      final count = await importCourse(widget.store, bytes);
      if (mounted) {
        setState(
          () => status =
              '$count language packs ready offline. Open Discover to start learning.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => status = error is FormatException
              ? error.message.toString()
              : 'Could not connect. Keep both devices on the same Wi-Fi with sharing open.',
        );
      }
    } finally {
      client?.close(force: true);
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Share over Wi-Fi')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Copy downloaded course packs between two devices on the same Wi-Fi. Internet is not required. Your personal progress and account tokens stay on your device.',
        ),
        SwitchListTile(
          title: const Text('Allow sharing'),
          subtitle: const Text(
            'Share all downloaded courses and language packs over Wi-Fi.',
          ),
          value: widget.store.allowSharing,
          onChanged: busy
              ? null
              : (value) async {
                  if (!value) await session.stop();
                  await widget.store.setAllowSharing(value);
                  if (mounted) setState(() {});
                },
        ),
        if (widget.store.allowSharing) ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.wifi),
            label: Text(
              session.server == null
                  ? 'Share all downloaded learning'
                  : 'Stop sharing',
            ),
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      if (session.server != null) {
                        await session.stop();
                      } else {
                        await session.start(await exportLibrary(widget.store));
                      }
                      if (mounted) setState(() => status = null);
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => status =
                              'Download a published part first and connect to Wi-Fi.',
                        );
                      }
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
          ),
          if (session.server != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              'Address: ${session.address}\nSharing code: ${session.code}',
            ),
            const Text(
              'Enter these on the receiving device. Keep this page open while sharing.',
            ),
          ],
        ],
        const SizedBox(height: 28),
        Text(
          'Receive from another device',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: address,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'Sender address',
            hintText: 'http://192.168.1.10:12345',
          ),
        ),
        TextField(
          controller: code,
          enabled: !busy,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Sharing code'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : receive,
          child: Text(busy ? 'Receiving…' : 'Receive course'),
        ),
        if (busy) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress),
        ],
        if (status != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(status!),
          ),
      ],
    ),
  );
}
