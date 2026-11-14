import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vma_running/theme.dart';

double contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  for (final option in AppThemes.all) {
    test('${option.id} light surfaces keep readable colored ink', () {
      final theme = option.light;
      final scheme = theme.colorScheme;
      final card = theme.cardTheme.color!;
      final input = theme.inputDecorationTheme.fillColor!;
      expect(card.a, 1);
      expect(input.a, 1);
      expect(card.computeLuminance(), greaterThan(0.85));
      expect(theme.cardTheme.elevation, 0);
      for (final surface in [card, input, scheme.surface]) {
        expect(contrast(scheme.onSurface, surface), greaterThanOrEqualTo(4.5));
        expect(
          contrast(scheme.onSurfaceVariant, surface),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(theme.textTheme.titleMedium!.color, scheme.onSurface);
      expect(theme.textTheme.bodySmall!.color, scheme.onSurface);
      expect(scheme.onSurface, isNot(Colors.black));
    });
  }
}
