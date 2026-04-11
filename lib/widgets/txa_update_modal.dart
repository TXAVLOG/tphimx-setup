import 'package:flutter/material.dart';
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                TxaLanguage.t('version_label').replaceAll('%version', version),
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
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
            style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          TxaLanguage.t('whats_new'),
          style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: Text(
                changelog,
                style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
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
                    side: const BorderSide(color: Colors.white24),
                    foregroundColor: Colors.white70,
                  ),
                  child: Text(TxaLanguage.t('later')),
                ),
              ),
            if (!forceUpdate) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: onUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text(TxaLanguage.t('update_now')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
