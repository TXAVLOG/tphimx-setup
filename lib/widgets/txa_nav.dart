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
        height: 66,
        decoration: BoxDecoration(
          // Glass morphism effect
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.02),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon section with pill highlight
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? TxaTheme.accent.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: isActive
                        ? TxaTheme.accent
                        : Colors.white.withValues(alpha: 0.5),
                    size: 24,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: TxaTheme.cardBg, width: 1.5),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        badgeCount > 9 ? '9+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: TxaTheme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
