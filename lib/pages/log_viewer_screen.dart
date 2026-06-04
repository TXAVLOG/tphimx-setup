import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tphimx_setup/utils/txa_toast.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_format.dart';
import '../utils/txa_logger.dart';

class LogEntry {
  final DateTime time;
  final String level;
  final String? tag;
  final String message;
  final Color color;
  final IconData icon;

  // Parsed API details (optional)
  final String? apiMethod;
  final String? apiUrl;
  final String? apiStatus;
  final String? apiTime;
  final String? apiRequest;
  final String? apiResponse;

  LogEntry({
    required this.time,
    required this.level,
    this.tag,
    required this.message,
    required this.color,
    required this.icon,
    this.apiMethod,
    this.apiUrl,
    this.apiStatus,
    this.apiTime,
    this.apiRequest,
    this.apiResponse,
  });
}

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<LogEntry> _appLogs = [];
  List<LogEntry> _apiLogs = [];
  List<LogEntry> _downloadLogs = [];
  List<LogEntry> _searchLogs = [];
  bool _loading = true;

  final ScrollController _appScroll = ScrollController();
  final ScrollController _apiScroll = ScrollController();
  final ScrollController _downloadScroll = ScrollController();
  final ScrollController _searchScroll = ScrollController();

  // Search & Filtering State
  String _searchApp = '';
  String _searchApi = '';
  String _searchDownload = '';
  String _searchSearch = '';

  String _filterApp = 'ALL';
  String _filterApi = 'ALL';
  String _filterDownload = 'ALL';
  final String _filterSearch = 'ALL';

  // Toggle Auto Scroll state
  bool _autoScrollApp = true;
  bool _autoScrollApi = true;
  bool _autoScrollDownload = true;
  bool _autoScrollSearch = true;

  // Track Expanded Log Indices
  final Set<int> _expandedApp = {};
  final Set<int> _expandedApi = {};
  final Set<int> _expandedDownload = {};
  final Set<int> _expandedSearch = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadLogs();

    // Setup listener to toggle FAB show/hide depending on scroll pos
    _appScroll.addListener(() => _checkScrollPos('app'));
    _apiScroll.addListener(() => _checkScrollPos('api'));
    _downloadScroll.addListener(() => _checkScrollPos('downloads'));
    _searchScroll.addListener(() => _checkScrollPos('search'));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _appScroll.dispose();
    _apiScroll.dispose();
    _downloadScroll.dispose();
    _searchScroll.dispose();
    super.dispose();
  }

  void _checkScrollPos(String type) {
    if (mounted) setState(() {});
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final appRaw = await _readLogFile('app');
      final apiRaw = await _readLogFile('api');
      final downloadRaw = await _readLogFile('downloads');
      final searchRaw = await _readLogFile('search');

      List<LogEntry> parsedApp = [];
      List<LogEntry> parsedApi = [];
      List<LogEntry> parsedDownloads = [];
      List<LogEntry> parsedSearch = [];

      try {
        parsedApp = _parseLogs(appRaw);
      } catch (e) {
        debugPrint('Error parsing APP logs: $e');
      }

      try {
        parsedApi = _parseApiLogs(apiRaw);
      } catch (e) {
        debugPrint('Error parsing API logs: $e');
      }

      try {
        parsedDownloads = _parseLogs(downloadRaw);
      } catch (e) {
        debugPrint('Error parsing DOWNLOADS logs: $e');
      }

      try {
        parsedSearch = _parseLogs(searchRaw);
      } catch (e) {
        debugPrint('Error parsing SEARCH logs: $e');
      }

      setState(() {
        _appLogs = parsedApp;
        _apiLogs = parsedApi;
        _downloadLogs = parsedDownloads;
        _searchLogs = parsedSearch;
        _loading = false;

        // Reset expanded cards on reload
        _expandedApp.clear();
        _expandedApi.clear();
        _expandedDownload.clear();
        _expandedSearch.clear();
      });

      // Scroll to bottom after build if autoScroll is enabled
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_autoScrollApp && _appScroll.hasClients) {
          _appScroll.jumpTo(_appScroll.position.maxScrollExtent);
        }
        if (_autoScrollApi && _apiScroll.hasClients) {
          _apiScroll.jumpTo(_apiScroll.position.maxScrollExtent);
        }
        if (_autoScrollSearch && _searchScroll.hasClients) {
          _searchScroll.jumpTo(_searchScroll.position.maxScrollExtent);
        }
        if (_autoScrollDownload && _downloadScroll.hasClients) {
          _downloadScroll.jumpTo(_downloadScroll.position.maxScrollExtent);
        }
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<LogEntry> _parseLogs(String raw) {
    final List<LogEntry> entries = [];
    if (raw.trim().isEmpty) return entries;

    final lines = raw.split('\n');
    final regExp = RegExp(r'^\[([\d:.]+)\] \[(\w+)\s*\] (?:\[(\w+)\] )?(.*)$');

    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      final match = regExp.firstMatch(line);
      if (match != null) {
        final timeStr = match.group(1)!;
        final level = match.group(2)!;
        final tag = match.group(3);
        final msg = match.group(4)!;

        Color color = Colors.white70;
        IconData icon = Icons.info_outline_rounded;

        if (level.contains('ERROR')) {
          color = Colors.redAccent;
          icon = Icons.error_outline_rounded;
        } else if (level.contains('WARN')) {
          color = Colors.orangeAccent;
          icon = Icons.warning_amber_rounded;
        } else if (msg.toLowerCase().contains('success')) {
          color = Colors.greenAccent;
          icon = Icons.check_circle_outline_rounded;
        } else if (tag == 'LOGGER') {
          color = TxaTheme.accent;
          icon = Icons.settings_suggest_rounded;
        } else if (tag == 'START' || tag == 'SUCCESS') {
          color = Colors.greenAccent;
          icon = Icons.file_download_done_rounded;
        } else if (tag == 'ERROR' || tag == 'CANCEL') {
          color = Colors.redAccent;
          icon = Icons.report_gmailerrorred_rounded;
        }

        try {
          final now = DateTime.now();
          final timeParts = timeStr.split(':');
          final time = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
            int.parse(timeParts[2].split('.')[0]),
          );

          entries.add(
            LogEntry(
              time: time,
              level: level.trim(),
              tag: tag,
              message: msg,
              color: color,
              icon: icon,
            ),
          );
        } catch (_) {}
      } else {
        // Handle multi-line messages (stack traces)
        if (entries.isNotEmpty) {
          final last = entries.last;
          entries[entries.length - 1] = LogEntry(
            time: last.time,
            level: last.level,
            tag: last.tag,
            message: '${last.message}\n$line',
            color: last.color,
            icon: last.icon,
          );
        }
      }
    }
    return entries;
  }

  List<LogEntry> _parseApiLogs(String raw) {
    final List<LogEntry> entries = [];
    if (raw.trim().isEmpty) return entries;

    final lines = raw.split('\n');
    final regExp = RegExp(r'^\[([\d:.]+)\] \[(\w+)\s*\] (?:\[(\w+)\] )?(.*)$');

    LogEntry? currentEntry;
    List<String> currentDetails = [];

    for (var line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      final match = regExp.firstMatch(line);
      if (match != null) {
        final timeStr = match.group(1)!;
        final msg = match.group(4)!;

        // Detect a new API Header block
        if (msg.contains('─── API')) {
          if (currentEntry != null) {
            entries.add(_finalizeApiEntry(currentEntry, currentDetails));
          }

          final methodMatch = RegExp(r'─── API (\w+)').firstMatch(msg);
          final method = methodMatch != null ? methodMatch.group(1)! : 'API';

          try {
            final now = DateTime.now();
            final timeParts = timeStr.split(':');
            final time = DateTime(
              now.year,
              now.month,
              now.day,
              int.parse(timeParts[0]),
              int.parse(timeParts[1]),
              int.parse(timeParts[2].split('.')[0]),
            );

            currentEntry = LogEntry(
              time: time,
              level: method,
              tag: 'API',
              message: '',
              color: Colors.cyanAccent,
              icon: Icons.cloud_done_rounded,
              apiMethod: method,
            );
            currentDetails = [];
          } catch (_) {
            currentEntry = null;
          }
        } else {
          // Accumulate detail line for active entry
          if (currentEntry != null) {
            currentDetails.add(line);
          }
        }
      } else {
        // Line doesn't match standard prefix (e.g. JSON multiline body)
        if (currentEntry != null) {
          currentDetails.add(line);
        }
      }
    }

    if (currentEntry != null) {
      entries.add(_finalizeApiEntry(currentEntry, currentDetails));
    }

    return entries;
  }

  LogEntry _finalizeApiEntry(LogEntry entry, List<String> details) {
    String url = '';
    String status = '';
    String? timeStr;

    bool inRequest = false;
    bool inResponse = false;
    List<String> bodyLines = [];
    List<String> respLines = [];

    for (var line in details) {
      final trimmed = line.trim();

      if (trimmed.startsWith('URL:')) {
        url = trimmed.replaceFirst('URL:', '').trim();
      } else if (trimmed.startsWith('STATUS:')) {
        status = trimmed.replaceFirst('STATUS:', '').trim();
      } else if (trimmed.startsWith('TIME:')) {
        timeStr = trimmed.replaceFirst('TIME:', '').trim();
      } else if (trimmed.startsWith('REQUEST BODY:')) {
        inRequest = true;
        inResponse = false;
        final content = trimmed.replaceFirst('REQUEST BODY:', '').trim();
        if (content.isNotEmpty) bodyLines.add(content);
      } else if (trimmed.startsWith('RESPONSE:')) {
        inRequest = false;
        inResponse = true;
        final content = trimmed.replaceFirst('RESPONSE:', '').trim();
        if (content.isNotEmpty) respLines.add(content);
      } else if (trimmed.startsWith(
        '──────────────────────────────────────────────',
      )) {
        inRequest = false;
        inResponse = false;
      } else {
        if (inRequest) {
          bodyLines.add(line);
        } else if (inResponse) {
          respLines.add(line);
        }
      }
    }

    final isError = status.isNotEmpty && !status.startsWith('2');
    final fullBody = bodyLines.join('\n').trim();
    final fullResp = respLines.join('\n').trim();

    // Format display text for search compatibility
    final buffer = StringBuffer();
    buffer.writeln('${entry.apiMethod} $url');
    buffer.write('Status: $status');
    if (timeStr != null) buffer.write(' | Time: $timeStr');
    if (fullBody.isNotEmpty) buffer.write('\nRequest: $fullBody');
    if (fullResp.isNotEmpty) buffer.write('\nResponse: $fullResp');

    return LogEntry(
      time: entry.time,
      level: entry.level,
      tag: entry.tag,
      message: buffer.toString(),
      color: isError ? Colors.redAccent : Colors.cyanAccent,
      icon: isError ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
      apiMethod: entry.apiMethod,
      apiUrl: url,
      apiStatus: status,
      apiTime: timeStr,
      apiRequest: fullBody,
      apiResponse: fullResp,
    );
  }

  Future<String> _readLogFile(String type) async {
    try {
      final path = await TxaLogger.getActiveLogPath();
      final date = TxaFormat.formatDate(DateTime.now(), pattern: 'yyyy-MM-dd');
      final file = File('$path/${type}_$date.log');
      if (await file.exists()) return await file.readAsString();
      return '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _clearLogs() async {
    try {
      final path = await TxaLogger.getActiveLogPath();
      final dir = Directory(path);
      if (await dir.exists()) {
        for (var f in dir.listSync()) {
          if (f is File) await f.delete();
        }
      }
      _loadLogs();
    } catch (_) {}
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxaTheme.cardBg,
        title: Text(
          TxaLanguage.t('clear_logs_confirm'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          TxaLanguage.t('clear_logs_msg'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(TxaLanguage.t('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearLogs();
            },
            child: Text(
              TxaLanguage.t('clear'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareLogs() async {
    try {
      String type = 'app';
      if (_tabController.index == 1) type = 'api';
      if (_tabController.index == 2) type = 'search';
      if (_tabController.index == 3) type = 'downloads';
      final path = await TxaLogger.getActiveLogPath();
      final date = TxaFormat.formatDate(DateTime.now(), pattern: 'yyyy-MM-dd');
      final filePath = '$path/${type}_$date.log';
      final file = File(filePath);

      if (await file.exists()) {
        final rawContent = await file.readAsString();

        // Fetch detailed device specs and IP geolocation
        final deviceInfo = await TxaLogger.getDeviceInfo();
        final locationInfo = await TxaLogger.getIpLocation();

        final buffer = StringBuffer();
        buffer.writeln('===============================================');
        buffer.writeln('          TPHIMX APP DIAGNOSTIC LOG          ');
        buffer.writeln('===============================================');
        buffer.writeln('DATE: $date');
        buffer.writeln('LOG TYPE: ${type.toUpperCase()}');
        buffer.writeln('-----------------------------------------------');
        buffer.writeln('DEVICE INFORMATION:');
        buffer.writeln('  Platform: ${deviceInfo['platform'] ?? 'Unknown'}');
        buffer.writeln(
          '  Device Name: ${deviceInfo['device_name'] ?? 'Unknown'}',
        );
        buffer.writeln(
          '  Device Model: ${deviceInfo['device_model'] ?? 'Unknown'}',
        );
        buffer.writeln(
          '  OS Version: ${deviceInfo['system_version'] ?? 'Unknown'}',
        );
        buffer.writeln('  Device UDID: ${deviceInfo['udid'] ?? 'Unknown'}');
        buffer.writeln('-----------------------------------------------');
        buffer.writeln('NETWORK / LOCATION:');
        buffer.writeln('  IP Address: ${locationInfo['ip'] ?? 'Unknown'}');
        buffer.writeln(
          '  Location: ${locationInfo['city'] ?? 'Unknown'}, ${locationInfo['region'] ?? 'Unknown'}, ${locationInfo['country'] ?? 'Unknown'}',
        );
        buffer.writeln('===============================================');
        buffer.writeln();
        buffer.writeln(rawContent);

        // Create temporary diagnostic log file to share
        final tempDir = await Directory.systemTemp.createTemp();
        final tempFile = File(
          '${tempDir.path}/${type}_logs_diagnostics_$date.log',
        );
        await tempFile.writeAsString(buffer.toString());

        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile(tempFile.path, name: '${type}_logs_diagnostics_$date.log'),
            ],
            subject:
                'TPhimX ${type.toUpperCase()} Logs with Diagnostics - $date',
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(TxaLanguage.t('no_logs_found'))),
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to share logs: $e');
      if (mounted) {
        TxaToast.show(context, 'Lỗi chia sẻ: $e', isError: true);
      }
    }
  }

  List<LogEntry> _getFilteredLogs(
    List<LogEntry> logs,
    String query,
    String levelFilter,
  ) {
    return logs.where((entry) {
      // 1. Level Filter
      if (levelFilter != 'ALL') {
        final isErr =
            entry.level.contains('ERROR') || entry.color == Colors.redAccent;
        final isWarn = entry.level.contains('WARN') || entry.level == 'WARN';

        if (levelFilter == 'ERROR' && !isErr) return false;
        if (levelFilter == 'WARN' && !isWarn) return false;
        if (levelFilter == 'INFO' && (isErr || isWarn)) return false;
      }

      // 2. Search query filter
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        final msg = entry.message.toLowerCase();
        final level = entry.level.toLowerCase();
        final tag = (entry.tag ?? '').toLowerCase();
        return msg.contains(q) || level.contains(q) || tag.contains(q);
      }

      return true;
    }).toList();
  }

  // Visual metrics calculation
  int _getErrorCount(List<LogEntry> logs) => logs
      .where((l) => l.level.contains('ERROR') || l.color == Colors.redAccent)
      .length;
  int _getWarnCount(List<LogEntry> logs) =>
      logs.where((l) => l.level.contains('WARN') || l.level == 'WARN').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      appBar: AppBar(
        backgroundColor: TxaTheme.primaryBg.withValues(alpha: 0.8),
        elevation: 0,
        title: Text(
          TxaLanguage.t('logs'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.8,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: TxaTheme.accent,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: [
            Tab(text: 'APP (${_appLogs.length})'),
            Tab(text: 'API (${_apiLogs.length})'),
            Tab(text: 'SEARCH (${_searchLogs.length})'),
            Tab(text: 'DOWNLOADS (${_downloadLogs.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _loadLogs,
            tooltip: 'Làm mới',
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 20),
            onPressed: _shareLogs,
            tooltip: TxaLanguage.t('share_logs'),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_sweep_rounded,
              color: Colors.redAccent,
              size: 22,
            ),
            onPressed: _showClearDialog,
            tooltip: 'Xóa toàn bộ',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: TxaTheme.accent),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLogTab('app', _appLogs, _appScroll),
                _buildLogTab('api', _apiLogs, _apiScroll),
                _buildLogTab('search', _searchLogs, _searchScroll),
                _buildLogTab('downloads', _downloadLogs, _downloadScroll),
              ],
            ),
    );
  }

  Widget _buildLogTab(
    String type,
    List<LogEntry> rawLogs,
    ScrollController scrollController,
  ) {
    // 1. Get search and filter state
    String query = '';
    String filter = 'ALL';
    bool autoScroll = true;
    Set<int> expanded = {};

    if (type == 'app') {
      query = _searchApp;
      filter = _filterApp;
      autoScroll = _autoScrollApp;
      expanded = _expandedApp;
    } else if (type == 'api') {
      query = _searchApi;
      filter = _filterApi;
      autoScroll = _autoScrollApi;
      expanded = _expandedApi;
    } else if (type == 'search') {
      query = _searchSearch;
      filter = _filterSearch;
      autoScroll = _autoScrollSearch;
      expanded = _expandedSearch;
    } else {
      query = _searchDownload;
      filter = _filterDownload;
      autoScroll = _autoScrollDownload;
      expanded = _expandedDownload;
    }

    final filtered = _getFilteredLogs(rawLogs, query, filter);

    // Dynamic show FAB if user has scrolled up
    final showFab =
        scrollController.hasClients &&
        scrollController.position.pixels <
            scrollController.position.maxScrollExtent - 200;

    return Stack(
      children: [
        Column(
          children: [
            // Statistics Dashboard Metric Box
            _buildStatsDashboard(rawLogs),

            // Search and level filter chips
            _buildFilterBar(type, query, filter, autoScroll),

            // Logs render area
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.feed_outlined,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            TxaLanguage.t('no_logs_found'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.only(
                        left: 12,
                        right: 12,
                        top: 4,
                        bottom: 80,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return _buildLogCard(
                          index,
                          filtered[index],
                          expanded,
                          query,
                          type,
                        );
                      },
                    ),
            ),
          ],
        ),

        // Smart Floating FAB for auto-scroll
        if (showFab)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              backgroundColor: TxaTheme.accent.withValues(alpha: 0.9),
              foregroundColor: Colors.white,
              onPressed: () {
                setState(() {
                  if (type == 'app') _autoScrollApp = true;
                  if (type == 'api') _autoScrollApi = true;
                  if (type == 'downloads') _autoScrollDownload = true;
                });
                scrollController.animateTo(
                  scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              child: const Icon(Icons.arrow_downward_rounded),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsDashboard(List<LogEntry> logs) {
    final total = logs.length;
    final errors = _getErrorCount(logs);
    final warnings = _getWarnCount(logs);
    final infos = total - errors - warnings;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildStatCard(
            'Tổng',
            total.toString(),
            Colors.blueAccent,
            Icons.assessment_outlined,
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            'Lỗi',
            errors.toString(),
            Colors.redAccent,
            Icons.error_outline_rounded,
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            'Cảnh báo',
            warnings.toString(),
            Colors.orangeAccent,
            Icons.warning_amber_rounded,
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            'Thông tin',
            infos.toString(),
            Colors.greenAccent,
            Icons.info_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: TxaTheme.cardBg.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color.withValues(alpha: 0.7), size: 13),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: TxaTheme.textMuted, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(
    String type,
    String query,
    String filter,
    bool autoScroll,
  ) {
    final searchController = TextEditingController(text: query);
    searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: searchController.text.length),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          // Glassmorphic Search input bar
          Row(
            children: [
              Expanded(
                child: TxaTheme.glassConnector(
                  radius: 10,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm nội dung logs...',
                      hintStyle: const TextStyle(
                        color: Colors.white30,
                        fontSize: 12,
                      ),
                      border: InputBorder.none,
                      icon: const Icon(
                        Icons.search_rounded,
                        color: TxaTheme.textMuted,
                        size: 16,
                      ),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: TxaTheme.textMuted,
                                size: 14,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (type == 'app') _searchApp = '';
                                  if (type == 'api') _searchApi = '';
                                  if (type == 'search') _searchSearch = '';
                                  if (type == 'downloads') _searchDownload = '';
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) {
                      setState(() {
                        if (type == 'app') _searchApp = val;
                        if (type == 'api') _searchApi = val;
                        if (type == 'search') _searchSearch = val;
                        if (type == 'downloads') _searchDownload = val;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Auto scroll lock toggle button
              InkWell(
                onTap: () {
                  setState(() {
                    if (type == 'app') _autoScrollApp = !_autoScrollApp;
                    if (type == 'api') _autoScrollApi = !_autoScrollApi;
                    if (type == 'search') {
                      _autoScrollSearch = !_autoScrollSearch;
                    }
                    if (type == 'downloads') {
                      _autoScrollDownload = !_autoScrollDownload;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: autoScroll
                        ? TxaTheme.accent.withValues(alpha: 0.15)
                        : TxaTheme.cardBg.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: autoScroll
                          ? TxaTheme.accent.withValues(alpha: 0.3)
                          : Colors.white10,
                    ),
                  ),
                  child: Icon(
                    autoScroll
                        ? Icons.vertical_align_bottom_rounded
                        : Icons.vertical_align_center_rounded,
                    color: autoScroll ? TxaTheme.accent : TxaTheme.textMuted,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Horizontal Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(type, 'Tất cả', 'ALL', filter),
                const SizedBox(width: 6),
                _buildFilterChip(type, 'Thông tin', 'INFO', filter),
                const SizedBox(width: 6),
                _buildFilterChip(type, 'Cảnh báo', 'WARN', filter),
                const SizedBox(width: 6),
                _buildFilterChip(type, 'Lỗi', 'ERROR', filter),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 16),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String type,
    String label,
    String value,
    String currentValue,
  ) {
    final active = value == currentValue;
    Color chipColor = TxaTheme.textMuted;
    if (active) {
      if (value == 'ERROR') {
        chipColor = Colors.redAccent;
      } else if (value == 'WARN') {
        chipColor = Colors.orangeAccent;
      } else if (value == 'INFO') {
        chipColor = Colors.greenAccent;
      } else {
        chipColor = TxaTheme.accent;
      }
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (type == 'app') _filterApp = value;
          if (type == 'api') _filterApi = value;
          if (type == 'downloads') _filterDownload = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? chipColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? chipColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? chipColor : TxaTheme.textSecondary,
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLogCard(
    int index,
    LogEntry entry,
    Set<int> expandedSet,
    String query,
    String type,
  ) {
    final isExpanded = expandedSet.contains(index);
    final isApi = entry.apiUrl != null;

    // Glowing border styling
    final itemColor = entry.color;
    final cardBg = TxaTheme.cardBg.withValues(alpha: isExpanded ? 0.6 : 0.25);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isExpanded
              ? itemColor.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            // Head summary tile clickable
            InkWell(
              onTap: () {
                setState(() {
                  if (expandedSet.contains(index)) {
                    expandedSet.remove(index);
                  } else {
                    expandedSet.add(index);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Left colored stripe
                        Container(
                          width: 3,
                          height: 14,
                          decoration: BoxDecoration(
                            color: itemColor,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: itemColor.withValues(alpha: 0.4),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Icon
                        Icon(entry.icon, size: 13, color: itemColor),
                        const SizedBox(width: 6),

                        // Timestamp
                        Text(
                          TxaFormat.formatDate(
                            entry.time,
                            pattern: 'HH:mm:ss.SSS',
                          ),
                          style: const TextStyle(
                            color: TxaTheme.textMuted,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 8),

                        // API Method Badge or Tag Label
                        if (isApi)
                          _buildBadge(entry.apiMethod ?? 'API', itemColor)
                        else
                          _buildBadge(entry.level, itemColor),

                        if (entry.tag != null && !isApi) ...[
                          const SizedBox(width: 6),
                          Text(
                            '#${entry.tag}',
                            style: const TextStyle(
                              color: Colors.white30,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],

                        const Spacer(),

                        // Up/Down Chevron Icon
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: TxaTheme.textMuted,
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Summary title/message
                    Text(
                      isApi
                          ? entry.apiUrl ?? entry.message
                          : _getSingleLineSummary(entry.message),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),

                    if (isApi && entry.apiStatus != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            color: itemColor,
                            size: 11,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Status: ${entry.apiStatus}',
                            style: TextStyle(
                              color: itemColor.withValues(alpha: 0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (entry.apiTime != null) ...[
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.timer_outlined,
                              color: TxaTheme.textMuted,
                              size: 11,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              entry.apiTime!,
                              style: const TextStyle(
                                color: TxaTheme.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Expand details area
            if (isExpanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.03),
                    ),
                  ),
                ),
                child: isApi
                    ? _buildApiExpandedView(entry)
                    : _buildNormalExpandedView(entry),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Text(
        label.trim().toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _getSingleLineSummary(String msg) {
    final firstLine = msg.split('\n')[0];
    return firstLine.length > 120
        ? '${firstLine.substring(0, 120)}...'
        : firstLine;
  }

  Future<String> _generateNormalReport(LogEntry entry) async {
    final deviceInfo = await TxaLogger.getDeviceInfo();
    final locationInfo = await TxaLogger.getIpLocation();

    final buffer = StringBuffer();
    buffer.writeln('===============================================');
    buffer.writeln('          TPHIMX APP DIAGNOSTIC LOG          ');
    buffer.writeln('===============================================');
    buffer.writeln(
      'TIMESTAMP: ${TxaFormat.formatDate(entry.time, pattern: 'yyyy-MM-dd HH:mm:ss.SSS')}',
    );
    buffer.writeln('LOG LEVEL: ${entry.level.toUpperCase()}');
    if (entry.tag != null) buffer.writeln('TAG: [${entry.tag}]');
    buffer.writeln('-----------------------------------------------');
    buffer.writeln('DEVICE INFORMATION:');
    buffer.writeln('  Platform: ${deviceInfo['platform'] ?? 'Unknown'}');
    buffer.writeln('  Device Name: ${deviceInfo['device_name'] ?? 'Unknown'}');
    buffer.writeln(
      '  Device Model: ${deviceInfo['device_model'] ?? 'Unknown'}',
    );
    buffer.writeln(
      '  OS Version: ${deviceInfo['system_version'] ?? 'Unknown'}',
    );
    buffer.writeln('  Device UDID: ${deviceInfo['udid'] ?? 'Unknown'}');
    buffer.writeln('-----------------------------------------------');
    buffer.writeln('NETWORK / LOCATION:');
    buffer.writeln('  IP Address: ${locationInfo['ip'] ?? 'Unknown'}');
    buffer.writeln(
      '  Location: ${locationInfo['city'] ?? 'Unknown'}, ${locationInfo['region'] ?? 'Unknown'}, ${locationInfo['country'] ?? 'Unknown'}',
    );
    buffer.writeln('-----------------------------------------------');
    buffer.writeln('LOG MESSAGE:');
    buffer.writeln(entry.message);
    buffer.writeln('===============================================');
    return buffer.toString();
  }

  Future<String> _generateApiReport(LogEntry entry) async {
    final deviceInfo = await TxaLogger.getDeviceInfo();
    final locationInfo = await TxaLogger.getIpLocation();

    final buffer = StringBuffer();
    buffer.writeln('===============================================');
    buffer.writeln('      TPHIMX APP API DIAGNOSTIC LOG          ');
    buffer.writeln('===============================================');
    buffer.writeln(
      'TIMESTAMP: ${TxaFormat.formatDate(entry.time, pattern: 'yyyy-MM-dd HH:mm:ss.SSS')}',
    );
    buffer.writeln('METHOD: ${entry.apiMethod ?? 'Unknown'}');
    buffer.writeln('URL: ${entry.apiUrl ?? 'Unknown'}');
    buffer.writeln('STATUS: ${entry.apiStatus ?? 'Unknown'}');
    if (entry.apiTime != null) {
      buffer.writeln('RESPONSE TIME: ${entry.apiTime}');
    }
    buffer.writeln('-----------------------------------------------');
    buffer.writeln('DEVICE INFORMATION:');
    buffer.writeln('  Platform: ${deviceInfo['platform'] ?? 'Unknown'}');
    buffer.writeln('  Device Name: ${deviceInfo['device_name'] ?? 'Unknown'}');
    buffer.writeln(
      '  Device Model: ${deviceInfo['device_model'] ?? 'Unknown'}',
    );
    buffer.writeln(
      '  OS Version: ${deviceInfo['system_version'] ?? 'Unknown'}',
    );
    buffer.writeln('  Device UDID: ${deviceInfo['udid'] ?? 'Unknown'}');
    buffer.writeln('-----------------------------------------------');
    buffer.writeln('NETWORK / LOCATION:');
    buffer.writeln('  IP Address: ${locationInfo['ip'] ?? 'Unknown'}');
    buffer.writeln(
      '  Location: ${locationInfo['city'] ?? 'Unknown'}, ${locationInfo['region'] ?? 'Unknown'}, ${locationInfo['country'] ?? 'Unknown'}',
    );
    buffer.writeln('-----------------------------------------------');
    if (entry.apiRequest != null && entry.apiRequest!.isNotEmpty) {
      buffer.writeln('REQUEST BODY:');
      buffer.writeln(entry.apiRequest);
      buffer.writeln('-----------------------------------------------');
    }
    if (entry.apiResponse != null && entry.apiResponse!.isNotEmpty) {
      buffer.writeln('RESPONSE DATA:');
      buffer.writeln(entry.apiResponse);
      buffer.writeln('-----------------------------------------------');
    }
    buffer.writeln('FULL MSG:');
    buffer.writeln(entry.message);
    buffer.writeln('===============================================');
    return buffer.toString();
  }

  Widget _buildNormalExpandedView(LogEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Chi tiết logs:',
              style: TextStyle(
                color: TxaTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.copy_all_rounded,
                color: TxaTheme.textMuted,
                size: 14,
              ),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
              tooltip: 'Sao chép logs',
              onPressed: () async {
                final report = await _generateNormalReport(entry);
                await Clipboard.setData(ClipboardData(text: report));
                if (mounted) {
                  TxaToast.show(context, 'Đã sao chép logs chẩn đoán chi tiết');
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        SelectableText(
          entry.message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildApiExpandedView(LogEntry entry) {
    final statusColor = entry.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Headers & Action Copy Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Nội dung kết nối API:',
              style: TextStyle(
                color: TxaTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.copy_all_rounded,
                color: TxaTheme.textMuted,
                size: 14,
              ),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
              tooltip: 'Sao chép toàn bộ logs chẩn đoán',
              onPressed: () async {
                final report = await _generateApiReport(entry);
                await Clipboard.setData(ClipboardData(text: report));
                if (mounted) {
                  TxaToast.show(
                    context,
                    'Đã sao chép chi tiết logs API chẩn đoán',
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Method & URL box
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildBadge(entry.apiMethod ?? 'GET', statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      entry.apiUrl ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text(
                    'Status:',
                    style: TextStyle(color: TxaTheme.textMuted, fontSize: 10),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    entry.apiStatus ?? '?',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (entry.apiTime != null) ...[
                    const SizedBox(width: 16),
                    const Text(
                      'Thời gian phản hồi:',
                      style: TextStyle(color: TxaTheme.textMuted, fontSize: 10),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entry.apiTime!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Request Block
        if (entry.apiRequest != null && entry.apiRequest!.isNotEmpty) ...[
          _buildPayloadBox(
            'Dữ liệu gửi lên (Request Body)',
            entry.apiRequest!,
            Colors.orangeAccent,
          ),
          const SizedBox(height: 8),
        ],

        // Response Block
        if (entry.apiResponse != null && entry.apiResponse!.isNotEmpty)
          _buildPayloadBox(
            'Phản hồi từ server (Response Data)',
            entry.apiResponse!,
            Colors.greenAccent,
          ),
      ],
    );
  }

  Widget _buildPayloadBox(String label, String payload, Color themeColor) {
    // Try to prettify JSON
    String prettyJson = payload;
    try {
      final decoded = json.decode(payload);
      final encoder = const JsonEncoder.withIndent('  ');
      prettyJson = encoder.convert(decoded);
    } catch (_) {}

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: themeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: TxaTheme.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(maxHeight: 250),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              prettyJson,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
