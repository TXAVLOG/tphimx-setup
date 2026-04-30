import 'package:quick_actions/quick_actions.dart';
import 'txa_language.dart';

class TxaShortcutService {
  static final QuickActions _quickActions = const QuickActions();

  static String? _downloadStatus;
  static bool? _isPlaying;
  static bool _miniActive = false;

  static void init(Function(String) onAction) {
    _quickActions.initialize(onAction);
    _updateShortcuts();
  }

  static void setDownloadStatus(String? status) {
    _downloadStatus = status;
    _updateShortcuts();
  }

  static void setPlayerStatus({bool? isPlaying, bool? miniActive}) {
    if (isPlaying != null) _isPlaying = isPlaying;
    if (miniActive != null) _miniActive = miniActive;
    _updateShortcuts();
  }

  static void _updateShortcuts() {
    List<ShortcutItem> items = [];

    // 1. Download Status (Dynamic)
    if (_downloadStatus != null) {
      items.add(
        ShortcutItem(
          type: 'action_download_progress',
          localizedTitle: _downloadStatus!,
          icon: 'ic_download_shortcut', // Needs to be in android/res/drawable
        ),
      );
    }

    // 2. Player Controls (Only if mini active)
    if (_miniActive) {
      items.add(
        ShortcutItem(
          type: 'action_player_play_pause',
          localizedTitle: _isPlaying == true
              ? TxaLanguage.t('player_pause')
              : TxaLanguage.t('player_play'),
          icon: _isPlaying == true ? 'ic_pause_shortcut' : 'ic_play_shortcut',
        ),
      );

      items.add(
        ShortcutItem(
          type: 'action_player_close',
          localizedTitle: TxaLanguage.t('player_close'),
          icon: 'ic_close_shortcut',
        ),
      );
    }

    // 3. Check for Updates
    items.add(
      ShortcutItem(
        type: 'action_check_update',
        localizedTitle: TxaLanguage.t('check_update'),
        icon: 'ic_update_shortcut',
      ),
    );

    _quickActions.setShortcutItems(items);
  }
}
