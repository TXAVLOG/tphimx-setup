import 'package:flutter/material.dart';
import 'txa_api.dart';
import 'txa_settings.dart';

class NotificationProvider extends ChangeNotifier {
  final TxaApi _api;
  int _unreadCount = 0;
  List<dynamic> _notifications = [];
  bool _isLoading = false;

  NotificationProvider(this._api) {
    if (TxaSettings.authToken.isNotEmpty) {
      fetchNotifications();
    }
  }

  int get unreadCount => _unreadCount;
  List<dynamic> get notifications => _notifications;
  bool get isLoading => _isLoading;

  Future<void> fetchNotifications() async {
    if (TxaSettings.authToken.isEmpty) {
      _unreadCount = 0;
      _notifications = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final res = await _api.getNotifications();
      if (res['data'] is List) {
        _notifications = res['data'];
        _unreadCount = _notifications
            .where((n) => n['is_read'] == false)
            .length;
      }
    } catch (e) {
      debugPrint('Fetch Notifications Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _api.markNotificationRead(id);
      final index = _notifications.indexWhere((n) => n['id'].toString() == id);
      if (index != -1) {
        if (_notifications[index]['is_read'] == false) {
          _notifications[index]['is_read'] = true;
          if (_unreadCount > 0) _unreadCount--;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Mark As Read Error: $e');
    }
  }

  Future<void> markAllRead() async {
    try {
      await _api.markAllRead();
      for (var n in _notifications) {
        n['is_read'] = true;
      }
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Mark All Read Error: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      await _api.clearNotifications();
      _notifications = [];
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Clear Notifications Error: $e');
    }
  }
}
