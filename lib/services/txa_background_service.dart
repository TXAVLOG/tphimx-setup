import 'package:workmanager/workmanager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/txa_api.dart';
import '../utils/txa_logger.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Check for update
      final api = TxaApi(); // Ensure this can be instantiated without BuildContext if possible, 
      // or use a direct http call if TxaApi requires context.
      // Assuming TxaApi uses a singleton or can be used directly for simple calls.
      
      final updateData = await api.getCheckUpdate();
      final Map<String, dynamic>? appData = updateData['data'];
      final String latestVersion = appData?['latest_version'] ?? '';
      
      final packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;
      
      if (latestVersion.isNotEmpty && _isNewer(latestVersion, currentVersion)) {
        // Show update notification
        // Note: We need a static way to show notification from background
        TxaLogger.log('[Background] Update found: $latestVersion');
        // Implementation for background notification
      }
      
      return Future.value(true);
    } catch (e) {
      TxaLogger.log('[Background] Task error: $e', isError: true);
      return Future.value(false);
    }
  });
}

bool _isNewer(String latest, String current) {
  List<int> latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
    if (latestParts[i] > currentParts[i]) return true;
    if (latestParts[i] < currentParts[i]) return false;
  }
  return latestParts.length > currentParts.length;
}

class TxaBackgroundService {
  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  static Future<void> registerUpdateTask() async {
    await Workmanager().registerPeriodicTask(
      "txa-update-check",
      "checkUpdateTask",
      frequency: const Duration(minutes: 15), // Android minimum is 15 mins for periodic
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}
