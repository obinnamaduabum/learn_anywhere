import 'package:flutter/material.dart';

import 'page_notices.dart';

import 'store.dart';
import 'strings.dart';

/// Small on-device adaptive policy. No language model or cloud inference.
class CoachSuggestion {
  const CoachSuggestion(
    this.strategy,
    this.message,
    this.reason,
    this.preferredHour,
  );
  final String strategy;
  final String message;
  final String reason;
  final int? preferredHour;
  static CoachSuggestion forStore(LearningStore store, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final activity = store.coachingActivity.where((a) {
      final date = DateTime.tryParse('${a['day']}');
      return date != null &&
          !date.isAfter(current) &&
          current.difference(date).inDays < 30;
    }).toList();
    final days = activity.map((a) => a['day']).toSet();
    final hours = <int, Set<String>>{};
    for (final a in activity) {
      final hour = a['hour'] as int;
      if (hour >= 9 && hour < 19) {
        hours.putIfAbsent(hour, () => {}).add('${a['day']}');
      }
    }
    int? preferred;
    if (days.length >= 5 && hours.isNotEmpty) {
      final ranked = hours.keys.toList()
        ..sort((a, b) {
          final comparison = hours[b]!.length.compareTo(hours[a]!.length);
          return comparison != 0 ? comparison : a.compareTo(b);
        });
      preferred = ranked.first;
    }
    final scores = <String, double>{
      'read': store.lessonsReadToday < store.dailyLessonGoal ? 2 : .2,
      'practice': store.lessonsReadToday > 0 && !store.practicedToday ? 2.4 : 1,
      'recap': store.dailyChallengeComplete ? 3 : .4,
    };
    for (final strategy in scores.keys) {
      final feedback = store.coachingFeedback[strategy] ?? {};
      final helpful = feedback['helpful'] ?? 0;
      final unhelpful = feedback['unhelpful'] ?? 0;
      // Smoothed feedback preference: cold-start stays neutral.
      scores[strategy] =
          scores[strategy]! +
          (helpful + 1) / (helpful + unhelpful + 2) -
          5 * unhelpful / (helpful + unhelpful + 2);
    }
    if (store.lessons.every((l) => store.isRead(l['id'] as int))) {
      scores['read'] = -1;
    }
    final strategies = scores.keys.toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    final strategy = store.dailyChallengeComplete ? 'recap' : strategies.first;
    final message = switch (strategy) {
      'practice' => 'Try a short checkpoint to remember what you read.',
      'recap' =>
        store.dailyChallengeComplete
            ? 'Your daily goal is done. Rest, or enjoy a quick recap.'
            : 'Start gently with a recap of a familiar lesson.',
      _ =>
        'One small lesson is enough to move forward. Continue where you stopped.',
    };
    final reason = switch (strategy) {
      'practice' =>
        'You have read today; a little recall can complete your challenge.',
      'recap' =>
        store.dailyChallengeComplete
            ? 'You have met your reading and practice goals today.'
            : 'A light recap fits your current progress and coaching feedback.',
      _ =>
        'This suggestion follows your daily reading goal and current progress.',
    };
    return CoachSuggestion(strategy, message, reason, preferred);
  }
}

class LocalCoachCard extends StatelessWidget {
  const LocalCoachCard({
    super.key,
    required this.store,
    required this.onAction,
  });
  final LearningStore store;
  final void Function(String strategy) onAction;
  @override
  Widget build(BuildContext context) {
    if (!store.adaptiveCoaching) return const SizedBox.shrink();
    final suggestion = CoachSuggestion.forStore(store);
    String label(String text) => translate(store.appLanguage, text);
    final rated =
        store.coachingFeedback[suggestion.strategy]?['ratedDay'] ==
        int.parse(store.todayKey.replaceAll('-', ''));
    Future<void> rate(bool value) async {
      try {
        await store.rateCoaching(suggestion.strategy, value);
      } catch (_) {
        if (context.mounted) {
          showPageSnackBar(
            context,
            SnackBar(content: Text(label('Could not save coaching feedback.'))),
          );
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label('Your learning coach'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(label(suggestion.message)),
            const SizedBox(height: 8),
            Text(
              label(suggestion.reason),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (suggestion.preferredHour != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${label('You often study around')} ${TimeOfDay(hour: suggestion.preferredHour!, minute: 0).format(context)}. ${label('Choose a time that suits you.')}',
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => onAction(suggestion.strategy),
              child: Text(
                label(switch (suggestion.strategy) {
                  'practice' => 'Quick practice',
                  'recap' => 'Reveal recap',
                  _ => 'Continue learning',
                }),
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: rated ? null : () => rate(true),
                  child: Text(label('Helpful')),
                ),
                TextButton(
                  onPressed: rated ? null : () => rate(false),
                  child: Text(label('Not for me')),
                ),
              ],
            ),
            Text(
              label(
                'Learns from recent study activity and your feedback on this device. No ChatGPT connection.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
