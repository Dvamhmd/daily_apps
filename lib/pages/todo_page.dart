import 'dart:convert';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/pages/todo_riwayat_page.dart';
import 'package:daily_apps/widgets/gta_switch_wheel.dart';
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

  static const String _prefsKey = 'daily_apps_todo_groups_v1';

  List<TodoDateGroup> _dateGroups = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'pending', 'completed'

  @override
  void initState() {
    super.initState();
    _loadTodoData();
  }

  Future<void> _loadTodoData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _dateGroups = decoded
            .map((item) => TodoDateGroup.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        // Data inisial jika baru pertama dibuka
        final now = DateTime.now();
        _dateGroups = [
          TodoDateGroup(
            id: 'init_today',
            date: DateTime(now.year, now.month, now.day),
            items: [
              TodoItem(
                id: 'init_task_1',
                title: 'Review checklist & rencana kerja harian',
                isCompleted: false,
              ),
              TodoItem(
                id: 'init_task_2',
                title: 'Selesaikan laporan harian',
                isCompleted: true,
              ),
            ],
          ),
        ];
        _saveTodoData();
      }
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
    } catch (e) {
      debugPrint('Error saving todos: $e');
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

  int get _totalTasks {
    return _dateGroups.fold(0, (sum, g) => sum + g.totalCount);
  }

  int get _completedTasks {
    return _dateGroups.fold(0, (sum, g) => sum + g.completedCount);
  }

  double get _overallProgress {
    if (_totalTasks == 0) return 0.0;
    return _completedTasks / _totalTasks;
  }

  // --- ACTIONS ---

  /// Dialog Buat To-Do List Baru
  Future<void> _showCreateTodoListDialog() async {
    DateTime selectedDate = DateTime.now();
    final taskController = TextEditingController();

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

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                          color: Colors.grey[300],
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
                            color: primaryTerracotta.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.playlist_add_rounded,
                            color: primaryTerracotta,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Buat To-Do List Baru',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Pilih tanggal untuk membuat list section baru',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF64748B),
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
                                colorScheme: const ColorScheme.light(
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
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryTerracotta.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event_available_rounded,
                              color: primaryTerracotta,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tanggal To-Do List',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    TodoDateGroup(
                                      id: '',
                                      date: selectedDate,
                                    ).formattedFullDate,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
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
                                  color:
                                      primaryTerracotta.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Hari Ini',
                                  style: TextStyle(
                                    color: primaryTerracotta,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.edit_calendar_rounded,
                              color: primaryTerracotta,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Tugas Pertama (Opsional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: taskController,
                      autofocus: false,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Rapat koordinasi proyek...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13.5,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.25),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: primaryTerracotta,
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
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                            child: const Text(
                              'Batal',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final cleanDate = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                              );
                              final taskTitle = taskController.text.trim();

                              setState(() {
                                final existingIndex = _dateGroups.indexWhere(
                                  (g) =>
                                      g.date.year == cleanDate.year &&
                                      g.date.month == cleanDate.month &&
                                      g.date.day == cleanDate.day,
                                );

                                if (existingIndex != -1) {
                                  if (taskTitle.isNotEmpty) {
                                    _dateGroups[existingIndex].items.add(
                                      TodoItem(
                                        id: DateTime.now()
                                            .microsecondsSinceEpoch
                                            .toString(),
                                        title: taskTitle,
                                        isCompleted: false,
                                      ),
                                    );
                                  }
                                } else {
                                  final newGroup = TodoDateGroup(
                                    id: DateTime.now()
                                        .microsecondsSinceEpoch
                                        .toString(),
                                    date: cleanDate,
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
                                  // Masukkan di urutan pertama
                                  _dateGroups.insert(0, newGroup);
                                }
                              });

                              _saveTodoData();
                              Navigator.pop(context);
                              HapticFeedback.mediumImpact();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'To-Do List baru berhasil dibuat!',
                                  ),
                                  backgroundColor: primaryTerracotta,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryTerracotta,
                              foregroundColor: Colors.white,
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

  /// Tambah Kerjaan Baru ke Section Tanggal
  Future<void> _showAddTaskDialog(TodoDateGroup group) async {
    final taskController = TextEditingController();

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
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                      color: Colors.grey[300],
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
                        color: primaryTerracotta.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.add_task_rounded,
                        color: primaryTerracotta,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tambah Kerjaan Baru',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            group.formattedFullDate,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: primaryTerracotta,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tugas / Pekerjaan yang Harus Dikerjakan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: taskController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Ketik apa tugas kamu...',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.25),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: primaryTerracotta,
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
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        child: const Text(
                          'Batal',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final text = taskController.text.trim();
                          if (text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tolong isi nama tugas!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                            return;
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
                          });

                          _saveTodoData();
                          Navigator.pop(context);
                          HapticFeedback.lightImpact();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTerracotta,
                          foregroundColor: Colors.white,
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

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Edit Tugas',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Nama tugas...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: primaryTerracotta,
                  width: 1.8,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
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
                backgroundColor: primaryTerracotta,
                foregroundColor: Colors.white,
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

  void _toggleTask(TodoItem item) {
    HapticFeedback.selectionClick();
    setState(() {
      item.isCompleted = !item.isCompleted;
    });
    _saveTodoData();
  }

  void _deleteTask(TodoDateGroup group, TodoItem item) {
    setState(() {
      group.items.removeWhere((i) => i.id == item.id);
    });
    _saveTodoData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Tugas berhasil dihapus'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _confirmDeleteGroup(TodoDateGroup group) async {
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
                'Hapus Section?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          content: Text(
            'Apakah kamu yakin ingin menghapus section "${group.formattedFullDate}" beserta seluruh ${group.totalCount} tugas di dalamnya?',
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
        _dateGroups.removeWhere((g) => g.id == group.id);
      });
      _saveTodoData();
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
      }
    });
    _saveTodoData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Semua tugas berhasil ditandai selesai! 🎉'),
        backgroundColor: accentCompleted,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  List<TodoDateGroup> get _filteredGroups {
    return _dateGroups.where((group) {
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
        return group.items.any((item) => !item.isCompleted);
      } else if (_selectedFilter == 'completed') {
        return group.items.any((item) => item.isCompleted);
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredGroups;

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
            Icon(Icons.checklist_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'To-Do List',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: 'Riwayat To-Do Selesai',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const TodoRiwayatPage()),
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
          ? const Center(
              child: CircularProgressIndicator(color: primaryTerracotta),
            )
          : RefreshIndicator(
              onRefresh: _loadTodoData,
              color: primaryTerracotta,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderBanner(),
                          const SizedBox(height: 18),
                          _buildSearchAndFilterBar(),
                          const SizedBox(height: 20),

                          // Section Title
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Daftar Rencana & Tugas',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryTerracotta
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_dateGroups.length} Hari',
                                      style: const TextStyle(
                                        color: primaryTerracotta,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (filtered.length > 1)
                                const Row(
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

                          const SizedBox(height: 12),
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
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: primaryTerracotta.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryTerracotta.withValues(alpha: 0.06),
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
                    color: primaryTerracotta.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: primaryTerracotta,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Buat Section / Tanggal Baru',
                  style: TextStyle(
                    color: primaryTerracotta,
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
                  'AGENDA & CHECKLIST',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.task_alt_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$_completedTasks/$_totalTasks Selesai',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
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
          Text(
            'Kelola pekerjaan terstruktur per tanggal untuk produktivitas yang rapi dan terpantau.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
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
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
          decoration: InputDecoration(
            hintText: 'Cari tugas atau tanggal...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13.5),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: primaryTerracotta,
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: primaryTerracotta.withValues(alpha: 0.15),
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
                color: primaryTerracotta,
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
          color: isSelected ? primaryTerracotta : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primaryTerracotta
                : Colors.grey.withValues(alpha: 0.2),
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: primaryTerracotta.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // --- SECTION TANGGAL (DATE GROUP CARD DENGAN DRAG HANDLE) ---
  Widget _buildDateGroupSection(TodoDateGroup group, int index) {
    final itemsToShow = group.items.where((item) {
      if (_selectedFilter == 'pending') return !item.isCompleted;
      if (_selectedFilter == 'completed') return item.isCompleted;
      return true;
    }).toList();

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: group.isToday
              ? primaryTerracotta.withValues(alpha: 0.4)
              : Colors.black.withValues(alpha: 0.06),
          width: group.isToday ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
            // Header Tanggal Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: group.isToday
                    ? primaryTerracotta.withValues(alpha: 0.07)
                    : const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.12),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Dedicated Drag Handle Icon
                  ReorderableDragStartListener(
                    index: index,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      color: Colors.transparent,
                      child: const Icon(
                        Icons.drag_indicator_rounded,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Icon Kalender / Date Indicator
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: group.isToday
                          ? primaryTerracotta
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.event_note_rounded,
                      color: group.isToday
                          ? Colors.white
                          : const Color(0xFF475569),
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
                            Text(
                              group.formattedFullDate,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: group.isToday
                                    ? primaryTerracotta
                                    : const Color(0xFF1E293B),
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
                                  color: group.isToday
                                      ? primaryTerracotta.withValues(alpha: 0.15)
                                      : Colors.grey.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  group.relativeDateLabel,
                                  style: TextStyle(
                                    color: group.isToday
                                        ? primaryTerracotta
                                        : const Color(0xFF475569),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${group.completedCount}/${group.totalCount} Tugas selesai',
                          style: TextStyle(
                            fontSize: 11,
                            color: group.isAllCompleted
                                ? accentCompleted
                                : const Color(0xFF64748B),
                            fontWeight: group.isAllCompleted
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Menu Titik Tiga
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (val) {
                      if (val == 'add') {
                        _showAddTaskDialog(group);
                      } else if (val == 'complete_all') {
                        setState(() {
                          for (final i in group.items) {
                            i.isCompleted = true;
                          }
                        });
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
                      const PopupMenuItem(
                        value: 'add',
                        child: Row(
                          children: [
                            Icon(Icons.add_rounded,
                                size: 18, color: primaryTerracotta),
                            SizedBox(width: 8),
                            Text('Tambah Tugas', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'complete_all',
                        child: Row(
                          children: [
                            Icon(Icons.done_all_rounded,
                                size: 18, color: accentCompleted),
                            SizedBox(width: 8),
                            Text('Tandai Semua Selesai',
                                style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'clear_completed',
                        child: Row(
                          children: [
                            Icon(Icons.cleaning_services_rounded,
                                size: 18, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Hapus Tugas Selesai',
                                style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete_section',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Hapus Section Ini',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (group.totalCount > 0)
              ClipRRect(
                child: LinearProgressIndicator(
                  value: group.progress,
                  minHeight: 2.5,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    group.isAllCompleted ? accentCompleted : primaryTerracotta,
                  ),
                ),
              ),

            if (itemsToShow.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Center(
                  child: Text(
                    group.items.isEmpty
                        ? 'Belum ada tugas pada tanggal ini'
                        : 'Tidak ada tugas yang sesuai filter',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: itemsToShow.length,
                separatorBuilder: (ctx, idx) => Divider(
                  height: 1,
                  thickness: 0.6,
                  color: Colors.grey.withValues(alpha: 0.12),
                  indent: 52,
                ),
                itemBuilder: (ctx, idx) {
                  final item = itemsToShow[idx];
                  return _buildTaskItemTile(group, item);
                },
              ),

            // Tombol + Tambah Kerjaan pada section ini
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: InkWell(
                onTap: () => _showAddTaskDialog(group),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: primaryTerracotta.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryTerracotta.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_rounded,
                        size: 18,
                        color: primaryTerracotta,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Tambah Kerjaan',
                        style: TextStyle(
                          color: primaryTerracotta,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
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
    ),
  );
}

  // --- TASK ITEM TILE DENGAN CHECKBOX & NAMA TUGAS ---
  Widget _buildTaskItemTile(TodoDateGroup group, TodoItem item) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        color: Colors.red[600],
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 20),
      ),
      onDismissed: (_) => _deleteTask(group, item),
      child: InkWell(
        onTap: () => _toggleTask(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _toggleTask(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: item.isCompleted ? accentCompleted : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: item.isCompleted
                          ? accentCompleted
                          : const Color(0xFFCBD5E1),
                      width: 2.0,
                    ),
                    boxShadow: item.isCompleted
                        ? [
                            BoxShadow(
                              color: accentCompleted.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: item.isCompleted
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    color: item.isCompleted
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF1E293B),
                    fontWeight:
                        item.isCompleted ? FontWeight.w400 : FontWeight.w500,
                    decoration: item.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: const Color(0xFF94A3B8),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 17,
                  color: Color(0xFF94A3B8),
                ),
                tooltip: 'Edit Tugas',
                onPressed: () => _showEditTaskDialog(item),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 17,
                  color: Color(0xFFCBD5E1),
                ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryTerracotta.withValues(alpha: 0.15),
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
              color: primaryTerracotta.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              size: 36,
              color: primaryTerracotta,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Tidak Ada List Tugas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
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
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showCreateTodoListDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryTerracotta,
              foregroundColor: Colors.white,
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
              '+ Buat To-Do List Baru',
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
