import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tphimx_setup/services/txa_language.dart';
import '../theme/txa_theme.dart';

class TxaNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int unreadNotifications;
  final bool isLoggedIn;

  const TxaNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadNotifications = 0,
    this.isLoggedIn = false,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final horizontalMargin = 24.0;
    // Floating position: move it up slightly from the bottom, or account for system nav bar
    final bottomMargin = bottomPadding > 0 ? bottomPadding + 12.0 : 24.0;

    return Padding(
      padding: EdgeInsets.only(
        left: horizontalMargin,
        right: horizontalMargin,
        bottom: bottomMargin,
      ),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          // Frosted glass effect: white with low opacity
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 25,
              spreadRadius: -5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            // High blur for premium frost effect
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.1),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                    icon: Icons.calendar_month_rounded,
                    label: TxaLanguage.t('schedule'),
                    isActive: currentIndex == 2,
                    onTap: () => onTap(2),
                  ),
                  _NavItem(
                    icon: Icons.terminal_rounded,
                    label: TxaLanguage.t('logs'),
                    isActive: currentIndex == 3,
                    onTap: () => onTap(3),
                  ),
                  if (isLoggedIn)
                    _NavItem(
                      icon: Icons.notifications_rounded,
                      label: TxaLanguage.t('notifications'),
                      isActive: currentIndex == 4,
                      badgeCount: unreadNotifications,
                      onTap: () => onTap(4),
                    ),
                  _NavItem(
                    icon: Icons.person_rounded,
                    label: TxaLanguage.t('profile'),
                    isActive: currentIndex == 5,
                    onTap: () => onTap(5),
                  ),
                ],
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
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: double.infinity,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              // Light highlight for active item
              color: isActive ? TxaTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      color: isActive ? TxaTheme.accent : Colors.white70,
                      size: 22,
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            badgeCount > 9 ? '9+' : badgeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: TxaTheme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
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
