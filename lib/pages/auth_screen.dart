import 'package:flutter/material.dart';
import 'dart:convert';
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

  final _loginIdController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _registerNameController = TextEditingController();
  final _registerUsernameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _showLoginPassword = false;
  bool _showRegPassword = false;
  String _registerGender = 'male';

  String? _loginIdError;
  String? _loginPasswordError;
  String? _registerNameError;
  String? _registerUsernameError;
  String? _registerEmailError;
  String? _registerPasswordError;
  String? _registerConfirmPasswordError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginIdController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerUsernameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final id = _loginIdController.text.trim();
    final password = _loginPasswordController.text;

    if (id.isEmpty || password.isEmpty) {
      TxaToast.show(
        context,
        TxaLanguage.t('error_empty_fields'),
        isError: true,
      );
      return;
    }

    setState(() {
      _loading = true;
      _loginIdError = null;
      _loginPasswordError = null;
    });
    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      final res = await api.login(id, password);

      if (res.data['success'] == true) {
        final token = res.data['data']['token'];
        final userData = res.data['data']['user'];

        TxaSettings.authToken = token;
        if (userData != null) {
          TxaSettings.userData = jsonEncode(userData);
        }
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
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data['data'] != null) {
        final errorCode = e.response?.data['data']['error_code'];
        setState(() {
          if (errorCode == 'USER_NOT_FOUND') {
            _loginIdError = e.response?.data['message'];
          } else if (errorCode == 'INVALID_PASSWORD') {
            _loginPasswordError = e.response?.data['message'];
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  e.response?.data['message'] ?? TxaLanguage.t('error_login'),
                ),
              ),
            );
          }
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(TxaLanguage.t('error_connection'))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRegister() async {
    final name = _registerNameController.text.trim();
    final username = _registerUsernameController.text.trim();
    final email = _registerEmailController.text.trim();
    final password = _registerPasswordController.text;
    final confirm = _registerConfirmPasswordController.text;

    if (name.isEmpty || username.isEmpty || email.isEmpty || password.isEmpty) {
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

    setState(() {
      _loading = true;
      _registerNameError = null;
      _registerUsernameError = null;
      _registerEmailError = null;
      _registerPasswordError = null;
      _registerConfirmPasswordError = null;
    });

    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      final res = await api.register(
        name: name,
        username: username,
        email: email,
        password: password,
        confirmPw: confirm,
        gender: _registerGender,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          TxaToast.show(context, TxaLanguage.t('register_success'));
          _tabController.animateTo(0);
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'];
        setState(() {
          if (errors != null) {
            if (errors['name'] != null) {
              _registerNameError = errors['name'][0];
            }
            if (errors['username'] != null) {
              _registerUsernameError = errors['username'][0];
            }
            if (errors['email'] != null) {
              _registerEmailError = errors['email'][0];
            }
            if (errors['password'] != null) {
              _registerPasswordError = errors['password'][0];
            }
          } else {
            TxaToast.show(
              context,
              e.response?.data['message'] ?? TxaLanguage.t('error_register'),
              isError: true,
            );
          }
        });
      } else {
        String errorMsg = TxaLanguage.t('error_register');
        if (e.response?.data != null && e.response?.data['message'] != null) {
          errorMsg = e.response?.data['message'];
        }
        if (mounted) TxaToast.show(context, errorMsg, isError: true);
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
            controller: _loginIdController,
            label: TxaLanguage.t('login_id'),
            hint: TxaLanguage.t('login_id_hint'),
            icon: Icons.person_outline_rounded,
            errorText: _loginIdError,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _loginPasswordController,
            label: TxaLanguage.t('password'),
            hint: TxaLanguage.t('password_hint'),
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
            controller: _registerNameController,
            label: TxaLanguage.t('full_name'),
            hint: TxaLanguage.t('full_name'),
            icon: Icons.person_outline_rounded,
            errorText: _registerNameError,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _registerUsernameController,
            label: TxaLanguage.t('username'),
            hint: TxaLanguage.t('username'),
            icon: Icons.account_box_outlined,
            errorText: _registerUsernameError,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _registerEmailController,
            label: TxaLanguage.t('email'),
            hint: TxaLanguage.t('email'),
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            errorText: _registerEmailError,
          ),
          const SizedBox(height: 16),
          // Gender Selection
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                TxaLanguage.t('gender'),
                style: const TextStyle(color: TxaTheme.textMuted, fontSize: 13),
              ),
            ),
          ),
          Row(
            children: [
              _buildGenderChip('male', TxaLanguage.t('gender_male')),
              const SizedBox(width: 8),
              _buildGenderChip('female', TxaLanguage.t('gender_female')),
              const SizedBox(width: 8),
              _buildGenderChip('other', TxaLanguage.t('gender_other')),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _registerPasswordController,
            label: TxaLanguage.t('password'),
            hint: TxaLanguage.t('password_hint'),
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            showPassword: _showRegPassword,
            onTogglePassword: () =>
                setState(() => _showRegPassword = !_showRegPassword),
            errorText: _registerPasswordError,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _registerConfirmPasswordController,
            label: TxaLanguage.t('confirm_password'),
            hint: TxaLanguage.t('confirm_password'),
            icon: Icons.lock_reset_rounded,
            isPassword: true,
            showPassword: _showRegPassword,
            errorText: _registerConfirmPasswordError,
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
    String? label,
    bool isPassword = false,
    bool? showPassword,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: const TextStyle(
                color: TxaTheme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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

  Widget _buildGenderChip(String value, String label) {
    bool isSelected = _registerGender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _registerGender = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? TxaTheme.accent.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? TxaTheme.accent.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : TxaTheme.textMuted,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
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
