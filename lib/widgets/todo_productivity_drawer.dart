import 'dart:convert';
import 'package:daily_apps/models/model_serious_mode.dart';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/pages/daily_productivity_page.dart';
import 'package:daily_apps/pages/serious_punishment_config_page.dart';
import 'package:daily_apps/pages/todo_riwayat_page.dart';
import 'package:daily_apps/pages/tugas_harian_page.dart';
import 'package:daily_apps/utils/serious_mode_service.dart';
import 'package:daily_apps/widgets/serious_mode_auth_dialog.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TodoProductivityDrawer extends StatefulWidget {
  final List<TodoDateGroup> activeGroups;
  final VoidCallback? onDataChanged;
  final bool isSeriousMode;
  final VoidCallback? onOpenSeriousMode;
  final VoidCallback? onExitSeriousMode;

  const TodoProductivityDrawer({
    super.key,
    required this.activeGroups,
    this.onDataChanged,
    this.isSeriousMode = false,
    this.onOpenSeriousMode,
    this.onExitSeriousMode,
  });

  @override
  State<TodoProductivityDrawer> createState() => _TodoProductivityDrawerState();
}

class _TodoProductivityDrawerState extends State<TodoProductivityDrawer> {
  static const Color primaryTerracotta = Color(0xFFBA5A3A);
  static const Color darkTerracotta = Color(0xFF8C3E26);

  static const Color seriousBg = Color(0xFF0F172A);
  static const Color seriousCardBg = Color(0xFF1E293B);
  static const Color seriousGold = Color(0xFFF59E0B);
  static const Color seriousFire = Color(0xFFEF4444);

  List<TodoDateGroup> _allGroups = [];
  bool _isLoading = true;
  bool _isSeriousMode = false;
  SeriousUser? _seriousUser;
  String _punishmentMode = SeriousPunishmentMode.defaultMode;

  @override
  void initState() {
    super.initState();
    _isSeriousMode = widget.isSeriousMode;
    _loadAllTodoData();
  }

