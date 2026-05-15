const List<String> audioConversionTargetFormats = [
  'ALAC',
  'FLAC',
  'AAC',
  'MP3',
  'Opus',
];

bool isLosslessConversionTarget(String targetFormat) {
  final normalized = targetFormat.trim().toLowerCase();
  return normalized == 'alac' || normalized == 'flac';
}

bool isLosslessConversionSource(String sourceFormat) {
  switch (sourceFormat.trim().toUpperCase()) {
    case 'FLAC':
    case 'ALAC':
    case 'M4A':
      return true;
    default:
      return false;
  }
}

bool canConvertAudioFormat({
  required String sourceFormat,
  required String targetFormat,
}) {
  if (sourceFormat.trim().toUpperCase() == targetFormat.trim().toUpperCase()) {
    return false;
  }
  if (isLosslessConversionTarget(targetFormat) &&
      !isLosslessConversionSource(sourceFormat)) {
    return false;
  }
  return true;
}

String? convertibleAudioSourceFormat({
  String? storedFormat,
  String? filePath,
  String? fileName,
}) {
  final fromStored = _convertibleAudioFormatLabel(storedFormat);
  if (fromStored != null) return fromStored;

  final name = (fileName != null && fileName.trim().isNotEmpty)
      ? fileName
      : filePath;
  if (name == null || name.trim().isEmpty) return null;

  final normalizedName = name.trim().toLowerCase();
  final dotIndex = normalizedName.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == normalizedName.length - 1) {
    return null;
  }
  return _convertibleAudioFormatLabel(normalizedName.substring(dotIndex + 1));
}

String? _convertibleAudioFormatLabel(String? rawFormat) {
  final format = rawFormat?.trim().toLowerCase();
  if (format == null || format.isEmpty) return null;

  switch (format) {
    case 'flac':
      return 'FLAC';
    case 'alac':
      return 'ALAC';
    case 'm4a':
    case 'mp4':
      return 'M4A';
    case 'aac':
    case 'mp4a':
      return 'AAC';
    case 'mp3':
      return 'MP3';
    case 'opus':
    case 'ogg':
      return 'Opus';
    case 'eac3':
    case 'ec-3':
      return 'EAC3';
    case 'ac3':
    case 'ac-3':
      return 'AC3';
    case 'ac4':
    case 'ac-4':
      return 'AC4';
    default:
      return null;
  }
}

String normalizedConvertedAudioFormat(String targetFormat) {
  return targetFormat.trim().toLowerCase();
}

int? convertedAudioBitrateKbps({
  required String targetFormat,
  required String bitrate,
}) {
  if (isLosslessConversionTarget(targetFormat)) return null;
  final match = RegExp(r'(\d+)').firstMatch(bitrate);
  return match != null ? int.tryParse(match.group(1)!) : null;
}
