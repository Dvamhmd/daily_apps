import 'dart:convert';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/utils/responsive_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TodoRiwayatPage extends StatefulWidget {
  const TodoRiwayatPage({super.key});

  @override
  State<TodoRiwayatPage> createState() => _TodoRiwayatPageState();
}

class _TodoRiwayatPageState extends State<TodoRiwayatPage> {
  static const Color primaryTerracotta = Color(0xFFBA5A3A);
  static const Color accentCompleted = Color(0xFF2E7D32);

  static const String _prefsKey = 'daily_apps_todo_groups_v1';

  List<TodoDateGroup> _allGroups = [];
  final Set<String> _collapsedGroupIds = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_prefsKey);
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
      final String encoded = jsonEncode(
        _allGroups.map((group) => group.toJson()).toList(),
      );
      await prefs.setString(_prefsKey, encoded);
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

  /// Hapus Riwayat Section
  Future<void> _deleteCompletedSection(TodoDateGroup group) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 24),
              SizedBox(width: 10),
              Text(
                'Hapus Riwayat?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          content: Text(
            'Hapus permanen riwayat to-do pada tanggal "${group.formattedFullDate}"?',
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Riwayat to-do berhasil dihapus'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  /// Bersihkan Semua Riwayat Arsip Selesai
  Future<void> _clearAllCompleted() async {
    if (_archivedGroups.isEmpty) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
              SizedBox(width: 10),
              Text(
                'Hapus Semua Riwayat?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          content: const Text(
            'Apakah kamu yakin ingin menghapus seluruh riwayat section to-do yang sudah diarsipkan?',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
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

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F6),
      appBar: AppBar(
        backgroundColor: primaryTerracotta,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Riwayat Task',
              style: TextStyle(
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
          ? const Center(
              child: CircularProgressIndicator(color: primaryTerracotta),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: primaryTerracotta,
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: accentCompleted.withValues(alpha: 0.28),
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
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'ARCHIVED SECTIONS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.archive_rounded,
                                color: Colors.white,
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
                            'Daftar section to-do yang telah diselesaikan dan kamu arsipkan.',
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
                              ),
                              const SizedBox(width: 10),
                              _buildStatBadge(
                                '$_totalCompletedTasks Tugas',
                                Icons.task_alt_rounded,
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
                      decoration: InputDecoration(
                        hintText: 'Cari riwayat tugas atau tanggal...',
                        hintStyle:
                            TextStyle(color: Colors.grey[400], fontSize: 13.5),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: accentCompleted,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: accentCompleted.withValues(alpha: 0.15),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: accentCompleted,
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

  Widget _buildStatBadge(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentCompleted.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                color: accentCompleted.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: accentCompleted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.done_all_rounded,
                        color: Colors.white,
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
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${group.totalCount} Tugas selesai',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: accentCompleted,
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
                      icon: const Icon(
                        Icons.unarchive_rounded,
                        color: primaryTerracotta,
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
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: accentCompleted,
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
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: group.items[idx].isCompleted
                                        ? accentCompleted
                                        : Colors.grey[400],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    group.items[idx].isCompleted
                                        ? Icons.check_rounded
                                        : Icons.radio_button_unchecked,
                                    color: Colors.white,
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
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF1E293B),
                                      decoration: group.items[idx].isCompleted
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                      decorationColor: const Color(0xFF94A3B8),
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
                                  icon: const Icon(
                                    Icons.undo_rounded,
                                    size: 13,
                                    color: primaryTerracotta,
                                  ),
                                  label: const Text(
                                    'Aktifkan',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: primaryTerracotta,
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
                              color: Colors.grey.withValues(alpha: 0.12),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentCompleted.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
              color: accentCompleted.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.archive_rounded,
              size: 36,
              color: accentCompleted,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Belum Ada Section yang Diarsipkan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Section tanggal yang telah selesai dan kamu pilih untuk "Arsipkan" pada halaman To-Do List akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
