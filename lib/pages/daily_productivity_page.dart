import 'dart:convert';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/utils/responsive_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Level produktivitas berdasarkan jumlah kegiatan/tugas yang diselesaikan dalam 1 hari
enum ProductivityLevel {
  none, // 0
  low, // 1 - 2
  medium, // 3 - 5
  high, // 6 - 8
  veryHigh, // 8 - 10
  crown, // > 10
}

class ProductivityHelper {
  static ProductivityLevel getLevel(int count) {
    if (count <= 0) return ProductivityLevel.none;
    if (count <= 2) return ProductivityLevel.low;
    if (count <= 5) return ProductivityLevel.medium;
    if (count <= 8) return ProductivityLevel.high;
    if (count <= 10) return ProductivityLevel.veryHigh;
    return ProductivityLevel.crown;
  }

  static Color getCellColor(ProductivityLevel level) {
    switch (level) {
      case ProductivityLevel.none:
        return const Color(0xFFF1F5F9); // Abu-abu netral lembut
      case ProductivityLevel.low:
        return const Color(0xFFBBF7D0); // Hijau samar (Light pastel green)
      case ProductivityLevel.medium:
        return const Color(0xFF4ADE80); // Hijau sedang (Mid green)
      case ProductivityLevel.high:
        return const Color(0xFF16A34A); // Hijau lebih terang (Strong vibrant green)
      case ProductivityLevel.veryHigh:
        return const Color(0xFF15803D); // Hijau sangat terang/pekat (Deep rich green)
      case ProductivityLevel.crown:
        return const Color(0xFF0F766E); // Royal emerald base with gold crown
    }
  }

  static Color getTextColor(ProductivityLevel level) {
    switch (level) {
      case ProductivityLevel.none:
        return const Color(0xFF64748B);
      case ProductivityLevel.low:
        return const Color(0xFF14532D);
      case ProductivityLevel.medium:
        return const Color(0xFF052E16);
      case ProductivityLevel.high:
      case ProductivityLevel.veryHigh:
      case ProductivityLevel.crown:
        return Colors.white;
    }
  }

  static String getLevelLabel(ProductivityLevel level) {
    switch (level) {
      case ProductivityLevel.none:
        return 'Belum Ada Kegiatan';
      case ProductivityLevel.low:
        return 'Ringan (1-2 Kegiatan)';
      case ProductivityLevel.medium:
        return 'Produktif (3-5 Kegiatan)';
      case ProductivityLevel.high:
        return 'Sangat Aktif (6-8 Kegiatan)';
      case ProductivityLevel.veryHigh:
        return 'Luar Biasa (8-10 Kegiatan)';
      case ProductivityLevel.crown:
        return 'Mahkota Juara (>10 Kegiatan)';
    }
  }

  static String getLevelShortBadge(ProductivityLevel level) {
    switch (level) {
      case ProductivityLevel.none:
        return '0';
      case ProductivityLevel.low:
        return '1-2';
      case ProductivityLevel.medium:
        return '3-5';
      case ProductivityLevel.high:
        return '6-8';
      case ProductivityLevel.veryHigh:
        return '8-10';
      case ProductivityLevel.crown:
        return '>10';
    }
  }
}

class DailyProductivityPage extends StatefulWidget {
  const DailyProductivityPage({super.key});

  @override
  State<DailyProductivityPage> createState() => _DailyProductivityPageState();
}

class _DailyProductivityPageState extends State<DailyProductivityPage> {
  static const Color primaryTerracotta = Color(0xFFBA5A3A);
  static const String _prefsKey = 'daily_apps_todo_groups_v1';

  late DateTime _selectedMonth;
  DateTime? _selectedDateDetail;
  List<TodoDateGroup> _allGroups = [];
  bool _isLoading = true;

