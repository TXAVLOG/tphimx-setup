import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tphimx_setup/services/txa_settings.dart';
import '../services/txa_download_manager.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../pages/download_manager_screen.dart';



class TxaDownloadMiniProgress extends StatefulWidget {
  const TxaDownloadMiniProgress({super.key});

  @override
  State<TxaDownloadMiniProgress> createState() =>
      _TxaDownloadMiniProgressState();
}

class _TxaDownloadMiniProgressState extends State<TxaDownloadMiniProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isDismissed = false;
  String _lastMovieIds = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Get all unique movies being downloaded
  List<_MovieDownloadInfo> _getMoviesInfo(TxaDownloadManager manager) {
    final activeTasks = manager.tasks
        .where(
          (t) =>
              t.status == DownloadStatus.downloading ||
              t.status == DownloadStatus.pending,
        )
        .toList();

    if (activeTasks.isEmpty) return [];

    // Group by movie
    final movieMap = <String, List<TxaDownloadTask>>{};
    for (var task in activeTasks) {
      movieMap.putIfAbsent(task.movieId, () => []).add(task);
    }

    return movieMap.entries.map((entry) {
      final tasks = entry.value;
      final firstTask = tasks.first;
      final totalProgress =
          tasks.fold(0.0, (sum, t) => sum + t.progress) / tasks.length;
      final downloadingTask = tasks.firstWhere(
        (t) => t.status == DownloadStatus.downloading,
        orElse: () => tasks.first,
      );

      return _MovieDownloadInfo(
        movieId: entry.key,
        movieTitle: firstTask.movieTitle,
        poster: firstTask.poster,
        totalEpisodes: tasks.length,
        currentEpisode: tasks.where((t) => t.progress > 0).length,
        overallProgress: totalProgress,
        statusDisplay: downloadingTask.statusDisplay,
        isHls: downloadingTask.isHls,
        downloadedSegments: downloadingTask.downloadedSegments,
        totalSegments: downloadingTask.totalSegments,
        isMerging: downloadingTask.isMerging,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TxaDownloadManager>(
      builder: (context, manager, child) {
        final moviesInfo = _getMoviesInfo(manager);
        final currentMovieIds = moviesInfo.map((m) => m.movieId).join(',');

        // Auto-show if new movies are added to download queue
        if (currentMovieIds != _lastMovieIds && moviesInfo.isNotEmpty) {
          _isDismissed = false;
          _lastMovieIds = currentMovieIds;
        }

        if (moviesInfo.isEmpty || _isDismissed) {
          _animationController.reverse();
          return const SizedBox.shrink();
        }

        _animationController.forward();

        // Position it above the TxaNav
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final bottomMargin = bottomPadding > 0 ? bottomPadding + 12.0 : 24.0;
        final navHeight = 66.0;
        final floatBottom = bottomMargin + navHeight + 12.0;

        return Positioned(
          bottom: floatBottom,
          left: 16,
          right: 16,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Opacity(
                opacity: _animationController.value,
                child: Transform.translate(
                  offset: Offset(0, 30 * (1 - _animationController.value)),
                  child: Material(
                    type: MaterialType.transparency,
                    child: child,
                  ),
                ),
              );
            },
            child: GestureDetector(
              onTap: () {
                TxaSettings.navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (ctx) => const DownloadManagerScreen(),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: TxaTheme.accent.withValues(alpha: 0.25),
                      blurRadius: 20,
                      spreadRadius: -5,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1E293B).withValues(alpha: 0.9),
                            const Color(0xFF0F172A).withValues(alpha: 0.95),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: TxaTheme.accent.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header - Show count if multiple movies
                          if (moviesInfo.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: TxaTheme.accent.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.downloading_rounded,
                                          color: TxaTheme.accent,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          TxaLanguage.t(
                                            'downloading_count',
                                            replace: {
                                              'n': moviesInfo.length.toString(),
                                            },
                                          ),
                                          style: TextStyle(
                                            color: TxaTheme.accent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${moviesInfo.fold(0, (sum, m) => sum + m.currentEpisode)}/${moviesInfo.fold(0, (sum, m) => sum + m.totalEpisodes)} tập',
                                    style: const TextStyle(
                                      color: TxaTheme.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => setState(() => _isDismissed = true),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: Colors.white.withValues(alpha: 0.5),
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Movie info - show first movie or list
                          _buildMovieItem(
                            moviesInfo.first,
                            moviesInfo.length == 1,
                          ),

                          // If multiple movies, show indicator
                          if (moviesInfo.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ...moviesInfo
                                      .take(5)
                                      .map(
                                        (m) => Container(
                                          width: 6,
                                          height: 6,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: m.overallProgress >= 1
                                                ? Colors.greenAccent
                                                : TxaTheme.accent.withValues(
                                                    alpha: 0.6,
                                                  ),
                                          ),
                                        ),
                                      ),
                                  if (moviesInfo.length > 5)
                                    Text(
                                      ' +${moviesInfo.length - 5}',
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
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMovieItem(_MovieDownloadInfo info, bool isSingle) {
    return Row(
      children: [
        // Movie Poster with progress ring
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                value: info.overallProgress,
                strokeWidth: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  info.overallProgress >= 1
                      ? Colors.greenAccent
                      : TxaTheme.accent,
                ),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                  image: NetworkImage(info.poster),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Play icon if completed
            if (info.overallProgress >= 1)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.greenAccent,
                  size: 24,
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),

        // Text Info
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.movieTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),

              // Episode progress text
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isSingle
                          ? '${info.currentEpisode}/${info.totalEpisodes} tập • ${info.statusDisplay}'
                          : info.statusDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: info.isMerging
                            ? Colors.orangeAccent
                            : TxaTheme.textMuted,
                        fontSize: 11,
                        fontWeight: info.isMerging
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: info.overallProgress,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    info.overallProgress >= 1
                        ? Colors.greenAccent
                        : info.isMerging
                        ? Colors.orangeAccent
                        : TxaTheme.accent,
                  ),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        isSingle
            ? GestureDetector(
                onTap: () => setState(() => _isDismissed = true),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              )
            : const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
                size: 20,
              ),
      ],
    );
  }
}

class _MovieDownloadInfo {
  final String movieId;
  final String movieTitle;
  final String poster;
  final int totalEpisodes;
  final int currentEpisode;
  final double overallProgress;
  final String statusDisplay;
  final bool isHls;
  final int downloadedSegments;
  final int totalSegments;
  final bool isMerging;

  _MovieDownloadInfo({
    required this.movieId,
    required this.movieTitle,
    required this.poster,
    required this.totalEpisodes,
    required this.currentEpisode,
    required this.overallProgress,
    required this.statusDisplay,
    required this.isHls,
    required this.downloadedSegments,
    required this.totalSegments,
    required this.isMerging,
  });
}
