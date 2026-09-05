import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/widgets/todo_alarm_setup_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TodoDateGroup Reminder & Alarm Serialization Tests', () {
    test('Default TodoDateGroup has reminder disabled and default values', () {
      final group = TodoDateGroup(
        id: 'group-1',
        date: DateTime(2026, 8, 28),
      );

      expect(group.reminderEnabled, isFalse);
      expect(group.reminderType, 'specific');
      expect(group.reminderIntervalMinutes, 60);
      expect(group.reminderIntervalStartTime, '08:00');
      expect(group.reminderIntervalEndTime, '21:00');
      expect(group.reminderSpecificTimes, ['09:00', '13:00', '19:00']);
      expect(group.reminderSoundType, 'default');
      expect(group.reminderDefaultSound, 'chime_classic');
      expect(group.reminderSoundDisplayName, 'Chime Klasik');
      expect(group.reminderSummaryLabel, 'Pengingat nonaktif');
    });

    test('TodoDateGroup reminder serialization toJson and fromJson (Specific Times)', () {
      final original = TodoDateGroup(
        id: 'group-2',
        date: DateTime(2026, 8, 29),
        items: [
          TodoItem(id: 't1', title: 'Task 1', isCompleted: false),
          TodoItem(id: 't2', title: 'Task 2', isCompleted: true),
        ],
        reminderEnabled: true,
        reminderType: 'specific',
        reminderSpecificTimes: ['08:30', '14:00', '20:00'],
        reminderSoundType: 'default',
        reminderDefaultSound: 'alarm_digital',
      );

      expect(original.pendingCount, 1);
      expect(original.completedCount, 1);
      expect(original.reminderSoundDisplayName, 'Alarm Digital');
      expect(original.reminderSummaryLabel, 'Jam: 08:30, 14:00, 20:00 • Alarm Digital');

      final jsonMap = original.toJson();
      final parsed = TodoDateGroup.fromJson(jsonMap);

      expect(parsed.id, original.id);
      expect(parsed.reminderEnabled, isTrue);
      expect(parsed.reminderType, 'specific');
      expect(parsed.reminderSpecificTimes, ['08:30', '14:00', '20:00']);
      expect(parsed.reminderSoundType, 'default');
      expect(parsed.reminderDefaultSound, 'alarm_digital');
      expect(parsed.items.length, 2);
    });

    test('TodoDateGroup reminder serialization toJson and fromJson (Interval Mode with Custom MP3)', () {
      final original = TodoDateGroup(
        id: 'group-3',
        date: DateTime(2026, 8, 30),
        reminderEnabled: true,
        reminderType: 'interval',
        reminderIntervalMinutes: 120,
        reminderIntervalStartTime: '09:00',
        reminderIntervalEndTime: '18:00',
        reminderSoundType: 'custom',
        reminderCustomSoundPath: '/storage/emulated/0/Music/ringtone.mp3',
        reminderCustomSoundName: 'ringtone.mp3',
      );

      expect(original.reminderSoundDisplayName, 'ringtone.mp3');
      expect(
        original.reminderSummaryLabel,
        'Tiap 2 jam (09:00 - 18:00) • ringtone.mp3',
      );

      final jsonMap = original.toJson();
      final parsed = TodoDateGroup.fromJson(jsonMap);

      expect(parsed.reminderEnabled, isTrue);
      expect(parsed.reminderType, 'interval');
      expect(parsed.reminderIntervalMinutes, 120);
      expect(parsed.reminderIntervalStartTime, '09:00');
      expect(parsed.reminderIntervalEndTime, '18:00');
      expect(parsed.reminderSoundType, 'custom');
      expect(parsed.reminderCustomSoundPath, '/storage/emulated/0/Music/ringtone.mp3');
      expect(parsed.reminderCustomSoundName, 'ringtone.mp3');
    });

    test('TodoAlarmConfig fromGroup and applyToGroup work seamlessly', () {
      final group = TodoDateGroup(
        id: 'group-4',
        date: DateTime(2026, 9, 1),
      );

      final config = TodoAlarmConfig.fromGroup(group);
      expect(config.enabled, isFalse);

      config.enabled = true;
      config.type = 'interval';
      config.intervalMinutes = 30;
      config.intervalStartTime = '07:00';
      config.intervalEndTime = '22:00';
      config.soundType = 'default';
      config.defaultSound = 'cheerful_melody';

      config.applyToGroup(group);

      expect(group.reminderEnabled, isTrue);
      expect(group.reminderType, 'interval');
      expect(group.reminderIntervalMinutes, 30);
      expect(group.reminderDefaultSound, 'cheerful_melody');
      expect(group.reminderSoundDisplayName, 'Melodi Ceria');
    });

    test('TodoDateGroup isPast and isAlarmActive correctly handles past, today, and future dates', () {
      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 2));
      final todayDate = DateTime(now.year, now.month, now.day);
      final futureDate = now.add(const Duration(days: 2));

      final pastGroup = TodoDateGroup(
        id: 'group-past',
        date: pastDate,
        reminderEnabled: true,
        items: [TodoItem(id: 't1', title: 'Task in past', isCompleted: false)],
      );

      final todayGroup = TodoDateGroup(
        id: 'group-today',
        date: todayDate,
        reminderEnabled: true,
        items: [TodoItem(id: 't2', title: 'Task today', isCompleted: false)],
      );

      final futureGroup = TodoDateGroup(
        id: 'group-future',
        date: futureDate,
        reminderEnabled: true,
        items: [TodoItem(id: 't3', title: 'Task in future', isCompleted: false)],
      );

      expect(pastGroup.isPast, isTrue);
      expect(pastGroup.isAlarmActive, isFalse, reason: 'Past section alarms should not be active');

      expect(todayGroup.isPast, isFalse);
      expect(todayGroup.isAlarmActive, isTrue, reason: 'Today section alarms should be active');

      expect(futureGroup.isPast, isFalse);
      expect(futureGroup.isAlarmActive, isTrue, reason: 'Future section alarms should be active');

      // If all items completed, alarm should be inactive
      todayGroup.items.first.isCompleted = true;
      expect(todayGroup.isAllCompleted, isTrue);
      expect(todayGroup.isAlarmActive, isFalse);
    });
  });
}
