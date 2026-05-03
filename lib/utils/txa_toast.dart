import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';

class TxaToast {
  static final List<OverlayEntry> _entries = [];

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final overlay = Overlay.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    final bgColor = isError
        ? const Color(0xFFD74A4A).withValues(alpha: 0.9)
        : TxaTheme.accent.withValues(alpha: 0.88);
    final icon = isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_rounded;
    final borderColor = isError
        ? const Color(0xFFFFB4B4).withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.25);

    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: topInset + 14,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -16 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [bgColor, bgColor.withValues(alpha: 0.72)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    _entries.add(overlayEntry);
    overlay.insert(overlayEntry);
    Future.delayed(const Duration(milliseconds: 2800), () {
      _entries.remove(overlayEntry);
      overlayEntry.remove();
    });
  }
}
