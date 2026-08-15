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



  const InfoCardUangku({
    super.key,
    required this.title,
    required this.amount,
    required this.items,
    required this.onChanged
  });

  @override
  State<InfoCardUangku> createState() => _InfoCardExpandableState();
}

class _InfoCardExpandableState extends State<InfoCardUangku> {
  bool isExpanded = false;
  List<Uangku> uangkuList = [];

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
    await prefs.setStringList('uangku', data);
  }

  Future<void> _loadUangku() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('uangku') ?? [];

    setState(() {
      uangkuList = data
          .map((e) => Uangku.fromJson(jsonDecode(e)))
          .toList();
    });
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
              onPressed: () {
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

                _saveUangku();
                RiwayatService.catatTambahUangku(nama, jumlah);
                widget.onChanged();
                Navigator.pop(context);
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
              onPressed: () {
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

                _saveUangku();
                RiwayatService.catatEditUangku(
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
                      RiwayatService.catatHapusUangku(item.nama, item.jumlah);
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
                Text(
                  widget.title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.pink,
                    fontWeight: FontWeight.bold,
                  ),
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
                ...uangkuList.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;

                  return Material(
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
                            const Icon(Icons.circle, size: 7, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              '${item.nama} : ${RupiahFormatter.format(item.jumlah)}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
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
