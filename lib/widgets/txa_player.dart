import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import '../services/txa_settings.dart';
import '../services/txa_language.dart';
import '../services/txa_mini_player_provider.dart';
import '../utils/txa_format.dart';
import '../theme/txa_theme.dart';
import 'package:provider/provider.dart';
import '../utils/txa_toast.dart';
import '../widgets/txa_modal.dart';

class TxaPlayer extends StatefulWidget {
  final dynamic movie;
  final List<dynamic> servers;
  final int? initialServerIndex;
  final String? initialEpisodeId;
  final BetterPlayerController? existingController;

  const TxaPlayer({
    super.key,
    required this.movie,
    required this.servers,
    this.initialServerIndex,
    this.initialEpisodeId,
    this.existingController,
  });

  @override
  State<TxaPlayer> createState() => _TxaPlayerState();
}

class _TxaPlayerState extends State<TxaPlayer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  BetterPlayerController? _betterPlayerController;
  bool _error = false;
  bool _isInitialized = false;
  bool _isRefreshing = false;
  bool _isEmbed = false;
  WebViewController? _webViewController;
  String? _detailedError;

  late int _currentServerIndex;
  late int _currentEpisodeIndex;

  // Markers
  double _introStart = 0;
  double _introEnd = 0;
  double _outroStart = 0;

  bool _showSkipIntro = false;
  bool _showSkipOutro = false;
  bool _autoNextTriggered = false;

  // --- NEW GESTURE & UI STATE ---
  double _brightness = TxaSettings.brightness;
  double _volume = TxaSettings.volume;
  double _loadingPercent = 0.0;
  String _loadingSpeed = '0 KB/s';
  Timer? _speedTimer;
  int _lastBytes = 0;
  bool _isLocked = false;
  String? _overlayLabel;
  IconData? _overlayIcon;
  double? _overlayValue; // 0.0 to 1.0
  Timer? _overlayTimer;

  bool _showControls = true;
  Timer? _controlsTimer;

  // --- NEW SEEK ACCUMULATION ---
  int _seekAccumulator = 0;
  Timer? _seekDebounce;

  // --- NEW AUTO NEXT OVERLAY ---
  bool _showAutoNextCountdownOverlay = false;
  int _autoNextRemaining = 5;
  Timer? _autoNextTimer;

  bool _isInternalVolumeChange = false;
  bool _isBuffering = false;

  static const _dndChannel = MethodChannel('com.tphimx.tphimx/dnd');

  // Clock settings
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  // Aspect ratio options
  static const List<Map<String, dynamic>> _aspectRatios = [
    {'label': '16:9', 'value': 16 / 9, 'fit': BoxFit.contain},
    {'label': '4:3', 'value': 4 / 3, 'fit': BoxFit.contain},
    {'label': '21:9', 'value': 21 / 9, 'fit': BoxFit.contain},
    {'label': 'Fill', 'value': null, 'fit': BoxFit.cover},
    {'label': 'Fit', 'value': null, 'fit': BoxFit.fitWidth},
  ];
  int _currentRatioIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentServerIndex = widget.initialServerIndex ?? 0;
    _currentEpisodeIndex = 0;
    _brightness = TxaSettings.brightness;
    _volume = TxaSettings.volume;

    _loadMarkers();

    if (widget.initialEpisodeId != null && widget.servers.isNotEmpty) {
      final episodes =
          widget.servers[_currentServerIndex]['server_data'] as List;
      for (int i = 0; i < episodes.length; i++) {
        if (episodes[i]['id'].toString() ==
            widget.initialEpisodeId.toString()) {
          _currentEpisodeIndex = i;
          break;
        }
      }
    }

    if (widget.existingController != null) {
      _betterPlayerController = widget.existingController;
      _isInitialized = true;
      _setupControllerListeners();
    } else {
      _initializePlayer();
    }
    _startControlsTimer();
    _initSystemMirrors();
    _startClock();
    _toggleDND(true);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (TxaSettings.autoPiP && _isInitialized && !_error && !_isLocked) {
        final isPlaying =
            _betterPlayerController?.videoPlayerController?.value.isPlaying ??
            false;
        if (isPlaying) {
          _betterPlayerController?.enablePictureInPicture(
            _betterPlayerController!.betterPlayerGlobalKey!,
          );
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      // Returning from background — check if we were in PiP
      _checkPiPReturn();
    }
  }

  void _checkPiPReturn() {
    // If we return and find ourselves in PiP or about to exit it,
    // we can transition to MiniPlayer if the user isn't on the player screen anymore.
    // However, since TxaPlayer is technically still on top, we might just stay full screen.
  }

  void _initSystemMirrors() {
    try {
      ScreenBrightness().setApplicationScreenBrightness(_brightness);
      // Hide system volume HUD during playback to use our custom premium overlay
      VolumeController.instance.showSystemUI = false;

      // Listen to system volume changes
      VolumeController.instance.addListener((v) {
        if (!mounted || _isLocked) return;

        if (_isInternalVolumeChange) {
          _isInternalVolumeChange = false;
          return;
        }

        if ((v - _volume).abs() > 0.01) {
          setState(() {
            _volume = v;
            TxaSettings.volume = v;
            _betterPlayerController?.setVolume(v);
          });
        }
      });
    } catch (e) {
      debugPrint("System mirror init error: $e");
    }
  }

  void _loadMarkers() {
    final m = widget.movie;
    final server = widget.servers.isNotEmpty
        ? widget.servers[_currentServerIndex]
        : null;
    final serverData = server != null ? server['server_data'] as List : [];
    final episode =
        serverData.isNotEmpty && _currentEpisodeIndex < serverData.length
        ? serverData[_currentEpisodeIndex]
        : null;

    // 1. Movie level markers
    if (m['markers'] != null) {
      final intro = m['markers']['intro'] as List?;
      if (intro != null && intro.length >= 2) {
        _introStart = (intro[0] as num).toDouble();
        _introEnd = (intro[1] as num).toDouble();
      }
      final outro = m['markers']['outro'] as List?;
      if (outro != null && outro.isNotEmpty) {
        _outroStart = (outro[0] as num).toDouble();
      }
    }

    // 2. Episode level markers (Override if exists)
    if (episode != null && episode['skip_markers'] != null) {
      final sm = episode['skip_markers'];
      final intro = sm['intro'] as List?;
      if (intro != null && intro.length >= 2) {
        _introStart = (intro[0] as num).toDouble();
        _introEnd = (intro[1] as num).toDouble();
      }
      final outro = sm['outro'] as List?;
      if (outro != null && outro.isNotEmpty) {
        _outroStart = (outro[0] as num).toDouble();
      }
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _showControls && !_isLocked) {
        setState(() => _showControls = false);
      }
    });
  }

  void _handleTap(TapUpDetails details, double width) {
    if (_isLocked || _betterPlayerController == null) return;
    final dx = details.globalPosition.dx;
    final isCenter = dx > width * 0.3 && dx < width * 0.7;

    if (isCenter) {
      // Toggle play/pause
      final c = _betterPlayerController!.videoPlayerController;
      if (c != null) {
        if (c.value.isPlaying) {
          c.pause();
        } else {
          c.play();
        }
        setState(() {});
      }
      // Always show controls when play/pause is toggled from center
      if (!_showControls) {
        setState(() => _showControls = true);
        _startControlsTimer();
      }
    } else {
      // Toggle controls visibility on sides
      setState(() {
        _showControls = !_showControls;
        if (_showControls) _startControlsTimer();
      });

      // If hiding controls, also hide drawers
      if (!_showControls) {
        _showEpisodeDrawer = false;
        _showServerDrawer = false;
      }
    }
  }

  void _setupControllerListeners() {
    _betterPlayerController?.addEventsListener(_onPlayerEvent);
  }

  void _startSpeedTracking() {
    _speedTimer?.cancel();
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _betterPlayerController == null) return;

      final buffered =
          _betterPlayerController!.videoPlayerController?.value.buffered;
      if (buffered == null || buffered.isEmpty) return;

      int currentSeconds = 0;
      for (var r in buffered) {
        currentSeconds += (r.end.inSeconds - r.start.inSeconds);
      }

      if (_lastBytes > 0) {
        final deltaSeconds = currentSeconds - _lastBytes;
        if (deltaSeconds >= 0) {
          final bytes = deltaSeconds * 200 * 1024;
          setState(() {
            _loadingSpeed = TxaFormat.formatSpeed(bytes.toDouble())['display'];
          });
        }
      }
      _lastBytes = currentSeconds;
    });
  }

  bool _showEpisodeDrawer = false;
  bool _showServerDrawer = false;

  Future<void> _initializePlayer() async {
    setState(() {
      _isInitialized = false;
      _error = false;
      _autoNextTriggered = false;
      _isEmbed = false;
    });

    // Force landscapeLeft for consistent rotation on both iOS and Android
    // landscapeLeft = 90° counter-clockwise (top on left side)
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startSpeedTracking();

    final server = widget.servers.isNotEmpty
        ? widget.servers[_currentServerIndex]
        : null;
    final serverData = server != null ? server['server_data'] as List : [];
    if (serverData.isEmpty) {
      setState(() => _error = true);
      return;
    }

    final episode = serverData[_currentEpisodeIndex];

    final List<Map<String, String>> sources = [];
    if (episode['stream_v6']?.toString().isNotEmpty == true) {
      sources.add({
        'type': 'stream',
        'url': episode['stream_v6'],
        'name': 'Stream V6',
      });
    }
    if (episode['stream_m3u8']?.toString().isNotEmpty == true) {
      sources.add({
        'type': 'stream',
        'url': episode['stream_m3u8'],
        'name': 'Stream M3U8',
      });
    }
    if (episode['link_m3u8']?.toString().isNotEmpty == true) {
      sources.add({
        'type': 'stream',
        'url': episode['link_m3u8'],
        'name': 'Link Direct',
      });
    }
    if (episode['stream_embed']?.toString().isNotEmpty == true) {
      sources.add({
        'type': 'embed',
        'url': episode['stream_embed'],
        'name': 'Embed Proxy',
      });
    }
    if (episode['link_embed']?.toString().isNotEmpty == true) {
      sources.add({
        'type': 'embed',
        'url': episode['link_embed'],
        'name': 'Embed Direct',
      });
    }

    if (sources.isEmpty) {
      _detailedError = TxaLanguage.t('no_sources_found');
      setState(() => _error = true);
      return;
    }

    await _trySource(sources, 0, episode);
  }

  Future<void> _trySource(
    List<Map<String, String>> sources,
    int index,
    dynamic episode,
  ) async {
    if (index >= sources.length) {
      if (mounted) setState(() => _error = true);
      return;
    }

    final source = sources[index];
    final url = source['url']!;
    final type = source['type']!;
    final isLast = index == sources.length - 1;

    if (type == 'embed') {
      _initializeEmbed(url);
      return;
    }

    // Handle Subtitles from API
    List<BetterPlayerSubtitlesSource>? subtitles;
    if (episode['subtitles'] != null && episode['subtitles'] is List) {
      subtitles = (episode['subtitles'] as List)
          .map(
            (s) => BetterPlayerSubtitlesSource(
              type: BetterPlayerSubtitlesSourceType.network,
              name: s['label'] ?? s['lang'] ?? 'Unknown',
              urls: [s['file']],
            ),
          )
          .toList();
    }

    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      headers: {
        "X-TXC-Client": "TPhimX-App-V6",
        "Referer": "https://film.nrotxa.online/",
      },
      cacheConfiguration: const BetterPlayerCacheConfiguration(useCache: true),
      subtitles: subtitles,
    );

    BetterPlayerConfiguration config = BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      autoPlay: true,
      fullScreenByDefault: true,
      allowedScreenSleep: false,
      controlsConfiguration: const BetterPlayerControlsConfiguration(
        showControls: false, // WE BUILD OUR OWN PREMIUM OVERLAY
        enablePlaybackSpeed: true,
        enableQualities: true,
        enableSubtitles: true,
      ),
    );

    _betterPlayerController?.dispose();
    _betterPlayerController = BetterPlayerController(config);

    try {
      await _betterPlayerController!.setupDataSource(dataSource);
      _betterPlayerController!.addEventsListener(_onPlayerEvent);

      _betterPlayerController!.setVolume(_volume);
      _betterPlayerController!.setSpeed(TxaSettings.playbackSpeed);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isEmbed = false;
          _error = false;
        });
      }
    } catch (e) {
      if (isLast) {
        _detailedError = "${TxaLanguage.t('all_sources_failed')}\n$e";
        if (mounted) setState(() => _error = true);
      } else {
        await _trySource(sources, index + 1, episode);
      }
    }
  }

  void _initializeEmbed(String url) {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadRequest(Uri.parse(url));

    if (mounted) {
      setState(() {
        _isInitialized = true;
        _isEmbed = true;
        _error = false;
      });
    }
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (_betterPlayerController == null) return;

    if (event.betterPlayerEventType == BetterPlayerEventType.progress) {
      // Update buffered percentage
      final buffered =
          _betterPlayerController!.videoPlayerController?.value.buffered;
      final duration =
          _betterPlayerController!.videoPlayerController?.value.duration;
      if (buffered != null && duration != null && duration.inSeconds > 0) {
        double totalBuffered = 0;
        for (var range in buffered) {
          totalBuffered += range.end.inSeconds - range.start.inSeconds;
        }
        setState(() {
          _loadingPercent = (totalBuffered / duration.inSeconds).clamp(
            0.0,
            1.0,
          );
        });
      }

      final pos =
          _betterPlayerController!.videoPlayerController?.value.position;
      final durObj =
          _betterPlayerController!.videoPlayerController?.value.duration;
      final ct = pos?.inSeconds.toDouble() ?? 0.0;
      final dur = durObj?.inSeconds.toDouble() ?? 0.0;

      // --- INTRO SKIP ---
      if (_introEnd > _introStart && ct >= _introStart && ct <= _introEnd) {
        if (!_showSkipIntro) setState(() => _showSkipIntro = true);
        if (TxaSettings.autoSkipIntro && ct < _introEnd - 2) {
          _betterPlayerController!.seekTo(Duration(seconds: _introEnd.toInt()));
        }
      } else {
        if (_showSkipIntro) setState(() => _showSkipIntro = false);
      }

      // --- OUTRO / AUTO NEXT ---
      bool isOutroZone = false;
      if (_outroStart > 0) {
        // Trigger 5s before outro start
        isOutroZone = ct >= (_outroStart - 5);
      } else {
        // Fallback: 10s before end
        isOutroZone = dur > 0 && ct >= (dur - 10);
      }

      if (isOutroZone && ct <= dur && dur > 0) {
        if (TxaSettings.autoNextEpisode &&
            !_autoNextTriggered &&
            !_showAutoNextCountdownOverlay) {
          _startAutoNextCountdown();
        }

        if (_outroStart > 0 && ct >= _outroStart) {
          if (!_showSkipOutro) setState(() => _showSkipOutro = true);
        }
      } else {
        if (_showSkipOutro) setState(() => _showSkipOutro = false);
        // Reset if seeking out
        if (_showAutoNextCountdownOverlay && ct < (dur - 20)) {
          _cancelAutoNextCountdown(resetTrigger: true);
        }
      }
    } else if (event.betterPlayerEventType ==
        BetterPlayerEventType.bufferingStart) {
      if (mounted) setState(() => _isBuffering = true);
    } else if (event.betterPlayerEventType ==
        BetterPlayerEventType.bufferingEnd) {
      if (mounted) setState(() => _isBuffering = false);
    } else if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
      _handlePlayerError();
    }
  }

  Future<void> _handlePlayerError() async {
    if (_isRefreshing || !mounted) return;
    setState(() => _isRefreshing = true);
    _initializePlayer();
  }

  void _startAutoNextCountdown() {
    if (!mounted || _autoNextTriggered) return;

    setState(() {
      _showAutoNextCountdownOverlay = true;
      _autoNextRemaining = 5;
    });

    _autoNextTimer?.cancel();
    _autoNextTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_autoNextRemaining > 1) {
          _autoNextRemaining--;
        } else {
          timer.cancel();
          _showAutoNextCountdownOverlay = false;
          _autoNextTriggered = true;
          _playNext();
        }
      });
    });
  }

  void _cancelAutoNextCountdown({bool resetTrigger = false}) {
    _autoNextTimer?.cancel();
    setState(() {
      _showAutoNextCountdownOverlay = false;
      _autoNextRemaining = 5;
    });
    // Prevent re-triggering for this session unless explicitly reset (on seek back)
    _autoNextTriggered = !resetTrigger;
  }

  void _playPrevious() {
    if (_currentEpisodeIndex > 0) {
      setState(() {
        _currentEpisodeIndex--;
      });
      _initializePlayer();
    }
  }

  void _playNext() {
    final serverData =
        widget.servers[_currentServerIndex]['server_data'] as List;
    if (_currentEpisodeIndex < serverData.length - 1) {
      setState(() {
        _currentEpisodeIndex++;
      });
      _initializePlayer();
    } else {
      Navigator.pop(context);
    }
  }

  // --- SERVER SWITCHING ---
  void _switchServer(int newServerIndex) {
    if (newServerIndex == _currentServerIndex) return;

    final newServerData = widget.servers[newServerIndex]['server_data'] as List;
    final oldServerData =
        widget.servers[_currentServerIndex]['server_data'] as List;

    // Check if current episode exists in new server
    if (_currentEpisodeIndex >= newServerData.length) {
      // Episode doesn't exist on this server — show modal & auto-revert
      final serverName =
          widget.servers[newServerIndex]['server_name'] ?? 'Server';
      final epName = oldServerData[_currentEpisodeIndex]['name'].toString();

      TxaModal.show(
        context,
        title: TxaLanguage.t('server_ep_unavailable_title'),
        content: Text(
          TxaLanguage.t(
            'server_ep_unavailable_msg',
          ).replaceAll('%ep', epName).replaceAll('%server', serverName),
          style: const TextStyle(
            color: TxaTheme.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              TxaLanguage.t('ok'),
              style: const TextStyle(
                color: TxaTheme.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        barrierDismissible: true,
      );

      // Auto-revert to first server
      setState(() {
        _currentServerIndex = 0;
        _showServerDrawer = false;
      });
      return;
    }

    // Switch server and reload
    setState(() {
      _currentServerIndex = newServerIndex;
      _showServerDrawer = false;
    });
    _loadMarkers();
    _initializePlayer();
  }

  // --- ASPECT RATIO ---
  void _cycleAspectRatio() {
    if (_betterPlayerController == null || _isEmbed) {
      TxaToast.show(context, TxaLanguage.t('feature_dev'));
      return;
    }
    setState(() {
      _currentRatioIndex = (_currentRatioIndex + 1) % _aspectRatios.length;
      final ratio = _aspectRatios[_currentRatioIndex];
      _betterPlayerController!.setOverriddenAspectRatio(
        ratio['value'] as double? ?? MediaQuery.of(context).size.aspectRatio,
      );
      _betterPlayerController!.setOverriddenFit(ratio['fit'] as BoxFit);
      _overlayIcon = Icons.aspect_ratio_rounded;
      _overlayLabel = "${TxaLanguage.t('player_ratio')}: ${ratio['label']}";
    });
    _showOverlayFeedback();
  }

  // --- GESTURE LOGIC ---
  void _handleVerticalDrag(DragUpdateDetails details, double width) {
    if (_isLocked) return;
    final delta = details.primaryDelta! / 200; // sensitivity
    if (details.globalPosition.dx < width / 2) {
      // Left side: Brightness
      setState(() {
        _brightness = (_brightness - delta).clamp(0.0, 1.0);
        _overlayIcon = Icons.brightness_medium_rounded;
        _overlayLabel = TxaLanguage.t('player_brightness');
        _overlayValue = _brightness;
        TxaSettings.brightness = _brightness;
        ScreenBrightness().setApplicationScreenBrightness(_brightness);
      });
    } else {
      // Right side: Volume
      setState(() {
        _isInternalVolumeChange = true;
        _volume = (_volume - delta).clamp(0.0, 1.0);
        _overlayIcon = _volume > 0
            ? Icons.volume_up_rounded
            : Icons.volume_off_rounded;
        _overlayLabel = TxaLanguage.t('player_audio');
        _overlayValue = _volume;
        _betterPlayerController?.setVolume(_volume);
        TxaSettings.volume = _volume;
        VolumeController.instance.setVolume(_volume);
      });
    }
    _showOverlayFeedback();
  }

  void _showOverlayFeedback() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _overlayLabel = null;
          _overlayIcon = null;
          _overlayValue = null;
        });
      }
    });
  }

  void _onDoubleTap(TapDownDetails details, double width) {
    if (_isLocked || _betterPlayerController == null) return;

    _seekDebounce?.cancel();
    final isForward = details.globalPosition.dx > width / 2;

    setState(() {
      if (isForward) {
        _seekAccumulator += 10;
      } else {
        _seekAccumulator -= 10;
      }

      final formattedTime = TxaFormat.formatDuration(_seekAccumulator.abs());
      if (isForward) {
        _overlayIcon = Icons.fast_forward_rounded;
        _overlayLabel = "+ $formattedTime";
      } else {
        _overlayIcon = Icons.fast_rewind_rounded;
        _overlayLabel = "- $formattedTime";
      }
      _overlayValue = null;
    });

    _seekDebounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final currentPos =
          _betterPlayerController!.videoPlayerController!.value.position;
      _betterPlayerController!.seekTo(
        currentPos + Duration(seconds: _seekAccumulator),
      );
      setState(() {
        _seekAccumulator = 0;
        _overlayLabel = null;
        _overlayIcon = null;
      });
    });
  }

  void _onLongPress(bool start) {
    if (_isLocked || _betterPlayerController == null) return;
    setState(() {
      if (start) {
        _betterPlayerController!.setSpeed(2.0);
        _overlayIcon = Icons.speed_rounded;
        _overlayLabel = TxaLanguage.t('player_fast_forward_2x');
      } else {
        _betterPlayerController!.setSpeed(TxaSettings.playbackSpeed);
        _overlayLabel = null;
        _overlayIcon = null;
      }
    });
  }

  void _startClock() {
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _toggleDND(bool enable) async {
    if (!TxaSettings.autoDND) return;
    try {
      final bool? hasPermission = await _dndChannel.invokeMethod<bool>(
        'checkPermission',
      );
      if (hasPermission == false && enable) {
        // Pause playback before opening Android settings to request DND access
        _betterPlayerController?.pause();
        if (!mounted) return;
        TxaToast.show(context, TxaLanguage.t('pip_permission_missing'));
      }
      await _dndChannel.invokeMethod('setDND', {'enable': enable});
    } catch (e) {
      debugPrint("DND Error: $e");
    }
  }

  @override
  void dispose() {
    _toggleDND(false);
    _clockTimer.cancel();
    _autoNextTimer?.cancel();
    _controlsTimer?.cancel();
    _overlayTimer?.cancel();
    _speedTimer?.cancel();
    _seekDebounce?.cancel();

    final miniProvider = Provider.of<TxaMiniPlayerProvider>(
      context,
      listen: false,
    );
    if (miniProvider.controller != _betterPlayerController) {
      _betterPlayerController?.dispose();
    }

    _betterPlayerController?.removeEventsListener(_onPlayerEvent);
    VolumeController.instance.removeListener();
    VolumeController.instance.showSystemUI = true; // Restore system volume HUD
    ScreenBrightness().resetApplicationScreenBrightness();
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Ensure orientation reset when popping
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTapUp: (d) => _handleTap(d, width),
          onVerticalDragUpdate: (d) => _handleVerticalDrag(d, width),
          onDoubleTapDown: (d) => _onDoubleTap(d, width),
          onLongPressStart: (_) => _onLongPress(true),
          onLongPressEnd: (_) => _onLongPress(false),
          child: Stack(
            children: [
              // 1. VIDEO
              Center(
                child: _isInitialized
                    ? Stack(
                        children: [
                          _isEmbed
                              ? WebViewWidget(controller: _webViewController!)
                              : BetterPlayer(
                                  controller: _betterPlayerController!,
                                ),
                          if (_isBuffering && !_isEmbed)
                            Container(
                              color: Colors.black26,
                              child: _buildLoadingUI(),
                            ),
                        ],
                      )
                    : _error
                    ? _buildErrorUI()
                    : _buildLoadingUI(),
              ),

              // 2. WATERMARK (Corner)
              Positioned(
                top: 40,
                right: 20,
                child: Opacity(
                  opacity: 0.3,
                  child: Text(
                    TxaLanguage.t('player_watermark'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),

              // 2.5 CLOCK (Top-Left)
              if (TxaSettings.showClock)
                Positioned(
                  top: 40,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      TxaFormat.formatDate(
                        _now,
                        pattern: TxaSettings.clockFormat,
                      ),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),

              // 3. GESTURE FEEDBACK OVERLAY
              if (_overlayLabel != null || _overlayIcon != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_overlayIcon, color: Colors.white, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          _overlayLabel!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_overlayValue != null) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 100,
                            child: LinearProgressIndicator(
                              value: _overlayValue,
                              backgroundColor: Colors.white24,
                              color: TxaTheme.accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // 4. CUSTOM CONTROLS
              if (_showControls && _isInitialized && !_error) ...[
                _buildControlOverlay(),
              ],

              // 4.5 EPISODE DRAWER
              if (_showEpisodeDrawer && _isInitialized && !_error)
                _buildEpisodeSelectionOverlay(),

              // 4.6 SERVER DRAWER
              if (_showServerDrawer && _isInitialized && !_error)
                _buildServerSelectionOverlay(),

              // 6. AUTO NEXT PREVIEW (PREMIUM)
              if (_showAutoNextCountdownOverlay && _isInitialized && !_error)
                _buildAutoNextOverlay(),

              // 7. SKIP BUTTONS
              if (_showSkipIntro)
                _buildSkipOverlay(TxaLanguage.t('skip_intro'), () {
                  _betterPlayerController!.seekTo(
                    Duration(seconds: _introEnd.toInt()),
                  );
                }, Alignment.bottomRight),
              if (_showSkipOutro)
                _buildSkipOverlay(
                  TxaLanguage.t('skip_outro_next'),
                  _playNext,
                  Alignment.bottomRight,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoNextOverlay() {
    final serverData =
        widget.servers[_currentServerIndex]['server_data'] as List;
    final nextEpIndex = _currentEpisodeIndex + 1;
    final nextEp = nextEpIndex < serverData.length
        ? serverData[nextEpIndex]
        : null;

    if (nextEp == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 85,
      right: 30,
      child: TxaTheme.glassConnector(
        radius: 20,
        padding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thumbnail
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 100,
                      height: 60,
                      color: Colors.black,
                      child: Image.network(
                        widget.movie['thumb_url'] ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.movie_rounded,
                          color: Colors.white24,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: TxaTheme.accent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: TxaTheme.accent.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Text(
                        "${TxaLanguage.t('episode')} ${nextEp['name']}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      TxaLanguage.t('prep_next_ep'),
                      style: const TextStyle(
                        color: TxaTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.movie['name'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${TxaLanguage.t('player_start_in')} 0${_autoNextRemaining}s",
                      style: const TextStyle(
                        color: TxaTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Action
              IconButton(
                onPressed: _cancelAutoNextCountdown,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlOverlay() {
    final serverData =
        widget.servers[_currentServerIndex]['server_data'] as List;
    final ep = serverData[_currentEpisodeIndex];
    final serverName =
        widget.servers[_currentServerIndex]['server_name'] ?? 'Server';

    return Stack(
      children: [
        // GRADIENTS
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black87,
                  ],
                  stops: const [0.0, 0.2, 0.7, 1.0],
                ),
              ),
            ),
          ),
        ),

        // TOP BAR
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      if (_betterPlayerController != null) {
                        context.read<TxaMiniPlayerProvider>().switchToMini(
                          controller: _betterPlayerController!,
                          movie: widget.movie,
                          servers: widget.servers,
                          serverIndex: _currentServerIndex,
                          episodeIndex: _currentEpisodeIndex,
                        );
                      }
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 8),
                  _HeaderIcon(
                    icon: _isLocked
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded,
                    onTap: () => setState(() => _isLocked = !_isLocked),
                    color: _isLocked ? TxaTheme.accent : Colors.white,
                    size: 26,
                  ),
                  const Spacer(),
                  Expanded(
                    flex: 12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${widget.movie['name']} - ${TxaLanguage.t('episode')} ${ep['name']}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          serverName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: TxaTheme.accent.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _HeaderIcon(
                    icon: Icons.picture_in_picture_alt_rounded,
                    onTap: () {
                      if (_betterPlayerController != null) {
                        context.read<TxaMiniPlayerProvider>().switchToMini(
                          controller: _betterPlayerController!,
                          movie: widget.movie,
                          servers: widget.servers,
                          serverIndex: _currentServerIndex,
                          episodeIndex: _currentEpisodeIndex,
                        );
                        Navigator.pop(context);
                      }
                    },
                  ),
                  _HeaderIcon(
                    icon: Icons.cast_connected_rounded,
                    onTap: () =>
                        TxaToast.show(context, TxaLanguage.t('feature_dev')),
                  ),
                  _HeaderIcon(
                    icon: Icons.settings_outlined,
                    onTap: _showFullSettings,
                  ),
                ],
              ),
            ),
          ),
        ),

        // CENTER CONTROLS
        if (!_isLocked)
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CenterControlIcon(
                  icon: Icons.replay_10_rounded,
                  onTap: () => _onDoubleTap(
                    TapDownDetails(
                      globalPosition: Offset(
                        MediaQuery.of(context).size.width * 0.2,
                        0,
                      ),
                    ),
                    MediaQuery.of(context).size.width,
                  ),
                ),
                const SizedBox(width: 60),
                _CenterControlIcon(
                  icon:
                      _betterPlayerController
                              ?.videoPlayerController
                              ?.value
                              .isPlaying ??
                          false
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 80,
                  onTap: () {
                    final c = _betterPlayerController?.videoPlayerController;
                    if (c == null) return;
                    c.value.isPlaying ? c.pause() : c.play();
                    setState(() {});
                  },
                ),
                const SizedBox(width: 60),
                _CenterControlIcon(
                  icon: Icons.forward_10_rounded,
                  onTap: () => _onDoubleTap(
                    TapDownDetails(
                      globalPosition: Offset(
                        MediaQuery.of(context).size.width * 0.8,
                        0,
                      ),
                    ),
                    MediaQuery.of(context).size.width,
                  ),
                ),
              ],
            ),
          ),

        // BOTTOM BAR (SEEK & NAVIGATION)
        if (!_isLocked)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isEmbed && _betterPlayerController != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 25.0),
                        child: _buildProgressBar(),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // LEFT: Time & Speed Info
                        Padding(
                          padding: const EdgeInsets.only(left: 20.0),
                          child: Row(
                            children: [
                              Text(
                                _betterPlayerController != null
                                    ? "${_formatDuration(_betterPlayerController!.videoPlayerController!.value.position)} / ${_formatDuration(_betterPlayerController!.videoPlayerController!.value.duration)}"
                                    : "00:00 / 00:00",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: TxaTheme.accent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: TxaTheme.accent.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  "${TxaSettings.playbackSpeed}x",
                                  style: const TextStyle(
                                    color: TxaTheme.accent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // RIGHT: Control Buttons
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // PREV EPISODE
                              if (_currentEpisodeIndex > 0)
                                _BottomBarItem(
                                  icon: Icons.skip_previous_rounded,
                                  label: TxaLanguage.t('prev_ep'),
                                  onTap: _playPrevious,
                                ),
                              if (_currentEpisodeIndex > 0)
                                const SizedBox(width: 32),

                              // RATIO BUTTON
                              _BottomBarItem(
                                icon: Icons.aspect_ratio_rounded,
                                label:
                                    '${TxaLanguage.t('player_ratio')} (${_aspectRatios[_currentRatioIndex]['label']})',
                                onTap: _cycleAspectRatio,
                              ),
                              const SizedBox(width: 32),
                              // SERVER BUTTON
                              _BottomBarItem(
                                icon: Icons.dns_rounded,
                                label:
                                    widget
                                        .servers[_currentServerIndex]['server_name'] ??
                                    TxaLanguage.t('select_server'),
                                onTap: () => setState(() {
                                  _showServerDrawer = true;
                                  _showEpisodeDrawer = false;
                                }),
                                isActive: true,
                              ),
                              const SizedBox(width: 32),
                              // SUBTITLE BUTTON
                              if (serverName.toLowerCase().contains('sub') ||
                                  serverName.toLowerCase().contains(
                                    'vietsub',
                                  ) ||
                                  serverName.toLowerCase().contains(
                                    'thuyết minh',
                                  ))
                                _BottomBarItem(
                                  icon: Icons.subtitles_rounded,
                                  label: TxaLanguage.t('player_subtitle'),
                                  onTap: () => TxaToast.show(
                                    context,
                                    TxaLanguage.t('feature_dev'),
                                  ),
                                ),
                              const SizedBox(width: 32),
                              // NEXT EPISODE
                              if (_currentEpisodeIndex < serverData.length - 1)
                                _BottomBarItem(
                                  icon: Icons.skip_next_rounded,
                                  label: TxaLanguage.t('next_ep'),
                                  onTap: _playNext,
                                ),
                              if (_currentEpisodeIndex < serverData.length - 1)
                                const SizedBox(width: 32),
                              // SPEED BUTTON
                              _BottomBarItem(
                                icon: Icons.speed_rounded,
                                label: '${TxaSettings.playbackSpeed}x',
                                onTap: () {
                                  double current = TxaSettings.playbackSpeed;
                                  double next = 1.0;
                                  if (current == 1.0) {
                                    next = 1.25;
                                  } else if (current == 1.25) {
                                    next = 1.5;
                                  } else if (current == 1.5) {
                                    next = 2.0;
                                  } else if (current == 2.0) {
                                    next = 0.75;
                                  } else {
                                    next = 1.0;
                                  }

                                  TxaSettings.playbackSpeed = next;
                                  _betterPlayerController?.setSpeed(next);
                                  setState(() {});
                                  _overlayIcon = Icons.speed_rounded;
                                  _overlayLabel =
                                      "${TxaLanguage.t('player_speed')}: ${next}x";
                                  _showOverlayFeedback();
                                },
                              ),
                              const SizedBox(width: 32),

                              // EPISODE LIST BUTTON
                              _BottomBarItem(
                                icon: Icons.playlist_play_rounded,
                                label: TxaLanguage.t('player_episodes'),
                                onTap: () => setState(() {
                                  _showEpisodeDrawer = true;
                                  _showServerDrawer = false;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        // DOUBLE TAP BADGE
        if (_showControls && !_isLocked)
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.touch_app_rounded,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      TxaLanguage.t('player_seek_hint_short'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final c = _betterPlayerController!.videoPlayerController!;
    return ValueListenableBuilder(
      valueListenable: c,
      builder: (context, value, child) {
        final pos = (value.position.inSeconds).toDouble();
        final dur = (value.duration?.inSeconds ?? 0).toDouble();
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDuration(value.position),
                      style: TextStyle(
                        color: TxaTheme.accent.withValues(alpha: 0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        shadows: const [
                          Shadow(blurRadius: 4, color: Colors.black),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      TxaLanguage.t('player_position'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatDuration(value.duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                // 1. MARKERS
                if (dur > 0)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Stack(
                        children: [
                          if (_introEnd > _introStart)
                            Positioned(
                              left:
                                  (_introStart / dur) *
                                  (MediaQuery.of(context).size.width - 48),
                              width:
                                  ((_introEnd - _introStart) / dur) *
                                  (MediaQuery.of(context).size.width - 48),
                              top: 23,
                              bottom: 23,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_outroStart > 0)
                            Positioned(
                              left:
                                  (_outroStart / dur) *
                                  (MediaQuery.of(context).size.width - 48),
                              right: 0,
                              top: 23,
                              bottom: 23,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                // 2. ACTUAL SLIDER
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 6, // Thicker for premium feel
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ), // More visible thumb
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                    activeTrackColor: TxaTheme.accent,
                    inactiveTrackColor: Colors.white10,
                    activeTickMarkColor: Colors.transparent,
                    inactiveTickMarkColor: Colors.transparent,
                    trackShape:
                        const RoundedRectSliderTrackShape(), // Smoother corners
                    thumbColor: TxaTheme.accent,
                  ),
                  child: Slider(
                    value: pos.clamp(0.0, dur > 0 ? dur : 0.0),
                    max: dur > 0 ? dur : 1.0,
                    label: _formatDuration(Duration(seconds: pos.toInt())),
                    divisions: dur > 0 ? dur.toInt() : null,
                    onChanged: (v) {
                      _betterPlayerController!.seekTo(
                        Duration(seconds: v.toInt()),
                      );
                      // Reset auto next if seeking back
                      if (_autoNextTriggered && v < (dur - 20)) {
                        setState(() => _autoNextTriggered = false);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showFullSettings() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => Align(
        alignment: Alignment.centerRight,
        child: _PremiumRightPanel(
          title: TxaLanguage.t('player_settings'),
          children: [
            // 1. PLAYBACK SPEED
            _SectionTitle(title: TxaLanguage.t('speed')),
            Wrap(
              spacing: 8,
              children: [0.5, 1.0, 1.25, 1.5, 2.0].map((s) {
                final isCur = TxaSettings.playbackSpeed == s;
                return ChoiceChip(
                  label: Text(
                    '${s}x',
                    style: TextStyle(
                      color: isCur ? Colors.white : Colors.white70,
                    ),
                  ),
                  selected: isCur,
                  selectedColor: TxaTheme.accent,
                  backgroundColor: Colors.white12,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        TxaSettings.playbackSpeed = s;
                        _betterPlayerController?.setSpeed(s);
                      });
                      Navigator.pop(ctx);
                      _overlayIcon = Icons.speed_rounded;
                      _overlayLabel = "${TxaLanguage.t('player_speed')}: ${s}x";
                      _showOverlayFeedback();
                    }
                  },
                );
              }).toList(),
            ),
            const Divider(color: Colors.white10, height: 32),

            // 2. BRIGHTNESS & VOLUME
            _SliderRow(
              label: TxaLanguage.t('player_brightness'),
              icon: Icons.brightness_medium_rounded,
              value: _brightness,
              onChanged: (v) {
                setState(() {
                  TxaSettings.brightness = v;
                  _brightness = v;
                });
              },
            ),
            _SliderRow(
              label: TxaLanguage.t('player_audio'),
              icon: Icons.volume_up_rounded,
              value: _volume,
              onChanged: (v) {
                setState(() {
                  _isInternalVolumeChange = true;
                  TxaSettings.volume = v;
                  _volume = v;
                  VolumeController.instance.setVolume(v);
                  _betterPlayerController?.setVolume(v);
                });
              },
            ),
            const Divider(color: Colors.white10, height: 32),

            _SwitchRow(
              label: TxaLanguage.t('player_show_clock'),
              value: TxaSettings.showClock,
              onChanged: (v) => setState(() => TxaSettings.showClock = v),
            ),
            if (TxaSettings.showClock)
              _DropdownRow<String>(
                label: TxaLanguage.t('player_clock_format'),
                value: TxaSettings.clockFormat,
                items: const {
                  'HH:mm': 'HH:mm',
                  'HH:mm:ss': 'HH:mm:ss',
                  'HH:mm:ss.SSS': 'HH:mm:ss.SSS',
                  'HH:mm dd/MM': 'HH:mm dd/MM',
                  'HH:mm:ss dd/MM/yyyy': 'HH:mm:ss dd/MM/yyyy',
                  'HH:mm:ss.SS dd/MM/yyyy': 'HH:mm:ss.SS dd/MM/yyyy',
                  'hh:mm a': 'hh:mm a',
                  'hh:mm:ss a': 'hh:mm:ss a',
                  'E, HH:mm': 'E, HH:mm',
                },
                onChanged: (v) => setState(() => TxaSettings.clockFormat = v!),
              ),
            _SwitchRow(
              label: TxaLanguage.t('player_dnd_auto'),
              value: TxaSettings.autoDND,
              onChanged: (v) {
                setState(() => TxaSettings.autoDND = v);
                _toggleDND(v);
              },
            ),
            _SwitchRow(
              label: TxaLanguage.t('skip_intro'),
              value: TxaSettings.autoSkipIntro,
              onChanged: (v) => setState(() => TxaSettings.autoSkipIntro = v),
            ),
            _SwitchRow(
              label: TxaLanguage.t('auto_next_ep'),
              value: TxaSettings.autoNextEpisode,
              onChanged: (v) => setState(() => TxaSettings.autoNextEpisode = v),
            ),
          ],
        ),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(anim1),
          child: child,
        );
      },
    );
  }

  // --- EPISODE SELECTION RIGHT PANEL ---
  Widget _buildEpisodeSelectionOverlay() {
    final serverData =
        widget.servers[_currentServerIndex]['server_data'] as List;
    final currentEpName = serverData[_currentEpisodeIndex]['name'].toString();

    return GestureDetector(
      onTap: () => setState(() => _showEpisodeDrawer = false),
      child: Container(
        color: Colors.black26,
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {}, // Prevent tap through
            child: Container(
              width: MediaQuery.of(context).size.width * 0.4,
              height: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF1A1F2E),
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.playlist_play_rounded,
                                color: TxaTheme.accent,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  TxaLanguage.t('player_episodes'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white54,
                                  size: 22,
                                ),
                                onPressed: () =>
                                    setState(() => _showEpisodeDrawer = false),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Current episode indicator
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: TxaTheme.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: TxaTheme.accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.play_circle_filled_rounded,
                                  color: TxaTheme.accent,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    "${TxaLanguage.t('watching')}: ${TxaLanguage.t('episode')} $currentEpName",
                                    style: const TextStyle(
                                      color: TxaTheme.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: serverData.length,
                        itemBuilder: (ctx, i) {
                          final isCur = i == _currentEpisodeIndex;
                          final epNameRaw = serverData[i]['name'].toString();
                          final bool isClean =
                              epNameRaw.toLowerCase().contains("tập") ||
                              epNameRaw.toLowerCase().contains("episode");
                          final displayName = isClean
                              ? epNameRaw
                              : "${TxaLanguage.t('episode')} $epNameRaw";

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _currentEpisodeIndex = i;
                                  _showEpisodeDrawer = false;
                                });
                                _loadMarkers();
                                _initializePlayer();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: isCur
                                      ? TxaTheme.accent
                                      : Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: isCur
                                      ? null
                                      : Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.06,
                                          ),
                                        ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isCur
                                          ? Icons.play_circle_filled_rounded
                                          : Icons.play_arrow_rounded,
                                      color: isCur
                                          ? Colors.white
                                          : Colors.white54,
                                      size: isCur ? 24 : 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: isCur
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          fontSize: isCur ? 15 : 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isCur)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          TxaLanguage.t('watching'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
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
  }

  // --- SERVER SELECTION RIGHT PANEL ---
  Widget _buildServerSelectionOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _showServerDrawer = false),
      child: Container(
        color: Colors.black26,
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {}, // Prevent tap through
            child: Container(
              width: MediaQuery.of(context).size.width * 0.4,
              height: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF1A1F2E),
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.dns_rounded,
                                color: TxaTheme.accent,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  TxaLanguage.t('select_server'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white54,
                                  size: 22,
                                ),
                                onPressed: () =>
                                    setState(() => _showServerDrawer = false),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Current server + episode info
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: TxaTheme.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: TxaTheme.accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: TxaTheme.accent,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    widget.servers[_currentServerIndex]['server_name'] ??
                                        'Server',
                                    style: const TextStyle(
                                      color: TxaTheme.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            TxaLanguage.t('server_switch_hint'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: widget.servers.length,
                        itemBuilder: (ctx, i) {
                          final isCur = i == _currentServerIndex;
                          final serverName =
                              widget.servers[i]['server_name'] ??
                              'Server ${i + 1}';
                          final epCount =
                              (widget.servers[i]['server_data'] as List?)
                                  ?.length ??
                              0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () => _switchServer(i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: isCur
                                      ? TxaTheme.accent
                                      : Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: isCur
                                      ? null
                                      : Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.06,
                                          ),
                                        ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isCur
                                          ? Icons.check_circle_rounded
                                          : Icons.dns_outlined,
                                      color: isCur
                                          ? Colors.white
                                          : Colors.white54,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            serverName,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: isCur
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$epCount ${TxaLanguage.t('episode').toLowerCase()}',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.4,
                                              ),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isCur)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          TxaLanguage.t('current_label'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
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
  }

  Widget _buildSkipOverlay(String label, VoidCallback onTap, Alignment align) {
    return Positioned(
      bottom: 160, // Higher than total time label
      right: 40, // Both buttons now on the right side
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: TxaTheme.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 8,
          shadowColor: TxaTheme.accent.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: const BorderSide(color: Colors.white10),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.fast_forward_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingUI() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: TxaTheme.accent,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  TxaLanguage.t('loading_video'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_loadingPercent * 100).toStringAsFixed(1)}% | $_loadingSpeed',
                  style: const TextStyle(
                    color: TxaTheme.textMuted,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorUI() => Center(
    child: Text(
      _detailedError ?? TxaLanguage.t('video_error'),
      style: const TextStyle(color: Colors.white70),
    ),
  );

  String _formatDuration(Duration? d) {
    if (d == null) return "00:00";
    final hh = d.inHours;
    final mm = d.inMinutes.remainder(60);
    final ss = d.inSeconds.remainder(60);
    if (hh > 0) {
      return '$hh:${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
    }
    return '$mm:${ss.toString().padLeft(2, '0')}';
  }
}

class _CenterControlIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _CenterControlIcon({
    required this.icon,
    required this.onTap,
    this.size = 50,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: size),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  const _BottomBarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? TxaTheme.accent : Colors.white,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? TxaTheme.accent : Colors.white70,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color color;
  const _HeaderIcon({
    required this.icon,
    this.onTap,
    this.size = 24,
    this.color = Colors.white,
  });
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: size),
      onPressed: onTap,
    );
  }
}

class _PremiumRightPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _PremiumRightPanel({required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 300,
        height: double.infinity,
        decoration: BoxDecoration(
          color: TxaTheme.primaryBg.withValues(alpha: 0.95),
          border: const Border(left: BorderSide(color: Colors.white10)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings_rounded, color: TxaTheme.accent),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(child: ListView(children: children)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: TxaTheme.accent,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      value: value,
      activeThumbColor: TxaTheme.accent,
      onChanged: onChanged,
    );
  }
}

class _SliderRow extends StatefulWidget {
  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;
  const _SliderRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });
  @override
  _SliderRowState createState() => _SliderRowState();
}

class _SliderRowState extends State<_SliderRow> {
  late double _v;
  @override
  void initState() {
    super.initState();
    _v = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(widget.icon, color: TxaTheme.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Slider(
            value: _v,
            activeColor: TxaTheme.accent,
            onChanged: (v) {
              setState(() => _v = v);
              widget.onChanged(v);
            },
          ),
        ),
        Text(
          '${(_v * 100).toInt()}%',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          Theme(
            data: Theme.of(context).copyWith(canvasColor: TxaTheme.primaryBg),
            child: DropdownButton<T>(
              value: value,
              underline: const SizedBox.shrink(),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: TxaTheme.accent,
                size: 20,
              ),
              style: const TextStyle(
                color: TxaTheme.accent,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              items: items.entries.map((e) {
                return DropdownMenuItem<T>(value: e.key, child: Text(e.value));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
