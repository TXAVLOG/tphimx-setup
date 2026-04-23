import 'package:flutter/material.dart';
import '../services/txa_settings.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_toast.dart';
import '../utils/txa_format.dart';

class GlobalSettingsScreen extends StatefulWidget {
  const GlobalSettingsScreen({super.key});

  @override
  State<GlobalSettingsScreen> createState() => _GlobalSettingsScreenState();
}

class _GlobalSettingsScreenState extends State<GlobalSettingsScreen> {
  String _cacheSize = "...";

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    final bytes = await TxaSettings.getCacheSize();
    if (mounted) {
      setState(() => _cacheSize = TxaFormat.formatSize(bytes)['display']);
    }
  }

  Future<void> _clearCache() async {
    await TxaSettings.clearCache();
    await _loadCacheSize();
    if (mounted) {
      TxaToast.show(context, TxaLanguage.t('cache_cleared'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          TxaLanguage.t('settings'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle(TxaLanguage.t('appearance')),
          _buildFontScaleTile(),
          const SizedBox(height: 8),
          _buildFontFamilyTile(),
          const Divider(color: Colors.white10, height: 32),
          _buildSectionTitle(TxaLanguage.t('system')),
          ListTile(
            onTap: _clearCache,
            leading: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white70,
            ),
            title: Text(
              TxaLanguage.t('clear_cache'),
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              _cacheSize,
              style: const TextStyle(color: TxaTheme.textMuted),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: TxaTheme.textMuted,
            ),
          ),
          const Divider(color: Colors.white10, height: 32),
          _buildSectionTitle(TxaLanguage.t('network_speed')),
          SwitchListTile(
            value: TxaSettings.autoQualityByNetwork,
            onChanged: (v) => setState(() => TxaSettings.autoQualityByNetwork = v),
            title: Text(TxaLanguage.t('auto_quality'), style: const TextStyle(color: Colors.white)),
            subtitle: Text(TxaLanguage.t('auto_quality_desc'), style: const TextStyle(color: TxaTheme.textMuted, fontSize: 12)),
            activeThumbColor: TxaTheme.accent,
          ),
          SwitchListTile(
            value: TxaSettings.showSpeedInNotification,
            onChanged: (v) => setState(() => TxaSettings.showSpeedInNotification = v),
            title: Text(TxaLanguage.t('show_speed_notif'), style: const TextStyle(color: Colors.white)),
            subtitle: Text(TxaLanguage.t('show_speed_notif_desc'), style: const TextStyle(color: TxaTheme.textMuted, fontSize: 12)),
            activeThumbColor: TxaTheme.accent,
          ),
          ListTile(
            title: Text(TxaLanguage.t('speed_unit'), style: const TextStyle(color: Colors.white)),
            subtitle: Text(TxaSettings.speedUnitGbps ? 'Gbps' : 'Mbps', style: const TextStyle(color: TxaTheme.textMuted)),
            trailing: const Icon(Icons.chevron_right_rounded, color: TxaTheme.textMuted),
            onTap: () {
              setState(() => TxaSettings.speedUnitGbps = !TxaSettings.speedUnitGbps);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: TxaTheme.accent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFontScaleTile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.format_size_rounded, color: Colors.white70),
          title: Text(
            TxaLanguage.t('font_size'),
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            '${(TxaSettings.fontSizeScale * 100).toInt()}%',
            style: const TextStyle(color: TxaTheme.textMuted),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            activeTrackColor: TxaTheme.accent,
            inactiveTrackColor: Colors.white12,
            thumbColor: TxaTheme.accent,
          ),
          child: Slider(
            value: TxaSettings.fontSizeScale,
            min: 0.8,
            max: 1.4,
            divisions: 6,
            onChanged: (v) {
              setState(() => TxaSettings.fontSizeScale = v);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFontFamilyTile() {
    final fonts = [
      {'name': 'Outfit', 'label': TxaLanguage.t('font_outfit')},
      {'name': 'Roboto', 'label': TxaLanguage.t('font_roboto')},
      {'name': 'Inter', 'label': TxaLanguage.t('font_inter')},
      {'name': 'Open Sans', 'label': TxaLanguage.t('font_open_sans')},
    ];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.font_download_rounded, color: Colors.white70),
      title: Text(
        TxaLanguage.t('font_family'),
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        fonts.firstWhere(
          (f) => f['name'] == TxaSettings.fontFamily,
          orElse: () => fonts[0],
        )['label']!,
        style: const TextStyle(color: TxaTheme.textMuted),
      ),
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: TxaTheme.secondaryBg,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        TxaLanguage.t('font_family'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...fonts.map((f) {
                      final isSelected = TxaSettings.fontFamily == f['name'];
                      return ListTile(
                        onTap: () {
                          setState(() => TxaSettings.fontFamily = f['name']!);
                          Navigator.pop(ctx);
                        },
                        title: Text(
                          f['label']!,
                          style: TextStyle(
                            color: isSelected ? TxaTheme.accent : Colors.white,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: TxaTheme.accent,
                              )
                            : null,
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
