import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/txa_api.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../widgets/txa_loading.dart';

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
    _changelogFuture = TxaApi().getChangelog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      body: Stack(
        children: [
          // Background Blobs (Liquid Design)
          Positioned(
            top: -50,
            right: -100,
            child: _buildBlob(TxaTheme.purple.withValues(alpha: 0.15)),
          ),
          Positioned(
            bottom: 100,
            left: -100,
            child: _buildBlob(TxaTheme.accent.withValues(alpha: 0.15)),
          ),
          
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Liquid AppBar
              SliverAppBar(
                expandedHeight: 120.0,
                floating: false,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: TxaTheme.accent),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          TxaLanguage.t('update_history'),
                          style: const TextStyle(
                            color: TxaTheme.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  background: Container(color: Colors.transparent),
                ),
              ),

              // Changelog Content
              SliverToBoxAdapter(
                child: FutureBuilder<List<dynamic>>(
                  future: _changelogFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 400,
                        child: Center(child: TxaLoading()),
                      );
                    }

                    if (snapshot.hasError) {
                      return SizedBox(
                        height: 400,
                        child: Center(
                          child: Text(
                            TxaLanguage.t('error_loading_data'),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      );
                    }

                    final logs = snapshot.data ?? [];
                    if (logs.isEmpty) {
                      return const SizedBox(
                        height: 400,
                        child: Center(
                          child: Text(
                            'Chưa có lịch sử cập nhật',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: logs.map((log) => _buildLogCard(log)).toList(),
                      ),
                    );
                  },
                ),
              ),
              
              const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlob(Color color) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final String version = log['version'] ?? 'Unknown';
    final String dateStr = log['date'] ?? '';
    final String title = log['title'] ?? '';
    final String content = log['content'] ?? '';
    
    // Auto-localized date
    String formattedDate = dateStr;
    try {
      final date = DateTime.parse(dateStr);
      formattedDate = DateFormat.yMMMMd(TxaLanguage.currentLang).format(date);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Version & Date)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: TxaTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(full),
                        border: Border.all(color: TxaTheme.accent.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: TxaTheme.purple.withValues(alpha: 0.2),
                            blurRadius: 10,
                          )
                        ],
                      ),
                      child: Text(
                        'v$version',
                        style: const TextStyle(
                          color: TxaTheme.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Title
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Content (Changelog)
                Text(
                  content,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  static const double full = 999;
}
