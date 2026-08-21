import 'package:daily_apps/cards/card_tagihan.dart';
import 'package:daily_apps/cards/card_tabungan.dart';
import 'package:daily_apps/cards/card_uangku.dart';
import 'package:daily_apps/models/model_tagihan.dart';
import 'package:daily_apps/models/model_tabungan.dart';
import 'package:daily_apps/models/model_uangku.dart';
import 'package:daily_apps/pages/riwayat_page.dart';
import 'package:daily_apps/pages/rundown_page.dart';
import 'package:daily_apps/pages/todo_page.dart';
import 'package:daily_apps/utils/notification_service.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:daily_apps/widgets/app_drawer.dart';
import 'package:daily_apps/widgets/gta_switch_wheel.dart';
import 'package:daily_apps/widgets/menu_transition_overlay.dart';
import 'package:flutter/material.dart';
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
      title: 'Daily Apps',
      theme: ThemeData(
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        canvasColor: const Color(0xFFF7F9FC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5E35B1),
          surface: const Color(0xFFF7F9FC),
        ),
      ),
      home: const MainScreenWrapper(),
    );
  }
}

class MainScreenWrapper extends StatefulWidget {
  const MainScreenWrapper({super.key});

  @override
  State<MainScreenWrapper> createState() => _MainScreenWrapperState();
}

