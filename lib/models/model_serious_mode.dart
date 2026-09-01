class SeriousUser {
  final String id;
  final String username;
  final String password;
  final String displayName;
  final String? avatarBase64;
  final int avatarIndex; // 0..7 untuk preset avatar jika tanpa foto
  int totalPoints;
  int totalTasksCompleted;
  int totalPunishmentsTaken;
  final DateTime registeredAt;
  DateTime lastActiveAt;

  SeriousUser({
    required this.id,
    required this.username,
    required this.password,
    required this.displayName,
    this.avatarBase64,
    this.avatarIndex = 0,
    this.totalPoints = 0,
    this.totalTasksCompleted = 0,
    this.totalPunishmentsTaken = 0,
    DateTime? registeredAt,
    DateTime? lastActiveAt,
  })  : registeredAt = registeredAt ?? DateTime.now(),
        lastActiveAt = lastActiveAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'password': password,
        'displayName': displayName,
        'avatarBase64': avatarBase64,
        'avatarIndex': avatarIndex,
        'totalPoints': totalPoints,
        'totalTasksCompleted': totalTasksCompleted,
        'totalPunishmentsTaken': totalPunishmentsTaken,
        'registeredAt': registeredAt.toIso8601String(),
        'lastActiveAt': lastActiveAt.toIso8601String(),
      };

  factory SeriousUser.fromJson(Map<String, dynamic> json) {
    return SeriousUser(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      displayName: json['displayName'] as String? ??
          json['username'] as String? ??
          'Player',
      avatarBase64: json['avatarBase64'] as String?,
      avatarIndex: json['avatarIndex'] as int? ?? 0,
      totalPoints: (json['totalPoints'] as num?)?.toInt() ?? 0,
      totalTasksCompleted:
          (json['totalTasksCompleted'] as num?)?.toInt() ?? 0,
      totalPunishmentsTaken:
          (json['totalPunishmentsTaken'] as num?)?.toInt() ?? 0,
      registeredAt: json['registeredAt'] != null
          ? DateTime.tryParse(json['registeredAt'].toString()) ??
              DateTime.now()
          : DateTime.now(),
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.tryParse(json['lastActiveAt'].toString()) ??
              DateTime.now()
          : DateTime.now(),
    );
  }

  SeriousUser copyWith({
    String? id,
    String? username,
    String? password,
    String? displayName,
    String? avatarBase64,
    int? avatarIndex,
    int? totalPoints,
    int? totalTasksCompleted,
    int? totalPunishmentsTaken,
    DateTime? registeredAt,
    DateTime? lastActiveAt,
  }) {
    return SeriousUser(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      displayName: displayName ?? this.displayName,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      totalPoints: totalPoints ?? this.totalPoints,
      totalTasksCompleted:
          totalTasksCompleted ?? this.totalTasksCompleted,
      totalPunishmentsTaken:
          totalPunishmentsTaken ?? this.totalPunishmentsTaken,
      registeredAt: registeredAt ?? this.registeredAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
}

/// Evaluasi performa section harian yang telah lewat
class SeriousSectionEvaluation {
  final String groupId;
  final DateTime date;
  final int completedCount;
  final int pendingCount;
  final String message;
  final bool isPunishmentRequired;
  final bool isPunishmentOptional;
  final bool isExempt;
  final int pointsEarned;

  SeriousSectionEvaluation({
    required this.groupId,
    required this.date,
    required this.completedCount,
    required this.pendingCount,
    required this.message,
    required this.isPunishmentRequired,
    required this.isPunishmentOptional,
    required this.isExempt,
    required this.pointsEarned,
  });

  bool get hasIncompleteTasks => pendingCount > 0;
}

/// Pilihan hukuman olahraga fisik
class SeriousPunishmentItem {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final String category; // 'Fisik'
  final String repsOrDuration;
  final String targetMuscle;

  const SeriousPunishmentItem({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    this.category = 'Fisik',
    this.repsOrDuration = '',
    this.targetMuscle = 'Full Body',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'emoji': emoji,
        'category': category,
        'repsOrDuration': repsOrDuration,
        'targetMuscle': targetMuscle,
      };

  factory SeriousPunishmentItem.fromJson(Map<String, dynamic> json) {
    return SeriousPunishmentItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '💪',
      category: json['category'] as String? ?? 'Fisik',
      repsOrDuration: json['repsOrDuration'] as String? ?? '',
      targetMuscle: json['targetMuscle'] as String? ?? 'Full Body',
    );
  }
}

/// Status pengerjaan hukuman untuk section tanggal yang terlewat
class SeriousGroupPunishmentState {
  final String groupId;
  final List<String> assignedPunishmentIds;
  final List<String> completedPunishmentIds;
  final bool isSurrendered;
  final bool isFullyCompleted;
  final DateTime updatedAt;

  SeriousGroupPunishmentState({
    required this.groupId,
    required this.assignedPunishmentIds,
    this.completedPunishmentIds = const [],
    this.isSurrendered = false,
    this.isFullyCompleted = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  int get totalAssigned => assignedPunishmentIds.length;
  int get completedCount => completedPunishmentIds.length;
  int get remainingCount => (totalAssigned - completedCount).clamp(0, totalAssigned);
  bool get isAllCompleted => totalAssigned > 0 && completedCount >= totalAssigned;
  double get progress => totalAssigned == 0 ? 0.0 : (completedCount / totalAssigned).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'assignedPunishmentIds': assignedPunishmentIds,
        'completedPunishmentIds': completedPunishmentIds,
        'isSurrendered': isSurrendered,
        'isFullyCompleted': isFullyCompleted,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SeriousGroupPunishmentState.fromJson(Map<String, dynamic> json) {
    List<String> assigned = [];
    if (json['assignedPunishmentIds'] is List) {
      assigned = (json['assignedPunishmentIds'] as List).map((e) => e.toString()).toList();
    }
    List<String> completed = [];
    if (json['completedPunishmentIds'] is List) {
      completed = (json['completedPunishmentIds'] as List).map((e) => e.toString()).toList();
    }

    return SeriousGroupPunishmentState(
      groupId: json['groupId'] as String? ?? '',
      assignedPunishmentIds: assigned,
      completedPunishmentIds: completed,
      isSurrendered: json['isSurrendered'] as bool? ?? false,
      isFullyCompleted: json['isFullyCompleted'] as bool? ?? false,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  SeriousGroupPunishmentState copyWith({
    String? groupId,
    List<String>? assignedPunishmentIds,
    List<String>? completedPunishmentIds,
    bool? isSurrendered,
    bool? isFullyCompleted,
    DateTime? updatedAt,
  }) {
    return SeriousGroupPunishmentState(
      groupId: groupId ?? this.groupId,
      assignedPunishmentIds: assignedPunishmentIds ?? this.assignedPunishmentIds,
      completedPunishmentIds: completedPunishmentIds ?? this.completedPunishmentIds,
      isSurrendered: isSurrendered ?? this.isSurrendered,
      isFullyCompleted: isFullyCompleted ?? this.isFullyCompleted,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

