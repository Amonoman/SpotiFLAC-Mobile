// lib/services/cross_extension_share_service.dart

import 'dart:convert';
import 'package:flutter/services.dart';

class CrossExtensionShareResult {
  final String extensionId;
  final String displayName;
  final bool found;

  /// Raw prefixed ID, e.g. "qobuz:0060253780269" or "tidal:456".
  final String? itemId;
  final String? albumId;
  final String? artistId;

  /// Direct web URL returned by the extension, e.g. "https://play.qobuz.com/track/12345".
  /// May be a track URL if no album URL is available – still opens the correct context.
  final String? externalLink;

  final String? itemName;
  final String? itemArtists;
  final String? error;

  const CrossExtensionShareResult({
    required this.extensionId,
    required this.displayName,
    required this.found,
    this.itemId,
    this.albumId,
    this.artistId,
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
      albumId: json['album_id'] as String?,
      artistId: json['artist_id'] as String?,
      externalLink: json['external_link'] as String?,
      itemName: json['item_name'] as String?,
      itemArtists: json['item_artists'] as String?,
      error: json['error'] as String?,
    );
  }

  /// Returns the best available URL for this result.
  /// Prefers [externalLink], then constructs one from [itemId].
  String? resolveLink(String type) {
    if (externalLink != null && externalLink!.isNotEmpty) {
      return externalLink;
    }
    final id = _stripPrefix(itemId ?? albumId ?? artistId ?? '');
    if (id.isEmpty) return null;
    return _buildFallbackLink(extensionId, id, type);
  }

  static String _stripPrefix(String id) {
    final colon = id.indexOf(':');
    return colon >= 0 ? id.substring(colon + 1) : id;
  }

  static String _buildFallbackLink(String extensionId, String id, String type) {
    final ext = extensionId.toLowerCase();
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
    if (ext.contains('apple') || ext.contains('itunes')) {
      return 'https://music.apple.com/album/$id';
    }
    if (ext.contains('youtube') || ext.contains('ytmusic')) {
      return type == 'artist'
          ? 'https://music.youtube.com/channel/$id'
          : 'https://music.youtube.com/browse/$id';
    }
    return id;
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
        .map((e) => CrossExtensionShareResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
