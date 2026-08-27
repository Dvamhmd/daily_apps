import 'dart:convert';
import 'package:daily_apps/models/model_rundown.dart';
import 'package:daily_apps/models/model_struktur.dart';
import 'package:daily_apps/models/model_tagihan.dart';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/models/model_uangku.dart';
import 'package:daily_apps/utils/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupService Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('generateBackupData & parseAndValidateBackup work properly', () async {
      final prefs = await SharedPreferences.getInstance();

      // Seed mock data for all features
      // 1. Keuangan
      final uangkuList = [
        Uangku('Gaji', 5000000),
        Uangku('Freelance', 1500000),
      ];
      final tagihanList = [
        Tagihan('Listrik', 350000),
        Tagihan('Internet', 400000),
      ];
      await prefs.setStringList(
          'uangku_2026_8', uangkuList.map((e) => jsonEncode(e.toJson())).toList());
      await prefs.setStringList('tagihan_2026_8',
          tagihanList.map((e) => jsonEncode(e.toJson())).toList());
      await prefs.setStringList('tabungan', [
        jsonEncode({'nama': 'Darurat', 'jumlah': 2000000})
      ]);

      // 2. Rundown
      final rundown = Rundown(
        id: 'rd_1',
        title: 'Acara Gathering',
        startDate: DateTime(2026, 8, 30),
        totalDays: 2,
        days: [
          RundownDay(
            dayNumber: 1,
            date: DateTime(2026, 8, 30),
            theme: 'Opening',
            rows: [
              RundownTableRow(
                id: 'r1',
                startTime: '08:00',
                durationMinutes: 60,
                activity: 'Registrasi',
              ),
            ],
          ),
        ],
      );
      await prefs.setStringList('rundowns_data', [jsonEncode(rundown.toJson())]);

      // 3. Todo List
      final todoGroup = TodoDateGroup(
        id: 'td_1',
        date: DateTime(2026, 8, 27),
        items: [
          TodoItem(id: 'ti_1', title: 'Beli ATK', isCompleted: false),
          TodoItem(id: 'ti_2', title: 'Bayar WiFi', isCompleted: true),
        ],
      );
      await prefs.setString('todo_list_data', jsonEncode([todoGroup.toJson()]));

      // 4. Struktur
      final strukturData = StrukturData(
        rekeningStruktur: RekeningStruktur(
          bankName: 'BCA',
          accountNumber: '1234567890',
          balance: 10000000,
        ),
        transactions: [
          StrukturTransaction(
            id: 'tr_1',
            title: 'Beli kertas',
            type: 'pengeluaran',
            amount: 50000,
          ),
        ],
      );
      await prefs.setString(
          'struktur_keuangan_data_2026_8', jsonEncode(strukturData.toJson()));

      // Run live summary
      final summary = await BackupService.getLiveSummary();
      expect(summary.totalUangku, 2);
      expect(summary.totalTagihan, 2);
      expect(summary.totalTabungan, 1);
      expect(summary.totalRundowns, 1);
      expect(summary.totalTodoGroups, 1);
      expect(summary.totalTodoActiveItems, 2);
      expect(summary.totalStrukturMonths, 1);
      expect(summary.totalStrukturTransactions, 1);

      // Generate Backup
      final backup = await BackupService.generateBackupData();
      expect(backup.appName, 'Daily Apps');
      expect(backup.preferences.isNotEmpty, true);

      // Encode and parse back
      final jsonString = jsonEncode(backup.toJson());
      final parsed = BackupService.parseAndValidateBackup(jsonString);

      expect(parsed.appName, 'Daily Apps');
      expect(parsed.summary.totalUangku, 2);
      expect(parsed.summary.totalRundowns, 1);

      // Now clear prefs to test restore
      await prefs.clear();
      expect(prefs.getKeys().isEmpty, true);

      // Restore
      final restoreSuccess = await BackupService.restoreBackup(parsed, cleanRestore: true);
      expect(restoreSuccess, true);

      // Verify data is restored
      final restoredUangku = prefs.getStringList('uangku_2026_8');
      expect(restoredUangku, isNotNull);
      expect(restoredUangku!.length, 2);

      final restoredRundowns = prefs.getStringList('rundowns_data');
      expect(restoredRundowns, isNotNull);
      expect(restoredRundowns!.length, 1);

      final restoredTodos = prefs.getString('todo_list_data');
      expect(restoredTodos, isNotNull);
      expect(restoredTodos!.contains('Beli ATK'), true);

      final restoredStruktur = prefs.getString('struktur_keuangan_data_2026_8');
      expect(restoredStruktur, isNotNull);
      expect(restoredStruktur!.contains('BCA'), true);
    });

    test('parseAndValidateBackup handles invalid json properly', () {
      expect(
        () => BackupService.parseAndValidateBackup(''),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => BackupService.parseAndValidateBackup('{"some": "data"}'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
