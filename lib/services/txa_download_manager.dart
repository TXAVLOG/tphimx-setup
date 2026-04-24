import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/txa_logger.dart';
import 'txa_language.dart';

enum DownloadStatus { pending, downloading, paused, completed, error }

class DownloadTask {
  final String id;
  final String movieId;
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

  final int _maxConcurrent = 3;
  String _currentMovieDownloading = '';

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

  Future<void> addTask({
    required String movieId,
    required String movieTitle,
    required String episodeTitle,
    required String url,
    required String poster,
    required String format,
  }) async {
    final id = _generateTaskId("$movieId-$episodeTitle");
    if (_tasks.any((t) => t.id == id)) {
      TxaLogger.log("Task already exists: $id");
      return;
    }

    final isHls = url.contains('.m3u8');
    final task = DownloadTask(
      id: id,
      movieId: movieId,
      movieTitle: movieTitle,
      episodeTitle: episodeTitle,
      url: url,
      poster: poster,
      format: format,
      isHls: isHls,
    );

    _tasks.add(task);
    await _saveTasks();
    notifyListeners();

    if (isHls) {
      _startHlsDownload(task);
    } else {
      _processQueue();
    }

    TxaLogger.log(
      "Added download task: $movieTitle - $episodeTitle",
      isError: false,
    );
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

      if (task.format == 'mp4') {
        await _downloadChunked(task);
      } else {
        await _downloadM3U8(task);
      }

      task.status = DownloadStatus.completed;
      task.progress = 100.0;
      await _saveTasks();
      _checkMovieCompletion(task.movieId);
      _processQueue();
    } catch (e) {
      TxaLogger.log("Download Error (${task.id}): $e", isError: true);
      task.status = DownloadStatus.error;
      task.error = e.toString();
      _processQueue();
    }
    notifyListeners();
  }

  Future<void> _downloadChunked(DownloadTask task) async {
    final cancelToken = CancelToken();
    await _dio.download(
      task.url,
      task.savePath!,
      cancelToken: cancelToken,
      onReceiveProgress: (count, total) {
        if (total != -1) {
          task.downloadedBytes = count;
          task.totalBytes = total;
          task.progress = (count / total) * 100;

          if (count % (1024 * 1024) == 0) {
            // Every 1MB
            _updateNotification(task);
            notifyListeners();
          }
        }
      },
    );
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
    final android = AndroidNotificationDetails(
      'txa_downloads',
      TxaLanguage.t('download_channel_name'),
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: task.progress.toInt(),
      onlyAlertOnce: true,
    );

    await _notifications.show(
      id: task.id.hashCode,
      title: task.movieTitle,
      body: "${task.episodeTitle}: ${task.progress.toInt()}%",
      notificationDetails: NotificationDetails(android: android),
    );
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
    if (_currentMovieDownloading == movieId) _currentMovieDownloading = '';
    _processQueue();
    notifyListeners();
  }

  String _generateTaskId(String input) {
    return input.hashCode.abs().toString();
  }

  Future<void> _startHlsDownload(DownloadTask task) async {
    try {
      task.status = DownloadStatus.downloading;
      notifyListeners();

      final dio = Dio();
      final response = await dio.get(task.url);
      final String m3u8Content = response.data.toString();

      final lines = m3u8Content.split('\n');
      final List<String> segmentUrls = [];
      final baseUrl = task.url.substring(0, task.url.lastIndexOf('/') + 1);

      for (var line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isNotEmpty && !trimmedLine.startsWith('#')) {
          if (trimmedLine.startsWith('http')) {
            segmentUrls.add(trimmedLine);
          } else {
            segmentUrls.add(baseUrl + trimmedLine);
          }
        }
      }

      if (segmentUrls.isEmpty) {
        throw Exception("No video segments found in M3U8");
      }

      task.totalSegments = segmentUrls.length;
      final dir = await getApplicationDocumentsDirectory();
      final movieDir = Directory(
        '${dir.path}/downloads/${task.movieId}/${task.id}',
      );
      if (!await movieDir.exists()) {
        await movieDir.create(recursive: true);
      }

      int completed = 0;
      for (var i = 0; i < segmentUrls.length; i++) {
        if (!_tasks.any((t) => t.id == task.id)) return;

        final segmentUrl = segmentUrls[i];
        final segmentPath = '${movieDir.path}/seg_$i.ts';

        if (!await File(segmentPath).exists()) {
          await dio.download(segmentUrl, segmentPath);
        }

        completed++;
        task.downloadedSegments = completed;
        task.progress = (completed / segmentUrls.length) * 100;

        if (completed % 5 == 0 || completed == segmentUrls.length) {
          notifyListeners();
          await _saveTasks();
        }
      }

      String localM3u8 = "";
      int segIdx = 0;
      for (var line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isNotEmpty && !trimmedLine.startsWith('#')) {
          localM3u8 += "seg_$segIdx.ts\n";
          segIdx++;
        } else {
          localM3u8 += "$trimmedLine\n";
        }
      }

      final localM3u8File = File('${movieDir.path}/index.m3u8');
      await localM3u8File.writeAsString(localM3u8);

      task.status = DownloadStatus.completed;
      task.savePath = localM3u8File.path;
      task.progress = 100.0;
      await _saveTasks();
      notifyListeners();

      _showNotification(
        TxaLanguage.t('download_completed'),
        "${task.movieTitle} - ${task.episodeTitle}",
      );
    } catch (e) {
      TxaLogger.log("HLS Download Error: $e", isError: true);
      task.status = DownloadStatus.error;
      task.error = e.toString();
      notifyListeners();
    }
  }

  Future<void> _showNotification(String title, String body) async {
    final plugin = FlutterLocalNotificationsPlugin();
    final androidDetails = AndroidNotificationDetails(
      'txa_download_channel',
      TxaLanguage.t('download_channel_name'),
      channelDescription: TxaLanguage.t('download_channel_desc'),
      importance: Importance.high,
      priority: Priority.high,
    );
    final details = NotificationDetails(android: androidDetails);
    await plugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
