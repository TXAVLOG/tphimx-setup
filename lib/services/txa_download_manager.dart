import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tphimx_setup/utils/txa_format.dart';
import '../utils/txa_logger.dart';
import 'txa_language.dart';

enum DownloadStatus { pending, downloading, paused, completed, error }

class DownloadTask {
  final String id;
  final String movieId;
  final String episodeId; // Added explicitly
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

  DownloadTask({
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

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
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
}

class TxaDownloadManager extends ChangeNotifier {
  static final TxaDownloadManager _instance = TxaDownloadManager._internal();
  factory TxaDownloadManager() => _instance;
  TxaDownloadManager._internal();

  final Dio _dio = Dio();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  List<DownloadTask> _tasks = [];
  List<DownloadTask> get tasks => _tasks;

  final int _maxConcurrent = 5;
  String _currentMovieDownloading = '';
  final Map<String, CancelToken> _cancelTokens = {};
  DateTime _lastSpeedCheck = DateTime.now();
  int _lastBytes = 0;
  String _currentSpeed = '0 KB/s';
  String get currentSpeed => _currentSpeed;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _initNotifications();
    await _loadTasks();
    _initialized = true;
    _processQueue();
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(
      settings: const InitializationSettings(android: android),
    );
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('txa_download_tasks');
    if (data != null) {
      final List<dynamic> list = jsonDecode(data);
      _tasks = list.map((e) => DownloadTask.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_tasks.map((e) => e.toJson()).toList());
    await prefs.setString('txa_download_tasks', data);
  }

  bool isTaskActive(String movieId, String episodeId) {
    return _tasks.any(
      (t) =>
          t.movieId == movieId &&
          t.episodeId == episodeId &&
          t.status != DownloadStatus.completed &&
          t.status != DownloadStatus.error,
    );
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
    final bool isDuplicate = _tasks.any((t) => t.id == taskId);
    if (isDuplicate) {
      TxaLogger.log(
        'Task already exists: $movieTitle - $episodeTitle',
        tag: 'DOWNLOAD',
        type: 'download',
      );
      return;
    }

    final isHls = url.contains('.m3u8');
    final task = DownloadTask(
      id: taskId,
      movieId: movieId,
      episodeId: episodeId,
      movieTitle: movieTitle,
      episodeTitle: episodeTitle,
      url: url,
      poster: poster,
      format: format,
      isHls: isHls,
    );

    _tasks.add(task);
    TxaLogger.log(
      'Added download task: $movieTitle - $episodeTitle',
      tag: 'DOWNLOAD',
      type: 'download',
    );
    await _saveTasks();
    _processQueue();
    notifyListeners();

    if (isHls) {
      _startDownloadTask(task);
    } else {
      _processQueue();
    }
  }

  void _processQueue() {
    if (_currentMovieDownloading.isEmpty) {
      try {
        final nextTask = _tasks.firstWhere(
          (t) =>
              t.status == DownloadStatus.pending ||
              t.status == DownloadStatus.paused,
        );
        _currentMovieDownloading = nextTask.movieId;
      } catch (_) {
        return;
      }
    }

    final activeCount = _tasks
        .where(
          (t) =>
              t.movieId == _currentMovieDownloading &&
              t.status == DownloadStatus.downloading,
        )
        .length;

    if (activeCount < _maxConcurrent) {
      final tasksToStart = _tasks
          .where(
            (t) =>
                t.movieId == _currentMovieDownloading &&
                (t.status == DownloadStatus.pending ||
                    t.status == DownloadStatus.paused),
          )
          .take(_maxConcurrent - activeCount)
          .toList();

      for (var task in tasksToStart) {
        _startDownloadTask(task);
      }
    }
  }

  Future<void> _startDownloadTask(DownloadTask task) async {
    task.status = DownloadStatus.downloading;
    notifyListeners();

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final safeMovieName = task.movieTitle.replaceAll(
        RegExp(r'[<>:"/\\|?*]'),
        '_',
      );
      final safeEpName = task.episodeTitle.replaceAll(
        RegExp(r'[<>:"/\\|?*]'),
        '_',
      );
      final dirPath = "${appDir.path}/movies/$safeMovieName/$safeEpName";
      await Directory(dirPath).create(recursive: true);

      final fileName = "txa_${task.id}.${task.format}";
      final filePath = "$dirPath/$fileName";
      task.savePath = filePath;

      TxaLogger.log(
        'Starting download: ${task.movieTitle} - ${task.episodeTitle}',
        tag: 'DOWNLOAD',
        type: 'download',
      );
      if (task.format == 'm3u8') {
        await _downloadM3U8(task);
      } else {
        await _downloadChunked(task);
      }

      task.status = DownloadStatus.completed;
      task.progress = 100.0;
      await _saveTasks();
      _checkMovieCompletion(task.movieId);
      _processQueue();
    } catch (e) {
      task.status = DownloadStatus.error;
      task.error = e.toString();
      _processQueue();
    }
    notifyListeners();
  }

  Future<void> _downloadChunked(DownloadTask task) async {
    final cancelToken = CancelToken();
    try {
      await _dio.download(
        task.url,
        task.savePath!,
        cancelToken: cancelToken,
        onReceiveProgress: (count, total) {
          if (task.status != DownloadStatus.downloading) {
            cancelToken.cancel("User paused or removed task");
            return;
          }
          if (total != -1) {
            task.downloadedBytes = count;
            task.totalBytes = total;
            task.progress = (count / total) * 100;

            // Update UI and Notifications less frequently but speed regularly
            _updateSpeed();
            if (count % (1024 * 512) == 0) {
              // Every 512KB
              _updateNotification(task);
              notifyListeners();
            }
          }
        },
      );
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        TxaLogger.log("Download cancelled/paused: ${task.id}");
      } else {
        rethrow;
      }
    }
  }

