import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:background_downloader_hls/background_downloader_hls.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/txa_format.dart';
import '../services/txa_language.dart';
import '../utils/txa_logger.dart';

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
  bool isMerging;
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
    this.isMerging = false,
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
    'isMerging': isMerging,
  };

  factory TxaDownloadTask.fromJson(Map<String, dynamic> json) =>
      TxaDownloadTask(
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
        isMerging: json['isMerging'] ?? false,
      );

  String get statusDisplay {
    if (status == DownloadStatus.completed) return TxaLanguage.t('downloaded');
    if (status == DownloadStatus.paused) return TxaLanguage.t('paused');
    if (status == DownloadStatus.error) {
      return TxaLanguage.t('download_error', replace: {'msg': error ?? ''});
    }
    if (status == DownloadStatus.pending) return TxaLanguage.t('pending');

    if (status == DownloadStatus.downloading) {
      if (isHls && isMerging) {
        return TxaLanguage.t('download_merging_video');
      }

      if (isHls && downloadedSegments > 0) {
        final speedStr = TxaFormat.formatSpeed(networkSpeed)['display'];
        final etaStr = timeRemaining != null
            ? TxaFormat.formatTime(timeRemaining!.inSeconds)
            : '--:--';
        final segmentsStr = TxaLanguage.t(
          'download_downloading_segments',
          replace: {
            'c': downloadedSegments.toString(),
            't': totalSegments.toString(),
          },
        );
        return '$segmentsStr • $speedStr • ETA: $etaStr';
      }

      final speedStr = TxaFormat.formatSpeed(networkSpeed)['display'];
      final etaStr = timeRemaining != null
          ? TxaFormat.formatTime(timeRemaining!.inSeconds)
          : '--:--';

      return TxaLanguage.t(
        'downloading_status',
        replace: {
          'p': (progress * 100).toStringAsFixed(0),
          's': speedStr,
          'e': etaStr,
        },
      );
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

  late HlsDownloader _hlsDownloader;
  final Map<String, StreamSubscription> _hlsSubscriptions = {};

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final Map<String, int> _lastNotifiedProgressPct = {};
  final Map<String, DateTime> _lastNotifiedTime = {};

  Future<void> init() async {
    if (_initialized) return;

    // Configure background_downloader
    await FileDownloader().configure(
      globalConfig: [(Config.requestTimeout, const Duration(seconds: 30))],
    );

    _hlsDownloader = HlsDownloader(
      logCallback: (level, message, [error, stackTrace]) => TxaLogger.log(
        message,
        type: 'downloads',
        tag: 'HLS_${level.name.toUpperCase()}',
      ),
    );

    // Listen for updates
    FileDownloader().updates.listen(_handleUpdate);

    // Initialize Local Notifications
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _notifications.initialize(
        settings: const InitializationSettings(android: android),
      );
      // Clean up any orphan notifications from previous crashes
      await _notifications.cancelAll();
    } catch (e) {
      TxaLogger.log('Failed to initialize local notifications for downloads: $e', isError: true, type: 'downloads');
    }

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
          txaTask.isMerging = false;
          break;
        case TaskStatus.complete:
          txaTask.status = DownloadStatus.completed;
          txaTask.progress = 1.0;
          txaTask.isMerging = false;
          TxaLogger.log(
            '✅ DOWNLOAD COMPLETE: ${txaTask.movieTitle} - ${txaTask.episodeTitle}',
            type: 'downloads',
            tag: 'SUCCESS',
          );
          break;
        case TaskStatus.failed:
          txaTask.status = DownloadStatus.error;
          txaTask.error = 'Download failed';
          txaTask.isMerging = false;
          TxaLogger.log(
            '❌ DOWNLOAD FAILED: ${txaTask.movieTitle} - ${txaTask.episodeTitle} | TaskId: ${update.task.taskId}',
            isError: true,
            type: 'downloads',
            tag: 'ERROR',
          );
          break;
        case TaskStatus.canceled:
          txaTask.status = DownloadStatus.error;
          txaTask.error = 'Download canceled';
          txaTask.isMerging = false;
          TxaLogger.log(
            '🛑 DOWNLOAD CANCELED: ${txaTask.movieTitle}',
            type: 'downloads',
            tag: 'CANCEL',
          );
          break;
        case TaskStatus.paused:
          txaTask.status = DownloadStatus.paused;
          txaTask.isMerging = false;
          break;
        default:
          break;
      }
    } else if (update is TaskProgressUpdate) {
      txaTask.progress = update.progress;
      txaTask.networkSpeed = update.networkSpeed;
      txaTask.timeRemaining = update.timeRemaining;

      // Estimate bytes for progress display when total is unknown
      if (txaTask.totalBytes > 0) {
        txaTask.downloadedBytes = (update.progress * txaTask.totalBytes)
            .toInt();
      } else if (update.progress > 0 &&
          update.networkSpeed > 0 &&
          update.timeRemaining.inSeconds > 0) {
        // Infer: total = remainingBytes / (1 - progress)
        final remainingBytes =
            update.networkSpeed * update.timeRemaining.inSeconds;
        final inferredTotal = (remainingBytes / (1 - update.progress)).toInt();
        if (inferredTotal > 0 && inferredTotal < 50 * 1024 * 1024 * 1024) {
          txaTask.totalBytes = inferredTotal;
          txaTask.downloadedBytes = (update.progress * inferredTotal).toInt();
        }
      }
    }

    notifyListeners();
    _saveTasks();
    _updateNotification(txaTask);
  }

  void _checkRunningTasks() async {
    for (var task in _tasks) {
      if (task.status == DownloadStatus.downloading ||
          task.status == DownloadStatus.pending) {
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
    try {
      if (!_initialized) {
        await init();
      }
      final String taskId = "${movieId}_$episodeId";
      if (_tasks.any((t) => t.id == taskId)) return;

      final isHls =
          url.contains('.m3u8') ||
          url.contains('/api/v6/playlist') ||
          url.contains('/api/proxy-media');

      Directory? baseDir;
      if (Platform.isAndroid) {
        try {
          final status = await Permission.manageExternalStorage.status;
          if (status.isGranted) {
            baseDir = Directory('/storage/emulated/0/TPHIMX/Videos');
            await baseDir.create(recursive: true);
          }
        } catch (e) {
          TxaLogger.log('Error creating manageExternalStorage directory: $e', isError: true, type: 'downloads');
        }

        if (baseDir == null) {
          try {
            final extDir = await getExternalStorageDirectory();
            if (extDir != null) {
              baseDir = Directory('${extDir.path}/TPHIMX/Videos');
              await baseDir.create(recursive: true);
            }
          } catch (e) {
            TxaLogger.log('Error creating externalStorage directory: $e', isError: true, type: 'downloads');
          }
        }

        if (baseDir == null) {
          final appDir = await getApplicationDocumentsDirectory();
          baseDir = Directory('${appDir.path}/TPHIMX/Videos');
          await baseDir.create(recursive: true);
        }
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        baseDir = Directory('${appDir.path}/TPHIMX/Videos');
        await baseDir.create(recursive: true);
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

      TxaLogger.log(
        '🚀 ENQUEUE: $movieTitle - $episodeTitle [${isHls ? "HLS" : "MP4"}]',
        type: 'downloads',
        tag: 'START',
      );

      // Enqueue via appropriate task type
      if (isHls) {
        final options = HlsDownloadOptions(
          downloadId: taskId,
          outputDirectoryPath: dirPath,
          combineSegments: true,
          deleteSegmentsAfterCombine: true,
        );

        // Start the download
        _hlsDownloader
            .downloadToFile(url, fileName, options: options)
            .then((result) {
              if (result.isSuccess) {
                txaTask.status = DownloadStatus.completed;
                txaTask.progress = 1.0;
                txaTask.isMerging = false;
                TxaLogger.log(
                  '✅ HLS DOWNLOAD COMPLETE: ${txaTask.movieTitle} - ${txaTask.episodeTitle}',
                  type: 'downloads',
                  tag: 'SUCCESS',
                );
              }
              _hlsSubscriptions[taskId]?.cancel();
              _hlsSubscriptions.remove(taskId);
              notifyListeners();
              _saveTasks();
            })
            .catchError((error) {
              if (error is HlsDownloadException) {
                if (error.code != HlsErrorCode.downloadCanceled &&
                    error.code != HlsErrorCode.downloadPaused) {
                  txaTask.status = DownloadStatus.error;
                  txaTask.error = error.message;
                  txaTask.isMerging = false;
                  TxaLogger.log(
                    '❌ HLS DOWNLOAD FAILED: ${txaTask.movieTitle} | Error: ${txaTask.error}',
                    isError: true,
                    type: 'downloads',
                    tag: 'ERROR',
                  );
                }
              } else {
                txaTask.status = DownloadStatus.error;
                txaTask.error = error.toString();
                txaTask.isMerging = false;
                TxaLogger.log(
                  '❌ HLS DOWNLOAD ERROR: ${txaTask.movieTitle} | Error: ${txaTask.error}',
                  isError: true,
                  type: 'downloads',
                  tag: 'ERROR',
                );
              }
              _hlsSubscriptions[taskId]?.cancel();
              _hlsSubscriptions.remove(taskId);
              notifyListeners();
              _saveTasks();
            });

        // Listen for progress updates
        final subscription = _hlsDownloader.listen(taskId).listen((update) {
          _handleHlsUpdate(taskId, update);
        });
        _hlsSubscriptions[taskId] = subscription;
      } else {
        final task = DownloadTask(
          url: url,
          taskId: taskId,
          filename: fileName,
          directory: "TPHIMX/Videos/$safeMovieName/$safeEpName",
          updates: Updates.statusAndProgress,
          allowPause: true,
        );
        await FileDownloader().enqueue(task);
      }
    } catch (e, stack) {
      TxaLogger.log(
        'Critical error in addTask: $e\n$stack',
        isError: true,
        type: 'downloads',
        tag: 'CRASH',
      );
      final String taskId = "${movieId}_$episodeId";
      final idx = _tasks.indexWhere((t) => t.id == taskId);
      if (idx != -1) {
        _tasks[idx].status = DownloadStatus.error;
        _tasks[idx].error = e.toString();
        notifyListeners();
        _saveTasks();
      }
    }
  }

  void _handleHlsUpdate(String taskId, HlsOverallTaskUpdate update) {
    final txaTaskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (txaTaskIndex == -1) return;

    final txaTask = _tasks[txaTaskIndex];

    switch (update.phase) {
      case HlsDownloadPhase.preparing:
        txaTask.status = DownloadStatus.pending;
        txaTask.isMerging = false;
        break;
      case HlsDownloadPhase.downloading:
        txaTask.status = DownloadStatus.downloading;
        txaTask.isMerging = false;
        txaTask.progress = update.progress;
        txaTask.totalSegments = update.totalSegments;
        txaTask.downloadedSegments = update.completedSegments;
        txaTask.networkSpeed = update.networkSpeed ?? 0;
        txaTask.timeRemaining = update.timeRemaining;
        // Estimate total bytes from segment count (avg ~1.5MB per .ts segment)
        if (update.totalSegments > 0) {
          const avgSegmentBytes = 1572864; // 1.5 MB
          txaTask.totalBytes = update.totalSegments * avgSegmentBytes;
          txaTask.downloadedBytes = (update.progress * txaTask.totalBytes)
              .toInt();
        }
        break;
      case HlsDownloadPhase.combining:
        txaTask.status = DownloadStatus.downloading;
        txaTask.isMerging = true;
        txaTask.downloadedSegments = txaTask.totalSegments;
        txaTask.networkSpeed = 0;
        txaTask.timeRemaining = null;
        txaTask.progress = 0.99; // Almost done
        break;
      case HlsDownloadPhase.completed:
        txaTask.status = DownloadStatus.completed;
        txaTask.progress = 1.0;
        txaTask.isMerging = false;
        break;
      case HlsDownloadPhase.paused:
        txaTask.status = DownloadStatus.paused;
        txaTask.isMerging = false;
        break;
      case HlsDownloadPhase.failed:
        txaTask.status = DownloadStatus.error;
        txaTask.error = update.message;
        txaTask.isMerging = false;
        break;
      case HlsDownloadPhase.canceled:
        txaTask.status = DownloadStatus.error;
        txaTask.error = 'Canceled';
        txaTask.isMerging = false;
        break;
    }

    notifyListeners();
    _saveTasks();
    _updateNotification(txaTask);
  }

  Future<void> pauseTask(String taskId) async {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    task.status = DownloadStatus.paused;
    task.isMerging = false;

    if (task.isHls) {
      await _hlsDownloader.pauseDownload(taskId);
    } else {
      final pluginTask = await FileDownloader().taskForId(taskId);
      if (pluginTask is DownloadTask) {
        await FileDownloader().pause(pluginTask);
      }
    }
    notifyListeners();
    await _saveTasks();
    await _updateNotification(task);
  }

  Future<void> resumeTask(String taskId) async {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    task.status = DownloadStatus.downloading;
    task.isMerging = false;

    if (task.isHls) {
      // Re-trigger download, it handles resuming internally if same ID is used
      addTask(
        movieId: task.movieId,
        episodeId: task.episodeId,
        movieTitle: task.movieTitle,
        episodeTitle: task.episodeTitle,
        url: task.url,
        poster: task.poster,
        format: task.format,
      );
    } else {
      final pluginTask = await FileDownloader().taskForId(taskId);
      if (pluginTask is DownloadTask) {
        await FileDownloader().resume(pluginTask);
      }
    }
    notifyListeners();
    await _saveTasks();
  }

  Future<void> removeTask(String taskId) async {
    final task = _tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => _tasks[0],
    ); // fallback if not found

    if (task.isHls) {
      await _hlsDownloader.cancelDownload(taskId);
      _hlsSubscriptions[taskId]?.cancel();
      _hlsSubscriptions.remove(taskId);
    } else {
      final pluginTask = await FileDownloader().taskForId(taskId);
      if (pluginTask != null) {
        await FileDownloader().cancelTasksWithIds([taskId]);
      }
    }

    try {
      await _notifications.cancel(id: taskId.hashCode);
    } catch (e) {
      TxaLogger.log('Failed to cancel notification for task $taskId: $e', isError: true, type: 'downloads');
    }

    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      final txaTask = _tasks[idx];
      if (txaTask.savePath != null) {
        try {
          final file = File(txaTask.savePath!);
          final epDir = file.parent;
          if (await epDir.exists()) {
            await epDir.delete(recursive: true);

            // Also check movie folder
            final movieDir = epDir.parent;
            if (await movieDir.exists()) {
              final movieChildren = await movieDir.list().toList();
              if (movieChildren.isEmpty) {
                await movieDir.delete();
              }
            }
          }
        } catch (e) {
          TxaLogger.log(
            'Failed to delete file/folders for task $taskId: $e',
            isError: true,
            type: 'downloads',
          );
        }
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
    return _tasks.any(
      (t) =>
          t.id == taskId &&
          (t.status == DownloadStatus.downloading ||
              t.status == DownloadStatus.pending),
    );
  }

  /// Get download status for a specific movie
  /// Returns: {downloadedEpisodes: int, totalEpisodes: int, isFullyDownloaded: bool, isPartiallyDownloaded: bool}
  Map<String, dynamic> getMovieDownloadStatus(
    String movieId,
    int totalEpisodes,
  ) {
    final movieTasks = _tasks.where((t) => t.movieId == movieId).toList();

    if (movieTasks.isEmpty) {
      return {
        'downloadedEpisodes': 0,
        'totalEpisodes': totalEpisodes,
        'isFullyDownloaded': false,
        'isPartiallyDownloaded': false,
        'hasActiveDownloads': false,
      };
    }

    final downloadedCount = movieTasks
        .where((t) => t.status == DownloadStatus.completed)
        .length;
    final hasActive = movieTasks.any(
      (t) =>
          t.status == DownloadStatus.downloading ||
          t.status == DownloadStatus.pending,
    );

    return {
      'downloadedEpisodes': downloadedCount,
      'totalEpisodes': totalEpisodes,
      'isFullyDownloaded':
          downloadedCount >= totalEpisodes && totalEpisodes > 0,
      'isPartiallyDownloaded':
          downloadedCount > 0 && downloadedCount < totalEpisodes,
      'hasActiveDownloads': hasActive,
    };
  }

  /// Check if a specific episode is downloaded
  bool isEpisodeDownloaded(String movieId, String episodeId) {
    final taskId = "${movieId}_$episodeId";
    final task = _tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => TxaDownloadTask(
        id: '',
        movieId: '',
        episodeId: '',
        movieTitle: '',
        episodeTitle: '',
        url: '',
        poster: '',
        format: '',
      ),
    );
    return task.id.isNotEmpty && task.status == DownloadStatus.completed;
  }

  /// Get all downloaded episodes for a movie
  List<TxaDownloadTask> getDownloadedEpisodes(String movieId) {
    return _tasks
        .where(
          (t) => t.movieId == movieId && t.status == DownloadStatus.completed,
        )
        .toList();
  }

  /// Get active downloading episodes for a movie
  List<TxaDownloadTask> getActiveDownloadsForMovie(String movieId) {
    return _tasks
        .where(
          (t) =>
              t.movieId == movieId &&
              (t.status == DownloadStatus.downloading ||
                  t.status == DownloadStatus.pending),
        )
        .toList();
  }

  Future<void> _updateNotification(TxaDownloadTask task) async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) return;

      final String taskId = task.id;
      final int notifId = taskId.hashCode;
      final now = DateTime.now();

      if (task.status == DownloadStatus.downloading) {
        final int progressPct = (task.progress * 100).toInt().clamp(0, 100);
        final lastPct = _lastNotifiedProgressPct[taskId];
        final lastTime = _lastNotifiedTime[taskId];

        // Throttle: only update if status changed, or pct changed, and at least 1.5 seconds passed (unless 0% or 100%)
        if (lastPct != null && lastTime != null) {
          final timePassed = now.difference(lastTime).inMilliseconds >= 1500;
          final pctChanged = progressPct != lastPct;
          if (!pctChanged || (!timePassed && progressPct > 0 && progressPct < 100)) {
            return;
          }
        }

        _lastNotifiedProgressPct[taskId] = progressPct;
        _lastNotifiedTime[taskId] = now;

        final String title = "${task.movieTitle} - ${task.episodeTitle}";
        final String body = task.statusDisplay;

        final androidDetails = AndroidNotificationDetails(
          'txa_movie_downloads',
          'TPhimX Tải Phim',
          channelDescription: 'Thông báo tiến trình tải phim',
          importance: Importance.low,
          priority: Priority.low,
          category: AndroidNotificationCategory.progress,
          showProgress: true,
          maxProgress: 100,
          progress: progressPct,
          ongoing: true,
          onlyAlertOnce: true,
        );

        final details = NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(
            presentAlert: false,
            presentSound: false,
          ),
        );

        await _notifications.show(
          id: notifId,
          title: title,
          body: body,
          notificationDetails: details,
        );
      } else if (task.status == DownloadStatus.completed) {
        _lastNotifiedProgressPct.remove(taskId);
        _lastNotifiedTime.remove(taskId);

        final String title = "${task.movieTitle} - ${task.episodeTitle}";
        final String body = TxaLanguage.t('download_finished');

        final androidDetails = const AndroidNotificationDetails(
          'txa_movie_downloads',
          'TPhimX Tải Phim',
          channelDescription: 'Thông báo tiến trình tải phim',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: false,
        );

        final details = NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(),
        );

        await _notifications.show(
          id: notifId,
          title: title,
          body: body,
          notificationDetails: details,
        );
      } else if (task.status == DownloadStatus.error) {
        _lastNotifiedProgressPct.remove(taskId);
        _lastNotifiedTime.remove(taskId);

        final String title = "${task.movieTitle} - ${task.episodeTitle}";
        final String body = "Tải thất bại: ${task.error ?? 'Lỗi không xác định'}";

        final androidDetails = const AndroidNotificationDetails(
          'txa_movie_downloads',
          'TPhimX Tải Phim',
          channelDescription: 'Thông báo tiến trình tải phim',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: false,
        );

        final details = NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(),
        );

        await _notifications.show(
          id: notifId,
          title: title,
          body: body,
          notificationDetails: details,
        );
      } else if (task.status == DownloadStatus.paused) {
        _lastNotifiedProgressPct.remove(taskId);
        _lastNotifiedTime.remove(taskId);
        await _notifications.cancel(id: notifId);
      }
    } catch (e) {
      TxaLogger.log('Error updating notification for task ${task.id}: $e', isError: true, type: 'downloads');
    }
  }
}
