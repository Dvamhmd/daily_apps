import 'package:daily_apps/cards/card_tagihan.dart';
import 'package:daily_apps/cards/card_tabungan.dart';
import 'package:daily_apps/cards/card_uangku.dart';
import 'package:daily_apps/models/model_tagihan.dart';
import 'package:daily_apps/models/model_tabungan.dart';
import 'package:daily_apps/models/model_uangku.dart';
import 'package:daily_apps/pages/riwayat_page.dart';
import 'package:daily_apps/utils/notification_service.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:daily_apps/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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

  DateTime selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  static const List<String> namaBulan = [
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

  String get selectedMonthKey =>
      '${selectedMonth.year}_${selectedMonth.month.toString().padLeft(2, '0')}';

  String danaAmanFilterMode = 'all'; // 'all', 'has_deadline', 'custom_date'
  DateTime? danaAmanCutoffDate;
  bool uangkuOnlyCair = false;

  // Total Keuangan Harian
  int get totalTagihan =>
      tagihanList.fold<int>(0, (sum, e) => sum + e.jumlah);

  int get totalUangku =>
      uangkuList.fold<int>(0, (sum, e) => sum + e.jumlah);

  int get totalUangkuCair =>
      uangkuList.where((e) => e.isCair).fold<int>(0, (sum, e) => sum + e.jumlah);

  int get totalUangkuDihitung =>
      uangkuOnlyCair ? totalUangkuCair : totalUangku;

  // Tagihan yang di-include dalam perhitungan Dana Aman
  List<Tagihan> get filteredTagihanDanaAman {
    if (danaAmanFilterMode == 'has_deadline') {
      return tagihanList.where((t) => t.deadline != null).toList();
    } else if (danaAmanFilterMode == 'custom_date' &&
        danaAmanCutoffDate != null) {
      final cutoff = DateTime(
        danaAmanCutoffDate!.year,
        danaAmanCutoffDate!.month,
        danaAmanCutoffDate!.day,
        23,
        59,
        59,
      );
      return tagihanList.where((t) {
        if (t.deadline == null) return false;
        final d =
            DateTime(t.deadline!.year, t.deadline!.month, t.deadline!.day);
        return d.isBefore(cutoff) ||
            d.isAtSameMomentAs(DateTime(danaAmanCutoffDate!.year,
                danaAmanCutoffDate!.month, danaAmanCutoffDate!.day));
      }).toList();
    }
    return tagihanList;
  }

  int get totalTagihanDanaAman =>
      filteredTagihanDanaAman.fold<int>(0, (sum, e) => sum + e.jumlah);

  // Dana Aman untuk Keuangan Harian (disesuaikan dengan filter deadline & filter uangku cair)
  int get danaAman => totalUangkuDihitung - totalTagihanDanaAman;

  String get danaAmanFilterLabel {
    if (danaAmanFilterMode == 'has_deadline') {
      return 'Hanya tagihan berdeadline';
    } else if (danaAmanFilterMode == 'custom_date' &&
        danaAmanCutoffDate != null) {
      return 'Tagihan s/d ${DateFormat('dd/MM/yy').format(danaAmanCutoffDate!)}';
    }
    return 'Semua tagihan';
  }

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
    NotificationService.initialize();
    _loadTagihan();
    _loadUangku();
    _loadTabungan();
    _loadTarget();
    _loadLastUpdated();
    _loadDanaAmanFilter();
    _loadUangkuFilter();
  }

  Future<void> _loadUangkuFilter() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      uangkuOnlyCair = prefs.getBool('uangku_only_cair') ?? false;
    });
  }

  Future<void> _loadDanaAmanFilter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      danaAmanFilterMode = prefs.getString('dana_aman_filter_mode') ?? 'all';
      final dateMillis = prefs.getInt('dana_aman_cutoff_date');
      danaAmanCutoffDate = dateMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(dateMillis)
          : null;
    });
  }

  Future<void> _saveDanaAmanFilter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dana_aman_filter_mode', danaAmanFilterMode);
    if (danaAmanCutoffDate != null) {
      await prefs.setInt(
        'dana_aman_cutoff_date',
        danaAmanCutoffDate!.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove('dana_aman_cutoff_date');
    }
  }

  void showOpsiDeadlineDanaAman() {
    String tempMode = danaAmanFilterMode;
    DateTime? tempCutoff = danaAmanCutoffDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFF5E35B1),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Opsi Deadline Dana Aman',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioGroup<String>(
                      groupValue: tempMode,
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            tempMode = val;
                            if (tempMode == 'custom_date') {
                              tempCutoff ??= DateTime.now();
                            }
                          });
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: 'all',
                            activeColor: const Color(0xFF5E35B1),
                            title: Text(
                              'Semua Tagihan (Default)',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Semua tagihan akan mengurangi uangku',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                          const Divider(),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: 'has_deadline',
                            activeColor: const Color(0xFF5E35B1),
                            title: Text(
                              'Hanya Tagihan Berdeadline',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Hanya tagihan yang memiliki deadline yang mengurangi uangku',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                          const Divider(),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: 'custom_date',
                            activeColor: const Color(0xFF5E35B1),
                            title: Text(
                              'Sesuaikan Batas Deadline',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Hanya tagihan dengan deadline s/d tanggal yang dipilih',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (tempMode == 'custom_date') ...[
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final initial = (tempCutoff != null &&
                                  !tempCutoff!.isBefore(today))
                              ? tempCutoff!
                              : today;

                          final picked = await showDatePicker(
                            context: context,
                            initialDate: initial,
                            firstDate: today,
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              tempCutoff = picked;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF5E35B1)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                size: 18,
                                color: Color(0xFF5E35B1),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tempCutoff == null
                                      ? 'Pilih Tanggal Batas'
                                      : 's/d ${DateFormat('dd/MM/yyyy').format(tempCutoff!)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF5E35B1),
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.edit_calendar_rounded,
                                size: 18,
                                color: Color(0xFF5E35B1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5E35B1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        danaAmanFilterMode = tempMode;
                        danaAmanCutoffDate = tempCutoff;
                      });
                      _saveDanaAmanFilter();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Terapkan',
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

  Future<void> _loadUangku() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'uangku_$selectedMonthKey';
    var data = prefs.getStringList(key);

    // Migrasi data legacy jika bulan ini belum punya data tapi ada data legacy 'uangku'
    if (data == null) {
      final now = DateTime.now();
      if (selectedMonth.year == now.year && selectedMonth.month == now.month) {
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
      uangkuList =
          data!.map((e) => Uangku.fromJson(jsonDecode(e))).toList();
    });
  }

  Future<void> _loadTagihan() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'tagihan_$selectedMonthKey';
    var data = prefs.getStringList(key);

    // Migrasi data legacy jika bulan ini belum punya data tapi ada data legacy 'tagihan'
    if (data == null) {
      final now = DateTime.now();
      if (selectedMonth.year == now.year && selectedMonth.month == now.month) {
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
      tagihanList =
          data!.map((e) => Tagihan.fromJson(jsonDecode(e))).toList();
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

  void _prevMonth() {
    setState(() {
      selectedMonth =
          DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
    });
    _loadMonthData();
  }

  void _nextMonth() {
    setState(() {
      selectedMonth =
          DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
    });
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    await _loadTagihan();
    await _loadUangku();
    await _updateLastUpdated();
  }

  void _showMonthYearPicker() {
    int tempYear = selectedMonth.year;
    int tempMonth = selectedMonth.month;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pilih Bulan & Tahun',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      final now = DateTime.now();
                      setDialogState(() {
                        tempYear = now.year;
                        tempMonth = now.month;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF5E35B1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Bulan Ini',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF5E35B1),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Year Selector
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded),
                            onPressed: () {
                              setDialogState(() {
                                tempYear--;
                              });
                            },
                          ),
                          Text(
                            '$tempYear',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF5E35B1),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            onPressed: () {
                              setDialogState(() {
                                tempYear++;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Month Grid (4 rows x 3 cols)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, idx) {
                        final monthNum = idx + 1;
                        final isSelected = tempMonth == monthNum;
                        final isCurrentActual =
                            (monthNum == DateTime.now().month &&
                                tempYear == DateTime.now().year);

                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              tempMonth = monthNum;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF5E35B1)
                                  : (isCurrentActual
                                      ? const Color(0xFF5E35B1)
                                          .withValues(alpha: 0.1)
                                      : Colors.grey[100]),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF5E35B1)
                                    : (isCurrentActual
                                        ? const Color(0xFF5E35B1)
                                            .withValues(alpha: 0.4)
                                        : Colors.transparent),
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              namaBulan[idx].substring(0, 3),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : (isCurrentActual
                                        ? FontWeight.w600
                                        : FontWeight.normal),
                                color: isSelected
                                    ? Colors.white
                                    : (isCurrentActual
                                        ? const Color(0xFF5E35B1)
                                        : const Color(0xFF1E293B)),
                              ),
                            ),
                          ),
                        );
                      },
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
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E35B1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      selectedMonth = DateTime(tempYear, tempMonth, 1);
                    });
                    _loadMonthData();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Pilih',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

  String _getUrgentTagihanMessage(List<Tagihan> urgentList) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (urgentList.isEmpty) return '';

    if (urgentList.length == 1) {
      final t = urgentList.first;
      final target =
          DateTime(t.deadline!.year, t.deadline!.month, t.deadline!.day);
      final diff = target.difference(today).inDays;

      if (diff == 0) {
        return 'Tagihan "${t.nama}" jatuh tempo hari ini!';
      } else if (diff == 1) {
        return 'Tagihan "${t.nama}" kurang 1 hari lagi!';
      } else if (diff > 1) {
        return 'Tagihan "${t.nama}" kurang $diff hari lagi!';
      } else {
        return 'Tagihan "${t.nama}" sudah lewat ${-diff} hari!';
      }
    }

    final sorted = List<Tagihan>.from(urgentList)
      ..sort((a, b) => a.deadline!.compareTo(b.deadline!));

    final nearest = sorted.first;
    final target = DateTime(
        nearest.deadline!.year, nearest.deadline!.month, nearest.deadline!.day);
    final diff = target.difference(today).inDays;

    String detail;
    if (diff == 0) {
      detail = '"${nearest.nama}" jatuh tempo hari ini';
    } else if (diff == 1) {
      detail = '"${nearest.nama}" kurang 1 hari lagi';
    } else if (diff > 1) {
      detail = '"${nearest.nama}" kurang $diff hari lagi';
    } else {
      detail = '"${nearest.nama}" lewat ${-diff} hari';
    }

    return 'Ada ${urgentList.length} tagihan mendesak ($detail)';
  }

  Future<void> _refreshAll() async {
    await _loadTagihan();
    await _loadUangku();
    await _loadTabungan();
    await _loadTarget();
    await _loadUangkuFilter();
    await _updateLastUpdated();
  }

  @override
  Widget build(BuildContext context) {
    final status = FinancialHealthHelper.getStatus(totalUangku, totalTagihan);
    final statusColor = FinancialHealthHelper.getStatusColor(status);

    final urgentTagihan = tagihanList.where((t) {
      if (t.deadline == null) return false;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target =
          DateTime(t.deadline!.year, t.deadline!.month, t.deadline!.day);
      final diff = target.difference(today).inDays;
      return diff <= 3;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      drawer: AppDrawer(
        totalUangku: totalUangku,
        totalTagihan: totalTagihan,
        totalTabungan: totalTabungan,
        selectedMonth: selectedMonth,
        onDataChanged: () async {
          await _loadTagihan();
          await _loadUangku();
          await _loadTabungan();
          await _loadTarget();
          await _loadLastUpdated();
        },
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5E35B1),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
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
          // Smart Health Badge
          Builder(
            builder: (context) {
              return InkWell(
                onTap: () => Scaffold.of(context).openDrawer(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status == StatusKesehatan.sehat
                            ? 'Sehat'
                            : (status == StatusKesehatan.perhatian
                                ? 'Perhatian'
                                : 'Kritis'),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(
              Icons.history_rounded,
              color: Colors.white,
              size: 26,
            ),
            tooltip: 'Riwayat Perubahan',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RiwayatPage(),
                ),
              ).then((_) async {
                await _loadTagihan();
                await _loadUangku();
                await _loadTabungan();
              });
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (urgentTagihan.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE65100).withValues(alpha: 0.12),
                      const Color(0xFFFFA726).withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE65100).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_rounded,
                      color: Color(0xFFE65100),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _getUrgentTagihanMessage(urgentTagihan),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // BULAN SELECTOR BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5E35B1).withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF5E35B1).withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Color(0xFF5E35B1),
                    ),
                    tooltip: 'Bulan Sebelumnya',
                    onPressed: _prevMonth,
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _showMonthYearPicker,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5E35B1)
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 18,
                              color: Color(0xFF5E35B1),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${namaBulan[selectedMonth.month - 1]} ${selectedMonth.year}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF5E35B1),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: Color(0xFF5E35B1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 18,
                      color: Color(0xFF5E35B1),
                    ),
                    tooltip: 'Bulan Berikutnya',
                    onPressed: _nextMonth,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // KEUANGAN HARIAN
            InfoCardTagihan(
              title: 'Tagihanku',
              amount: totalTagihan.toString(),
              selectedMonth: selectedMonth,
              items: tagihanList
                  .map((e) => {
                        'name': e.nama,
                        'amount': e.jumlah.toString(),
                      })
                  .toList(),
              onChanged: _refreshAll,
            ),

            const SizedBox(height: 16),

            InfoCardUangku(
              title: 'Uangku',
              amount: totalUangku.toString(),
              selectedMonth: selectedMonth,
              onlyCair: uangkuOnlyCair,
              onFilterChanged: (val) {
                setState(() {
                  uangkuOnlyCair = val;
                });
              },
              items: uangkuList
                  .map((e) => {
                        'name': e.nama,
                        'amount': e.jumlah.toString(),
                      })
                  .toList(),
              onChanged: _refreshAll,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: Color(0xFF5E35B1),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            danaAmanFilterLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF5E35B1),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: showOpsiDeadlineDanaAman,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Sesuaikan',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF5E35B1),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  size: 18,
                                  color: Color(0xFF5E35B1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (uangkuOnlyCair) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.filter_alt_rounded,
                          size: 13,
                          color: Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Uangku terhitung: ${RupiahFormatter.format(totalUangkuCair)} (Hanya cair)',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (danaAmanFilterMode != 'all') ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tagihan terhitung: ${RupiahFormatter.format(totalTagihanDanaAman)} (${filteredTagihanDanaAman.length} tagihan)',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              danaAmanFilterMode = 'all';
                              danaAmanCutoffDate = null;
                            });
                            _saveDanaAmanFilter();
                          },
                          child: Text(
                            'Reset',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.red[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
              onChanged: _refreshAll,
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
