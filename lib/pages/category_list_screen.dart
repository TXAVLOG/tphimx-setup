import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/txa_api.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import 'movie_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CategoryListScreen extends StatefulWidget {
  final String title;
  final String? slug;
  final String? type;

  const CategoryListScreen({
    super.key,
    required this.title,
    this.slug,
    this.type,
  });

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  int _page = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_loading &&
          _hasMore) {
        _loadData(loadMore: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool loadMore = false}) async {
    if (loadMore) {
      _page++;
    } else {
      _page = 1;
      _items = [];
    }

    setState(() => _loading = true);

    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      Map<String, dynamic> res;
      if (widget.slug != null) {
        res = await api.getCategory(widget.slug!, page: _page);
      } else if (widget.type != null) {
        res = await api.getType(widget.type!, page: _page);
      } else {
        res = {'data': []};
      }

      final data = res['data'] ?? res;
      final List list = data is List
          ? data
          : (data?['movies']?['data'] as List? ??
                data?['data'] as List? ??
                data?['items'] as List? ??
                []);

      setState(() {
        _items.addAll(list);
        _loading = false;
        _hasMore = list.length >= 20; // Assumption for pagination
      });
    } catch (_) {
      setState(() => _loading = false);
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
          TxaLanguage.t(widget.title),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _items.isEmpty && _loading
          ? const Center(
              child: CircularProgressIndicator(color: TxaTheme.accent),
            )
          : CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width > 1200
                          ? 7
                          : MediaQuery.of(context).size.width > 900
                          ? 5
                          : MediaQuery.of(context).size.width > 600
                          ? 4
                          : 3,
                      childAspectRatio: 0.65,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final movie = _items[index];
                      return _MovieGridItem(movie: movie);
                    }, childCount: _items.length),
                  ),
                ),
                if (_loading && _items.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: TxaTheme.accent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MovieGridItem extends StatelessWidget {
  final dynamic movie;
  const _MovieGridItem({required this.movie});

  @override
  Widget build(BuildContext context) {
    final name = movie['name'] ?? '';
    final poster = movie['thumb_url'] ?? movie['poster_url'] ?? '';
    final slug = movie['slug'] ?? '';
    final quality = movie['quality'] ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (ctx) => MovieDetailScreen(slug: slug)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: poster,
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) =>
                        Container(color: TxaTheme.cardBg),
                  ),
                  if (quality.isNotEmpty)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: TxaTheme.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          quality,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            movie['origin_name'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
