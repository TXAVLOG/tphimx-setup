import 'package:flutter/material.dart';
import '../services/txa_settings.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_toast.dart';
import '../utils/txa_format.dart';
import '../services/txa_speed_service.dart';
import 'package:permission_handler/permission_handler.dart';

import '../widgets/txa_modal.dart';

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
    final bool? confirm = await TxaModal.show<bool>(
      context,
      title: TxaLanguage.t('clear_cache'),
      content: Text(
        TxaLanguage.t('clear_cache_msg'),
        style: const TextStyle(color: TxaTheme.textMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            TxaLanguage.t('cancel'),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            TxaLanguage.t('clear'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );

    if (confirm == true) {
      final bytesBefore = await TxaSettings.getCacheSize();
      await TxaSettings.clearCache();
      await _loadCacheSize();
      if (mounted) {
        final formatted = TxaFormat.formatFileSize(bytesBefore);
        TxaToast.show(
          context,
          "${TxaLanguage.t('cache_cleared')} ($formatted)",
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildSectionTitle(TxaLanguage.t('appearance')),
          _buildFontScaleTile(),
          const SizedBox(height: 8),
          _buildFontFamilyTile(),
          const Divider(color: Colors.white10, height: 32),
          _buildSectionTitle(TxaLanguage.t('cache_management')),
          ListTile(
            onTap: _clearCache,
            leading: const Icon(
              Icons.cleaning_services_rounded,
              color: Colors.white70,
            ),
            title: Text(
              TxaLanguage.t('clear_cache'),
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              TxaLanguage.t('cache_size', replace: {'size': _cacheSize}),
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
            onChanged: (v) =>
                setState(() => TxaSettings.autoQualityByNetwork = v),
            title: Text(
              TxaLanguage.t('auto_quality'),
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              TxaLanguage.t('auto_quality_desc'),
              style: const TextStyle(color: TxaTheme.textMuted, fontSize: 12),
            ),
            activeThumbColor: TxaTheme.accent,
          ),
          SwitchListTile(
            value: TxaSettings.showSpeedInNotification,
            onChanged: (v) {
              TxaSettings.showSpeedInNotification = v;
              TxaSpeedService.toggleSpeedNotification(v);
              setState(() {});
            },
            title: Text(
              TxaLanguage.t('show_speed_notif'),
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              TxaLanguage.t('show_speed_notif_desc'),
              style: const TextStyle(color: TxaTheme.textMuted, fontSize: 12),
            ),
            activeThumbColor: TxaTheme.accent,
          ),
          ListTile(
            title: Text(
              TxaLanguage.t('speed_unit'),
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              TxaSettings.speedUnit,
              style: const TextStyle(color: TxaTheme.textMuted),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: TxaTheme.textMuted,
            ),
            onTap: () {
              final units = [
                'Auto',
                'KB/s',
                'MB/s',
                'GB/s',
                'B/s',
                'Mb/s',
                'Gb/s',
              ];
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
                              TxaLanguage.t('speed_unit'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Flexible(
                            child: ListView(
                              shrinkWrap: true,
                              children: units.map((u) {
                                final isSelected = TxaSettings.speedUnit == u;
                                return ListTile(
                                  onTap: () {
                                    setState(() => TxaSettings.speedUnit = u);
                                    if (TxaSettings.showSpeedInNotification) {
                                      TxaSpeedService.startService(); // Restart with new unit
                                    }
                                    Navigator.pop(ctx);
                                  },
                                  title: Text(
                                    u,
                                    style: TextStyle(
                                      color: isSelected
                                          ? TxaTheme.accent
                                          : Colors.white,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: TxaTheme.accent,
                                        )
                                      : null,
                                );
                              }).toList(),
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
          const Divider(color: Colors.white10, height: 32),
          _buildSectionTitle(TxaLanguage.t('permissions')),
          ListTile(
            leading: const Icon(Icons.security_rounded, color: Colors.white70),
            title: Text(
              TxaLanguage.t('manage_permissions'),
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              TxaLanguage.t('manage_permissions_desc'),
              style: const TextStyle(color: TxaTheme.textMuted, fontSize: 12),
            ),
            trailing: const Icon(
              Icons.open_in_new_rounded,
              color: TxaTheme.textMuted,
              size: 20,
            ),
            onTap: () => openAppSettings(),
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
      {'name': 'Montserrat', 'label': TxaLanguage.t('font_montserrat')},
      {'name': 'Oswald', 'label': TxaLanguage.t('font_oswald')},
      {'name': 'Playfair Display', 'label': TxaLanguage.t('font_playfair')},
      {'name': 'Poppins', 'label': TxaLanguage.t('font_poppins')},
      {'name': 'Lato', 'label': TxaLanguage.t('font_lato')},
      {'name': 'Nunito', 'label': TxaLanguage.t('font_nunito')},
      {'name': 'Merriweather', 'label': TxaLanguage.t('font_merriweather')},
      {'name': 'Manrope', 'label': TxaLanguage.t('font_manrope')},
      {'name': 'Rubik', 'label': TxaLanguage.t('font_rubik')},
      {'name': 'Fira Sans', 'label': TxaLanguage.t('font_fira_sans')},
      {'name': 'Source Sans 3', 'label': TxaLanguage.t('font_source_sans_3')},
      {
        'name': 'Plus Jakarta Sans',
        'label': TxaLanguage.t('font_plus_jakarta_sans'),
      },
      {'name': 'Bebas Neue', 'label': TxaLanguage.t('font_bebas_neue')},
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
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: fonts.map((f) {
                          final isSelected =
                              TxaSettings.fontFamily == f['name'];
                          return ListTile(
                            onTap: () {
                              setState(
                                () => TxaSettings.fontFamily = f['name']!,
                              );
                              Navigator.pop(ctx);
                            },
                            title: Text(
                              f['label']!,
                              style: TextStyle(
                                color: isSelected
                                    ? TxaTheme.accent
                                    : Colors.white,
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
                        }).toList(),
                      ),
                    ),
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
