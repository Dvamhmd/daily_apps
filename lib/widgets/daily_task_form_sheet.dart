import 'package:daily_apps/models/model_daily_task.dart';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/utils/todo_alarm_service.dart';
import 'package:daily_apps/widgets/todo_alarm_setup_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DailyTaskFormSheet extends StatefulWidget {
  final DailyTaskGroup? initialGroup;

  const DailyTaskFormSheet({
    super.key,
    this.initialGroup,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    DailyTaskGroup? initialGroup,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DailyTaskFormSheet(
        initialGroup: initialGroup,
      ),
    );
  }

  @override
  State<DailyTaskFormSheet> createState() => _DailyTaskFormSheetState();
}

class _DailyTaskFormSheetState extends State<DailyTaskFormSheet> {
  static const Color primaryTerracotta = Color(0xFFBA5A3A);
  static const Color darkTerracotta = Color(0xFF8C3E26);

  late TextEditingController _titleController;
  late TextEditingController _taskInputController;
  final FocusNode _taskFocusNode = FocusNode();

  late List<String> _tasks;
  late DateTime _startDate;
  late DateTime _endDate;

  late bool _reminderEnabled;
  late String _reminderType;
  late int _reminderIntervalMinutes;
  late String _reminderIntervalStartTime;
  late String _reminderIntervalEndTime;
  late List<String> _reminderSpecificTimes;
  late String _reminderSoundType;
  late String _reminderDefaultSound;
  String? _reminderCustomSoundPath;
  String? _reminderCustomSoundName;

  final List<String> _quickTaskSuggestions = [
    'Minum air putih 2L',
    'Olahraga 30 menit',
    'Konsumsi vitamin',
    'Membaca buku 15 menit',
    'Tidur sebelum jam 23:00',
    'Review rencana harian',
    'Ibadah tepat waktu',
    'Jalan kaki 5000 langkah',
  ];

  @override
  void initState() {
    super.initState();
    final group = widget.initialGroup;
    _titleController = TextEditingController(text: group?.title ?? '');
    _taskInputController = TextEditingController();
    _tasks = group != null ? List<String>.from(group.tasks) : [];

    final now = DateTime.now();
    _startDate = group?.startDate ?? DateTime(now.year, now.month, now.day);
    _endDate = group?.endDate ??
        DateTime(now.year, now.month, now.day).add(const Duration(days: 6));

    _reminderEnabled = group?.reminderEnabled ?? false;
    _reminderType = group?.reminderType ?? 'specific';
    _reminderIntervalMinutes = group?.reminderIntervalMinutes ?? 60;
    _reminderIntervalStartTime = group?.reminderIntervalStartTime ?? '08:00';
    _reminderIntervalEndTime = group?.reminderIntervalEndTime ?? '21:00';
    _reminderSpecificTimes = group != null
        ? List<String>.from(group.reminderSpecificTimes)
        : ['09:00', '13:00', '19:00'];
    _reminderSoundType = group?.reminderSoundType ?? 'default';
    _reminderDefaultSound = group?.reminderDefaultSound ?? 'chime_classic';
    _reminderCustomSoundPath = group?.reminderCustomSoundPath;
    _reminderCustomSoundName = group?.reminderCustomSoundName;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _taskInputController.dispose();
    _taskFocusNode.dispose();
    super.dispose();
  }

