import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';

class TxaLoading extends StatelessWidget {
  final String? message;
  const TxaLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Premium Logo Animation or just Blur logo
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.2),
            duration: const Duration(seconds: 1),
            curve: Curves.easeInOutSine,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: 0.8 + (value - 1.0) * 0.5,
                  child: child,
                ),
              );
            },
            onEnd:
                () {}, // Restart is handled by logic elsewhere or just use a repetitive animation
            child: Image.asset('assets/logo.png', height: 80),
          ),
          const SizedBox(height: 32),
          // Gradient Spinner
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(TxaTheme.accent),
              backgroundColor: TxaTheme.accent.withValues(alpha: 0.1),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 24),
            Text(
              message!,
              style: TextStyle(
                color: TxaTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TxaSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const TxaSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: TxaTheme.cardBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Stack(
        children: [
          // Shimmer effect
          _ShimmerGradient(
            width: width,
            height: height,
            borderRadius: borderRadius,
          ),
        ],
      ),
    );
  }
}

class _ShimmerGradient extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _ShimmerGradient({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  State<_ShimmerGradient> createState() => _ShimmerGradientState();
}

class _ShimmerGradientState extends State<_ShimmerGradient>
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
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.05),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }
}
