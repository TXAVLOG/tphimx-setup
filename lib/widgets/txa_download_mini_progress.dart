import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/txa_download_manager.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../pages/download_manager_screen.dart';

class TxaDownloadMiniProgress extends StatelessWidget {
  const TxaDownloadMiniProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TxaDownloadManager>(
      builder: (context, manager, child) {
        final activeTasks = manager.tasks
            .where((t) =>
                t.status == DownloadStatus.downloading ||
                t.status == DownloadStatus.pending)
            .toList();

        if (activeTasks.isEmpty) return const SizedBox.shrink();

        // Calculate overall stats
        int totalEpisodes = activeTasks.length;
        double overallProgress = 0;
        if (totalEpisodes > 0) {
          overallProgress =
              activeTasks.fold(0.0, (sum, t) => sum + t.progress) /
              totalEpisodes;
        }

        // Get the first active task for display
        final firstTask = activeTasks.first;

        // Position it above the TxaNav
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final bottomMargin = bottomPadding > 0 ? bottomPadding + 12.0 : 24.0;
        final navHeight = 66.0;
        final floatBottom = bottomMargin + navHeight + 12.0;

        return Positioned(
          bottom: floatBottom,
          left: 20,
          right: 20,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              onTap: () {
                // Navigate to download manager
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => const DownloadManagerScreen(),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: TxaTheme.accent.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: TxaTheme.accent.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Movie Poster or Download Icon
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: TxaTheme.cardBg,
                                borderRadius: BorderRadius.circular(10),
                                image: DecorationImage(
                                  image: NetworkImage(firstTask.poster),
                                  fit: BoxFit.cover,
                                  colorFilter: ColorFilter.mode(
                                    Colors.black.withValues(alpha: 0.2),
                                    BlendMode.darken,
                                  ),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.download_rounded,
                              color: Colors.white,
                              size: 20,
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
                                activeTasks.length > 1
                                    ? TxaLanguage.t(
                                        'download_summary',
                                        replace: {
                                          'n': activeTasks.length.toString(),
                                        },
                                      )
                                    : firstTask.movieTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: overallProgress,
                                        backgroundColor: Colors.white10,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                          TxaTheme.accent,
                                        ),
                                        minHeight: 4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${(overallProgress * 100).toInt()}%",
                                    style: const TextStyle(
                                      color: TxaTheme.accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Close/Dismiss maybe? Or just a "Go" icon
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: TxaTheme.textMuted,
                        ),
                      ],
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
}
