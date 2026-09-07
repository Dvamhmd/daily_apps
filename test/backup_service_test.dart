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

    test('generateBackupData & parseAndValidateBackup work properly with all feature data & bool keys', () async {
      final prefs = await SharedPreferences.getInstance();

      // Seed mock data for all features
      // 1. Keuangan (including uangku_only_cair boolean key)
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
      await prefs.setBool('uangku_only_cair', true); // This was previously causing type cast crash
      await prefs.setStringList('tagihan_2026_8',
          tagihanList.map((e) => jsonEncode(e.toJson())).toList());
      await prefs.setStringList('tabungan', [
        jsonEncode({'nama': 'Darurat', 'jumlah': 2000000})
      ]);
      await prefs.setStringList('tagihan_lunas', [
        jsonEncode({'nama': 'Air PDAM', 'jumlah': 150000})
      ]);
      await prefs.setStringList('riwayat_keuangan_list', [
        jsonEncode({'tanggal': '2026-08-01', 'pesan': 'Tambah Gaji Rp 5.000.000'})
      ]);
      await prefs.setString('dana_aman_filter_mode', 'semua');
      await prefs.setInt('dana_aman_custom_days', 15);

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

      // 3. Todo List & Todo History
      final todoGroup = TodoDateGroup(
        id: 'td_1',
        date: DateTime(2026, 8, 27),
        items: [
          TodoItem(id: 'ti_1', title: 'Beli ATK', isCompleted: false),
          TodoItem(id: 'ti_2', title: 'Bayar WiFi', isCompleted: true),
        ],
      );
      await prefs.setString('todo_list_data', jsonEncode([todoGroup.toJson()]));
      await prefs.setString('todo_history_data', jsonEncode([todoGroup.toJson()]));

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

      // 5. Pribadi
      await prefs.setString(
          'pribadi_keuangan_data_2026_8',
          jsonEncode({
            'saldoDompet': 500000.0,
            'saldoBank': 10000000.0,
            'transactions': [
              {
                'id': 'pt_1',
                'title': 'Makan Siang',
                'amount': 35000.0,
                'type': 'pengeluaran',
                'category': 'makanan',
                'timestamp': '2026-08-01T12:00:00.000',
              }
            ],
          }));

      // 6. Serious Mode & App Settings
      await prefs.setBool('serious_mode_active', true);
      await prefs.setString('serious_current_user', jsonEncode({'id': 'u1', 'username': 'admin'}));
      await prefs.setInt('default_main_page', 2);
      await prefs.setDouble('custom_threshold', 99.5);

      // Run live summary without any errors
      final summary = await BackupService.getLiveSummary();
      expect(summary.totalUangku, 2);
      expect(summary.totalTagihan, 2);
      expect(summary.totalTabungan, 1);
      expect(summary.totalTagihanLunas, 1);
      expect(summary.totalRiwayatKeuangan, 1);
      expect(summary.totalRundowns, 1);
      expect(summary.totalTodoGroups, 1);
      expect(summary.totalTodoActiveItems, 2);
      expect(summary.totalTodoHistoryGroups, 1);
      expect(summary.totalTodoHistoryItems, 2);
      expect(summary.totalStrukturMonths, 1);
      expect(summary.totalStrukturTransactions, 1);
      expect(summary.totalPribadiMonths, 1);
      expect(summary.totalPribadiTransactions, 1);

      // Generate Backup
      final backup = await BackupService.generateBackupData();
      expect(backup.appName, 'Daily Apps');
      expect(backup.preferences.isNotEmpty, true);
      expect(backup.preferences.containsKey('uangku_only_cair'), true);
      expect(backup.preferences['uangku_only_cair']['type'], 'bool');
      expect(backup.preferences['uangku_only_cair']['value'], true);
      expect(backup.preferences['default_main_page']['type'], 'int');
      expect(backup.preferences['default_main_page']['value'], 2);
      expect(backup.preferences['custom_threshold']['type'], 'double');
      expect(backup.preferences['custom_threshold']['value'], 99.5);

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

      // Verify all data types are restored properly
      final restoredUangku = prefs.getStringList('uangku_2026_8');
      expect(restoredUangku, isNotNull);
      expect(restoredUangku!.length, 2);

      expect(prefs.getBool('uangku_only_cair'), true);
      expect(prefs.getBool('serious_mode_active'), true);
      expect(prefs.getInt('default_main_page'), 2);
      expect(prefs.getDouble('custom_threshold'), 99.5);
      expect(prefs.getString('dana_aman_filter_mode'), 'semua');

      final restoredRundowns = prefs.getStringList('rundowns_data');
      expect(restoredRundowns, isNotNull);
      expect(restoredRundowns!.length, 1);

      final restoredTodos = prefs.getString('todo_list_data');
      expect(restoredTodos, isNotNull);
      expect(restoredTodos!.contains('Beli ATK'), true);

      final restoredStruktur = prefs.getString('struktur_keuangan_data_2026_8');
      expect(restoredStruktur, isNotNull);
      expect(restoredStruktur!.contains('BCA'), true);

      final restoredPribadi = prefs.getString('pribadi_keuangan_data_2026_8');
      expect(restoredPribadi, isNotNull);
      expect(restoredPribadi!.contains('Makan Siang'), true);
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
