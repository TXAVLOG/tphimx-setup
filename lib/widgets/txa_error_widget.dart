import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import 'txa_modal.dart';

class TxaErrorWidget extends StatelessWidget {
  final String message;
  final String? technicalDetails;
  final VoidCallback onRetry;

  const TxaErrorWidget({
    super.key,
    required this.message,
    this.technicalDetails,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        _showDiagnosticModal(context);
      },
      child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: TxaTheme.textMuted,
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (technicalDetails != null) ...[
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    technicalDetails!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: TxaTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: 180,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(TxaLanguage.t('retry')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TxaTheme.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _showDiagnosticModal(BuildContext context) {
    TxaModal.show(
      context,
      title: 'DIAGNOSTIC MODE',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bug_report_rounded, color: TxaTheme.accent, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Chế độ chẩn đoán nâng cao dành cho nhà phát triển.',
            textAlign: TextAlign.center,
            style: TextStyle(color: TxaTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          _buildModalOption(
            icon: Icons.copy_rounded,
            label: 'Copy Error Details',
            onTap: () {
              Clipboard.setData(ClipboardData(text: technicalDetails ?? message));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Error details copied to clipboard')),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildModalOption(
            icon: Icons.history_rounded,
            label: 'View Application Logs',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs are available in Settings > Account > Premium')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModalOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
