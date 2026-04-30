import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/txa_api.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../widgets/txa_loading.dart';
import '../utils/txa_logger.dart';
import '../utils/txa_format.dart';

class UpdateHistoryScreen extends StatefulWidget {
  const UpdateHistoryScreen({super.key});

  @override
  State<UpdateHistoryScreen> createState() => _UpdateHistoryScreenState();
}

class _UpdateHistoryScreenState extends State<UpdateHistoryScreen> {
  late Future<List<dynamic>> _changelogFuture;

  @override
  void initState() {
    super.initState();
    _loadChangelog();
  }

  void _loadChangelog() {
    setState(() {
      _changelogFuture = TxaApi()
          .getChangelog()
          .then((data) {
            TxaLogger.log(
              'Successfully fetched ${data.length} update entries',
              tag: 'UPDATE',
              type: 'update',
            );
            return data;
          })
          .catchError((e) {
            TxaLogger.log(
              'Failed to fetch changelog: $e',
              isError: true,
              tag: 'UPDATE',
              type: 'update',
            );
            throw e;
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      body: Stack(
        children: [
          // Background Blobs for depth
          Positioned(
            top: -150,
            right: -100,
            child: _buildBlob(TxaTheme.purple.withValues(alpha: 0.1)),
          ),
          Positioned(
            bottom: 100,
            left: -150,
            child: _buildBlob(TxaTheme.accent.withValues(alpha: 0.08)),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Premium App Bar
              SliverAppBar(
                expandedHeight: 160.0,
                floating: false,
                pinned: true,
                backgroundColor: TxaTheme.primaryBg.withValues(alpha: 0.8),
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(
                    TxaLanguage.t('update_history'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 2,
                    ),
                  ),
                  background: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              TxaTheme.accent.withValues(alpha: 0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 40,
                        child: Icon(
                          Icons.history_rounded,
                          size: 60,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ],
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: TxaTheme.accent,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                sliver: FutureBuilder<List<dynamic>>(
                  future: _changelogFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverFillRemaining(
                        child: Center(child: TxaLoading()),
                      );
                    }

                    if (snapshot.hasError) {
                      return SliverFillRemaining(child: _buildErrorState());
                    }

                    final logs = snapshot.data ?? [];
                    if (logs.isEmpty) {
                      return SliverFillRemaining(child: _buildEmptyState());
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return _buildPremiumTimelineItem(
                          logs[index],
                          isFirst: index == 0,
                          isLast: index == logs.length - 1,
                        );
                      }, childCount: logs.length),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlob(Color color) {
    return Container(
      width: 500,
      height: 500,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: Colors.red.withValues(alpha: 0.3),
            size: 80,
          ),
          const SizedBox(height: 16),
          Text(
            TxaLanguage.t('error_loading_data'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _loadChangelog,
            icon: const Icon(Icons.refresh),
            label: Text(TxaLanguage.t('retry')),
            style: TextButton.styleFrom(
              foregroundColor: TxaTheme.accent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: TxaTheme.accent, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded, color: Colors.white10, size: 80),
          const SizedBox(height: 16),
          Text(
            TxaLanguage.t('no_changelog'),
            style: const TextStyle(color: Colors.white24, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTimelineItem(
    Map<String, dynamic> log, {
    required bool isFirst,
    required bool isLast,
  }) {
    final String version = log['version'] ?? '?.?.?';
    final String dateStr = log['date'] ?? '';
    final String title = log['title'] ?? '';
    final String content = log['content'] ?? '';

    // Logic to determine update type (just for visual flair)
    Color typeColor = TxaTheme.accent;
    IconData typeIcon = Icons.auto_awesome;

    final lowerTitle = title.toLowerCase();
    final lowerContent = content.toLowerCase();

    if (lowerTitle.contains('fix') ||
        lowerContent.contains('sửa') ||
        lowerTitle.contains('lỗi')) {
      typeColor = Colors.orangeAccent;
      typeIcon = Icons.bug_report_rounded;
    } else if (lowerTitle.contains('feature') ||
        lowerTitle.contains('mới') ||
        lowerContent.contains('tính năng')) {
      typeColor = Colors.greenAccent;
      typeIcon = Icons.add_circle_outline_rounded;
    } else if (lowerTitle.contains('performance') ||
        lowerTitle.contains('hiệu năng') ||
        lowerTitle.contains('tối ưu')) {
      typeColor = Colors.blueAccent;
      typeIcon = Icons.speed_rounded;
    }

    String formattedDate = dateStr;
    try {
      final date = DateTime.parse(dateStr);
      formattedDate = TxaFormat.formatDate(date);
    } catch (_) {}

    return IntrinsicHeight(
      child: Row(
        children: [
          // Timeline Column
          SizedBox(
            width: 60,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 30,
                  color: isFirst ? Colors.transparent : Colors.white10,
                ),
                // Glowing Indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TxaTheme.primaryBg,
                    border: Border.all(color: typeColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: typeColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(typeIcon, size: 12, color: typeColor),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : Colors.white10,
                  ),
                ),
              ],
            ),
          ),

          // Card Column
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 30),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with gradient line
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                typeColor.withValues(alpha: 0.1),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'v$version',
                                style: TextStyle(
                                  color: typeColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Body
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                content,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 13,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
