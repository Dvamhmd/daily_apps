import 'package:flutter_test/flutter_test.dart';
import 'package:daily_apps/models/model_struktur.dart';

void main() {
  group('Kustom Kode Transaksi Struktur Tests', () {
    test('Default customKodeRules starts from 0 (empty list)', () {
      final data = StrukturData();
      expect(data.customKodeRules, isEmpty);
      expect(CustomKodeRule.defaultRules(), isEmpty);
    });

    test('resolveKodeFromText returns "-" when customRules is empty', () {
      expect(StrukturTransaction.resolveKodeFromText('DP KK Barqi'), equals('-'));
      expect(
          StrukturTransaction.resolveKodeFromText('konsumsi pembinaan',
              customRules: []),
          equals('-'));
    });

    test('Custom rules resolution and precedence', () {
      final customRules = [
        CustomKodeRule(keyword: 'bensin', kode: 'Biaya BBM & Transportasi'),
        CustomKodeRule(keyword: 'honor pemateri', kode: 'Honorarium Pemateri'),
        CustomKodeRule(keyword: 'honor', kode: 'Honorarium Umum'),
        CustomKodeRule(keyword: 'konsumsi', kode: 'Biaya Konsumsi Acara'),
        CustomKodeRule(keyword: 'dp kk', kode: 'Terima DP DTK'),
      ];

      // Match 'bensin'
      expect(
        StrukturTransaction.resolveKodeFromText('Beli bensin motor operasional',
            customRules: customRules),
        equals('Biaya BBM & Transportasi'),
      );

      // Match 'honor pemateri' takes precedence over 'honor' due to longer keyword length
      expect(
        StrukturTransaction.resolveKodeFromText('Bayar honor pemateri kajian',
            customRules: customRules),
        equals('Honorarium Pemateri'),
      );

      // Match general 'honor'
      expect(
        StrukturTransaction.resolveKodeFromText('Bayar honor panitia',
            customRules: customRules),
        equals('Honorarium Umum'),
      );

      // Match 'konsumsi'
      expect(
        StrukturTransaction.resolveKodeFromText('Konsumsi rapat pengurus',
            customRules: customRules),
        equals('Biaya Konsumsi Acara'),
      );

      // No match
      expect(
        StrukturTransaction.resolveKodeFromText('Beli kertas HVS',
            customRules: customRules),
        equals('-'),
      );
    });

    test('Display Kode preserves saved kode or falls back to custom rules', () {
      final customRules = [
        CustomKodeRule(keyword: 'konsumsi', kode: 'Biaya Konsumsi Acara'),
      ];

      final txExplicit = StrukturTransaction(
        id: '1',
        title: 'Pengeluaran Lain',
        type: 'pengeluaran',
        amount: 100000,
        kode: 'Kode Khusus',
      );
      expect(txExplicit.getDisplayKode(customRules: customRules),
          equals('Kode Khusus'));

      final txAuto = StrukturTransaction(
        id: '2',
        title: 'Pengeluaran',
        type: 'pengeluaran',
        amount: 250000,
        note: 'Beli konsumsi pembinaan',
      );
      expect(txAuto.getDisplayKode(customRules: customRules),
          equals('Biaya Konsumsi Acara'));

      final txNoMatch = StrukturTransaction(
        id: '3',
        title: 'Pengeluaran',
        type: 'pengeluaran',
        amount: 50000,
        note: 'Beli spidol',
      );
      expect(txNoMatch.getDisplayKode(customRules: customRules), equals('-'));
    });

    test('JSON serialization preserves kode and customKodeRules', () {
      final tx = StrukturTransaction(
        id: '99',
        title: 'Sewa gedung',
        type: 'pengeluaran',
        amount: 750000,
        kode: 'Sewa Tempat',
      );

      final jsonTx = tx.toJson();
      final fromJsonTx = StrukturTransaction.fromJson(jsonTx);
      expect(fromJsonTx.kode, equals('Sewa Tempat'));
      expect(fromJsonTx.displayKode, equals('Sewa Tempat'));

      final data = StrukturData(
        customKodeRules: [
          CustomKodeRule(keyword: 'donasi', kode: 'Penerimaan Donasi'),
        ],
      );

      final jsonData = data.toJson();
      final fromJsonData = StrukturData.fromJson(jsonData);

      expect(fromJsonData.customKodeRules.length, equals(1));
      expect(fromJsonData.customKodeRules.first.keyword, equals('donasi'));
      expect(fromJsonData.customKodeRules.first.kode, equals('Penerimaan Donasi'));
    });

    test('Dana Operasional excludes pemasukan with DP in code', () {
      final customRules = [
        CustomKodeRule(keyword: 'dp', kode: 'DP Setoran'),
        CustomKodeRule(keyword: 'infaq', kode: 'Infaq Rutin'),
      ];

      final data = StrukturData(
        rekeningStruktur: RekeningStruktur(balance: 1000000),
        onHandDebit: OnHandDebit(balance: 500000),
        onHandCash: OnHandCash(balance: 200000),
        customKodeRules: customRules,
        transactions: [
          // DP Pemasukan (should be excluded from operational funds)
          StrukturTransaction(
            id: '1',
            title: 'DP KK Barqi',
            type: 'pemasukan',
            amount: 300000,
            note: 'DP KK',
          ),
          // Normal Pemasukan (included)
          StrukturTransaction(
            id: '2',
            title: 'Infaq Kas',
            type: 'pemasukan',
            amount: 200000,
            note: 'infaq',
          ),
          // Explicit kode DP
          StrukturTransaction(
            id: '3',
            title: 'Pemasukan Peserta',
            type: 'pemasukan',
            amount: 150000,
            kode: 'DP Angkatan',
          ),
        ],
      );

      expect(data.totalDanaStruktur, equals(1700000));
      expect(data.totalPemasukanDP, equals(450000)); // 300.000 + 150.000
      expect(data.totalDanaOperasional, equals(1250000)); // 1.700.000 - 450.000
    });
  });
}
