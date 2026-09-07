import 'package:flutter_test/flutter_test.dart';
import 'package:daily_apps/models/model_pribadi.dart';

void main() {
  group('Keuangan Pribadi Kategori Tests', () {
    test('PersonalDefaultRules should separate pemasukan and pengeluaran', () {
      final pemasukan = PersonalDefaultRules.defaultPemasukanRules();
      final pengeluaran = PersonalDefaultRules.defaultPengeluaranRules();
      final all = PersonalDefaultRules.defaultRules();

      expect(pemasukan.every((r) => r.type == 'pemasukan'), isTrue);
      expect(pengeluaran.every((r) => r.type == 'pengeluaran'), isTrue);
      expect(all.length, equals(pemasukan.length + pengeluaran.length));
    });

    test('resolveKodeFromText should prevent keyword collisions between pemasukan and pengeluaran', () {
      final rules = [
        CustomKodeRule(keyword: 'bonus', kode: 'Bonus Pemasukan', type: 'pemasukan'),
        CustomKodeRule(keyword: 'bonus', kode: 'Bonus Pegawai (Pengeluaran)', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'admin', kode: 'Admin Fee Masuk', type: 'pemasukan'),
        CustomKodeRule(keyword: 'admin', kode: 'Biaya Admin Bank', type: 'pengeluaran'),
      ];

      // Pemasukan resolution
      final resPemasukan = PribadiTransaction.resolveKodeFromText(
        'Dapat bonus proyek',
        customRules: rules,
        type: 'pemasukan',
      );
      expect(resPemasukan, equals('Bonus Pemasukan'));

      // Pengeluaran resolution
      final resPengeluaran = PribadiTransaction.resolveKodeFromText(
        'Bayar bonus staf',
        customRules: rules,
        type: 'pengeluaran',
      );
      expect(resPengeluaran, equals('Bonus Pegawai (Pengeluaran)'));

      // Transaction getDisplayKode
      final txMasuk = PribadiTransaction(
        id: '1',
        title: 'Pembayaran admin',
        type: 'pemasukan',
        amount: 10000,
      );
      expect(txMasuk.getDisplayKode(customRules: rules), equals('Admin Fee Masuk'));

      final txKeluar = PribadiTransaction(
        id: '2',
        title: 'Pembayaran admin',
        type: 'pengeluaran',
        amount: 5000,
      );
      expect(txKeluar.getDisplayKode(customRules: rules), equals('Biaya Admin Bank'));
    });

    test('Kategori auto-sorting should sort by category ascending then by keyword ascending', () {
      final rules = [
        CustomKodeRule(keyword: 'pertamax', kode: 'Transportasi', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'indomaret', kode: 'Belanja', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'bensin', kode: 'Transportasi', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'alfamart', kode: 'Belanja', type: 'pengeluaran'),
      ];

      rules.sort((a, b) {
        final catComp =
            a.kode.trim().toLowerCase().compareTo(b.kode.trim().toLowerCase());
        if (catComp != 0) return catComp;
        return a.keyword
            .trim()
            .toLowerCase()
            .compareTo(b.keyword.trim().toLowerCase());
      });

      // Expected order:
      // 1. Belanja -> alfamart
      // 2. Belanja -> indomaret
      // 3. Transportasi -> bensin
      // 4. Transportasi -> pertamax
      expect(rules[0].kode, equals('Belanja'));
      expect(rules[0].keyword, equals('alfamart'));

      expect(rules[1].kode, equals('Belanja'));
      expect(rules[1].keyword, equals('indomaret'));

      expect(rules[2].kode, equals('Transportasi'));
      expect(rules[2].keyword, equals('bensin'));

      expect(rules[3].kode, equals('Transportasi'));
      expect(rules[3].keyword, equals('pertamax'));
    });
  });
}
