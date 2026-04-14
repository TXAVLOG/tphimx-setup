import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'widgets/splash_screen.dart';
import 'services/txa_api.dart';
import 'services/txa_network.dart';
import 'services/txa_settings.dart';
import 'services/search_provider.dart';
import 'theme/txa_theme.dart';
import 'services/txa_mini_player_provider.dart';
import 'services/txa_shortcut_service.dart';
import 'widgets/txa_mini_player.dart';
import 'utils/txa_logger.dart';
import 'pages/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TxaSettings.init();
  await initializeDateFormatting('vi', null);
  
  TxaLogger.log('TPhimX Premium: Application startup sequence completed.');
  
  // Initialize Local Notifications (Android & iOS only, skip Web)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);
      
      // Request permissions explicitly for iOS
      if (Platform.isIOS) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      }
    } catch (e) {
      TxaLogger.log('[Notification] Init failed: $e');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<TxaApi>(create: (_) => TxaApi()),
        Provider<TxaNetwork>(create: (_) => TxaNetwork()),
        ChangeNotifierProvider<SearchProvider>(create: (_) => SearchProvider()),
        ChangeNotifierProvider<TxaMiniPlayerProvider>(create: (_) => TxaMiniPlayerProvider()),
      ],
      child: const TPhimXApp(),
    ),
  );
}

class TPhimXApp extends StatelessWidget {
  const TPhimXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TPhimX Premium',
      debugShowCheckedModeBanner: false,
      theme: TxaTheme.darkTheme.copyWith(
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const MainEntry(),
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const TxaMiniPlayer(),
          ],
        );
      },
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
      return SplashScreen(onFinish: () {
        setState(() {
          _showSplash = false;
        });
      });
    }
    return const HomeScreen(); // Now using the real HomeScreen with API & TxaNav
  }
}
