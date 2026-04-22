import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/txa_logger.dart';

class TxaSettings {
  static late SharedPreferences _prefs;
  static Function()? onSettingsChanged;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static void _notify() => onSettingsChanged?.call();

  // --- Player Settings ---
  static bool get autoSkipIntro =>
      _prefs.getBool('player_auto_skip_intro') ?? false;
  static set autoSkipIntro(bool v) {
    _prefs.setBool('player_auto_skip_intro', v);
    _notify();
  }

  static bool get autoNextEpisode =>
      _prefs.getBool('player_auto_next_episode') ?? true;
  static set autoNextEpisode(bool v) {
    _prefs.setBool('player_auto_next_episode', v);
    _notify();
  }

  static double get volume => _prefs.getDouble('player_volume') ?? 1.0;
  static set volume(double v) => _prefs.setDouble('player_volume', v);

  static double get playbackSpeed =>
      _prefs.getDouble('player_playback_speed') ?? 1.0;
  static set playbackSpeed(double v) {
    _prefs.setDouble('player_playback_speed', v);
    _notify();
  }

  static String get quality => _prefs.getString('player_quality') ?? 'Auto';
  static set quality(String v) {
    _prefs.setString('player_quality', v);
    _notify();
  }

  static bool get showClock => _prefs.getBool('player_show_clock') ?? true;
  static set showClock(bool v) {
    _prefs.setBool('player_show_clock', v);
    _notify();
  }

  static String get clockFormat =>
      _prefs.getString('player_clock_format') ?? 'HH:mm';
  static set clockFormat(String v) {
    _prefs.setString('player_clock_format', v);
    _notify();
  }

  static bool get autoDND => _prefs.getBool('player_auto_dnd') ?? true;
  static set autoDND(bool v) {
    _prefs.setBool('player_auto_dnd', v);
    _notify();
  }

  static bool get autoPiP => _prefs.getBool('player_auto_pip') ?? true;
  static set autoPiP(bool v) {
    _prefs.setBool('player_auto_pip', v);
    _notify();
  }

  static double get brightness => _prefs.getDouble('player_brightness') ?? 0.5;
  static set brightness(double v) {
    _prefs.setDouble('player_brightness', v);
    _notify();
  }

  // --- Appearance ---
  static double get fontSizeScale => _prefs.getDouble('app_font_size') ?? 1.0;
  static set fontSizeScale(double v) {
    _prefs.setDouble('app_font_size', v);
    _notify();
  }

  static String get fontFamily =>
      _prefs.getString('app_font_family') ?? 'Outfit';
  static set fontFamily(String v) {
    _prefs.setString('app_font_family', v);
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
  static String get authToken => _prefs.getString('auth_token') ?? '';
  static set authToken(String value) {
    if (value.isEmpty) {
      TxaLogger.log(
        '[AuthTrap] Token is being cleared. Stack: ${StackTrace.current}',
        isError: true,
      );
    }
    _prefs.setString('auth_token', value);
    _notify();
  }

  static String get userData => _prefs.getString('user_data') ?? '';
  static set userData(String value) {
    _prefs.setString('user_data', value);
    _notify();
  }

  // Scheduled Movies
  static bool isMovieScheduled(String movieId) {
    return _prefs.getBool('sch_$movieId') ?? false;
  }

  static void setMovieScheduled(String movieId, bool scheduled) {
    if (scheduled) {
      _prefs.setBool('sch_$movieId', true);
    } else {
      _prefs.remove('sch_$movieId');
    }
  }

  // --- iOS Specific ---
  static String get udid => _prefs.getString('ios_device_udid') ?? '';
  static set udid(String v) => _prefs.setString('ios_device_udid', v);
}
