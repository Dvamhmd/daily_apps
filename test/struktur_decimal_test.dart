import 'package:flutter_test/flutter_test.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:daily_apps/models/model_struktur.dart';

void main() {
  group('RupiahFormatter Decimal Tests', () {
    test('Format without decimal (default 0)', () {
      expect(RupiahFormatter.format(0), '0');
      expect(RupiahFormatter.format(50000), '50.000');
      expect(RupiahFormatter.format(1250000), '1.250.000');
      expect(RupiahFormatter.format(100000000), '100.000.000');
    });

    test('Format with various decimal digits', () {
      expect(RupiahFormatter.format(1500000, decimalDigits: 1), '1.500.000,0');
      expect(RupiahFormatter.format(1500000, decimalDigits: 2), '1.500.000,00');
      expect(RupiahFormatter.format(1500000, decimalDigits: 3), '1.500.000,000');
      expect(RupiahFormatter.format(1500000.5, decimalDigits: 2), '1.500.000,50');
      expect(RupiahFormatter.format(1500000.75, decimalDigits: 2), '1.500.000,75');
      expect(RupiahFormatter.format(0, decimalDigits: 2), '0,00');
      expect(RupiahFormatter.format(25000, decimalDigits: 0), '25.000');
    });

    test('Negative numbers with decimal digits', () {
      expect(RupiahFormatter.format(-50000, decimalDigits: 2), '-50.000,00');
    });
  });

  group('StrukturData decimalDigits Serialization Tests', () {
    test('Default decimalDigits is 0', () {
      final data = StrukturData();
      expect(data.decimalDigits, 0);
    });

    test('Serialization toJson and fromJson preserves decimalDigits', () {
      final data = StrukturData(decimalDigits: 2);
      final jsonMap = data.toJson();
      expect(jsonMap['decimalDigits'], 2);

      final restored = StrukturData.fromJson(jsonMap);
      expect(restored.decimalDigits, 2);
    });

    test('fromJson fallback to 0 when decimalDigits is null', () {
      final jsonMap = <String, dynamic>{
        'rekeningStruktur': {'balance': 0},
        'onHandDebit': {'balance': 0},
        'onHandCash': {'balance': 0},
        'transactions': [],
      };
      final restored = StrukturData.fromJson(jsonMap);
      expect(restored.decimalDigits, 0);
    });
  });
}
