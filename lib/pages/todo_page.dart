import 'dart:convert';
import 'package:daily_apps/models/model_serious_mode.dart';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/pages/todo_riwayat_page.dart';
import 'package:daily_apps/utils/responsive_text.dart';
import 'package:daily_apps/utils/serious_mode_service.dart';
import 'package:daily_apps/utils/todo_alarm_service.dart';
import 'package:daily_apps/widgets/ash_disintegration_effect.dart';
import 'package:daily_apps/widgets/custom_toast.dart';
import 'package:daily_apps/widgets/gta_switch_wheel.dart';
import 'package:daily_apps/widgets/serious_confirm_add_dialog.dart';
import 'package:daily_apps/widgets/serious_leaderboard_widget.dart';
import 'package:daily_apps/widgets/serious_mode_auth_dialog.dart';
import 'package:daily_apps/widgets/serious_punishment_dialog.dart';
import 'package:daily_apps/widgets/todo_alarm_popup_dialog.dart';
import 'package:daily_apps/widgets/todo_alarm_setup_sheet.dart';
import 'package:daily_apps/widgets/todo_mode_transition_overlay.dart';
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

class _TodoUndoAction {
  final String title;
  final String subtitle;
  final VoidCallback onUndo;

  _TodoUndoAction({
    required this.title,
    required this.subtitle,
    required this.onUndo,
  });
}

class TodoDragPayload {
  final String sourceGroupId;
  final List<TodoItem> items;
  final int? sourceIndex;

  TodoDragPayload({
    required this.sourceGroupId,
    required this.items,
    this.sourceIndex,
  });
}

class _TodoPageState extends State<TodoPage> with TickerProviderStateMixin {
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
  TodoTransitionType _transitionType = TodoTransitionType.loading;
  SeriousUser? _transitionUser;
  String? _transitionSubtitle;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'pending', 'completed'

  bool _isSeriousMode = false;
  SeriousUser? _seriousUser;
  bool _isManualSyncing = false;
  Map<String, SeriousGroupPunishmentState> _punishmentStates = {};
  final Set<String> _disintegratingTaskIds = {};

  // State untuk Undo Mode Biasa (5 Detik Cooldown)
  AnimationController? _undoController;
  _TodoUndoAction? _activeUndo;

  // State untuk Seleksi Banyak (Multi-Select) & Drag-and-Drop Item (Mode Biasa)
  final Set<String> _selectedTaskIds = {};
  String? _multiSelectGroupId;
  bool _isDraggingTasks = false;
  String? _draggingTaskId;
  final ValueNotifier<Set<String>> _activeDraggingTaskIdsNotifier =
      ValueNotifier<Set<String>>({});

  @override
  void initState() {
    super.initState();
    _initAlarmSystem();
    _loadTodoData();
  }

  @override
  void dispose() {
    TodoAlarmService.activeAlarmNotifier.removeListener(_onActiveAlarmChanged);
    _undoController?.dispose();
    _activeDraggingTaskIdsNotifier.dispose();
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

    if (targetGroup.isPast) {
      TodoAlarmService.stopAlarmSound();
      return;
    }

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

  Future<void> _loadTodoData({
    TodoTransitionType? transitionType,
    SeriousUser? transitionUser,
    String? transitionSubtitle,
    bool showTransition = false,
  }) async {
    final startTime = DateTime.now();
    if (showTransition) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          if (transitionType != null) _transitionType = transitionType;
          _transitionUser = transitionUser ?? _seriousUser;
          _transitionSubtitle = transitionSubtitle;
        });
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSeriousMode = await SeriousModeService.isSeriousModeActive();
      _seriousUser = await SeriousModeService.getCurrentUser();

      if (_transitionType == TodoTransitionType.loading) {
        _transitionType = _isSeriousMode
            ? TodoTransitionType.toSerious
            : TodoTransitionType.toNormal;
      }

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

      _collapsedGroupIds.clear();
      for (final group in _dateGroups) {
        if (group.isCollapsed) {
          _collapsedGroupIds.add(group.id);
        }
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
        _punishmentStates = await SeriousModeService.getAllPunishmentStates(_seriousUser?.id);
      } else if (_isSeriousMode) {
        _punishmentStates = await SeriousModeService.getAllPunishmentStates();
      } else {
        _punishmentStates = {};
      }

