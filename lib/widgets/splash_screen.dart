import 'dart:async';
import 'package:flutter/material.dart';
import '../services/txa_language.dart';
import '../services/txa_network.dart';
import '../services/txa_permission.dart';
import '../theme/txa_theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const SplashScreen({super.key, required this.onFinish});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.0;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _startInit();
  }

  Future<void> _startInit() async {
    // 1. Initial Permission Request (No modal, just system dialogs)
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
            Text(
              _status,
              style: const TextStyle(color: TxaTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
