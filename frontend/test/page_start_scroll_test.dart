import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_anywhere/page_start_scroll.dart';

void main() {
  testWidgets('forward navigation and return both start pages at the top', (
    tester,
  ) async {
    final observer = PageStartScrollObserver();
    final first = ScrollController();
    final second = ScrollController();
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) {
            pageContext = context;
            return Scaffold(
              body: ListView(
                controller: first,
                children: const [SizedBox(height: 3000)],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    first.jumpTo(500);
    await tester.pump();
    Navigator.of(pageContext).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: ListView(
            controller: second,
            children: const [SizedBox(height: 3000)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(second.offset, 0);
    second.jumpTo(700);
    await tester.pump();
    Navigator.of(pageContext).pop();
    await tester.pumpAndSettle();
    expect(first.offset, 0);
    first.jumpTo(400);
    await tester.pump();
    observer.reset(ModalRoute.of(pageContext));
    await tester.pumpAndSettle();
    expect(first.offset, 0);
    await tester.pumpWidget(const SizedBox());
    first.dispose();
    second.dispose();
  });
}