  @override
  void didUpdateWidget(covariant TodoProductivityDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSeriousMode != widget.isSeriousMode) {
      _isSeriousMode = widget.isSeriousMode;
      _loadAllTodoData();
    }
  }

  Future<void> _loadAllTodoData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSeriousMode = widget.isSeriousMode;
      _seriousUser = await SeriousModeService.getCurrentUser();
      _punishmentMode = await SeriousModeService.getPunishmentMode();

      final String prefsKey = _isSeriousMode && _seriousUser != null
          ? SeriousModeService.getSeriousTodoGroupsKey(
              SeriousModeService.getUserStorageIdentifier(_seriousUser))
          : (_isSeriousMode
              ? SeriousModeService.prefKeySeriousTodoGroups
              : SeriousModeService.prefKeyNormalTodoGroups);

      final String? jsonStr = prefs.getString(prefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _allGroups = decoded
            .map((item) => TodoDateGroup.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        _allGroups = List.from(widget.activeGroups);
      }
    } catch (e) {
      _allGroups = List.from(widget.activeGroups);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int get _todayCompletedCount {
    final now = DateTime.now();
    int count = 0;
    for (final group in _allGroups) {
      if (group.date.year == now.year &&
          group.date.month == now.month &&
          group.date.day == now.day) {
        count += group.completedCount;
      }
    }
    return count;
  }

  int get _thisMonthCompletedCount {
    final now = DateTime.now();
    int count = 0;
    for (final group in _allGroups) {
      if (group.date.year == now.year && group.date.month == now.month) {
        count += group.completedCount;
      }
    }
    return count;
  }

  int get _totalAllCompletedCount {
    int count = 0;
    for (final group in _allGroups) {
      count += group.completedCount;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor:
          _isSeriousMode ? seriousBg : const Color(0xFFF7F9FC),
      child: Column(
        children: [
          // Drawer Header
          _isSeriousMode
              ? _buildSeriousDrawerHeader()
              : _buildNormalDrawerHeader(),

          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: _isSeriousMode ? seriousGold : primaryTerracotta,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    children: [
                      // Top Quick Card
                      if (_isSeriousMode)
                        _buildSeriousPlayerCard()
                      else
                        _buildNormalQuickStatusCard(),

                      const SizedBox(height: 18),
                      Text(
                        _isSeriousMode
                            ? 'FITUR & MENU (MODE SERIUS)'
                            : 'FITUR & MENU (MODE BIASA)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isSeriousMode
                              ? const Color(0xFF94A3B8)
                              : Colors.grey[500],
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (_isSeriousMode) ...[
                        // Serious Mode Menu 1: Kembali ke Mode Biasa
                        _buildMenuItem(
                          context: context,
                          icon: Icons.swap_horiz_rounded,
                          iconColor: const Color(0xFF38BDF8),
                          title: 'Mode Biasa / Reguler',
                          subtitle:
                              'Kembali ke To-Do List normal (data terpisah)',
                          onTap: () {
                            Navigator.pop(context);
                            widget.onExitSeriousMode?.call();
                          },
                        ),

                        // Serious Mode Menu 2: Activity
                        _buildMenuItem(
                          context: context,
                          icon: Icons.insights_rounded,
                          iconColor: seriousGold,
                          title: 'Activity',
                          subtitle:
                              'Kalender aktivitas harian & riwayat mode serius',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DailyProductivityPage(
                                    isSeriousMode: true),
                              ),
                            ).then((_) {
                              widget.onDataChanged?.call();
                              _loadAllTodoData();
                            });
                          },
                        ),

                        // Serious Mode Menu 3: Tugas Harian
                        _buildMenuItem(
                          context: context,
                          icon: Icons.event_repeat_rounded,
                          iconColor: const Color(0xFFFB923C),
                          title: 'Tugas Harian',
                          subtitle:
                              'Set up & terapkan aktivitas ke to-do serius',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const TugasHarianPage(isSeriousMode: true),
                              ),
                            ).then((_) {
                              widget.onDataChanged?.call();
                              _loadAllTodoData();
                            });
                          },
                        ),

                        // Serious Mode Menu 4: Hukuman
                        _buildMenuItem(
                          context: context,
                          icon: Icons.tune_rounded,
                          iconColor: const Color(0xFFF43F5E),
                          title: 'Hukuman',
                          subtitle:
                              'Opsi mandiri, default, campuran & hukuman sendiri',
                          badgeText:
                              SeriousPunishmentMode.getShortLabel(_punishmentMode),
                          badgeColor: _punishmentMode ==
                                  SeriousPunishmentMode.mandiri
                              ? const Color(0xFF0369A1)
                              : (_punishmentMode ==
                                      SeriousPunishmentMode.campuran
                                  ? const Color(0xFF6B21A8)
                                  : const Color(0xFF92400E)),
                          badgeTextColor: _punishmentMode ==
                                  SeriousPunishmentMode.mandiri
                              ? const Color(0xFF7DD3FC)
                              : (_punishmentMode ==
                                      SeriousPunishmentMode.campuran
                                  ? const Color(0xFFD8B4FE)
                                  : const Color(0xFFFDE68A)),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const SeriousPunishmentConfigPage(),
                              ),
                            ).then((_) {
                              widget.onDataChanged?.call();
                              _loadAllTodoData();
                            });
                          },
                        ),
                      ] else ...[
                        // Normal Mode Menu 1: Mode Serius
                        _buildMenuItem(
                          context: context,
                          icon: Icons.local_fire_department_rounded,
                          iconColor: const Color(0xFFEF4444),
                          title: 'Mode Serius',
                          subtitle:
                              'To-do list tantangan, sistem poin, ranking & hukuman',
                          onTap: () {
                            Navigator.pop(context);
                            widget.onOpenSeriousMode?.call();
                          },
                        ),

                        // Normal Mode Menu 2: Tugas Harian
                        _buildMenuItem(
                          context: context,
                          icon: Icons.event_repeat_rounded,
                          iconColor: const Color(0xFFE65100),
                          title: 'Tugas Harian',
                          subtitle:
                              'Set up grup aktivitas & terapkan ke section normal',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const TugasHarianPage(isSeriousMode: false),
                              ),
                            ).then((_) {
                              widget.onDataChanged?.call();
                              _loadAllTodoData();
                            });
                          },
                        ),

                        // Normal Mode Menu 3: Activity
                        _buildMenuItem(
                          context: context,
                          icon: Icons.insights_rounded,
                          iconColor: primaryTerracotta,
                          title: 'Activity',
                          subtitle: 'Kalender aktivitas harian & pencapaian',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DailyProductivityPage(
                                    isSeriousMode: false),
                              ),
                            ).then((_) {
                              widget.onDataChanged?.call();
                              _loadAllTodoData();
                            });
                          },
                        ),

                        // Normal Mode Menu 4: Riwayat Task
                        _buildMenuItem(
                          context: context,
                          icon: Icons.history_rounded,
                          iconColor: const Color(0xFF1976D2),
                          title: 'Riwayat Task',
                          subtitle:
                              'Arsip daftar task reguler yang telah selesai',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const TodoRiwayatPage(isSeriousMode: false),
                              ),
                            ).then((_) {
                              widget.onDataChanged?.call();
                              _loadAllTodoData();
                            });
                          },
                        ),
                      ],
                    ],
                  ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _isSeriousMode
                  ? 'Daily Apps • Serious Game Mode v2.1'
                  : 'Daily Apps v2.1.0',
              style: TextStyle(
                fontSize: 11,
                color: _isSeriousMode
                    ? const Color(0xFF64748B)
                    : Colors.grey[400],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalDrawerHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryTerracotta, darkTerracotta],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.checklist_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Apps',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'To-Do List (Mode Biasa)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const List<Map<String, dynamic>> _presetAvatars = [
    {'emoji': '🦁', 'name': 'Singa Juara', 'color': 0xFFF59E0B},
    {'emoji': '⚡', 'name': 'Flash Fokus', 'color': 0xFF3B82F6},
    {'emoji': '👑', 'name': 'Sultan Task', 'color': 0xFFEAB308},
    {'emoji': '🥷', 'name': 'Ninja Disiplin', 'color': 0xFF6366F1},
    {'emoji': '🐉', 'name': 'Naga Produktif', 'color': 0xFF10B981},
    {'emoji': '🚀', 'name': 'Rocket Man', 'color': 0xFFEC4899},
    {'emoji': '🥊', 'name': 'Fighter', 'color': 0xFFEF4444},
    {'emoji': '🧠', 'name': 'Mastermind', 'color': 0xFF8B5CF6},
  ];

  Widget _buildSeriousDrawerHeader() {
    final playerName = _seriousUser?.displayName ?? 'Challenger';

    Widget avatarChild;
    if (_seriousUser?.avatarBase64 != null && _seriousUser!.avatarBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(_seriousUser!.avatarBase64!);
        avatarChild = ClipOval(
          child: Image.memory(
            bytes,
            width: 46,
            height: 46,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        final idx = (_seriousUser?.avatarIndex ?? 0).clamp(0, _presetAvatars.length - 1);
        avatarChild = Text(_presetAvatars[idx]['emoji'] as String, style: const TextStyle(fontSize: 24));
      }
    } else if (_seriousUser != null) {
      final idx = _seriousUser!.avatarIndex.clamp(0, _presetAvatars.length - 1);
      avatarChild = Text(_presetAvatars[idx]['emoji'] as String, style: const TextStyle(fontSize: 24));
    } else {
      avatarChild = const Icon(
        Icons.local_fire_department_rounded,
        color: Colors.white,
        size: 26,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [seriousGold, seriousFire],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: seriousFire.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: avatarChild,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mode Serius',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pemain: $playerName 🔥',
                      style: const TextStyle(
                        color: Color(0xFFFDE68A),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeriousPlayerCard() {
    final points = _seriousUser?.totalPoints ?? 0;
    final completed = _seriousUser?.totalTasksCompleted ?? 0;
    final punishments = _seriousUser?.totalPunishmentsTaken ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: seriousCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: seriousGold.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: seriousGold.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.military_tech_rounded,
                  color: seriousGold, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Status Pemain Serius',
                  style: TextStyle(
                    color: seriousGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: seriousGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$points Pts',
                  style: const TextStyle(
                    color: seriousGold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Mode Serius aktif dengan sistem poin, hukuman roulette & aturan anti-hapus.',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
          const Divider(height: 18, color: Color(0xFF334155)),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  'Total Poin',
                  '$points Pts',
                  seriousGold,
                  isDark: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniStat(
                  'Task Selesai',
                  '$completed Task',
                  const Color(0xFF4ADE80),
                  isDark: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniStat(
                  'Hukuman',
                  '${punishments}x Diambil',
                  const Color(0xFFF87171),
                  isDark: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNormalQuickStatusCard() {
    final todayCount = _todayCompletedCount;
    final level = ProductivityHelper.getLevel(todayCount);
    final isCrown = level == ProductivityLevel.king;
    final isOverload = level == ProductivityLevel.overload;
    final statusTitle = ProductivityHelper.getLevelLabel(level);
    final statusDesc = todayCount == 0
        ? 'Belum ada to-do yang selesai hari ini. Yuk mulai selesaikan tugasmu!'
        : ProductivityHelper.getPraiseQuote(level);

    final statusColor = isOverload
        ? const Color(0xFFEF4444)
        : (isCrown
            ? const Color(0xFFD97706)
            : (todayCount > 0
                ? const Color(0xFF16A34A)
                : const Color(0xFF64748B)));

    if (isOverload) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF09090B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFEF4444),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: 0.2),
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
                const Text('💀', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusTitle,
                    style: const TextStyle(
                      color: Color(0xFFFCA5A5),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              statusDesc,
              style: const TextStyle(
                color: Color(0xFFFECACA),
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const Divider(height: 18, color: Color(0xFF27272A)),
            Row(
              children: [
                Expanded(
                  child: _buildMiniStat(
                    'Hari Ini',
                    '$todayCount Selesai',
                    const Color(0xFFEF4444),
                    isDark: true,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMiniStat(
                    'Bulan Ini',
                    '$_thisMonthCompletedCount Selesai',
                    const Color(0xFFF87171),
                    isDark: true,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMiniStat(
                    'Total Selesai',
                    '$_totalAllCompletedCount',
                    const Color(0xFFE2E8F0),
                    isDark: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
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
              Icon(
                isCrown
                    ? Icons.emoji_events_rounded
                    : (todayCount > 0
                        ? Icons.local_fire_department_rounded
                        : Icons.spa_rounded),
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusTitle,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            statusDesc,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  'Hari Ini',
                  '$todayCount Selesai',
                  statusColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniStat(
                  'Bulan Ini',
                  '$_thisMonthCompletedCount Selesai',
                  primaryTerracotta,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniStat(
                  'Total Selesai',
                  '$_totalAllCompletedCount',
                  const Color(0xFF1976D2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color,
      {bool isDark = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? const Color(0xFF94A3B8) : Colors.grey[500],
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badgeText,
    Color? badgeColor,
    Color? badgeTextColor,
  }) {
    final isDark = _isSeriousMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155).withValues(alpha: 0.6)
              : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Material(
        color: isDark ? seriousCardBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor ??
                        (isDark
                            ? const Color(0xFF1E3A8A)
                            : const Color(0xFFDCFCE7)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeTextColor ??
                          (isDark
                              ? const Color(0xFF93C5FD)
                              : const Color(0xFF166534)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : Colors.grey[500],
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: isDark ? const Color(0xFF64748B) : Colors.grey,
          ),
        ),
      ),
    );
  }
}
