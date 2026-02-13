import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:spotiflac_android/app.dart';
import 'package:spotiflac_android/providers/download_queue_provider.dart';
import 'package:spotiflac_android/providers/extension_provider.dart';
import 'package:spotiflac_android/services/notification_service.dart';
import 'package:spotiflac_android/services/share_intent_service.dart';
import 'package:spotiflac_android/services/cover_cache_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final runtimeProfile = await _resolveRuntimeProfile();
  _configureImageCache(runtimeProfile);

  runApp(
    ProviderScope(
      child: _EagerInitialization(
        child: SpotiFLACApp(
          disableOverscrollEffects: runtimeProfile.disableOverscrollEffects,
        ),
      ),
    ),
  );
}

Future<_RuntimeProfile> _resolveRuntimeProfile() async {
  const defaults = _RuntimeProfile(
    imageCacheMaximumSize: 240,
    imageCacheMaximumSizeBytes: 60 << 20,
    disableOverscrollEffects: false,
  );

  if (!Platform.isAndroid) return defaults;

  try {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final isArm32Only = androidInfo.supported64BitAbis.isEmpty;
    final isLowRamDevice =
        androidInfo.isLowRamDevice || androidInfo.physicalRamSize <= 2500;

    if (!isArm32Only && !isLowRamDevice) {
      return defaults;
    }

    return _RuntimeProfile(
      imageCacheMaximumSize: 120,
      imageCacheMaximumSizeBytes: 24 << 20,
      disableOverscrollEffects: true,
    );
  } catch (e) {
    debugPrint('Failed to resolve runtime profile: $e');
    return defaults;
  }
}

void _configureImageCache(_RuntimeProfile runtimeProfile) {
  final imageCache = PaintingBinding.instance.imageCache;
  // Keep memory cache bounded so cover-heavy pages don't retain too many
  // full-resolution images simultaneously.
  imageCache.maximumSize = runtimeProfile.imageCacheMaximumSize;
  imageCache.maximumSizeBytes = runtimeProfile.imageCacheMaximumSizeBytes;
}

class _RuntimeProfile {
  final int imageCacheMaximumSize;
  final int imageCacheMaximumSizeBytes;
  final bool disableOverscrollEffects;

  const _RuntimeProfile({
    required this.imageCacheMaximumSize,
    required this.imageCacheMaximumSizeBytes,
    required this.disableOverscrollEffects,
  });
}

/// Widget to eagerly initialize providers that need to load data on startup
class _EagerInitialization extends ConsumerStatefulWidget {
  const _EagerInitialization({required this.child});
  final Widget child;

  @override
  ConsumerState<_EagerInitialization> createState() =>
      _EagerInitializationState();
}

class _EagerInitializationState extends ConsumerState<_EagerInitialization> {
  @override
  void initState() {
    super.initState();
    _initializeAppServices();
    _initializeExtensions();
    ref.read(downloadHistoryProvider);
  }

  Future<void> _initializeAppServices() async {
    try {
      await CoverCacheManager.initialize();
      await Future.wait([
        NotificationService().initialize(),
        ShareIntentService().initialize(),
      ]);
    } catch (e) {
      debugPrint('Failed to initialize app services: $e');
    }
  }

  Future<void> _initializeExtensions() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final extensionsDir = '${appDir.path}/extensions';
      final dataDir = '${appDir.path}/extension_data';

      await Directory(extensionsDir).create(recursive: true);
      await Directory(dataDir).create(recursive: true);

      await ref
          .read(extensionProvider.notifier)
          .initialize(extensionsDir, dataDir);
    } catch (e) {
      debugPrint('Failed to initialize extensions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
