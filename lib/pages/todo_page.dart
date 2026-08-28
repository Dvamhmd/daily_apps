import 'dart:convert';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/pages/todo_riwayat_page.dart';
import 'package:daily_apps/utils/responsive_text.dart';
import 'package:daily_apps/utils/todo_alarm_service.dart';
import 'package:daily_apps/widgets/gta_switch_wheel.dart';
import 'package:daily_apps/widgets/todo_alarm_popup_dialog.dart';
import 'package:daily_apps/widgets/todo_alarm_setup_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TodoPage extends StatefulWidget {
  final ValueChanged<int> onPageSelected;

  const TodoPage({
    super.key,
    required this.onPageSelected,
  });

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  static const Color primaryTerracotta = Color(0xFFBA5A3A);
  static const Color darkTerracotta = Color(0xFF8C3E26);
  static const Color accentCompleted = Color(0xFF2E7D32);

  static const String _prefsKey = 'daily_apps_todo_groups_v1';

  List<TodoDateGroup> _dateGroups = [];
  final Set<String> _collapsedGroupIds = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'pending', 'completed'

  @override
  void initState() {
    super.initState();
    _initAlarmSystem();
    _loadTodoData();
  }

  @override
  void dispose() {
    TodoAlarmService.activeAlarmNotifier.removeListener(_onActiveAlarmChanged);
    super.dispose();
  }

  void _initAlarmSystem() {
    TodoAlarmService.initialize(
      onNotificationClick: (payload) {
        _handleNotificationAlarmTrigger(payload);
      },
    );
    TodoAlarmService.requestPermissions();
    TodoAlarmService.activeAlarmNotifier.addListener(_onActiveAlarmChanged);
  }

  void _onActiveAlarmChanged() {
    final payload = TodoAlarmService.activeAlarmNotifier.value;
    if (payload != null && mounted) {
      _handleNotificationAlarmTrigger(payload);
    }
  }

  void _handleNotificationAlarmTrigger(AlarmTriggerPayload payload) {
    if (!mounted) return;
    final targetGroup = _dateGroups.firstWhere(
      (g) => g.id == payload.groupId,
      orElse: () => _dateGroups.firstWhere(
        (g) =>
            g.date.year == payload.date.year &&
            g.date.month == payload.date.month &&
            g.date.day == payload.date.day,
        orElse: () => TodoDateGroup(id: payload.groupId, date: payload.date),
      ),
    );

    if (targetGroup.pendingItems.isNotEmpty) {
      TodoAlarmPopupDialog.show(
        context,
        group: targetGroup,
        onDismiss: () {
          _loadTodoData();
        },
      );
    } else {
      TodoAlarmService.stopAlarmSound();
    }
  }

  Future<void> _loadTodoData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _dateGroups = decoded
            .map((item) => TodoDateGroup.fromJson(item as Map<String, dynamic>))
            .toList();
        for (final group in _dateGroups) {
          group.items = [
            ...group.items.where((i) => !i.isCompleted),
            ...group.items.where((i) => i.isCompleted),
          ];
        }
      } else {
        _dateGroups = [];
      }
      // Sinkronisasi jadwal alarm seluruh group
      TodoAlarmService.syncAllAlarms(_dateGroups);
    } catch (e) {
      debugPrint('Error loading todos: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveTodoData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(
        _dateGroups.map((group) => group.toJson()).toList(),
      );
      await prefs.setString(_prefsKey, encoded);
    } catch (e) {
      debugPrint('Error saving todos: $e');
    }
  }

  /// Reorder/Drag handler untuk mengurutkan section tanggal
  void _onReorderGroups(int oldIndex, int newIndex) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final filteredList = _filteredGroups;
      final movedItem = filteredList[oldIndex];
      final targetItem = filteredList[newIndex];

      final realOldIndex = _dateGroups.indexOf(movedItem);
      final realNewIndex = _dateGroups.indexOf(targetItem);

      if (realOldIndex != -1 && realNewIndex != -1) {
        _dateGroups.removeAt(realOldIndex);
        _dateGroups.insert(realNewIndex, movedItem);
      }
    });
    _saveTodoData();
  }

  List<TodoDateGroup> get _activeDateGroups =>
      _dateGroups.where((g) => !g.isArchived).toList();

  int get _totalTasks {
    return _activeDateGroups.fold(0, (sum, g) => sum + g.totalCount);
  }

  int get _completedTasks {
    return _activeDateGroups.fold(0, (sum, g) => sum + g.completedCount);
  }

  double get _overallProgress {
    if (_totalTasks == 0) return 0.0;
    return _completedTasks / _totalTasks;
  }

  bool _isGroupCollapsed(String id) => _collapsedGroupIds.contains(id);

  void _toggleGroupCollapse(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_collapsedGroupIds.contains(id)) {
        _collapsedGroupIds.remove(id);
      } else {
        _collapsedGroupIds.add(id);
      }
    });
  }

  void _archiveGroup(TodoDateGroup group) {
    if (!group.isAllCompleted || group.items.isEmpty) {
      HapticFeedback.vibrate();
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      group.isArchived = true;
    });
    _saveTodoData();
  }

  void _showToast(BuildContext context, String message, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? primaryTerracotta : const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showConfigureAlarmDialog(TodoDateGroup group) async {
    await TodoAlarmService.requestOverlayPermissionWithDialog(context);
    final initialConfig = TodoAlarmConfig.fromGroup(group);
    if (!mounted) return;
    final res = await TodoAlarmSetupSheet.show(
      context,
      initialConfig: initialConfig,
      dateTitle: group.formattedFullDate,
    );
    if (res != null) {
      setState(() {
        res.applyToGroup(group);
      });
      if (group.reminderEnabled) {
        await TodoAlarmService.scheduleGroupAlarm(group);
      } else {
        await TodoAlarmService.cancelGroupAlarm(group.id);
      }
      await _saveTodoData();
      if (mounted) {
        _showToast(context, 'Berhasil atur pengingat');
      }
    }
  }

  /// Dialog Buat To-Do List Baru
  Future<void> _showCreateTodoListDialog() async {
    DateTime selectedDate = DateTime.now();
    final taskController = TextEditingController();
    TodoAlarmConfig alarmConfig = TodoAlarmConfig(
      enabled: false,
      type: 'specific',
      intervalMinutes: 60,
      intervalStartTime: '08:00',
      intervalEndTime: '21:00',
      specificTimes: ['09:00', '13:00', '19:00'],
      soundType: 'default',
      defaultSound: 'chime_classic',
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final now = DateTime.now();
            final isDateToday = selectedDate.year == now.year &&
                selectedDate.month == now.month &&
                selectedDate.day == now.day;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryTerracotta.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.playlist_add_rounded,
                            color: primaryTerracotta,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Buat To-Do List Baru',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Pilih tanggal untuk membuat list section baru',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
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
                          setModalState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryTerracotta.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event_available_rounded,
                              color: primaryTerracotta,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tanggal To-Do List',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    TodoDateGroup(
                                      id: '',
                                      date: selectedDate,
                                    ).formattedFullDate,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isDateToday)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      primaryTerracotta.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Hari Ini',
                                  style: TextStyle(
                                    color: primaryTerracotta,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.edit_calendar_rounded,
                              color: primaryTerracotta,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tugas Pertama (Opsional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: taskController,
                      autofocus: false,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Rapat koordinasi proyek...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13.5,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.25),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: primaryTerracotta,
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Toggle Pengingat / Alarm
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: alarmConfig.enabled
                            ? primaryTerracotta.withValues(alpha: 0.06)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: alarmConfig.enabled
                              ? primaryTerracotta.withValues(alpha: 0.4)
                              : Colors.grey.withValues(alpha: 0.25),
                          width: alarmConfig.enabled ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: alarmConfig.enabled
                                      ? primaryTerracotta
                                      : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.alarm_rounded,
                                  color: alarmConfig.enabled
                                      ? Colors.white
                                      : const Color(0xFF64748B),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Pengingat / Alarm Section',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    Text(
                                      alarmConfig.enabled
                                          ? 'Alarm aktif berbunyi looping jika tugas belum selesai'
                                          : 'Nyalakan alarm pengingat tugas',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: alarmConfig.enabled
                                            ? darkTerracotta
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: alarmConfig.enabled,
                                activeThumbColor: primaryTerracotta,
                                onChanged: (val) async {
                                  if (val) {
                                    await TodoAlarmService
                                        .requestOverlayPermissionWithDialog(
                                            context);
                                    if (!context.mounted) return;
                                    final res = await TodoAlarmSetupSheet.show(
                                      context,
                                      initialConfig: alarmConfig,
                                      dateTitle: TodoDateGroup(
                                        id: '',
                                        date: selectedDate,
                                      ).formattedFullDate,
                                    );
                                    if (res != null) {
                                      setModalState(() {
                                        alarmConfig = res;
                                        alarmConfig.enabled = true;
                                      });
                                      if (context.mounted) {
                                        _showToast(
                                            context, 'Berhasil atur pengingat');
                                      }
                                    }
                                  } else {
                                    setModalState(() {
                                      alarmConfig.enabled = false;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          if (alarmConfig.enabled) ...[
                            const SizedBox(height: 8),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    alarmConfig.type == 'interval'
                                        ? '🔔 Tiap ${alarmConfig.intervalMinutes < 60 ? "${alarmConfig.intervalMinutes} Menit" : "${alarmConfig.intervalMinutes ~/ 60} Jam"} (${alarmConfig.intervalStartTime} - ${alarmConfig.intervalEndTime}) • ${_getSoundLabel(alarmConfig)}'
                                        : '🔔 Jam: ${alarmConfig.specificTimes.join(', ')} • ${_getSoundLabel(alarmConfig)}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: darkTerracotta,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    final res = await TodoAlarmSetupSheet.show(
                                      context,
                                      initialConfig: alarmConfig,
                                      dateTitle: TodoDateGroup(
                                        id: '',
                                        date: selectedDate,
                                      ).formattedFullDate,
                                    );
                                    if (res != null) {
                                      setModalState(() {
                                        alarmConfig = res;
                                        alarmConfig.enabled = true;
                                      });
                                      if (context.mounted) {
                                        _showToast(context, 'Berhasil atur pengingat');
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.edit_rounded, size: 14, color: primaryTerracotta),
                                  label: const Text(
                                    'Ubah',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: primaryTerracotta,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                            child: const Text(
                              'Batal',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final cleanDate = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                              );
                              final taskTitle = taskController.text.trim();

                              final existingIndex = _dateGroups.indexWhere(
                                (g) =>
                                    g.date.year == cleanDate.year &&
                                    g.date.month == cleanDate.month &&
                                    g.date.day == cleanDate.day,
                              );

                              final TodoDateGroup targetGroup;

                              if (existingIndex != -1) {
                                final existingGroup = _dateGroups[existingIndex];
                                existingGroup.isArchived = false;
                                _collapsedGroupIds.remove(existingGroup.id);
                                alarmConfig.applyToGroup(existingGroup);

                                if (taskTitle.isNotEmpty) {
                                  existingGroup.items.add(
                                    TodoItem(
                                      id: DateTime.now()
                                          .microsecondsSinceEpoch
                                          .toString(),
                                      title: taskTitle,
                                      isCompleted: false,
                                    ),
                                  );
                                  existingGroup.items = [
                                    ...existingGroup.items
                                        .where((i) => !i.isCompleted),
                                    ...existingGroup.items
                                        .where((i) => i.isCompleted),
                                  ];
                                }
                                targetGroup = existingGroup;
                              } else {
                                final newGroup = TodoDateGroup(
                                  id: DateTime.now()
                                      .microsecondsSinceEpoch
                                      .toString(),
                                  date: cleanDate,
                                  isArchived: false,
                                  items: taskTitle.isNotEmpty
                                      ? [
                                          TodoItem(
                                            id: DateTime.now()
                                                .microsecondsSinceEpoch
                                                .toString(),
                                            title: taskTitle,
                                            isCompleted: false,
                                          ),
                                        ]
                                      : [],
                                );
                                alarmConfig.applyToGroup(newGroup);
                                _collapsedGroupIds.remove(newGroup.id);
                                _dateGroups.insert(0, newGroup);
                                targetGroup = newGroup;
                              }

                              setState(() {
                                _searchQuery = '';
                                _selectedFilter = 'all';
                              });

                              // Jadwalkan Alarm Service
                              if (targetGroup.reminderEnabled) {
                                TodoAlarmService.scheduleGroupAlarm(targetGroup);
                              }

                              _saveTodoData();
                              Navigator.pop(context);
                              _showToast(context, 'To-Do List berhasil dibuat!');
                              HapticFeedback.mediumImpact();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryTerracotta,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.check_rounded, size: 20),
                            label: const Text(
                              'Buat List',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getSoundLabel(TodoAlarmConfig config) {
    if (config.soundType == 'custom') {
      return config.customSoundName ?? 'Kustom MP3';
    }
    switch (config.defaultSound) {
      case 'alarm_digital':
        return 'Alarm Digital';
      case 'gentle_bell':
        return 'Bel Lembut';
      case 'cheerful_melody':
        return 'Melodi Ceria';
      case 'chime_classic':
      default:
        return 'Chime Klasik';
    }
  }

  /// Tambah Kerjaan Baru ke Section Tanggal
  Future<void> _showAddTaskDialog(TodoDateGroup group) async {
    final taskController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryTerracotta.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.add_task_rounded,
                        color: primaryTerracotta,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tambah Kerjaan Baru',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            group.formattedFullDate,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: primaryTerracotta,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tugas / Pekerjaan yang Harus Dikerjakan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: taskController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Ketik apa tugas kamu...',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.25),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: primaryTerracotta,
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        child: const Text(
                          'Batal',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final text = taskController.text.trim();
                          if (text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tolong isi nama tugas!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            group.items.add(
                              TodoItem(
                                id: DateTime.now()
                                    .microsecondsSinceEpoch
                                    .toString(),
                                title: text,
                                isCompleted: false,
                              ),
                            );
                            group.items = [
                              ...group.items.where((i) => !i.isCompleted),
                              ...group.items.where((i) => i.isCompleted),
                            ];
                          });

                          if (group.reminderEnabled) {
                            TodoAlarmService.scheduleGroupAlarm(group);
                          }

                          _saveTodoData();
                          Navigator.pop(context);
                          HapticFeedback.lightImpact();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTerracotta,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text(
                          'Simpan Tugas',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Edit Nama Tugas
  Future<void> _showEditTaskDialog(TodoItem item) async {
    final controller = TextEditingController(text: item.title);

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Edit Tugas',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Nama tugas...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: primaryTerracotta,
                  width: 1.8,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final newText = controller.text.trim();
                if (newText.isNotEmpty) {
                  setState(() {
                    item.title = newText;
                  });
                  _saveTodoData();
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTerracotta,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _toggleTask(TodoDateGroup group, TodoItem item) {
    HapticFeedback.selectionClick();
    setState(() {
      item.isCompleted = !item.isCompleted;
      group.items = [
        ...group.items.where((i) => !i.isCompleted),
        ...group.items.where((i) => i.isCompleted),
      ];
    });
    if (group.reminderEnabled) {
      if (group.isAllCompleted) {
        TodoAlarmService.cancelGroupAlarm(group.id);
      } else {
        TodoAlarmService.scheduleGroupAlarm(group);
      }
    }
    _saveTodoData();
  }

  void _deleteTask(TodoDateGroup group, TodoItem item) {
    setState(() {
      group.items.removeWhere((i) => i.id == item.id);
    });
    if (group.reminderEnabled) {
      if (group.isAllCompleted || group.items.isEmpty) {
        TodoAlarmService.cancelGroupAlarm(group.id);
      } else {
        TodoAlarmService.scheduleGroupAlarm(group);
      }
    }
    _saveTodoData();
    _showToast(context, 'Tugas berhasil dihapus');
  }

  Future<void> _confirmDeleteGroup(TodoDateGroup group) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
              SizedBox(width: 10),
              Text(
                'Hapus Section?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          content: Text(
            'Apakah kamu yakin ingin menghapus section "${group.formattedFullDate}" beserta seluruh ${group.totalCount} tugas di dalamnya?',
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
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      TodoAlarmService.cancelGroupAlarm(group.id);
      setState(() {
        _dateGroups.removeWhere((g) => g.id == group.id);
      });
      _saveTodoData();
      if (mounted) {
        _showToast(context, 'Section berhasil dihapus');
      }
    }
  }

  void _completeAllTasks() {
    if (_totalTasks == 0) return;
    HapticFeedback.mediumImpact();
    setState(() {
      for (final g in _dateGroups) {
        for (final item in g.items) {
          item.isCompleted = true;
        }
        TodoAlarmService.cancelGroupAlarm(g.id);
      }
    });
    _saveTodoData();
    _showToast(context, 'Semua tugas berhasil ditandai selesai! 🎉');
  }

  List<TodoDateGroup> get _filteredGroups {
    return _activeDateGroups.where((group) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesDate =
            group.formattedFullDate.toLowerCase().contains(query);
        final matchesTasks = group.items.any(
          (item) => item.title.toLowerCase().contains(query),
        );
        if (!matchesDate && !matchesTasks) return false;
      }

      if (_selectedFilter == 'pending') {
        return group.items.isEmpty ||
            group.items.any((item) => !item.isCompleted);
      } else if (_selectedFilter == 'completed') {
        return group.items.isNotEmpty &&
            group.items.every((item) => item.isCompleted);
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredGroups;

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
            Icon(Icons.checklist_rounded, color: Colors.white, size: 20),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'To-Do List',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: 'Riwayat To-Do Selesai',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const TodoRiwayatPage()),
              );
              _loadTodoData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: Colors.white),
            tooltip: 'Selesaikan Semua Tugas',
            onPressed: _completeAllTasks,
          ),
        ],
      ),
      floatingActionButton: GtaSwitchWheel(
        currentIndex: 2,
        onPageSelected: widget.onPageSelected,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryTerracotta),
            )
          : RefreshIndicator(
              onRefresh: _loadTodoData,
              color: primaryTerracotta,
              child: ResponsiveContentWrapper(
                maxWidth: 720,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderBanner(),
                            const SizedBox(height: 18),
                            _buildSearchAndFilterBar(),
                            const SizedBox(height: 20),

                            // Section Title
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Flexible(
                                        child: Text(
                                          'Daftar Rencana & Tugas',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E293B),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: primaryTerracotta
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${_activeDateGroups.length} Hari',
                                          style: const TextStyle(
                                            color: primaryTerracotta,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (filtered.length > 1) ...[
                                  const SizedBox(width: 8),
                                  const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.drag_indicator_rounded,
                                        size: 14,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Tahan & Geser',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),

                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),

                    // REORDERABLE LIST OF DATE SECTIONS
                    if (filtered.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: _buildEmptyState(),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverReorderableList(
                          itemCount: filtered.length,
                          // ignore: deprecated_member_use
                          onReorder: _onReorderGroups,
                          proxyDecorator:
                              (Widget child, int index, Animation<double> animation) {
                            return AnimatedBuilder(
                              animation: animation,
                              builder: (context, _) {
                                final elevation = 4.0 + 8.0 * animation.value;
                                return Material(
                                  color: Colors.transparent,
                                  elevation: elevation,
                                  shadowColor: Colors.black38,
                                  borderRadius: BorderRadius.circular(20),
                                  child: child,
                                );
                              },
                            );
                          },
                          itemBuilder: (context, index) {
                            final group = filtered[index];
                            return ReorderableDelayedDragStartListener(
                              key: ValueKey(group.id),
                              index: index,
                              child: _buildDateGroupSection(group, index),
                            );
                          },
                        ),
                      ),

                    // FOOTER / ADD BUTTON
                    if (filtered.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: _buildAddNewSectionButton(),
                        ),
                      ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 100),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // --- TOMBOL BUAT SECTION BARU DI BAWAH CARD TODO LIST ---
  Widget _buildAddNewSectionButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showCreateTodoListDialog,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: primaryTerracotta.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryTerracotta.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryTerracotta.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: primaryTerracotta,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Buat Section / Tanggal Baru',
                  style: TextStyle(
                    color: primaryTerracotta,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- HEADER BANNER ---
  Widget _buildHeaderBanner() {
    final progressPercent = (_overallProgress * 100).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryTerracotta, darkTerracotta],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primaryTerracotta.withValues(alpha: 0.28),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'AGENDA & CHECKLIST',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.task_alt_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$_completedTasks/$_totalTasks Selesai',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Catatan Tugas & Checklist Harian',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kelola pekerjaan terstruktur per tanggal untuk produktivitas yang rapi dan terpantau.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _overallProgress,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$progressPercent%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- SEARCH & FILTER BAR ---
  Widget _buildSearchAndFilterBar() {
    return Column(
      children: [
        TextField(
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
          decoration: InputDecoration(
            hintText: 'Cari tugas atau tanggal...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13.5),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: primaryTerracotta,
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: primaryTerracotta.withValues(alpha: 0.15),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.black.withValues(alpha: 0.05),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: primaryTerracotta,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip('all', 'Semua ($_totalTasks)'),
              const SizedBox(width: 8),
              _buildFilterChip(
                'pending',
                'Belum Selesai (${_totalTasks - _completedTasks})',
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'completed',
                'Selesai ($_completedTasks)',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final bool isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = key;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? primaryTerracotta : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primaryTerracotta
                : Colors.grey.withValues(alpha: 0.2),
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: primaryTerracotta.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // --- SECTION TANGGAL (DATE GROUP CARD DENGAN DRAG HANDLE, EXPAND/COLLAPSE & ARSIP) ---
  Widget _buildDateGroupSection(TodoDateGroup group, int index) {
    final isCollapsed = _isGroupCollapsed(group.id);
    final itemsToShow = group.items.where((item) {
      if (_selectedFilter == 'pending') return !item.isCompleted;
      if (_selectedFilter == 'completed') return item.isCompleted;
      return true;
    }).toList();

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: group.isToday
                ? primaryTerracotta.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.06),
            width: group.isToday ? 1.6 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Tanggal Section (Tappable untuk Expand / Collapse)
              Container(
                decoration: BoxDecoration(
                  color: group.isToday
                      ? primaryTerracotta.withValues(alpha: 0.07)
                      : const Color(0xFFF8FAFC),
                  border: Border(
                    bottom: BorderSide(
                      color: isCollapsed
                          ? Colors.transparent
                          : Colors.grey.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    // Dedicated Drag Handle Icon
                    ReorderableDragStartListener(
                      index: index,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        color: Colors.transparent,
                        child: const Icon(
                          Icons.drag_indicator_rounded,
                          color: Color(0xFF94A3B8),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Area Header yang bisa di-tap untuk buka/tutup (Expand/Collapse)
                    Expanded(
                      child: InkWell(
                        onTap: () => _toggleGroupCollapse(group.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 4,
                          ),
                          child: Row(
                            children: [
                              // Icon Kalender / Date Indicator
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: group.isToday
                                      ? primaryTerracotta
                                      : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Icon(
                                  Icons.event_note_rounded,
                                  color: group.isToday
                                      ? Colors.white
                                      : const Color(0xFF475569),
                                  size: 15,
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Tanggal & Hari Label
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            group.formattedFullDate,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.bold,
                                              color: group.isToday
                                                  ? primaryTerracotta
                                                  : const Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                        if (group.isToday ||
                                            group.isTomorrow ||
                                            group.isYesterday) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: group.isToday
                                                  ? primaryTerracotta
                                                      .withValues(alpha: 0.15)
                                                  : Colors.grey
                                                      .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              group.relativeDateLabel,
                                              style: TextStyle(
                                                color: group.isToday
                                                    ? primaryTerracotta
                                                    : const Color(0xFF475569),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          '${group.completedCount}/${group.totalCount} Tugas selesai',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: group.isAllCompleted
                                                ? accentCompleted
                                                : const Color(0xFF64748B),
                                            fontWeight: group.isAllCompleted
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (group.reminderEnabled) ...[
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () => _showConfigureAlarmDialog(group),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: primaryTerracotta.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: primaryTerracotta.withValues(alpha: 0.3),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.alarm_on_rounded,
                                                size: 12,
                                                color: primaryTerracotta,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  group.reminderSummaryLabel,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: primaryTerracotta,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Chevron Expand / Collapse Button
                    IconButton(
                      icon: AnimatedRotation(
                        turns: isCollapsed ? 0.0 : 0.5,
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: group.isToday
                              ? primaryTerracotta
                              : const Color(0xFF64748B),
                          size: 22,
                        ),
                      ),
                      tooltip: isCollapsed ? 'Buka Section' : 'Tutup Section',
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () => _toggleGroupCollapse(group.id),
                    ),

                    // Menu Titik Tiga
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onSelected: (val) {
                        if (val == 'add') {
                          _showAddTaskDialog(group);
                        } else if (val == 'alarm') {
                          _showConfigureAlarmDialog(group);
                        } else if (val == 'archive') {
                          _archiveGroup(group);
                        } else if (val == 'toggle_collapse') {
                          _toggleGroupCollapse(group.id);
                        } else if (val == 'complete_all') {
                          setState(() {
                            for (final i in group.items) {
                              i.isCompleted = true;
                            }
                          });
                          TodoAlarmService.cancelGroupAlarm(group.id);
                          _saveTodoData();
                        } else if (val == 'clear_completed') {
                          setState(() {
                            group.items.removeWhere((i) => i.isCompleted);
                          });
                          _saveTodoData();
                        } else if (val == 'delete_section') {
                          _confirmDeleteGroup(group);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'add',
                          child: Row(
                            children: [
                              Icon(Icons.add_rounded,
                                  size: 18, color: primaryTerracotta),
                              SizedBox(width: 8),
                              Text('Tambah Tugas',
                                  style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'alarm',
                          child: Row(
                            children: [
                              Icon(
                                group.reminderEnabled
                                    ? Icons.alarm_on_rounded
                                    : Icons.alarm_add_rounded,
                                size: 18,
                                color: primaryTerracotta,
                              ),
                              SizedBox(width: 8),
                              Text(
                                group.reminderEnabled
                                    ? 'Atur Pengingat Alarm'
                                    : 'Nyalakan Pengingat Alarm',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'archive',
                          enabled:
                              group.isAllCompleted && group.items.isNotEmpty,
                          child: Row(
                            children: [
                              Icon(
                                Icons.archive_rounded,
                                size: 18,
                                color: (group.isAllCompleted &&
                                        group.items.isNotEmpty)
                                    ? accentCompleted
                                    : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                (group.isAllCompleted && group.items.isNotEmpty)
                                    ? 'Arsipkan Section'
                                    : 'Arsipkan (Belum Selesai)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: (group.isAllCompleted &&
                                          group.items.isNotEmpty)
                                      ? null
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggle_collapse',
                          child: Row(
                            children: [
                              Icon(
                                isCollapsed
                                    ? Icons.unfold_more_rounded
                                    : Icons.unfold_less_rounded,
                                size: 18,
                                color: const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isCollapsed ? 'Buka Section' : 'Tutup Section',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'complete_all',
                          child: Row(
                            children: [
                              Icon(Icons.done_all_rounded,
                                  size: 18, color: accentCompleted),
                              SizedBox(width: 8),
                              Text('Tandai Semua Selesai',
                                  style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'clear_completed',
                          child: Row(
                            children: [
                              Icon(Icons.cleaning_services_rounded,
                                  size: 18, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Hapus Tugas Selesai',
                                  style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete_section',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Hapus Section Ini',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),

              // KONTEN SECTION DENGAN ANIMASI SLIDE YANG MULUS & STABIL
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOutCubic,
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.topCenter,
                child: isCollapsed
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (group.totalCount > 0)
                            ClipRRect(
                              child: LinearProgressIndicator(
                                value: group.progress,
                                minHeight: 2.5,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  group.isAllCompleted
                                      ? accentCompleted
                                      : primaryTerracotta,
                                ),
                              ),
                            ),

                          // Tombol Arsipkan Section Jika Sudah 100% Selesai
                          if (group.isAllCompleted && group.items.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: accentCompleted.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      accentCompleted.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: accentCompleted,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Semua tugas selesai! Siap diarsipkan.',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: accentCompleted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _archiveGroup(group),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accentCompleted,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    icon: const Icon(Icons.archive_rounded,
                                        size: 14),
                                    label: const Text(
                                      'Arsipkan',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (itemsToShow.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 20, horizontal: 16),
                              child: Center(
                                child: Text(
                                  group.items.isEmpty
                                      ? 'Belum ada tugas pada tanggal ini'
                                      : 'Tidak ada tugas yang sesuai filter',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12.5,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            )
                          else
                            Column(
                              children: [
                                for (int idx = 0;
                                    idx < itemsToShow.length;
                                    idx++) ...[
                                  _buildTaskItemTile(group, itemsToShow[idx]),
                                  if (idx < itemsToShow.length - 1)
                                    Divider(
                                      height: 1,
                                      thickness: 0.6,
                                      color:
                                          Colors.grey.withValues(alpha: 0.12),
                                      indent: 44,
                                    ),
                                ],
                              ],
                            ),

                          // Tombol + Tambah Kerjaan pada section ini
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                            child: InkWell(
                              onTap: () => _showAddTaskDialog(group),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color:
                                      primaryTerracotta.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: primaryTerracotta
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_circle_rounded,
                                      size: 16,
                                      color: primaryTerracotta,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Tambah Kerjaan',
                                      style: TextStyle(
                                        color: primaryTerracotta,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TASK ITEM TILE DENGAN CHECKBOX & NAMA TUGAS ---
  Widget _buildTaskItemTile(TodoDateGroup group, TodoItem item) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red[600],
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 18),
      ),
      onDismissed: (_) => _deleteTask(group, item),
      child: InkWell(
        onTap: () => _toggleTask(group, item),
        child: Padding(
          padding: const EdgeInsets.only(
            left: 12,
            right: 4,
            top: 3.5,
            bottom: 3.5,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _toggleTask(group, item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: item.isCompleted ? accentCompleted : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: item.isCompleted
                          ? accentCompleted
                          : const Color(0xFFCBD5E1),
                      width: 1.8,
                    ),
                    boxShadow: item.isCompleted
                        ? [
                            BoxShadow(
                              color: accentCompleted.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 1.5),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: item.isCompleted
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 13,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: item.isCompleted
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF1E293B),
                    fontWeight:
                        item.isCompleted ? FontWeight.w400 : FontWeight.w500,
                    decoration: item.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: const Color(0xFF94A3B8),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 15,
                  color: Color(0xFF94A3B8),
                ),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(),
                tooltip: 'Edit Tugas',
                onPressed: () => _showEditTaskDialog(item),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: Color(0xFFCBD5E1),
                ),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(),
                tooltip: 'Hapus Tugas',
                onPressed: () => _deleteTask(group, item),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- EMPTY STATE CARD ---
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryTerracotta.withValues(alpha: 0.15),
        ),
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
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: primaryTerracotta.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              size: 36,
              color: primaryTerracotta,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Tidak Ada List Tugas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedFilter != 'all'
                ? 'Tidak ada tugas yang cocok dengan pencarian / filter kamu.'
                : 'Mulai buat section tanggal baru dan catat tugas-tugas harianmu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showCreateTodoListDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryTerracotta,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Buat Section / Tanggal Baru',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
