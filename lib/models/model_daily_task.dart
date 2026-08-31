import 'package:daily_apps/models/model_todo.dart';

class DailyTaskGroup {
  String id;
  String title;
  List<String> tasks;
  DateTime? startDate;
  DateTime? endDate;

  // Konfigurasi Alarm
  bool reminderEnabled;
  String reminderType; // 'interval' | 'specific'
  int reminderIntervalMinutes;
  String reminderIntervalStartTime;
  String reminderIntervalEndTime;
  List<String> reminderSpecificTimes;
  String reminderSoundType; // 'default' | 'custom'
  String reminderDefaultSound;
  String? reminderCustomSoundPath;
  String? reminderCustomSoundName;

  DateTime createdAt;

  DailyTaskGroup({
    required this.id,
    required this.title,
    required this.tasks,
    this.startDate,
    this.endDate,
    this.reminderEnabled = false,
    this.reminderType = 'specific',
    this.reminderIntervalMinutes = 60,
    this.reminderIntervalStartTime = '08:00',
    this.reminderIntervalEndTime = '21:00',
    List<String>? reminderSpecificTimes,
    this.reminderSoundType = 'default',
    this.reminderDefaultSound = 'chime_classic',
    this.reminderCustomSoundPath,
    this.reminderCustomSoundName,
    DateTime? createdAt,
  })  : reminderSpecificTimes =
            reminderSpecificTimes ?? ['09:00', '13:00', '19:00'],
        createdAt = createdAt ?? DateTime.now();

  int get totalTasks => tasks.length;

  String get dateRangeSummary {
    if (startDate == null || endDate == null) {
      return 'Belum ditentukan';
    }
    final s = startDate!;
    final e = endDate!;
    final totalDays = e.difference(s).inDays + 1;
    return '${s.day}/${s.month}/${s.year} - ${e.day}/${e.month}/${e.year} ($totalDays hari)';
  }

