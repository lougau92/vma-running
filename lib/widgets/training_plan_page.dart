import 'package:app_feedback/app_feedback.dart'
    show FeedbackSender, FeedbackSubmission, captureFeedbackContext;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart' show PackageInfo;
import '../app_localizations.dart';
import '../content_refresh.dart';
import '../remote_asset_loader.dart';
import '../runtime/runtime_platform.dart' show feedbackBrowserFamily;
import '../workouts/workout.dart';
import '../workouts/workout_content.dart';

class TrainingPlanPage extends StatefulWidget {
  TrainingPlanPage({
    super.key,
    required this.userVma,
    RemoteAssetLoader? loader,
    this.feedbackSender,
  }) : loader = loader ?? RemoteAssetLoader();
  final double userVma;
  final FeedbackSender? feedbackSender;
  final RemoteAssetLoader loader;
  @override
  State<TrainingPlanPage> createState() => _TrainingPlanPageState();
}

class _TrainingPlanPageState extends State<TrainingPlanPage> {
  static const documentPath = 'app_documents/workout_plan';
  late Stream<RemoteLoadResult> _stream;
  String? _notice;
  bool _sendingError = false;
  @override
  void initState() {
    super.initState();
    _stream = _watch();
  }

  Stream<RemoteLoadResult> _watch() => widget.loader.watchText(
    documentPath: documentPath,
    validate: WorkoutConversion.parse,
  );
  Future<void> _refresh() => refreshContent(_watch(), (stream) {
    setState(() {
      _notice = null;
      _stream = stream;
    });
  });
  void _notify(RemoteLoadResult result) {
    if (result.refreshing || result.error == null) return;
    const key = 'trainingPlanUsedCache';
    if (key == _notice) return;
    _notice = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)[key])),
        );
      }
    });
  }

  Future<void> _sendError(BuildContext context, Object? error) async {
    final sender = widget.feedbackSender;
    if (sender == null || _sendingError) return;
    final messenger = ScaffoldMessenger.of(context);
    final s = AppLocalizations.of(context);
    final diagnostic = error == null
        ? 'stream ended without workout data'
        : remoteContentErrorCode(error) ?? error.runtimeType.toString();
    setState(() => _sendingError = true);
    try {
      final uiContext = captureFeedbackContext(context);
      final browser = feedbackBrowserFamily();
      final package = await PackageInfo.fromPlatform().then<PackageInfo?>(
        (info) => info,
        onError: (Object _) => null,
      );
      final details = [
        'Workout failed to load ($diagnostic).',
        if (package != null) 'App ${package.version}+${package.buildNumber}',
        if (browser != null) 'Browser $browser',
      ];
      await sender.send(
        FeedbackSubmission(
          category: 'Bug report',
          message: details.join('\n'),
          origin: 'training-plan',
          uiContext: uiContext,
        ),
      );
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(s['workout_error_sent'])),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(s['workout_error_send_failed'])),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingError = false);
    }
  }

  Widget _loadError(BuildContext context, Object? error) {
    final s = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s['workout_load_error'], textAlign: TextAlign.center),
          TextButton(onPressed: _refresh, child: Text(s['workout_retry'])),
          if (widget.feedbackSender != null)
            TextButton(
              onPressed: _sendingError
                  ? null
                  : () => _sendError(context, error),
              child: Text(s['workout_send_error']),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RemoteLoadResult>(
      stream: _stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError ||
              snapshot.connectionState == ConnectionState.done) {
            return _loadError(context, snapshot.error);
          }
          return const Center(child: CircularProgressIndicator());
        }
        final result = snapshot.data!;
        WorkoutConversion conversion;
        try {
          conversion = WorkoutConversion.parse(result.data);
        } on FormatException catch (error) {
          return _loadError(context, error);
        }
        _notify(result);
        return WorkoutContent(
          conversion: conversion,
          result: result,
          userVma: widget.userVma,
          onRefresh: _refresh,
          waiting: snapshot.connectionState == ConnectionState.waiting,
        );
      },
    );
  }
}
