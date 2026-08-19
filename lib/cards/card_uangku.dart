import 'package:daily_apps/models/model_tagihan.dart';
import 'package:daily_apps/models/model_uangku.dart';
import 'package:daily_apps/utils/riwayat_service.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class InfoCardUangku extends StatefulWidget {
  final String title;
  final String amount;
  final List<Map<String, String>> items;
  final VoidCallback onChanged;
  final DateTime? selectedMonth;

  const InfoCardUangku({
    super.key,
    required this.title,
    required this.amount,
    required this.items,
    required this.onChanged,
    this.selectedMonth,
  });

  @override
  State<InfoCardUangku> createState() => _InfoCardExpandableState();
}

class _InfoCardExpandableState extends State<InfoCardUangku> {
  bool isExpanded = false;
  List<Uangku> uangkuList = [];

  String get _monthKey {
    final d = widget.selectedMonth ?? DateTime.now();
    return '${d.year}_${d.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadUangku();
  }

  @override
  void didUpdateWidget(covariant InfoCardUangku oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadUangku();
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

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Tambah Uangku',
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
                final jumlahText = jumlahCtrl.text.replaceAll('.', '');

                if (nama.isEmpty || jumlahText.isEmpty) return;

                final jumlah = int.parse(jumlahText);

                setState(() {
                  uangkuList.add(
                    Uangku(
                      nama,
                      jumlah,
                    ),
                  );
                });

                await _saveUangku();
                if (jumlah > 0) {
                  await _tambah10PersenKeTagihanDp(jumlah);
                }
                await RiwayatService.catatTambahUangku(
                  nama,
                  jumlah,
                  bulan: widget.selectedMonth ?? DateTime.now(),
                );
                widget.onChanged();
                if (mounted) {
                  Navigator.pop(context);
                }
              },

              child: Text(
                'Tambah Uangku',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void showEditUangku(int index) {
    final item = uangkuList[index];

    final namaCtrl = TextEditingController(text: item.nama);
    final jumlahCtrl = TextEditingController(
      text: RupiahFormatter.format(item.jumlah),
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Edit Uangku',
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

                if (nama.isEmpty || jumlahClean.isEmpty) return;

                final namaLama = item.nama;
                final jumlahLama = item.jumlah;
                final jumlahBaru = int.parse(jumlahClean);

                setState(() {
                  uangkuList[index] = Uangku(
                    nama,
                    jumlahBaru,
                  );
                });

                await _saveUangku();
                if (jumlahBaru > jumlahLama) {
                  final selisih = jumlahBaru - jumlahLama;
                  await _tambah10PersenKeTagihanDp(selisih);
                }
                await RiwayatService.catatEditUangku(
                  namaLama: namaLama,
                  jumlahLama: jumlahLama,
                  namaBaru: nama,
                  jumlahBaru: jumlahBaru,
                  bulan: widget.selectedMonth ?? DateTime.now(),
                );
                widget.onChanged();
                if (mounted) {
                  Navigator.pop(context);
                }
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
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo saat ini: ${RupiahFormatter.format(item.jumlah)}',
                  style: GoogleFonts.poppins(
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
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nominal',
                    hintStyle: GoogleFonts.poppins(
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
                          uangkuList[index] = Uangku(namaLama, jumlahBaru);
                        });

                        await _saveUangku();
                        await _tambah10PersenKeTagihanDp(nominal);
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
                        style: GoogleFonts.poppins(
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
                          uangkuList[index] = Uangku(namaLama, jumlahBaru);
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
                        style: GoogleFonts.poppins(
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
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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
                      Icons.account_balance_wallet_rounded,
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

                /// LIST UANGKU
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: uangkuList.length,
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        return Material(
                          elevation: 3,
                          color: const Color(0xFFEBFDE5),
                          borderRadius: BorderRadius.circular(8),
                          child: child,
                        );
                      },
                      child: child,
                    );
                  },
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final item = uangkuList.removeAt(oldIndex);
                      uangkuList.insert(newIndex, item);
                    });
                    _saveUangku();
                    widget.onChanged();
                  },
                  itemBuilder: (context, index) {
                    final item = uangkuList[index];
                    return Material(
                      key: ValueKey('${item.nama}_${item.jumlah}_$index'),
                      color: Colors.transparent, // penting biar warna card tetap
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        splashColor: Colors.green.withValues(alpha: 0.2),
                        highlightColor: Colors.green.withValues(alpha: 0.1),
                        onLongPress: () {
                          showEditUangku(index);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              ReorderableDragStartListener(
                                index: index,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(
                                    Icons.drag_handle_rounded,
                                    size: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                              const Icon(Icons.circle, size: 7, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${item.nama} : ${RupiahFormatter.format(item.jumlah)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => showKelolaNominalUangku(index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF63B967)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFF63B967)
                                          .withValues(alpha: 0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.exposure_rounded,
                                        size: 14,
                                        color: Color(0xFF2E7D32),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '+/-',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
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
                  },
                ),

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
                        onPressed: showTambahUangku,
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
                        onPressed: showHapusUangku,
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
