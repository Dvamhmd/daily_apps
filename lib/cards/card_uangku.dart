import 'package:daily_apps/models/model_tagihan.dart';
import 'package:daily_apps/models/model_uangku.dart';
import 'package:daily_apps/utils/riwayat_service.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class InfoCardUangku extends StatefulWidget {
  final String title;
  final String amount;
  final List<Map<String, String>> items;
  final VoidCallback onChanged;
  final DateTime? selectedMonth;
  final bool? onlyCair;
  final ValueChanged<bool>? onFilterChanged;

  const InfoCardUangku({
    super.key,
    required this.title,
    required this.amount,
    required this.items,
    required this.onChanged,
    this.selectedMonth,
    this.onlyCair,
    this.onFilterChanged,
  });

  @override
  State<InfoCardUangku> createState() => _InfoCardExpandableState();
}

class _InfoCardExpandableState extends State<InfoCardUangku> {
  bool isExpanded = false;
  bool _internalOnlyCair = false;
  List<Uangku> uangkuList = [];

  bool get onlyCair => widget.onlyCair ?? _internalOnlyCair;

  String get _monthKey {
    final d = widget.selectedMonth ?? DateTime.now();
    return '${d.year}_${d.month.toString().padLeft(2, '0')}';
  }

  int get totalSudahCair =>
      uangkuList.where((e) => e.isCair).fold<int>(0, (sum, e) => sum + e.jumlah);

  int get totalBelumCair =>
      uangkuList.where((e) => !e.isCair).fold<int>(0, (sum, e) => sum + e.jumlah);

  bool get hasBelumCair => uangkuList.any((e) => !e.isCair);

  @override
  void initState() {
    super.initState();
    _loadOnlyCair();
    _loadUangku();
  }

