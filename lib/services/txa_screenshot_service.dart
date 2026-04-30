import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenshot_detect/flutter_screenshot_detect.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/txa_logger.dart';
import '../widgets/txa_screenshot_popup.dart';

class TxaScreenshotService {
  static final TxaScreenshotService _instance =
      TxaScreenshotService._internal();
  factory TxaScreenshotService() => _instance;
  TxaScreenshotService._internal();

  final ScreenshotController screenshotController = ScreenshotController();
  OverlayEntry? _overlayEntry;
  bool _isListening = false;
  StreamSubscription? _subscription;

  void init(BuildContext context) {
    if (_isListening) return;
    _isListening = true;

    _subscription = FlutterScreenshotDetect().onScreenshot.listen((
      event,
    ) async {
      TxaLogger.log('Screenshot detected! ${DateTime.now()}');

      // Capture current widget tree (including our watermark)
      try {
        final directory = await getTemporaryDirectory();
        final String fileName =
            'screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
        final path = await screenshotController.captureAndSave(
          directory.path,
          fileName: fileName,
        );

        if (path != null && context.mounted) {
          _showPopup(context, path);
        }
      } catch (e) {
        TxaLogger.log('Failed to capture screenshot: $e', isError: true);
      }
    });
  }

  void _showPopup(BuildContext context, String path) {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) => TxaScreenshotPopup(
        imagePath: path,
        onDismiss: () {
          _overlayEntry?.remove();
          _overlayEntry = null;
        },
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void dispose() {
    _subscription?.cancel();
    _isListening = false;
  }
}
