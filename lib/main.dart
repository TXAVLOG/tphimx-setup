import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:app_links/app_links.dart';
import 'pages/email_verification_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'widgets/splash_screen.dart';
import 'services/txa_api.dart';
import 'services/txa_settings.dart';
import 'services/txa_network.dart';
import 'services/search_provider.dart';
import 'theme/txa_theme.dart';
import 'services/txa_mini_player_provider.dart';
import 'services/txa_shortcut_service.dart';
import 'services/favorite_provider.dart';
import 'services/notification_provider.dart';
import 'widgets/txa_mini_player.dart';
import 'utils/txa_logger.dart';
import 'pages/home_screen.dart';
import 'pages/movie_detail_screen.dart';
import 'services/txa_language.dart';
import 'services/txa_background_service.dart';
import 'services/txa_speed_service.dart';
import 'services/txa_download_manager.dart';
import 'services/txa_history_sync_service.dart';
import 'pages/download_manager_screen.dart';
import 'widgets/txa_watermark.dart';
import 'services/txa_screenshot_service.dart';
import 'package:screenshot/screenshot.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TxaSettings.init();
  await TxaLanguage.init();
  await TxaBackgroundService.init();
  await TxaBackgroundService.registerUpdateTask();
  await TxaSpeedService.init();
  TxaSpeedService.toggleSpeedNotification(TxaSettings.showSpeedInNotification);
  await TxaDownloadManager().init();
  await initializeDateFormatting('vi', null);

  try {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
  } catch (e) {
    debugPrint('Timezone Init Error: $e');
  }

  // Check Android TV
  bool isTV = false;
  if (!kIsWeb && Platform.isAndroid) {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    isTV = androidInfo.systemFeatures.contains('android.software.leanback');
  }

  TxaLogger.log('TPhimX Premium: Application startup sequence completed.');

  // Initialize Local Notifications (handled in _TPhimXAppState for navigation)

  // Handle Deep Links
  final appLinks = AppLinks();

  runApp(
    MultiProvider(
      providers: [
        Provider<TxaApi>(create: (_) => TxaApi()),
        ChangeNotifierProvider<TxaNetwork>(create: (_) => TxaNetwork()),
        ProxyProvider2<TxaApi, TxaNetwork, TxaHistorySyncService>(
          update: (_, api, network, _) => TxaHistorySyncService(api, network),
        ),
        ChangeNotifierProvider<SearchProvider>(create: (_) => SearchProvider()),
        ChangeNotifierProvider<FavoriteProvider>(
          create: (context) => FavoriteProvider(context.read<TxaApi>()),
        ),
        ChangeNotifierProvider<NotificationProvider>(
          create: (context) => NotificationProvider(context.read<TxaApi>()),
        ),
        ChangeNotifierProvider<TxaMiniPlayerProvider>(
          create: (_) => TxaMiniPlayerProvider(),
        ),
        ChangeNotifierProvider<TxaDownloadManager>.value(
          value: TxaDownloadManager(),
        ),
        Provider<AppLinks>.value(value: appLinks),
      ],
      child: TPhimXApp(isTV: isTV),
    ),
  );
}

class TPhimXApp extends StatefulWidget {
  final bool isTV;
  const TPhimXApp({super.key, this.isTV = false});

  @override
  State<TPhimXApp> createState() => _TPhimXAppState();
}

