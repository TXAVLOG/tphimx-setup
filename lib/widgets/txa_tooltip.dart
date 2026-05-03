import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';

class TxaTooltip extends StatelessWidget {
  final Widget child;
  final String message;
  final tooltipKey = GlobalKey<TooltipState>();

  TxaTooltip({super.key, required this.child, required this.message});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      key: tooltipKey,
      message: message,
      triggerMode: TooltipTriggerMode.longPress,
      waitDuration: const Duration(milliseconds: 250),
      showDuration: const Duration(milliseconds: 1600),
      preferBelow: false,
      verticalOffset: 16,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            TxaTheme.secondaryBg.withValues(alpha: 0.95),
            TxaTheme.cardBg.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: TxaTheme.accent.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }
}
