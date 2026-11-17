import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../feature_flags.dart';
import '../remote_asset_loader.dart';
import '../widgets/home_app_bar.dart';
import '../widgets/home_workspace.dart';
import 'preview_data.dart';
import 'preview_support.dart';

@ResponsivePreview(group: 'App shell', name: 'Navigation with saved VMA')
Widget appWorkspacePreview() => const _WorkspacePreview(vma: 18);

@ResponsivePreview(group: 'App shell', name: 'VMA setup prompt')
Widget appWorkspaceMissingVmaPreview() => const _WorkspacePreview(vma: null);

@ResponsivePreview(group: 'App shell', name: 'Initial loading')
Widget appWorkspaceLoadingPreview() =>
    const _WorkspacePreview(vma: 18, loading: true);

class _WorkspacePreview extends StatefulWidget {
  const _WorkspacePreview({required this.vma, this.loading = false});
  final double? vma;
  final bool loading;
  @override
  State<_WorkspacePreview> createState() => _WorkspacePreviewState();
}

class _WorkspacePreviewState extends State<_WorkspacePreview> {
  AppSettings _settings = const AppSettings();
  @override
  Widget build(BuildContext context) => HomeWorkspace(
    appBar: HomeAppBar(feedbackSender: null, onSettingsPressed: () {}),
    loading: widget.loading,
    vma: widget.vma,
    settings: _settings,
    onSettingsChanged: (settings) => setState(() => _settings = settings),
    features: const FeatureFlags(),
    loader: PreviewContentLoader(
      results: [
        RemoteLoadResult(
          data: workoutPreviewJson,
          origin: RemoteLoadOrigin.network,
        ),
      ],
    ),
  );
}
