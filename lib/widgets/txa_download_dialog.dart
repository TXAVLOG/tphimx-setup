import 'package:flutter/material.dart';
import '../services/txa_download.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';

class TxaDownloadDialog extends StatefulWidget {
  final String url;
  final String filename;
  final Function(String path)? onFinished;

  const TxaDownloadDialog({
    super.key,
    required this.url,
    required this.filename,
    this.onFinished,
  });

  @override
  State<TxaDownloadDialog> createState() => _TxaDownloadDialogState();

  /// Static helper to show the dialog
  static Future<void> show(
    BuildContext context,
    String url,
    String filename, {
    Function(String path)? onFinished,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false, // Lock UI
      builder: (ctx) => TxaDownloadDialog(
        url: url,
        filename: filename,
        onFinished: onFinished,
      ),
    );
  }
}

class _TxaDownloadDialogState extends State<TxaDownloadDialog> {
  final TxaDownload _downloader = TxaDownload();
  Map<String, dynamic>? _progress;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  void _startDownload() async {
    final file = await _downloader.startDownload(
      widget.url,
      widget.filename,
      onProgress: (info) {
        if (mounted) setState(() => _progress = info);
      },
    );

    if (!mounted) return;

    if (file != null) {
      Navigator.pop(context); // Close dialog
      if (widget.onFinished != null) widget.onFinished!(file.path);
    } else {
      // If error (and not cancelled)
      if (!_downloader.isDownloading) {
        setState(
          () => _error =
              _downloader.lastError ?? TxaLanguage.t('cannot_download_update'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _progress;
    final progressVal = (info?['progress'] ?? 0.0) / 100.0;

    return PopScope(
      canPop: false, // Prevent back button
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: TxaTheme.primaryBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: TxaTheme.glassBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.downloading_rounded,
                color: TxaTheme.accent,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? TxaLanguage.t('downloading'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              if (_error == null) ...[
                Text(
                  widget.filename,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressVal,
                    backgroundColor: Colors.white10,
                    color: TxaTheme.accent,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${info?['formatted']?['downloaded'] ?? '0B'} / ${info?['formatted']?['total'] ?? '0B'}",
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      "${(progressVal * 100).toInt()}%",
                      style: const TextStyle(
                        color: TxaTheme.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${TxaLanguage.t('speed')}: ${info?['formatted']?['speed'] ?? '0 B/s'}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      "ETA: ${info?['formatted']?['eta'] ?? '00:00'}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _downloader.cancelDownload();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white10),
                        foregroundColor: Colors.white70,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        _error != null
                            ? TxaLanguage.t('close')
                            : TxaLanguage.t('cancel'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
