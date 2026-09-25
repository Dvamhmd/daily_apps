import 'package:daily_apps/utils/pos_validation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PosValidationService Tests', () {
    test('Mengizinkan nama unik ketika data masih kosong', () async {
      final result = await PosValidationService.checkDuplicateName(newName: 'Cash');
      expect(result, isNull);
    });

    test('Menolak nama yang sama di kategori yang sama (case insensitive & trimmed)', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('uangku', ['{"nama":"Cash","jumlah":10000}']);

      final result1 = await PosValidationService.checkDuplicateName(newName: 'Cash');
      expect(result1, isNotNull);
      expect(result1, contains('Uangku'));

      final result2 = await PosValidationService.checkDuplicateName(newName: '  cash  ');
      expect(result2, isNotNull);
      expect(result2, contains('Uangku'));
    });

    test('Menolak nama yang sama lintas kategori (Uangku vs Tagihan vs Tabungan)', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('tagihan', ['{"nama":"Listrik","jumlah":50000}']);
      await prefs.setStringList('tabungan', ['{"nama":"BCA Darurat","jumlah":500000}']);

      // Coba tambah Uangku dengan nama Listrik -> harus ditolak karena sudah ada di Tagihan
      final resTagihan = await PosValidationService.checkDuplicateName(newName: 'Listrik');
      expect(resTagihan, isNotNull);
      expect(resTagihan, contains('Tagihan'));

      // Coba tambah Tagihan dengan nama BCA Darurat -> harus ditolak karena sudah ada di Tabungan
      final resTabungan = await PosValidationService.checkDuplicateName(newName: 'bca darurat');
      expect(resTabungan, isNotNull);
      expect(resTabungan, contains('Tabunganku'));
    });

    test('Mengizinkan nama yang sama saat mengedit pos miliknya sendiri (currentName)', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('uangku', ['{"nama":"Cash","jumlah":10000}']);

      // Edit 'Cash' tetap 'Cash' atau ubah case
      final result = await PosValidationService.checkDuplicateName(
        newName: 'Cash',
        currentName: 'Cash',
      );
      expect(result, isNull);

      final resultCase = await PosValidationService.checkDuplicateName(
        newName: 'CASH',
        currentName: 'Cash',
      );
      expect(resultCase, isNull);
    });
  });
}
