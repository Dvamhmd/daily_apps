import 'package:daily_apps/cards/card_tagihan.dart';
import 'package:daily_apps/cards/card_tabungan.dart';
import 'package:daily_apps/cards/card_uangku.dart';
import 'package:daily_apps/models/model_tagihan.dart';
import 'package:daily_apps/models/model_tabungan.dart';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/models/model_uangku.dart';
import 'package:daily_apps/pages/riwayat_page.dart';
import 'package:daily_apps/pages/rundown_page.dart';
import 'package:daily_apps/pages/todo_page.dart';
import 'package:daily_apps/utils/notification_service.dart';
import 'package:daily_apps/utils/responsive_text.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:daily_apps/utils/serious_mode_service.dart';
import 'package:daily_apps/utils/todo_alarm_service.dart';
import 'package:daily_apps/widgets/app_drawer.dart';
import 'package:daily_apps/widgets/custom_toast.dart';
import 'package:daily_apps/widgets/gta_switch_wheel.dart';
import 'package:daily_apps/widgets/menu_transition_overlay.dart';
import 'package:daily_apps/widgets/todo_alarm_popup_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeDateFormatting('id_ID', null);
  } catch (_) {}

  if (!kIsWeb) {
    try {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
      );
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
    } catch (_) {}
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: CustomToast.navigatorKey,
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
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: ResponsiveText.getEffectiveTextScaler(context),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
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
    _initGlobalAlarmListener();
  }

  @override
  void dispose() {
    TodoAlarmService.activeAlarmNotifier.removeListener(_onActiveAlarmTriggered);
    super.dispose();
  }

  void _initGlobalAlarmListener() {
    TodoAlarmService.initialize(
      onNotificationClick: (payload) {
        _handleGlobalAlarm(payload);
      },
    );
    TodoAlarmService.requestPermissions();
    TodoAlarmService.activeAlarmNotifier.addListener(_onActiveAlarmTriggered);
  }

  void _onActiveAlarmTriggered() {
    final payload = TodoAlarmService.activeAlarmNotifier.value;
    if (payload != null && mounted) {
      _handleGlobalAlarm(payload);
    }
  }

  Future<void> _handleGlobalAlarm(AlarmTriggerPayload payload) async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final isSeriousMode = await SeriousModeService.isSeriousModeActive();
      String? jsonStr;
      if (isSeriousMode) {
        final curUser = await SeriousModeService.getCurrentUser();
        if (curUser != null) {
          final userKey = SeriousModeService.getSeriousTodoGroupsKey(
            SeriousModeService.getUserStorageIdentifier(curUser),
          );
          jsonStr = prefs.getString(userKey) ??
              prefs.getString(SeriousModeService.prefKeySeriousTodoGroups);
        } else {
          jsonStr = prefs.getString(SeriousModeService.prefKeySeriousTodoGroups);
        }
      } else {
        jsonStr = prefs.getString(SeriousModeService.prefKeyNormalTodoGroups) ??
            prefs.getString('daily_apps_todo_groups_v1') ??
            prefs.getString('todo_date_groups_v1');
      }

      TodoDateGroup targetGroup;
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final list = decoded
            .map((item) => TodoDateGroup.fromJson(item as Map<String, dynamic>))
            .toList();
        targetGroup = list.firstWhere(
          (g) => g.id == payload.groupId,
          orElse: () => list.firstWhere(
            (g) =>
                g.date.year == payload.date.year &&
                g.date.month == payload.date.month &&
                g.date.day == payload.date.day,
            orElse: () => TodoDateGroup(id: payload.groupId, date: payload.date),
          ),
        );
      } else {
        targetGroup = TodoDateGroup(id: payload.groupId, date: payload.date);
      }

      if (!mounted) return;
      if (targetGroup.isPast) {
        TodoAlarmService.stopAlarmSound();
        return;
      }
      if (targetGroup.items.isEmpty || targetGroup.pendingItems.isNotEmpty) {
        TodoAlarmPopupDialog.show(
          context,
          group: targetGroup,
          isSeriousMode: isSeriousMode,
        );
      } else {
        TodoAlarmService.stopAlarmSound();
      }
    } catch (e) {
      debugPrint('Global alarm popup handling error: $e');
    }
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

  // Limit Pengeluaran Harian
  bool limitHarianEnabled = false;
  DateTime? limitHarianStartDate;
  DateTime? limitHarianEndDate;

  // Total Keuangan Harian
  int get totalTagihan {
    int sum = 0;
    for (final e in tagihanList) {
      sum += e.jumlah;
    }
    return sum;
  }

  int get totalUangku {
    int sum = 0;
    for (final e in uangkuList) {
      sum += e.jumlah;
    }
    return sum;
  }

  int get totalUangkuCair {
    int sum = 0;
    for (final e in uangkuList) {
      if (e.isCair) sum += e.jumlah;
    }
    return sum;
  }

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

  int get totalTagihanDanaAman {
    if (danaAmanFilterMode == 'has_deadline') {
      int sum = 0;
      for (final t in tagihanList) {
        if (t.deadline != null) sum += t.jumlah;
      }
      return sum;
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
      final cutoffDateOnly = DateTime(
        danaAmanCutoffDate!.year,
        danaAmanCutoffDate!.month,
        danaAmanCutoffDate!.day,
      );
      int sum = 0;
      for (final t in tagihanList) {
        if (t.deadline == null) continue;
        final d =
            DateTime(t.deadline!.year, t.deadline!.month, t.deadline!.day);
        if (d.isBefore(cutoff) || d.isAtSameMomentAs(cutoffDateOnly)) {
          sum += t.jumlah;
        }
      }
      return sum;
    }
    return totalTagihan;
  }

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

  // Perhitungan Limit Pengeluaran Harian Berbasis Dana Aman
  int get totalHariPeriodeLimit {
    if (limitHarianStartDate == null || limitHarianEndDate == null) return 0;
    final start = DateTime(
      limitHarianStartDate!.year,
      limitHarianStartDate!.month,
      limitHarianStartDate!.day,
    );
    final end = DateTime(
      limitHarianEndDate!.year,
      limitHarianEndDate!.month,
      limitHarianEndDate!.day,
    );
    final diff = end.difference(start).inDays;
    return diff < 0 ? 0 : diff + 1;
  }

  int get sisaHariLimit {
    if (limitHarianEndDate == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(
      limitHarianEndDate!.year,
      limitHarianEndDate!.month,
      limitHarianEndDate!.day,
    );

    if (limitHarianStartDate != null) {
      final start = DateTime(
        limitHarianStartDate!.year,
        limitHarianStartDate!.month,
        limitHarianStartDate!.day,
      );
      if (today.isBefore(start)) {
        final diff = end.difference(start).inDays;
        return diff < 0 ? 0 : diff + 1;
      }
    }

    final diff = end.difference(today).inDays;
    if (diff < 0) return 0;
    return diff + 1; // Hari ini dihitung sebagai 1 hari tersisa
  }

  int get hariKeLimit {
    if (limitHarianStartDate == null || limitHarianEndDate == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(
      limitHarianStartDate!.year,
      limitHarianStartDate!.month,
      limitHarianStartDate!.day,
    );
    final end = DateTime(
      limitHarianEndDate!.year,
      limitHarianEndDate!.month,
      limitHarianEndDate!.day,
    );
    if (today.isBefore(start)) return 0;
    if (today.isAfter(end)) return totalHariPeriodeLimit;
    return today.difference(start).inDays + 1;
  }

  double get progressHariLimit {
    final total = totalHariPeriodeLimit;
    if (total <= 0) return 0.0;
    final passed = hariKeLimit;
    final p = passed / total;
    return p.clamp(0.0, 1.0);
  }

  bool get isPeriodeLimitSelesai {
    if (limitHarianEndDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(
      limitHarianEndDate!.year,
      limitHarianEndDate!.month,
      limitHarianEndDate!.day,
    );
    return today.isAfter(end);
  }

  int get limitPengeluaranHarian {
    if (!limitHarianEnabled || limitHarianEndDate == null) return 0;
    final sisa = sisaHariLimit;
    if (sisa <= 0) return 0;
    if (danaAman <= 0) return 0;
    return (danaAman / sisa).floor();
  }

  static String formatTanggalIndoLengkap(DateTime date) {
    const hari = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
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
    final namaHari = hari[date.weekday - 1];
    final namaBulan = bulan[date.month - 1];
    return '$namaHari, ${date.day} $namaBulan ${date.year}';
  }

  static String formatTanggalIndoSingkat(DateTime date) {
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${date.day} ${bulan[date.month - 1]} ${date.year}';
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
    final loadedTargetDate = _parseTargetDateFromPrefs(prefs);
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

    // Limit Pengeluaran Harian
    final loadedLimitEnabled = prefs.getBool('limit_harian_enabled') ?? false;
    final startMillis = prefs.getInt('limit_harian_start_date');
    final endMillis = prefs.getInt('limit_harian_end_date');
    final loadedLimitStartDate = startMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(startMillis)
        : null;
    final loadedLimitEndDate = endMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(endMillis)
        : null;

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
      limitHarianEnabled = loadedLimitEnabled;
      limitHarianStartDate = loadedLimitStartDate;
      limitHarianEndDate = loadedLimitEndDate;
    });
  }

  Future<void> _saveLimitHarian() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('limit_harian_enabled', limitHarianEnabled);
    if (limitHarianStartDate != null) {
      await prefs.setInt(
        'limit_harian_start_date',
        limitHarianStartDate!.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove('limit_harian_start_date');
    }
    if (limitHarianEndDate != null) {
      await prefs.setInt(
        'limit_harian_end_date',
        limitHarianEndDate!.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove('limit_harian_end_date');
    }
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

  void showPengaturanDanaAman() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    String tempMode = danaAmanFilterMode;
    DateTime? tempCutoff = danaAmanCutoffDate;
    bool tempLimitEnabled = limitHarianEnabled;
    DateTime tempStart = limitHarianStartDate ??
        DateTime(selectedMonth.year, selectedMonth.month, 1);
    DateTime tempEnd = limitHarianEndDate ??
        DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Helper simulasi tagihan & dana aman live
            int calcSimulatedTagihan(String mode, DateTime? cutoff) {
              if (mode == 'has_deadline') {
                int sum = 0;
                for (final t in tagihanList) {
                  if (t.deadline != null) sum += t.jumlah;
                }
                return sum;
              } else if (mode == 'custom_date' && cutoff != null) {
                final cutoffDt = DateTime(
                    cutoff.year, cutoff.month, cutoff.day, 23, 59, 59);
                final cutoffDateOnly =
                    DateTime(cutoff.year, cutoff.month, cutoff.day);
                int sum = 0;
                for (final t in tagihanList) {
                  if (t.deadline == null) continue;
                  final d = DateTime(
                      t.deadline!.year, t.deadline!.month, t.deadline!.day);
                  if (d.isBefore(cutoffDt) ||
                      d.isAtSameMomentAs(cutoffDateOnly)) {
                    sum += t.jumlah;
                  }
                }
                return sum;
              }
              return totalTagihan;
            }

            final simTagihan = calcSimulatedTagihan(tempMode, tempCutoff);
            final simDanaAman = totalUangkuDihitung - simTagihan;

            final calcStart =
                DateTime(tempStart.year, tempStart.month, tempStart.day);
            final calcEnd = DateTime(tempEnd.year, tempEnd.month, tempEnd.day);
            final totalHari = calcEnd.difference(calcStart).inDays + 1;

            int sisaHari;
            if (today.isBefore(calcStart)) {
              sisaHari = totalHari;
            } else if (today.isAfter(calcEnd)) {
              sisaHari = 0;
            } else {
              sisaHari = calcEnd.difference(today).inDays + 1;
            }

            final int estimasiLimit = (sisaHari > 0 && simDanaAman > 0)
                ? (simDanaAman / sisaHari).floor()
                : 0;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5E35B1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Color(0xFF5E35B1),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pengaturan Dana Aman',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Deadline tagihan & limit pengeluaran',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SECTION 1: FILTER DEADLINE TAGIHAN
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5E35B1)
                              .withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.filter_alt_outlined,
                              size: 15,
                              color: Color(0xFF5E35B1),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Opsi Deadline Tagihan',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5E35B1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
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
                              visualDensity: VisualDensity.compact,
                              value: 'all',
                              activeColor: const Color(0xFF5E35B1),
                              title: const Text(
                                'Semua Tagihan (Default)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: const Text(
                                'Semua tagihan akan mengurangi uangku',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                            const Divider(height: 8),
                            RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              value: 'has_deadline',
                              activeColor: const Color(0xFF5E35B1),
                              title: const Text(
                                'Hanya Tagihan Berdeadline',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: const Text(
                                'Hanya tagihan yang memiliki deadline yang mengurangi uangku',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                            const Divider(height: 8),
                            RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              value: 'custom_date',
                              activeColor: const Color(0xFF5E35B1),
                              title: const Text(
                                'Sesuaikan Batas Deadline',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: const Text(
                                'Hanya tagihan dengan deadline s/d tanggal batas',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (tempMode == 'custom_date') ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final now = DateTime.now();
                            final today =
                                DateTime(now.year, now.month, now.day);
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
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E5F5)
                                  .withValues(alpha: 0.5),
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
                                  size: 16,
                                  color: Color(0xFF5E35B1),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tempCutoff == null
                                        ? 'Pilih Tanggal Batas'
                                        : 's/d ${DateFormat('dd MMMM yyyy').format(tempCutoff!)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF5E35B1),
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.edit_calendar_rounded,
                                  size: 16,
                                  color: Color(0xFF5E35B1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(),
                      ),

                      // SECTION 2: LIMIT PENGELUARAN HARIAN
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5E35B1)
                              .withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.speed_rounded,
                              size: 15,
                              color: Color(0xFF5E35B1),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Limit Pengeluaran Harian',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF5E35B1),
                                ),
                              ),
                            ),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch.adaptive(
                                value: tempLimitEnabled,
                                activeColor: const Color(0xFF5E35B1),
                                onChanged: (val) {
                                  setDialogState(() {
                                    tempLimitEnabled = val;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (tempLimitEnabled) ...[
                        const SizedBox(height: 10),

                        // Date Range Picker Card
                        const Text(
                          'Rentang Tanggal (Start — End):',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF616161),
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              initialDateRange: DateTimeRange(
                                start: tempStart,
                                end: tempEnd.isBefore(tempStart)
                                    ? tempStart
                                    : tempEnd,
                              ),
                              saveText: 'Pilih',
                              helpText: 'Pilih Rentang Tanggal Limit',
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Color(0xFF5E35B1),
                                      onPrimary: Colors.white,
                                      surface: Colors.white,
                                      onSurface: Colors.black87,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setDialogState(() {
                                tempStart = picked.start;
                                tempEnd = picked.end;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE7F6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF5E35B1)
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.date_range_rounded,
                                  size: 18,
                                  color: Color(0xFF5E35B1),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${formatTanggalIndoSingkat(tempStart)} — ${formatTanggalIndoSingkat(tempEnd)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF311B92),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Total $totalHari hari periode (Ketuk untuk ganti rentang)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: const Color(0xFF5E35B1)
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.edit_calendar_rounded,
                                  size: 16,
                                  color: Color(0xFF5E35B1),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Live Simulation Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF5E35B1)
                                    .withValues(alpha: 0.08),
                                const Color(0xFF7E57C2)
                                    .withValues(alpha: 0.12),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF5E35B1)
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calculate_outlined,
                                    size: 16,
                                    color: Color(0xFF5E35B1),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Simulasi Limit Harian',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFF5E35B1),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5E35B1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$sisaHari Hari Tersisa',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 14),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Dana Aman:',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                  Text(
                                    RupiahFormatter.format(simDanaAman),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Limit / Hari:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF424242),
                                    ),
                                  ),
                                  Text(
                                    '${RupiahFormatter.format(estimasiLimit)} / hari',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E7D32),
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
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5E35B1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          danaAmanFilterMode = tempMode;
                          danaAmanCutoffDate = tempCutoff;
                          limitHarianEnabled = tempLimitEnabled;
                          if (tempLimitEnabled) {
                            limitHarianStartDate = tempStart;
                            limitHarianEndDate = tempEnd;
                          }
                        });
                        _saveDanaAmanFilter();
                        _saveLimitHarian();
                        Navigator.pop(context);
                        CustomToast.showSuccess(
                          context,
                          title: 'Pengaturan Disimpan',
                          subtitle: 'Filter & limit harian berhasil diperbarui',
                        );
                      },
                      child: const Text(
                        'Terapkan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showDialogAturLimitHarian() => showPengaturanDanaAman();
  void showOpsiDeadlineDanaAman() => showPengaturanDanaAman();

  Widget _buildLimitHarianSection() {
    if (!limitHarianEnabled || limitHarianEndDate == null) {
      return const SizedBox.shrink();
    }

    final isExpired = isPeriodeLimitSelesai;
    final sisa = sisaHariLimit;
    final limit = limitPengeluaranHarian;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.speed_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Limit Pengeluaran Harian',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: showPengaturanDanaAman,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_calendar_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Ubah',
                        style: TextStyle(
                          fontSize: 10,
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
          const SizedBox(height: 8),

          // Nominal Limit & Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      RupiahFormatter.format(limit),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '/ hari',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isExpired)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF5350),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Periode Berakhir',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                )
              else if (danaAman <= 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Dana Habis',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$sisa hari lagi',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Linear Progress Bar Periode
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressHariLimit,
              minHeight: 5,
              backgroundColor: Colors.black.withValues(alpha: 0.15),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFA7F3D0)),
            ),
          ),

          const SizedBox(height: 6),

          // Detail Periode & Rumus
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hari ke-$hariKeLimit dari $totalHariPeriodeLimit hari',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                's/d ${formatTanggalIndoSingkat(limitHarianEndDate!)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
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
      targetDate = _parseTargetDateFromPrefs(prefs);
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
                      hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 15,
                        fontWeight: FontWeight.normal,
                      ),
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
                    onPressed: () async {
                      final cleanValue =
                          targetCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');

                      setState(() {
                        targetTabungan = int.tryParse(cleanValue) ?? 0;
                        targetDate = tempTargetDate;
                      });

                      await _saveTarget();
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
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
        centerTitle: false,
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
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
        child: ResponsiveContentWrapper(
          maxWidth: 680,
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
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${namaBulan[selectedMonth.month - 1]} ${selectedMonth.year}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF5E35B1),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
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
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
                              const SizedBox(width: 8),
                              const Flexible(
                                child: Text(
                                  'Dana Aman',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: showPengaturanDanaAman,
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
                                  'Pengaturan',
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

                    if (limitHarianEnabled && limitHarianEndDate != null) ...[
                      const SizedBox(height: 12),
                      _buildLimitHarianSection(),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // TARGET TABUNGANKU (CONSOLIDATED ALL-IN-ONE CARD)
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
                targetAmount: targetTabungan,
                targetDate: targetDate,
                onEditTarget: showEditTarget,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
  }
}
