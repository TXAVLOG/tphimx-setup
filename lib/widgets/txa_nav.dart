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
    final horizontalMargin = 20.0;
    final bottomMargin = bottomPadding > 0 ? bottomPadding : 20.0;

    return Positioned(
      bottom: bottomMargin,
      left: horizontalMargin,
      right: horizontalMargin,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: TxaTheme.primaryBg.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.1),
              BlendMode.darken,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isActive ? TxaTheme.accent : Colors.white38,
                  size: 24,
                  shadows: isActive
                      ? [
                          Shadow(
                            color: TxaTheme.accent.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
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
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: TxaTheme.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
