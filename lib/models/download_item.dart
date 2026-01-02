import 'package:json_annotation/json_annotation.dart';
import 'package:spotiflac_android/models/track.dart';

part 'download_item.g.dart';

/// Download status enum
enum DownloadStatus {
  queued,
  downloading,
  completed,
  failed,
  skipped,
}

@JsonSerializable()
class DownloadItem {
  final String id;
  final Track track;
  final String service;
  final DownloadStatus status;
  final double progress;
  final String? filePath;
  final String? error;
  final DateTime createdAt;
  final String? qualityOverride; // Override quality for this specific download

  const DownloadItem({
    required this.id,
    required this.track,
    required this.service,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.filePath,
    this.error,
    required this.createdAt,
    this.qualityOverride,
  });

  DownloadItem copyWith({
    String? id,
    Track? track,
    String? service,
    DownloadStatus? status,
    double? progress,
    String? filePath,
    String? error,
    DateTime? createdAt,
    String? qualityOverride,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      track: track ?? this.track,
      service: service ?? this.service,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      filePath: filePath ?? this.filePath,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      qualityOverride: qualityOverride ?? this.qualityOverride,
    );
  }

  factory DownloadItem.fromJson(Map<String, dynamic> json) =>
      _$DownloadItemFromJson(json);
  Map<String, dynamic> toJson() => _$DownloadItemToJson(this);
}
