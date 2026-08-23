import 'package:daily_apps/models/model_tagihan.dart';
import 'package:daily_apps/models/model_uangku.dart';
import 'package:daily_apps/utils/notification_service.dart';
import 'package:daily_apps/utils/riwayat_service.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class InfoCardTagihan extends StatefulWidget {
  final String title;
  final String amount;
  final List<Map<String, String>> items;
  final VoidCallback onChanged;
  final DateTime? selectedMonth;

  const InfoCardTagihan({
    super.key,
    required this.title,
    required this.amount,
    required this.items,
    required this.onChanged,
    this.selectedMonth,
  });

  @override
  State<InfoCardTagihan> createState() => _InfoCardExpandableState();
}

class _InfoCardExpandableState extends State<InfoCardTagihan> {
  bool isExpanded = false;
  List<Tagihan> tagihanList = [];

  String get _monthKey {
    final d = widget.selectedMonth ?? DateTime.now();
    return '${d.year}_${d.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadTagihan();
  }

  @override
  void didUpdateWidget(covariant InfoCardTagihan oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth != widget.selectedMonth ||
        oldWidget.amount != widget.amount) {
      _loadTagihan();
    }
  }

  Future<void> _saveTagihan() async {
    final prefs = await SharedPreferences.getInstance();
    final data = tagihanList
        .map((e) => jsonEncode(e.toJson()))
        .toList();
    await prefs.setStringList('tagihan_$_monthKey', data);
  }

  Future<void> _loadTagihan() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'tagihan_$_monthKey';
    var data = prefs.getStringList(key);

    // Migrasi data legacy jika bulan ini belum punya data tapi ada data di 'tagihan'
    if (data == null) {
      final now = DateTime.now();
      final d = widget.selectedMonth ?? now;
      if (d.year == now.year && d.month == now.month) {
        final legacy = prefs.getStringList('tagihan');
        if (legacy != null) {
          data = legacy;
          await prefs.setStringList(key, legacy);
        }
      }
    }

    data ??= [];

    if (!mounted) return;
    setState(() {
      tagihanList = data!
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
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: namaCtrl,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'nama',
                    hintStyle: TextStyle(
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'jumlah',
                    hintStyle: TextStyle(
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
                            style: TextStyle(
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
                    RiwayatService.catatTambahTagihan(
                      nama,
                      jumlah,
                      bulan: widget.selectedMonth ?? DateTime.now(),
                    );
                    widget.onChanged();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Tambah Tagihan',
                    style: TextStyle(
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
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: namaCtrl,
                  style: TextStyle(
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
                  style: TextStyle(
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
                            style: TextStyle(
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
                      bulan: widget.selectedMonth ?? DateTime.now(),
                    );
                    widget.onChanged();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Simpan Perubahan',
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

  Future<void> showBayarTagihan(Tagihan item, int index) async {
    final prefs = await SharedPreferences.getInstance();
    final uKey = 'uangku_$_monthKey';
    var rawUangku = prefs.getStringList(uKey);
    if (rawUangku == null) {
      final now = DateTime.now();
      final d = widget.selectedMonth ?? now;
      if (d.year == now.year && d.month == now.month) {
        rawUangku = prefs.getStringList('uangku');
        if (rawUangku != null) {
          await prefs.setStringList(uKey, rawUangku);
        }
      }
    }
    rawUangku ??= [];
    List<Uangku> listUangku =
        rawUangku.map((e) => Uangku.fromJson(jsonDecode(e))).toList();

    if (!mounted) return;

    if (listUangku.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Belum ada pos Uangku untuk membayar tagihan ini.',
            style: TextStyle(),
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
                    style: TextStyle(
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sisa Tagihan: ${RupiahFormatter.format(item.jumlah)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: const Color(0xFFE65100),
                          ),
                        ),
                        if (item.formattedDeadline != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Jatuh Tempo: ${item.formattedDeadline}',
                            style: TextStyle(
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
                    style: TextStyle(
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
                          child: Material(
                            color: isSelected
                                ? const Color(0xFF5E35B1).withValues(alpha: 0.08)
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
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
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'Saldo: ${RupiahFormatter.format(u.jumlah)} $statusLabel',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: statusColor,
                                  fontWeight: FontWeight.w500,
                                ),
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
                        style: TextStyle(
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
                          style: TextStyle(
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
                    style: TextStyle(
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
                  style: TextStyle(
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
                          style: TextStyle(),
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
                          style: TextStyle(),
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
                          style: TextStyle(),
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
                      chosenUangku.copyWith(jumlah: sisaSaldo);
                  await prefs.setStringList(
                    'uangku_$_monthKey',
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
                    final bSuffix = RiwayatService.formatBulanSuffix(
                        widget.selectedMonth ?? DateTime.now());
                    await RiwayatService.catatRiwayat(
                      kategori: 'Tagihan',
                      perubahan:
                          '$namaFormat dibayar sebagian ${RupiahFormatter.format(nominalBayar)} (sisa ${RupiahFormatter.format(sisaTagihan)}) dari $sumberFormat$bSuffix',
                      tipe: 'kurang',
                      nominal: nominalBayar,
                    );

                    await RiwayatService.catatRiwayat(
                      kategori: 'Uangku',
                      perubahan:
                          '$sumberFormat ${RupiahFormatter.format(nominalBayar)} dikurangi untuk bayar tagihan $namaFormat$bSuffix',
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
                            style: TextStyle(),
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
                    final bSuffix = RiwayatService.formatBulanSuffix(
                        widget.selectedMonth ?? DateTime.now());
                    final jumlahFormat = RupiahFormatter.format(item.jumlah);
                    await RiwayatService.catatRiwayat(
                      kategori: 'Tagihan',
                      perubahan:
                          '$namaFormat $jumlahFormat lunas dibayar (dari $sumberFormat)$bSuffix',
                      tipe: 'hapus',
                      nominal: item.jumlah,
                    );

                    await RiwayatService.catatRiwayat(
                      kategori: 'Uangku',
                      perubahan:
                          '$sumberFormat $jumlahFormat dikurangi untuk bayar tagihan $namaFormat$bSuffix',
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
                            style: TextStyle(),
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
                  style: TextStyle(
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
              style: TextStyle(fontWeight: FontWeight.bold),
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
                    style: TextStyle(
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
                      RiwayatService.catatHapusTagihan(
                        item.nama,
                        item.jumlah,
                        bulan: widget.selectedMonth ?? DateTime.now(),
                      );
                    }
                    widget.onChanged();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Konfirmasi Hapus',
                    style: TextStyle(
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3EC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFDBA74),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
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
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: Color(0xFFE11D48),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF9F1239),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (tagihanList.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${tagihanList.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE11D48),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9F1239).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF9F1239),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          /// TOTAL
          Text(
            RupiahFormatter.format(int.parse(widget.amount)),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),

          /// EXPAND CONTENT
          AnimatedCrossFade(
            firstChild: const SizedBox(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                /// LIST TAGIHAN
                if (tagihanList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Text(
                        'Belum ada data tagihan',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: tagihanList.length,
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          return Material(
                            elevation: 4,
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            shadowColor: Colors.black.withValues(alpha: 0.15),
                            child: child,
                          );
                        },
                        child: child,
                      );
                    },
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final item = tagihanList.removeAt(oldIndex);
                        tagihanList.insert(newIndex, item);
                      });
                      _saveTagihan();
                      widget.onChanged();
                    },
                    itemBuilder: (context, index) {
                      final item = tagihanList[index];
                      return Container(
                        key: ValueKey('${item.nama}_${item.jumlah}_$index'),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFDBA74)
                                .withValues(alpha: 0.6),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEA580C)
                                  .withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            splashColor:
                                const Color(0xFFE11D48).withValues(alpha: 0.1),
                            highlightColor:
                                const Color(0xFFE11D48).withValues(alpha: 0.05),
                            onLongPress: () {
                              showEditTagihan(index);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Icon(
                                        Icons.drag_indicator_rounded,
                                        size: 18,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item.nama} : ${RupiahFormatter.format(item.jumlah)}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF1E293B),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (item.formattedDeadline != null) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.event_rounded,
                                                size: 12,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Tempo: ${item.formattedDeadline!}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Quick "Bayar" Chip Button
                                  InkWell(
                                    onTap: () => showBayarTagihan(item, index),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2E7D32)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFF2E7D32)
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 14,
                                            color: Color(0xFF2E7D32),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Bayar',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2E7D32),
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
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 10),

                /// BUTTONS
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF63B967),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.add_circle_outline_rounded,
                            size: 18),
                        label: const Text(
                          'Tambah',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: showTambahTagihan,
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
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text(
                          'Hapus',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: showHapusTagihan,
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
