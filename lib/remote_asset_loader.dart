import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'train_data_loader.dart';

enum RemoteLoadOrigin { network, cache, asset }

class RemoteLoadResult {
  const RemoteLoadResult({
    required this.data,
    required this.origin,
    this.source,
    this.error,
  });

  final String data;
  final RemoteLoadOrigin origin;
  final FileSource? source;
  final Object? error;

  bool get fromCache => origin == RemoteLoadOrigin.cache;
  bool get fromAsset => origin == RemoteLoadOrigin.asset;
}

class RemoteAssetLoader {
  RemoteAssetLoader({AdvancedGitHubCacheManager? cacheManager})
    : _cacheManager = cacheManager ?? AdvancedGitHubCacheManager();

  final AdvancedGitHubCacheManager _cacheManager;

  Future<RemoteLoadResult> loadText({
    required String remoteUrl,
    required String assetPath,
    bool forceRefresh = false,
  }) async {
    try {
      final result = await _cacheManager.getFile(
        remoteUrl,
        forceRefresh: forceRefresh,
      );
      return RemoteLoadResult(
        data: result.data,
        origin: result.fromCache
            ? RemoteLoadOrigin.cache
            : RemoteLoadOrigin.network,
        source: result.source,
      );
    } catch (e) {
      final bundled = await rootBundle.loadString(assetPath);
      return RemoteLoadResult(
        data: bundled,
        origin: RemoteLoadOrigin.asset,
        error: e,
      );
    }
  }
}
