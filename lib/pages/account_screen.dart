import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../theme/txa_theme.dart';
import '../services/txa_settings.dart';
import '../services/txa_language.dart';
import '../services/txa_api.dart';
import '../utils/txa_toast.dart';
import 'legal_screen.dart';
import 'auth_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'history_screen.dart';
import 'favorite_list_screen.dart';
import 'global_settings_screen.dart';
import 'movie_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  void _handleDev(BuildContext context, String label) {
    TxaToast.show(
      context,
      TxaLanguage.t('feature_under_dev').replaceAll('%label', label),
    );
  }

  void _showPlayerSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _PlayerSettingsBottomSheet(),
    );
  }

  Future<void> _launchUrl(BuildContext context, String urlStr) async {
    final Uri url = Uri.parse(urlStr);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(TxaLanguage.t('not_open_link'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      {
        'id': 'history',
        'label': TxaLanguage.t('watching'),
        'icon': Icons.history_rounded,
        'action': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (ctx) => const HistoryScreen()),
        ),
      },
      {
        'id': 'favorites',
        'label': TxaLanguage.t('add_favorite'),
        'icon': Icons.favorite_border_rounded,
        'action': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (ctx) => const FavoriteListScreen()),
        ),
      },
      {
        'id': 'global_settings',
        'label': TxaLanguage.t('settings'),
        'icon': Icons.settings_rounded,
        'action': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (ctx) => const GlobalSettingsScreen()),
        ),
      },
      {
        'id': 'tv_login',
        'label': TxaLanguage.t('tv_login'),
        'icon': Icons.tv_rounded,
        'action': () => _handleDev(context, TxaLanguage.t('tv_login')),
      },
      {
        'id': 'player_settings',
        'label': TxaLanguage.t('player_settings'),
        'icon': Icons.settings_suggest_rounded,
        'action': () => _showPlayerSettings(context),
      },
      // Social Links
      if (TxaApi.facebookFanpage.isNotEmpty)
        {
          'id': 'fb_fanpage',
          'label': TxaLanguage.t('fb_fanpage'),
          'icon': Icons.facebook_rounded,
          'action': () => _launchUrl(context, TxaApi.facebookFanpage),
        },
      if (TxaApi.telegramChannel.isNotEmpty)
        {
          'id': 'tg_channel',
          'label': TxaLanguage.t('tg_channel'),
          'icon': Icons.send_rounded,
          'action': () => _launchUrl(context, TxaApi.telegramChannel),
        },
      if (TxaApi.telegramGroup.isNotEmpty)
        {
          'id': 'tg_group',
          'label': TxaLanguage.t('tg_support'),
          'icon': Icons.groups_rounded,
          'action': () => _launchUrl(context, TxaApi.telegramGroup),
        },
      {
        'id': 'terms',
        'label': TxaLanguage.t('terms_of_service'),
        'icon': Icons.description_outlined,
        'action': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => LegalScreen(
              title: TxaLanguage.t('terms_of_service'),
              sections: [
                LegalSection(
                  title: TxaLanguage.currentLang == 'vi'
                      ? 'Quy định chung'
                      : 'General Rules',
                  content: TxaLanguage.currentLang == 'vi'
                      ? 'Chào mừng bạn đến với TPhimX. Khi truy cập và sử dụng dịch vụ, bạn đồng ý tuân thủ các quy định dưới đây.'
                      : 'Welcome to TPhimX. By accessing and using the service, you agree to comply with the regulations below.',
                  icon: Icons.gavel_rounded,
                ),
              ],
            ),
          ),
        ),
      },
      {
        'id': 'privacy',
        'label': TxaLanguage.t('privacy_policy'),
        'icon': Icons.security_rounded,
        'action': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => LegalScreen(
              title: TxaLanguage.t('privacy_policy'),
              sections: [
                LegalSection(
                  title: TxaLanguage.currentLang == 'vi'
                      ? 'Thu thập thông tin'
                      : 'Data Collection',
                  content: TxaLanguage.currentLang == 'vi'
                      ? 'Chúng tôi chỉ thu thập dữ liệu cần thiết để mang lại trải nghiệm tốt nhất cho bạn.'
                      : 'We only collect data necessary to bring the best experience to you.',
                  icon: Icons.storage_rounded,
                ),
              ],
            ),
          ),
        ),
      },
    ];

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset('assets/logo.png', height: 32),
                    const SizedBox(width: 8),
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'T',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: TxaTheme.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text: 'Phim',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: TxaTheme.accent,
                            ),
                          ),
                          TextSpan(
                            text: 'X',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: TxaTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (Platform.isIOS) const SizedBox(width: 8),
                    // Status badge: Đã đăng ký / Chưa đăng ký (iOS Only)
                    if (Platform.isIOS)
                      Builder(
                        builder: (_) {
                          final isRegistered = TxaSettings.udid.isNotEmpty;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isRegistered
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isRegistered
                                    ? Colors.green.withValues(alpha: 0.5)
                                    : Colors.orange.withValues(alpha: 0.5),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isRegistered
                                      ? Icons.verified_rounded
                                      : Icons.info_outline_rounded,
                                  color: isRegistered
                                      ? Colors.green
                                      : Colors.orange,
                                  size: 10,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  isRegistered
                                      ? TxaLanguage.t('status_registered')
                                      : TxaLanguage.t('status_not_registered'),
                                  style: TextStyle(
                                    color: isRegistered
                                        ? Colors.green
                                        : Colors.orange,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
                Text(
                  TxaLanguage.t('account_title'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TxaTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Auth Section
          Builder(
            builder: (context) {
              final token = TxaSettings.authToken;
              if (token.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => const AuthScreen(),
                                ),
                              ).then((val) {
                                if (val == true) setState(() {});
                              }),
                          icon: const Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                          ),
                          label: Text(
                            TxaLanguage.t('login'),
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TxaTheme.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => const AuthScreen(),
                                ),
                              ).then((val) {
                                if (val == true) setState(() {});
                              }),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TxaTheme.cardBg,
                            foregroundColor: TxaTheme.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(
                                color: TxaTheme.glassBorder,
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            TxaLanguage.t('register'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Logged in state
              Map<String, dynamic>? initialUser;
              try {
                if (TxaSettings.userData.isNotEmpty) {
                  initialUser = {'data': jsonDecode(TxaSettings.userData)};
                }
              } catch (_) {}

              return FutureBuilder<Map<String, dynamic>>(
                future: Provider.of<TxaApi>(context, listen: false).getAuthMe(),
                builder: (context, snapshot) {
                  Map<String, dynamic>? userData;

                  if (snapshot.hasData) {
                    userData = snapshot.data?['data'];
                    // Update cache silently
                    if (userData != null) {
                      TxaSettings.userData = jsonEncode(userData);
                    }
                  } else if (initialUser != null) {
                    // Fallback to cache while loading or on error
                    userData = initialUser['data'];
                  }

                  if (snapshot.hasError) {
                    final err = snapshot.error.toString();
                    if (err.contains('401') || err.contains('Unauthorized')) {
                      // Token expired/invalid, logout silently
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        TxaSettings.authToken = '';
                        TxaSettings.userData = '';
                        Provider.of<TxaApi>(
                          context,
                          listen: false,
                        ).setToken('');
                        if (mounted) setState(() {});
                      });
                    }
                    return _buildErrorCard(snapshot.error?.toString());
                  }

                  final name = userData?['name'] ?? 'TPhimX User';
                  final email = userData?['email'] ?? '...';
                  final isVerified = userData?['email_verified_at'] != null;
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: TxaTheme.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: TxaTheme.glassBorder),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: TxaTheme.accent,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: const TextStyle(
                                  color: TxaTheme.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (isVerified)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.green.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.verified_rounded,
                                        color: Colors.greenAccent,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        TxaLanguage.t('email_verified'),
                                        style: const TextStyle(
                                          color: Colors.greenAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Text(
                                  TxaLanguage.t('email_not_verified'),
                                  style: TextStyle(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            TxaSettings.authToken = '';
                            TxaSettings.userData = '';
                            Provider.of<TxaApi>(
                              context,
                              listen: false,
                            ).setToken('');
                            setState(() {});
                            TxaToast.show(
                              context,
                              TxaLanguage.t('logout_success'),
                            );
                          },
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 16),

          // Watching List (History Preview)
          if (TxaSettings.authToken.isNotEmpty) _buildWatchingSection(),

          const SizedBox(height: 16),

          // Menu Items - Compact Grid Layout
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    onTap: item['action'] as VoidCallback,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: TxaTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TxaTheme.glassBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: TxaTheme.glassBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              item['icon'] as IconData,
                              color: TxaTheme.textPrimary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item['label'] as String,
                              style: const TextStyle(
                                color: TxaTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: TxaTheme.textMuted,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Version info - Compact
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? '3.2.1';
                  final buildNumber = snapshot.data?.buildNumber ?? '321';
                  return Text(
                    TxaLanguage.t(
                      'current_version',
                    ).replaceAll('%version', '$version (Build $buildNumber)'),
                    style: const TextStyle(
                      color: TxaTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(dynamic message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message?.toString() ?? 'Unknown Error',
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: () => setState(() {}),
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.redAccent,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                TxaLanguage.t('watching'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => const HistoryScreen()),
                ),
                child: Text(
                  TxaLanguage.t('view_all'),
                  style: const TextStyle(color: TxaTheme.accent, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: FutureBuilder<Map<String, dynamic>>(
            future: Provider.of<TxaApi>(
              context,
              listen: false,
            ).getWatchHistory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              final List<dynamic> items = snapshot.data?['data'] is List
                  ? snapshot.data!['data']
                  : [];
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    TxaLanguage.t('no_history'),
                    style: const TextStyle(
                      color: TxaTheme.textMuted,
                      fontSize: 13,
                    ),
                  ),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.take(5).length,
                itemBuilder: (ctx, index) {
                  final item = items[index];
                  final movie = item['movie'] ?? {};
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => MovieDetailScreen(
                          slug: movie['slug'],
                          autoPlay: true,
                        ),
                      ),
                    ).then((_) => setState(() {})),
                    child: Container(
                      width: 160,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(
                            movie['thumb_url'] ?? '',
                          ),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.3),
                            BlendMode.darken,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            movie['name'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlayerSettingsBottomSheet extends StatefulWidget {
  const _PlayerSettingsBottomSheet();

  @override
  State<_PlayerSettingsBottomSheet> createState() =>
      _PlayerSettingsBottomSheetState();
}

class _PlayerSettingsBottomSheetState
    extends State<_PlayerSettingsBottomSheet> {
  bool _hasOverlayPermission = true;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final status = await Permission.systemAlertWindow.status;
    setState(() {
      _hasOverlayPermission = status.isGranted;
      // If missing, auto disable
      if (!_hasOverlayPermission && TxaSettings.autoPiP) {
        TxaSettings.autoPiP = false;
      }
    });
  }

  Future<void> _requestOverlayPermission() async {
    final status = await Permission.systemAlertWindow.request();
    if (status.isGranted) {
      setState(() => _hasOverlayPermission = true);
    } else {
      openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TxaTheme.primaryBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(
                Icons.settings_suggest_rounded,
                color: TxaTheme.accent,
              ),
              const SizedBox(width: 12),
              Text(
                TxaLanguage.t('player_settings'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 1. Sliders for Volume & Brightness
          _SliderSetting(
            label: TxaLanguage.t('player_brightness'),
            icon: Icons.brightness_medium_rounded,
            value: TxaSettings.brightness,
            onChanged: (v) => setState(() => TxaSettings.brightness = v),
          ),
          _SliderSetting(
            label: TxaLanguage.t('player_audio'),
            icon: Icons.volume_up_rounded,
            value: TxaSettings.volume,
            onChanged: (v) => setState(() => TxaSettings.volume = v),
          ),

          const Divider(color: Colors.white10, height: 32),

          // 2. Toggles
          _SettingToggle(
            label: TxaLanguage.t('skip_intro'),
            value: TxaSettings.autoSkipIntro,
            onChanged: (v) => setState(() => TxaSettings.autoSkipIntro = v),
          ),
          _SettingToggle(
            label: TxaLanguage.t('auto_next_ep'),
            value: TxaSettings.autoNextEpisode,
            onChanged: (v) => setState(() => TxaSettings.autoNextEpisode = v),
          ),

          const Divider(color: Colors.white10, height: 32),

          // 3. Auto PiP with Permission Check (Android Only)
          if (Platform.isAndroid)
            _hasOverlayPermission
                ? _SettingToggle(
                    label: TxaLanguage.t('auto_pip_label'),
                    value: TxaSettings.autoPiP,
                    onChanged: (v) => setState(() => TxaSettings.autoPiP = v),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            TxaLanguage.t('pip_permission_missing'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _requestOverlayPermission,
                          child: Text(
                            TxaLanguage.t('grant'),
                            style: const TextStyle(
                              color: TxaTheme.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

          if (Platform.isAndroid) const SizedBox(height: 8),
          if (Platform.isAndroid)
            Text(
              TxaLanguage.t('auto_pip_desc'),
              style: const TextStyle(color: TxaTheme.textMuted, fontSize: 11),
            ),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: TxaTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              TxaLanguage.t('save_changes'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  const _SliderSetting({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: TxaTheme.textSecondary, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '${(value * 100).toInt()}%',
                style: const TextStyle(
                  color: TxaTheme.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              activeTrackColor: TxaTheme.accent,
              inactiveTrackColor: Colors.white12,
              thumbColor: TxaTheme.accent,
              overlayColor: TxaTheme.accent.withValues(alpha: 0.1),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

class _SettingToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 15),
      ),
      value: value,
      activeThumbColor: TxaTheme.accent,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}
