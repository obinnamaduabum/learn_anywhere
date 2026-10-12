import 'package:flutter/material.dart';

import 'store.dart';
import 'strings.dart';

class LearnerProfilePage extends StatefulWidget {
  const LearnerProfilePage({
    super.key,
    required this.store,
    this.editing = false,
  });
  final LearningStore store;
  final bool editing;
  @override
  State<LearnerProfilePage> createState() => _LearnerProfilePageState();
}

class _LearnerProfilePageState extends State<LearnerProfilePage> {
  late DateTime? dateOfBirth = widget.store.learnerDateOfBirth;
  late String gender = widget.store.learnerGender;
  late bool preferExplained = widget.store.preferExplained;
  bool busy = false;
  String? error;
  String label(String text) => translate(widget.store.appLanguage, text);
  @override
  void initState() {
    super.initState();
    widget.store.addListener(refresh);
    if (widget.store.catalog.isEmpty) {
      widget.store.refreshCatalog();
    }
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.store.removeListener(refresh);
    super.dispose();
  }

  Future<void> save({bool skip = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.saveLearnerProfile(
        null,
        skip ? '' : gender,
        widget.store.learningInterest,
        dateOfBirth: skip ? null : dateOfBirth,
        explainedVersions: skip ? false : preferExplained,
      );
      if (mounted && widget.editing) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = label('Could not save your profile. Try again.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label('Your learner profile'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              label('Make learning yours'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              label(
                'Date of birth and gender are optional and saved only on this device. You can change or remove these details in Profile.',
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              key: const Key('learner-date-of-birth'),
              contentPadding: EdgeInsets.zero,
              title: Text(label('Date of birth (optional)')),
              subtitle: Text(
                dateOfBirth == null
                    ? label('Choose a date')
                    : MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(dateOfBirth!),
              ),
              trailing: dateOfBirth == null
                  ? const Icon(Icons.calendar_month)
                  : IconButton(
                      tooltip: label('Clear date of birth'),
                      onPressed: busy
                          ? null
                          : () => setState(() => dateOfBirth = null),
                      icon: const Icon(Icons.clear),
                    ),
              onTap: busy
                  ? null
                  : () async {
                      final now = DateTime.now();
                      final selected = await showDatePicker(
                        context: context,
                        initialDate:
                            dateOfBirth ??
                            DateTime(now.year - 18, now.month, now.day),
                        firstDate: DateTime(now.year - 120, now.month, now.day),
                        lastDate: DateTime(now.year, now.month, now.day),
                      );
                      if (mounted && selected != null) {
                        setState(() => dateOfBirth = selected);
                      }
                    },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const Key('learner-gender'),
              initialValue: gender,
              decoration: InputDecoration(
                labelText: label('Gender (optional)'),
                border: const OutlineInputBorder(),
              ),
              items: ['', 'Woman', 'Man', 'Non-binary', 'Prefer not to say']
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(
                        label(value.isEmpty ? 'Not provided' : value),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: busy
                  ? null
                  : (value) => setState(() => gender = value!),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              key: const Key('prefer-explained'),
              title: Text(label('Start with explained lessons')),
              subtitle: Text(
                label(
                  'You can switch between regular and explained versions while reading.',
                ),
              ),
              value: preferExplained,
              onChanged: busy
                  ? null
                  : (value) => setState(() => preferExplained = value),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('save-learner-profile'),
              onPressed: busy ? null : save,
              child: Text(label(busy ? 'Saving…' : 'Continue')),
            ),
            if (!widget.editing)
              TextButton(
                onPressed: busy ? null : () => save(skip: true),
                child: Text(label('Skip for now')),
              ),
          ],
        ),
      ),
    );
  }
}
