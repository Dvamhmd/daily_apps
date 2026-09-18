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

    test('SheetsConfig calculates max capacity accurately', () {
      final config = SheetsConfig(
        startRow: 4,
        endRow: 23,
        startRowOnHand: 4,
        endRowOnHand: 23,
      );

      expect(config.maxRekeningCapacity, 20);
      expect(config.maxOnHandCapacity, 20);
    });

    test('Apps Script template clearOldTransactionData excludes false positive words like KAS and SALDO', () {
      final script = SheetsSyncService.getGoogleAppsScriptCode();
      expect(script.contains('strVal.indexOf("KAS") !== -1'), isFalse);
      expect(script.contains('strVal.indexOf("SALDO") !== -1'), isFalse);
      expect(script.contains('strVal.indexOf("CATATAN:") === 0'), isTrue);
      expect(script.contains('clearFirst'), isTrue);
    });

    test('compareData detects discrepancy when local is empty and remote has data', () {
      final remoteResult = SheetsFetchResult(
        isSuccess: true,
        message: 'Success',
        rekeningRows: [
          {'no': 1, 'debit': '100000', 'kredit': '', 'keterangan': 'Pemasukan remote'}
        ],
        onHandRows: [],
      );

      final comp = SheetsSyncService.compareData(
        localTransactions: [],
        remoteFetchResult: remoteResult,
      );

      expect(comp.hasDiscrepancy, isTrue);
      expect(comp.discrepancyReasons.isNotEmpty, isTrue);
    });

    test('compareData detects discrepancy when amounts differ even if counts match', () {
      final tx = StrukturTransaction(
        id: '1',
        title: 'Kas Masuk',
        type: 'pemasukan',
        amount: 50000,
        timestamp: DateTime(2026, 9, 7),
        targetAccount: 'rekening',
      );

      final remoteResult = SheetsFetchResult(
        isSuccess: true,
        message: 'Success',
        rekeningRows: [
          {'no': 1, 'debit': '100000', 'kredit': '', 'keterangan': 'Pemasukan remote'}
        ],
        onHandRows: [],
      );

      final comp = SheetsSyncService.compareData(
        localTransactions: [tx],
        remoteFetchResult: remoteResult,
      );

      expect(comp.hasDiscrepancy, isTrue);
      expect(comp.discrepancyReasons.any((r) => r.contains('Total Masuk/Debit Rekening berbeda')), isTrue);
    });

    test('compareData does not report discrepancy when remote spreadsheet is completely empty', () {
      final tx = StrukturTransaction(
        id: '1',
        title: 'Kas Masuk',
        type: 'pemasukan',
        amount: 50000,
        timestamp: DateTime(2026, 9, 7),
        targetAccount: 'rekening',
      );

      final remoteResult = SheetsFetchResult(
        isSuccess: true,
        message: 'Empty sheet',
        rekeningRows: [],
        onHandRows: [],
      );

      final comp = SheetsSyncService.compareData(
        localTransactions: [tx],
        remoteFetchResult: remoteResult,
      );

      expect(comp.hasDiscrepancy, isFalse);
    });
  });
}
