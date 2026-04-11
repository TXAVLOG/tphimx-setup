import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/txa_settings.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_toast.dart';

class TxaPlayer extends StatefulWidget {
  final dynamic movie;
  final List<dynamic> servers;
  final int? initialServerIndex;
  final String? initialEpisodeId;

  const TxaPlayer({
    super.key,
    required this.movie,
    required this.servers,
    this.initialServerIndex,
    this.initialEpisodeId,
  });

  @override
  State<TxaPlayer> createState() => _TxaPlayerState();
}

class _TxaPlayerState extends State<TxaPlayer> with TickerProviderStateMixin {
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
  bool _isLocked = false;
  String? _overlayLabel;
  IconData? _overlayIcon;
  double? _overlayValue; // 0.0 to 1.0
  Timer? _overlayTimer;
  
  bool _showControls = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _currentServerIndex = widget.initialServerIndex ?? 0;
    _currentEpisodeIndex = 0;
    _brightness = TxaSettings.brightness;
    _volume = TxaSettings.volume;

    _loadMarkers();

    if (widget.initialEpisodeId != null && widget.servers.isNotEmpty) {
      final episodes = widget.servers[_currentServerIndex]['server_data'] as List;
      for (int i = 0; i < episodes.length; i++) {
        if (episodes[i]['id'].toString() == widget.initialEpisodeId.toString()) {
          _currentEpisodeIndex = i;
          break;
        }
      }
    }

