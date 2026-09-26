import 'package:daily_apps/models/model_pribadi.dart';
import 'package:daily_apps/pages/pribadi_page.dart';
import 'package:daily_apps/utils/pribadi_saldo_awal_service.dart';
import 'package:daily_apps/utils/pribadi_sync_service.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PribadiSaldoAwalService Tests', () {
    test('getPreviousMonthKey calculates previous month key correctly', () {
      expect(PribadiSaldoAwalService.getPreviousMonthKey('2026_10'), '2026_09');
      expect(PribadiSaldoAwalService.getPreviousMonthKey('2026_01'), '2025_12');
    });

    test('getTanggalSatuBulan returns date of 1st day of the month', () {
      final date = PribadiSaldoAwalService.getTanggalSatuBulan('2026_10');
      expect(date.year, 2026);
      expect(date.month, 10);
      expect(date.day, 1);
    });

    test('calculateSisaDana calculates remaining balance correctly', () {
      final dataWithPos = PribadiData(
        posDanaList: [
          PosDana(id: 'pos_1', nama: 'Cash', balance: 750000),
          PosDana(id: 'pos_2', nama: 'BCA', balance: 250000),
        ],
      );
      expect(PribadiSaldoAwalService.calculateSisaDana(dataWithPos), 1000000);

      final dataWithTx = PribadiData(
        transactions: [
          PribadiTransaction(
            id: 'tx_1',
            title: 'Gaji',
            type: 'pemasukan',
            amount: 5000000,
          ),
          PribadiTransaction(
            id: 'tx_2',
            title: 'Sewa',
            type: 'pengeluaran',
            amount: 2000000,
          ),
        ],
      );
      expect(PribadiSaldoAwalService.calculateSisaDana(dataWithTx), 3000000);
    });

    test('getBreakdownSisaDanaBulanSebelumnya returns list of pos with remaining balances', () async {
      final septKey = '2026_09';
      final octKey = '2026_10';

      final septData = PribadiData(
        posDanaList: [
          PosDana(id: 'pos_1', nama: 'Cash', balance: 150000),
          PosDana(id: 'pos_2', nama: 'BCA', balance: 350000),
          PosDana(id: 'pos_3', nama: 'GoPay', balance: 50000),
        ],
      );
      await PribadiSyncService.savePribadiData(septKey, septData);

      final breakdown = await PribadiSaldoAwalService.getBreakdownSisaDanaBulanSebelumnya(octKey);
      expect(breakdown.length, 3);
      expect(breakdown[0].nama, 'Cash');
      expect(breakdown[0].sisaSaldo, 150000);
      expect(breakdown[1].nama, 'BCA');
      expect(breakdown[1].sisaSaldo, 350000);
      expect(breakdown[2].nama, 'GoPay');
      expect(breakdown[2].sisaSaldo, 50000);
    });

    test('syncSaldoAwal creates Pos Dana and Debit transactions based on previous month Pos Dana', () async {
      final septKey = '2026_09';
      final octKey = '2026_10';

      // Setup September data with multiple Pos Dana
      final septData = PribadiData(
        posDanaList: [
          PosDana(id: 'pos_1', nama: 'Cash', balance: 100000),
          PosDana(id: 'pos_2', nama: 'BCA', balance: 400000),
        ],
      );
      await PribadiSyncService.savePribadiData(septKey, septData);

      // October data initially empty (no pos dana yet)
      final octData = PribadiData(
        posDanaList: [],
        transactions: [],
      );

      // Enable saldo awal for October
      await PribadiSaldoAwalService.setSaldoAwalEnabled(octKey, true);

      // Sync October
      final changed = await PribadiSaldoAwalService.syncSaldoAwal(
        currentMonthKey: octKey,
        currentData: octData,
      );

      expect(changed, isTrue);
      // October now has the 2 Pos Dana from September
      expect(octData.posDanaList.length, 2);
      expect(octData.posDanaList.any((p) => p.nama == 'Cash' && p.balance == 100000), isTrue);
      expect(octData.posDanaList.any((p) => p.nama == 'BCA' && p.balance == 400000), isTrue);

      // And October has 2 Saldo Awal transactions matching each Pos Dana
      expect(octData.transactions.length, 2);

      final cashTx = octData.transactions.firstWhere((t) => t.targetAccount == 'Cash');
      expect(cashTx.timestamp.day, 1);
      expect(cashTx.timestamp.month, 10);
      expect(cashTx.timestamp.year, 2026);
      expect(cashTx.kode, 'Saldo Awal');
      expect(cashTx.note, 'Sisa Dana (Cash)');
      expect(cashTx.type, 'pemasukan'); // Debit
      expect(cashTx.amount, 100000);

      final bcaTx = octData.transactions.firstWhere((t) => t.targetAccount == 'BCA');
      expect(bcaTx.timestamp.day, 1);
      expect(bcaTx.kode, 'Saldo Awal');
      expect(bcaTx.note, 'Sisa Dana (BCA)');
      expect(bcaTx.type, 'pemasukan'); // Debit
      expect(bcaTx.amount, 400000);
    });

    test('syncSaldoAwal dynamically adjusts Pos Dana and transaction if previous month balance changes', () async {
      final septKey = '2026_09';
      final octKey = '2026_10';

      // Setup September data initially with Cash: 500.000
      final septData = PribadiData(
        posDanaList: [
          PosDana(id: 'pos_cash', nama: 'Cash', balance: 500000),
        ],
      );
      await PribadiSyncService.savePribadiData(septKey, septData);

      final octData = PribadiData(
        posDanaList: [],
        transactions: [],
      );
      await PribadiSaldoAwalService.setSaldoAwalEnabled(octKey, true);
      await PribadiSaldoAwalService.syncSaldoAwal(
        currentMonthKey: octKey,
        currentData: octData,
      );

      expect(octData.transactions.first.amount, 500000);
      expect(octData.posDanaList.first.balance, 500000);

      // User spends 100.000 in September -> Cash becomes 400.000
      septData.posDanaList.first.balance = 400000;
      await PribadiSyncService.savePribadiData(septKey, septData);

      // Now sync October again
      final adjusted = await PribadiSaldoAwalService.syncSaldoAwal(
        currentMonthKey: octKey,
        currentData: octData,
      );

      expect(adjusted, isTrue);
      expect(octData.transactions.first.amount, 400000);
      expect(octData.posDanaList.first.balance, 400000);
    });
  });

  group('PribadiPage Saldo Awal UI Tests', () {
    testWidgets('Long press on banner opens Saldo Awal modal and shows Pos Dana breakdown',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final now = DateTime.now();
      final curKey = '${now.year}_${now.month.toString().padLeft(2, '0')}';
      final prevDate = DateTime(now.year, now.month - 1, 1);
      final prevKey = '${prevDate.year}_${prevDate.month.toString().padLeft(2, '0')}';

      // Setup previous month with Cash (150.000) and BCA (200.000)
      final prevData = PribadiData(
        posDanaList: [
          PosDana(id: 'pos_cash', nama: 'Cash', balance: 150000),
          PosDana(id: 'pos_bca', nama: 'BCA', balance: 200000),
        ],
      );
      await PribadiSyncService.savePribadiData(prevKey, prevData);

      await tester.pumpWidget(
        const MaterialApp(
          home: PribadiPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Find Total Dana Pribadi banner
      final bannerFinder = find.textContaining('TOTAL DANA PRIBADI');
      expect(bannerFinder, findsOneWidget);

      // Long press banner to open modal
      await tester.longPress(bannerFinder);
      await tester.pumpAndSettle();

      // Verify modal opened and displays previous month's Pos Dana breakdown
      expect(find.text('Saldo Awal Bulan Ini'), findsOneWidget);
      expect(find.text('Gunakan Sebagai Saldo Awal'), findsOneWidget);
      expect(find.textContaining('350.000'), findsWidgets);
      expect(find.text('Cash'), findsWidgets);
      expect(find.textContaining('150.000'), findsWidgets);
      expect(find.text('BCA'), findsWidgets);
      expect(find.textContaining('200.000'), findsWidgets);

      // Toggle switch to ON
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Tap Terapkan & Simpan
      await tester.tap(find.text('Terapkan & Simpan'));
      await tester.pumpAndSettle();

      // Verify Saldo Awal badge on banner and in transaction list are shown
      expect(find.text('Saldo Awal'), findsWidgets);

      // Total Dana Pribadi now reflects 350.000
      expect(find.textContaining('350.000'), findsWidgets);
    });
  });
}
