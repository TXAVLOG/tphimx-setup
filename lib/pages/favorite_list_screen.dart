import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/txa_api.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import 'movie_detail_screen.dart';

class FavoriteListScreen extends StatefulWidget {
  const FavoriteListScreen({super.key});

  @override
  State<FavoriteListScreen> createState() => _FavoriteListScreenState();
}

class _FavoriteListScreenState extends State<FavoriteListScreen> {
  List<dynamic>? _items;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      final res = await api.getFavorites();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          TxaLanguage.t('add_favorite'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              TxaLanguage.t('error'),
              style: const TextStyle(color: Colors.white),
            ),
            TextButton(
              onPressed: _loadFavorites,
              child: Text(TxaLanguage.t('retry')),
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
              Icons.favorite_border_rounded,
              size: 64,
              color: TxaTheme.textMuted.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              TxaLanguage.t('no_favorites'),
              style: const TextStyle(color: TxaTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: _items!.length,
      itemBuilder: (context, index) {
        final movie = _items![index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => MovieDetailScreen(slug: movie['slug']),
              ),
            ).then((_) => _loadFavorites());
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: movie['thumb_url'] ?? '',
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) =>
                        Container(color: TxaTheme.secondaryBg),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                movie['name'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
