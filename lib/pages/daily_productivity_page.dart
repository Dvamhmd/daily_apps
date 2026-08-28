import 'dart:convert';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/utils/responsive_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Level produktivitas berdasarkan jumlah kegiatan/tugas yang diselesaikan dalam 1 hari
enum ProductivityLevel {
  none, // 0
  lazy, // 1 - 2
  okay, // 3 - 5
  good, // 6 - 8
  amazing, // 9 - 10
  king, // 11 - 15
  overload, // > 15
}

class ProductivityHelper {
  static ProductivityLevel getLevel(int count) {
    if (count <= 0) return ProductivityLevel.none;
    if (count <= 2) return ProductivityLevel.lazy;
    if (count <= 5) return ProductivityLevel.okay;
    if (count <= 8) return ProductivityLevel.good;
    if (count <= 10) return ProductivityLevel.amazing;
    if (count <= 15) return ProductivityLevel.king;
    return ProductivityLevel.overload;
  }

  static Color getCellColor(ProductivityLevel level) {
    switch (level) {
      case ProductivityLevel.none:
        return const Color(0xFFF1F5F9); // Abu-abu netral lembut
      case ProductivityLevel.lazy:
        return const Color(0xFFDCFCE7); // Hijau sangat muda
      case ProductivityLevel.okay:
        return const Color(0xFF86EFAC); // Hijau muda segar
      case ProductivityLevel.good:
        return const Color(0xFF22C55E); // Hijau sedang
      case ProductivityLevel.amazing:
        return const Color(0xFF15803D); // Hijau pekat
      case ProductivityLevel.king:
        return const Color(0xFFD97706); // Emas / Amber
      case ProductivityLevel.overload:
        return const Color(0xFF09090B); // Hitam pekat
    }
  }

  static Color getTextColor(ProductivityLevel level) {
    switch (level) {
      case ProductivityLevel.none:
        return const Color(0xFF64748B);
      case ProductivityLevel.lazy:
        return const Color(0xFF166534);
      case ProductivityLevel.okay:
        return const Color(0xFF064E3B);
      case ProductivityLevel.good:
      case ProductivityLevel.amazing:
      case ProductivityLevel.king:
      case ProductivityLevel.overload:
        return Colors.white;
    }
  }

  static String getPraiseQuote(ProductivityLevel level) {
    switch (level) {
      case ProductivityLevel.none:
        return 'Belum ada kegiatan yang diselesaikan.';
      case ProductivityLevel.lazy:
        return 'huuu, dasar pemalas 😜';
      case ProductivityLevel.okay:
        return 'B aja sih, tapi okeelah 😌';
      case ProductivityLevel.good:
        return 'Boleh jugaa nih, yukk pertahankan!! 💪';
      case ProductivityLevel.amazing:
        return 'Kamu luar biasaaa, semangattt!!! 🤩';
      case ProductivityLevel.king:
        return 'Anjayy kelas king 👑, kamu memang legenda';
      case ProductivityLevel.overload:
        return 'kerja boleh, tapi jangan maksain diri yaa 🥺, kamu boleh istirahat kok kalo capek, jaga kesehatan yaa, kita sayang kamu ❤️';
    }
  }

  static String getLevelLabel(ProductivityLevel level) {
    switch (level) {
      case ProductivityLevel.none:
        return 'Belum Ada Kegiatan 🌱';
      case ProductivityLevel.lazy:
        return '1 - 2 Kegiatan 😜';
      case ProductivityLevel.okay:
        return '3 - 5 Kegiatan 😌';
      case ProductivityLevel.good:
        return '6 - 8 Kegiatan 💪';
      case ProductivityLevel.amazing:
        return '9 - 10 Kegiatan 🤩';
      case ProductivityLevel.king:
        return '11 - 15 Kegiatan 👑';
      case ProductivityLevel.overload:
        return '>15 Kegiatan 💀';
    }
  }

  static String getLevelShortBadge(ProductivityLevel level) {
    switch (level) {
      case ProductivityLevel.none:
        return '0';
      case ProductivityLevel.lazy:
        return '1-2';
      case ProductivityLevel.okay:
        return '3-5';
      case ProductivityLevel.good:
        return '6-8';
      case ProductivityLevel.amazing:
        return '9-10';
      case ProductivityLevel.king:
        return '11-15';
      case ProductivityLevel.overload:
        return '>15';
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
  bool _isActivitiesExpanded = false;

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
        if (count >= 11) {
          monthCrownDays += 1;
        }
      }
    }

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
                    // Month Navigator & Metrics Card
                    _buildMonthOverviewCard(
                      monthTotalCompleted: monthTotalCompleted,
                      monthActiveDays: monthActiveDays,
                      monthCrownDays: monthCrownDays,
                      isCurrentMonth: isCurrentMonth,
                    ),
                    const SizedBox(height: 14),

