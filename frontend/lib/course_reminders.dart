import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Notifications are opt-in and scheduled on-device, without a backend.
class CourseReminderService {
  const CourseReminderService();
  static const channel = MethodChannel('learn_anywhere/reminders');
  bool get debugEnabled => kDebugMode;
  bool get supported => Platform.isIOS;
  Future<void> updateCourse(String title) async {
    if (!supported) return;
    try {
      if (debugEnabled) {
        await channel.invokeMethod<void>('updateCourse', title);
      } else {
        await channel.invokeMethod<bool>('setEnabled', false);
      }
    } on PlatformException {
      // Notification failures must not prevent reading or saving progress.
    } on MissingPluginException {
      // Older installed native builds may not have the reminder channel yet.
    }
  }

  Future<void> testOneMinute() async {
    if (!debugEnabled) return;
    await channel.invokeMethod<void>('testOneMinute');
  }

  Future<bool> enabled() async {
    if (!debugEnabled) return false;
    return await channel.invokeMethod<bool>('status') ?? false;
  }

  Future<bool> setEnabled(bool value) async {
    if (!debugEnabled) {
      if (supported) await channel.invokeMethod<bool>('setEnabled', false);
      return false;
    }
    return await channel.invokeMethod<bool>('setEnabled', value) ?? false;
  }
}

class CourseReminderSetting extends StatefulWidget {
  const CourseReminderSetting({
    super.key,
    this.service = const CourseReminderService(),
  });
  final CourseReminderService service;
  @override
  State<CourseReminderSetting> createState() => _CourseReminderSettingState();
}

class _CourseReminderSettingState extends State<CourseReminderSetting>
    with WidgetsBindingObserver {
  bool enabled = false;
  bool busy = true;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  Future<void> load() async {
    try {
      final value = widget.service.supported
          ? await widget.service.enabled()
          : false;
      if (mounted) {
        setState(() {
          enabled = value;
          busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Could not check notification settings.';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> change(bool value) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final actual = await widget.service.setEnabled(value);
      if (mounted) setState(() => enabled = actual);
    } on PlatformException catch (exception) {
      if (mounted) {
        setState(
          () =>
              error = exception.message ?? 'Could not update course reminders.',
        );
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Could not update course reminders.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> testReminders() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.service.testOneMinute();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Both reminders are scheduled in one minute. Put the app in the background to see them.',
            ),
          ),
        );
      }
    } catch (exception) {
      if (mounted) {
        setState(
          () => error = exception is PlatformException
              ? exception.message
              : 'Could not schedule test reminders.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SwitchListTile(
        key: const Key('course-reminders'),
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.notifications_outlined),
        title: const Text('Course reading reminders'),
        subtitle: Text(
          widget.service.supported
              ? 'A noon reminder with your course name, plus a random reminder between 9 AM and 7 PM. Random reminders are scheduled for 30 days and refreshed when you reopen the app.'
              : 'Course notifications are currently available on iPhone.',
        ),
        value: enabled,
        onChanged: busy || !widget.service.supported ? null : change,
      ),
      if (widget.service.supported)
        TextButton.icon(
          onPressed: busy ? null : testReminders,
          icon: const Icon(Icons.notification_add_outlined),
          label: const Text('Test both reminders in 1 minute'),
        ),
      if (error != null)
        Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}
