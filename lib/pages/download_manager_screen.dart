import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/txa_download_manager.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import 'download_episodes_screen.dart';

class DownloadManagerScreen extends StatefulWidget {
  final bool isOfflineMode;
  const DownloadManagerScreen({super.key, this.isOfflineMode = false});

  @override
  State<DownloadManagerScreen> createState() => _DownloadManagerScreenState();
}

class _DownloadManagerScreenState extends State<DownloadManagerScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedMovies = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.4),
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        automaticallyImplyLeading: !widget.isOfflineMode,
        title: Text(
          TxaLanguage.t('download_manager'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: Colors.redAccent,
              ),
              onPressed: _showDeleteConfirm,
              tooltip: TxaLanguage.t('delete'),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedMovies.clear();
              }),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.select_all_rounded, color: Colors.white),
              onPressed: () => setState(() => _isSelectionMode = true),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<TxaDownloadManager>(
        builder: (context, manager, child) {
          // Group tasks by movieId
          final Map<String, List<TxaDownloadTask>> grouped = {};
          for (var task in manager.tasks) {
            grouped.putIfAbsent(task.movieId, () => []).add(task);
          }

          if (grouped.isEmpty) {
            return _buildEmptyState();
          }

          final movieIds = grouped.keys.toList();

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [TxaTheme.primaryBg, Color(0xFF0F172A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
                // Stats Header
                SliverToBoxAdapter(
                  child: _buildStatsHeader(manager, movieIds.length),
                ),
                // Grid
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 20,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final mid = movieIds[index];
                        final movieTasks = grouped[mid]!;
                        return _buildMovieCard(mid, movieTasks);
                      },
                      childCount: movieIds.length,
                    ),
                  ),
                ),
              ],
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
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.download_for_offline_outlined,
              size: 80,
              color: TxaTheme.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            TxaLanguage.t('no_history'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            TxaLanguage.t('no_history_msg'),
            style: const TextStyle(color: TxaTheme.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(TxaDownloadManager manager, int movieCount) {
    int downloadingCount = manager.tasks
        .where((t) => t.status == DownloadStatus.downloading)
        .length;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatItem(
            Icons.movie_filter_rounded,
            movieCount.toString(),
            TxaLanguage.t('movies'),
          ),
          const SizedBox(width: 12),
          _buildStatItem(
            Icons.downloading_rounded,
            downloadingCount.toString(),
            TxaLanguage.t('downloading'),
            color: TxaTheme.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color ?? Colors.white70, size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: TxaTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieCard(String mid, List<TxaDownloadTask> tasks) {
    final firstTask = tasks.first;
    final completedCount = tasks.where((t) => t.status == DownloadStatus.completed).length;
    final totalCount = tasks.length;
    final isAllDone = completedCount == totalCount;
    final isSelected = _selectedMovies.contains(mid);

    double overallProgress = 0;
    if (totalCount > 0) {
      overallProgress = tasks.fold(0.0, (sum, t) => sum + t.progress) / totalCount;
    }

    final activeTask = tasks.firstWhere(
      (t) => t.status == DownloadStatus.downloading,
      orElse: () => firstTask,
    );

    return GestureDetector(
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedMovies.add(mid);
          });
        }
      },
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedMovies.remove(mid);
              if (_selectedMovies.isEmpty) _isSelectionMode = false;
            } else {
              _selectedMovies.add(mid);
            }
          });
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DownloadEpisodesScreen(
                movieId: mid,
                movieTitle: firstTask.movieTitle,
                poster: firstTask.poster,
              ),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: TxaTheme.cardBg,
          border: Border.all(
            color: isSelected ? TxaTheme.accent : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: TxaTheme.accent.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Poster
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: firstTask.poster,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: TxaTheme.cardBg),
                  errorWidget: (context, url, error) => Container(
                    color: TxaTheme.cardBg,
                    child: const Icon(Icons.error, color: Colors.white10),
                  ),
                ),
              ),
              // Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.9),
                      ],
                      stops: const [0.5, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              // Info
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      firstTask.movieTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (!isAllDone) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: overallProgress,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(TxaTheme.accent),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        TxaLanguage.t('episodes_completed', replace: {
                          'c': completedCount.toString(),
                          't': totalCount.toString(),
                        }),
                        style: const TextStyle(color: TxaTheme.accent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ] else
                      Text(
                        TxaLanguage.t('episode_count_label', replace: {'n': totalCount.toString()}),
                        style: const TextStyle(color: TxaTheme.textMuted, fontSize: 10),
                      ),
                  ],
                ),
              ),
              // Status Badge
              if (activeTask.status == DownloadStatus.downloading)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: TxaTheme.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: TxaTheme.accent.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.downloading_rounded, color: Colors.white, size: 16),
                  ),
                ),
              // Selection Checkbox
              if (_isSelectionMode)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? TxaTheme.accent : Colors.black45,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(
                      isSelected ? Icons.check_rounded : null,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirm() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: TxaTheme.secondaryBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              TxaLanguage.t('delete_all_confirm'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              TxaLanguage.t('delete_selected_movies_msg'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: TxaTheme.textMuted),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(TxaLanguage.t('cancel'), style: const TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      for (var mid in _selectedMovies) {
                        TxaDownloadManager().removeMovie(mid);
                      }
                      setState(() {
                        _isSelectionMode = false;
                        _selectedMovies.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(TxaLanguage.t('delete'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
