import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speed_checker_plugin/speed_checker_plugin.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/txa_logger.dart';
import '../services/txa_settings.dart';
import '../services/txa_language.dart';
import '../services/txa_api.dart';

class TxaSpeedService {
  static const MethodChannel _channel = MethodChannel(
    'com.tphimx/speed_service',
  );
  static final _speedChecker = SpeedCheckerPlugin();

  static double _currentDownload = 0;
  static double _currentUpload = 0;
  static String _currentNetworkType = 'Unknown';
  static bool _isTesting = false;

  static double get currentDownload => _currentDownload;
  static double get currentUpload => _currentUpload;
  static String get currentNetworkType => _currentNetworkType;
  static bool get isTesting => _isTesting;

  static Future<void> init() async {
    await updateNetworkType();

    if (TxaSettings.showSpeedInNotification) {
      await startService();
    }

    TxaSettings().addListener(() {
      if (TxaSettings.showSpeedInNotification) {
        startService();
      } else {
        stopService();
      }
    });

    // Lắng nghe thay đổi ngôn ngữ
    TxaLanguage().addListener(() {
      if (TxaSettings.showSpeedInNotification) {
        startService(); // Cập nhật ngôn ngữ cho notification
      }
    });
  }

  static Future<void> updateNetworkType() async {
    final result = await Connectivity().checkConnectivity();
    if (result.contains(ConnectivityResult.wifi)) {
      _currentNetworkType = TxaLanguage.t('network_wifi');
    } else if (result.contains(ConnectivityResult.mobile)) {
      _currentNetworkType = TxaLanguage.t('network_mobile');
    } else if (result.contains(ConnectivityResult.ethernet)) {
      _currentNetworkType = TxaLanguage.t('network_ethernet');
    } else {
      _currentNetworkType = TxaLanguage.t('network_error');
    }
  }

  /// Kiểm tra độ trễ (Ping) đến API Server
  static Future<int> checkApiLatency() async {
    final stopwatch = Stopwatch()..start();
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse(TxaApi.baseUrl));
      final response = await request.close();
      stopwatch.stop();
      client.close();
      return response.statusCode == 200 ? stopwatch.elapsedMilliseconds : -1;
    } catch (e) {
      TxaLogger.log('Ping API Error: $e');
      return -1;
    }
  }

  static Future<bool> checkSpeed({
    Function(double down, double up, double progress)? onProgress,
  }) async {
    if (_isTesting) return false;

    if (Platform.isAndroid) {
      final status = await Permission.location.status;
      if (status.isDenied || status.isRestricted) {
        final result = await Permission.location.request();
        if (!result.isGranted) return false;
      } else if (status.isPermanentlyDenied) {
        return false;
      }
    }

    _isTesting = true;

    await updateNetworkType();
    _currentDownload = 0;
    _currentUpload = 0;

    final completer = Completer<bool>();
    StreamSubscription? subscription;

    try {
      subscription = _speedChecker.speedTestResultStream.listen(
        (result) {
          final dynamic res = result;
          double progress = 0;
          try {
            if (res is Map) {
              _currentDownload = (res['downloadSpeed'] as num?)?.toDouble() ?? 0;
              _currentUpload = (res['uploadSpeed'] as num?)?.toDouble() ?? 0;
              progress = (res['progress'] as num?)?.toDouble() ?? 0;
            } else {
              _currentDownload = (res.downloadSpeed as num?)?.toDouble() ?? 0;
              _currentUpload = (res.uploadSpeed as num?)?.toDouble() ?? 0;
              // Some versions might not have progress field, we estimate
              progress = (_currentDownload > 0 ? 0.5 : 0) + (_currentUpload > 0 ? 0.5 : 0);
            }
          } catch (e) {
            TxaLogger.log('Error parsing speed result: $e');
          }

          if (onProgress != null) onProgress(_currentDownload, _currentUpload, progress);
        },
        onError: (e) {
          TxaLogger.log('Speed test stream error: $e');
          if (!completer.isCompleted) completer.complete(false);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(true);
        },
      );

      _speedChecker.startSpeedTest();

      // Wait until completer finishes or timeout (60s)
      final result = await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          TxaLogger.log('Speed test timed out, falling back to download test');
          return false;
        },
      );

      if (!result) {
        // Fallback to manual download test
        return await _checkSpeedByDownload(onProgress: onProgress);
      }
      return true;
    } catch (e) {
      TxaLogger.log('Speed test error: $e');
      // Final attempt fallback on any exception
      try {
        return await _checkSpeedByDownload(onProgress: onProgress);
      } catch (_) {
        return false;
      }
    } finally {
      subscription?.cancel();
      _isTesting = false;
    }
  }

  static Future<bool> _checkSpeedByDownload({
    Function(double down, double up, double progress)? onProgress,
  }) async {
    TxaLogger.log('Starting fallback download speed test...');
    final client = HttpClient();
    final stopwatch = Stopwatch()..start();
    int downloadedBytes = 0;
    const totalBytes = 10485760; // 10MB
    
    try {
      final request = await client.getUrl(Uri.parse('https://speed.cloudflare.com/__down?bytes=$totalBytes'));
      final response = await request.close();
      
      await response.listen((chunk) {
        downloadedBytes += chunk.length;
        final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
        if (elapsedSec > 0) {
          _currentDownload = (downloadedBytes * 8 / (1024 * 1024)) / elapsedSec; // Mbps
          double progress = downloadedBytes / totalBytes;
          if (onProgress != null) onProgress(_currentDownload, 0, progress);
        }
      }).asFuture();
      
      stopwatch.stop();
      return true;
    } catch (e) {
      TxaLogger.log('Fallback speed test error: $e');
      return false;
    } finally {
      client.close();
    }
  }

  /// Bắt đầu service với đầy đủ đa ngôn ngữ từ TxaLanguage
  static Future<void> startService() async {
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      // Chuẩn bị các chuỗi dịch
      final translations = {
        'speedUnit': TxaSettings.speedUnit,
        'txtTitle': TxaLanguage.t('network_speed'),
        'txtInit': TxaLanguage.t('loading_progress'),
        'txtNetwork': TxaLanguage.t('network'),
        'txtOffline': TxaLanguage.t('network_error'),
        'txtWiFi': TxaLanguage.t('network_wifi'),
        'txtMobile': TxaLanguage.t('network_mobile'),
        'txtEthernet': TxaLanguage.t('network_ethernet'),
        'txtUnknown': TxaLanguage.t('error_unknown'),
        'txtUsage': TxaLanguage.t('network_usage'),
        'txtTotal': TxaLanguage.t('total'),
        'fontWeight': 900,
      };

      final bool? result = await _channel.invokeMethod(
        'startSpeedService',
        translations,
      );
      TxaLogger.log('Native Speed Service started with translations: $result');
    } on PlatformException catch (e) {
      TxaLogger.log('Failed to start native speed service: ${e.message}');
    }
  }

  static Future<void> stopService() async {
    try {
      final bool? result = await _channel.invokeMethod('stopSpeedService');
      TxaLogger.log('Native Speed Service stopped: $result');
    } on PlatformException catch (e) {
      TxaLogger.log('Failed to stop native speed service: ${e.message}');
    }
  }

  static Future<void> toggleSpeedNotification(bool enable) async {
    if (enable) {
      await startService();
    } else {
      await stopService();
    }
  }
}