    _initializePlayer();
    _startControlsTimer();
  }

  void _loadMarkers() {
    final m = widget.movie;
    final server = widget.servers.isNotEmpty ? widget.servers[_currentServerIndex] : null;
    final serverData = server != null ? server['server_data'] as List : [];
    final episode = serverData.isNotEmpty && _currentEpisodeIndex < serverData.length ? serverData[_currentEpisodeIndex] : null;

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
    if (episode != null) {
      if (episode['intro_start'] != null) _introStart = (episode['intro_start'] as num).toDouble();
      if (episode['intro_end'] != null) _introEnd = (episode['intro_end'] as num).toDouble();
      if (episode['outro_start'] != null) _outroStart = (episode['outro_start'] as num).toDouble();
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
      
      // If hiding controls, also hide drawer
      if (!_showControls) {
         _showEpisodeDrawer = false;
      }
    }
  }

  bool _showEpisodeDrawer = false;


  Future<void> _initializePlayer() async {
    setState(() {
      _isInitialized = false;
      _error = false;
      _autoNextTriggered = false;
      _isEmbed = false;
    });

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final server = widget.servers.isNotEmpty ? widget.servers[_currentServerIndex] : null;
    final serverData = server != null ? server['server_data'] as List : [];
    if (serverData.isEmpty) {
       setState(() => _error = true);
       return;
    }

    final episode = serverData[_currentEpisodeIndex];
    
    final List<Map<String, String>> sources = [];
    if (episode['stream_v6']?.toString().isNotEmpty == true) sources.add({'type': 'stream', 'url': episode['stream_v6'], 'name': 'Stream V6'});
    if (episode['stream_m3u8']?.toString().isNotEmpty == true) sources.add({'type': 'stream', 'url': episode['stream_m3u8'], 'name': 'Stream M3U8'});
    if (episode['link_m3u8']?.toString().isNotEmpty == true) sources.add({'type': 'stream', 'url': episode['link_m3u8'], 'name': 'Link Direct'});
    if (episode['stream_embed']?.toString().isNotEmpty == true) sources.add({'type': 'embed', 'url': episode['stream_embed'], 'name': 'Embed Proxy'});
    if (episode['link_embed']?.toString().isNotEmpty == true) sources.add({'type': 'embed', 'url': episode['link_embed'], 'name': 'Embed Direct'});

    if (sources.isEmpty) {
      _detailedError = TxaLanguage.t('no_sources_found');
      setState(() => _error = true);
      return;
    }

    await _trySource(sources, 0, episode);
  }

  Future<void> _trySource(List<Map<String, String>> sources, int index, dynamic episode) async {
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
       subtitles = (episode['subtitles'] as List).map((s) => BetterPlayerSubtitlesSource(
         type: BetterPlayerSubtitlesSourceType.network,
         name: s['label'] ?? s['lang'] ?? 'Unknown',
         urls: [s['file']],
       )).toList();
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
      final pos = _betterPlayerController!.videoPlayerController?.value.position;
      final durObj = _betterPlayerController!.videoPlayerController?.value.duration;
      final ct = pos?.inSeconds.toDouble() ?? 0.0;
      final dur = durObj?.inSeconds.toDouble() ?? 0.0;

      if (_introEnd > _introStart && ct >= _introStart && ct <= _introEnd) {
        if (!_showSkipIntro) setState(() => _showSkipIntro = true);
        if (TxaSettings.autoSkipIntro && ct < _introEnd - 2) {
           _betterPlayerController!.seekTo(Duration(seconds: _introEnd.toInt()));
        }
      } else {
        if (_showSkipIntro) setState(() => _showSkipIntro = false);
      }

      if (_outroStart > 0 && ct >= _outroStart && ct <= (dur)) {
         if (!_showSkipOutro) setState(() => _showSkipOutro = true);
         if (TxaSettings.autoNextEpisode && !_autoNextTriggered && dur - ct < 10) {
            _autoNextTriggered = true;
            _showAutoNextCountdown();
         }
      } else {
         if (_showSkipOutro) setState(() => _showSkipOutro = false);
      }
    } else if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
       _handlePlayerError();
    }
  }

  Future<void> _handlePlayerError() async {
     if (_isRefreshing || !mounted) return;
     setState(() => _isRefreshing = true);
     _initializePlayer();
  }

  void _showAutoNextCountdown() {
     TxaToast.show(context, TxaLanguage.t('prep_next_ep'));
     Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _autoNextTriggered) _playNext();
     });
  }

  void _playNext() {
    final serverData = widget.servers[_currentServerIndex]['server_data'] as List;
    if (_currentEpisodeIndex < serverData.length - 1) {
       setState(() { _currentEpisodeIndex++; });
       _initializePlayer();
    } else {
       Navigator.pop(context);
    }
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
      });
    } else {
      // Right side: Volume
      setState(() {
        _volume = (_volume - delta).clamp(0.0, 1.0);
        _overlayIcon = _volume > 0 ? Icons.volume_up_rounded : Icons.volume_off_rounded;
        _overlayLabel = TxaLanguage.t('player_audio');
        _overlayValue = _volume;
        _betterPlayerController?.setVolume(_volume);
        TxaSettings.volume = _volume;
      });
    }
    _showOverlayFeedback();
  }

  void _showOverlayFeedback() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() { _overlayLabel = null; _overlayIcon = null; _overlayValue = null; });
    });
  }

  void _onDoubleTap(TapDownDetails details, double width) {
    if (_isLocked || _betterPlayerController == null) return;
    const seekDuration = 10;
    if (details.globalPosition.dx < width / 2) {
      _betterPlayerController!.seekTo(_betterPlayerController!.videoPlayerController!.value.position - const Duration(seconds: seekDuration));
      _overlayIcon = Icons.fast_rewind_rounded;
      _overlayLabel = TxaLanguage.t('player_seek_backward').replaceAll('%count', '$seekDuration');
    } else {
      _betterPlayerController!.seekTo(_betterPlayerController!.videoPlayerController!.value.position + const Duration(seconds: seekDuration));
      _overlayIcon = Icons.fast_forward_rounded;
      _overlayLabel = TxaLanguage.t('player_seek_forward').replaceAll('%count', '$seekDuration');
    }
    _showOverlayFeedback();
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

  @override
  void dispose() {
    _betterPlayerController?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
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
                  ? (_isEmbed ? WebViewWidget(controller: _webViewController!) : BetterPlayer(controller: _betterPlayerController!))
                  : _error ? _buildErrorUI() : _buildLoadingUI(),
            ),

            // 2. WATERMARK (Corner)
            Positioned(
              top: 40,
              right: 20,
              child: Opacity(
                opacity: 0.3,
                child: Text(
                  TxaLanguage.t('player_watermark'),
                  style: const TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 1.2),
                ),
              ),
            ),

            // 3. GESTURE FEEDBACK OVERLAY
            if (_overlayLabel != null || _overlayIcon != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_overlayIcon, color: Colors.white, size: 40),
                      const SizedBox(height: 8),
                      Text(_overlayLabel!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      if (_overlayValue != null) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 100,
                          child: LinearProgressIndicator(value: _overlayValue, backgroundColor: Colors.white24, color: TxaTheme.accent),
                        ),
                      ]
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


            // 5. SKIP BUTTONS
            if (_showSkipIntro) _buildSkipOverlay(TxaLanguage.t('skip_intro'), () {
               _betterPlayerController!.seekTo(Duration(seconds: _introEnd.toInt()));
            }, Alignment.bottomLeft),
            if (_showSkipOutro) _buildSkipOverlay(TxaLanguage.t('skip_outro_next'), _playNext, Alignment.bottomRight),
          ],
        ),
      ),
    );
  }

  Widget _buildControlOverlay() {
    final serverData = widget.servers[_currentServerIndex]['server_data'] as List;
    final ep = serverData[_currentEpisodeIndex];
    
    return Stack(
      children: [
        // GRADIENTS
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black87],
                  stops: const [0.0, 0.2, 0.7, 1.0],
                ),
              ),
            ),
          ),
        ),

        // TOP BAR
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                   IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 28), 
                    onPressed: () => Navigator.pop(context)
                  ),
                  const SizedBox(width: 8),
                  _HeaderIcon(
                    icon: _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                    onTap: () => setState(() => _isLocked = !_isLocked),
                    color: _isLocked ? TxaTheme.accent : Colors.white,
                    size: 26,
                  ),
                  const Spacer(),
                  Expanded(
                    flex: 12,
                    child: Text(
                      "(${TxaLanguage.t('app_name')} - ${widget.movie['name']} ${TxaLanguage.t('episode')} ${ep['name']})", 
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const Spacer(),
                  _HeaderIcon(icon: Icons.cast_connected_rounded, onTap: () {}),
                  _HeaderIcon(icon: Icons.settings_outlined, onTap: _showFullSettings),
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
                  onTap: () => _onDoubleTap(TapDownDetails(globalPosition: Offset(MediaQuery.of(context).size.width * 0.2, 0)), MediaQuery.of(context).size.width)
                ),
                const SizedBox(width: 60),
                _CenterControlIcon(
                  icon: _betterPlayerController?.videoPlayerController?.value.isPlaying ?? false ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
                  onTap: () => _onDoubleTap(TapDownDetails(globalPosition: Offset(MediaQuery.of(context).size.width * 0.8, 0)), MediaQuery.of(context).size.width)
                ),
              ],
            ),
          ),

        // BOTTOM BAR (SEEK & NAVIGATION)
        if (!_isLocked)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isEmbed && _betterPlayerController != null)
                      _buildProgressBar(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _BottomBarItem(icon: Icons.aspect_ratio_rounded, label: TxaLanguage.t('player_ratio'), onTap: _showAudioSettings),
                        const SizedBox(width: 40),
                        _BottomBarItem(icon: Icons.mic_none_rounded, label: TxaLanguage.t('player_audio_track'), onTap: _showAudioSettings),
                        const SizedBox(width: 40),
                        _BottomBarItem(icon: Icons.playlist_play_rounded, label: TxaLanguage.t('player_episodes'), onTap: () => setState(() => _showEpisodeDrawer = true)),
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
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app_rounded, color: Colors.amber, size: 16),
                      const SizedBox(width: 6),
                      Text(TxaLanguage.t('player_seek_hint_short'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
              children: [
                Text(_formatDuration(value.position), style: const TextStyle(color: Colors.white, fontSize: 11)),
                Text(_formatDuration(value.duration), style: const TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                activeTrackColor: TxaTheme.accent,
                inactiveTrackColor: Colors.white24,
                activeTickMarkColor: Colors.transparent,
                inactiveTickMarkColor: Colors.transparent,
                trackShape: const RectangularSliderTrackShape(),
              ),
              child: Slider(
                value: pos.clamp(0.0, dur > 0 ? dur : 0.0),
                max: dur > 0 ? dur : 1.0,
                onChanged: (v) => _betterPlayerController!.seekTo(Duration(seconds: v.toInt())),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAudioSettings() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => _PremiumSettingsSheet(
        title: TxaLanguage.t('player_audio'),
        children: [
          _SheetItem(label: 'Server: ${widget.servers[_currentServerIndex]['server_name']}', icon: Icons.storage_rounded, onTap: () {}),
          _SheetItem(label: 'Phụ đề: Auto', icon: Icons.subtitles_rounded, onTap: () {}),
        ],
      ),
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
                  label: Text('${s}x', style: TextStyle(color: isCur ? Colors.white : Colors.white70)),
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
                      _overlayLabel = "${TxaLanguage.t('speed')}: ${s}x";
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
                  TxaSettings.volume = v;
                  _volume = v;
                  _betterPlayerController?.setVolume(v);
                });
              },
            ),
            const Divider(color: Colors.white10, height: 32),

            // 3. TOGGLES
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
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(anim1),
          child: child,
        );
      },
    );
  }

  // Removed _showEpisodeList as it is now handled inline

  Widget _buildEpisodeSelectionOverlay() {
    final serverData = widget.servers[_currentServerIndex]['server_data'] as List;
    
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
                      child: Row(
                        children: [
                          const Icon(Icons.sort_rounded, color: Colors.white70),
                          const SizedBox(width: 10),
                          Text(TxaLanguage.t('series_parts'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70),
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
                          final bool isClean = epNameRaw.toLowerCase().contains("tập") || epNameRaw.toLowerCase().contains("episode");
                          final displayName = isClean ? epNameRaw : "${TxaLanguage.t('episode')} $epNameRaw";

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () { 
                                setState(() { _currentEpisodeIndex = i; _showEpisodeDrawer = false; }); 
                                _initializePlayer(); 
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: isCur ? TxaTheme.accent : Colors.white12, 
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.play_arrow_rounded, color: isCur ? Colors.white : Colors.white70),
                                    const SizedBox(width: 12),
                                    Text(
                                      displayName, 
                                      style: TextStyle(
                                        color: isCur ? Colors.white : Colors.white, 
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15
                                      )
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

  // Removed _buildEpisodeSelectionOverlayLegacy

  Widget _buildSkipOverlay(String label, VoidCallback onTap, Alignment align) {
    return Positioned(
      bottom: 100,
      left: align == Alignment.bottomLeft ? 40 : null,
      right: align == Alignment.bottomRight ? 40 : null,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: TxaTheme.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLoadingUI() => const Center(child: CircularProgressIndicator(color: TxaTheme.accent));
  Widget _buildErrorUI() => Center(child: Text(_detailedError ?? TxaLanguage.t('video_error'), style: const TextStyle(color: Colors.white70)));

  String _formatDuration(Duration? d) {
    if (d == null) return "00:00";
    final hh = d.inHours;
    final mm = d.inMinutes.remainder(60);
    final ss = d.inSeconds.remainder(60);
    if (hh > 0) return '$hh:${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
    return '$mm:${ss.toString().padLeft(2, '0')}';
  }
}

class _CenterControlIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _CenterControlIcon({required this.icon, required this.onTap, this.size = 50});
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
  const _BottomBarItem({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
  const _HeaderIcon({required this.icon, this.onTap, this.size = 24, this.color = Colors.white});
  @override
  Widget build(BuildContext context) {
    return IconButton(icon: Icon(icon, color: color, size: size), onPressed: onTap);
  }
}

class _PremiumSettingsSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _PremiumSettingsSheet({required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: TxaTheme.primaryBg.withValues(alpha: 0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 32, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ...children,
          const SizedBox(height: 24),
        ],
      ),
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
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white70), onPressed: () => Navigator.pop(context)),
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
      child: Text(title, style: const TextStyle(color: TxaTheme.accent, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1)),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      value: value,
      activeThumbColor: TxaTheme.accent,
      onChanged: onChanged,
    );
  }
}

class _SheetItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SheetItem({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: TxaTheme.textSecondary),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }
}

class _SliderRow extends StatefulWidget {
  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;
  const _SliderRow({required this.label, required this.icon, required this.value, required this.onChanged});
  @override
  _SliderRowState createState() => _SliderRowState();
}
class _SliderRowState extends State<_SliderRow> {
  late double _v; @override void initState() { super.initState(); _v = widget.value; }
  @override Widget build(BuildContext context) {
    return Row(children: [
      Icon(widget.icon, color: TxaTheme.textSecondary, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Slider(value: _v, activeColor: TxaTheme.accent, onChanged: (v) { setState(() => _v = v); widget.onChanged(v); })),
      Text('${(_v * 100).toInt()}%', style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]);
  }
}
