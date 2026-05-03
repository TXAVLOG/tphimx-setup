import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:optimize_battery/optimize_battery.dart';
import 'txa_language.dart';

class TxaPermission {
  // Mandatory permissions for the app to function
  static List<Map<String, dynamic>> get mandatoryPermissions {
    final List<Map<String, dynamic>> perms = [];
    if (Platform.isAndroid) {
      perms.add({
        'id': 'storage',
        'label': TxaLanguage.t('permission_storage_label'),
        'desc': TxaLanguage.t('permission_storage_desc'),
        'permission': Permission.manageExternalStorage,
      });
      perms.add({
        'id': 'install_packages',
        'label': TxaLanguage.t('permission_install_label'),
        'desc': TxaLanguage.t('permission_install_desc'),
        'permission': Permission.requestInstallPackages,
      });
    }
    return perms;
  }

  // Optional permissions that enhance the experience
  static List<Map<String, dynamic>> get optionalPermissions {
    final List<Map<String, dynamic>> perms = [
      {
        'id': 'notifications',
        'label': TxaLanguage.t('permission_notif_label'),
        'desc': TxaLanguage.t('permission_notif_desc'),
        'permission': Permission.notification,
      },
    ];
    if (Platform.isAndroid) {
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
      perms.add({
        'id': 'location',
        'label': TxaLanguage.t('permission_location_label'),
        'desc': TxaLanguage.t('permission_location_desc'),
        'permission': Permission.location,
      });
      perms.add({
        'id': 'nearby',
        'label': TxaLanguage.t('permission_nearby_label'),
        'desc': TxaLanguage.t('permission_nearby_desc'),
        'permission': Permission.nearbyWifiDevices,
      });
    }
    return perms;
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    return await OptimizeBattery.isIgnoringBatteryOptimizations();
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    if (Platform.isAndroid) {
      await OptimizeBattery.stopOptimizingBatteryUsage();
    }
  }

  static Future<bool> checkAllMandatory() async {
    if (!Platform.isAndroid) return true;
    for (var p in mandatoryPermissions) {
      try {
        final status = await (p['permission'] as Permission).status.timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => PermissionStatus.denied,
        );
        if (!status.isGranted) return false;
      } catch (e) {
        return false;
      }
    }
    return true;
  }

  static Future<bool> checkAllRequired() async {
    return await checkAllMandatory();
  }

  static Future<void> requestInitial() async {
    if (!Platform.isAndroid) return;
    final List<Permission> toRequest = [];
    for (var p in mandatoryPermissions) {
      toRequest.add(p['permission'] as Permission);
    }
    await toRequest.request();
  }

  static Future<bool> requestInstall() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.requestInstallPackages.request();
    return status.isGranted;
  }

  static List<Map<String, dynamic>> get permissions => [...mandatoryPermissions, ...optionalPermissions];

  static Future<Map<String, PermissionStatus>> getAllStatus() async {
    Map<String, PermissionStatus> statuses = {};
    final all = permissions;
    for (var p in all) {
      try {
        if (p['id'] == 'battery') {
          final isIgnored = await isIgnoringBatteryOptimizations();
          statuses[p['id']] = isIgnored ? PermissionStatus.granted : PermissionStatus.denied;
        } else {
          statuses[p['id']] = await (p['permission'] as Permission).status.timeout(
            const Duration(milliseconds: 500),
            onTimeout: () => PermissionStatus.denied,
          );
        }
      } catch (e) {
        statuses[p['id']] = PermissionStatus.denied;
      }
    }
    return statuses;
  }

  // Request Nearby Devices only when needed
  static Future<bool> requestNearby() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.nearbyWifiDevices.request();
    return status.isGranted;
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
