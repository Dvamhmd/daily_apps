import 'package:daily_apps/models/model_tagihan.dart';
import 'package:daily_apps/models/model_uangku.dart';
import 'package:daily_apps/utils/notification_service.dart';
import 'package:daily_apps/utils/riwayat_service.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class InfoCardTagihan extends StatefulWidget {
  final String title;
  final String amount;
  final List<Map<String, String>> items;
  final VoidCallback onChanged;



  const InfoCardTagihan({
    super.key,
    required this.title,
    required this.amount,
    required this.items,
    required this.onChanged
  });

  @override
  State<InfoCardTagihan> createState() => _InfoCardExpandableState();
}

class _InfoCardExpandableState extends State<InfoCardTagihan> {
  bool isExpanded = false;
  List<Tagihan> tagihanList = [];

  @override
  void initState() {
    super.initState();
    _loadTagihan();
  }

  @override
  void didUpdateWidget(covariant InfoCardTagihan oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadTagihan();
  }

  Future<void> _saveTagihan() async {
    final prefs = await SharedPreferences.getInstance();
    final data = tagihanList
        .map((e) => jsonEncode(e.toJson()))
        .toList();
    await prefs.setStringList('tagihan', data);
  }

  Future<void> _loadTagihan() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('tagihan') ?? [];

