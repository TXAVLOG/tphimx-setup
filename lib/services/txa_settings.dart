import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/txa_logger.dart';

class TxaSettings extends ChangeNotifier {
  static final TxaSettings _instance = TxaSettings._internal();
  factory TxaSettings() => _instance;
  TxaSettings._internal();

  static SharedPreferences? _prefs;
  static bool get isInitialized => _prefs != null;

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      TxaLogger.log('TxaSettings: Failed to initialize SharedPreferences: $e', isError: true);
      // Don't rethrow, let the app try to run with defaults
    }
  }

  static void _notify() {
    _instance.notifyListeners();
  }

  // --- Player Settings ---
  static bool get autoSkipIntro =>
      _prefs?.getBool('player_auto_skip_intro') ?? false;
  static set autoSkipIntro(bool v) {
    _prefs?.setBool('player_auto_skip_intro', v);
    _notify();
  }

  static bool get autoNextEpisode =>
      _prefs?.getBool('player_auto_next_episode') ?? true;
  static set autoNextEpisode(bool v) {
    _prefs?.setBool('player_auto_next_episode', v);
    _notify();
  }

  static double get volume => _prefs?.getDouble('player_volume') ?? 1.0;
  static set volume(double v) => _prefs?.setDouble('player_volume', v);

  static double get playbackSpeed =>
      _prefs?.getDouble('player_playback_speed') ?? 1.0;
  static set playbackSpeed(double v) {
    _prefs?.setDouble('player_playback_speed', v);
    _notify();
  }

  static String get quality => _prefs?.getString('player_quality') ?? 'Auto';
  static set quality(String v) {
    _prefs?.setString('player_quality', v);
    _notify();
  }

  static bool get showClock => _prefs?.getBool('player_show_clock') ?? true;
  static set showClock(bool v) {
    _prefs?.setBool('player_show_clock', v);
    _notify();
  }

  static String get clockFormat =>
      _prefs?.getString('player_clock_format') ?? 'HH:mm';
  static set clockFormat(String v) {
    _prefs?.setString('player_clock_format', v);
    _notify();
  }

  static bool get autoDND => _prefs?.getBool('player_auto_dnd') ?? true;
  static set autoDND(bool v) {
    _prefs?.setBool('player_auto_dnd', v);
    _notify();
  }

  static bool get autoPiP => _prefs?.getBool('player_auto_pip') ?? true;
  static set autoPiP(bool v) {
    _prefs?.setBool('player_auto_pip', v);
    _notify();
  }

  static bool get miracastEnabled =>
      _prefs?.getBool('player_miracast_enabled') ?? false;
  static set miracastEnabled(bool v) {
    _prefs?.setBool('player_miracast_enabled', v);
    _notify();
  }

  static bool get autoQualityByNetwork =>
      _prefs?.getBool('app_auto_quality_network') ?? true;
  static set autoQualityByNetwork(bool v) {
    _prefs?.setBool('app_auto_quality_network', v);
    _notify();
  }

  static bool get showSpeedInNotification =>
      _prefs?.getBool('app_show_speed_notif') ?? false;
  static set showSpeedInNotification(bool v) {
    _prefs?.setBool('app_show_speed_notif', v);
    _notify();
  }

  static String get speedUnit => _prefs?.getString('app_speed_unit') ?? 'Auto';
  static set speedUnit(String v) {
    _prefs?.setString('app_speed_unit', v);
    _notify();
  }

  static String get defaultQuality =>
      _prefs?.getString('app_default_quality') ?? '1080p';
  static set defaultQuality(String v) {
    _prefs?.setString('app_default_quality', v);
    _notify();
  }

  static double get brightness => _prefs?.getDouble('player_brightness') ?? 0.5;
  static set brightness(double v) {
    _prefs?.setDouble('player_brightness', v);
    _notify();
  }

  // --- Appearance ---
  static double get fontSizeScale => _prefs?.getDouble('app_font_size') ?? 1.0;
  static set fontSizeScale(double v) {
    _prefs?.setDouble('app_font_size', v);
    _notify();
  }

  static String get fontFamily =>
      _prefs?.getString('app_font_family') ?? 'Outfit';
  static set fontFamily(String v) {
    _prefs?.setString('app_font_family', v);
    _notify();
  }

  // --- Cache Management ---
  static Future<int> getCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int totalSize = 0;
      if (tempDir.existsSync()) {
        totalSize += _calculateSize(tempDir);
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  static int _calculateSize(Directory dir) {
    int total = 0;
    try {
      if (dir.existsSync()) {
        dir.listSync(recursive: true, followLinks: false).forEach((entity) {
          if (entity is File) {
            total += entity.lengthSync();
          }
        });
      }
    } catch (_) {}
    return total;
  }

  static Future<bool> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Auth ---
  static String get authToken => _prefs?.getString('auth_token') ?? '';
  static set authToken(String value) {
    if (value.isEmpty) {
      TxaLogger.log(
        '[AuthTrap] Token is being cleared. Stack: ${StackTrace.current}',
        isError: true,
      );
    }
    _prefs?.setString('auth_token', value);
    _notify();
  }

  static String get userData => _prefs?.getString('user_data') ?? '';
  static set userData(String value) {
    _prefs?.setString('user_data', value);
    _notify();
  }

  // Scheduled Movies
  static bool isMovieScheduled(String movieId) {
    return _prefs?.getBool('sch_$movieId') ?? false;
  }

  static void setMovieScheduled(String movieId, bool scheduled) {
    if (scheduled) {
      _prefs?.setBool('sch_$movieId', true);
    } else {
      _prefs?.remove('sch_$movieId');
    }
  }

  // --- iOS Specific ---
  static String get udid => _prefs?.getString('ios_device_udid') ?? '';
  static set udid(String v) => _prefs?.setString('ios_device_udid', v);

  // --- App State flags for Background Tasks ---
  static bool get isUpdateDownloading =>
      _prefs?.getBool('is_update_downloading') ?? false;
  static set isUpdateDownloading(bool v) =>
      _prefs?.setBool('is_update_downloading', v);

  static bool get isAppForeground =>
      _prefs?.getBool('is_app_foreground') ?? false;
  static set isAppForeground(bool v) => _prefs?.setBool('is_app_foreground', v);

  static String get lastNotifiedUpdateVersion =>
      _prefs?.getString('last_notified_update_version') ?? '';
  static set lastNotifiedUpdateVersion(String v) =>
      _prefs?.setString('last_notified_update_version', v);

  // --- Watch History ---
  static void saveLocalHistory(int episodeId, double position) {
    _prefs?.setDouble('hist_$episodeId', position);
  }

  static double getLocalHistory(int episodeId) {
    return _prefs?.getDouble('hist_$episodeId') ?? 0.0;
  }

  static void addPendingSync(Map<String, dynamic> data) {
    List<String> pending = _prefs?.getStringList('pending_history_sync') ?? [];
    // Avoid duplicates for same episode
    pending.removeWhere((item) {
      try {
        final decoded = jsonDecode(item);
        return decoded['episode_id'] == data['episode_id'];
      } catch (_) {
        return false;
      }
    });
    pending.add(jsonEncode(data));
    _prefs?.setStringList('pending_history_sync', pending);
  }

  static List<Map<String, dynamic>> getPendingSync() {
    List<String> pending = _prefs?.getStringList('pending_history_sync') ?? [];
    return pending
        .map((e) {
          try {
            return jsonDecode(e) as Map<String, dynamic>;
          } catch (_) {
            return <String, dynamic>{};
          }
        })
        .where((m) => m.isNotEmpty)
        .toList();
  }

  static void clearPendingSync() {
    _prefs?.remove('pending_history_sync');
  }
}
