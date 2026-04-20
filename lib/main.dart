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
import 'services/txa_language.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TxaSettings.init();
  await TxaLanguage.init();
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

  // Initialize Local Notifications (Android & iOS only, skip Web)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          );
      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );
      await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
      );

      // Request permissions explicitly for iOS
      if (Platform.isIOS) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      TxaLogger.log('[Notification] Init failed: $e');
    }
  }

  // Handle Deep Links
  final appLinks = AppLinks();

  runApp(
    MultiProvider(
      providers: [
        Provider<TxaApi>(create: (_) => TxaApi()),
        Provider<TxaNetwork>(create: (_) => TxaNetwork()),
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

class _TPhimXAppState extends State<TPhimXApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    TxaSettings.onSettingsChanged = () {
      if (mounted) setState(() {});
    };
    TxaLanguage.onLanguageChanged = () {
      if (mounted) setState(() {});
    };
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
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(TxaSettings.fontSizeScale)),
          child: Stack(
            children: [child ?? const SizedBox.shrink(), const TxaMiniPlayer()],
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
      }
    });
  }

  bool _showSplash = true;

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
    return HomeScreen(
      key: ValueKey("${TxaSettings.authToken}_${TxaLanguage.currentLang}"),
    ); // Pass ValueKey to force rebuild on auth/lang change
  }
}
