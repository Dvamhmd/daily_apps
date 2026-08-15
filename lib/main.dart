import 'package:daily_apps/cards/card_tagihan.dart';
import 'package:daily_apps/cards/card_tabungan.dart';
import 'package:daily_apps/cards/card_uangku.dart';
import 'package:daily_apps/models/model_tagihan.dart';
import 'package:daily_apps/models/model_tabungan.dart';
import 'package:daily_apps/models/model_uangku.dart';
import 'package:daily_apps/pages/riwayat_page.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Keuangan',
      home: const KeuanganPage(),
    );
  }
}

class KeuanganPage extends StatefulWidget {
  const KeuanganPage({super.key});

  @override
  State<KeuanganPage> createState() => _KeuanganPageState();
}

class _KeuanganPageState extends State<KeuanganPage> {
  List<Tagihan> tagihanList = [];
  List<Uangku> uangkuList = [];
  List<Tabungan> tabunganList = [];
  DateTime? lastUpdated;
  DateTime? targetDate;
  int targetTabungan = 0;

  // Total Keuangan Harian
  int get totalTagihan =>
      tagihanList.fold<int>(0, (sum, e) => sum + e.jumlah);

  int get totalUangku =>
      uangkuList.fold<int>(0, (sum, e) => sum + e.jumlah);

  // Dana Aman untuk Keuangan Harian
  int get danaAman => totalUangku - totalTagihan;

  // Total Tabungan Terkumpul (Terpisah dari Keuangan Harian)
  int get totalTabungan =>
      tabunganList.fold<int>(0, (sum, e) => sum + e.jumlah);

  // Kekurangan Dana untuk mencapai target Tabungan
  int get sisaTarget {
    final sisa = targetTabungan - totalTabungan;
    return sisa < 0 ? 0 : sisa; // tidak minus
  }

  // Progress persentase tabungan
  double get progressTabungan {
    if (targetTabungan == 0) return 0.0;
    final p = totalTabungan / targetTabungan;
    return p > 1.0 ? 1.0 : (p < 0.0 ? 0.0 : p);
  }

  int get persenTabungan {
    if (targetTabungan == 0) return 0;
    return ((totalTabungan / targetTabungan) * 100).round();
  }

  int get sisaHari {
    if (targetDate == null) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      targetDate!.year,
      targetDate!.month,
      targetDate!.day,
    );

