import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_anywhere/main.dart';

void main() {
  testWidgets('Backend Markdown displays headings and bold without markers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonMarkdownBody(
            text:
                '## Key idea\n\nA **bold term** in a paragraph.\n\n- First item\n- Second item',
          ),
        ),
      ),
    );
    expect(find.text('Key idea'), findsOneWidget);
    expect(find.textContaining('bold term', findRichText: true), findsWidgets);
    expect(
      find.textContaining('**bold term**', findRichText: true),
      findsNothing,
    );
    expect(find.text('First item'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
