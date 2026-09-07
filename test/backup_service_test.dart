import 'dart:convert';
import 'package:daily_apps/models/model_pribadi.dart';
import 'package:daily_apps/models/model_rundown.dart';
import 'package:daily_apps/models/model_struktur.dart';
import 'package:daily_apps/models/model_tagihan.dart';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/models/model_uangku.dart';
import 'package:daily_apps/utils/backup_service.dart';
import 'package:daily_apps/utils/serious_mode_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupService Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('getLiveSummary accurately detects Todo List (Normal & Serious mode: active & history items)', () async {
      final prefs = await SharedPreferences.getInstance();

      // Normal mode todo groups (1 active with 3 tasks, 1 archived with 2 tasks)
      final normalActiveGroup = TodoDateGroup(
        id: 'norm_active_1',
        date: DateTime(2026, 9, 7),
        isArchived: false,
        items: [
          TodoItem(id: 't1', title: 'Kerjakan Tugas 1', isCompleted: false),
          TodoItem(id: 't2', title: 'Kerjakan Tugas 2', isCompleted: true),
          TodoItem(id: 't3', title: 'Kerjakan Tugas 3', isCompleted: false),
        ],
      );
      final normalHistoryGroup = TodoDateGroup(
        id: 'norm_hist_1',
        date: DateTime(2026, 9, 6),
        isArchived: true,
        items: [
          TodoItem(id: 't4', title: 'Tugas Kemarin A', isCompleted: true),
          TodoItem(id: 't5', title: 'Tugas Kemarin B', isCompleted: true),
        ],
      );

      await prefs.setString(
        SeriousModeService.prefKeyNormalTodoGroups,
        jsonEncode([normalActiveGroup.toJson(), normalHistoryGroup.toJson()]),
      );

      // Serious mode todo groups (1 active with 2 tasks)
      final seriousActiveGroup = TodoDateGroup(
        id: 'ser_active_1',
        date: DateTime(2026, 9, 7),
        isArchived: false,
        items: [
          TodoItem(id: 'st1', title: 'Target Serious 1', isCompleted: false),
          TodoItem(id: 'st2', title: 'Target Serious 2', isCompleted: true),
        ],
      );

      await prefs.setString(
        SeriousModeService.prefKeySeriousTodoGroups,
        jsonEncode([seriousActiveGroup.toJson()]),
      );

      // Run live summary
      final summary = await BackupService.getLiveSummary();

      // Active groups: normalActiveGroup (3 items) + seriousActiveGroup (2 items) = 2 groups, 5 items
      expect(summary.totalTodoGroups, 2);
      expect(summary.totalTodoActiveItems, 5);

      // History groups: normalHistoryGroup (2 items) = 1 group, 2 items
      expect(summary.totalTodoHistoryGroups, 1);
      expect(summary.totalTodoHistoryItems, 2);
    });

    test('getLiveSummary accurately detects RiwayatService entries', () async {
      final prefs = await SharedPreferences.getInstance();
      // Initially 0
      var summary = await BackupService.getLiveSummary();
      expect(summary.totalRiwayatKeuangan, 0);

      // Add riwayat entries
      await prefs.setStringList('riwayat_keuangan', [
        '{"id":"1","datetime":"2026-09-07T10:00:00","kategori":"Tagihan","perubahan":"Listrik Rp 350.000 ditambah ke tagihan","tipe":"tambah","nominal":350000}',
        '{"id":"2","datetime":"2026-09-07T10:05:00","kategori":"Uangku","perubahan":"Gaji Rp 5.000.000 ditambah ke uangku","tipe":"tambah","nominal":5000000}',
      ]);

      summary = await BackupService.getLiveSummary();
      expect(summary.totalRiwayatKeuangan, 2);
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
          'uangku_2026_09', uangkuList.map((e) => jsonEncode(e.toJson())).toList());
      await prefs.setBool('uangku_only_cair', true);
      await prefs.setStringList('tagihan_2026_09',
          tagihanList.map((e) => jsonEncode(e.toJson())).toList());
      await prefs.setStringList('tabungan', [
        jsonEncode({'nama': 'Darurat', 'jumlah': 2000000})
      ]);
      await prefs.setStringList('tagihan_lunas', [
        jsonEncode({'nama': 'Air PDAM', 'jumlah': 150000})
      ]);
      await prefs.setStringList('riwayat_keuangan', [
        jsonEncode({'id': 'rw_1', 'kategori': 'Uangku', 'perubahan': 'Gaji Rp 5.000.000 ditambah ke uangku', 'tipe': 'tambah', 'nominal': 5000000})
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

      // 3. Todo List (Normal Mode & History)
      final activeGroup = TodoDateGroup(
        id: 'td_1',
        date: DateTime(2026, 9, 7),
        isArchived: false,
        items: [
          TodoItem(id: 'ti_1', title: 'Beli ATK', isCompleted: false),
          TodoItem(id: 'ti_2', title: 'Bayar WiFi', isCompleted: true),
        ],
      );
      final historyGroup = TodoDateGroup(
        id: 'td_hist_1',
        date: DateTime(2026, 9, 1),
        isArchived: true,
        items: [
          TodoItem(id: 'ti_3', title: 'Selesai Task 3', isCompleted: true),
        ],
      );
      await prefs.setString(
        SeriousModeService.prefKeyNormalTodoGroups,
        jsonEncode([activeGroup.toJson(), historyGroup.toJson()]),
      );

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
          'struktur_keuangan_data_2026_09', jsonEncode(strukturData.toJson()));

      // 5. Pribadi
      final pribadiData = PribadiData(
        posDanaList: [
          PosDana(id: 'p1', nama: 'Gaji', balance: 5000000),
        ],
        transactions: [
          PribadiTransaction(
            id: 'pt_1',
            title: 'Makan Siang',
            amount: 35000,
            type: 'pengeluaran',
          ),
        ],
      );
      await prefs.setString(
          'pribadi_keuangan_data_2026_09', jsonEncode(pribadiData.toJson()));

      // 6. Serious Mode & App Settings
      await prefs.setBool(SeriousModeService.prefKeyActiveMode, true);
      await prefs.setString(SeriousModeService.prefKeyCurrentUser,
          jsonEncode({'id': 'u1', 'username': 'admin'}));
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
      expect(summary.totalTodoHistoryItems, 1);
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
      expect(parsed.summary.totalTodoActiveItems, 2);
      expect(parsed.summary.totalTodoHistoryItems, 1);

      // Now clear prefs to test restore
      await prefs.clear();
      expect(prefs.getKeys().isEmpty, true);

      // Restore
      final restoreSuccess =
          await BackupService.restoreBackup(parsed, cleanRestore: true);
      expect(restoreSuccess, true);

      // Verify all data types are restored properly
      final restoredUangku = prefs.getStringList('uangku_2026_09');
      expect(restoredUangku, isNotNull);
      expect(restoredUangku!.length, 2);

      expect(prefs.getBool('uangku_only_cair'), true);
      expect(prefs.getBool(SeriousModeService.prefKeyActiveMode), true);
      expect(prefs.getInt('default_main_page'), 2);
      expect(prefs.getDouble('custom_threshold'), 99.5);
      expect(prefs.getString('dana_aman_filter_mode'), 'semua');

      final restoredRundowns = prefs.getStringList('rundowns_data');
      expect(restoredRundowns, isNotNull);
      expect(restoredRundowns!.length, 1);

      final restoredTodos =
          prefs.getString(SeriousModeService.prefKeyNormalTodoGroups);
      expect(restoredTodos, isNotNull);
      expect(restoredTodos!.contains('Beli ATK'), true);

      final restoredStruktur =
          prefs.getString('struktur_keuangan_data_2026_09');
      expect(restoredStruktur, isNotNull);
      expect(restoredStruktur!.contains('BCA'), true);

      final restoredPribadi = prefs.getString('pribadi_keuangan_data_2026_09');
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
