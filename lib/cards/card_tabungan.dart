import 'dart:convert';
import 'package:daily_apps/models/model_tabungan.dart';
import 'package:daily_apps/utils/riwayat_service.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InfoCardTabungan extends StatefulWidget {
  final String title;
  final String amount;
  final List<Map<String, String>> items;
  final VoidCallback onChanged;
  final int? targetAmount;
  final DateTime? targetDate;
  final VoidCallback? onEditTarget;

  const InfoCardTabungan({
    super.key,
    required this.title,
    required this.amount,
    required this.items,
    required this.onChanged,
    this.targetAmount,
    this.targetDate,
    this.onEditTarget,
  });

  @override
  State<InfoCardTabungan> createState() => _InfoCardTabunganState();
}

class _InfoCardTabunganState extends State<InfoCardTabungan> {
  List<Tabungan> tabunganList = [];
  int _localTargetAmount = 0;
  DateTime? _localTargetDate;

  DateTime? _parseTargetDateFromPrefs(SharedPreferences prefs) {
    try {
      final raw = prefs.get('target_date');
      if (raw == null) return null;
      if (raw is int) {
        return DateTime.fromMillisecondsSinceEpoch(raw);
      }
      if (raw is String) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
        final intVal = int.tryParse(raw);
        if (intVal != null) return DateTime.fromMillisecondsSinceEpoch(intVal);
      }
    } catch (e) {
      debugPrint('Error parsing target_date: $e');
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadTabungan();
  }

