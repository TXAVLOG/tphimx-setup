import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/txa_language.dart';
import '../services/txa_network.dart';
import '../services/txa_permission.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/txa_settings.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_toast.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/date_symbol_data_local.dart';
import '../services/txa_download_manager.dart';
import '../services/txa_api.dart';
import 'txa_maintenance_screen.dart';
import '../utils/txa_logger.dart';
import '../widgets/txa_modal.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const SplashScreen({super.key, required this.onFinish});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with WidgetsBindingObserver {
  double _progress = 0.0;
  String _status = '';
  String? _fatalError;
  bool _isIosLocked = false;
  bool _isMaintenance = false;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
    // Allow UI to settle before starting heavy initialization
    Future.delayed(const Duration(seconds: 1), _startInit);
    
    // Remove the native splash screen as soon as Flutter draws its first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isShowingPermissionModal) {
      // Re-check permissions when coming back from settings
      _checkPermissionsSilently();
    }
  }

  bool _isShowingPermissionModal = false;
  Map<String, PermissionStatus> _permissionStatuses = {};

  Future<void> _checkPermissionsSilently() async {
    final statuses = await TxaPermission.getAllStatus();
    if (mounted) {
      setState(() {
        _permissionStatuses = statuses;
      });
      // If modal is showing and all mandatory are now granted, we don't automatically close it, 
      // but the "Continue" button will light up.
    }
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingUri(uri);
    });
  }

  void _handleIncomingUri(Uri uri) {
    if (uri.scheme == 'tphimx' && uri.host == 'udid') {
      final String? m = uri.queryParameters['m'];
      if (m != null && m.isNotEmpty) {
        final bool isValid = RegExp(r'^[a-fA-F0-9\-]{20,45}$').hasMatch(m);
        if (isValid) {
          TxaSettings.udid = m;
          TxaToast.show(context, '✅ Xác minh thiết bị thành công!');
          if (_isIosLocked) {
            setState(() {
              _isIosLocked = false;
              _status = 'Đang tiếp tục khởi động...';
            });
            _startInit();
          }
        } else {
          TxaToast.show(context, '❌ Mã UDID không hợp lệ: $m', isError: true);
        }
      }
    }
  }

  Future<void> _startInit() async {
    try {
      // 1. Initial Permission Check
      setState(() {
        _status = TxaLanguage.t('splash_check_permissions');
        _progress = 0.05;
      });

      TxaLogger.log('Step 1: Checking mandatory permissions...', tag: 'SPLASH');
      final allMandatory = await TxaPermission.checkAllMandatory().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
      if (!allMandatory) {
        TxaLogger.log('Permissions missing, showing modal...', tag: 'SPLASH');
        await _showPermissionModal();
      }
      TxaLogger.log('Permissions OK.', tag: 'SPLASH');

      // 2. Initialize Language
      setState(() {
        _status = TxaLanguage.t('splash_init_language');
        _progress = 0.3;
      });
      TxaLogger.log('Step 2: Initializing Language...', tag: 'SPLASH');
      await TxaLanguage.init().timeout(
        const Duration(seconds: 5),
        onTimeout: () => TxaLogger.log('Language init timeout', isError: true, tag: 'SPLASH'),
      );
      TxaLogger.log('Language initialized: ${TxaLanguage.currentLang}', tag: 'SPLASH');

      // 3. Initialize Timezone
      setState(() {
        _status = TxaLanguage.t('splash_config_system');
        _progress = 0.5;
      });
      await initializeDateFormatting('vi', null);
      try {
        tz.initializeTimeZones();
        tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
      } catch (e) {
        // Timezone init failure
      }

      // 4. Initialize Download Manager
      setState(() {
        _status = TxaLanguage.t('splash_init_download');
        _progress = 0.7;
      });
      print('TXA_BOOT_SPLASH: Starting DownloadManager init...');
      await TxaDownloadManager().init().timeout(const Duration(seconds: 15));
      print('TXA_BOOT_SPLASH: DownloadManager init done');

      // 2.5 iOS UDID Check (Locked state)
      if (Platform.isIOS && TxaSettings.udid.isEmpty) {
        setState(() {
          _isIosLocked = true;
          _progress = 0.75;
          _status = TxaLanguage.t('splash_ios_no_access');
        });
        return; // Stop initialization until unlocked via deep link
      }

      // 5. Check Network
      setState(() {
        _status = TxaLanguage.t('connecting');
        _progress = 0.9;
      });
      final hasNet = await TxaNetwork().checkConnection().timeout(
        const Duration(seconds: 5),
        onTimeout: () => true, // Assume connected if check fails
      );
      if (!hasNet) {
        _showError(TxaLanguage.t('network_error'));
        return;
      }

      // 6. Ping API to check Maintenance Mode
      try {
        print('TXA_BOOT_SPLASH: Starting API Maintenance check...');
        final api = TxaApi();
        final isMaintenance = await api.checkMaintenance().timeout(const Duration(seconds: 10));
        print('TXA_BOOT_SPLASH: API Maintenance check done: $isMaintenance');
        if (isMaintenance) {
           setState(() {
            _isMaintenance = true;
          });
          return;
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 503) {
          setState(() {
            _isMaintenance = true;
          });
          return;
        }
        TxaLogger.log('API Check failed (non-critical): $e', tag: 'SPLASH');
      }

      // Success final progress update
      setState(() {
        _progress = 1.0;
        _status = TxaLanguage.t('success');
      });
      Future.delayed(const Duration(seconds: 1), widget.onFinish);
    } catch (e, stack) {
      debugPrint('[SplashError] $e\n$stack');
      setState(() {
        _fatalError = e.toString();
        _status = TxaLanguage.t('splash_init_failed');
      });
    }
  }

  Future<void> _showPermissionModal() async {
    _isShowingPermissionModal = true;
    _permissionStatuses = await TxaPermission.getAllStatus();

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Continuous check inside modal
          Timer? checkTimer;
          
          // We use a local state to track if we've already started the timer
          // to avoid multiple timers in the same dialog
          void startTimer() {
            checkTimer?.cancel();
            checkTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
              if (!ctx.mounted) {
                timer.cancel();
                return;
              }
              final newStatuses = await TxaPermission.getAllStatus();
              bool changed = false;
              newStatuses.forEach((key, value) {
                if (_permissionStatuses[key] != value) changed = true;
              });

              if (changed && ctx.mounted) {
                setModalState(() {
                  _permissionStatuses = newStatuses;
                });
                // Also update the parent state just in case
                if (mounted) {
                  setState(() {
                    _permissionStatuses = newStatuses;
                  });
                }
              }
            });
          }

          // Trigger timer once
          WidgetsBinding.instance.addPostFrameCallback((_) => startTimer());

          final mandatory = TxaPermission.mandatoryPermissions;
          final optional = TxaPermission.optionalPermissions;

          bool canContinue = true;
          for (var p in mandatory) {
            if (!(_permissionStatuses[p['id']]?.isGranted ?? false)) {
              canContinue = false;
              break;
            }
          }

          return TxaModal(
            title: TxaLanguage.t('permissions_required'),
            showClose: false,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPermissionSection(
                  TxaLanguage.t('permissions_mandatory'),
                  mandatory,
                  setModalState,
                ),
                const SizedBox(height: 16),
                _buildPermissionSection(
                  TxaLanguage.t('permissions_optional'),
                  optional,
                  setModalState,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  checkTimer?.cancel();
                  _isShowingPermissionModal = false;
                  Navigator.pop(ctx);
                },
                child: Text(
                  TxaLanguage.t('cancel'),
                  style: const TextStyle(color: TxaTheme.textMuted),
                ),
              ),
              ElevatedButton(
                onPressed: canContinue
                    ? () {
                        checkTimer?.cancel();
                        _isShowingPermissionModal = false;
                        Navigator.pop(ctx);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TxaTheme.accent,
                  disabledBackgroundColor: Colors.white10,
                  foregroundColor: Colors.black,
                  disabledForegroundColor: Colors.white24,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  minimumSize: const Size(120, 44),
                ),
                child: Text(
                  TxaLanguage.t('continue'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPermissionSection(
    String title,
    List<Map<String, dynamic>> perms,
    StateSetter setModalState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: TxaTheme.accent,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...perms.map((p) {
          final status = _permissionStatuses[p['id']] ?? PermissionStatus.denied;
          final isGranted = status.isGranted;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isGranted
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['label'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p['desc'],
                        style: const TextStyle(
                          color: TxaTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: isGranted
                      ? null
                      : () async {
                          if (p['id'] == 'battery') {
                            await TxaPermission.requestIgnoreBatteryOptimizations();
                          } else {
                            final Permission perm = p['permission'];
                            await perm.request();
                          }
                          final newStatuses = await TxaPermission.getAllStatus();
                          if (mounted) {
                            setState(() {
                              _permissionStatuses = newStatuses;
                            });
                            setModalState(() {});
                          }
                        },
                  style: TextButton.styleFrom(
                    backgroundColor: isGranted
                        ? Colors.green.withValues(alpha: 0.1)
                        : TxaTheme.accent.withValues(alpha: 0.1),
                    foregroundColor: isGranted ? Colors.green : TxaTheme.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: Text(
                    isGranted ? TxaLanguage.t('granted') : TxaLanguage.t('grant'),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> _handleGetUDID() async {
    String deviceName = "iPhone";
    try {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      deviceName = iosInfo.name;
    } catch (e) {
      deviceName = "iOS Device";
    }

    final String url =
        "https://asset.nrotxa.online/uuid?device_name=${Uri.encodeComponent(deviceName)}";
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      // ignore: use_build_context_synchronously
      TxaToast.show(context, TxaLanguage.t('splash_browser_error'), isError: true);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxaTheme.cardBg,
        title: Text(
          TxaLanguage.t('error'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          msg,
          style: const TextStyle(color: TxaTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startInit();
            },
            child: Text(TxaLanguage.t('retry')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isMaintenance) {
      return TxaMaintenanceScreen(
        onRetry: () {
          setState(() {
            _isMaintenance = false;
            _progress = 0;
            _fatalError = null;
          });
          _startInit();
        },
      );
    }

    if (_fatalError != null) {
      return _buildErrorView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', width: 80, height: 80),
            const SizedBox(height: 32),
            Container(
              width: 240,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: 240 * _progress,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [TxaTheme.accent, Color(0xFF818CF8)],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${(_progress * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: TxaTheme.textMuted, fontSize: 13),
              ),
            ),
            if (_isIosLocked) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _handleGetUDID,
                icon: const Icon(Icons.apple_rounded),
                label: Text(
                  TxaLanguage.t('splash_get_access'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TxaTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                TxaLanguage.t('splash_safari_note'),
                style: const TextStyle(color: Colors.white30, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 64,
            ),
            const SizedBox(height: 24),
            Text(
              TxaLanguage.t('splash_error_title'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: SelectableText(
                _fatalError ?? TxaLanguage.t('error_unknown'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _fatalError ?? 'NaN'),
                    );
                    TxaToast.show(context, TxaLanguage.t('splash_error_copied'));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(TxaLanguage.t('splash_error_copy')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white12,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _fatalError = null;
                      _progress = 0;
                    });
                    _startInit();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(TxaLanguage.t('retry')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TxaTheme.accent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
