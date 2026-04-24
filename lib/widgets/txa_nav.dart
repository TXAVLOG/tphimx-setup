import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';

class TxaNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int unreadNotifications;

  const TxaNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadNotifications = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Positioned(
      bottom: bottomPadding + 12,
      left: 16,
      right: 16,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          height: 68,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: -10,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: TxaTheme.accent.withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: -5,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                        icon: Icons.notifications_rounded,
                        label: TxaLanguage.t('notifications'),
                        isActive: currentIndex == 3,
                        onTap: () => onTap(3),
                        badgeCount: unreadNotifications,
                      ),
                      _NavItem(
                        icon: Icons.person_rounded,
                        label: TxaLanguage.t('profile'),
                        isActive: currentIndex == 4,
                        onTap: () => onTap(4),
                      ),
                      if (Platform.isIOS)
                        _NavItem(
                          icon: Icons.workspace_premium_rounded,
                          label: TxaLanguage.t('premium_tab'),
                          isActive: currentIndex == 5,
                          onTap: () => onTap(5),
                        ),
                    ],
                  ),
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              padding: EdgeInsets.all(isActive ? 8 : 4),
              decoration: BoxDecoration(
                color: isActive 
                    ? TxaTheme.accent.withValues(alpha: 0.15) 
                    : Colors.transparent,
                shape: BoxShape.circle,
                boxShadow: isActive ? [
                  BoxShadow(
                    color: TxaTheme.accent.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ] : null,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: isActive ? TxaTheme.accent : Colors.white.withValues(alpha: 0.5),
                    size: isActive ? 24 : 22,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
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
            ),
            const SizedBox(height: 4),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isActive ? 1.0 : 0.0,
              child: Text(
                label,
                style: const TextStyle(
                  color: TxaTheme.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
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
