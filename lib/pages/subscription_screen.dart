import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_settings.dart';
import '../services/txa_api.dart';
import '../utils/txa_toast.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  List<dynamic> _packages = [];
  dynamic _selectedPackage;
  String _selectedCycle = 'monthly';
  String _paymentMethod = 'sepay'; // 'sepay' or 'manual'

  // Payment states for Manual or SePay
  bool _isProcessingPayment = false;
  String? _currentTxid;
  double _calculatedPrice = 0.0;
  String? _vietQrUrl;
  
  Map<String, dynamic> _paymentInfo = {};

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    final api = Provider.of<TxaApi>(context, listen: false);
    final res = await api.getPackages();
    final list = (res['packages'] is List) ? res['packages'] as List : [];
    final pay = (res['payment'] is Map<String, dynamic>) ? res['payment'] as Map<String, dynamic> : <String, dynamic>{};

    if (mounted) {
      setState(() {
        _packages = list;
        _paymentInfo = pay;
        if (_packages.isNotEmpty) {
          _selectedPackage = _packages.first;
        }
        _isLoading = false;
        _recalculatePrice();
      });
    }
  }

  void _recalculatePrice() {
    if (_selectedPackage == null) return;
    
    double basePrice = (_selectedPackage['price'] is num)
        ? (_selectedPackage['price'] as num).toDouble()
        : 69000.0;
    double baseAnnualPrice = (_selectedPackage['annual_price'] is num)
        ? (_selectedPackage['annual_price'] as num).toDouble()
        : 599000.0;

    int numMonths = 1;
    double discountRate = 0.0;

    switch (_selectedCycle) {
      case 'monthly':
        numMonths = 1;
        _calculatedPrice = basePrice;
        break;
      case '3months':
        numMonths = 3;
        _calculatedPrice = basePrice * 3;
        break;
      case '6months':
        numMonths = 6;
        discountRate = 0.05; // 5% off
        _calculatedPrice = basePrice * 6 * (1 - discountRate);
        break;
      case 'annual':
        numMonths = 12;
        _calculatedPrice = baseAnnualPrice > 0 ? baseAnnualPrice : (basePrice * 12 * 0.91); // ~9% off
        break;
    }
    
    _calculatedPrice = _calculatedPrice.roundToDouble();
  }

  List<String> _extractPackageFeatures(dynamic p) {
    if (p == null) return [];
    List<String> list = [];
    if (p['features'] is List) {
      list.addAll((p['features'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty));
    }
    if (p['permissions'] is Map) {
      final perm = p['permissions'] as Map;
      if (perm['bypass_ads'] == true && !list.any((e) => e.toLowerCase().contains('quảng cáo'))) {
        list.add('Xem phim không quảng cáo');
      }
      if (perm['max_resolution'] != null && !list.any((e) => e.contains('4K') || e.contains('1080p') || e.contains('HD'))) {
        list.add('Độ phân giải tối đa ${perm['max_resolution']}');
      }
      if (perm['watch_together'] == true && !list.any((e) => e.toLowerCase().contains('xem chung'))) {
        list.add('Hỗ trợ tính năng Xem Chung cùng bạn bè');
      }
      if (perm['vip_badge'] == true && !list.any((e) => e.toLowerCase().contains('huy hiệu'))) {
        list.add('Huy hiệu VIP độc quyền trên tài khoản');
      }
    }
    return list;
  }

  String _formatCurrency(double val) {
    return '${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}đ';
  }

  Future<void> _launchUrl(String urlStr) async {
    final Uri url = Uri.parse(urlStr);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        TxaToast.show(context, TxaLanguage.t('not_open_link'), isError: true);
      }
    }
  }

  Future<void> _processCheckout() async {
    if (TxaSettings.authToken.isEmpty) {
      TxaToast.show(context, TxaLanguage.t('login_required'), isError: true);
      return;
    }

    setState(() {
      _isProcessingPayment = true;
    });

    final api = Provider.of<TxaApi>(context, listen: false);
    
    // Generate transaction ID: TXAG for new, TXAU for update
    final String randomStr = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    final String txid = 'TXAG$randomStr';
    _currentTxid = txid;

    // Load active settings to get username and email
    String username = 'user';
    String email = 'user@example.com';
    try {
      final userResponse = await api.getAuthMe();
      if (userResponse != null && userResponse['data'] != null) {
        username = userResponse['data']['username'] ?? username;
        email = userResponse['data']['email'] ?? email;
      }
    } catch (_) {}

    final Map<String, dynamic> paymentData = {
      'txid': txid,
      'username': username,
      'email': email,
      'packageTitle': _selectedPackage['title'],
      'price': _calculatedPrice,
      'cycle': _selectedCycle,
      'method': _paymentMethod,
      'status': 'pending',
      'note': 'Flutter App Checkout'
    };

    // Save payment log on backend
    final saveResult = await api.createPaymentLog(paymentData);
    if (saveResult == null) {
      if (mounted) {
        TxaToast.show(context, TxaLanguage.t('error_connection'), isError: true);
        setState(() {
          _isProcessingPayment = false;
        });
      }
      return;
    }

    if (_paymentMethod == 'sepay') {
      // Initialize SePay Automated PG
      final initResult = await api.initSepayPayment(txid, _calculatedPrice, _selectedPackage['title']);
      if (initResult != null) {
        // SePay PG returns checkoutUrl directly in raw mode
        final String? checkoutUrl = initResult['checkoutUrl'];
        if (checkoutUrl != null) {
          await _launchUrl(checkoutUrl);
          if (mounted) {
            _showPaymentWaitingModal(txid);
          }
        } else {
          // Check enveloped format just in case
          final String? envCheckoutUrl = initResult['data']?['checkoutUrl'];
          if (envCheckoutUrl != null) {
            await _launchUrl(envCheckoutUrl);
            if (mounted) {
              _showPaymentWaitingModal(txid);
            }
          } else {
            if (mounted) {
              TxaToast.show(context, 'Lỗi không khởi tạo được cổng SePay.', isError: true);
            }
          }
        }
      } else {
        if (mounted) {
          TxaToast.show(context, 'Lỗi kết nối cổng SePay.', isError: true);
        }
      }
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    } else {
      // Manual Bank Transfer QR construction from dynamic backend payment settings
      final String bankName = _paymentInfo['bank_name'] ?? 'MBBank';
      final String accountNo = _paymentInfo['account_no'] ?? '0000000000';
      final String accountName = _paymentInfo['account_name'] ?? 'HE THONG RAP PHIM';
      
      _vietQrUrl = 'https://img.vietqr.io/image/$bankName-$accountNo-compact.png?amount=${_calculatedPrice.toInt()}&addInfo=$txid&accountName=${Uri.encodeComponent(accountName)}';

      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
        _showManualTransferBottomSheet(txid, bankName, accountNo, accountName);
      }
    }
  }

  void _showPaymentWaitingModal(String txid) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxaTheme.cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white10),
        ),
        title: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
            ),
            const SizedBox(width: 12),
            Text(
              TxaLanguage.t('payment_waiting'),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cổng thanh toán tự động SePay đã được mở. Vui lòng hoàn tất thanh toán trên trình duyệt.',
              style: TextStyle(color: TxaTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Mã giao dịch:', style: TextStyle(color: TxaTheme.textMuted, fontSize: 11)),
                  SelectableText(
                    txid,
                    style: const TextStyle(color: Colors.amber, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Go back to account screen
              TxaToast.show(context, 'Hệ thống đang xử lý thanh toán của bạn.');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(TxaLanguage.t('ok'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showManualTransferBottomSheet(String txid, String bankName, String accountNo, String accountName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: TxaTheme.primaryBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: const Border(top: BorderSide(color: Colors.white10)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    TxaLanguage.t('payment_waiting'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    TxaLanguage.t('payment_instruction'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: TxaTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  
                  // VietQR Image Card
                  Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Image.network(_vietQrUrl!, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bank details List
                  _buildTransferDetailRow(ctx, 'Ngân hàng', bankName, copyable: false),
                  _buildTransferDetailRow(ctx, 'Số tài khoản', accountNo, copyable: true),
                  _buildTransferDetailRow(ctx, 'Chủ tài khoản', accountName, copyable: false),
                  _buildTransferDetailRow(ctx, 'Nội dung chuyển khoản (Memo)', txid, copyable: true, isCode: true),
                  _buildTransferDetailRow(ctx, 'Số tiền', _formatCurrency(_calculatedPrice), copyable: false),

                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                      TxaToast.show(context, 'Cảm ơn bạn! Yêu cầu giao dịch đang được đối soát.');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(
                      TxaLanguage.t('pay_confirm'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildTransferDetailRow(BuildContext ctx, String label, String value, {bool copyable = false, bool isCode = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: TxaTheme.textMuted, fontSize: 12)),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: isCode ? Colors.amberAccent : Colors.white,
                    fontFamily: isCode ? 'monospace' : null,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (copyable) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      TxaToast.show(ctx, 'Đã sao chép $label!');
                    },
                    child: const Icon(Icons.copy_rounded, color: Colors.amber, size: 16),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          TxaLanguage.t('subscription_vip_title'),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // VIP Premium Banner Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.amber, Colors.orangeAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'VIP PREMIUM',
                              style: TextStyle(color: Colors.black80, fontWeight: FontWeight.black, fontSize: 20, letterSpacing: 1.5),
                            ),
                            Icon(Icons.workspace_premium_rounded, color: Colors.black80, size: 36),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          TxaLanguage.t('subscription_vip_desc'),
                          style: const TextStyle(color: Colors.black80, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Package list selector
                  const Text(
                    'CHỌN GÓI DỊCH VỤ',
                    style: TextStyle(color: TxaTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _packages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final p = _packages[idx];
                      final isSelected = _selectedPackage?['id'] == p['id'];
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedPackage = p;
                            _recalculatePrice();
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.amber.withValues(alpha: 0.08) : TxaTheme.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? Colors.amber : TxaTheme.glassBorder,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    p['title'] ?? '',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle_rounded, color: Colors.amber, size: 20)
                                  else
                                    const Icon(Icons.radio_button_off_rounded, color: TxaTheme.textMuted, size: 20),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_formatCurrency((p['price'] as num).toDouble())} / tháng',
                                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                               Builder(
                                builder: (_) {
                                  final feats = _extractPackageFeatures(p);
                                  if (feats.isEmpty) return const SizedBox.shrink();
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 12),
                                      ...feats.map((f) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.check_rounded, color: Colors.green, size: 14),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                f,
                                                style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 11),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Duration / Cycle selection
                  const Text(
                    'CHỌN CHU KỲ THANH TOÁN',
                    style: TextStyle(color: TxaTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildCycleButton('monthly', TxaLanguage.t('pkg_monthly')),
                      const SizedBox(width: 8),
                      _buildCycleButton('annual', TxaLanguage.t('pkg_annual') + ' (Giảm ~9%)'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Payment method selection
                  const Text(
                    'PHƯƠNG THỨC THANH TOÁN',
                    style: TextStyle(color: TxaTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: TxaTheme.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: TxaTheme.glassBorder),
                    ),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          value: 'sepay',
                          groupValue: _paymentMethod,
                          title: const Text('Cổng thanh toán SePay Tự Động', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Quét mã thanh toán ngân hàng nhận gói ngay lập tức.', style: TextStyle(color: TxaTheme.textMuted, fontSize: 11)),
                          activeColor: Colors.amber,
                          onChanged: (val) {
                            setState(() {
                              _paymentMethod = val!;
                            });
                          },
                        ),
                        const Divider(color: Colors.white10, height: 1),
                        RadioListTile<String>(
                          value: 'manual',
                          groupValue: _paymentMethod,
                          title: const Text('Chuyển khoản VietQR Thủ công', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Tự chuyển khoản & tải biên lai lên để chờ Admin duyệt.', style: TextStyle(color: TxaTheme.textMuted, fontSize: 11)),
                          activeColor: Colors.amber,
                          onChanged: (val) {
                            setState(() {
                              _paymentMethod = val!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Total amount card & action button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TỔNG CỘNG', style: TextStyle(color: TxaTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text('Giá đã gồm VAT', style: TextStyle(color: TxaTheme.textSecondary, fontSize: 11)),
                          ],
                        ),
                        Text(
                          _formatCurrency(_calculatedPrice),
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.black, fontSize: 22, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: _isProcessingPayment ? null : _processCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isProcessingPayment
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Text(
                            TxaLanguage.t('upgrade_vip_btn'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildCycleButton(String cycle, String label) {
    final isSelected = _selectedCycle == cycle;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCycle = cycle;
            _recalculatePrice();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.amber.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.amber : Colors.white10,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.amberAccent : Colors.white60,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
