class TodoItem {
  String id;
  String title;
  bool isCompleted;
  DateTime createdAt;

  TodoItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  TodoItem copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class TodoDateGroup {
  String id;
  DateTime date;
  List<TodoItem> items;
  bool isArchived;
  bool isCollapsed;

  // Reminder / Alarm configuration
  bool reminderEnabled;
  String reminderType; // 'interval' | 'specific'
  int reminderIntervalMinutes;
  String reminderIntervalStartTime;
  String reminderIntervalEndTime;
  List<String> reminderSpecificTimes;
  String reminderSoundType; // 'default' | 'custom'
  String reminderDefaultSound; // 'chime_classic', 'alarm_digital', 'gentle_bell', 'cheerful_melody'
  String? reminderCustomSoundPath;
  String? reminderCustomSoundName;

  TodoDateGroup({
    required this.id,
    required this.date,
    List<TodoItem>? items,
    this.isArchived = false,
    this.isCollapsed = false,
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
  })  : items = items ?? [],
        reminderSpecificTimes = reminderSpecificTimes ?? ['09:00', '13:00', '19:00'];

  int get totalCount => items.length;
  int get completedCount => items.where((item) => item.isCompleted).length;
  int get pendingCount => items.where((item) => !item.isCompleted).length;
  double get progress => totalCount == 0 ? 0.0 : completedCount / totalCount;
  bool get isAllCompleted => totalCount > 0 && completedCount == totalCount;
  List<TodoItem> get pendingItems => items.where((item) => !item.isCompleted).toList();

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  bool get isPast {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groupDate = DateTime(date.year, date.month, date.day);
    return groupDate.isBefore(today);
  }

  bool get isAlarmActive =>
      reminderEnabled && !isArchived && !isAllCompleted && !isPast;

  static const List<String> _namaHari = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu'
  ];

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

  String get relativeDateLabel {
    if (isToday) return 'Hari Ini';
    if (isTomorrow) return 'Besok';
    if (isYesterday) return 'Kemarin';
    return _namaHari[(date.weekday - 1).clamp(0, 6)];
  }

  String get formattedFullDate {
    final dayName = _namaHari[(date.weekday - 1).clamp(0, 6)];
    final monthName = _namaBulan[(date.month - 1).clamp(0, 11)];
    return '$dayName, ${date.day} $monthName ${date.year}';
  }

  String get formattedDateShort {
    final monthName = _namaBulan[(date.month - 1).clamp(0, 11)];
    return '${date.day} $monthName ${date.year}';
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
    if (!reminderEnabled) return 'Pengingat nonaktif';
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
      final times = reminderSpecificTimes.isEmpty ? 'Belum diatur' : reminderSpecificTimes.join(', ');
      return 'Jam: $times • $soundName';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
        'isArchived': isArchived,
        'isCollapsed': isCollapsed,
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
      };

  factory TodoDateGroup.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] != null
        ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
        : DateTime.now();

    List<TodoItem> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((item) => TodoItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    List<String> parsedTimes = ['09:00', '13:00', '19:00'];
    if (json['reminderSpecificTimes'] is List) {
      parsedTimes = (json['reminderSpecificTimes'] as List)
          .map((e) => e.toString())
          .toList();
    }

    return TodoDateGroup(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      date: rawDate,
      items: parsedItems,
      isArchived: json['isArchived'] as bool? ?? false,
      isCollapsed: json['isCollapsed'] as bool? ?? false,
      reminderEnabled: json['reminderEnabled'] as bool? ?? false,
      reminderType: json['reminderType'] as String? ?? 'specific',
      reminderIntervalMinutes: json['reminderIntervalMinutes'] as int? ?? 60,
      reminderIntervalStartTime: json['reminderIntervalStartTime'] as String? ?? '08:00',
      reminderIntervalEndTime: json['reminderIntervalEndTime'] as String? ?? '21:00',
      reminderSpecificTimes: parsedTimes,
      reminderSoundType: json['reminderSoundType'] as String? ?? 'default',
      reminderDefaultSound: json['reminderDefaultSound'] as String? ?? 'chime_classic',
      reminderCustomSoundPath: json['reminderCustomSoundPath'] as String?,
      reminderCustomSoundName: json['reminderCustomSoundName'] as String?,
    );
  }
}
