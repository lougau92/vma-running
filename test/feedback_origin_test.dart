import 'package:app_feedback/app_feedback.dart'
    show FeedbackSender, FeedbackSubmission;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:vma_running/app_settings.dart';
import 'package:vma_running/feature_flags.dart';
import 'package:vma_running/remote_asset_loader.dart';
import 'package:vma_running/vma_home.dart';

class _Sender implements FeedbackSender {
  final sent = <FeedbackSubmission>[];
  @override
  Future<void> send(FeedbackSubmission feedback) async => sent.add(feedback);
}

class _Loader extends RemoteAssetLoader {
  @override
  Stream<RemoteLoadResult> watchText({
    required String documentPath,
    required String assetPath,
    String fieldName = 'content',
    void Function(String)? validate,
  }) => const Stream.empty();
}

void main() {
  testWidgets(
    'home feedback captures each active tab independently of locale',
    (tester) async {
      SharedPreferences.setMockInitialValues({'user_vma': 18.0});
      final sender = _Sender();
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
          home: VmaHomePage(
            settings: const AppSettings(),
            onSettingsChanged: (_) {},
            feedbackSender: sender,
            features: const FeatureFlags(
              clubCommunications: true,
              clubRankings: true,
            ),
            loader: _Loader(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tabs = {
        Icons.analytics: 'intensity',
        Icons.timer: 'times',
        Icons.fitness_center: 'training-plan',
        Icons.calculate_outlined: 'calculator',
        Icons.campaign_outlined: 'club-communications',
        Icons.emoji_events: 'club-rankings',
      };
      for (final tab in tabs.entries) {
        await tester.tap(find.byIcon(tab.key));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.feedback_outlined));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('feedback-message')),
          'Un avis de test.',
        );
        final send = find.byKey(const ValueKey('feedback-send'));
        await tester.ensureVisible(send);
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(sender.sent.last.origin, tab.value);
        expect(sender.sent.last.uiContext!.screen, tab.value);
        final data = sender.sent.last.uiContext!.toJson();
        expect((data['route'] as Map)['presentation'], 'page');
        final navigation = (data['controls'] as List).cast<Map>().singleWhere(
          (control) => control['type'] == 'bottom-navigation',
        );
        expect(navigation['selected'], tabs.values.toList().indexOf(tab.value));
        expect(sender.sent.last.message, 'Un avis de test.');
      }
      expect(sender.sent, hasLength(6));
      expect(tester.takeException(), isNull);
    },
  );
}
