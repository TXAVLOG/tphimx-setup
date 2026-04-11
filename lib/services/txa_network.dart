import 'package:connectivity_plus/connectivity_plus.dart';

class TxaNetwork {
  final Connectivity _connectivity = Connectivity();

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
