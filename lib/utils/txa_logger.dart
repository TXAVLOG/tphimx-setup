import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class TxaLogger {
  static String? _cachedLogPath;

  static Future<String>? _logPathFuture;

  static Future<String> get _logPath async {
    // If permission was granted later, we should clear cache to re-check
    // But for performance, we only re-check if we are currently in fallback mode
    if (_cachedLogPath != null && !_cachedLogPath!.contains('TPHIMX')) {
      _cachedLogPath = null;
      _logPathFuture = null;
    }

    _logPathFuture ??= _calculateLogPath();
    return _logPathFuture!;
  }

  static Future<String> _calculateLogPath() async {
    if (_cachedLogPath != null) return _cachedLogPath!;

    // Default sandbox path
    final docDir = await getApplicationDocumentsDirectory();
    final sandboxPath = '${docDir.path}/Logs';

    if (Platform.isAndroid) {
      try {
        // Check permission with a strict timeout to prevent hangs
        final status = await Permission.manageExternalStorage.status.timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => PermissionStatus.denied,
        );

        if (status.isGranted) {
          final premiumDir = Directory('/storage/emulated/0/TPHIMX/Logs');
          if (!await premiumDir.exists()) {
            await premiumDir.create(recursive: true);
          }
          _cachedLogPath = premiumDir.path;
          return _cachedLogPath!;
        }
      } catch (e) {
        debugPrint('Logger premium path check failed: $e');
      }
    }

    // Fallback to sandbox
    final logDir = Directory(sandboxPath);
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    _cachedLogPath = logDir.path;
    return _cachedLogPath!;
  }

  static void init() {
    // 1. Catch Flutter Framework Errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      log('FLUTTER ERROR: ${details.exceptionAsString()}\n${details.stack}', 
          isError: true, tag: 'CRASH', type: 'error');
    };

    // 2. Catch Platform Errors (Asynchronous)
    PlatformDispatcher.instance.onError = (error, stack) {
      log('PLATFORM ERROR: $error\n$stack', 
          isError: true, tag: 'CRASH', type: 'error');
      return true;
    };

    log('================================================================', tag: 'SESSION');
    log('TxaLogger initialized. Global error tracking active.', tag: 'LOGGER');
  }

  static Future<void> log(
    String message, {
    bool isError = false,
    String? tag,
    String type = 'app',
  }) async {
    try {
      final path = await _logPath;
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final file = File('$path/${type}_$date.log');

      // Auto-clean if file > 5MB
      if (await file.exists() && await file.length() > 5 * 1024 * 1024) {
        await file.delete();
      }

      final now = DateTime.now();
      final timestamp = DateFormat('HH:mm:ss.SSS').format(now);
      final level = isError ? 'ERROR' : 'INFO ';
      final tagStr = tag != null ? '[$tag] ' : '';

      // Build a premium formatted log line with clearer separation
      final logLine = '[$timestamp] [$level] $tagStr$message\n';

      await file.writeAsString(logLine, mode: FileMode.append, flush: true);

      // Also print to console for development with colors/tags
      final consolePrefix = isError
          ? '❌ [$timestamp] [TPHIMX-$type]'
          : 'ℹ️ [$timestamp] [TPHIMX-$type]';
      debugPrint('$consolePrefix $tagStr$message');
    } catch (e) {
      if (kDebugMode) debugPrint('CRITICAL: Failed to write to log file: $e');
    }
  }

  static Future<void> logApi({
    required String method,
    required String path,
    int? statusCode,
    dynamic body,
    dynamic response,
    Duration? duration,
  }) async {
    final isError = statusCode == null || statusCode >= 400;
    final buffer = StringBuffer();
    buffer.writeln('─── API ${method.toUpperCase()} ──────────────────────');
    buffer.writeln('URL: $path');
    if (statusCode != null) buffer.writeln('STATUS: $statusCode');
    if (duration != null) buffer.writeln('TIME: ${duration.inMilliseconds}ms');

    if (body != null) {
      buffer.writeln('REQUEST BODY: $body');
    }

    if (response != null) {
      buffer.writeln('RESPONSE: $response');
    }
    buffer.writeln('──────────────────────────────────────────────');

    await log(buffer.toString(), isError: isError, tag: 'API', type: 'api');
  }
}
