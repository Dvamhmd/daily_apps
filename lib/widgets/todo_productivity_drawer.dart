import 'dart:convert';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/pages/daily_productivity_page.dart';
import 'package:daily_apps/pages/todo_riwayat_page.dart';
import 'package:daily_apps/pages/tugas_harian_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TodoProductivityDrawer extends StatefulWidget {
  final List<TodoDateGroup> activeGroups;
  final VoidCallback? onDataChanged;

  const TodoProductivityDrawer({
    super.key,
    required this.activeGroups,
    this.onDataChanged,
  });

  @override
  State<TodoProductivityDrawer> createState() => _TodoProductivityDrawerState();
}

class _TodoProductivityDrawerState extends State<TodoProductivityDrawer> {
  static const Color primaryTerracotta = Color(0xFFBA5A3A);
  static const Color darkTerracotta = Color(0xFF8C3E26);
  static const String _prefsKey = 'daily_apps_todo_groups_v1';

  List<TodoDateGroup> _allGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllTodoData();
  }

  Future<void> _loadAllTodoData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _allGroups = decoded
            .map((item) => TodoDateGroup.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        _allGroups = List.from(widget.activeGroups);
      }
    } catch (e) {
      _allGroups = List.from(widget.activeGroups);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int get _todayCompletedCount {
    final now = DateTime.now();
    int count = 0;
    for (final group in _allGroups) {
      if (group.date.year == now.year &&
          group.date.month == now.month &&
          group.date.day == now.day) {
        count += group.completedCount;
      }
    }
    return count;
  }

  int get _thisMonthCompletedCount {
    final now = DateTime.now();
    int count = 0;
    for (final group in _allGroups) {
      if (group.date.year == now.year && group.date.month == now.month) {
        count += group.completedCount;
      }
    }
    return count;
  }

  int get _totalAllCompletedCount {
    int count = 0;
    for (final group in _allGroups) {
      count += group.completedCount;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final todayCount = _todayCompletedCount;
    final level = ProductivityHelper.getLevel(todayCount);
    final isCrown = level == ProductivityLevel.king;
    final isOverload = level == ProductivityLevel.overload;
    final statusTitle = ProductivityHelper.getLevelLabel(level);
    final statusDesc = todayCount == 0
        ? 'Belum ada to-do yang selesai hari ini. Yuk mulai selesaikan tugasmu!'
        : ProductivityHelper.getPraiseQuote(level);

    return Drawer(
      backgroundColor: const Color(0xFFF7F9FC),
      child: Column(
        children: [
          // Drawer Header with gradient Terracotta
          _buildDrawerHeader(),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryTerracotta),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    children: [
                      // Top Quick Productivity Card
                      _buildQuickStatusCard(
                        todayCount: todayCount,
                        isCrown: isCrown,
                        isOverload: isOverload,
                        level: level,
                        statusTitle: statusTitle,
                        statusDesc: statusDesc,
                      ),

                      const SizedBox(height: 18),
                      Text(
                        'FITUR & MENU',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Menu 1: Tugas Harian (Set Up Grup Aktivitas)
                      _buildMenuItem(
                        context: context,
                        icon: Icons.event_repeat_rounded,
                        iconColor: const Color(0xFFE65100),
                        title: 'Tugas Harian',
                        subtitle: 'Set up grup aktivitas & terapkan ke section',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TugasHarianPage(),
                            ),
                          ).then((_) {
                            if (widget.onDataChanged != null) {
                              widget.onDataChanged!();
                            }
                            _loadAllTodoData();
                          });
                        },
                      ),

                      // Menu 2: Activity
                      _buildMenuItem(
                        context: context,
                        icon: Icons.insights_rounded,
                        iconColor: primaryTerracotta,
                        title: 'Activity',
                        subtitle: 'Kalender aktivitas harian & pencapaian',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DailyProductivityPage(),
                            ),
                          ).then((_) {
                            if (widget.onDataChanged != null) {
                              widget.onDataChanged!();
                            }
                            _loadAllTodoData();
                          });
                        },
                      ),

                      // Menu 3: Riwayat Task
                      _buildMenuItem(
                        context: context,
                        icon: Icons.history_rounded,
                        iconColor: const Color(0xFF1976D2),
                        title: 'Riwayat Task',
                        subtitle: 'Arsip daftar task yang telah selesai',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TodoRiwayatPage(),
                            ),
                          ).then((_) {
                            if (widget.onDataChanged != null) {
                              widget.onDataChanged!();
                            }
                            _loadAllTodoData();
                          });
                        },
                      ),
                    ],
                  ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Daily Apps v2.1.0',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[400],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryTerracotta, darkTerracotta],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.checklist_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Apps',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'To-Do List & Activity',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatusCard({
    required int todayCount,
    required bool isCrown,
    required bool isOverload,
    required ProductivityLevel level,
    required String statusTitle,
    required String statusDesc,
  }) {
    final statusColor = isOverload
        ? const Color(0xFFEF4444)
        : (isCrown
            ? const Color(0xFFD97706)
            : (todayCount > 0
                ? const Color(0xFF16A34A)
                : const Color(0xFF64748B)));

    if (isOverload) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF09090B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFEF4444),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('💀', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusTitle,
                    style: const TextStyle(
                      color: Color(0xFFFCA5A5),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              statusDesc,
              style: const TextStyle(
                color: Color(0xFFFECACA),
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const Divider(height: 18, color: Color(0xFF27272A)),
            // Mini Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildMiniStat(
                    'Hari Ini',
                    '$todayCount Selesai',
                    const Color(0xFFEF4444),
                    isDark: true,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMiniStat(
                    'Bulan Ini',
                    '$_thisMonthCompletedCount Selesai',
                    const Color(0xFFF87171),
                    isDark: true,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMiniStat(
                    'Total Selesai',
                    '$_totalAllCompletedCount',
                    const Color(0xFFE2E8F0),
                    isDark: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCrown
                    ? Icons.emoji_events_rounded
                    : (todayCount > 0
                        ? Icons.local_fire_department_rounded
                        : Icons.spa_rounded),
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                statusTitle,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            statusDesc,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const Divider(height: 18),
          // Mini Stats Row
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  'Hari Ini',
                  '$todayCount Selesai',
                  statusColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniStat(
                  'Bulan Ini',
                  '$_thisMonthCompletedCount Selesai',
                  primaryTerracotta,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniStat(
                  'Total Selesai',
                  '$_totalAllCompletedCount',
                  const Color(0xFF1976D2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color, {bool isDark = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? const Color(0xFF94A3B8) : Colors.grey[500],
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badgeText,
    Color? badgeColor,
    Color? badgeTextColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor ?? const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeTextColor ?? const Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
