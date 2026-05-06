import 'dart:ui';
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

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context, tasks),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final task = tasks[index];
                      return _buildEpisodeItem(context, task, manager);
                    },
                    childCount: tasks.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, List<TxaDownloadTask> tasks) {
    final completedCount = tasks.where((t) => t.status == DownloadStatus.completed).length;
    final totalCount = tasks.length;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: TxaTheme.primaryBg,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        title: Text(
          movieTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            shadows: [Shadow(color: Colors.black87, blurRadius: 12)],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(poster, fit: BoxFit.cover),
            // Gradient overlays
            Container(
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
            // Glass Summary Card
            Positioned(
              bottom: 60,
              left: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryStat(Icons.check_circle_outline_rounded, completedCount.toString(), TxaLanguage.t('downloaded')),
                        Container(width: 1, height: 30, color: Colors.white10),
                        _buildSummaryStat(Icons.video_library_outlined, totalCount.toString(), TxaLanguage.t('episodes')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
          onPressed: () => _showDeleteAllConfirm(context),
        ),
      ],
    );
  }

  Widget _buildSummaryStat(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, color: TxaTheme.accent, size: 14),
            const SizedBox(width: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        Text(label, style: const TextStyle(color: TxaTheme.textMuted, fontSize: 10)),
      ],
    );
  }

  Widget _buildEpisodeItem(BuildContext context, TxaDownloadTask task, TxaDownloadManager manager) {
    final bool isDownloading = task.status == DownloadStatus.downloading;
    final bool isCompleted = task.status == DownloadStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDownloading ? TxaTheme.accent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isCompleted ? () => _playEpisode(context, task) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Status Icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getStatusColor(task.status).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getStatusIcon(task.status),
                          color: _getStatusColor(task.status),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.episodeTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isCompleted ? TxaLanguage.t('downloaded') : task.statusDisplay,
                              style: TextStyle(
                                color: isDownloading ? TxaTheme.accent : TxaTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Action buttons
                      if (isCompleted)
                        const Icon(Icons.play_circle_filled_rounded, color: TxaTheme.accent, size: 32)
                      else if (isDownloading)
                        IconButton(
                          icon: const Icon(Icons.pause_circle_filled_rounded, color: Colors.white70),
                          onPressed: () => manager.pauseTask(task.id),
                        )
                      else if (task.status == DownloadStatus.paused)
                        IconButton(
                          icon: const Icon(Icons.play_circle_filled_rounded, color: TxaTheme.accent),
                          onPressed: () => manager.resumeTask(task.id),
                        ),
                      
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: TxaTheme.textMuted),
                        onSelected: (val) {
                          if (val == 'delete') manager.removeTask(task.id);
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 12),
                                Text(TxaLanguage.t('delete')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (isDownloading || task.status == DownloadStatus.paused) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: task.progress,
                              minHeight: 6,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                task.status == DownloadStatus.paused ? Colors.grey : TxaTheme.accent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "${(task.progress * 100).toInt()}%",
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (isDownloading) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniStat(Icons.speed_rounded, TxaFormat.formatSpeed(task.networkSpeed)['display']),
                          _buildMiniStat(
                            Icons.timer_outlined, 
                            task.timeRemaining != null ? TxaFormat.formatTime(task.timeRemaining!.inSeconds) : '--:--'
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: TxaTheme.textMuted, size: 12),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: TxaTheme.textMuted, fontSize: 10)),
      ],
    );
  }

  IconData _getStatusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.completed: return Icons.check_rounded;
      case DownloadStatus.downloading: return Icons.downloading_rounded;
      case DownloadStatus.paused: return Icons.pause_rounded;
      case DownloadStatus.error: return Icons.error_outline_rounded;
      case DownloadStatus.pending: return Icons.schedule_rounded;
    }
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.completed: return Colors.greenAccent;
      case DownloadStatus.downloading: return TxaTheme.accent;
      case DownloadStatus.paused: return Colors.orangeAccent;
      case DownloadStatus.error: return Colors.redAccent;
      case DownloadStatus.pending: return Colors.blueAccent;
    }
  }

  void _playEpisode(BuildContext context, TxaDownloadTask task) {
    if (task.savePath == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => TxaPlayer(
          movie: {
            'id': task.movieId,
            'name': task.movieTitle,
            'poster_url': task.poster,
          },
          servers: const [], // Required parameter
          localPath: task.savePath,
          localTitle: task.episodeTitle,
        ),
      ),
    );
  }

  void _showDeleteAllConfirm(BuildContext context) {
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
              TxaLanguage.t('delete_all_episodes_msg'),
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
                      TxaDownloadManager().removeMovie(movieId);
                      Navigator.pop(context); // Back to manager screen
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
