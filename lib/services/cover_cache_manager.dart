import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Persistent cache manager for album/track cover images.
/// 
/// Unlike the default cache manager which stores in temp directory
/// (can be cleared by system anytime), this stores in app support
/// directory which persists across app restarts.
class CoverCacheManager {
  static const String _cacheKey = 'coverImageCache';
  static const int _maxCacheObjects = 1000;
  static const Duration _maxCacheAge = Duration(days: 365);

  static CacheManager? _instance;
  static bool _initialized = false;
  static String? _cachePath;

  /// Get the singleton cache manager instance.
  /// Must call [initialize] before using this.
  static CacheManager get instance {
    if (!_initialized || _instance == null) {
      // Fallback to default cache manager if not initialized
      debugPrint('CoverCacheManager: Not initialized, using DefaultCacheManager');
      return DefaultCacheManager();
    }
    return _instance!;
  }

  /// Check if cache manager is initialized
  static bool get isInitialized => _initialized && _instance != null;

  /// Initialize the cache manager with persistent storage path.
  /// Call this once during app startup (in main.dart).
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final appDir = await getApplicationSupportDirectory();
      _cachePath = p.join(appDir.path, 'cover_cache');
      
      // Ensure cache directory exists
      await Directory(_cachePath!).create(recursive: true);
      
      debugPrint('CoverCacheManager: Initializing at $_cachePath');

      _instance = CacheManager(
        Config(
          _cacheKey,
          stalePeriod: _maxCacheAge,
          maxNrOfCacheObjects: _maxCacheObjects,
          // Use path only (not databaseName) to store database in persistent directory
          repo: JsonCacheInfoRepository(path: _cachePath),
          fileSystem: IOFileSystem(_cachePath!),
          fileService: HttpFileService(),
        ),
      );
      
      _initialized = true;
      debugPrint('CoverCacheManager: Initialized successfully');
    } catch (e) {
      debugPrint('CoverCacheManager: Failed to initialize: $e');
      // Will fallback to DefaultCacheManager
    }
  }

  /// Clear all cached cover images.
  /// Returns the number of files deleted.
  static Future<void> clearCache() async {
    if (!_initialized || _instance == null) return;
    await _instance!.emptyCache();
  }

  /// Get cache statistics
  static Future<CacheStats> getStats() async {
    if (!_initialized || _cachePath == null) {
      return const CacheStats(fileCount: 0, totalSizeBytes: 0);
    }

    final cacheDir = Directory(_cachePath!);
    
    if (!await cacheDir.exists()) {
      return const CacheStats(fileCount: 0, totalSizeBytes: 0);
    }

    int fileCount = 0;
    int totalSize = 0;

    try {
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          fileCount++;
          totalSize += await entity.length();
        }
      }
    } catch (e) {
      debugPrint('CoverCacheManager: Error getting stats: $e');
    }

    return CacheStats(fileCount: fileCount, totalSizeBytes: totalSize);
  }
}

/// Statistics about the cover image cache
class CacheStats {
  final int fileCount;
  final int totalSizeBytes;

  const CacheStats({
    required this.fileCount,
    required this.totalSizeBytes,
  });

  /// Get human-readable size string
  String get formattedSize {
    if (totalSizeBytes < 1024) {
      return '$totalSizeBytes B';
    } else if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else if (totalSizeBytes < 1024 * 1024 * 1024) {
      return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
