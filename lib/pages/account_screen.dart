import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/txa_theme.dart';
import '../services/txa_settings.dart';
import '../services/txa_language.dart';
import '../services/txa_api.dart';
import '../utils/txa_toast.dart';
import 'legal_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(TxaLanguage.t('not_open_link'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      {
        'id': 'history',
        'label': TxaLanguage.t('watching'),
        'icon': Icons.history_rounded,
        'action': () => _handleDev(context, TxaLanguage.t('watching')),
      },
      {
        'id': 'mylist',
        'label': TxaLanguage.t('my_list_long'),
        'icon': Icons.list_alt_rounded,
        'action': () => _handleDev(context, TxaLanguage.t('my_list_long')),
      },
      {
        'id': 'favorites',
        'label': TxaLanguage.t('add_favorite'),
        'icon': Icons.favorite_border_rounded,
        'action': () => _handleDev(context, TxaLanguage.t('add_favorite')),
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
                  title: TxaLanguage.currentLang == 'vi' ? 'Quy định chung' : 'General Rules',
                  content: TxaLanguage.currentLang == 'vi' ? 'Chào mừng bạn đến với TPhimX. Khi truy cập và sử dụng dịch vụ, bạn đồng ý tuân thủ các quy định dưới đây.' : 'Welcome to TPhimX. By accessing and using the service, you agree to comply with the regulations below.',
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
                  title: TxaLanguage.currentLang == 'vi' ? 'Thu thập thông tin' : 'Data Collection',
                  content: TxaLanguage.currentLang == 'vi' ? 'Chúng tôi chỉ thu thập dữ liệu cần thiết để mang lại trải nghiệm tốt nhất cho bạn.' : 'We only collect data necessary to bring the best experience to you.',
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset('assets/logo.png', height: 36),
                    const SizedBox(width: 10),
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'T',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: TxaTheme.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text: 'Phim',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: TxaTheme.accent,
                            ),
                          ),
                          TextSpan(
                            text: 'X',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: TxaTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  TxaLanguage.t('account_title'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: TxaTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Auth Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleDev(context, TxaLanguage.t('login')),
                    icon: const Icon(Icons.person_outline_rounded, size: 20),
                    label: Text(TxaLanguage.t('login')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TxaTheme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleDev(context, 'Đăng ký'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TxaTheme.cardBg,
                      foregroundColor: TxaTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: TxaTheme.glassBorder),
                      ),
                      elevation: 0,
                    ),
                    child: Text(TxaLanguage.t('register')),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Menu Items
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: item['action'] as VoidCallback,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: TxaTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: TxaTheme.glassBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: TxaTheme.glassBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              item['icon'] as IconData,
                              color: TxaTheme.textPrimary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              item['label'] as String,
                              style: const TextStyle(
                                color: TxaTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: TxaTheme.textMuted,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Version info
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? '2.4.7';
                  final buildNumber = snapshot.data?.buildNumber ?? '247';
                  return Text(
                    TxaLanguage.t('current_version').replaceAll('%version', '$version (Build $buildNumber)'),
                    style: const TextStyle(
                      color: TxaTheme.textMuted,
                      fontSize: 12,
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
}

class _PlayerSettingsBottomSheet extends StatefulWidget {
  const _PlayerSettingsBottomSheet();

  @override
  State<_PlayerSettingsBottomSheet> createState() =>
      _PlayerSettingsBottomSheetState();
}

class _PlayerSettingsBottomSheetState
    extends State<_PlayerSettingsBottomSheet> {
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
              const Icon(Icons.settings_suggest_rounded, color: TxaTheme.accent),
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
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const Spacer(),
              Text('${(value * 100).toInt()}%', style: const TextStyle(color: TxaTheme.accent, fontWeight: FontWeight.bold, fontSize: 13)),
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
            child: Slider(
              value: value,
              onChanged: onChanged,
            ),
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