      // Sinkronisasi jadwal alarm seluruh group
      TodoAlarmService.syncAllAlarms(_dateGroups);
    } catch (e) {
      debugPrint('Error loading todos: $e');
    } finally {
      if (showTransition) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        const minDisplayDuration = 600;
        if (elapsed < minDisplayDuration) {
          await Future.delayed(Duration(milliseconds: minDisplayDuration - elapsed));
        }
      }
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
        _punishmentStates = await SeriousModeService.getAllPunishmentStates(_seriousUser?.id);
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

  Future<void> _handleSurrenderAshEffect(String groupId) async {
    final groupIndex = _dateGroups.indexWhere((g) => g.id == groupId);
    if (groupIndex == -1) {
      await _loadTodoData();
      return;
    }

    final group = _dateGroups[groupIndex];
    final uncompleted = group.items.where((i) => !i.isCompleted).toList();
    if (uncompleted.isEmpty) {
      await _loadTodoData();
      return;
    }

    // 1. Trigger animasi partikel abu tersapu angin
    if (mounted) {
      setState(() {
        _disintegratingTaskIds.addAll(uncompleted.map((t) => t.id));
      });
    }

    HapticFeedback.heavyImpact();

    // 2. Tunggu durasi animasi (1350ms)
    await Future.delayed(const Duration(milliseconds: 1400));

    // 3. Hapus tugas yang tidak tercentang dari grup
    group.items.removeWhere((i) => !i.isCompleted);

    if (mounted) {
      setState(() {
        _disintegratingTaskIds.removeAll(uncompleted.map((t) => t.id));
      });
    }

    // 4. Simpan ke database lokal dan background sync
    await _saveTodoData();
    await _loadTodoData();

    if (mounted) {
      CustomToast.showInfo(
        context,
        title: 'Tugas Menjadi Abu 💨',
        subtitle: '${uncompleted.length} tugas yang tidak tercentang telah hangus dan dihapus.',
      );
    }
  }

  Future<void> _handleOpenSeriousMode() async {
    _dismissUndo();
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
          _transitionType = TodoTransitionType.toSerious;
          _transitionUser = user;
        });
        await _loadTodoData(
          transitionType: TodoTransitionType.toSerious,
          transitionUser: user,
          showTransition: true,
        );
      }
    } else {
      await SeriousModeService.setSeriousModeActive(true);
      if (mounted) {
        setState(() {
          _isSeriousMode = true;
          _seriousUser = curUser;
          _dateGroups = [];
          _isLoading = true;
          _transitionType = TodoTransitionType.toSerious;
          _transitionUser = curUser;
        });
        CustomToast.showSuccess(
          context,
          title: 'Mode Serius Aktif 🔥',
          subtitle: 'Anti-Hapus, sistem poin & hukuman aktif',
        );
        await _loadTodoData(
          transitionType: TodoTransitionType.toSerious,
          transitionUser: curUser,
          showTransition: true,
        );
      }
    }
  }

  Future<void> _handleEditSeriousProfile() async {
    HapticFeedback.mediumImpact();
    final updated = await SeriousModeAuthDialog.showEditProfile(context);
    if (updated != null && mounted) {
      setState(() {
        _seriousUser = updated;
        _isLoading = true;
        _transitionType = TodoTransitionType.switchAccount;
        _transitionUser = updated;
      });
      await _loadTodoData(
        transitionType: TodoTransitionType.switchAccount,
        transitionUser: updated,
        showTransition: true,
      );
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
        final idx = user.avatarIndex
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
      _dismissUndo();
      await SeriousModeService.setSeriousModeActive(false);
      if (mounted) {
        setState(() {
          _isSeriousMode = false;
          _seriousUser = null;
          _dateGroups = [];
          _isLoading = true;
          _transitionType = TodoTransitionType.toNormal;
          _transitionUser = null;
        });
        CustomToast.showInfo(
          context,
          title: 'Mode Normal',
          subtitle: 'Beralih ke To-Do List Mode Normal',
        );
        _loadTodoData(
          transitionType: TodoTransitionType.toNormal,
          showTransition: true,
        );
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

  bool _isGroupCollapsed(String id) {
    final group = _dateGroups.firstWhere(
      (g) => g.id == id,
      orElse: () => TodoDateGroup(id: '', date: DateTime.now()),
    );
    if (group.id.isNotEmpty) {
      return group.isCollapsed;
    }
    return _collapsedGroupIds.contains(id);
  }

  void _toggleGroupCollapse(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_collapsedGroupIds.contains(id)) {
        _collapsedGroupIds.remove(id);
      } else {
        _collapsedGroupIds.add(id);
      }
      for (final g in _dateGroups) {
        if (g.id == id) {
          g.isCollapsed = _collapsedGroupIds.contains(id);
          break;
        }
      }
    });
    _saveTodoData();
  }

  bool _canArchiveGroup(TodoDateGroup group) {
    if (group.items.isEmpty) return false;
    if (group.isAllCompleted) return true;
    if (_isSeriousMode) {
      final state = _punishmentStates[group.id];
      if (state != null && (state.isFullyCompleted || state.isSurrendered)) {
        return true;
      }
      final eval = SeriousModeService.evaluateSection(group, states: _punishmentStates);
      if (eval != null && eval.isExempt) {
        return true;
      }
    }
    return false;
  }

  void _archiveGroup(TodoDateGroup group) {
    if (!_canArchiveGroup(group)) {
      HapticFeedback.vibrate();
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      group.isArchived = true;
    });
    _saveTodoData();
    _showToast(context, 'Section berhasil diarsipkan');
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
          builder: (sheetCtx, setModalState) {
            final now = DateTime.now();
            final isDateToday = selectedDate.year == now.year &&
                selectedDate.month == now.month &&
                selectedDate.day == now.day;
            final isDark = _isSeriousMode;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
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
                                            sheetCtx);
                                    if (!sheetCtx.mounted) return;
                                    final res = await TodoAlarmSetupSheet.show(
                                      sheetCtx,
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
                                      if (sheetCtx.mounted) {
                                        _showToast(
                                            sheetCtx, 'Berhasil atur pengingat');
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
                                      sheetCtx,
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
                                      if (sheetCtx.mounted) {
                                        _showToast(sheetCtx, 'Berhasil atur pengingat');
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
                                if (!mounted) return;
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

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                              if (mounted) {
                                _showToast(context, 'To-Do List berhasil dibuat!');
                              }
                              _saveTodoData();
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
                            if (!mounted) return;
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

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          _saveTodoData();
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

  // --- UNDO HELPER METHODS (MODE BIASA) ---
  void _showTopUndoBanner({
    required String title,
    required String subtitle,
    required VoidCallback onUndo,
  }) {
    if (_isSeriousMode) return;

    _undoController?.stop();
    _undoController?.dispose();

    _undoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _undoController!.addListener(() {
      if (mounted) setState(() {});
    });

    _undoController!.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _dismissUndo();
      }
    });

    setState(() {
      _activeUndo = _TodoUndoAction(
        title: title,
        subtitle: subtitle,
        onUndo: onUndo,
      );
    });

    _undoController!.forward(from: 0.0);
  }

  void _dismissUndo() {
    _undoController?.stop();
    if (mounted) {
      setState(() {
        _activeUndo = null;
      });
    }
  }

  void _handleUndo() {
    final action = _activeUndo;
    _dismissUndo();
    if (action != null) {
      HapticFeedback.mediumImpact();
      action.onUndo();
    }
  }

  Widget _buildTopUndoBanner() {
    if (_activeUndo == null || _undoController == null) {
      return const SizedBox.shrink();
    }

    final remainingProgress =
        (1.0 - _undoController!.value).clamp(0.0, 1.0);
    final remainingSeconds =
        (remainingProgress * 5).ceil().clamp(1, 5);

    return Material(
      color: Colors.transparent,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.8),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _undoController!,
            curve: const Interval(0.0, 0.08, curve: Curves.easeOutCubic),
          ),
        ),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _undoController!,
              curve: const Interval(0.0, 0.06, curve: Curves.easeIn),
            ),
          ),
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta != null && details.primaryDelta! < -4) {
                _dismissUndo();
              }
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E293B),
                    Color(0xFF0F172A),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primaryTerracotta.withValues(alpha: 0.6),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: primaryTerracotta.withValues(alpha: 0.18),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                      child: Row(
                        children: [
                          // Icon badge with animated timer
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryTerracotta.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: primaryTerracotta.withValues(alpha: 0.45),
                              ),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFFF8A65),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Text info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _activeUndo!.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryTerracotta.withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${remainingSeconds}s',
                                        style: const TextStyle(
                                          color: Color(0xFFFFCC80),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_activeUndo!.subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _activeUndo!.subtitle,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.75),
                                      fontSize: 11.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Action Undo button
                          ElevatedButton.icon(
                            onPressed: _handleUndo,
                            icon: const Icon(Icons.undo_rounded, size: 15),
                            label: const Text(
                              'BATALKAN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryTerracotta,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Dismiss button
                          InkWell(
                            onTap: _dismissUndo,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Linear Cooldown Progress bar
                    LinearProgressIndicator(
                      value: remainingProgress,
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF8A65),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

    final int originalIndex = group.items.indexOf(item);
    final TodoItem deletedItem = item;
    final String groupId = group.id;

    HapticFeedback.selectionClick();
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

    _showTopUndoBanner(
      title: 'Tugas Dihapus',
      subtitle: deletedItem.title,
      onUndo: () {
        final targetGroup = _dateGroups.firstWhere(
          (g) => g.id == groupId,
          orElse: () => group,
        );
        final insertIndex = (originalIndex >= 0 && originalIndex <= targetGroup.items.length)
            ? originalIndex
            : targetGroup.items.length;
        setState(() {
          targetGroup.items.insert(insertIndex, deletedItem);
        });
        if (targetGroup.reminderEnabled) {
          TodoAlarmService.scheduleGroupAlarm(targetGroup);
        }
        _saveTodoData();
        CustomToast.showSuccess(
          context,
          title: 'Tugas Dikembalikan',
          subtitle: deletedItem.title,
        );
      },
    );
  }

  // --- HELPER METODE DRAG & DROP, PINDAH SECTION & GROUPING (MODE BIASA) ---

  void _toggleTaskSelection(String groupId, String taskId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_multiSelectGroupId != groupId) {
        _selectedTaskIds.clear();
        _multiSelectGroupId = groupId;
      }
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds.remove(taskId);
        if (_selectedTaskIds.isEmpty) {
          _multiSelectGroupId = null;
        }
      } else {
        _selectedTaskIds.add(taskId);
      }
    });
  }

  void _moveTasksToSection(
    TodoDateGroup sourceGroup,
    TodoDateGroup targetGroup,
    List<TodoItem> tasksToMove, {
    int? targetIndex,
  }) {
    if (_isSeriousMode) {
      CustomToast.showError(
        context,
        title: 'Tugas Terkunci',
        subtitle: 'Di Mode Serius, tugas tidak dapat dipindahkan ke section lain! 🚫',
      );
      return;
    }

    if (tasksToMove.isEmpty) return;
    if (sourceGroup.id == targetGroup.id) return;

    final List<TodoItem> movedTasks = List.from(tasksToMove);
    final Map<String, int> originalIndices = {};
    for (final task in movedTasks) {
      originalIndices[task.id] = sourceGroup.items.indexOf(task);
    }

    HapticFeedback.mediumImpact();
    setState(() {
      sourceGroup.items.removeWhere((item) => movedTasks.any((t) => t.id == item.id));
      if (targetIndex != null && targetIndex >= 0 && targetIndex <= targetGroup.items.length) {
        targetGroup.items.insertAll(targetIndex, movedTasks);
      } else {
        targetGroup.items.addAll(movedTasks);
      }
      _selectedTaskIds.clear();
      _multiSelectGroupId = null;
    });

    if (sourceGroup.reminderEnabled) {
      if (sourceGroup.isAllCompleted || sourceGroup.items.isEmpty) {
        TodoAlarmService.cancelGroupAlarm(sourceGroup.id);
      } else {
        TodoAlarmService.scheduleGroupAlarm(sourceGroup);
      }
    }
    if (targetGroup.reminderEnabled) {
      TodoAlarmService.scheduleGroupAlarm(targetGroup);
    }

    _saveTodoData();

    _showTopUndoBanner(
      title: 'Tugas Dipindahkan',
      subtitle: movedTasks.length == 1
          ? '${movedTasks.first.title} ➔ ${targetGroup.relativeDateLabel} (${targetGroup.formattedDateShort})'
          : '${movedTasks.length} tugas ➔ ${targetGroup.relativeDateLabel} (${targetGroup.formattedDateShort})',
      onUndo: () {
        setState(() {
          targetGroup.items.removeWhere((item) => movedTasks.any((t) => t.id == item.id));
          for (final task in movedTasks) {
            final origIdx = originalIndices[task.id] ?? sourceGroup.items.length;
            final insertIdx = origIdx.clamp(0, sourceGroup.items.length);
            sourceGroup.items.insert(insertIdx, task);
          }
        });
        if (sourceGroup.reminderEnabled) {
          TodoAlarmService.scheduleGroupAlarm(sourceGroup);
        }
        if (targetGroup.reminderEnabled) {
          if (targetGroup.isAllCompleted || targetGroup.items.isEmpty) {
            TodoAlarmService.cancelGroupAlarm(targetGroup.id);
          } else {
            TodoAlarmService.scheduleGroupAlarm(targetGroup);
          }
        }
        _saveTodoData();
      },
    );
  }

  void _reorderTasksWithinSection(
    TodoDateGroup group,
    List<TodoItem> itemsToReorder,
    int targetIndex,
  ) {
    if (_isSeriousMode || itemsToReorder.isEmpty) return;

    HapticFeedback.selectionClick();
    setState(() {
      TodoItem? targetItem;
      if (targetIndex >= 0 && targetIndex < group.items.length) {
        targetItem = group.items[targetIndex];
      }
      group.items.removeWhere((i) => itemsToReorder.any((t) => t.id == i.id));
      int newInsertIndex = targetItem != null ? group.items.indexOf(targetItem) : group.items.length;
      if (newInsertIndex < 0) newInsertIndex = group.items.length;
      group.items.insertAll(newInsertIndex, itemsToReorder);
      _selectedTaskIds.clear();
      _multiSelectGroupId = null;
    });
    _saveTodoData();
  }

  void _showMoveTasksModal(TodoDateGroup sourceGroup, List<TodoItem> tasksToMove) {
    if (_isSeriousMode) return;
    final otherGroups = _dateGroups.where((g) => g.id != sourceGroup.id && !g.isArchived).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: _isSeriousMode ? seriousCardBg : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryTerracotta.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.drive_file_move_rounded, color: primaryTerracotta, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pindahkan ${tasksToMove.length} Tugas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isSeriousMode ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Dari ${sourceGroup.formattedDateShort} ke section tanggal lain:',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isSeriousMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (otherGroups.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Tidak ada section tanggal lain yang tersedia',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: _isSeriousMode ? const Color(0xFF94A3B8) : Colors.grey[500],
                      ),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: otherGroups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final target = otherGroups[idx];
                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _moveTasksToSection(sourceGroup, target, tasksToMove);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: target.isToday
                                ? primaryTerracotta.withValues(alpha: 0.08)
                                : (_isSeriousMode
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: target.isToday
                                  ? primaryTerracotta.withValues(alpha: 0.4)
                                  : (_isSeriousMode ? seriousBorder : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: target.isToday ? primaryTerracotta : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  target.formattedFullDate,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: target.isToday ? FontWeight.bold : FontWeight.w500,
                                    color: target.isToday
                                        ? primaryTerracotta
                                        : (_isSeriousMode ? Colors.white : const Color(0xFF1E293B)),
                                  ),
                                ),
                              ),
                              if (target.isToday)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primaryTerracotta,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Hari Ini',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
    );
  }



  Widget _buildMultiSelectBottomBar() {
    if (_isSeriousMode || _selectedTaskIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedCount = _selectedTaskIds.length;
    TodoDateGroup? activeGroup;
    for (final g in _dateGroups) {
      if (g.items.any((i) => _selectedTaskIds.contains(i.id))) {
        activeGroup = g;
        break;
      }
    }

    final selectedTasks = activeGroup?.items
        .where((i) => _selectedTaskIds.contains(i.id))
        .toList() ?? [];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: primaryTerracotta.withValues(alpha: 0.5),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryTerracotta,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$selectedCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tugas Dipilih',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Tahan & seret untuk atur / pindahkan',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (activeGroup != null) ...[
                IconButton(
                  onPressed: () => _showMoveTasksModal(
                    activeGroup!,
                    selectedTasks,
                  ),
                  tooltip: 'Pindahkan ke Section Lain',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.drive_file_move_rounded, color: Colors.white, size: 20),
                ),
                IconButton(
                  onPressed: () {
                    for (final task in selectedTasks) {
                      task.isCompleted = true;
                    }
                    _selectedTaskIds.clear();
                    _saveTodoData();
                    setState(() {});
                  },
                  tooltip: 'Tandai Selesai',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.done_all_rounded, color: Color(0xFF10B981), size: 20),
                ),
                IconButton(
                  onPressed: () {
                    final itemsToDelete = List<TodoItem>.from(selectedTasks);
                    final group = activeGroup!;
                    setState(() {
                      group.items.removeWhere((i) => _selectedTaskIds.contains(i.id));
                      _selectedTaskIds.clear();
                    });
                    _saveTodoData();
                    _showTopUndoBanner(
                      title: 'Tugas Dihapus',
                      subtitle: '${itemsToDelete.length} tugas dihapus',
                      onUndo: () {
                        setState(() {
                          group.items.addAll(itemsToDelete);
                        });
                        _saveTodoData();
                      },
                    );
                  },
                  tooltip: 'Hapus Tugas',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                ),
              ],
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedTaskIds.clear();
                    _multiSelectGroupId = null;
                  });
                },
                tooltip: 'Batal',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatchDragFeedback(
    List<TodoItem> tasks, {
    bool isProxy = false,
    TodoItem? singleFallback,
  }) {
    final effectiveTasks = tasks.isNotEmpty
        ? tasks
        : (singleFallback != null ? [singleFallback] : <TodoItem>[]);

    if (effectiveTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 8,
      color: Colors.transparent,
      shadowColor: primaryTerracotta.withValues(alpha: 0.35),
      child: Container(
        decoration: BoxDecoration(
          color: _isSeriousMode ? seriousCardBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: primaryTerracotta.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: primaryTerracotta, width: 1.8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: effectiveTasks.asMap().entries.map((entry) {
                final idx = entry.key;
                final t = entry.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: idx > 0
                      ? BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: _isSeriousMode
                                  ? const Color(0xFF334155)
                                  : Colors.grey.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                        )
                      : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.drag_indicator_rounded,
                        color: primaryTerracotta,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          t.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _isSeriousMode
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableTaskTile(TodoDateGroup group, TodoItem item, {int index = 0}) {
    if (_isSeriousMode) {
      return _buildTaskItemTile(group, item, index: index);
    }

    final isSelected = _selectedTaskIds.contains(item.id);
    final tasksBeingDragged = isSelected
        ? group.items.where((i) => _selectedTaskIds.contains(i.id)).toList()
        : [item];

    return ValueListenableBuilder<Set<String>>(
      valueListenable: _activeDraggingTaskIdsNotifier,
      builder: (context, activeDraggedIds, _) {
        final isItemBeingDragged = activeDraggedIds.contains(item.id) ||
            (_isDraggingTasks && (isSelected || _draggingTaskId == item.id));

        return DragTarget<TodoDragPayload>(
          onWillAcceptWithDetails: (details) => true,
          onAcceptWithDetails: (details) {
            final payload = details.data;
            _activeDraggingTaskIdsNotifier.value = {};
            if (payload.sourceGroupId == group.id) {
              final targetIndex = group.items.indexOf(item);
              _reorderTasksWithinSection(group, payload.items, targetIndex);
            } else {
              final sourceGroup = _dateGroups.firstWhere(
                (g) => g.id == payload.sourceGroupId,
                orElse: () => group,
              );
              final targetIndex = group.items.indexOf(item);
              _moveTasksToSection(sourceGroup, group, payload.items, targetIndex: targetIndex);
            }
          },
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;
            final childTile = _buildTaskItemTile(
              group,
              item,
              index: index,
              isSelected: isSelected,
              onSelectionToggled: () {
                _toggleTaskSelection(group.id, item.id);
              },
            );

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isHovering)
                  Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryTerracotta,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                LongPressDraggable<TodoDragPayload>(
                  data: TodoDragPayload(
                    sourceGroupId: group.id,
                    items: tasksBeingDragged,
                    sourceIndex: group.items.indexOf(item),
                  ),
                  onDragStarted: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _isDraggingTasks = true;
                      _draggingTaskId = item.id;
                      if (!_selectedTaskIds.contains(item.id)) {
                        _multiSelectGroupId = group.id;
                        _selectedTaskIds.add(item.id);
                      }
                    });
                    _activeDraggingTaskIdsNotifier.value = isSelected
                        ? Set<String>.from(_selectedTaskIds)
                        : {item.id};
                  },
                  onDragEnd: (_) {
                    setState(() {
                      _isDraggingTasks = false;
                      _draggingTaskId = null;
                    });
                    _activeDraggingTaskIdsNotifier.value = {};
                  },
                  onDraggableCanceled: (_, __) {
                    setState(() {
                      _isDraggingTasks = false;
                      _draggingTaskId = null;
                    });
                    _activeDraggingTaskIdsNotifier.value = {};
                  },
                  feedback: Material(
                    color: Colors.transparent,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: _buildBatchDragFeedback(
                        tasksBeingDragged,
                        isProxy: false,
                        singleFallback: item,
                      ),
                    ),
                  ),
                  childWhenDragging: Visibility(
                    visible: false,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: childTile,
                  ),
                  child: isItemBeingDragged
                      ? Visibility(
                          visible: false,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: childTile,
                        )
                      : childTile,
                ),
              ],
            );
          },
        );
      },
    );
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
      final int originalIndex = _dateGroups.indexOf(group);
      final TodoDateGroup deletedGroup = group;

      TodoAlarmService.cancelGroupAlarm(group.id);
      setState(() {
        _dateGroups.removeWhere((g) => g.id == group.id);
      });
      _saveTodoData();

      _showTopUndoBanner(
        title: 'Section Dihapus',
        subtitle: '${deletedGroup.formattedFullDate} (${deletedGroup.totalCount} tugas)',
        onUndo: () {
          final insertIndex = (originalIndex >= 0 && originalIndex <= _dateGroups.length)
              ? originalIndex
              : _dateGroups.length;
          setState(() {
            _dateGroups.insert(insertIndex, deletedGroup);
          });
          if (deletedGroup.reminderEnabled &&
              !deletedGroup.isAllCompleted &&
              deletedGroup.items.isNotEmpty) {
            TodoAlarmService.scheduleGroupAlarm(deletedGroup);
          }
          _saveTodoData();
          CustomToast.showSuccess(
            context,
            title: 'Section Dikembalikan',
            subtitle: deletedGroup.formattedFullDate,
          );
        },
      );
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
          final isSerious = await SeriousModeService.isSeriousModeActive();
          final user = await SeriousModeService.getCurrentUser();
          if (mounted) {
            setState(() {
              _isSeriousMode = isSerious;
              _seriousUser = user;
              _transitionType = isSerious
                  ? TodoTransitionType.switchAccount
                  : TodoTransitionType.toNormal;
              _transitionUser = user;
              _isLoading = true;
            });
            await _loadTodoData(
              transitionType: isSerious
                  ? TodoTransitionType.switchAccount
                  : TodoTransitionType.toNormal,
              transitionUser: user,
              showTransition: true,
            );
          }
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _isLoading
            ? TodoModeTransitionWidget(
                key: const ValueKey('todo_transition_loading_view'),
                transitionType: _transitionType,
                user: _transitionUser ?? _seriousUser,
                customSubtitle: _transitionSubtitle,
                isDarkMode: _isSeriousMode,
              )
            : Stack(
                key: const ValueKey('todo_main_content_view'),
                children: [
                  RefreshIndicator(
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
                                return KeyedSubtree(
                                  key: ValueKey(group.id),
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
                if (!_isSeriousMode && _activeUndo != null)
                  Positioned(
                    top: 10,
                    left: 16,
                    right: 16,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 580),
                        child: _buildTopUndoBanner(),
                      ),
                    ),
                  ),
                if (!_isSeriousMode && _selectedTaskIds.isNotEmpty)
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: _buildMultiSelectBottomBar(),
                  ),
              ],
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

    return DragTarget<TodoDragPayload>(
      onWillAcceptWithDetails: (details) {
        if (_isSeriousMode) return false;
        return true;
      },
      onAcceptWithDetails: (details) {
        final payload = details.data;
        if (payload.sourceGroupId != group.id) {
          final sourceGroup = _dateGroups.firstWhere(
            (g) => g.id == payload.sourceGroupId,
            orElse: () => group,
          );
          _moveTasksToSection(sourceGroup, group, payload.items);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isDropHover = candidateData.any((p) => p != null && p.sourceGroupId != group.id);

        return Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _isSeriousMode ? seriousCardBg : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDropHover
                    ? primaryTerracotta
                    : (_isSeriousMode
                        ? (group.isToday
                            ? seriousGold.withValues(alpha: 0.5)
                            : const Color(0xFF334155))
                        : (group.isToday
                            ? primaryTerracotta.withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.06))),
                width: isDropHover ? 2.2 : (group.isToday ? 1.6 : 1.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDropHover
                      ? primaryTerracotta.withValues(alpha: 0.35)
                      : (_isSeriousMode
                          ? Colors.black.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.04)),
                  blurRadius: isDropHover ? 14 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isDropHover && candidateData.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: primaryTerracotta.withValues(alpha: 0.15),
                        border: Border(
                          bottom: BorderSide(
                            color: primaryTerracotta.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.move_to_inbox_rounded, color: primaryTerracotta, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lepas di sini untuk memindahkan ${candidateData.first?.items.length ?? 1} tugas ke section ini',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryTerracotta,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                                        () {
                                          final int sectionPts = _isSeriousMode
                                              ? SeriousModeService.calculateSectionPoints(group, states: _punishmentStates)
                                              : SeriousModeService.calculatePoints(group.completedCount);
                                          final isNegative = sectionPts < 0;
                                          final ptsText = isNegative ? '$sectionPts PTS' : '+$sectionPts PTS';
                                          final Color ptsBadgeBg = _isSeriousMode
                                              ? (isNegative
                                                  ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                                                  : seriousGold.withValues(alpha: 0.18))
                                              : primaryTerracotta.withValues(alpha: 0.15);
                                          final Color ptsBadgeFg = _isSeriousMode
                                              ? (isNegative ? const Color(0xFFF87171) : seriousGold)
                                              : primaryTerracotta;

                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: ptsBadgeBg,
                                              borderRadius: BorderRadius.circular(6),
                                              border: isNegative
                                                  ? Border.all(
                                                      color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                                                      width: 0.8,
                                                    )
                                                  : null,
                                            ),
                                            child: Text(
                                              ptsText,
                                              style: TextStyle(
                                                color: ptsBadgeFg,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        }(),
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
                                            color: group.isPast
                                                ? (_isSeriousMode
                                                        ? Colors.white.withValues(alpha: 0.05)
                                                        : Colors.grey.withValues(alpha: 0.1))
                                                : (_isSeriousMode
                                                        ? seriousGold
                                                        : primaryTerracotta)
                                                    .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: group.isPast
                                                  ? (_isSeriousMode
                                                          ? Colors.white24
                                                          : Colors.grey.withValues(alpha: 0.3))
                                                  : (_isSeriousMode
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
                                                group.isPast
                                                    ? Icons.alarm_off_rounded
                                                    : Icons.alarm_on_rounded,
                                                size: 12,
                                                color: group.isPast
                                                    ? (_isSeriousMode
                                                            ? Colors.white54
                                                            : const Color(0xFF94A3B8))
                                                    : (_isSeriousMode
                                                            ? seriousGold
                                                            : primaryTerracotta),
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  group.isPast
                                                      ? '${group.reminderSummaryLabel} (Lewat)'
                                                      : group.reminderSummaryLabel,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: group.isPast
                                                        ? (_isSeriousMode
                                                                ? Colors.white54
                                                                : const Color(0xFF94A3B8))
                                                        : (_isSeriousMode
                                                                ? seriousGold
                                                                : primaryTerracotta),
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
                            final completedItems = group.items.where((i) => i.isCompleted).toList();
                            if (completedItems.isEmpty) return;

                            final allOriginalItems = List<TodoItem>.from(group.items);
                            final groupId = group.id;

                            setState(() {
                              group.items.removeWhere((i) => i.isCompleted);
                            });
                            _saveTodoData();

                            _showTopUndoBanner(
                              title: 'Tugas Selesai Dihapus',
                              subtitle: '${completedItems.length} tugas selesai dihapus dari section',
                              onUndo: () {
                                final targetGroup = _dateGroups.firstWhere(
                                  (g) => g.id == groupId,
                                  orElse: () => group,
                                );
                                setState(() {
                                  targetGroup.items = List<TodoItem>.from(allOriginalItems);
                                });
                                _saveTodoData();
                                CustomToast.showSuccess(
                                  context,
                                  title: 'Tugas Selesai Dikembalikan',
                                  subtitle: '${completedItems.length} tugas dipulihkan',
                                );
                              },
                            );
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
                                Flexible(
                                  child: Text(
                                    'Tambah Tugas',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _isSeriousMode
                                          ? Colors.white
                                          : const Color(0xFF1E293B),
                                    ),
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
                                Flexible(
                                  child: Text(
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
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'archive',
                            enabled: _canArchiveGroup(group),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.archive_rounded,
                                  size: 18,
                                  color: _canArchiveGroup(group)
                                      ? (_isSeriousMode
                                          ? const Color(0xFF10B981)
                                          : accentCompleted)
                                      : (_isSeriousMode
                                          ? Colors.white38
                                          : const Color(0xFF94A3B8)),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _canArchiveGroup(group)
                                        ? 'Arsipkan Section'
                                        : 'Arsipkan (Belum Selesai)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _canArchiveGroup(group)
                                          ? (_isSeriousMode
                                              ? Colors.white
                                              : const Color(0xFF1E293B))
                                          : (_isSeriousMode
                                              ? Colors.white38
                                              : const Color(0xFF94A3B8)),
                                    ),
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
                                Flexible(
                                  child: Text(
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
                                Flexible(
                                  child: Text(
                                    'Tandai Semua Selesai',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _isSeriousMode
                                          ? Colors.white
                                          : const Color(0xFF1E293B),
                                    ),
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
                                Flexible(
                                  child: Text(
                                    'Hapus Tugas Selesai',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _isSeriousMode
                                          ? Colors.white
                                          : const Color(0xFF1E293B),
                                    ),
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
                                Flexible(
                                  child: Text(
                                    'Hapus Section Ini',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _isSeriousMode
                                          ? seriousFire
                                          : Colors.red,
                                    ),
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

                          // Kartu Evaluasi / Note Tebus Hukuman Mode Serius untuk Section yang Terlewat
                          if (_isSeriousMode)
                            () {
                              final state = _punishmentStates[group.id];
                              if (state != null && state.isFullyCompleted) {
                                // Tampilkan Note Mode Tebus Hukuman
                                return _buildTebusHukumanNote(group, state);
                              }
                              if (state != null && state.isSurrendered) {
                                // Tampilkan Note Menyerah (dengan opsi arsipkan)
                                return _buildSurrenderedNote(group, state);
                              }
                              final eval = SeriousModeService.evaluateSection(group, states: _punishmentStates);
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
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              itemCount: itemsToShow.length,
                              proxyDecorator: (child, index, animation) {
                                final draggedItem = index < itemsToShow.length ? itemsToShow[index] : null;
                                final isBatch = draggedItem != null &&
                                    _selectedTaskIds.contains(draggedItem.id) &&
                                    _selectedTaskIds.length > 1;

                                final selectedTasks = isBatch
                                    ? group.items.where((i) => _selectedTaskIds.contains(i.id)).toList()
                                    : (draggedItem != null ? [draggedItem] : <TodoItem>[]);

                                return AnimatedBuilder(
                                  animation: animation,
                                  builder: (context, _) {
                                    if (isBatch && selectedTasks.isNotEmpty) {
                                      return _buildBatchDragFeedback(
                                        selectedTasks,
                                        isProxy: true,
                                        singleFallback: draggedItem,
                                      );
                                    }

                                    return Material(
                                      elevation: 6,
                                      color: _isSeriousMode ? seriousCardBg : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      shadowColor: primaryTerracotta.withValues(alpha: 0.3),
                                      child: child,
                                    );
                                  },
                                );
                              },
                              onReorderItem: (oldIndex, newIndex) {
                                _activeDraggingTaskIdsNotifier.value = {};
                                if (_isSeriousMode) return;
                                if (oldIndex == newIndex) return;

                                final itemToMove = itemsToShow[oldIndex];
                                final targetItem = itemsToShow[newIndex];

                                final isMovingSelectedBatch = _selectedTaskIds.contains(itemToMove.id) &&
                                    _selectedTaskIds.length > 1;

                                final List<TodoItem> itemsToReorder = isMovingSelectedBatch
                                    ? group.items
                                        .where((i) => _selectedTaskIds.contains(i.id))
                                        .toList()
                                    : [itemToMove];

                                final actualOldIndex = group.items.indexOf(itemToMove);
                                if (actualOldIndex == -1) return;

                                HapticFeedback.selectionClick();
                                setState(() {
                                  final isTargetInBatch =
                                      itemsToReorder.any((i) => i.id == targetItem.id);

                                  group.items.removeWhere(
                                      (i) => itemsToReorder.any((t) => t.id == i.id));

                                  int insertIndex;
                                  if (isTargetInBatch) {
                                    insertIndex = actualOldIndex.clamp(0, group.items.length);
                                  } else {
                                    final targetActualIndex = group.items.indexOf(targetItem);
                                    if (targetActualIndex == -1) {
                                      insertIndex = group.items.length;
                                    } else if (newIndex > oldIndex) {
                                      insertIndex = targetActualIndex + 1;
                                    } else {
                                      insertIndex = targetActualIndex;
                                    }
                                  }

                                  if (insertIndex < 0) insertIndex = 0;
                                  if (insertIndex > group.items.length) {
                                    insertIndex = group.items.length;
                                  }

                                  group.items.insertAll(insertIndex, itemsToReorder);
                                  _selectedTaskIds.clear();
                                  _multiSelectGroupId = null;
                                });
                                _saveTodoData();
                              },
                              itemBuilder: (context, idx) {
                                final item = itemsToShow[idx];
                                return KeyedSubtree(
                                  key: ValueKey('task_${item.id}'),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildDraggableTaskTile(group, item, index: idx),
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
                                  ),
                                );
                              },
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
  },
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
              onPressed: () async {
                await SeriousPunishmentDialog.show(
                  context,
                  evaluation: eval,
                  allGroups: _dateGroups,
                  onCompleted: () {
                    _loadTodoData();
                  },
                  onSurrendered: (groupId) {
                    _handleSurrenderAshEffect(groupId);
                  },
                );
                await _loadTodoData();
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- NOTE TEBUS HUKUMAN MODE SERIUS PADA SECTION ---
  Widget _buildTebusHukumanNote(
      TodoDateGroup group, SeriousGroupPunishmentState state) {
    final points = SeriousModeService.calculatePoints(group.totalCount);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.5),
          width: 1.3,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: Color(0xFF34D399),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'MODE TEBUS HUKUMAN AKTIF',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF34D399),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Poin Bertahan 🛡️',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6EE7B7),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Seluruh ${state.totalAssigned} latihan fisik telah diselesaikan! Poin penuh jadwal hari ini ($points Pts) berhasil dipertahankan.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFFD1FAE5),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => _archiveGroup(group),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.archive_rounded, size: 13),
                    label: const Text(
                      'Arsipkan Section',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
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

  // --- NOTE MENYERAH MODE SERIUS PADA SECTION ---
  Widget _buildSurrenderedNote(
      TodoDateGroup group, SeriousGroupPunishmentState state) {
    final penalty = state.assignedPunishmentIds.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.4),
          width: 1.3,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.flag_rounded,
              color: Color(0xFFF87171),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'STATUS MENYERAH',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF87171),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '-$penalty Pts ⚠️',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFCA5A5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Kamu memutuskan menyerah untuk section ini. Poin telah disesuaikan dan section siap diarsipkan.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFFCBD5E1),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => _archiveGroup(group),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF475569),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.archive_rounded, size: 13),
                    label: const Text(
                      'Arsipkan Section',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
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

  // --- TASK ITEM TILE DENGAN CHECKBOX & NAMA TUGAS ---
  Widget _buildTaskItemTile(
    TodoDateGroup group,
    TodoItem item, {
    int index = 0,
    bool isSelected = false,
    VoidCallback? onSelectionToggled,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groupDate =
        DateTime(group.date.year, group.date.month, group.date.day);
    final isMissedLocked =
        _isSeriousMode && groupDate.isBefore(today) && !item.isCompleted;
    final isMultiSelect = !_isSeriousMode && _selectedTaskIds.isNotEmpty;
    final isDisintegrating = _disintegratingTaskIds.contains(item.id);

    return AshDisintegrationWrapper(
      isDisintegrating: isDisintegrating,
      seed: item.id.hashCode,
      child: Dismissible(
      key: Key(item.id),
      direction:
          (_isSeriousMode || isMultiSelect) ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red[600],
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 18),
      ),
      onDismissed: (_) => _deleteTask(group, item),
      child: InkWell(
        onTap: () {
          if (isMultiSelect) {
            if (onSelectionToggled != null) {
              onSelectionToggled();
            } else {
              _toggleTaskSelection(group.id, item.id);
            }
          } else {
            _toggleTask(group, item);
          }
        },
        onLongPress: () {
          if (!_isSeriousMode) {
            HapticFeedback.mediumImpact();
            _toggleTaskSelection(group.id, item.id);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? primaryTerracotta.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(
                    color: primaryTerracotta.withValues(alpha: 0.45),
                    width: 1.2,
                  )
                : null,
          ),
          padding: const EdgeInsets.only(
            left: 12,
            right: 4,
            top: 3.5,
            bottom: 3.5,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox (Seleksi jika mode pilih banyak aktif, atau Checkbox Status Selesai)
              if (isMultiSelect)
                GestureDetector(
                  onTap: onSelectionToggled ?? () => _toggleTaskSelection(group.id, item.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isSelected ? primaryTerracotta : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? primaryTerracotta : const Color(0xFFCBD5E1),
                        width: 1.8,
                      ),
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(Icons.check_rounded, color: Colors.white, size: 13),
                          )
                        : null,
                  ),
                )
              else
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
              else ...[
                Listener(
                  onPointerDown: (_) {
                    if (_selectedTaskIds.contains(item.id)) {
                      _activeDraggingTaskIdsNotifier.value =
                          Set<String>.from(_selectedTaskIds);
                    } else {
                      _activeDraggingTaskIdsNotifier.value = {item.id};
                    }
                  },
                  onPointerCancel: (_) {
                    _activeDraggingTaskIdsNotifier.value = {};
                  },
                  child: ReorderableDragStartListener(
                    index: index,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        color: Colors.transparent,
                        child: const Icon(
                          Icons.drag_indicator_rounded,
                          size: 19,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
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
