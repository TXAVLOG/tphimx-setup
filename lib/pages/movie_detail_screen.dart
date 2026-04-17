import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/txa_api.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_toast.dart';
import '../widgets/txa_player.dart';
import '../widgets/txa_error_widget.dart';
import 'package:share_plus/share_plus.dart';
import '../services/txa_settings.dart';
import '../utils/txa_logger.dart';
import '../services/txa_mini_player_provider.dart';

class MovieDetailScreen extends StatefulWidget {
  final String slug;
  final bool autoPlay;
  const MovieDetailScreen({
    super.key,
    required this.slug,
    this.autoPlay = false,
  });

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  bool _descExpanded = false;
  late TabController _tabController;

  int _selectedServerIndex = 0;
  bool _autoPlayed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      final res = await api.getMovie(widget.slug);
      setState(() {
        _data = res['data'];
        _loading = false;
      });

      // Auto play if requested
      if (widget.autoPlay && !_autoPlayed) {
        _autoPlayed = true;
        _playAutomatically();
      }
    } catch (e) {
      TxaLogger.log(
        'Movie Detail Load Error [${widget.slug}]: $e',
        isError: true,
      );
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _playAutomatically() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _data == null) return;
      final s = _data!['servers'] as List? ?? [];
      if (s.isNotEmpty && (s[0]['server_data'] as List).isNotEmpty) {
        final m = _data!['movie'];
        final history = _data!['history'];
        String epId = s[0]['server_data'][0]['id'].toString();
        double initialTime = 0;

        if (history != null) {
          epId = history['episode_id'].toString();
          initialTime = (history['current_time'] as num).toDouble();
        }

        final miniProvider = context.read<TxaMiniPlayerProvider>();
        if (!miniProvider.isClosed) miniProvider.close();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => TxaPlayer(
              movie: m,
              servers: s,
              initialServerIndex: 0,
              initialEpisodeId: epId,
              initialTime: initialTime,
            ),
          ),
        );
      }
    });
  }

  Future<void> _toggleFavorite() async {
    final api = Provider.of<TxaApi>(context, listen: false);
    if (TxaSettings.authToken.isEmpty) {
      TxaToast.show(context, TxaLanguage.t('login_required'), isError: true);
      return;
    }

    try {
      final res = await api.toggleFavorite(_data!['movie']['id']);
      if (!mounted) return;

      if (res['success'] == true) {
        setState(() {
          _data!['movie']['is_favorite'] = res['data']['is_favorite'];
        });
        TxaToast.show(
          context,
          res['data']['is_favorite']
              ? TxaLanguage.t('favorite_added')
              : TxaLanguage.t('favorite_removed'),
        );
      }
    } catch (e) {
      if (mounted) {
        TxaToast.show(context, "${TxaLanguage.t('error')}: $e", isError: true);
      }
    }
  }

  void _shareMovie() {
    final movie = _data!['movie'];
    final shareText =
        '${movie['name']} - ${TxaLanguage.t('app_slogan')}\nXem ngay tại: https://film.nrotxa.online/movie/${widget.slug}';
    Share.share(shareText, subject: movie['name']);
  }

  // Cleaned up

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: TxaTheme.primaryBg,
        body: Center(child: CircularProgressIndicator(color: TxaTheme.accent)),
      );
    }

    if (_error != null || _data == null || _data!['movie'] == null) {
      return Scaffold(
        backgroundColor: TxaTheme.primaryBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: TxaErrorWidget(
          message: _error != null
              ? TxaLanguage.t('error_loading_data')
              : TxaLanguage.t('not_found_movie'),
          technicalDetails: _error,
          onRetry: _loadDetail,
        ),
      );
    }

    final movie = _data!['movie'];
    final servers = _data!['servers'] as List? ?? [];
    final related = _data!['related'] as List? ?? [];

    final bannerUrl = movie['poster_url'] ?? movie['thumb_url'] ?? '';
    final name = movie['name'] ?? '';
    final content = movie['content'] ?? '';
    final year = movie['year']?.toString() ?? '';
    final quality = movie['quality']?.toString() ?? '';
    final time = movie['time']?.toString() ?? '';
    final categories = movie['categories'] as List? ?? [];

    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            // TABLET LAYOUT: 2 COLUMNS
            return Row(
              children: [
                // Left Column: Details & Recommendation
                Expanded(
                  flex: 5,
                  child: CustomScrollView(
                    slivers: [
                      _buildTabletHeader(bannerUrl),
                      _buildTabletInfo(
                        name,
                        year,
                        quality,
                        time,
                        categories,
                        content,
                        movie,
                      ),
                      _buildTabletTabsSwitcher(), // For Actors & Related
                      SliverFillRemaining(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            const SizedBox.shrink(), // Episodes are on the right
                            if (movie['actors'] != null &&
                                (movie['actors'] as List).isNotEmpty)
                              _buildActorsTab(movie['actors'])
                            else
                              Center(
                                child: Text(
                                  TxaLanguage.t('no_actors'),
                                  style: const TextStyle(
                                    color: TxaTheme.textMuted,
                                  ),
                                ),
                              ),
                            _buildRelatedTab(related),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Vertical Divider
                Container(width: 1, color: Colors.white10),
                // Right Column: Episode List
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            TxaLanguage.t('episodes'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Expanded(child: _buildEpisodesTab(servers)),
                    ],
                  ),
                ),
              ],
            );
          }

          // MOBILE LAYOUT (DEFAULT)
          return CustomScrollView(
            slivers: [
              // Banner Area
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    SizedBox(
                      height: 250,
                      width: double.infinity,
                      child: CachedNetworkImage(
                        imageUrl: bannerUrl,
                        fit: BoxFit.cover,
                        placeholder: (ctx, url) =>
                            Container(color: TxaTheme.secondaryBg),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.3),
                              Colors.transparent,
                              TxaTheme.primaryBg,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Back Button
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main Header Info
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Action Buttons
                      _HeroActionButton(
                        label: TxaLanguage.t('watch_now'),
                        icon: Icons.play_arrow_rounded,
                        color: TxaTheme.accent,
                        onTap: () {
                          final m = _data!['movie'];
                          final s = _data!['servers'] as List? ?? [];
                          if (s.isNotEmpty &&
                              (s[0]['server_data'] as List).isNotEmpty) {
                            final miniProvider = context
                                .read<TxaMiniPlayerProvider>();
                            if (!miniProvider.isClosed) miniProvider.close();

                            final history = _data!['history'];
                            String epId = s[0]['server_data'][0]['id']
                                .toString();
                            double initialTime = 0;

                            if (history != null) {
                              epId = history['episode_id'].toString();
                              initialTime = (history['current_time'] as num)
                                  .toDouble();
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => TxaPlayer(
                                  movie: m,
                                  servers: s,
                                  initialServerIndex: 0,
                                  initialEpisodeId: epId,
                                  initialTime: initialTime,
                                ),
                              ),
                            );
                          } else {
                            TxaToast.show(
                              context,
                              TxaLanguage.t('no_episodes'),
                              isError: true,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      // Interaction Icons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _IconBtn(
                            icon: (_data!['movie']['is_favorite'] == true)
                                ? Icons.favorite_rounded
                                : Icons.add_rounded,
                            color: (_data!['movie']['is_favorite'] == true)
                                ? Colors.red
                                : Colors.white,
                            label: TxaLanguage.t('add_favorite'),
                            onTap: _toggleFavorite,
                          ),
                          _IconBtn(
                            icon: Icons.download_rounded,
                            label: TxaLanguage.t('download'),
                            onTap: () => _showComingSoon(context),
                          ),
                          _IconBtn(
                            icon: Icons.share_rounded,
                            label: TxaLanguage.t('share'),
                            onTap: _shareMovie,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Badges
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (year.isNotEmpty) _SimpleBadge(text: year),
                          if (quality.isNotEmpty) _SimpleBadge(text: quality),
                          if (time.isNotEmpty) _SimpleBadge(text: time),
                          if (movie['imdb_score'] != null &&
                              double.tryParse(movie['imdb_score'].toString()) !=
                                  0)
                            _SimpleBadge(
                              text: 'IMDb ${movie['imdb_score']}',
                              color: Colors.orangeAccent,
                            ),
                          if (movie['tmdb_score'] != null &&
                              double.tryParse(movie['tmdb_score'].toString()) !=
                                  0)
                            _SimpleBadge(
                              text: 'TMDb ${movie['tmdb_score']}',
                              color: Colors.blueAccent,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Broadcast Banner
                      if (movie['broadcast_at'] != null &&
                          movie['status'] != 'completed')
                        _BroadcastBanner(movie: movie),

                      const SizedBox(height: 16),
                      // Category chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories
                            .take(3)
                            .map((cat) => _CatText(text: cat['name'] ?? ''))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      // Description
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
                            maxLines: _descExpanded ? null : 3,
                            overflow: _descExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: TxaTheme.textSecondary,
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _descExpanded = !_descExpanded),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _descExpanded
                                      ? TxaLanguage.t('collapse')
                                      : TxaLanguage.t('show_more'),
                                  style: const TextStyle(
                                    color: TxaTheme.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _descExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: TxaTheme.accent,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Tabs
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: TxaTheme.accent,
                    labelColor: TxaTheme.accent,
                    unselectedLabelColor: TxaTheme.textMuted,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    tabs: [
                      Tab(text: TxaLanguage.t('episodes')),
                      Tab(text: TxaLanguage.t('actors')),
                      Tab(text: TxaLanguage.t('recommendation')),
                    ],
                  ),
                ),
              ),

              // Tab View Content
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildEpisodesTab(servers),
                    if (_data!['movie']['actors'] != null &&
                        (_data!['movie']['actors'] as List).isNotEmpty)
                      _buildActorsTab(_data!['movie']['actors'])
                    else
                      Center(
                        child: Text(
                          TxaLanguage.t('no_actors'),
                          style: const TextStyle(color: TxaTheme.textMuted),
                        ),
                      ),
                    _buildRelatedTab(related),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Tablet Helpers
  Widget _buildTabletHeader(String bannerUrl) {
    return SliverToBoxAdapter(
      child: Stack(
        children: [
          SizedBox(
            height: 350,
            width: double.infinity,
            child: CachedNetworkImage(imageUrl: bannerUrl, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.transparent,
                    TxaTheme.primaryBg,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletInfo(
    String name,
    String year,
    String quality,
    String time,
    List categories,
    String content,
    dynamic movie,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                if (year.isNotEmpty) _SimpleBadge(text: year),
                if (quality.isNotEmpty) _SimpleBadge(text: quality),
                if (time.isNotEmpty) _SimpleBadge(text: time),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              content.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
              style: const TextStyle(
                color: TxaTheme.textSecondary,
                fontSize: 15,
                height: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletTabsSwitcher() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        TabBar(
          controller: _tabController,
          indicatorColor: TxaTheme.accent,
          labelColor: TxaTheme.accent,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            const SizedBox.shrink(), // Placeholder for episodes
            Tab(text: TxaLanguage.t('actors')),
            Tab(text: TxaLanguage.t('recommendation')),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodesTab(List servers) {
    if (servers.isEmpty) {
      return Center(
        child: Text(
          TxaLanguage.t('no_episodes'),
          style: const TextStyle(color: TxaTheme.textMuted),
        ),
      );
    }

    final currentServer = servers[_selectedServerIndex];
    final episodes = currentServer['server_data'] as List? ?? [];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_data!['seasons'] != null &&
                  (_data!['seasons'] as List).isNotEmpty)
                _SeasonPartPicker(
                  currentSlug: widget.slug,
                  seasons: _data!['seasons'] as List,
                  onSelected: (slug) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => MovieDetailScreen(slug: slug),
                      ),
                    );
                  },
                )
              else
                const SizedBox.shrink(),

              _ServerPicker(
                servers: servers,
                selectedIndex: _selectedServerIndex,
                onChanged: (idx) {
                  setState(() => _selectedServerIndex = idx);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 1.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: episodes.length,
              itemBuilder: (context, index) {
                final ep = episodes[index];
                final history = _data!['history'];
                final bool isActive =
                    history != null &&
                    history['episode_id'].toString() == ep['id'].toString();

                final epName = ep['name'].toString().replaceAll(
                  RegExp(r'[^0-9]'),
                  '',
                );
                final displayName = epName.isEmpty ? ep['name'] : epName;

                return GestureDetector(
                  onTap: () {
                    if (servers.isNotEmpty) {
                      // CLOSE MINI PLAYER IF ACTIVE
                      final miniProvider = context
                          .read<TxaMiniPlayerProvider>();
                      if (!miniProvider.isClosed) miniProvider.close();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => TxaPlayer(
                            movie: _data!['movie'],
                            servers: servers,
                            initialServerIndex: _selectedServerIndex,
                            initialEpisodeId: ep['id'].toString(),
                            initialTime: isActive
                                ? (history['current_time'] as num).toDouble()
                                : 0,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isActive ? TxaTheme.accent : TxaTheme.secondaryBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive ? TxaTheme.accent : Colors.white10,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: TxaTheme.accent.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      displayName,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedTab(List related) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.55,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: related.length,
        itemBuilder: (context, index) {
          final m = related[index];
          return GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (ctx) => MovieDetailScreen(slug: m['slug']),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CachedNetworkImage(
                            imageUrl: m['thumb_url'] ?? '',
                            fit: BoxFit.cover,
                            placeholder: (ctx, url) =>
                                Container(color: TxaTheme.secondaryBg),
                          ),
                        ),
                        if (m['year'] != null)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                m['year'].toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  m['name'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  m['origin_name'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TxaTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActorsTab(List actors) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: actors.length,
        itemBuilder: (context, index) {
          final actor = actors[index];
          return Column(
            children: [
              Expanded(
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: actor['thumb'] ?? '',
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) =>
                        Container(color: TxaTheme.secondaryBg),
                    errorWidget: (ctx, url, err) => Container(
                      color: TxaTheme.secondaryBg,
                      child: const Icon(Icons.person, color: Colors.white24),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                actor['name'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

void _showComingSoon(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: TxaTheme.secondaryBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: TxaTheme.accent,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            TxaLanguage.t('coming_soon'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            TxaLanguage.t('coming_soon_msg'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            TxaLanguage.t('ok'),
            style: const TextStyle(color: TxaTheme.accent),
          ),
        ),
      ],
    ),
  );
}

class _HeroActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _HeroActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color ?? Colors.white, size: 24),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: TxaTheme.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SimpleBadge extends StatelessWidget {
  final String text;
  final Color? color;
  const _SimpleBadge({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CatText extends StatelessWidget {
  final String text;
  const _CatText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(color: TxaTheme.textMuted, fontSize: 12),
      ),
    );
  }
}

class _DropdownBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _DropdownBtn({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: TxaTheme.secondaryBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: TxaTheme.textMuted, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down_rounded,
              color: TxaTheme.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerPicker extends StatelessWidget {
  final List servers;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _ServerPicker({
    required this.servers,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _DropdownBtn(
      label: servers[selectedIndex]['server_name'] ?? 'Server',
      icon: Icons.dns_rounded,
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: TxaTheme.primaryBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    TxaLanguage.t('select_server'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: servers.length,
                      itemBuilder: (ctx, i) {
                        final isSel = i == selectedIndex;
                        return ListTile(
                          title: Text(
                            servers[i]['server_name'],
                            style: TextStyle(
                              color: isSel ? TxaTheme.accent : Colors.white,
                            ),
                          ),
                          trailing: isSel
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: TxaTheme.accent,
                                )
                              : null,
                          onTap: () {
                            onChanged(i);
                            Navigator.pop(ctx);
                          },
                        );
                      },
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

class _SeasonPartPicker extends StatelessWidget {
  final String currentSlug;
  final List seasons;
  final ValueChanged<String> onSelected;

  const _SeasonPartPicker({
    required this.currentSlug,
    required this.seasons,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Find current season's name
    final currentSeason = seasons.firstWhere(
      (s) => s['slug'] == currentSlug,
      orElse: () => null,
    );
    final String label = currentSeason != null
        ? currentSeason['name']
        : TxaLanguage.t('series_parts');

    return _DropdownBtn(
      label: label,
      icon: Icons.layers_rounded,
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: TxaTheme.primaryBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    TxaLanguage.t('related_parts'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: seasons.length,
                      itemBuilder: (ctx, i) {
                        final s = seasons[i];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(
                              imageUrl: s['thumb_url'],
                              width: 40,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(
                            s['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            s['year']?.toString() ?? '',
                            style: const TextStyle(
                              color: TxaTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () {
                            onSelected(s['slug']);
                            Navigator.pop(ctx);
                          },
                        );
                      },
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

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: TxaTheme.primaryBg, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

class _BroadcastBanner extends StatefulWidget {
  final Map<String, dynamic> movie;
  const _BroadcastBanner({required this.movie});

  @override
  State<_BroadcastBanner> createState() => _BroadcastBannerState();
}

class _BroadcastBannerState extends State<_BroadcastBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _bellController;

  @override
  void initState() {
    super.initState();
    _bellController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _bellController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final broadcastAt = movie['broadcast_at'];
    if (broadcastAt == null) return const SizedBox.shrink();

    DateTime? targetDate;
    try {
      targetDate = DateTime.parse(broadcastAt).toLocal();
    } catch (_) {
      return const SizedBox.shrink();
    }

    if (targetDate.isBefore(DateTime.now())) return const SizedBox.shrink();

    final formattedTime = DateFormat(
      'HH:mm [dd-MM-yyyy]',
      TxaLanguage.currentLang,
    ).format(targetDate);
    String nextEp = (movie['next_episode_name'] ?? '').toString().trim();
    if (nextEp.isNotEmpty) {
      // Check if it already has "Tập" or "tap" prefix (case insensitive)
      final hasTapPrefix = RegExp(
        r'^(tập|episode)\s',
        caseSensitive: false,
      ).hasMatch(nextEp);

      if (!hasTapPrefix) {
        // Handle "4 vietsub" or just "4"
        final match = RegExp(r'^(\d+)\s*(.*)$').firstMatch(nextEp);
        if (match != null) {
          final number = match.group(1);
          final suffix = match.group(2)?.trim() ?? "";
          if (suffix.isNotEmpty) {
            final formattedSuffix =
                suffix[0].toUpperCase() + suffix.substring(1);
            nextEp = "${TxaLanguage.t('episode')} $number ($formattedSuffix)";
          } else {
            nextEp = "${TxaLanguage.t('episode')} $number";
          }
        }
      }
    }

    final epTotal =
        int.tryParse(movie['episode_total']?.toString() ?? '0') ?? 0;
    final isFinal =
        RegExp(
          r'end|full|kết thúc|kt|cuối',
          caseSensitive: false,
        ).hasMatch(nextEp) ||
        (epTotal > 0 && nextEp.contains(epTotal.toString()));

    String msg = "";
    if (isFinal) {
      msg = TxaLanguage.t('broadcast_final_msg')
          .replaceAll(
            '%prefix',
            nextEp.isEmpty ? TxaLanguage.t('final_ep') : nextEp,
          )
          .replaceAll('%time', formattedTime);
    } else if (nextEp.isNotEmpty) {
      msg = TxaLanguage.t(
        'broadcast_msg',
      ).replaceAll('%prefix', nextEp).replaceAll('%time', formattedTime);
    } else {
      msg = TxaLanguage.t(
        'broadcast_suffix',
      ).replaceAll('%time', formattedTime);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFFDB2777)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          RotationTransition(
            turns: TweenSequence<double>([
              TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.05), weight: 1),
              TweenSequenceItem(
                tween: Tween(begin: 0.05, end: -0.05),
                weight: 2,
              ),
              TweenSequenceItem(
                tween: Tween(begin: -0.05, end: 0.0),
                weight: 1,
              ),
              TweenSequenceItem(tween: ConstantTween(0.0), weight: 6),
            ]).animate(_bellController),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