  @override
  void didUpdateWidget(covariant InfoCardTabungan oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount != widget.amount ||
        oldWidget.targetAmount != widget.targetAmount ||
        oldWidget.targetDate != widget.targetDate) {
      _loadTabungan();
    }
  }

  Future<void> _saveTabungan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = tabunganList.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList('tabungan', data);
    } catch (e) {
      debugPrint('Error saving tabungan: $e');
    }
  }

  Future<void> _loadTabungan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList('tabungan') ?? [];
      final loadedTarget = prefs.getInt('target_amount') ?? 0;
      final loadedDate = _parseTargetDateFromPrefs(prefs);

      if (mounted) {
        setState(() {
          tabunganList =
              data.map((e) => Tabungan.fromJson(jsonDecode(e))).toList();
          _localTargetAmount = loadedTarget;
          _localTargetDate = loadedDate;
        });
      }
    } catch (e) {
      debugPrint('Error loading tabungan: $e');
    }
  }

  int get effectiveTargetAmount {
    if (widget.targetAmount != null && widget.targetAmount! > 0) {
      return widget.targetAmount!;
    }
    if (_localTargetAmount > 0) {
      return _localTargetAmount;
    }
    // Jika tidak ada target global, hitung akumulasi target per pos jika ada
    final sumPosTarget = tabunganList.fold<int>(
      0,
      (sum, item) => sum + (item.targetNominal ?? 0),
    );
    return sumPosTarget;
  }

  DateTime? get effectiveTargetDate => widget.targetDate ?? _localTargetDate;

  int get totalNominal {
    if (tabunganList.isNotEmpty) {
      return tabunganList.fold<int>(0, (sum, item) => sum + item.jumlah);
    }
    return int.tryParse(widget.amount) ?? 0;
  }

  int get sisaTarget {
    if (effectiveTargetAmount <= 0) return 0;
    final sisa = effectiveTargetAmount - totalNominal;
    return sisa < 0 ? 0 : sisa;
  }

  double get progressTabungan {
    if (effectiveTargetAmount <= 0) return 0.0;
    final p = totalNominal / effectiveTargetAmount;
    return p.clamp(0.0, 1.0);
  }

  int get persenTabungan {
    if (effectiveTargetAmount <= 0) return 0;
    return ((totalNominal / effectiveTargetAmount) * 100).round();
  }

  int get sisaHari {
    if (effectiveTargetDate == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      effectiveTargetDate!.year,
      effectiveTargetDate!.month,
      effectiveTargetDate!.day,
    );
    final diff = target.difference(today).inDays;
    if (diff < 0) return 0;
    if (diff == 0) return 1; // Deadline hari ini dihitung 1 hari
    return diff;
  }

  int get tabunganPerHari {
    if (effectiveTargetDate == null || sisaTarget <= 0) return 0;
    final days = sisaHari;
    if (days <= 0) return sisaTarget;
    return (sisaTarget / days).ceil();
  }

  void _handleOpenTargetSettings([VoidCallback? onComplete]) {
    if (widget.onEditTarget != null) {
      widget.onEditTarget!();
      if (onComplete != null) {
        onComplete();
      }
    } else {
      _showLocalEditTargetDialog(onComplete);
    }
  }

  void _showLocalEditTargetDialog([VoidCallback? onComplete]) {
    DateTime? tempTargetDate = effectiveTargetDate;
    final targetCtrl = TextEditingController(
      text: effectiveTargetAmount == 0
          ? ''
          : RupiahFormatter.format(effectiveTargetAmount),
    );

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setLocalState) {
            return AlertDialog(
              scrollable: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Edit Target Tabungan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Target Tabungan (Rp)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: targetCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      RupiahInputFormatter(),
                    ],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Contoh: 1.000.000',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Deadline Target',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogCtx,
                        initialDate: tempTargetDate ??
                            DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) {
                        setLocalState(() {
                          tempTargetDate = picked;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: Color(0xFF5E35B1),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tempTargetDate == null
                                  ? 'Pilih tanggal deadline'
                                  : DateFormat('dd MMMM yyyy')
                                      .format(tempTargetDate!),
                              style: TextStyle(
                                fontSize: 14,
                                color: tempTargetDate == null
                                    ? Colors.grey[500]
                                    : const Color(0xFF1E293B),
                                fontWeight: tempTargetDate == null
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (tempTargetDate != null)
                            InkWell(
                              onTap: () {
                                setLocalState(() {
                                  tempTargetDate = null;
                                });
                              },
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E35B1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    final newTarget = RupiahFormatter.parse(targetCtrl.text);

                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('target_amount', newTarget);
                    if (tempTargetDate != null) {
                      await prefs.setInt(
                          'target_date', tempTargetDate!.millisecondsSinceEpoch);
                    } else {
                      await prefs.remove('target_date');
                    }

                    if (mounted) {
                      setState(() {
                        _localTargetAmount = newTarget;
                        _localTargetDate = tempTargetDate;
                      });
                    }

                    widget.onChanged();
                    if (onComplete != null) onComplete();

                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTambahTabunganDialog(
      BuildContext context, VoidCallback onUpdated) {
    final namaCtrl = TextEditingController();
    final jumlahCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Tambah Pos Tabungan',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nama Pos',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: namaCtrl,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Jumlah Terkumpul',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: jumlahCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  RupiahInputFormatter(),
                ],
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF63B967),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              ),
              onPressed: () async {
                final nama = namaCtrl.text.trim();
                if (nama.isEmpty) return;

                final jumlah = RupiahFormatter.parse(jumlahCtrl.text);

                final newTabungan = Tabungan(
                  nama,
                  jumlah,
                );

                setState(() {
                  tabunganList.add(newTabungan);
                });

                await _saveTabungan();
                await RiwayatService.catatTambahTabungan(nama, jumlah);

                widget.onChanged();
                onUpdated();

                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                }
              },
              child: const Text(
                'Tambah Pos',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTabunganDialog(
      BuildContext context, int index, VoidCallback onUpdated) {
    final item = tabunganList[index];

    final namaCtrl = TextEditingController(text: item.nama);
    final jumlahCtrl = TextEditingController(
      text: RupiahFormatter.format(item.jumlah),
    );

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Edit Pos Tabungan',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nama Pos',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: namaCtrl,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Jumlah Terkumpul',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: jumlahCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  RupiahInputFormatter(),
                ],
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF63B967),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              ),
              onPressed: () async {
                final nama = namaCtrl.text.trim();
                if (nama.isEmpty) return;

                final jumlahBaru = RupiahFormatter.parse(jumlahCtrl.text);

                final namaLama = item.nama;
                final jumlahLama = item.jumlah;

                setState(() {
                  tabunganList[index] = Tabungan(
                    nama,
                    jumlahBaru,
                    targetNominal: item.targetNominal,
                    targetDate: item.targetDate,
                  );
                });

                await _saveTabungan();
                await RiwayatService.catatEditTabungan(
                  namaLama: namaLama,
                  jumlahLama: jumlahLama,
                  namaBaru: nama,
                  jumlahBaru: jumlahBaru,
                );

                widget.onChanged();
                onUpdated();

                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                }
              },
              child: const Text(
                'Simpan Perubahan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHapusTabunganDialog(
      BuildContext context, VoidCallback onUpdated) {
    final selected = <int>{};

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setLocal) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Hapus Tabungan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(dialogCtx).size.height * 0.5,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: tabunganList.asMap().entries.map((e) {
                    final i = e.key;
                    final item = e.value;
                    return CheckboxListTile(
                      value: selected.contains(i),
                      onChanged: (val) {
                        setLocal(() {
                          val! ? selected.add(i) : selected.remove(i);
                        });
                      },
                      title: Text(
                        item.nama,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                      activeColor: Colors.green,
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -4),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 0,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF63B967),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    final itemsToDelete = tabunganList
                        .asMap()
                        .entries
                        .where((e) => selected.contains(e.key))
                        .map((e) => e.value)
                        .toList();

                    setState(() {
                      tabunganList = tabunganList
                          .asMap()
                          .entries
                          .where((e) => !selected.contains(e.key))
                          .map((e) => e.value)
                          .toList();
                    });
                    await _saveTabungan();
                    for (final item in itemsToDelete) {
                      await RiwayatService.catatHapusTabungan(
                          item.nama, item.jumlah);
                    }
                    widget.onChanged();
                    onUpdated();
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                  },
                  child: const Text(
                    'Konfirmasi Hapus',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openTabunganBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // DRAG HANDLE
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // MODAL HEADER
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF5E35B1)
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.savings_rounded,
                                color: Color(0xFF5E35B1),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Detail & Kelola Tabungan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  '${tabunganList.length} item • Total ${RupiahFormatter.format(totalNominal)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.grey[600],
                          onPressed: () => Navigator.pop(bottomSheetContext),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // SCROLLABLE CONTENT
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // TARGET OVERVIEW BANNER (WITH ATUR / UBAH BUTTON)
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5E35B1).withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF5E35B1).withValues(alpha: 0.15),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5E35B1).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.flag_rounded,
                                    color: Color(0xFF5E35B1),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        effectiveTargetAmount > 0
                                            ? 'Target: ${RupiahFormatter.format(effectiveTargetAmount)}'
                                            : 'Target Belum Diatur',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        effectiveTargetDate != null
                                            ? 'Deadline: ${DateFormat('dd MMM yyyy').format(effectiveTargetDate!)} ($sisaHari hari lagi)'
                                            : (effectiveTargetAmount > 0
                                                ? 'Belum ada batas waktu deadline'
                                                : 'Ketuk Atur untuk menetapkan target'),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _handleOpenTargetSettings(
                                      () => setModalState(() {})),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5E35B1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          effectiveTargetAmount > 0
                                              ? Icons.edit_rounded
                                              : Icons.add_rounded,
                                          size: 13,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          effectiveTargetAmount > 0 ? 'Ubah' : 'Atur',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // INFO SISA TARGET & ESTIMASI NABUNG / HARI
                          Row(
                            children: [
                              // KEKURANGAN
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.savings_outlined,
                                            size: 15,
                                            color: Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 5),
                                          const Flexible(
                                            child: Text(
                                              'Kekurangan',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        effectiveTargetAmount <= 0
                                            ? 'Rp 0'
                                            : (sisaTarget == 0 && totalNominal > 0
                                                ? 'Tercapai! 🎉'
                                                : RupiahFormatter.format(sisaTarget)),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: (sisaTarget == 0 && totalNominal > 0 && effectiveTargetAmount > 0)
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // NABUNG / HARI
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFBBF7D0),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.trending_up_rounded,
                                            size: 15,
                                            color: Color(0xFF16A34A),
                                          ),
                                          const SizedBox(width: 5),
                                          const Flexible(
                                            child: Text(
                                              'Nabung / Hari',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF16A34A),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        effectiveTargetDate == null
                                            ? '-'
                                            : RupiahFormatter.format(tabunganPerHari),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF16A34A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // DAFTAR TABUNGAN SUBHEADER
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Daftar Tabungan',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              Text(
                                'Tahan/Ketuk untuk edit',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // LIST ITEM TABUNGAN
                          if (tabunganList.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 24, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.savings_outlined,
                                    size: 32,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Belum ada data tabungan',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tekan tombol Tambah di bawah untuk mulai menabung',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context)
                                  .copyWith(scrollbars: false),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: tabunganList.length > 3
                                      ? 165
                                      : double.infinity,
                                ),
                                child: ReorderableListView.builder(
                                  shrinkWrap: true,
                                  physics: tabunganList.length > 3
                                      ? const ClampingScrollPhysics()
                                      : const NeverScrollableScrollPhysics(),
                                  buildDefaultDragHandles: false,
                                  itemCount: tabunganList.length,
                                  proxyDecorator:
                                      (child, index, animation) {
                                    return AnimatedBuilder(
                                      animation: animation,
                                      builder: (context, child) {
                                        return Material(
                                          elevation: 4,
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          shadowColor: Colors.black
                                              .withValues(alpha: 0.15),
                                          child: child,
                                        );
                                      },
                                      child: child,
                                    );
                                  },
                                  onReorderItem: (oldIndex, newIndex) async {
                                    if (oldIndex == newIndex) return;
                                    setState(() {
                                      final item =
                                          tabunganList.removeAt(oldIndex);
                                      tabunganList.insert(newIndex, item);
                                    });
                                    await _saveTabungan();
                                    widget.onChanged();
                                    setModalState(() {});
                                  },
                                  itemBuilder: (context, index) {
                                    final item = tabunganList[index];
                                    final hasTarget = item.targetNominal != null && item.targetNominal! > 0;
                                    return Container(
                                      key: ValueKey(
                                          'tabungan_${item.nama}_${item.jumlah}_${item.targetNominal ?? 0}'),
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFF5E35B1)
                                              .withValues(alpha: 0.2),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF5E35B1)
                                                .withValues(alpha: 0.03),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          splashColor: const Color(0xFF5E35B1)
                                              .withValues(alpha: 0.08),
                                          highlightColor:
                                              const Color(0xFF5E35B1)
                                                  .withValues(alpha: 0.04),
                                          onLongPress: () {
                                            _showEditTabunganDialog(
                                              context,
                                              index,
                                              () => setModalState(() {}),
                                            );
                                          },
                                          onTap: () {
                                            _showEditTabunganDialog(
                                              context,
                                              index,
                                              () => setModalState(() {}),
                                            );
                                          },
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: hasTarget ? 10 : 9),
                                            child: Row(
                                              crossAxisAlignment: hasTarget
                                                  ? CrossAxisAlignment.start
                                                  : CrossAxisAlignment.center,
                                              children: [
                                                ReorderableDragStartListener(
                                                  index: index,
                                                  child: Padding(
                                                    padding: EdgeInsets.only(
                                                        right: 8,
                                                        top: hasTarget ? 2 : 0),
                                                    child: Icon(
                                                      Icons
                                                          .drag_indicator_rounded,
                                                      size: 18,
                                                      color: Colors.grey[400],
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: hasTarget
                                                      ? Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment.start,
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    '${item.nama} : ${RupiahFormatter.format(item.jumlah)}',
                                                                    style: const TextStyle(
                                                                      fontSize: 14,
                                                                      color: Color(0xFF1E293B),
                                                                      fontWeight:
                                                                          FontWeight.w600,
                                                                    ),
                                                                    overflow:
                                                                        TextOverflow.ellipsis,
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 6),
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(
                                                                      horizontal: 6, vertical: 2),
                                                                  decoration: BoxDecoration(
                                                                    color: item.progress >= 1.0
                                                                        ? const Color(0xFF63B967).withValues(alpha: 0.15)
                                                                        : const Color(0xFF5E35B1).withValues(alpha: 0.1),
                                                                    borderRadius: BorderRadius.circular(6),
                                                                  ),
                                                                  child: Text(
                                                                    '${item.percentage}%',
                                                                    style: TextStyle(
                                                                      fontSize: 11,
                                                                      fontWeight: FontWeight.bold,
                                                                      color: item.progress >= 1.0
                                                                          ? const Color(0xFF2E7D32)
                                                                          : const Color(0xFF5E35B1),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 6),
                                                            ClipRRect(
                                                              borderRadius: BorderRadius.circular(3),
                                                              child: LinearProgressIndicator(
                                                                value: item.progress.clamp(0.0, 1.0),
                                                                minHeight: 4,
                                                                backgroundColor: Colors.grey[200],
                                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                                  item.progress >= 1.0
                                                                      ? const Color(0xFF63B967)
                                                                      : const Color(0xFF5E35B1),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment.spaceBetween,
                                                              children: [
                                                                Text(
                                                                  'Target: ${RupiahFormatter.format(item.targetNominal!)}',
                                                                  style: TextStyle(
                                                                    fontSize: 11,
                                                                    color: Colors.grey[600],
                                                                  ),
                                                                ),
                                                                if (item.targetDate != null)
                                                                  Text(
                                                                    DateFormat('d MMM yyyy', 'id_ID').format(item.targetDate!),
                                                                    style: TextStyle(
                                                                      fontSize: 11,
                                                                      color: Colors.grey[500],
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ],
                                                        )
                                                      : Text(
                                                          '${item.nama} : ${RupiahFormatter.format(item.jumlah)}',
                                                          style: const TextStyle(
                                                            fontSize: 14,
                                                            color: Color(0xFF1E293B),
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                ),
                                                Padding(
                                                  padding: EdgeInsets.only(
                                                      left: 4,
                                                      top: hasTarget ? 2 : 0),
                                                  child: Icon(
                                                    Icons.edit_outlined,
                                                    size: 15,
                                                    color: Colors.grey[400],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                          const SizedBox(height: 16),

                          // BUTTONS TAMBAH & HAPUS
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF63B967),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                  icon: const Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 18),
                                  label: const Text(
                                    'Tambah',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () {
                                    _showTambahTabunganDialog(
                                      context,
                                      () => setModalState(() {}),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF5350),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                  icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18),
                                  label: const Text(
                                    'Hapus',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () {
                                    _showHapusTabunganDialog(
                                      context,
                                      () => setModalState(() {}),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF5E35B1).withValues(alpha: 0.18),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5E35B1).withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openTabunganBottomSheet,
          borderRadius: BorderRadius.circular(20),
          splashColor: const Color(0xFF5E35B1).withValues(alpha: 0.05),
          highlightColor: const Color(0xFF5E35B1).withValues(alpha: 0.03),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Header Target & Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5E35B1)
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.flag_rounded,
                              color: Color(0xFF5E35B1),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (tabunganList.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF5E35B1)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${tabunganList.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF5E35B1),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tombol Atur Target
                        InkWell(
                          onTap: _handleOpenTargetSettings,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5E35B1)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF5E35B1)
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit_rounded,
                                  size: 13,
                                  color: Color(0xFF5E35B1),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Atur',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF5E35B1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Slide-up Sheet Action Indicator
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5E35B1)
                                .withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: Color(0xFF5E35B1),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Total Tabungan Terkumpul (Main Primary Nominal) & Sisa Waktu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        RupiahFormatter.format(totalNominal),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (effectiveTargetDate != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: sisaHari <= 7
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 12,
                              color: sisaHari <= 7
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$sisaHari Hari Lagi',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: sisaHari <= 7
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 4),

                // Target info, Kekurangan, & percentage
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              effectiveTargetAmount > 0
                                  ? 'Target: ${RupiahFormatter.format(effectiveTargetAmount)}'
                                  : 'Belum ada target',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '• ',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const Text(
                            'Kekurangan',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            ': ${RupiahFormatter.format(sisaTarget)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$persenTabungan%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5E35B1),
                      ),
                    ),
                  ],
                ),

                if (effectiveTargetDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Deadline: ${DateFormat('dd MMMM yyyy').format(effectiveTargetDate!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 10),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressTabungan,
                    minHeight: 8,
                    backgroundColor:
                        const Color(0xFF5E35B1).withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF5E35B1),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Subtle Interactive Hint Chip (Opens slide from bottom)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5E35B1).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.vertical_align_top_rounded,
                        size: 14,
                        color: Color(0xFF5E35B1),
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Ketuk untuk Buka Rincian & Kelola Tabungan',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5E35B1),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
