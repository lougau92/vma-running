import 'package:app_feedback/app_feedback.dart' show FeedbackContextScope;
import 'package:flutter/widgets.dart';

import '../runtime/runtime_environment.dart' show RuntimeEnvironment;
import '../runtime/runtime_platform.dart' as platform;

/// Reads device and window signals without depending on widget ancestry.
RuntimeEnvironment readRuntimeEnvironment() => platform.readEnvironment();

/// Tracks browser/PWA presentation changes without relying on viewport width.
class RuntimeEnvironmentHost extends StatefulWidget {
  const RuntimeEnvironmentHost({super.key, required this.child});

  final Widget child;

  @override
  State<RuntimeEnvironmentHost> createState() => _RuntimeEnvironmentHostState();
}

class _RuntimeEnvironmentHostState extends State<RuntimeEnvironmentHost> {
  late RuntimeEnvironment _environment;
  late void Function() _stopWatching;

  @override
  void initState() {
    super.initState();
    _environment = platform.readEnvironment();
    _stopWatching = platform.watchEnvironment(() {
      if (mounted) setState(() => _environment = platform.readEnvironment());
    });
  }

  @override
  void dispose() {
    _stopWatching();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FeedbackContextScope(
    id: 'runtime',
    data: _environment.feedbackData,
    child: widget.child,
  );
}
