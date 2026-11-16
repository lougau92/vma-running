import 'package:flutter/material.dart';
import '../app_localizations.dart';
import '../content_refresh.dart';
import '../remote_asset_loader.dart';
import '../workouts/workout.dart';
import '../workouts/workout_content.dart';

class TrainingPlanPage extends StatefulWidget {
  TrainingPlanPage({
    super.key,
    required this.userVma,
    RemoteAssetLoader? loader,
  }) : loader = loader ?? RemoteAssetLoader();
  final double userVma;
  final RemoteAssetLoader loader;
  @override
  State<TrainingPlanPage> createState() => _TrainingPlanPageState();
}

class _TrainingPlanPageState extends State<TrainingPlanPage> {
  static const documentPath = 'app_documents/workout_plan';
  late Stream<RemoteLoadResult> _stream;
  String? _notice;
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

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return StreamBuilder<RemoteLoadResult>(
      stream: _stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child:
                (snapshot.hasError ||
                    snapshot.connectionState == ConnectionState.done)
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s['workout_load_error']),
                      TextButton(
                        onPressed: _refresh,
                        child: Text(s['workout_retry']),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
          );
        }
        final result = snapshot.data!;
        WorkoutConversion conversion;
        try {
          conversion = WorkoutConversion.parse(result.data);
        } on FormatException {
          return Center(child: Text(s['workout_load_error']));
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
