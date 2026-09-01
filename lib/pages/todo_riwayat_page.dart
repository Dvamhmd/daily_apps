import 'dart:convert';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/utils/responsive_text.dart';
import 'package:daily_apps/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_apps/utils/serious_mode_service.dart';

class TodoRiwayatPage extends StatefulWidget {
  final bool isSeriousMode;

  const TodoRiwayatPage({
    super.key,
    this.isSeriousMode = false,
  });

  @override
  State<TodoRiwayatPage> createState() => _TodoRiwayatPageState();
}

class _TodoRiwayatPageState extends State<TodoRiwayatPage> {
  static const Color primaryTerracotta = Color(0xFFBA5A3A);
  static const Color seriousBg = Color(0xFF0F172A);
  static const Color seriousCardBg = Color(0xFF1E293B);
  static const Color seriousCardBorder = Color(0xFF334155);
  static const Color seriousGold = Color(0xFFF59E0B);
  static const Color seriousFire = Color(0xFFEF4444);
  static const Color accentCompleted = Color(0xFF2E7D32);

  static const String _prefsKeyNormal = SeriousModeService.prefKeyNormalTodoGroups;
  static const String _prefsKeySerious = SeriousModeService.prefKeySeriousTodoGroups;

  String get _prefsKey =>
      widget.isSeriousMode ? _prefsKeySerious : _prefsKeyNormal;

  List<TodoDateGroup> _allGroups = [];
  final Set<String> _collapsedGroupIds = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<String> _getEffectiveKey() async {
    if (widget.isSeriousMode) {
      final user = await SeriousModeService.getCurrentUser();
      return SeriousModeService.getSeriousTodoGroupsKey(user?.id);
    }
    return SeriousModeService.prefKeyNormalTodoGroups;
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getEffectiveKey();
      final String? jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _allGroups = decoded
            .map((item) => TodoDateGroup.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading history todos: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getEffectiveKey();
      final String encoded = jsonEncode(
        _allGroups.map((group) => group.toJson()).toList(),
      );
      await prefs.setString(key, encoded);
    } catch (e) {
      debugPrint('Error saving todos: $e');
    }
  }

  // Section yang telah diarsipkan
  List<TodoDateGroup> get _archivedGroups {
    final archived = _allGroups.where((group) => group.isArchived).toList();

    // Urutkan dari tanggal terbaru
    archived.sort((a, b) => b.date.compareTo(a.date));

    if (_searchQuery.isEmpty) return archived;

    final query = _searchQuery.toLowerCase();
    return archived.where((group) {
      final matchesDate = group.formattedFullDate.toLowerCase().contains(query);
      final matchesTask = group.items.any(
        (item) => item.title.toLowerCase().contains(query),
      );
      return matchesDate || matchesTask;
    }).toList();
  }