class _TPhimXAppState extends State<TPhimXApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TxaSettings.isAppForeground = true;
    _initDeepLinks();
    _initNotifications();

    // Initialize screenshot detection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TxaScreenshotService().init(context);
    });

    TxaSettings.onSettingsChanged = () {
      if (mounted) setState(() {});
    };
    TxaLanguage.onLanguageChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      TxaSettings.isAppForeground = true;
    } else {
      TxaSettings.isAppForeground = false;
    }
  }

  void _initNotifications() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    try {
      final plugin = FlutterLocalNotificationsPlugin();
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await plugin.initialize(
        settings: const InitializationSettings(
          android: androidInit,
          iOS: darwinInit,
        ),
        onDidReceiveNotificationResponse: (response) {
          _handleNotificationPayload(response.payload);
        },
      );

      // Handle notification if app was launched from it
      final launchDetails = await plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        _handleNotificationPayload(
          launchDetails?.notificationResponse?.payload,
        );
      }

      if (Platform.isIOS) {
        await plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      TxaLogger.log('[Notification] Init failed in AppState: $e');
    }
  }

  void _handleNotificationPayload(String? payload) {
    if (payload == null || !payload.startsWith('movie_detail:')) return;

    final parts = payload.split(':');
    if (parts.length < 2) return;
    final slug = parts[1];
    if (slug.isEmpty) return;

    TxaLogger.log('[Notification] Deep linking to movie: $slug');

    // Polling until navigator is ready (max 5 seconds)
    int attempts = 0;
    Timer.periodic(const Duration(milliseconds: 300), (timer) {
      attempts++;
      if (_navigatorKey.currentState != null) {
        timer.cancel();
        _navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (ctx) => MovieDetailScreen(slug: slug)),
        );
      } else if (attempts > 15) {
        timer.cancel();
        TxaLogger.log('[Notification] Navigator state timeout', isError: true);
      }
    });
  }

  void _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle initial link if app was closed
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) _handleDeepLink(initialUri);

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.path.contains('verify-email')) {
      final token = uri.queryParameters['token'];
      if (token != null) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (ctx) => EmailVerificationScreen(token: token),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String fontFamily = TxaSettings.fontFamily;
    TextTheme? textTheme;

    switch (fontFamily) {
      case 'Roboto':
        textTheme = GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme);
        break;
      case 'Inter':
        textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
        break;
      case 'Open Sans':
        textTheme = GoogleFonts.openSansTextTheme(ThemeData.dark().textTheme);
        break;
      case 'Montserrat':
        textTheme = GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme);
        break;
      case 'Oswald':
        textTheme = GoogleFonts.oswaldTextTheme(ThemeData.dark().textTheme);
        break;
      case 'Playfair Display':
        textTheme = GoogleFonts.playfairDisplayTextTheme(
          ThemeData.dark().textTheme,
        );
        break;
      default:
        textTheme = GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme);
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'TPhimX Premium',
      debugShowCheckedModeBanner: false,
      theme: TxaTheme.darkTheme.copyWith(textTheme: textTheme),
      home: widget.isTV ? const TVBlockScreen() : const MainEntry(),
      builder: (context, child) {
        return Screenshot(
          controller: TxaScreenshotService().screenshotController,
          child: TxaWatermark(
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(TxaSettings.fontSizeScale),
              ),
              child: Stack(
                children: [
                  child ?? const SizedBox.shrink(),
                  const TxaMiniPlayer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class TVBlockScreen extends StatelessWidget {
  const TVBlockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: TxaTheme.secondaryBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TxaTheme.glassBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.tv_off_rounded,
                color: Colors.redAccent,
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                'Ứng dụng không hỗ trợ Android TV',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Vui lòng cài đặt phiên bản TPhimX dành cho TV để có trải nghiệm tốt nhất.',
                textAlign: TextAlign.center,
                style: TextStyle(color: TxaTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => SystemNavigator.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Thoát'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainEntry extends StatefulWidget {
  const MainEntry({super.key});

  @override
  State<MainEntry> createState() => _MainEntryState();
}

class _MainEntryState extends State<MainEntry> {
  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    TxaShortcutService.init((type) {
      if (!mounted) return;
      final miniProvider = context.read<TxaMiniPlayerProvider>();

      switch (type) {
        case 'action_player_play_pause':
          miniProvider.playPause();
          break;
        case 'action_player_close':
          miniProvider.close();
          break;
        case 'action_check_update':
          TxaBackgroundService.manualCheckUpdate();
          break;
      }
    });

    // Start History Sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TxaHistorySyncService>().start();
    });
  }

  bool _showSplash = true;
  bool _isOfflineMode = false;
  bool _isNoConnectionNoData = false;

  Future<void> _checkConnectivity() async {
    final network = context.read<TxaNetwork>();
    final isOnline = await network.isConnected();
    if (!mounted) return;

    if (!isOnline) {
      final downloadManager = context.read<TxaDownloadManager>();
      // Check if there are ANY completed tasks to show in offline mode
      if (downloadManager.tasks.any(
        (t) => t.status == DownloadStatus.completed,
      )) {
        setState(() {
          _isOfflineMode = true;
          _isNoConnectionNoData = false;
        });
      } else {
        setState(() {
          _isOfflineMode = false;
          _isNoConnectionNoData = true;
        });
      }
    } else {
      setState(() {
        _isNoConnectionNoData = false;
        _isOfflineMode = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onFinish: () {
          setState(() {
            _showSplash = false;
          });
        },
      );
    }

    if (_isNoConnectionNoData) {
      return const NoConnectionScreen();
    }

    if (_isOfflineMode) {
      return const OfflineModeScreen();
    }

    return HomeScreen(
      key: ValueKey("${TxaSettings.authToken}_${TxaLanguage.currentLang}"),
    );
  }
}

class NoConnectionScreen extends StatelessWidget {
  const NoConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 80,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 24),
              Text(
                TxaLanguage.t('no_internet_no_downloads'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                TxaLanguage.t('no_internet_msg'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // In a real app, we might want to restart or re-check
                  // For now, let's just trigger a re-check
                  final state = context
                      .findAncestorStateOfType<_MainEntryState>();
                  state?._checkConnectivity();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(TxaLanguage.t('retry')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OfflineModeScreen extends StatelessWidget {
  const OfflineModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          TxaLanguage.t('offline_mode'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: const Icon(
          Icons.signal_wifi_off_rounded,
          color: Colors.redAccent,
        ),
      ),
      body: const DownloadManagerScreen(),
    );
  }
}
