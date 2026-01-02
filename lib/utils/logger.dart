import 'package:logger/logger.dart';

/// Global logger instance for the app
/// Uses pretty printer in debug mode for readable output
final log = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.none,
  ),
  level: Level.debug,
);

/// Logger with class/tag prefix for better traceability
class AppLogger {
  final String _tag;
  
  AppLogger(this._tag);
  
  void d(String message) => log.d('[$_tag] $message');
  void i(String message) => log.i('[$_tag] $message');
  void w(String message) => log.w('[$_tag] $message');
  void e(String message, [Object? error, StackTrace? stackTrace]) => 
      log.e('[$_tag] $message', error: error, stackTrace: stackTrace);
}