    final diff = target.difference(today).inDays;
    return diff > 0 ? diff : 0;
  }

  int get tabunganPerHari {
    if (sisaHari == 0) return 0;
    return (sisaTarget / sisaHari).ceil(); // dibulatkan ke atas
  }

  String formatTanggal(DateTime date) {
    const bulan = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final jam = date.hour.toString().padLeft(2, '0');
    final menit = date.minute.toString().padLeft(2, '0');

    return '${date.day} ${bulan[date.month - 1]} ${date.year} • $jam:$menit';
  }

  @override
  void initState() {
    super.initState();
    _loadTagihan();
    _loadUangku();
    _loadTabungan();
    _loadTarget();
    _loadLastUpdated();
  }

  Future<void> _loadUangku() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('uangku') ?? [];

    setState(() {
      uangkuList =
          data.map((e) => Uangku.fromJson(jsonDecode(e))).toList();
    });
  }

  Future<void> _loadTagihan() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('tagihan') ?? [];

    setState(() {
      tagihanList =
          data.map((e) => Tagihan.fromJson(jsonDecode(e))).toList();
    });
  }

  Future<void> _loadTabungan() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('tabungan') ?? [];

    setState(() {
      tabunganList =
          data.map((e) => Tabungan.fromJson(jsonDecode(e))).toList();
    });
  }

  Future<void> _loadTarget() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final dateMillis = prefs.getInt('target_date');
      targetDate = dateMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(dateMillis)
          : null;
      targetTabungan = prefs.getInt('target_amount') ?? 0;
    });
  }

  Future<void> _saveTarget() async {
    final prefs = await SharedPreferences.getInstance();
    if (targetDate != null) {
      await prefs.setInt(
        'target_date',
        targetDate!.millisecondsSinceEpoch,
      );
    }
    await prefs.setInt('target_amount', targetTabungan);
  }

  Future<void> _loadLastUpdated() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt('last_updated');

    setState(() {
      lastUpdated =
          millis != null ? DateTime.fromMillisecondsSinceEpoch(millis) : null;
    });
  }

  Future<void> _updateLastUpdated() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    await prefs.setInt('last_updated', now.millisecondsSinceEpoch);

    setState(() {
      lastUpdated = now;
    });
  }

  void showEditTarget() {
    final targetCtrl = TextEditingController(
      text: targetTabungan == 0
          ? ''
          : RupiahFormatter.format(targetTabungan),
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Edit Target',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: targetDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );

                      if (picked != null) {
                        setLocalState(() {
                          targetDate = picked;
                        });
                      }
                    },
                    child: Text(
                      targetDate == null
                          ? 'Pilih Deadline'
                          : formatTanggal(targetDate!),
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: targetCtrl,
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
                      hintText: 'Target Tabungan',
                      hintStyle: GoogleFonts.poppins(),
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
                      final cleanValue =
                          targetCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');

                      setState(() {
                        targetTabungan = int.tryParse(cleanValue) ?? 0;
                      });

                      _saveTarget();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Simpan',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5E35B1),
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: Text(
          'Keuangan',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.history_rounded,
              color: Colors.white,
              size: 28,
            ),
            tooltip: 'Riwayat Perubahan',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RiwayatPage(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lastUpdated == null
                  ? 'Belum pernah diperbarui'
                  : 'Diperbarui : ${formatTanggal(lastUpdated!)}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 16),

            // KEUANGAN HARIAN
            InfoCardTagihan(
              title: 'Tagihanku',
              amount: totalTagihan.toString(),
              items: tagihanList
                  .map((e) => {
                        'name': e.nama,
                        'amount': e.jumlah.toString(),
                      })
                  .toList(),
              onChanged: () async {
                await _loadTagihan();
                await _updateLastUpdated();
              },
            ),

            const SizedBox(height: 16),

            InfoCardUangku(
              title: 'Uangku',
              amount: totalUangku.toString(),
              items: uangkuList
                  .map((e) => {
                        'name': e.nama,
                        'amount': e.jumlah.toString(),
                      })
                  .toList(),
              onChanged: () async {
                await _loadUangku();
                await _updateLastUpdated();
              },
            ),

            const SizedBox(height: 16),

            // DANA AMAN (KEUANGAN HARIAN)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF5E35B1).withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5E35B1).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: Color(0xFF5E35B1),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Dana Aman :',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    RupiahFormatter.format(danaAman),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF5E35B1),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 36, thickness: 1.2),

            // TARGET TABUNGAN (TERPISAH DARI KEUANGAN HARIAN)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.flag_circle_rounded,
                      color: Color(0xFF5E35B1),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      targetDate == null
                          ? 'Target Tabungan'
                          : 'Target : ${formatTanggal(targetDate!)}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 24, color: Color(0xFF5E35B1)),
                  tooltip: 'Edit Target',
                  onPressed: showEditTarget,
                ),
              ],
            ),

            Text(
              targetTabungan == 0
                  ? '0'
                  : RupiahFormatter.format(targetTabungan),
              style: GoogleFonts.poppins(
                fontSize: 36,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),

            if (targetTabungan > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progressTabungan,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progressTabungan >= 1.0
                        ? const Color(0xFF63B967)
                        : const Color(0xFF5E35B1),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Terkumpul: ${RupiahFormatter.format(totalTabungan)} ($persenTabungan%)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (sisaHari > 0)
                    Text(
                      '$sisaHari hari lagi',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5E35B1),
                      ),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // KARTU TABUNGANKU (INPUT MANDIRI TERPISAH)
            InfoCardTabungan(
              title: 'Tabunganku',
              amount: totalTabungan.toString(),
              items: tabunganList
                  .map((e) => {
                        'name': e.nama,
                        'amount': e.jumlah.toString(),
                      })
                  .toList(),
              onChanged: () async {
                await _loadTabungan();
                await _updateLastUpdated();
              },
            ),

            const SizedBox(height: 18),

            // KEKURANGAN DANA (SISA TARGET)
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.red,
                  radius: 14,
                  child: Icon(
                    Icons.remove,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kekurangan Dana',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        RupiahFormatter.format(sisaTarget),
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // TABUNGAN PER HARI
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.green,
                  radius: 14,
                  child: Icon(
                    Icons.attach_money,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sisaHari > 0
                            ? 'Tabungan per hari ($sisaHari hari)'
                            : 'Tabungan per hari',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        RupiahFormatter.format(tabunganPerHari),
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
