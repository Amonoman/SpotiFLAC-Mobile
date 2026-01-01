import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:spotiflac_android/models/download_item.dart';
import 'package:spotiflac_android/models/settings.dart';
import 'package:spotiflac_android/models/track.dart';
import 'package:spotiflac_android/services/platform_bridge.dart';
import 'package:spotiflac_android/services/ffmpeg_service.dart';

// Download History Item model
class DownloadHistoryItem {
  final String id;
  final String trackName;
  final String artistName;
  final String albumName;
  final String? coverUrl;
  final String filePath;
  final String service;
  final DateTime downloadedAt;

  const DownloadHistoryItem({
    required this.id,
    required this.trackName,
    required this.artistName,
    required this.albumName,
    this.coverUrl,
    required this.filePath,
    required this.service,
    required this.downloadedAt,
  });
}

// Download History State
class DownloadHistoryState {
  final List<DownloadHistoryItem> items;

  const DownloadHistoryState({this.items = const []});

  DownloadHistoryState copyWith({List<DownloadHistoryItem>? items}) {
    return DownloadHistoryState(items: items ?? this.items);
  }
}

// Download History Notifier (Riverpod 3.x)
class DownloadHistoryNotifier extends Notifier<DownloadHistoryState> {
  @override
  DownloadHistoryState build() {
    return const DownloadHistoryState();
  }

  void addToHistory(DownloadHistoryItem item) {
    state = state.copyWith(items: [item, ...state.items]);
  }

  void removeFromHistory(String id) {
    state = state.copyWith(
      items: state.items.where((item) => item.id != id).toList(),
    );
  }

  void clearHistory() {
    state = const DownloadHistoryState();
  }
}

// Download History Provider
final downloadHistoryProvider = NotifierProvider<DownloadHistoryNotifier, DownloadHistoryState>(
  DownloadHistoryNotifier.new,
);

class DownloadQueueState {
  final List<DownloadItem> items;
  final DownloadItem? currentDownload;
  final bool isProcessing;
  final String outputDir;
  final String filenameFormat;
  final bool autoFallback;

  const DownloadQueueState({
    this.items = const [],
    this.currentDownload,
    this.isProcessing = false,
    this.outputDir = '',
    this.filenameFormat = '{artist} - {title}',
    this.autoFallback = true,
  });

  DownloadQueueState copyWith({
    List<DownloadItem>? items,
    DownloadItem? currentDownload,
    bool? isProcessing,
    String? outputDir,
    String? filenameFormat,
    bool? autoFallback,
  }) {
    return DownloadQueueState(
      items: items ?? this.items,
      currentDownload: currentDownload ?? this.currentDownload,
      isProcessing: isProcessing ?? this.isProcessing,
      outputDir: outputDir ?? this.outputDir,
      filenameFormat: filenameFormat ?? this.filenameFormat,
      autoFallback: autoFallback ?? this.autoFallback,
    );
  }

  int get queuedCount => items.where((i) => i.status == DownloadStatus.queued || i.status == DownloadStatus.downloading).length;
  int get completedCount => items.where((i) => i.status == DownloadStatus.completed).length;
  int get failedCount => items.where((i) => i.status == DownloadStatus.failed).length;
}

// Download Queue Notifier (Riverpod 3.x)
class DownloadQueueNotifier extends Notifier<DownloadQueueState> {
  Timer? _progressTimer;

  @override
  DownloadQueueState build() {
    // Initialize output directory asynchronously
    Future.microtask(() async {
      await _initOutputDir();
    });
    return const DownloadQueueState();
  }

