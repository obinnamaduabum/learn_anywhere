import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'store.dart';
import 'strings.dart';

class LearningCompanionCard extends StatefulWidget {
  const LearningCompanionCard({
    super.key,
    required this.store,
    required this.id,
    this.showExplain = true,
    this.explanationOnly = false,
  });
  final LearningStore store;
  final int id;
  final bool showExplain;
  final bool explanationOnly;
  @override
  State<LearningCompanionCard> createState() => _LearningCompanionCardState();
}

class _LearningCompanionCardState extends State<LearningCompanionCard> {
  bool busy = false;
  String? error;
  Map<String, dynamic>? answer;
  @override
  void initState() {
    super.initState();
    if (widget.explanationOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ask('explain');
      });
    }
  }

  String label(String value) => translate(widget.store.appLanguage, value);
  Future<void> ask(String action) async {
    if (action == 'explain') {
      if (widget.store.savedExplanations != null) {
        readExplanation();
      } else {
        await download();
      }
      return;
    }
    final cached = widget
        .store
        .companionHelp[widget.store.companionCacheKey(widget.id, action)];
    if (cached == null) {
      final allowed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(label('AI learning help')),
          content: Text(
            label(
              'This sends the published lesson to Groq through our server. Your reading history, profile details and assessment answers are not sent. AI can make mistakes; check the lesson sources.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(label('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(label('Continue')),
            ),
          ],
        ),
      );
      if (allowed != true || !mounted) return;
    }
    setState(() {
      busy = true;
      error = null;
      answer = null;
    });
    try {
      final result = await widget.store.requestCompanion(widget.id, action);
      if (mounted) setState(() => answer = result);
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure.toString().replaceFirst('HttpException: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> download() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final pack = await widget.store.downloadExplanations();
      if (!mounted) return;
      if (pack['available'] == false) {
        setState(
          () => error = label(
            'Explanations are not available yet for this course and language.',
          ),
        );
      } else {
        setState(
          () => answer = {
            'text': (pack['lessons'] as List)[widget.id]['text'],
            'suggestions': <String>[],
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = label(
            'Could not download explanations. Saved explanations remain available offline.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void readExplanation() {
    final pack = widget.store.savedExplanations;
    if (pack == null) return;
    setState(
      () => answer = {
        'text': (pack['lessons'] as List)[widget.id]['text'],
        'suggestions': <String>[],
      },
    );
  }

  @override
  void didUpdateWidget(LearningCompanionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      answer = null;
      error = null;
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shadowColor: Colors.transparent,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label(
              widget.explanationOnly
                  ? 'Lesson explanation'
                  : 'AI learning companion',
            ),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            label(
              'Get a simpler explanation or suggested preparation before reading. Saved help works offline.',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label(
              widget.store.savedExplanations == null
                  ? 'Reviewed explanations: not downloaded'
                  : 'Reviewed explanations · version ${widget.store.savedExplanations!['explanationVersion']} · Ready offline',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in {
                if (widget.showExplain && !widget.explanationOnly)
                  'explain': 'Explain this',
                if (!widget.explanationOnly) 'prerequisites': 'Before you read',
              }.entries)
                OutlinedButton(
                  onPressed: busy ? null : () => ask(item.key),
                  child: Text(label(item.value)),
                ),
            ],
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (answer != null) ...[
            const SizedBox(height: 12),
            SelectableText('${answer!['text']}'),
            for (final suggestion in (answer!['suggestions'] as List? ?? []))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('$suggestion'),
              ),
            if ((answer!['suggestions'] as List? ?? []).isNotEmpty)
              TextButton(
                onPressed: () async {
                  try {
                    await const MethodChannel(
                      'learn_anywhere/reminders',
                    ).invokeMethod<void>(
                      'setSuggestions',
                      answer!['suggestions'],
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            label(
                              'Suggestions saved for course reminders. Enable course reminders in Profile.',
                            ),
                          ),
                        ),
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            label(
                              'Could not update reminders. Please try again.',
                            ),
                          ),
                        ),
                      );
                    }
                  }
                },
                child: Text(label('Use for course reminders')),
              ),
            Text(
              label('AI-generated help · check against lesson sources'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    ),
  );
}
