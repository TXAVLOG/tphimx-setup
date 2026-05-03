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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: !widget.isOfflineMode,
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
          final Map<String, List<TxaDownloadTask>> grouped = {};
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

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
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

              double overallProgress = 0;
              if (totalCount > 0) {
                overallProgress =
                    (movieTasks.fold(0.0, (sum, t) => sum + t.progress)) /
                    totalCount;
              }

              final activeTask = movieTasks.firstWhere(
                (t) => t.status == DownloadStatus.downloading,
                orElse: () => firstTask,
              );

              final isSelected = _selectedMovies.contains(mid);

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? TxaTheme.accent
                                    : TxaTheme.glassBorder,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: TxaTheme.accent.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                imageUrl: firstTask.poster,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                placeholder: (context, url) => Container(
                                  color: TxaTheme.cardBg,
                                  child: const Center(
                                    child: Icon(
                                      Icons.movie_outlined,
                                      color: TxaTheme.textMuted,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: TxaTheme.cardBg,
                                  child: const Center(
                                    child: Icon(
                                      Icons.error_outline_rounded,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Gradient Overlay for text readability if needed, but here we use a separate label

                          // Download Progress Overlay
                          if (!isAllDone)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.black45,
                                ),
                                child: Center(
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: CircularProgressIndicator(
                                          value: overallProgress,
                                          strokeWidth: 3,
                                          backgroundColor: Colors.white24,
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                Color
                                              >(TxaTheme.accent),
                                        ),
                                      ),
                                      Text(
                                        "${(overallProgress * 100).toInt()}%",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          // Episode count badge
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                TxaLanguage.t(
                                  'episode_count_label',
                                  replace: {'n': totalCount.toString()},
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          if (_isSelectionMode)
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: TxaTheme.accent,
                                size: 22,
                                shadows: const [
                                  Shadow(color: Colors.black87, blurRadius: 4),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      firstTask.movieTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeTask.statusDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: activeTask.status == DownloadStatus.downloading
                            ? TxaTheme.accent
                            : TxaTheme.textMuted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
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
            child: Text(
              TxaLanguage.t('delete'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
