import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/txa_theme.dart';

class TxaModal extends StatelessWidget {
  final String title;
  final Widget? content;
  final List<Widget>? actions;
  final bool showClose;
  final VoidCallback? onClose;

  const TxaModal({
    super.key,
    required this.title,
    this.content,
    this.actions,
    this.showClose = true,
    this.onClose,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    Widget? content,
    List<Widget>? actions,
    bool barrierDismissible = true,
    bool showClose = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => TxaModal(
        title: title,
        content: content,
        actions: actions,
        showClose: showClose,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  TxaTheme.secondaryBg.withValues(alpha: 0.95),
                  TxaTheme.cardBg.withValues(alpha: 0.92),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.38),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (showClose)
                      IconButton(
                        onPressed: onClose ?? () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          foregroundColor: Colors.white70,
                          minimumSize: const Size(34, 34),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                if (content != null) ...[
                  const SizedBox(height: 14),
                  Flexible(child: SingleChildScrollView(child: content!)),
                ],
                if (actions != null && actions!.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 8,
                    children: actions!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
