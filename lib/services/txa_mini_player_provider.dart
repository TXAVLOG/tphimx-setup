import 'package:flutter/material.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'txa_shortcut_service.dart';

class TxaMiniPlayerProvider with ChangeNotifier {
  BetterPlayerController? _controller;
  dynamic _movie;
  List<dynamic>? _servers;
  int _serverIndex = 0;
  int _episodeIndex = 0;
  
  bool _isMini = false;
  bool _isClosed = true;

  BetterPlayerController? get controller => _controller;
  dynamic get movie => _movie;
  List<dynamic>? get servers => _servers;
  int get serverIndex => _serverIndex;
  bool get isMini => _isMini;
  bool get isClosed => _isClosed;
  int get episodeIndex => _episodeIndex;

  void switchToMini({
    required BetterPlayerController controller,
    required dynamic movie,
    required List<dynamic> servers,
    required int serverIndex,
    required int episodeIndex,
  }) {
    _controller = controller;
    _movie = movie;
    _servers = servers;
    _serverIndex = serverIndex;
    _episodeIndex = episodeIndex;
    _isMini = true;
    _isClosed = false;
    
    TxaShortcutService.setPlayerStatus(
      miniActive: true,
      isPlaying: controller.videoPlayerController!.value.isPlaying,
    );
    notifyListeners();
  }

  void switchToFull() {
    _isMini = false;
    TxaShortcutService.setPlayerStatus(miniActive: false);
    notifyListeners();
  }

  void close() {
    _controller?.dispose();
    _controller = null;
    _isClosed = true;
    _isMini = false;
    TxaShortcutService.setPlayerStatus(miniActive: false);
    notifyListeners();
  }

  // Action methods to sync with player
  void playPause() {
    if (_controller == null) return;
    if (_controller!.videoPlayerController!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    TxaShortcutService.setPlayerStatus(isPlaying: _controller!.videoPlayerController!.value.isPlaying);
    notifyListeners();
  }
}
