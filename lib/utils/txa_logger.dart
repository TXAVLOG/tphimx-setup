import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class TxaLogger {
  static Future<String> get _logPath async {
    // Check for "Manage All Files" permission (Android 11+)
    final status = await Permission.manageExternalStorage.status;
    
    if (status.isGranted) {
      // Premium path for granted "All Files" permission
      final dir = Directory('/storage/emulated/0/TPHIMX/Logs');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    } else {
      // Default sandbox path
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/Logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      return logDir.path;
    }
  }

  static Future<void> log(String message, {bool isError = false}) async {
    try {
      final path = await _logPath;
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final file = File('$path/app_$date.log');
      
      final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
      final level = isError ? 'ERROR' : 'INFO';
      final logLine = '[$timestamp] [$level] $message\n';
      
      await file.writeAsString(logLine, mode: FileMode.append, flush: true);
      
      // Also print to console for development
      if (isError) {
        if (kDebugMode) debugPrint('TPHIMX-LOG-ERR: $message');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('CRITICAL: Failed to write to log file: $e');
    }
  }
}
