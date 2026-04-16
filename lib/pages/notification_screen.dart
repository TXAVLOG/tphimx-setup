import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../services/txa_api.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../utils/txa_format.dart';
import 'auth_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<dynamic>? _items;
  bool _loading = true;
  String? _error;
  bool _isUnauthorized = false;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
      _isUnauthorized = false;
    });
    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      final res = await api.getNotifications();
      setState(() {
        _items = res['data'] is List ? res['data'] : [];
        _loading = false;
      });
    } catch (e) {
      bool unauthorized = false;
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          unauthorized = true;
        }
      }
      setState(() {
        _isUnauthorized = unauthorized;
        _error = unauthorized ? null : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markAsRead(String id, int index) async {
    if (_items![index]['is_read'] == true) return;

    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      await api.markNotificationRead(id);
      setState(() {
        _items![index]['is_read'] = true;
      });
    } catch (e) {
      // Silently fail or log
    }
  }

  Future<void> _clearAll() async {
    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      await api.clearNotifications();
      setState(() {
        _items = [];
      });
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _markAllRead() async {
    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      await api.markAllRead();
      setState(() {
        if (_items != null) {
          for (var item in _items!) {
            item['is_read'] = true;
          }
        }
      });
    } catch (e) {
      // Silently fail
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          TxaLanguage.t('notifications'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_items != null && _items!.isNotEmpty) ...[
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                TxaLanguage.t('read_all'),
                style: const TextStyle(color: TxaTheme.accent, fontSize: 13),
              ),
            ),
            IconButton(
              onPressed: _clearAll,
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: Colors.redAccent,
              ),
            ),
          ],
          IconButton(
            onPressed: _fetchNotifications,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: TxaTheme.accent),
      );
    }

    if (_isUnauthorized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 80,
              color: TxaTheme.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              TxaLanguage.t('login_required_notifications'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              width: 200,
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => const AuthScreen()),
                  );
                  if (result == true) {
                    _fetchNotifications();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: TxaTheme.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                  shadowColor: TxaTheme.accent.withValues(alpha: 0.4),
                ),
                child: Text(
                  TxaLanguage.t('login'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              TxaLanguage.t('error_loading_notifications'),
              style: const TextStyle(color: TxaTheme.textMuted),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _fetchNotifications,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(TxaLanguage.t('retry')),
              style: TextButton.styleFrom(foregroundColor: TxaTheme.accent),
            ),
          ],
        ),
      );
    }

    if (_items == null || _items!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 80,
              color: TxaTheme.textMuted.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 16),
            Text(
              TxaLanguage.t('no_notifications'),
              style: const TextStyle(color: TxaTheme.textMuted, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _items!.length,
      itemBuilder: (context, index) {
        final item = _items![index];
        final bool isRead = item['is_read'] == true;
        final String id = item['id']?.toString() ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => _markAsRead(id, index),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isRead
                    ? TxaTheme.cardBg.withValues(alpha: 0.5)
                    : TxaTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isRead
                      ? TxaTheme.glassBorder
                      : TxaTheme.accent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: isRead
                        ? TxaTheme.glassBg
                        : TxaTheme.accent.withValues(alpha: 0.2),
                    child:
                        item['image_url'] != null &&
                            item['image_url'].toString().isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              item['image_url'],
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            isRead
                                ? Icons.notifications_none_rounded
                                : Icons.notifications_active_rounded,
                            color: isRead
                                ? TxaTheme.textMuted
                                : TxaTheme.accent,
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] ?? '',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isRead
                                ? FontWeight.w500
                                : FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['message'] ?? '',
                          style: TextStyle(
                            color: isRead
                                ? TxaTheme.textSecondary
                                : TxaTheme.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          TxaFormat.formatTimeAgo(item['created_at'] ?? ''),
                          style: const TextStyle(
                            color: TxaTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: TxaTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
