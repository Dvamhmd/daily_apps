import 'dart:convert';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/pages/todo_page.dart';
import 'package:daily_apps/utils/serious_mode_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('TodoPage Normal Mode: Deleting task shows Top Undo Banner with 5s countdown and can undo', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final group = TodoDateGroup(
      id: 'group_test_1',
      date: now,
      items: [
        TodoItem(id: 'task_1', title: 'Belajar Flutter'),
        TodoItem(id: 'task_2', title: 'Makan Siang'),
      ],
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SeriousModeService.prefKeyNormalTodoGroups,
      jsonEncode([group.toJson()]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TodoPage(
          onPageSelected: (_) {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify tasks are present
    expect(find.text('Belajar Flutter'), findsOneWidget);
    expect(find.text('Makan Siang'), findsOneWidget);

    // Find delete icon button for 'Belajar Flutter'
    final deleteButtons = find.byTooltip('Hapus Tugas');
    expect(deleteButtons, findsWidgets);

    // Tap first delete button
    await tester.tap(deleteButtons.first);
    await tester.pump();

    // Top undo banner should appear with title and subtitle
    expect(find.text('Tugas Dihapus'), findsOneWidget);
    expect(find.text('BATALKAN'), findsOneWidget);
    expect(find.text('5s'), findsOneWidget);
    // Subtitle in undo banner displays task title
    expect(find.text('Belajar Flutter'), findsOneWidget);

    // Wait 2 seconds (simulate cooldown)
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('BATALKAN'), findsOneWidget);

    // Tap BATALKAN (Undo)
    await tester.tap(find.text('BATALKAN'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Verify task is restored in the list and undo banner is dismissed
    expect(find.text('Tugas Dihapus'), findsNothing);
    expect(find.text('BATALKAN'), findsNothing);
    expect(find.byKey(const Key('task_1')), findsOneWidget);
    expect(find.byKey(const Key('task_2')), findsOneWidget);
  });

  testWidgets('TodoPage Normal Mode: 5-second countdown expires and dismisses undo banner', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final group = TodoDateGroup(
      id: 'group_test_2',
      date: now,
      items: [
        TodoItem(id: 'task_1', title: 'Tugas Uji Coba'),
      ],
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SeriousModeService.prefKeyNormalTodoGroups,
      jsonEncode([group.toJson()]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TodoPage(
          onPageSelected: (_) {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    final deleteButton = find.byTooltip('Hapus Tugas');
    await tester.tap(deleteButton);
    await tester.pump();

    expect(find.text('Tugas Dihapus'), findsOneWidget);

    // Advance timer past 5 seconds
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    // Undo banner should be dismissed
    expect(find.text('Tugas Dihapus'), findsNothing);
    expect(find.text('BATALKAN'), findsNothing);
  });

  testWidgets('TodoPage Normal Mode: Deleting section shows Top Undo Banner and can undo', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final group = TodoDateGroup(
      id: 'group_test_3',
      date: now,
      items: [
        TodoItem(id: 'task_sec_1', title: 'Tugas Dalam Section'),
      ],
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SeriousModeService.prefKeyNormalTodoGroups,
      jsonEncode([group.toJson()]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TodoPage(
          onPageSelected: (_) {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tugas Dalam Section'), findsOneWidget);

    // Open section popup menu (3 dots)
    final popupButtons = find.byType(PopupMenuButton<String>);
    expect(popupButtons, findsWidgets);
    await tester.tap(popupButtons.first);
    await tester.pumpAndSettle();

    // Tap Hapus Section Ini in popup menu
    expect(find.text('Hapus Section Ini'), findsOneWidget);
    await tester.tap(find.text('Hapus Section Ini'));
    await tester.pumpAndSettle();

    // Confirm dialog appears
    expect(find.text('Hapus Section?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Hapus'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Section deleted, top undo banner shown
    expect(find.text('Section Dihapus'), findsOneWidget);
    expect(find.text('BATALKAN'), findsOneWidget);

    // Tap BATALKAN
    await tester.tap(find.text('BATALKAN'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Verify section and task are restored
    expect(find.text('Section Dihapus'), findsNothing);
    expect(find.text('Tugas Dalam Section'), findsOneWidget);
  });
}
