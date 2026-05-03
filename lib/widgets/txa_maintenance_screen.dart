import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';

class TxaMaintenanceScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const TxaMaintenanceScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TxaTheme.accent.withValues(alpha: 0.15),
              ),
            ),
          ),
          
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Maintenance Icon
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(seconds: 1),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: child,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: TxaTheme.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: TxaTheme.accent.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: TxaTheme.accent.withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.engineering_rounded,
                        size: 80,
                        color: TxaTheme.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Text Content
                  Text(
                    TxaLanguage.t('maintenance_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    TxaLanguage.t('maintenance_msg'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: TxaTheme.textSecondary,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                        TxaLanguage.t('retry'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TxaTheme.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: TxaTheme.accent.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => SystemNavigator.pop(),
                    icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                    label: Text(TxaLanguage.t('exit_app')),
                    style: TextButton.styleFrom(
                      foregroundColor: TxaTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom Branding
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 0.3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/logo.png', height: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'TPHIMX PREMIUM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