  Future<void> _loadOnlyCair() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _internalOnlyCair = prefs.getBool('uangku_only_cair') ?? false;
      });
    }
  }

  Future<void> _toggleOnlyCair() async {
    final newVal = !onlyCair;
    setState(() {
      _internalOnlyCair = newVal;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('uangku_only_cair', newVal);
    widget.onFilterChanged?.call(newVal);
    widget.onChanged();
  }

  @override
  void didUpdateWidget(covariant InfoCardUangku oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth != widget.selectedMonth ||
        oldWidget.onlyCair != widget.onlyCair ||
        oldWidget.amount != widget.amount) {
      _loadUangku();
    }
  }

  Future<void> _saveUangku() async {
    final prefs = await SharedPreferences.getInstance();
    final data = uangkuList
        .map((e) => jsonEncode(e.toJson()))
        .toList();
    await prefs.setStringList('uangku_$_monthKey', data);
  }

  Future<void> _loadUangku() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'uangku_$_monthKey';
    var data = prefs.getStringList(key);

    // Migrasi data legacy jika bulan ini belum punya data tapi ada data di 'uangku'
    if (data == null) {
      final now = DateTime.now();
      final d = widget.selectedMonth ?? now;
      if (d.year == now.year && d.month == now.month) {
        final legacy = prefs.getStringList('uangku');
        if (legacy != null) {
          data = legacy;
          await prefs.setStringList(key, legacy);
        }
      }
    }

    data ??= [];

    if (!mounted) return;
    setState(() {
      uangkuList = data!
          .map((e) => Uangku.fromJson(jsonDecode(e)))
          .toList();
    });
  }

  Future<void> _tambah10PersenKeTagihanDp(int nominalTambahUangku) async {
    if (nominalTambahUangku <= 0) return;
    final nominalDp = (nominalTambahUangku * 0.10).round();
    if (nominalDp <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    final tagihanKey = 'tagihan_$_monthKey';
    var data = prefs.getStringList(tagihanKey);
    if (data == null) {
      final now = DateTime.now();
      final d = widget.selectedMonth ?? now;
      if (d.year == now.year && d.month == now.month) {
        data = prefs.getStringList('tagihan');
      }
    }
    data ??= [];

    List<Tagihan> tagihanList =
        data.map((e) => Tagihan.fromJson(jsonDecode(e))).toList();

    final index = tagihanList.indexWhere(
      (t) => t.nama.trim().toLowerCase() == 'dp',
    );

    if (index != -1) {
      final itemLama = tagihanList[index];
      final totalBaru = itemLama.jumlah + nominalDp;
      tagihanList[index] = itemLama.copyWith(jumlah: totalBaru);

      final prefsData =
          tagihanList.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(tagihanKey, prefsData);

      final bSuffix = RiwayatService.formatBulanSuffix(
          widget.selectedMonth ?? DateTime.now());
      await RiwayatService.catatRiwayat(
        kategori: 'Tagihan',
        perubahan:
            '${itemLama.nama} ${RupiahFormatter.format(nominalDp)} Otomatis ditambah ke tagihan$bSuffix',
        tipe: 'tambah',
        nominal: nominalDp,
      );
    } else {
      final newDp = Tagihan('DP', nominalDp);
      tagihanList.add(newDp);

      final prefsData =
          tagihanList.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(tagihanKey, prefsData);

      final bSuffix = RiwayatService.formatBulanSuffix(
          widget.selectedMonth ?? DateTime.now());
      await RiwayatService.catatRiwayat(
        kategori: 'Tagihan',
        perubahan:
            'DP ${RupiahFormatter.format(nominalDp)} Otomatis ditambah ke tagihan$bSuffix',
        tipe: 'tambah',
        nominal: nominalDp,
      );
    }
  }

  void showTambahUangku() {
    final namaCtrl = TextEditingController();
    final jumlahCtrl = TextEditingController();
    DateTime? selectedTanggalCair;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Tambah Uangku',
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
                        color: Colors.blueGrey),
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
                        color: Colors.blueGrey),
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
                    final initial = selectedTanggalCair ?? today;

                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedTanggalCair = picked;
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
                            selectedTanggalCair == null
                                ? 'Pilih Tanggal Cair (Opsional)'
                                : DateFormat('dd/MM/yyyy')
                                    .format(selectedTanggalCair!),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: selectedTanggalCair == null
                                  ? Colors.blueGrey
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        if (selectedTanggalCair != null)
                          GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedTanggalCair = null;
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
                  onPressed: () async {
                    final nama = namaCtrl.text.trim();
                    final jumlahText =
                        jumlahCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');

                    if (nama.isEmpty || jumlahText.isEmpty) return;

                    final jumlah = int.parse(jumlahText);

                    final newUangku = Uangku(
                      nama,
                      jumlah,
                      tanggalCair: selectedTanggalCair,
                    );

                    setState(() {
                      uangkuList.add(newUangku);
                    });

                    await _saveUangku();
                    if (jumlah > 0 && newUangku.isCair) {
                      await _tambah10PersenKeTagihanDp(jumlah);
                    }
                    await RiwayatService.catatTambahUangku(
                      nama,
                      jumlah,
                      bulan: widget.selectedMonth ?? DateTime.now(),
                    );
                    widget.onChanged();
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(
                    'Tambah Uangku',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 18),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void showEditUangku(int index) {
    final item = uangkuList[index];

    final namaCtrl = TextEditingController(text: item.nama);
    final jumlahCtrl = TextEditingController(
      text: RupiahFormatter.format(item.jumlah),
    );
    DateTime? selectedTanggalCair = item.tanggalCair;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Edit Uangku',
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
                    final initial = selectedTanggalCair ?? today;

                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedTanggalCair = picked;
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
                            selectedTanggalCair == null
                                ? 'Pilih Tanggal Cair (Opsional)'
                                : DateFormat('dd/MM/yyyy')
                                    .format(selectedTanggalCair!),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: selectedTanggalCair == null
                                  ? Colors.blueGrey
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        if (selectedTanggalCair != null)
                          GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedTanggalCair = null;
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
                  onPressed: () async {
                    final nama = namaCtrl.text.trim();
                    final jumlahClean =
                        jumlahCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');

                    final namaLama = item.nama;
                    final jumlahLama = item.jumlah;
                    final itemLama = item;
                    final jumlahBaru = int.parse(jumlahClean);
                    final itemBaru = Uangku(
                      nama,
                      jumlahBaru,
                      tanggalCair: selectedTanggalCair,
                    );

                    setState(() {
                      uangkuList[index] = itemBaru;
                    });

                    await _saveUangku();
                    if (itemBaru.isCair) {
                      if (!itemLama.isCair) {
                        if (jumlahBaru > 0) {
                          await _tambah10PersenKeTagihanDp(jumlahBaru);
                        }
                      } else {
                        if (jumlahBaru > jumlahLama) {
                          final selisih = jumlahBaru - jumlahLama;
                          await _tambah10PersenKeTagihanDp(selisih);
                        }
                      }
                    }
                    await RiwayatService.catatEditUangku(
                      namaLama: namaLama,
                      jumlahLama: jumlahLama,
                      namaBaru: nama,
                      jumlahBaru: jumlahBaru,
                      bulan: widget.selectedMonth ?? DateTime.now(),
                    );
                    widget.onChanged();
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
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

  void showKelolaNominalUangku(int index) {
    final item = uangkuList[index];
    final nominalCtrl = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Kelola ${item.nama}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo saat ini: ${RupiahFormatter.format(item.jumlah)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blueGrey[700],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nominalCtrl,
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
                    hintText: 'Nominal',
                    hintStyle: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.blueGrey,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    errorText: errorText,
                    errorMaxLines: 2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    if (errorText != null) {
                      setDialogState(() {
                        errorText = null;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF63B967),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        final cleanText =
                            nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                        if (cleanText.isEmpty) {
                          setDialogState(() {
                            errorText = 'Masukkan nominal terlebih dahulu';
                          });
                          return;
                        }

                        final nominal = int.parse(cleanText);
                        if (nominal <= 0) {
                          setDialogState(() {
                            errorText = 'Nominal harus lebih dari 0';
                          });
                          return;
                        }

                        final namaLama = item.nama;
                        final jumlahLama = item.jumlah;
                        final jumlahBaru = jumlahLama + nominal;

                        setState(() {
                          uangkuList[index] =
                              item.copyWith(jumlah: jumlahBaru);
                        });

                        await _saveUangku();
                        if (item.isCair) {
                          await _tambah10PersenKeTagihanDp(nominal);
                        }
                        await RiwayatService.catatEditUangku(
                          namaLama: namaLama,
                          jumlahLama: jumlahLama,
                          namaBaru: namaLama,
                          jumlahBaru: jumlahBaru,
                          bulan: widget.selectedMonth ?? DateTime.now(),
                        );
                        widget.onChanged();
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      },
                      child: Text(
                        'Debit',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD46A6A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        final cleanText =
                            nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                        if (cleanText.isEmpty) {
                          setDialogState(() {
                            errorText = 'Masukkan nominal terlebih dahulu';
                          });
                          return;
                        }

                        final nominal = int.parse(cleanText);
                        if (nominal <= 0) {
                          setDialogState(() {
                            errorText = 'Nominal harus lebih dari 0';
                          });
                          return;
                        }

                        if (nominal > item.jumlah) {
                          setDialogState(() {
                            errorText =
                                'Nominal melebihi saldo ${item.nama} (${RupiahFormatter.format(item.jumlah)})';
                          });
                          return;
                        }

                        final namaLama = item.nama;
                        final jumlahLama = item.jumlah;
                        final jumlahBaru = jumlahLama - nominal;

                        setState(() {
                          uangkuList[index] =
                              item.copyWith(jumlah: jumlahBaru);
                        });

                        _saveUangku();
                        RiwayatService.catatEditUangku(
                          namaLama: namaLama,
                          jumlahLama: jumlahLama,
                          namaBaru: namaLama,
                          jumlahBaru: jumlahBaru,
                          bulan: widget.selectedMonth ?? DateTime.now(),
                        );
                        widget.onChanged();
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Kredit',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void showHapusUangku() {
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
              'Hapus Uangku',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: uangkuList.asMap().entries.map((e) {
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
                    final itemsToDelete = uangkuList
                        .asMap()
                        .entries
                        .where((e) => selected.contains(e.key))
                        .map((e) => e.value)
                        .toList();

                    setState(() {
                      uangkuList = uangkuList
                          .asMap()
                          .entries
                          .where((e) => !selected.contains(e.key))
                          .map((e) => e.value)
                          .toList();
                    });
                    _saveUangku();
                    for (final item in itemsToDelete) {
                      RiwayatService.catatHapusUangku(
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
                        fontSize: 18),
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
    final displayedList = onlyCair
        ? uangkuList.where((e) => e.isCair).toList()
        : uangkuList;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7E6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF86EFAC),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF15803D).withValues(alpha: 0.08),
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
                          color:
                              const Color(0xFF16A34A).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Color(0xFF16A34A),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF15803D),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (uangkuList.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${uangkuList.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF15803D).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF15803D),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          /// TOTAL & FILTER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                RupiahFormatter.format(
                  onlyCair ? totalSudahCair : int.parse(widget.amount),
                ),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              InkWell(
                onTap: _toggleOnlyCair,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: onlyCair
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF16A34A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF16A34A)
                          .withValues(alpha: onlyCair ? 1.0 : 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        onlyCair
                            ? Icons.filter_alt_rounded
                            : Icons.filter_alt_off_rounded,
                        size: 14,
                        color:
                            onlyCair ? Colors.white : const Color(0xFF15803D),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        onlyCair ? 'Cair' : 'Semua',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color:
                              onlyCair ? Colors.white : const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          /// KLASIFIKASI STATUS (Jika ada yang belum cair)
          if (hasBelumCair) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Cair: ${RupiahFormatter.format(totalSudahCair)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE65100).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE65100).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: Color(0xFFE65100),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Belum: ${RupiahFormatter.format(totalBelumCair)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          /// EXPAND CONTENT
          AnimatedCrossFade(
            firstChild: const SizedBox(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                /// LIST UANGKU
                if (displayedList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Text(
                        onlyCair
                            ? 'Tidak ada dana yang sudah cair'
                            : 'Belum ada data uangku',
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
                    itemCount: displayedList.length,
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
                      if (onlyCair) return;
                      setState(() {
                        final item = uangkuList.removeAt(oldIndex);
                        uangkuList.insert(newIndex, item);
                      });
                      _saveUangku();
                      widget.onChanged();
                    },
                    itemBuilder: (context, index) {
                      final item = displayedList[index];
                      final originalIndex = uangkuList.indexOf(item);

                      return Container(
                        key: ValueKey('${item.nama}_${item.jumlah}_$index'),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF86EFAC)
                                .withValues(alpha: 0.6),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF15803D)
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
                                const Color(0xFF16A34A).withValues(alpha: 0.1),
                            highlightColor:
                                const Color(0xFF16A34A).withValues(alpha: 0.05),
                            onLongPress: () {
                              if (originalIndex != -1) {
                                showEditUangku(originalIndex);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  if (!onlyCair)
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
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
                                        if (item.tanggalCair != null) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                item.isCair
                                                    ? Icons.check_circle_rounded
                                                    : Icons.schedule_rounded,
                                                size: 12,
                                                color: item.isCair
                                                    ? const Color(0xFF2E7D32)
                                                    : const Color(0xFFE65100),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                item.isCair
                                                    ? 'Cair • ${item.formattedTanggalCair}'
                                                    : 'Belum Cair • ${item.formattedTanggalCair}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: item.isCair
                                                      ? const Color(0xFF2E7D32)
                                                      : const Color(0xFFE65100),
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
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      if (originalIndex != -1) {
                                        showKelolaNominalUangku(originalIndex);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF63B967)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFF63B967)
                                              .withValues(alpha: 0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.exposure_rounded,
                                            size: 14,
                                            color: Color(0xFF2E7D32),
                                          ),
                                          SizedBox(width: 3),
                                          Text(
                                            '+/-',
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
                        onPressed: showTambahUangku,
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
                        onPressed: showHapusUangku,
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
