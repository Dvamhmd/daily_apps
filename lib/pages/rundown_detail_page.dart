import 'package:daily_apps/models/model_rundown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class RundownDetailPage extends StatefulWidget {
  final Rundown rundown;
  final Function(Rundown updatedRundown)? onRundownChanged;
  final VoidCallback? onRundownDeleted;

  const RundownDetailPage({
    super.key,
    required this.rundown,
    this.onRundownChanged,
    this.onRundownDeleted,
  });

  @override
  State<RundownDetailPage> createState() => _RundownDetailPageState();
}

class _RundownDetailPageState extends State<RundownDetailPage> {
  static const Color primaryTeal = Color(0xFF00897B);
  static const Color lightTealBg = Color(0xFFF0FDF4);

  late Rundown _rundown;
  int _selectedDayIndex = 0;

  // Set of selected row indices for the active day
  final Set<int> _selectedRowIndices = {};

  // Auto cascade time: if true, editing a row's start time or duration automatically updates next rows' start times
  bool _autoCascadeTime = true;

  @override
  void initState() {
    super.initState();
    _rundown = widget.rundown;
    _ensureDefaultRows();
  }

  void _ensureDefaultRows() {
    bool changed = false;
    final updatedDays = _rundown.days.map((day) {
      if (day.rows.isEmpty) {
        changed = true;
        return RundownDay.createWithDefaultRows(
          dayNumber: day.dayNumber,
          date: day.date,
          theme: day.theme,
          initialRowCount: 5,
        );
      }
      return day;
    }).toList();

    if (changed) {
      _rundown = _rundown.copyWith(days: updatedDays);
      widget.onRundownChanged?.call(_rundown);
    }
  }

