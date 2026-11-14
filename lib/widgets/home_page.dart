import 'package:app_feedback/app_feedback.dart'
    show FeedbackSender, UnavailableFeedbackSender, FeedbackContextScope;
import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../feature_flags.dart';
import '../remote_asset_loader.dart';
import '../vma_storage.dart';
import 'settings_page.dart';
import 'vma_change_celebration.dart';
import 'home_app_bar.dart';
import 'home_workspace.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    this.feedbackSender = const UnavailableFeedbackSender(),
    this.features = const FeatureFlags(),
    this.loader,
  });

  final FeedbackSender? feedbackSender;
  final FeatureFlags features;
  final RemoteAssetLoader? loader;
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _vmaStorage = VmaStorage();
  late final RemoteAssetLoader _remoteLoader;
  OverlayEntry? _celebrationEntry;

  double? _vma;
  bool _loading = true;

  @override
  void dispose() {
    _celebrationEntry?.remove();
    super.dispose();
  }

  void _setVma(double value) {
    final changed = _vma != null && value != _vma;
    setState(() {
      _vma = value;
    });
    if (changed) _celebrateVmaChange();
  }

  void _celebrateVmaChange() {
    _celebrationEntry?.remove();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: VmaChangeCelebration(
          onComplete: () {
            if (identical(_celebrationEntry, entry)) {
              entry.remove();
              _celebrationEntry = null;
            }
          },
        ),
      ),
    );
    _celebrationEntry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  @override
  void initState() {
    super.initState();
    _remoteLoader = widget.loader ?? RemoteAssetLoader();
    _loadVma();
  }

  Future<void> _loadVma() async {
    final stored = await _vmaStorage.load();
    if (!mounted) return;

    setState(() {
      _vma = stored;
      _loading = false;
    });

    if (stored == null) {
      await _promptForVma();
    }
  }

  Future<void> _promptForVma() async {
    final selected = await _vmaStorage.promptForVma(
      context,
      initialValue: _vma,
    );

    if (selected != null && mounted) _setVma(selected);
  }

  @override
  Widget build(BuildContext context) {
    return FeedbackContextScope(
      id: 'home',
      child: HomeWorkspace(
        appBar: HomeAppBar(
          feedbackSender: widget.feedbackSender,
          onSettingsPressed: _openSettingsPage,
        ),
        loading: _loading,
        vma: _vma,
        settings: widget.settings,
        onSettingsChanged: widget.onSettingsChanged,
        features: widget.features,
        loader: _remoteLoader,
      ),
    );
  }

  void _openSettingsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/settings'),
        builder: (_) => SettingsPage(
          feedbackSender: widget.feedbackSender,
          settings: widget.settings,
          onVmaChanged: _setVma,
          onSettingsChanged: widget.onSettingsChanged,
        ),
      ),
    );
  }
}
