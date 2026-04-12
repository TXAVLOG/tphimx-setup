import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';

class TxaNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const TxaNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Positioned(
      bottom: bottomPadding + 16,
      left: 20,
      right: 20,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0x990F172A), // More translucent for liquid feel
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: const Color(0x1FFFFFFF), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NavItem(
                      icon: Icons.home_rounded,
                      label: TxaLanguage.t('home'),
                      isActive: currentIndex == 0,
                      onTap: () => onTap(0),
                    ),
                    _NavItem(
                      icon: Icons.search_rounded,
                      label: TxaLanguage.t('search'),
                      isActive: currentIndex == 1,
                      onTap: () => onTap(1),
                    ),
                    _NavItem(
                      icon: Icons.calendar_today_rounded,
                      label: TxaLanguage.t('schedule'),
                      isActive: currentIndex == 2,
                      onTap: () => onTap(2),
                    ),
                    _NavItem(
                      icon: Icons.person_rounded,
                      label: TxaLanguage.t('profile'),
                      isActive: currentIndex == 3,
                      onTap: () => onTap(3),
                    ),
                    if (Platform.isIOS)
                      _NavItem(
                        icon: Icons.workspace_premium_rounded,
                        label: TxaLanguage.t('premium_tab'),
                        isActive: currentIndex == 4,
                        onTap: () => onTap(4),
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
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isActive ? TxaTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? TxaTheme.accent : TxaTheme.textMuted,
              size: 22,
            ),
            if (isActive) ...[
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? TxaTheme.accent : TxaTheme.textMuted,
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  height: 1.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
