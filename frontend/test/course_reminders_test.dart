import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_anywhere/course_reminders.dart';

class FakeReminders extends CourseReminderService {
  bool value = false;
  bool denied = false;
  @override
  bool get supported => true;
  @override
  Future<bool> enabled() async => value;
  @override
  Future<bool> setEnabled(bool enabled) async {
    if (denied) {
      throw PlatformException(
        code: 'permission',
        message: 'Allow notifications in Settings.',
      );
    }
    return value = enabled;
  }
}

class NonDebugReminders extends CourseReminderService {
  @override
  bool get debugEnabled => false;
  @override
  bool get supported => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'non-debug service refuses scheduling and only cancels course reminders',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(CourseReminderService.channel, (
            call,
          ) async {
            calls.add(call);
            return false;
          });
      try {
        final service = NonDebugReminders();
        await service.updateCourse('AI Foundations');
        await service.testOneMinute();
        expect(await service.enabled(), isFalse);
        expect(await service.setEnabled(true), isFalse);
        expect(calls.map((call) => call.method), ['setEnabled', 'setEnabled']);
        expect(calls.every((call) => call.arguments == false), isTrue);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(CourseReminderService.channel, null);
      }
    },
  );
  test('course title is sent to the native reminder scheduler', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(CourseReminderService.channel, (call) async {
          received = call;
          return null;
        });
    try {
      await FakeReminders().updateCourse('AI Foundations');
      expect(received?.method, 'updateCourse');
      expect(received?.arguments, 'AI Foundations');
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(CourseReminderService.channel, null);
    }
  });
  testWidgets('opt-in and cancellation reflect saved notification preference', (
    tester,
  ) async {
    final service = FakeReminders();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CourseReminderSetting(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('course-reminders')))
          .value,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('course-reminders')));
    await tester.pumpAndSettle();
    expect(service.value, isTrue);
    await tester.tap(find.byKey(const Key('course-reminders')));
    await tester.pumpAndSettle();
    expect(service.value, isFalse);
  });
  testWidgets('permission denial leaves reminders off and explains recovery', (
    tester,
  ) async {
    final service = FakeReminders()..denied = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CourseReminderSetting(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('course-reminders')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('course-reminders')))
          .value,
      isFalse,
    );
    expect(find.text('Allow notifications in Settings.'), findsOneWidget);
  });
}
