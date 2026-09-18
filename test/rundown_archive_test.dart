import 'dart:convert';
import 'package:daily_apps/models/model_rundown.dart';
import 'package:daily_apps/pages/rundown_arsip_page.dart';
import 'package:daily_apps/pages/rundown_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Rundown Model Archiving Tests', () {
    test('Rundown defaults isArchived to false', () {
      final rundown = Rundown(
        id: 'rd_1',
        title: 'Acara Konser',
        startDate: DateTime(2026, 9, 20),
        totalDays: 1,
        days: [
          RundownDay(
            dayNumber: 1,
            date: DateTime(2026, 9, 20),
            theme: 'Panggung Utama',
          ),
        ],
      );

      expect(rundown.isArchived, isFalse);
    });

    test('Rundown toJson and fromJson preserves isArchived flag', () {
      final rundown = Rundown(
        id: 'rd_2',
        title: 'Gathering Perusahaan',
        startDate: DateTime(2026, 9, 21),
        totalDays: 2,
        days: [
          RundownDay(
            dayNumber: 1,
            date: DateTime(2026, 9, 21),
            theme: 'Pembukaan',
          ),
        ],
        isArchived: true,
      );

      final json = rundown.toJson();
      expect(json['isArchived'], isTrue);

      final restored = Rundown.fromJson(json);
      expect(restored.id, 'rd_2');
      expect(restored.title, 'Gathering Perusahaan');
      expect(restored.isArchived, isTrue);
    });

    test('Rundown fromJson backwards compatibility (missing isArchived defaults to false)', () {
      final legacyJson = {
        'id': 'legacy_1',
        'title': 'Rundown Jadul',
        'startDate': '2026-09-18T00:00:00.000',
        'totalDays': 1,
        'days': [],
        'expenses': [],
        'createdAt': '2026-09-18T00:00:00.000',
      };

      final rundown = Rundown.fromJson(legacyJson);
      expect(rundown.isArchived, isFalse);
    });

    test('Rundown copyWith updates isArchived correctly', () {
      final original = Rundown(
        id: 'rd_3',
        title: 'Festival Musik',
        startDate: DateTime(2026, 9, 25),
        totalDays: 1,
        days: [],
        isArchived: false,
      );

      final archived = original.copyWith(isArchived: true);
      expect(archived.isArchived, isTrue);
      expect(archived.id, original.id);
      expect(archived.title, original.title);

      final restored = archived.copyWith(isArchived: false);
      expect(restored.isArchived, isFalse);
    });
  });

  group('RundownPage Headbar Archive Button & RundownArsipPage Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('RundownPage shows only active rundowns and opens RundownArsipPage from headbar button',
        (WidgetTester tester) async {
      final activeRundown = Rundown(
        id: 'rd_active',
        title: 'Acara Masih Berjalan',
        startDate: DateTime(2026, 9, 20),
        totalDays: 1,
        days: [
          RundownDay(
            dayNumber: 1,
            date: DateTime(2026, 9, 20),
            theme: 'Sesi 1',
          ),
        ],
        isArchived: false,
      );

      final archivedRundown = Rundown(
        id: 'rd_archived',
        title: 'Acara Bulan Lalu Selesai',
        startDate: DateTime(2026, 8, 10),
        totalDays: 1,
        days: [
          RundownDay(
            dayNumber: 1,
            date: DateTime(2026, 8, 10),
            theme: 'Penutupan',
          ),
        ],
        isArchived: true,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('rundowns_data', [
        jsonEncode(activeRundown.toJson()),
        jsonEncode(archivedRundown.toJson()),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: RundownPage(onPageSelected: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // Main list only displays active rundown
      expect(find.text('Acara Masih Berjalan'), findsOneWidget);
      expect(find.text('Acara Bulan Lalu Selesai'), findsNothing);
      expect(find.text('Daftar Rundown (1)'), findsOneWidget);

      // Verify Archive button is in the headbar
      final archiveBtn = find.byTooltip('Arsip Rundown (1)');
      expect(archiveBtn, findsOneWidget);

      // Tap on headbar Archive button
      await tester.tap(archiveBtn);
      await tester.pumpAndSettle();

      // Now on RundownArsipPage
      expect(find.text('Arsip Rundown'), findsOneWidget);
      expect(find.text('Acara Bulan Lalu Selesai'), findsOneWidget);
      expect(find.text('Acara Masih Berjalan'), findsNothing);
      expect(find.text('ARSIP'), findsOneWidget);

      // Tap 'Pulihkan ke Aktif'
      final restoreBtn = find.text('Pulihkan ke Aktif');
      expect(restoreBtn, findsOneWidget);
      await tester.tap(restoreBtn);
      await tester.pumpAndSettle();

      // Now archive page is empty
      expect(find.text('Belum Ada Rundown Diarsipkan'), findsOneWidget);

      // Go back to main page
      final backBtn = find.byIcon(Icons.arrow_back_ios_new_rounded);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // Main page now shows both active rundowns
      expect(find.text('Acara Masih Berjalan'), findsOneWidget);
      expect(find.text('Acara Bulan Lalu Selesai'), findsOneWidget);
      expect(find.text('Daftar Rundown (2)'), findsOneWidget);
    });

    testWidgets('Archiving a rundown from 3-dots popup menu in RundownPage moves it out of main list',
        (WidgetTester tester) async {
      final rundown1 = Rundown(
        id: 'rd_test_1',
        title: 'Festival Musik 2026',
        startDate: DateTime(2026, 9, 20),
        totalDays: 1,
        days: [],
        isArchived: false,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('rundowns_data', [
        jsonEncode(rundown1.toJson()),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: RundownPage(onPageSelected: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Festival Musik 2026'), findsOneWidget);

      // Tap 3-dots popup menu on the card
      final moreBtn = find.byIcon(Icons.more_vert_rounded);
      expect(moreBtn, findsOneWidget);
      await tester.tap(moreBtn);
      await tester.pumpAndSettle();

      // Tap 'Arsipkan Rundown' in popup menu
      final arsipkanMenuItem = find.text('Arsipkan Rundown');
      expect(arsipkanMenuItem, findsOneWidget);
      await tester.tap(arsipkanMenuItem);
      await tester.pumpAndSettle();

      // Active list is now empty, showing empty state
      expect(find.text('Festival Musik 2026'), findsNothing);
      expect(find.text('Belum Ada Rundown Kegiatan'), findsOneWidget);
      expect(find.text('Buka Arsip Rundown (1)'), findsOneWidget);
    });
  });
}
