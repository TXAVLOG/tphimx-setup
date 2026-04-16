import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../services/txa_api.dart';
import '../services/txa_settings.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_toast.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _showLoginPassword = false;
  bool _showRegPassword = false;

  String? _loginEmailError;
  String? _loginPasswordError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      TxaToast.show(
        context,
        TxaLanguage.t('error_empty_fields'),
        isError: true,
      );
      return;
    }

    setState(() {
      _loading = true;
      _loginEmailError = null;
      _loginPasswordError = null;
    });
    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      final res = await api.login(email, password);

      if (res.statusCode == 200 && res.data['data'] != null) {
        final token = res.data['data']['token'];
        TxaSettings.authToken = token;
        api.setToken(token);

        if (mounted) {
          TxaToast.show(context, TxaLanguage.t('login_success'));
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          TxaToast.show(
            context,
            res.data['message'] ?? TxaLanguage.t('error_login'),
            isError: true,
          );
        }
      }
    } catch (e) {
      String errorMsg = TxaLanguage.t('error_login');
      if (e is DioException) {
        final data = e.response?.data;
        if (data != null && data['message'] != null) {
          errorMsg = data['message'];
          final errorCode = data['data'] != null
              ? data['data']['error_code']
              : null;

          setState(() {
            if (errorCode == 'USER_NOT_FOUND') {
              _loginEmailError = errorMsg;
            } else if (errorCode == 'INVALID_PASSWORD') {
              _loginPasswordError = errorMsg;
            }
          });
        } else if (e.type == DioExceptionType.connectionTimeout) {
          errorMsg = 'Kết nối quá hạn. Vui lòng thử lại.';
        }
      }
      if (mounted) {
        TxaToast.show(context, errorMsg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRegister() async {
    final name = _regNameController.text.trim();
    final email = _regEmailController.text.trim();
    final password = _regPasswordController.text;
    final confirm = _regConfirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      TxaToast.show(
        context,
        TxaLanguage.t('error_empty_fields'),
        isError: true,
      );
      return;
    }

    if (password != confirm) {
      TxaToast.show(
        context,
        TxaLanguage.t('error_password_mismatch'),
        isError: true,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      final res = await api.register(name, email, password, confirm);

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          TxaToast.show(context, TxaLanguage.t('register_success'));
          _tabController.animateTo(0);
        }
      } else {
        if (mounted) {
          TxaToast.show(
            context,
            res.data['message'] ?? TxaLanguage.t('error_register'),
            isError: true,
          );
        }
      }
    } catch (e) {
      String errorMsg = TxaLanguage.t('error_register');
      if (e is DioException) {
        if (e.response?.data != null && e.response?.data['message'] != null) {
          errorMsg = e.response?.data['message'];
        }
      }
      if (mounted) {
        TxaToast.show(context, errorMsg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [TxaTheme.primaryBg, Color(0xFF0F172A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header / Back Button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Logo & Title
                const SizedBox(height: 20),
                Image.asset('assets/logo.png', height: 80),
                const SizedBox(height: 16),
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'T',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: 'Phim',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: TxaTheme.accent,
                        ),
                      ),
                      TextSpan(
                        text: 'X',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  TxaLanguage.t('app_slogan'),
                  style: const TextStyle(
                    color: TxaTheme.textMuted,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),

                const SizedBox(height: 40),

                // Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: TxaTheme.accent,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: TxaTheme.textMuted,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    tabs: [
                      Tab(text: TxaLanguage.t('login')),
                      Tab(text: TxaLanguage.t('register')),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildLoginForm(), _buildRegisterForm()],
                  ),
                ),
              ],
            ),
          ),

          if (_loading)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(color: TxaTheme.accent),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          _buildTextField(
            controller: _loginEmailController,
            hint: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            errorText: _loginEmailError,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _loginPasswordController,
            hint: TxaLanguage.t('password'),
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            showPassword: _showLoginPassword,
            onTogglePassword: () =>
                setState(() => _showLoginPassword = !_showLoginPassword),
            errorText: _loginPasswordError,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  TxaToast.show(context, TxaLanguage.t('feature_dev')),
              child: Text(
                TxaLanguage.t('forgot_password'),
                style: const TextStyle(color: TxaTheme.textMuted, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildAuthButton(
            text: TxaLanguage.t('login'),
            onPressed: _handleLogin,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          _buildTextField(
            controller: _regNameController,
            hint: TxaLanguage.t('full_name'),
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _regEmailController,
            hint: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _regPasswordController,
            hint: TxaLanguage.t('password'),
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            showPassword: _showRegPassword,
            onTogglePassword: () =>
                setState(() => _showRegPassword = !_showRegPassword),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _regConfirmPasswordController,
            hint: TxaLanguage.t('confirm_password'),
            icon: Icons.lock_reset_rounded,
            isPassword: true,
            showPassword: _showRegPassword,
          ),
          const SizedBox(height: 40),
          _buildAuthButton(
            text: TxaLanguage.t('create_account'),
            onPressed: _handleRegister,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool? showPassword,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: errorText != null
                  ? Colors.redAccent.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
              width: errorText != null ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && (showPassword == false),
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: TxaTheme.textMuted,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                icon,
                color: errorText != null ? Colors.redAccent : TxaTheme.accent,
                size: 20,
              ),
              suffixIcon: isPassword && onTogglePassword != null
                  ? IconButton(
                      onPressed: onTogglePassword,
                      icon: Icon(
                        showPassword!
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: TxaTheme.textMuted,
                        size: 20,
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              errorText,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAuthButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: TxaTheme.brandGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: TxaTheme.accent.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
