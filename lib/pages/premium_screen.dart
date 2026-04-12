import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'package:cross_file/cross_file.dart';
import '../theme/txa_theme.dart';
import '../services/txa_settings.dart';
import '../services/txa_language.dart';
import '../utils/txa_toast.dart';
import '../utils/txa_logger.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingUri(uri);
    });
    _appLinks.getInitialLink().then((uri) {
      if (uri != null && mounted) _handleIncomingUri(uri);
    });
  }

  void _handleIncomingUri(Uri uri) {
    if (uri.scheme == 'tphimx' && uri.host == 'udid') {
      final String? m = uri.queryParameters['m'];
      if (m != null && m.isNotEmpty) {
        final bool isValid = RegExp(r'^[a-fA-F0-9\-]{20,45}$').hasMatch(m);
        if (isValid) {
          setState(() { TxaSettings.udid = m; });
          if (mounted) TxaToast.show(context, TxaLanguage.t('udid_auto_detected'));
        } else {
          if (mounted) TxaToast.show(context, TxaLanguage.t('udid_invalid').replaceAll('%m', m), isError: true);
        }
      }
    }
  }

  Future<void> _launchUrl(BuildContext context, String urlStr) async {
    final Uri url = Uri.parse(urlStr);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(TxaLanguage.t('not_open_link'))),
      );
    }
  }

  Future<void> _handleGetUDID(BuildContext context) async {
    if (Platform.isIOS) {
      String deviceName = "iPhone";
      try {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name;
      } catch (e) {
        deviceName = "iOS Device";
      }
      final String url = "https://asset.nrotxa.online/uuid?device_name=${Uri.encodeComponent(deviceName)}";
      if (!context.mounted) return;
      await _launchUrl(context, url);
    }
  }

  void _handleDeleteUdid() {
    setState(() { TxaSettings.udid = ''; });
    TxaToast.show(context, TxaLanguage.t('udid_deleted'));
  }

  void _showUdidInputDialog(BuildContext context) {
    final controller = TextEditingController(text: TxaSettings.udid);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxaTheme.cardBg,
        surfaceTintColor: Colors.transparent,
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.white10),
        ),
        title: Row(
          children: [
            const Icon(Icons.fingerprint_rounded, color: TxaTheme.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              TxaSettings.udid.isEmpty ? TxaLanguage.t('udid_register_title') : TxaLanguage.t('udid_update_title'),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace'),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black26,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                hintText: TxaLanguage.t('udid_hint'),
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(TxaLanguage.t('cancel'), style: const TextStyle(color: Colors.white38, fontSize: 13)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                setState(() { TxaSettings.udid = val; });
                Navigator.pop(ctx);
                TxaToast.show(context, '✅ ${TxaLanguage.t('udid_save')} ${TxaLanguage.t('success')}!');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TxaTheme.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(TxaLanguage.t('udid_save'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareLogs() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/Logs');
      if (!await logDir.exists()) {
        if (mounted) TxaToast.show(context, TxaLanguage.t('no_logs_found'), isError: true);
        return;
      }

      final files = await logDir.list().where((f) => f.path.endsWith('.log')).toList();
      if (files.isEmpty) {
        if (mounted) TxaToast.show(context, TxaLanguage.t('no_logs_found'), isError: true);
        return;
      }

      final xFiles = files.map((f) => XFile(f.path)).toList();
      await Share.shareXFiles(
        xFiles,
        subject: TxaLanguage.t('share_logs_subject'),
      );
    } catch (e) {
      TxaLogger.log('Share logs error: $e', isError: true);
      if (mounted) TxaToast.show(context, '${TxaLanguage.t('error')}: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRegistered = TxaSettings.udid.isNotEmpty;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isRegistered
                          ? [Colors.green.withValues(alpha: 0.2), Colors.green.withValues(alpha: 0.05)]
                          : [TxaTheme.accent.withValues(alpha: 0.2), TxaTheme.accent.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isRegistered ? Colors.green.withValues(alpha: 0.3) : TxaTheme.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    isRegistered ? Icons.verified_rounded : Icons.workspace_premium_rounded,
                    color: isRegistered ? Colors.green : TxaTheme.accent,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TxaLanguage.t('ios_service_title'),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isRegistered
                            ? TxaLanguage.t('ios_ready_desc')
                            : TxaLanguage.t('ios_premium_desc'),
                        style: const TextStyle(color: TxaTheme.textMuted, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isRegistered
                      ? [Colors.green.withValues(alpha: 0.1), Colors.transparent]
                      : [TxaTheme.accent.withValues(alpha: 0.1), Colors.transparent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isRegistered ? Colors.green.withValues(alpha: 0.3) : TxaTheme.accent.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    isRegistered ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    color: isRegistered ? Colors.green : TxaTheme.accent,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isRegistered ? TxaLanguage.t('udid_registered_badge') : TxaLanguage.t('ios_premium_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isRegistered ? Colors.green : TxaTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isRegistered) ...[
                    const SizedBox(height: 16),
                    // UDID display (compact)
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: TxaSettings.udid));
                        TxaToast.show(context, TxaLanguage.t('udid_copied'));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.fingerprint_rounded, color: TxaTheme.accent, size: 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                TxaSettings.udid,
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                              ),
                            ),
                            const Icon(Icons.copy_rounded, color: TxaTheme.accent, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            if (isRegistered) ...[
              // Install button
              ElevatedButton.icon(
                onPressed: () => _launchUrl(context, 'https://asset.nrotxa.online/install'),
                icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                label: Text(TxaLanguage.t('udid_install_btn')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.withValues(alpha: 0.8),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 12),
              // Update + Delete row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showUdidInputDialog(context),
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: Text(TxaLanguage.t('udid_update_btn')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TxaTheme.glassBg,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _handleDeleteUdid,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text(TxaLanguage.t('udid_delete_btn')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent, width: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Get UDID + Input UDID
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleGetUDID(context),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                      label: Text(TxaLanguage.t('udid_get_btn')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TxaTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showUdidInputDialog(context),
                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                      label: Text(TxaLanguage.t('udid_input_btn')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TxaTheme.accent,
                        side: const BorderSide(color: TxaTheme.accent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),

            // Share Logs Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TxaTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TxaTheme.glassBorder),
              ),
              child: InkWell(
                onTap: _shareLogs,
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: TxaTheme.glassBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.share_rounded, color: TxaTheme.textPrimary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TxaLanguage.t('share_logs'),
                            style: const TextStyle(color: TxaTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            TxaLanguage.t('share_logs_desc'),
                            style: const TextStyle(color: TxaTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: TxaTheme.textMuted, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
