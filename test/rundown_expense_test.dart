import 'dart:convert';
import 'package:daily_apps/models/model_pribadi.dart';
import 'package:daily_apps/models/model_rundown.dart';
import 'package:daily_apps/models/model_uangku.dart';
import 'package:daily_apps/pages/rundown_detail_page.dart';
import 'package:daily_apps/utils/pribadi_sync_service.dart';
import 'package:daily_apps/utils/riwayat_service.dart';
import 'package:daily_apps/utils/rundown_expense_service.dart';
import 'package:daily_apps/widgets/dialog_rundown_expense.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RundownExpenseItem & Rundown Model Tests', () {
    test('RundownExpenseItem serializes and deserializes correctly', () {
      final item = RundownExpenseItem(
        id: 'exp_1',
        nama: 'Bensin',
        nominalEstimasi: 20000,
        nominalRealisasi: 12000,
        posDana: 'Operasional',
        tanggalRealisasi: DateTime(2026, 9, 18, 10, 0),
        isRealized: true,
        catatan: 'Bensin mobil panitia',
      );

      final json = item.toJson();
      final fromJson = RundownExpenseItem.fromJson(json);

      expect(fromJson.id, 'exp_1');
      expect(fromJson.nama, 'Bensin');
      expect(fromJson.nominalEstimasi, 20000);
      expect(fromJson.nominalRealisasi, 12000);
      expect(fromJson.posDana, 'Operasional');
      expect(fromJson.isRealized, isTrue);
      expect(fromJson.catatan, 'Bensin mobil panitia');
    });

    test('Rundown calculations for expenses are accurate', () {
      final rundown = Rundown(
        id: 'rd_1',
        title: 'Acara Kantor',
        startDate: DateTime(2026, 9, 18),
        totalDays: 1,
        days: [],
        expenses: [
          RundownExpenseItem(
            id: 'exp_1',
            nama: 'Bensin',
            nominalEstimasi: 20000,
            nominalRealisasi: 12000,
            posDana: 'Operasional',
            isRealized: true,
          ),
          RundownExpenseItem(
            id: 'exp_2',
            nama: 'Konsumsi Snack',
            nominalEstimasi: 100000,
            isRealized: false,
          ),
          RundownExpenseItem(
            id: 'exp_3',
            nama: 'Air Mineral',
            nominalEstimasi: 30000,
            nominalRealisasi: 35000,
            posDana: 'Kas Kecil',
            isRealized: true,
          ),
        ],
      );

      // Total Estimasi = 20.000 + 100.000 + 30.000 = 150.000
      expect(rundown.totalEstimasiPengeluaran, 150000);

      // Total Realisasi = 12.000 + 35.000 = 47.000
      expect(rundown.totalRealisasiPengeluaran, 47000);

      // Selisih = 150.000 - 47.000 = 103.000
      expect(rundown.selisihPengeluaran, 103000);

      // Total Terealisasi = 2 item
      expect(rundown.totalItemTerealisasi, 2);
      expect(rundown.hasExpenses, isTrue);
    });
  });

  group('RundownExpenseService Integration Tests', () {
    test('executeRealisasi cuts Pos Dana in Uangku & Keuangan Pribadi and records transaction',
        () async {
      final now = DateTime(2026, 9, 18);
      final monthKey = PribadiSyncService.getMonthKey(now, null);

      // Setup initial Uangku / Pos Dana data
      await PribadiSyncService.saveUangkuList(monthKey, [
        Uangku('Dana Operasional', 500000),
        Uangku('BCA', 1000000),
      ]);

      final pData = PribadiData(
        posDanaList: [
          PosDana(id: 'pos_op', nama: 'Dana Operasional', balance: 500000),
          PosDana(id: 'pos_bca', nama: 'BCA', balance: 1000000),
        ],
        transactions: [],
      );
      await PribadiSyncService.savePribadiData(monthKey, pData);

      final rundown = Rundown(
        id: 'rd_test',
        title: 'Gathering 2026',
        startDate: now,
        totalDays: 1,
        days: [],
      );

      final item = RundownExpenseItem(
        id: 'exp_bensin',
        nama: 'Bensin',
        nominalEstimasi: 20000,
      );

      // Realisasi diisi Rp 12.000 dari Pos Dana "Dana Operasional"
      final updatedItem = await RundownExpenseService.executeRealisasi(
        rundown: rundown,
        item: item,
        nominalRealisasi: 12000,
        posDanaNama: 'Dana Operasional',
        tanggalRealisasi: now,
        catatan: 'Bensin Avanza',
        selectedMonth: now,
      );

      expect(updatedItem.isRealized, isTrue);
      expect(updatedItem.nominalRealisasi, 12000);
      expect(updatedItem.posDana, 'Dana Operasional');

      // 1. Verifikasi saldo Uangku (Keuangan Utama) berkurang Rp 12.000 -> Rp 488.000
      final updatedUList = await PribadiSyncService.loadUangkuList(monthKey);
      final uOp = updatedUList.firstWhere((u) => u.nama == 'Dana Operasional');
      expect(uOp.jumlah, 488000);

      // 2. Verifikasi saldo Pos Dana di Keuangan Pribadi berkurang Rp 12.000 -> Rp 488.000
      final updatedPData = await PribadiSyncService.loadPribadiData(monthKey);
      final posOp =
          updatedPData.posDanaList.firstWhere((p) => p.nama == 'Dana Operasional');
      expect(posOp.balance, 488000);

      // 3. Verifikasi Transaksi Pengeluaran tercatat di Keuangan Pribadi
      expect(updatedPData.transactions.length, 1);
      final tx = updatedPData.transactions.first;
      expect(tx.isPengeluaran, isTrue);
      expect(tx.amount, 12000);
      expect(tx.sourceAccount, 'Dana Operasional');
      expect(tx.title, contains('Rundown: Gathering 2026 - Bensin'));

      // 4. Verifikasi Riwayat Keuangan tercatat
      final riwayat = await RiwayatService.getRiwayat();
      expect(riwayat.isNotEmpty, isTrue);
      expect(riwayat.first.kategori, 'Rundown');
      expect(riwayat.first.perubahan, contains('Realisasi Bensin'));
      expect(riwayat.first.nominal, 12000);

      // 5. Test Rollback / Revert Realisasi
      final revertedItem = await RundownExpenseService.revertRealisasi(
        rundown: rundown,
        item: updatedItem,
        selectedMonth: now,
      );

      expect(revertedItem.isRealized, isFalse);
      expect(revertedItem.nominalRealisasi, isNull);
      expect(revertedItem.posDana, isNull);

      // Verifikasi saldo kembali ke Rp 500.000
      final revertedUList = await PribadiSyncService.loadUangkuList(monthKey);
      expect(revertedUList.first.jumlah, 500000);

      final revertedPData = await PribadiSyncService.loadPribadiData(monthKey);
      expect(revertedPData.posDanaList.first.balance, 500000);
      expect(revertedPData.transactions.isEmpty, isTrue);
    });
  });

  group('Rundown Expense UI Tests', () {
    testWidgets(
        'RundownDetailPage renders Quick Summary card and opens ModalEstimasiPengeluaran',
        (WidgetTester tester) async {
      final sampleRundown = Rundown(
        id: 'rd_ui_test',
        title: 'Gathering 2026',
        startDate: DateTime(2026, 9, 18),
        totalDays: 1,
        days: [
          RundownDay.createWithDefaultRows(
            dayNumber: 1,
            date: DateTime(2026, 9, 18),
            theme: 'Main Event',
          ),
        ],
        expenses: [
          RundownExpenseItem(
            id: 'exp_1',
            nama: 'Bensin',
            nominalEstimasi: 20000,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RundownDetailPage(rundown: sampleRundown),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Quick Summary card
      expect(find.text('Estimasi Biaya Acara'), findsOneWidget);
      expect(find.textContaining('Est: Rp 20.000'), findsOneWidget);
      expect(find.text('Kelola'), findsOneWidget);

      // Tap Kelola to open ModalEstimasiPengeluaran
      await tester.tap(find.text('Kelola'));
      await tester.pumpAndSettle();

      // Verify Modal items
      expect(find.text('Estimasi & Realisasi Biaya'), findsOneWidget);
      expect(find.text('TOTAL ESTIMASI'), findsOneWidget);
      expect(find.text('TOTAL REALISASI'), findsOneWidget);
      expect(find.text('Bensin'), findsOneWidget);
      expect(find.text('Isi Realisasi'), findsOneWidget);
    });
  });
}