    setState(() {
      tagihanList = data
          .map((e) => Tagihan.fromJson(jsonDecode(e)))
          .toList();
    });
  }

  void showTambahTagihan() {
    final namaCtrl = TextEditingController();
    final jumlahCtrl = TextEditingController();
    DateTime? selectedDeadline;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Tambah Tagihan',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: namaCtrl,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'nama',
                    hintStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        color: Colors.blueGrey
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
                TextField(
                  controller: jumlahCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    RupiahInputFormatter(),
                  ],
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'jumlah',
                    hintStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        color: Colors.blueGrey
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
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final initial = (selectedDeadline != null &&
                            !selectedDeadline!.isBefore(today))
                        ? selectedDeadline!
                        : today;

                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: today,
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDeadline = picked;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          size: 20,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedDeadline == null
                                ? 'Pilih Deadline (Opsional)'
                                : DateFormat('dd/MM/yyyy')
                                    .format(selectedDeadline!),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: selectedDeadline == null
                                  ? Colors.blueGrey
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        if (selectedDeadline != null)
                          GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedDeadline = null;
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

                    if (nama.isEmpty || jumlahText.isEmpty) return;

                    final jumlah = int.parse(jumlahText);

                    final newTagihan = Tagihan(
                      nama,
                      jumlah,
                      deadline: selectedDeadline,
                    );

                    setState(() {
                      tagihanList.add(newTagihan);
                    });

                    _saveTagihan();
                    NotificationService.jadwalkanTagihan(newTagihan);
                    RiwayatService.catatTambahTagihan(nama, jumlah);
                    widget.onChanged();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Tambah Tagihan',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 18
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

  void showEditTagihan(int index) {
    final item = tagihanList[index];

    final namaCtrl = TextEditingController(text: item.nama);
    final jumlahCtrl = TextEditingController(
      text: RupiahFormatter.format(item.jumlah),
    );
    DateTime? selectedDeadline = item.deadline;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Edit Tagihan',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: namaCtrl,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nama',
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: jumlahCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    RupiahInputFormatter(),
                  ],
                  style: GoogleFonts.poppins(
                    fontSize: 16,
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
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final initial = (selectedDeadline != null &&
                            !selectedDeadline!.isBefore(today))
                        ? selectedDeadline!
                        : today;

                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: today,
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDeadline = picked;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          size: 20,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedDeadline == null
                                ? 'Pilih Deadline (Opsional)'
                                : DateFormat('dd/MM/yyyy')
                                    .format(selectedDeadline!),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: selectedDeadline == null
                                  ? Colors.blueGrey
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        if (selectedDeadline != null)
                          GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedDeadline = null;
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

                    if (nama.isEmpty || jumlahClean.isEmpty) return;

                    final namaLama = item.nama;
                    final jumlahLama = item.jumlah;
                    final jumlahBaru = int.parse(jumlahClean);

                    final editedTagihan = Tagihan(
                      nama,
                      jumlahBaru,
                      deadline: selectedDeadline,
                    );

                    setState(() {
                      tagihanList[index] = editedTagihan;
                    });

                    _saveTagihan();
                    NotificationService.batalkanTagihan(item);
                    NotificationService.jadwalkanTagihan(editedTagihan);

                    RiwayatService.catatEditTagihan(
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

  Future<void> showBayarTagihan(Tagihan item, int index) async {
    final prefs = await SharedPreferences.getInstance();
    final rawUangku = prefs.getStringList('uangku') ?? [];
    List<Uangku> listUangku =
        rawUangku.map((e) => Uangku.fromJson(jsonDecode(e))).toList();

    if (!mounted) return;

    if (listUangku.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Belum ada pos Uangku untuk membayar tagihan ini.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFFD46A6A),
        ),
      );
      return;
    }

    int selectedUangkuIndex = 0;
    final nominalCtrl = TextEditingController(
      text: RupiahFormatter.format(item.jumlah),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentNominalClean =
              nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
          final currentNominal = int.tryParse(currentNominalClean) ?? 0;
          final isLunas = currentNominal >= item.jumlah;
          final labelText = isLunas ? 'Lunas' : 'dicicil :v';
          final labelColor = isLunas
              ? const Color(0xFF2E7D32)
              : const Color(0xFFE65100);

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF2E7D32),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bayar Tagihan',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.nama,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sisa Tagihan: ${RupiahFormatter.format(item.jumlah)}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: const Color(0xFFE65100),
                          ),
                        ),
                        if (item.formattedDeadline != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Jatuh Tempo: ${item.formattedDeadline}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Pilih Sumber Dana (Uangku):',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioGroup<int>(
                    groupValue: selectedUangkuIndex,
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedUangkuIndex = val);
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: listUangku.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final u = entry.value;
                        final isSelected = selectedUangkuIndex == idx;
                        final isZero = u.jumlah <= 0;

                        String statusLabel;
                        Color statusColor;
                        if (isZero) {
                          statusLabel = '(Saldo 0)';
                          statusColor = const Color(0xFFD46A6A);
                        } else if (u.jumlah < item.jumlah) {
                          statusLabel = '(Saldo < Tagihan)';
                          statusColor = const Color(0xFFE65100);
                        } else {
                          statusLabel = '(Cukup)';
                          statusColor = const Color(0xFF2E7D32);
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF5E35B1).withValues(alpha: 0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF5E35B1)
                                  : Colors.grey[300]!,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: RadioListTile<int>(
                            value: idx,
                            activeColor: const Color(0xFF5E35B1),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 0),
                            dense: true,
                            title: Text(
                              u.nama,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Saldo: ${RupiahFormatter.format(u.jumlah)} $statusLabel',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Jumlah Pembayaran :',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          labelText,
                          key: ValueKey<String>(labelText),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: labelColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nominalCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      RupiahInputFormatter(),
                    ],
                    onChanged: (_) {
                      setModalState(() {});
                    },
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Masukkan nominal',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Batal',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  final chosenUangku = listUangku[selectedUangkuIndex];

                  if (chosenUangku.jumlah <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Saldo "${chosenUangku.nama}" Rp 0, tidak ada saldo yang dapat digunakan untuk membayar.',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: const Color(0xFFD46A6A),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  final jumlahClean = nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                  final nominalBayarTarget = int.tryParse(jumlahClean) ?? 0;

                  if (nominalBayarTarget <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Masukkan nominal pembayaran yang valid (lebih dari 0).',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: const Color(0xFFD46A6A),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  if (nominalBayarTarget > item.jumlah) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Nominal pembayaran tidak boleh melebihi sisa tagihan (${RupiahFormatter.format(item.jumlah)}).',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: const Color(0xFFD46A6A),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  // Batasi pembayaran maksimal sebesar saldo Uangku yang tersedia (agar tidak minus)
                  final nominalBayar = (nominalBayarTarget > chosenUangku.jumlah)
                      ? chosenUangku.jumlah
                      : nominalBayarTarget;

                  final namaFormat = RiwayatService.capitalize(item.nama);
                  final sumberFormat =
                      RiwayatService.capitalize(chosenUangku.nama);

                  final sisaSaldo = chosenUangku.jumlah - nominalBayar; // Minimal 0

                  // Update Saldo Uangku
                  listUangku[selectedUangkuIndex] =
                      Uangku(chosenUangku.nama, sisaSaldo);
                  await prefs.setStringList(
                    'uangku',
                    listUangku
                        .map((e) => jsonEncode(e.toJson()))
                        .toList(),
                  );

                  // Kasus 1: Bayar Sebagian (nominalBayar < item.jumlah)
                  if (nominalBayar < item.jumlah) {
                    final sisaTagihan = item.jumlah - nominalBayar;

                    // Tagihan berkurang nominalnya
                    final updatedTagihan = item.copyWith(jumlah: sisaTagihan);
                    setState(() {
                      tagihanList[index] = updatedTagihan;
                    });
                    await _saveTagihan();

                    // Jadwalkan ulang notifikasi dengan nominal baru
                    await NotificationService.jadwalkanTagihan(updatedTagihan);

                    // Catat Riwayat
                    await RiwayatService.catatRiwayat(
                      kategori: 'Tagihan',
                      perubahan:
                          '$namaFormat dibayar sebagian ${RupiahFormatter.format(nominalBayar)} (sisa ${RupiahFormatter.format(sisaTagihan)}) dari $sumberFormat',
                      tipe: 'kurang',
                      nominal: nominalBayar,
                    );

                    await RiwayatService.catatRiwayat(
                      kategori: 'Uangku',
                      perubahan:
                          '$sumberFormat ${RupiahFormatter.format(nominalBayar)} dikurangi untuk bayar tagihan $namaFormat',
                      tipe: 'kurang',
                      nominal: nominalBayar,
                    );

                    widget.onChanged();
                    if (context.mounted) {
                      Navigator.pop(context);
                      final isSaldoHabis = nominalBayar < nominalBayarTarget;
                      final msg = isSaldoHabis
                          ? 'Membayar ${RupiahFormatter.format(nominalBayar)} (seluruh saldo $sumberFormat). Sisa tagihan "$namaFormat": ${RupiahFormatter.format(sisaTagihan)}'
                          : 'Dibayar sebagian! Sisa tagihan "$namaFormat": ${RupiahFormatter.format(sisaTagihan)}';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            msg,
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: const Color(0xFFE65100),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } else {
                    // Kasus 2: Pelunasan Penuh (nominalBayar == item.jumlah)
                    // Archive Tagihan Lunas
                    final rawLunas =
                        prefs.getStringList('tagihan_lunas') ?? [];
                    final lunasItem = item.copyWith(
                      isLunas: true,
                      tanggalLunas: DateTime.now(),
                      dibayarDari: chosenUangku.nama,
                    );
                    rawLunas.insert(0, jsonEncode(lunasItem.toJson()));
                    await prefs.setStringList('tagihan_lunas', rawLunas);

                    // Remove from active Tagihan
                    setState(() {
                      tagihanList.removeAt(index);
                    });
                    await _saveTagihan();

                    // Cancel Notification
                    await NotificationService.batalkanTagihan(item);

                    // Record Riwayat
                    final jumlahFormat = RupiahFormatter.format(item.jumlah);
                    await RiwayatService.catatRiwayat(
                      kategori: 'Tagihan',
                      perubahan:
                          '$namaFormat $jumlahFormat lunas dibayar (dari $sumberFormat)',
                      tipe: 'hapus',
                      nominal: item.jumlah,
                    );

                    await RiwayatService.catatRiwayat(
                      kategori: 'Uangku',
                      perubahan:
                          '$sumberFormat $jumlahFormat dikurangi untuk bayar tagihan $namaFormat',
                      tipe: 'kurang',
                      nominal: item.jumlah,
                    );

                    widget.onChanged();
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Tagihan "$namaFormat" berhasil dilunasi!',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: const Color(0xFF2E7D32),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  'Konfirmasi Bayar',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void showHapusTagihan() {
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
              'Hapus Tagihan',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: tagihanList.asMap().entries.map((e) {
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

                  // mengatur jarak antar list
                  dense: true,
                  visualDensity: const VisualDensity(
                    vertical: -4,
                  ),
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
                    final itemsToDelete = tagihanList
                        .asMap()
                        .entries
                        .where((e) => selected.contains(e.key))
                        .map((e) => e.value)
                        .toList();

                    setState(() {
                      tagihanList = tagihanList
                          .asMap()
                          .entries
                          .where((e) => !selected.contains(e.key))
                          .map((e) => e.value)
                          .toList();
                    });
                    _saveTagihan();
                    for (final item in itemsToDelete) {
                      NotificationService.batalkanTagihan(item);
                      RiwayatService.catatHapusTagihan(item.nama, item.jumlah);
                    }
                    widget.onChanged();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Konfirmasi Hapus',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 18
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
        color: const Color(0xFFD9FAD1),
        borderRadius: BorderRadius.circular(14),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.pink,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.pink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.pink,
                  size: 22,
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          /// TOTAL
          Text(
            RupiahFormatter.format(int.parse(widget.amount)),
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),

          /// EXPAND CONTENT
          AnimatedCrossFade(
            firstChild: const SizedBox(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),

                /// LIST TAGIHAN
                ...tagihanList.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      splashColor: Colors.green.withValues(alpha: 0.2),
                      highlightColor: Colors.green.withValues(alpha: 0.1),
                      onLongPress: () {
                        showEditTagihan(index);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            const Icon(Icons.circle,
                                size: 7, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.nama} : ${RupiahFormatter.format(item.jumlah)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (item.formattedDeadline != null)
                                    Text(
                                      'Tempo: ${item.formattedDeadline!}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Quick "Bayar" Chip Button
                            InkWell(
                              onTap: () => showBayarTagihan(item, index),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E7D32)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF2E7D32)
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: Color(0xFF2E7D32),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Bayar',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF2E7D32),
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
                        onPressed: showTambahTagihan,
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
                        onPressed: showHapusTagihan,
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
