import 'dart:convert';
import 'package:daily_apps/models/model_todo.dart';
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

  // Section yang sudah 100% selesai (ada tugas dan semua tugas selesai)
  List<TodoDateGroup> get _completedGroups {
    final completed = _allGroups.where((group) {
      return group.items.isNotEmpty && group.isAllCompleted;
    }).toList();

    // Urutkan dari tanggal terbaru
    completed.sort((a, b) => b.date.compareTo(a.date));

    if (_searchQuery.isEmpty) return completed;

    final query = _searchQuery.toLowerCase();
    return completed.where((group) {
      final matchesDate = group.formattedFullDate.toLowerCase().contains(query);
      final matchesTask = group.items.any(
        (item) => item.title.toLowerCase().contains(query),
      );
      return matchesDate || matchesTask;
    }).toList();
  }

  int get _totalCompletedTasks {
    return _completedGroups.fold(0, (sum, g) => sum + g.completedCount);
  }

  /// Aktifkan kembali / batalkan checklist tugas
  void _uncompleteTask(TodoDateGroup group, TodoItem item) {
    HapticFeedback.selectionClick();
    setState(() {
      item.isCompleted = false;
    });
    _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tugas "${item.title}" dipindahkan ke daftar aktif'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              item.isCompleted = true;
            });
            _saveData();
          },
        ),
      ),
    );
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

  /// Bersihkan Semua Riwayat Selesai
  Future<void> _clearAllCompleted() async {
    if (_completedGroups.isEmpty) return;

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
            'Apakah kamu yakin ingin menghapus seluruh riwayat section to-do yang sudah selesai?',
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
        _allGroups.removeWhere((g) => g.items.isNotEmpty && g.isAllCompleted);
      });
      _saveData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedList = _completedGroups;

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
              'Riwayat To-Do Selesai',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17.5,
              ),
            ),
          ],
        ),
        actions: [
          if (completedList.isNotEmpty)
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
                                'ARCHIVE & COMPLETION',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Pekerjaan yang Telah Tuntas',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Semua section to-do yang telah berhasil kamu selesaikan 100%.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildStatBadge(
                              '${completedList.length} Section',
                              Icons.calendar_today_rounded,
                            ),
                            const SizedBox(width: 10),
                            _buildStatBadge(
                              '$_totalCompletedTasks Tugas Selesai',
                              Icons.task_alt_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Search Field
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
                  if (completedList.isEmpty)
                    _buildEmptyRiwayat()
                  else
                    ...completedList.map(
                      (group) => _buildCompletedGroupCard(group),
                    ),

                  const SizedBox(height: 40),
                ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            // Header Section Selesai
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        Text(
                          '${group.completedCount} tugas telah tuntas',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: accentCompleted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    tooltip: 'Hapus Riwayat Ini',
                    onPressed: () => _deleteCompletedSection(group),
                  ),
                ],
              ),
            ),

            // Daftar Tugas
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: group.items.length,
              separatorBuilder: (ctx, idx) => Divider(
                height: 1,
                thickness: 0.6,
                color: Colors.grey.withValues(alpha: 0.12),
                indent: 52,
              ),
              itemBuilder: (ctx, idx) {
                final item = group.items[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: accentCompleted,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF64748B),
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _uncompleteTask(group, item),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(
                          Icons.undo_rounded,
                          size: 14,
                          color: primaryTerracotta,
                        ),
                        label: const Text(
                          'Aktifkan',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: primaryTerracotta,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
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
              Icons.history_rounded,
              size: 36,
              color: accentCompleted,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Belum Ada Riwayat Selesai',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Section tanggal yang seluruh tugasnya sudah dichecklist akan tercatat di sini secara otomatis.',
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
