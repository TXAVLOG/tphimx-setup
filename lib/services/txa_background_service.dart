import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/txa_api.dart';
import '../services/txa_settings.dart';
import '../services/txa_language.dart';
import '../utils/txa_logger.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // 1. Initialize dependencies
      await TxaSettings.init();
      await TxaLanguage.init();
      final api = TxaApi();
      final prefs = await SharedPreferences.getInstance();
      
      final notificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await notificationsPlugin.initialize(settings: initSettings);

      // 2. Check for App Updates
      final updateData = await api.getCheckUpdate();
      final Map<String, dynamic>? appData = updateData['data'];
      final String latestVersion = appData?['latest_version'] ?? '';
      
      final packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;
      
      if (latestVersion.isNotEmpty && _isNewer(latestVersion, currentVersion)) {
        await _showNotification(
          notificationsPlugin,
          999,
          TxaLanguage.t('update_available'),
          '${TxaLanguage.t('version_label', replace: {'version': latestVersion})}. ${TxaLanguage.t('update_now')}!',
        );
      }

      // 3. Check for New Episode Notifications (Favorites)
      if (TxaSettings.authToken.isNotEmpty) {
        try {
          final notifData = await api.getNotifications();
          final List<dynamic> notifs = notifData['data'] ?? [];
          final String lastNotifId = prefs.getString('last_bg_notif_id') ?? '';
          
          if (notifs.isNotEmpty) {
            // Process up to 5 newest unread notifications
            int count = 0;
            String? latestId;
            
            for (var notif in notifs) {
              final String currentId = notif['id']?.toString() ?? '';
              if (currentId == lastNotifId) break; // Reached old notifications
              if (notif['is_read'] == true) continue;
              
              latestId ??= currentId;
              
              final String slug = notif['movie_slug'] ?? '';
              
              await _showNotification(
                notificationsPlugin,
                100 + count,
                TxaLanguage.t(
                  'bg_new_episode_title_simple',
                  replace: {'n': notif['movie_name'] ?? ''},
                ),
                notif['message'] ?? '',
                payload: slug.isNotEmpty ? 'movie_detail:$slug' : null,
                groupKey: 'txa_episodes_group',
              );
              
              count++;
              if (count >= 5) break; 
            }
            
            if (latestId != null) {
              await prefs.setString('last_bg_notif_id', latestId);
              
              // If multiple notifications, show a summary (Android only)
              if (count > 1) {
                await _showSummaryNotification(notificationsPlugin, 'txa_episodes_group');
              }
            }
          }
        } catch (e) {
          TxaLogger.log('[Background] Notif check error: $e');
        }
      }

      // 4. Check for Broadcast Schedule
      try {
        final scheduleData = await api.getSchedule();
        final List<dynamic> days = scheduleData['data'] ?? [];
        if (days.isNotEmpty) {
          final todayMovies = days.first['movies'] as List<dynamic>? ?? [];
          final now = DateTime.now();
          
          for (var movie in todayMovies) {
            final String? broadcastAtStr = movie['broadcast_at'];
            if (broadcastAtStr != null) {
              final broadcastAt = DateTime.parse(broadcastAtStr);
              final diff = broadcastAt.difference(now).inMinutes;
              
              // If movie starts in 5-20 minutes, notify
              if (diff > 5 && diff < 20) {
                final String movieKey = 'sched_notif_${movie['id']}_${broadcastAt.day}';
                if (prefs.getBool(movieKey) != true) {
                  await _showNotification(
                    notificationsPlugin,
                    200 + (movie['id'] as int),
                    TxaLanguage.t(
                      'broadcast_reminder_title',
                      replace: {'name': movie['name'] ?? ''},
                    ),
                    TxaLanguage.t(
                      'broadcast_reminder_body',
                      replace: {
                        'movie': movie['name'] ?? '',
                        'minutes': diff.toString(),
                      },
                    ),
                  );
                  await prefs.setBool(movieKey, true);
                }
              }
            }
          }
        }
      } catch (e) {
        TxaLogger.log('[Background] Schedule check error: $e');
      }
      
      return Future.value(true);
    } catch (e) {
      TxaLogger.log('[Background] Task error: $e', isError: true);
      return Future.value(false);
    }
  });
}

Future<void> _showNotification(
  FlutterLocalNotificationsPlugin plugin,
  int id,
  String title,
  String body, {
  String? payload,
  String? groupKey,
}) async {
  final List<AndroidNotificationAction> actions = [];
  if (payload != null && payload.startsWith('movie_detail:')) {
    actions.add(
      AndroidNotificationAction(
        'view_detail',
        TxaLanguage.t('view_movie_detail'),
        showsUserInterface: true,
      ),
    );
  }

  final androidDetails = AndroidNotificationDetails(
    'txa_background_channel',
    'TPhimX Background Service',
    channelDescription: 'System notifications for updates and schedules',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    groupKey: groupKey,
    setAsGroupSummary: false,
    actions: actions,
  );
  
  final details = NotificationDetails(
    android: androidDetails,
    iOS: const DarwinNotificationDetails(),
  );
  
  await plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: details,
    payload: payload,
  );
}

Future<void> _showSummaryNotification(
  FlutterLocalNotificationsPlugin plugin,
  String groupKey,
) async {
  final androidDetails = AndroidNotificationDetails(
    'txa_background_channel',
    'TPhimX Background Service',
    channelDescription: 'System notifications for updates and schedules',
    importance: Importance.high,
    priority: Priority.high,
    groupKey: groupKey,
    setAsGroupSummary: true,
    styleInformation: const InboxStyleInformation([], contentTitle: 'TPhimX', summaryText: 'Nhiều cập nhật mới'),
  );
  
  final details = NotificationDetails(android: androidDetails);
  await plugin.show(
    id: groupKey.hashCode,
    title: null,
    body: null,
    notificationDetails: details,
  );
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
    );
  }

  static Future<void> registerUpdateTask() async {
    // We can use a single periodic task to check everything
    await Workmanager().registerPeriodicTask(
      "txa-background-sync",
      "backgroundSyncTask",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }
}
