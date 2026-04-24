import 'dart:async';
import 'package:speed_checker_plugin/speed_checker_plugin.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/txa_logger.dart';
import '../services/txa_settings.dart';
import '../services/txa_language.dart';

import '../utils/txa_format.dart';

class TxaSpeedService {
  static final _speedChecker = SpeedCheckerPlugin();
  static final _notifications = FlutterLocalNotificationsPlugin();
  
  static double _currentDownload = 0;
  static double _currentUpload = 0;
  static String _currentNetworkType = 'Unknown';
  static bool _isTesting = false;

  static double get currentDownload => _currentDownload;
  static double get currentUpload => _currentUpload;
  static String get currentNetworkType => _currentNetworkType;
  static bool get isTesting => _isTesting;

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwinSettings = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );
    // Corrected for flutter_local_notifications v21+
    await _notifications.initialize(settings: initializationSettings); 
    
    await updateNetworkType();
    _updateSpeedNotification();
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

  static Future<void> checkSpeed({Function(double down, double up)? onProgress}) async {
    if (_isTesting) return;
    _isTesting = true;
    
    await updateNetworkType();
    
    _currentDownload = 0;
    _currentUpload = 0;
    
    try {
      _speedChecker.startSpeedTest();
      
      // We'll use a periodic timer to simulate/poll if the plugin doesn't provide a direct stream
      // or if we're still debugging the exact API. This ensures the fields are NOT final.
      Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (!_isTesting) {
          timer.cancel();
          return;
        }
        // In a real scenario, the plugin would update these via callbacks.
        // For now, we ensure they are mutable.
        if (onProgress != null) onProgress(_currentDownload, _currentUpload);
      });
      
      // Delay to simulate test duration if plugin call is async
      await Future.delayed(const Duration(seconds: 5));
    } catch (e) {
      TxaLogger.log('Speed test error: $e');
    } finally {
      _isTesting = false;
    }
  }

  static Timer? _notificationTimer;
  static void toggleSpeedNotification(bool enable) {
    _notificationTimer?.cancel();
    if (enable) {
      _notificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        if (!_isTesting) {
          _updateSpeedNotification();
        }
      });
    }
  }

  static void _updateSpeedNotification() async {
    if (!TxaSettings.showSpeedInNotification) {
      await _notifications.cancel(id: 888); // Use fixed ID for speed notification
      return;
    }

    // Format speed text
    // Note: _currentDownload and _currentUpload are in Mbps based on UI usage
    String speedText = "Down: ${TxaFormat.formatNetworkSpeed(_currentDownload * 1000000, useGbps: TxaSettings.speedUnitGbps)} | Up: ${TxaFormat.formatNetworkSpeed(_currentUpload * 1000000, useGbps: TxaSettings.speedUnitGbps)}";
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'speed_channel',
      'Network Speed',
      channelDescription: 'Shows current network speed',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      onlyAlertOnce: true,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
    );
    
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    
    await _notifications.show(
      id: 888,
      title: 'TPhimX Speed Monitor',
      body: speedText,
      notificationDetails: platformDetails,
    );
  }
}
