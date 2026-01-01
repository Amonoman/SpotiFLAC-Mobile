import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';

/// FFmpeg service for audio conversion and remuxing
class FFmpegService {
  /// Convert M4A (DASH segments) to FLAC
  /// Returns the output file path on success, null on failure
  static Future<String?> convertM4aToFlac(String inputPath) async {
    final outputPath = inputPath.replaceAll('.m4a', '.flac');

    // FFmpeg command to remux M4A to FLAC
    final command =
        '-i "$inputPath" -c:a flac -compression_level 8 "$outputPath" -y';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      // Delete original M4A file
      try {
        await File(inputPath).delete();
      } catch (_) {}
      return outputPath;
    }

    // Log error for debugging
    final logs = await session.getLogs();
    for (final log in logs) {
      print('[FFmpeg] ${log.getMessage()}');
    }

    return null;
  }

  /// Convert FLAC to MP3
  static Future<String?> convertFlacToMp3(
    String inputPath, {
    String bitrate = '320k',
  }) async {
    final dir = File(inputPath).parent.path;
    final baseName =
        inputPath.split(Platform.pathSeparator).last.replaceAll('.flac', '');
    final outputDir = '$dir${Platform.pathSeparator}MP3';

    // Create output directory
    await Directory(outputDir).create(recursive: true);

    final outputPath = '$outputDir${Platform.pathSeparator}$baseName.mp3';

    final command =
        '-i "$inputPath" -codec:a libmp3lame -b:a $bitrate -map 0:a -map_metadata 0 -id3v2_version 3 "$outputPath" -y';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return outputPath;
    }

    return null;
  }

  /// Convert FLAC to M4A (AAC or ALAC)
  static Future<String?> convertFlacToM4a(
    String inputPath, {
    String codec = 'aac',
    String bitrate = '256k',
  }) async {
    final dir = File(inputPath).parent.path;
    final baseName =
        inputPath.split(Platform.pathSeparator).last.replaceAll('.flac', '');
    final outputDir = '$dir${Platform.pathSeparator}M4A';

    // Create output directory
    await Directory(outputDir).create(recursive: true);

    final outputPath = '$outputDir${Platform.pathSeparator}$baseName.m4a';

    String command;
    if (codec == 'alac') {
      // ALAC - lossless
      command =
          '-i "$inputPath" -codec:a alac -map 0:a -map_metadata 0 "$outputPath" -y';
    } else {
      // AAC - lossy
      command =
          '-i "$inputPath" -codec:a aac -b:a $bitrate -map 0:a -map_metadata 0 "$outputPath" -y';
    }

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return outputPath;
    }

    return null;
  }

  /// Check if FFmpeg is available
  static Future<bool> isAvailable() async {
    try {
      final session = await FFmpegKit.execute('-version');
      final returnCode = await session.getReturnCode();
      return ReturnCode.isSuccess(returnCode);
    } catch (e) {
      return false;
    }
  }

  /// Get FFmpeg version info
  static Future<String?> getVersion() async {
    try {
      final session = await FFmpegKit.execute('-version');
      final output = await session.getOutput();
      return output;
    } catch (e) {
      return null;
    }
  }
}
