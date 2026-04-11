import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/txa_language.dart';
import '../services/txa_network.dart';
import '../services/txa_permission.dart';

import '../services/txa_settings.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_toast.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const SplashScreen({super.key, required this.onFinish});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.0;
  String _status = '';
  String? _fatalError;
  bool _isIosLocked = false;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _startInit();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingUri(uri);
    });
  }

  void _handleIncomingUri(Uri uri) {
    if (uri.scheme == 'tphimx' && uri.host == 'udid') {
      final String? m = uri.queryParameters['m'];
      if (m != null && m.isNotEmpty) {
        final bool isValid = RegExp(r'^[a-fA-F0-9\-]{20,45}$').hasMatch(m);
        if (isValid) {
          TxaSettings.udid = m;
          TxaToast.show(context, '✅ Xác minh thiết bị thành công!');
          if (_isIosLocked) {
            setState(() {
              _isIosLocked = false;
              _status = 'Đang tiếp tục khởi động...';
            });
            _startInit();
          }
        } else {
          TxaToast.show(context, '❌ Mã UDID không hợp lệ: $m', isError: true);
        }
      }
    }
  }

  Future<void> _startInit() async {
    try {
      // 1. Initial Permission Request
      setState(() {
        _status = 'Kiểm tra quyền truy cập...';
        _progress = 0.2;
      });
      await TxaPermission.requestInitial();

      // 2. Initialize Language
      setState(() {
        _status = 'Khởi tạo ngôn ngữ...';
        _progress = 0.4;
      });
      await TxaLanguage.init();

      // 2.5 iOS UDID Check (Locked state)
      if (Platform.isIOS && TxaSettings.udid.isEmpty) {
        setState(() {
          _isIosLocked = true;
          _progress = 0.5;
          _status = 'Bạn chưa có quyền truy cập ứng dụng này.';
        });
        return; // Stop initialization until unlocked via deep link
      }
      
      // 3. Check Network
      setState(() {
        _status = TxaLanguage.t('connecting');
        _progress = 0.7;
      });
      final hasNet = await TxaNetwork().checkConnection();
      if (!hasNet) {
        _showError(TxaLanguage.t('network_error'));
        return;
      }

      // Success final progress update
      setState(() {
        _progress = 1.0;
        _status = TxaLanguage.t('success');
      });
      Future.delayed(const Duration(seconds: 1), widget.onFinish);
    } catch (e, stack) {
      debugPrint('[SplashError] $e\n$stack');
      setState(() {
        _fatalError = e.toString();
        _status = 'Khởi tạo thất bại';
      });
    }
  }

  Future<void> _handleGetUDID() async {
    String deviceName = "iPhone";
    try {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      deviceName = iosInfo.name;
    } catch (e) {
      deviceName = "iOS Device";
    }

    final String url = "https://asset.nrotxa.online/uuid?device_name=${Uri.encodeComponent(deviceName)}";
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      TxaToast.show(context, 'Không thể mở trình duyệt', isError: true);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxaTheme.cardBg,
        title: Text(TxaLanguage.t('error'), style: const TextStyle(color: Colors.white)),
        content: Text(msg, style: const TextStyle(color: TxaTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startInit();
            },
            child: Text(TxaLanguage.t('retry')),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_fatalError != null) {
      return _buildErrorView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', width: 80, height: 80),
            const SizedBox(height: 32),
            Container(
              width: 240,
              height: 6,
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(3)),
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: 240 * _progress,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [TxaTheme.accent, Color(0xFF818CF8)]),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${(_progress * 100).toInt()}%',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: TxaTheme.textMuted, fontSize: 13),
              ),
            ),
            if (_isIosLocked) ...[
               const SizedBox(height: 32),
               ElevatedButton.icon(
                 onPressed: _handleGetUDID,
                 icon: const Icon(Icons.apple_rounded),
                 label: const Text('Lấy quyền truy cập ứng dụng', style: TextStyle(fontWeight: FontWeight.bold)),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: TxaTheme.accent,
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                 ),
               ),
               const SizedBox(height: 16),
               const Text(
                 'Lưu ý: Bạn cần cài đặt Profile xác minh sau khi mở Safari.',
                 style: TextStyle(color: Colors.white30, fontSize: 11),
               ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
            const SizedBox(height: 24),
            const Text(
              'Oops! Đã có lỗi xảy ra',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: SelectableText(
                _fatalError ?? 'Lỗi không xác định',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _fatalError ?? 'NaN'));
                    TxaToast.show(context, 'Đã copy mã lỗi!');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy Lỗi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white12,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _fatalError = null;
                      _progress = 0;
                    });
                    _startInit();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Thử lại'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TxaTheme.accent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
