import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'txa_language.dart';

class TxaPermission {
  // Define permissions used for general UI display
  static List<Map<String, dynamic>> get permissions {
    final List<Map<String, dynamic>> perms = [
      {
        'id': 'notifications',
        'label': TxaLanguage.t('permission_notif_label'),
        'desc': TxaLanguage.t('permission_notif_desc'),
        'permission': Permission.notification,
      },
    ];
    // manageExternalStorage is Android-only — crashes on iOS
    if (Platform.isAndroid) {
      perms.add({
        'id': 'storage',
        'label': TxaLanguage.t('permission_storage_label'),
        'desc': TxaLanguage.t('permission_storage_desc'),
        'permission': Permission.manageExternalStorage,
      });
      perms.add({
        'id': 'overlay',
        'label': TxaLanguage.t('permission_overlay_label'),
        'desc': TxaLanguage.t('permission_overlay_desc'),
        'permission': Permission.systemAlertWindow,
      });
      perms.add({
        'id': 'dnd',
        'label': TxaLanguage.t('permission_dnd_label'),
        'desc': TxaLanguage.t('permission_dnd_desc'),
        'permission': Permission.accessNotificationPolicy,
      });
      perms.add({
        'id': 'exact_alarm',
        'label': TxaLanguage.t('permission_alarm_label'),
        'desc': TxaLanguage.t('permission_alarm_desc'),
        'permission': Permission.scheduleExactAlarm,
      });
      perms.add({
        'id': 'battery',
        'label': TxaLanguage.t('battery_optimization'),
        'desc': TxaLanguage.t('ignore_battery_msg'),
        'permission': Permission.ignoreBatteryOptimizations,
      });
    }
    return perms;
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    return await Permission.ignoreBatteryOptimizations.isGranted;
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    if (Platform.isAndroid) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  static Future<bool> checkAllRequired() async {
    // Storage permission is Android-only; on iOS we skip this check
    if (!Platform.isAndroid) return true;
    final statuses = await getAllStatus();
    final storageStatus = statuses['storage'] ?? PermissionStatus.denied;
    return storageStatus.isGranted;
  }

  static Future<Map<String, PermissionStatus>> getAllStatus() async {
    Map<String, PermissionStatus> statuses = {};
    for (var p in permissions) {
      statuses[p['id']] = await (p['permission'] as Permission).status;
    }
    return statuses;
  }

  static Future<void> requestInitial() async {
    // 1. Notification (Simple dialog/box)
    await Permission.notification.request();

    // 2. Storage Management (Android Only)
    if (Platform.isAndroid) {
      // On Android 11+ this opens the "Manage All Files" screen correctly.
      // For earlier versions, it acts as a storage request.
      await Permission.manageExternalStorage.request();

      // 3. Do Not Disturb Access
      await Permission.accessNotificationPolicy.request();
    }
  }

  // Request all (Legacy compatibility for SplashScreen)
  static Future<void> requestAll() async => requestInitial();

  // Install Permission - EXPLICITLY triggered ONLY during update to avoid unknown source setting at startup
  static Future<bool> requestInstall() async {
    final status = await Permission.requestInstallPackages.request();
    return status.isGranted;
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
