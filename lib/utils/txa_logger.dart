import 'dart:io';
import 'dart:convert';
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

  static String _normalizeMessage(String msg) {
    // Remove timestamps like [12:34:56.789] or [2026-05-31 ...]
    String cleaned = msg.replaceAll(RegExp(r'\[\d{2,4}[-\d:]*[\s\d:.]*\]'), '');
    // Remove hex codes / memory addresses (e.g. 0x7f3a8b)
    cleaned = cleaned.replaceAll(RegExp(r'0x[a-fA-F0-9]+'), '');
    // Remove digits to prevent matching different IDs of same error
    cleaned = cleaned.replaceAll(RegExp(r'\d+'), '');
    // Convert to lowercase, remove extra spaces and trim
    return cleaned.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static Future<void> log(
    String message, {
    bool isError = false,
    String? tag,
    String type = 'app',
  }) async {
    try {
      final path = await _logPath;
      final now = DateTime.now();
      final timestamp = DateFormat('HH:mm:ss.SSS').format(now);
      final level = isError ? 'ERROR' : 'INFO ';
      final tagStr = tag != null ? '[$tag] ' : '';
      final logLine = '[$timestamp] [$level] $tagStr$message\n';

      // 1. ALWAYS write all logs to dynamic daily files so they appear on the app's logs viewer screen!
      final date = DateFormat('yyyy-MM-dd').format(now);
      final dailyFile = File('$path/${type}_$date.log');

      if (await dailyFile.exists() &&
          await dailyFile.length() > 1 * 1024 * 1024) {
        await dailyFile.delete();
      }
      await dailyFile.writeAsString(
        logLine,
        mode: FileMode.append,
        flush: true,
      );

      // 2. ERROR LOGS: Also save in permanent errors.log and upload to Supabase, avoiding duplicate types
      if (isError || type == 'error') {
        final errorFile = File('$path/errors.log');
        bool isDuplicate = false;

        if (await errorFile.exists()) {
          final content = await errorFile.readAsString();
          final normalizedNew = _normalizeMessage(message);
          final lines = content.split('\n');
          for (var line in lines) {
            if (line.isEmpty) continue;
            final normalizedLine = _normalizeMessage(line);
            if (normalizedLine == normalizedNew ||
                (normalizedNew.length > 8 &&
                    normalizedLine.contains(normalizedNew))) {
              isDuplicate = true;
              break;
            }
          }
        }

        if (!isDuplicate) {
          await errorFile.writeAsString(
            logLine,
            mode: FileMode.append,
            flush: true,
          );
          // Auto-submit unique error logs directly to Supabase
          submitErrorLog(type: type, message: message, tag: tag);
        }
      }

      // Print to console with developer colors/tags
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

  // Submit error log directly to Supabase logs table
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
      final detailsMap = {
        'type': type,
        'tag': tag,
        'extra': extra,
        'device_info': deviceInfo,
        'location_info': locationInfo,
        'app_version': 'TPhimX-App-V4.5.0',
        'timestamp': DateTime.now().toIso8601String(),
      };

      await dio.post(
        'https://jjmzipyewddbepnelawf.supabase.co/rest/v1/logs',
        data: {
          'action': 'client_error',
          'level': 'error',
          'message': message,
          'details': jsonEncode(detailsMap),
        },
        options: Options(
          headers: {
            'apikey': 'sb_publishable_p45xwwJNPMFAzp9K8YQlkA_2oc87I1u',
            'Authorization':
                'Bearer sb_publishable_p45xwwJNPMFAzp9K8YQlkA_2oc87I1u',
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          connectTimeout: const Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Failed to submit error log to Supabase: $e');
    }
  }
}
