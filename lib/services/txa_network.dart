import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class TxaNetwork extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  List<ConnectivityResult> _currentStatus = [ConnectivityResult.none];

  TxaNetwork() {
    _connectivity.onConnectivityChanged.listen((status) {
      _currentStatus = status;
      notifyListeners();
    });
    _init();
  }

  Future<void> _init() async {
    _currentStatus = await _connectivity.checkConnectivity();
    notifyListeners();
  }

  bool get isOffline => _currentStatus.contains(ConnectivityResult.none);

  /// Check current connection status
  Future<bool> isConnected() async {
    final status = await _connectivity.checkConnectivity();
    return !status.contains(ConnectivityResult.none);
  }

  Future<bool> checkConnection() async {
    return await isConnected();
  }

  /// Listen for connection changes
  Stream<List<ConnectivityResult>> onConnectionChanged() {
    return _connectivity.onConnectivityChanged;
  }

  /// Get current connection type
  Future<List<ConnectivityResult>> getConnectionType() async {
    return await _connectivity.checkConnectivity();
  }

  /// Check if on mobile (LTE/3G)
  Future<bool> isMobile() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.mobile);
  }

  /// Check if on WiFi
  Future<bool> isWifi() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }
}
