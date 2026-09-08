import 'dart:convert';
import 'package:daily_apps/models/model_rundown.dart';
import 'package:daily_apps/utils/responsive_text.dart';
import 'package:daily_apps/widgets/custom_toast.dart';
import 'package:daily_apps/widgets/dialog_tambah_rundown.dart';
import 'package:flutter/gestures.dart';
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

  // Column Header Alignment Settings: 'left', 'center', 'right' (Default: 'center')
  final Map<String, String> _headerColAlignments = {};

  // Column Data Cell Alignment Settings: 'left', 'center', 'right' (Default: 'center', except kegiatan = 'left')
  final Map<String, String> _dataColAlignments = {};

  // Touch pointer tracking for highly responsive and accurate pinch-to-zoom
  final Map<int, Offset> _activePointers = {};
  int? _pinchPointer1;
  int? _pinchPointer2;
  double? _initialPinchDistance;
  double _pinchStartZoom = 1.0;
  bool _isPinching = false;

  // Active resize state tracking to lock scrolling and prevent jumping/shifting
  bool _isResizingColumn = false;
  bool _isResizingRow = false;

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

  String _getHeaderColAlignment(String colKey, {String defaultAlign = 'center'}) {
    return _headerColAlignments[colKey] ?? defaultAlign;
  }

  String _getDataColAlignment(String colKey, {String defaultAlign = 'center'}) {
    return _dataColAlignments[colKey] ?? defaultAlign;
  }

  TextAlign _getTextAlign(String alignStr) {
    switch (alignStr) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      case 'center':
      default:
        return TextAlign.center;
    }
  }

  Alignment _getAlignment(String alignStr) {
    switch (alignStr) {
      case 'left':
        return Alignment.centerLeft;
      case 'right':
        return Alignment.centerRight;
      case 'center':
      default:
        return Alignment.center;
    }
  }

  MainAxisAlignment _getMainAxisAlignment(String alignStr) {
    switch (alignStr) {
      case 'left':
        return MainAxisAlignment.start;
      case 'right':
        return MainAxisAlignment.end;
      case 'center':
      default:
        return MainAxisAlignment.center;
    }
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
      final headerAlignmentsJson =
          prefs.getString('rundown_header_col_alignments');
      if (headerAlignmentsJson != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(headerAlignmentsJson);
          _headerColAlignments.clear();
          decoded.forEach((k, v) {
            if (v is String) {
              _headerColAlignments[k] = v;
            }
          });
        } catch (_) {}
      }
      final dataAlignmentsJson =
          prefs.getString('rundown_data_col_alignments');
      if (dataAlignmentsJson != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(dataAlignmentsJson);
          _dataColAlignments.clear();
          decoded.forEach((k, v) {
            if (v is String) {
              _dataColAlignments[k] = v;
            }
          });
        } catch (_) {}
      } else {
        // Fallback to legacy single alignment map if exists
        final legacyAlignmentsJson = prefs.getString('rundown_col_alignments');
        if (legacyAlignmentsJson != null) {
          try {
            final Map<String, dynamic> decoded =
                jsonDecode(legacyAlignmentsJson);
            decoded.forEach((k, v) {
              if (v is String) {
                _dataColAlignments[k] = v;
                if (!_headerColAlignments.containsKey(k)) {
                  _headerColAlignments[k] = v;
                }
              }
            });
          } catch (_) {}
        }
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
      await prefs.setString(
          'rundown_header_col_alignments', jsonEncode(_headerColAlignments));
      await prefs.setString(
          'rundown_data_col_alignments', jsonEncode(_dataColAlignments));
      // Save legacy for backwards compatibility
      await prefs.setString(
          'rundown_col_alignments', jsonEncode(_dataColAlignments));
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
      final keys = _activePointers.keys.toList();
      _pinchPointer1 = keys[0];
      _pinchPointer2 = keys[1];
      final p1 = _activePointers[_pinchPointer1]!;
      final p2 = _activePointers[_pinchPointer2]!;
      _initialPinchDistance = (p1 - p2).distance;
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

    if (_isPinching &&
        _pinchPointer1 != null &&
        _pinchPointer2 != null &&
        _activePointers.containsKey(_pinchPointer1) &&
        _activePointers.containsKey(_pinchPointer2)) {
      final p1 = _activePointers[_pinchPointer1]!;
      final p2 = _activePointers[_pinchPointer2]!;
      final currentDistance = (p1 - p2).distance;

      if (_initialPinchDistance != null && _initialPinchDistance! > 10.0) {
        final scaleFactor = currentDistance / _initialPinchDistance!;
        final newZoom = (_pinchStartZoom * scaleFactor).clamp(0.4, 2.2);

        if ((newZoom - _currentZoom).abs() > 0.002) {
          setState(() {
            _currentZoom = newZoom;
          });
        }
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    if (event.pointer == _pinchPointer1 || event.pointer == _pinchPointer2) {
      if (_activePointers.length >= 2) {
        final keys = _activePointers.keys.toList();
        _pinchPointer1 = keys[0];
        _pinchPointer2 = keys[1];
        final p1 = _activePointers[_pinchPointer1]!;
        final p2 = _activePointers[_pinchPointer2]!;
        _initialPinchDistance = (p1 - p2).distance;
        _pinchStartZoom = _currentZoom;
      } else {
        _pinchPointer1 = null;
        _pinchPointer2 = null;
        _initialPinchDistance = null;
        if (_isPinching) {
          setState(() {
            _isPinching = false;
          });
        }
      }
    } else if (_activePointers.length < 2) {
      _pinchPointer1 = null;
      _pinchPointer2 = null;
      _initialPinchDistance = null;
      if (_isPinching) {
        setState(() {
          _isPinching = false;
        });
      }
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2) {
      _pinchPointer1 = null;
      _pinchPointer2 = null;
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
                              _headerColAlignments.clear();
                              _dataColAlignments.clear();
                              _dataColAlignments['kegiatan'] = 'left';
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
                      'Sesuaikan tinggi baris, lebar kolom, dan perataan teks (kiri, tengah, kanan) pada tabel.',
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

                            const SizedBox(height: 16),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 16),

                            // 7. PERATAAN KOLOM SECTION
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.format_align_left_rounded,
                                          size: 18, color: primaryTeal),
                                      SizedBox(width: 8),
                                      Text(
                                        'Perataan Judul & Data Kolom',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Atur alignment teks (kiri, tengah, kanan) secara terpisah untuk Judul Kolom dan Isi Data.',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        _openColumnAlignmentModal();
                                      },
                                      icon: const Icon(Icons.tune_rounded,
                                          size: 16, color: primaryTeal),
                                      label: const Text(
                                        'Buka Pengaturan Alignment',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: primaryTeal,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side:
                                            const BorderSide(color: primaryTeal),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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

  Future<void> _openColumnAlignmentModal() async {
    final activeDay = (_selectedDayIndex < _rundown.days.length)
        ? _rundown.days[_selectedDayIndex]
        : null;

    int alignmentTargetTab = 0; // 0: Judul Kolom (Header), 1: Data Kolom (Data)

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
            final isHeaderTab = alignmentTargetTab == 0;

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

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.format_align_left_rounded,
                                  color: primaryTeal, size: 22),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Perataan Kolom (Alignment)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              if (isHeaderTab) {
                                _headerColAlignments.clear();
                              } else {
                                _dataColAlignments.clear();
                                _dataColAlignments['kegiatan'] = 'left';
                              }
                            });
                            setModalState(() {});
                            _saveTableSettings();
                          },
                          icon: const Icon(Icons.refresh_rounded,
                              size: 15, color: primaryTeal),
                          label: Text(
                            isHeaderTab ? 'Reset Judul' : 'Reset Data',
                            style: const TextStyle(
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
                    const SizedBox(height: 10),

                    // Tab Selector: Judul Kolom vs Data Kolom
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  alignmentTargetTab = 0;
                                });
                              },
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isHeaderTab
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: isHeaderTab
                                      ? [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.06),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.title_rounded,
                                      size: 16,
                                      color: isHeaderTab
                                          ? primaryTeal
                                          : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Judul Kolom',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: isHeaderTab
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isHeaderTab
                                            ? primaryTeal
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  alignmentTargetTab = 1;
                                });
                              },
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !isHeaderTab
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: !isHeaderTab
                                      ? [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.06),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.table_rows_rounded,
                                      size: 16,
                                      color: !isHeaderTab
                                          ? primaryTeal
                                          : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Data Kolom',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: !isHeaderTab
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: !isHeaderTab
                                            ? primaryTeal
                                            : const Color(0xFF64748B),
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
                    const SizedBox(height: 8),
                    Text(
                      isHeaderTab
                          ? 'Perataan teks khusus untuk baris Judul Kolom (Header Tabel):'
                          : 'Perataan teks khusus untuk baris Isi Data (Cells Tabel):',
                      style: const TextStyle(
                          fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 10),

                    // Column Alignment List
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            _buildAlignmentSegmentedControl(
                              title: 'Kolom No',
                              icon: Icons.format_list_numbered_rounded,
                              currentValue: isHeaderTab
                                  ? _getHeaderColAlignment('no')
                                  : _getDataColAlignment('no'),
                              onChanged: (val) {
                                setState(() {
                                  if (isHeaderTab) {
                                    _headerColAlignments['no'] = val;
                                  } else {
                                    _dataColAlignments['no'] = val;
                                  }
                                });
                                setModalState(() {});
                                _saveTableSettings();
                              },
                            ),
                            const SizedBox(height: 10),
                            _buildAlignmentSegmentedControl(
                              title: 'Waktu Mulai',
                              icon: Icons.access_time_rounded,
                              currentValue: isHeaderTab
                                  ? _getHeaderColAlignment('mulai')
                                  : _getDataColAlignment('mulai'),
                              onChanged: (val) {
                                setState(() {
                                  if (isHeaderTab) {
                                    _headerColAlignments['mulai'] = val;
                                  } else {
                                    _dataColAlignments['mulai'] = val;
                                  }
                                });
                                setModalState(() {});
                                _saveTableSettings();
                              },
                            ),
                            const SizedBox(height: 10),
                            _buildAlignmentSegmentedControl(
                              title: 'Waktu Selesai',
                              icon: Icons.check_circle_outline_rounded,
                              currentValue: isHeaderTab
                                  ? _getHeaderColAlignment('selesai')
                                  : _getDataColAlignment('selesai'),
                              onChanged: (val) {
                                setState(() {
                                  if (isHeaderTab) {
                                    _headerColAlignments['selesai'] = val;
                                  } else {
                                    _dataColAlignments['selesai'] = val;
                                  }
                                });
                                setModalState(() {});
                                _saveTableSettings();
                              },
                            ),
                            const SizedBox(height: 10),
                            _buildAlignmentSegmentedControl(
                              title: 'Durasi',
                              icon: Icons.timer_outlined,
                              currentValue: isHeaderTab
                                  ? _getHeaderColAlignment('durasi')
                                  : _getDataColAlignment('durasi'),
                              onChanged: (val) {
                                setState(() {
                                  if (isHeaderTab) {
                                    _headerColAlignments['durasi'] = val;
                                  } else {
                                    _dataColAlignments['durasi'] = val;
                                  }
                                });
                                setModalState(() {});
                                _saveTableSettings();
                              },
                            ),
                            const SizedBox(height: 10),
                            _buildAlignmentSegmentedControl(
                              title: 'Kegiatan',
                              icon: Icons.event_note_rounded,
                              currentValue: isHeaderTab
                                  ? _getHeaderColAlignment('kegiatan',
                                      defaultAlign: 'center')
                                  : _getDataColAlignment('kegiatan',
                                      defaultAlign: 'left'),
                              onChanged: (val) {
                                setState(() {
                                  if (isHeaderTab) {
                                    _headerColAlignments['kegiatan'] = val;
                                  } else {
                                    _dataColAlignments['kegiatan'] = val;
                                  }
                                });
                                setModalState(() {});
                                _saveTableSettings();
                              },
                            ),
                            if (activeDay != null)
                              ...activeDay.customColumns.map((colName) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: _buildAlignmentSegmentedControl(
                                    title: colName,
                                    icon: Icons.view_column_rounded,
                                    currentValue: isHeaderTab
                                        ? _getHeaderColAlignment(colName)
                                        : _getDataColAlignment(colName),
                                    onChanged: (val) {
                                      setState(() {
                                        if (isHeaderTab) {
                                          _headerColAlignments[colName] = val;
                                        } else {
                                          _dataColAlignments[colName] = val;
                                        }
                                      });
                                      setModalState(() {});
                                      _saveTableSettings();
                                    },
                                  ),
                                );
                              }),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

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
                              fontSize: 14, fontWeight: FontWeight.bold),
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

  Widget _buildAlignmentSegmentedControl({
    required String title,
    required IconData icon,
    required String currentValue,
    required void Function(String newAlign) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(icon, size: 17, color: primaryTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAlignButton(
                  icon: Icons.format_align_left_rounded,
                  tooltip: 'Rata Kiri',
                  isSelected: currentValue == 'left',
                  onTap: () => onChanged('left'),
                ),
                Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                _buildAlignButton(
                  icon: Icons.format_align_center_rounded,
                  tooltip: 'Rata Tengah',
                  isSelected: currentValue == 'center',
                  onTap: () => onChanged('center'),
                ),
                Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                _buildAlignButton(
                  icon: Icons.format_align_right_rounded,
                  tooltip: 'Rata Kanan',
                  isSelected: currentValue == 'right',
                  onTap: () => onChanged('right'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlignButton({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: 32,
          height: 28,
          decoration: BoxDecoration(
            color: isSelected ? primaryTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
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
        physics: (_isPinching || _isResizingColumn || _isResizingRow)
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

            // 5. Atur Perataan Kolom (Alignment: Kiri, Tengah, Kanan)
            Tooltip(
              message: 'Atur Perataan Kolom (Kiri / Tengah / Kanan)',
              child: Material(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _openColumnAlignmentModal,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFCBD5E1),
                        width: 1.2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.format_align_left_rounded,
                      color: Color(0xFF334155),
                      size: 19,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // 6. Kustom Ukuran Kolom & Baris (Mode Geser Spreadsheet)
            Tooltip(
              message: _isResizeMode
                  ? 'Selesai Ubah Ukuran'
                  : 'Mode Kustom Ukuran (Geser Kolom & Baris)\n(Tahan untuk buka slider presisi)',
              child: Material(
                color: _isResizeMode
                    ? primaryTeal
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _toggleResizeMode,
                  onLongPress: _openTableDimensionsModal,
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
        customColsTotal;
  }

  double _calculateBaseTableHeight(RundownDay activeDay) {
    const double headerHeight = 36.0;
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

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      behavior: HitTestBehavior.translucent,
      child: Container(
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
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            overscroll: false,
            physics: const ClampingScrollPhysics(),
          ),
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            physics: (_isPinching || _isResizingColumn || _isResizingRow)
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            child: SizedBox(
              width: scaledWidth,
              height: scaledHeight,
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
      ),
    );
  }

  Widget _buildHeaderCellWithResizeHandle({
    required double width,
    required Widget child,
    required void Function(double delta) onResize,
    bool showRightBorder = true,
  }) {
    final borderDecoration = showRightBorder
        ? const Border(
            right: BorderSide(
              color: Color(0xFFCBD5E1),
              width: 1.0,
            ),
          )
        : null;

    if (!_isResizeMode) {
      return Container(
        width: width,
        height: 36.0,
        decoration: BoxDecoration(
          border: borderDecoration,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: child,
      );
    }

    return SizedBox(
      width: width,
      height: 36.0,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragDown: (_) {
            setState(() {
              _isResizingColumn = true;
            });
          },
          onHorizontalDragStart: (_) {
            setState(() {
              _isResizingColumn = true;
            });
          },
          onHorizontalDragUpdate: (details) {
            onResize(details.delta.dx);
          },
          onHorizontalDragEnd: (_) {
            setState(() {
              _isResizingColumn = false;
            });
            _saveTableSettings();
          },
          onHorizontalDragCancel: () {
            setState(() {
              _isResizingColumn = false;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: primaryTeal.withValues(alpha: 0.14),
              border: Border(
                top: BorderSide(
                  color: primaryTeal.withValues(alpha: 0.4),
                  width: 1.0,
                ),
                bottom: BorderSide(
                  color: primaryTeal.withValues(alpha: 0.4),
                  width: 1.0,
                ),
                right: showRightBorder
                    ? const BorderSide(
                        color: Color(0xFFCBD5E1),
                        width: 1.0,
                      )
                    : BorderSide.none,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Stack(
              alignment: Alignment.center,
              children: [
                child,
                Positioned(
                  right: 2,
                  child: Icon(
                    Icons.unfold_more_rounded,
                    size: 13,
                    color: primaryTeal.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(RundownDay activeDay) {
    return Container(
      height: 36.0,
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
            child: Align(
              alignment: _getAlignment(_getHeaderColAlignment('no')),
              child: Text(
                'No',
                textAlign: _getTextAlign(_getHeaderColAlignment('no')),
                style: const TextStyle(
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
            child: Align(
              alignment: _getAlignment(_getHeaderColAlignment('mulai')),
              child: Text(
                'Mulai',
                textAlign: _getTextAlign(_getHeaderColAlignment('mulai')),
                style: const TextStyle(
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
            child: Align(
              alignment: _getAlignment(_getHeaderColAlignment('selesai')),
              child: Text(
                'Selesai',
                textAlign: _getTextAlign(_getHeaderColAlignment('selesai')),
                style: const TextStyle(
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
            child: Align(
              alignment: _getAlignment(_getHeaderColAlignment('durasi')),
              child: Text(
                'Durasi',
                textAlign: _getTextAlign(_getHeaderColAlignment('durasi')),
                style: const TextStyle(
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
            showRightBorder: activeDay.customColumns.isNotEmpty,
            onResize: (delta) {
              setState(() {
                _colKegiatanWidth =
                    (_colKegiatanWidth + delta).clamp(120.0, 600.0);
              });
            },
            child: Align(
              alignment: _getAlignment(
                  _getHeaderColAlignment('kegiatan', defaultAlign: 'center')),
              child: Text(
                'Kegiatan',
                textAlign: _getTextAlign(
                    _getHeaderColAlignment('kegiatan', defaultAlign: 'center')),
                style: const TextStyle(
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
          ...activeDay.customColumns.asMap().entries.map((entry) {
            final colIndex = entry.key;
            final colName = entry.value;
            final isLast = colIndex == activeDay.customColumns.length - 1;
            final colW = _getColCustomWidth(colName);
            final align = _getHeaderColAlignment(colName);
            return _buildHeaderCellWithResizeHandle(
              width: colW,
              showRightBorder: !isLast,
              onResize: (delta) {
                setState(() {
                  _customColWidths[colName] =
                      (colW + delta).clamp(60.0, 400.0);
                });
              },
              child: Align(
                alignment: _getAlignment(align),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: _getMainAxisAlignment(align),
                  children: [
                    Flexible(
                      child: Text(
                        colName,
                        textAlign: _getTextAlign(align),
                        style: const TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _deleteCustomColumn(colName),
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(2.0),
                        child: Icon(Icons.close_rounded,
                            size: 12, color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _toggleRowSelection(int index) {
    if (_isResizeMode) return;
    HapticFeedback.mediumImpact();
    setState(() {
      if (_selectedRowIndices.contains(index)) {
        _selectedRowIndices.remove(index);
      } else {
        _selectedRowIndices.add(index);
      }
    });
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
            child: Material(
              color: isSelected
                  ? primaryTeal.withValues(alpha: 0.14)
                  : (isEven ? Colors.white : const Color(0xFFFBFDFA)),
              child: InkWell(
                splashColor: primaryTeal.withValues(alpha: 0.28),
                highlightColor: primaryTeal.withValues(alpha: 0.16),
                onTap: _isResizeMode
                    ? null
                    : () {
                        if (_selectedRowIndices.isNotEmpty) {
                          _toggleRowSelection(index);
                        }
                      },
                onLongPress:
                    _isResizeMode ? null : () => _toggleRowSelection(index),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _isResizeMode
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFFF1F5F9),
                        width: 1.0,
                      ),
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Select Checkbox & Number (Tekan lama tahan untuk mulai memilih baris)
                      Container(
                        width: _colNoWidth,
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: Align(
                          alignment: _getAlignment(_getDataColAlignment('no')),
                          child: InkWell(
                            splashColor: primaryTeal.withValues(alpha: 0.28),
                            highlightColor: primaryTeal.withValues(alpha: 0.16),
                            onTap: _isResizeMode
                                ? null
                                : () {
                                    if (_selectedRowIndices.isNotEmpty) {
                                      _toggleRowSelection(index);
                                    }
                                  },
                            onLongPress: _isResizeMode
                                ? null
                                : () => _toggleRowSelection(index),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 2, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: _getMainAxisAlignment(
                                    _getDataColAlignment('no')),
                                children: [
                                  if (_selectedRowIndices.isNotEmpty) ...[
                                    Icon(
                                      isSelected
                                          ? Icons.check_box_rounded
                                          : Icons
                                              .check_box_outline_blank_rounded,
                                      size: 13.5,
                                      color: isSelected
                                          ? primaryTeal
                                          : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 2),
                                  ],
                                  Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 10.5,
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
                        ),
                      ),

                      // 2. WAKTU MULAI
                      Container(
                        width: _colMulaiWidth,
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: Align(
                          alignment:
                              _getAlignment(_getDataColAlignment('mulai')),
                          child: InkWell(
                            splashColor: primaryTeal.withValues(alpha: 0.28),
                            highlightColor: primaryTeal.withValues(alpha: 0.16),
                            onTap: _isResizeMode
                                ? null
                                : () {
                                    if (_selectedRowIndices.isNotEmpty) {
                                      _toggleRowSelection(index);
                                    } else {
                                      _pickRowStartTime(index);
                                    }
                                  },
                            onLongPress: _isResizeMode
                                ? null
                                : () => _toggleRowSelection(index),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              child: Text(
                                row.startTime.isNotEmpty
                                    ? row.startTime
                                    : '--:--',
                                textAlign: _getTextAlign(
                                    _getDataColAlignment('mulai')),
                                style: TextStyle(
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w600,
                                  color: row.startTime.isNotEmpty
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF94A3B8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 3. WAKTU SELESAI (OTOMATIS)
                      Container(
                        width: _colSelesaiWidth,
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: Align(
                          alignment:
                              _getAlignment(_getDataColAlignment('selesai')),
                          child: InkWell(
                            splashColor: primaryTeal.withValues(alpha: 0.28),
                            highlightColor: primaryTeal.withValues(alpha: 0.16),
                            onTap: _isResizeMode
                                ? null
                                : () {
                                    if (_selectedRowIndices.isNotEmpty) {
                                      _toggleRowSelection(index);
                                    }
                                  },
                            onLongPress: _isResizeMode
                                ? null
                                : () => _toggleRowSelection(index),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              child: Text(
                                row.endTime.isNotEmpty ? row.endTime : '--:--',
                                textAlign: _getTextAlign(
                                    _getDataColAlignment('selesai')),
                                style: TextStyle(
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w600,
                                  color: row.endTime.isNotEmpty
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF94A3B8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 4. DURASI (Klik untuk atur durasi)
                      Container(
                        width: _colDurasiWidth,
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: Align(
                          alignment:
                              _getAlignment(_getDataColAlignment('durasi')),
                          child: InkWell(
                            splashColor: primaryTeal.withValues(alpha: 0.28),
                            highlightColor: primaryTeal.withValues(alpha: 0.16),
                            onTap: _isResizeMode
                                ? null
                                : () {
                                    if (_selectedRowIndices.isNotEmpty) {
                                      _toggleRowSelection(index);
                                    } else {
                                      _editRowDuration(index);
                                    }
                                  },
                            onLongPress: _isResizeMode
                                ? null
                                : () => _toggleRowSelection(index),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              child: Text(
                                row.durationText,
                                textAlign: _getTextAlign(
                                    _getDataColAlignment('durasi')),
                                style: TextStyle(
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w600,
                                  color: row.durationMinutes > 0
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF94A3B8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 5. KEGIATAN (Inline Text Input)
                      InkWell(
                        splashColor: primaryTeal.withValues(alpha: 0.22),
                        highlightColor: primaryTeal.withValues(alpha: 0.12),
                        onLongPress: _isResizeMode
                            ? null
                            : () => _toggleRowSelection(index),
                        onTap: _isResizeMode
                            ? null
                            : () {
                                if (_selectedRowIndices.isNotEmpty) {
                                  _toggleRowSelection(index);
                                }
                              },
                        child: Container(
                          width: _colKegiatanWidth,
                          decoration: BoxDecoration(
                            border: activeDay.customColumns.isNotEmpty
                                ? const Border(
                                    right: BorderSide(
                                      color: Color(0xFFE2E8F0),
                                      width: 1.0,
                                    ),
                                  )
                                : null,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: TextFormField(
                                key: ValueKey('${row.id}_activity'),
                                initialValue: row.activity,
                                textAlign: _getTextAlign(_getDataColAlignment(
                                    'kegiatan',
                                    defaultAlign: 'left')),
                                enabled: !_isResizeMode,
                                textCapitalization:
                                    TextCapitalization.sentences,
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
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 3),
                                  border: InputBorder.none,
                                ),
                                onChanged: (val) {
                                  row.activity = val;
                                  _notifyChange();
                                },
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 6. CUSTOM COLUMNS
                      ...activeDay.customColumns.asMap().entries.map((entry) {
                        final colIndex = entry.key;
                        final colName = entry.value;
                        final isLast =
                            colIndex == activeDay.customColumns.length - 1;
                        final val = row.customValues[colName] ?? '';
                        final colW = _getColCustomWidth(colName);
                        final align = _getDataColAlignment(colName);
                        return InkWell(
                          splashColor: primaryTeal.withValues(alpha: 0.22),
                          highlightColor: primaryTeal.withValues(alpha: 0.12),
                          onLongPress: _isResizeMode
                              ? null
                              : () => _toggleRowSelection(index),
                          onTap: _isResizeMode
                              ? null
                              : () {
                                  if (_selectedRowIndices.isNotEmpty) {
                                    _toggleRowSelection(index);
                                  }
                                },
                          child: Container(
                            width: colW,
                            decoration: BoxDecoration(
                              border: !isLast
                                  ? const Border(
                                      right: BorderSide(
                                        color: Color(0xFFE2E8F0),
                                        width: 1.0,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: TextFormField(
                                  key: ValueKey('${row.id}_custom_$colName'),
                                  initialValue: val,
                                  textAlign: _getTextAlign(align),
                                  enabled: !_isResizeMode,
                                  textCapitalization:
                                      TextCapitalization.sentences,
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
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Area-based Row Height Drag Gesture (Seluruh area baris) - ONLY in resize mode
          if (_isResizeMode)
            Positioned.fill(
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeRow,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  dragStartBehavior: DragStartBehavior.down,
                  onVerticalDragDown: (_) {
                    setState(() {
                      _isResizingRow = true;
                    });
                  },
                  onVerticalDragStart: (_) {
                    setState(() {
                      _isResizingRow = true;
                    });
                  },
                  onVerticalDragUpdate: (details) {
                    setState(() {
                      _rowHeight =
                          (_rowHeight + details.delta.dy).clamp(26.0, 90.0);
                    });
                  },
                  onVerticalDragEnd: (_) {
                    setState(() {
                      _isResizingRow = false;
                    });
                    _saveTableSettings();
                  },
                  onVerticalDragCancel: () {
                    setState(() {
                      _isResizingRow = false;
                    });
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
