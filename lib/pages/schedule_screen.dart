import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

import 'package:provider/provider.dart';
import '../services/txa_api.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../utils/txa_toast.dart';
import '../services/txa_settings.dart';
import 'movie_detail_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<dynamic>? _data;
  bool _loading = true;
  String? _error;
  late DateTime _selectedDate;
  late DateTime _today;
  late DateTime _pivotDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _selectedDate = _today;
    _pivotDate = _today;
    _fetchSchedule();
  }

  Future<void> _fetchSchedule() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = Provider.of<TxaApi>(context, listen: false);
      final res = await api.getSchedule();
      final data = res['data'];
      setState(() {
        _data = data is List ? data : [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  List<DateTime> _getCurrentWeekDates() {
    final day = _selectedDate.weekday; // 1=Mon, 7=Sun
    final monday = _selectedDate.subtract(Duration(days: day - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  List<dynamic> _getMoviesForDate(DateTime date) {
    if (_data == null) return [];
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    for (final group in _data!) {
      if (group['date'] == dateStr) {
        return group['movies'] as List? ?? [];
      }
    }
    return [];
  }

  void _changeWeek(int direction) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: direction * 7));
      _pivotDate = _selectedDate;
    });
  }

  void _handleMonthSelect(int monthIdx) {
    setState(() {
      _selectedDate = DateTime(
        _pivotDate.year,
        monthIdx + 1,
        _selectedDate.day,
      );
      // Ensure day is valid for that month
      if (_selectedDate.month != monthIdx + 1) {
        _selectedDate = DateTime(_pivotDate.year, monthIdx + 2, 0);
      }
      _pivotDate = _selectedDate;
      Navigator.pop(context);
    });
  }

  void _handleYearSelect(int year) {
    setState(() {
      _pivotDate = DateTime(year, _pivotDate.month, _pivotDate.day);
      Navigator.pop(context); // Close Year Picker
      _showMonthPicker(); // Back to Month Picker
    });
  }

  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: TxaTheme.primaryBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => setModalState(
                      () => _pivotDate = DateTime(
                        _pivotDate.year - 1,
                        _pivotDate.month,
                        1,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _showYearPicker();
                    },
                    child: Text(
                      TxaLanguage.t(
                        'year_label',
                      ).replaceAll('%year', _pivotDate.year.toString()),
                      style: const TextStyle(
                        color: TxaTheme.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => setModalState(
                      () => _pivotDate = DateTime(
                        _pivotDate.year + 1,
                        _pivotDate.month,
                        1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: 12,
                itemBuilder: (ctx, i) {
                  final isSelected =
                      _selectedDate.month == i + 1 &&
                      _selectedDate.year == _pivotDate.year;
                  return GestureDetector(
                    onTap: () => _handleMonthSelect(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? TxaTheme.accent : TxaTheme.cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: TxaTheme.glassBorder),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _months[i],
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : TxaTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showYearPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final curStart = (_pivotDate.year ~/ 10) * 10 - 1;
          return Container(
            decoration: const BoxDecoration(
              color: TxaTheme.primaryBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => setModalState(
                        () => _pivotDate = DateTime(_pivotDate.year - 10, 1, 1),
                      ),
                    ),
                    Text(
                      '$curStart - ${curStart + 11}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => setModalState(
                        () => _pivotDate = DateTime(_pivotDate.year + 10, 1, 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: 12,
                  itemBuilder: (ctx, i) {
                    final year = curStart + i;
                    final isSelected = _selectedDate.year == year;
                    final isSibling = i == 0 || i == 11;
                    return GestureDetector(
                      onTap: () => _handleYearSelect(year),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? TxaTheme.accent : TxaTheme.cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: TxaTheme.glassBorder),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$year',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isSibling
                                      ? TxaTheme.textMuted
                                      : TxaTheme.textPrimary),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatEpisodeLabel(dynamic movie) {
    if (movie['type'] == 'single') return TxaLanguage.t('movie_single');
    String val = (movie['next_episode_name'] ?? movie['episode_current'] ?? '1')
        .toString()
        .trim();
    if (val.isEmpty) return TxaLanguage.t('unknown_episode');

    // Check if it already has "Tập" or "tap" prefix (case insensitive)
    final hasTapPrefix = RegExp(r'^tập\s', caseSensitive: false).hasMatch(val);
    if (!hasTapPrefix) {
      if (RegExp(r'^(\d+)\s*(.*)$').hasMatch(val)) {
        final match = RegExp(r'^(\d+)\s*(.*)$').firstMatch(val);
        if (match != null) {
          final number = match.group(1);
          final suffix = match.group(2)?.trim() ?? "";
          if (suffix.isNotEmpty) {
            final formattedSuffix =
                suffix[0].toUpperCase() + suffix.substring(1);
            return "${TxaLanguage.t('episode')} $number ($formattedSuffix)";
          } else {
            return "${TxaLanguage.t('episode')} $number";
          }
        }
      } else if (!val.toLowerCase().contains('full') &&
          !val.toLowerCase().contains('tập') &&
          !val.toLowerCase().contains('episode')) {
        return "${TxaLanguage.t('episode')} $val";
      }
    }
    return val;
  }

  static const _daysShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _months = [
    'Th1',
    'Th2',
    'Th3',
    'Th4',
    'Th5',
    'Th6',
    'Th7',
    'Th8',
    'Th9',
    'Th10',
    'Th11',
    'Th12',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _showMonthPicker,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        color: TxaTheme.accent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_months[_selectedDate.month - 1]}, ${_selectedDate.year}',
                        style: const TextStyle(
                          color: TxaTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: TxaTheme.textMuted,
                        size: 16,
                      ),
                    ],
                  ),
                ),
                if (!_isSameDay(_selectedDate, _today))
                  GestureDetector(
                    onTap: () => setState(() {
                      _selectedDate = _today;
                      _pivotDate = _today;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: TxaTheme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        TxaLanguage.t('today'),
                        style: const TextStyle(
                          color: TxaTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Week Navigator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _changeWeek(-1),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: TxaTheme.textSecondary,
                      size: 22,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _getCurrentWeekDates().asMap().entries.map((
                      entry,
                    ) {
                      final i = entry.key;
                      final d = entry.value;
                      final isActive = _isSameDay(d, _selectedDate);
                      final isToday = _isSameDay(d, _today);
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedDate = d;
                          _pivotDate = d;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? TxaTheme.accent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _daysShort[i],
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : TxaTheme.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${d.day}',
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : (isToday
                                            ? TxaTheme.accent
                                            : TxaTheme.textPrimary),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isToday && !isActive) ...[
                                const SizedBox(height: 2),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: TxaTheme.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                GestureDetector(
                  onTap: () => _changeWeek(1),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: TxaTheme.textSecondary,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Divider(color: TxaTheme.glassBorder, height: 1),
          ),

          // Content
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: TxaTheme.accent,
              strokeWidth: 2,
            ),
            const SizedBox(height: 12),
            Text(
              TxaLanguage.t('loading_schedule'),
              style: const TextStyle(color: TxaTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            Text(
              "${TxaLanguage.t('error')}: $_error",
              style: const TextStyle(color: TxaTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _fetchSchedule,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(TxaLanguage.t('retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: TxaTheme.accent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    final movies = _getMoviesForDate(_selectedDate);
    if (movies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 40,
              color: TxaTheme.textMuted.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              _isSameDay(_selectedDate, _today)
                  ? TxaLanguage.t('no_schedule_today')
                  : TxaLanguage.t('no_schedule_date').replaceAll(
                      '%date',
                      '${_selectedDate.day}/${_selectedDate.month}',
                    ),
              style: const TextStyle(color: TxaTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        final movieId = movie['id']?.toString() ?? movie['slug'] ?? '';
        final isScheduled = TxaSettings.isMovieScheduled(movieId);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => MovieDetailScreen(
                  slug: movie['slug'] ?? movie['id']?.toString() ?? '',
                ),
              ),
            );
          },
          child: _ScheduleMovieCard(
            movie: movie,
            episodeLabel: _formatEpisodeLabel(movie),
            isScheduled: isScheduled,
            onTapNotification: () => _toggleNotification(movie),
          ),
        );
      },
    );
  }

  Future<void> _toggleNotification(dynamic movie) async {
    final movieId = movie['id']?.toString() ?? movie['slug'] ?? '';
    final isScheduled = TxaSettings.isMovieScheduled(movieId);

    final String movieName = movie['name'] ?? 'TPhimX';
    final int reminderId = '${movieId}_reminder'.hashCode;
    final int nowId = '${movieId}_now'.hashCode;

    if (isScheduled) {
      final notif = FlutterLocalNotificationsPlugin();
      await notif.cancel(id: reminderId);
      await notif.cancel(id: nowId);
      TxaSettings.setMovieScheduled(movieId, false);
      setState(() {});
      if (!mounted) return;
      TxaToast.show(context, TxaLanguage.t('notification_cancelled'));
      return;
    }

    if (await Permission.notification.isDenied) {
      final res = await Permission.notification.request();
      if (!res.isGranted) {
        if (!mounted) return;
        TxaToast.show(context, TxaLanguage.t('notification_permission_denied'));
        return;
      }
    }

    if (await Permission.scheduleExactAlarm.isDenied) {
      final res = await Permission.scheduleExactAlarm.request();
      if (!res.isGranted) {
        if (!mounted) return;
        TxaToast.show(
          context,
          TxaLanguage.t('exact_alarm_permission_denied'),
          isError: true,
        );
        return;
      }
    }

    final broadcastTime = movie['broadcast_time']?.toString() ?? '';
    if (broadcastTime.isEmpty) return;

    try {
      final timeParts = broadcastTime.split(':');
      if (timeParts.length < 2) return;

      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final DateTime targetTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        hour,
        minute,
      );

      final DateTime reminderTime = targetTime.subtract(
        const Duration(minutes: 10),
      );

      if (targetTime.isBefore(DateTime.now())) {
        if (!mounted) return;
        TxaToast.show(context, TxaLanguage.t('notification_time_passed'));
        return;
      }

      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidDetails = AndroidNotificationDetails(
        'schedule_reminders',
        'Schedule Reminders',
        channelDescription: 'Notifications for upcoming movie broadcasts',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(''),
      );
      const platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      // 1. Schedule Reminder Notification (10 mins before)
      if (reminderTime.isAfter(DateTime.now())) {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id: reminderId,
          title: TxaLanguage.t(
            'broadcast_reminder_title',
            replace: {'name': movieName},
          ),
          body: TxaLanguage.t(
            'broadcast_reminder_body',
            replace: {'movie': movieName, 'minutes': '10'},
          ),
          scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
          notificationDetails: platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }

      // 2. Schedule Now Notification (at exact time)
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: nowId,
        title: TxaLanguage.t(
          'broadcast_now_title',
          replace: {'name': movieName},
        ),
        body: TxaLanguage.t(
          'broadcast_now_body',
          replace: {'movie': movieName},
        ),
        scheduledDate: tz.TZDateTime.from(targetTime, tz.local),
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      TxaSettings.setMovieScheduled(movieId, true);
      setState(() {});
      if (!mounted) return;
      TxaToast.show(context, TxaLanguage.t('notification_scheduled'));
    } catch (e) {
      if (!mounted) return;
      TxaToast.show(context, "${TxaLanguage.t('error')}: $e");
    }
  }
}

class _ScheduleMovieCard extends StatelessWidget {
  final dynamic movie;
  final String episodeLabel;
  final bool isScheduled;
  final VoidCallback onTapNotification;

  const _ScheduleMovieCard({
    required this.movie,
    required this.episodeLabel,
    required this.isScheduled,
    required this.onTapNotification,
  });

  @override
  Widget build(BuildContext context) {
    final name = movie['name'] ?? '';
    final thumbUrl = movie['thumb_url'] ?? movie['poster_url'] ?? '';
    final broadcastTime = movie['broadcast_time'] ?? '';
    final quality = movie['quality'] ?? '';
    final lang = movie['lang'] ?? '';
    final cats = movie['categories'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: TxaTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TxaTheme.glassBorder),
      ),
      child: Row(
        children: [
          // Poster
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
            ),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: thumbUrl,
                  width: 80,
                  height: 110,
                  fit: BoxFit.cover,
                  placeholder: (ctx, url) => Container(
                    width: 80,
                    height: 110,
                    color: TxaTheme.secondaryBg,
                  ),
                  errorWidget: (ctx, url, err) => Container(
                    width: 80,
                    height: 110,
                    color: TxaTheme.secondaryBg,
                    child: const Icon(Icons.movie, color: TxaTheme.textMuted),
                  ),
                ),
                if (broadcastTime.isNotEmpty)
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: TxaTheme.accent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        broadcastTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (quality.isNotEmpty)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        quality,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TxaTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: TxaTheme.pink.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          episodeLabel,
                          style: const TextStyle(
                            color: TxaTheme.pink,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (lang.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: TxaTheme.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            lang,
                            style: const TextStyle(
                              color: TxaTheme.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (cats.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: cats
                          .take(2)
                          .map<Widget>(
                            (cat) => Text(
                              '#${cat['name'] ?? ''}',
                              style: TextStyle(
                                color: TxaTheme.textMuted.withValues(
                                  alpha: 0.7,
                                ),
                                fontSize: 10,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Bell icon
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              onPressed: onTapNotification,
              icon: Icon(
                isScheduled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: isScheduled
                    ? TxaTheme.accent
                    : TxaTheme.textMuted.withValues(alpha: 0.5),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
