import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/txa_language.dart';
import 'txa_modal.dart';

class TxaUpdateModal extends StatelessWidget {
  final String version;
  final String changelog;
  final String? releaseDate;
  final String? fileSize;
  final VoidCallback onUpdate;
  final VoidCallback? onCancel;
  final bool forceUpdate;

  const TxaUpdateModal({
    super.key,
    required this.version,
    required this.changelog,
    this.releaseDate,
    this.fileSize,
    required this.onUpdate,
    this.onCancel,
    this.forceUpdate = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String version,
    required String changelog,
    String? releaseDate,
    String? fileSize,
    required VoidCallback onUpdate,
    VoidCallback? onCancel,
    bool forceUpdate = false,
  }) {
    return TxaModal.show(
      context,
      title: TxaLanguage.t('update_available'),
      barrierDismissible: !forceUpdate,
      showClose: !forceUpdate,
      content: TxaUpdateModal(
        version: version,
        changelog: changelog,
        releaseDate: releaseDate,
        fileSize: fileSize,
        onUpdate: onUpdate,
        onCancel: onCancel,
        forceUpdate: forceUpdate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !forceUpdate,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && forceUpdate) {
          SystemNavigator.pop();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueAccent.withValues(alpha: 0.22),
                      Colors.purpleAccent.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  TxaLanguage.t('version_label', replace: {'version': version}),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              if (fileSize != null)
                Text(
                  fileSize!,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
            ],
          ),
          if (releaseDate != null) ...[
            const SizedBox(height: 8),
            Text(
              releaseDate!,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            TxaLanguage.t('whats_new'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: Text(
                  changelog,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (!forceUpdate)
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel ?? () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(TxaLanguage.t('later')),
                  ),
                ),
              if (!forceUpdate) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(TxaLanguage.t('update_now')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
