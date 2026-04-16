import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/txa_api.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String token;
  const EmailVerificationScreen({super.key, required this.token});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _verifying = true;
  String? _error;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      final res = await api.verifyEmail(widget.token);

      setState(() {
        _verifying = false;
        _success = res['success'] == true;
        if (!_success) _error = res['message'] ?? 'Xác minh thất bại';
      });
    } catch (e) {
      setState(() {
        _verifying = false;
        _success = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(TxaLanguage.t('verify_email')),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_verifying) ...[
                const CircularProgressIndicator(color: TxaTheme.accent),
                const SizedBox(height: 24),
                Text(
                  TxaLanguage.t('verifying_email'),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ] else if (_success) ...[
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.greenAccent,
                  size: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  TxaLanguage.t('verify_success'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  TxaLanguage.t('verify_success_msg'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: TxaTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TxaTheme.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(TxaLanguage.t('continue')),
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  TxaLanguage.t('verify_failed'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _error ?? TxaLanguage.t('verify_failed_msg'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: TxaTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(TxaLanguage.t('retry')),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
