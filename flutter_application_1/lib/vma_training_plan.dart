import 'package:flutter/material.dart';
import 'app_localizations.dart';

class VmaTrainingPlan extends StatefulWidget {
  const VmaTrainingPlan({super.key});

  @override
  State<VmaTrainingPlan> createState() => _VmaTrainingPlanState();
}

class _VmaTrainingPlanState extends State<VmaTrainingPlan> {
  int _selectedGroup = 1;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final workout = _selectedGroup == 1 ? _group1() : _group2();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                strings.trainingPlanTab,
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              ToggleButtons(
                isSelected: [_selectedGroup == 1, _selectedGroup == 2],
                onPressed: (index) {
                  setState(() => _selectedGroup = index + 1);
                },
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(strings.groupOne),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(strings.groupTwo),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: strings.preSession,
            items: [
              '${strings.warmup}: 15’ boucle habituelle + 3 gammes',
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: strings.sessionContent,
            items: workout,
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: strings.cooldown,
            items: ['Retour au calme en footing lent autour de la piste dans le sens horlogique 5’'],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: strings.remarks,
            items: ['Bien respecter les % de VMA très important.'],
          ),
        ],
      ),
    );
  }

  List<String> _group1() {
    return [
      'Bloc 1: 3 x 1200 (75%-80%-85%) — 2’30" actif / marche/trott entre répétitions',
      'Pause sèche 3’',
      'Bloc 2: 3 x 800 (90%) — 2’ actif / marche/trott entre répétitions',
      'Pause sèche 3’',
      'Bloc 3: 4 x 200 (105%) — 1’ actif / marche/trott entre répétitions',
    ];
  }

  List<String> _group2() {
    return [
      'Bloc 1: 3 x 1000 (75%-80%-85%) — 2’30" actif / marche/trott entre répétitions',
      'Pause sèche 3’',
      'Bloc 2: 3 x 600 (90%) — 2’ actif / marche/trott entre répétitions',
      'Pause sèche 3’',
      'Bloc 3: 4 x 100 (105%) — 1’ actif / marche/trott entre répétitions',
    ];
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...items.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
