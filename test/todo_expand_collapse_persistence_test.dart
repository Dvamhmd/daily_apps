import 'dart:convert';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/pages/todo_page.dart';
import 'package:daily_apps/pages/todo_riwayat_page.dart';
import 'package:daily_apps/utils/serious_mode_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Todo Section Expand/Collapse Persistence Tests', () {
    test('TodoDateGroup model correctly serializes and deserializes isCollapsed', () {
      final now = DateTime(2026, 9, 5);
      final group = TodoDateGroup(
        id: 'group_1',
        date: now,
        isCollapsed: true,
        items: [
          TodoItem(id: 't1', title: 'Tugas Belanja'),
        ],
      );

      final json = group.toJson();
      expect(json['isCollapsed'], isTrue);

      final restored = TodoDateGroup.fromJson(json);
      expect(restored.isCollapsed, isTrue);
      expect(restored.id, 'group_1');
      expect(restored.items.length, 1);
      expect(restored.items.first.title, 'Tugas Belanja');

      // Test default value
      final defaultGroup = TodoDateGroup.fromJson({
        'id': 'group_default',
        'date': now.toIso8601String(),
      });
      expect(defaultGroup.isCollapsed, isFalse);
    });

    testWidgets('Toggling collapse persists to SharedPreferences and survives app restart / reload',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final group = TodoDateGroup(
        id: 'group_test_1',
        date: now,
        isCollapsed: false,
        items: [
          TodoItem(id: 'task_1', title: 'Belajar Flutter Testing'),
        ],
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        SeriousModeService.prefKeyNormalTodoGroups,
        jsonEncode([group.toJson()]),
      );

      // 1. First app launch: Section is initially expanded
      await tester.pumpWidget(
        MaterialApp(
          home: TodoPage(
            onPageSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Task item is visible
      expect(find.text('Belajar Flutter Testing'), findsOneWidget);

      // Tap collapse button (Chevron or header)
      final collapseBtn = find.byTooltip('Tutup Section');
      expect(collapseBtn, findsOneWidget);
      await tester.tap(collapseBtn);
      await tester.pumpAndSettle();

      // Verify task item is now collapsed (hidden / not showing item text in visible tree)
      expect(find.text('Belajar Flutter Testing'), findsNothing);

      // Verify SharedPreferences has saved isCollapsed = true
      final savedJsonStr = prefs.getString(SeriousModeService.prefKeyNormalTodoGroups);
      expect(savedJsonStr, isNotNull);
      final List decoded = jsonDecode(savedJsonStr!);
      expect(decoded.first['isCollapsed'], isTrue);

      // 2. Simulate App Restart (Rebuilding TodoPage from scratch with saved SharedPreferences)
      await tester.pumpWidget(
        MaterialApp(
          home: TodoPage(
            onPageSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify on app restart: Section remains collapsed!
      expect(find.text('Belajar Flutter Testing'), findsNothing);
      expect(find.byTooltip('Buka Section'), findsOneWidget);

      // 3. User taps to expand again
      await tester.tap(find.byTooltip('Buka Section'));
      await tester.pumpAndSettle();

      expect(find.text('Belajar Flutter Testing'), findsOneWidget);

      // Verify SharedPreferences has updated isCollapsed = false
      final updatedJsonStr = prefs.getString(SeriousModeService.prefKeyNormalTodoGroups);
      final List updatedDecoded = jsonDecode(updatedJsonStr!);
      expect(updatedDecoded.first['isCollapsed'], isFalse);
    });

    testWidgets('TodoRiwayatPage also persists collapsed state', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final archivedGroup = TodoDateGroup(
        id: 'archived_group_1',
        date: now,
        isArchived: true,
        isCollapsed: true, // Already saved as collapsed
        items: [
          TodoItem(id: 'task_archived_1', title: 'Tugas Arsip 1', isCompleted: true),
        ],
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        SeriousModeService.prefKeyNormalTodoGroups,
        jsonEncode([archivedGroup.toJson()]),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TodoRiwayatPage(isSeriousMode: false),
        ),
      );
      await tester.pumpAndSettle();

      // Since isCollapsed is true, task item is not visible initially
      expect(find.text('Tugas Arsip 1'), findsNothing);
      expect(find.byTooltip('Buka Section'), findsOneWidget);

      // Tap to expand
      await tester.tap(find.byTooltip('Buka Section'));
      await tester.pumpAndSettle();

      expect(find.text('Tugas Arsip 1'), findsOneWidget);

      // Verify saved to prefs as isCollapsed = false
      final savedStr = prefs.getString(SeriousModeService.prefKeyNormalTodoGroups);
      final List decoded = jsonDecode(savedStr!);
      expect(decoded.first['isCollapsed'], isFalse);
    });
  });
}
