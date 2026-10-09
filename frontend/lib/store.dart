import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'identity.dart';
import 'course_reminders.dart';

class LearningStore extends ChangeNotifier {
  LearningStore(this.directory, {String? baseUrl, IdentityStorage? identity})
    : baseUrl = baseUrl ?? apiUrl,
      identity = identity ?? KeychainIdentityStorage();
  final String baseUrl;
  final IdentityStorage identity;
  final List<Map<String, dynamic>> _newEvents = [];
  int confirmedPoints = 0;
  int pendingEvents = 0;
  bool eventsMigrated = false;
  final Directory directory;
  Database? database;
  List<Map<String, dynamic>> catalog = [];
  String? catalogError;
  bool refreshing = false;
  double? packDownloadProgress;
  final List<Map<String, dynamic>> downloadActivity = [];
  int get activeDownloads => downloadActivity
      .where((d) => d['status'] == 'downloading' || d['status'] == 'saving')
      .length;

  void notifyLocalContentChanged() => notifyListeners();

  void finishDownload(String id, int version, String language) {
    for (final item in downloadActivity) {
      if (item['key'] == '$id:$version:$language') {
        item['status'] = 'complete';
      }
    }
    notifyListeners();
  }

  String? packNotice;
  static const apiUrl = String.fromEnvironment(
    'LEARNING_API_URL',
    defaultValue: 'http://127.0.0.1:8084',
  );
  static bool isAllowedEndpoint(Uri endpoint) {
    if (endpoint.scheme == 'https') return true;
    if (endpoint.scheme != 'http') return false;
    if (['127.0.0.1', 'localhost', '10.0.2.2'].contains(endpoint.host)) {
      return true;
    }
    // Local demo releases must explicitly opt in to private-network HTTP.
    const allowLocalDemo = bool.fromEnvironment('ALLOW_LOCAL_DEMO_HTTP');
    if (!kDebugMode && !allowLocalDemo) return false;
    final address = InternetAddress.tryParse(endpoint.host);
    if (address == null || address.type != InternetAddressType.IPv4) {
      return false;
    }
    final bytes = address.rawAddress;
    return bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168);
  }

  String courseId = 'digital-safety-v1';
  int courseVersion = 1;
  String courseTitle = 'Digital Safety';
  final Map<String, dynamic> courseStates = {};
  final Map<String, int> _packSizes = {};
  String get courseKey => '$courseId:$courseVersion';
  List<String> get taskLabels => courseId == 'digital-safety-v1'
      ? [
          'Set a screen lock on my device',
          'Use a unique password',
          'Turn on multi-factor authentication',
          'Back up important files',
        ]
      : [
          'Explain the main ideas in my own words',
          'Practise one skill from this course',
          'Write down steps to use the skill again',
          'Demonstrate what I learned',
        ];
  List<String> get taskKeys => courseId == 'digital-safety-v1'
      ? ['screen_lock', 'unique_password', 'mfa', 'backup']
      : ['recap', 'practice', 'plan', 'demonstrate'];
  String appLanguage = 'en';
  String preferredLanguage = 'en';
  bool hasChosenLanguage = false;
  bool autoReadAloud = true;
  Future<void> setAutoReadAloud(bool value) async {
    autoReadAloud = value;
    await save();
    notifyListeners();
  }

  bool allowSharing = false;
  Future<void> setAllowSharing(bool value) async {
    allowSharing = value;
    await save();
    notifyListeners();
  }

  bool darkTheme = false;
  double fontScale = 1;
  Future<void> setFontScale(double value) async {
    if (!value.isFinite) {
      throw const FormatException('Choose a valid font size.');
    }
    fontScale = (value.clamp(.85, 1.4) * 100).round() / 100;
    await save();
    notifyListeners();
  }

  Future<void> setDarkTheme(bool value) async {
    darkTheme = value;
    notifyListeners();
    await save();
  }

  String lessonLanguage = 'en';
  bool sound = false;
  int xp = 0;
  int revision = 0;
  int syncedRevision = 0;
  String? lastSync;
  String deviceId = '';
  Map<String, dynamic> pack = {};
  final Map<int, Map<String, dynamic>> progress = {};
  final Set<String> downloaded = {};
  final Set<String> studyDays = {};
  bool adaptiveCoaching = false;
  final List<Map<String, dynamic>> coachingActivity = [];
  final Map<String, Map<String, int>> coachingFeedback = {};
  Future<void> setAdaptiveCoaching(bool enabled) async {
    adaptiveCoaching = enabled;
    await _persist();
    notifyListeners();
  }

  Future<void> forgetCoachingPatterns() async {
    coachingActivity.clear();
    coachingFeedback.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> rateCoaching(String strategy, bool helpful) async {
    if (!adaptiveCoaching ||
        !['read', 'practice', 'recap'].contains(strategy)) {
      return;
    }
    final values = coachingFeedback.putIfAbsent(
      strategy,
      () => {'helpful': 0, 'unhelpful': 0},
    );
    final day = int.parse(todayKey.replaceAll('-', ''));
    if (values['ratedDay'] == day) return;
    values['ratedDay'] = day;
    final key = helpful ? 'helpful' : 'unhelpful';
    values[key] = (values[key] ?? 0) + 1;
    await _persist();
    notifyListeners();
  }

  int dailyLessonGoal = 1;
  int weeklyStudyGoal = 3;
  String learningInterest = '';
  bool hasCompletedLearnerProfile = false;
  int? learnerAge;
  DateTime? learnerDateOfBirth;
  String learnerGender = '';
  Future<void> saveLearnerProfile(
    int? age,
    String gender,
    String interest, {
    DateTime? dateOfBirth,
  }) async {
    if (age != null && (age < 1 || age > 120)) {
      throw ArgumentError('Enter an age from 1 to 120.');
    }
    if (![
      '',
      'Woman',
      'Man',
      'Non-binary',
      'Prefer not to say',
    ].contains(gender)) {
      throw ArgumentError('Choose a gender option.');
    }
    if (dateOfBirth != null) {
      final today = DateTime.now();
      final date = DateTime(
        dateOfBirth.year,
        dateOfBirth.month,
        dateOfBirth.day,
      );
      if (date.isAfter(DateTime(today.year, today.month, today.day)) ||
          date.isBefore(DateTime(today.year - 120, today.month, today.day))) {
        throw ArgumentError('Choose a valid date of birth.');
      }
      learnerDateOfBirth = date;
      learnerAge =
          today.year -
          date.year -
          ((today.month < date.month ||
                  (today.month == date.month && today.day < date.day))
              ? 1
              : 0);
    } else {
      learnerDateOfBirth = null;
      learnerAge = age;
    }
    learnerGender = gender;
    learningInterest = interest;
    hasCompletedLearnerProfile = true;
    await _persist();
    notifyListeners();
  }

  final Map<String, Set<String>> dailyReads = {};
  final Map<String, Set<String>> dailyPractice = {};
  String get todayKey => dateKey(DateTime.now());
  int get lessonsReadToday => dailyReads[todayKey]?.length ?? 0;
  bool get practicedToday => dailyPractice[todayKey]?.isNotEmpty ?? false;
  bool get dailyChallengeComplete => lessonsReadToday >= dailyLessonGoal;
  int get studyDaysThisWeek {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
    return List.generate(
      7,
      (i) => dateKey(DateTime(monday.year, monday.month, monday.day + i)),
    ).where(studyDays.contains).length;
  }

  Future<void> setLearningGoals(int daily, int weekly, String interest) async {
    if (daily < 1 || daily > 3 || weekly < 1 || weekly > 7) {
      throw ArgumentError('Choose 1–3 lessons and 1–7 study days.');
    }
    dailyLessonGoal = daily;
    weeklyStudyGoal = weekly;
    learningInterest = interest;
    await save();
  }

  Future<void> recordCheckpoint(int id) async {
    if (id < 0 || id >= lessons.length || !isUnlocked(id)) return;
    dailyPractice.putIfAbsent(todayKey, () => {}).add('$courseKey:$id');
    studyDays.add(todayKey);
    await save();
  }

  final Set<String> bookmarkedCourses = {};
  Future<void> toggleCourseBookmark(String id) async {
    if (id.isEmpty) return;
    final wasSaved = bookmarkedCourses.contains(id);
    if (wasSaved) {
      bookmarkedCourses.remove(id);
    } else {
      bookmarkedCourses.add(id);
    }
    try {
      await _persist();
    } catch (_) {
      if (wasSaved) {
        bookmarkedCourses.add(id);
      } else {
        bookmarkedCourses.remove(id);
      }
      rethrow;
    }
    notifyListeners();
  }

  bool isBookmarked(int id) => lessonProgress(id)['bookmarked'] == true;

  Future<void> toggleBookmark(int id) async {
    if (id < 0 || id >= lessons.length || !isUnlocked(id)) return;
    final previous = isBookmarked(id);
    lessonProgress(id)['bookmarked'] = !previous;
    try {
      await _persist();
    } catch (_) {
      lessonProgress(id)['bookmarked'] = previous;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> saveReadingPosition(int id, double fraction) async {
    if (id < 0 || id >= lessons.length || !isUnlocked(id)) return;
    lessonProgress(id)['readingFraction'] = fraction.clamp(0.0, 1.0);
    await _persist();
  }

  List<Map<String, dynamic>> recommendedCourses(
    List<Map<String, dynamic>> courses,
  ) {
    String category(Map<String, dynamic> course) =>
        '${course['category'] ?? 'General Learning'}';
    final selected = catalog.where((c) => c['id'] == courseId);
    final interest = learningInterest.isNotEmpty
        ? learningInterest
        : (selected.isEmpty ? '' : category(selected.first));
    int score(Map<String, dynamic> course) {
      final packs = (course['packs'] as List? ?? []);
      return (interest.isNotEmpty && category(course) == interest ? 4 : 0) +
          (packs.any((p) => p['language'] == preferredLanguage) ? 2 : 0) +
          (course['id'] != courseId ? 1 : 0);
    }

    final ranked = courses.where((c) => c['id'] != courseId).toList();
    ranked.sort((a, b) {
      final comparison = score(b).compareTo(score(a));
      return comparison != 0
          ? comparison
          : '${a['title']}'.compareTo('${b['title']}');
    });
    return ranked.take(3).toList();
  }

  final Set<int> safetyChecklist = {};
  bool taskComplete = false;
  Future<void> _writes = Future.value();
  bool syncing = false;
  String? syncError;
  static const languages = {
    'en': 'English',
    'fr': 'Français',
    'pt': 'Português',
    'ar': 'العربية',
    'ha': 'Hausa',
    'yo': 'Yorùbá',
    'ig': 'Igbo',
  };
  static const lessonLanguages = languages;
  List<Map<String, dynamic>> get lessons =>
      (pack['lessons'] as List? ?? []).cast<Map<String, dynamic>>();
  int get completedCount =>
      progress.values.where((p) => p['complete'] == true).length;
  int get currentLesson =>
      min(progress.values.where((p) => p['read'] == true).length, 4);
  bool isRead(int id) => progress[id]?['read'] == true;
  bool isComplete(int id) => progress[id]?['complete'] == true;
  bool isUnlocked(int id) => id == 0 || progress[id - 1]?['read'] == true;
  int get streak {
    var day = DateTime.now();
    if (!studyDays.contains(dateKey(day))) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    var count = 0;
    while (studyDays.contains(dateKey(day))) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  Map<String, dynamic> lessonProgress(int id) => progress.putIfAbsent(
    id,
    () => {
      'read': false,
      'answers': <int>[],
      'complete': false,
      'awarded': <int>[],
    },
  );
  List<int> answers(int id) =>
      (lessonProgress(id)['answers'] as List).cast<int>();
  int questionIndex(int id) => answers(id).length;
  int score(int id) {
    final a = answers(id);
    final questions = lessons[id]['questions'] as List;
    var correct = 0;
    for (var i = 0; i < a.length && i < questions.length; i++) {
      if (a[i] == questions[i]['correct']) correct++;
    }
    return correct;
  }

  Future<void> initialize() async {
    await directory.create(recursive: true);
    const resetId = String.fromEnvironment('RESET_LOCAL_DATA');
    final resetMarker = File('${directory.path}/local-reset-marker');
    if (kDebugMode &&
        resetId.isNotEmpty &&
        (!await resetMarker.exists() ||
            await resetMarker.readAsString() != resetId)) {
      await deleteDatabase('${directory.path}/learning.db');
      await const MethodChannel(
        'learn_anywhere/identity',
      ).invokeMethod<void>('clear');
      await resetMarker.writeAsString(resetId);
    }
    database = await openDatabase(
      '${directory.path}/learning.db',
      version: 3,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await db.execute(_outboxSchema);
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE packs RENAME TO old_packs');
          await db.execute(_packsSchema);
          await db.execute(
            "INSERT INTO packs SELECT 'digital-safety-v1:1:' || language, 'digital-safety-v1', 1, language, json, saved_at FROM old_packs",
          );
          await db.execute('DROP TABLE old_packs');
          if (oldVersion == 2) {
            await db.execute(
              "ALTER TABLE outbox ADD COLUMN language TEXT NOT NULL DEFAULT 'en'",
            );
          }
        }
      },
      onCreate: (db, version) async {
        await db.execute(_outboxSchema);
        await db.execute(
          'CREATE TABLE state (id INTEGER PRIMARY KEY, json TEXT NOT NULL)',
        );
        await db.execute(_packsSchema);
        await db.execute(
          'CREATE TABLE catalog (id INTEGER PRIMARY KEY, json TEXT NOT NULL)',
        );
      },
    );
    for (final row in await database!.query('packs')) {
      _packSizes[row['pack_key'] as String] = utf8
          .encode(row['json'] as String)
          .length;
    }
    final rows = await database!.query(
      'state',
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isNotEmpty) {
      try {
        final data =
            jsonDecode(rows.first['json'] as String) as Map<String, dynamic>;
        courseId = data['courseId'] as String? ?? 'digital-safety-v1';
        courseVersion = data['courseVersion'] as int? ?? 1;
        courseTitle = data['courseTitle'] as String? ?? 'Digital Safety';
        courseStates.addAll(
          data['courseStates'] as Map<String, dynamic>? ?? {},
        );
        appLanguage = data['appLanguage'] as String? ?? 'en';
        preferredLanguage = data['preferredLanguage'] as String? ?? appLanguage;
        hasChosenLanguage = data['hasChosenLanguage'] == true;
        needsProgressRestore = data['needsProgressRestore'] == true;
        autoReadAloud = data['autoReadAloud'] != false;
        darkTheme = data['darkTheme'] == true;
        final savedScale = data['fontScale'];
        fontScale = savedScale is num && savedScale.isFinite
            ? savedScale.toDouble().clamp(.85, 1.4)
            : 1;
        allowSharing = data['allowSharing'] == true;
        lessonLanguage = data['lessonLanguage'] as String? ?? 'en';
        sound = data['sound'] == true;
        xp = data['xp'] as int? ?? 0;
        confirmedPoints = data['confirmedPoints'] as int? ?? 0;
        eventsMigrated = data['eventsMigrated'] == true;
        revision = data['revision'] as int? ?? 0;
        syncedRevision = data['syncedRevision'] as int? ?? 0;
        lastSync = data['lastSync'] as String?;
        deviceId = data['deviceId'] as String? ?? '';
        taskComplete = data['taskComplete'] == true;
        safetyChecklist.addAll(
          (data['safetyChecklist'] as List? ?? []).cast<int>(),
        );
        studyDays.addAll((data['studyDays'] as List? ?? []).cast<String>());
        dailyLessonGoal = (data['dailyLessonGoal'] as int? ?? 1).clamp(1, 3);
        weeklyStudyGoal = (data['weeklyStudyGoal'] as int? ?? 3).clamp(1, 7);
        for (final entry
            in (data['companionHelp'] as Map<String, dynamic>? ?? {}).entries) {
          companionHelp[entry.key] = Map<String, dynamic>.from(
            entry.value as Map,
          );
        }
        learningInterest = data['learningInterest'] as String? ?? '';
        bookmarkedCourses.addAll(
          (data['bookmarkedCourses'] as List? ?? []).cast<String>(),
        );
        hasCompletedLearnerProfile = data['hasCompletedLearnerProfile'] == true;
        learnerAge = data['learnerAge'] as int?;
        learnerDateOfBirth = DateTime.tryParse(
          data['learnerDateOfBirth'] as String? ?? '',
        );
        learnerGender = data['learnerGender'] as String? ?? '';
        for (final entry
            in (data['dailyReads'] as Map<String, dynamic>? ?? {}).entries) {
          dailyReads[entry.key] = (entry.value as List).cast<String>().toSet();
        }
        for (final entry
            in (data['dailyPractice'] as Map<String, dynamic>? ?? {}).entries) {
          dailyPractice[entry.key] = (entry.value as List)
              .cast<String>()
              .toSet();
        }
        for (final entry
            in (data['progress'] as Map<String, dynamic>? ?? {}).entries) {
          progress[int.parse(entry.key)] = Map<String, dynamic>.from(
            entry.value as Map,
          );
        }
      } catch (_) {
        rethrow;
      }
    }
    if (deviceId.isEmpty) {
      deviceId =
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    }
    downloaded.addAll(
      (await database!.query(
        'packs',
        where: 'course_id = ? AND version = ?',
        whereArgs: [courseId, courseVersion],
      )).map((r) => r['language'] as String),
    );
    final cached = await database!.query(
      'catalog',
      where: 'id = ?',
      whereArgs: [1],
    );
    if (cached.isNotEmpty) {
      catalog = (jsonDecode(cached.first['json'] as String) as List)
          .cast<Map<String, dynamic>>();
    }
    if (!languages.containsKey(appLanguage)) appLanguage = 'en';
    if (!lessonLanguages.containsKey(lessonLanguage)) lessonLanguage = 'en';
    // The small English starter pack ships with the app and is ready offline.
    if (!downloaded.contains('en')) {
      await savePack('en', bundled: courseId == 'digital-safety-v1');
    }
    if (!downloaded.contains(lessonLanguage)) lessonLanguage = 'en';
    await _loadPack();
    if (!eventsMigrated) {
      _migrateProgressEvents();
      eventsMigrated = true;
    }
    await _persist();
    if (Platform.isIOS) {
      await const CourseReminderService().updateCourse(courseTitle);
    }
    await _countPending();
    for (final row in await database!.query('packs')) {
      final pack = jsonDecode(row['json'] as String) as Map<String, dynamic>;
      final size = utf8.encode(row['json'] as String).length;
      if (!downloadActivity.any((item) => item['key'] == row['pack_key'])) {
        downloadActivity.add({
          'key': row['pack_key'],
          'courseId': row['course_id'],
          'title': pack['title'] ?? row['course_id'],
          'language': row['language'],
          'status': 'complete',
          'received': size,
          'total': size,
        });
      }
    }
  }

  Future<void> _loadPack() async {
    final rows = await database!.query(
      'packs',
      where: 'pack_key = ?',
      whereArgs: ['$courseKey:$lessonLanguage'],
    );
    pack = jsonDecode(rows.single['json'] as String) as Map<String, dynamic>;
  }

  Iterable<Map<String, dynamic>> get catalogPacks sync* {
    for (final course in catalog) {
      final parts = course['parts'] as List?;
      if (parts == null) {
        yield course;
      } else {
        yield* parts.cast<Map<String, dynamic>>();
      }
    }
  }

  Set<String> get availablePackLanguages {
    for (final course in catalogPacks) {
      if (course['id'] == courseId) {
        return (course['packs'] as List)
            .map((p) => (p as Map)['language'] as String)
            .toSet();
      }
    }
    return courseId == 'digital-safety-v1'
        ? languages.keys.toSet()
        : downloaded;
  }

  Future<int> packBytes(String lang) async {
    final size = _packSizes['$courseKey:$lang'];
    if (size != null) return size;
    for (final course in catalogPacks) {
      if (course['id'] == courseId) {
        for (final p in course['packs'] as List) {
          if (p['language'] == lang) return p['bytes'] as int;
        }
      }
    }
    return utf8
        .encode(await rootBundle.loadString('assets/packs/$lang.json'))
        .length;
  }

  Future<String> _get(String route, {bool trackDownload = false}) async {
    final endpoint = Uri.parse('$baseUrl$route');
    if (!isAllowedEndpoint(endpoint)) {
      throw const FormatException(
        'Use HTTPS, or a local development endpoint.',
      );
    }
    Map<String, dynamic>? activity;
    if (endpoint.path.startsWith('/api/v1/packs/')) {
      final parts = endpoint.pathSegments;
      final id = parts[1];
      final language = parts[2];
      final version = endpoint.queryParameters['version'] ?? '1';
      final key = '$id:$version:$language';
      downloadActivity.removeWhere((item) => item['key'] == key);
      activity = {
        'key': key,
        'courseId': id,
        'language': language,
        'title':
            catalogPacks
                .where((c) => c['id'] == id)
                .map((c) => c['title'])
                .firstOrNull ??
            (id == courseId ? courseTitle : id),
        'status': 'downloading',
        'received': 0,
        'total': 0,
      };
      downloadActivity.insert(0, activity);
      trackDownload = true;
      notifyListeners();
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client
          .getUrl(endpoint)
          .timeout(const Duration(seconds: 10));
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      if (!trackDownload) {
        return await utf8.decoder
            .bind(res)
            .join()
            .timeout(const Duration(seconds: 10));
      }
      final bytes = <int>[];
      final total = res.contentLength;
      activity?['total'] = total;
      await for (final chunk in res.timeout(const Duration(seconds: 20))) {
        bytes.addAll(chunk);
        activity?['received'] = bytes.length;
        packDownloadProgress = total > 0
            ? (bytes.length / total).clamp(0.0, 1.0)
            : null;
        notifyListeners();
      }
      activity?['status'] = 'saving';
      notifyListeners();
      return utf8.decode(bytes);
    } catch (_) {
      activity?['status'] = 'failed';
      notifyListeners();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> refreshCatalog() async {
    if (refreshing) return;
    refreshing = true;
    catalogError = null;
    notifyListeners();
    try {
      final raw = await _get('/api/v1/courses');
      final decoded = jsonDecode(raw);
      if (decoded is! List ||
          decoded.any((item) => item is! Map<String, dynamic>)) {
        throw const FormatException('Invalid catalog response');
      }
      final updated = decoded.cast<Map<String, dynamic>>();
      try {
        await database!.insert('catalog', {
          'id': 1,
          'json': raw,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {
        catalog = updated;
        catalogError =
            'Courses loaded, but could not be saved on this device. Try again.';
        return;
      }
      catalog = updated;
    } on SocketException catch (failure) {
      final reason = failure.osError?.message ?? failure.message;
      catalogError =
          'Cannot connect to the lesson service at $baseUrl. $reason. Downloaded lessons still work offline.';
    } on TimeoutException {
      catalogError =
          'The lesson service at $baseUrl did not respond in time. Try again.';
    } on HttpException catch (failure) {
      catalogError =
          'The lesson service returned ${failure.message}. Try again.';
    } on FormatException {
      catalogError =
          'The lesson service returned an invalid course catalog. Downloaded lessons still work offline.';
    } catch (_) {
      catalogError =
          'Could not refresh courses. Downloaded lessons still work offline.';
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  Future<void> savePack(String lang, {bool bundled = false}) async {
    try {
      await _savePack(lang, bundled: bundled);
    } catch (_) {
      for (final item in downloadActivity) {
        if (item['key'] == '$courseKey:$lang') item['status'] = 'failed';
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _savePack(String lang, {bool bundled = false}) async {
    String content;
    bool preview = bundled;
    packNotice = null;
    if (bundled) {
      content = await rootBundle.loadString('assets/packs/$lang.json');
    } else {
      try {
        packDownloadProgress = null;
        notifyListeners();
        content = await _get(
          '/api/v1/packs/$courseId/$lang?version=$courseVersion',
          trackDownload: true,
        );
      } catch (_) {
        if (courseId != 'digital-safety-v1') rethrow;
        // Keep the Flutter prototype usable while backend work is paused.
        // The UI explicitly identifies included preview content.
        content = await rootBundle.loadString('assets/packs/$lang.json');
        preview = true;
        packNotice = 'Backend unavailable. Using the included preview pack.';
      }
    }
    final value = jsonDecode(content) as Map<String, dynamic>;
    if (value['id'] != courseId ||
        value['version'] != courseVersion ||
        value['language'] != lang ||
        (value['lessons'] as List).length != 5) {
      throw const FormatException('Invalid lesson pack');
    }
    value['_origin'] = preview ? 'Included preview' : 'Backend';
    await database!.insert('packs', {
      'pack_key': '$courseKey:$lang',
      'course_id': courseId,
      'version': courseVersion,
      'language': lang,
      'json': jsonEncode(value),
      'saved_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _packSizes['$courseKey:$lang'] = utf8.encode(jsonEncode(value)).length;
    downloaded.add(lang);
    finishDownload(courseId, courseVersion, lang);
    notifyListeners();
  }

  Future<void> selectCourse(Map<String, dynamic> course) async {
    try {
      await _selectCourse(course);
    } catch (_) {
      for (final item in downloadActivity) {
        if (item['courseId'] == course['id'] && item['status'] != 'complete') {
          item['status'] = 'failed';
        }
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _selectCourse(Map<String, dynamic> course) async {
    final id = course['id'] as String;
    final packs = (course['packs'] as List).cast<Map<String, dynamic>>();
    final matching = packs.where((p) => p['language'] == preferredLanguage);
    if (matching.isEmpty) {
      throw FormatException(
        '${lessonLanguages[preferredLanguage]} is not available for this course. Choose another language to continue.',
      );
    }
    final selected = matching.first;
    final version = selected['version'] as int;
    if (id == courseId &&
        version == courseVersion &&
        lessonLanguage == preferredLanguage &&
        downloaded.contains(preferredLanguage)) {
      return;
    }
    // Download before switching so a failed request preserves the active course.
    final lang = selected['language'] as String;
    final key = '$id:$version:$lang';
    final cached = await database!.query(
      'packs',
      where: 'pack_key = ?',
      whereArgs: [key],
    );
    if (cached.isEmpty) {
      final content = await _get('/api/v1/packs/$id/$lang?version=$version');
      final value = jsonDecode(content) as Map<String, dynamic>;
      if (value['id'] != id ||
          value['version'] != version ||
          value['language'] != lang ||
          (value['lessons'] as List).length != 5) {
        throw const FormatException('Invalid course pack');
      }
      value['_origin'] = 'Backend';
      await database!.insert('packs', {
        'pack_key': key,
        'course_id': id,
        'version': version,
        'language': lang,
        'json': jsonEncode(value),
        'saved_at': DateTime.now().toIso8601String(),
      });
      finishDownload(id, version, lang);
    }
    final loaded = await database!.query(
      'packs',
      where: 'pack_key = ?',
      whereArgs: [key],
    );
    _packSizes[key] = utf8.encode(loaded.single['json'] as String).length;
    await _persist();
    courseStates[courseKey] = jsonDecode(
      jsonEncode({
        'progress': progress.map((k, v) => MapEntry('$k', v)),
        'taskComplete': taskComplete,
        'safetyChecklist': safetyChecklist.toList(),
      }),
    );
    courseId = id;
    courseVersion = version;
    courseTitle = course['title'] as String;
    lessonLanguage = lang;
    progress.clear();
    safetyChecklist.clear();
    taskComplete = false;
    final saved = courseStates[courseKey] as Map<String, dynamic>?;
    if (saved != null) {
      for (final entry in (saved['progress'] as Map<String, dynamic>).entries) {
        progress[int.parse(entry.key)] = Map<String, dynamic>.from(
          entry.value as Map,
        );
      }
      taskComplete = saved['taskComplete'] == true;
      safetyChecklist.addAll((saved['safetyChecklist'] as List).cast<int>());
    }
    downloaded.clear();
    downloaded.addAll(
      (await database!.query(
        'packs',
        where: 'course_id = ? AND version = ?',
        whereArgs: [courseId, courseVersion],
      )).map((r) => r['language'] as String),
    );
    await _loadPack();
    await save();
  }

  Future<void> choosePreferredLanguage(String language) async {
    if (!lessonLanguages.containsKey(language)) {
      throw const FormatException('Choose a supported language.');
    }
    preferredLanguage = language;
    appLanguage = language;
    await refreshCatalog();
    final candidates = <Map<String, dynamic>>[];
    for (final course in catalog) {
      candidates.addAll(
        ((course['parts'] as List?) ?? [course]).cast<Map<String, dynamic>>(),
      );
    }
    final available = candidates.where(
      (course) =>
          (course['packs'] as List).any((pack) => pack['language'] == language),
    );
    if (available.isNotEmpty) {
      try {
        await selectCourse(available.first);
      } catch (_) {
        packNotice =
            'Language preference saved. Reconnect to download your selected language.';
      }
    } else {
      packNotice = 'No published course is available in this language yet.';
    }
    hasChosenLanguage = true;
    await save();
  }

  Future<void> changeLanguages(String app, String lesson) async {
    if (!lessonLanguages.containsKey(lesson)) {
      throw const FormatException('Choose a supported language.');
    }
    appLanguage = lesson;
    preferredLanguage = lesson;
    packNotice = null;
    if (!availablePackLanguages.contains(lesson) &&
        !downloaded.contains(lesson)) {
      packNotice =
          '${lessonLanguages[lesson]} is not available for this course yet. Your language preference is saved; lessons remain in ${lessonLanguages[lessonLanguage]}.';
      await save();
      return;
    }
    try {
      if (!downloaded.contains(lesson)) await savePack(lesson);
      lessonLanguage = lesson;
      await _loadPack();
    } catch (_) {
      packNotice =
          'Language preference saved. Could not download ${lessonLanguages[lesson]}; reconnect to try again. Your downloaded lessons remain available.';
      await save();
      rethrow;
    }
    await save();
  }

  Future<void> removePack(String lang) async {
    if (lang == lessonLanguage || lang == 'en') return;
    await database!.delete(
      'packs',
      where: 'pack_key = ?',
      whereArgs: ['$courseKey:$lang'],
    );
    downloaded.remove(lang);
    notifyListeners();
  }

  Future<void> readLesson(int id) async {
    if (!isUnlocked(id)) return;
    final wasRead = isRead(id);
    lessonProgress(id)['read'] = true;
    lessonProgress(id)['readingFraction'] = 1.0;
    if (!wasRead) _event('lesson_read', id);
    dailyReads.putIfAbsent(todayKey, () => {}).add('$courseKey:$id');
    studyDays.add(dateKey(DateTime.now()));
    await save();
  }

  Future<void> answer(int id, int question, int selected) async {
    if (!isUnlocked(id) || lessonProgress(id)['read'] != true) return;
    final questions = lessons[id]['questions'] as List;
    final a = answers(id);
    if (question != a.length ||
        question >= questions.length ||
        selected < 0 ||
        selected >= (questions[question]['options'] as List).length) {
      return;
    }
    _event('quiz_answered', id, {
      'questionId': questions[question]['id'],
      'selectedOption': selected,
    });
    a.add(selected);
    lessonProgress(id)['answers'] = a;
    final awarded = (lessonProgress(id)['awarded'] as List? ?? []).cast<int>();
    if (selected == questions[question]['correct'] &&
        !awarded.contains(question)) {
      xp += 10;
      awarded.add(question);
      lessonProgress(id)['awarded'] = awarded;
    }
    studyDays.add(dateKey(DateTime.now()));
    await save();
  }

  Future<void> completeQuiz(int id) async {
    if (!isUnlocked(id) ||
        lessonProgress(id)['read'] != true ||
        answers(id).length != (lessons[id]['questions'] as List).length) {
      return;
    }
    if (!isComplete(id)) {
      lessonProgress(id)['complete'] = true;
      _event('quiz_completed', id);
      xp += 50;
      studyDays.add(dateKey(DateTime.now()));
      await save();
    }
  }

  Future<void> resetQuiz(int id) async {
    lessonProgress(id)['answers'] = <int>[];
    // Keep completion and awards: practicing never re-locks lessons or farms XP.
    await save();
  }

  Future<void> toggleTask(int index, bool value) async {
    value ? safetyChecklist.add(index) : safetyChecklist.remove(index);
    await save();
  }

  Future<void> finishTask() async {
    if (completedCount != 5 || safetyChecklist.length != 4 || taskComplete) {
      return;
    }
    taskComplete = true;
    _event('task_completed', 0, {'checklist': taskKeys});
    xp += 100;
    await save();
  }

  Map<String, dynamic> snapshot() => {
    'schemaVersion': 3,
    'courseId': courseId,
    'courseVersion': courseVersion,
    'courseTitle': courseTitle,
    'courseStates': {
      ...courseStates,
      courseKey: {
        'progress': progress.map((k, v) => MapEntry('$k', v)),
        'taskComplete': taskComplete,
        'safetyChecklist': safetyChecklist.toList(),
      },
    },
    'confirmedPoints': confirmedPoints,
    'eventsMigrated': eventsMigrated,
    'deviceId': deviceId,
    'appLanguage': appLanguage,
    'preferredLanguage': preferredLanguage,
    'hasChosenLanguage': hasChosenLanguage,
    'needsProgressRestore': needsProgressRestore,
    'autoReadAloud': autoReadAloud,
    'darkTheme': darkTheme,
    'fontScale': fontScale,
    'allowSharing': allowSharing,
    'lessonLanguage': lessonLanguage,
    'sound': sound,
    'xp': xp,
    'revision': revision,
    'syncedRevision': syncedRevision,
    'lastSync': lastSync,
    'studyDays': studyDays.toList(),
    'dailyLessonGoal': dailyLessonGoal,
    'weeklyStudyGoal': weeklyStudyGoal,
    'learningInterest': learningInterest,
    'companionHelp': companionHelp,
    'bookmarkedCourses': bookmarkedCourses.toList(),
    'hasCompletedLearnerProfile': hasCompletedLearnerProfile,
    'learnerAge': learnerAge,
    'learnerDateOfBirth': learnerDateOfBirth == null
        ? null
        : dateKey(learnerDateOfBirth!),
    'learnerGender': learnerGender,
    'dailyReads': dailyReads.map((k, v) => MapEntry(k, v.toList())),
    'dailyPractice': dailyPractice.map((k, v) => MapEntry(k, v.toList())),
    'taskComplete': taskComplete,
    'safetyChecklist': safetyChecklist.toList(),
    'progress': progress.map((k, v) => MapEntry('$k', v)),
  };
  static const _packsSchema =
      'CREATE TABLE packs (pack_key TEXT PRIMARY KEY, course_id TEXT NOT NULL, version INTEGER NOT NULL, language TEXT NOT NULL, json TEXT NOT NULL, saved_at TEXT NOT NULL)';

  static const _outboxSchema =
      'CREATE TABLE outbox (sequence INTEGER PRIMARY KEY AUTOINCREMENT, event_id TEXT UNIQUE NOT NULL, course_id TEXT NOT NULL, version INTEGER NOT NULL, language TEXT NOT NULL, event_json TEXT NOT NULL)';

  void _event(String type, int lessonId, [Map<String, dynamic>? extra]) {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    _newEvents.add({'id': id, 'type': type, 'lessonId': lessonId, ...?extra});
  }

  void _migrateProgressEvents() {
    for (final lesson in lessons) {
      final id = lesson['id'] as int;
      final p = progress[id];
      if (p == null || p['read'] != true) continue;
      _event('lesson_read', id);
      final questions = lesson['questions'] as List;
      final previousAnswers = (p['answers'] as List? ?? []).cast<int>();
      final awarded = (p['awarded'] as List? ?? []).cast<int>();
      for (var i = 0; i < questions.length; i++) {
        final q = questions[i] as Map;
        if (awarded.contains(i)) {
          _event('quiz_answered', id, {
            'questionId': q['id'],
            'selectedOption': q['correct'],
          });
        }
        if (i < previousAnswers.length) {
          _event('quiz_answered', id, {
            'questionId': q['id'],
            'selectedOption': previousAnswers[i],
          });
        } else if (p['complete'] == true && !awarded.contains(i)) {
          // Old snapshots retained completion but discarded practice answers.
          // A wrong placeholder preserves completion without adding question XP.
          _event('quiz_answered', id, {
            'questionId': q['id'],
            'selectedOption':
                ((q['correct'] as int) + 1) % (q['options'] as List).length,
          });
        }
      }
      if (p['complete'] == true) _event('quiz_completed', id);
    }
    if (taskComplete) {
      _event('task_completed', 0, {'checklist': taskKeys});
    }
  }

  Future<void> _countPending() async {
    pendingEvents =
        Sqflite.firstIntValue(
          await database!.rawQuery('SELECT COUNT(*) FROM outbox'),
        ) ??
        0;
  }

  Future<void> _persist({List<String> acknowledged = const []}) {
    final content = jsonEncode(snapshot());
    final events = List<Map<String, dynamic>>.from(_newEvents);
    _newEvents.clear();
    final courseId = pack['id'] as String? ?? 'digital-safety-v1';
    final eventLanguage = lessonLanguage;
    final version = pack['version'] as int? ?? 1;
    _writes = _writes.catchError((Object _) {}).then((_) async {
      await database!.transaction((txn) async {
        for (final id in acknowledged) {
          await txn.delete('outbox', where: 'event_id = ?', whereArgs: [id]);
        }
        await txn.insert('state', {
          'id': 1,
          'json': content,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        for (final event in events) {
          await txn.insert('outbox', {
            'event_id': event['id'],
            'course_id': courseId,
            'version': version,
            'language': eventLanguage,
            'event_json': jsonEncode(event),
          });
        }
      });
      await _countPending();
    });
    return _writes;
  }

  Future<void> save() async {
    revision++;
    notifyListeners();
    await _persist();
    if (Platform.isIOS) {
      await const CourseReminderService().updateCourse(courseTitle);
    }
  }

  static const syncUrl = String.fromEnvironment(
    'LEARNING_SYNC_URL',
    defaultValue: '$apiUrl/api/v1/progress/sync',
  );
  bool get syncConfigured => baseUrl.isNotEmpty;

  final Map<String, Map<String, dynamic>> companionHelp = {};
  String get explanationPackKey => 'reviewed:$courseKey:$lessonLanguage';
  Map<String, dynamic>? get savedExplanations =>
      companionHelp[explanationPackKey];

  Future<Map<String, dynamic>> downloadExplanations() async {
    final key = explanationPackKey;
    final selectedCourse = courseId;
    final selectedVersion = courseVersion;
    final selectedLanguage = lessonLanguage;
    final Map<String, dynamic> result;
    try {
      result =
          jsonDecode(
                await _get(
                  '/api/v1/explanations/${Uri.encodeComponent(selectedCourse)}/$selectedLanguage?version=$selectedVersion',
                ),
              )
              as Map<String, dynamic>;
    } on HttpException catch (failure) {
      if (failure.message != 'HTTP 404') rethrow;
      return {
        'courseId': selectedCourse,
        'courseVersion': selectedVersion,
        'language': selectedLanguage,
        'available': false,
      };
    }
    if (result['courseId'] != selectedCourse ||
        result['courseVersion'] != selectedVersion ||
        result['language'] != selectedLanguage ||
        result['available'] is! bool) {
      throw const FormatException('Invalid explanation pack.');
    }
    if (result['available'] == false) return result;
    final entries = result['lessons'];
    if (result['explanationVersion'] is! int ||
        (result['explanationVersion'] as int) < 1 ||
        entries is! List ||
        entries.length != lessons.length) {
      throw const FormatException('Invalid explanation pack.');
    }
    for (var i = 0; i < entries.length; i++) {
      final item = entries[i];
      if (item is! Map ||
          item['id'] != i ||
          item['text'] is! String ||
          (item['text'] as String).trim().isEmpty ||
          (item['text'] as String).length > 6000) {
        throw const FormatException('Invalid explanation pack.');
      }
    }
    final previous = companionHelp[key];
    if (previous != null &&
        (previous['explanationVersion'] as int) >
            (result['explanationVersion'] as int)) {
      throw const FormatException('An older explanation version was returned.');
    }
    companionHelp[key] = result;
    await _persist();
    notifyListeners();
    return result;
  }

  String companionCacheKey(int id, String action) =>
      'groq-v1:$courseKey:$lessonLanguage:$id:$action';
  Future<Map<String, dynamic>> requestCompanion(int id, String action) async {
    if (![
          'explain',
          'practice',
          'suggestions',
          'prerequisites',
        ].contains(action) ||
        id < 0 ||
        id >= lessons.length ||
        !isUnlocked(id)) {
      throw const FormatException('Choose an unlocked lesson.');
    }
    final cacheKey = companionCacheKey(id, action);
    if (companionHelp.containsKey(cacheKey)) return companionHelp[cacheKey]!;
    final selectedCourse = courseId;
    final selectedVersion = courseVersion;
    final selectedLanguage = lessonLanguage;
    var token = await identity.read();
    if (token == null) {
      final registration = await _post('/api/v1/installations', {});
      token = registration['token'] as String;
      await identity.write(token);
    }
    final result = await _post(
      '/api/v1/learning-companion',
      {
        'courseId': selectedCourse,
        'version': selectedVersion,
        'language': selectedLanguage,
        'lessonId': id,
        'action': action,
      },
      token: token,
      responseTimeout: const Duration(seconds: 50),
    );
    if (result['text'] is! String || result['suggestions'] is! List) {
      throw const FormatException('Invalid AI help response.');
    }
    companionHelp[cacheKey] = {
      'text': result['text'],
      'suggestions': (result['suggestions'] as List)
          .whereType<String>()
          .where((s) => s.length <= 160)
          .take(3)
          .toList(),
    };
    await _persist();
    notifyListeners();
    return companionHelp[cacheKey]!;
  }

  Future<Map<String, dynamic>> _post(
    String route,
    Map<String, dynamic> body, {
    String? token,
    Duration responseTimeout = const Duration(seconds: 10),
  }) async {
    final endpoint = Uri.parse('$baseUrl$route');
    if (!isAllowedEndpoint(endpoint)) {
      throw const FormatException('HTTPS or loopback HTTP required');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .postUrl(endpoint)
          .timeout(const Duration(seconds: 10));
      request.headers.contentType = ContentType.json;
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      request.write(jsonEncode(body));
      final response = await request.close().timeout(responseTimeout);
      final raw = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final failure = jsonDecode(raw) as Map<String, dynamic>;
        throw HttpException(
          failure['message']?.toString() ??
              'Request failed (${response.statusCode})',
        );
      }
      return jsonDecode(raw) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  bool needsProgressRestore = false;

  List<Map<String, dynamic>> courseRequests = [];

  Future<void> refreshCourseRequests() async {
    final token = await identity.read();
    if (token == null) return;
    try {
      final result = await _post(
        '/api/v1/course-requests/status',
        {},
        token: token,
      );
      courseRequests = (result['requests'] as List)
          .cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (_) {
      /* Request status updates wait until connectivity returns. */
    }
  }

  Future<Map<String, dynamic>> requestCourse(
    String title,
    String source,
    String requestId,
  ) async {
    var token = await identity.read();
    if (token == null) {
      final registration = await _post('/api/v1/installations', {});
      token = registration['token'] as String;
      await identity.write(token);
    }
    final result = await _post('/api/v1/course-requests', {
      'title': title.trim(),
      'source': source,
      'language': preferredLanguage,
      'requestId': requestId,
    }, token: token);
    await refreshCourseRequests();
    return result;
  }

  Future<void> clearLocalProgress() async {
    if (syncing) throw StateError('Wait for synchronization to finish.');
    await _writes;
    needsProgressRestore = true;
    progress.clear();
    courseStates.clear();
    safetyChecklist.clear();
    taskComplete = false;
    xp = 0;
    confirmedPoints = 0;
    studyDays.clear();
    dailyReads.clear();
    dailyPractice.clear();
    coachingActivity.clear();
    coachingFeedback.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> restoreConfirmedProgress(String token) async {
    final response = await _post('/api/v1/progress/restore', {}, token: token);
    for (final item in response['courses'] as List) {
      final rows = await database!.query(
        'packs',
        where: 'course_id = ? AND version = ?',
        whereArgs: [item['courseId'], item['version']],
        limit: 1,
      );
      if (rows.isEmpty) continue;
      final content = jsonDecode(rows.first['json'] as String) as Map;
      final server = item['state'] as Map;
      final restored = <String, dynamic>{};
      for (final lesson in content['lessons'] as List) {
        final id = '${lesson['id']}';
        final value = (server['lessons'] as Map)[id] as Map?;
        if (value == null) continue;
        final answers = <int>[];
        for (final question in lesson['questions'] as List) {
          final selected = (value['answers'] as Map)[question['id']];
          if (selected == null) break;
          answers.add(selected as int);
        }
        restored[id] = {
          'read': value['read'] == true,
          'complete': value['complete'] == true,
          'answers': answers,
        };
      }
      final key = '${item['courseId']}:${item['version']}';
      final done = (server['rewards'] as Map).containsKey('final-task');
      courseStates[key] = {
        'progress': restored,
        'taskComplete': done,
        'safetyChecklist': done ? [0, 1, 2, 3] : [],
      };
      if (item['courseId'] == courseId && item['version'] == courseVersion) {
        progress.clear();
        for (final entry in restored.entries) {
          progress[int.parse(entry.key)] = Map<String, dynamic>.from(
            entry.value as Map,
          );
        }
        taskComplete = done;
      }
    }
    confirmedPoints = response['confirmedPoints'] as int;
    xp = confirmedPoints;
  }

  Future<void> sync() async {
    if (syncing || !syncConfigured) return;
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      await _writes;
      var token = await identity.read();
      if (token == null) {
        final registration = await _post('/api/v1/installations', {});
        token = registration['token'] as String;
        await identity.write(token);
      }
      final sentRevision = revision;
      while (true) {
        final rows = await database!.query(
          'outbox',
          orderBy: 'sequence',
          limit: 100,
        );
        if (rows.isEmpty) break;
        final courseId = rows.first['course_id'];
        final version = rows.first['version'];
        final batch = rows
            .takeWhile(
              (r) => r['course_id'] == courseId && r['version'] == version,
            )
            .toList();
        final ack = await _post('/api/v1/progress/sync', {
          'courseId': courseId,
          'version': version,
          'language': rows.first['language'],
          'events': batch
              .map((r) => jsonDecode(r['event_json'] as String))
              .toList(),
        }, token: token);
        final accepted = (ack['acceptedEventIds'] as List)
            .cast<String>()
            .toSet();
        if (!batch.every((r) => accepted.contains(r['event_id']))) {
          throw const FormatException('Missing event acknowledgement');
        }
        confirmedPoints = ack['confirmedPoints'] as int;
        await _persist(
          acknowledged: batch.map((r) => r['event_id'] as String).toList(),
        );
      }
      if (needsProgressRestore) {
        await restoreConfirmedProgress(token);
        needsProgressRestore = false;
      }
      syncedRevision = sentRevision;
      lastSync = DateTime.now().toIso8601String();
      await _persist();
    } catch (_) {
      syncError = 'Could not sync. Your progress is safe on this device.';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }
}
