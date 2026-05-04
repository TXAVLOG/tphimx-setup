import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tphimx_setup/utils/txa_toast.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_format.dart';

class LogEntry {
  final DateTime time;
  final String level;
  final String? tag;
  final String message;
  final Color color;
  final IconData icon;

  LogEntry({
    required this.time,
    required this.level,
    this.tag,
    required this.message,
    required this.color,
    required this.icon,
  });
}

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<LogEntry> _appLogs = [];
  List<LogEntry> _apiLogs = [];
  List<LogEntry> _downloadLogs = [];
  bool _loading = true;
  final ScrollController _appScroll = ScrollController();
  final ScrollController _apiScroll = ScrollController();
  final ScrollController _downloadScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _appScroll.dispose();
    _apiScroll.dispose();
    _downloadScroll.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final appRaw = await _readLogFile('app');
      final apiRaw = await _readLogFile('api');
      final downloadRaw = await _readLogFile('downloads');
      
      setState(() {
        _appLogs = _parseLogs(appRaw);
        _apiLogs = _parseApiLogs(apiRaw);
        _downloadLogs = _parseLogs(downloadRaw);
        _loading = false;
      });

      // Scroll to bottom after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_appScroll.hasClients) {
          _appScroll.jumpTo(_appScroll.position.maxScrollExtent);
        }
        if (_apiScroll.hasClients) {
          _apiScroll.jumpTo(_apiScroll.position.maxScrollExtent);
        }
        if (_downloadScroll.hasClients) {
          _downloadScroll.jumpTo(_downloadScroll.position.maxScrollExtent);
        }
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<LogEntry> _parseLogs(String raw) {
    final List<LogEntry> entries = [];
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
          final time = DateTime(now.year, now.month, now.day, 
            int.parse(timeParts[0]), int.parse(timeParts[1]), 
            int.parse(timeParts[2].split('.')[0]));
            
          entries.add(LogEntry(
            time: time,
            level: level,
            tag: tag,
            message: msg,
            color: color,
            icon: icon,
          ));
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
    final chunks = raw.split('─── API');
    
    for (var chunk in chunks) {
      if (chunk.trim().isEmpty) continue;
      
      final lines = chunk.split('\n');
      final headerLine = lines[0];
      final method = headerLine.split(' ')[1].replaceAll('─', '').trim();
      
      String url = '';
      String status = '';
      String? timeStr;
      
      for (var line in lines) {
        if (line.startsWith('URL:')) url = line.replaceFirst('URL:', '').trim();
        if (line.startsWith('STATUS:')) status = line.replaceFirst('STATUS:', '').trim();
        if (line.startsWith('TIME:')) timeStr = line.replaceFirst('TIME:', '').trim();
      }

      final isError = status.isNotEmpty && !status.startsWith('2');
      
      entries.add(LogEntry(
        time: DateTime.now(),
        level: method,
        tag: 'API',
        message: '$url\nStatus: $status | Time: $timeStr',
        color: isError ? Colors.redAccent : Colors.cyanAccent,
        icon: isError ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
      ));
    }
    return entries;
  }

  Future<String> _readLogFile(String type) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      String path = '${docDir.path}/Logs';
      if (Platform.isAndroid) {
        final premiumDir = Directory('/storage/emulated/0/TPHIMX/Logs');
        if (await premiumDir.exists()) path = premiumDir.path;
      }
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
      final docDir = await getApplicationDocumentsDirectory();
      String path = '${docDir.path}/Logs';
      if (Platform.isAndroid) {
        final premiumDir = Directory('/storage/emulated/0/TPHIMX/Logs');
        if (await premiumDir.exists()) path = premiumDir.path;
      }
      final dir = Directory(path);
      if (await dir.exists()) {
        for (var f in dir.listSync()) { if (f is File) await f.delete(); }
      }
      _loadLogs();
    } catch (_) {}
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxaTheme.cardBg,
        title: Text(TxaLanguage.t('clear_logs_confirm'), style: const TextStyle(color: Colors.white)),
        content: Text(TxaLanguage.t('clear_logs_msg'), style: const TextStyle(color: Colors.white70)),
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
            child: Text(TxaLanguage.t('clear'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareLogs() async {
    try {
      String type = 'app';
      if (_tabController.index == 1) type = 'api';
      if (_tabController.index == 2) type = 'downloads';
      final docDir = await getApplicationDocumentsDirectory();
      String path = '${docDir.path}/Logs';
      if (Platform.isAndroid) {
        final premiumDir = Directory('/storage/emulated/0/TPHIMX/Logs');
        if (await premiumDir.exists()) path = premiumDir.path;
      }
      final date = TxaFormat.formatDate(DateTime.now(), pattern: 'yyyy-MM-dd');
      final filePath = '$path/${type}_$date.log';
      final file = File(filePath);

      if (await file.exists()) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(filePath, name: '${type}_logs_$date.log')],
            subject: 'TPhimX ${type.toUpperCase()} Logs - $date',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      appBar: AppBar(
        backgroundColor: TxaTheme.primaryBg.withValues(alpha: 0.8),
        elevation: 0,
        title: Text(
          TxaLanguage.t('logs'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: TxaTheme.accent,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: 'APP (${_appLogs.length})'),
            Tab(text: 'API (${_apiLogs.length})'),
            Tab(text: 'DOWNLOADS (${_downloadLogs.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadLogs,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareLogs,
            tooltip: TxaLanguage.t('share_logs'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
            onPressed: _showClearDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: TxaTheme.accent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLogList(_appLogs, _appScroll),
                _buildLogList(_apiLogs, _apiScroll),
                _buildLogList(_downloadLogs, _downloadScroll),
              ],
            ),
    );
  }

  Widget _buildLogList(List<LogEntry> logs, ScrollController controller) {
    if (logs.isEmpty) {
      return Center(
        child: Text(
          TxaLanguage.t('no_logs_found'),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final entry = logs[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: entry.color, width: 3),
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(entry.icon, size: 14, color: entry.color),
                  const SizedBox(width: 8),
                  Text(
                    TxaFormat.formatDate(entry.time, pattern: 'HH:mm:ss.SSS'),
                    style: const TextStyle(color: TxaTheme.textMuted, fontSize: 10),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: entry.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      entry.level.trim(),
                      style: TextStyle(color: entry.color, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (entry.tag != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '#${entry.tag}',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              SelectableText(
                entry.message,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}
