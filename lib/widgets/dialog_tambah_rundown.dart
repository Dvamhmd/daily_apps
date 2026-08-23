import 'package:daily_apps/models/model_rundown.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ModalTambahRundown extends StatefulWidget {
  final Rundown? rundown;

  const ModalTambahRundown({
    super.key,
    this.rundown,
  });

  static Future<Rundown?> show(BuildContext context, {Rundown? rundown}) {
    return showModalBottomSheet<Rundown>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalTambahRundown(rundown: rundown),
    );
  }

  @override
  State<ModalTambahRundown> createState() => _ModalTambahRundownState();
}

class _ModalTambahRundownState extends State<ModalTambahRundown> {
  static const Color primaryTeal = Color(0xFF00897B);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _singleThemeController = TextEditingController();

  DateTime _startDate = DateTime.now();
  int _totalDays = 1;

  // List of controllers for multi-day themes
  final List<TextEditingController> _dayThemeControllers = [];

  bool get isEditing => widget.rundown != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final r = widget.rundown!;
      _titleController.text = r.title;
      _startDate = r.startDate;
      _totalDays = r.totalDays;
      if (r.days.isNotEmpty) {
        _singleThemeController.text = r.days.first.theme;
        for (int i = 0; i < r.days.length; i++) {
          final ctrl = TextEditingController(text: r.days[i].theme);
          _dayThemeControllers.add(ctrl);
        }
      }
    }
    _syncDayControllers();
  }

  void _syncDayControllers() {
    while (_dayThemeControllers.length < _totalDays) {
      final index = _dayThemeControllers.length;
      final ctrl = TextEditingController();
      // If expanding from 1 day and single theme was typed, put it in day 1
      if (index == 0 && _singleThemeController.text.isNotEmpty) {
        ctrl.text = _singleThemeController.text;
      }
      _dayThemeControllers.add(ctrl);
    }
    while (_dayThemeControllers.length > _totalDays) {
      final last = _dayThemeControllers.removeLast();
      last.dispose();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _singleThemeController.dispose();
    for (final ctrl in _dayThemeControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _setTotalDays(int newDays) {
    if (newDays < 1 || newDays > 30) return;
    setState(() {
      _totalDays = newDays;
      _syncDayControllers();
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
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
      setState(() {
        _startDate = picked;
      });
    }
  }

  void _onGenerateRundown() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final title = _titleController.text.trim();
    final List<RundownDay> days = [];

    for (int i = 0; i < _totalDays; i++) {
      final dayDate = _startDate.add(Duration(days: i));
      String theme = '';
      if (_totalDays == 1) {
        theme = _singleThemeController.text.trim();
      } else {
        theme = _dayThemeControllers[i].text.trim();
      }

      final fallbackTheme = 'Agenda Hari Ke-${i + 1}';
      final finalTheme = theme.isNotEmpty ? theme : fallbackTheme;

      if (isEditing && widget.rundown!.days.length > i) {
        final existingDay = widget.rundown!.days[i];
        days.add(
          existingDay.copyWith(
            dayNumber: i + 1,
            date: dayDate,
            theme: finalTheme,
          ),
        );
      } else {
        days.add(
          RundownDay.createWithDefaultRows(
            dayNumber: i + 1,
            date: dayDate,
            theme: finalTheme,
            initialRowCount: 5,
          ),
        );
      }
    }

    if (isEditing) {
      final updatedRundown = widget.rundown!.copyWith(
        title: title,
        startDate: _startDate,
        totalDays: _totalDays,
        days: days,
      );
      Navigator.of(context).pop(updatedRundown);
    } else {
      final newRundown = Rundown(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        startDate: _startDate,
        totalDays: _totalDays,
        days: days,
      );
      Navigator.of(context).pop(newRundown);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // Fallback format if id_ID locale is not initialized
    String formattedStartDate;
    try {
      formattedStartDate = DateFormat('EEEE, d MMM yyyy').format(_startDate);
    } catch (_) {
      formattedStartDate =
          '${_startDate.day}/${_startDate.month}/${_startDate.year}';
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Bar with Drag Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              // Header Modal
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isEditing
                            ? Icons.edit_calendar_rounded
                            : Icons.add_task_rounded,
                        color: primaryTeal,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing
                                ? 'Edit Informasi Rundown'
                                : 'Buat Rundown Baru',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEditing
                                ? 'Ubah judul, tanggal pelaksanaan, durasi hari, dan tema'
                                : 'Tentukan tanggal, durasi, dan tema acara',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Form Body (Scrollable)
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. JUDUL RUNDOWN
                      const Text(
                        'Judul Rundown / Acara',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Judul rundown wajib diisi';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Contoh: Family Gathering 2026 / Workshop',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.normal,
                          ),
                          prefixIcon: const Icon(
                            Icons.event_available_rounded,
                            color: primaryTeal,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: primaryTeal, width: 1.8),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.redAccent),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: Colors.redAccent, width: 1.8),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 2. TANGGAL PELAKSANAAN & JUMLAH HARI
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tanggal Pelaksanaan
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tanggal Mulai',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _pickStartDate,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_month_rounded,
                                          color: primaryTeal,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            formattedStartDate,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Jumlah Hari
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Jumlah Hari',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        onPressed: _totalDays > 1
                                            ? () => _setTotalDays(_totalDays - 1)
                                            : null,
                                        icon: const Icon(Icons.remove_rounded,
                                            size: 18),
                                        color: primaryTeal,
                                        disabledColor: Colors.grey[300],
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                      Text(
                                        '$_totalDays Hari',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _totalDays < 30
                                            ? () => _setTotalDays(_totalDays + 1)
                                            : null,
                                        icon:
                                            const Icon(Icons.add_rounded, size: 18),
                                        color: primaryTeal,
                                        disabledColor: Colors.grey[300],
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),



                      const SizedBox(height: 22),

                      // 3. TEMA / THEME SECTION (DYNAMIC)
                      Row(
                        children: [
                          Icon(
                            Icons.palette_rounded,
                            size: 16,
                            color: primaryTeal,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _totalDays == 1
                                ? 'Tema Acara'
                                : 'Tema Kegiatan Per Hari ($_totalDays Hari)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (_totalDays == 1) ...[
                        // Single Day Theme
                        TextFormField(
                          controller: _singleThemeController,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1E293B),
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Contoh: Grand Opening & Sesi Networking (opsional)',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                            prefixIcon: const Icon(
                              Icons.loyalty_rounded,
                              color: primaryTeal,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: primaryTeal, width: 1.8),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Multi-Day Themes
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _totalDays,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final currentDayDate =
                                _startDate.add(Duration(days: index));
                            String dateStr;
                            try {
                              dateStr = DateFormat('d MMM').format(currentDayDate);
                            } catch (_) {
                              dateStr =
                                  '${currentDayDate.day}/${currentDayDate.month}';
                            }

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              primaryTeal.withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Day ${index + 1}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: primaryTeal,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        dateStr,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _dayThemeControllers[index],
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1E293B),
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Tema Day ${index + 1} (contoh: ${index == 0 ? "Kedatangan & Ice Breaking" : index == 1 ? "Seminar & Diskusi" : "Penutupan & Wisata"})',
                                      hintStyle: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFE2E8F0)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: primaryTeal, width: 1.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 28),

                      // Generate / Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _onGenerateRundown,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                            shadowColor: primaryTeal.withValues(alpha: 0.4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isEditing
                                    ? Icons.check_circle_rounded
                                    : Icons.auto_awesome_rounded,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isEditing
                                    ? 'Simpan Perubahan'
                                    : 'Generate Rundown',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
