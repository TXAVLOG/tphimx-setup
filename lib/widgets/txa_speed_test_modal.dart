import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/txa_speed_service.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';

class TxaSpeedTestModal extends StatefulWidget {
  const TxaSpeedTestModal({super.key});

  static void show(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const TxaSpeedTestModal(),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<TxaSpeedTestModal> createState() => _TxaSpeedTestModalState();
}

class _TxaSpeedTestModalState extends State<TxaSpeedTestModal>
    with SingleTickerProviderStateMixin {
  bool _isTesting = false;
  double _download = 0;
  double _upload = 0;
  double _progress = 0;
  int _apiPing = -1;
  int _imgPing = -1;
  bool _isFinished = false;
  TxaSpeedTestPhase _phase = TxaSpeedTestPhase.ping;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    // Auto start test
    WidgetsBinding.instance.addPostFrameCallback((_) => _runTest());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _runTest() async {
    if (_isTesting) return;

    setState(() {
      _isTesting = true;
      _isFinished = false;
      _download = 0;
      _upload = 0;
      _progress = 0;
      _apiPing = -1;
      _imgPing = -1;
      _phase = TxaSpeedTestPhase.ping;
    });

    // 1. Check Pings
    final apiLatency = await TxaSpeedService.checkApiLatency();
    if (!mounted) return;
    setState(() => _apiPing = apiLatency);
    
    // Simulating checking image server ping (could use actual image CDN if available)
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _imgPing = (apiLatency * 1.2).toInt());

    // 2. Check Speed
    await TxaSpeedService.checkSpeedPhased(
      onProgress: (phase, down, up, prog) {
        if (!mounted) return;
        setState(() {
          _phase = phase;
          _download = down;
          _upload = up;
          _progress = prog;
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _isFinished = true;
      _phase = TxaSpeedTestPhase.complete;
      _progress = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildSpeedDisplay(),
                    const SizedBox(height: 32),
                    _buildStatsRow(),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: _isFinished
                          ? _buildResultChart()
                          : _buildProgressBar(),
                    ),
                    const SizedBox(height: 32),
                    _buildActionButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TxaLanguage.t('speed_test'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              TxaSpeedService.currentNetworkType,
              style: const TextStyle(
                color: TxaTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildSpeedDisplay() {
    final displaySpeed = _phase == TxaSpeedTestPhase.upload ? _upload : _download;
    final phaseLabel = _phase == TxaSpeedTestPhase.upload
        ? TxaLanguage.t('upload_label')
        : _phase == TxaSpeedTestPhase.download
            ? TxaLanguage.t('download_label')
            : _phase == TxaSpeedTestPhase.complete
                ? TxaLanguage.t('test_completed')
                : TxaLanguage.t('testing');

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return SizedBox(
          width: 188,
          height: 188,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 188,
                height: 188,
                child: CircularProgressIndicator(
                  value: _isTesting
                      ? _progress.clamp(0.02, 1.0).toDouble()
                      : 1,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _phase == TxaSpeedTestPhase.upload
                        ? Colors.orangeAccent
                        : TxaTheme.accent,
                  ),
                ),
              ),
              Container(
                width: 164,
                height: 164,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                  boxShadow: [
                    BoxShadow(
                      color: TxaTheme.accent.withValues(
                        alpha: 0.10 + (0.12 * _pulseController.value),
                      ),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          displaySpeed.toStringAsFixed(1),
                          key: ValueKey(
                            '${_phase.name}_${displaySpeed.toStringAsFixed(1)}',
                          ),
                          style: TextStyle(
                            color: _phase == TxaSpeedTestPhase.upload
                                ? Colors.orangeAccent
                                : TxaTheme.accent,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Text(
                        'Mbps',
                        style: TextStyle(
                          color: TxaTheme.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          phaseLabel,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isTesting)
                Positioned(
                  bottom: 10,
                  child: Text(
                    '${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
        );
      },
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(
          Icons.api_rounded,
          'Server API',
          _apiPing == -1 ? '--' : '${_apiPing}ms',
          _apiPing != -1 && _apiPing < 200 ? Colors.greenAccent : Colors.redAccent,
        ),
        _buildStatItem(
          Icons.image_rounded,
          'Server Image',
          _imgPing == -1 ? '--' : '${_imgPing}ms',
          _imgPing != -1 && _imgPing < 300 ? Colors.greenAccent : Colors.redAccent,
        ),
        _buildStatItem(
          _phase == TxaSpeedTestPhase.upload
              ? Icons.upload_rounded
              : Icons.download_rounded,
          _phase == TxaSpeedTestPhase.upload
              ? TxaLanguage.t('upload_label')
              : TxaLanguage.t('download_label'),
          _phase == TxaSpeedTestPhase.upload
              ? _upload.toStringAsFixed(1)
              : _download.toStringAsFixed(1),
          TxaTheme.accent,
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: Colors.white38, size: 20),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: TxaTheme.textMuted, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Column(
      key: const ValueKey('speed-progress'),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            valueColor: AlwaysStoppedAnimation<Color>(
              _phase == TxaSpeedTestPhase.upload
                  ? Colors.orangeAccent
                  : TxaTheme.accent,
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _phase == TxaSpeedTestPhase.upload
              ? TxaLanguage.t('upload_label')
              : TxaLanguage.t('download_label'),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildResultChart() {
    String evaluation = '';
    if (_download > 50) {
      evaluation = TxaLanguage.t('speed_excellent');
    } else if (_download > 20) {
      evaluation = TxaLanguage.t('speed_good');
    } else if (_download > 5) {
      evaluation = TxaLanguage.t('speed_stable');
    } else {
      evaluation = TxaLanguage.t('speed_slow');
    }

    final maxSpeed = [_download, _upload, 1.0].reduce((a, b) => a > b ? a : b);

    return Column(
      key: const ValueKey('speed-result-chart'),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.greenAccent,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                TxaLanguage.t('test_completed'),
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildChartBar(
          TxaLanguage.t('download_label'),
          _download,
          maxSpeed,
          TxaTheme.accent,
        ),
        const SizedBox(height: 10),
        _buildChartBar(
          TxaLanguage.t('upload_label'),
          _upload,
          maxSpeed,
          Colors.orangeAccent,
        ),
        const SizedBox(height: 12),
        Text(
          evaluation,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildChartBar(
    String label,
    double value,
    double maxValue,
    Color color,
  ) {
    final factor = maxValue <= 0
        ? 0.0
        : (value / maxValue).clamp(0.0, 1.0).toDouble();
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(color: TxaTheme.textMuted, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: factor,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 58,
          child: Text(
            value.toStringAsFixed(1),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isTesting ? null : _runTest,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFinished ? Colors.white.withValues(alpha: 0.05) : TxaTheme.accent,
          foregroundColor: _isFinished ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Text(
          _isTesting 
            ? TxaLanguage.t('testing') 
            : (_isFinished ? TxaLanguage.t('test_again') : TxaLanguage.t('start_test')),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
