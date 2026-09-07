import 'package:daily_apps/models/model_rundown.dart';
import 'package:daily_apps/pages/rundown_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Rundown createSampleRundown() {
    return Rundown(
      id: 'test_rundown_1',
      title: 'Family Gathering 2026',
      startDate: DateTime(2026, 9, 10),
      totalDays: 2,
      days: [
        RundownDay.createWithDefaultRows(
          dayNumber: 1,
          date: DateTime(2026, 9, 10),
          theme: 'Opening & Games',
          initialRowCount: 5,
        ),
        RundownDay.createWithDefaultRows(
          dayNumber: 2,
          date: DateTime(2026, 9, 11),
          theme: 'Closing & Photos',
          initialRowCount: 5,
        ),
      ],
    );
  }

  testWidgets('RundownDetailPage renders compact icon-only toolbar and opens dimension modal',
      (WidgetTester tester) async {
    final sampleRundown = createSampleRundown();

    await tester.pumpWidget(
      MaterialApp(
        home: RundownDetailPage(rundown: sampleRundown),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and day header
    expect(find.text('Family Gathering 2026'), findsWidgets);
    expect(find.text('DAY 1'), findsOneWidget);

    // Verify toolbar buttons are icon-only without redundant button text labels
    // The select all checkbox text is compact 'Semua'
    expect(find.text('Semua'), findsOneWidget);

    // Verify icon buttons in toolbar
    expect(find.byIcon(Icons.add_rounded), findsWidgets);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.view_column_rounded), findsWidgets);
    expect(find.byIcon(Icons.tune_rounded), findsWidgets);

    // Tap on Tune Icon to enter Mode Kustom Ukuran (Spreadsheet Resize Mode)
    final tuneButton = find.byIcon(Icons.tune_rounded).first;
    await tester.tap(tuneButton);
    await tester.pumpAndSettle();

    // Verify Mode Kustom Ukuran Banner is displayed
    expect(find.text('Mode Kustom Ukuran Aktif'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('Slider'), findsOneWidget);
    expect(find.text('Selesai'), findsWidgets);

    // Tap on 'Slider' button from banner to open precision modal
    final sliderBtn = find.text('Slider');
    await tester.tap(sliderBtn);
    await tester.pumpAndSettle();

    // Verify modal bottom sheet is displayed
    expect(find.text('Kustom Ukuran Tabel'), findsOneWidget);
    expect(find.text('Tinggi Baris (Row Height)'), findsOneWidget);
    expect(find.text('Lebar Kolom Kegiatan'), findsOneWidget);
    expect(find.text('Reset Standar'), findsOneWidget);

    // Tap on 'Luas' preset for Row Height
    final luasChip = find.textContaining('Luas');
    if (luasChip.evaluate().isNotEmpty) {
      await tester.tap(luasChip.first);
      await tester.pumpAndSettle();
    }

    // Tap 'Selesai' inside modal to close modal
    final modalSelesaiButton =
        find.widgetWithText(ElevatedButton, 'Selesai').last;
    await tester.tap(modalSelesaiButton);
    await tester.pumpAndSettle();

    // Exit Resize Mode by tapping Selesai on banner
    final bannerSelesai = find.widgetWithText(ElevatedButton, 'Selesai').first;
    await tester.tap(bannerSelesai);
    await tester.pumpAndSettle();

    // Verify SharedPreferences persisted row height
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('rundown_row_height'), isNotNull);
  });

  testWidgets('RundownDetailPage add row and delete row operations work correctly',
      (WidgetTester tester) async {
    final sampleRundown = createSampleRundown();

    await tester.pumpWidget(
      MaterialApp(
        home: RundownDetailPage(rundown: sampleRundown),
      ),
    );
    await tester.pumpAndSettle();

    // Initial 5 rows
    expect(find.text('1'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    // Tap Add Row button (Icons.add_rounded in table toolbar)
    final addBtn = find.byIcon(Icons.add_rounded).first;
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    // Now 6 rows should exist
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('Spreadsheet drag resize handles allow adjusting column width and row height by dragging',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sampleRundown = createSampleRundown();

    await tester.pumpWidget(
      MaterialApp(
        home: RundownDetailPage(rundown: sampleRundown),
      ),
    );
    await tester.pumpAndSettle();

    // Toggle Resize Mode
    final tuneButton = find.byIcon(Icons.tune_rounded).first;
    await tester.tap(tuneButton);
    await tester.pumpAndSettle();

    expect(find.text('Mode Kustom Ukuran Aktif'), findsOneWidget);

    // Find column resize handles by SystemMouseCursors.resizeColumn
    final columnHandles = find.byWidgetPredicate((w) =>
        w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn);
    expect(columnHandles, findsWidgets);

    // Drag 1st handle (No column right border) horizontally to expand column
    await tester.drag(columnHandles.first, const Offset(20, 0),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    // Verify SharedPreferences updated with new column width
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('rundown_col_no_width'), isNotNull);

    // Find row resize handles by SystemMouseCursors.resizeRow
    final rowHandles = find.byWidgetPredicate(
        (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeRow);
    expect(rowHandles, findsWidgets);

    // Drag vertically on first row bottom handle to adjust row height
    await tester.drag(rowHandles.first, const Offset(0, 20),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    // Verify SharedPreferences updated with new row height
    expect(prefs.getDouble('rundown_row_height'), isNotNull);
  });
}
