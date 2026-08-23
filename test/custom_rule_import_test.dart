import 'dart:typed_data';
import 'package:daily_apps/models/model_struktur.dart';
import 'package:daily_apps/utils/custom_rule_import_helper.dart';
import 'package:excel/excel.dart';
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
  });
}
