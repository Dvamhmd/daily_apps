import 'package:flutter/material.dart';
import 'package:daily_apps/models/model_pribadi.dart';
import 'package:daily_apps/pages/pribadi_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Pribadi Model & Logic Tests', () {
    test('PribadiData initialization and default calculations', () {
      final data = PribadiData(
        rekeningPribadi: RekeningPribadi(
          bankName: 'BCA',
          accountNumber: '123456789',
          accountHolder: 'Test User',
          balance: 1000000,
        ),
        onHandDebit: OnHandDebit(
          bankName: 'Jago',
          accountNumber: '987654321',
          accountHolder: 'Test User',
          balance: 500000,
        ),
        onHandCash: OnHandCash(balance: 250000),
        customKodeRules: PersonalDefaultRules.defaultRules(),
      );

      expect(data.totalOnHand, 750000);
      expect(data.totalDanaPribadi, 1750000);
      expect(data.totalPemasukan, 0);
      expect(data.totalPengeluaran, 0);
    });

    test('PribadiTransaction auto resolution of KU & Kategori', () {
      final rules = [
        ...PersonalDefaultRules.defaultRules(),
        CustomKodeRule(keyword: 'gaji', kode: 'Pemasukan', type: 'ku'),
        CustomKodeRule(keyword: 'makan', kode: 'Kebutuhan Pokok', type: 'ku'),
      ];

      final txGaji = PribadiTransaction(
        id: '1',
        title: 'Penerimaan Gaji Bulanan',
        type: 'pemasukan',
        targetAccount: 'rekening',
        amount: 5000000,
      );

      expect(txGaji.getDisplayKode(customRules: rules), 'Pemasukan Gaji');
      expect(txGaji.getDisplayKu(customRules: rules), 'Pemasukan');

      final txMakan = PribadiTransaction(
        id: '2',
        title: 'Makan Siang di Restoran',
        type: 'pengeluaran',
        sourceAccount: 'debit',
        amount: 75000,
      );

      expect(txMakan.getDisplayKode(customRules: rules), 'Makanan & Minuman');
      expect(txMakan.getDisplayKu(customRules: rules), 'Kebutuhan Pokok');
    });

    test('PribadiCategory summary aggregation logic', () {
      final transactions = [
        PribadiTransaction(
          id: '1',
          title: 'Gaji',
          type: 'pemasukan',
          targetAccount: 'Dana Operasional',
          amount: 3000000,
        ),
        PribadiTransaction(
          id: '2',
          title: 'Bonus',
          type: 'pemasukan',
          targetAccount: 'Dana Tabungan',
          amount: 1000000,
        ),
        PribadiTransaction(
          id: '3',
          title: 'Makan Siang',
          type: 'pengeluaran',
          kode: 'Makanan & Minuman',
          amount: 50000,
        ),
        PribadiTransaction(
          id: '4',
          title: 'Makan Malam',
          type: 'pengeluaran',
          kode: 'Makanan & Minuman',
          amount: 75000,
        ),
        PribadiTransaction(
          id: '5',
          title: 'Bensin Motor',
          type: 'pengeluaran',
          kode: 'Transportasi',
          amount: 30000,
        ),
      ];

      final rules = PersonalDefaultRules.defaultRules();

      // Agregasi Pemasukan berdasarkan Kategori
      final Map<String, int> pemasukanByCat = {};
      for (final t in transactions) {
        if (t.isPemasukan && t.amount > 0) {
          final rawCat = t.getDisplayKode(customRules: rules);
          final catName = (rawCat != '-' && rawCat.trim().isNotEmpty)
              ? rawCat.trim()
              : 'Umum';
          pemasukanByCat[catName] = (pemasukanByCat[catName] ?? 0) + t.amount;
        }
      }
      expect(pemasukanByCat['Pemasukan Gaji'], 3000000);
      expect(pemasukanByCat['Bonus & THR'], 1000000);
      expect(pemasukanByCat.length, 2);

      // Agregasi Pengeluaran berdasarkan Kategori
      final Map<String, int> pengeluaranByCat = {};
      for (final t in transactions) {
        if (t.isPengeluaran && t.amount > 0) {
          final rawCat = t.getDisplayKode(customRules: rules);
          final catName = (rawCat != '-' && rawCat.trim().isNotEmpty)
              ? rawCat.trim()
              : 'Umum';
          pengeluaranByCat[catName] = (pengeluaranByCat[catName] ?? 0) + t.amount;
        }
      }
      expect(pengeluaranByCat['Makanan & Minuman'], 125000);
      expect(pengeluaranByCat['Transportasi'], 30000);
      expect(pengeluaranByCat.length, 2);
    });

    test('PribadiTransaction sorting by timestamp ascending and descending', () {
      final tx1 = PribadiTransaction(
        id: '1',
        title: 'Tx Lama',
        type: 'pengeluaran',
        amount: 10000,
        timestamp: DateTime(2026, 8, 1, 10, 0),
      );
      final tx2 = PribadiTransaction(
        id: '2',
        title: 'Tx Baru',
        type: 'pengeluaran',
        amount: 20000,
        timestamp: DateTime(2026, 8, 15, 14, 0),
      );

      final list = [tx1, tx2];

      // Sort Ascending (Terlama -> Terbaru)
      final ascList = List<PribadiTransaction>.from(list)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      expect(ascList.first.id, '1');
      expect(ascList.last.id, '2');

      // Sort Descending (Terbaru -> Terlama)
      final descList = List<PribadiTransaction>.from(list)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      expect(descList.first.id, '2');
      expect(descList.last.id, '1');
    });

    test('PribadiData rollback safety & negative balance prevention', () {
      final pos1 = PosDana(id: 'pos_1', nama: 'Rekening Utama', balance: 0);
      final pos2 = PosDana(id: 'pos_2', nama: 'Dompet Kas', balance: 100000);

      final data = PribadiData(
        posDanaList: [pos1, pos2],
        transactions: [
          // Pemasukan 500.000 ke pos1
          PribadiTransaction(
            id: 't1',
            title: 'Gaji',
            type: 'pemasukan',
            targetAccount: 'Rekening Utama',
            amount: 500000,
          ),
          // Pengeluaran 300.000 dari pos1
          PribadiTransaction(
            id: 't2',
            title: 'Belanja',
            type: 'pengeluaran',
            sourceAccount: 'Rekening Utama',
            amount: 300000,
          ),
        ],
      );

      // Simulasikan kondisi saldo setelah transaksi terjadi
      pos1.balance = 200000;

      // Fungsi simulasi rollback
      void rollbackTx(PribadiTransaction tx) {
        final total = tx.amount + tx.adminFee;
        if (tx.isPemasukan) {
          final pIdx = data.posDanaList.indexWhere((p) => p.nama == tx.targetAccount || p.id == tx.targetAccount);
          if (pIdx != -1) {
            data.posDanaList[pIdx].balance -= tx.amount;
            if (data.posDanaList[pIdx].balance < 0) data.posDanaList[pIdx].balance = 0;
          }
        } else if (tx.isPengeluaran) {
          final pIdx = data.posDanaList.indexWhere((p) => p.nama == tx.sourceAccount || p.id == tx.sourceAccount);
          if (pIdx != -1) {
            data.posDanaList[pIdx].balance += total;
          }
        }
      }

      // Rollback dari transaksi terakhir (Pengeluaran -> Pemasukan)
      for (final tx in data.transactions.reversed) {
        rollbackTx(tx);
      }

      // Pastikan saldo tidak negatif dan kembali ke kondisi aman
      expect(pos1.balance, greaterThanOrEqualTo(0));
      expect(pos2.balance, greaterThanOrEqualTo(0));
      expect(data.totalDanaPribadi, greaterThanOrEqualTo(0));
    });

    test('PribadiData serialization toJson and fromJson', () {
      final original = PribadiData(
        rekeningPribadi: RekeningPribadi(
          bankName: 'Mandiri',
          accountNumber: '112233',
          accountHolder: 'User A',
          balance: 2000000,
        ),
        transactions: [
          PribadiTransaction(
            id: '10',
            title: 'Bonus',
            type: 'pemasukan',
            targetAccount: 'rekening',
            amount: 500000,
          ),
        ],
      );

      final json = original.toJson();
      final decoded = PribadiData.fromJson(json);

      expect(decoded.rekeningPribadi.bankName, 'Mandiri');
      expect(decoded.rekeningPribadi.balance, 2000000);
      expect(decoded.transactions.length, 1);
      expect(decoded.transactions.first.amount, 500000);
    });

    testWidgets('PribadiPage renders cleanly across multiple screen resolutions',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final screenSizes = [
        const Size(320, 568), // Compact budget phone (iPhone SE / Small Android)
        const Size(360, 800), // Standard Android
        const Size(412, 915), // Large Android (Pixel / Galaxy Ultra)
        const Size(600, 1024), // 7-inch Tablet / Foldable unfolded
        const Size(800, 1280), // 10-inch Tablet
        const Size(800, 400), // Landscape mode Android
      ];

      for (final size in screenSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: PribadiPage(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PribadiPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
