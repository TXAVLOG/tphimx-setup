import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:better_player_plus/better_player_plus.dart';
import '../services/txa_mini_player_provider.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_logger.dart';
import '../services/txa_api.dart';
import '../services/txa_settings.dart';
import 'txa_player.dart';
import 'dart:async';
import 'dart:io';
import 'package:floating/floating.dart';

class TxaMiniPlayer extends StatefulWidget {
  const TxaMiniPlayer({super.key});

  @override
  State<TxaMiniPlayer> createState() => _TxaMiniPlayerState();
}

class _TxaMiniPlayerState extends State<TxaMiniPlayer> with WidgetsBindingObserver {
  // Mini-player dimensions - Optimized for 16:9
  static const double miniWidth = 300;
  static const double miniHeight = 168;
  static const double miniMargin = 20;

  Offset _offset = const Offset(-1, -1);
  bool _isDragging = false;
  Timer? _historySyncTimer;
  final Floating _floating = Floating();
  final GlobalKey _miniPlayerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _startHistorySync();
    WidgetsBinding.instance.addObserver(this);
    _enableAutoPiP();

    TxaSettings().addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    if (TxaSettings.autoPiP) {
      _enableAutoPiP();
    } else {
      _floating.cancelOnLeavePiP();
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (!Platform.isAndroid) return;
      
      final provider = Provider.of<TxaMiniPlayerProvider>(context, listen: false);
      if (provider.isClosed || !provider.isMini || provider.controller == null) return;
      
      final isPlaying = provider.controller!.videoPlayerController?.value.isPlaying ?? false;
      
      if (TxaSettings.autoPiP && isPlaying) {
        try {
          provider.controller!.enablePictureInPicture(_miniPlayerKey);
        } catch (e) {
          debugPrint('Mini PiP Error: $e');
        }
      } else {
        _floating.cancelOnLeavePiP();
      }
    } else if (state == AppLifecycleState.resumed) {
      _enableAutoPiP();
    }
  }

  void _enableAutoPiP() {
    if (!Platform.isAndroid || !TxaSettings.autoPiP) return;
    final provider = Provider.of<TxaMiniPlayerProvider>(context, listen: false);
    if (provider.isClosed || !provider.isMini) return;

    try {
      _floating.enable(OnLeavePiP(aspectRatio: const Rational(16, 9)));
    } catch (e) {
      TxaLogger.log('Mini Auto PiP enable error: $e', isError: true);
    }
  }

  @override
  void dispose() {
    TxaSettings().removeListener(_onSettingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    _historySyncTimer?.cancel();
    _floating.cancelOnLeavePiP();
    super.dispose();
  }

  void _startHistorySync() {
    _historySyncTimer?.cancel();
    _historySyncTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _syncHistory();
    });
  }

  Future<void> _syncHistory() async {
    if (!mounted) return;
    final provider = Provider.of<TxaMiniPlayerProvider>(context, listen: false);
    if (provider.isClosed || !provider.isMini || provider.controller == null) {
      return;
    }
    if (TxaSettings.authToken.isEmpty) return;

    final pos = provider.controller!.videoPlayerController?.value.position;
    final dur = provider.controller!.videoPlayerController?.value.duration;

    if (pos == null || dur == null || dur.inSeconds == 0) return;

    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      final mId = int.tryParse(provider.movie?['id'].toString() ?? '0') ?? 0;
      final eId = int.tryParse(provider.currentEpisodeId.toString()) ?? 0;

      if (mId == 0 || eId == 0) return;

      await api.updateWatchHistory(
        movieId: mId,
        episodeId: eId,
        currentTime: pos.inSeconds.toDouble(),
        duration: dur.inSeconds.toDouble(),
      );
    } catch (e) {
      TxaLogger.log("MiniPlayer History Sync Error: $e", isError: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_offset.dx < 0) {
      final size = MediaQuery.of(context).size;
      _offset = Offset(
        size.width - miniWidth - miniMargin,
        size.height - miniHeight - 120, // Avoid bottom nav
      );
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
              : const Duration(milliseconds: 500),
          curve: Curves.easeOutQuart,
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
              // Snap to horizontal edges
              double targetX = _offset.dx < (size.width - miniWidth) / 2
                  ? miniMargin
                  : size.width - miniWidth - miniMargin;

              // Clamp vertical
              double targetY = _offset.dy.clamp(
                60.0,
                size.height - miniHeight - 60.0,
              );

              setState(() {
                _offset = Offset(targetX, targetY);
              });
            },
            onTap: () => _restoreToFull(context, provider),
            child: MouseRegion(
              cursor: SystemMouseCursors.move,
              child: Container(
                width: miniWidth,
                height: miniHeight,
                padding: const EdgeInsets.all(1.5), // For border glow
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: TxaTheme.accent.withValues(alpha: 0.15),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: TxaTheme.accent.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      children: [
                        // Video Content — NO glass overlay so video is fully visible
                        Positioned.fill(
                          child: provider.controller != null
                              ? BetterPlayer(
                                  key: _miniPlayerKey,
                                  controller: provider.controller!,
                                )
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

                        // Darker Gradient Overlay for Text Readability - HIDE IN PIP
                        if (!provider.isPip)
                          Positioned.fill(
                            child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.4),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),

                        // Title Bar - HIDE IN PIP
                        if (!provider.isPip)
                          Positioned(
                            top: 10,
                          left: 12,
                          right: 12,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      provider.movie?['name']?.toString() ??
                                          'TPhimX Premium',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 4,
                                            color: Colors.black,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: TxaTheme.accent.withValues(
                                          alpha: 0.8,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        provider.episodeName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Close Button
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => provider.close(),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black38,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Center Controls - HIDE IN PIP
                        if (!provider.isPip)
                          Center(
                            child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _MiniControlButton(
                                icon:
                                    provider
                                            .controller
                                            ?.videoPlayerController
                                            ?.value
                                            .isPlaying ==
                                        true
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                onTap: () =>
                                    setState(() => provider.playPause()),
                              ),
                            ],
                          ),
                        ),

                        // Bottom Info & Badge
                        Positioned(
                          bottom: 10,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome_motion_rounded,
                                  color: TxaTheme.accent,
                                  size: 10,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "PREMIUM PIP",
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Progress Bar - HIDE IN PIP
                        if (!provider.isPip)
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
          ),
        );
      },
    );
  }

  void _restoreToFull(BuildContext context, TxaMiniPlayerProvider provider) {
    if (provider.isPip) {
      provider.isPip = false;
      return;
    }
    final movie = provider.movie;
    final controller = provider.controller;
    if (controller == null) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => TxaPlayer(
          movie: movie,
          servers: provider.servers ?? [],
          initialServerIndex: provider.serverIndex,
          existingController: controller,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    provider.switchToFull();
  }
}

class _MiniControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MiniControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: TxaTheme.accent.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: TxaTheme.accent.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: TxaTheme.accent.withValues(alpha: 0.2),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
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

        return Container(
          height: 3,
          width: double.infinity,
          decoration: const BoxDecoration(color: Colors.white12),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: TxaTheme.accent,
                boxShadow: [
                  BoxShadow(
                    color: TxaTheme.accent.withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
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
