import 'package:flutter/foundation.dart' show TargetPlatform;

/// Device class and window presentation are independent: desktop PWAs exist.
class RuntimeEnvironment {
  RuntimeEnvironment({
    required this.platform,
    required this.isWeb,
    int maxTouchPoints = 0,
    String displayMode = 'browser',
  }) : displayMode = isWeb ? displayMode : 'native',
       // iPadOS can identify as macOS when requesting desktop websites.
       isMobile =
           platform == TargetPlatform.android ||
           platform == TargetPlatform.iOS ||
           (isWeb && platform == TargetPlatform.macOS && maxTouchPoints > 1);

  final TargetPlatform platform;
  final bool isWeb;
  final bool isMobile;
  final String displayMode;

  Map<String, Object?> get feedbackData => {
    'platform': platform.name,
    'runtime': isWeb ? 'web' : 'native',
    'deviceClass': isMobile ? 'mobile' : 'desktop',
    'displayMode': displayMode,
  };
}
