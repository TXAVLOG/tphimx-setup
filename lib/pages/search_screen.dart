import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../services/txa_api.dart';
import '../services/search_provider.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../utils/txa_format.dart';
import 'movie_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  String _query = '';
  List<dynamic> _results = [];
  List<dynamic> _hotMovies = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _loadHotSearch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sp = Provider.of<SearchProvider>(context);
    if (sp.categorySlug != null && sp.categorySlug != _query) {
      _query = sp.categorySlug!;
      _doCategorySearch(sp.categorySlug!);
    } else if (sp.query.isNotEmpty &&
        (sp.query != _controller.text || !_searched)) {
      _controller.text = sp.query;
      _query = sp.query;
      _doSearch(sp.query);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHotSearch() async {
    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      final res = await api.getHotSearch(limit: 10);
      final data = res['data'];
      if (data != null) {
        setState(() {
          _hotMovies = data is List ? data : (data['data'] as List? ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _doSearch(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _searched = true;
      _query = keyword;
    });
    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      final res = await api.searchMovies(keyword.trim());
      final data = res['data'];
      setState(() {
        _results = data is List
            ? data
            : (data?['data'] as List? ?? data?['items'] as List? ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _results = [];
        _loading = false;
      });
    }
  }

  Future<void> _doCategorySearch(String slug) async {
    setState(() {
      _loading = true;
      _searched = true;
      _query = '';
    });
    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      final res = await api.getCategory(slug);
      final data = res['data'];
      setState(() {
        _results = data is List
            ? data
            : (data?['data'] as List? ?? data?['items'] as List? ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _results = [];
        _loading = false;
      });
    }
  }

  void _onInputChanged(String val) {
    _query = val;
    _debounce?.cancel();
    if (val.trim().isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _doSearch(val));
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {
      _query = '';
      _results = [];
      _searched = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: TxaTheme.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: TxaTheme.glassBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: TxaTheme.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: _onInputChanged,
                      onSubmitted: (val) => _doSearch(val),
                      style: const TextStyle(
                        color: TxaTheme.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: TxaLanguage.t('search_hint'),
                        hintStyle: const TextStyle(
                          color: TxaTheme.textMuted,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: _clearSearch,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          color: TxaTheme.textMuted,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Content
          Expanded(
            child: Consumer<SearchProvider>(
              builder: (ctx, sp, child) {
                // If provider changed, we might need to refresh
                return _buildContent(sp);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(SearchProvider sp) {
    // If provider state doesn't match our local state, and it was just set externally
    if (sp.categorySlug != null &&
        !_loading &&
        !_results.isNotEmpty &&
        _query == '') {
      // This is a bit tricky with local state, usually we'd move all state to provider.
      // For now, let's just trigger it if results are empty.
    }

    // Loading
    if (_searched && _loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: TxaTheme.accent,
              strokeWidth: 2,
            ),
            const SizedBox(height: 12),
            Text(
              TxaLanguage.t('searching'),
              style: const TextStyle(color: TxaTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Search results (Normal or Category)
    if (_searched && !_loading && _results.isNotEmpty) {
      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sp.categoryName != null
                    ? TxaLanguage.t(
                        'category_label',
                      ).replaceAll('%name', sp.categoryName!)
                    : TxaLanguage.t(
                        'search_results',
                      ).replaceAll('%count', _results.length.toString()),
                style: const TextStyle(
                  color: TxaTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (sp.categorySlug != null)
                GestureDetector(
                  onTap: () {
                    sp.clear();
                    _clearSearch();
                  },
                  child: Text(
                    TxaLanguage.t('clear_filter'),
                    style: const TextStyle(
                      color: TxaTheme.accent,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ..._results.map(
            (m) => GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => MovieDetailScreen(slug: m['slug']),
                ),
              ),
              child: _SearchResultItem(movie: m, keyword: _query),
            ),
          ),
        ],
      );
    }

    // No results
    if (_searched && !_loading && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: TxaTheme.textMuted.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              TxaLanguage.t('search_no_results').replaceAll('%query', _query),
              style: const TextStyle(color: TxaTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Default: Hot Search
    if (_hotMovies.isNotEmpty) {
      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          Text(
            TxaLanguage.t('search_hot_title'),
            style: const TextStyle(
              color: TxaTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(
            _hotMovies.length,
            (i) => GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) =>
                      MovieDetailScreen(slug: _hotMovies[i]['slug']),
                ),
              ),
              child: _HotSearchItem(movie: _hotMovies[i], rank: i + 1),
            ),
          ),
        ],
      );
    }

    return Center(
      child: Text(
        TxaLanguage.t('search_input_prompt'),
        style: const TextStyle(color: TxaTheme.textMuted, fontSize: 13),
      ),
    );
  }
}

class _SearchResultItem extends StatelessWidget {
  final dynamic movie;
  final String keyword;

  const _SearchResultItem({required this.movie, required this.keyword});

  @override
  Widget build(BuildContext context) {
    final name = movie['name'] ?? '';
    final originName = movie['origin_name'] ?? '';
    final thumbUrl = movie['thumb_url'] ?? movie['poster_url'] ?? '';
    final year = movie['year']?.toString() ?? '';
    final quality = movie['quality']?.toString() ?? '';
    final type = movie['type'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: TxaTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TxaTheme.glassBorder),
      ),
      child: Row(
        children: [
          // Thumb
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: thumbUrl,
              width: 60,
              height: 85,
              fit: BoxFit.cover,
              placeholder: (ctx, url) =>
                  Container(width: 60, height: 85, color: TxaTheme.secondaryBg),
              errorWidget: (ctx, url, err) => Container(
                width: 60,
                height: 85,
                color: TxaTheme.secondaryBg,
                child: const Icon(
                  Icons.movie,
                  size: 20,
                  color: TxaTheme.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TxaTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (originName.isNotEmpty)
                  Text(
                    originName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TxaTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: [
                    if (year.isNotEmpty) _SmallBadge(text: year),
                    if (quality.isNotEmpty)
                      _SmallBadge(
                        text: quality,
                        color: const Color(0xFF10B981),
                      ),
                    if (type == 'series')
                      _SmallBadge(text: TxaLanguage.t('movie_series')),
                    if (type == 'single')
                      _SmallBadge(text: TxaLanguage.t('movie_single')),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: TxaTheme.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _HotSearchItem extends StatelessWidget {
  final dynamic movie;
  final int rank;

  const _HotSearchItem({required this.movie, required this.rank});

  @override
  Widget build(BuildContext context) {
    final name = movie['name'] ?? '';
    final thumbUrl = movie['thumb_url'] ?? movie['poster_url'] ?? '';
    final year = movie['year']?.toString() ?? '';
    final searchCount = movie['search_count'] ?? movie['view_total'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: TxaTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TxaTheme.glassBorder),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: rank <= 3 ? TxaTheme.accent : TxaTheme.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Thumb
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: thumbUrl,
              width: 42,
              height: 56,
              fit: BoxFit.cover,
              placeholder: (ctx, url) =>
                  Container(width: 42, height: 56, color: TxaTheme.secondaryBg),
              errorWidget: (ctx, url, err) =>
                  Container(width: 42, height: 56, color: TxaTheme.secondaryBg),
            ),
          ),
          const SizedBox(width: 10),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TxaTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$year • ${TxaLanguage.t('views_count').replaceAll('%count', TxaFormat.formatNumber(searchCount))}',
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
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String text;
  final Color? color;
  const _SmallBadge({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? TxaTheme.accent).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? TxaTheme.accent,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
