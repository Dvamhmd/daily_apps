import 'dart:convert';
import 'package:daily_apps/cards/card_tabungan.dart';
import 'package:daily_apps/models/model_tabungan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Tabungan Model & Calculation Tests', () {
    test('Model serialization and calculations with target', () {
      final tabungan = Tabungan(
        'Liburan',
        500000,
        targetNominal: 1000000,
        targetDate: DateTime.now().add(const Duration(days: 10)),
      );

      expect(tabungan.nama, 'Liburan');
      expect(tabungan.jumlah, 500000);
      expect(tabungan.targetNominal, 1000000);
      expect(tabungan.progress, 0.5);
      expect(tabungan.percentage, 50);
      expect(tabungan.sisaTarget, 500000);
      expect(tabungan.sisaHari, 10);

      final json = tabungan.toJson();
      final parsed = Tabungan.fromJson(json);
      expect(parsed.nama, tabungan.nama);
      expect(parsed.jumlah, tabungan.jumlah);
      expect(parsed.targetNominal, tabungan.targetNominal);
    });

    test('Model handles 0 target or reached target gracefully', () {
      final tabungan = Tabungan('Tabungan Bebas', 200000);
      expect(tabungan.progress, 0.0);
      expect(tabungan.percentage, 0);
      expect(tabungan.sisaTarget, 0);
      expect(tabungan.sisaHari, isNull);

      final reached = Tabungan('Done', 1500000, targetNominal: 1000000);
      expect(reached.progress, 1.0);
      expect(reached.percentage, 150);
      expect(reached.sisaTarget, 0);
    });
  });

  group('InfoCardTabungan Widget & Persistence Tests', () {
    testWidgets('Renders InfoCardTabungan and displays target & nominal accurately',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'tabungan': [
          jsonEncode(Tabungan('Dana Darurat', 2000000, targetNominal: 5000000).toJson()),
          jsonEncode(Tabungan('Qurban', 1000000, targetNominal: 3000000).toJson()),
        ],
        'target_amount': 10000000,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InfoCardTabungan(
                title: 'Tabunganku',
                amount: '3000000',
                items: const [
                  {'name': 'Dana Darurat', 'amount': '2000000'},
                  {'name': 'Qurban', 'amount': '1000000'},
                ],
                targetAmount: 10000000,
                onChanged: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tabunganku'), findsWidgets);
      // Total amount should be formatted
      expect(find.textContaining('3.000.000'), findsWidgets);
      // Target Tabungan should show 10.000.000
      expect(find.textContaining('10.000.000'), findsWidgets);

      // Open bottom sheet by tapping the card
      await tester.tap(find.text('Tabunganku').first);
      await tester.pumpAndSettle();

      // Check items inside modal
      expect(find.textContaining('Dana Darurat'), findsWidgets);
      expect(find.textContaining('Qurban'), findsWidgets);
      // Check banner inside bottom sheet
      expect(find.textContaining('Target:'), findsWidgets);
      expect(find.text('Kekurangan'), findsWidgets);
      expect(find.text('Nabung / Hari'), findsWidgets);
      expect(find.text('Tambah'), findsWidgets);
      expect(find.text('Hapus'), findsWidgets);
    });
  });
}
