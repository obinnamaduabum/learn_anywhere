import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LessonAudio extends StatefulWidget {
  const LessonAudio({
    super.key,
    required this.text,
    required this.language,
    this.autoRead = false,
  });
  final String text;
  final String language;
  final bool autoRead;

  @override
  State<LessonAudio> createState() => _LessonAudioState();
}

class _LessonAudioState extends State<LessonAudio>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const channel = MethodChannel('learn_anywhere/speech');
  String state = 'idle';
  String? error;
  double speed = 1;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.autoRead) unawaited(command('speak'));
    });
    channel.setMethodCallHandler((call) async {
      if (call.method == 'state' && mounted) {
        setState(() => state = call.arguments as String);
      }
    });
  }

  Future<void> command(String method) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await channel.invokeMethod<void>(
        method,
        method == 'speak'
            ? {'text': widget.text, 'language': widget.language, 'speed': speed}
            : null,
      );
      if (mounted) {
        setState(
          () => state = switch (method) {
            'speak' || 'resume' => 'speaking',
            'pause' => 'paused',
            _ => 'idle',
          },
        );
      }
    } on PlatformException catch (failure) {
      if (mounted) {
        setState(() {
          state = 'idle';
          error = failure.code == 'no_voice'
              ? null
              : 'Could not play this lesson. Please try again.';
        });
        if (failure.code == 'no_voice') {
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text(
                'No voice available',
                textAlign: TextAlign.center,
              ),
              content: const Text(
                'No voice is available for this language. Check downloaded voices in iPhone Accessibility settings, or choose another lesson language.',
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB3261E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel', textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          );
        }
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() => error = 'Read aloud is currently available on iPhone.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> stopQuietly() async {
    try {
      await channel.invokeMethod<void>('stop');
    } catch (_) {
      /* No speech plugin on other platforms. */
    }
  }

  @override
  void didUpdateWidget(LessonAudio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.language != widget.language ||
        oldWidget.autoRead != widget.autoRead) {
      unawaited(
        stopQuietly().then((_) {
          if (mounted && widget.autoRead) return command('speak');
        }),
      );
      state = 'idle';
      error = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle != AppLifecycleState.resumed) unawaited(stopQuietly());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    channel.setMethodCallHandler(null);
    unawaited(stopQuietly());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => command(
                      state == 'speaking'
                          ? 'pause'
                          : state == 'paused'
                          ? 'resume'
                          : 'speak',
                    ),
              icon: Icon(
                state == 'speaking' ? Icons.pause : Icons.volume_up_outlined,
              ),
              label: Text(
                state == 'speaking'
                    ? 'Pause'
                    : state == 'paused'
                    ? 'Resume'
                    : 'Read aloud',
              ),
            ),
            if (state != 'idle')
              IconButton(
                tooltip: 'Stop reading',
                onPressed: busy ? null : () => command('stop'),
                icon: const Icon(Icons.stop),
              ),
            DropdownButton<double>(
              value: speed,
              hint: const Text('Reading speed'),
              onChanged: busy || state != 'idle'
                  ? null
                  : (value) => setState(() => speed = value!),
              items: [.75, 1.0, 1.25]
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text('$value×')),
                  )
                  .toList(),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}
