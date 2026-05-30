import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import '../services/txa_settings.dart';

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
      log(
        'FLUTTER ERROR: ${details.exceptionAsString()}\n${details.stack}',
        isError: true,
        tag: 'CRASH',
        type: 'error',
      );
    };

    // 2. Catch Platform Errors (Asynchronous)
    PlatformDispatcher.instance.onError = (error, stack) {
      log(
        'PLATFORM ERROR: $error\n$stack',
        isError: true,
        tag: 'CRASH',
        type: 'error',
      );
      return true;
    };

    log(
      '================================================================',
      tag: 'SESSION',
    );
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

      // Auto-submit error logs to server
      if (isError) {
        submitErrorLog(type: type, message: message, tag: tag);
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

  static Future<String> getActiveLogPath() async {
    return await _logPath;
  }

  // Get device information
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    Map<String, dynamic> info = {
      'platform': Platform.isIOS ? 'iOS' : 'Android',
      'udid': TxaSettings.udid,
    };

    try {
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        info['device_name'] = iosInfo.name;
        info['device_model'] = iosInfo.model;
        info['system_version'] = iosInfo.systemVersion;
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        info['device_name'] = androidInfo.brand;
        info['device_model'] = androidInfo.model;
        info['system_version'] = androidInfo.version.release;
      }
    } catch (e) {
      debugPrint('Failed to get device info: $e');
    }

    return info;
  }

  // Get IP and location info
  static Future<Map<String, dynamic>> getIpLocation() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://ipapi.co/json/',
        options: Options(connectTimeout: const Duration(seconds: 5)),
      );
      if (response.data != null) {
        return {
          'ip': response.data['ip'] ?? 'unknown',
          'city': response.data['city'] ?? 'unknown',
          'region': response.data['region'] ?? 'unknown',
          'country': response.data['country_name'] ?? 'unknown',
          'latitude': response.data['latitude']?.toString() ?? 'unknown',
          'longitude': response.data['longitude']?.toString() ?? 'unknown',
        };
      }
    } catch (e) {
      debugPrint('Failed to get IP/location: $e');
    }
    return {
      'ip': 'unknown',
      'city': 'unknown',
      'region': 'unknown',
      'country': 'unknown',
      'latitude': 'unknown',
      'longitude': 'unknown',
    };
  }

  // Submit error log to server
  static Future<void> submitErrorLog({
    required String type,
    required String message,
    String? tag,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final deviceInfo = await getDeviceInfo();
      final locationInfo = await getIpLocation();

      final dio = Dio();
      await dio.post(
        'https://dongmephim.online/api/app/client-error',
        data: {
          'type': type,
          'message': message,
          'tag': tag,
          'extra': {
            ...?extra,
            'device_info': deviceInfo,
            'location_info': locationInfo,
          },
          'device_info': 'TPhimX-App-V4.4.0',
          'timestamp': DateTime.now().toIso8601String(),
        },
        options: Options(
          headers: {
            'X-TXA-API-KEY': 'tphimx-mobile-2026-secure',
            'X-TXC-Client': 'TPhimX-App',
            'X-TXC-Platform': Platform.isIOS ? 'iOS' : 'Android',
            'X-TXA-UDID': TxaSettings.udid,
          },
          connectTimeout: const Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Failed to submit error log: $e');
    }
  }
}
