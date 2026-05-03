import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:background_downloader_hls/background_downloader_hls.dart';
import '../utils/txa_format.dart';
import '../services/txa_language.dart';

enum DownloadStatus { pending, downloading, paused, completed, error }

class TxaDownloadTask {
  final String id;
  final String movieId;
  final String episodeId;
  final String movieTitle;
  final String episodeTitle;
  final String url;
  final String poster;
  final String format; // mp4 or m3u8
  DownloadStatus status;
  double progress;
  int downloadedBytes;
  int totalBytes;
  String? savePath;
  String? error;
  DateTime createdAt;
  bool isHls;
  int totalSegments;
  int downloadedSegments;
  double networkSpeed; // bytes per second
  Duration? timeRemaining;

  TxaDownloadTask({
    required this.id,
    required this.movieId,
    required this.episodeId,
    required this.movieTitle,
    required this.episodeTitle,
    required this.url,
    required this.poster,
    required this.format,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.savePath,
    this.error,
    DateTime? createdAt,
    this.isHls = false,
    this.totalSegments = 0,
    this.downloadedSegments = 0,
    this.networkSpeed = 0,
    this.timeRemaining,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'movieId': movieId,
    'episodeId': episodeId,
    'movieTitle': movieTitle,
    'episodeTitle': episodeTitle,
    'url': url,
    'poster': poster,
    'format': format,
    'status': status.index,
    'progress': progress,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    'savePath': savePath,
    'error': error,
    'createdAt': createdAt.toIso8601String(),
    'isHls': isHls,
    'totalSegments': totalSegments,
    'downloadedSegments': downloadedSegments,
  };

  factory TxaDownloadTask.fromJson(Map<String, dynamic> json) => TxaDownloadTask(
    id: json['id'],
    movieId: json['movieId'],
    episodeId: json['episodeId'] ?? '',
    movieTitle: json['movieTitle'],
    episodeTitle: json['episodeTitle'],
    url: json['url'],
    poster: json['poster'],
    format: json['format'],
    status: DownloadStatus.values[json['status']],
    progress: json['progress'],
    downloadedBytes: json['downloadedBytes'],
    totalBytes: json['totalBytes'],
    savePath: json['savePath'],
    error: json['error'],
    createdAt: DateTime.parse(json['createdAt']),
    isHls: json['isHls'] ?? false,
    totalSegments: json['totalSegments'] ?? 0,
    downloadedSegments: json['downloadedSegments'] ?? 0,
  );

  String get statusDisplay {
    if (status == DownloadStatus.completed) return TxaLanguage.t('downloaded');
    if (status == DownloadStatus.paused) return TxaLanguage.t('paused');
    if (status == DownloadStatus.error) return TxaLanguage.t('download_error', replace: {'msg': error ?? ''});
    if (status == DownloadStatus.pending) return TxaLanguage.t('pending');
    
    if (status == DownloadStatus.downloading) {
      if (isHls && downloadedSegments > 0) {
        return TxaLanguage.t('download_downloading_segments', replace: {
          'c': downloadedSegments.toString(),
          't': totalSegments.toString(),
        });
      }
      
      final speedStr = TxaFormat.formatSpeed(networkSpeed)['display'];
      final etaStr = timeRemaining != null ? TxaFormat.formatTime(timeRemaining!.inSeconds) : '--:--';
      
      return TxaLanguage.t('downloading_status', replace: {
        'p': (progress * 100).toStringAsFixed(0),
        's': speedStr,
        'e': etaStr,
      });
    }
    
    return '';
  }
}

class TxaDownloadManager extends ChangeNotifier {
  static final TxaDownloadManager _instance = TxaDownloadManager._internal();
  factory TxaDownloadManager() => _instance;
  TxaDownloadManager._internal();

  List<TxaDownloadTask> _tasks = [];
  List<TxaDownloadTask> get tasks => _tasks;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    
    // Configure background_downloader
    await FileDownloader().configure(
      globalConfig: [
        (Config.requestTimeout, const Duration(seconds: 30)),
      ],
    );

    // Listen for updates
    FileDownloader().updates.listen(_handleUpdate);

    await _loadTasks();
    _initialized = true;
    _checkRunningTasks();
  }

