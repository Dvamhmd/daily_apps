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

  TodoDateGroup({
    required this.id,
    required this.date,
    List<TodoItem>? items,
  }) : items = items ?? [];

  int get totalCount => items.length;
  int get completedCount => items.where((item) => item.isCompleted).length;
  double get progress => totalCount == 0 ? 0.0 : completedCount / totalCount;
  bool get isAllCompleted => totalCount > 0 && completedCount == totalCount;

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
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

    return TodoDateGroup(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      date: rawDate,
      items: parsedItems,
    );
  }
}
