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

  testWidgets('RundownDetailPage renders compact icon-only toolbar and can open dimension modal via long press',
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

    // Tap on Tune Icon in toolbar to enter resize mode
    final tuneButton = find.byIcon(Icons.tune_rounded).last;
    await tester.tap(tuneButton);
    await tester.pumpAndSettle();

    // Verify tune icon turns into check icon
    expect(find.byIcon(Icons.check_rounded), findsWidgets);

    // Tap check icon to exit resize mode
    final checkButton = find.byIcon(Icons.check_rounded).last;
    await tester.tap(checkButton);
    await tester.pumpAndSettle();

    // Verify tune icon returns
    expect(find.byIcon(Icons.tune_rounded), findsWidgets);
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

  testWidgets('Spreadsheet drag resize handles allow adjusting column width and row height by dragging only when toggle is active',
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

    // Initially, table setting mode is OFF: no resize handles should exist
    expect(
        find.byWidgetPredicate((w) =>
            w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn),
        findsNothing);
    expect(
        find.byWidgetPredicate((w) =>
            w is MouseRegion && w.cursor == SystemMouseCursors.resizeRow),
        findsNothing);

    // Toggle Resize Mode ON via table settings icon
    final tuneButton = find.byIcon(Icons.tune_rounded).first;
    await tester.tap(tuneButton);
    await tester.pumpAndSettle();

    // Find column resize handles on header title areas by SystemMouseCursors.resizeColumn
    final columnHandles = find.byWidgetPredicate((w) =>
        w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn);
    expect(columnHandles, findsWidgets);

    // Drag column header title area (e.g. Kegiatan or No) horizontally to expand column
    await tester.drag(find.text('Kegiatan'), const Offset(30, 0),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    // Drag 1st handle (No column header area) horizontally to expand column
    await tester.drag(columnHandles.first, const Offset(20, 0),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    // Verify SharedPreferences updated with new column width
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('rundown_col_no_width'), isNotNull);
    expect(prefs.getDouble('rundown_col_kegiatan_width'), isNotNull);

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

    // Toggle Resize Mode OFF via check icon
    final checkButton = find.byIcon(Icons.check_rounded).first;
    await tester.tap(checkButton);
    await tester.pumpAndSettle();

    // Now resize handles should be disabled again
    expect(
        find.byWidgetPredicate((w) =>
            w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn),
        findsNothing);
    expect(
        find.byWidgetPredicate((w) =>
            w is MouseRegion && w.cursor == SystemMouseCursors.resizeRow),
        findsNothing);
  });

  testWidgets('Rundown table uses ClampingScrollPhysics without rubber-band bounce at edges',
      (WidgetTester tester) async {
    final sampleRundown = createSampleRundown();

    await tester.pumpWidget(
      MaterialApp(
        home: RundownDetailPage(rundown: sampleRundown),
      ),
    );
    await tester.pumpAndSettle();

    // Find horizontal SingleChildScrollView with ClampingScrollPhysics in table
    final horizontalScrollView = find.byWidgetPredicate((w) =>
        w is SingleChildScrollView &&
        w.scrollDirection == Axis.horizontal &&
        w.physics is ClampingScrollPhysics);
    expect(horizontalScrollView, findsOneWidget);
  });

  testWidgets('Zoom controls in control bar work properly',
      (WidgetTester tester) async {
    final sampleRundown = createSampleRundown();

    await tester.pumpWidget(
      MaterialApp(
        home: RundownDetailPage(rundown: sampleRundown),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial zoom is 100%
    expect(find.text('100%'), findsOneWidget);

    // Tap Zoom In button
    final zoomInBtn = find.byTooltip('Perbesar Tabel (Zoom In)');
    expect(zoomInBtn, findsOneWidget);
    await tester.tap(zoomInBtn);
    await tester.pumpAndSettle();

    // Verify zoom increased to 110%
    expect(find.text('110%'), findsOneWidget);

    // Tap scale indicator to reset to 100%
    await tester.tap(find.text('110%'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('Column alignment (left, center, right) can be set separately for Header and Data',
      (WidgetTester tester) async {
    final sampleRundown = createSampleRundown();

    await tester.pumpWidget(
      MaterialApp(
        home: RundownDetailPage(rundown: sampleRundown),
      ),
    );
    await tester.pumpAndSettle();

    // Find alignment button in toolbar
    final alignButton =
        find.byTooltip('Atur Perataan Kolom (Kiri / Tengah / Kanan)');
    expect(alignButton, findsOneWidget);

    // Tap alignment button to open alignment modal
    await tester.tap(alignButton);
    await tester.pumpAndSettle();

    // Verify modal header and tabs are visible
    expect(find.text('Perataan Kolom (Alignment)'), findsOneWidget);
    expect(find.text('Judul Kolom'), findsOneWidget);
    expect(find.text('Data Kolom'), findsOneWidget);
    expect(find.text('Kolom No'), findsOneWidget);

    // In Judul Kolom tab (default), set Kolom No to Right alignment
    final rataKananButtons = find.byTooltip('Rata Kanan');
    expect(rataKananButtons, findsWidgets);
    await tester.tap(rataKananButtons.first);
    await tester.pumpAndSettle();

    // Switch to Data Kolom tab
    await tester.tap(find.text('Data Kolom'));
    await tester.pumpAndSettle();

    // In Data Kolom tab, set Waktu Mulai to Left alignment
    final rataKiriButtons = find.byTooltip('Rata Kiri');
    expect(rataKiriButtons, findsWidgets);
    // tap the second rata kiri button (which corresponds to Waktu Mulai)
    await tester.tap(rataKiriButtons.at(1));
    await tester.pumpAndSettle();

    // Tap Selesai button to close modal
    await tester.tap(find.widgetWithText(ElevatedButton, 'Selesai'));
    await tester.pumpAndSettle();

    // Verify separate persistence in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final headerAlignmentsStr =
        prefs.getString('rundown_header_col_alignments');
    final dataAlignmentsStr = prefs.getString('rundown_data_col_alignments');

    expect(headerAlignmentsStr, isNotNull);
    expect(headerAlignmentsStr, contains('"no":"right"'));

    expect(dataAlignmentsStr, isNotNull);
    expect(dataAlignmentsStr, contains('"mulai":"left"'));
  });

  testWidgets(
      'Custom column header has no cross icon and can be renamed and deleted via long press options',
      (WidgetTester tester) async {
    final sampleRundown = Rundown(
      id: 'test_rundown_custom_col',
      title: 'Acara Custom',
      startDate: DateTime(2026, 9, 10),
      totalDays: 1,
      days: [
        RundownDay(
          dayNumber: 1,
          date: DateTime(2026, 9, 10),
          theme: 'Day 1',
          customColumns: ['PIC / Petugas'],
          rows: [
            RundownTableRow(
              id: 'row_1',
              startTime: '08:00',
              durationMinutes: 30,
              activity: 'Pembukaan',
              location: 'Hall',
              customValues: {'PIC / Petugas': 'Budi'},
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RundownDetailPage(rundown: sampleRundown),
      ),
    );
    await tester.pumpAndSettle();

    // Verify custom column header text exists
    expect(find.text('PIC / Petugas'), findsWidgets);

    // Verify cross icon is NOT in the header
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    // Long press on custom column header
    var customColHeader = find.text('PIC / Petugas').first;
    await tester.longPress(customColHeader);
    await tester.pumpAndSettle();

    // Verify bottom sheet options appear
    expect(find.text('Edit Nama Kolom'), findsOneWidget);
    expect(find.text('Hapus Kolom'), findsOneWidget);

    // Test 1: Edit Nama Kolom
    await tester.tap(find.text('Edit Nama Kolom'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Nama Kolom'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Koordinator');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
    await tester.pumpAndSettle();

    // Verify renamed column exists and old name does not
    expect(find.text('Koordinator'), findsWidgets);
    expect(find.text('PIC / Petugas'), findsNothing);

    // Test 2: Hapus Kolom
    customColHeader = find.text('Koordinator').first;
    await tester.longPress(customColHeader);
    await tester.pumpAndSettle();

    expect(find.text('Hapus Kolom'), findsOneWidget);
    await tester.tap(find.text('Hapus Kolom'));
    await tester.pumpAndSettle();

    // Confirm dialog appears
    expect(find.text('Hapus Kolom "Koordinator"?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Hapus'));
    await tester.pumpAndSettle();

    // Verify custom column is deleted
    expect(find.text('Koordinator'), findsNothing);
  });
}

