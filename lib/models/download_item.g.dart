// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DownloadItem _$DownloadItemFromJson(Map<String, dynamic> json) => DownloadItem(
  id: json['id'] as String,
  track: Track.fromJson(json['track'] as Map<String, dynamic>),
  service: json['service'] as String,
  status:
      $enumDecodeNullable(_$DownloadStatusEnumMap, json['status']) ??
      DownloadStatus.queued,
  progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
  filePath: json['filePath'] as String?,
  error: json['error'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  qualityOverride: json['qualityOverride'] as String?,
);

Map<String, dynamic> _$DownloadItemToJson(DownloadItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'track': instance.track,
      'service': instance.service,
      'status': _$DownloadStatusEnumMap[instance.status]!,
      'progress': instance.progress,
      'filePath': instance.filePath,
      'error': instance.error,
      'createdAt': instance.createdAt.toIso8601String(),
      'qualityOverride': instance.qualityOverride,
    };

const _$DownloadStatusEnumMap = {
  DownloadStatus.queued: 'queued',
  DownloadStatus.downloading: 'downloading',
  DownloadStatus.completed: 'completed',
  DownloadStatus.failed: 'failed',
  DownloadStatus.skipped: 'skipped',
};
