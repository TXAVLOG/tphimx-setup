import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../services/txa_language.dart';

class TxaFormat {
  /// Pad number to 2 digits
  static String pad2(int n) {
    return n.toString().padLeft(2, '0');
  }

  /// Format seconds to H:m:s or m:s
  static String formatTime(int seconds) {
    if (seconds < 0) return '00:00';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${pad2(h)}:${pad2(m)}:${pad2(s)}';
    }
    return '${pad2(m)}:${pad2(s)}';
  }

  /// Format date to string
  static String formatDate(DateTime date, {String pattern = 'dd/MM/yyyy'}) {
    return DateFormat(pattern).format(date);
  }

  /// Format size (bytes to human readable)
  static Map<String, dynamic> formatSize(
    int bytes, {
    int decimals = 2,
    bool padInteger = false,
  }) {
    if (bytes <= 0) return {'value': 0.0, 'unit': 'B', 'display': '0.00 B'};
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    final double value = bytes.toDouble();
    const double base = 1024.0;
    final int i = (math.log(value.abs()) / math.log(base)).floor().clamp(
      0,
      units.length - 1,
    );
    final double unitValue = value / math.pow(base, i);

    // Format with decimals
    String formatted = unitValue.toStringAsFixed(decimals); // e.g. "1.45"
    if (padInteger) {
      List<String> parts = formatted.split('.');
      String integerPart = parts[0].padLeft(2, '0');
      String decimalPart = parts.length > 1 ? parts[1] : '';
      formatted = decimalPart.isNotEmpty
          ? "$integerPart.$decimalPart"
          : integerPart;
    }

    final String display = '$formatted ${units[i]}';
    return {'value': unitValue, 'unit': units[i], 'display': display};
  }

  /// Format file size directly to string
  static String formatFileSize(int bytes) {
    return formatSize(bytes)['display'];
  }

  /// Format speed (bytes/s to human readable) - For Download/Update
  static Map<String, dynamic> formatSpeed(
    double bytesPerSec, {
    int decimals = 2,
  }) {
    final sizeInfo = formatSize(bytesPerSec.toInt(), decimals: decimals);
    return {
      'value': sizeInfo['value'],
      'unit': '${sizeInfo['unit']}/s',
      'display': '${sizeInfo['display']}/s',
    };
  }

  /// Format network speed specifically for App Settings/Status - Support custom Units
  static String formatNetworkSpeed(double bitsPerSec, {String unit = 'Auto'}) {
    if (bitsPerSec <= 0) return '0 ${unit == 'Auto' ? 'KB/s' : unit}';
    double mbps = bitsPerSec / 1000000.0;
    double bytesPerSec = bitsPerSec / 8.0;

    switch (unit) {
      case 'Mb/s':
        return '${mbps.toStringAsFixed(2)} Mb/s';
      case 'Gb/s':
        return '${(mbps / 1000.0).toStringAsFixed(2)} Gb/s';
      case 'B/s':
        return '${bytesPerSec.toStringAsFixed(0)} B/s';
      case 'KB/s':
        return '${(bytesPerSec / 1024.0).toStringAsFixed(2)} KB/s';
      case 'MB/s':
        return '${(bytesPerSec / (1024.0 * 1024.0)).toStringAsFixed(2)} MB/s';
      case 'GB/s':
        return '${(bytesPerSec / (1024.0 * 1024.0 * 1024.0)).toStringAsFixed(2)} GB/s';
      case 'TB/s':
        return '${(bytesPerSec / (1024.0 * 1024.0 * 1024.0 * 1024.0)).toStringAsFixed(2)} TB/s';
      case 'Auto':
      default:
        // Use Bytes-based units for Auto as it's more common for downloads
        if (bytesPerSec >= 1024 * 1024 * 1024) {
          return '${(bytesPerSec / (1024.0 * 1024.0 * 1024.0)).toStringAsFixed(2)} GB/s';
        }
        if (bytesPerSec >= 1024 * 1024) {
          return '${(bytesPerSec / (1024.0 * 1024.0)).toStringAsFixed(2)} MB/s';
        }
        return '${(bytesPerSec / 1024.0).toStringAsFixed(2)} KB/s';
    }
  }

  /// Format data size specifically for the update process
  static String formatDataSize(int bytes) {
    final info = formatSize(bytes);
    return info['display'];
  }

  /// Format duration to localized words (ETA)
  static String formatDuration(int seconds) {
    if (seconds <= 0) return TxaLanguage.t('time_second', replace: {'n': '0'});
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    List<String> parts = [];
    if (h > 0) parts.add(TxaLanguage.t('time_hour', replace: {'n': '$h'}));
    if (m > 0) parts.add(TxaLanguage.t('time_minute', replace: {'n': '$m'}));
    if (s > 0 && h == 0) {
      parts.add(TxaLanguage.t('time_second', replace: {'n': '$s'}));
    }
    return parts.isEmpty
        ? TxaLanguage.t('time_second', replace: {'n': '0'})
        : parts.join(' ');
  }

  /// Relative time (ago) from String
  static String formatTimeAgo(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return formatAgo(date);
    } catch (e) {
      return '';
    }
  }

  /// Relative time (ago) - Localized
  static String formatAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 30) return TxaLanguage.t('time_just_now');
    if (diff.inSeconds < 60) {
      return TxaLanguage.t(
        'time_seconds_ago',
        replace: {'n': '${diff.inSeconds}'},
      );
    }
    if (diff.inMinutes < 60) {
      return TxaLanguage.t(
        'time_minutes_ago',
        replace: {'n': '${diff.inMinutes}'},
      );
    }
    if (diff.inHours < 24) {
      return TxaLanguage.t('time_hours_ago', replace: {'n': '${diff.inHours}'});
    }
    if (diff.inDays < 30) {
      return TxaLanguage.t('time_days_ago', replace: {'n': '${diff.inDays}'});
    }
    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return TxaLanguage.t('time_months_ago', replace: {'n': '$months'});
    }
    final years = (diff.inDays / 365).floor();
    return TxaLanguage.t('time_years_ago', replace: {'n': '$years'});
  }

  /// Format number - Localized suffixes
  static String formatNumber(dynamic numVal, {bool compact = false}) {
    if (numVal == null) return '0';
    num val = numVal is num ? numVal : double.tryParse(numVal.toString()) ?? 0;
    if (val == 0) return '0';

    if (compact) {
      final absVal = val.abs();
      if (absVal >= 1e9) {
        String s = (val / 1e9).toStringAsFixed(1);
        if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
        return '$s${TxaLanguage.t('num_b')}';
      }
      if (absVal >= 1e6) {
        String s = (val / 1e6).toStringAsFixed(1);
        if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
        return '$s${TxaLanguage.t('num_m')}';
      }
      if (absVal >= 1e3) {
        String s = (val / 1e3).toStringAsFixed(1);
        if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
        return '$s${TxaLanguage.t('num_k')}';
      }
    }

    final formatter = NumberFormat('#,###', 'en_US');
    return formatter.format(val);
  }

  /// Format date to HH:mm:ss dd/MM/yy
  static String formatDateTime(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('HH:mm:ss dd/MM/yy').format(date);
    } catch (e) {
      return '';
    }
  }

  /// Format battery level
  static String formatBattery(int level) {
    return '$level%';
  }

  /// Format episode name to avoid duplication (e.g. "Tập Tập 1")
  /// Also handles special cases like "Full", "Trailer" to not add "Tập" prefix.
  static String formatEpisodeName(String? name) {
    if (name == null || name.isEmpty) return "";
    final trimmed = name.trim();

    // Vietnamese "Tập" and English "Episode" / "Ep" / "Part" / "P"
    // Also handle cases like "Tập1" or "Ep.1" (no space or with dot)
    final prefixPattern = RegExp(
      r'^(tập|episode|ep\.?|part|p\.?)\s?\d+',
      caseSensitive: false,
    );

    if (prefixPattern.hasMatch(trimmed)) return trimmed;

    // Special cases like "Full", "Trailer", "Special", "Final"
    // If it contains these words, usually we don't want to prepend "Tập"
    final lowercase = trimmed.toLowerCase();
    final specialKeywords = [
      'full',
      'trailer',
      'special',
      'hoàn tất',
      'hoàn thành',
      'final',
      'tập cuối',
      'hồi kết',
    ];

    for (var keyword in specialKeywords) {
      if (lowercase.contains(keyword)) return trimmed;
    }

    // If it's just a number, add "Tập"
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return TxaLanguage.t('episode_label', replace: {'n': trimmed});
    }

    // Fallback: return as is
    return trimmed;
  }
}