  Future<void> _downloadM3U8(DownloadTask task) async {
    await _downloadChunked(task);
  }

  void _checkMovieCompletion(String movieId) {
    final movieTasks = _tasks.where((t) => t.movieId == movieId).toList();
    final allDone = movieTasks.every(
      (t) => t.status == DownloadStatus.completed,
    );

    if (allDone && movieTasks.isNotEmpty) {
      _currentMovieDownloading = '';
      _showMovieDoneNotification(movieTasks.first.movieTitle);
    }
  }

  Future<void> _updateNotification(DownloadTask task) async {
    _updateSpeed();

    final movieTasks = _tasks.where((t) => t.movieId == task.movieId).toList();
    final done = movieTasks
        .where((t) => t.status == DownloadStatus.completed)
        .length;
    final total = movieTasks.length;

    String countInfo = "";
    if (total > 1) {
      countInfo =
          "${TxaLanguage.t('episodes_count').replaceAll('%c%', (done + 1).toString()).replaceAll('%t%', total.toString())} • ";
    }

    final android = AndroidNotificationDetails(
      'txa_downloads',
      TxaLanguage.t('download_channel_name'),
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: task.progress.toInt(),
      onlyAlertOnce: true,
      ongoing: true, // Keep it ongoing while downloading
    );

    String sizeInfo = "";
    if (task.totalBytes > 0) {
      sizeInfo = " (${TxaFormat.formatFileSize(task.downloadedBytes)} / ${TxaFormat.formatFileSize(task.totalBytes)})";
    }

    await _notifications.show(
      id: task.id.hashCode,
      title: task.movieTitle,
      body:
          "$countInfo${task.episodeTitle}: ${task.progress.toInt()}%$sizeInfo • $_currentSpeed",
      notificationDetails: NotificationDetails(android: android),
    );
  }

