import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/txa_download_manager.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_format.dart';
import '../widgets/txa_player.dart';

class DownloadEpisodesScreen extends StatelessWidget {
  final String movieId;
  final String movieTitle;
  final String poster;

  const DownloadEpisodesScreen({
    super.key,
    required this.movieId,
    required this.movieTitle,
    required this.poster,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      body: Consumer<TxaDownloadManager>(
        builder: (context, manager, child) {
          final tasks = manager.tasks
              .where((t) => t.movieId == movieId)
              .toList();

          if (tasks.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) Navigator.pop(context);
            });
            return const SizedBox.shrink();
          }

          final completedCount = tasks
              .where((t) => t.status == DownloadStatus.completed)
              .length;
          final totalCount = tasks.length;
          final totalBytes = tasks.fold<int>(0, (sum, t) => sum + t.totalBytes);

          return CustomScrollView(
            slivers: [
              // Hero header with movie poster
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: TxaTheme.primaryBg,
                iconTheme: const IconThemeData(color: Colors.white),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    movieTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        poster,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: TxaTheme.cardBg,
                          child: const Icon(
                            Icons.movie_outlined,
                            color: TxaTheme.textMuted,
                            size: 64,
                          ),
                        ),
                      ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              TxaTheme.primaryBg.withValues(alpha: 0.7),
                              TxaTheme.primaryBg,
                            ],
                            stops: const [0.0, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white,
                    ),
                    color: TxaTheme.cardBg,
                    onSelected: (value) {
                      if (value == 'delete_all') {
                        _showDeleteAllDialog(context, manager);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'delete_all',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_sweep_rounded,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              TxaLanguage.t('delete_movie_confirm'),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Stats bar
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: TxaTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TxaTheme.glassBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat(
                        Icons.download_done_rounded,
                        '$completedCount/$totalCount',
                        TxaLanguage.t('episodes'),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: TxaTheme.glassBorder,
                      ),
                      _buildStat(
                        Icons.storage_rounded,
                        TxaFormat.formatFileSize(totalBytes),
                        TxaLanguage.t('total'),
                      ),
                    ],
                  ),
                ),
              ),

              // Episode list
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final task = tasks[index];
                    return _buildEpisodeTile(context, task, manager);
                  }, childCount: tasks.length),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: TxaTheme.accent, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: TxaTheme.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildEpisodeTile(
    BuildContext context,
    TxaDownloadTask task,
    TxaDownloadManager manager,
  ) {
    final isDone = task.status == DownloadStatus.completed;
    final isError = task.status == DownloadStatus.error;
    final isDownloading = task.status == DownloadStatus.downloading;
    final isPaused = task.status == DownloadStatus.paused;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: TxaTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone
              ? TxaTheme.accent.withValues(alpha: 0.3)
              : TxaTheme.glassBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isDone
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TxaPlayer(
                        movie: {'id': task.movieId, 'name': task.movieTitle},
                        servers: [],
                        initialEpisodeId: task.episodeId,
                        localPath: task.savePath,
                        localTitle: task.episodeTitle,
                      ),
                    ),
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Status icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDone
                        ? TxaTheme.accent.withValues(alpha: 0.1)
                        : isError
                        ? Colors.redAccent.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isDone
                        ? Icons.play_circle_fill_rounded
                        : isError
                        ? Icons.error_outline_rounded
                        : isDownloading
                        ? Icons.downloading_rounded
                        : Icons.pause_circle_outline_rounded,
                    color: isDone
                        ? TxaTheme.accent
                        : isError
                        ? Colors.redAccent
                        : Colors.white70,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.episodeTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isDone)
                        Text(
                          task.totalBytes > 0
                              ? TxaFormat.formatFileSize(task.totalBytes)
                              : TxaLanguage.t('download_completed'),
                          style: const TextStyle(
                            color: TxaTheme.textMuted,
                            fontSize: 11,
                          ),
                        )
                      else if (isError)
                        Text(
                          task.error ?? TxaLanguage.t('error'),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else ...[
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: task.progress,
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              TxaTheme.accent,
                            ),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _buildProgressText(task),
                          style: const TextStyle(
                            color: TxaTheme.textMuted,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Actions
                if (isDownloading)
                  IconButton(
                    onPressed: () => manager.pauseTask(task.id),
                    icon: const Icon(
                      Icons.pause_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
                    visualDensity: VisualDensity.compact,
                  )
                else if (isPaused || isError)
                  IconButton(
                    onPressed: () => manager.resumeTask(task.id),
                    icon: Icon(
                      Icons.play_arrow_rounded,
                      color: isError ? Colors.redAccent : Colors.white70,
                      size: 22,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),

                IconButton(
                  onPressed: () => manager.removeTask(task.id),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: TxaTheme.textMuted,
                    size: 18,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildProgressText(TxaDownloadTask task) {
    if (task.status == DownloadStatus.downloading) {
      final parts = <String>[];
      parts.add(task.statusDisplay);
      if (task.networkSpeed > 0) {
        parts.add(TxaFormat.formatSpeed(task.networkSpeed)['display']);
      }
      if (task.timeRemaining != null && task.timeRemaining!.inSeconds > 0) {
        parts.add('ETA ${TxaFormat.formatDuration(task.timeRemaining!.inSeconds)}');
      }
      if (task.totalBytes > 0) {
        parts.add('${TxaFormat.formatFileSize(task.downloadedBytes)} / ${TxaFormat.formatFileSize(task.totalBytes)}');
      }
      return parts.join(' • ');
    }
    return task.statusDisplay;
  }

  void _showDeleteAllDialog(BuildContext context, TxaDownloadManager manager) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxaTheme.cardBg,
        title: Text(
          TxaLanguage.t('delete_movie_confirm'),
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
              manager.removeMovie(movieId);
              Navigator.pop(context);
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