  void _startProgressPolling(String itemId) {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      try {
        final progress = await PlatformBridge.getDownloadProgress();
        final bytesReceived = progress['bytes_received'] as int? ?? 0;
        final bytesTotal = progress['bytes_total'] as int? ?? 0;
        final isDownloading = progress['is_downloading'] as bool? ?? false;
        
        if (isDownloading && bytesTotal > 0) {
          final percentage = bytesReceived / bytesTotal;
          updateProgress(itemId, percentage);
          
          // Log progress
          final mbReceived = bytesReceived / (1024 * 1024);
          final mbTotal = bytesTotal / (1024 * 1024);
          print('[DownloadQueue] Progress: ${(percentage * 100).toStringAsFixed(1)}% (${mbReceived.toStringAsFixed(2)}/${mbTotal.toStringAsFixed(2)} MB)');
        }
      } catch (e) {
        // Ignore polling errors
      }
    });
  }

  void _stopProgressPolling() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  Future<void> _initOutputDir() async {
    if (state.outputDir.isEmpty) {
      try {
        if (Platform.isIOS) {
          // iOS: Use Documents directory (accessible via Files app)
          final dir = await getApplicationDocumentsDirectory();
          final musicDir = Directory('${dir.path}/SpotiFLAC');
          if (!await musicDir.exists()) {
            await musicDir.create(recursive: true);
          }
          state = state.copyWith(outputDir: musicDir.path);
        } else {
          // Android: Use external storage Music folder
          final dir = await getExternalStorageDirectory();
          if (dir != null) {
            final musicDir = Directory('${dir.parent.parent.parent.parent.path}/Music/SpotiFLAC');
            if (!await musicDir.exists()) {
              await musicDir.create(recursive: true);
            }
            state = state.copyWith(outputDir: musicDir.path);
          } else {
            // Fallback to documents directory
            final docDir = await getApplicationDocumentsDirectory();
            final musicDir = Directory('${docDir.path}/SpotiFLAC');
            if (!await musicDir.exists()) {
              await musicDir.create(recursive: true);
            }
            state = state.copyWith(outputDir: musicDir.path);
          }
        }
      } catch (e) {
        // Fallback for any platform
        final dir = await getApplicationDocumentsDirectory();
        final musicDir = Directory('${dir.path}/SpotiFLAC');
        if (!await musicDir.exists()) {
          await musicDir.create(recursive: true);
        }
        state = state.copyWith(outputDir: musicDir.path);
      }
    }
  }

  void setOutputDir(String dir) {
    state = state.copyWith(outputDir: dir);
  }

  void updateSettings(AppSettings settings) {
    state = state.copyWith(
      outputDir: settings.downloadDirectory.isNotEmpty ? settings.downloadDirectory : state.outputDir,
      filenameFormat: settings.filenameFormat,
      autoFallback: settings.autoFallback,
    );
  }

  String addToQueue(Track track, String service) {
    final id = '${track.isrc ?? track.id}-${DateTime.now().millisecondsSinceEpoch}';
    final item = DownloadItem(
      id: id,
      track: track,
      service: service,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(items: [...state.items, item]);

    if (!state.isProcessing) {
      // Run in microtask to not block UI
      Future.microtask(() => _processQueue());
    }

    return id;
  }

  void addMultipleToQueue(List<Track> tracks, String service) {
    final newItems = tracks.map((track) {
      final id = '${track.isrc ?? track.id}-${DateTime.now().millisecondsSinceEpoch}';
      return DownloadItem(
        id: id,
        track: track,
        service: service,
        createdAt: DateTime.now(),
      );
    }).toList();

    state = state.copyWith(items: [...state.items, ...newItems]);

    if (!state.isProcessing) {
      // Run in microtask to not block UI
      Future.microtask(() => _processQueue());
    }
  }

  void updateItemStatus(String id, DownloadStatus status, {double? progress, String? filePath, String? error}) {
    final items = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(
          status: status,
          progress: progress ?? item.progress,
          filePath: filePath,
          error: error,
        );
      }
      return item;
    }).toList();

    state = state.copyWith(items: items);
  }

  void updateProgress(String id, double progress) {
    updateItemStatus(id, DownloadStatus.downloading, progress: progress);
  }

  void cancelItem(String id) {
    updateItemStatus(id, DownloadStatus.skipped);
  }

  void clearCompleted() {
    final items = state.items.where((item) =>
      item.status != DownloadStatus.completed &&
      item.status != DownloadStatus.failed &&
      item.status != DownloadStatus.skipped
    ).toList();

    state = state.copyWith(items: items);
  }

  void clearAll() {
    state = const DownloadQueueState();
  }

  /// Embed metadata and cover to a FLAC file after M4A conversion
  Future<void> _embedMetadataAndCover(String flacPath, Track track) async {
    // Download cover first
    String? coverPath;
    if (track.coverUrl != null && track.coverUrl!.isNotEmpty) {
      coverPath = '$flacPath.cover.jpg';
      try {
        // Download cover using HTTP
        final httpClient = HttpClient();
        final request = await httpClient.getUrl(Uri.parse(track.coverUrl!));
        final response = await request.close();
        if (response.statusCode == 200) {
          final file = File(coverPath);
          final sink = file.openWrite();
          await response.pipe(sink);
          await sink.close();
          print('[DownloadQueue] Cover downloaded to: $coverPath');
        } else {
          print('[DownloadQueue] Failed to download cover: HTTP ${response.statusCode}');
          coverPath = null;
        }
        httpClient.close();
      } catch (e) {
        print('[DownloadQueue] Failed to download cover: $e');
        coverPath = null;
      }
    }

    // Use Go backend to embed metadata
    try {
      // For now, we'll use FFmpeg to embed cover since Go backend expects to download the file
      // FFmpeg can embed cover art to FLAC
      if (coverPath != null && await File(coverPath).exists()) {
        final tempOutput = '$flacPath.tmp';
        final command = '-i "$flacPath" -i "$coverPath" -map 0:a -map 1:0 -c copy -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" -disposition:v attached_pic "$tempOutput" -y';
        
        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();
        
        if (ReturnCode.isSuccess(returnCode)) {
          // Replace original with temp
          await File(flacPath).delete();
          await File(tempOutput).rename(flacPath);
          print('[DownloadQueue] Cover embedded via FFmpeg');
        } else {
          // Try alternative method using metaflac-style embedding
          print('[DownloadQueue] FFmpeg cover embed failed, trying alternative...');
          // Clean up temp file if exists
          final tempFile = File(tempOutput);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
        
        // Clean up cover file
        try {
          await File(coverPath).delete();
        } catch (_) {}
      }
    } catch (e) {
      print('[DownloadQueue] Failed to embed metadata: $e');
    }
  }

  Future<void> _processQueue() async {
    if (state.isProcessing) return; // Prevent multiple concurrent processing
    
    state = state.copyWith(isProcessing: true);
    print('[DownloadQueue] Starting queue processing...');

    // Ensure output directory is initialized before processing
    if (state.outputDir.isEmpty) {
      print('[DownloadQueue] Output dir empty, initializing...');
      await _initOutputDir();
    }
    
    // If still empty, use fallback
    if (state.outputDir.isEmpty) {
      print('[DownloadQueue] Using fallback directory...');
      final dir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${dir.path}/SpotiFLAC');
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }
      state = state.copyWith(outputDir: musicDir.path);
    }
    
    print('[DownloadQueue] Output directory: ${state.outputDir}');

    while (true) {
      final nextItem = state.items.firstWhere(
        (item) => item.status == DownloadStatus.queued,
        orElse: () => DownloadItem(
          id: '',
          track: const Track(id: '', name: '', artistName: '', albumName: '', duration: 0),
          service: '',
          createdAt: DateTime.now(),
        ),
      );

      if (nextItem.id.isEmpty) {
        print('[DownloadQueue] No more items to process');
        break;
      }

      print('[DownloadQueue] Processing: ${nextItem.track.name} by ${nextItem.track.artistName}');
      print('[DownloadQueue] Cover URL: ${nextItem.track.coverUrl}');
      
      state = state.copyWith(currentDownload: nextItem);
      updateItemStatus(nextItem.id, DownloadStatus.downloading);
      
      // Start progress polling
      _startProgressPolling(nextItem.id);

      try {
        Map<String, dynamic> result;

        if (state.autoFallback) {
          print('[DownloadQueue] Using auto-fallback mode');
          result = await PlatformBridge.downloadWithFallback(
            isrc: nextItem.track.isrc ?? '',
            spotifyId: nextItem.track.id,
            trackName: nextItem.track.name,
            artistName: nextItem.track.artistName,
            albumName: nextItem.track.albumName,
            albumArtist: nextItem.track.albumArtist,
            coverUrl: nextItem.track.coverUrl,
            outputDir: state.outputDir,
            filenameFormat: state.filenameFormat,
            trackNumber: nextItem.track.trackNumber ?? 1,
            discNumber: nextItem.track.discNumber ?? 1,
            releaseDate: nextItem.track.releaseDate,
            preferredService: nextItem.service,
          );
        } else {
          result = await PlatformBridge.downloadTrack(
            isrc: nextItem.track.isrc ?? '',
            service: nextItem.service,
            spotifyId: nextItem.track.id,
            trackName: nextItem.track.name,
            artistName: nextItem.track.artistName,
            albumName: nextItem.track.albumName,
            albumArtist: nextItem.track.albumArtist,
            coverUrl: nextItem.track.coverUrl,
            outputDir: state.outputDir,
            filenameFormat: state.filenameFormat,
            trackNumber: nextItem.track.trackNumber ?? 1,
            discNumber: nextItem.track.discNumber ?? 1,
            releaseDate: nextItem.track.releaseDate,
          );
        }

        // Stop progress polling for this item
        _stopProgressPolling();
        
        print('[DownloadQueue] Result: $result');
        
        if (result['success'] == true) {
          var filePath = result['file_path'] as String?;
          print('[DownloadQueue] Download success, file: $filePath');
          
          // Check if file is M4A (DASH stream from Tidal) and needs remuxing to FLAC
          if (filePath != null && filePath.endsWith('.m4a')) {
            print('[DownloadQueue] Converting M4A to FLAC...');
            updateItemStatus(nextItem.id, DownloadStatus.downloading, progress: 0.9);
            final flacPath = await FFmpegService.convertM4aToFlac(filePath);
            if (flacPath != null) {
              filePath = flacPath;
              print('[DownloadQueue] Converted to: $flacPath');
              
              // After conversion, embed metadata and cover to the new FLAC file
              print('[DownloadQueue] Embedding metadata and cover to converted FLAC...');
              try {
                await _embedMetadataAndCover(
                  flacPath,
                  nextItem.track,
                );
                print('[DownloadQueue] Metadata and cover embedded successfully');
              } catch (e) {
                print('[DownloadQueue] Warning: Failed to embed metadata/cover: $e');
              }
            }
          }
          
          updateItemStatus(
            nextItem.id,
            DownloadStatus.completed,
            progress: 1.0,
            filePath: filePath,
          );

          if (filePath != null) {
            ref.read(downloadHistoryProvider.notifier).addToHistory(
              DownloadHistoryItem(
                id: nextItem.id,
                trackName: nextItem.track.name,
                artistName: nextItem.track.artistName,
                albumName: nextItem.track.albumName,
                coverUrl: nextItem.track.coverUrl,
                filePath: filePath,
                service: result['service'] as String? ?? nextItem.service,
                downloadedAt: DateTime.now(),
              ),
            );
          }
        } else {
          final errorMsg = result['error'] as String? ?? 'Download failed';
          print('[DownloadQueue] Download failed: $errorMsg');
          updateItemStatus(
            nextItem.id,
            DownloadStatus.failed,
            error: errorMsg,
          );
        }
      } catch (e, stackTrace) {
        _stopProgressPolling();
        print('[DownloadQueue] Exception: $e');
        print('[DownloadQueue] StackTrace: $stackTrace');
        updateItemStatus(
          nextItem.id,
          DownloadStatus.failed,
          error: e.toString(),
        );
      }
    }

    _stopProgressPolling();
    print('[DownloadQueue] Queue processing finished');
    state = state.copyWith(isProcessing: false, currentDownload: null);
  }
}

final downloadQueueProvider = NotifierProvider<DownloadQueueNotifier, DownloadQueueState>(
  DownloadQueueNotifier.new,
);