  void _addTask() {
    final text = _taskInputController.text.trim();
    if (text.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _tasks.add(text);
        _taskInputController.clear();
      });
      _taskFocusNode.requestFocus();
    }
  }

  void _removeTask(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _tasks.removeAt(index);
    });
  }

  void _addSuggestedTask(String suggestion) {
    if (!_tasks.contains(suggestion)) {
      HapticFeedback.lightImpact();
      setState(() {
        _tasks.add(suggestion);
      });
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      ),
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
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _setPresetDays(int days) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final s = DateTime(now.year, now.month, now.day);
    setState(() {
      _startDate = s;
      _endDate = s.add(Duration(days: days - 1));
    });
  }

  Future<void> _configureAlarm() async {
    await TodoAlarmService.requestOverlayPermissionWithDialog(context);
    if (!mounted) return;

    final dummyGroup = TodoDateGroup(
      id: 'template',
      date: _startDate,
      reminderEnabled: _reminderEnabled,
      reminderType: _reminderType,
      reminderIntervalMinutes: _reminderIntervalMinutes,
      reminderIntervalStartTime: _reminderIntervalStartTime,
      reminderIntervalEndTime: _reminderIntervalEndTime,
      reminderSpecificTimes: _reminderSpecificTimes,
      reminderSoundType: _reminderSoundType,
      reminderDefaultSound: _reminderDefaultSound,
      reminderCustomSoundPath: _reminderCustomSoundPath,
      reminderCustomSoundName: _reminderCustomSoundName,
    );

    final res = await TodoAlarmSetupSheet.show(
      context,
      initialConfig: TodoAlarmConfig.fromGroup(dummyGroup),
      dateTitle: 'Tugas Harian (${_titleController.text.trim().isEmpty ? "Grup Aktivitas" : _titleController.text.trim()})',
    );

    if (res != null) {
      setState(() {
        _reminderEnabled = res.enabled;
        _reminderType = res.type;
        _reminderIntervalMinutes = res.intervalMinutes;
        _reminderIntervalStartTime = res.intervalStartTime;
        _reminderIntervalEndTime = res.intervalEndTime;
        _reminderSpecificTimes = List<String>.from(res.specificTimes);
        _reminderSoundType = res.soundType;
        _reminderDefaultSound = res.defaultSound;
        _reminderCustomSoundPath = res.customSoundPath;
        _reminderCustomSoundName = res.customSoundName;
      });
    }
  }

  String get _soundLabel {
    if (_reminderSoundType == 'custom') {
      return _reminderCustomSoundName ?? 'Kustom MP3';
    }
    switch (_reminderDefaultSound) {
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

  String get _alarmSummary {
    if (!_reminderEnabled) return 'Alarm nonaktif';
    if (_reminderType == 'interval') {
      final hours = _reminderIntervalMinutes ~/ 60;
      final mins = _reminderIntervalMinutes % 60;
      String intervalStr = '';
      if (hours > 0 && mins > 0) {
        intervalStr = '$hours Jam $mins Mnt';
      } else if (hours > 0) {
        intervalStr = '$hours Jam';
      } else {
        intervalStr = '$mins Mnt';
      }
      return 'Tiap $intervalStr ($_reminderIntervalStartTime - $_reminderIntervalEndTime) • $_soundLabel';
    } else {
      final times = _reminderSpecificTimes.isEmpty
          ? 'Belum diatur'
          : _reminderSpecificTimes.join(', ');
      return 'Jam: $times • $_soundLabel';
    }
  }

  int get _totalDaysCount {
    final s = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final e = DateTime(_endDate.year, _endDate.month, _endDate.day);
    return e.difference(s).inDays + 1;
  }

  DailyTaskGroup _buildDailyTaskGroup() {
    final id = widget.initialGroup?.id ??
        'daily_group_${DateTime.now().millisecondsSinceEpoch}';
    return DailyTaskGroup(
      id: id,
      title: _titleController.text.trim().isEmpty
          ? 'Grup Aktivitas'
          : _titleController.text.trim(),
      tasks: List<String>.from(_tasks),
      startDate: _startDate,
      endDate: _endDate,
      reminderEnabled: _reminderEnabled,
      reminderType: _reminderType,
      reminderIntervalMinutes: _reminderIntervalMinutes,
      reminderIntervalStartTime: _reminderIntervalStartTime,
      reminderIntervalEndTime: _reminderIntervalEndTime,
      reminderSpecificTimes: List<String>.from(_reminderSpecificTimes),
      reminderSoundType: _reminderSoundType,
      reminderDefaultSound: _reminderDefaultSound,
      reminderCustomSoundPath: _reminderCustomSoundPath,
      reminderCustomSoundName: _reminderCustomSoundName,
      createdAt: widget.initialGroup?.createdAt,
    );
  }

  void _submit({required bool shouldApply}) {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masukkan judul grup aktivitas!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tambahkan minimal 1 tugas pada grup aktivitas!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final group = _buildDailyTaskGroup();
    Navigator.pop(context, {
      'group': group,
      'shouldApply': shouldApply,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialGroup != null;
    final totalDays = _totalDaysCount;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Handle bar
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
            const SizedBox(height: 14),

            // Header Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryTerracotta.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.event_repeat_rounded,
                      color: primaryTerracotta,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing
                              ? 'Edit Grup Aktivitas'
                              : 'Buat Grup Aktivitas Baru',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Kustomisasi tugas & terapkan otomatis ke section tanggal',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  ),
                ],
              ),
            ),

            const Divider(height: 20),

            // Scrollable Form Content
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                children: [
                  // 1. Judul Grup Aktivitas
                  const Text(
                    'Judul Grup Aktivitas',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    autofocus: !isEditing,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Misal: Kesehatan, Rutinitas Pagi, Belajar...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      prefixIcon: const Icon(
                        Icons.bookmark_outline_rounded,
                        color: primaryTerracotta,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: primaryTerracotta,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. Daftar Tugas dalam Grup
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Daftar Tugas Aktivitas',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                        ),
                      ),
                      Text(
                        '${_tasks.length} Tugas',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryTerracotta,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Input tambah tugas
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _taskInputController,
                          focusNode: _taskFocusNode,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _addTask(),
                          decoration: InputDecoration(
                            hintText: 'Ketik nama tugas lalu klik tambah...',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13.5,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[200]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[200]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: primaryTerracotta,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addTask,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTerracotta,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add_rounded, size: 18),
                            SizedBox(width: 4),
                            Text('Tambah', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Rekomendasi Tugas Cepat
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _quickTaskSuggestions.map((suggestion) {
                        final isAdded = _tasks.contains(suggestion);
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            avatar: Icon(
                              isAdded
                                  ? Icons.check_circle_rounded
                                  : Icons.add_circle_outline_rounded,
                              size: 14,
                              color: isAdded
                                  ? Colors.grey
                                  : primaryTerracotta,
                            ),
                            label: Text(
                              suggestion,
                              style: TextStyle(
                                fontSize: 11,
                                color: isAdded
                                    ? Colors.grey
                                    : const Color(0xFF334155),
                                fontWeight: isAdded
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                              ),
                            ),
                            backgroundColor: isAdded
                                ? Colors.grey[100]
                                : primaryTerracotta.withValues(alpha: 0.08),
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            onPressed: isAdded
                                ? null
                                : () => _addSuggestedTask(suggestion),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Daftar tugas yang telah dimasukkan
                  if (_tasks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _tasks.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Colors.grey[200],
                        ),
                        itemBuilder: (context, idx) {
                          final taskName = _tasks[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: primaryTerracotta.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${idx + 1}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: primaryTerracotta,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    taskName,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: Color(0xFF1E293B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                    size: 19,
                                  ),
                                  tooltip: 'Hapus Tugas',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _removeTask(idx),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),

                  // 3. Pilihan Rentang Tanggal
                  const Text(
                    'Pilih Rentang Tanggal Penerapan',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tugas akan otomatis dibuat pada setiap section tanggal dalam rentang',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Preset Rentang Tanggal Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildPresetChip(label: 'Hari Ini (1 Hari)', days: 1),
                        _buildPresetChip(label: '3 Hari', days: 3),
                        _buildPresetChip(label: '7 Hari (Seminggu)', days: 7),
                        _buildPresetChip(label: '14 Hari (2 Minggu)', days: 14),
                        _buildPresetChip(label: '30 Hari (Sebulan)', days: 30),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Card Rentang Tanggal
                  InkWell(
                    onTap: _pickDateRange,
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryTerracotta.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.date_range_rounded,
                              color: primaryTerracotta,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Rentang Tanggal Section',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_startDate.day}/${_startDate.month}/${_startDate.year}  →  ${_endDate.day}/${_endDate.month}/${_endDate.year}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: primaryTerracotta.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$totalDays Hari',
                              style: const TextStyle(
                                color: primaryTerracotta,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.edit_calendar_rounded,
                            color: primaryTerracotta,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 4. Toggle Alarm & Setting Alarm
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _reminderEnabled
                          ? primaryTerracotta.withValues(alpha: 0.05)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _reminderEnabled
                            ? primaryTerracotta.withValues(alpha: 0.4)
                            : Colors.grey[200]!,
                        width: _reminderEnabled ? 1.5 : 1,
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
                                color: _reminderEnabled
                                    ? primaryTerracotta
                                    : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.alarm_rounded,
                                color: _reminderEnabled
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
                                    'Terapkan Alarm Sekaligus',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    _reminderEnabled
                                        ? 'Alarm akan aktif berbunyi pada setiap section tanggal'
                                        : 'Nyalakan alarm pengingat tugas harian',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _reminderEnabled
                                          ? darkTerracotta
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _reminderEnabled,
                              activeThumbColor: primaryTerracotta,
                              onChanged: (val) async {
                                if (val) {
                                  await _configureAlarm();
                                } else {
                                  setState(() {
                                    _reminderEnabled = false;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        if (_reminderEnabled) ...[
                          const SizedBox(height: 8),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '🔔 $_alarmSummary',
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
                                onPressed: _configureAlarm,
                                icon: const Icon(
                                  Icons.tune_rounded,
                                  size: 14,
                                  color: primaryTerracotta,
                                ),
                                label: const Text(
                                  'Atur Ulang',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: primaryTerracotta,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Text(
                    '* Catatan: Pengaturan alarm dapat diatur ulang secara individual pada masing-masing section tanggal setelah diterapkan.',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Actions: Simpan & Terapkan vs Simpan Saja
            Container(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: OutlinedButton(
                      onPressed: () => _submit(shouldApply: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Hanya Simpan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 6,
                    child: ElevatedButton.icon(
                      onPressed: () => _submit(shouldApply: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryTerracotta,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text(
                        'Simpan & Terapkan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
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
    );
  }

  Widget _buildPresetChip({required String label, required int days}) {
    final now = DateTime.now();
    final s = DateTime(now.year, now.month, now.day);
    final targetEnd = s.add(Duration(days: days - 1));
    final isSelected = _startDate.year == s.year &&
        _startDate.month == s.month &&
        _startDate.day == s.day &&
        _endDate.year == targetEnd.year &&
        _endDate.month == targetEnd.month &&
        _endDate.day == targetEnd.day;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 11.5,
          color: isSelected ? primaryTerracotta : const Color(0xFF475569),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        selectedColor: primaryTerracotta.withValues(alpha: 0.15),
        backgroundColor: const Color(0xFFF1F5F9),
        side: BorderSide(
          color: isSelected ? primaryTerracotta : Colors.transparent,
        ),
        checkmarkColor: primaryTerracotta,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        onSelected: (_) => _setPresetDays(days),
      ),
    );
  }
}
