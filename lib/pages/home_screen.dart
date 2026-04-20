import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../widgets/txa_loading.dart';
import '../services/txa_api.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../widgets/txa_nav.dart';
import '../pages/search_screen.dart';
import '../pages/schedule_screen.dart';
import '../pages/account_screen.dart';
import '../pages/notification_screen.dart';
import '../pages/premium_screen.dart';
import '../pages/category_list_screen.dart';
import '../pages/movie_detail_screen.dart';
import '../pages/global_settings_screen.dart';
import '../widgets/txa_dropdown.dart';
import '../services/favorite_provider.dart';
import '../widgets/txa_player.dart';
import '../utils/txa_toast.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:open_file/open_file.dart';
import '../services/txa_permission.dart';
import '../widgets/txa_update_modal.dart';
import '../utils/txa_url_resolve.dart';
import '../widgets/txa_download_dialog.dart';
import '../widgets/txa_error_widget.dart';
import '../utils/txa_logger.dart';
import '../utils/txa_format.dart';
import '../services/txa_settings.dart';
import '../services/notification_provider.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final List<Widget> _tabs = [
    const _HomeTab(),
    const SearchScreen(),
    const ScheduleScreen(),
    const NotificationScreen(),
    const AccountScreen(),
    if (Platform.isIOS) const PremiumScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdate();
    });
  }

  Future<void> _checkUpdate({bool manual = false}) async {
    try {
      if (manual) TxaToast.show(context, TxaLanguage.t('checking_update'));

      final api = Provider.of<TxaApi>(context, listen: false);
      final updateData = await api.getCheckUpdate();

      final Map<String, dynamic>? appData = updateData['data'];
      final String latestVersion =
          appData?['latest_version'] ?? appData?['current_version'] ?? '';
      final String minVersion = appData?['min_version'] ?? '';
      final bool forceUpdate = appData?['force_update'] == true;

      // Get current version from PackageInfo
      final packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      debugPrint(
        '[TxaUpdate] API Latest: $latestVersion, App Current: $currentVersion, Min: $minVersion',
      );

      bool isNewer(String latest, String current) {
        List<int> latestParts = latest
            .split('.')
            .map((e) => int.tryParse(e) ?? 0)
            .toList();
        List<int> currentParts = current
            .split('.')
            .map((e) => int.tryParse(e) ?? 0)
            .toList();
        for (
          int i = 0;
          i < latestParts.length && i < currentParts.length;
          i++
        ) {
          if (latestParts[i] > currentParts[i]) return true;
          if (latestParts[i] < currentParts[i]) return false;
        }
        return latestParts.length > currentParts.length;
      }

      // Check if current version is below min_version (force update regardless)
      final bool belowMinVersion =
          minVersion.isNotEmpty && isNewer(minVersion, currentVersion);
      final bool shouldForce = forceUpdate || belowMinVersion;

      if (latestVersion.isNotEmpty && isNewer(latestVersion, currentVersion)) {
        if (!mounted) return;

        final String rawDate = appData?['release_date'] ?? '';
        final int rawSize =
            int.tryParse(appData?['size']?.toString() ?? '0') ?? 0;
        final String? sha256 = appData?['sha256'];

        String? formattedDate;
        if (rawDate.isNotEmpty) {
          try {
            DateTime dt = DateTime.parse(rawDate);
            formattedDate = TxaFormat.formatDate(dt);
          } catch (_) {}
        }

        String? formattedSize;
        if (rawSize > 0) {
          formattedSize = TxaFormat.formatSize(rawSize)['display'];
        }

        TxaUpdateModal.show(
          context,
          version: latestVersion,
          changelog: appData?['changelog'] ?? '',
          releaseDate: formattedDate,
          fileSize: formattedSize,
          forceUpdate: shouldForce,
          onUpdate: () async {
            final String rawUrl =
                appData?['download_url'] ?? appData?['apk_url'] ?? '';
            Navigator.pop(context); // Close modal

            // --- PLATFORM SENSITIVE UPDATE ---
            if (defaultTargetPlatform == TargetPlatform.iOS) {
              final uri = Uri.parse(rawUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                if (!mounted) return;
                TxaToast.show(
                  context,
                  TxaLanguage.t('error_opening_link'),
                  isError: true,
                );
              }
              return;
            }

            // --- ANDROID FLOW ---
            await _handleAndroidUpdate(rawUrl, latestVersion, rawSize, sha256);
          },
        );
      } else if (manual) {
        if (!mounted) return;
        TxaToast.show(
          context,
          TxaLanguage.t('up_to_date').replaceAll('%version', currentVersion),
        );
      }
    } catch (e) {
      if (manual && mounted) {
        TxaToast.show(context, TxaLanguage.t('update_error'), isError: true);
      }
      debugPrint('Check update error: $e');
    }
  }

  /// Handles the full Android update flow:
  /// 1. Check permissions (storage + install unknown apps)
  /// 2. Check if APK already cached & valid → install directly
  /// 3. Otherwise download then install
  Future<void> _handleAndroidUpdate(
    String rawUrl,
    String version,
    int expectedSize,
    String? sha256,
  ) async {
    // --- STEP 1: STORAGE PERMISSION ---
    if (!await TxaPermission.checkAllRequired()) {
      if (!mounted) return;
      TxaToast.show(
        context,
        TxaLanguage.t('permissions_required'),
        isError: true,
      );
      await TxaPermission.requestInitial();
      if (!mounted) return;
      if (!await TxaPermission.checkAllRequired()) return;
    }

    // --- STEP 2: INSTALL UNKNOWN APPS PERMISSION ---
    // Request and then ALWAYS continue to install/download after granting
    if (!await TxaPermission.requestInstall()) {
      if (!mounted) return;
      TxaToast.show(
        context,
        TxaLanguage.t('permissions_required'),
        isError: true,
      );
      return; // User explicitly denied — stop
    }

    if (!mounted) return;

    // --- STEP 3: CHECK CACHED APK ---
    final String filename = 'TPHIMX_$version.apk';
    final dir = await getExternalStorageDirectory();
    final String savePath = '${dir?.path}/$filename';
    final File cachedFile = File(savePath);

    if (cachedFile.existsSync()) {
      final int localSize = cachedFile.lengthSync();
      bool isValid = false;

      if (expectedSize > 0 && localSize == expectedSize) {
        // Size matches — check SHA256 if provided by server
        if (sha256 != null && sha256.isNotEmpty) {
          if (!mounted) return;
          TxaToast.show(context, TxaLanguage.t('verifying_file'));
          final bytes = await cachedFile.readAsBytes();
          final localHash = _sha256Hex(bytes);
          isValid = localHash == sha256.toLowerCase();
          debugPrint(
            '[TxaUpdate] SHA256 check: local=$localHash, server=$sha256, match=$isValid',
          );
        } else {
          // No SHA256 from server — size match is good enough
          isValid = true;
        }
      }

      if (isValid) {
        // File is already downloaded and valid → install directly!
        debugPrint(
          '[TxaUpdate] Cached APK valid ($localSize bytes), opening installer directly',
        );
        if (!mounted) return;
        TxaToast.show(context, TxaLanguage.t('installing_cached'));
        final result = await OpenFile.open(savePath);
        if (!mounted) return;
        if (result.type != ResultType.done) {
          TxaToast.show(context, "Error: ${result.message}", isError: true);
        }
        return;
      } else {
        // File corrupted or size mismatch → delete and re-download
        debugPrint(
          '[TxaUpdate] Cached APK invalid (local=$localSize, expected=$expectedSize), deleting...',
        );
        try {
          cachedFile.deleteSync();
        } catch (_) {}
      }
    }

    // --- STEP 4: DOWNLOAD ---
    if (!mounted) return;
    TxaToast.show(context, TxaLanguage.t('loading_progress'));

    // Resolve direct link (Handles Mediafire!)
    final resolved = await TxaUrlResolve.resolve(rawUrl);
    if (resolved['success']) {
      if (!mounted) return;
      TxaDownloadDialog.show(
        context,
        resolved['url'],
        filename,
        onFinished: (path) async {
          TxaLogger.log('Download finished, opening installer: $path');
          final result = await OpenFile.open(path);
          if (!mounted) return;
          if (result.type != ResultType.done) {
            TxaToast.show(context, "Error: ${result.message}", isError: true);
          }
        },
      );
    } else {
      if (!mounted) return;
      TxaToast.show(
        context,
        TxaLanguage.t(
          'resolver_error',
        ).replaceAll('%error', resolved['error'] ?? 'Unknown'),
        isError: true,
      );
    }
  }

  /// Simple SHA256 hex digest
  String _sha256Hex(List<int> bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          TxaToast.show(context, TxaLanguage.t('press_back_again'));
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: TxaTheme.primaryBg,
        drawer: _buildDrawer(),
        body: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [TxaTheme.primaryBg, Color(0xFF0F172A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: IndexedStack(index: _currentIndex, children: _tabs),
            ),

            // Home Header (Pinned) - Only show on Home Tab
            if (_currentIndex == 0) _buildHomeHeader(),

            // TxaNav
            Consumer<NotificationProvider>(
              builder: (context, notif, child) {
                return TxaNav(
                  currentIndex: _currentIndex,
                  unreadNotifications: notif.unreadCount,
                  onTap: (index) {
                    setState(() => _currentIndex = index);
                    if (index == 3) {
                      notif
                          .markAllRead(); // Or keep as is depending on business logic
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: const Icon(
                  Icons.menu_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              Row(
                children: [
                  Image.asset('assets/logo.png', height: 24),
                  const SizedBox(width: 8),
                  Text(
                    TxaLanguage.t('app_name'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _GlassIconBtn(
                    icon: Icons.search_rounded,
                    onTap: () => setState(() => _currentIndex = 1),
                  ),
                  const SizedBox(width: 8),
                  Consumer<NotificationProvider>(
                    builder: (context, notif, child) {
                      return _GlassIconBadge(
                        icon: Icons.notifications_rounded,
                        badgeCount: notif.unreadCount,
                        onTap: () => setState(() => _currentIndex = 3),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _GlassIconBtn(
                    icon: Icons.settings_rounded,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => const GlobalSettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Image.asset('assets/logo.png', height: 40),
                  const SizedBox(width: 12),
                  const Text(
                    'TPhimX Premium',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10),
            // Version & Check Update
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final version = snapshot.data?.version ?? '...';
                      return Text(
                        TxaLanguage.t(
                          'current_version',
                        ).replaceAll('%version', version),
                        style: const TextStyle(
                          color: TxaTheme.textMuted,
                          fontSize: 13,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _checkUpdate(manual: true),
                      icon: const Icon(
                        Icons.system_update_alt_rounded,
                        size: 16,
                      ),
                      label: Text(TxaLanguage.t('check_update')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10),
            // Language Selection
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TxaLanguage.t('language'),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TxaDropdown<String>(
                    value: TxaLanguage.currentLang,
                    items: [
                      DropdownMenuItem(
                        value: 'vi',
                        child: Text(TxaLanguage.t('vi_lang')),
                      ),
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(TxaLanguage.t('en_lang')),
                      ),
                    ],
                    onChanged: (val) async {
                      if (val != null) {
                        await TxaLanguage.setLang(val);
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),
            if (Platform.isAndroid) ...[
              const Divider(color: Colors.white10),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TxaLanguage.t('check_permissions'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<Map<String, PermissionStatus>>(
                      future: TxaPermission.getAllStatus(),
                      builder: (context, snapshot) {
                        final statuses = snapshot.data ?? {};
                        return Column(
                          children: TxaPermission.permissions.map((p) {
                            final status =
                                statuses[p['id']] ?? PermissionStatus.denied;
                            final isGranted = status.isGranted;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    isGranted
                                        ? Icons.check_circle_outline
                                        : Icons.error_outline,
                                    color: isGranted
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      p['label'],
                                      style: TextStyle(
                                        color: isGranted
                                            ? Colors.white70
                                            : TxaTheme.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await TxaPermission.openSettings();
                          setState(
                            () {},
                          ); // Refresh statuses when they come back
                        },
                        icon: const Icon(Icons.settings_rounded, size: 14),
                        label: Text(
                          TxaLanguage.t('go_to_settings'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TxaTheme.glassBg,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: TxaTheme.glassBorder),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? '3.2.5';
                  final build = snapshot.data?.buildNumber ?? '325';
                  return Text(
                    'Version $version (Build $build)',
                    style: const TextStyle(
                      color: TxaTheme.textMuted,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// HOME TAB — Trang Chủ (Ported from Ionic Home.jsx)
// =====================================================
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  String _activeFilter = 'all';
  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadHome() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      final result = await api.getHome();
      final data = result['data'] ?? result;

      // Sync favorite IDs to provider
      if (mounted && data['favorite_ids'] != null) {
        Provider.of<FavoriteProvider>(context, listen: false).loadFavoriteIds(
          (data['favorite_ids'] as List)
              .map((e) => int.parse(e.toString()))
              .toList(),
        );
      }

      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      TxaLogger.log('Home Load Error: $e', isError: true);
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build sections from API data (matching Ionic logic)
    final List<Map<String, dynamic>> sections = [];

    List getListData(String key) {
      if (_data == null) return [];
      final val = _data![key];
      if (val is Map) return val['data'] as List? ?? [];
      return val as List? ?? [];
    }

    String getTitle(String key, String fallbackCode) {
      if (_data == null) return TxaLanguage.t(fallbackCode);
      final val = _data![key];
      if (val is Map && val['title'] != null) {
        return TxaLanguage.t(val['title']);
      }
      return TxaLanguage.t(fallbackCode);
    }

    if (_data != null) {
      final latest = getListData('latest').isEmpty
          ? getListData('items')
          : getListData('latest');
      final hot = getListData('hot');
      final anime = getListData('anime');
      final series = getListData('series');
      final single = getListData('single');
      final cartoon = getListData('cartoon');
      final tvshows = getListData('tvshows');
      final theater = getListData('theater');

      if (latest.isNotEmpty) {
        sections.add({
          'title': getTitle('latest', 'TXA_NEW1'),
          'movies': latest,
          'key': 'latest',
        });
      }

      if (hot.isNotEmpty) {
        sections.add({
          'title': '🔥 ${getTitle('hot', 'TXA_HOT1')}',
          'movies': hot,
          'key': 'hot',
        });
      }

      if (anime.isNotEmpty) {
        sections.add({
          'title': '🎌 ${getTitle('anime', 'TXA_HH1')}',
          'movies': anime,
          'key': 'anime',
        });
      }

      if (series.isNotEmpty) {
        sections.add({
          'title': '📺 ${getTitle('series', 'TXA_PB1')}',
          'movies': series,
          'key': 'series',
        });
      }

      if (single.isNotEmpty) {
        sections.add({
          'title': '🎬 ${getTitle('single', 'TXA_PL1')}',
          'movies': single,
          'key': 'single',
        });
      }

      if (cartoon.isNotEmpty) {
        sections.add({
          'title': '✨ ${getTitle('cartoon', 'TXA_HH1')}',
          'movies': cartoon,
          'key': 'cartoon',
        });
      }

      if (tvshows.isNotEmpty) {
        sections.add({
          'title': '🎭 ${getTitle('tvshows', 'TXA_TV1')}',
          'movies': tvshows,
          'key': 'tvshows',
        });
      }

      if (theater.isNotEmpty) {
        sections.add({
          'title': '🍿 ${getTitle('theater', 'TXA_CR1')}',
          'movies': theater,
          'key': 'theater',
        });
      }
    }

    final featured = _data?['featured'] as List? ?? [];
    final categories = _data?['categories'] as List? ?? [];

    final filteredSections = _activeFilter == 'all'
        ? sections
        : [
            ...sections.where((s) => s['key'] == _activeFilter),
            ...sections.where(
              (s) =>
                  s['key'] != _activeFilter &&
                  (s['key'] == 'latest' || s['key'] == 'hot'),
            ),
          ];

    return Container(
      color: TxaTheme.primaryBg,
      child: RefreshIndicator(
        onRefresh: _loadHome,
        color: TxaTheme.accent,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // Spacer for Pinned Header (MediaQuery top + header height)
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.top + 60),
            ),

            if (_loading)
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Skeleton HeroSlider
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: TxaSkeleton(
                          width: double.infinity,
                          height: 300,
                          borderRadius: 16,
                        ),
                      ),
                      // Skeleton FilterChips
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            4,
                            (i) => const TxaSkeleton(
                              width: 80,
                              height: 30,
                              borderRadius: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Skeleton MovieSections
                      ...List.generate(
                        2,
                        (i) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: TxaSkeleton(width: 120, height: 16),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 170,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: 5,
                                physics: const NeverScrollableScrollPhysics(),
                                itemBuilder: (ctx, idx) => const Padding(
                                  padding: EdgeInsets.only(right: 12),
                                  child: TxaSkeleton(
                                    width: 120,
                                    height: 170,
                                    borderRadius: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_error != null || _data == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: TxaErrorWidget(
                  message: TxaLanguage.t('error_loading_data'),
                  technicalDetails: _error,
                  onRetry: _loadHome,
                ),
              )
            else ...[
              // Hero Slider
              SliverToBoxAdapter(
                child: featured.isNotEmpty
                    ? _HeroSlider(movies: featured.take(10).toList())
                    : const SizedBox(height: 100),
              ),

              // Filter Tabs
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
                  child: SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _FilterChip(
                          label: TxaLanguage.t('recommendation'),
                          isActive: _activeFilter == 'all',
                          onTap: () => setState(() => _activeFilter = 'all'),
                        ),
                        _FilterChip(
                          label: TxaLanguage.t('series_movies'),
                          isActive: _activeFilter == 'series',
                          onTap: () => setState(() => _activeFilter = 'series'),
                        ),
                        _FilterChip(
                          label: TxaLanguage.t('single_movies'),
                          isActive: _activeFilter == 'single',
                          onTap: () => setState(() => _activeFilter = 'single'),
                        ),
                        ...categories
                            .take(6)
                            .map<Widget>(
                              (cat) => _FilterChip(
                                label: cat['name'] ?? '',
                                isActive: false,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (ctx) => CategoryListScreen(
                                        title: cat['name'] ?? '',
                                        slug: cat['slug'],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),

              // Popular Categories
              if (categories.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              TxaLanguage.t('trending_categories'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              TxaLanguage.t('more'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: TxaTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 75,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: categories.take(8).length,
                            itemBuilder: (ctx, i) {
                              final cat = categories[i];
                              final colors = [
                                [
                                  const Color(0xFFFACC15),
                                  const Color(0xFFEA580C),
                                ],
                                [
                                  const Color(0xFFF87171),
                                  const Color(0xFFDC2626),
                                ],
                                [
                                  const Color(0xFFF472B6),
                                  const Color(0xFFDB2777),
                                ],
                                [
                                  const Color(0xFF4ADE80),
                                  const Color(0xFF16A34A),
                                ],
                                [
                                  const Color(0xFF60A5FA),
                                  const Color(0xFF2563EB),
                                ],
                                [
                                  const Color(0xFFC084FC),
                                  const Color(0xFF9333EA),
                                ],
                              ];
                              final colorSet = colors[i % colors.length];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (ctx) => CategoryListScreen(
                                        title: cat['name'] ?? '',
                                        slug: cat['slug'],
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 135,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: colorSet,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          cat['name'] ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          TxaLanguage.t(
                                            'all_movies_count',
                                          ).replaceAll(
                                            '%count',
                                            (cat['count'] ?? '20+').toString(),
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Movie Sections
              ...filteredSections.map(
                (section) => SliverToBoxAdapter(
                  child: _MovieSection(
                    title: section['title'],
                    movies: section['movies'],
                    sectionKey: section['key'],
                  ),
                ),
              ),
            ],

            // Bottom spacer
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// WIDGETS
// =====================================================

class _GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: TxaTheme.glassBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TxaTheme.glassBorder),
        ),
        child: Icon(icon, color: TxaTheme.textPrimary, size: 20),
      ),
    );
  }
}

class _GlassIconBadge extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final VoidCallback onTap;

  const _GlassIconBadge({
    required this.icon,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TxaTheme.glassBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TxaTheme.glassBorder),
            ),
            child: Icon(icon, color: TxaTheme.textPrimary, size: 20),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? TxaTheme.accent : TxaTheme.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? TxaTheme.accent : TxaTheme.glassBorder,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : TxaTheme.textSecondary,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroSlider extends StatefulWidget {
  final List<dynamic> movies;
  const _HeroSlider({required this.movies});

  @override
  State<_HeroSlider> createState() => _HeroSliderState();
}

class _HeroSliderState extends State<_HeroSlider> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.65, initialPage: 0);
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        int nextPage = _currentPage + 1;
        if (nextPage >= widget.movies.length) nextPage = 0;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _playMovie(BuildContext context, dynamic movie) async {
    final String slug = movie['slug'] ?? '';
    if (slug.isEmpty) return;

    TxaToast.show(context, TxaLanguage.t('loading_progress'));

    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      final res = await api.getMovie(slug);
      final data = res['data'];

      if (data != null && data['servers'] != null) {
        final servers = data['servers'] as List;
        if (servers.isNotEmpty &&
            (servers[0]['server_data'] as List).isNotEmpty) {
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => TxaPlayer(
                movie: data['movie'],
                servers: servers,
                initialServerIndex: 0,
                initialEpisodeId: servers[0]['server_data'][0]['id'].toString(),
              ),
            ),
          );
          return;
        }
      }

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (ctx) => MovieDetailScreen(slug: slug)),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (ctx) => MovieDetailScreen(slug: slug)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();

    final currentMovie = widget.movies[_currentPage];
    final posterUrl =
        currentMovie['thumb_url'] ?? currentMovie['poster_url'] ?? '';
    final name = currentMovie['name'] ?? '';
    final originName = currentMovie['origin_name'] ?? '';
    final desc = currentMovie['content'] ?? currentMovie['description'] ?? '';

    return SizedBox(
      height: 620,
      child: Stack(
        children: [
          // Blurred background
          Positioned.fill(
            child: CachedNetworkImage(imageUrl: posterUrl, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),
          ),
          // Bottom gradient
          Positioned(
            bottom: -1,
            left: 0,
            right: 0,
            height: 250,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, TxaTheme.primaryBg],
                ),
              ),
            ),
          ),

          // Slider Content
          Column(
            children: [
              const SizedBox(height: 90),
              // Paging posters
              SizedBox(
                height: 320,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: widget.movies.length,
                  itemBuilder: (context, index) {
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double value = 1.0;
                        if (_pageController.position.haveDimensions) {
                          value = (_pageController.page! - index).abs();
                          value = (1 - (value * 0.2)).clamp(0.8, 1.0);
                        } else {
                          value = (index == 0) ? 1.0 : 0.8;
                        }
                        return Transform.scale(
                          scale: value,
                          child: Opacity(
                            opacity: (value - 0.7) / (1.0 - 0.7),
                            child: child,
                          ),
                        );
                      },
                      child: _HeroCard(movie: widget.movies[index]),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              // Info Overlay
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    if (originName.isNotEmpty)
                      Text(
                        originName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _HeroActionButton(
                          label: TxaLanguage.t('watch_now'),
                          icon: Icons.play_arrow_rounded,
                          color: TxaTheme.accent,
                          onTap: () => _playMovie(context, currentMovie),
                        ),
                        const SizedBox(width: 12),
                        Builder(
                          builder: (ctx) {
                            final int? mId = currentMovie['id'];
                            final isFav =
                                (mId != null &&
                                    TxaSettings.authToken.isNotEmpty)
                                ? ctx.select<FavoriteProvider, bool>(
                                    (p) => p.isFavorite(mId),
                                  )
                                : (currentMovie['is_favorite'] == true);

                            return _HeroActionButton(
                              label: isFav
                                  ? TxaLanguage.t('favorite_added')
                                  : TxaLanguage.t('add_favorite'),
                              icon: isFav
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isFav ? Colors.pinkAccent : Colors.white,
                              textColor: isFav ? Colors.white : Colors.black87,
                              onTap: () async {
                                final int? id = currentMovie['id'];
                                if (id == null) return;
                                if (TxaSettings.authToken.isEmpty) {
                                  TxaToast.show(
                                    context,
                                    TxaLanguage.t('login_required_favorites'),
                                  );
                                  return;
                                }
                                try {
                                  final favProvider =
                                      Provider.of<FavoriteProvider>(
                                        context,
                                        listen: false,
                                      );
                                  final success = await favProvider
                                      .toggleFavorite(id);

                                  if (context.mounted && success) {
                                    final newStatus = favProvider.isFavorite(
                                      id,
                                    );
                                    TxaToast.show(
                                      context,
                                      newStatus
                                          ? TxaLanguage.t('favorite_added')
                                          : TxaLanguage.t('favorite_removed'),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    TxaToast.show(
                                      context,
                                      TxaLanguage.t('error'),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      desc
                          .toString()
                          .replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '')
                          .trim(),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final dynamic movie;
  const _HeroCard({required this.movie});

  @override
  Widget build(BuildContext context) {
    final posterUrl = movie['thumb_url'] ?? movie['poster_url'] ?? '';
    final year = movie['year']?.toString() ?? '';
    final time =
        movie['time']?.toString() ?? movie['episode_current']?.toString() ?? '';
    final quality = movie['quality']?.toString() ?? '';

    // Multi-source score (TMDB vs IMDb)
    dynamic tmdbVote = movie['tmdb']?['vote_average'];
    dynamic imdbVote = movie['imdb']?['vote_average'];
    String vote = (tmdbVote ?? imdbVote ?? '0.0').toString();
    if (vote == '0') vote = '0.0';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => MovieDetailScreen(slug: movie['slug']),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(imageUrl: posterUrl, fit: BoxFit.cover),
            // Badges overlay
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (year.isNotEmpty) _HeroBadge(text: year),
                      if (time.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        _HeroBadge(text: time, icon: Icons.access_time_rounded),
                      ],
                    ],
                  ),
                  if (quality.isNotEmpty)
                    _HeroBadge(
                      text: quality,
                      color: const Color(0xFF10B981),
                    ), // Green for quality
                ],
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: _HeroBadge(
                text: 'IMDb $vote',
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;
  const _HeroBadge({required this.text, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: Colors.white),
            const SizedBox(width: 2),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _HeroActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.textColor = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovieSection extends StatelessWidget {
  final String title;
  final List movies;
  final String sectionKey;

  const _MovieSection({
    required this.title,
    required this.movies,
    required this.sectionKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: TxaTheme.textPrimary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) =>
                            CategoryListScreen(title: title, type: sectionKey),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        TxaLanguage.t('see_all'),
                        style: TextStyle(
                          fontSize: 12,
                          color: TxaTheme.accent.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: TxaTheme.accent.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Horizontal movie row
          SizedBox(
            height: 210,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: movies.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _MovieCard(
                    key: ValueKey('mov_${movies[index]['id']}'),
                    movie: movies[index],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MovieCard extends StatefulWidget {
  final dynamic movie;
  const _MovieCard({super.key, required this.movie});

  @override
  State<_MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<_MovieCard> {
  List<Map<String, String>> _getBadges() {
    final badges = <Map<String, String>>[];
    final type = widget.movie['type'] ?? '';
    if (type == 'series') badges.add({'text': 'PB', 'cls': 'type'});
    if (type == 'single') badges.add({'text': 'PL', 'cls': 'quality'});
    final epCurrent = widget.movie['episode_current']?.toString();
    if (epCurrent != null && epCurrent.isNotEmpty) {
      badges.add({'text': epCurrent, 'cls': 'episode'});
    }
    final quality = widget.movie['quality']?.toString();
    if (quality != null && quality.isNotEmpty) {
      badges.add({'text': quality, 'cls': 'quality'});
    }
    final lang = widget.movie['lang']?.toString();
    if (lang != null && lang.isNotEmpty) {
      badges.add({'text': lang == 'Vietsub' ? 'VS' : lang, 'cls': 'sub'});
    }
    return badges;
  }

  Future<void> _toggleFavorite() async {
    if (TxaSettings.authToken.isEmpty) {
      TxaToast.show(context, TxaLanguage.t('login_required_favorites'));
      return;
    }

    final int? id = widget.movie['id'];
    if (id == null) return;

    try {
      final favProvider = Provider.of<FavoriteProvider>(context, listen: false);
      final success = await favProvider.toggleFavorite(id);
      if (mounted && success) {
        final newStatus = favProvider.isFavorite(id);
        TxaToast.show(
          context,
          newStatus
              ? TxaLanguage.t('favorite_added')
              : TxaLanguage.t('favorite_removed'),
        );
      }
    } catch (e) {
      if (mounted) {
        TxaToast.show(context, "${TxaLanguage.t('error')}: $e", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int? mId = widget.movie['id'];
    final bool isFav = (mId != null && TxaSettings.authToken.isNotEmpty)
        ? context.select<FavoriteProvider, bool>((p) => p.isFavorite(mId))
        : (widget.movie['is_favorite'] == true);

    final name = widget.movie['name'] ?? 'Không rõ';
    final originName = widget.movie['origin_name'] ?? '';
    final posterUrl =
        widget.movie['thumb_url'] ?? widget.movie['poster_url'] ?? '';
    final badges = _getBadges();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => MovieDetailScreen(slug: widget.movie['slug'] ?? ''),
        ),
      ),
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TxaTheme.glassBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: posterUrl,
                      fit: BoxFit.cover,
                      placeholder: (ctx, url) =>
                          Container(color: TxaTheme.cardBg),
                      errorWidget: (ctx, url, err) => Container(
                        color: TxaTheme.cardBg,
                        child: Center(
                          child: Text(
                            name.substring(
                              0,
                              name.length > 3 ? 3 : name.length,
                            ),
                            style: const TextStyle(
                              color: TxaTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Badges
                    if (badges.isNotEmpty)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Wrap(
                          spacing: 3,
                          runSpacing: 3,
                          children: badges.take(3).map((b) {
                            Color bgColor;
                            switch (b['cls']) {
                              case 'type':
                                bgColor = TxaTheme.accent;
                                break;
                              case 'episode':
                                bgColor = TxaTheme.pink;
                                break;
                              case 'quality':
                                bgColor = const Color(0xFF10B981);
                                break;
                              case 'sub':
                                bgColor = const Color(0xFFF59E0B);
                                break;
                              default:
                                bgColor = TxaTheme.accent;
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                b['text']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    // Update time and Favorite Heart icon overlay
                    Positioned(
                      bottom: 5,
                      left: 6,
                      right: 6,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Favorite heart icon
                          GestureDetector(
                            onTap: _toggleFavorite,
                            child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              size: 16,
                              color: isFav
                                  ? Colors.red
                                  : Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          // Update timestamp (H:i:s d/M/yy)
                          if (widget.movie['updated_at'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                TxaFormat.formatDateTime(
                                  widget.movie['updated_at'].toString(),
                                ),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Name
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: TxaTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (originName.isNotEmpty)
              Text(
                originName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: TxaTheme.textMuted, fontSize: 9),
              ),
          ],
        ),
      ),
    );
  }
}
