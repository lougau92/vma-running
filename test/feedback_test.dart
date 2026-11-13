import 'dart:convert' show jsonEncode, utf8;
import 'dart:typed_data' show ByteData, Uint8List;

import 'package:app_feedback/app_feedback.dart'
    show
        FeedbackSender,
        FeedbackSubmission,
        SupabaseFeedbackSender,
        UnavailableFeedbackSender;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show CachingAssetBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:vma_running/app_settings.dart';
import 'package:vma_running/feedback_setup.dart';
import 'package:vma_running/vma_settings_page.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.config);
  final String config;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(config)));
}

class _MemorySender implements FeedbackSender {
  final sent = <FeedbackSubmission>[];
  @override
  Future<void> send(FeedbackSubmission feedback) async => sent.add(feedback);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled feedback config creates an isolated sender without signing in',
    () async {
      final sender = await loadFeedbackSender();
      expect(sender, isA<SupabaseFeedbackSender>());
      expect((sender as SupabaseFeedbackSender).appId, 'vma-running');
      await sender.dispose();
    },
  );

  test('invalid feedback config is optional and rejects secret keys', () async {
    final config = jsonEncode({
      'supabase_url': 'https://example.supabase.co',
      'supabase_publishable_key': 'sb_secret_offline-example',
      'app_id': 'vma-running',
    });
    expect(
      await loadFeedbackSender(bundle: _Bundle(config)),
      isA<UnavailableFeedbackSender>(),
    );
    expect(
      await loadFeedbackSender(bundle: _Bundle('invalid json')),
      isA<UnavailableFeedbackSender>(),
    );
  });

  testWidgets(
    'VMA settings opens localized feedback with the injected sender',
    (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'VMA',
        packageName: 'vma_running',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      final sender = _MemorySender();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: VmaSettingsPage(
            settings: const AppSettings(),
            onSettingsChanged: (_) {},
            feedbackSender: sender,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.feedback_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Envoyer un avis'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('feedback-message')),
        'Un retour de test.',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('feedback-send')));
      await tester.tap(find.byKey(const ValueKey('feedback-send')));
      await tester.pumpAndSettle();
      expect(sender.sent.single.message, 'Un retour de test.');
      expect(sender.sent.single.category, 'Bug report');
      expect(sender.sent.single.origin, 'settings');
      expect(sender.sent.single.uiContext!.screen, 'settings');
      expect(find.text('Avis envoyé.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
