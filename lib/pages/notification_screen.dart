import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_provider.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../utils/txa_format.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

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
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, child) {
              if (provider.notifications.isEmpty) {
                return const SizedBox.shrink();
              }
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                onSelected: (val) {
                  if (val == 'read_all') {
                    provider.markAllRead();
                  }
                  if (val == 'clear_all') {
                    provider.clearAll();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'read_all',
                    child: Row(
                      children: [
                        const Icon(Icons.done_all_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(TxaLanguage.t('read_all')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_sweep_rounded,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          TxaLanguage.t('delete_all'),
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: TxaTheme.accent),
            );
          }

          if (provider.notifications.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: provider.fetchNotifications,
            color: TxaTheme.accent,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: provider.notifications.length,
              itemBuilder: (context, index) {
                final item = provider.notifications[index];
                return _NotificationItem(item: item);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: TxaTheme.secondaryBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: TxaTheme.textMuted.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            TxaLanguage.t('no_notifications'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            TxaLanguage.t('no_notifications_desc'), // I'll add this translation
            style: const TextStyle(color: TxaTheme.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final dynamic item;
  const _NotificationItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final bool isRead = item['is_read'] == true;
    final String id = item['id']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.read<NotificationProvider>().markAsRead(id);
          // Potential navigation here if item has a movie slug
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isRead
                ? TxaTheme.cardBg
                : TxaTheme.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isRead
                  ? TxaTheme.glassBorder
                  : TxaTheme.accent.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: isRead
                ? null
                : [
                    BoxShadow(
                      color: TxaTheme.accent.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon/Image
              _buildLeading(isRead),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['title'] ?? '',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              fontSize: 15,
                            ),
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
                    const SizedBox(height: 6),
                    Text(
                      item['message'] ?? '',
                      style: TextStyle(
                        color: isRead
                            ? TxaTheme.textSecondary
                            : TxaTheme.textPrimary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      TxaFormat.formatTimeAgo(item['created_at'] ?? ''),
                      style: const TextStyle(
                        color: TxaTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(bool isRead) {
    final imageUrl = item['image_url']?.toString() ?? '';

    if (imageUrl.isNotEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
          ),
          border: Border.all(color: Colors.white10),
        ),
      );
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isRead
            ? TxaTheme.glassBg
            : TxaTheme.accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isRead
            ? Icons.notifications_none_rounded
            : Icons.notifications_active_rounded,
        color: isRead ? TxaTheme.textMuted : TxaTheme.accent,
        size: 24,
      ),
    );
  }
}
