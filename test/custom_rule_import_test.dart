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

    test('K12 Rules preset contains 25 rules and password is Yu5uf1253', () {
      expect(CustomRuleImportHelper.k12Password, equals('Yu5uf1253'));
      final k12Result = CustomRuleImportHelper.getK12ImportResult();
      expect(k12Result.isSuccess, isTrue);
      expect(k12Result.rules.length, 25);
      expect(k12Result.kuCount, 0);
      expect(k12Result.kategoriCount, 25);

      // Verify specific K12 rules requested by user
      final dpKk = k12Result.rules.firstWhere((r) => r.keyword == 'DP KK');
      expect(dpKk.kode, 'Terima DP DTK');
      expect(dpKk.type, 'kategori');

      final kirimDp = k12Result.rules.firstWhere((r) => r.keyword == 'Kirim DP ke S3');
      expect(kirimDp.kode, 'Kirim DP DTK ke S3');

      final danaKontribusi = k12Result.rules.firstWhere((r) => r.keyword == 'Dana kontribusi DP dari S3');
      expect(danaKontribusi.kode, 'Kontribusi DP S4');

      final motor = k12Result.rules.firstWhere((r) => r.keyword == 'Motor');
      expect(motor.kode, 'Motor, Peralatan & Elektronik');

      final sewa = k12Result.rules.firstWhere((r) => r.keyword == 'Sewa tempat');
      expect(sewa.kode, 'Sewa Tempat');

      final bensin = k12Result.rules.firstWhere((r) => r.keyword == 'Bensin');
      expect(bensin.kode, 'Biaya Transportasi Lokal');

      final konsumsi = k12Result.rules.firstWhere((r) => r.keyword == 'Konsumsi');
      expect(konsumsi.kode, 'Biaya Konsumsi Acara');

      final internet = k12Result.rules.firstWhere((r) => r.keyword == 'Internet');
      expect(internet.kode, 'Biaya Komunikasi dan Internet');

      final kuota = k12Result.rules.firstWhere((r) => r.keyword == 'Kuota');
      expect(kuota.kode, 'Biaya Komunikasi dan Internet');

      final pulsa = k12Result.rules.firstWhere((r) => r.keyword == 'Pulsa');
      expect(pulsa.kode, 'Biaya Komunikasi dan Internet');

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

      final atk = k12Result.rules.firstWhere((r) => r.keyword == 'ATK');
      expect(atk.kode, 'Biaya ATK');

      final admin = k12Result.rules.firstWhere((r) => r.keyword == 'Admin');
      expect(admin.kode, 'Biaya RTK');

      final biFast = k12Result.rules.firstWhere((r) => r.keyword == 'Bi Fast');
      expect(biFast.kode, 'Biaya RTK');

      final rtk = k12Result.rules.firstWhere((r) => r.keyword == 'RTK');
      expect(rtk.kode, 'Biaya RTK');

      final peralatan = k12Result.rules.firstWhere((r) => r.keyword == 'Peralatan');
      expect(peralatan.kode, 'Pemeliharaan Bangunan, Peralatan');

      final bangunan = k12Result.rules.firstWhere((r) => r.keyword == 'Bangunan');
      expect(bangunan.kode, 'Pemeliharaan Bangunan, Peralatan');
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
  });
}
