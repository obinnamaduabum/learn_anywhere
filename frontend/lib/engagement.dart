import 'package:flutter/material.dart';

import 'store.dart';
import 'strings.dart';

String el(LearningStore store, String text) =>
    translate(store.appLanguage, text);

class LearningMomentum extends StatelessWidget {
  const LearningMomentum({
    super.key,
    required this.store,
    required this.onContinue,
  });
  final LearningStore store;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                store.dailyChallengeComplete
                    ? Icons.check_circle
                    : Icons.flag_outlined,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  el(store, 'Daily challenge'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          Text(
            '${store.lessonsReadToday} / ${store.dailyLessonGoal} ${el(store, 'lessons read today')}',
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (store.lessonsReadToday / store.dailyLessonGoal).clamp(
              0.0,
              1.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            store.dailyChallengeComplete
                ? el(store, 'Daily challenge complete!')
                : el(store, 'Small steps. Real skills.'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text('🔥 ${store.streak} ${el(store, 'day streak')}'),
              Text(
                '${store.studyDaysThisWeek} / ${store.weeklyStudyGoal} ${el(store, 'study days this week')}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onContinue,
            icon: const Icon(Icons.play_arrow),
            label: Text(el(store, 'Continue learning')),
          ),
        ],
      ),
    ),
  );
}

Future<void> editLearningGoals(
  BuildContext context,
  LearningStore store,
) async {
  var daily = store.dailyLessonGoal;
  var weekly = store.weeklyStudyGoal;
  var interest = store.learningInterest;
  var busy = false;
  String? error;
  final categories =
      store.catalog
          .map((c) => '${c['category'] ?? 'General Learning'}')
          .toSet()
          .toList()
        ..sort();
  if (interest.isNotEmpty && !categories.contains(interest)) {
    categories.add(interest);
  }
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(el(store, 'Learning goals')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: daily,
                decoration: InputDecoration(
                  labelText: el(store, 'Lessons per day'),
                ),
                items: [1, 2, 3]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                    .toList(),
                onChanged: busy
                    ? null
                    : (value) => update(() => daily = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: weekly,
                decoration: InputDecoration(
                  labelText: el(store, 'Study days per week'),
                ),
                items: List.generate(
                  7,
                  (i) =>
                      DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                ),
                onChanged: busy
                    ? null
                    : (value) => update(() => weekly = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: interest,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: el(store, 'Learning interest'),
                ),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(el(store, 'Any topic')),
                  ),
                  ...categories.map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: busy
                    ? null
                    : (value) => update(() => interest = value!),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(dialogContext),
            child: Text(el(store, 'Cancel')),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    update(() => busy = true);
                    try {
                      await store.setLearningGoals(daily, weekly, interest);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    } catch (_) {
                      if (dialogContext.mounted) {
                        update(() {
                          busy = false;
                          error = el(
                            store,
                            'Could not save your goals. Try again.',
                          );
                        });
                      }
                    }
                  },
            child: Text(el(store, 'Save goals')),
          ),
        ],
      ),
    ),
  );
}

/// Recall practice uses published takeaways, never final assessment questions.
class RecallPrompt {
  RecallPrompt(this.sentence, this.answer, this.options, this.explanation);
  final String sentence;
  final String answer;
  final List<String> options;
  final String explanation;
  static RecallPrompt? fromLesson(Map<String, dynamic> lesson) {
    final tips = (lesson['takeaways'] as List? ?? [])
        .map((t) => '$t')
        .where((t) => t.trim().split(RegExp(r'\s+')).length > 2)
        .toList();
    if (tips.isEmpty) return null;
    final words = tips.first.trim().split(RegExp(r'\s+'));
    final answer = words.last;
    final options = {
      answer,
      ...tips.skip(1).map((t) => t.trim().split(RegExp(r'\s+')).last),
    }.toList();
    if (options.length < 2) return null;
    options.sort();
    return RecallPrompt(
      '${words.take(words.length - 1).join(' ')} ____',
      answer,
      options,
      tips.first,
    );
  }
}

class LessonCheckpoint extends StatefulWidget {
  const LessonCheckpoint({super.key, required this.store, required this.id});
  final LearningStore store;
  final int id;
  @override
  State<LessonCheckpoint> createState() => _LessonCheckpointState();
}

class _LessonCheckpointState extends State<LessonCheckpoint> {
  bool revealed = false;
  String? selected;
  bool busy = false;
  String? error;
  @override
  void didUpdateWidget(covariant LessonCheckpoint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.store.lessonLanguage != widget.store.lessonLanguage) {
      revealed = false;
      selected = null;
    }
  }

  Future<void> record() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.recordCheckpoint(widget.id);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = el(
            widget.store,
            'Could not save your practice. Try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final lesson = store.lessons[widget.id];
    final tips = (lesson['takeaways'] as List? ?? []).map((t) => '$t').toList();
    final prompt = RecallPrompt.fromLesson(lesson);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              el(store, 'Pause and remember'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              el(
                store,
                'Explain one idea in your own words, then reveal the recap.',
              ),
            ),
            TextButton.icon(
              key: Key('checkpoint-reveal-${widget.id}'),
              onPressed: () => setState(() => revealed = !revealed),
              icon: Icon(revealed ? Icons.visibility_off : Icons.visibility),
              label: Text(el(store, revealed ? 'Hide recap' : 'Reveal recap')),
            ),
            if (revealed)
              ...tips.map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• $tip'),
                ),
              ),
            if (prompt != null) ...[
              const Divider(),
              Text(
                el(store, 'Quick practice'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                el(
                  store,
                  'Complete this takeaway. Practice does not change your assessment score.',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                prompt.sentence,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: prompt.options
                    .map(
                      (option) => ChoiceChip(
                        label: Text(option),
                        selected: selected == option,
                        onSelected: busy
                            ? null
                            : (_) async {
                                setState(() => selected = option);
                                await record();
                              },
                      ),
                    )
                    .toList(),
              ),
              if (selected != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      '${el(store, selected == prompt.answer ? 'Nice work!' : 'Keep learning!')} ${prompt.explanation}',
                    ),
                  ),
                ),
            ] else
              OutlinedButton(
                onPressed: busy ? null : record,
                child: Text(el(store, 'I practised this idea')),
              ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
