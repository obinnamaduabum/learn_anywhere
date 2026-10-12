import 'dart:math';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';

import 'api_endpoint.dart';
import 'course_catalog.dart';
import 'course_reminders.dart';
import 'learner_profile.dart';
import 'store.dart';
import 'lesson_audio.dart';
import 'lesson_references.dart';
import 'page_start_scroll.dart';
import 'page_notices.dart';
import 'lan_share.dart';
import 'strings.dart';

const teal = Color(0xFF087F77);
const deepTeal = Color(0xFF075E57);
const ink = Color(0xFF142B3F);
const mint = Color(0xFFE6F4EE);
const canvas = Color(0xFFF7FBF9);
const gold = Color(0xFFF2B84B);
final pageStartScrollObserver = PageStartScrollObserver();

const darkCanvas = Color(0xFF101B20);
const darkSurface = Color(0xFF1B2B31);
const darkRaised = Color(0xFF263A42);
const darkInk = Color(0xFFEAF2F4);
const darkMuted = Color(0xFFB4C7CD);
const darkAccent = Color(0xFF80DACC);
const darkBorder = Color(0xFF40575F);

Color themeColor(BuildContext context, Color color) {
  if (Theme.of(context).brightness != Brightness.dark) return color;
  if (color == ink) return darkInk;
  if (color == teal || color == deepTeal) return darkAccent;
  if (color == Colors.white) return darkSurface;
  if (color == canvas) return darkCanvas;
  if (color == mint) return darkRaised;
  if (color.computeLuminance() > .65) return darkRaised;
  if (color.computeLuminance() < .25) return darkMuted;
  return color;
}

Color themeTextColor(BuildContext context, Color color) {
  final theme = Theme.of(context);
  if (theme.brightness != Brightness.dark) return color;
  final scheme = theme.colorScheme;
  if ([
    scheme.onSurface,
    scheme.onSurfaceVariant,
    scheme.onPrimary,
    scheme.onSecondary,
    scheme.primary,
    darkInk,
    darkMuted,
  ].contains(color)) {
    return color;
  }
  if (color == ink || color == Colors.white) return darkInk;
  if (color == teal || color == deepTeal) return darkAccent;
  return color.computeLuminance() < .25 ? darkMuted : color;
}

ThemeData darkTealTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: teal,
        brightness: Brightness.dark,
      ).copyWith(
        primary: darkAccent,
        onPrimary: const Color(0xFF073C35),
        secondary: const Color(0xFFA4CFC8),
        onSecondary: const Color(0xFF143B36),
        surface: darkSurface,
        onSurface: darkInk,
        onSurfaceVariant: darkMuted,
        surfaceContainerLowest: darkCanvas,
        surfaceContainerLow: darkSurface,
        surfaceContainer: darkSurface,
        surfaceContainerHigh: darkRaised,
        surfaceContainerHighest: darkRaised,
        outline: darkBorder,
        outlineVariant: darkBorder,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: darkCanvas,
    textTheme: ThemeData.dark().textTheme
        .apply(bodyColor: darkInk, displayColor: darkInk)
        .copyWith(
          headlineLarge: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: darkInk,
            letterSpacing: -1,
          ),
          headlineMedium: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: darkInk,
            letterSpacing: -.6,
          ),
          titleLarge: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: darkInk,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: darkInk,
          ),
          bodyLarge: const TextStyle(fontSize: 16, color: darkInk, height: 1.5),
          bodyMedium: const TextStyle(
            fontSize: 14,
            color: darkInk,
            height: 1.4,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkCanvas,
      foregroundColor: darkInk,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: darkSurface,
      indicatorColor: darkRaised,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected) ? darkInk : darkMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? darkAccent : darkMuted,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkRaised,
      hintStyle: const TextStyle(color: darkMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: darkAccent, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: darkAccent,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(0, 54),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: darkInk,
        side: const BorderSide(color: darkBorder),
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrap());
}

Future<LearningStore> initializeLearningStore() async {
  final path = await getDatabasesPath();
  final endpoint = await simulatorApiEndpoint(LearningStore.apiUrl);
  final store = LearningStore(
    Directory('$path/learn_anywhere'),
    baseUrl: endpoint,
  );
  await store.initialize();
  return store;
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key, this.initialize = initializeLearningStore});
  final Future<LearningStore> Function() initialize;
  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<LearningStore> initialization = widget.initialize();
  @override
  Widget build(BuildContext context) => FutureBuilder<LearningStore>(
    future: initialization,
    builder: (context, snapshot) {
      if (snapshot.hasData) return LearningApp(store: snapshot.data!);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: teal,
          scaffoldBackgroundColor: canvas,
        ),
        home: snapshot.hasError
            ? Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LearnAnywhereLogo(),
                        const SizedBox(height: 30),
                        const Text('Could not open your learning materials.'),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => setState(() {
                            initialization = widget.initialize();
                          }),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : const AppLoadingScreen(),
      );
    },
  );
}

class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LearnAnywhereLogo(),
          SizedBox(height: 30),
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: teal,
              strokeWidth: 3,
              semanticsLabel: 'Loading learning materials',
            ),
          ),
        ],
      ),
    ),
  );
}

class AppLanguageScope extends InheritedWidget {
  const AppLanguageScope({
    super.key,
    required this.language,
    required super.child,
  });
  final String language;
  @override
  bool updateShouldNotify(AppLanguageScope oldWidget) =>
      oldWidget.language != language;
}

class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  @override
  Widget build(BuildContext context) => Text(
    translate(
      context
              .dependOnInheritedWidgetOfExactType<AppLanguageScope>()
              ?.language ??
          'en',
      data,
    ),
    style: style?.color == null
        ? style
        : style!.copyWith(color: themeTextColor(context, style!.color!)),
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
  );
}

class PreferenceTextScaler extends TextScaler {
  const PreferenceTextScaler(this.system, this.factor);
  final TextScaler system;
  final double factor;
  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;
  @override
  double get textScaleFactor => system.scale(14) / 14 * factor;
}

class LearningApp extends StatelessWidget {
  const LearningApp({
    super.key,
    required this.store,
    this.showStartupLogo = true,
  });
  final bool showStartupLogo;
  final LearningStore store;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => MaterialApp(
      navigatorObservers: [pageStartScrollObserver],
      title: 'Learn Anywhere',
      darkTheme: darkTealTheme(),
      themeMode: store.darkTheme ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: PreferenceTextScaler(
            MediaQuery.textScalerOf(context),
            store.fontScale,
          ),
        ),
        child: AppLanguageScope(language: store.appLanguage, child: child!),
      ),
      // App strings are bundled, including locales not supported by Material.
      locale: Locale(
        ['fr', 'pt', 'ar'].contains(store.appLanguage)
            ? store.appLanguage
            : 'en',
      ),
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
        Locale('pt'),
        Locale('ar'),
      ],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: teal,
          primary: teal,
          surface: Colors.white,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: ink,
            letterSpacing: -1,
          ),
          headlineMedium: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: ink,
            letterSpacing: -.6,
          ),
          titleLarge: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: ink, height: 1.5),
          bodyMedium: TextStyle(fontSize: 14, color: ink, height: 1.4),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: canvas,
          foregroundColor: ink,
          centerTitle: false,
          elevation: 0,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: teal,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: teal,
            minimumSize: const Size(0, 50),
            side: const BorderSide(color: Color(0xFFC6E2DA)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: StartupPage(store: store, showLogo: showStartupLogo),
    ),
  );
}

