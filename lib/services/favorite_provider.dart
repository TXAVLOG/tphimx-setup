import 'package:flutter/material.dart';
import 'txa_api.dart';
import 'txa_settings.dart';

class FavoriteProvider extends ChangeNotifier {
  final TxaApi _api;
  final Map<dynamic, bool> _favorites = {};

  FavoriteProvider(this._api) {
    // We don't load all favorites immediately to avoid heavy initial load,
    // but we can track toggles globally.
  }

  /// Normalize movie ID to a consistent key (int if possible, else string)
  dynamic _normalizeId(dynamic id) {
    if (id is int) return id;
    if (id is String) {
      final parsed = int.tryParse(id);
      return parsed ?? id;
    }
    return id;
  }

  bool isFavorite(dynamic movieId) => _favorites[_normalizeId(movieId)] ?? false;

  /// Update the favorite status locally. Useful when data comes from an API response
  /// that already includes the status (like movie detail).
  void setFavoriteStatus(dynamic movieId, bool status) {
    final key = _normalizeId(movieId);
    if (_favorites[key] != status) {
      _favorites[key] = status;
      notifyListeners();
    }
  }

  void loadFavoriteIds(List<dynamic> ids) {
    _favorites.clear();
    for (var id in ids) {
      _favorites[_normalizeId(id)] = true;
    }
    notifyListeners();
  }

  Future<bool> toggleFavorite(dynamic movieId) async {
    if (TxaSettings.authToken.isEmpty) return false;

    final key = _normalizeId(movieId);
    try {
      final res = await _api.toggleFavorite(movieId);
      if (res['success'] == true) {
        final bool status = res['data']['is_favorite'];
        _favorites[key] = status;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Toggle Favorite Error: $e');
    }
    return false;
  }
}
