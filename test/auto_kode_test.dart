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

    test('Rincian Pemasukan calculation: Saldo Awal, Dana dari S3, Total Pemasukan Non-DP, Total Pengeluaran, Sisa Saldo, and Dana Kontribusi DP', () {
      final customRules = [
        CustomKodeRule(keyword: 'Saldo Awal', kode: 'Saldo Awal'),
        CustomKodeRule(keyword: 'Dana S3', kode: 'Dana dari S3'),
      ];

      final transactions = [
        StrukturTransaction(
          id: '1',
          title: 'Saldo Awal Bulan',
          type: 'pemasukan',
          amount: 500000,
          note: 'Saldo Awal',
        ),
        StrukturTransaction(
          id: '2',
          title: 'Penerimaan Dana dari S3',
          type: 'pemasukan',
          amount: 1500000,
          note: 'Transfer Dana S3',
        ),
        StrukturTransaction(
          id: '3',
          title: 'DP Peserta KK',
          type: 'pemasukan',
          amount: 750000,
          kode: 'DP Angkatan',
          note: 'DP Masuk',
        ),
        StrukturTransaction(
          id: '4',
          title: 'Beli Konsumsi Rapat',
          type: 'pengeluaran',
          amount: 300000,
          note: 'Konsumsi',
        ),
        StrukturTransaction(
          id: '5',
          title: 'Beli ATK & Perlengkapan',
          type: 'pengeluaran',
          amount: 200000,
          note: 'ATK',
        ),
      ];

      final pemasukanList = transactions.where((tx) => tx.isPemasukan).toList();
      final pengeluaranList = transactions.where((tx) => tx.isPengeluaran).toList();

      final pemasukanNonDP = pemasukanList.where((tx) => !tx.isDPTransaction(customRules: customRules)).toList();
      final pemasukanDP = pemasukanList.where((tx) => tx.isDPTransaction(customRules: customRules)).toList();

      int saldoAwalNominal = 0;
      int danaS3Nominal = 0;
      final Map<String, int> pemasukanLainMap = {};

      for (final tx in pemasukanNonDP) {
        final rawKategori = tx.getDisplayKode(customRules: customRules).trim();
        final kategoriLower = rawKategori.toLowerCase();
        final isSaldoAwal = kategoriLower.contains('saldo awal');
        final isDanaS3 = !isSaldoAwal &&
            (kategoriLower.contains('dana dari s3') ||
                kategoriLower.contains('dana s3') ||
                kategoriLower == 's3');

        if (isSaldoAwal) {
          saldoAwalNominal += tx.amount;
        } else if (isDanaS3) {
          danaS3Nominal += tx.amount;
        } else {
          final name = rawKategori.isEmpty || rawKategori == '-' ? 'Lainnya' : rawKategori;
          pemasukanLainMap[name] = (pemasukanLainMap[name] ?? 0) + tx.amount;
        }
      }

      final totalPemasukanNonDP = pemasukanNonDP.fold<int>(0, (sum, tx) => sum + tx.amount);
      final totalPemasukanDP = pemasukanDP.fold<int>(0, (sum, tx) => sum + tx.amount);
      final totalPengeluaran = pengeluaranList.fold<int>(0, (sum, tx) => sum + tx.amount);
      final sisaSaldo = totalPemasukanNonDP - totalPengeluaran;

      expect(saldoAwalNominal, equals(500000));
      expect(danaS3Nominal, equals(1500000));
      expect(totalPemasukanNonDP, equals(2000000));
      expect(totalPemasukanDP, equals(750000));
      expect(totalPengeluaran, equals(500000));
      expect(sisaSaldo, equals(1500000));
    });

    test('Pemasukan with unconfigured keyword goes to Lainnya and not Dana dari S3', () {
      // Empty rules (no rule for "s3" or "dana turun dari s3")
      final customRules = <CustomKodeRule>[];

      final tx = StrukturTransaction(
        id: '1',
        title: 'Pemasukan',
        type: 'pemasukan',
        amount: 500000,
        note: 'Dana turun dari S3',
      );

      final rawKategori = tx.getDisplayKode(customRules: customRules).trim();
      expect(rawKategori, equals('-'));

      final kategoriLower = rawKategori.toLowerCase();
      final isSaldoAwal = kategoriLower.contains('saldo awal');
      final isDanaS3 = !isSaldoAwal &&
          (kategoriLower.contains('dana dari s3') ||
              kategoriLower.contains('dana s3') ||
              kategoriLower == 's3');

      expect(isSaldoAwal, isFalse);
      expect(isDanaS3, isFalse);
    });

    test('Tab Pengeluaran: Saldo Awal, Dana dari S3, and DP are excluded from Kategori Pengeluaran map and aggregation', () {
      final customRules = [
        CustomKodeRule(keyword: 'Saldo Awal', kode: 'Saldo Awal'),
        CustomKodeRule(keyword: 'Dana S3', kode: 'Dana dari S3'),
        CustomKodeRule(keyword: 'DP', kode: 'DP Angkatan'),
        CustomKodeRule(keyword: 'Konsumsi', kode: 'Konsumsi'),
        CustomKodeRule(keyword: 'ATK', kode: 'ATK'),
      ];

      final pengeluaranKategoriMap = <String, int>{};
      final pengeluaranKategoriCountMap = <String, int>{};

      // 1. Initial categories from customKodeRules (type != 'ku')
      for (final r in customRules.where((r) => r.type != 'ku')) {
        final name = r.kode.trim();
        final nameLower = name.toLowerCase();
        final bool isSaldoAwal = nameLower.contains('saldo awal');
        final bool isDanaS3 = !isSaldoAwal &&
            (nameLower.contains('dana dari s3') ||
                nameLower.contains('dana s3') ||
                nameLower == 's3');

        if (name.isNotEmpty &&
            !name.toUpperCase().contains('DP') &&
            !isSaldoAwal &&
            !isDanaS3 &&
            !pengeluaranKategoriMap.containsKey(name)) {
          pengeluaranKategoriMap[name] = 0;
          pengeluaranKategoriCountMap[name] = 0;
        }
      }

      expect(pengeluaranKategoriMap.containsKey('Saldo Awal'), isFalse);
      expect(pengeluaranKategoriMap.containsKey('Dana dari S3'), isFalse);
      expect(pengeluaranKategoriMap.containsKey('DP Angkatan'), isFalse);
      expect(pengeluaranKategoriMap.containsKey('Konsumsi'), isTrue);
      expect(pengeluaranKategoriMap.containsKey('ATK'), isTrue);

      // 2. Transaction aggregation
      final pengeluaranList = [
        StrukturTransaction(
          id: '1',
          title: 'Konsumsi Rapat',
          type: 'pengeluaran',
          amount: 50000,
          kode: 'Konsumsi',
        ),
        StrukturTransaction(
          id: '2',
          title: 'Beli ATK',
          type: 'pengeluaran',
          amount: 25000,
          kode: 'ATK',
        ),
        StrukturTransaction(
          id: '3',
          title: 'Misc Saldo Awal',
          type: 'pengeluaran',
          amount: 10000,
          kode: 'Saldo Awal',
        ),
        StrukturTransaction(
          id: '4',
          title: 'Misc Dana S3',
          type: 'pengeluaran',
          amount: 20000,
          kode: 'Dana dari S3',
        ),
        StrukturTransaction(
          id: '5',
          title: 'DP Pengeluaran',
          type: 'pengeluaran',
          amount: 30000,
          kode: 'DP Angkatan',
        ),
      ];

      for (final tx in pengeluaranList) {
        final rawKategori = tx.getDisplayKode(customRules: customRules).trim();
        final kategori = rawKategori.isEmpty ? '-' : rawKategori;
        final kategoriLower = kategori.toLowerCase();
        final bool isSaldoAwal = kategoriLower.contains('saldo awal');
        final bool isDanaS3 = !isSaldoAwal &&
            (kategoriLower.contains('dana dari s3') ||
                kategoriLower.contains('dana s3') ||
                kategoriLower == 's3');

        if (kategori.toUpperCase().contains('DP') ||
            isSaldoAwal ||
            isDanaS3 ||
            tx.isDPTransaction(customRules: customRules)) {
          continue;
        }

        String matchedKey = kategori;
        for (final k in pengeluaranKategoriMap.keys) {
          if (k.toLowerCase() == kategori.toLowerCase()) {
            matchedKey = k;
            break;
          }
        }
        pengeluaranKategoriMap[matchedKey] =
            (pengeluaranKategoriMap[matchedKey] ?? 0) + tx.amount;
        pengeluaranKategoriCountMap[matchedKey] =
            (pengeluaranKategoriCountMap[matchedKey] ?? 0) + 1;
      }

      expect(pengeluaranKategoriMap['Konsumsi'], equals(50000));
      expect(pengeluaranKategoriCountMap['Konsumsi'], equals(1));
      expect(pengeluaranKategoriMap['ATK'], equals(25000));
      expect(pengeluaranKategoriCountMap['ATK'], equals(1));
      expect(pengeluaranKategoriMap.containsKey('Saldo Awal'), isFalse);
      expect(pengeluaranKategoriMap.containsKey('Dana dari S3'), isFalse);
      expect(pengeluaranKategoriMap.containsKey('DP Angkatan'), isFalse);
    });
  });
}

