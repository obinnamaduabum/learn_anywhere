import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_anywhere/page_notices.dart';
import 'package:learn_anywhere/page_start_scroll.dart';

void main() {
  testWidgets(
    'navigation clears notices and ignores late responses from covered pages',
    (tester) async {
      late BuildContext source;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [PageStartScrollObserver()],
          home: Builder(
            builder: (context) {
              source = context;
              return const Scaffold(body: Text('First page'));
            },
          ),
        ),
      );
      showPageSnackBar(source, const SnackBar(content: Text('First notice')));
      await tester.pumpAndSettle();
      expect(find.text('First notice'), findsOneWidget);
      Navigator.of(source).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Second page')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('First notice'), findsNothing);
      showPageSnackBar(source, const SnackBar(content: Text('Late response')));
      await tester.pumpAndSettle();
      expect(find.text('Late response'), findsNothing);
      Navigator.of(source).pop();
      await tester.pumpAndSettle();
      expect(find.text('First notice'), findsNothing);
      expect(find.text('Late response'), findsNothing);
      showPageSnackBar(source, const SnackBar(content: Text('New notice')));
      await tester.pumpAndSettle();
      expect(find.text('New notice'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('inactive outgoing tabs cannot display notices', (tester) async {
    bool active = true;
    late BuildContext source;
    await tester.pumpWidget(
      MaterialApp(
        home: PageNoticeScope(
          isActive: () => active,
          child: Builder(
            builder: (context) {
              source = context;
              return const Scaffold(body: Text('Tab page'));
            },
          ),
        ),
      ),
    );
    showPageSnackBar(source, const SnackBar(content: Text('Tab notice')));
    await tester.pumpAndSettle();
    expect(find.text('Tab notice'), findsOneWidget);
    clearPageNotices(source);
    active = false;
    showPageSnackBar(source, const SnackBar(content: Text('Late tab notice')));
    await tester.pumpAndSettle();
    expect(find.text('Tab notice'), findsNothing);
    expect(find.text('Late tab notice'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
