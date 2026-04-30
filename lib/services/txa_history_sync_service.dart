import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/txa_api.dart';
import '../services/txa_settings.dart';
import '../services/txa_network.dart';
import '../utils/txa_logger.dart';

class TxaHistorySyncService {
  final TxaApi _api;
  final TxaNetwork _network;
  bool _isSyncing = false;
  Timer? _timer;

  TxaHistorySyncService(this._api, this._network);

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _sync();
    });

    _network.onConnectionChanged().listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        _sync();
      }
    });

    // Initial sync
    _sync();
  }

  Future<void> _sync() async {
    if (_isSyncing) return;

    final pending = TxaSettings.getPendingSync();
    if (pending.isEmpty) return;

    if (!(await _network.isConnected())) return;

    _isSyncing = true;
    TxaLogger.log(
      "Starting sync of ${pending.length} pending history items...",
    );

    int successCount = 0;
    final List<Map<String, dynamic>> failed = [];

    for (var item in pending) {
      try {
        await _api.updateWatchHistory(
          movieId: item['movie_id'],
          episodeId: item['episode_id'],
          currentTime: item['current_time'].toDouble(),
          duration: item['duration'].toDouble(),
        );
        successCount++;
      } catch (e) {
        TxaLogger.log(
          "Sync item failed: ${item['episode_id']} - $e",
          isError: true,
        );
        failed.add(item);
      }
    }

    TxaSettings.clearPendingSync();
    if (failed.isNotEmpty) {
      for (var item in failed) {
        TxaSettings.addPendingSync(item);
      }
    }

    TxaLogger.log(
      "History sync finished. Success: $successCount, Failed: ${failed.length}",
    );
    _isSyncing = false;
  }

  void dispose() {
    _timer?.cancel();
  }
}
