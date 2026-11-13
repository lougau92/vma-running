import 'package:app_feedback/app_feedback.dart' show captureFeedbackContext;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vma_running/runtime/runtime_environment.dart';
import 'package:vma_running/runtime/runtime_environment_host.dart';

void main() {
  test('device class is independent of browser and PWA presentation', () {
    for (final web in [false, true]) {
      for (final mode in [
        'browser',
        'standalone',
        'fullscreen',
        'minimal-ui',
      ]) {
        for (final platform in TargetPlatform.values) {
          final environment = RuntimeEnvironment(
            platform: platform,
            isWeb: web,
            displayMode: mode,
          );
          expect(
            environment.isMobile,
            [TargetPlatform.android, TargetPlatform.iOS].contains(platform),
          );
          expect(environment.displayMode, web ? mode : 'native');
        }
      }
    }
  });

  test('iPad desktop-site mode and touchscreen desktops', () {
    final ipad = RuntimeEnvironment(
      platform: TargetPlatform.macOS,
      isWeb: true,
      maxTouchPoints: 5,
    );
    expect(ipad.isMobile, isTrue);
    expect(
      RuntimeEnvironment(platform: TargetPlatform.macOS, isWeb: true).isMobile,
      isFalse,
    );
    expect(
      RuntimeEnvironment(
        platform: TargetPlatform.windows,
        isWeb: true,
        maxTouchPoints: 10,
      ).isMobile,
      isFalse,
      reason: 'touchscreen laptops remain desktop',
    );
  });

  testWidgets('environment is included in automatic feedback context', (
    tester,
  ) async {
    Map<String, dynamic>? snapshot;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => RuntimeEnvironmentHost(child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  snapshot = captureFeedbackContext(context).toJson(),
              child: const Text('Capture'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Capture'));
    final scopes = snapshot!['scopes'] as List;
    final runtime = scopes.cast<Map>().singleWhere((s) => s['id'] == 'runtime');
    expect(runtime['state'], {
      'platform': 'iOS',
      'runtime': 'native',
      'deviceClass': 'mobile',
      'displayMode': 'native',
    });
  }, variant: TargetPlatformVariant({TargetPlatform.iOS}));
}
