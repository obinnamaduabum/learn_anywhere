import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_anywhere/lesson_audio.dart';

void main() {
  testWidgets('missing voice popup can be cancelled and read aloud retried', (
    tester,
  ) async {
    const channel = MethodChannel('learn_anywhere/speech');
    var attempts = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'speak') {
            attempts++;
            throw PlatformException(code: 'no_voice');
          }
          return null;
        });
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonAudio(text: 'Lesson', language: 'en'),
        ),
      ),
    );
    await tester.tap(find.text('Read aloud'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('No voice is available'), findsNothing);
    await tester.tap(find.text('Read aloud'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
