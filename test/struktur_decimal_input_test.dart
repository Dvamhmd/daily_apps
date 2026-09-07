import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:daily_apps/models/model_struktur.dart';

void main() {
  group('RupiahFormatter Decimal Tests', () {
    test('parseToNum parses standard integer string with dots', () {
      expect(RupiahFormatter.parseToNum('1.000.000'), 1000000);
      expect(RupiahFormatter.parseToNum('50.000'), 50000);
      expect(RupiahFormatter.parseToNum('0'), 0);
      expect(RupiahFormatter.parseToNum(''), 0);
      expect(RupiahFormatter.parseToNum(null), 0);
    });

    test('parseToNum parses decimal numbers with comma', () {
      expect(RupiahFormatter.parseToNum('1.000,50'), 1000.5);
      expect(RupiahFormatter.parseToNum('25.000,75'), 25000.75);
      expect(RupiahFormatter.parseToNum('0,25'), 0.25);
      expect(RupiahFormatter.parseToNum(',50'), 0.5);
      expect(RupiahFormatter.parseToNum('100,'), 100);
    });

    test('format formats values with decimalDigits correctly', () {
      expect(RupiahFormatter.format(1000000, decimalDigits: 0), '1.000.000');
      expect(RupiahFormatter.format(1000.5, decimalDigits: 2), '1.000,50');
      expect(RupiahFormatter.format(25000.75, decimalDigits: 2), '25.000,75');
      expect(RupiahFormatter.format(0, decimalDigits: 2), '0,00');
    });

    test('RupiahInputFormatter formats input with comma and thousand separator', () {
      final formatter = RupiahInputFormatter(allowDecimal: true, maxDecimalDigits: 2);

      // Input "1000" -> "1.000"
      final result1 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '1000',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      expect(result1.text, '1.000');

      // Input "1000," -> "1.000,"
      final result2 = formatter.formatEditUpdate(
        result1,
        const TextEditingValue(
          text: '1.000,',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      expect(result2.text, '1.000,');

      // Input "1.000,5" -> "1.000,5"
      final result3 = formatter.formatEditUpdate(
        result2,
        const TextEditingValue(
          text: '1.000,5',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      expect(result3.text, '1.000,5');

      // Input "1.000,50" -> "1.000,50"
      final result4 = formatter.formatEditUpdate(
        result3,
        const TextEditingValue(
          text: '1.000,50',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      expect(result4.text, '1.000,50');

      // Input "1.000,509" -> should be capped at 2 decimal digits: "1.000,50"
      final result5 = formatter.formatEditUpdate(
        result4,
        const TextEditingValue(
          text: '1.000,509',
          selection: TextSelection.collapsed(offset: 9),
        ),
      );
      expect(result5.text, '1.000,50');
    });
  });

  group('Model Struktur Decimal Support Tests', () {
    test('RekeningStruktur and OnHand balances support num values', () {
      final rekening = RekeningStruktur(
        bankName: 'BSI',
        accountNumber: '1234567890',
        accountHolder: 'Struktur',
        balance: 1500000.75,
      );
      final debit = OnHandDebit(
        bankName: 'BCA',
        accountNumber: '0987',
        accountHolder: 'Debit Holder',
        balance: 250000.5,
      );
      final cash = OnHandCash(
        balance: 100000.25,
      );

      expect(rekening.balance, 1500000.75);
      expect(debit.balance, 250000.5);
      expect(cash.balance, 100000.25);
    });

    test('StrukturData totals with decimal transactions calculate correctly', () {
      final data = StrukturData(
        rekeningStruktur: RekeningStruktur(
          bankName: 'BSI',
          accountNumber: '123',
          accountHolder: 'Struktur',
          balance: 1000.5,
        ),
        onHandDebit: OnHandDebit(
          bankName: 'BCA',
          accountNumber: '456',
          accountHolder: 'Debit',
          balance: 500.25,
        ),
        onHandCash: OnHandCash(
          balance: 250.25,
        ),
        decimalDigits: 2,
        transactions: [
          StrukturTransaction(
            id: '1',
            title: 'Pemasukan A',
            type: 'pemasukan',
            targetAccount: 'rekening',
            amount: 500.5,
            timestamp: DateTime.now(),
          ),
          StrukturTransaction(
            id: '2',
            title: 'Pengeluaran B',
            type: 'pengeluaran',
            sourceAccount: 'rekening',
            amount: 200.25,
            adminFee: 2.5,
            timestamp: DateTime.now(),
          ),
        ],
      );

      expect(data.totalOnHand, 750.5);
      expect(data.totalDanaStruktur, 1751.0);
      expect(data.totalPemasukan, 500.5);
      expect(data.totalPengeluaran, 200.25);
    });

    test('StrukturData JSON serialization preserves decimal values', () {
      final data = StrukturData(
        rekeningStruktur: RekeningStruktur(
          bankName: 'BSI',
          accountNumber: '123',
          accountHolder: 'Struktur',
          balance: 12345.67,
        ),
        onHandDebit: OnHandDebit(
          bankName: 'BCA',
          accountNumber: '456',
          accountHolder: 'Debit',
          balance: 2345.67,
        ),
        onHandCash: OnHandCash(
          balance: 345.67,
        ),
        decimalDigits: 2,
        transactions: [
          StrukturTransaction(
            id: 'tx_1',
            title: 'Donasi',
            type: 'pemasukan',
            targetAccount: 'rekening',
            amount: 9876.54,
            adminFee: 1.23,
            timestamp: DateTime(2026, 9, 7),
          ),
        ],
      );

      final json = data.toJson();
      final restored = StrukturData.fromJson(json);

      expect(restored.rekeningStruktur.balance, 12345.67);
      expect(restored.onHandDebit.balance, 2345.67);
      expect(restored.onHandCash.balance, 345.67);
      expect(restored.decimalDigits, 2);
      expect(restored.transactions.first.amount, 9876.54);
      expect(restored.transactions.first.adminFee, 1.23);
    });
  });
}