  static const List<String> _namaBulan = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember'
  ];

  static const List<String> _namaHariSingkat = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _selectedDateDetail = DateTime(now.year, now.month, now.day);
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
      }
    } catch (e) {
      debugPrint('Error loading productivity data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<DateTime, List<TodoItem>> get _completedTasksByDate {
    final Map<DateTime, List<TodoItem>> map = {};
    for (final group in _allGroups) {
      final key = DateTime(group.date.year, group.date.month, group.date.day);
      final completed = group.items.where((item) => item.isCompleted).toList();
      if (completed.isNotEmpty) {
        if (map.containsKey(key)) {
          map[key]!.addAll(completed);
        } else {
          map[key] = List.from(completed);
        }
      }
    }
    return map;
  }

  int _getCompletedCountForDate(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    return _completedTasksByDate[key]?.length ?? 0;
  }

  List<TodoItem> _getCompletedItemsForDate(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    return _completedTasksByDate[key] ?? [];
  }

  void _previousMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
        1,
      );
      _selectedDateDetail = null;
    });
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      );
      _selectedDateDetail = null;
    });
  }

  void _goToCurrentMonth() {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    setState(() {
      _selectedMonth = DateTime(now.year, now.month, 1);
      _selectedDateDetail = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = _selectedMonth.year == now.year &&
        _selectedMonth.month == now.month;

    final completedMap = _completedTasksByDate;

    // Statistik bulan terpilih
    int monthTotalCompleted = 0;
    int monthActiveDays = 0;
    int monthCrownDays = 0;
    final daysInSelectedMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;

    for (int day = 1; day <= daysInSelectedMonth; day++) {
      final dateKey =
          DateTime(_selectedMonth.year, _selectedMonth.month, day);
      final count = completedMap[dateKey]?.length ?? 0;
      if (count > 0) {
        monthTotalCompleted += count;
        monthActiveDays += 1;
        if (count > 10) {
          monthCrownDays += 1;
        }
      }
    }

    final todayKey = DateTime(now.year, now.month, now.day);
    final todayCount = completedMap[todayKey]?.length ?? 0;
    final todayLevel = ProductivityHelper.getLevel(todayCount);

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F6),
      appBar: AppBar(
        backgroundColor: primaryTerracotta,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Activity',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryTerracotta),
            )
          : RefreshIndicator(
              onRefresh: _loadAllTodoData,
              color: primaryTerracotta,
              child: ResponsiveContentWrapper(
                maxWidth: 680,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    // Today Quick Status Card
                    _buildTodayQuickCard(todayCount, todayLevel),
                    const SizedBox(height: 14),

                    // Month Navigator & Metrics Card
                    _buildMonthOverviewCard(
                      monthTotalCompleted: monthTotalCompleted,
                      monthActiveDays: monthActiveDays,
                      monthCrownDays: monthCrownDays,
                      isCurrentMonth: isCurrentMonth,
                    ),
                    const SizedBox(height: 14),

                    // Strava Heatmap Calendar Card
                    _buildCalendarCard(),
                    const SizedBox(height: 14),

                    // Legend Classification Card
                    _buildLegendCard(),
                    const SizedBox(height: 14),

                    // Selected Date Detail Card
                    if (_selectedDateDetail != null) ...[
                      _buildDateDetailCard(_selectedDateDetail!),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTodayQuickCard(int count, ProductivityLevel level) {
    final cellColor = ProductivityHelper.getCellColor(level);
    final isCrown = level == ProductivityLevel.crown;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCrown
              ? const Color(0xFFEAB308)
              : (count > 0
                  ? const Color(0xFF16A34A).withValues(alpha: 0.3)
                  : const Color(0xFFE2E8F0)),
          width: isCrown ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isCrown
                ? const Color(0xFFEAB308).withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: isCrown
                  ? const LinearGradient(
                      colors: [Color(0xFFCA8A04), Color(0xFF047857)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isCrown ? null : cellColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCrown
                    ? const Color(0xFFFDE047)
                    : (count > 0
                        ? const Color(0xFF16A34A).withValues(alpha: 0.4)
                        : const Color(0xFFCBD5E1)),
                width: 1.2,
              ),
            ),
            child: Center(
              child: isCrown
                  ? const Text('👑', style: TextStyle(fontSize: 24))
                  : Icon(
                      count > 0
                          ? Icons.local_fire_department_rounded
                          : Icons.hourglass_empty_rounded,
                      color: count > 0
                          ? ProductivityHelper.getTextColor(level)
                          : const Color(0xFF94A3B8),
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Produktivitas Hari Ini',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isCrown
                            ? const Color(0xFFFEF08A)
                            : (count > 0
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCrown
                            ? '👑 Mahkota'
                            : '${ProductivityHelper.getLevelShortBadge(level)} Selesai',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isCrown
                              ? const Color(0xFF854D0E)
                              : (count > 0
                                  ? const Color(0xFF166534)
                                  : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$count Kegiatan Diselesaikan',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthOverviewCard({
    required int monthTotalCompleted,
    required int monthActiveDays,
    required int monthCrownDays,
    required bool isCurrentMonth,
  }) {
    final monthName = _namaBulan[_selectedMonth.month - 1];
    final year = _selectedMonth.year;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Month Selector Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 24),
                onPressed: _previousMonth,
                visualDensity: VisualDensity.compact,
                tooltip: 'Bulan Sebelumnya',
              ),
              InkWell(
                onTap: isCurrentMonth ? null : _goToCurrentMonth,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$monthName $year',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (!isCurrentMonth) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primaryTerracotta.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Bulan Ini',
                            style: TextStyle(
                              fontSize: 10,
                              color: primaryTerracotta,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 24),
                onPressed: _nextMonth,
                visualDensity: VisualDensity.compact,
                tooltip: 'Bulan Berikutnya',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3 Metric Pills
          Row(
            children: [
              _buildMiniMetric(
                label: 'Total Selesai',
                value: '$monthTotalCompleted',
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF16A34A),
              ),
              const SizedBox(width: 8),
              _buildMiniMetric(
                label: 'Hari Aktif',
                value: '$monthActiveDays Hari',
                icon: Icons.event_available_rounded,
                color: primaryTerracotta,
              ),
              const SizedBox(width: 8),
              _buildMiniMetric(
                label: 'Hari Mahkota',
                value: '$monthCrownDays Hari',
                icon: Icons.emoji_events_rounded,
                color: const Color(0xFFCA8A04),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    final year = _selectedMonth.year;
    final month = _selectedMonth.month;
    final totalDays = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1 = Mon, 7 = Sun
    final now = DateTime.now();

    final completedMap = _completedTasksByDate;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 20,
                color: primaryTerracotta,
              ),
              SizedBox(width: 8),
              Text(
                'Kalender Aktivitas Harian',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Intensitas warna diukur dari kegiatan to-do yang selesai tiap hari.',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),

          // Row Hari Singkat (Sen, Sel, Rab, Kam, Jum, Sab, Min)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final isWeekend = index >= 5;
              return Expanded(
                child: Center(
                  child: Text(
                    _namaHariSingkat[index],
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isWeekend
                          ? primaryTerracotta.withValues(alpha: 0.85)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),

          // Grid Tanggal (Heatmap Cells)
          _buildHeatmapGrid(
            year: year,
            month: month,
            totalDays: totalDays,
            firstWeekday: firstWeekday,
            now: now,
            completedMap: completedMap,
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapGrid({
    required int year,
    required int month,
    required int totalDays,
    required int firstWeekday,
    required DateTime now,
    required Map<DateTime, List<TodoItem>> completedMap,
  }) {
    final List<Widget> rows = [];
    int currentDay = 1;
    final leadingEmpty = firstWeekday - 1;

    while (currentDay <= totalDays) {
      final List<Widget> dayWidgets = [];

      for (int i = 0; i < 7; i++) {
        if (rows.isEmpty && i < leadingEmpty) {
          dayWidgets.add(
            const Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: SizedBox(),
              ),
            ),
          );
        } else if (currentDay <= totalDays) {
          final date = DateTime(year, month, currentDay);
          final isToday = date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
          final isSelected = _selectedDateDetail != null &&
              _selectedDateDetail!.year == date.year &&
              _selectedDateDetail!.month == date.month &&
              _selectedDateDetail!.day == date.day;

          final count = _getCompletedCountForDate(date);
          final level = ProductivityHelper.getLevel(count);

          dayWidgets.add(
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildHeatmapCell(
                  date: date,
                  dayNumber: currentDay,
                  count: count,
                  level: level,
                  isToday: isToday,
                  isSelected: isSelected,
                ),
              ),
            ),
          );
          currentDay++;
        } else {
          dayWidgets.add(
            const Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: SizedBox(),
              ),
            ),
          );
        }
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: dayWidgets,
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildHeatmapCell({
    required DateTime date,
    required int dayNumber,
    required int count,
    required ProductivityLevel level,
    required bool isToday,
    required bool isSelected,
  }) {
    final cellColor = ProductivityHelper.getCellColor(level);
    final textColor = ProductivityHelper.getTextColor(level);
    final isCrown = level == ProductivityLevel.crown;

    return Padding(
      padding: const EdgeInsets.all(2.5),
      child: Tooltip(
        message:
            '$dayNumber ${_namaBulan[date.month - 1]}: $count kegiatan selesai',
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedDateDetail = date;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: isCrown
                  ? const LinearGradient(
                      colors: [Color(0xFFCA8A04), Color(0xFF047857)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isCrown ? null : cellColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? primaryTerracotta
                    : (isToday
                        ? const Color(0xFF2563EB)
                        : (isCrown
                            ? const Color(0xFFFDE047)
                            : (count > 0
                                ? const Color(0xFF16A34A).withValues(alpha: 0.3)
                                : const Color(0xFFE2E8F0)))),
                width: (isSelected || isToday || isCrown) ? 2 : 1,
              ),
              boxShadow: isCrown
                  ? [
                      BoxShadow(
                        color: const Color(0xFFCA8A04).withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : (isSelected
                      ? [
                          BoxShadow(
                            color: primaryTerracotta.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Text(
                    '$dayNumber',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: (count > 0 || isToday || isSelected)
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
                if (isCrown)
                  const Positioned(
                    top: 1,
                    right: 1,
                    child: Text(
                      '👑',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                if (isToday && !isCrown)
                  Positioned(
                    bottom: 2.5,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: count > 2 ? Colors.white : const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: Color(0xFF64748B)),
              SizedBox(width: 6),
              Text(
                'Klasifikasi Produktivitas',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildLegendItem(
                level: ProductivityLevel.none,
                label: '0 (Kosong)',
              ),
              _buildLegendItem(
                level: ProductivityLevel.low,
                label: '1 - 2',
              ),
              _buildLegendItem(
                level: ProductivityLevel.medium,
                label: '3 - 5',
              ),
              _buildLegendItem(
                level: ProductivityLevel.high,
                label: '6 - 8',
              ),
              _buildLegendItem(
                level: ProductivityLevel.veryHigh,
                label: '8 - 10',
              ),
              _buildLegendItem(
                level: ProductivityLevel.crown,
                label: '>10 👑',
                isCrown: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required ProductivityLevel level,
    required String label,
    bool isCrown = false,
  }) {
    final cellColor = ProductivityHelper.getCellColor(level);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            gradient: isCrown
                ? const LinearGradient(
                    colors: [Color(0xFFCA8A04), Color(0xFF047857)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isCrown ? null : cellColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isCrown
                  ? const Color(0xFFFDE047)
                  : const Color(0xFFCBD5E1),
              width: 1,
            ),
          ),
          child: isCrown
              ? const Center(
                  child: Text(
                    '👑',
                    style: TextStyle(fontSize: 9),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDateDetailCard(DateTime date) {
    final count = _getCompletedCountForDate(date);
    final items = _getCompletedItemsForDate(date);
    final level = ProductivityHelper.getLevel(count);
    final levelLabel = ProductivityHelper.getLevelLabel(level);
    final isCrown = level == ProductivityLevel.crown;

    final dateStr =
        '${date.day} ${_namaBulan[date.month - 1]} ${date.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCrown
              ? const Color(0xFFEAB308)
              : primaryTerracotta.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isCrown
                ? const Color(0xFFEAB308).withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.04),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCrown
                      ? const Color(0xFFFEF08A)
                      : (count > 0
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCrown
                      ? Icons.emoji_events_rounded
                      : (count > 0
                          ? Icons.task_alt_rounded
                          : Icons.event_busy_rounded),
                  color: isCrown
                      ? const Color(0xFF854D0E)
                      : (count > 0
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF64748B)),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      levelLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isCrown
                            ? const Color(0xFF854D0E)
                            : (count > 0
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          if (items.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Belum ada kegiatan yang diselesaikan pada tanggal ini.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF94A3B8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ] else ...[
            Text(
              '${items.length} Tugas Selesai:',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 15,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
