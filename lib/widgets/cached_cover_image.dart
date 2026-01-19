import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spotiflac_android/services/cover_cache_manager.dart';

/// A wrapper around CachedNetworkImage that uses persistent cache storage.
/// 
/// This ensures cover images are cached to disk and persist across app restarts,
/// instead of being stored in the temporary directory that can be cleared by the OS.
class CachedCoverImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Widget Function(BuildContext, String, Object)? errorWidget;
  final Widget Function(BuildContext, String)? placeholder;
  final BorderRadius? borderRadius;

  const CachedCoverImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    this.errorWidget,
    this.placeholder,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      cacheManager: CoverCacheManager.isInitialized 
          ? CoverCacheManager.instance 
          : null,
      errorWidget: errorWidget,
      placeholder: placeholder,
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }
}

/// Provider for CachedNetworkImageProvider that uses persistent cache.
/// Use this for precacheImage() calls.
CachedNetworkImageProvider cachedCoverImageProvider(String url) {
  return CachedNetworkImageProvider(
    url,
    cacheManager: CoverCacheManager.isInitialized 
        ? CoverCacheManager.instance 
        : null,
  );
}