class LearnAnywhereLogo extends StatelessWidget {
  const LearnAnywhereLogo({super.key});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 108,
        height: 108,
        decoration: BoxDecoration(
          color: themeColor(context, mint),
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.menu_book_rounded, size: 64, color: teal),
            Positioned(
              right: 9,
              bottom: 9,
              child: Icon(
                Icons.offline_bolt_rounded,
                color: deepTeal,
                size: 25,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      const AppText(
        'Learn Anywhere',
        style: TextStyle(
          fontSize: 28,
          color: deepTeal,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class StartupPage extends StatefulWidget {
  const StartupPage({super.key, required this.store, required this.showLogo});
  final LearningStore store;
  final bool showLogo;
  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  late bool loading = widget.showLogo;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    if (loading) {
      timer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => loading = false);
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => loading
      ? const AppLoadingScreen()
      : widget.store.hasChosenLanguage
      ? widget.store.hasCompletedLearnerProfile
            ? HomeShell(store: widget.store)
            : LearnerProfilePage(store: widget.store)
      : PreferredLanguagePage(store: widget.store);
}

class PreferredLanguagePage extends StatefulWidget {
  const PreferredLanguagePage({super.key, required this.store});
  final LearningStore store;
  @override
  State<PreferredLanguagePage> createState() => _PreferredLanguagePageState();
}

class _PreferredLanguagePageState extends State<PreferredLanguagePage> {
  String? selected;
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(24),
      child: FilledButton.icon(
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.arrow_forward),
        label: AppText(
          tr(widget.store, busy ? 'Applying language…' : 'Continue'),
        ),
        onPressed: selected == null || busy
            ? null
            : () async {
                setState(() => busy = true);
                try {
                  await widget.store.choosePreferredLanguage(selected!);
                } catch (_) {
                  if (context.mounted) {
                    message(
                      context,
                      'Could not save your preference. Please try again.',
                    );
                  }
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.translate, size: 48, color: teal),
          const SizedBox(height: 20),
          AppText(
            tr(widget.store, 'Choose your preferred language'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          const AppText(
            'Learn in a language you feel comfortable with. You can change it later. English is available when a translation is missing.',
          ),
          const SizedBox(height: 24),
          for (final language in LearningStore.lessonLanguages.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Surface(
                padding: EdgeInsets.zero,
                color: selected == language.key ? mint : Colors.white,
                child: ListTile(
                  title: AppText(language.value),
                  trailing: Icon(
                    selected == language.key
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: teal,
                  ),
                  selected: selected == language.key,
                  onTap: busy
                      ? null
                      : () => setState(() => selected = language.key),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

String tr(LearningStore s, String text) => translate(s.appLanguage, text);
void message(BuildContext context, String text) => showPageSnackBar(
  context,
  SnackBar(content: AppText(text), behavior: SnackBarBehavior.floating),
);
Future<void> bookmarkWithFeedback(
  BuildContext context,
  LearningStore store,
  int id,
) => safely(context, () async {
  await store.toggleBookmark(id);
  if (context.mounted) {
    message(
      context,
      store.isBookmarked(id) ? 'Lesson bookmarked' : 'Bookmark removed',
    );
  }
});

Future<void> safely(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted) {
      message(
        context,
        error is FormatException
            ? error.message
            : error is SocketException || error is TimeoutException
            ? 'This part is not saved yet. Reconnect to download it; saved lessons remain available.'
            : 'Could not complete this action. Your saved progress is safe. Try again.',
      );
    }
  }
}

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: themeColor(context, color),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Material(color: themeColor(context, color), child: child),
  );
}

class Pill extends StatelessWidget {
  const Pill(
    this.text,
    this.icon, {
    super.key,
    this.color = mint,
    this.foreground = deepTeal,
    this.textWidth,
  });
  final String text;
  final IconData icon;
  final Color color, foreground;
  final double? textWidth;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: themeColor(context, color),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: themeColor(context, foreground)),
        const SizedBox(width: 5),
        Flexible(
          child: SizedBox(
            width: textWidth,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: themeColor(context, foreground),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class DownloadNotificationButton extends StatelessWidget {
  const DownloadNotificationButton({
    super.key,
    required this.store,
    this.courseIds,
    this.title,
  });
  final LearningStore store;
  final Set<String>? courseIds;
  final String? title;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => IconButton(
      tooltip: 'Download notifications',
      icon: Badge(
        isLabelVisible: store.downloadActivity
            .where(
              (d) =>
                  (courseIds == null || courseIds!.contains(d['courseId'])) &&
                  (d['status'] == 'downloading' || d['status'] == 'saving'),
            )
            .isNotEmpty,
        label: AppText(
          '${store.downloadActivity.where((d) => (courseIds == null || courseIds!.contains(d['courseId'])) && (d['status'] == 'downloading' || d['status'] == 'saving')).length}',
        ),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => DownloadActivityPage(
            store: store,
            courseIds: courseIds,
            title: title,
          ),
        ),
      ),
    ),
  );
}

class DownloadActivityPage extends StatelessWidget {
  const DownloadActivityPage({
    super.key,
    required this.store,
    this.courseIds,
    this.title,
  });
  final LearningStore store;
  final Set<String>? courseIds;
  final String? title;
  List<Map<String, dynamic>> get entries => store.downloadActivity
      .where((d) => courseIds == null || courseIds!.contains(d['courseId']))
      .toList();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: AppText(
        title == null ? 'Download activity' : '$title · languages',
      ),
    ),
    body: AnimatedBuilder(
      animation: store,
      builder: (context, _) => entries.isEmpty
          ? const Center(
              child: AppText(
                'No downloads yet. Download a course or language pack to see progress here.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = entries[index];
                final status = item['status'] as String;
                final active = status == 'downloading' || status == 'saving';
                final received = item['received'] as int;
                final total = item['total'] as int;
                final progress = total > 0
                    ? (received / total).clamp(0.0, 1.0)
                    : null;
                return Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            status == 'complete'
                                ? Icons.download_done
                                : status == 'failed'
                                ? Icons.error_outline
                                : Icons.downloading,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppText(
                              item['title'] as String,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AppText(
                        LearningStore.lessonLanguages[item['language']] ??
                            item['language'] as String,
                      ),
                      const SizedBox(height: 12),
                      if (active)
                        LinearProgressIndicator(
                          value: status == 'saving' ? null : progress,
                        ),
                      const SizedBox(height: 8),
                      AppText(
                        status == 'complete'
                            ? 'Download completed'
                            : status == 'failed'
                            ? 'Download failed. Try again from the course or language selector.'
                            : status == 'saving'
                            ? 'Saving on this device…'
                            : progress == null
                            ? 'Downloading…'
                            : '${(progress * 100).round()}% · ${(received / 1024).toStringAsFixed(1)} / ${(total / 1024).toStringAsFixed(1)} KB',
                      ),
                    ],
                  ),
                );
              },
            ),
    ),
  );
}

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key, required this.store});
  final LearningStore store;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip:
        '${tr(store, 'Language')}: '
        '${LearningStore.languages[store.appLanguage] ?? store.appLanguage}',
    onPressed: () => showLanguages(context, store),
    icon: const Icon(Icons.language),
  );
}

void showLanguages(BuildContext context, LearningStore store) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => LanguagePanel(store: store),
    );

class LanguagePanel extends StatefulWidget {
  const LanguagePanel({super.key, required this.store});
  final LearningStore store;
  @override
  State<LanguagePanel> createState() => _LanguagePanelState();
}

class _LanguagePanelState extends State<LanguagePanel> {
  late String lesson = widget.store.preferredLanguage;
  bool busy = false;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) => PopScope(
      canPop: !busy,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: AppText(
                    tr(widget.store, 'Language'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppText(
              tr(widget.store, 'Preferred language'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: lesson,
              items: LearningStore.lessonLanguages.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: AppText(
                        '${e.value}${widget.store.downloaded.contains(e.key) ? ' · ✓' : ''}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: busy ? null : (v) => setState(() => lesson = v!),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.menu_book),
              ),
            ),
            const SizedBox(height: 16),
            const AppText(
              'Use this language for the app and lessons. Downloaded lessons work offline.',
              style: TextStyle(fontSize: 13, color: Color(0xFF607A80)),
            ),
            const SizedBox(height: 12),
            if (busy) ...[
              LinearProgressIndicator(value: widget.store.packDownloadProgress),
              const SizedBox(height: 8),
              AppText(
                widget.store.packDownloadProgress == null
                    ? 'Preparing language pack…'
                    : '${(widget.store.packDownloadProgress! * 100).round()}% downloaded',
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: AppText(
                  busy
                      ? (widget.store.downloaded.contains(lesson)
                            ? tr(widget.store, 'Applying languages…')
                            : tr(widget.store, 'Downloading language pack…'))
                      : tr(widget.store, 'Apply languages'),
                ),
                onPressed: busy
                    ? null
                    : () async {
                        widget.store.packDownloadProgress = null;
                        setState(() => busy = true);
                        try {
                          if (!widget.store.availablePackLanguages.contains(
                            lesson,
                          )) {
                            await widget.store.refreshCatalog();
                          }
                          await widget.store.changeLanguages(lesson, lesson);
                          if (mounted) setState(() => busy = false);
                          await WidgetsBinding.instance.endOfFrame;
                          if (context.mounted) {
                            message(
                              context,
                              widget.store.lessonLanguage != lesson
                                  ? 'Language not available'
                                  : widget.store.packNotice ??
                                        '${LearningStore.lessonLanguages[lesson]} selected for the app and lessons.',
                            );
                            final route = ModalRoute.of(context);
                            if (route != null && !route.isCurrent) {
                              Navigator.of(context).removeRoute(route);
                            } else {
                              Navigator.pop(context);
                            }
                          }
                        } catch (error) {
                          if (mounted) setState(() => busy = false);
                          await WidgetsBinding.instance.endOfFrame;
                          if (context.mounted) {
                            message(
                              context,
                              error is FormatException
                                  ? 'Language not available'
                                  : 'Could not download the language pack. Check your connection and try again.',
                            );
                            if (error is FormatException) {
                              final route = ModalRoute.of(context);
                              if (route != null && !route.isCurrent) {
                                Navigator.of(context).removeRoute(route);
                              } else {
                                Navigator.pop(context);
                              }
                            }
                          }
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});
  final LearningStore store;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int tab = 0;
  Timer? syncTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(widget.store.refreshCatalog());
        unawaited(widget.store.sync());
      }
    });
    syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (widget.store.pendingEvents > 0) {
        unawaited(widget.store.sync());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.store.refreshCatalog());
      unawaited(widget.store.sync());
      unawaited(widget.store.refreshCourseRequests());
    }
  }

  @override
  void dispose() {
    syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void selectTab(int next) {
    clearPageNotices(context);
    setState(() => tab = next);
    pageStartScrollObserver.reset(ModalRoute.of(context));
  }

  Widget tabPage() {
    final currentTab = tab;
    return PageNoticeScope(
      key: ValueKey('notice-tab-$currentTab'),
      isActive: () => mounted && tab == currentTab,
      child: [
        AdventurePage(store: widget.store, onDiscover: () => selectTab(1)),
        DiscoverPage(store: widget.store),
        DownloadsPage(store: widget.store),
        ProgressPage(store: widget.store),
      ][currentTab],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      titleSpacing: 12,
      title: const Row(
        children: [
          Icon(Icons.auto_stories, color: teal),
          SizedBox(width: 6),
          Expanded(
            child: AppText(
              'Learn Anywhere',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Bookmarked lessons',
          icon: const Icon(Icons.bookmarks_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => BookmarksPage(store: widget.store),
            ),
          ),
        ),
        LanguageButton(store: widget.store),
        const SizedBox(width: 4),
      ],
    ),
    body: AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: tabPage(),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: selectTab,
      backgroundColor: Theme.of(context).colorScheme.surface,
      indicatorColor: themeColor(context, mint),
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: themeColor(context, teal)),
          label: tr(widget.store, 'Home'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore, color: themeColor(context, teal)),
          label: tr(widget.store, 'Discover'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.download_outlined),
          selectedIcon: Icon(Icons.download, color: themeColor(context, teal)),
          label: tr(widget.store, 'Downloads'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person, color: themeColor(context, teal)),
          label: tr(widget.store, 'Profile'),
        ),
      ],
    ),
  );
}

void openLesson(BuildContext context, LearningStore store, int id) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => LessonPage(store: store, id: id),
    ),
  );
}

void resumeCourse(BuildContext context, LearningStore store) =>
    resumeCourseWithNavigator(Navigator.of(context), store);

void resumeCourseWithNavigator(NavigatorState navigator, LearningStore store) {
  if (store.lessons.isEmpty) return;
  final Widget page = store.completedCount == store.lessons.length
      ? FinalTaskPage(store: store)
      : store.lessonProgress(store.currentLesson)['read'] == true
      ? QuizPage(store: store, id: 0, finalAssessment: true)
      : LessonPage(store: store, id: store.currentLesson);
  navigator.push(MaterialPageRoute<void>(builder: (_) => page));
}

