import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/txa_config.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_toast.dart';

/// TxaDonateScreen — Màn hình donate ủng hộ (iOS only)
/// Hiển thị sau splash screen, trước khi vào app chính.
class TxaDonateScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const TxaDonateScreen({super.key, required this.onFinish});

  @override
  State<TxaDonateScreen> createState() => _TxaDonateScreenState();
}

class _TxaDonateScreenState extends State<TxaDonateScreen>
    with SingleTickerProviderStateMixin {
  String _transferContent = '';
  String _qrUrl = '';
  bool _isLoading = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Track which field was just copied for icon animation
  String? _copiedField;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _generateTransferContent();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _generateTransferContent() async {
    try {
      String deviceId = 'unknown';
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? iosInfo.name;

      // SHA256 hash → take first 6 chars → uppercase
      final hash = sha256.convert(utf8.encode(deviceId)).toString();
      final suffix = hash.substring(0, 6).toUpperCase();

      if (!mounted) return;
      setState(() {
        _transferContent = '${TxaConfig.donateContentPrefix}$suffix';
        _qrUrl = TxaConfig.buildQrUrl(transferContent: _transferContent);
        _isLoading = false;
      });
      _fadeController.forward();
    } catch (e) {
      if (!mounted) return;
      // Fallback with random-ish content
      setState(() {
        _transferContent =
            '${TxaConfig.donateContentPrefix}${DateTime.now().millisecondsSinceEpoch.toRadixString(36).substring(0, 6).toUpperCase()}';
        _qrUrl = TxaConfig.buildQrUrl(transferContent: _transferContent);
        _isLoading = false;
      });
      _fadeController.forward();
    }
  }

  Future<void> _copyToClipboard(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    setState(() {
      _copiedField = label;
    });
    TxaToast.show(context, '📋 Đã sao chép $label');

    // Reset icon after animation
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _copiedField = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: TxaTheme.accent),
              )
            : FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 24),
                  child: Column(
                    children: [
                      // ── Header ──
                      _buildHeader(),
                      const SizedBox(height: 20),

                      // ── QR Code Card ──
                      _buildQrCard(),
                      const SizedBox(height: 16),

                      // ── Transfer Info Cards ──
                      _buildInfoCard(
                        icon: Icons.person_rounded,
                        label: 'Chủ tài khoản',
                        value: TxaConfig.donateAccountName,
                        color: const Color(0xFF818CF8),
                      ),
                      const SizedBox(height: 10),
                      _buildInfoCard(
                        icon: Icons.account_balance_rounded,
                        label: 'Ngân hàng',
                        value: TxaConfig.donateBankName,
                        color: const Color(0xFF34D399),
                      ),
                      const SizedBox(height: 10),
                      _buildInfoCard(
                        icon: Icons.credit_card_rounded,
                        label: 'Số tài khoản',
                        value: TxaConfig.donateAccountNumber,
                        color: const Color(0xFFFBBF24),
                      ),
                      const SizedBox(height: 10),
                      _buildInfoCard(
                        icon: Icons.description_rounded,
                        label: 'Nội dung CK',
                        value: _transferContent,
                        color: const Color(0xFFF472B6),
                      ),
                      const SizedBox(height: 28),

                      // ── Enter App Button ──
                      _buildEnterButton(),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: TxaTheme.accent.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // Heart icon with glow
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [TxaTheme.accent, TxaTheme.purple],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: TxaTheme.accent.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Ủng hộ thớt nhé! 💜',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Donate tùy tâm để mình có động lực phát triển app tiếp nha.\nCảm ơn bạn rất nhiều! 🙏',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: TxaTheme.accent.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _qrUrl,
              width: 280,
              height: 280,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  width: 280,
                  height: 280,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: TxaTheme.accent,
                      strokeWidth: 3,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return SizedBox(
                  width: 280,
                  height: 280,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.qr_code_2_rounded,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Không tải được mã QR',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Quét mã QR để chuyển khoản',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final isCopied = _copiedField == label;

    return GestureDetector(
      onTap: () => _copyToClipboard(label, value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isCopied
              ? color.withValues(alpha: 0.08)
              : const Color(0xFF1A1F2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCopied
                ? color.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
            width: isCopied ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            // Label + Value
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            // Copy button with animated icon swap
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Container(
                key: ValueKey(isCopied),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isCopied
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCopied ? Icons.check_rounded : Icons.copy_rounded,
                  color: isCopied ? Colors.greenAccent : Colors.white54,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnterButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: widget.onFinish,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [TxaTheme.accent, TxaTheme.purple],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: TxaTheme.accent.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text(
                  'Vào App',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
