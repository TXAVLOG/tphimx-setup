import 'dart:math';
import 'package:flutter/material.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';

class TxaCoachMarkTarget {
  final GlobalKey key;
  final String titleKey;
  final String descKey;
  final IconData icon;
  final CoachMarkPosition tooltipPosition;

  TxaCoachMarkTarget({
    required this.key,
    required this.titleKey,
    required this.descKey,
    required this.icon,
    this.tooltipPosition = CoachMarkPosition.bottom,
  });
}

enum CoachMarkPosition { top, bottom, left, right }

class TxaCoachMark {
  static OverlayEntry? _overlayEntry;
  static int _currentStep = 0;
  static List<TxaCoachMarkTarget> _targets = [];
  static VoidCallback? _onFinish;

  static void show({
    required BuildContext context,
    required List<TxaCoachMarkTarget> targets,
    VoidCallback? onFinish,
  }) {
    if (targets.isEmpty) return;
    _targets = targets;
    _currentStep = 0;
    _onFinish = onFinish;

    _overlayEntry = OverlayEntry(
      builder: (context) => _CoachMarkOverlay(
        targets: targets,
        onNext: _next,
        onSkip: _skip,
        onFinish: _finish,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void _next() {
    _currentStep++;
    if (_currentStep >= _targets.length) {
      _finish();
    } else {
      _overlayEntry?.markNeedsBuild();
    }
  }

  static void _skip() {
    _finish();
  }

  static void _finish() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _onFinish?.call();
  }

  static int get currentStep => _currentStep;
  static int get totalSteps => _targets.length;
}

class _CoachMarkOverlay extends StatefulWidget {
  final List<TxaCoachMarkTarget> targets;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onFinish;

  const _CoachMarkOverlay({
    required this.targets,
    required this.onNext,
    required this.onSkip,
    required this.onFinish,
  });

  @override
  State<_CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<_CoachMarkOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _slideController.forward();
    _updateTargetRect();
  }

  @override
  void didUpdateWidget(covariant _CoachMarkOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateTargetRect();
    _slideController.forward(from: 0);
  }

  void _updateTargetRect() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = widget.targets[TxaCoachMark.currentStep];
      final renderBox = target.key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final offset = renderBox.localToGlobal(Offset.zero);
        setState(() {
          _targetRect = Rect.fromLTWH(
            offset.dx - 8,
            offset.dy - 8,
            renderBox.size.width + 16,
            renderBox.size.height + 16,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = TxaCoachMark.currentStep;
    final target = widget.targets[currentStep];
    final size = MediaQuery.of(context).size;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          // Dark overlay with hole
          GestureDetector(
            onTap: () {}, // Absorb taps outside tooltip
            child: CustomPaint(
              size: Size(size.width, size.height),
              painter: _HolePainter(
                holeRect: _targetRect,
                overlayColor: Colors.black.withValues(alpha: 0.78),
              ),
            ),
          ),

          // Pulsing ring around target
          if (_targetRect != null)
            Positioned(
              left: _targetRect!.left,
              top: _targetRect!.top,
              width: _targetRect!.width,
              height: _targetRect!.height,
              child: _PulseRing(),
            ),

          // Tooltip
          if (_targetRect != null)
            _buildTooltip(target, size),

          // Top progress bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 24,
            right: 24,
            child: Row(
              children: [
                // Step dots
                Expanded(
                  child: Row(
                    children: List.generate(widget.targets.length, (i) {
                      final isActive = i == currentStep;
                      final isDone = i < currentStep;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isDone || isActive
                              ? TxaTheme.accent
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
                // Skip button
                GestureDetector(
                  onTap: widget.onSkip,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      TxaLanguage.t('skip'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltip(TxaCoachMarkTarget target, Size screenSize) {
    final isLast = TxaCoachMark.currentStep == widget.targets.length - 1;

    // Calculate tooltip position
    Offset tooltipOffset;
    double maxWidth = min(340, screenSize.width - 48);

    switch (target.tooltipPosition) {
      case CoachMarkPosition.bottom:
        tooltipOffset = Offset(
          (screenSize.width - maxWidth) / 2,
          _targetRect!.bottom + 20,
        );
        break;
      case CoachMarkPosition.top:
        tooltipOffset = Offset(
          (screenSize.width - maxWidth) / 2,
          max(_targetRect!.top - 220, 60),
        );
        break;
      case CoachMarkPosition.left:
      case CoachMarkPosition.right:
        tooltipOffset = Offset(
          (screenSize.width - maxWidth) / 2,
          _targetRect!.center.dy - 80,
        );
        break;
    }

    // Ensure tooltip stays within screen
    tooltipOffset = Offset(
      tooltipOffset.dx.clamp(24, screenSize.width - maxWidth - 24),
      tooltipOffset.dy.clamp(60, screenSize.height - 240),
    );

    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        final slideValue = CurvedAnimation(
          parent: _slideController,
          curve: Curves.easeOutCubic,
        ).value;

        final yOffset = (1 - slideValue) * 30;

        return Positioned(
          left: tooltipOffset.dx,
          top: tooltipOffset.dy + yOffset,
          width: maxWidth,
          child: Opacity(
            opacity: slideValue,
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: TxaTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: TxaTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    target.icon,
                    color: TxaTheme.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${TxaCoachMark.currentStep + 1}/${widget.targets.length}',
                        style: TextStyle(
                          color: TxaTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        TxaLanguage.t(target.titleKey),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              TxaLanguage.t(target.descKey),
              style: const TextStyle(
                color: TxaTheme.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // Navigation dots (small)
                Row(
                  children: List.generate(widget.targets.length, (i) {
                    return Container(
                      margin: const EdgeInsets.only(right: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == TxaCoachMark.currentStep
                            ? TxaTheme.accent
                            : Colors.white.withValues(alpha: 0.2),
                      ),
                    );
                  }),
                ),
                const Spacer(),
                if (!isLast)
                  GestureDetector(
                    onTap: widget.onSkip,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        TxaLanguage.t('skip'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: isLast ? widget.onFinish : widget.onNext,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [TxaTheme.accent, TxaTheme.purple],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isLast ? TxaLanguage.t('got_it') : TxaLanguage.t('next'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

class _HolePainter extends CustomPainter {
  final Rect? holeRect;
  final Color overlayColor;

  _HolePainter({this.holeRect, required this.overlayColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    if (holeRect == null) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    final path = Path();
    path.addRect(Offset.zero & size);

    final holePath = Path();
    final rrect = RRect.fromRectAndRadius(holeRect!, const Radius.circular(16));
    holePath.addRRect(rrect);

    final resultPath = Path.combine(PathOperation.difference, path, holePath);
    canvas.drawPath(resultPath, paint);

    // Subtle glow around hole
    final glowPaint = Paint()
      ..color = TxaTheme.accent.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rrect, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PulseRing extends StatefulWidget {
  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final opacity = 1.0 - progress;
        final scale = 1.0 + (progress * 0.15);

        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: TxaTheme.accent.withValues(alpha: opacity * 0.5),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}