  String _formatDateShort(DateTime date) {
    try {
      return DateFormat('d MMM yyyy').format(date);
    } catch (_) {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatDateFull(DateTime date) {
    try {
      return DateFormat('EEEE, d MMMM yyyy').format(date);
    } catch (_) {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _notifyChange() {
    widget.onRundownChanged?.call(_rundown);
  }

  // --- RECALCULATE CHAINED TIMES ---
  void _recalculateDayTimes(int dayIndex, {int fromRowIndex = 0}) {
    final day = _rundown.days[dayIndex];
    if (day.rows.isEmpty) return;

    final newRows = List<RundownTableRow>.from(day.rows);

    if (fromRowIndex == 0 && newRows.first.startTime.isEmpty) {
      newRows.first.startTime = '08:00';
    }

    if (_autoCascadeTime) {
      for (int i = fromRowIndex; i < newRows.length; i++) {
        if (i > 0) {
          // Waktu mulai baris ini = Waktu berhenti baris sebelumnya
          final prevEnd = newRows[i - 1].endTime;
          if (prevEnd.isNotEmpty) {
            newRows[i].startTime = prevEnd;
          }
        }
      }
    }

    final updatedDay = day.copyWith(rows: newRows);
    final updatedDays = List<RundownDay>.from(_rundown.days);
    updatedDays[dayIndex] = updatedDay;

    setState(() {
      _rundown = _rundown.copyWith(days: updatedDays);
    });
    _notifyChange();
  }

  // --- ROW OPERATIONS ---

  void _addRow() {
    final activeDay = _rundown.days[_selectedDayIndex];
    final countToAdd =
        _selectedRowIndices.isNotEmpty ? _selectedRowIndices.length : 1;

    final newRows = List<RundownTableRow>.from(activeDay.rows);

    // Determine insert position
    int insertIndex = newRows.length;
    if (_selectedRowIndices.isNotEmpty) {
      insertIndex = _selectedRowIndices.reduce((a, b) => a > b ? a : b) + 1;
      if (insertIndex > newRows.length) insertIndex = newRows.length;
    }

    // Determine previous endTime for initial start time
    String prevEnd = '08:00';
    if (insertIndex > 0 && insertIndex - 1 < newRows.length) {
      prevEnd = newRows[insertIndex - 1].endTime;
      if (prevEnd.isEmpty) prevEnd = '08:00';
    } else if (newRows.isNotEmpty) {
      prevEnd = newRows.last.endTime;
      if (prevEnd.isEmpty) prevEnd = '08:00';
    }

    for (int i = 0; i < countToAdd; i++) {
      final newRow = RundownTableRow(
        id: '${DateTime.now().microsecondsSinceEpoch}_$i',
        startTime: prevEnd,
        durationMinutes: 30,
      );
      newRows.insert(insertIndex + i, newRow);
      prevEnd = newRow.endTime;
    }

    final updatedDay = activeDay.copyWith(rows: newRows);
    final updatedDays = List<RundownDay>.from(_rundown.days);
    updatedDays[_selectedDayIndex] = updatedDay;

    setState(() {
      _rundown = _rundown.copyWith(days: updatedDays);
      _selectedRowIndices.clear();
    });

    if (_autoCascadeTime) {
      _recalculateDayTimes(_selectedDayIndex, fromRowIndex: insertIndex);
    } else {
      _notifyChange();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '$countToAdd baris baru ditambahkan (Waktu mulai terhubung otomatis)!'),
        backgroundColor: primaryTeal,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _deleteSelectedRows() {
    final activeDay = _rundown.days[_selectedDayIndex];
    if (_selectedRowIndices.isEmpty) {
      if (activeDay.rows.isEmpty) return;
      final newRows = List<RundownTableRow>.from(activeDay.rows)..removeLast();
      final updatedDay = activeDay.copyWith(rows: newRows);
      final updatedDays = List<RundownDay>.from(_rundown.days);
      updatedDays[_selectedDayIndex] = updatedDay;

      setState(() {
        _rundown = _rundown.copyWith(days: updatedDays);
      });
      _notifyChange();
      return;
    }

    final deleteCount = _selectedRowIndices.length;
    final sortedIndices = _selectedRowIndices.toList()
      ..sort((a, b) => b.compareTo(a));

    final newRows = List<RundownTableRow>.from(activeDay.rows);
    final minIndex = sortedIndices.last;

    for (final idx in sortedIndices) {
      if (idx >= 0 && idx < newRows.length) {
        newRows.removeAt(idx);
      }
    }

    final updatedDay = activeDay.copyWith(rows: newRows);
    final updatedDays = List<RundownDay>.from(_rundown.days);
    updatedDays[_selectedDayIndex] = updatedDay;

    setState(() {
      _rundown = _rundown.copyWith(days: updatedDays);
      _selectedRowIndices.clear();
    });

    if (_autoCascadeTime && minIndex < newRows.length) {
      _recalculateDayTimes(_selectedDayIndex, fromRowIndex: minIndex);
    } else {
      _notifyChange();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$deleteCount baris berhasil dihapus!'),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- DURATION EDITING ---

  Future<void> _editRowDuration(int rowIndex) async {
    final activeDay = _rundown.days[_selectedDayIndex];
    final row = activeDay.rows[rowIndex];
    final currentDuration = row.durationMinutes;

    final customCtrl = TextEditingController(text: currentDuration.toString());

    final selectedDuration = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: primaryTeal),
                    const SizedBox(width: 8),
                    Text(
                      'Atur Durasi (Baris ${rowIndex + 1})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Waktu Mulai: ${row.startTime.isNotEmpty ? row.startTime : "08:00"}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),

                // Quick Preset Chips
                const Text(
                  'Pilihan Cepat (Menit):',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [15, 30, 45, 60, 90, 120, 180].map((mins) {
                    final isSel = mins == currentDuration;
                    return ChoiceChip(
                      label: Text(
                        mins >= 60 && mins % 60 == 0
                            ? '${mins ~/ 60} Jam'
                            : '$mins Mnt',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSel ? FontWeight.bold : FontWeight.w500,
                          color: isSel ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                      selected: isSel,
                      selectedColor: primaryTeal,
                      backgroundColor: const Color(0xFFF1F5F9),
                      onSelected: (_) => Navigator.of(ctx).pop(mins),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),

                // Custom Input
                const Text(
                  'Atau Masukkan Menit Kustom:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: customCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          hintText: 'Contoh: 25',
                          suffixText: 'Menit',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        final val = int.tryParse(customCtrl.text.trim());
                        if (val != null && val > 0) {
                          Navigator.of(ctx).pop(val);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                      child: const Text('Terapkan',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (selectedDuration != null && selectedDuration > 0) {
      final updatedRows = List<RundownTableRow>.from(activeDay.rows);
      updatedRows[rowIndex].durationMinutes = selectedDuration;

      final updatedDay = activeDay.copyWith(rows: updatedRows);
      final updatedDays = List<RundownDay>.from(_rundown.days);
      updatedDays[_selectedDayIndex] = updatedDay;

      setState(() {
        _rundown = _rundown.copyWith(days: updatedDays);
      });

      if (_autoCascadeTime) {
        _recalculateDayTimes(_selectedDayIndex, fromRowIndex: rowIndex);
      } else {
        _notifyChange();
      }
    }
  }

  // --- TIME PICKING IN ROW ---

  Future<void> _pickRowStartTime(int rowIndex) async {
    final activeDay = _rundown.days[_selectedDayIndex];
    final row = activeDay.rows[rowIndex];

    TimeOfDay initial = const TimeOfDay(hour: 8, minute: 0);
    try {
      final parts = row.startTime.split(':').map(int.parse).toList();
      if (parts.length == 2) {
        initial = TimeOfDay(hour: parts[0], minute: parts[1]);
      }
    } catch (_) {}

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryTeal,
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';

      final updatedRows = List<RundownTableRow>.from(activeDay.rows);
      updatedRows[rowIndex].startTime = formatted;

      final updatedDay = activeDay.copyWith(rows: updatedRows);
      final updatedDays = List<RundownDay>.from(_rundown.days);
      updatedDays[_selectedDayIndex] = updatedDay;

      setState(() {
        _rundown = _rundown.copyWith(days: updatedDays);
      });

      if (_autoCascadeTime) {
        _recalculateDayTimes(_selectedDayIndex, fromRowIndex: rowIndex);
      } else {
        _notifyChange();
      }
    }
  }

  // --- COLUMN OPERATIONS ---

  Future<void> _addNewColumn() async {
    final colNameCtrl = TextEditingController();
    final colName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Tambah Kolom Baru',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan nama kolom baru yang ingin ditambahkan ke tabel:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: colNameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Contoh: Keterangan, Dresscode, Alat, dll.',
                hintStyle:
                    const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryTeal, width: 1.8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child:
                const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              final name = colNameCtrl.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(ctx).pop(name);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );

    if (colName != null && colName.isNotEmpty) {
      final activeDay = _rundown.days[_selectedDayIndex];
      if (activeDay.customColumns.contains(colName)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kolom "$colName" sudah ada!'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final updatedCols = List<String>.from(activeDay.customColumns)
        ..add(colName);
      final updatedDay = activeDay.copyWith(customColumns: updatedCols);
      final updatedDays = List<RundownDay>.from(_rundown.days);
      updatedDays[_selectedDayIndex] = updatedDay;

      setState(() {
        _rundown = _rundown.copyWith(days: updatedDays);
      });
      _notifyChange();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kolom "$colName" berhasil ditambahkan!'),
            backgroundColor: primaryTeal,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteCustomColumn(String colName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Hapus Kolom "$colName"?',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Text(
          'Data pada kolom "$colName" di seluruh baris hari ini akan dihapus.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final activeDay = _rundown.days[_selectedDayIndex];
      final updatedCols = List<String>.from(activeDay.customColumns)
        ..remove(colName);

      final updatedRows = activeDay.rows.map((r) {
        final newMap = Map<String, String>.from(r.customValues)
          ..remove(colName);
        return RundownTableRow(
          id: r.id,
          startTime: r.startTime,
          durationMinutes: r.durationMinutes,
          activity: r.activity,
          location: r.location,
          customValues: newMap,
        );
      }).toList();

      final updatedDay =
          activeDay.copyWith(customColumns: updatedCols, rows: updatedRows);
      final updatedDays = List<RundownDay>.from(_rundown.days);
      updatedDays[_selectedDayIndex] = updatedDay;

      setState(() {
        _rundown = _rundown.copyWith(days: updatedDays);
      });
      _notifyChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeDay = (_selectedDayIndex < _rundown.days.length)
        ? _rundown.days[_selectedDayIndex]
        : null;

    return Scaffold(
      backgroundColor: lightTealBg,
      appBar: AppBar(
        backgroundColor: primaryTeal,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _rundown.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_column_rounded, color: Colors.white),
            tooltip: 'Tambah Kolom',
            onPressed: _addNewColumn,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Banner Info
            _buildHeaderBanner(),

            const SizedBox(height: 16),

            // 2. Day Selector Tabs
            _buildDaySelectorSection(),

            const SizedBox(height: 16),

            // 3. Theme Header & Auto Cascade Switch
            if (activeDay != null) ...[
              _buildDayThemeHeader(activeDay),
              const SizedBox(height: 12),

              // 4. Table Toolbar (Select All, Add Row, Delete Row, Add Column)
              _buildTableToolbar(activeDay),

              const SizedBox(height: 10),

              // 5. Interactive Editable Table
              _buildInteractiveTable(activeDay),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00897B), Color(0xFF004D40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00897B).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'TABEL RUNDOWN OTOMATIS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_rundown.totalDays} Hari',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _rundown.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatDateShort(_rundown.startDate)} s/d ${_formatDateShort(_rundown.endDate)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelectorSection() {
    return SizedBox(
      height: 58,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _rundown.days.length,
        itemBuilder: (context, index) {
          final day = _rundown.days[index];
          final isSelected = index == _selectedDayIndex;
          String dayDateStr;
          try {
            dayDateStr = DateFormat('d MMM').format(day.date);
          } catch (_) {
            dayDateStr = '${day.date.day}/${day.date.month}';
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedDayIndex = index;
                  _selectedRowIndices.clear();
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? primaryTeal : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? primaryTeal : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.6 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primaryTeal.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'DAY ${day.dayNumber}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      dayDateStr,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.9)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayThemeHeader(RundownDay activeDay) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00897B).withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_rounded, color: primaryTeal, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tema: ${activeDay.theme.isNotEmpty ? activeDay.theme : "Hari Ke-${activeDay.dayNumber}"} • ${_formatDateFull(activeDay.date)}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _autoCascadeTime = !_autoCascadeTime;
              });
              if (_autoCascadeTime) {
                _recalculateDayTimes(_selectedDayIndex);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _autoCascadeTime
                    ? primaryTeal.withValues(alpha: 0.12)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _autoCascadeTime
                        ? Icons.link_rounded
                        : Icons.link_off_rounded,
                    size: 14,
                    color: _autoCascadeTime
                        ? primaryTeal
                        : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _autoCascadeTime ? 'Auto Sambung' : 'Manual',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: _autoCascadeTime
                          ? primaryTeal
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableToolbar(RundownDay activeDay) {
    final allSelected = activeDay.rows.isNotEmpty &&
        _selectedRowIndices.length == activeDay.rows.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Select All Checkbox
          InkWell(
            onTap: () {
              setState(() {
                if (allSelected) {
                  _selectedRowIndices.clear();
                } else {
                  _selectedRowIndices.clear();
                  for (int i = 0; i < activeDay.rows.length; i++) {
                    _selectedRowIndices.add(i);
                  }
                }
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  allSelected
                      ? Icons.check_box_rounded
                      : _selectedRowIndices.isNotEmpty
                          ? Icons.indeterminate_check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                  color: _selectedRowIndices.isNotEmpty
                      ? primaryTeal
                      : const Color(0xFF94A3B8),
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  _selectedRowIndices.isNotEmpty
                      ? '${_selectedRowIndices.length} dipilih'
                      : 'Pilih',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _selectedRowIndices.isNotEmpty
                        ? primaryTeal
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Tambah Baris Button
          ElevatedButton.icon(
            onPressed: _addRow,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(
              _selectedRowIndices.isNotEmpty
                  ? '+ ${_selectedRowIndices.length} Baris'
                  : '+ Baris',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 6),

          // Hapus Baris Button
          ElevatedButton.icon(
            onPressed:
                activeDay.rows.isNotEmpty ? _deleteSelectedRows : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedRowIndices.isNotEmpty
                  ? Colors.redAccent
                  : const Color(0xFFF1F5F9),
              foregroundColor: _selectedRowIndices.isNotEmpty
                  ? Colors.white
                  : const Color(0xFF64748B),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: Icon(Icons.delete_outline_rounded,
                size: 16,
                color: _selectedRowIndices.isNotEmpty
                    ? Colors.white
                    : const Color(0xFF64748B)),
            label: Text(
              _selectedRowIndices.isNotEmpty
                  ? 'Hapus (${_selectedRowIndices.length})'
                  : 'Hapus',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 6),

          // Tambah Kolom Button
          OutlinedButton.icon(
            onPressed: _addNewColumn,
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryTeal,
              side: const BorderSide(color: primaryTeal, width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.view_column_rounded, size: 16),
            label: const Text(
              '+ Kolom',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveTable(RundownDay activeDay) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00897B).withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TABLE HEADER
              _buildTableHeader(activeDay),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // TABLE BODY ROWS
              if (activeDay.rows.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  alignment: Alignment.center,
                  child: const Text(
                    'Tidak ada baris di tabel. Klik "+ Baris" untuk menambah.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  ),
                )
              else
                ...List.generate(activeDay.rows.length, (index) {
                  final row = activeDay.rows[index];
                  final isSelected = _selectedRowIndices.contains(index);
                  return _buildTableRow(activeDay, row, index, isSelected);
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(RundownDay activeDay) {
    return Container(
      color: primaryTeal.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          // Select Checkbox / No column
          const SizedBox(
            width: 44,
            child: Text(
              'No',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: primaryTeal,
              ),
            ),
          ),

          // 1. WAKTU MULAI
          const SizedBox(
            width: 95,
            child: Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: primaryTeal),
                SizedBox(width: 4),
                Text(
                  'Mulai',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),

          // 2. DURASI
          const SizedBox(
            width: 105,
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 14, color: primaryTeal),
                SizedBox(width: 4),
                Text(
                  'Durasi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),

          // 3. WAKTU SELESAI (OTOMATIS)
          const SizedBox(
            width: 105,
            child: Row(
              children: [
                Icon(Icons.flag_rounded, size: 14, color: primaryTeal),
                SizedBox(width: 4),
                Text(
                  'Selesai (Otomatis)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),

          // 4. KEGIATAN
          const SizedBox(
            width: 200,
            child: Row(
              children: [
                Icon(Icons.event_note_rounded, size: 14, color: primaryTeal),
                SizedBox(width: 4),
                Text(
                  'Kegiatan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),

          // 5. LOKASI
          const SizedBox(
            width: 150,
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, size: 14, color: primaryTeal),
                SizedBox(width: 4),
                Text(
                  'Lokasi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),

          // 6. CUSTOM COLUMNS (e.g. Keterangan, etc.)
          ...activeDay.customColumns.map((colName) {
            return SizedBox(
              width: 160,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      colName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => _deleteCustomColumn(colName),
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(Icons.close_rounded,
                          size: 14, color: Colors.redAccent),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTableRow(
    RundownDay activeDay,
    RundownTableRow row,
    int index,
    bool isSelected,
  ) {
    final isEven = index % 2 == 0;
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? primaryTeal.withValues(alpha: 0.12)
            : (isEven ? Colors.white : const Color(0xFFFBFDFA)),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          // Select Checkbox & Number
          SizedBox(
            width: 44,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedRowIndices.remove(index);
                  } else {
                    _selectedRowIndices.add(index);
                  }
                });
              },
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 17,
                    color: isSelected ? primaryTeal : const Color(0xFFCBD5E1),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? primaryTeal
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 1. WAKTU MULAI
          SizedBox(
            width: 95,
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () => _pickRowStartTime(index),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: row.startTime.isNotEmpty
                        ? primaryTeal.withValues(alpha: 0.1)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: row.startTime.isNotEmpty
                          ? primaryTeal.withValues(alpha: 0.3)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 13,
                          color: row.startTime.isNotEmpty
                              ? primaryTeal
                              : const Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        row.startTime.isNotEmpty ? row.startTime : '--:--',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: row.startTime.isNotEmpty
                              ? primaryTeal
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. DURASI (Klik untuk atur durasi)
          SizedBox(
            width: 105,
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () => _editRowDuration(index),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        row.durationText,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down_rounded,
                          size: 16, color: primaryTeal),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. WAKTU SELESAI (OTOMATIS)
          SizedBox(
            width: 105,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: row.endTime.isNotEmpty
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: row.endTime.isNotEmpty
                        ? primaryTeal.withValues(alpha: 0.25)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 12,
                        color: row.endTime.isNotEmpty
                            ? primaryTeal
                            : const Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      row.endTime.isNotEmpty ? row.endTime : '--:--',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: row.endTime.isNotEmpty
                            ? const Color(0xFF004D40)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. KEGIATAN (Inline Text Input)
          SizedBox(
            width: 200,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextFormField(
                initialValue: row.activity,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
                decoration: const InputDecoration(
                  hintText: 'Nama kegiatan...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFCBD5E1),
                    fontWeight: FontWeight.normal,
                  ),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  row.activity = val;
                  _notifyChange();
                },
              ),
            ),
          ),

          // 5. LOKASI (Inline Text Input)
          SizedBox(
            width: 150,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextFormField(
                initialValue: row.location,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155),
                ),
                decoration: const InputDecoration(
                  hintText: 'Ruangan / Tempat...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFCBD5E1),
                  ),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  row.location = val;
                  _notifyChange();
                },
              ),
            ),
          ),

          // 6. CUSTOM COLUMNS
          ...activeDay.customColumns.map((colName) {
            final val = row.customValues[colName] ?? '';
            return SizedBox(
              width: 160,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextFormField(
                  initialValue: val,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF334155),
                  ),
                  decoration: InputDecoration(
                    hintText: '$colName...',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFCBD5E1),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    border: InputBorder.none,
                  ),
                  onChanged: (newVal) {
                    row.customValues[colName] = newVal;
                    _notifyChange();
                  },
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
