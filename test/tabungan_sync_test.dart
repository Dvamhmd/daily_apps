import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_apps/models/model_tabungan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tabungan Persistence & Progress Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Loads and saves tabungan pos dana correctly without data loss', () async {
      final prefs = await SharedPreferences.getInstance();

      final list = [
        Tabungan('Tabungan Darurat', 5000000),
        Tabungan('Tabungan Liburan', 2500000),
      ];
      final encoded = list.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList('tabungan', encoded);

      final loadedRaw = prefs.getStringList('tabungan') ?? [];
      final loadedList = loadedRaw.map((e) => Tabungan.fromJson(jsonDecode(e))).toList();

      expect(loadedList.length, equals(2));
      expect(loadedList[0].nama, equals('Tabungan Darurat'));
      expect(loadedList[0].jumlah, equals(5000000));
      expect(loadedList[1].nama, equals('Tabungan Liburan'));
      expect(loadedList[1].jumlah, equals(2500000));
    });

    test('Handles target_date stored as int and string seamlessly without crashing', () async {
      // Test when stored as int
      SharedPreferences.setMockInitialValues({
        'target_date': 1700000000000,
        'target_amount': 10000000,
      });
      var prefs = await SharedPreferences.getInstance();

      DateTime? parseDate(dynamic raw) {
        if (raw == null) return null;
        if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
        if (raw is String) {
          final parsed = DateTime.tryParse(raw);
          if (parsed != null) return parsed;
          final intVal = int.tryParse(raw);
          if (intVal != null) return DateTime.fromMillisecondsSinceEpoch(intVal);
        }
        return null;
      }

      var rawDate = prefs.get('target_date');
      var date = parseDate(rawDate);
      expect(date, isNotNull);
      expect(date!.millisecondsSinceEpoch, equals(1700000000000));

      // Test when stored as String
      SharedPreferences.setMockInitialValues({
        'target_date': '2026-12-31T00:00:00.000',
        'target_amount': 15000000,
      });
      prefs = await SharedPreferences.getInstance();
      rawDate = prefs.get('target_date');
      date = parseDate(rawDate);
      expect(date, isNotNull);
      expect(date!.year, equals(2026));
      expect(date.month, equals(12));
      expect(date.day, equals(31));
    });

    test('Progress calculates properly before and after target is set', () {
      final tabungan = [
        Tabungan('Pos 1', 2000000),
        Tabungan('Pos 2', 3000000),
      ];
      final total = tabungan.fold<int>(0, (sum, e) => sum + e.jumlah);
      expect(total, equals(5000000));

      // Before target is set (target = 0)
      int targetAmount = 0;
      double progress = targetAmount <= 0 ? 0.0 : (total / targetAmount).clamp(0.0, 1.0);
      int percentage = targetAmount <= 0 ? 0 : ((total / targetAmount) * 100).round();

      expect(progress, equals(0.0));
      expect(percentage, equals(0));

      // After target is set (target = 10.000.000)
      targetAmount = 10000000;
      progress = targetAmount <= 0 ? 0.0 : (total / targetAmount).clamp(0.0, 1.0);
      percentage = targetAmount <= 0 ? 0 : ((total / targetAmount) * 100).round();

      expect(progress, equals(0.5));
      expect(percentage, equals(50));
    });
  });
}
