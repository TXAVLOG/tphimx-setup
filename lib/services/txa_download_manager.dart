import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
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
    notifyListeners();
    _processQueue();
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
      Directory? baseDir;
      if (Platform.isAndroid) {
        baseDir = Directory('/storage/emulated/0/TPHIMX/Videos');
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        baseDir = Directory('${appDir.path}/TPHIMX/Videos');
      }

      final safeMovieName = task.movieTitle.replaceAll(
        RegExp(r'[<>:"/\\|?*]'),
        '_',
      );
      final safeEpName = task.episodeTitle.replaceAll(
        RegExp(r'[<>:"/\\|?*]'),
        '_',
      );
      final dirPath = "${baseDir.path}/$safeMovieName/$safeEpName";
      await Directory(dirPath).create(recursive: true);

      final ext = task.isHls ? 'mp4' : task.format;
      final fileName = "txa_${task.id}.$ext";
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
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;

    Directory? appDir;
    if (Platform.isAndroid) {
      appDir = await getExternalStorageDirectory();
      appDir ??= await getApplicationDocumentsDirectory();
    } else {
      appDir = await getApplicationDocumentsDirectory();
    }

    final tempDir = Directory("${appDir.path}/temp_hls/${task.id}");
    if (!await tempDir.exists()) await tempDir.create(recursive: true);

    try {
      // 1. Fetch Master Playlist
      final masterRes = await _dio.get<String>(
        task.url,
        cancelToken: cancelToken,
      );
      final masterContent = masterRes.data ?? '';

      // 2. Extract Variant
      final lines = masterContent.split('\n');
      String variantUrl = '';
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('#EXT-X-STREAM-INF')) {
          if (i + 1 < lines.length) {
            variantUrl = lines[i + 1].trim();
            break;
          }
        }
      }

      String variantContent = masterContent;
      if (variantUrl.isNotEmpty) {
        if (!variantUrl.startsWith('http')) {
          final uri = Uri.parse(task.url);
          variantUrl = '${uri.scheme}://${uri.host}$variantUrl';
        }
        final variantRes = await _dio.get<String>(
          variantUrl,
          cancelToken: cancelToken,
        );
        variantContent = variantRes.data ?? '';
      }

      // 3. Extract Segments
      final vLines = variantContent.split('\n');
      final segments = <String>[];
      for (var line in vLines) {
        final l = line.trim();
        if (l.isNotEmpty && !l.startsWith('#')) {
          segments.add(l);
        }
      }

      if (segments.isEmpty) {
        throw Exception("No segments found in m3u8");
      }

      task.totalSegments = segments.length;
      task.downloadedSegments = 0;
      notifyListeners();

      // 4. Download Segments
      final playlistUri = Uri.parse(task.url);
      final baseUri = playlistUri.resolve('.');
      final concatListPath = "${tempDir.path}/concat.txt";
      final concatFile = File(concatListPath);
      final sink = concatFile.openWrite();

      final maxWorkers = 5;
      int currentIndex = 0;

      Future<void> downloadWorker() async {
        while (currentIndex < segments.length) {
          if (task.status != DownloadStatus.downloading) {
            cancelToken.cancel("User paused");
            return;
          }
          final idx = currentIndex++;
          final segPath = segments[idx];
          final segUrl = segPath.startsWith('http')
              ? segPath
              : baseUri.resolve(segPath).toString();
          final tsPath = "${tempDir.path}/seg_$idx.ts";

          bool success = false;
          int retries = 3;
          while (!success && retries > 0) {
            try {
              final file = File(tsPath);
              if (!await file.exists() || await file.length() == 0) {
                await _dio.download(segUrl, tsPath, cancelToken: cancelToken);
              }
              success = true;
            } catch (e) {
              if (e is DioException && CancelToken.isCancel(e)) rethrow;
              retries--;
              if (retries == 0) {
                throw Exception("Failed to download segment $idx");
              }
              await Future.delayed(const Duration(seconds: 1));
            }
          }

          task.downloadedSegments++;
          if (task.downloadedSegments % 5 == 0 ||
              task.downloadedSegments == task.totalSegments) {
            _updateNotification(task);
            notifyListeners();
          }
        }
      }

      final workers = List.generate(maxWorkers, (_) => downloadWorker());
      await Future.wait(workers);

      // Write to concat file
      for (int i = 0; i < segments.length; i++) {
        sink.writeln("file 'seg_$i.ts'");
      }
      await sink.close();

      // 5. Merge with FFmpeg
      // Double check task status hasn't changed to paused/removed during download
      if (task.status == DownloadStatus.downloading) {
        task.progress = 99.9;
        _updateNotification(task);
        notifyListeners();

        final outputMp4 = task.savePath!;
        if (await File(outputMp4).exists()) {
          await File(outputMp4).delete();
        }

        final command =
            "-f concat -safe 0 -i \"$concatListPath\" -c copy -metadata copyright=\"TPhimX Premium\" -metadata comment=\"Downloaded from TPhimX App\" \"$outputMp4\"";
        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          // Cleanup
          await tempDir.delete(recursive: true);
        } else {
          final logs = await session.getLogsAsString();
          throw Exception("FFmpeg merge failed: $logs");
        }
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        TxaLogger.log("Download cancelled/paused: ${task.id}");
      } else {
        rethrow;
      }
    } finally {
      _cancelTokens.remove(task.id);
    }
  }

  void _checkMovieCompletion(String movieId) {
    final movieTasks = _tasks.where((t) => t.movieId == movieId).toList();
    final allDone = movieTasks.every(
      (t) => t.status == DownloadStatus.completed,
    );

    if (allDone && movieTasks.isNotEmpty) {
      _currentMovieDownloading = '';
      _showMovieDoneNotification(movieTasks.first.movieTitle, movieTasks);
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
          "${TxaLanguage.t('episodes_count', replace: {'c': (done + 1).toString(), 't': total.toString()})} • ";
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

    String body = "";
    if (task.isHls) {
      if (task.totalSegments > 0) {
        if (task.downloadedSegments == task.totalSegments) {
          body =
              "$countInfo${task.episodeTitle}: ${TxaLanguage.t('download_merging_video')}";
        } else {
          body =
              "$countInfo${task.episodeTitle}: ${TxaLanguage.t('download_downloading_segments', replace: {'c': task.downloadedSegments.toString(), 't': task.totalSegments.toString()})}";
        }
      } else {
        body =
            "$countInfo${task.episodeTitle}: ${TxaLanguage.t('download_fetching_playlist')}";
      }
    } else {
      String sizeInfo = "";
      if (task.totalBytes > 0) {
        sizeInfo =
            " (${TxaFormat.formatFileSize(task.downloadedBytes)} / ${TxaFormat.formatFileSize(task.totalBytes)})";
      }
      body =
          "$countInfo${task.episodeTitle}: ${task.progress.toInt()}%$sizeInfo • $_currentSpeed";
    }

    await _notifications.show(
      id: task.id.hashCode,
      title: task.movieTitle,
      body: body,
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

  void _showMovieDoneNotification(String title, List<DownloadTask> tasks) {
    final android = AndroidNotificationDetails(
      'txa_downloads_done',
      TxaLanguage.t('download_completed'),
      importance: Importance.high,
      priority: Priority.high,
    );

    String body;
    if (tasks.length == 1) {
      body =
          "$title: ${TxaLanguage.t('download_single_completed', replace: {'ep': tasks.first.episodeTitle})}";
    } else {
      body =
          "$title: ${TxaLanguage.t('download_all_completed', replace: {'n': tasks.length.toString()})}";
    }

    _notifications.show(
      id: title.hashCode,
      title: TxaLanguage.t('download_completed'),
      body: body,
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

  Future<void> pauseTask(String taskId) async {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    if (task.status == DownloadStatus.downloading) {
      task.status = DownloadStatus.paused;
      _cancelTokens[taskId]?.cancel("User paused");
      _cancelTokens.remove(taskId);
      await _saveTasks();
      notifyListeners();
    }
  }

  Future<void> priorityTask(String taskId) async {
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
        await pauseTask(t.id);
        t.status = DownloadStatus.pending; // Back to queue
      }
    }

    _processQueue();
    notifyListeners();
    await _saveTasks();
  }

  Future<void> resumeTask(String taskId) async {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    if (task.status == DownloadStatus.paused ||
        task.status == DownloadStatus.error) {
      task.status = DownloadStatus.pending;
      await _saveTasks();
      _processQueue();
      notifyListeners();
    }
  }
}