class AdventurePage extends StatelessWidget {
  const AdventurePage({super.key, required this.store, this.onDiscover});
  final VoidCallback? onDiscover;
  final LearningStore store;
  @override
  Widget build(BuildContext context) {
    if (!store.hasSelectedCurrentCourse && !store.hasOtherReadingCourses) {
      return ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const SizedBox(height: 20),
          Icon(
            Icons.explore_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          AppText(
            tr(store, 'Discover courses'),
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          AppText(
            tr(
              store,
              'Choose a course to start learning. Your progress will appear here.',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onDiscover,
            icon: const Icon(Icons.search),
            label: AppText(tr(store, 'Discover courses')),
          ),
        ],
      );
    }
    final readCount = store.lessons
        .where((lesson) => store.isRead(lesson['id'] as int))
        .length;
    return RefreshIndicator(
      onRefresh: store.refreshCatalog,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        children: [
          AppText(
            tr(store, 'Your courses'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (store.hasSelectedCurrentCourse)
            Surface(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          store.courseTitle,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontSize: 20, height: 1.3),
                        ),
                        const SizedBox(height: 8),
                        CourseCategoryLabel(
                          category: store.categoryForCourse(store.courseId),
                        ),
                        const SizedBox(height: 8),
                        AppText(
                          '$readCount / ${store.lessons.length} ${tr(store, 'Read').toLowerCase()} · ${LearningStore.lessonLanguages[store.lessonLanguage]}',
                        ),
                        if (store.lessons.isNotEmpty &&
                            readCount < store.lessons.length) ...[
                          const SizedBox(height: 12),
                          AppText(
                            store.lessons[store.currentLesson]['title']
                                as String,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AppText(
                            '${store.lessons[store.currentLesson]['minutes'] ?? '—'} min',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value:
                                readCount / math.max(1, store.lessons.length),
                            minHeight: 7,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: store.lessons.isEmpty
                                ? null
                                : () => resumeCourse(context, store),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: AppText(
                              tr(
                                store,
                                store.lessons.isNotEmpty &&
                                        store.completedCount ==
                                            store.lessons.length
                                    ? 'Final challenge'
                                    : readCount == store.lessons.length &&
                                          store.lessons.isNotEmpty
                                    ? 'Final quiz'
                                    : store.hasStartedCurrentCourse
                                    ? 'Continue learning'
                                    : 'Start course',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Pill('${store.xp} XP', Icons.star_outline_rounded),
              Pill(
                '${store.streak} ${tr(store, 'day streak')}',
                Icons.local_fire_department_outlined,
              ),
            ],
          ),
          if (store.hasOtherReadingCourses)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: store.otherReadingCourses(),
              builder: (context, snapshot) => Column(
                children: [
                  for (final course
                      in snapshot.data ?? <Map<String, dynamic>>[])
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: HomeReadingCourseCard(
                        store: store,
                        course: course,
                      ),
                    ),
                ],
              ),
            ),
          if (store.hasSelectedCurrentCourse) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppText(
                    tr(store, 'Learning path'),
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 20, height: 1.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            AppText(
              '${store.courseTitle} · ${tr(store, 'Learning path')}',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.zero,
              child: Stack(
                children: [
                  Column(
                    children: List.generate(store.lessons.length, (i) {
                      final complete = store.isComplete(i),
                          read = store.isRead(i);
                      return Padding(
                        padding: EdgeInsets.only(
                          left: 0,
                          right: 0,
                          bottom: i == store.lessons.length - 1 ? 0 : 10,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => openLesson(context, store, i),
                          child: Container(
                            key: ValueKey('learning-path-$i'),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: themeColor(
                                context,
                                read ? mint : Colors.white,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: read
                                    ? teal
                                    : Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: complete ? teal : deepTeal,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: complete || read
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                          )
                                        : AppText(
                                            '${i + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AppText(
                                        store.lessons[i]['title'] as String,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: ink,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      AppText(
                                        '${tr(store, complete
                                            ? 'Completed'
                                            : read
                                            ? 'Read'
                                            : 'Not read')} · ${store.lessons[i]['minutes'] ?? '—'} min',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: teal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: teal,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: store.lessons.isEmpty
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => QuizPage(
                          store: store,
                          id: 0,
                          finalAssessment: true,
                        ),
                      ),
                    ),
              icon: const Icon(Icons.quiz_outlined),
              label: AppText(tr(store, 'Final quiz')),
            ),
          ],
        ],
      ),
    );
  }
}

class HomeReadingCourseCard extends StatefulWidget {
  const HomeReadingCourseCard({
    super.key,
    required this.store,
    required this.course,
  });
  final LearningStore store;
  final Map<String, dynamic> course;
  @override
  State<HomeReadingCourseCard> createState() => _HomeReadingCourseCardState();
}

class _HomeReadingCourseCardState extends State<HomeReadingCourseCard> {
  bool opening = false;
  Future<void> resume() async {
    if (opening) return;
    setState(() => opening = true);
    final navigator = Navigator.of(context);
    final store = widget.store;
    final course = widget.course;
    try {
      await store.selectCourse(course);
      if (navigator.mounted) resumeCourseWithNavigator(navigator, store);
    } catch (_) {
      if (mounted) {
        message(context, 'Could not open this saved course. Please try again.');
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          widget.course['title'] as String,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontSize: 20, height: 1.3),
        ),
        const SizedBox(height: 8),
        CourseCategoryLabel(
          category: '${widget.course['category'] ?? 'General Learning'}',
        ),
        const SizedBox(height: 8),
        AppText(
          '${widget.course['readCount']} / ${widget.course['lessonCount']} ${tr(widget.store, 'Read').toLowerCase()} · ${LearningStore.languages[widget.course['language']]}',
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value:
              (widget.course['readCount'] as int) /
              math.max(1, widget.course['lessonCount'] as int),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: opening ? null : resume,
            icon: opening
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: AppText(
              tr(
                widget.store,
                widget.course['readCount'] == widget.course['lessonCount']
                    ? 'Final quiz'
                    : 'Continue learning',
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class CourseCategoryLabel extends StatelessWidget {
  const CourseCategoryLabel({super.key, required this.category});
  final String category;
  @override
  Widget build(BuildContext context) {
    final label = category.trim().isEmpty
        ? 'General Learning'
        : category.trim();
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Material(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => message(context, label),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: AppText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key, required this.store});
  final LearningStore store;
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  String search = '';
  final searchController = TextEditingController();
  String? opening;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_catalogChanged);
  }

  Future<void> _refresh() async {
    await widget.store.refreshCatalog();
    if (!mounted) return;
    message(
      context,
      widget.store.catalogError ??
          'Courses refreshed. Open a course to download its latest version.',
    );
  }

  void _catalogChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(DiscoverPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_catalogChanged);
      widget.store.addListener(_catalogChanged);
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_catalogChanged);
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courses = widget.store.catalog.isEmpty
        ? <Map<String, dynamic>>[
            {
              'id': 'digital-safety-v1',
              'title': 'Digital Safety',
              'description':
                  'Five small lessons for a safer digital life. Starter pack included.',
              'lessonCount': 5,
              'packs': [
                {'language': 'en', 'version': 1},
              ],
            },
          ]
        : widget.store.catalog;
    final grouped = groupCourses(courses).toList();
    final ordered = grouped;
    final matching = ordered.where(
      (c) => [
        c['title'],
        c['description'],
        c['category'],
        for (final part in (c['parts'] as List? ?? const []))
          '${part['title']} ${part['description'] ?? ''}',
      ].join(' ').toLowerCase().contains(search.trim().toLowerCase()),
    );
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor:
            Theme.of(context).textTheme.headlineLarge?.color ??
            Theme.of(context).colorScheme.onSurface,
        tooltip: 'Request a course',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                CourseRequestPage(store: widget.store, initialTitle: search),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 90),
          children: [
            AppText(
              tr(widget.store, 'Discover'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: searchController,
              onChanged: (v) => setState(() => search = v),
              decoration: InputDecoration(
                hintText: tr(widget.store, 'Find a course'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: search.isEmpty
                    ? null
                    : IconButton(
                        tooltip: tr(widget.store, 'Clear search'),
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          setState(() => search = '');
                        },
                      ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFFDCEAE3)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: AppText(
                    'Small courses. Useful everyday skills.',
                    style: TextStyle(color: Color(0xFF6D8385), fontSize: 13),
                  ),
                ),
                IconButton(
                  onPressed: widget.store.refreshing ? null : _refresh,
                  tooltip: tr(widget.store, 'Refresh'),
                  icon: widget.store.refreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (widget.store.catalogError != null) ...[
              Surface(color: mint, child: AppText(widget.store.catalogError!)),
              const SizedBox(height: 10),
            ],
            for (final course in matching)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              course['title'] as String,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontSize: 20, height: 1.3),
                            ),
                          ),
                          IconButton(
                            tooltip:
                                widget.store.bookmarkedCourses.contains(
                                  course['id'],
                                )
                                ? 'Remove course bookmark'
                                : 'Bookmark course',
                            icon: Icon(
                              widget.store.bookmarkedCourses.contains(
                                    course['id'],
                                  )
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: teal,
                            ),
                            onPressed: () => safely(context, () async {
                              final id = course['id'] as String;
                              await widget.store.toggleCourseBookmark(id);
                              if (mounted && context.mounted) {
                                setState(() {});
                                message(
                                  context,
                                  widget.store.bookmarkedCourses.contains(id)
                                      ? 'Course bookmarked'
                                      : 'Bookmark removed',
                                );
                              }
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CourseCategoryLabel(
                        category: '${course['category'] ?? 'General Learning'}',
                      ),
                      const SizedBox(height: 10),
                      AppText(
                        course['description'] as String,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Pill(
                            '${course['lessonCount']} lessons',
                            Icons.menu_book_outlined,
                          ),
                          if (course['parts'] != null)
                            Pill(
                              '${(course['parts'] as List).length} parts',
                              Icons.collections_bookmark_outlined,
                            ),
                          Pill(
                            course['parts'] != null
                                ? 'Quiz after each part'
                                : 'Quiz at the end',
                            Icons.quiz_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: opening != null
                              ? null
                              : () => safely(context, () async {
                                  setState(
                                    () => opening = course['id'] as String,
                                  );
                                  try {
                                    if (course['parts'] != null) {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => SeriesPage(
                                            store: widget.store,
                                            course: course,
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    await widget.store.selectCourse(course);
                                    if (context.mounted) {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              CoursePage(store: widget.store),
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) setState(() => opening = null);
                                  }
                                }),
                          icon: const Icon(Icons.arrow_forward),
                          label: AppText(
                            opening == course['id']
                                ? 'Opening course…'
                                : course['parts'] != null
                                ? 'View series'
                                : tr(widget.store, 'View course'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (matching.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const AppText(
                      'No matching courses. Try another topic or request one.',
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const AppText('Request a course'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => CourseRequestPage(
                            store: widget.store,
                            initialTitle: search.trim(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CourseRequestPage extends StatefulWidget {
  const CourseRequestPage({
    super.key,
    required this.store,
    this.initialTitle = '',
  });
  final LearningStore store;
  final String initialTitle;
  @override
  State<CourseRequestPage> createState() => _CourseRequestPageState();
}

class _CourseRequestPageState extends State<CourseRequestPage> {
  late final title = TextEditingController(text: widget.initialTitle);
  String source = 'ai';
  bool sending = false;
  String? notice;
  String requestId = '';
  @override
  void initState() {
    super.initState();
    widget.store.refreshCourseRequests();
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  String newRequestId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const AppText('Request a course')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const AppText(
            'Cannot find what you need? Request a course by title.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: title,
            maxLength: 160,
            enabled: !sending,
            onChanged: (_) => requestId = '',
            decoration: const InputDecoration(
              labelText: 'Course title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ai', label: AppText('AI-generated')),
              ButtonSegment(value: 'human', label: AppText('Human-authored')),
            ],
            selected: {source},
            onSelectionChanged: sending
                ? null
                : (selection) => setState(() {
                    source = selection.single;
                    requestId = '';
                  }),
          ),
          const SizedBox(height: 16),
          const AppText(
            'AI: up to 3 requests per day (UTC). Generation continues on the backend after you disconnect. All generated courses need approval. Human requests are sent for authoring.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: AppText(sending ? 'Sending request…' : 'Submit request'),
            onPressed: sending
                ? null
                : () async {
                    if (title.text.trim().isEmpty) {
                      setState(() => notice = 'Enter a course title.');
                      return;
                    }
                    setState(() {
                      sending = true;
                      notice = null;
                    });
                    if (requestId.isEmpty) requestId = newRequestId();
                    try {
                      final result = await widget.store.requestCourse(
                        title.text,
                        source,
                        requestId,
                      );
                      if (mounted) {
                        setState(() {
                          notice = source == 'ai'
                              ? 'Request queued. ${result['remaining'] ?? 0} AI requests remaining today. You can disconnect now.'
                              : 'Request sent for human authoring.';
                          requestId = '';
                        });
                      }
                    } catch (error) {
                      if (mounted) {
                        setState(
                          () => notice = error.toString().replaceFirst(
                            'HttpException: ',
                            '',
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => sending = false);
                    }
                  },
          ),
          if (notice != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: AppText(notice!),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: AppText('Your course requests')),
              IconButton(
                tooltip: 'Refresh requests',
                onPressed: widget.store.refreshCourseRequests,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          for (final request in widget.store.courseRequests)
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: AppText(request['title'] as String),
              subtitle: AppText(switch (request['status']) {
                'queued' => 'Queued for generation',
                'generating' => 'Generating on the backend',
                'awaiting_approval' => 'Draft ready · awaiting approval',
                'published' => 'Approved · available in Discover',
                'failed' => 'Generation failed · submit a new request',
                _ => 'Awaiting human authoring',
              }),
            ),
        ],
      ),
    ),
  );
}

class SeriesPage extends StatefulWidget {
  const SeriesPage({super.key, required this.store, required this.course});
  final LearningStore store;
  final Map<String, dynamic> course;
  @override
  State<SeriesPage> createState() => _SeriesPageState();
}

class _SeriesPageState extends State<SeriesPage> {
  String? opening;
  bool savingSeries = false;
  String? saveNotice;
  bool saveFailed = false;
  final attemptedAutoDownloads = <String>{};

  Map<String, dynamic> get currentCourse =>
      widget.store.catalog
          .where((course) => course['id'] == widget.course['id'])
          .firstOrNull ??
      widget.course;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_storeChanged);
    considerAutoDownload();
  }

  @override
  void didUpdateWidget(SeriesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_storeChanged);
      widget.store.addListener(_storeChanged);
      attemptedAutoDownloads.clear();
    }
    considerAutoDownload();
  }

  @override
  void dispose() {
    widget.store.removeListener(_storeChanged);
    super.dispose();
  }

  void _storeChanged() {
    if (!mounted) return;
    setState(() {});
    considerAutoDownload();
  }

  void considerAutoDownload() {
    if (!widget.store.autoDownload || savingSeries) return;
    final key = '${currentCourse['id']}:${widget.store.preferredLanguage}';
    if (!attemptedAutoDownloads.add(key)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentKey =
          '${currentCourse['id']}:${widget.store.preferredLanguage}';
      if (!widget.store.autoDownload || savingSeries || currentKey != key) {
        attemptedAutoDownloads.remove(key);
        if (currentKey != key) considerAutoDownload();
        return;
      }
      unawaited(saveSeries(automatic: true));
    });
  }

  Future<void> saveSeries({bool automatic = false}) async {
    if (savingSeries) return;
    setState(() {
      savingSeries = true;
      saveNotice = null;
      saveFailed = false;
    });
    try {
      await widget.store.saveSeries(currentCourse);
      if (mounted) {
        setState(
          () => saveNotice = 'Series saved. Its lessons are ready offline.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          saveFailed = true;
          saveNotice = error is FormatException
              ? error.message
              : 'Could not save every part. Saved lessons remain available; reconnect to retry.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => savingSeries = false);
        if (automatic) considerAutoDownload();
      }
    }
  }

  int readCount(Map<String, dynamic> part) {
    final versions = (part['packs'] as List).map(
      (p) => p['version'] as int? ?? 1,
    );
    final version = versions.isEmpty ? 1 : versions.reduce(math.max);
    final store = widget.store;
    if (part['id'] == store.courseId && version == store.courseVersion) {
      return store.progress.values.where((p) => p['read'] == true).length;
    }
    final saved = store.courseStates["${part['id']}:$version"] as Map?;
    final progress = saved?['progress'] as Map?;
    return progress?.values.where((p) => p['read'] == true).length ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final course =
            widget.store.catalog
                .where((c) => c['id'] == widget.course['id'])
                .firstOrNull ??
            widget.course;
        final parts = (course['parts'] as List).cast<Map<String, dynamic>>();
        return Scaffold(
          appBar: AppBar(title: AppText(course['title'] as String)),
          body: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Surface(
                color: mint,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppText(
                            '${parts.length} parts · ${course['lessonCount']} lessons',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        DownloadNotificationButton(
                          store: widget.store,
                          title: course['title'] as String,
                          courseIds: parts
                              .map((p) => p['id'] as String)
                              .toSet(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const AppText(
                      'Save parts before going offline. Read each part, then take its final quiz.',
                    ),
                    if (savingSeries ||
                        (!widget.store.isSeriesSaved(currentCourse) &&
                            (!widget.store.autoDownload || saveFailed)))
                      TextButton.icon(
                        onPressed: savingSeries || parts.isEmpty
                            ? null
                            : saveSeries,
                        icon: savingSeries
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_outlined),
                        label: AppText(
                          savingSeries
                              ? 'Saving series…'
                              : saveFailed
                              ? 'Retry download'
                              : 'Save all parts offline',
                        ),
                      ),
                    if (saveNotice != null)
                      AppText(
                        saveNotice!,
                        style: const TextStyle(fontSize: 13),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SavedCourseLanguages(store: widget.store, course: course),
              for (final part in parts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Surface(
                    color: readCount(part) > 0 ? mint : Colors.white,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: mint,
                        child: AppText('${part['partIndex']}'),
                      ),
                      title: AppText(part['title'] as String),
                      subtitle: AppText(
                        readCount(part) >= (part['lessonCount'] as int)
                            ? 'Read · quiz at the end'
                            : readCount(part) > 0
                            ? '${readCount(part)} / ${part['lessonCount']} lessons read'
                            : '${part['lessonCount']} lessons · quiz at the end',
                      ),
                      trailing: opening == part['id']
                          ? const CircularProgressIndicator()
                          : Icon(
                              readCount(part) >= (part['lessonCount'] as int)
                                  ? Icons.check_circle_outline
                                  : Icons.chevron_right,
                              color: teal,
                            ),
                      onTap: opening != null
                          ? null
                          : () => safely(context, () async {
                              setState(() => opening = part['id'] as String);
                              try {
                                await widget.store.selectCourse(part);
                                if (context.mounted) {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          CoursePage(store: widget.store),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => opening = null);
                              }
                            }),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class SavedCourseLanguages extends StatelessWidget {
  const SavedCourseLanguages({
    super.key,
    required this.store,
    required this.course,
  });
  final LearningStore store;
  final Map<String, dynamic> course;

  @override
  Widget build(BuildContext context) {
    final counts = store.savedLanguageCounts(course);
    final total = (course['parts'] as List?)?.length ?? 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('Languages saved on this device'),
          const SizedBox(height: 6),
          if (counts.isEmpty)
            const AppText(
              'No languages saved yet',
              style: TextStyle(fontSize: 13),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: counts.entries
                  .map(
                    (entry) => Chip(
                      label: AppText(
                        total > 1
                            ? '${LearningStore.lessonLanguages[entry.key]} · ${entry.value}/$total parts'
                            : LearningStore.lessonLanguages[entry.key]!,
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class CoursePage extends StatelessWidget {
  const CoursePage({super.key, required this.store});
  final LearningStore store;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: AppText(store.courseTitle),
        actions: [LanguageButton(store: store)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          AppText(
            'Course contents',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          AppText(
            '${store.lessons.length} lessons · ${List.generate(store.lessons.length, (i) => i).where(store.isRead).length} read',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          const AppText(
            'Read each lesson, then take the final quiz.',
            style: TextStyle(fontSize: 13),
          ),
          SavedCourseLanguages(store: store, course: {'id': store.courseId}),
          const SizedBox(height: 18),
          ...List.generate(
            store.lessons.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Surface(
                color: store.isRead(i) ? mint : Colors.white,
                padding: const EdgeInsets.all(4),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: themeColor(context, mint),
                    child: AppText(
                      '${i + 1}',
                      style: const TextStyle(color: teal),
                    ),
                  ),
                  title: AppText(
                    store.lessons[i]['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: AppText(
                    tr(
                      store,
                      store.isComplete(i)
                          ? 'Completed'
                          : store.isRead(i)
                          ? 'Read'
                          : 'Not read',
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    store.isRead(i)
                        ? Icons.check_circle_outline
                        : Icons.chevron_right,
                    color: themeColor(context, teal),
                  ),
                  onTap: () => openLesson(context, store, i),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    QuizPage(store: store, id: 0, finalAssessment: true),
              ),
            ),
            icon: const Icon(Icons.quiz_outlined),
            label: const AppText('Take final quiz'),
          ),
          if (store.completedCount == store.lessons.length)
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => QuizReviewPage(store: store),
                ),
              ),
              icon: const Icon(Icons.fact_check_outlined),
              label: const AppText('Review answers'),
            ),
        ],
      ),
    ),
  );
}

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key, required this.store});
  final LearningStore store;
  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  late Future<List<Map<String, dynamic>>> saved;
  String signature = '';
  String? opening;
  @override
  void initState() {
    super.initState();
    saved = widget.store.savedCourseLibrary();
    widget.store.addListener(changed);
  }

  void changed() {
    if (!mounted) return;
    final next =
        '${widget.store.downloaded.join(',')}:${widget.store.downloadActivity.map((item) => '${item['key']}:${item['status']}').join(',')}';
    setState(() {
      if (signature != next) {
        saved = widget.store.savedCourseLibrary();
        signature = next;
      }
    });
  }

  @override
  void dispose() {
    widget.store.removeListener(changed);
    super.dispose();
  }

  Future<void> open(Map<String, dynamic> course, bool manage) async {
    if (opening != null) return;
    final navigator = Navigator.of(context);
    final store = widget.store;
    setState(() => opening = course['id'] as String);
    try {
      if (course['parts'] != null) {
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => SeriesPage(store: store, course: course),
          ),
        );
      } else {
        await store.selectCourse(course);
        if (navigator.mounted) {
          await navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => manage
                  ? CourseDownloadsPage(store: store)
                  : CoursePage(store: store),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        message(context, 'Could not open saved course. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          opening = null;
          saved = store.savedCourseLibrary();
        });
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: saved,
    builder: (context, snapshot) {
      final courses = snapshot.data ?? <Map<String, dynamic>>[];
      final active = widget.store.downloadActivity
          .where(
            (item) =>
                item['status'] == 'downloading' || item['status'] == 'saving',
          )
          .toList();
      return RefreshIndicator(
        onRefresh: () async {
          final next = widget.store.savedCourseLibrary();
          setState(() => saved = next);
          await next;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(22),
          children: [
            AppText(
              tr(widget.store, 'Downloads'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            AppText(
              tr(widget.store, 'Courses saved for offline learning'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            if (active.isNotEmpty) ...[
              AppText(
                tr(widget.store, 'Downloading'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final item in active)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          '${item['title']} · ${LearningStore.languages[item['language']]}',
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value:
                              (item['total'] as int? ?? 0) > 0 &&
                                  item['status'] != 'saving'
                              ? ((item['received'] as int) /
                                        (item['total'] as int))
                                    .clamp(0.0, 1.0)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
            if (snapshot.hasError)
              AppText(
                tr(
                  widget.store,
                  'Could not load saved courses. Pull down to retry.',
                ),
              ),
            if (!snapshot.hasData && !snapshot.hasError)
              const Center(child: CircularProgressIndicator()),
            if (snapshot.hasData && courses.isEmpty) ...[
              AppText(
                tr(widget.store, 'No saved courses yet'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              AppText(
                tr(
                  widget.store,
                  'Open a course in Discover to save it on this device.',
                ),
              ),
            ],
            if (courses.isNotEmpty)
              AppText(
                '${courses.length} ${tr(widget.store, 'Saved courses')}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            for (final course in courses)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        course['title'] as String,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final lang in course['savedLanguages'] as List)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: AppText(
                                  course['parts'] == null
                                      ? '${LearningStore.languages[lang]}'
                                      : '${LearningStore.languages[lang]} · ${(course['savedUnits'] as List).where((unit) => unit['language'] == lang).length}/${(course['parts'] as List).length} ${tr(widget.store, 'parts saved')}',
                                ),
                              ),
                            ],
                          ),
                        ),
                      AppText(
                        '${tr(widget.store, 'Ready offline')} · ${(course['savedBytes'] as int) / 1024 >= 1024 ? '${((course['savedBytes'] as int) / 1048576).toStringAsFixed(1)} MB' : '${((course['savedBytes'] as int) / 1024).toStringAsFixed(1)} KB'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: opening != null
                              ? null
                              : () => open(course, false),
                          icon: opening == course['id']
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.menu_book_outlined),
                          label: AppText(tr(widget.store, 'Open course')),
                        ),
                      ),
                      TextButton(
                        onPressed: opening != null
                            ? null
                            : () => open(course, true),
                        child: AppText(
                          tr(
                            widget.store,
                            course['parts'] == null
                                ? 'Manage languages'
                                : 'View parts',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => DownloadActivityPage(store: widget.store),
                ),
              ),
              icon: const Icon(Icons.history),
              label: AppText(tr(widget.store, 'Download activity')),
            ),
          ],
        ),
      );
    },
  );
}

class CourseDownloadsPage extends StatefulWidget {
  const CourseDownloadsPage({super.key, required this.store});
  final LearningStore store;
  @override
  State<CourseDownloadsPage> createState() => _CourseDownloadsPageState();
}

class _CourseDownloadsPageState extends State<CourseDownloadsPage> {
  String? busy;
  Future<void> download(String lang) async {
    setState(() => busy = lang);
    await safely(context, () async {
      await widget.store.savePack(lang);
      if (mounted) {
        message(
          context,
          widget.store.packNotice ??
              '${LearningStore.lessonLanguages[lang]} ready offline.',
        );
      }
    });
    if (mounted) setState(() => busy = null);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: AppText(tr(widget.store, 'Manage languages'))),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          AppText(
            widget.store.courseTitle,
            key: const Key('downloads-course-title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ...LearningStore.lessonLanguages.entries
              .where((e) => widget.store.availablePackLanguages.contains(e.key))
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Surface(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: mint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.language, color: teal),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                e.value,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              FutureBuilder<int>(
                                future: widget.store.packBytes(e.key),
                                builder: (_, s) => AppText(
                                  '${widget.store.lessons.length} lessons · ${s.hasData ? '${(s.data! / 1024).toStringAsFixed(1)} KB' : '…'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6D8385),
                                  ),
                                ),
                              ),
                              if (widget.store.downloaded.contains(e.key))
                                AppText(
                                  tr(widget.store, 'Ready offline'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: teal,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        busy == e.key
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : widget.store.downloaded.contains(e.key)
                            ? PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'refresh') download(e.key);
                                  if (v == 'remove') {
                                    safely(
                                      context,
                                      () => widget.store.removePack(e.key),
                                    );
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'refresh',
                                    child: AppText('Update download'),
                                  ),
                                  if (e.key != 'en' &&
                                      e.key != widget.store.lessonLanguage)
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: AppText('Remove from device'),
                                    ),
                                ],
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: teal,
                                ),
                              )
                            : IconButton(
                                onPressed: busy != null
                                    ? null
                                    : () => download(e.key),
                                tooltip: tr(widget.store, 'Download pack'),
                                icon: const Icon(
                                  Icons.download_rounded,
                                  color: teal,
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 16),
          const AppText(
            'These language packs belong to the selected course. Saved packs work offline. Downloading or updating a pack requires a connection.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6D8385)),
          ),
        ],
      ),
    ),
  );
}

/// Adapt obsolete navigation instructions for display and speech only.
String lessonReadingText(String body) => body.replaceAll(
  RegExp(
    r'(?:Then )?Complete all three quiz questions (?:to unlock the next lesson|before moving on)\.',
    caseSensitive: false,
  ),
  'Read all lessons in this part, then take the final quiz.',
);

class LessonReadingBody extends StatelessWidget {
  const LessonReadingBody({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final paragraph in paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Builder(
              builder: (context) {
                final match = RegExp(
                  r'^([^\n:.!?]{1,48}):\s+([\s\S]+)$',
                ).firstMatch(paragraph.trim());
                final body = match == null ? paragraph.trim() : match.group(2)!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (match != null) ...[
                      Semantics(
                        header: true,
                        child: AppText(
                          '${match.group(1)}:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    AppText(
                      body,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.65),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

class LessonPage extends StatefulWidget {
  const LessonPage({super.key, required this.store, required this.id});
  final LearningStore store;
  final int id;
  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  final scroll = ScrollController(keepScrollOffset: false);
  Timer? readingSave;
  late final readingCourseKey = widget.store.courseKey;
  double readingFraction = 0;
  final Completer<void> initialPosition = Completer<void>();
  bool atEnd = false;
  bool advancing = false;
  double swipeDistance = 0;
  bool showExplained = false;
  bool loadingExplanation = false;

  String? get explainedText => widget.store.lessonExplanationText(widget.id);

  Future<void> toggleExplanation() async {
    if (loadingExplanation) return;
    final key = widget.store.explanationPackKey;
    if (showExplained && explainedText != null) {
      setState(() => showExplained = false);
    } else {
      if (explainedText == null) {
        setState(() => loadingExplanation = true);
        try {
          await widget.store.loadLessonExplanation(widget.id);
        } catch (failure) {
          if (mounted) {
            message(
              context,
              tr(
                widget.store,
                failure is HttpException &&
                        failure.message.contains('not configured')
                    ? 'Explanations are not available yet. Your lesson is ready to read.'
                    : 'Could not load an explanation. Reconnect and try again.',
              ),
            );
          }
          return;
        } finally {
          if (mounted) setState(() => loadingExplanation = false);
        }
      }
      if (!mounted || key != widget.store.explanationPackKey) return;
      if (explainedText == null) {
        message(
          context,
          tr(
            widget.store,
            'Explanations are not available yet for this course and language.',
          ),
        );
        return;
      }
      setState(() => showExplained = true);
    }
    if (!mounted) return;
    message(
      context,
      '${tr(widget.store, showExplained ? 'Explained version' : 'Regular version')}.',
    );
    setState(() => atEnd = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.jumpTo(scroll.position.minScrollExtent);
      }
    });
  }

  Future<void> continueLesson() async {
    if (advancing) return;
    setState(() => advancing = true);
    try {
      await safely(context, () async {
        if (atEnd || widget.store.isRead(widget.id)) {
          await widget.store.readLesson(widget.id);
        }
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => widget.id < widget.store.lessons.length - 1
                ? LessonPage(store: widget.store, id: widget.id + 1)
                : QuizPage(store: widget.store, id: 0, finalAssessment: true),
          ),
        );
      });
    } finally {
      if (mounted) setState(() => advancing = false);
    }
  }

  void finishSwipe(DragEndDetails details) {
    final forward = widget.store.lessonLanguage == 'ar'
        ? swipeDistance >= 80
        : swipeDistance <= -80;
    swipeDistance = 0;
    if (forward) {
      unawaited(continueLesson());
    }
  }

  @override
  void initState() {
    super.initState();
    showExplained = widget.store.preferExplained && explainedText != null;
    if (widget.store.preferExplained && explainedText == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) toggleExplanation();
      });
    }
    scroll.addListener(() {
      if (scroll.hasClients && initialPosition.isCompleted) {
        final extent = scroll.position.maxScrollExtent;
        readingFraction = extent <= 0
            ? 1
            : (scroll.offset / extent).clamp(0.0, 1.0);
        readingSave?.cancel();
        readingSave = Timer(const Duration(milliseconds: 700), () {
          if (widget.store.courseKey != readingCourseKey) return;
          widget.store
              .saveReadingPosition(widget.id, readingFraction)
              .catchError((Object _) {});
        });
      }
      if (scroll.hasClients && scroll.position.extentAfter < 30 && !atEnd) {
        setState(() => atEnd = true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        readingFraction = 0;
        scroll.jumpTo(scroll.position.minScrollExtent);
      }
      initialPosition.complete();
      if (mounted &&
          scroll.hasClients &&
          scroll.position.maxScrollExtent <= 0) {
        setState(() => atEnd = true);
      }
    });
  }

  @override
  void dispose() {
    readingSave?.cancel();
    if (readingFraction > 0 && widget.store.courseKey == readingCourseKey) {
      widget.store
          .saveReadingPosition(widget.id, readingFraction)
          .catchError((Object _) {});
    }
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final lesson = widget.store.lessons[widget.id];
      // Older downloaded packs describe the former per-lesson quiz flow.
      final isExplained = showExplained && explainedText != null;
      final lessonBody = lessonReadingText(
        isExplained ? explainedText! : lesson['body'] as String,
      );
      return Directionality(
        textDirection: widget.store.lessonLanguage == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: Scaffold(
          floatingActionButton: FloatingActionButton(
            heroTag: 'lesson-explanation',
            backgroundColor: isExplained ? gold : teal,
            foregroundColor: isExplained ? ink : Colors.white,
            tooltip: tr(
              widget.store,
              isExplained ? 'Regular version' : 'Explained version',
            ),
            onPressed: loadingExplanation ? null : toggleExplanation,
            child: loadingExplanation
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isExplained ? Icons.lightbulb : Icons.lightbulb_outline,
                    color: isExplained ? ink : Colors.white,
                  ),
          ),
          appBar: AppBar(
            title: AppText(
              'Lesson ${widget.id + 1} / ${widget.store.lessons.length}',
              style: const TextStyle(fontSize: 17),
            ),
            actions: [
              IconButton(
                tooltip: widget.store.isBookmarked(widget.id)
                    ? 'Remove bookmark'
                    : 'Bookmark lesson',
                onPressed: () =>
                    bookmarkWithFeedback(context, widget.store, widget.id),
                icon: Icon(
                  widget.store.isBookmarked(widget.id)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                ),
              ),
              LanguageButton(store: widget.store),
            ],
          ),
          body: GestureDetector(
            key: const ValueKey('lesson-swipe-area'),
            onHorizontalDragStart: (_) => swipeDistance = 0,
            onHorizontalDragUpdate: (details) =>
                swipeDistance += details.primaryDelta ?? 0,
            onHorizontalDragEnd: finishSwipe,
            onHorizontalDragCancel: () => swipeDistance = 0,
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 110),
              children: [
                AppText(
                  lesson['title'] as String,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 10),
                AppText(
                  lesson['subtitle'] as String,
                  style: const TextStyle(color: teal, fontSize: 17),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Pill(
                      '${isExplained ? (lessonBody.trim().split(RegExp(r"\s+")).length + 199) ~/ 200 : lesson['minutes'] ?? '—'} min',
                      Icons.schedule,
                    ),
                    Pill(
                      tr(widget.store, 'Ready offline'),
                      Icons.cloud_done_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LessonAudio(
                  autoRead: widget.store.autoReadAloud,
                  text:
                      '${lesson['title']}. ${lesson['subtitle']}. $lessonBody',
                  language: widget.store.lessonLanguage,
                ),
                const SizedBox(height: 16),
                if (loadingExplanation) const LinearProgressIndicator(),
                if (isExplained)
                  AppText(
                    widget.store.savedExplanations == null
                        ? '${tr(widget.store, 'Explained version')} · ${tr(widget.store, 'AI-generated')}'
                        : '${tr(widget.store, 'Explained version')} · ${widget.store.savedExplanations!['explanationVersion']}',
                  ),
                LessonReadingBody(text: lessonBody),
                const SizedBox(height: 24),
                Surface(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText(
                        'Reference for further reading',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6D8385),
                        ),
                      ),
                      for (final source in lessonReferences(lesson)) ...[
                        const SizedBox(height: 12),
                        AppText(
                          source['name']!,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        SelectableText(
                          source['url']!,
                          style: const TextStyle(color: teal, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const AppText(
                  'Keep reading. Your quiz comes at the end of this part.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: teal, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: !advancing ? continueLesson : null,
                  icon: const Icon(Icons.quiz),
                  label: AppText(
                    widget.id < widget.store.lessons.length - 1
                        ? 'Next lesson'
                        : 'Take final quiz',
                  ),
                ),
                if (widget.id < widget.store.lessons.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: AppText(
                      widget.store.lessonLanguage == 'ar'
                          ? 'Swipe right to continue. You can skip lessons.'
                          : 'Swipe left to continue. You can skip lessons.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class QuizIntroPage extends StatelessWidget {
  const QuizIntroPage({super.key, required this.store, required this.id});
  final LearningStore store;
  final int id;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: AppText(tr(store, 'Play lesson quiz')),
      actions: [LanguageButton(store: store)],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        const Center(child: ShieldMascot(size: 155)),
        const SizedBox(height: 28),
        AppText(
          store.lessons[id]['title'] as String,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        const AppText(
          'Put your new skills into practice.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 26),
        Surface(
          color: mint,
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.quiz_outlined, color: teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppText('3 questions · ${tr(store, 'No timer')}'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Icon(Icons.stars_rounded, color: teal),
                  SizedBox(width: 12),
                  Expanded(
                    child: AppText(
                      '+10 XP for each correct answer\n+50 XP for first completion',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Icon(Icons.lock_open, color: teal),
                  SizedBox(width: 12),
                  Expanded(
                    child: AppText(
                      'Read the lessons, then complete the quiz and review your answers.',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(
              builder: (_) => QuizPage(store: store, id: id),
            ),
          ),
          icon: const Icon(Icons.play_arrow),
          label: AppText(
            tr(
              store,
              store.answers(id).isEmpty
                  ? 'Play lesson quiz'
                  : 'Continue lesson',
            ),
          ),
        ),
        const SizedBox(height: 12),
        const AppText(
          'Answers save offline after each question.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6D8385), fontSize: 12),
        ),
      ],
    ),
  );
}

class QuizPage extends StatefulWidget {
  const QuizPage({
    super.key,
    required this.store,
    required this.id,
    this.finalAssessment = false,
  });
  final bool finalAssessment;
  final LearningStore store;
  final int id;
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final scroll = ScrollController(keepScrollOffset: false);
  late int index;
  int? selected;
  bool checked = false, busy = false;
  @override
  void initState() {
    super.initState();
    final count = widget.store.questionIndex(widget.id);
    index = count > 0 ? count - 1 : 0;
    if (count > 0) {
      selected = widget.store.answers(widget.id)[index];
      checked = true;
    }
  }

  Future<void> check() async {
    if (selected == null || busy) return;
    setState(() => busy = true);
    try {
      await widget.store.answer(widget.id, index, selected!);
      if (widget.store.sound) await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.lightImpact();
      if (mounted) {
        setState(() => checked = true);
      }
    } catch (_) {
      if (mounted) {
        message(context, 'Could not save your answer. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (mounted && checked) await next();
  }

  Future<void> next() async {
    if (busy) return;
    final questions = widget.store.lessons[widget.id]['questions'] as List;
    if (index == questions.length - 1) {
      setState(() => busy = true);
      await safely(context, () async {
        await widget.store.completeQuiz(widget.id);
        unawaited(widget.store.sync());
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  widget.finalAssessment &&
                      widget.id < widget.store.lessons.length - 1
                  ? QuizPage(
                      store: widget.store,
                      id: widget.id + 1,
                      finalAssessment: true,
                    )
                  : QuizResultPage(
                      store: widget.store,
                      id: widget.id,
                      finalAssessment: widget.finalAssessment,
                    ),
            ),
          );
        }
      });
      if (mounted) setState(() => busy = false);
    } else {
      setState(() {
        index++;
        selected = null;
        checked = false;
      });
      if (scroll.hasClients) scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final questions = widget.store.lessons[widget.id]['questions'] as List;
      final q = questions[index] as Map<String, dynamic>;
      final preceding = widget.finalAssessment
          ? widget.store.lessons
                .take(widget.id)
                .fold<int>(
                  0,
                  (sum, lesson) => sum + (lesson['questions'] as List).length,
                )
          : 0;
      final total = widget.finalAssessment
          ? widget.store.lessons.fold<int>(
              0,
              (sum, lesson) => sum + (lesson['questions'] as List).length,
            )
          : questions.length;
      final current = preceding + index;

      return Directionality(
        textDirection: widget.store.lessonLanguage == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
            title: AppText(
              widget.finalAssessment ? 'Final quiz' : 'Lesson quiz',
              style: const TextStyle(fontSize: 17),
            ),
            actions: [
              IconButton(
                tooltip: 'Toggle quiz sound',
                onPressed: () => safely(context, () async {
                  widget.store.sound = !widget.store.sound;
                  await widget.store.save();
                }),
                icon: Icon(
                  widget.store.sound
                      ? Icons.volume_up_outlined
                      : Icons.volume_off_outlined,
                ),
              ),
              LanguageButton(store: widget.store),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: FilledButton.icon(
              onPressed: busy || !checked && selected == null
                  ? null
                  : checked
                  ? next
                  : check,
              icon: Icon(checked ? Icons.arrow_forward : Icons.check),
              label: AppText(
                tr(
                  widget.store,
                  checked
                      ? index == questions.length - 1
                            ? widget.finalAssessment &&
                                      widget.id <
                                          widget.store.lessons.length - 1
                                  ? 'Next question'
                                  : 'See score'
                            : 'Next question'
                      : index == questions.length - 1 &&
                            (!widget.finalAssessment ||
                                widget.id == widget.store.lessons.length - 1)
                      ? 'Submit quiz'
                      : 'Next question',
                ),
              ),
            ),
          ),
          body: ListView(
            controller: scroll,
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  AppText(
                    '${current + 1} ${tr(widget.store, 'of')} $total',
                    style: const TextStyle(
                      color: teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(
                  total,
                  (i) => Expanded(
                    child: Container(
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: i <= current ? teal : const Color(0xFFDCE9E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              AppText(
                q['prompt'] as String,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 22),
              ...List.generate((q['options'] as List).length, (i) {
                final chosen = selected == i;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    selected: chosen,
                    button: true,
                    label:
                        '${String.fromCharCode(65 + i)}. ${(q['options'] as List)[i]}',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: themeColor(
                          context,
                          chosen ? const Color(0xFFF0FAF6) : Colors.white,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: chosen ? teal : const Color(0xFFDDE9E3),
                          width: chosen ? 2 : 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: checked
                            ? null
                            : () => setState(() => selected = i),
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: chosen ? teal : canvas,
                                child: AppText(
                                  String.fromCharCode(65 + i),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: chosen ? Colors.white : ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: AppText(
                                  (q['options'] as List)[i] as String,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 14),
              const SizedBox(height: 24),
              const SizedBox(height: 14),
              AppText(
                tr(widget.store, 'Saved on this device'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6D8385)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class QuizResultPage extends StatefulWidget {
  const QuizResultPage({
    super.key,
    required this.store,
    required this.id,
    this.finalAssessment = false,
  });
  final bool finalAssessment;
  final LearningStore store;
  final int id;
  @override
  State<QuizResultPage> createState() => _QuizResultPageState();
}

class _QuizResultPageState extends State<QuizResultPage>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: AppText(tr(widget.store, 'Quiz complete!'))),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(
          height: 210,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (_, _) =>
                      CustomPaint(painter: ConfettiPainter(controller.value)),
                ),
              ),
              const ShieldMascot(size: 160),
            ],
          ),
        ),
        AppText(
          tr(widget.store, 'Quiz complete!'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 12),
        AppText(
          widget.finalAssessment
              ? '${List.generate(widget.store.lessons.length, widget.store.score).reduce((a, b) => a + b)} / ${widget.store.lessons.fold<int>(0, (n, l) => n + (l['questions'] as List).length)} ${tr(widget.store, 'correct')}'
              : '${widget.store.score(widget.id)} / ${(widget.store.lessons[widget.id]['questions'] as List).length} ${tr(widget.store, 'correct')}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        const SizedBox(height: 20),
        Center(
          child: Pill(
            '${widget.store.xp} XP',
            Icons.star_rounded,
            color: const Color(0xFFFFEDBD),
            foreground: const Color(0xFF8A5B00),
          ),
        ),
        const SizedBox(height: 24),
        Surface(
          color: mint,
          child: Row(
            children: [
              const Icon(Icons.lock_open_rounded, color: teal, size: 32),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      (widget.finalAssessment ||
                              widget.id == widget.store.lessons.length - 1)
                          ? tr(widget.store, 'Final challenge')
                          : 'Next lesson: ${widget.id + 2}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const AppText(
                      'You finished every question. Review your answers to learn why.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () {
            Navigator.popUntil(context, (r) => r.isFirst);
            if ((widget.finalAssessment ||
                widget.id == widget.store.lessons.length - 1)) {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => FinalTaskPage(store: widget.store),
                ),
              );
            } else {
              openLesson(context, widget.store, widget.id + 1);
            }
          },
          icon: const Icon(Icons.arrow_forward),
          label: AppText(
            tr(
              widget.store,
              (widget.finalAssessment ||
                      widget.id == widget.store.lessons.length - 1)
                  ? 'Final challenge'
                  : 'Continue lesson',
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => QuizReviewPage(
                store: widget.store,
                lessonId: widget.finalAssessment ? null : widget.id,
              ),
            ),
          ),
          icon: const Icon(Icons.fact_check_outlined),
          label: const AppText('Review answers'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => safely(context, () async {
            if (widget.finalAssessment) {
              for (var id = 0; id < widget.store.lessons.length; id++) {
                await widget.store.resetQuiz(id);
              }
            } else {
              await widget.store.resetQuiz(widget.id);
            }
            if (context.mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => QuizPage(
                    store: widget.store,
                    id: widget.finalAssessment ? 0 : widget.id,
                    finalAssessment: widget.finalAssessment,
                  ),
                ),
              );
            }
          }),
          icon: const Icon(Icons.replay),
          label: AppText(tr(widget.store, 'Practice again')),
        ),
        const SizedBox(height: 14),
        const AppText(
          'Practice builds confidence. Completion rewards are earned once.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFF6D8385)),
        ),
      ],
    ),
  );
}

class QuizReviewPage extends StatelessWidget {
  const QuizReviewPage({super.key, required this.store, this.lessonId});
  final LearningStore store;
  final int? lessonId;
  @override
  Widget build(BuildContext context) {
    final ids = lessonId == null
        ? List.generate(store.lessons.length, (i) => i)
        : [lessonId!];
    final finished = ids.every(
      (id) =>
          store.isComplete(id) &&
          store.answers(id).length ==
              (store.lessons[id]['questions'] as List).length,
    );
    return Directionality(
      textDirection: store.lessonLanguage == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: const AppText('Review answers')),
        body: !finished
            ? const Center(
                child: AppText('Finish the quiz to review your answers.'),
              )
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  for (final id in ids) ...[
                    AppText(
                      store.lessons[id]['title'] as String,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    for (
                      var i = 0;
                      i < (store.lessons[id]['questions'] as List).length;
                      i++
                    )
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Surface(
                          child: Builder(
                            builder: (context) {
                              final question =
                                  (store.lessons[id]['questions'] as List)[i]
                                      as Map;
                              final options = question['options'] as List;
                              final answer = store.answers(id)[i];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(
                                    question['prompt'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  AppText('Your answer: ${options[answer]}'),
                                  const SizedBox(height: 8),
                                  AppText(
                                    'Correct answer: ${options[question['correct'] as int]}',
                                    style: const TextStyle(
                                      color: teal,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  AppText(question['explanation'] as String),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key, required this.store});
  final LearningStore store;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      AppText(
        tr(store, 'Your progress'),
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 8),
      AppText(
        store.courseTitle,
        key: const Key('progress-course-title'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 24),
      Surface(
        color: mint,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            stat('${store.xp}', 'XP', Icons.star_rounded),
            stat(
              '${store.completedCount}/${store.lessons.length}',
              tr(store, 'Completed'),
              Icons.menu_book,
            ),
            stat(
              '${store.streak}',
              tr(store, 'day streak'),
              Icons.local_fire_department,
            ),
          ],
        ),
      ),
      const SizedBox(height: 26),
      AppText(
        tr(store, 'Your badges'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          badge(
            Icons.shield_outlined,
            tr(store, 'Safety Explorer'),
            store.completedCount >= 1,
          ),
          const SizedBox(width: 12),
          badge(
            Icons.workspace_premium,
            'Quiz Champion',
            store.completedCount >= math.min(3, store.lessons.length),
          ),
          const SizedBox(width: 12),
          badge(Icons.emoji_events, 'Digital Hero', store.taskComplete),
        ],
      ),
      const SizedBox(height: 26),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Your next milestone',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            AppText(
              store.completedCount < math.min(3, store.lessons.length)
                  ? 'Complete ${math.min(3, store.lessons.length)} lessons'
                  : store.completedCount < store.lessons.length
                  ? 'Complete all ${store.lessons.length} lessons'
                  : 'Finish your practical task',
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: math.min(
                store.completedCount /
                    (store.completedCount < math.min(3, store.lessons.length)
                        ? math.max(1, math.min(3, store.lessons.length))
                        : math.max(1, store.lessons.length)),
                1,
              ),
              minHeight: 7,
              backgroundColor: mint,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              tr(store, 'Final challenge'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            AppText(
              store.courseId == 'digital-safety-v1'
                  ? tr(store, 'Build your safety checklist')
                  : 'Put your new skill into practice',
            ),
            const SizedBox(height: 15),
            FilledButton.icon(
              onPressed:
                  (store.lessons.isNotEmpty &&
                      store.completedCount == store.lessons.length)
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => FinalTaskPage(store: store),
                      ),
                    )
                  : null,
              icon: Icon(
                (store.lessons.isNotEmpty &&
                        store.completedCount == store.lessons.length)
                    ? Icons.checklist
                    : Icons.lock_outline,
              ),
              label: AppText(
                tr(store, store.taskComplete ? 'Completed' : 'Final challenge'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      AppText('Settings', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'Appearance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              key: const Key('appearance-theme'),
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.light_mode_outlined),
                  label: AppText('Teal light'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: AppText('Teal dark'),
                ),
              ],
              selected: {store.darkTheme},
              onSelectionChanged: (selection) =>
                  safely(context, () => store.setDarkTheme(selection.single)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              tr(store, 'Font size'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: tr(store, 'Decrease font size'),
                  onPressed: store.fontScale <= .85
                      ? null
                      : () => safely(
                          context,
                          () => store.setFontScale(store.fontScale - .05),
                        ),
                  icon: const Icon(Icons.text_decrease),
                ),
                Expanded(
                  child: AppText(
                    '${(store.fontScale * 100).round()}%',
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  tooltip: tr(store, 'Increase font size'),
                  onPressed: store.fontScale >= 1.4
                      ? null
                      : () => safely(
                          context,
                          () => store.setFontScale(store.fontScale + .05),
                        ),
                  icon: const Icon(Icons.text_increase),
                ),
              ],
            ),
            TextButton(
              onPressed: store.fontScale == 1
                  ? null
                  : () => safely(context, () => store.setFontScale(1)),
              child: AppText(tr(store, 'Reset font size')),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      Surface(
        child: ListTile(
          leading: const Icon(Icons.person_outline),
          title: AppText(tr(store, 'Your learner profile')),
          subtitle: const AppText('Optional date of birth and gender'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => LearnerProfilePage(store: store, editing: true),
            ),
          ),
        ),
      ),
      const SizedBox(height: 22),
      Surface(
        child: SwitchListTile(
          key: const Key('auto-download-setting'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.download_for_offline_outlined),
          title: const AppText('Auto-download'),
          subtitle: const AppText(
            'Automatically save opened series in your preferred language.',
          ),
          value: store.autoDownload,
          onChanged: (value) =>
              safely(context, () => store.setAutoDownload(value)),
        ),
      ),
      const SizedBox(height: 22),
      if (kDebugMode) ...[
        const Surface(child: CourseReminderSetting()),
        const SizedBox(height: 22),
      ],
      Surface(
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.volume_up_outlined),
          title: const AppText('Auto-play lesson audio'),
          subtitle: const AppText(
            'Automatically read lessons when opened. Turn off to start playback manually.',
          ),
          value: store.autoReadAloud,
          onChanged: (value) =>
              safely(context, () => store.setAutoReadAloud(value)),
        ),
      ),
      const SizedBox(height: 22),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'Accessibility',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: AppText('Read controls with VoiceOver'),
              subtitle: AppText('Touch to hear; double-tap to activate.'),
              children: [
                AppText(
                  '1. Open iPhone Settings → Accessibility → VoiceOver.\n'
                  '2. Turn VoiceOver on.\n'
                  '3. Touch an item to hear its name.\n'
                  '4. Double-tap to activate the selected item.\n'
                  '5. Swipe left or right to move between items.\n'
                  '6. Swipe with three fingers to scroll.',
                ),
                SizedBox(height: 10),
                AppText(
                  'VoiceOver is an iPhone setting. The Auto-play lesson audio option does not turn it on. If both voices speak together, turn automatic lesson reading off and use VoiceOver.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => LanSharePage(store: store)),
        ),
        icon: const Icon(Icons.wifi),
        label: const AppText('Sharing settings'),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        icon: const Icon(Icons.restart_alt),
        label: const AppText('Clear local progress'),
        onPressed: store.syncing
            ? null
            : () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const AppText('Clear local progress?'),
                    content: const AppText(
                      'This resets progress shown on this device. Downloaded lessons and backend progress stay saved. Previously synced progress returns when you sync. Pending activity is kept for synchronization.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const AppText('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const AppText('Clear progress'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await safely(context, store.clearLocalProgress);
                }
              },
      ),
      const SizedBox(height: 12),
      LanguageButton(store: store),
      const SizedBox(height: 16),
      const AppText(
        'A fresh start is always welcome. No lives to lose, no timer, and no personal profile required.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Color(0xFF6D8385)),
      ),
    ],
  );
  Widget stat(String number, String label, IconData icon) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: teal),
        const SizedBox(height: 8),
        AppText(
          number,
          style: const TextStyle(
            fontSize: 24,
            color: ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        AppText(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    ),
  );
  Widget badge(IconData icon, String title, bool earned) => Expanded(
    child: Surface(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      color: earned ? const Color(0xFFFFF3D5) : const Color(0xFFF0F4F1),
      child: Column(
        children: [
          Icon(
            earned ? icon : Icons.lock_outline,
            size: 34,
            color: earned ? const Color(0xFFB48123) : const Color(0xFFAFBDB5),
          ),
          const SizedBox(height: 10),
          AppText(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class FinalTaskPage extends StatelessWidget {
  const FinalTaskPage({super.key, required this.store});
  final LearningStore store;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, _) => Scaffold(
      appBar: AppBar(title: AppText(tr(store, 'Final challenge'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: ShieldMascot(size: 120)),
          const SizedBox(height: 24),
          AppText(
            store.courseId == 'digital-safety-v1'
                ? tr(store, 'Build your safety checklist')
                : 'Put your new skill into practice',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 14),
          const AppText(
            'Apply what you learned. Complete these actions on your own device, then mark them here. Never enter your password into this app.',
          ),
          const SizedBox(height: 24),
          ...List.generate(
            4,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Surface(
                padding: EdgeInsets.zero,
                child: CheckboxListTile(
                  value: store.safetyChecklist.contains(i),
                  onChanged: store.taskComplete
                      ? null
                      : (v) => safely(
                          context,
                          () => store.toggleTask(i, v ?? false),
                        ),
                  title: AppText(store.taskLabels[i]),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed:
                !store.taskComplete &&
                    store.safetyChecklist.length == 4 &&
                    store.completedCount == store.lessons.length
                ? () => safely(context, () async {
                    await store.finishTask();
                    unawaited(store.sync());
                    if (context.mounted) {
                      message(
                        context,
                        '${tr(store, 'Course complete!')} +100 XP',
                      );
                    }
                  })
                : null,
            icon: const Icon(Icons.emoji_events),
            label: AppText(
              tr(
                store,
                store.taskComplete ? 'Course complete!' : 'Complete course',
              ),
            ),
          ),
          if (store.taskComplete)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Center(
                child: Pill(
                  'Digital Hero · +100 XP',
                  Icons.workspace_premium,
                  color: Color(0xFFFFEABD),
                  foreground: Color(0xFF8A5B00),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class ShieldMascot extends StatelessWidget {
  const ShieldMascot({super.key, this.size = 100, this.happy = true});
  final double size;
  final bool happy;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Friendly safety shield',
    image: true,
    child: SizedBox(
      width: size,
      height: size * 1.05,
      child: CustomPaint(painter: ShieldPainter(happy)),
    ),
  );
}

class ShieldPainter extends CustomPainter {
  ShieldPainter(this.happy);
  final bool happy;
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    c.drawOval(
      Rect.fromCenter(
        center: Offset(w * .5, h * .94),
        width: w * .65,
        height: h * .08,
      ),
      Paint()..color = teal.withValues(alpha: .12),
    );
    final path = Path()
      ..moveTo(w * .5, h * .05)
      ..quadraticBezierTo(w * .67, h * .2, w * .89, h * .2)
      ..lineTo(w * .83, h * .58)
      ..quadraticBezierTo(w * .77, h * .79, w * .5, h * .91)
      ..quadraticBezierTo(w * .23, h * .79, w * .17, h * .58)
      ..lineTo(w * .11, h * .2)
      ..quadraticBezierTo(w * .33, h * .2, w * .5, h * .05)
      ..close();
    c.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF66D3BE), teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    c.drawPath(
      path,
      Paint()
        ..color = deepTeal
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .025,
    );
    c.drawCircle(Offset(w * .36, h * .44), w * .043, Paint()..color = ink);
    c.drawCircle(Offset(w * .64, h * .44), w * .043, Paint()..color = ink);
    c.drawCircle(
      Offset(w * .35, h * .43),
      w * .014,
      Paint()..color = Colors.white,
    );
    c.drawCircle(
      Offset(w * .63, h * .43),
      w * .014,
      Paint()..color = Colors.white,
    );
    c.drawCircle(
      Offset(w * .27, h * .53),
      w * .048,
      Paint()..color = const Color(0xFFFFCBA6).withValues(alpha: .7),
    );
    c.drawCircle(
      Offset(w * .73, h * .53),
      w * .048,
      Paint()..color = const Color(0xFFFFCBA6).withValues(alpha: .7),
    );
    c.drawArc(
      Rect.fromLTWH(w * .39, h * .51, w * .22, h * .14),
      0,
      math.pi,
      false,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .024
        ..strokeCap = StrokeCap.round,
    );
    c.drawLine(
      Offset(w * .17, h * .48),
      Offset(w * .03, h * .39),
      Paint()
        ..color = deepTeal
        ..strokeWidth = w * .055
        ..strokeCap = StrokeCap.round,
    );
    c.drawLine(
      Offset(w * .83, h * .48),
      Offset(w * .97, h * .34),
      Paint()
        ..color = deepTeal
        ..strokeWidth = w * .055
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(ShieldPainter old) => old.happy != happy;
}

class QuestPathPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0xFFD4E9DD)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(s.width * .35, 30);
    for (var i = 0; i < 4; i++) {
      final y = (i + 1) * s.height / 5;
      path.quadraticBezierTo(
        i.isEven ? s.width * .9 : s.width * .1,
        y - s.height / 10,
        i.isEven ? s.width * .6 : s.width * .35,
        y + 30,
      );
    }
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(QuestPathPainter old) => false;
}

class ConfettiPainter extends CustomPainter {
  ConfettiPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas c, Size s) {
    final random = math.Random(7);
    for (var i = 0; i < 40; i++) {
      final x = random.nextDouble() * s.width;
      final y = (random.nextDouble() * s.height + progress * 100) % s.height;
      c.save();
      c.translate(x, y);
      c.rotate(random.nextDouble() * math.pi + progress * 3);
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 5, 10),
          const Radius.circular(2),
        ),
        Paint()
          ..color = [
            teal,
            gold,
            const Color(0xFF83CAB3),
          ][i % 3].withValues(alpha: 1 - progress * .45),
      );
      c.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) => old.progress != progress;
}

class BookmarksPage extends StatelessWidget {
  const BookmarksPage({super.key, required this.store});
  final LearningStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final ids = List.generate(
        store.lessons.length,
        (i) => i,
      ).where(store.isBookmarked).toList();
      return Scaffold(
        appBar: AppBar(title: const AppText('Bookmarks')),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            if (store.bookmarkedCourses.isNotEmpty) ...[
              AppText('Courses', style: Theme.of(context).textTheme.titleLarge),
              for (final courseId in store.bookmarkedCourses.toList())
                ListTile(
                  key: ValueKey('saved-course-$courseId'),
                  title: AppText(
                    store.catalog.where((c) => c['id'] == courseId).isNotEmpty
                        ? '${store.catalog.firstWhere((c) => c['id'] == courseId)['title']}'
                        : courseId == store.courseId
                        ? store.courseTitle
                        : courseId,
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove course bookmark',
                    icon: const Icon(Icons.bookmark),
                    onPressed: () => safely(context, () async {
                      await store.toggleCourseBookmark(courseId);
                      if (context.mounted) message(context, 'Bookmark removed');
                    }),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            if (ids.isEmpty)
              const AppText(
                'No bookmarks in this course yet. Tap the bookmark icon while reading a lesson.',
              ),
            for (final id in ids)
              ListTile(
                title: AppText('${store.lessons[id]['title']}'),
                subtitle: AppText('Lesson ${id + 1}'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => LessonPage(store: store, id: id),
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Remove bookmark',
                  icon: const Icon(Icons.bookmark),
                  onPressed: () => bookmarkWithFeedback(context, store, id),
                ),
              ),
          ],
        ),
      );
    },
  );
}
