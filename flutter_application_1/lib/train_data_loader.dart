import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

class AdvancedGitHubCacheManager {
  final Map<String, CacheEntry> _memoryCache = {};
  final Duration _defaultCacheDuration;

  AdvancedGitHubCacheManager({Duration? cacheDuration})
      : _defaultCacheDuration = cacheDuration ?? const Duration(hours: 1);

  Future<CacheResult> getFile(
    String url, {
    Duration? maxAge,
    bool forceRefresh = false,
  }) async {
    final cacheDuration = maxAge ?? _defaultCacheDuration;

    if (!forceRefresh && _memoryCache.containsKey(url)) {
      final entry = _memoryCache[url]!;
      if (DateTime.now().difference(entry.timestamp) < cacheDuration) {
        return CacheResult(entry.data, true, CacheSource.memory);
      }
    }

    // Check disk cache
    final diskFile = await _getCacheFile(url);
    if (!forceRefresh && await diskFile.exists()) {
      final lastModified = await diskFile.lastModified();
      if (DateTime.now().difference(lastModified) < cacheDuration) {
        final content = await diskFile.readAsString();
        _updateMemoryCache(url, content);
        return CacheResult(content, true, CacheSource.disk);
      }
    }

    // Fetch from network
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final content = response.body;
        
        // Update caches
        _updateMemoryCache(url, content);
        await _updateDiskCache(url, content);
        
        return CacheResult(content, false, CacheSource.network);
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to stale cache if available
      if (await diskFile.exists()) {
        final staleContent = await diskFile.readAsString();
        return CacheResult(staleContent, true, CacheSource.diskStale);
      }
      rethrow;
    }
  }

  void _updateMemoryCache(String url, String data) {
    _memoryCache[url] = CacheEntry(data, DateTime.now());
  }

  Future<void> _updateDiskCache(String url, String data) async {
    final file = await _getCacheFile(url);
    await file.create(recursive: true);
    await file.writeAsString(data);
  }

  Future<void> clearCache({String? url}) async {
    if (url != null) {
      _memoryCache.remove(url);
      final file = await _getCacheFile(url);
      if (await file.exists()) {
        await file.delete();
      }
    } else {
      _memoryCache.clear();
      final directory = await getTemporaryDirectory();
      final cacheDir = Directory(p.join(directory.path, 'github_cache'));
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    }
  }

  Future<File> _getCacheFile(String url) async {
    final directory = await getTemporaryDirectory();
    final filename = _getFilenameFromUrl(url);
    return File(p.join(directory.path, 'github_cache', filename));
  }

  String _getFilenameFromUrl(String url) {
    return Uri.parse(url).pathSegments.join('_');
  }
}

class CacheEntry {
  final String data;
  final DateTime timestamp;

  CacheEntry(this.data, this.timestamp);
}

class CacheResult {
  final String data;
  final bool fromCache;
  final CacheSource source;

  CacheResult(this.data, this.fromCache, this.source);
}

enum CacheSource {
  memory,
  disk,
  diskStale,
  network
}

extension CacheUtils on AdvancedGitHubCacheManager {
  Future<int> getCacheSize() async {
    final directory = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(directory.path, 'github_cache'));

    if (!await cacheDir.exists()) return 0;

    int totalSize = 0;
    await for (var file in cacheDir.list()) {
      if (file is File) {
        totalSize += await file.length();
      }
    }
    return totalSize;
  }

  Future<void> clearOldCache({
    Duration olderThan = const Duration(days: 7),
  }) async {
    final directory = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(directory.path, 'github_cache'));

    if (!await cacheDir.exists()) return;

    final cutoff = DateTime.now().subtract(olderThan);

    await for (var file in cacheDir.list()) {
      if (file is File) {
        final lastModified = await file.lastModified();
        if (lastModified.isBefore(cutoff)) {
          await file.delete();
        }
      }
    }
  }
}
