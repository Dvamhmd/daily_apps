import 'dart:convert';
import 'package:daily_apps/models/model_rundown.dart';
import 'package:daily_apps/pages/rundown_page.dart';
import 'package:daily_apps/utils/backup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Rundown Backup & Import Immediate Sync Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
        'RundownPage immediately displays imported rundowns after BackupService.restoreBackup without entering archive page',
        (WidgetTester tester) async {
      // 1. Setup initially empty SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 2. Pump RundownPage widget
      await tester.pumpWidget(
        MaterialApp(
          home: RundownPage(
            onPageSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that initially rundown list is empty (shows empty state text)
      expect(find.text('Belum Ada Rundown Kegiatan'), findsOneWidget);
      expect(find.text('Acara Konser Akbar 2026'), findsNothing);

      // 3. Prepare backup data model with imported rundown
      final importedRundown = Rundown(
        id: 'rd_test_imported_1',
        title: 'Acara Konser Akbar 2026',
        startDate: DateTime(2026, 10, 1),
        totalDays: 1,
        isArchived: false,
        days: [
          RundownDay(
            dayNumber: 1,
            date: DateTime(2026, 10, 1),
            theme: 'Pembukaan',
            rows: [],
          ),
        ],
      );

      final rawRundownList = [jsonEncode(importedRundown.toJson())];

      final backupModel = BackupDataModel(
        version: 1,
        appName: 'Daily Apps',
        exportedAt: DateTime.now(),
        summary: const BackupSummary(totalRundowns: 1),
        preferences: {
          'rundowns_data': {
            'type': 'string_list',
            'value': rawRundownList,
          },
        },
      );

      // 4. Perform restore backup
      final restoreResult = await BackupService.restoreBackup(backupModel);
      expect(restoreResult, true);

      // 5. Let UI react to the notification
      await tester.pumpAndSettle();

      // 6. Verify that RundownPage updated immediately and now shows the imported title!
      expect(find.text('Acara Konser Akbar 2026'), findsOneWidget);
      expect(find.text('Belum Ada Rundown Kegiatan'), findsNothing);
    });

    testWidgets(
        'IndexedStack with KeuanganPage and RundownPage keeps Rundown in sync right after import from Keuangan drawer',
        (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      int currentPageIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: IndexedStack(
                  index: currentPageIndex,
                  children: [
                    Container(key: const ValueKey('keuangan_placeholder')),
                    RundownPage(onPageSelected: (idx) {
                      setState(() => currentPageIndex = idx);
                    }),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate import happening on page 0 (Keuangan)
      final importedRundown = Rundown(
        id: 'rd_test_imported_2',
        title: 'Festival Musik 2026',
        startDate: DateTime(2026, 11, 1),
        totalDays: 2,
        isArchived: false,
        days: [
          RundownDay(
            dayNumber: 1,
            date: DateTime(2026, 11, 1),
            theme: 'Hari 1',
            rows: [],
          ),
        ],
      );

      final rawRundownList = [jsonEncode(importedRundown.toJson())];
      final backupModel = BackupDataModel(
        version: 1,
        appName: 'Daily Apps',
        exportedAt: DateTime.now(),
        summary: const BackupSummary(totalRundowns: 1),
        preferences: {
          'rundowns_data': {
            'type': 'string_list',
            'value': rawRundownList,
          },
        },
      );

      await BackupService.restoreBackup(backupModel);
      await tester.pumpAndSettle();

      // Verify offstage data is loaded
      expect(find.text('Festival Musik 2026', skipOffstage: false),
          findsOneWidget);

      // Now switch tab to RundownPage (index 1)
      final statefulFinder = find.byType(StatefulBuilder);
      final StateSetter setTestState =
          tester.state<State<StatefulBuilder>>(statefulFinder).setState;
      setTestState(() {
        currentPageIndex = 1;
      });
      await tester.pumpAndSettle();

      // Now navigate to RundownPage (index 1) and verify on-stage display
      expect(find.text('Festival Musik 2026'), findsOneWidget);
    });
  });
}