  void _handleUpdate(TaskUpdate update) {
    final txaTaskIndex = _tasks.indexWhere((t) => t.id == update.task.taskId);
    if (txaTaskIndex == -1) return;

    final txaTask = _tasks[txaTaskIndex];

    if (update is TaskStatusUpdate) {
        switch (update.status) {
          case TaskStatus.enqueued:
            txaTask.status = DownloadStatus.pending;
            break;
          case TaskStatus.running:
            txaTask.status = DownloadStatus.downloading;
            break;
          case TaskStatus.complete:
            txaTask.status = DownloadStatus.completed;
            txaTask.progress = 1.0;
            break;
          case TaskStatus.failed:
            txaTask.status = DownloadStatus.error;
            txaTask.error = 'Download failed';
            break;
          case TaskStatus.canceled:
            txaTask.status = DownloadStatus.error;
            txaTask.error = 'Download canceled';
            break;
          case TaskStatus.paused:
            txaTask.status = DownloadStatus.paused;
            break;
          default:
            break;
        }
    } else if (update is TaskProgressUpdate) {
      txaTask.progress = update.progress;
      txaTask.networkSpeed = update.networkSpeed;
      txaTask.timeRemaining = update.timeRemaining;
    }

    notifyListeners();
    _saveTasks();
  }

  void _checkRunningTasks() async {
    for (var task in _tasks) {
      if (task.status == DownloadStatus.downloading || task.status == DownloadStatus.pending) {
        // The plugin maintains its own state across restarts
      }
    }
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('txa_download_tasks');
    if (data != null) {
      final List<dynamic> list = jsonDecode(data);
      _tasks = list.map((e) => TxaDownloadTask.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_tasks.map((e) => e.toJson()).toList());
    await prefs.setString('txa_download_tasks', data);
  }

  Future<void> addTask({
    required String movieId,
    required String episodeId,
    required String movieTitle,
    required String episodeTitle,
    required String url,
    required String poster,
    required String format,
  }) async {
    if (!_initialized) {
      await init();
    }
    final String taskId = "${movieId}_$episodeId";
    if (_tasks.any((t) => t.id == taskId)) return;

    final isHls = url.contains('.m3u8');
    
    Directory? baseDir;
    if (Platform.isAndroid) {
      baseDir = Directory('/storage/emulated/0/TPHIMX/Videos');
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      baseDir = Directory('${appDir.path}/TPHIMX/Videos');
    }
    
    final safeMovieName = movieTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final safeEpName = episodeTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final dirPath = "${baseDir.path}/$safeMovieName/$safeEpName";
    await Directory(dirPath).create(recursive: true);

    final ext = isHls ? 'mp4' : format;
    final fileName = "txa_$taskId.$ext";
    final filePath = "$dirPath/$fileName";

    final txaTask = TxaDownloadTask(
      id: taskId,
      movieId: movieId,
      episodeId: episodeId,
      movieTitle: movieTitle,
      episodeTitle: episodeTitle,
      url: url,
      poster: poster,
      format: format,
      isHls: isHls,
      savePath: filePath,
      status: DownloadStatus.pending,
    );

    _tasks.add(txaTask);
    await _saveTasks();
    
    // Enqueue via plugin
    final task = DownloadTask(
      url: url,
      taskId: taskId,
      filename: fileName,
      directory: dirPath,
      updates: Updates.statusAndProgress,
      allowPause: true,
    );
    await FileDownloader().enqueue(task);
  }

  Future<void> pauseTask(String taskId) async {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    task.status = DownloadStatus.paused;
    final pluginTask = await FileDownloader().taskForId(taskId);
    if (pluginTask is DownloadTask) {
      await FileDownloader().pause(pluginTask);
    }
    notifyListeners();
    await _saveTasks();
  }

  Future<void> resumeTask(String taskId) async {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    task.status = DownloadStatus.downloading;
    final pluginTask = await FileDownloader().taskForId(taskId);
    if (pluginTask is DownloadTask) {
      await FileDownloader().resume(pluginTask);
    }
    notifyListeners();
    await _saveTasks();
  }

  Future<void> removeTask(String taskId) async {
    final pluginTask = await FileDownloader().taskForId(taskId);
    if (pluginTask != null) {
      await FileDownloader().cancelTasksWithIds([taskId]);
    }
    
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      final txaTask = _tasks[idx];
      if (txaTask.savePath != null) {
        final file = File(txaTask.savePath!);
        if (await file.exists()) await file.delete();
      }
      _tasks.removeAt(idx);
      await _saveTasks();
      notifyListeners();
    }
  }

  Future<void> removeMovie(String movieId) async {
    final tasksToRemove = _tasks.where((t) => t.movieId == movieId).toList();
    for (var t in tasksToRemove) {
      await removeTask(t.id);
    }
  }

  void prioritizeMovie(String movieId) {
    // Stub for compatibility - background_downloader handles queue internally
  }

  bool isTaskActive(String movieId, String episodeId) {
    final taskId = "${movieId}_$episodeId";
    return _tasks.any((t) => t.id == taskId && 
        (t.status == DownloadStatus.downloading || t.status == DownloadStatus.pending));
  }
}
