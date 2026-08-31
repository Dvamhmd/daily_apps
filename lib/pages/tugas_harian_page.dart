import 'dart:convert';
import 'package:daily_apps/models/model_daily_task.dart';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/utils/responsive_text.dart';
import 'package:daily_apps/utils/todo_alarm_service.dart';
import 'package:daily_apps/widgets/custom_toast.dart';
import 'package:daily_apps/widgets/daily_task_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TugasHarianPage extends StatefulWidget {
  const TugasHarianPage({super.key});

  @override
  State<TugasHarianPage> createState() => _TugasHarianPageState();
}

class _TugasHarianPageState extends State<TugasHarianPage> {
  static const Color primaryTerracotta = Color(0xFFBA5A3A);

  static const String _prefsGroupsKey = 'daily_apps_daily_task_groups_v1';
  static const String _prefsTodoKey = 'daily_apps_todo_groups_v1';

  List<DailyTaskGroup> _taskGroups = [];
  bool _isLoading = true;

  final List<DailyTaskGroup> _starterTemplates = [
    DailyTaskGroup(
      id: 'template_kesehatan',
      title: 'Kesehatan & Kebugaran',
      tasks: [
        'Minum air putih 2 Liter',
        'Olahraga / Senam 30 Menit',
        'Konsumsi vitamin & buah',
        'Tidur teratur sebelum 23:00',
      ],
      reminderEnabled: true,
      reminderType: 'specific',
      reminderSpecificTimes: ['08:00', '13:00', '20:00'],
      reminderDefaultSound: 'chime_classic',
    ),
    DailyTaskGroup(
      id: 'template_pagi',
      title: 'Rutinitas Pagi Produktif',
      tasks: [
        'Bangun pagi & Rapikan tempat tidur',
        'Minum segelas air hangat',
        'Review target & to-do list hari ini',
        'Membaca buku 15 menit',
      ],
      reminderEnabled: true,
      reminderType: 'specific',
      reminderSpecificTimes: ['06:30', '09:00'],
      reminderDefaultSound: 'cheerful_melody',
    ),
    DailyTaskGroup(
      id: 'template_ibadah',
      title: 'Ibadah & Self Care',
      tasks: [
        'Ibadah tepat waktu',
        'Bersyukur 3 hal positif hari ini',
        'Meditasi / Jalan santai 15 menit',
        'Beri kabar keluarga / teman',
      ],
      reminderEnabled: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadDailyTaskGroups();
  }

  Future<void> _loadDailyTaskGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_prefsGroupsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _taskGroups = decoded
            .map((item) => DailyTaskGroup.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        _taskGroups = [];
      }
    } catch (e) {
      debugPrint('Error loading daily task groups: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveDailyTaskGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(
        _taskGroups.map((g) => g.toJson()).toList(),
      );
      await prefs.setString(_prefsGroupsKey, encoded);
    } catch (e) {
      debugPrint('Error saving daily task groups: $e');
    }
  }

  Future<void> _applyGroupToTodoSections(
    DailyTaskGroup group, {
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_prefsTodoKey) ??
          prefs.getString('todo_date_groups_v1');

      List<TodoDateGroup> existingDateGroups = [];
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        existingDateGroups = decoded
            .map((item) => TodoDateGroup.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      final now = DateTime.now();
      final start = customStart ??
          group.startDate ??
          DateTime(now.year, now.month, now.day);
      final end = customEnd ??
          group.endDate ??
          start.add(const Duration(days: 6));

      // Terapkan tugas grup ke section tanggal
      final updatedGroups = DailyTaskGroup.applyGroupToDateGroups(
        existingGroups: existingDateGroups,
        taskGroup: group,
        rangeStart: start,
        rangeEnd: end,
        overwriteAlarm: group.reminderEnabled,
      );

      // Simpan kembali ke Todo List SharedPreferences
      final String encoded = jsonEncode(
        updatedGroups.map((g) => g.toJson()).toList(),
      );
      await prefs.setString(_prefsTodoKey, encoded);

      // Sinkronisasi jadwal alarm
      await TodoAlarmService.syncAllAlarms(updatedGroups);

      final totalDays = end.difference(start).inDays + 1;
      if (mounted) {
        CustomToast.showSuccess(
          context,
          title: 'Berhasil diterapkan ke $totalDays section tanggal To-Do List!',
        );
      }
    } catch (e) {
      debugPrint('Error applying task group: $e');
      if (mounted) {
        CustomToast.showError(
          context,
          title: 'Gagal menerapkan tugas ke section: $e',
        );
      }
    }
  }

  Future<void> _openCreateGroupDialog({DailyTaskGroup? template}) async {
    final result = await DailyTaskFormSheet.show(
      context,
      initialGroup: template,
    );

    if (result != null && result['group'] is DailyTaskGroup) {
      final DailyTaskGroup newGroup = result['group'] as DailyTaskGroup;
      final bool shouldApply = result['shouldApply'] == true;

      setState(() {
        final existingIdx = _taskGroups.indexWhere((g) => g.id == newGroup.id);
        if (existingIdx != -1) {
          _taskGroups[existingIdx] = newGroup;
        } else {
          _taskGroups.insert(0, newGroup);
        }
      });
      await _saveDailyTaskGroups();

      if (shouldApply) {
        await _applyGroupToTodoSections(newGroup);
      } else {
        if (mounted) {
          CustomToast.showSuccess(
            context,
            title: 'Grup Aktivitas berhasil disimpan!',
          );
        }
      }
    }
  }

  Future<void> _quickApplyGroupDialog(DailyTaskGroup group) async {
    final now = DateTime.now();
    DateTime rangeStart = group.startDate ?? DateTime(now.year, now.month, now.day);
    DateTime rangeEnd = group.endDate ??
        rangeStart.add(const Duration(days: 6));

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(
        start: rangeStart,
        end: rangeEnd.isBefore(rangeStart) ? rangeStart : rangeEnd,
      ),
      helpText: 'PILIH RENTANG TANGGAL PENERAPAN',
      confirmText: 'TERAPKAN SEKARANG',
      cancelText: 'BATAL',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryTerracotta,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      HapticFeedback.mediumImpact();
      // Update group's saved range
      group.startDate = picked.start;
      group.endDate = picked.end;
      await _saveDailyTaskGroups();

      await _applyGroupToTodoSections(
        group,
        customStart: picked.start,
        customEnd: picked.end,
      );
    }
  }

  Future<void> _confirmDeleteGroup(DailyTaskGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 10),
            Text(
              'Hapus Grup Aktivitas?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah kamu yakin ingin menghapus grup aktivitas "${group.title}"?',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedback.mediumImpact();
      setState(() {
        _taskGroups.removeWhere((g) => g.id == group.id);
      });
      await _saveDailyTaskGroups();
      if (mounted) {
        CustomToast.showSuccess(context, title: 'Grup Aktivitas berhasil dihapus');
      }
    }
  }

  void _duplicateGroup(DailyTaskGroup group) {
    HapticFeedback.lightImpact();
    final newGroup = group.copyWith(
      id: 'daily_group_${DateTime.now().millisecondsSinceEpoch}',
      title: '${group.title} (Salinan)',
      createdAt: DateTime.now(),
    );
    setState(() {
      _taskGroups.insert(0, newGroup);
    });
    _saveDailyTaskGroups();
    CustomToast.showSuccess(context, title: 'Grup Aktivitas berhasil diduplikasi');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F6),
      appBar: AppBar(
        backgroundColor: primaryTerracotta,
        centerTitle: false,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_repeat_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Tugas Harian',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
            tooltip: 'Panduan Tugas Harian',
            onPressed: () {
              _showHelpDialog();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryTerracotta),
            )
          : ResponsiveContentWrapper(
              maxWidth: 720,
              child: RefreshIndicator(
                onRefresh: _loadDailyTaskGroups,
                color: primaryTerracotta,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Banner
                            _buildInfoBanner(),

                            const SizedBox(height: 16),

                            // Main Action Button: Buat Grup Aktivitas Baru
                            _buildCreateButton(),

                            const SizedBox(height: 22),

                            // Section Title: Grup Aktivitas Saya
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Grup Aktivitas Tersimpan',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                if (_taskGroups.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryTerracotta
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_taskGroups.length} Grup',
                                      style: const TextStyle(
                                        color: primaryTerracotta,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // List of Groups or Empty State
                            if (_taskGroups.isEmpty)
                              _buildEmptyState()
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _taskGroups.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 14),
                                itemBuilder: (context, idx) {
                                  final group = _taskGroups[idx];
                                  return _buildGroupCard(group);
                                },
                              ),

                            // Rekomendasi Starter Templates (jika ada grup)
                            if (_taskGroups.isNotEmpty) ...[
                              const SizedBox(height: 28),
                              const Text(
                                'Inspirasi Template Rutinitas',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ..._starterTemplates.map(
                                (t) => _buildStarterTemplateTile(t),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryTerracotta.withValues(alpha: 0.08),
            primaryTerracotta.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primaryTerracotta.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryTerracotta,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: primaryTerracotta.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set Up Tugas Harian Otomatis',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Buat kumpulan tugas berulang (Grup Aktivitas) dan terapkan langsung ke banyak section tanggal To-Do List sekaligus beserta jadwal alarmnya.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryTerracotta.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => _openCreateGroupDialog(),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTerracotta,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 22),
            SizedBox(width: 10),
            Text(
              'Buat Grup Aktivitas Baru',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(DailyTaskGroup group) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey[200]!, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryTerracotta.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.event_note_rounded,
                    color: primaryTerracotta,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${group.totalTasks} Aktivitas Terdaftar',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _openCreateGroupDialog(template: group);
                    } else if (val == 'duplicate') {
                      _duplicateGroup(group);
                    } else if (val == 'delete') {
                      _confirmDeleteGroup(group);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: primaryTerracotta),
                          SizedBox(width: 10),
                          Text('Edit Grup'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.copy_rounded, size: 18, color: Color(0xFF1976D2)),
                          SizedBox(width: 10),
                          Text('Duplikasi'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                          SizedBox(width: 10),
                          Text('Hapus', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Badges: Rentang Tanggal & Alarm
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.date_range_rounded,
                        size: 13,
                        color: Color(0xFF475569),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        group.dateRangeSummary,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: group.reminderEnabled
                        ? primaryTerracotta.withValues(alpha: 0.12)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        group.reminderEnabled
                            ? Icons.alarm_on_rounded
                            : Icons.alarm_off_rounded,
                        size: 13,
                        color: group.reminderEnabled
                            ? primaryTerracotta
                            : Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        group.reminderEnabled
                            ? group.reminderSummaryLabel
                            : 'Alarm Nonaktif',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: group.reminderEnabled
                              ? primaryTerracotta
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Task Items Preview List
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: group.tasks.take(4).map((task) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 14,
                        color: primaryTerracotta,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList()
                ..addAll(
                  group.tasks.length > 4
                      ? [
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '+ ${group.tasks.length - 4} tugas lainnya...',
                              style: const TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ]
                      : [],
                ),
            ),
          ),

          const SizedBox(height: 14),

          // Bottom Action Bar: Terapkan ke Section & Edit
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _quickApplyGroupDialog(group),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTerracotta,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                    label: const Text(
                      'Terapkan ke Section',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _openCreateGroupDialog(template: group),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryTerracotta,
                    side: const BorderSide(color: primaryTerracotta, width: 1.2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text(
                    'Kustomisasi',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryTerracotta.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.checklist_rtl_rounded,
              color: primaryTerracotta,
              size: 40,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Belum Ada Grup Aktivitas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Mulai dengan membuat grup aktivitas baru atau gunakan salah satu rekomendasi template di bawah ini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Rekomendasi Template Siap Pakai:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ..._starterTemplates.map((t) => _buildStarterTemplateTile(t)),
        ],
      ),
    );
  }

  Widget _buildStarterTemplateTile(DailyTaskGroup template) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryTerracotta.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.bookmark_add_rounded,
              color: primaryTerracotta,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${template.totalTasks} tugas • ${template.tasks.first}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _openCreateGroupDialog(template: template),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: primaryTerracotta,
              side: const BorderSide(color: primaryTerracotta, width: 1.2),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Pakai',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: primaryTerracotta, size: 24),
            SizedBox(width: 10),
            Text(
              'Cara Kerja Tugas Harian',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Buat Grup Aktivitas (misal: Kesehatan, Rutinitas Pagi, Belajar).\n'
              '2. Masukkan daftar tugas yang ingin dikerjakan rutin.\n'
              '3. Tentukan rentang tanggal penerapannya (misal: 7 hari atau 30 hari ke depan).\n'
              '4. Atur alarm pengingat jika ingin dibunyikan otomatis.\n'
              '5. Klik "Simpan & Terapkan", maka seluruh section tanggal pada To-Do List akan langsung terisi tugas dan alarm tersebut.\n'
              '6. Anda tetap dapat mengedit atau mengatur ulang alarm pada tiap section tanggal secara terpisah.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.45,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryTerracotta,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }
}
