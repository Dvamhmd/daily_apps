import 'dart:convert';
import 'package:daily_apps/models/model_serious_mode.dart';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/pages/todo_riwayat_page.dart';
import 'package:daily_apps/utils/responsive_text.dart';
import 'package:daily_apps/utils/serious_mode_service.dart';
import 'package:daily_apps/utils/todo_alarm_service.dart';
import 'package:daily_apps/widgets/custom_toast.dart';
import 'package:daily_apps/widgets/gta_switch_wheel.dart';
import 'package:daily_apps/widgets/serious_confirm_add_dialog.dart';
import 'package:daily_apps/widgets/serious_leaderboard_widget.dart';
import 'package:daily_apps/widgets/serious_mode_auth_dialog.dart';
import 'package:daily_apps/widgets/serious_punishment_dialog.dart';
import 'package:daily_apps/widgets/todo_alarm_popup_dialog.dart';
import 'package:daily_apps/widgets/todo_alarm_setup_sheet.dart';
import 'package:daily_apps/widgets/todo_productivity_drawer.dart';
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

  static const Color seriousBg = Color(0xFF0F172A);
  static const Color seriousCardBg = Color(0xFF1E293B);
  static const Color seriousGold = Color(0xFFF59E0B);
  static const Color seriousFire = Color(0xFFEF4444);
  static const Color seriousBorder = Color(0xFF334155);

  static const String _prefsKeyNormal = SeriousModeService.prefKeyNormalTodoGroups;
  static const String _prefsKeySerious = SeriousModeService.prefKeySeriousTodoGroups;

  String get _prefsKey {
    if (_isSeriousMode && _seriousUser != null) {
      return SeriousModeService.getSeriousTodoGroupsKey(
        SeriousModeService.getUserStorageIdentifier(_seriousUser),
      );
    } else if (_isSeriousMode) {
      return _prefsKeySerious;
    }
    return _prefsKeyNormal;
  }

  List<TodoDateGroup> _dateGroups = [];
  final Set<String> _collapsedGroupIds = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'pending', 'completed'

  bool _isSeriousMode = false;
  SeriousUser? _seriousUser;
  bool _isManualSyncing = false;

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
    TodoAlarmService.activeAlarmNotifier.addListener(_onActiveAlarmChanged);
    TodoAlarmService.requestPermissions();
  }

  void _onActiveAlarmChanged() {
    final payload = TodoAlarmService.activeAlarmNotifier.value;
    if (payload == null || !mounted) return;

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
        isSeriousMode: _isSeriousMode,
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
      _isSeriousMode = await SeriousModeService.isSeriousModeActive();
      _seriousUser = await SeriousModeService.getCurrentUser();

      // Pemulihan data lokal multi-akun: pastikan data user ditemukan dari berbagai key yang pernah dipakai
      if (_isSeriousMode && _seriousUser != null) {
        final userKey = SeriousModeService.getSeriousTodoGroupsKey(
          SeriousModeService.getUserStorageIdentifier(_seriousUser),
        );
        if (!prefs.containsKey(userKey)) {
          final existingData = await SeriousModeService.findExistingUserTodoData(prefs, _seriousUser!);
          if (existingData != null && existingData.isNotEmpty) {
            await prefs.setString(userKey, existingData);
          }
        }
      }

      final String currentKey = _prefsKey;
      final String? jsonStr = prefs.getString(currentKey);
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

      // Jika _dateGroups kosong pada Mode Serius (misal HP baru yang baru login),
      // coba ambil daftar tugas dari cloud spreadsheet
      if (_isSeriousMode && _seriousUser != null && _dateGroups.isEmpty) {
        final remoteGroups = await SeriousModeService.fetchUserTasksFromSpreadsheet(_seriousUser!.username);
        if (remoteGroups.isNotEmpty) {
          _dateGroups = remoteGroups;
          final String encoded = jsonEncode(_dateGroups.map((g) => g.toJson()).toList());
          await prefs.setString(currentKey, encoded);
        }
      }

      if (_isSeriousMode && _seriousUser != null) {
        await SeriousModeService.recalculateAndSyncUserProgress(_dateGroups, targetUser: _seriousUser);
        _seriousUser = await SeriousModeService.getCurrentUser();
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

      if (_isSeriousMode) {
        await SeriousModeService.recalculateAndSyncUserProgress(_dateGroups, targetUser: _seriousUser);
        _seriousUser = await SeriousModeService.getCurrentUser();
        // Sinkronisasi daftar task ke cloud spreadsheet di background secara non-blocking
        SeriousModeService.scheduleTasksCloudSync(_seriousUser, _dateGroups);
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error saving todos: $e');
    }
  }

  Future<void> _handleManualSyncSpreadsheet() async {
    if (_isManualSyncing) return;
    setState(() {
      _isManualSyncing = true;
    });
    HapticFeedback.mediumImpact();

    final res = await SeriousModeService.syncAllDataToSpreadsheet(
      groups: _dateGroups,
      targetUser: _seriousUser,
    );

    if (mounted) {
      setState(() {
        _isManualSyncing = false;
        if (res['user'] is SeriousUser) {
          _seriousUser = res['user'] as SeriousUser;
        }
      });

      if (res['success'] == true) {
        CustomToast.showSuccess(
          context,
          title: 'Sinkronisasi Berhasil! ☁️',
          subtitle: 'Total ${_seriousUser?.totalPoints ?? 0} Poin & ${_seriousUser?.totalTasksCompleted ?? 0} Tugas Selesai berhasil disimpan ke Spreadsheet!',
        );
      } else {
        CustomToast.showError(
          context,
          title: 'Gagal Sinkronisasi',
          subtitle: res['message']?.toString() ?? 'Periksa koneksi internet Anda',
        );
      }
    }
  }

  Future<void> _handleOpenSeriousMode() async {
    final curUser = await SeriousModeService.getCurrentUser();
    if (!mounted) return;
    if (curUser == null) {
      final user = await SeriousModeAuthDialog.show(context);
      if (user != null && mounted) {
        setState(() {
          _isSeriousMode = true;
          _seriousUser = user;
          _dateGroups = [];
          _isLoading = true;
        });
        await _loadTodoData();
      }
    } else {
      await SeriousModeService.setSeriousModeActive(true);
      if (mounted) {
        setState(() {
          _isSeriousMode = true;
          _seriousUser = curUser;
          _dateGroups = [];
          _isLoading = true;
        });
        CustomToast.showSuccess(
          context,
          title: 'Mode Serius Aktif 🔥',
          subtitle: 'Anti-Hapus, sistem poin & hukuman aktif',
        );
        await _loadTodoData();
      }
    }
  }

  Future<void> _handleEditSeriousProfile() async {
    HapticFeedback.mediumImpact();
    final updated = await SeriousModeAuthDialog.showEditProfile(context);
    if (updated != null && mounted) {
      setState(() {
        _seriousUser = updated;
      });
      await _loadTodoData();
    }
  }

  Widget _buildSeriousUserAvatarWidget({double size = 52}) {
    final user = _seriousUser;
    Widget avatarContent;

    if (user?.avatarBase64 != null && user!.avatarBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(user.avatarBase64!);
        avatarContent = ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Text('👑', style: TextStyle(fontSize: size * 0.5)),
          ),
        );
      } catch (_) {
        final idx = (user?.avatarIndex ?? 0)
            .clamp(0, SeriousModeAuthDialog.presetAvatars.length - 1);
        avatarContent = Text(
          SeriousModeAuthDialog.presetAvatars[idx]['emoji'] as String,
          style: TextStyle(fontSize: size * 0.5),
        );
      }
    } else if (user != null) {
      final idx = user.avatarIndex
          .clamp(0, SeriousModeAuthDialog.presetAvatars.length - 1);
      final avatarData = SeriousModeAuthDialog.presetAvatars[idx];
      avatarContent = Text(
        avatarData['emoji'] as String,
        style: TextStyle(fontSize: size * 0.5),
      );
    } else {
      avatarContent = Text(
        '👑',
        style: TextStyle(fontSize: size * 0.5),
      );
    }

    final avatarColor = (user != null &&
            user.avatarIndex >= 0 &&
            user.avatarIndex < SeriousModeAuthDialog.presetAvatars.length)
        ? Color(
            SeriousModeAuthDialog.presetAvatars[user.avatarIndex]['color'] as int)
        : seriousGold;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: avatarColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: avatarColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: avatarColor.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: avatarContent,
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: seriousCardBg,
              shape: BoxShape.circle,
              border: Border.all(color: seriousGold, width: 1.2),
            ),
            child: const Icon(
              Icons.edit_rounded,
              color: seriousGold,
              size: 10.5,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleExitSeriousMode() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: seriousCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Text('🎮', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              'Keluar Mode Serius?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: const Text(
          'Anda akan kembali ke tampilan To-Do List mode reguler. Akun, poin dan peringkat Anda tetap tersimpan.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tetap di Mode Serius',
                style: TextStyle(color: seriousGold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar ke Mode Normal',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SeriousModeService.setSeriousModeActive(false);
      if (mounted) {
        setState(() {
          _isSeriousMode = false;
          _seriousUser = null;
          _dateGroups = [];
          _isLoading = true;
        });
        CustomToast.showInfo(
          context,
          title: 'Mode Normal',
          subtitle: 'Beralih ke To-Do List Mode Normal',
        );
        _loadTodoData();
      }
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
    if (isSuccess) {
      CustomToast.showSuccess(
        context,
        title: message,
      );
    } else {
      CustomToast.showInfo(
        context,
        title: message,
      );
    }
  }

  Future<void> _showConfigureAlarmDialog(TodoDateGroup group) async {
    await TodoAlarmService.requestOverlayPermissionWithDialog(context);
    final initialConfig = TodoAlarmConfig.fromGroup(group);
    if (!mounted) return;
    final res = await TodoAlarmSetupSheet.show(
      context,
      initialConfig: initialConfig,
      dateTitle: group.formattedFullDate,
      isSeriousMode: _isSeriousMode,
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
            final isDark = _isSeriousMode;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? seriousCardBg : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  border: isDark
                      ? Border.all(
                          color: seriousGold.withValues(alpha: 0.35),
                          width: 1.5,
                        )
                      : null,
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
                          color: isDark
                              ? const Color(0xFF475569)
                              : Colors.grey[300],
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
                            color: (isDark ? seriousGold : primaryTerracotta)
                                .withValues(alpha: isDark ? 0.15 : 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.playlist_add_rounded,
                            color: isDark ? seriousGold : primaryTerracotta,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Buat To-Do List Baru',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pilih tanggal untuk membuat list section baru',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
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
                                colorScheme: isDark
                                    ? const ColorScheme.dark(
                                        primary: seriousGold,
                                        onPrimary: Colors.black,
                                        surface: Color(0xFF1E293B),
                                        onSurface: Colors.white,
                                      )
                                    : const ColorScheme.light(
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
                          color: isDark ? seriousBg : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (isDark ? seriousGold : primaryTerracotta)
                                .withValues(alpha: isDark ? 0.45 : 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_available_rounded,
                              color: isDark ? seriousGold : primaryTerracotta,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tanggal To-Do List',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    TodoDateGroup(
                                      id: '',
                                      date: selectedDate,
                                    ).formattedFullDate,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1E293B),
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
                                  color: (isDark
                                          ? seriousGold
                                          : primaryTerracotta)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Hari Ini',
                                  style: TextStyle(
                                    color: isDark
                                        ? seriousGold
                                        : primaryTerracotta,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.edit_calendar_rounded,
                              color: isDark ? seriousGold : primaryTerracotta,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tugas Pertama (Opsional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: taskController,
                      autofocus: false,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Rapat koordinasi proyek...',
                        hintStyle: TextStyle(
                          color: isDark
                              ? const Color(0xFF64748B)
                              : Colors.grey[400],
                          fontSize: 13.5,
                        ),
                        filled: true,
                        fillColor:
                            isDark ? seriousBg : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark
                                ? seriousBorder
                                : Colors.grey[300]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark
                                ? seriousBorder
                                : Colors.grey.withValues(alpha: 0.25),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? seriousGold : primaryTerracotta,
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
                            ? (isDark
                                ? seriousGold.withValues(alpha: 0.12)
                                : primaryTerracotta.withValues(alpha: 0.06))
                            : (isDark ? seriousBg : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: alarmConfig.enabled
                              ? (isDark
                                  ? seriousGold.withValues(alpha: 0.5)
                                  : primaryTerracotta.withValues(alpha: 0.4))
                              : (isDark
                                  ? seriousBorder
                                  : Colors.grey.withValues(alpha: 0.25)),
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
                                      ? (isDark
                                          ? seriousGold
                                          : primaryTerracotta)
                                      : (isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.alarm_rounded,
                                  color: alarmConfig.enabled
                                      ? (isDark ? Colors.black : Colors.white)
                                      : const Color(0xFF64748B),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pengingat / Alarm Section',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    Text(
                                      alarmConfig.enabled
                                          ? 'Alarm aktif berbunyi looping jika tugas belum selesai'
                                          : 'Nyalakan alarm pengingat tugas',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: alarmConfig.enabled
                                            ? (isDark
                                                ? seriousGold
                                                : darkTerracotta)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: alarmConfig.enabled,
                                activeThumbColor:
                                    isDark ? seriousGold : primaryTerracotta,
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
                                      isSeriousMode: _isSeriousMode,
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
                            Divider(
                              height: 1,
                              color: isDark
                                  ? seriousBorder
                                  : const Color(0xFFE2E8F0),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    alarmConfig.type == 'interval'
                                        ? '🔔 Tiap ${alarmConfig.intervalMinutes < 60 ? "${alarmConfig.intervalMinutes} Menit" : "${alarmConfig.intervalMinutes ~/ 60} Jam"} (${alarmConfig.intervalStartTime} - ${alarmConfig.intervalEndTime}) • ${_getSoundLabel(alarmConfig)}'
                                        : '🔔 Jam: ${alarmConfig.specificTimes.join(', ')} • ${_getSoundLabel(alarmConfig)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark
                                          ? seriousGold
                                          : darkTerracotta,
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
                                      isSeriousMode: _isSeriousMode,
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
                                  icon: Icon(
                                    Icons.edit_rounded,
                                    size: 14,
                                    color: isDark
                                        ? seriousGold
                                        : primaryTerracotta,
                                  ),
                                  label: Text(
                                    'Ubah',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? seriousGold
                                          : primaryTerracotta,
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
                              side: BorderSide(
                                color: isDark
                                    ? seriousBorder
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Text(
                              'Batal',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final cleanDate = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                              );
                              final taskTitle = taskController.text.trim();

                              if (taskTitle.isNotEmpty && _isSeriousMode) {
                                final confirmed =
                                    await SeriousConfirmAddDialog.show(
                                  context,
                                  taskTitle: taskTitle,
                                );
                                if (!confirmed) return;
                              }

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
                              backgroundColor: isDark
                                  ? seriousGold
                                  : primaryTerracotta,
                              foregroundColor:
                                  isDark ? Colors.black : Colors.white,
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
    final isDark = _isSeriousMode;

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
            decoration: BoxDecoration(
              color: isDark ? seriousCardBg : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: isDark
                  ? Border.all(
                      color: seriousGold.withValues(alpha: 0.35),
                      width: 1.5,
                    )
                  : null,
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
                      color: isDark
                          ? const Color(0xFF475569)
                          : Colors.grey[300],
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
                        color: (isDark ? seriousGold : primaryTerracotta)
                            .withValues(alpha: isDark ? 0.15 : 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.add_task_rounded,
                        color: isDark ? seriousGold : primaryTerracotta,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tambah Kerjaan Baru',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            group.formattedFullDate,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? seriousGold
                                  : primaryTerracotta,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Tugas / Pekerjaan yang Harus Dikerjakan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: taskController,
                  autofocus: true,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Ketik apa tugas kamu...',
                    hintStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF64748B)
                          : Colors.grey[400],
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: isDark ? seriousBg : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark
                            ? seriousBorder
                            : Colors.grey[300]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark
                            ? seriousBorder
                            : Colors.grey.withValues(alpha: 0.25),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? seriousGold : primaryTerracotta,
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
                          side: BorderSide(
                            color: isDark
                                ? seriousBorder
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final text = taskController.text.trim();
                          if (text.isEmpty) {
                            CustomToast.showWarning(
                              context,
                              title: 'Nama Tugas Kosong',
                              subtitle: 'Tolong isi nama tugas terlebih dahulu.',
                            );
                            return;
                          }

                          if (_isSeriousMode) {
                            final confirmed =
                                await SeriousConfirmAddDialog.show(
                              context,
                              taskTitle: text,
                            );
                            if (!confirmed) return;
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
                          backgroundColor:
                              isDark ? seriousGold : primaryTerracotta,
                          foregroundColor:
                              isDark ? Colors.black : Colors.white,
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
    final isDark = _isSeriousMode;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? seriousCardBg : Colors.white,
          scrollable: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: isDark
                ? BorderSide(
                    color: seriousGold.withValues(alpha: 0.35),
                    width: 1.5,
                  )
                : BorderSide.none,
          ),
          title: Text(
            'Edit Tugas',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
            ),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Nama tugas...',
              hintStyle: TextStyle(
                color: isDark ? const Color(0xFF64748B) : Colors.grey[400],
              ),
              filled: true,
              fillColor: isDark ? seriousBg : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? seriousBorder : Colors.grey[300]!,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? seriousBorder
                      : Colors.grey.withValues(alpha: 0.25),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? seriousGold : primaryTerracotta,
                  width: 1.8,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey,
                ),
              ),
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
                backgroundColor:
                    isDark ? seriousGold : primaryTerracotta,
                foregroundColor: isDark ? Colors.black : Colors.white,
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
    // Mode Serius: Cek jika task berada pada tanggal lampau dan belum dikerjakan
    if (_isSeriousMode && !item.isCompleted) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final groupDate =
          DateTime(group.date.year, group.date.month, group.date.day);
      if (groupDate.isBefore(today)) {
        HapticFeedback.heavyImpact();
        CustomToast.showWarning(
          context,
          title: 'Tugas Terlewat Terkunci 🔒',
          subtitle:
              'Tugas pada tanggal lampau tidak bisa dicentang untuk menambah poin langsung. Selesaikan hukuman olahraga untuk mempertahankan poin!',
        );
        return;
      }
    }

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
    if (_isSeriousMode) {
      CustomToast.showError(
        context,
        title: 'Tugas Terkunci',
        subtitle: 'Di Mode Serius, tugas yang sudah disepakati TIDAK BISA DIHAPUS! 🚫',
      );
      return;
    }
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
    if (_isSeriousMode) {
      CustomToast.showError(
        context,
        title: 'Section Terkunci',
        subtitle: 'Di Mode Serius, section to-do list TIDAK BISA DIHAPUS! 🚫',
      );
      return;
    }
    final isDark = _isSeriousMode;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? seriousCardBg : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: isDark
                ? const BorderSide(color: seriousBorder, width: 1)
                : BorderSide.none,
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: isDark ? seriousFire : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'Hapus Section?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          content: Text(
            'Apakah kamu yakin ingin menghapus section "${group.formattedFullDate}" beserta seluruh ${group.totalCount} tugas di dalamnya?',
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? seriousFire : Colors.red[700],
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
      backgroundColor:
          _isSeriousMode ? seriousBg : const Color(0xFFFBF8F6),
      drawer: TodoProductivityDrawer(
        activeGroups: _dateGroups,
        isSeriousMode: _isSeriousMode,
        onOpenSeriousMode: _handleOpenSeriousMode,
        onExitSeriousMode: _handleExitSeriousMode,
        onDataChanged: () async {
          await _loadTodoData();
        },
      ),
      appBar: AppBar(
        backgroundColor:
            _isSeriousMode ? seriousBg : primaryTerracotta,
        centerTitle: false,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isSeriousMode
                  ? Icons.local_fire_department_rounded
                  : Icons.checklist_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _isSeriousMode ? 'To-Do List (Mode Serius)' : 'To-Do List',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_isSeriousMode) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: seriousGold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'GAMES',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_isSeriousMode)
            IconButton(
              icon: const Icon(Icons.emoji_events_rounded,
                  color: seriousGold),
              tooltip: 'Leaderboard Top 3',
              onPressed: () => SeriousLeaderboardModal.show(context),
            ),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: 'Riwayat Task',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) =>
                      TodoRiwayatPage(isSeriousMode: _isSeriousMode),
                ),
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
          ? Center(
              child: CircularProgressIndicator(
                  color: _isSeriousMode ? seriousGold : primaryTerracotta),
            )
          : RefreshIndicator(
              onRefresh: _loadTodoData,
              color: _isSeriousMode ? seriousGold : primaryTerracotta,
              child: ResponsiveContentWrapper(
                maxWidth: 720,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderBanner(),
                            const SizedBox(height: 14),
                            _buildSearchAndFilterBar(),
                            const SizedBox(height: 14),

                            // Section Title
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Text(
                                  _isSeriousMode
                                      ? 'Misi & Target Harian'
                                      : 'Daftar Rencana & Tugas',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                    color: _isSeriousMode
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (_isSeriousMode
                                            ? seriousGold
                                            : primaryTerracotta)
                                        .withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_activeDateGroups.length} Hari',
                                    style: TextStyle(
                                      color: _isSeriousMode
                                          ? seriousGold
                                          : primaryTerracotta,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (filtered.length > 1)
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
                            ),

                            const SizedBox(height: 8),
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
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
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
              color: _isSeriousMode ? seriousCardBg : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: (_isSeriousMode ? seriousGold : primaryTerracotta)
                    .withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isSeriousMode ? seriousGold : primaryTerracotta)
                      .withValues(alpha: 0.06),
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
                    color: (_isSeriousMode ? seriousGold : primaryTerracotta)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: _isSeriousMode ? seriousGold : primaryTerracotta,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _isSeriousMode
                      ? 'Buat Section Tanggal Baru (Mode Serius)'
                      : 'Buat Section / Tanggal Baru',
                  style: TextStyle(
                    color: _isSeriousMode ? seriousGold : primaryTerracotta,
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
    if (_isSeriousMode) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: seriousGold.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: seriousGold.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: seriousGold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🔥', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 4),
                      Text(
                        'MODE SERIUS AKTIF',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: _handleExitSeriousMode,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.exit_to_app_rounded,
                            color: Colors.white70, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Keluar Mode',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _handleEditSeriousProfile,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    _buildSeriousUserAvatarWidget(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _seriousUser?.displayName ?? 'Pemain Serius',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.18)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_rounded,
                                        size: 10, color: seriousGold),
                                    SizedBox(width: 3),
                                    Text(
                                      'Edit',
                                      style: TextStyle(
                                        color: seriousGold,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${_seriousUser?.username ?? "user"} • Ketuk untuk edit profil',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_seriousUser?.totalPoints ?? 0}',
                          style: const TextStyle(
                            color: seriousGold,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'TOTAL POIN',
                          style: TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: seriousGold,
                      foregroundColor: Colors.black,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.emoji_events_rounded, size: 18),
                    label: const Text(
                      'Leaderboard 🏆',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 12.5),
                    ),
                    onPressed: () {
                      SeriousLeaderboardModal.show(context);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: seriousGold,
                      side: const BorderSide(color: seriousGold, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isManualSyncing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: seriousGold,
                            ),
                          )
                        : const Icon(Icons.cloud_sync_rounded, size: 18),
                    label: Text(
                      _isManualSyncing ? 'Sync...' : 'Sync Sheet',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: _isManualSyncing ? null : _handleManualSyncSpreadsheet,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

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
              InkWell(
                onTap: _handleOpenSeriousMode,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🔥', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 4),
                      Text(
                        'Mode Serius',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
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
          const Text(
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
          style: TextStyle(
            color: _isSeriousMode ? Colors.white : const Color(0xFF1E293B),
            fontSize: 13.5,
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
          decoration: InputDecoration(
            hintText: 'Cari tugas atau tanggal...',
            hintStyle: TextStyle(
              color: _isSeriousMode
                  ? const Color(0xFF64748B)
                  : Colors.grey[400],
              fontSize: 13.5,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: _isSeriousMode ? seriousGold : primaryTerracotta,
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      size: 18,
                      color: _isSeriousMode ? Colors.white70 : Colors.grey[600],
                    ),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: _isSeriousMode ? seriousCardBg : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _isSeriousMode
                    ? const Color(0xFF334155)
                    : primaryTerracotta.withValues(alpha: 0.15),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _isSeriousMode
                    ? const Color(0xFF334155)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _isSeriousMode ? seriousGold : primaryTerracotta,
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
          color: isSelected
              ? (_isSeriousMode ? seriousGold : primaryTerracotta)
              : (_isSeriousMode ? seriousCardBg : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (_isSeriousMode ? seriousGold : primaryTerracotta)
                : (_isSeriousMode
                    ? const Color(0xFF334155)
                    : Colors.grey.withValues(alpha: 0.2)),
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: (_isSeriousMode ? seriousGold : primaryTerracotta)
                    .withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (_isSeriousMode ? Colors.black : Colors.white)
                : (_isSeriousMode
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF475569)),
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
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _isSeriousMode ? seriousCardBg : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isSeriousMode
                ? (group.isToday
                    ? seriousGold.withValues(alpha: 0.5)
                    : const Color(0xFF334155))
                : (group.isToday
                    ? primaryTerracotta.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.06)),
            width: group.isToday ? 1.6 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isSeriousMode
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.04),
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
                  color: _isSeriousMode
                      ? (group.isToday
                          ? seriousGold.withValues(alpha: 0.12)
                          : const Color(0xFF162032))
                      : (group.isToday
                          ? primaryTerracotta.withValues(alpha: 0.07)
                          : const Color(0xFFF8FAFC)),
                  border: Border(
                    bottom: BorderSide(
                      color: isCollapsed
                          ? Colors.transparent
                          : (_isSeriousMode
                              ? const Color(0xFF334155)
                              : Colors.grey.withValues(alpha: 0.12)),
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
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: _isSeriousMode
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
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
                                  color: _isSeriousMode
                                      ? (group.isToday
                                          ? seriousGold
                                          : const Color(0xFF334155))
                                      : (group.isToday
                                          ? primaryTerracotta
                                          : const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Icon(
                                  Icons.event_note_rounded,
                                  color: _isSeriousMode
                                      ? (group.isToday
                                          ? Colors.black
                                          : Colors.white70)
                                      : (group.isToday
                                          ? Colors.white
                                          : const Color(0xFF475569)),
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
                                              color: _isSeriousMode
                                                  ? (group.isToday
                                                      ? seriousGold
                                                      : Colors.white)
                                                  : (group.isToday
                                                      ? primaryTerracotta
                                                      : const Color(0xFF1E293B)),
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
                                              color: _isSeriousMode
                                                  ? (group.isToday
                                                      ? seriousGold
                                                          .withValues(alpha: 0.2)
                                                      : const Color(0xFF334155))
                                                  : (group.isToday
                                                      ? primaryTerracotta
                                                          .withValues(alpha: 0.15)
                                                      : Colors.grey
                                                          .withValues(alpha: 0.15)),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              group.relativeDateLabel,
                                              style: TextStyle(
                                                color: _isSeriousMode
                                                    ? (group.isToday
                                                        ? seriousGold
                                                        : Colors.white70)
                                                    : (group.isToday
                                                        ? primaryTerracotta
                                                        : const Color(0xFF475569)),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 2,
                                      children: [
                                        Text(
                                          '${group.completedCount}/${group.totalCount} Tugas selesai',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: group.isAllCompleted
                                                ? accentCompleted
                                                : (_isSeriousMode
                                                    ? const Color(0xFF94A3B8)
                                                    : const Color(0xFF64748B)),
                                            fontWeight: group.isAllCompleted
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _isSeriousMode
                                                ? seriousGold.withValues(alpha: 0.18)
                                                : primaryTerracotta.withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '+${SeriousModeService.calculatePoints(group.completedCount)} PTS',
                                            style: TextStyle(
                                              color: _isSeriousMode
                                                  ? seriousGold
                                                  : primaryTerracotta,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                            ),
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
                                            color: (_isSeriousMode
                                                    ? seriousGold
                                                    : primaryTerracotta)
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: (_isSeriousMode
                                                      ? seriousGold
                                                      : primaryTerracotta)
                                                  .withValues(alpha: 0.3),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.alarm_on_rounded,
                                                size: 12,
                                                color: _isSeriousMode
                                                    ? seriousGold
                                                    : primaryTerracotta,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  group.reminderSummaryLabel,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: _isSeriousMode
                                                        ? seriousGold
                                                        : primaryTerracotta,
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
                          color: _isSeriousMode
                              ? (group.isToday ? seriousGold : Colors.white70)
                              : (group.isToday
                                  ? primaryTerracotta
                                  : const Color(0xFF64748B)),
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
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerTheme: DividerThemeData(
                          color: _isSeriousMode
                              ? seriousBorder
                              : const Color(0xFFE2E8F0),
                          thickness: 1,
                          space: 1,
                        ),
                      ),
                      child: PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: _isSeriousMode
                              ? Colors.white70
                              : const Color(0xFF64748B),
                          size: 20,
                        ),
                        color: _isSeriousMode ? seriousCardBg : Colors.white,
                        surfaceTintColor: Colors.transparent,
                        elevation: _isSeriousMode ? 8 : 4,
                        shadowColor: _isSeriousMode
                            ? Colors.black.withValues(alpha: 0.6)
                            : Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: _isSeriousMode
                                ? seriousBorder
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
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
                          PopupMenuItem(
                            value: 'add',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  size: 18,
                                  color: _isSeriousMode
                                      ? seriousGold
                                      : primaryTerracotta,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Tambah Tugas',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _isSeriousMode
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
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
                                  color: _isSeriousMode
                                      ? seriousGold
                                      : primaryTerracotta,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  group.reminderEnabled
                                      ? 'Atur Pengingat Alarm'
                                      : 'Nyalakan Pengingat Alarm',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _isSeriousMode
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                  ),
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
                                      ? (_isSeriousMode
                                          ? const Color(0xFF10B981)
                                          : accentCompleted)
                                      : (_isSeriousMode
                                          ? Colors.white38
                                          : const Color(0xFF94A3B8)),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  (group.isAllCompleted &&
                                          group.items.isNotEmpty)
                                      ? 'Arsipkan Section'
                                      : 'Arsipkan (Belum Selesai)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: (group.isAllCompleted &&
                                            group.items.isNotEmpty)
                                        ? (_isSeriousMode
                                            ? Colors.white
                                            : const Color(0xFF1E293B))
                                        : (_isSeriousMode
                                            ? Colors.white38
                                            : const Color(0xFF94A3B8)),
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
                                  color: _isSeriousMode
                                      ? seriousGold
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isCollapsed
                                      ? 'Buka Section'
                                      : 'Tutup Section',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _isSeriousMode
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'complete_all',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.done_all_rounded,
                                  size: 18,
                                  color: _isSeriousMode
                                      ? const Color(0xFF10B981)
                                      : accentCompleted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Tandai Semua Selesai',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _isSeriousMode
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'clear_completed',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.cleaning_services_rounded,
                                  size: 18,
                                  color: _isSeriousMode
                                      ? seriousGold
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Hapus Tugas Selesai',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _isSeriousMode
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'delete_section',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: _isSeriousMode
                                      ? seriousFire
                                      : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Hapus Section Ini',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _isSeriousMode
                                        ? seriousFire
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
                                      : (_isSeriousMode
                                          ? seriousGold
                                          : primaryTerracotta),
                                ),
                              ),
                            ),

                          // Kartu Evaluasi Mode Serius untuk Section yang Terlewat
                          () {
                            final eval = SeriousModeService.evaluateSection(group);
                            if (eval != null) {
                              return _buildSeriousEvaluationCard(eval);
                            }
                            return const SizedBox.shrink();
                          }(),

                          // Tombol Arsipkan Section Jika Sudah 100% Selesai
                          if (group.isAllCompleted && group.items.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: accentCompleted.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      accentCompleted.withValues(alpha: 0.3),
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
                                    color: _isSeriousMode
                                        ? const Color(0xFF64748B)
                                        : Colors.grey[500],
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
                                      color: _isSeriousMode
                                          ? const Color(0xFF334155)
                                          : Colors.grey.withValues(alpha: 0.12),
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
                                  color: _isSeriousMode
                                      ? const Color(0xFF0F172A).withValues(alpha: 0.4)
                                      : primaryTerracotta.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _isSeriousMode
                                        ? seriousGold.withValues(alpha: 0.3)
                                        : primaryTerracotta.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_circle_rounded,
                                      size: 16,
                                      color: _isSeriousMode
                                          ? seriousGold
                                          : primaryTerracotta,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Tambah Kerjaan',
                                      style: TextStyle(
                                        color: _isSeriousMode
                                            ? seriousGold
                                            : primaryTerracotta,
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

  // --- KARTU EVALUASI ROASTING & HUKUMAN MODE SERIUS ---
  Widget _buildSeriousEvaluationCard(SeriousSectionEvaluation eval) {
    final Color borderColor;
    final Color bgColor;
    final Color badgeColor;
    final String emoji;
    final String tagLabel;

    if (eval.isExempt) {
      borderColor = const Color(0xFF10B981);
      bgColor = const Color(0xFF064E3B).withValues(alpha: 0.2);
      badgeColor = const Color(0xFF10B981);
      emoji = '👑';
      tagLabel = 'OVER PRODUKTIF (>15 SELESAI)';
    } else if (eval.isPunishmentOptional) {
      borderColor = seriousGold;
      bgColor = const Color(0xFF78350F).withValues(alpha: 0.2);
      badgeColor = seriousGold;
      emoji = '⚡';
      tagLabel = 'SANGAT PRODUKTIF (11-15 SELESAI)';
    } else {
      borderColor = seriousFire;
      bgColor = const Color(0xFF7F1D1D).withValues(alpha: 0.2);
      badgeColor = seriousFire;
      emoji = '💀';
      tagLabel = 'TANGGAL LEWAT • HUKUMAN WAJIB';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tagLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: badgeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  eval.isExempt
                      ? 'Bebas Hukuman'
                      : (eval.isPunishmentOptional
                          ? 'Opsional'
                          : '${eval.pendingCount} Belum Selesai'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '"${eval.message}"',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: badgeColor,
                foregroundColor:
                    eval.isPunishmentOptional ? Colors.black : Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(
                eval.isExempt
                    ? Icons.bedtime_rounded
                    : Icons.sports_esports_rounded,
                size: 13,
              ),
              label: Text(
                eval.isExempt
                    ? 'Bebas Hukuman • Istirahat Dulu'
                    : (eval.isPunishmentOptional
                        ? 'Pilih Hukuman / Lewati'
                        : 'Ambil Hukuman! 💀'),
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                SeriousPunishmentDialog.show(
                  context,
                  evaluation: eval,
                  allGroups: _dateGroups,
                  onCompleted: () {
                    _loadTodoData();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- TASK ITEM TILE DENGAN CHECKBOX & NAMA TUGAS ---
  Widget _buildTaskItemTile(TodoDateGroup group, TodoItem item) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groupDate =
        DateTime(group.date.year, group.date.month, group.date.day);
    final isMissedLocked =
        _isSeriousMode && groupDate.isBefore(today) && !item.isCompleted;

    return Dismissible(
      key: Key(item.id),
      direction:
          _isSeriousMode ? DismissDirection.none : DismissDirection.endToStart,
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
                    color: item.isCompleted
                        ? (_isSeriousMode ? seriousGold : accentCompleted)
                        : (isMissedLocked
                            ? const Color(0xFF3B1212)
                            : (_isSeriousMode
                                ? const Color(0xFF0F172A)
                                : Colors.white)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: item.isCompleted
                          ? (_isSeriousMode ? seriousGold : accentCompleted)
                          : (isMissedLocked
                              ? const Color(0xFFEF4444)
                              : (_isSeriousMode
                                  ? const Color(0xFF475569)
                                  : const Color(0xFFCBD5E1))),
                      width: 1.8,
                    ),
                    boxShadow: item.isCompleted
                        ? [
                            BoxShadow(
                              color: (_isSeriousMode
                                      ? seriousGold
                                      : accentCompleted)
                                  .withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 1.5),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: item.isCompleted
                        ? Icon(
                            Icons.check_rounded,
                            color: _isSeriousMode ? Colors.black : Colors.white,
                            size: 13,
                          )
                        : (isMissedLocked
                            ? const Icon(
                                Icons.lock_rounded,
                                color: Color(0xFFEF4444),
                                size: 11,
                              )
                            : null),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: item.isCompleted
                              ? (_isSeriousMode
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8))
                              : (isMissedLocked
                                  ? const Color(0xFFFCA5A5)
                                  : (_isSeriousMode
                                      ? Colors.white
                                      : const Color(0xFF1E293B))),
                          fontWeight: item.isCompleted
                              ? FontWeight.w400
                              : (isMissedLocked
                                  ? FontWeight.w600
                                  : FontWeight.w500),
                          decoration: item.isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: _isSeriousMode
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    if (isMissedLocked) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFEF4444).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          'TERLEWAT',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFEF4444),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 15,
                  color: _isSeriousMode
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(),
                tooltip: 'Edit Tugas',
                onPressed: () => _showEditTaskDialog(item),
              ),
              if (_isSeriousMode)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Tooltip(
                    message: 'Tugas terkunci (Anti-Hapus Mode Serius)',
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: seriousGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: seriousGold,
                      ),
                    ),
                  ),
                )
              else

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
        color: _isSeriousMode ? seriousCardBg : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isSeriousMode
              ? const Color(0xFF334155)
              : primaryTerracotta.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: _isSeriousMode
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.03),
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
              color: _isSeriousMode
                  ? seriousGold.withValues(alpha: 0.15)
                  : primaryTerracotta.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              size: 36,
              color: _isSeriousMode ? seriousGold : primaryTerracotta,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Tidak Ada List Tugas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _isSeriousMode ? Colors.white : const Color(0xFF1E293B),
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
              color: _isSeriousMode
                  ? const Color(0xFF94A3B8)
                  : Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showCreateTodoListDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isSeriousMode ? seriousGold : primaryTerracotta,
              foregroundColor:
                  _isSeriousMode ? Colors.black : Colors.white,
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
