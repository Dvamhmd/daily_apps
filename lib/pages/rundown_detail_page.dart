import 'dart:convert';
import 'package:daily_apps/models/model_rundown.dart';
import 'package:daily_apps/utils/responsive_text.dart';
import 'package:daily_apps/widgets/custom_toast.dart';
import 'package:daily_apps/widgets/dialog_tambah_rundown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';

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

  // Auto cascade time: always active so editing a row's start time or duration automatically updates next rows' start times
  static const bool _autoCascadeTime = true;

  // Horizontal scroll controller for table
  final ScrollController _horizontalScrollController = ScrollController();
  double _currentZoom = 1.0;

  // Mode Kustom Ukuran (Spreadsheet / Excel style interactive drag-to-resize)
  bool _isResizeMode = false;

  // Customizable Column Widths and Row Height
  double _rowHeight = 36.0;
  double _colNoWidth = 36.0;
  double _colMulaiWidth = 74.0;
  double _colSelesaiWidth = 74.0;
  double _colDurasiWidth = 72.0;
  double _colKegiatanWidth = 240.0;
  double _colCustomWidth = 140.0;
  final Map<String, double> _customColWidths = {};

  // Touch pointer tracking for highly responsive and accurate pinch-to-zoom
  final Map<int, Offset> _activePointers = {};
  double? _initialPinchDistance;
  double _pinchStartZoom = 1.0;
  bool _isPinching = false;

  @override
  void initState() {
    super.initState();
    _rundown = widget.rundown;
    _ensureDefaultRows();
    _loadTableSettings();
  }

  double _getColCustomWidth(String colName) {
    return _customColWidths[colName] ?? _colCustomWidth;
  }

  void _toggleResizeMode() {
    setState(() {
      _isResizeMode = !_isResizeMode;
    });
    if (!_isResizeMode) {
      _saveTableSettings();
    }
  }

  Future<void> _loadTableSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final customWidthsJson = prefs.getString('rundown_custom_col_widths');
      if (customWidthsJson != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(customWidthsJson);
          _customColWidths.clear();
          decoded.forEach((k, v) {
            if (v is num) {
              _customColWidths[k] = v.toDouble();
            }
          });
        } catch (_) {}
      }
      setState(() {
        _rowHeight = prefs.getDouble('rundown_row_height') ?? 36.0;
        _colKegiatanWidth =
            prefs.getDouble('rundown_col_kegiatan_width') ?? 240.0;
        _colMulaiWidth = prefs.getDouble('rundown_col_mulai_width') ?? 74.0;
        _colSelesaiWidth = prefs.getDouble('rundown_col_selesai_width') ?? 74.0;
        _colDurasiWidth = prefs.getDouble('rundown_col_durasi_width') ?? 72.0;
        _colCustomWidth = prefs.getDouble('rundown_col_custom_width') ?? 140.0;
        _colNoWidth = prefs.getDouble('rundown_col_no_width') ?? 36.0;
      });
    } catch (_) {}
  }

  Future<void> _saveTableSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('rundown_row_height', _rowHeight);
      await prefs.setDouble('rundown_col_kegiatan_width', _colKegiatanWidth);
      await prefs.setDouble('rundown_col_mulai_width', _colMulaiWidth);
      await prefs.setDouble('rundown_col_selesai_width', _colSelesaiWidth);
      await prefs.setDouble('rundown_col_durasi_width', _colDurasiWidth);
      await prefs.setDouble('rundown_col_custom_width', _colCustomWidth);
      await prefs.setDouble('rundown_col_no_width', _colNoWidth);
      await prefs.setString(
          'rundown_custom_col_widths', jsonEncode(_customColWidths));
    } catch (_) {}
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _activePointers.clear();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.position;
    if (_activePointers.length >= 2) {
      final points = _activePointers.values.toList();
      _initialPinchDistance = (points[0] - points[1]).distance;
      _pinchStartZoom = _currentZoom;
      if (!_isPinching) {
        setState(() {
          _isPinching = true;
        });
      }
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) return;
    _activePointers[event.pointer] = event.position;

    if (_activePointers.length >= 2 &&
        _initialPinchDistance != null &&
        _initialPinchDistance! > 8.0) {
      final points = _activePointers.values.toList();
      final currentDistance = (points[0] - points[1]).distance;
      final scaleFactor = currentDistance / _initialPinchDistance!;
      final newZoom = (_pinchStartZoom * scaleFactor).clamp(0.4, 2.2);

      if ((newZoom - _currentZoom).abs() > 0.003) {
        setState(() {
          _currentZoom = newZoom;
        });
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2) {
      _initialPinchDistance = null;
      if (_isPinching) {
        setState(() {
          _isPinching = false;
        });
      }
    } else if (_activePointers.length == 2) {
      final points = _activePointers.values.toList();
      _initialPinchDistance = (points[0] - points[1]).distance;
      _pinchStartZoom = _currentZoom;
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2) {
      _initialPinchDistance = null;
      if (_isPinching) {
        setState(() {
          _isPinching = false;
        });
      }
    }
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 0.1).clamp(0.4, 2.2);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 0.1).clamp(0.4, 2.2);
    });
  }

  void _resetZoom() {
    setState(() {
      _currentZoom = 1.0;
    });
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

    CustomToast.showSuccess(
      context,
      title: 'Baris Ditambahkan',
      subtitle: '$countToAdd baris baru ditambahkan (Waktu terhubung otomatis)!',
    );
  }

  void _deleteSelectedRows() {
    if (_selectedRowIndices.isEmpty) return;

    final activeDay = _rundown.days[_selectedDayIndex];
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

    CustomToast.showSuccess(
      context,
      title: 'Baris Dihapus',
      subtitle: '$deleteCount baris berhasil dihapus.',
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
        scrollable: true,
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
          CustomToast.showWarning(
            context,
            title: 'Kolom Sudah Ada',
            subtitle: 'Kolom "$colName" sudah ada di daftar.',
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
        CustomToast.showSuccess(
          context,
          title: 'Kolom Ditambahkan',
          subtitle: 'Kolom "$colName" berhasil ditambahkan!',
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

  Future<void> _openEditRundownModal() async {
    final updated = await ModalTambahRundown.show(context, rundown: _rundown);
    if (updated != null) {
      setState(() {
        _rundown = updated;
        if (_selectedDayIndex >= _rundown.days.length) {
          _selectedDayIndex = (_rundown.days.length - 1).clamp(0, 9999);
        }
      });
      _notifyChange();

      if (mounted) {
        CustomToast.showSuccess(
          context,
          title: 'Rundown Diperbarui',
          subtitle: 'Informasi rundown berhasil diperbarui!',
        );
      }
    }
  }

  // --- CUSTOM TABLE DIMENSIONS (ROW HEIGHT & COLUMN WIDTHS) ---

  Future<void> _openTableDimensionsModal() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
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

                    // Header with Reset Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tune_rounded,
                                color: primaryTeal, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Kustom Ukuran Tabel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _rowHeight = 36.0;
                              _colKegiatanWidth = 240.0;
                              _colMulaiWidth = 74.0;
                              _colSelesaiWidth = 74.0;
                              _colDurasiWidth = 72.0;
                              _colCustomWidth = 140.0;
                              _colNoWidth = 36.0;
                            });
                            setModalState(() {});
                            _saveTableSettings();
                          },
                          icon: const Icon(Icons.refresh_rounded,
                              size: 15, color: primaryTeal),
                          label: const Text(
                            'Reset Standar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primaryTeal,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sesuaikan tinggi baris dan lebar kolom agar pas dan nyaman di layar.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),

                    // Scrollable Settings Content
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. TINGGI BARIS SECTION
                            _buildDimensionSliderSection(
                              icon: Icons.table_rows_rounded,
                              title: 'Tinggi Baris (Row Height)',
                              value: _rowHeight,
                              min: 26.0,
                              max: 60.0,
                              unit: 'px',
                              presetOptions: [
                                {'label': 'Kompak', 'value': 30.0},
                                {'label': 'Standar', 'value': 36.0},
                                {'label': 'Nyaman', 'value': 42.0},
                                {'label': 'Luas', 'value': 50.0},
                              ],
                              onChanged: (val) {
                                setState(() => _rowHeight = val);
                                setModalState(() {});
                                _saveTableSettings();
                              },
                            ),

                            const SizedBox(height: 16),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 16),

                            // 2. LEBAR KOLOM KEGIATAN
                            _buildDimensionSliderSection(
                              icon: Icons.event_note_rounded,
                              title: 'Lebar Kolom Kegiatan',
                              value: _colKegiatanWidth,
                              min: 150.0,
                              max: 450.0,
                              unit: 'px',
                              presetOptions: [
                                {'label': 'Ringkas', 'value': 180.0},
                                {'label': 'Standar', 'value': 240.0},
                                {'label': 'Lebar', 'value': 320.0},
                                {'label': 'Maksimal', 'value': 400.0},
                              ],
                              onChanged: (val) {
                                setState(() => _colKegiatanWidth = val);
                                setModalState(() {});
                                _saveTableSettings();
                              },
                            ),

                            const SizedBox(height: 16),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 16),

                            // 3. LEBAR KOLOM WAKTU MULAI & SELESAI
                            _buildDimensionSliderSection(
                              icon: Icons.access_time_rounded,
                              title: 'Lebar Kolom Waktu Mulai & Selesai',
                              value: _colMulaiWidth,
                              min: 55.0,
                              max: 120.0,
                              unit: 'px',
                              presetOptions: [
                                {'label': 'Kecil', 'value': 62.0},
                                {'label': 'Standar', 'value': 74.0},
                                {'label': 'Lebar', 'value': 90.0},
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _colMulaiWidth = val;
                                  _colSelesaiWidth = val;
                                });
                                setModalState(() {});
                                _saveTableSettings();
                              },
                            ),

                            const SizedBox(height: 16),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 16),

                            // 4. LEBAR KOLOM DURASI
                            _buildDimensionSliderSection(
                              icon: Icons.timer_outlined,
                              title: 'Lebar Kolom Durasi',
                              value: _colDurasiWidth,
                              min: 55.0,
                              max: 120.0,
                              unit: 'px',
                              presetOptions: [
                                {'label': 'Kecil', 'value': 62.0},
                                {'label': 'Standar', 'value': 72.0},
                                {'label': 'Lebar', 'value': 88.0},
                              ],
                              onChanged: (val) {
                                setState(() => _colDurasiWidth = val);
                                setModalState(() {});
                                _saveTableSettings();
                              },
                            ),

                            const SizedBox(height: 16),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 16),

                            // 5. LEBAR KOLOM TAMBAHAN / KUSTOM
                            _buildDimensionSliderSection(
                              icon: Icons.view_column_rounded,
                              title: 'Lebar Kolom Kustom (Tambahan)',
                              value: _colCustomWidth,
                              min: 90.0,
                              max: 300.0,
                              unit: 'px',
                              presetOptions: [
                                {'label': 'Ramping', 'value': 110.0},
                                {'label': 'Standar', 'value': 140.0},
                                {'label': 'Lebar', 'value': 200.0},
                              ],
                              onChanged: (val) {
                                setState(() => _colCustomWidth = val);
                                setModalState(() {});
                                _saveTableSettings();
                              },
                            ),

                            const SizedBox(height: 16),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 16),

                            // 6. LEBAR KOLOM NO / CHECKLIST
                            _buildDimensionSliderSection(
                              icon: Icons.format_list_numbered_rounded,
                              title: 'Lebar Kolom No / Checklist',
                              value: _colNoWidth,
                              min: 30.0,
                              max: 60.0,
                              unit: 'px',
                              presetOptions: [
                                {'label': 'Kecil', 'value': 32.0},
                                {'label': 'Standar', 'value': 36.0},
                                {'label': 'Lebar', 'value': 48.0},
                              ],
                              onChanged: (val) {
                                setState(() => _colNoWidth = val);
                                setModalState(() {});
                                _saveTableSettings();
                              },
                            ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // Tutup Button
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text(
                          'Selesai',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
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

  Widget _buildDimensionSliderSection({
    required IconData icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required String unit,
    required List<Map<String, dynamic>> presetOptions,
    required ValueChanged<double> onChanged,
  }) {
    final int roundedVal = value.round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: primaryTeal),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: primaryTeal.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Text(
                '$roundedVal $unit',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: primaryTeal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Presets Chips
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: presetOptions.map((opt) {
            final optVal = (opt['value'] as num).toDouble();
            final isSelected = (value - optVal).abs() < 1.5;
            return InkWell(
              onTap: () => onChanged(optVal),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? primaryTeal : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? primaryTeal : const Color(0xFFCBD5E1),
                    width: isSelected ? 1.2 : 0.8,
                  ),
                ),
                child: Text(
                  '${opt['label']} (${optVal.toInt()}$unit)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 6),

        // Slider with - and + step buttons
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
              color: value > min ? primaryTeal : const Color(0xFFCBD5E1),
              onPressed: value > min
                  ? () => onChanged((value - 2.0).clamp(min, max))
                  : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: primaryTeal,
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                  thumbColor: primaryTeal,
                  overlayColor: primaryTeal.withValues(alpha: 0.15),
                  trackHeight: 4,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: (v) => onChanged(v.roundToDouble()),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              color: value < max ? primaryTeal : const Color(0xFFCBD5E1),
              onPressed: value < max
                  ? () => onChanged((value + 2.0).clamp(min, max))
                  : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ],
    );
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
            icon: Icon(
              _isResizeMode ? Icons.check_rounded : Icons.tune_rounded,
              color: Colors.white,
            ),
            tooltip: _isResizeMode
                ? 'Selesai Ubah Ukuran'
                : 'Mode Kustom Ukuran (Geser Kolom & Baris)',
            onPressed: _toggleResizeMode,
          ),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 24),
            tooltip: 'Edit Informasi Rundown',
            onPressed: _openEditRundownModal,
          ),
          IconButton(
            icon: const Icon(Icons.view_column_rounded, color: Colors.white),
            tooltip: 'Tambah Kolom',
            onPressed: _addNewColumn,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: _isPinching
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: ResponsiveContentWrapper(
          maxWidth: 850,
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

                // 4. Table Toolbar (Select All, Add Row, Delete Row, Add Column, Toggle Resize Mode)
                _buildTableToolbar(activeDay),

                if (_isResizeMode) ...[
                  const SizedBox(height: 10),
                  _buildResizeModeBanner(),
                ],

                const SizedBox(height: 10),

                // Zoom & Scale Control Bar
                _buildZoomControlBar(),

                const SizedBox(height: 10),

                // 5. Interactive Editable Table (Zoomable)
                _buildInteractiveTable(activeDay),
              ],

              const SizedBox(height: 80),
            ],
          ),
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
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: _openEditRundownModal,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded,
                          color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Edit',
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
              const SizedBox(width: 6),
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
            _rundown.totalDays == 1
                ? _formatDateShort(_rundown.startDate)
                : '${_formatDateShort(_rundown.startDate)} s/d ${_formatDateShort(_rundown.endDate)}',
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // 1. Select All Checkbox
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
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                    const SizedBox(width: 6),
                    Text(
                      _selectedRowIndices.isNotEmpty
                          ? 'Semua (${_selectedRowIndices.length})'
                          : 'Semua',
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
            ),

            const SizedBox(width: 8),
            Container(
              height: 20,
              width: 1,
              color: const Color(0xFFE2E8F0),
            ),
            const SizedBox(width: 8),

            // 2. Tambah Baris Button (Icon Only + Tooltip & Badge)
            Tooltip(
              message: _selectedRowIndices.isNotEmpty
                  ? 'Tambah ${_selectedRowIndices.length} Baris Baru'
                  : 'Tambah 1 Baris Baru',
              child: Material(
                color: primaryTeal,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _addRow,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.add_rounded,
                            color: Colors.white, size: 20),
                        if (_selectedRowIndices.length > 1)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFF004D40),
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                  minWidth: 14, minHeight: 14),
                              child: Text(
                                '${_selectedRowIndices.length}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // 3. Hapus Baris Button (Icon Only + Tooltip & Badge)
            Tooltip(
              message: _selectedRowIndices.isNotEmpty
                  ? 'Hapus ${_selectedRowIndices.length} Baris Terpilih'
                  : 'Pilih baris untuk menghapus',
              child: Material(
                color: _selectedRowIndices.isNotEmpty
                    ? Colors.redAccent
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _selectedRowIndices.isNotEmpty
                      ? _deleteSelectedRows
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: _selectedRowIndices.isNotEmpty
                              ? Colors.white
                              : const Color(0xFF94A3B8),
                        ),
                        if (_selectedRowIndices.isNotEmpty)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFF991B1B),
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                  minWidth: 14, minHeight: 14),
                              child: Text(
                                '${_selectedRowIndices.length}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // 4. Tambah Kolom Button (Icon Only + Tooltip)
            Tooltip(
              message: 'Tambah Kolom Baru',
              child: Material(
                color: primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _addNewColumn,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: primaryTeal.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.view_column_rounded,
                      color: primaryTeal,
                      size: 19,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),
            Container(
              height: 20,
              width: 1,
              color: const Color(0xFFE2E8F0),
            ),
            const SizedBox(width: 8),

            // 5. Kustom Ukuran Kolom & Baris (Mode Geser Spreadsheet)
            Tooltip(
              message: _isResizeMode
                  ? 'Selesai Ubah Ukuran'
                  : 'Mode Kustom Ukuran (Geser Kolom & Baris)',
              child: Material(
                color: _isResizeMode
                    ? primaryTeal
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _toggleResizeMode,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isResizeMode
                            ? const Color(0xFF004D40)
                            : const Color(0xFFCBD5E1),
                        width: 1.2,
                      ),
                      boxShadow: _isResizeMode
                          ? [
                              BoxShadow(
                                color: primaryTeal.withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _isResizeMode
                          ? Icons.check_rounded
                          : Icons.tune_rounded,
                      color: _isResizeMode
                          ? Colors.white
                          : const Color(0xFF334155),
                      size: 19,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResizeModeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryTeal.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: primaryTeal,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.open_with_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mode Kustom Ukuran Aktif',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  'Geser garis pembatas kolom (↔) atau baris (↕) langsung di tabel.',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Reset Button
          TextButton(
            onPressed: () {
              setState(() {
                _rowHeight = 36.0;
                _colNoWidth = 36.0;
                _colMulaiWidth = 74.0;
                _colSelesaiWidth = 74.0;
                _colDurasiWidth = 72.0;
                _colKegiatanWidth = 240.0;
                _colCustomWidth = 140.0;
                _customColWidths.clear();
              });
              _saveTableSettings();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Reset',
              style: TextStyle(
                color: Color(0xFF38BDF8),
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
              ),
            ),
          ),
          // Slider / Opsi Presisi Button
          TextButton.icon(
            onPressed: _openTableDimensionsModal,
            icon: const Icon(Icons.tune_rounded, size: 14, color: Colors.white70),
            label: const Text(
              'Slider',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 4),
          // Selesai Button
          ElevatedButton(
            onPressed: _toggleResizeMode,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Selesai',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateBaseTableWidth(RundownDay activeDay) {
    double customColsTotal = 0;
    for (final col in activeDay.customColumns) {
      customColsTotal += _getColCustomWidth(col);
    }
    return _colNoWidth +
        _colMulaiWidth +
        _colSelesaiWidth +
        _colDurasiWidth +
        _colKegiatanWidth +
        customColsTotal +
        16.0;
  }

  double _calculateBaseTableHeight(RundownDay activeDay) {
    const double headerHeight = 34.0;
    const double dividerHeight = 1.0;
    if (activeDay.rows.isEmpty) {
      return headerHeight + dividerHeight + 50.0;
    }
    return headerHeight + dividerHeight + (activeDay.rows.length * _rowHeight);
  }

  Widget _buildZoomControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Row(
              children: [
                Icon(Icons.pinch_rounded, size: 18, color: primaryTeal),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Zoom',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zoom Out Button
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                color: primaryTeal,
                tooltip: 'Perkecil Tabel (Zoom Out)',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _zoomOut,
              ),
              const SizedBox(width: 2),
              // Scale indicator (tap to reset to 100%)
              InkWell(
                onTap: _resetZoom,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${(_currentZoom * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              // Zoom In Button
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                color: primaryTeal,
                tooltip: 'Perbesar Tabel (Zoom In)',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _zoomIn,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveTable(RundownDay activeDay) {
    final baseWidth = _calculateBaseTableWidth(activeDay);
    final baseHeight = _calculateBaseTableHeight(activeDay);
    final scaledWidth = baseWidth * _currentZoom;
    final scaledHeight = baseHeight * _currentZoom;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isResizeMode
              ? primaryTeal
              : const Color(0xFF00897B).withValues(alpha: 0.18),
          width: _isResizeMode ? 1.6 : 1.0,
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
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        physics: _isPinching
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        child: SizedBox(
          width: scaledWidth,
          height: scaledHeight,
          child: Listener(
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerCancel,
            behavior: HitTestBehavior.translucent,
            child: OverflowBox(
              minWidth: baseWidth,
              maxWidth: baseWidth,
              minHeight: baseHeight,
              maxHeight: baseHeight,
              alignment: Alignment.topLeft,
              child: Transform.scale(
                scale: _currentZoom,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: baseWidth,
                  height: baseHeight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // TABLE HEADER
                      _buildTableHeader(activeDay),

                      const Divider(
                          height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                      // TABLE BODY ROWS
                      if (activeDay.rows.isEmpty)
                        Container(
                          width: baseWidth,
                          height: 50,
                          alignment: Alignment.center,
                          child: const Text(
                            'Tidak ada baris di tabel. Klik ikon "+" untuk menambah baris.',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        )
                      else
                        ...List.generate(activeDay.rows.length, (index) {
                          final row = activeDay.rows[index];
                          final isSelected =
                              _selectedRowIndices.contains(index);
                          return _buildTableRow(
                              activeDay, row, index, isSelected);
                        }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCellWithResizeHandle({
    required double width,
    required Widget child,
    required void Function(double delta) onResize,
  }) {
    return SizedBox(
      width: width,
      height: 34.0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: child,
            ),
          ),
          // Column divider resize handle (Google Sheets / Excel style)
          Positioned(
            right: -8,
            top: 0,
            bottom: 0,
            width: 16,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  onResize(details.delta.dx);
                },
                onHorizontalDragEnd: (_) => _saveTableSettings(),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _isResizeMode ? 3.0 : 1.0,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: _isResizeMode
                          ? primaryTeal
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: _isResizeMode
                          ? [
                              BoxShadow(
                                color: primaryTeal.withValues(alpha: 0.4),
                                blurRadius: 3,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(RundownDay activeDay) {
    return Container(
      height: 34.0,
      color: primaryTeal.withValues(alpha: 0.08),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Select Checkbox / No column
          _buildHeaderCellWithResizeHandle(
            width: _colNoWidth,
            onResize: (delta) {
              setState(() {
                _colNoWidth = (_colNoWidth + delta).clamp(28.0, 100.0);
              });
            },
            child: const Center(
              child: Text(
                'No',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.bold,
                  color: primaryTeal,
                ),
              ),
            ),
          ),

          // 2. WAKTU MULAI
          _buildHeaderCellWithResizeHandle(
            width: _colMulaiWidth,
            onResize: (delta) {
              setState(() {
                _colMulaiWidth = (_colMulaiWidth + delta).clamp(50.0, 160.0);
              });
            },
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mulai',
                style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // 3. WAKTU SELESAI (OTOMATIS)
          _buildHeaderCellWithResizeHandle(
            width: _colSelesaiWidth,
            onResize: (delta) {
              setState(() {
                _colSelesaiWidth =
                    (_colSelesaiWidth + delta).clamp(50.0, 160.0);
              });
            },
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Selesai',
                style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // 4. DURASI
          _buildHeaderCellWithResizeHandle(
            width: _colDurasiWidth,
            onResize: (delta) {
              setState(() {
                _colDurasiWidth = (_colDurasiWidth + delta).clamp(45.0, 140.0);
              });
            },
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Durasi',
                style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // 5. KEGIATAN
          _buildHeaderCellWithResizeHandle(
            width: _colKegiatanWidth,
            onResize: (delta) {
              setState(() {
                _colKegiatanWidth =
                    (_colKegiatanWidth + delta).clamp(120.0, 600.0);
              });
            },
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Kegiatan',
                style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // 6. CUSTOM COLUMNS (e.g. Keterangan, etc.)
          ...activeDay.customColumns.map((colName) {
            final colW = _getColCustomWidth(colName);
            return _buildHeaderCellWithResizeHandle(
              width: colW,
              onResize: (delta) {
                setState(() {
                  _customColWidths[colName] =
                      (colW + delta).clamp(60.0, 400.0);
                });
              },
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      colName,
                      style: const TextStyle(
                        fontSize: 11.0,
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
                          size: 12, color: Colors.redAccent),
                    ),
                  ),
                  const SizedBox(width: 2),
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
    return SizedBox(
      height: _rowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryTeal.withValues(alpha: 0.12)
                    : (isEven ? Colors.white : const Color(0xFFFBFDFA)),
                border: Border(
                  bottom: BorderSide(
                    color: _isResizeMode
                        ? primaryTeal.withValues(alpha: 0.35)
                        : const Color(0xFFF1F5F9),
                    width: _isResizeMode ? 1.5 : 1.0,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Select Checkbox & Number
                  SizedBox(
                    width: _colNoWidth,
                    child: InkWell(
                      onTap: _isResizeMode
                          ? null
                          : () {
                              setState(() {
                                if (isSelected) {
                                  _selectedRowIndices.remove(index);
                                } else {
                                  _selectedRowIndices.add(index);
                                }
                              });
                            },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 15,
                            color: isSelected
                                ? primaryTeal
                                : const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 10.0,
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

                  // 2. WAKTU MULAI
                  SizedBox(
                    width: _colMulaiWidth,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: _isResizeMode
                            ? null
                            : () => _pickRowStartTime(index),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: row.startTime.isNotEmpty
                                ? primaryTeal.withValues(alpha: 0.1)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(5),
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
                                  size: 11,
                                  color: row.startTime.isNotEmpty
                                      ? primaryTeal
                                      : const Color(0xFF94A3B8)),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  row.startTime.isNotEmpty
                                      ? row.startTime
                                      : '--:--',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: row.startTime.isNotEmpty
                                        ? primaryTeal
                                        : const Color(0xFF94A3B8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. WAKTU SELESAI (OTOMATIS)
                  SizedBox(
                    width: _colSelesaiWidth,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: row.endTime.isNotEmpty
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(5),
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
                                size: 10.5,
                                color: row.endTime.isNotEmpty
                                    ? primaryTeal
                                    : const Color(0xFF94A3B8)),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                row.endTime.isNotEmpty ? row.endTime : '--:--',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: row.endTime.isNotEmpty
                                      ? const Color(0xFF004D40)
                                      : const Color(0xFF94A3B8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 4. DURASI (Klik untuk atur durasi)
                  SizedBox(
                    width: _colDurasiWidth,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: _isResizeMode
                            ? null
                            : () => _editRowDuration(index),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  row.durationText,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down_rounded,
                                  size: 13, color: primaryTeal),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 5. KEGIATAN (Inline Text Input)
                  SizedBox(
                    width: _colKegiatanWidth,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: TextFormField(
                        key: ValueKey('${row.id}_activity'),
                        initialValue: row.activity,
                        enabled: !_isResizeMode,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Nama kegiatan...',
                          hintStyle: TextStyle(
                            fontSize: 11.0,
                            color: Color(0xFFCBD5E1),
                            fontWeight: FontWeight.normal,
                          ),
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                          border: InputBorder.none,
                        ),
                        onChanged: (val) {
                          row.activity = val;
                          _notifyChange();
                        },
                      ),
                    ),
                  ),

                  // 6. CUSTOM COLUMNS
                  ...activeDay.customColumns.map((colName) {
                    final val = row.customValues[colName] ?? '';
                    final colW = _getColCustomWidth(colName);
                    return SizedBox(
                      width: colW,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: TextFormField(
                          key: ValueKey('${row.id}_custom_$colName'),
                          initialValue: val,
                          enabled: !_isResizeMode,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF334155),
                          ),
                          decoration: InputDecoration(
                            hintText: '$colName...',
                            hintStyle: const TextStyle(
                              fontSize: 11.0,
                              color: Color(0xFFCBD5E1),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 3),
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
            ),
          ),

          // Horizontal Row Bottom Drag Handle (Spreadsheet / Excel style)
          Positioned(
            left: 0,
            right: 0,
            bottom: -6,
            height: 12,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeRow,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) {
                  setState(() {
                    _rowHeight =
                        (_rowHeight + details.delta.dy).clamp(26.0, 90.0);
                  });
                },
                onVerticalDragEnd: (_) => _saveTableSettings(),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: _isResizeMode ? 3.0 : 1.0,
                    width: double.infinity,
                    color: _isResizeMode
                        ? primaryTeal.withValues(alpha: 0.8)
                        : Colors.transparent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
