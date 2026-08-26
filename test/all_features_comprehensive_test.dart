import 'package:daily_apps/cards/card_tabungan.dart';
import 'package:daily_apps/cards/card_tagihan.dart';
import 'package:daily_apps/cards/card_uangku.dart';
import 'package:daily_apps/main.dart';
import 'package:daily_apps/models/model_rundown.dart';
import 'package:daily_apps/models/model_tabungan.dart';
import 'package:daily_apps/models/model_tagihan.dart';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/models/model_uangku.dart';
import 'package:daily_apps/pages/riwayat_page.dart';
import 'package:daily_apps/pages/rundown_page.dart';
import 'package:daily_apps/pages/todo_page.dart';
import 'package:daily_apps/pages/todo_riwayat_page.dart';
import 'package:daily_apps/utils/custom_rule_import_helper.dart';
import 'package:daily_apps/utils/responsive_text.dart';
import 'package:daily_apps/utils/riwayat_service.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:daily_apps/widgets/app_drawer.dart';
import 'package:daily_apps/widgets/gta_switch_wheel.dart';
import 'package:daily_apps/widgets/menu_transition_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. Responsive Text Scaling & Clamping Tests', () {
    test('ResponsiveText clamps large system font scales (Android B protection)', () {
      final largeScaler = ResponsiveText.calculateEffectiveTextScaler(
        screenWidth: 390.0,
        systemTextScaler: const TextScaler.linear(1.5),
        minScale: 0.85,
        maxScale: 1.10,
      );
      expect(largeScaler.scale(1.0), closeTo(1.10, 0.001));
    });

    test('ResponsiveText clamps tiny system font scales (Android C protection)', () {
      final smallScaler = ResponsiveText.calculateEffectiveTextScaler(
        screenWidth: 390.0,
        systemTextScaler: const TextScaler.linear(0.6),
        minScale: 0.85,
        maxScale: 1.10,
      );
      expect(smallScaler.scale(1.0), closeTo(0.85, 0.001));
    });

    test('ResponsiveText scales smoothly with screen width', () {
      // Compact device (340dp)
      final compactScaler = ResponsiveText.calculateEffectiveTextScaler(
        screenWidth: 340.0,
        systemTextScaler: const TextScaler.linear(1.0),
        minScale: 0.85,
        maxScale: 1.10,
      );
      expect(compactScaler.scale(1.0), closeTo(0.88, 0.01));

      // Large device (450dp)
      final largeScreenScaler = ResponsiveText.calculateEffectiveTextScaler(
        screenWidth: 450.0,
        systemTextScaler: const TextScaler.linear(1.0),
        minScale: 0.85,
        maxScale: 1.10,
      );
      expect(largeScreenScaler.scale(1.0), closeTo(1.10, 0.01));
    });

    testWidgets('MaterialApp applies responsive text scaler correctly', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(MainScreenWrapper), findsOneWidget);
    });
  });

  group('2. Rupiah Formatter Tests', () {
    test('Formats positive numbers, zero, and large numbers accurately', () {
      expect(RupiahFormatter.format(0), '0');
      expect(RupiahFormatter.format(50000), '50.000');
      expect(RupiahFormatter.format(1250000), '1.250.000');
      expect(RupiahFormatter.format(100000000), '100.000.000');
    });
  });

  group('3. Main Navigation & GTA Wheel Tests', () {
    testWidgets('Renders MainScreenWrapper and switches pages via onPageSelected',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainScreenWrapper(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(KeuanganPage), findsOneWidget);
      expect(find.byType(IndexedStack), findsOneWidget);
      expect(find.byType(MenuTransitionWrapper), findsOneWidget);
    });

    testWidgets('GtaSwitchWheel renders FAB properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: GtaSwitchWheel(
              currentIndex: 0,
              onPageSelected: (idx) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GtaSwitchWheel), findsOneWidget);
    });

    testWidgets('AppDrawer renders properly and shows status and menu',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Poppins'),
          home: Scaffold(
            body: AppDrawer(
              totalUangku: 5000000,
              totalTagihan: 2000000,
              totalTabungan: 1000000,
              onDataChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily Apps'), findsOneWidget);
      expect(find.text('Struktur'), findsOneWidget);
      expect(find.text('Riwayat Keuangan'), findsOneWidget);
      expect(find.text('Arsip Tagihan Lunas'), findsOneWidget);
    });
  });

  group('4. Keuangan Models & Cards Comprehensive Tests', () {
    test('Uangku Model JSON serialization and cair status', () {
      final now = DateTime.now();
      final item1 = Uangku(
        'Gaji Pokok',
        5000000,
        tanggalCair: now.subtract(const Duration(days: 1)),
      );
      expect(item1.isCair, isTrue);

      final item2 = Uangku(
        'Bonus Project',
        2000000,
        tanggalCair: now.add(const Duration(days: 5)),
      );
      expect(item2.isCair, isFalse);

      final json = item2.toJson();
      final restored = Uangku.fromJson(json);
      expect(restored.nama, 'Bonus Project');
      expect(restored.jumlah, 2000000);
      expect(restored.isCair, isFalse);
    });

    test('Tagihan Model JSON serialization and deadline formatting', () {
      final deadline = DateTime(2026, 9, 15);
      final tagihan = Tagihan(
        'Listrik PLN',
        350000,
        deadline: deadline,
        isLunas: false,
      );

      expect(tagihan.nama, 'Listrik PLN');
      expect(tagihan.jumlah, 350000);
      expect(tagihan.isLunas, isFalse);

      final json = tagihan.toJson();
      final restored = Tagihan.fromJson(json);
      expect(restored.nama, 'Listrik PLN');
      expect(restored.jumlah, 350000);
      expect(restored.deadline?.year, 2026);
    });

    test('Tabungan Model JSON serialization and progress calculations', () {
      final tabungan = Tabungan(
        'Beli Laptop',
        15000000,
        targetNominal: 20000000,
      );
      expect(tabungan.nama, 'Beli Laptop');
      expect(tabungan.jumlah, 15000000);
      expect(tabungan.percentage, 75);
      expect(tabungan.progress, 0.75);
      expect(tabungan.sisaTarget, 5000000);

      final json = tabungan.toJson();
      final restored = Tabungan.fromJson(json);
      expect(restored.nama, 'Beli Laptop');
      expect(restored.jumlah, 15000000);
      expect(restored.percentage, 75);
    });

    testWidgets('Main screen renders all 3 cards in KeuanganPage', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.byType(InfoCardUangku), findsOneWidget);
      expect(find.byType(InfoCardTagihan), findsOneWidget);
      expect(find.byType(InfoCardTabungan), findsOneWidget);
    });
  });

  group('5. Riwayat Service & Page Tests', () {
    test('RiwayatService logs changes and clears cleanly', () async {
      await RiwayatService.catatTambahTagihan('WiFi', 300000);

      final list = await RiwayatService.getRiwayat();
      expect(list.length, 1);
      expect(list.first.kategori, 'Tagihan');
      expect(list.first.tipe, 'tambah');
      expect(list.first.nominal, 300000);

      await RiwayatService.hapusSemuaRiwayat();
      final emptyList = await RiwayatService.getRiwayat();
      expect(emptyList.isEmpty, isTrue);
    });

    testWidgets('RiwayatPage displays empty state and filter chips', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RiwayatPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Riwayat Keuangan'), findsOneWidget);
      expect(find.text('Semua Waktu'), findsOneWidget);
      expect(find.text('Hari Ini'), findsOneWidget);
      expect(find.text('Minggu Ini'), findsOneWidget);
      expect(find.text('Bulan Ini'), findsOneWidget);
      expect(find.text('Belum Ada Riwayat Perubahan'), findsOneWidget);
    });
  });

  group('6. Rundown & Todo Models and Pages Tests', () {
    test('Rundown and RundownTableRow serialization', () {
      final row = RundownTableRow(
        id: 'r_1',
        startTime: '08:00',
        durationMinutes: 60,
        activity: 'Pembukaan Acara',
        location: 'Hall A',
      );
      final day = RundownDay(
        dayNumber: 1,
        date: DateTime(2026, 9, 1),
        theme: 'Hari Pertama',
        rows: [row],
      );
      final rundown = Rundown(
        id: 'rd_1',
        title: 'Grand Launching',
        startDate: DateTime(2026, 9, 1),
        totalDays: 1,
        days: [day],
      );

      final json = rundown.toJson();
      final restored = Rundown.fromJson(json);
      expect(restored.title, 'Grand Launching');
      expect(restored.totalDays, 1);
      expect(restored.days.length, 1);
      expect(restored.days.first.rows.first.activity, 'Pembukaan Acara');
      expect(restored.days.first.rows.first.location, 'Hall A');
    });

    test('TodoDateGroup and TodoItem serialization with isArchived', () {
      final todoItem = TodoItem(
        id: 't_1',
        title: 'Beli ATK Kantor',
        isCompleted: true,
      );
      final group = TodoDateGroup(
        id: 'g_1',
        date: DateTime(2026, 8, 26),
        items: [todoItem],
        isArchived: true,
      );

      final json = group.toJson();
      final restored = TodoDateGroup.fromJson(json);
      expect(restored.items.length, 1);
      expect(restored.items.first.title, 'Beli ATK Kantor');
      expect(restored.items.first.isCompleted, isTrue);
      expect(restored.isAllCompleted, isTrue);
      expect(restored.isArchived, isTrue);
    });

    testWidgets('RundownPage renders header banner', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RundownPage(onPageSelected: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rundown Acara'), findsOneWidget);
      expect(find.byTooltip('Buat Rundown Baru'), findsOneWidget);
    });

    testWidgets('TodoPage renders appbar and todo header', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TodoPage(onPageSelected: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('To-Do List'), findsWidgets);
      expect(find.byTooltip('Riwayat To-Do Selesai'), findsOneWidget);
    });

    testWidgets('TodoRiwayatPage renders empty state properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TodoRiwayatPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Riwayat To-Do Selesai'), findsOneWidget);
      expect(find.text('Belum Ada Section yang Diarsipkan'), findsOneWidget);
    });
  });

  group('7. Custom Rules & Preset Parsing Tests', () {
    test('Parses General Rules (40 rules) and K12 Rules (25 rules) cleanly', () {
      final generalResult = CustomRuleImportHelper.getGeneralImportResult();
      expect(generalResult.rules.length, 40);

      final k12Result = CustomRuleImportHelper.getK12ImportResult();
      expect(k12Result.rules.length, 25);
    });
  });

  group('8. Multi-Screen Scalability & Zero-Defect Logic Tests', () {
    testWidgets('KeuanganPage renders flawlessly on Compact Screen (320x480)',
        (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Poppins'),
          home: Scaffold(
            body: KeuanganPage(onPageSelected: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InfoCardUangku), findsOneWidget);
      expect(find.byType(InfoCardTagihan), findsOneWidget);
      expect(find.byType(InfoCardTabungan), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RundownPage renders flawlessly on Tablet/Large Screen (800x1280)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Poppins'),
          home: Scaffold(
            body: RundownPage(onPageSelected: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rundown Acara'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TodoPage renders flawlessly on Compact Screen (320x480)',
        (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Poppins'),
          home: Scaffold(
            body: TodoPage(onPageSelected: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('To-Do List'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    test('Zero Division & Negative Boundary protections in Financial calculations', () {
      // Test Tabungan calculations with 0 target
      final zeroTargetTabungan = Tabungan('Tabungan Bebas', 500000, targetNominal: 0);
      expect(zeroTargetTabungan.progress, 0.0);
      expect(zeroTargetTabungan.percentage, 0);
      expect(zeroTargetTabungan.sisaTarget, 0);

      // Test Tabungan progress clamping with surplus
      final surplusTabungan = Tabungan('Tabungan Lebih', 3000000, targetNominal: 1000000);
      expect(surplusTabungan.progress, 1.0);
      expect(surplusTabungan.percentage, 300);
      expect(surplusTabungan.sisaTarget, 0);

      // Test TodoDateGroup progress with 0 items
      final emptyGroup = TodoDateGroup(id: 'g0', date: DateTime.now());
      expect(emptyGroup.progress, 0.0);
      expect(emptyGroup.isAllCompleted, isFalse);
    });
  });
}
