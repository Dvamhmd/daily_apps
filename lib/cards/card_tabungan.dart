import 'dart:convert';
import 'package:daily_apps/models/model_tabungan.dart';
import 'package:daily_apps/utils/riwayat_service.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InfoCardTabungan extends StatefulWidget {
  final String title;
  final String amount;
  final List<Map<String, String>> items;
  final VoidCallback onChanged;

  const InfoCardTabungan({
    super.key,
    required this.title,
    required this.amount,
    required this.items,
    required this.onChanged,
  });

  @override
  State<InfoCardTabungan> createState() => _InfoCardTabunganState();
}

class _InfoCardTabunganState extends State<InfoCardTabungan> {
  bool isExpanded = false;
  List<Tabungan> tabunganList = [];

  @override
  void initState() {
    super.initState();
    _loadTabungan();
  }

  Future<void> _saveTabungan() async {
    final prefs = await SharedPreferences.getInstance();
    final data = tabunganList.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('tabungan', data);
  }

  Future<void> _loadTabungan() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('tabungan') ?? [];

    setState(() {
      tabunganList =
          data.map((e) => Tabungan.fromJson(jsonDecode(e))).toList();
    });
  }

  void showTambahTabungan() {
    final namaCtrl = TextEditingController();
    final jumlahCtrl = TextEditingController();
    final targetNominalCtrl = TextEditingController();
    DateTime? selectedTargetDate;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.savings_rounded,
                  color: Color(0xFF2E7D32),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tambah Tabungan',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nama Pos Tabungan',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: namaCtrl,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Misal: Liburan, Beli Laptop, Darurat',
                      hintStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w400,
                        color: Colors.blueGrey,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Jumlah Saat Ini (Terkumpul)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: jumlahCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      RupiahInputFormatter(),
                    ],
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Jumlah terkumpul saat ini',
                      hintStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w400,
                        color: Colors.blueGrey,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Target Nominal (Opsional)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: targetNominalCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      RupiahInputFormatter(),
                    ],
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Misal: 5.000.000',
                      hintStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w400,
                        color: Colors.blueGrey,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Target Tanggal Capaian (Opsional)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedTargetDate ?? now,
                        firstDate: now,
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedTargetDate = picked;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: selectedTargetDate != null
                                    ? const Color(0xFF2E7D32)
                                    : Colors.blueGrey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                selectedTargetDate != null
                                    ? '${selectedTargetDate!.day}/${selectedTargetDate!.month}/${selectedTargetDate!.year}'
                                    : 'Pilih target tanggal',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: selectedTargetDate != null
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: selectedTargetDate != null
                                      ? const Color(0xFF1E293B)
                                      : Colors.blueGrey,
                                ),
                              ),
                            ],
                          ),
                          if (selectedTargetDate != null)
                            InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedTargetDate = null;
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
                  onPressed: () {
                    final nama = namaCtrl.text.trim();
                    final jumlahText = jumlahCtrl.text.replaceAll('.', '');
                    final targetClean =
                        targetNominalCtrl.text.replaceAll('.', '');

                    if (nama.isEmpty || jumlahText.isEmpty) return;

                    final jumlah = int.parse(jumlahText);
                    final targetNominal = targetClean.isNotEmpty
                        ? int.parse(targetClean)
                        : null;

                    setState(() {
                      tabunganList.add(
                        Tabungan(
                          nama,
                          jumlah,
                          targetNominal: targetNominal,
                          targetDate: selectedTargetDate,
                        ),
                      );
                    });

                    _saveTabungan();
                    RiwayatService.catatTambahTabungan(nama, jumlah);
                    widget.onChanged();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Tambah Tabungan',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
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

  void showEditTabungan(int index) {
    final item = tabunganList[index];

    final namaCtrl = TextEditingController(text: item.nama);
    final jumlahCtrl = TextEditingController(
      text: RupiahFormatter.format(item.jumlah),
    );
    final targetNominalCtrl = TextEditingController(
      text: item.targetNominal != null
          ? RupiahFormatter.format(item.targetNominal!)
          : '',
    );
    DateTime? selectedTargetDate = item.targetDate;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Edit Tabungan',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nama Pos Tabungan',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: namaCtrl,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Nama pos / sumber',
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Jumlah Saat Ini (Terkumpul)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: jumlahCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      RupiahInputFormatter(),
                    ],
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Jumlah',
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Target Nominal (Opsional)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: targetNominalCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      RupiahInputFormatter(),
                    ],
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Target Nominal',
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Target Tanggal Capaian (Opsional)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedTargetDate ?? now,
                        firstDate: now,
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedTargetDate = picked;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: selectedTargetDate != null
                                    ? const Color(0xFF2E7D32)
                                    : Colors.blueGrey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                selectedTargetDate != null
                                    ? '${selectedTargetDate!.day}/${selectedTargetDate!.month}/${selectedTargetDate!.year}'
                                    : 'Pilih target tanggal',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: selectedTargetDate != null
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: selectedTargetDate != null
                                      ? const Color(0xFF1E293B)
                                      : Colors.blueGrey,
                                ),
                              ),
                            ],
                          ),
                          if (selectedTargetDate != null)
                            InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedTargetDate = null;
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
                  onPressed: () {
                    final nama = namaCtrl.text.trim();
                    final jumlahClean =
                        jumlahCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                    final targetClean = targetNominalCtrl.text
                        .replaceAll(RegExp(r'[^0-9]'), '');

                    if (nama.isEmpty || jumlahClean.isEmpty) return;

                    final namaLama = item.nama;
                    final jumlahLama = item.jumlah;
                    final jumlahBaru = int.parse(jumlahClean);
                    final targetNominal = targetClean.isNotEmpty
                        ? int.parse(targetClean)
                        : null;

                    setState(() {
                      tabunganList[index] = Tabungan(
                        nama,
                        jumlahBaru,
                        targetNominal: targetNominal,
                        targetDate: selectedTargetDate,
                      );
                    });

                    _saveTabungan();
                    RiwayatService.catatEditTabungan(
                      namaLama: namaLama,
                      jumlahLama: jumlahLama,
                      namaBaru: nama,
                      jumlahBaru: jumlahBaru,
                    );
                    widget.onChanged();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Simpan Perubahan',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
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

  void showHapusTabungan() {
    final selected = <int>{};

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Hapus Tabungan',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Column(
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
                    style: GoogleFonts.poppins(
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
                  onPressed: () {
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
                    _saveTabungan();
                    for (final item in itemsToDelete) {
                      RiwayatService.catatHapusTabungan(item.nama, item.jumlah);
                    }
                    widget.onChanged();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Konfirmasi Hapus',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9), // Soft Mint / Green
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF63B967).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER
          InkWell(
            onTap: () {
              setState(() {
                isExpanded = !isExpanded;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.savings_rounded,
                      color: Color(0xFF2E7D32),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: const Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: const Color(0xFF2E7D32),
                  size: 22,
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          /// TOTAL TABUNGAN
          Text(
            RupiahFormatter.format(int.parse(widget.amount)),
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),

          /// EXPAND CONTENT
          AnimatedCrossFade(
            firstChild: const SizedBox(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (tabunganList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Belum ada pos tabungan. Klik Tambah untuk memasukkan uang tabungan.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                /// LIST TABUNGAN
                ...tabunganList.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final hasTarget =
                      item.targetNominal != null && item.targetNominal! > 0;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      splashColor: Colors.green.withValues(alpha: 0.2),
                      highlightColor: Colors.green.withValues(alpha: 0.1),
                      onLongPress: () {
                        showEditTabungan(index);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.circle,
                                    size: 7, color: Color(0xFF63B967)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${item.nama} : ${RupiahFormatter.format(item.jumlah)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (hasTarget)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E7D32)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${item.percentage}%',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (hasTarget) ...[
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 15),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: item.progress,
                                        backgroundColor: Colors.grey[300],
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF2E7D32),
                                        ),
                                        minHeight: 6,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Target: ${RupiahFormatter.format(item.targetNominal!)}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        if (item.targetDate != null)
                                          Text(
                                            item.sisaHari != null &&
                                                    item.sisaHari! >= 0
                                                ? 's/d ${item.targetDate!.day}/${item.targetDate!.month}/${item.targetDate!.year} (${item.sisaHari} hari)'
                                                : 'Target lewat',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 8),

                /// BUTTONS
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF63B967),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                        ),
                        onPressed: showTambahTabungan,
                        child: Text(
                          'Tambah',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (tabunganList.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD46A6A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                          ),
                          onPressed: showHapusTabungan,
                          child: Text(
                            'Hapus',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}
