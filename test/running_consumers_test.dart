import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:vma_running/calculator/running_calculator_draft.dart';
import 'package:vma_running/plan_exporter.dart';
import 'package:vma_running/running/running_distance_labels.dart';
import 'package:vma_running/running/running.dart';
import 'package:vma_running/training_plan.dart';
import 'package:vma_running/vma_pace.dart';
import 'package:vma_running/vma_times_table.dart';

void main() {
  final draft = const RunningCalculatorDraft(
    firstText: '0.4',
    second: RunningMeasure.intensity,
    secondText: '120',
  );

  test('calculator, VMA rows and workout lines agree on the same effort', () {
    final run = draft.calculate(20)!;
    final row = VmaPaceCalculator()
        .buildTable(
          20,
          minPercent: 120,
          maxPercent: 120,
          step: 5,
          distanceMeters: 400,
        )
        .single;
    expect(run.speed.kmh, 24);
    expect(run.seconds, closeTo(60, 1e-10));
    expect(row.speedKmh, run.speed.kmh);
    expect(row.pacePerKm, '02:30');
    expect(row.pacePerKm, formatPacePerKm(run.speed));
    expect(row.timeForDistance, '01:00');
    expect(row.timeForDistance, formatRunningDuration(run.seconds));
    final text = formatSetLine(
      const IntervalSet(
        repetitions: 4,
        distanceMeters: 400,
        vmaPercent: 120,
        recoverySeconds: 60,
        recoveryType: RecoveryType.jog,
      ),
      20,
      AppLocalizations(const Locale('en')),
    );
    expect(text, '4x 400 m @ 02:30 /km | 01:00 jog');
  });

  test(
    'distance labels round consistently without floating-point artifacts',
    () {
      final strings = AppLocalizations(const Locale('en'));
      expect(formatDistanceShort(399.999999999, strings), '400 m');
      expect(formatDistanceShort(1250, strings), '1.25 km');
      expect(formatDistanceShort(1500, strings), '1.5 km');
      expect(formatDistanceLong(1250, strings), '1.25 kilometers');
      expect(formatDistanceLong(400.000000001, strings), '400 meters');
      expect(formatDistanceShort(kMarathonMeters, strings), strings.marathon);
    },
  );

  test('invalid table parameters produce no rows instead of looping', () {
    final calculator = VmaPaceCalculator();
    for (final step in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        calculator.buildTable(
          18,
          minPercent: 60,
          maxPercent: 120,
          step: step,
          distanceMeters: 400,
        ),
        isEmpty,
      );
    }
    expect(
      calculator.buildTable(
        0,
        minPercent: 60,
        maxPercent: 120,
        step: 5,
        distanceMeters: 400,
      ),
      isEmpty,
    );
    expect(
      calculator.buildTable(
        18,
        minPercent: 120,
        maxPercent: 60,
        step: 5,
        distanceMeters: 400,
      ),
      isEmpty,
    );
  });

  testWidgets(
    'Times table agrees in both directions and handles invalid speed',
    (tester) async {
      final run = draft.calculate(20)!;
      Widget app({bool valid = true}) => MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: VmaTimesTable(
            speed: valid ? run.speed : null,
            minDistanceMeters: 400,
            maxDistanceMeters: 400,
            minTimeSeconds: 60,
            maxTimeSeconds: 60,
            onEditDistances: () {},
            onEditTimes: () {},
          ),
        ),
      );
      List<String> row() => tester
          .widget<DataTable>(find.byType(DataTable))
          .rows
          .single
          .cells
          .map(
            (cell) => (((cell.child as SizedBox).child as Center).child as Text)
                .data!,
          )
          .toList();
      await tester.pumpWidget(app());
      expect(row(), ['400 m', '01:00']);
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pump();
      expect(row(), ['01:00', '400 m']);
      await tester.pumpWidget(app(valid: false));
      expect(row(), ['01:00', '-']);
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pump();
      expect(row(), ['400 m', '-']);
      expect(tester.takeException(), isNull);
    },
  );
}