  int get _totalCompletedTasks {
    return _archivedGroups.fold(0, (sum, g) => sum + g.completedCount);
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

  /// Mengembalikan section dari arsip ke daftar aktif
  void _unarchiveGroup(TodoDateGroup group) {
    HapticFeedback.mediumImpact();
    setState(() {
      group.isArchived = false;
    });
    _saveData();
  }

  /// Aktifkan kembali / batalkan checklist tugas
  void _uncompleteTask(TodoDateGroup group, TodoItem item) {
    HapticFeedback.selectionClick();
    setState(() {
      item.isCompleted = false;
      // Jika tugas diaktifkan kembali, otomatis unarchive section agar muncul di todo list aktif
      group.isArchived = false;
      group.items = [
        ...group.items.where((i) => !i.isCompleted),
        ...group.items.where((i) => i.isCompleted),
      ];
    });
    _saveData();
  }

  /// Hapus satu section selesai permanen
  Future<void> _deleteCompletedSection(TodoDateGroup group) async {
    final isDark = widget.isSeriousMode;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? seriousCardBg : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? seriousCardBorder : Colors.transparent,
            ),
          ),
          title: Row(
            children: [
              const Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 24),
              const SizedBox(width: 10),
              Text(
                'Hapus Riwayat?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          content: Text(
            'Hapus permanen riwayat to-do pada tanggal "${group.formattedFullDate}"?',
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            ),
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
      setState(() {
        _allGroups.removeWhere((g) => g.id == group.id);
      });
      _saveData();
      if (mounted) {
        CustomToast.showSuccess(
          context,
          title: 'Riwayat to-do berhasil dihapus',
        );
      }
    }
  }

  /// Bersihkan Semua Riwayat Arsip Selesai
  Future<void> _clearAllCompleted() async {
    if (_archivedGroups.isEmpty) return;

    final isDark = widget.isSeriousMode;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? seriousCardBg : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? seriousCardBorder : Colors.transparent,
            ),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
              const SizedBox(width: 10),
              Text(
                'Hapus Semua Riwayat?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          content: Text(
            'Apakah kamu yakin ingin menghapus seluruh riwayat section to-do yang sudah diarsipkan?',
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            ),
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
              child: const Text('Hapus Semua'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _allGroups.removeWhere((g) => g.isArchived);
      });
      _saveData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final archivedList = _archivedGroups;
    final isDark = widget.isSeriousMode;

    return Scaffold(
      backgroundColor: isDark ? seriousBg : const Color(0xFFFBF8F6),
      appBar: AppBar(
        backgroundColor: isDark ? seriousBg : primaryTerracotta,
        centerTitle: true,
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
              isDark
                  ? Icons.history_rounded
                  : Icons.history_toggle_off_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              isDark
                  ? 'Riwayat Task (Mode Serius)'
                  : 'Riwayat Task',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17.5,
              ),
            ),
          ],
        ),
        actions: [
          if (archivedList.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
              tooltip: 'Hapus Semua Riwayat',
              onPressed: _clearAllCompleted,
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? seriousGold : primaryTerracotta,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: isDark ? seriousGold : primaryTerracotta,
              child: ResponsiveContentWrapper(
                maxWidth: 720,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  children: [
                    // Banner Ringkasan Riwayat
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                              : [const Color(0xFF2E7D32), const Color(0xFF1B5E20)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark
                              ? seriousGold.withValues(alpha: 0.35)
                              : Colors.transparent,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.35)
                                : accentCompleted.withValues(alpha: 0.28),
                            blurRadius: 15,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? seriousGold.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: isDark
                                      ? Border.all(
                                          color: seriousGold.withValues(alpha: 0.4))
                                      : null,
                                ),
                                child: Text(
                                  isDark ? 'ARSIP MODE SERIUS 🔥' : 'ARCHIVED SECTIONS',
                                  style: TextStyle(
                                    color: isDark ? seriousGold : Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.archive_rounded,
                                color: isDark ? seriousGold : Colors.white,
                                size: 22,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Section yang Telah Diarsipkan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isDark
                                ? 'Daftar riwayat tugas mode serius yang telah diselesaikan dan diarsipkan.'
                                : 'Daftar section to-do yang telah diselesaikan dan kamu arsipkan.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildStatBadge(
                                '${archivedList.length} Section',
                                Icons.calendar_today_rounded,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 10),
                              _buildStatBadge(
                                '$_totalCompletedTasks Tugas',
                                Icons.task_alt_rounded,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Search Bar
                    TextField(
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Cari riwayat tugas atau tanggal...',
                        hintStyle: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey[400],
                          fontSize: 13.5,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: isDark ? seriousGold : accentCompleted,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: isDark ? seriousCardBg : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDark
                                ? seriousCardBorder
                                : accentCompleted.withValues(alpha: 0.15),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDark
                                ? seriousCardBorder
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDark ? seriousGold : accentCompleted,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Daftar Section Selesai
                    if (archivedList.isEmpty)
                      _buildEmptyRiwayat()
                    else
                      ...archivedList.map(
                        (group) => _buildCompletedGroupCard(group),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatBadge(String label, IconData icon, {required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? seriousGold.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: isDark
            ? Border.all(color: seriousGold.withValues(alpha: 0.35))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isDark ? seriousGold : Colors.white,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isDark ? seriousGold : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedGroupCard(TodoDateGroup group) {
    final isCollapsed = _isGroupCollapsed(group.id);
    final isDark = widget.isSeriousMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? seriousCardBg : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? seriousCardBorder
              : accentCompleted.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.03),
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
            // Header Section Diarsipkan (Tappable untuk Expand / Collapse)
            InkWell(
              onTap: () => _toggleGroupCollapse(group.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                color: isDark
                    ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                    : accentCompleted.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: isDark ? seriousGold : accentCompleted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.done_all_rounded,
                        color: isDark ? Colors.black : Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.formattedFullDate,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${group.totalCount} Tugas selesai',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFFFDE68A) : accentCompleted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Tombol Kembalikan / Batalkan Arsip (Unarchive)
                    IconButton(
                      icon: Icon(
                        Icons.unarchive_rounded,
                        color: isDark ? seriousGold : primaryTerracotta,
                        size: 20,
                      ),
                      tooltip: 'Kembalikan ke Daftar Aktif',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _unarchiveGroup(group),
                    ),

                    // Chevron Expand / Collapse
                    IconButton(
                      icon: AnimatedRotation(
                        turns: isCollapsed ? 0.0 : 0.5,
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: isDark ? seriousGold : accentCompleted,
                          size: 22,
                        ),
                      ),
                      tooltip: isCollapsed ? 'Buka Section' : 'Tutup Section',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _toggleGroupCollapse(group.id),
                    ),

                    // Tombol Hapus Section Ini
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      tooltip: 'Hapus Riwayat Ini',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _deleteCompletedSection(group),
                    ),
                  ],
                ),
              ),
            ),

            // Daftar Tugas dengan animasi slide yang mulus
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.topCenter,
              child: isCollapsed
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        for (int idx = 0; idx < group.items.length; idx++) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: group.items[idx].isCompleted
                                        ? (isDark ? seriousGold : accentCompleted)
                                        : (isDark ? const Color(0xFF475569) : Colors.grey[400]),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    group.items[idx].isCompleted
                                        ? Icons.check_rounded
                                        : Icons.radio_button_unchecked,
                                    color: isDark ? Colors.black : Colors.white,
                                    size: 13,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    group.items[idx].title,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: group.items[idx].isCompleted
                                          ? (isDark ? const Color(0xFF64748B) : const Color(0xFF64748B))
                                          : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B)),
                                      decoration: group.items[idx].isCompleted
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                      decorationColor: isDark
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _uncompleteTask(
                                      group, group.items[idx]),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: Icon(
                                    Icons.undo_rounded,
                                    size: 13,
                                    color: isDark ? seriousGold : primaryTerracotta,
                                  ),
                                  label: Text(
                                    'Aktifkan',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? seriousGold : primaryTerracotta,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (idx < group.items.length - 1)
                            Divider(
                              height: 1,
                              thickness: 0.6,
                              color: isDark
                                  ? seriousCardBorder.withValues(alpha: 0.5)
                                  : Colors.grey.withValues(alpha: 0.12),
                              indent: 44,
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRiwayat() {
    final isDark = widget.isSeriousMode;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? seriousCardBg : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? seriousCardBorder
              : accentCompleted.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
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
              color: isDark
                  ? seriousGold.withValues(alpha: 0.15)
                  : accentCompleted.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.archive_rounded,
              size: 36,
              color: isDark ? seriousGold : accentCompleted,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Belum Ada Section yang Diarsipkan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isDark
                ? 'Section mode serius yang telah selesai dan kamu arsipkan pada halaman To-Do List akan muncul di sini.'
                : 'Section tanggal yang telah selesai dan kamu pilih untuk "Arsipkan" pada halaman To-Do List akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
