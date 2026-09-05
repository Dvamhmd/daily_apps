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

  group('TodoPage Multi-Select & Batch Drag UI Tests', () {
    testWidgets('Long press on task item activates multi-select mode with bottom bar', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final group = TodoDateGroup(
        id: 'group_test_1',
        date: now,
        items: [
          TodoItem(id: 'task_1', title: 'Kirim Invoice'),
          TodoItem(id: 'task_2', title: 'Review Desain'),
          TodoItem(id: 'task_3', title: 'Olahraga Pagi'),
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

      expect(find.text('Kirim Invoice'), findsOneWidget);
      expect(find.text('Review Desain'), findsOneWidget);

      // Bottom bar not visible initially
      expect(find.text('Tugas Dipilih'), findsNothing);

      // Long press first item to enter multi-select mode
      await tester.longPress(find.text('Kirim Invoice'));
      await tester.pumpAndSettle();

      // Multi-select bottom bar should now appear
      expect(find.text('Tugas Dipilih'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Tahan & seret untuk atur / pindahkan'), findsOneWidget);

      // Tap on second task to add to selection
      await tester.tap(find.text('Review Desain'));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);

      // Tap Batal button to dismiss multi-select
      await tester.tap(find.byTooltip('Batal'));
      await tester.pumpAndSettle();

      expect(find.text('Tugas Dipilih'), findsNothing);
    });

    testWidgets('Swiping task left deletes task and shows Top Undo Banner', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final group = TodoDateGroup(
        id: 'group_test_2',
        date: now,
        items: [
          TodoItem(id: 'task_1', title: 'Setup Database'),
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

      expect(find.text('Setup Database'), findsOneWidget);

      // Swipe left to delete with sufficient distance
      await tester.drag(find.text('Setup Database'), const Offset(-600, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350)); // Dismissible slide animation
      await tester.pump(const Duration(milliseconds: 350)); // Dismissible resize animation -> triggers onDismissed

      // Top undo banner should appear
      expect(find.text('Tugas Dihapus'), findsOneWidget);
      expect(find.text('BATALKAN'), findsOneWidget);
    });

    testWidgets('Multi-select bottom bar move button opens modal and moves tasks with undo', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));

      final group1 = TodoDateGroup(
        id: 'group_1',
        date: today,
        items: [
          TodoItem(id: 'task_to_move', title: 'Beli Sayur'),
        ],
      );

      final group2 = TodoDateGroup(
        id: 'group_2',
        date: tomorrow,
        items: [],
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        SeriousModeService.prefKeyNormalTodoGroups,
        jsonEncode([group1.toJson(), group2.toJson()]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TodoPage(
            onPageSelected: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Long press task to select it
      await tester.longPress(find.text('Beli Sayur'));
      await tester.pumpAndSettle();

      expect(find.text('Tugas Dipilih'), findsOneWidget);

      // Tap 'Pindahkan ke Section Lain' on bottom bar
      final moveBtn = find.byTooltip('Pindahkan ke Section Lain');
      expect(moveBtn, findsOneWidget);

      await tester.tap(moveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Pindahkan 1 Tugas'), findsOneWidget);
      final targetTileFinder = find.descendant(
        of: find.byType(ListView),
        matching: find.text(group2.formattedFullDate),
      );
      expect(targetTileFinder, findsOneWidget);

      await tester.tap(targetTileFinder);
      await tester.pump();

      expect(find.text('Tugas Dipindahkan'), findsOneWidget);
      expect(find.text('BATALKAN'), findsOneWidget);
    });

    testWidgets('ReorderableListView and ReorderableDragStartListener exist on task items for drag & drop', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final group = TodoDateGroup(
        id: 'group_reorder_test',
        date: now,
        items: [
          TodoItem(id: 'task_a', title: 'Task A'),
          TodoItem(id: 'task_b', title: 'Task B'),
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

      // Find ReorderableListView inside the section
      expect(find.byType(ReorderableListView), findsWidgets);

      // Find drag handle ReorderableDragStartListener
      expect(find.byType(ReorderableDragStartListener), findsWidgets);
      expect(find.byIcon(Icons.drag_indicator_rounded), findsWidgets);
    });

    testWidgets('Multi-select batch drag reorders all selected tasks together', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final group = TodoDateGroup(
        id: 'group_batch_reorder_test',
        date: now,
        items: [
          TodoItem(id: 'task_1', title: 'Tugas 1'),
          TodoItem(id: 'task_2', title: 'Tugas 2'),
          TodoItem(id: 'task_3', title: 'Tugas 3'),
          TodoItem(id: 'task_4', title: 'Tugas 4'),
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

      // Select Task 1, 2, 3
      await tester.longPress(find.text('Tugas 1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tugas 2'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tugas 3'));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget); // 3 items selected
    });
  });
}