                    // Strava Heatmap Calendar Card with Inline Expandable Detail
                    _buildCalendarCard(),
                  ],
                ),
              ),
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
                label: 'Juara & King',
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
            'Klik tanggal untuk melihat pencapaian dan daftar aktivitas harian.',
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

          // Selected Date Detail Section (Inline & Expandable)
          if (_selectedDateDetail != null) ...[
            const SizedBox(height: 14),
            _buildDateDetailInline(_selectedDateDetail!),
          ],
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
    final isCrown = level == ProductivityLevel.king;
    final isOverload = level == ProductivityLevel.overload;

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
                      colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
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
                        : (isOverload
                            ? const Color(0xFFEF4444)
                            : (isCrown
                                ? const Color(0xFFFDE68A)
                                : (count > 0
                                    ? const Color(0xFF16A34A).withValues(alpha: 0.3)
                                    : const Color(0xFFE2E8F0))))),
                width: (isSelected || isToday || isCrown || isOverload) ? 2 : 1,
              ),
              boxShadow: isOverload
                  ? [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : (isCrown
                      ? [
                          BoxShadow(
                            color: const Color(0xFFD97706).withValues(alpha: 0.45),
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
                          : null)),
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
                      shadows: (isCrown || isOverload)
                          ? [
                              const Shadow(
                                color: Colors.black38,
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
                if (isCrown)
                  const Positioned(
                    top: 1,
                    right: 1.5,
                    child: Text(
                      '👑',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                if (isOverload)
                  const Positioned(
                    top: 1,
                    right: 1.5,
                    child: Text(
                      '💀',
                      style: TextStyle(fontSize: 9.5),
                    ),
                  ),
                if (isToday && !isCrown && !isOverload)
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

  Widget _buildDateDetailInline(DateTime date) {
    final count = _getCompletedCountForDate(date);
    final items = _getCompletedItemsForDate(date);
    final level = ProductivityHelper.getLevel(count);
    final isCrown = level == ProductivityLevel.king;
    final isOverload = level == ProductivityLevel.overload;
    final praiseQuote = ProductivityHelper.getPraiseQuote(level);

    final dateStr =
        '${date.day} ${_namaBulan[date.month - 1]} ${date.year}';

    if (isOverload) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF09090B), // Hitam pekat
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFEF4444), // Border merah
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Tanggal & Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFEF4444),
                      width: 1.2,
                    ),
                  ),
                  child: const Text(
                    '💀',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '$count Kegiatan Selesai',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFCA5A5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF450A0A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                    ),
                  ),
                  child: const Text(
                    '💀 >15',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFCA5A5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Kata-kata Pujian / Pesan Peduli
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                praiseQuote,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFFECACA),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),

            if (items.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isActivitiesExpanded = !_isActivitiesExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      Text(
                        '${items.length} Aktivitas Dikerjakan',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE2E8F0),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isActivitiesExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: const Color(0xFFF87171),
                      ),
                      const Spacer(),
                      Text(
                        _isActivitiesExpanded ? 'Tutup' : 'Lihat Detail',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFFF87171),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    children: items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).toList(),
                  ),
                ),
                crossFadeState: _isActivitiesExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ] else ...[
              const SizedBox(height: 6),
              const Text(
                'Belum ada kegiatan yang diselesaikan pada tanggal ini.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF94A3B8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCrown
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCrown
              ? const Color(0xFFF59E0B)
              : (count > 0
                  ? primaryTerracotta.withValues(alpha: 0.3)
                  : const Color(0xFFE2E8F0)),
          width: isCrown ? 1.5 : 1.2,
        ),
        boxShadow: isCrown
            ? [
                BoxShadow(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Tanggal & Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: isCrown
                      ? const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isCrown
                      ? null
                      : (count > 0
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isCrown
                      ? Icons.emoji_events_rounded
                      : (count > 0
                          ? Icons.task_alt_rounded
                          : Icons.event_busy_rounded),
                  color: isCrown
                      ? Colors.white
                      : (count > 0
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF64748B)),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      count > 0
                          ? '$count Kegiatan Selesai'
                          : 'Belum ada kegiatan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isCrown
                            ? const Color(0xFFB45309)
                            : (count > 0
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isCrown
                        ? const Color(0xFFFEF08A)
                        : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isCrown
                        ? '👑 11-15'
                        : '${ProductivityHelper.getLevelShortBadge(level)} Selesai',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isCrown
                          ? const Color(0xFF854D0E)
                          : const Color(0xFF166534),
                    ),
                  ),
                ),
            ],
          ),

          if (count > 0) ...[
            const SizedBox(height: 10),
            // Kata-kata Pujian
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isCrown
                    ? const Color(0xFFFEF3C7)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCrown
                      ? const Color(0xFFFDE68A)
                      : const Color(0xFFBBF7D0),
                ),
              ),
              child: Text(
                praiseQuote,
                style: TextStyle(
                  fontSize: 12,
                  color: isCrown
                      ? const Color(0xFF92400E)
                      : const Color(0xFF166534),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],

          if (items.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _isActivitiesExpanded = !_isActivitiesExpanded;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  children: [
                    Text(
                      '${items.length} Aktivitas Dikerjakan',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isActivitiesExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: primaryTerracotta,
                    ),
                    const Spacer(),
                    Text(
                      _isActivitiesExpanded ? 'Tutup' : 'Lihat Detail',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: primaryTerracotta,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  children: items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1E293B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).toList(),
                ),
              ),
              crossFadeState: _isActivitiesExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ] else ...[
            const SizedBox(height: 6),
            const Text(
              'Belum ada kegiatan yang diselesaikan pada tanggal ini.',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF94A3B8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