  void _updateSpeed() {
    final now = DateTime.now();
    final diff = now.difference(_lastSpeedCheck).inMilliseconds;
    if (diff >= 1000) {
      final activeTasks = _tasks
          .where((t) => t.status == DownloadStatus.downloading)
          .toList();
      int currentTotalBytes = 0;
      for (var t in activeTasks) {
        currentTotalBytes += t.downloadedBytes;
      }

      final bytesDiff = currentTotalBytes - _lastBytes;
      if (bytesDiff > 0) {
        final speed = (bytesDiff / (diff / 1000)); // bytes per second
        _currentSpeed = TxaFormat.formatNetworkSpeed(
          speed * 8,
        ); // TxaFormat expects bits/s
      } else {
        _currentSpeed = "0 KB/s";
      }

      _lastBytes = currentTotalBytes;
      _lastSpeedCheck = now;
    }
  }

  void _showMovieDoneNotification(String title) {
    final android = AndroidNotificationDetails(
      'txa_downloads_done',
      TxaLanguage.t('download_completed'),
      importance: Importance.high,
      priority: Priority.high,
    );
    _notifications.show(
      id: title.hashCode,
      title: TxaLanguage.t('download_completed'),
      body: "$title: ${TxaLanguage.t('download_all_completed')}",
      notificationDetails: NotificationDetails(android: android),
    );
  }

  void prioritizeMovie(String movieId) {
    for (var t in _tasks) {
      if (t.movieId == _currentMovieDownloading &&
          t.status == DownloadStatus.downloading) {
        t.status = DownloadStatus.paused;
      }
    }
    _currentMovieDownloading = movieId;
    _processQueue();
    notifyListeners();
  }

  Future<void> removeMovie(String movieId) async {
    final toRemove = _tasks.where((t) => t.movieId == movieId).toList();
    for (var task in toRemove) {
      if (task.savePath != null) {
        final file = File(task.savePath!);
        if (await file.exists()) await file.delete();
        final dir = file.parent;
        if (await dir.exists()) {
          final list = await dir.list().toList();
          if (list.isEmpty) await dir.delete();
        }
      }
      _tasks.remove(task);
    }
    await _saveTasks();
    if (_currentMovieDownloading == movieId) {
      _currentMovieDownloading = '';
    }
    _processQueue();
    notifyListeners();
  }

  Future<void> removeTask(String taskId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;

    final task = _tasks[idx];
    if (task.savePath != null) {
      final file = File(task.savePath!);
      if (await file.exists()) await file.delete();
      // If HLS, delete the whole folder
      if (task.isHls) {
        final dir = file.parent;
        if (await dir.exists()) await dir.delete(recursive: true);
      }
    }
    _tasks.removeAt(idx);
    await _saveTasks();
    _processQueue();
    notifyListeners();
  }

  void pauseTask(String taskId) {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    if (task.status == DownloadStatus.downloading) {
      task.status = DownloadStatus.paused;
      _cancelTokens[taskId]?.cancel("User paused");
      _cancelTokens.remove(taskId);
      notifyListeners();
      _saveTasks();
    }
  }

  void priorityTask(String taskId) {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;

    final task = _tasks.removeAt(idx);
    _tasks.insert(0, task); // Move to front

    if (task.status == DownloadStatus.paused ||
        task.status == DownloadStatus.error) {
      task.status = DownloadStatus.pending;
    }

    // Stop current downloading if different
    for (var t in _tasks) {
      if (t.id != taskId && t.status == DownloadStatus.downloading) {
        pauseTask(t.id);
        t.status = DownloadStatus.pending; // Back to queue
      }
    }

    _processQueue();
    notifyListeners();
    _saveTasks();
  }

  void resumeTask(String taskId) {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    if (task.status == DownloadStatus.paused ||
        task.status == DownloadStatus.error) {
      task.status = DownloadStatus.pending;
      _processQueue();
      notifyListeners();
      _saveTasks();
    }
  }
}
