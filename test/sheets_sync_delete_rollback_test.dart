import 'package:flutter_test/flutter_test.dart';
import 'package:daily_apps/models/model_sheets_config.dart';
import 'package:daily_apps/models/model_struktur.dart';
import 'package:daily_apps/utils/sheets_sync_service.dart';

void main() {
  group('SheetsSyncService Delete & Rollback Sync Tests', () {
    test('emptyTransactionRow creates a row with empty strings for all fields', () {
      final emptyRow = SheetsSyncService.emptyTransactionRow();
      expect(emptyRow['no'], '');
      expect(emptyRow['tanggal'], '');
      expect(emptyRow['ku'], '');
      expect(emptyRow['kategori'], '');
      expect(emptyRow['keterangan'], '');
      expect(emptyRow['debit'], '');
      expect(emptyRow['kredit'], '');
      expect(emptyRow['no_onhand'], '');
      expect(emptyRow['tanggal_onhand'], '');
      expect(emptyRow['ku_onhand'], '');
      expect(emptyRow['kategori_onhand'], '');
      expect(emptyRow['keterangan_onhand'], '');
      expect(emptyRow['debit_onhand'], '');
      expect(emptyRow['kredit_onhand'], '');
    });

    test('formatTransactionRow correctly formats a transaction row', () {
      final tx = StrukturTransaction(
        id: '123',
        title: 'Kas Masuk Operasional',
        type: 'pemasukan',
        amount: 500000,
        timestamp: DateTime(2026, 9, 7),
        targetAccount: 'rekening',
      );

      final row = SheetsSyncService.formatTransactionRow(tx, 1);
      expect(row['no'], 1);
      expect(row['debit'], 500000);
      expect(row['kredit'], '');
      expect(row['keterangan'], contains('Kas Masuk Operasional'));
    });

    test('SheetsConfig auto-enables hasConfiguredCells when isConfigured is true from JSON', () {
      final json = {
        'webAppUrl': 'https://script.google.com/macros/s/ABCDEF12345/exec',
        'sheetName': 'Bulan Ini',
        'autoSyncOnInput': true,
        'hasConfiguredCells': false,
      };

      final config = SheetsConfig.fromJson(json);
      expect(config.isConfigured, isTrue);
      expect(config.hasConfiguredCells, isTrue);
    });

    test('Apps Script template clearOldTransactionData excludes false positive words like KAS and SALDO', () {
      final script = SheetsSyncService.getGoogleAppsScriptCode();
      expect(script.contains('strVal.indexOf("KAS") !== -1'), isFalse);
      expect(script.contains('strVal.indexOf("SALDO") !== -1'), isFalse);
      expect(script.contains('strVal.indexOf("CATATAN:") === 0'), isTrue);
      expect(script.contains('clearFirst'), isTrue);
    });
  });
}
