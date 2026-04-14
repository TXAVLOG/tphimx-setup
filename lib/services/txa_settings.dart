import 'package:shared_preferences/shared_preferences.dart';

class TxaSettings {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Player Settings ---
  static bool get autoSkipIntro => _prefs.getBool('player_auto_skip_intro') ?? false;
  static set autoSkipIntro(bool v) => _prefs.setBool('player_auto_skip_intro', v);

  static bool get autoNextEpisode => _prefs.getBool('player_auto_next_episode') ?? true;
  static set autoNextEpisode(bool v) => _prefs.setBool('player_auto_next_episode', v);

  static double get volume => _prefs.getDouble('player_volume') ?? 1.0;
  static set volume(double v) => _prefs.setDouble('player_volume', v);

  static double get playbackSpeed => _prefs.getDouble('player_playback_speed') ?? 1.0;
  static set playbackSpeed(double v) => _prefs.setDouble('player_playback_speed', v);

  static String get quality => _prefs.getString('player_quality') ?? 'Auto';
  static set quality(String v) => _prefs.setString('player_quality', v);
  
  static bool get showClock => _prefs.getBool('player_show_clock') ?? true;
  static set showClock(bool v) => _prefs.setBool('player_show_clock', v);

  static bool get autoPiP => _prefs.getBool('player_auto_pip') ?? true;
  static set autoPiP(bool v) => _prefs.setBool('player_auto_pip', v);

  static double get brightness => _prefs.getDouble('player_brightness') ?? 0.5;
  static set brightness(double v) => _prefs.setDouble('player_brightness', v);

  // --- iOS Specific ---
  static String get udid => _prefs.getString('ios_device_udid') ?? '';
  static set udid(String v) => _prefs.setString('ios_device_udid', v);
}
