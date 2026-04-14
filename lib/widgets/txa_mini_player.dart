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
  Offset _offset = const Offset(-20, -100); // Default bottom-right (relative to screen dimensions)
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
        if (provider.isClosed || !provider.isMini) return const SizedBox.shrink();

        return AnimatedPositioned(
          duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
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
              // Snap to edges if needed logic could go here
            },
            onTap: () => _restoreToFull(context, provider),
            child: TxaTheme.glassConnector(
              radius: 20,
              padding: const EdgeInsets.all(8),
              child: Container(
                width: 220,
                height: 124,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: -5,
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Video content
                      IgnorePointer(
                        child: BetterPlayer(
                          controller: provider.controller!,
                        ),
                      ),
                      
                      // Overlay Controls (Gradient)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black26, Colors.black.withValues(alpha: 0.7)],
                            ),
                          ),
                        ),
                      ),
                      
                      // Title & Episode
                      Positioned(
                        top: 8, left: 10, right: 30,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.movie['name'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "${TxaLanguage.t('episode')} ${provider.episodeIndex + 1}",
                              style: TextStyle(color: TxaTheme.accent.withValues(alpha: 0.9), fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),

                      // CLOSE BUTTON
                      Positioned(
                        top: 4, right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => provider.close(),
                        ),
                      ),

                      // CENTER ACTIONS
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _MiniIcon(
                              icon: Icons.replay_10_rounded,
                              onTap: () => provider.controller?.seekTo(
                                provider.controller!.videoPlayerController!.value.position - const Duration(seconds: 10)
                              ),
                            ),
                            const SizedBox(width: 16),
                            _MiniIcon(
                              icon: provider.controller!.videoPlayerController!.value.isPlaying 
                                ? Icons.pause_rounded 
                                : Icons.play_arrow_rounded,
                              size: 28,
                              onTap: () => setState(() => provider.playPause()),
                            ),
                            const SizedBox(width: 16),
                            _MiniIcon(
                              icon: Icons.fullscreen_rounded,
                              onTap: () => _restoreToFull(context, provider),
                            ),
                          ],
                        ),
                      ),
                      
                      // PROGRESS BAR (Minimal)
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: _MiniProgressBar(controller: provider.controller!),
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

class _MiniIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _MiniIcon({required this.icon, required this.onTap, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white10,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
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
