import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:vma_running/running/running.dart';
import 'package:vma_running/theme.dart';
import 'package:vma_running/widgets/intensity_pace_control.dart';
import 'package:vma_running/widgets/intensity_runner.dart';

const _visual = ValueKey('runner-visual');

Widget _runner({
  double percent = 60,
  bool reducedMotion = false,
  bool active = true,
}) => MaterialApp(
  theme: EnjambeeTheme.lightTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
    child: TickerMode(enabled: active, child: child!),
  ),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 300,
        child: RepaintBoundary(
          key: _visual,
          child: IntensityRunner(percent: percent),
        ),
      ),
    ),
  ),
);

Future<Uint8List> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_visual),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
}

int _warmPixelCount(Uint8List pixels) {
  var count = 0;
  for (var i = 0; i < pixels.length; i += 4) {
    final pixel = i ~/ 4;
    final x = pixel % 300;
    final y = pixel ~/ 300;
    // Inspect the far-right trail area, where the 120% runner stands.
    if (x < 180 || y < 14 || y > 46) continue;
    final red = pixels[i];
    final green = pixels[i + 1];
    final blue = pixels[i + 2];
    if (red > 35 && red > green + 12 && red > blue + 12) {
      count++;
    }
  }
  return count;
}

void main() {
  testWidgets(
    'reduced motion shows distinct calm and hard static running poses',
    (tester) async {
      await tester.pumpWidget(_runner(reducedMotion: true));
      await tester.pumpAndSettle();
      final calm = await _pixels(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(await _pixels(tester), orderedEquals(calm));
      await tester.pumpWidget(_runner(percent: 120, reducedMotion: true));
      await tester.pumpAndSettle();
      final hard = await _pixels(tester);
      expect(hard, isNot(orderedEquals(calm)));
      expect(_warmPixelCount(hard), greaterThan(_warmPixelCount(calm)));
      expect(find.byType(Text), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preview animates, pauses offscreen, and settles after returning',
    (tester) async {
      await tester.pumpWidget(_runner(percent: 120));
      await tester.pump(const Duration(milliseconds: 50));
      final first = await _pixels(tester);
      await tester.pump(const Duration(milliseconds: 120));
      expect(await _pixels(tester), isNot(orderedEquals(first)));

      await tester.pumpWidget(_runner(percent: 120, active: false));
      await tester.pump();
      final paused = await _pixels(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(await _pixels(tester), orderedEquals(paused));
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(_runner(percent: 120));
      await tester.pumpAndSettle();
      final settled = await _pixels(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(await _pixels(tester), orderedEquals(settled));
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(_runner(percent: 60));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'visual preserves slider interaction and localized accessibility',
    (tester) async {
      final semantics = tester.ensureSemantics();
      double? changed;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: EnjambeeTheme.lightTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 312,
                child: IntensityPaceControl(
                  percent: 60,
                  speed: RunningSpeed.fromVma(15, 60),
                  onChanged: (value) => changed = value,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final slider = find.byType(Slider);
      expect(tester.getSemantics(slider).toStringDeep(), contains('60%'));
      await tester.drag(slider, const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(changed, 120);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
