import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';

class TxaDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? label;
  final IconData? icon;

  const TxaDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              color: TxaTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: TxaTheme.glassBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TxaTheme.glassBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: value,
                  items: items,
                  onChanged: onChanged,
                  isExpanded: true,
                  dropdownColor: const Color(
                    0xFF0F172A,
                  ), // Dark surface for menu
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: TxaTheme.accent,
                    size: 20,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  style: const TextStyle(
                    color: TxaTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