  String get reminderSoundDisplayName {
    if (reminderSoundType == 'custom') {
      return reminderCustomSoundName ?? 'Kustom MP3';
    }
    switch (reminderDefaultSound) {
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

  String get reminderSummaryLabel {
    if (!reminderEnabled) return 'Alarm nonaktif';
    final soundName = reminderSoundDisplayName;
    if (reminderType == 'interval') {
      final hours = reminderIntervalMinutes ~/ 60;
      final mins = reminderIntervalMinutes % 60;
      String intervalStr = '';
      if (hours > 0 && mins > 0) {
        intervalStr = '$hours jam $mins mnt';
      } else if (hours > 0) {
        intervalStr = '$hours jam';
      } else {
        intervalStr = '$mins mnt';
      }
      return 'Tiap $intervalStr ($reminderIntervalStartTime - $reminderIntervalEndTime) • $soundName';
    } else {
      final times = reminderSpecificTimes.isEmpty
          ? 'Belum diatur'
          : reminderSpecificTimes.join(', ');
      return 'Jam: $times • $soundName';
    }
  }

  DailyTaskGroup copyWith({
    String? id,
    String? title,
    List<String>? tasks,
    DateTime? startDate,
    DateTime? endDate,
    bool? reminderEnabled,
    String? reminderType,
    int? reminderIntervalMinutes,
    String? reminderIntervalStartTime,
    String? reminderIntervalEndTime,
    List<String>? reminderSpecificTimes,
    String? reminderSoundType,
    String? reminderDefaultSound,
    String? reminderCustomSoundPath,
    String? reminderCustomSoundName,
    DateTime? createdAt,
  }) {
    return DailyTaskGroup(
      id: id ?? this.id,
      title: title ?? this.title,
      tasks: tasks ?? List<String>.from(this.tasks),
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderType: reminderType ?? this.reminderType,
      reminderIntervalMinutes:
          reminderIntervalMinutes ?? this.reminderIntervalMinutes,
      reminderIntervalStartTime:
          reminderIntervalStartTime ?? this.reminderIntervalStartTime,
      reminderIntervalEndTime:
          reminderIntervalEndTime ?? this.reminderIntervalEndTime,
      reminderSpecificTimes:
          reminderSpecificTimes ?? List<String>.from(this.reminderSpecificTimes),
      reminderSoundType: reminderSoundType ?? this.reminderSoundType,
      reminderDefaultSound:
          reminderDefaultSound ?? this.reminderDefaultSound,
      reminderCustomSoundPath:
          reminderCustomSoundPath ?? this.reminderCustomSoundPath,
      reminderCustomSoundName:
          reminderCustomSoundName ?? this.reminderCustomSoundName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'tasks': tasks,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'reminderEnabled': reminderEnabled,
        'reminderType': reminderType,
        'reminderIntervalMinutes': reminderIntervalMinutes,
        'reminderIntervalStartTime': reminderIntervalStartTime,
        'reminderIntervalEndTime': reminderIntervalEndTime,
        'reminderSpecificTimes': reminderSpecificTimes,
        'reminderSoundType': reminderSoundType,
        'reminderDefaultSound': reminderDefaultSound,
        'reminderCustomSoundPath': reminderCustomSoundPath,
        'reminderCustomSoundName': reminderCustomSoundName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DailyTaskGroup.fromJson(Map<String, dynamic> json) {
    List<String> parsedTasks = [];
    if (json['tasks'] is List) {
      parsedTasks =
          (json['tasks'] as List).map((item) => item.toString()).toList();
    }

    List<String> parsedTimes = ['09:00', '13:00', '19:00'];
    if (json['reminderSpecificTimes'] is List) {
      parsedTimes = (json['reminderSpecificTimes'] as List)
          .map((e) => e.toString())
          .toList();
    }

    return DailyTaskGroup(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? '',
      tasks: parsedTasks,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString())
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'].toString())
          : null,
      reminderEnabled: json['reminderEnabled'] as bool? ?? false,
      reminderType: json['reminderType'] as String? ?? 'specific',
      reminderIntervalMinutes: json['reminderIntervalMinutes'] as int? ?? 60,
      reminderIntervalStartTime:
          json['reminderIntervalStartTime'] as String? ?? '08:00',
      reminderIntervalEndTime:
          json['reminderIntervalEndTime'] as String? ?? '21:00',
      reminderSpecificTimes: parsedTimes,
      reminderSoundType: json['reminderSoundType'] as String? ?? 'default',
      reminderDefaultSound:
          json['reminderDefaultSound'] as String? ?? 'chime_classic',
      reminderCustomSoundPath: json['reminderCustomSoundPath'] as String?,
      reminderCustomSoundName: json['reminderCustomSoundName'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Terapkan grup tugas ini ke rentang tanggal tertentu pada list TodoDateGroup
  static List<TodoDateGroup> applyGroupToDateGroups({
    required List<TodoDateGroup> existingGroups,
    required DailyTaskGroup taskGroup,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    bool overwriteAlarm = true,
  }) {
    final List<TodoDateGroup> result = List.from(existingGroups);

    // Normalisasi start dan end date ke midnight
    DateTime curr = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final DateTime end = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);

    while (!curr.isAfter(end)) {
      final targetDate = curr;

      // Cari apakah section tanggal sudah ada
      final existingIndex = result.indexWhere((g) =>
          g.date.year == targetDate.year &&
          g.date.month == targetDate.month &&
          g.date.day == targetDate.day &&
          !g.isArchived);

      if (existingIndex != -1) {
        // Update section yang sudah ada
        final existingGroup = result[existingIndex];
        final currentTaskTitles =
            existingGroup.items.map((i) => i.title.trim().toLowerCase()).toSet();

        for (final taskTitle in taskGroup.tasks) {
          if (taskTitle.trim().isNotEmpty) {
            // Jika belum ada tugas yang sama, tambahkan
            if (!currentTaskTitles.contains(taskTitle.trim().toLowerCase())) {
              existingGroup.items.add(
                TodoItem(
                  id: '${DateTime.now().microsecondsSinceEpoch}_${existingGroup.items.length}',
                  title: taskTitle.trim(),
                  isCompleted: false,
                ),
              );
            }
          }
        }

        // Terapkan alarm jika taskGroup mengaktifkan alarm
        if (taskGroup.reminderEnabled &&
            (overwriteAlarm || !existingGroup.reminderEnabled)) {
          existingGroup.reminderEnabled = true;
          existingGroup.reminderType = taskGroup.reminderType;
          existingGroup.reminderIntervalMinutes =
              taskGroup.reminderIntervalMinutes;
          existingGroup.reminderIntervalStartTime =
              taskGroup.reminderIntervalStartTime;
          existingGroup.reminderIntervalEndTime =
              taskGroup.reminderIntervalEndTime;
          existingGroup.reminderSpecificTimes =
              List<String>.from(taskGroup.reminderSpecificTimes);
          existingGroup.reminderSoundType = taskGroup.reminderSoundType;
          existingGroup.reminderDefaultSound = taskGroup.reminderDefaultSound;
          existingGroup.reminderCustomSoundPath =
              taskGroup.reminderCustomSoundPath;
          existingGroup.reminderCustomSoundName =
              taskGroup.reminderCustomSoundName;
        }
      } else {
        // Buat section tanggal baru
        final newItems = taskGroup.tasks
            .where((t) => t.trim().isNotEmpty)
            .map((t) => TodoItem(
                  id: '${DateTime.now().microsecondsSinceEpoch}_${t.hashCode}',
                  title: t.trim(),
                  isCompleted: false,
                ))
            .toList();

        final newGroup = TodoDateGroup(
          id: 'group_${targetDate.millisecondsSinceEpoch}',
          date: targetDate,
          items: newItems,
          reminderEnabled: taskGroup.reminderEnabled,
          reminderType: taskGroup.reminderType,
          reminderIntervalMinutes: taskGroup.reminderIntervalMinutes,
          reminderIntervalStartTime: taskGroup.reminderIntervalStartTime,
          reminderIntervalEndTime: taskGroup.reminderIntervalEndTime,
          reminderSpecificTimes:
              List<String>.from(taskGroup.reminderSpecificTimes),
          reminderSoundType: taskGroup.reminderSoundType,
          reminderDefaultSound: taskGroup.reminderDefaultSound,
          reminderCustomSoundPath: taskGroup.reminderCustomSoundPath,
          reminderCustomSoundName: taskGroup.reminderCustomSoundName,
        );
        result.add(newGroup);
      }

      curr = curr.add(const Duration(days: 1));
    }

    // Urutkan tanggal dari yang terbaru (atau sesuai tanggal menaik/menurun)
    result.sort((a, b) => b.date.compareTo(a.date));

    return result;
  }
}
