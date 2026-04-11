import 'package:permission_handler/permission_handler.dart';
import 'txa_language.dart';

class TxaPermission {
  // Define permissions used for general UI display
  static List<Map<String, dynamic>> get permissions => [
    {
      'id': 'notifications',
      'label': TxaLanguage.t('permission_notif_label'),
      'desc': TxaLanguage.t('permission_notif_desc'),
      'permission': Permission.notification,
    },
    {
      'id': 'storage',
      'label': TxaLanguage.t('permission_storage_label'),
      'desc': TxaLanguage.t('permission_storage_desc'),
      'permission': Permission.manageExternalStorage,
    },
  ];

  static Future<bool> checkAllRequired() async {
    // We only require "Manage All Files" to function for core features (logs, updates, downloads)
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

    // 2. Storage Management (Might open settings if API >= 30, otherwise dialog)
    // On Android 11+ this opens the "Manage All Files" screen correctly.
    // For earlier versions, it acts as a storage request.
    await Permission.manageExternalStorage.request();
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
