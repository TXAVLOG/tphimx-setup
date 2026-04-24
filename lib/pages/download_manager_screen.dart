import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/txa_download_manager.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';

class DownloadManagerScreen extends StatefulWidget {
  const DownloadManagerScreen({super.key});

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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          TxaLanguage.t('download_manager'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
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
        ],
      ),
      body: Consumer<TxaDownloadManager>(
        builder: (context, manager, child) {
          // Group tasks by movieId
          final Map<String, List<DownloadTask>> grouped = {};
          for (var task in manager.tasks) {
            grouped.putIfAbsent(task.movieId, () => []).add(task);
          }

          if (grouped.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.download_for_offline_outlined,
                    size: 64,
                    color: TxaTheme.textMuted,
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

          final movieIds = grouped.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: movieIds.length,
            itemBuilder: (context, index) {
              final mid = movieIds[index];
              final movieTasks = grouped[mid]!;
              final firstTask = movieTasks.first;

              final completedCount = movieTasks
                  .where((t) => t.status == DownloadStatus.completed)
                  .length;
              final totalCount = movieTasks.length;
              final isAllDone = completedCount == totalCount;

              // Calculate overall progress for overlay fill effect
              double overallProgress = 0;
              if (totalCount > 0) {
                overallProgress =
                    (movieTasks.fold(0.0, (sum, t) => sum + t.progress)) /
                    (totalCount * 100);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    if (_isSelectionMode) {
                      setState(() {
                        if (_selectedMovies.contains(mid)) {
                          _selectedMovies.remove(mid);
                        } else {
                          _selectedMovies.add(mid);
                        }
                      });
                    } else {
                      // Show detailed episode list for this movie
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: TxaTheme.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedMovies.contains(mid)
                            ? TxaTheme.accent
                            : TxaTheme.glassBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Movie Poster with Fill-up Overlay
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(12),
                              ),
                              child: CachedNetworkImage(
                                imageUrl: firstTask.poster,
                                width: 70,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            // FILL-UP OVERLAY EFFECT
                            if (!isAllDone)
                              ClipRRect(
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(12),
                                ),
                                child: Container(
                                  width: 70,
                                  height: 100,
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    height: 100 * (1 - overallProgress),
                                    color: Colors.black.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            if (!isAllDone)
                              const Positioned.fill(
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: TxaTheme.accent,
                                    ),
                                  ),
                                ),
                              ),
                            if (_isSelectionMode)
                              Positioned(
                                top: 4,
                                left: 4,
                                child: Icon(
                                  _selectedMovies.contains(mid)
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: TxaTheme.accent,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                firstTask.movieTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                TxaLanguage.t(
                                  'downloaded_series_progress',
                                  replace: {
                                    'p': (overallProgress * 100)
                                        .toInt()
                                        .toString(),
                                    'c': completedCount.toString(),
                                    't': totalCount.toString(),
                                  },
                                ),
                                style: const TextStyle(
                                  color: TxaTheme.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (!isAllDone)
                                Row(
                                  children: [
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: overallProgress,
                                        backgroundColor: Colors.white10,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              TxaTheme.accent,
                                            ),
                                        minHeight: 4,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Priority button
                                    GestureDetector(
                                      onTap: () => manager.prioritizeMovie(mid),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: TxaTheme.accent.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: TxaTheme.accent.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          TxaLanguage.t('priority_download'),
                                          style: const TextStyle(
                                            color: TxaTheme.accent,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showMovieActions(mid),
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: TxaTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showMovieActions(String movieId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TxaTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
            ),
            title: Text(
              TxaLanguage.t('delete_movie_confirm'),
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(ctx);
              TxaDownloadManager().removeMovie(movieId);
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxaTheme.cardBg,
        title: Text(
          TxaLanguage.t('delete_all_confirm'),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(TxaLanguage.t('cancel')),
          ),
          TextButton(
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
            child: const Text('Xóa', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
