import 'package:daily_apps/models/model_daily_task.dart';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/pages/daily_productivity_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DailyTaskGroup Model & Application Tests', () {
    test('Default values and serialization (toJson / fromJson)', () {
      final group = DailyTaskGroup(
        id: 'group_test_1',
        title: 'Kesehatan & Kebugaran',
        tasks: [
          'Minum air 2L',
          'Olahraga 30 Menit',
          'Konsumsi Vitamin',
        ],
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 7),
        reminderEnabled: true,
        reminderType: 'specific',
        reminderSpecificTimes: ['08:00', '13:00', '20:00'],
        reminderDefaultSound: 'chime_classic',
      );

      expect(group.totalTasks, 3);
      expect(group.reminderEnabled, isTrue);
      expect(group.dateRangeSummary, '1/9/2026 - 7/9/2026 (7 hari)');
      expect(group.reminderSoundDisplayName, 'Chime Klasik');
      expect(
        group.reminderSummaryLabel,
        'Jam: 08:00, 13:00, 20:00 • Chime Klasik',
      );

      final jsonMap = group.toJson();
      final parsed = DailyTaskGroup.fromJson(jsonMap);

      expect(parsed.id, group.id);
      expect(parsed.title, 'Kesehatan & Kebugaran');
      expect(parsed.tasks.length, 3);
      expect(parsed.tasks[0], 'Minum air 2L');
      expect(parsed.reminderEnabled, isTrue);
      expect(parsed.reminderSpecificTimes, ['08:00', '13:00', '20:00']);
      expect(parsed.reminderDefaultSound, 'chime_classic');
    });

    test('DailyTaskGroup.applyGroupToDateGroups creates new sections for missing dates', () {
      final taskGroup = DailyTaskGroup(
        id: 'group_template',
        title: 'Rutinitas Pagi',
        tasks: ['Bangun 05:00', 'Membaca Buku', 'Olahraga'],
        reminderEnabled: true,
        reminderType: 'specific',
        reminderSpecificTimes: ['06:00', '09:00'],
        reminderDefaultSound: 'cheerful_melody',
      );

      final rangeStart = DateTime(2026, 9, 1);
      final rangeEnd = DateTime(2026, 9, 3); // 3 days: 1, 2, 3 Sept

      final List<TodoDateGroup> existing = [];
      final result = DailyTaskGroup.applyGroupToDateGroups(
        existingGroups: existing,
        taskGroup: taskGroup,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(result.length, 3);
      for (final dateSection in result) {
        expect(dateSection.items.length, 3);
        expect(dateSection.items.map((i) => i.title).toList(), [
          'Bangun 05:00',
          'Membaca Buku',
          'Olahraga',
        ]);
        expect(dateSection.reminderEnabled, isTrue);
        expect(dateSection.reminderSpecificTimes, ['06:00', '09:00']);
        expect(dateSection.reminderDefaultSound, 'cheerful_melody');
      }
    });

    test('DailyTaskGroup.applyGroupToDateGroups merges tasks into existing sections without duplicates', () {
      final existingDate = DateTime(2026, 9, 1);
      final existingSection = TodoDateGroup(
        id: 'existing_1',
        date: existingDate,
        items: [
          TodoItem(id: 'item_1', title: 'Tugas Lama'),
          TodoItem(id: 'item_2', title: 'Minum air 2L'), // Duplicate task name
        ],
        reminderEnabled: false,
      );

      final taskGroup = DailyTaskGroup(
        id: 'group_template',
        title: 'Kesehatan',
        tasks: ['Minum air 2L', 'Olahraga 30 Menit'],
        reminderEnabled: true,
        reminderType: 'interval',
        reminderIntervalMinutes: 120,
        reminderIntervalStartTime: '08:00',
        reminderIntervalEndTime: '20:00',
      );

      final result = DailyTaskGroup.applyGroupToDateGroups(
        existingGroups: [existingSection],
        taskGroup: taskGroup,
        rangeStart: existingDate,
        rangeEnd: existingDate,
      );

      expect(result.length, 1);
      final updatedSection = result.first;
      // Should have 'Tugas Lama', 'Minum air 2L', and 'Olahraga 30 Menit' (3 items, not 4)
      expect(updatedSection.items.length, 3);
      expect(
        updatedSection.items.map((i) => i.title).toList(),
        ['Tugas Lama', 'Minum air 2L', 'Olahraga 30 Menit'],
      );
      expect(updatedSection.reminderEnabled, isTrue);
      expect(updatedSection.reminderType, 'interval');
      expect(updatedSection.reminderIntervalMinutes, 120);
    });
  });

  group('ProductivityHelper Heatmap Color Tests', () {
    test('Serious Mode (Dark Mode): few tasks has lower opacity, more tasks has higher opacity', () {
      // Lazy (1-2 tasks) -> Low opacity green (0.18)
      final lazyColor = ProductivityHelper.getCellColor(ProductivityLevel.lazy, isDark: true);
      // Okay (3-5 tasks) -> Medium opacity green (0.42)
      final okayColor = ProductivityHelper.getCellColor(ProductivityLevel.okay, isDark: true);
      // Good (6-8 tasks) -> High opacity green (0.70)
      final goodColor = ProductivityHelper.getCellColor(ProductivityLevel.good, isDark: true);
      // Amazing (9-10 tasks) -> Full opacity green (1.0)
      final amazingColor = ProductivityHelper.getCellColor(ProductivityLevel.amazing, isDark: true);

      // Verify opacity increases as task count increases
      expect(lazyColor.opacity, closeTo(0.18, 0.01));
      expect(okayColor.opacity, closeTo(0.42, 0.01));
      expect(goodColor.opacity, closeTo(0.70, 0.01));
      expect(amazingColor.opacity, closeTo(1.0, 0.01));

      // Verify text colors in dark mode
      expect(ProductivityHelper.getTextColor(ProductivityLevel.lazy, isDark: true).value, 0xFFA7F3D0);
      expect(ProductivityHelper.getTextColor(ProductivityLevel.amazing, isDark: true).value, 0xFFFFFFFF);
    });

    test('Normal Mode (Light Mode): retains original light color palette', () {
      expect(ProductivityHelper.getCellColor(ProductivityLevel.lazy, isDark: false).value, 0xFFDCFCE7);
      expect(ProductivityHelper.getCellColor(ProductivityLevel.okay, isDark: false).value, 0xFF86EFAC);
      expect(ProductivityHelper.getCellColor(ProductivityLevel.good, isDark: false).value, 0xFF22C55E);
      expect(ProductivityHelper.getCellColor(ProductivityLevel.amazing, isDark: false).value, 0xFF15803D);
    });
  });
}

