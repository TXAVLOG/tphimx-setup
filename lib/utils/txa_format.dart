import 'dart:math' as math;
import 'package:intl/intl.dart';

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
  static Map<String, dynamic> formatSize(int bytes, {int decimals = 2, bool padInteger = true}) {
    if (bytes <= 0) return {'value': 0.0, 'unit': 'B', 'display': '00.00 B'};
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    final double value = bytes.toDouble();
    const double base = 1024.0;
    final int i = (math.log(value.abs()) / math.log(base)).floor().clamp(0, units.length - 1);
    final double unitValue = value / math.pow(base, i);
    
    // Format with decimals
    String formatted = unitValue.toStringAsFixed(decimals); // e.g. "1.45"
    if (padInteger) {
      List<String> parts = formatted.split('.');
      String integerPart = parts[0].padLeft(2, '0');
      String decimalPart = parts.length > 1 ? parts[1] : '';
      formatted = decimalPart.isNotEmpty ? "$integerPart.$decimalPart" : integerPart;
    }

    final String display = '$formatted ${units[i]}';
    return {'value': unitValue, 'unit': units[i], 'display': display};
  }

  /// Format speed (bytes/s to human readable)
  static Map<String, dynamic> formatSpeed(double bytesPerSec, {int decimals = 2}) {
    final sizeInfo = formatSize(bytesPerSec.toInt(), decimals: decimals);
    return {
      'value': sizeInfo['value'],
      'unit': '${sizeInfo['unit']}/s',
      'display': '${sizeInfo['display']}/s',
    };
  }

  /// Format duration to Vietnamese words
  static String formatDuration(int seconds) {
    if (seconds <= 0) return '0 giây';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    List<String> parts = [];
    if (h > 0) parts.add('$h giờ');
    if (m > 0) parts.add('$m phút');
    if (s > 0 && h == 0) parts.add('$s giây');
    return parts.isEmpty ? '0 giây' : parts.join(' ');
  }

  /// Relative time (ago)
  static String formatAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 30) return 'Vừa xong';
    if (diff.inSeconds < 60) return '${diff.inSeconds} giây trước';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 30) return '${diff.inDays} ngày trước';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} tháng trước';
    return '${(diff.inDays / 365).floor()} năm trước';
  }

  /// Format number
  static String formatNumber(dynamic numVal, {bool compact = false}) {
    if (numVal == null) return '0';
    num val = numVal is num ? numVal : double.tryParse(numVal.toString()) ?? 0;
    if (val == 0) return '0';
    
    if (compact) {
      final absVal = val.abs();
      if (absVal >= 1e9) {
        String s = (val / 1e9).toStringAsFixed(1);
        if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
        return '${s}B';
      }
      if (absVal >= 1e6) {
        String s = (val / 1e6).toStringAsFixed(1);
        if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
        return '${s}M';
      }
      if (absVal >= 1e3) {
        String s = (val / 1e3).toStringAsFixed(1);
        if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
        return '${s}K';
      }
    }
    
    final formatter = NumberFormat('#,###', 'en_US');
    return formatter.format(val);
  }
}
