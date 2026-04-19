import 'package:flutter/material.dart';
import 'txa_api.dart';
import 'txa_settings.dart';

class FavoriteProvider extends ChangeNotifier {
  final TxaApi _api;
  final Map<int, bool> _favorites = {};

  FavoriteProvider(this._api) {
    // We don't load all favorites immediately to avoid heavy initial load,
    // but we can track toggles globally.
  }

  bool isFavorite(int movieId) => _favorites[movieId] ?? false;

  /// Update the favorite status locally. Useful when data comes from an API response
  /// that already includes the status (like movie detail).
  void setFavoriteStatus(int movieId, bool status) {
    if (_favorites[movieId] != status) {
      _favorites[movieId] = status;
      notifyListeners();
    }
  }

  Future<bool> toggleFavorite(int movieId) async {
    if (TxaSettings.authToken.isEmpty) return false;

    try {
      final res = await _api.toggleFavorite(movieId);
      if (res['success'] == true) {
        final bool status = res['data']['is_favorite'];
        _favorites[movieId] = status;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Toggle Favorite Error: $e');
    }
    return false;
  }
}
