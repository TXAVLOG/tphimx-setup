import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speed_checker_plugin/speed_checker_plugin.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/txa_logger.dart';
import '../services/txa_settings.dart';
import '../services/txa_language.dart';

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

    final oldListener = TxaSettings.onSettingsChanged;
    TxaSettings.onSettingsChanged = () {
      oldListener?.call();
      if (TxaSettings.showSpeedInNotification) {
        startService();
      } else {
        stopService();
      }
    };

    // Lắng nghe thay đổi ngôn ngữ
    final oldLangListener = TxaLanguage.onLanguageChanged;
    TxaLanguage.onLanguageChanged = () {
      oldLangListener?.call();
      if (TxaSettings.showSpeedInNotification) {
        startService(); // Cập nhật ngôn ngữ cho notification
      }
    };
  }

  static Future<void> updateNetworkType() async {
    final result = await Connectivity().checkConnectivity();
    if (result.contains(ConnectivityResult.wifi)) {
      _currentNetworkType = 'WiFi';
    } else if (result.contains(ConnectivityResult.mobile)) {
      _currentNetworkType = 'Mobile';
    } else if (result.contains(ConnectivityResult.ethernet)) {
      _currentNetworkType = 'Ethernet';
    } else {
      _currentNetworkType = TxaLanguage.t('network_error');
    }
  }

  static Future<void> checkSpeed({
    Function(double down, double up)? onProgress,
  }) async {
    if (_isTesting) return;
    _isTesting = true;

    await updateNetworkType();
    _currentDownload = 0;
    _currentUpload = 0;

    StreamSubscription? subscription;

    try {
      subscription = _speedChecker.speedTestResultStream.listen(
        (result) {
          // Use dynamic to access properties safely across different plugin versions
          final res = result as dynamic;
          _currentDownload = (res.download as num?)?.toDouble() ?? 0;
          _currentUpload = (res.upload as num?)?.toDouble() ?? 0;

          if (onProgress != null) onProgress(_currentDownload, _currentUpload);
        },
        onError: (e) {
          TxaLogger.log('Speed test stream error: $e');
        },
        onDone: () {
          _isTesting = false;
        },
      );

      _speedChecker.startSpeedTest();

      // Wait for a reasonable time or until done
      await Future.delayed(const Duration(seconds: 30));
    } catch (e) {
      TxaLogger.log('Speed test error: $e');
    } finally {
      subscription?.cancel();
      _isTesting = false;
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
