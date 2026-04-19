import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class TxaLogger {
  static Future<String> get _logPath async {
    // manageExternalStorage is Android-only; on other platforms (iOS) we always use the sandbox
    bool isAndroid11Plus = false;
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.status;
      if (status.isGranted) {
        isAndroid11Plus = true;
      }
    }

    if (isAndroid11Plus) {
      // Premium path for granted "All Files" permission (Android Only)
      final dir = Directory('/storage/emulated/0/TPHIMX/Logs');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    } else {
      // Default sandbox path (iOS and non-authorized Android)
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/Logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      return logDir.path;
    }
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

      // Build a premium formatted log line
      final logLine = '[$timestamp] [$level] $tagStr$message\n';

      await file.writeAsString(logLine, mode: FileMode.append, flush: true);

      // Also print to console for development with colors/tags
      if (kDebugMode) {
        final consolePrefix = isError
            ? '❌ [TPHIMX-$type]'
            : 'ℹ️ [TPHIMX-$type]';
        debugPrint('$consolePrefix $tagStr$message');
      }
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
