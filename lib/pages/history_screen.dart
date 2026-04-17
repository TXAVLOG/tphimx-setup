import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/txa_api.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_format.dart';
import 'movie_detail_screen.dart';
import '../services/txa_settings.dart';
import 'auth_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic>? _items;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (TxaSettings.authToken.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'LOGIN_REQUIRED';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      final res = await api.getWatchHistory();
      setState(() {
        _items = res['data'] is List ? res['data'] : [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _clearHistory() async {
    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      await api.clearWatchHistory();
      setState(() => _items = []);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          TxaLanguage.t('watching'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_items != null && _items!.isNotEmpty)
            IconButton(
              onPressed: _clearHistory,
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: Colors.redAccent,
              ),
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

    if (_error != null) {
      final bool isLoginReq = _error == 'LOGIN_REQUIRED';
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLoginReq
                  ? Icons.lock_outline_rounded
                  : Icons.error_outline_rounded,
              size: 64,
              color: TxaTheme.textMuted.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                isLoginReq
                    ? TxaLanguage.t('login_required_history')
                    : TxaLanguage.t('error_loading_data'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: TxaTheme.textMuted),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoginReq
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const AuthScreen()),
                      ).then((val) {
                        if (val == true) _loadHistory();
                      });
                    }
                  : _loadHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: TxaTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                isLoginReq ? TxaLanguage.t('login') : TxaLanguage.t('retry'),
              ),
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
              Icons.history_rounded,
              size: 64,
              color: TxaTheme.textMuted.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              TxaLanguage.t('no_history'),
              style: const TextStyle(color: TxaTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items!.length,
      itemBuilder: (context, index) {
        final item = _items![index];
        final movie = item['movie'] ?? {};
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () async {
              // Show loading overlay or just go to detail with autoPlay
              // For better UX and consistency, we fetch detail first or let DetailScreen handle it.
              // Here we'll just go to DetailScreen and it will already highlight the episode.
              // If the user wants "automatic", we could add a flag to MovieDetailScreen.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) =>
                      MovieDetailScreen(slug: movie['slug'], autoPlay: true),
                ),
              ).then((_) => _loadHistory());
            },
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: movie['thumb_url'] ?? '',
                    width: 100,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) =>
                        Container(color: TxaTheme.secondaryBg),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie['name'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${TxaLanguage.t('watching')}: ${item['episode_name'] ?? '...'}',
                        style: const TextStyle(
                          color: TxaTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        TxaFormat.formatTimeAgo(item['updated_at'] ?? ''),
                        style: const TextStyle(
                          color: TxaTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
