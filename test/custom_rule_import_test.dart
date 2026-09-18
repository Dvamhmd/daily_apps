import 'package:daily_apps/models/model_struktur.dart';
import 'package:daily_apps/utils/custom_rule_import_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomRuleImportHelper Tests', () {
    test('Parse Tab-delimited (Excel Paste)', () {
      final text = '''
Jenis Aturan\tKeterangan Pemicu\tHasil
KU\trapat\tSekretaris
KU\tpengabaran\tPublikasi
Kategori\tKonsumsi\tKonsumsi
''';

      final result = CustomRuleImportHelper.parseText(text);
      expect(result.isSuccess, isTrue);
      expect(result.rules.length, 3);
      expect(result.kuCount, 2);
      expect(result.kategoriCount, 1);

      expect(result.rules[0].type, 'ku');
      expect(result.rules[0].keyword, 'rapat');
      expect(result.rules[0].kode, 'Sekretaris');

      expect(result.rules[1].type, 'ku');
      expect(result.rules[1].keyword, 'pengabaran');
      expect(result.rules[1].kode, 'Publikasi');

      expect(result.rules[2].type, 'kategori');
      expect(result.rules[2].keyword, 'Konsumsi');
      expect(result.rules[2].kode, 'Konsumsi');
    });

    test('Parse Pipe-delimited (Markdown Table)', () {
      final text = '''
| Jenis Aturan | Keterangan Pemicu | Hasil |
| --- | --- | --- |
| KU | rapat | Sekretaris |
| KU | pengabaran | Publikasi |
| Kategori | Konsumsi | Konsumsi |
''';

      final result = CustomRuleImportHelper.parseText(text);
      expect(result.isSuccess, isTrue);
      expect(result.rules.length, 3);
      expect(result.kuCount, 2);
      expect(result.kategoriCount, 1);
      expect(result.rules[0].keyword, 'rapat');
      expect(result.rules[0].kode, 'Sekretaris');
    });

    test('Parse CSV text', () {
      final text = '''
Jenis Aturan,Keterangan Pemicu,Hasil
KU,rapat,Sekretaris
KU,pengabaran,Publikasi
Kategori,Konsumsi,Konsumsi
''';

      final result = CustomRuleImportHelper.parseText(text);
      expect(result.isSuccess, isTrue);
      expect(result.rules.length, 3);
      expect(result.kuCount, 2);
      expect(result.kategoriCount, 1);
    });

    test('Parse mixed KU and Kategori rules when defaultType is ku (e.g. from KU tab)', () {
      final buffer = StringBuffer();
      buffer.writeln('Jenis Aturan\tKeterangan Pemicu\tHasil');
      for (int i = 1; i <= 26; i++) {
        buffer.writeln('KU\tkeyword_ku_$i\tHasil_KU_$i');
      }
      for (int i = 1; i <= 26; i++) {
        buffer.writeln('Kategori\tkeyword_kat_$i\tHasil_KAT_$i');
      }

      // Simulate parsing when the user is on the 'ku' tab (defaultType = 'ku')
      final resultKuTab = CustomRuleImportHelper.parseText(buffer.toString(), defaultType: 'ku');
      expect(resultKuTab.isSuccess, isTrue);
      expect(resultKuTab.rules.length, 52);
      expect(resultKuTab.kuCount, 26);
      expect(resultKuTab.kategoriCount, 26);

      // Simulate parsing when the user is on the 'kategori' tab (defaultType = 'kategori')
      final resultKatTab = CustomRuleImportHelper.parseText(buffer.toString(), defaultType: 'kategori');
      expect(resultKatTab.isSuccess, isTrue);
      expect(resultKatTab.rules.length, 52);
      expect(resultKatTab.kuCount, 26);
      expect(resultKatTab.kategoriCount, 26);
    });

    test('Parse Excel Bytes generated from template', () {
      final bytes = CustomRuleImportHelper.generateTemplateExcelBytes();
      final result = CustomRuleImportHelper.parseExcelBytes(bytes);

      expect(result.isSuccess, isTrue);
      expect(result.rules.length, 5);
      expect(result.kuCount, 3);
      expect(result.kategoriCount, 2);
    });

    test('Apply Import Merge Mode', () {
      final currentRules = [
        CustomKodeRule(keyword: 'rapat', kode: 'Sekretariat Lama', type: 'ku'),
        CustomKodeRule(keyword: 'snack', kode: 'Konsumsi', type: 'kategori'),
      ];

      final importedRules = [
        CustomKodeRule(keyword: 'rapat', kode: 'Sekretaris Baru', type: 'ku'),
        CustomKodeRule(keyword: 'bensin', kode: 'Transportasi', type: 'kategori'),
      ];

      final merged = CustomRuleImportHelper.applyImport(
        currentRules: currentRules,
        importedRules: importedRules,
        replaceAll: false,
      );

      expect(merged.length, 3);
      // 'rapat' KU should be updated
      final rapat = merged.firstWhere((r) => r.keyword == 'rapat' && r.type == 'ku');
      expect(rapat.kode, 'Sekretaris Baru');
      // 'snack' remains
      expect(merged.any((r) => r.keyword == 'snack'), isTrue);
      // 'bensin' added
      expect(merged.any((r) => r.keyword == 'bensin'), isTrue);
    });

    test('Apply Import Replace All Mode', () {
      final currentRules = [
        CustomKodeRule(keyword: 'rapat', kode: 'Sekretariat Lama', type: 'ku'),
      ];

      final importedRules = [
        CustomKodeRule(keyword: 'bensin', kode: 'Transportasi', type: 'kategori'),
      ];

      final replaced = CustomRuleImportHelper.applyImport(
        currentRules: currentRules,
        importedRules: importedRules,
        replaceAll: true,
      );

      expect(replaced.length, 1);
      expect(replaced.first.keyword, 'bensin');
    });

    test('General Rules preset contains 40 rules (26 KU and 14 Kategori)', () {
      final generalResult = CustomRuleImportHelper.getGeneralImportResult();
      expect(generalResult.isSuccess, isTrue);
      expect(generalResult.rules.length, 40);
      expect(generalResult.kuCount, 26);
      expect(generalResult.kategoriCount, 14);
    });

    test('K12 Rules preset contains 52 rules (26 KU & 26 Kategori) and password is Yu5uf1253', () {
      expect(CustomRuleImportHelper.k12Password, equals('Yu5uf1253'));
      final k12Result = CustomRuleImportHelper.getK12ImportResult();
      expect(k12Result.isSuccess, isTrue);
      expect(k12Result.rules.length, 52);
      expect(k12Result.kuCount, 26);
      expect(k12Result.kategoriCount, 26);

      // Verify specific K12 Kategori rules requested by user
      final dpKk = k12Result.rules.firstWhere((r) => r.keyword == 'DP KK' && r.type == 'kategori');
      expect(dpKk.kode, 'Terima DP DTK');

      final danaTurun = k12Result.rules.firstWhere((r) => r.keyword == 'Dana turun');
      expect(danaTurun.kode, 'Kontribusi DP S4');

      final kirimDp = k12Result.rules.firstWhere((r) => r.keyword == 'Kirim DP ke S3');
      expect(kirimDp.kode, 'Kirim DP DTK ke S3');

      final setorDana = k12Result.rules.firstWhere((r) => r.keyword == 'Setor Dana Kontribusi ke S3');
      expect(setorDana.kode, 'Kirim DP DTK ke S3');

      final kirimDana = k12Result.rules.firstWhere((r) => r.keyword == 'Kirim Dana Kontribusi ke S3');
      expect(kirimDana.kode, 'Kirim DP DTK ke S3');

      final bensin = k12Result.rules.firstWhere((r) => r.keyword == 'Bensin' && r.type == 'kategori');
      expect(bensin.kode, 'Biaya Transportasi Lokal');

      final internet = k12Result.rules.firstWhere((r) => r.keyword == 'Internet');
      expect(internet.kode, 'Biaya Komunikasi dan Internet');

      final kuota = k12Result.rules.firstWhere((r) => r.keyword == 'Kuota');
      expect(kuota.kode, 'Biaya Komunikasi dan Internet');

      final pulsa = k12Result.rules.firstWhere((r) => r.keyword == 'Pulsa' && r.type == 'kategori');
      expect(pulsa.kode, 'Biaya Komunikasi dan Internet');

      final sewa = k12Result.rules.firstWhere((r) => r.keyword == 'Sewa');
      expect(sewa.kode, 'Sewa Tempat');

      final konsumsi = k12Result.rules.firstWhere((r) => r.keyword == 'Konsumsi');
      expect(konsumsi.kode, 'Biaya Konsumsi Acara');

      final air = k12Result.rules.firstWhere((r) => r.keyword == 'Air');
      expect(air.kode, 'Biaya Listrik dan Air');

      final listrik = k12Result.rules.firstWhere((r) => r.keyword == 'Listrik');
      expect(listrik.kode, 'Biaya Listrik dan Air');

      final spidol = k12Result.rules.firstWhere((r) => r.keyword == 'Spidol');
      expect(spidol.kode, 'Biaya ATK');

      final bolpoin = k12Result.rules.firstWhere((r) => r.keyword == 'Bolpoin');
      expect(bolpoin.kode, 'Biaya ATK');

      final pulpen = k12Result.rules.firstWhere((r) => r.keyword == 'Pulpen');
      expect(pulpen.kode, 'Biaya ATK');

      final buku = k12Result.rules.firstWhere((r) => r.keyword == 'Buku');
      expect(buku.kode, 'Biaya ATK');

      final kertas = k12Result.rules.firstWhere((r) => r.keyword == 'Kertas');
      expect(kertas.kode, 'Biaya ATK');

      final print = k12Result.rules.firstWhere((r) => r.keyword == 'Print');
      expect(print.kode, 'Biaya ATK');

      final pensil = k12Result.rules.firstWhere((r) => r.keyword == 'Pensil');
      expect(pensil.kode, 'Biaya ATK');

      final atk = k12Result.rules.firstWhere((r) => r.keyword == 'ATK' && r.type == 'kategori');
      expect(atk.kode, 'Biaya ATK');

      final admin = k12Result.rules.firstWhere((r) => r.keyword == 'Admin' && r.type == 'kategori');
      expect(admin.kode, 'Biaya RTK');

      final biFast = k12Result.rules.firstWhere((r) => r.keyword == 'Bi Fast');
      expect(biFast.kode, 'Biaya RTK');

      final rtk = k12Result.rules.firstWhere((r) => r.keyword == 'RTK' && r.type == 'kategori');
      expect(rtk.kode, 'Biaya RTK');

      final peralatan = k12Result.rules.firstWhere((r) => r.keyword == 'Peralatan');
      expect(peralatan.kode, 'Pemeliharaan Bangunan, Peralatan');

      final bangunan = k12Result.rules.firstWhere((r) => r.keyword == 'Bangunan');
      expect(bangunan.kode, 'Pemeliharaan Bangunan, Peralatan');

      // Verify specific K12 KU rules
      final rapat = k12Result.rules.firstWhere((r) => r.keyword == 'rapat' && r.type == 'ku');
      expect(rapat.kode, 'Sekretaris');

      final rakor = k12Result.rules.firstWhere((r) => r.keyword == 'rakor' && r.type == 'ku');
      expect(rakor.kode, 'Sekretaris');

      final rab = k12Result.rules.firstWhere((r) => r.keyword == 'rab' && r.type == 'ku');
      expect(rab.kode, 'Sekretaris');

      final rkub = k12Result.rules.firstWhere((r) => r.keyword == 'rkub' && r.type == 'ku');
      expect(rkub.kode, 'Sekretaris');

      final bensinKu = k12Result.rules.firstWhere((r) => r.keyword == 'bensin' && r.type == 'ku');
      expect(bensinKu.kode, 'Sekretaris');

      final atkKu = k12Result.rules.firstWhere((r) => r.keyword == 'ATK' && r.type == 'ku');
      expect(atkKu.kode, 'Sekretaris');

      final rtkKu = k12Result.rules.firstWhere((r) => r.keyword == 'RTK' && r.type == 'ku');
      expect(rtkKu.kode, 'Sekretaris');

      final simulasi = k12Result.rules.firstWhere((r) => r.keyword == 'simulasi' && r.type == 'ku');
      expect(simulasi.kode, 'Sekretaris');

      final adminKu = k12Result.rules.firstWhere((r) => r.keyword == 'admin' && r.type == 'ku');
      expect(adminKu.kode, 'KU SDK');

      final bankKu = k12Result.rules.firstWhere((r) => r.keyword == 'bank' && r.type == 'ku');
      expect(bankKu.kode, 'KU SDK');

      final pulsaKu = k12Result.rules.firstWhere((r) => r.keyword == 'pulsa' && r.type == 'ku');
      expect(pulsaKu.kode, 'KU SDK');

      final pembinaanAp = k12Result.rules.firstWhere((r) => r.keyword == 'pembinaan AP');
      expect(pembinaanAp.kode, 'KU SDM');

      final olahraga = k12Result.rules.firstWhere((r) => r.keyword == 'olahraga');
      expect(olahraga.kode, 'KU SDM');

      final silah = k12Result.rules.firstWhere((r) => r.keyword == 'silah');
      expect(silah.kode, 'KU SDM');

      final pekabaran = k12Result.rules.firstWhere((r) => r.keyword == 'Pekabaran');
      expect(pekabaran.kode, 'KU Publikasi');

      final talwiyah = k12Result.rules.firstWhere((r) => r.keyword == 'Talwiyah');
      expect(talwiyah.kode, 'KU Publikasi');

      final pengabaran = k12Result.rules.firstWhere((r) => r.keyword == 'Pengabaran');
      expect(pengabaran.kode, 'KU Publikasi');

      final pembinaanAb = k12Result.rules.firstWhere((r) => r.keyword == 'pembinaan AB');
      expect(pembinaanAb.kode, 'KU Publikasi');

      final pratal = k12Result.rules.firstWhere((r) => r.keyword == 'Pratal');
      expect(pratal.kode, 'KU Publikasi');

      final moral = k12Result.rules.firstWhere((r) => r.keyword == 'Moral');
      expect(moral.kode, 'KU Hukum');

      final disiplin = k12Result.rules.firstWhere((r) => r.keyword == 'Disiplin');
      expect(disiplin.kode, 'KU Hukum');

      final mpmd = k12Result.rules.firstWhere((r) => r.keyword == 'MPMD');
      expect(mpmd.kode, 'KU Hukum');

      final rpm = k12Result.rules.firstWhere((r) => r.keyword == 'RPM');
      expect(rpm.kode, 'KU Ekonomi');

      final pangan = k12Result.rules.firstWhere((r) => r.keyword == 'Pangan');
      expect(pangan.kode, 'KU Ekonomi');

      final kedaulatanPangan = k12Result.rules.firstWhere((r) => r.keyword == 'Kedaulatan Pangan');
      expect(kedaulatanPangan.kode, 'KU Ekonomi');

      final bibit = k12Result.rules.firstWhere((r) => r.keyword == 'Bibit');
      expect(bibit.kode, 'KU Ekonomi');
    });

    test('StrukturData serialization with isSaldoRekeningUnlocked', () {
      final data = StrukturData(isSaldoRekeningUnlocked: true);
      final json = data.toJson();
      expect(json['isSaldoRekeningUnlocked'], isTrue);

      final fromJson = StrukturData.fromJson(json);
      expect(fromJson.isSaldoRekeningUnlocked, isTrue);

      final dataFalse = StrukturData(isSaldoRekeningUnlocked: false);
      final jsonFalse = dataFalse.toJson();
      expect(jsonFalse['isSaldoRekeningUnlocked'], isFalse);
      final fromJsonFalse = StrukturData.fromJson(jsonFalse);
      expect(fromJsonFalse.isSaldoRekeningUnlocked, isFalse);
    });

    test('Mode Admin calculates Saldo Akhir from Saldo Awal + Transactions Mutasi', () {
      final data = StrukturData(isSaldoRekeningUnlocked: true);
      data.transactions = [
        StrukturTransaction(
          id: '1',
          type: 'pemasukan',
          title: 'Dana Turun',
          amount: 5000000,
          targetAccount: 'rekening',
          timestamp: DateTime.now(),
        ),
        StrukturTransaction(
          id: '2',
          type: 'pengeluaran',
          title: 'Konsumsi',
          amount: 1000000,
          sourceAccount: 'rekening',
          timestamp: DateTime.now(),
        ),
        StrukturTransaction(
          id: '3',
          type: 'pemasukan',
          title: 'Tarik Tunai ke Debit',
          amount: 2000000,
          targetAccount: 'debit',
          timestamp: DateTime.now(),
        ),
        StrukturTransaction(
          id: '4',
          type: 'pengeluaran',
          title: 'Bensin',
          amount: 500000,
          sourceAccount: 'cash',
          timestamp: DateTime.now(),
        ),
      ];

      // Saldo Awal sebelum transaksi:
      const saldoAwalRekening = 10000000;
      const saldoAwalDebit = 3000000;
      const saldoAwalCash = 1000000;

      // Mutasi Rekening: +5.000.000 - 1.000.000 = +4.000.000 -> Saldo Akhir = 14.000.000
      // Mutasi Debit: +2.000.000 -> Saldo Akhir = 5.000.000
      // Mutasi Cash: -500.000 -> Saldo Akhir = 500.000
      data.rekeningStruktur.balance = saldoAwalRekening + 4000000;
      data.onHandDebit.balance = saldoAwalDebit + 2000000;
      data.onHandCash.balance = saldoAwalCash - 500000;

      expect(data.rekeningStruktur.balance, 14000000);
      expect(data.onHandDebit.balance, 5000000);
      expect(data.onHandCash.balance, 500000);
      expect(data.totalDanaStruktur, 19500000);
    });
  });
}

