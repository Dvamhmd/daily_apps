import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_apps/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Limit Pengeluaran Harian Logic Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Perhitungan sisa hari inklusif dari start hingga end date', () {
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 9, 30);
      final totalHari = end.difference(start).inDays + 1;
      expect(totalHari, 30);

      // Hari ini 18 September 2026, end 25 September 2026 -> 8 hari (18,19,20,21,22,23,24,25)
      final today = DateTime(2026, 9, 18);
      final targetEnd = DateTime(2026, 9, 25);
      final sisaHari = targetEnd.difference(today).inDays + 1;
      expect(sisaHari, 8);

      // Dana aman 800.000 / 8 hari = 100.000 / hari
      final danaAman = 800000;
      final limitHarian = (danaAman / sisaHari).floor();
      expect(limitHarian, 100000);
    });

    test('Simulasi pergantian hari: sisa hari berkurang & limit menyesuaikan dinamis', () {
      final targetEnd = DateTime(2026, 9, 25);
      int danaAman = 700000;

      // Hari ke-1 (18 Sept): sisa 8 hari
      DateTime currentDay = DateTime(2026, 9, 18);
      int sisa = targetEnd.difference(currentDay).inDays + 1;
      expect(sisa, 8);
      expect((danaAman / sisa).floor(), 87500);

      // Hari ke-2 (19 Sept): sisa 7 hari, misal dana aman berkurang jadi 620.000
      currentDay = DateTime(2026, 9, 19);
      danaAman = 620000;
      sisa = targetEnd.difference(currentDay).inDays + 1;
      expect(sisa, 7);
      expect((danaAman / sisa).floor(), 88571);

      // Hari terakhir (25 Sept): sisa 1 hari
      currentDay = DateTime(2026, 9, 25);
      sisa = targetEnd.difference(currentDay).inDays + 1;
      expect(sisa, 1);
      expect((danaAman / sisa).floor(), 620000);

      // Hari setelah periode (26 Sept): sisa 0 hari (periode selesai)
      currentDay = DateTime(2026, 9, 26);
      final diff = targetEnd.difference(currentDay).inDays;
      final sisaSelesai = diff < 0 ? 0 : diff + 1;
      expect(sisaSelesai, 0);
    });

    test('Handling Dana Aman negatif atau 0', () {
      const danaAmanNol = 0;
      const danaAmanMinus = -50000;
      const sisaHari = 5;

      final limitNol = (sisaHari > 0 && danaAmanNol > 0) ? (danaAmanNol / sisaHari).floor() : 0;
      final limitMinus = (sisaHari > 0 && danaAmanMinus > 0) ? (danaAmanMinus / sisaHari).floor() : 0;

      expect(limitNol, 0);
      expect(limitMinus, 0);
    });

    test('SharedPreferences persistence untuk Limit Harian', () async {
      final prefs = await SharedPreferences.getInstance();

      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 9, 30);

      await prefs.setBool('limit_harian_enabled', true);
      await prefs.setInt('limit_harian_start_date', start.millisecondsSinceEpoch);
      await prefs.setInt('limit_harian_end_date', end.millisecondsSinceEpoch);

      expect(prefs.getBool('limit_harian_enabled'), true);
      expect(prefs.getInt('limit_harian_start_date'), start.millisecondsSinceEpoch);
      expect(prefs.getInt('limit_harian_end_date'), end.millisecondsSinceEpoch);

      final loadedStart = DateTime.fromMillisecondsSinceEpoch(prefs.getInt('limit_harian_start_date')!);
      final loadedEnd = DateTime.fromMillisecondsSinceEpoch(prefs.getInt('limit_harian_end_date')!);

      expect(loadedStart.year, 2026);
      expect(loadedStart.month, 9);
      expect(loadedStart.day, 1);

      expect(loadedEnd.year, 2026);
      expect(loadedEnd.month, 9);
      expect(loadedEnd.day, 30);
    });

    testWidgets('Modal Pengaturan Dana Aman menyatukan Opsi Deadline dan Limit Harian', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('uangku_2026_09', [
        '{"nama":"Gaji","jumlah":3000000,"tanggalCair":null}',
      ]);
      await prefs.setStringList('tagihan_2026_09', [
        '{"nama":"Listrik","jumlah":500000,"deadline":"2026-09-25T00:00:00.000"}',
      ]);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Buka modal dari tombol Pengaturan di card Dana Aman
      expect(find.text('Pengaturan'), findsOneWidget);
      await tester.tap(find.text('Pengaturan'));
      await tester.pumpAndSettle();

      // Verifikasi komponen Opsi Deadline dan Limit Pengeluaran Harian tampil bersama
      expect(find.text('Pengaturan Dana Aman'), findsOneWidget);
      expect(find.text('Opsi Deadline Tagihan'), findsOneWidget);
      expect(find.text('Limit Pengeluaran Harian'), findsWidgets);

      // Aktifkan switch limit harian
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Verifikasi muncul card rentang tanggal dan simulasi live
      expect(find.text('Simulasi Limit Harian'), findsOneWidget);

      // Terapkan pengaturan
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();

      // Verifikasi tersimpan dan limit harian tampil berdampingan dengan Dana Aman (Dana Aman | Limit)
      expect(find.text('|'), findsOneWidget);
      expect(find.text('/ hari'), findsOneWidget);
    });
  });
}
