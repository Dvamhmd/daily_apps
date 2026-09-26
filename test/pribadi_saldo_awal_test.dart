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

    test('syncSaldoAwal creates Debit transaction with Tanggal 1 and Saldo Awal category', () async {
      final septKey = '2026_09';
      final octKey = '2026_10';

      // Setup September data with 500.000 sisa dana
      final septData = PribadiData(
        posDanaList: [
          PosDana(id: 'pos_1', nama: 'Cash', balance: 500000),
        ],
        transactions: [
          PribadiTransaction(
            id: 'tx_gaji',
            title: 'Gaji',
            type: 'pemasukan',
            amount: 500000,
            timestamp: DateTime(2026, 9, 5),
          ),
        ],
      );
      await PribadiSyncService.savePribadiData(septKey, septData);

      // October data initially empty
      final octData = PribadiData(
        posDanaList: [
          PosDana(id: 'pos_1', nama: 'Cash', balance: 0),
        ],
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
      expect(octData.transactions.length, 1);

      final saldoAwalTx = octData.transactions.first;
      expect(saldoAwalTx.timestamp.day, 1);
      expect(saldoAwalTx.timestamp.month, 10);
      expect(saldoAwalTx.timestamp.year, 2026);
      expect(saldoAwalTx.kode, 'Saldo Awal');
      expect(saldoAwalTx.note, 'Sisa dana bulan kemarin');
      expect(saldoAwalTx.title, 'Sisa dana bulan kemarin');
      expect(saldoAwalTx.type, 'pemasukan'); // Debit
      expect(saldoAwalTx.amount, 500000);
      expect(octData.posDanaList.first.balance, 500000);
    });

    test('syncSaldoAwal dynamically adjusts if previous month remaining balance changes', () async {
      final septKey = '2026_09';
      final octKey = '2026_10';

      // Setup September data initially with 500.000 sisa dana
      final septData = PribadiData(
        posDanaList: [
          PosDana(id: 'pos_cash', nama: 'Cash', balance: 500000),
        ],
        transactions: [
          PribadiTransaction(
            id: 'tx_sept',
            title: 'Gaji',
            type: 'pemasukan',
            amount: 500000,
            timestamp: DateTime(2026, 9, 1),
          ),
        ],
      );
      await PribadiSyncService.savePribadiData(septKey, septData);

      final octData = PribadiData(
        posDanaList: [
          PosDana(id: 'pos_cash', nama: 'Cash', balance: 0),
        ],
        transactions: [],
      );
      await PribadiSaldoAwalService.setSaldoAwalEnabled(octKey, true);
      await PribadiSaldoAwalService.syncSaldoAwal(
        currentMonthKey: octKey,
        currentData: octData,
      );

      expect(octData.transactions.first.amount, 500000);
      expect(octData.posDanaList.first.balance, 500000);

      // User spends 100.000 in September -> sisa becomes 400.000
      septData.posDanaList.first.balance = 400000;
      septData.transactions.add(
        PribadiTransaction(
          id: 'tx_makan',
          title: 'Makan',
          type: 'pengeluaran',
          amount: 100000,
          timestamp: DateTime(2026, 9, 15),
        ),
      );
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
    testWidgets('Long press on magenta banner opens Saldo Awal modal and can toggle',
        (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final now = DateTime.now();
      final curKey = '${now.year}_${now.month.toString().padLeft(2, '0')}';
      final prevDate = DateTime(now.year, now.month - 1, 1);
      final prevKey = '${prevDate.year}_${prevDate.month.toString().padLeft(2, '0')}';

      // Setup previous month with 350.000
      final prevData = PribadiData(
        posDanaList: [
          PosDana(id: 'pos_cash', nama: 'Cash', balance: 350000),
        ],
        transactions: [
          PribadiTransaction(
            id: 'tx_1',
            title: 'Gaji',
            type: 'pemasukan',
            amount: 350000,
            timestamp: prevDate,
          ),
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

      // Verify modal opened
      expect(find.text('Saldo Awal Bulan Ini'), findsOneWidget);
      expect(find.text('Gunakan Sebagai Saldo Awal'), findsOneWidget);
      expect(find.textContaining('350.000'), findsWidgets);

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
