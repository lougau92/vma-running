import 'package:app_feedback/app_feedback.dart' show FeedbackContextScope;
import 'package:flutter/widgets.dart';

import 'runtime_environment.dart' show RuntimeEnvironment;
import 'runtime_probe_stub.dart'
    if (dart.library.js_interop) 'runtime_probe_web.dart'
    as probe;

/// Reads device and window signals without depending on widget ancestry.
RuntimeEnvironment readRuntimeEnvironment() => probe.readEnvironment();

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
    _environment = probe.readEnvironment();
    _stopWatching = probe.watchEnvironment(() {
      if (mounted) setState(() => _environment = probe.readEnvironment());
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
