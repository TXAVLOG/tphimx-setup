import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
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
import '../utils/txa_format.dart';
import 'download_manager_screen.dart';
import 'update_history_screen.dart';
import '../widgets/txa_modal.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  void initState() {
    super.initState();
    TxaSettings().addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    TxaSettings().removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

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
      TxaToast.show(context, TxaLanguage.t('not_open_link'), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = [
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
        'id': 'downloads',
        'label': TxaLanguage.t('download_manager'),
        'icon': Icons.download_for_offline_rounded,
        'action': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (ctx) => const DownloadManagerScreen()),
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
      {
        'id': 'update_history',
        'label': TxaLanguage.t('update_history'),
        'icon': Icons.history_rounded,
        'action': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (ctx) => const UpdateHistoryScreen()),
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

          // Profile content is now inside the ListView via _PremiumProfileCard

          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Profile Card (Premium Glass)
                const _PremiumProfileCard(),
                const SizedBox(height: 24),

                // Watching List (History Preview)
                if (TxaSettings.authToken.isNotEmpty) _buildWatchingSection(),
                if (TxaSettings.authToken.isNotEmpty) const SizedBox(height: 24),
                
                // Settings Groups
                _buildMenuSection(TxaLanguage.t('general_settings'), ['favorites', 'downloads', 'history'], menuItems),
                const SizedBox(height: 24),
                _buildMenuSection(TxaLanguage.t('app_settings'), ['global_settings', 'player_settings', 'tv_login'], menuItems),
                const SizedBox(height: 24),
                _buildMenuSection(TxaLanguage.t('community_support'), ['fb_fanpage', 'tg_channel', 'tg_group'], menuItems),
                const SizedBox(height: 24),
                _buildMenuSection(TxaLanguage.t('legal'), ['terms', 'privacy', 'update_history'], menuItems),

                const SizedBox(height: 32),
                
                // Logout / Cache Actions
                if (TxaSettings.authToken.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton.icon(
                      onPressed: () => _showLogoutConfirm(context),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text(TxaLanguage.t('logout')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                
                ElevatedButton.icon(
                  onPressed: () => _showClearCacheConfirm(context),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  label: Text(TxaLanguage.t('clear_cache')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    foregroundColor: TxaTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    elevation: 0,
                  ),
                ),
                
                const SizedBox(height: 100),
              ],
            ),
          ),

          // Version info - Compact
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? '4.2.8';
                  final buildNumber = snapshot.data?.buildNumber ?? '428';
                  return InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => const UpdateHistoryScreen(),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        TxaLanguage.t(
                          'current_version',
                          replace: {'version': '$version (Build $buildNumber)'},
                        ),
                        style: const TextStyle(
                          color: TxaTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
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

  void _showLogoutConfirm(BuildContext context) {
    TxaModal.show(
      context,
      title: TxaLanguage.t('logout'),
      content: Text(
        TxaLanguage.t('logout_confirm'),
        style: const TextStyle(color: TxaTheme.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(TxaLanguage.t('cancel'), style: const TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            TxaSettings.authToken = '';
            TxaSettings.userData = '';
            Provider.of<TxaApi>(context, listen: false).setToken('');
            setState(() {});
            TxaToast.show(context, TxaLanguage.t('logout_success'));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            TxaLanguage.t('logout'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  void _showClearCacheConfirm(BuildContext context) {
    TxaModal.show(
      context,
      title: TxaLanguage.t('clear_cache'),
      content: Text(
        TxaLanguage.t('clear_cache_msg'),
        style: const TextStyle(color: TxaTheme.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(TxaLanguage.t('cancel'), style: const TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            TxaToast.show(context, TxaLanguage.t('cache_cleared'));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: TxaTheme.accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            TxaLanguage.t('clear'),
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(String title, List<String> itemIds, List<Map<String, dynamic>> allItems) {
    final items = allItems.where((i) => itemIds.contains(i['id'])).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: TxaTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: TxaTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TxaTheme.glassBorder),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: items.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.white.withValues(alpha: 0.05),
              height: 1,
              indent: 48,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                onTap: item['action'] as VoidCallback,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TxaTheme.glassBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item['icon'] as IconData, color: TxaTheme.textPrimary, size: 18),
                ),
                title: Text(
                  item['label'] as String,
                  style: const TextStyle(color: TxaTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: TxaTheme.textMuted, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              );
            },
          ),
        ),
      ],
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
              // Sort: most recent watched first
              items.sort((a, b) {
                final aTime = a['updated_at']?.toString() ?? '';
                final bTime = b['updated_at']?.toString() ?? '';
                return bTime.compareTo(aTime);
              });
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
                          if (item['current_time'] != null &&
                              item['duration'] != null &&
                              (item['duration'] as num) > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${TxaFormat.formatTime((item['current_time'] as num).toInt())} / ${TxaFormat.formatTime((item['duration'] as num).toInt())}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
      if (mounted) {
        setState(() {
          _hasOverlayPermission = true;
          TxaSettings.autoPiP = true;
        });
      }
    } else {
      if (mounted) {
        TxaModal.show(
          context,
          title: TxaLanguage.t('permission_overlay_label'),
          content: Text(
            TxaLanguage.t('permission_overlay_desc'),
            style: const TextStyle(color: TxaTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(TxaLanguage.t('close'), style: const TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TxaTheme.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                TxaLanguage.t('go_to_settings'),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      }
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

          // 3. Auto PiP (Android Only) - Powered by floating package
          if (Platform.isAndroid)
            _SettingToggle(
              label: TxaLanguage.t('auto_pip_label'),
              value: TxaSettings.autoPiP,
              onChanged: (v) {
                if (v && !_hasOverlayPermission) {
                  _requestOverlayPermission();
                } else {
                  setState(() => TxaSettings.autoPiP = v);
                }
              },
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

class _PremiumProfileCard extends StatelessWidget {
  const _PremiumProfileCard();

  @override
  Widget build(BuildContext context) {
    final token = TxaSettings.authToken;
    if (token.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: TxaTheme.brandGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: TxaTheme.accent.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.stars_rounded, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            Text(
              TxaLanguage.t('app_slogan'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const AuthScreen()),
                      );
                      if (result == true) {
                        // AccountScreen listener will handle the rebuild
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(TxaLanguage.t('login'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const AuthScreen(isRegister: true)),
                      );
                      if (result == true) {
                        // AccountScreen listener will handle the rebuild
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(TxaLanguage.t('register')),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: Provider.of<TxaApi>(context, listen: false).getAuthMe(),
      builder: (context, snapshot) {
        // Priority: API result > Cache
        Map<String, dynamic>? user = snapshot.data?['data'];
        if (user == null && TxaSettings.userData.isNotEmpty) {
          try {
            user = jsonDecode(TxaSettings.userData);
          } catch (_) {}
        }

        if (user == null) {
          if (snapshot.hasError) {
            return _buildErrorCard(context, snapshot.error?.toString(), () {
              final state = context.findAncestorStateOfType<_AccountScreenState>();
              (state as dynamic)?.setState(() {});
            });
          }
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final name = user['name'] ?? 'TPhimX User';
        final email = user['email'] ?? '...';
        final isVerified = user['email_verified_at'] != null;
        final avatar = user['avatar'];

        // Check for session expiration quietly
        bool isExpired = false;
        if (snapshot.hasError) {
          final err = snapshot.error;
          if (err is DioException && err.response?.statusCode == 401) {
            isExpired = true;
          } else if (err.toString().contains('401')) {
            isExpired = true;
          }
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: TxaTheme.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: TxaTheme.glassBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: TxaTheme.accent, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: TxaTheme.accent.withValues(alpha: 0.2),
                      backgroundImage: (avatar != null && avatar.toString().isNotEmpty)
                          ? CachedNetworkImageProvider(avatar)
                          : null,
                      child: (avatar == null || avatar.toString().isEmpty)
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: Colors.white, size: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isExpired)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              '!',
                              style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(color: TxaTheme.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    if (isVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              TxaLanguage.t('email_verified'),
                              style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _buildErrorCard(BuildContext context, dynamic message, VoidCallback onRetry) {
  final is401 =
      message.toString().contains('401') ||
      message.toString().toLowerCase().contains('unauthenticated');

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
        Icon(
          is401 ? Icons.vpn_key_rounded : Icons.error_outline_rounded,
          color: Colors.redAccent,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                is401 ? 'Phiên đăng nhập hết hạn' : 'Lỗi tải thông tin',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                is401
                    ? 'Vui lòng đăng nhập lại để tiếp tục'
                    : (message?.toString() ?? 'Unknown Error'),
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
              ),
            ],
          ),
        ),
        if (is401)
          TextButton(
            onPressed: () {
              TxaSettings.authToken = '';
              TxaSettings.userData = '';
              Provider.of<TxaApi>(context, listen: false).setToken('');
              onRetry();
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Đăng nhập',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          IconButton(
            onPressed: onRetry,
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


