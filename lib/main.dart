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
import 'pages/home_screen.dart';
import 'utils/txa_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TxaSettings.init();
  await initializeDateFormatting('vi', null);
  
  TxaLogger.log('TPhimX Premium: Application startup sequence completed.');
  
  // Initialize Local Notifications (only on Android/iOS/Desktop)
  if (!ThemeData().platform.toString().contains('web')) {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<TxaApi>(create: (_) => TxaApi()),
        Provider<TxaNetwork>(create: (_) => TxaNetwork()),
        ChangeNotifierProvider<SearchProvider>(create: (_) => SearchProvider()),
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
    );
  }
}

class MainEntry extends StatefulWidget {
  const MainEntry({super.key});

  @override
  State<MainEntry> createState() => _MainEntryState();
}

class _MainEntryState extends State<MainEntry> {
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
