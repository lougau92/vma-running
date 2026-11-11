import 'dart:convert' show jsonDecode;

import 'package:app_feedback/app_feedback.dart'
    show
        FeedbackBackendConfig,
        FeedbackSender,
        SupabaseFeedbackSender,
        UnavailableFeedbackSender;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

Future<FeedbackSender> loadFeedbackSender({AssetBundle? bundle}) async {
  try {
    final raw = await (bundle ?? rootBundle).loadString('assets/feedback.json');
    final config = jsonDecode(raw) as Map<String, dynamic>;
    return SupabaseFeedbackSender.forProject(
      FeedbackBackendConfig(
        url: config['supabase_url'] as String,
        publishableKey: config['supabase_publishable_key'] as String,
        appId: config['app_id'] as String,
      ),
    );
  } catch (_) {
    // Missing or invalid optional feedback config must not prevent offline use.
    return const UnavailableFeedbackSender();
  }
}
