import 'dart:convert';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AdvancedGitHubCacheManager {
  AdvancedGitHubCacheManager({CacheManager? cacheManager})
    : _cacheManager = cacheManager ?? DefaultCacheManager();

  final CacheManager _cacheManager;

  Future<CacheResult> getFile(String url, {bool forceRefresh = false}) async {
    try {
      if (!forceRefresh) {
        final cached = await _cacheManager.getFileFromCache(url);
        if (cached != null) {
          return _toResult(cached);
        }
      }

      final fetched = await _cacheManager.downloadFile(
        url,
        force: forceRefresh,
      );
      return _toResult(fetched);
    } catch (e) {
      // If download fails but a stale cache exists, return it.
      final fallback = await _cacheManager.getFileFromCache(url);
      if (fallback != null) {
        return _toResult(fallback);
      }
      rethrow;
    }
  }

  Future<void> clearCache({String? url}) async {
    if (url != null) {
      await _cacheManager.removeFile(url);
    } else {
      await _cacheManager.emptyCache();
    }
  }

  Future<CacheResult> _toResult(FileInfo info) async {
    final content = utf8.decode(await info.file.readAsBytes());
    final fromCache = info.source != FileSource.Online;
    return CacheResult(content, fromCache, info.source);
  }
}

class CacheResult {
  final String data;
  final bool fromCache;
  final FileSource source;

  CacheResult(this.data, this.fromCache, this.source);
}
