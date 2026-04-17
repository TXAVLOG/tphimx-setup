import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:better_player_plus/better_player_plus.dart';
import '../services/txa_mini_player_provider.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import 'txa_player.dart';

class TxaMiniPlayer extends StatefulWidget {
  const TxaMiniPlayer({super.key});

  @override
  State<TxaMiniPlayer> createState() => _TxaMiniPlayerState();
}

class _TxaMiniPlayerState extends State<TxaMiniPlayer> {
  Offset _offset = const Offset(
    -20,
    -100,
  ); // Default bottom-right (relative to screen dimensions)
  bool _isDragging = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize offset based on screen size if not set
    final size = MediaQuery.of(context).size;
    if (_offset.dx < 0) {
      _offset = Offset(size.width - 240, size.height - 180);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TxaMiniPlayerProvider>(
      builder: (context, provider, child) {
        if (provider.isClosed || !provider.isMini) {
          return const SizedBox.shrink();
        }

        return AnimatedPositioned(
          duration: _isDragging
              ? Duration.zero
              : const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          left: _offset.dx,
          top: _offset.dy,
          child: GestureDetector(
            onPanStart: (_) => setState(() => _isDragging = true),
            onPanUpdate: (details) {
              setState(() {
                _offset += details.delta;
              });
            },
            onPanEnd: (details) {
              setState(() => _isDragging = false);
              final size = MediaQuery.of(context).size;
              // Snap to nearest side (240 width + 16 margin)
              double targetX = _offset.dx < size.width / 2
                  ? 16
                  : size.width - 256;
              double targetY = _offset.dy.clamp(60.0, size.height - 180.0);
              setState(() {
                _offset = Offset(targetX, targetY);
              });
            },
            onTap: () => _restoreToFull(context, provider),
            child: Container(
              width: 240,
              height: 135,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 25,
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: TxaTheme.glassConnector(
                radius: 16,
                padding: const EdgeInsets.all(3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      // Video content or Placeholder
                      Positioned.fill(
                        child: provider.controller != null
                            ? BetterPlayer(controller: provider.controller!)
                            : Container(
                                color: TxaTheme.cardBg,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: TxaTheme.accent,
                                  ),
                                ),
                              ),
                      ),

                      // Overlay Controls (Subtle Gradient)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.1),
                                Colors.black.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Status Info (Ultra Compact)
                      Positioned(
                        top: 6,
                        left: 10,
                        right: 30,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.movie['name'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(blurRadius: 4, color: Colors.black),
                                ],
                              ),
                            ),
                            Text(
                              "${TxaLanguage.t('episode')} ${provider.episodeName}",
                              style: TextStyle(
                                color: TxaTheme.accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // CLOSE BUTTON (Tiny)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => provider.close(),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(5.0),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white70,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // PLAY/PAUSE (Center)
                      Center(
                        child: InkWell(
                          onTap: () => setState(() => provider.playPause()),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Icon(
                              provider
                                          .controller
                                          ?.videoPlayerController
                                          ?.value
                                          .isPlaying ==
                                      true
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),

                      // PROGRESS LINE (Thinnest)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _MiniProgressBar(
                          controller: provider.controller!,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _restoreToFull(BuildContext context, TxaMiniPlayerProvider provider) {
    final movie = provider.movie;
    final controller = provider.controller;
    if (controller == null) return;

    // We don't want to dispose the controller when leaving this "mini" mode
    // but the full TxaPlayer expects to initialize its own.
    // To solve this, we will pass the existing controller to TxaPlayer.

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => TxaPlayer(
          movie: movie,
          servers: provider.servers ?? [],
          initialServerIndex: provider.serverIndex,
          existingController: controller,
        ),
      ),
    );
    provider.switchToFull();
  }
}

class _MiniProgressBar extends StatelessWidget {
  final BetterPlayerController controller;
  const _MiniProgressBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.videoPlayerController!,
      builder: (context, value, child) {
        final duration = value.duration?.inMilliseconds ?? 0;
        final position = value.position.inMilliseconds;
        double progress = 0;
        if (duration > 0) progress = position / duration;

        return LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white12,
          color: TxaTheme.accent,
          minHeight: 2,
        );
      },
    );
  }
}
