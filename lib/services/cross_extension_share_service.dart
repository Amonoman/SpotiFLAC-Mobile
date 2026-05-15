// lib/services/cross_extension_share_service.dart

import 'dart:convert';
import 'package:flutter/services.dart';

class CrossExtensionShareResult {
  final String extensionId;
  final String displayName;
  final bool found;
  final String? itemId;
  final String? externalLink;
  final String? itemName;
  final String? itemArtists;
  final String? error;

  const CrossExtensionShareResult({
    required this.extensionId,
    required this.displayName,
    required this.found,
    this.itemId,
    this.externalLink,
    this.itemName,
    this.itemArtists,
    this.error,
  });

  factory CrossExtensionShareResult.fromJson(Map<String, dynamic> json) {
    return CrossExtensionShareResult(
      extensionId: json['extension_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      found: json['found'] as bool? ?? false,
      itemId: json['item_id'] as String?,
      externalLink: json['external_link'] as String?,
      itemName: json['item_name'] as String?,
      itemArtists: json['item_artists'] as String?,
      error: json['error'] as String?,
    );
  }

  /// Returns the best shareable URL for this result.
  /// Prefers [externalLink] returned by Go. Falls back to constructing
  /// one from [itemId] based on the known extension ID.
  String? resolveLink(String type) {
    // 1. Use what Go already figured out.
    if (externalLink != null && externalLink!.isNotEmpty) {
      return externalLink;
    }

    // 2. Fallback: build from itemId.
    final raw = itemId ?? '';
    if (raw.isEmpty) return null;
    final id = _stripPrefix(raw);
    if (id.isEmpty) return null;
    return _buildLink(extensionId.toLowerCase(), id, type);
  }

  static String _stripPrefix(String id) {
    final colon = id.indexOf(':');
    return colon >= 0 ? id.substring(colon + 1) : id;
  }

  static String? _buildLink(String ext, String id, String type) {
    if (ext.contains('qobuz')) {
      return type == 'artist'
          ? 'https://open.qobuz.com/interpreter/$id'
          : 'https://open.qobuz.com/album/$id';
    }
    if (ext.contains('tidal')) {
      return type == 'artist'
          ? 'https://tidal.com/browse/artist/$id'
          : 'https://tidal.com/browse/album/$id';
    }
    if (ext.contains('deezer')) {
      return type == 'artist'
          ? 'https://www.deezer.com/artist/$id'
          : 'https://www.deezer.com/album/$id';
    }
    if (ext.contains('spotify')) {
      return type == 'artist'
          ? 'https://open.spotify.com/artist/$id'
          : 'https://open.spotify.com/album/$id';
    }
    if (ext.contains('apple') || ext.contains('applemusic')) {
      // Apple Music URLs: music.apple.com/{storefront}/{type}/{name}/{id}
      // We don't know the storefront or slug, so use the minimal form.
      return type == 'artist'
          ? 'https://music.apple.com/us/artist/$id'
          : 'https://music.apple.com/us/album/$id';
    }
    if (ext.contains('soundcloud')) {
      // SoundCloud needs a slug in the URL which we don't have from the ID alone.
      // Return null — the Go layer should have found the permalink_url via customSearch.
      return null;
    }
    if (ext.contains('youtube') || ext.contains('ytmusic')) {
      return type == 'artist'
          ? 'https://music.youtube.com/channel/$id'
          : 'https://music.youtube.com/browse/$id';
    }
    return null;
  }
}

class CrossExtensionShareService {
  static const _channel = MethodChannel('com.zarz.spotiflac/backend');

  static Future<List<CrossExtensionShareResult>> findAcrossExtensions({
    required String name,
    required String artists,
    required String type,
    required String sourceExtensionId,
  }) async {
    final requestJson = jsonEncode({
      'name': name,
      'artists': artists,
      'type': type,
      'source_extension_id': sourceExtensionId,
    });

    final String? responseJson = await _channel.invokeMethod(
      'findCollectionAcrossExtensions',
      requestJson,
    );

    if (responseJson == null || responseJson.isEmpty) return [];

    final List<dynamic> decoded = jsonDecode(responseJson) as List<dynamic>;
    return decoded
        .map((e) =>
            CrossExtensionShareResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
