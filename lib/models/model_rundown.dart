class RundownTableRow {
  String id;
  String startTime;
  int durationMinutes;
  String activity;
  String location;
  Map<String, String> customValues;

  RundownTableRow({
    required this.id,
    this.startTime = '',
    int? durationMinutes,
    String? endTime,
    this.activity = '',
    this.location = '',
    Map<String, String>? customValues,
  })  : durationMinutes = durationMinutes ?? _inferDuration(startTime, endTime),
        customValues = customValues ?? {};

  static int _inferDuration(String start, String? end) {
    if (start.isEmpty || end == null || end.isEmpty) return 60;
    try {
      final sParts = start.split(':').map((e) => int.parse(e.trim())).toList();
      final eParts = end.split(':').map((e) => int.parse(e.trim())).toList();
      if (sParts.length == 2 && eParts.length == 2) {
        int sMin = sParts[0] * 60 + sParts[1];
        int eMin = eParts[0] * 60 + eParts[1];
        if (eMin < sMin) eMin += 24 * 60;
        final diff = eMin - sMin;
        return diff > 0 ? diff : 60;
      }
    } catch (_) {}
    return 60;
  }

  /// Waktu berhenti = Waktu mulai + Durasi
  String get endTime {
    if (startTime.trim().isEmpty) return '';
    return calculateEndTime(startTime, durationMinutes);
  }

  static String calculateEndTime(String start, int durationMins) {
    if (start.trim().isEmpty) return '';
    try {
      final parts =
          start.split(':').map((e) => int.parse(e.trim())).toList();
      if (parts.length == 2) {
        int totalMinutes = parts[0] * 60 + parts[1] + durationMins;
        int endHour = (totalMinutes ~/ 60) % 24;
        int endMin = totalMinutes % 60;
        return '${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    return '';
  }

  String get durationText {
    if (durationMinutes <= 0) return '-';
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return '$hours j $minutes m';
    } else if (hours > 0) {
      return '$hours jam';
    } else {
      return '$minutes mnt';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime,
        'durationMinutes': durationMinutes,
        'endTime': endTime,
        'activity': activity,
        'location': location,
        'customValues': customValues,
      };

  factory RundownTableRow.fromJson(Map<String, dynamic> json) {
    Map<String, String> customMap = {};
    if (json['customValues'] is Map) {
      (json['customValues'] as Map).forEach((k, v) {
        customMap[k.toString()] = v?.toString() ?? '';
      });
    }

    final startVal = json['startTime'] as String? ?? '';
    final endVal = json['endTime'] as String? ?? '';
    final durVal = json['durationMinutes'] as int? ??
        _inferDuration(startVal, endVal);

    final activityVal = json['activity'] as String? ??
        json['title'] as String? ??
        '';

    return RundownTableRow(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      startTime: startVal,
      durationMinutes: durVal,
      activity: activityVal,
      location: json['location'] as String? ?? '',
      customValues: customMap,
    );
  }

  RundownTableRow clone() {
    return RundownTableRow(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      startTime: startTime,
      durationMinutes: durationMinutes,
      activity: activity,
      location: location,
      customValues: Map<String, String>.from(customValues),
    );
  }
}

class RundownDay {
  final int dayNumber;
  final DateTime date;
  final String theme;
  final List<String> customColumns;
  final List<RundownTableRow> rows;

  RundownDay({
    required this.dayNumber,
    required this.date,
    required this.theme,
    List<String>? customColumns,
    List<RundownTableRow>? rows,
  })  : customColumns = customColumns ?? [],
        rows = rows ?? [];

  /// Factory helper to create a day with 5 initial connected rows
  factory RundownDay.createWithDefaultRows({
    required int dayNumber,
    required DateTime date,
    required String theme,
    int initialRowCount = 5,
  }) {
    final rows = <RundownTableRow>[];
    String currentStart = '08:00';
    const defaultDurations = [60, 30, 30, 60, 60];

    for (int i = 0; i < initialRowCount; i++) {
      final dur = i < defaultDurations.length ? defaultDurations[i] : 60;
      final row = RundownTableRow(
        id: '${DateTime.now().millisecondsSinceEpoch}_row_$i',
        startTime: currentStart,
        durationMinutes: dur,
      );
      rows.add(row);
      currentStart = row.endTime;
    }

    return RundownDay(
      dayNumber: dayNumber,
      date: date,
      theme: theme,
      customColumns: [],
      rows: rows,
    );
  }

  Map<String, dynamic> toJson() => {
        'dayNumber': dayNumber,
        'date': date.toIso8601String(),
        'theme': theme,
        'customColumns': customColumns,
        'rows': rows.map((e) => e.toJson()).toList(),
      };

  factory RundownDay.fromJson(Map<String, dynamic> json) {
    List<RundownTableRow> parsedRows = [];
    if (json['rows'] is List) {
      parsedRows = (json['rows'] as List)
          .map((e) => RundownTableRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['items'] is List) {
      parsedRows = (json['items'] as List)
          .map((e) => RundownTableRow.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // If rows are empty upon loading, ensure at least 5 default rows
    if (parsedRows.isEmpty) {
      return RundownDay.createWithDefaultRows(
        dayNumber: json['dayNumber'] as int? ?? 1,
        date: json['date'] != null
            ? DateTime.parse(json['date'] as String)
            : DateTime.now(),
        theme: json['theme'] as String? ?? '',
      );
    }

    List<String> parsedCols = [];
    if (json['customColumns'] is List) {
      parsedCols = (json['customColumns'] as List)
          .map((e) => e.toString())
          .toList();
    }

    return RundownDay(
      dayNumber: json['dayNumber'] as int? ?? 1,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      theme: json['theme'] as String? ?? '',
      customColumns: parsedCols,
      rows: parsedRows,
    );
  }

  RundownDay copyWith({
    int? dayNumber,
    DateTime? date,
    String? theme,
    List<String>? customColumns,
    List<RundownTableRow>? rows,
  }) {
    return RundownDay(
      dayNumber: dayNumber ?? this.dayNumber,
      date: date ?? this.date,
      theme: theme ?? this.theme,
      customColumns: customColumns ?? this.customColumns,
      rows: rows ?? this.rows,
    );
  }
}

class Rundown {
  final String id;
  final String title;
  final DateTime startDate;
  final int totalDays;
  final List<RundownDay> days;
  final DateTime createdAt;

  Rundown({
    required this.id,
    required this.title,
    required this.startDate,
    required this.totalDays,
    required this.days,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  DateTime get endDate => startDate.add(Duration(days: totalDays - 1));

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startDate': startDate.toIso8601String(),
        'totalDays': totalDays,
        'days': days.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Rundown.fromJson(Map<String, dynamic> json) {
    return Rundown(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? '',
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : DateTime.now(),
      totalDays: json['totalDays'] as int? ?? 1,
      days: (json['days'] as List<dynamic>?)
              ?.map((e) => RundownDay.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Rundown copyWith({
    String? id,
    String? title,
    DateTime? startDate,
    int? totalDays,
    List<RundownDay>? days,
    DateTime? createdAt,
  }) {
    return Rundown(
      id: id ?? this.id,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      totalDays: totalDays ?? this.totalDays,
      days: days ?? this.days,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