class _MainScreenWrapperState extends State<MainScreenWrapper> {
  final GlobalKey<MenuTransitionWrapperState> _transitionKey =
      GlobalKey<MenuTransitionWrapperState>();
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDefaultMainPage();
  }

  Future<void> _loadDefaultMainPage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('default_main_page') ?? 0;
    if (mounted && savedIndex >= 0 && savedIndex <= 2) {
      setState(() {
        _currentPageIndex = savedIndex;
      });
    }
  }

  void _onPageSelected(int index) {
    if (_currentPageIndex != index) {
      if (_transitionKey.currentState != null) {
        _transitionKey.currentState!.triggerTransition(index, () {
          if (mounted) {
            setState(() {
              _currentPageIndex = index;
            });
          }
        });
      } else {
        setState(() {
          _currentPageIndex = index;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MenuTransitionWrapper(
      key: _transitionKey,
      currentPageIndex: _currentPageIndex,
      child: Container(
        color: _currentPageIndex == 1
            ? const Color(0xFFF0FDF4)
            : (_currentPageIndex == 2
                ? const Color(0xFFFBF8F6)
                : const Color(0xFFF7F9FC)),
        child: IndexedStack(
          index: _currentPageIndex,
          children: [
            KeuanganPage(onPageSelected: _onPageSelected),
            RundownPage(onPageSelected: _onPageSelected),
            TodoPage(onPageSelected: _onPageSelected),
          ],
        ),
      ),
    );
  }
}

class KeuanganPage extends StatefulWidget {
  final ValueChanged<int>? onPageSelected;

  const KeuanganPage({super.key, this.onPageSelected});

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
    if (diff < 0) return 0;
    if (diff == 0) return 1; // Deadline hari ini dihitung 1 hari
    return diff;
  }

  int get tabunganPerHari {
    if (sisaTarget <= 0) return 0;
    if (sisaHari <= 0) return 0;
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
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();

    // Tagihan
    final tagihanKey = 'tagihan_$selectedMonthKey';
    var rawTagihan = prefs.getStringList(tagihanKey);
    if (rawTagihan == null) {
      final now = DateTime.now();
      if (selectedMonth.year == now.year && selectedMonth.month == now.month) {
        final legacy = prefs.getStringList('tagihan');
        if (legacy != null) {
          rawTagihan = legacy;
          await prefs.setStringList(tagihanKey, legacy);
        }
      }
    }
    rawTagihan ??= [];

    // Uangku
    final uangkuKey = 'uangku_$selectedMonthKey';
    var rawUangku = prefs.getStringList(uangkuKey);
    if (rawUangku == null) {
      final now = DateTime.now();
      if (selectedMonth.year == now.year && selectedMonth.month == now.month) {
        final legacy = prefs.getStringList('uangku');
        if (legacy != null) {
          rawUangku = legacy;
          await prefs.setStringList(uangkuKey, legacy);
        }
      }
    }
    rawUangku ??= [];

    // Tabungan
    final rawTabungan = prefs.getStringList('tabungan') ?? [];

    // Target
    final dateMillis = prefs.getInt('target_date');
    final loadedTargetDate = dateMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(dateMillis)
        : null;
    final loadedTargetAmount = prefs.getInt('target_amount') ?? 0;

    // Last Updated
    final millis = prefs.getInt('last_updated');
    final loadedLastUpdated =
        millis != null ? DateTime.fromMillisecondsSinceEpoch(millis) : null;

    // Filter Dana Aman & Uangku
    final loadedFilterMode = prefs.getString('dana_aman_filter_mode') ?? 'all';
    final cutoffMillis = prefs.getInt('dana_aman_cutoff_date');
    final loadedCutoffDate = cutoffMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(cutoffMillis)
        : null;
    final loadedOnlyCair = prefs.getBool('uangku_only_cair') ?? false;

    if (!mounted) return;
    setState(() {
      tagihanList =
          rawTagihan!.map((e) => Tagihan.fromJson(jsonDecode(e))).toList();
      uangkuList =
          rawUangku!.map((e) => Uangku.fromJson(jsonDecode(e))).toList();
      tabunganList =
          rawTabungan.map((e) => Tabungan.fromJson(jsonDecode(e))).toList();
      targetDate = loadedTargetDate;
      targetTabungan = loadedTargetAmount;
      lastUpdated = loadedLastUpdated;
      danaAmanFilterMode = loadedFilterMode;
      danaAmanCutoffDate = loadedCutoffDate;
      uangkuOnlyCair = loadedOnlyCair;
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
                      style: TextStyle(
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
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Semua tagihan akan mengurangi uangku',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const Divider(),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: 'has_deadline',
                            activeColor: const Color(0xFF5E35B1),
                            title: Text(
                              'Hanya Tagihan Berdeadline',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Hanya tagihan yang memiliki deadline yang mengurangi uangku',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const Divider(),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: 'custom_date',
                            activeColor: const Color(0xFF5E35B1),
                            title: Text(
                              'Sesuaikan Batas Deadline',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Hanya tagihan dengan deadline s/d tanggal yang dipilih',
                              style: TextStyle(fontSize: 12),
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
                                  style: TextStyle(
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
                      style: TextStyle(
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
    } else {
      await prefs.remove('target_date');
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
                    style: TextStyle(
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
                        style: TextStyle(
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
                            style: TextStyle(
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
                              style: TextStyle(
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
                    style: TextStyle(
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
                    style: TextStyle(
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
    DateTime? tempTargetDate = targetDate;
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final now = DateTime.now();
                            final today =
                                DateTime(now.year, now.month, now.day);
                            final initial = (tempTargetDate != null &&
                                    tempTargetDate!.isAfter(today))
                                ? tempTargetDate!
                                : today;

                            final picked = await showDatePicker(
                              context: context,
                              initialDate: initial,
                              firstDate: DateTime(now.year - 1),
                              lastDate: DateTime(2100),
                            );

                            if (picked != null) {
                              setLocalState(() {
                                tempTargetDate = picked;
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_month_rounded,
                              size: 18),
                          label: Text(
                            tempTargetDate == null
                                ? 'Pilih Deadline'
                                : DateFormat('dd MMM yyyy')
                                    .format(tempTargetDate!),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (tempTargetDate != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.red),
                          tooltip: 'Hapus Deadline',
                          onPressed: () {
                            setLocalState(() {
                              tempTargetDate = null;
                            });
                          },
                        ),
                      ],
                    ],
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      final cleanValue =
                          targetCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');

                      setState(() {
                        targetTabungan = int.tryParse(cleanValue) ?? 0;
                        targetDate = tempTargetDate;
                      });

                      _saveTarget();
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Simpan',
                      style: TextStyle(
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
    await _loadInitialData();
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
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: GtaSwitchWheel(
        currentIndex: 0,
        onPageSelected: widget.onPageSelected ?? (index) {},
      ),
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
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: const Text(
          'Keuangan',
          style: TextStyle(
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
                        style: const TextStyle(
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
              size: 24,
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
                margin: const EdgeInsets.only(bottom: 14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFFBEB),
                      const Color(0xFFFEF3C7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: Color(0xFFD97706),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _getUrgentTagihanMessage(urgentTagihan),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB45309),
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
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5E35B1).withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF5E35B1).withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      size: 24,
                      color: Color(0xFF5E35B1),
                    ),
                    tooltip: 'Bulan Sebelumnya',
                    onPressed: _prevMonth,
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _showMonthYearPicker,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF5E35B1).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
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
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5E35B1),
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
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: Color(0xFF5E35B1),
                    ),
                    tooltip: 'Bulan Berikutnya',
                    onPressed: _nextMonth,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

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

            const SizedBox(height: 14),

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

            const SizedBox(height: 14),

            // DANA AMAN (KEUANGAN HARIAN) - STANDOUT HERO CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF5E35B1),
                    Color(0xFF7E57C2),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5E35B1).withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
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
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shield_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Dana Aman',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: showOpsiDeadlineDanaAman,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Filter',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down,
                                size: 16,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    RupiahFormatter.format(danaAman),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            danaAmanFilterLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (danaAmanFilterMode != 'all')
                          InkWell(
                            onTap: () {
                              setState(() {
                                danaAmanFilterMode = 'all';
                                danaAmanCutoffDate = null;
                              });
                              _saveDanaAmanFilter();
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                'Reset',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFFFCDD2),
                                  fontWeight: FontWeight.bold,
                                ),
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
                          Icons.check_circle_rounded,
                          size: 13,
                          color: Color(0xFFA7F3D0),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Uangku terhitung: ${RupiahFormatter.format(totalUangkuCair)} (Cair)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFA7F3D0),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // TARGET TABUNGAN (MODERN GOAL CARD)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF5E35B1).withValues(alpha: 0.15),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5E35B1).withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
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
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5E35B1)
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.flag_circle_rounded,
                              color: Color(0xFF5E35B1),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            targetDate == null
                                ? 'Target Tabungan'
                                : 'Target: ${DateFormat('dd MMM yyyy').format(targetDate!)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: showEditTarget,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5E35B1)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                size: 14,
                                color: Color(0xFF5E35B1),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Edit',
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
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    targetTabungan == 0
                        ? 'Rp 0'
                        : RupiahFormatter.format(targetTabungan),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (targetTabungan > 0) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progressTabungan,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progressTabungan >= 1.0
                              ? const Color(0xFF10B981)
                              : const Color(0xFF5E35B1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Terkumpul: ${RupiahFormatter.format(totalTabungan)} ($persenTabungan%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        if (sisaHari > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5E35B1)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$sisaHari hari lagi',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5E35B1),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

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

            const SizedBox(height: 14),

            // STATS DUO CARDS: KEKURANGAN DANA & TABUNGAN PER HARI
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFECDD3),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFEF4444).withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.trending_down_rounded,
                                color: Color(0xFFEF4444),
                                size: 15,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Kekurangan',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          RupiahFormatter.format(sisaTarget),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFBBF7D0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF10B981).withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.savings_rounded,
                                color: Color(0xFF10B981),
                                size: 15,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                sisaHari > 0
                                    ? 'Nabung/Hari ($sisaHari hr)'
                                    : 'Nabung/Hari',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          RupiahFormatter.format(tabunganPerHari),
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
