import 'package:flutter_test/flutter_test.dart';
import 'package:daily_apps/models/model_struktur.dart';

void main() {
  group('Auto-Input Kode Transaksi Struktur Tests', () {
    test('Rule 1: DP KK -> Terima DP DTK', () {
      expect(
        StrukturTransaction.resolveKodeFromText('DP KK Barqi'),
        equals('Terima DP DTK'),
      );
      expect(
        StrukturTransaction.resolveKodeFromText('Penerimaan dp kk cabang'),
        equals('Terima DP DTK'),
      );
    });

    test('Rule 2: konsumsi -> Biaya Konsumsi Acara', () {
      expect(
        StrukturTransaction.resolveKodeFromText(
            'konsumsi pembinaan AB Afwan'),
        equals('Biaya Konsumsi Acara'),
      );
      expect(
        StrukturTransaction.resolveKodeFromText('Beli Konsumsi Rapat'),
        equals('Biaya Konsumsi Acara'),
      );
    });

    test('Rule 3: sewa tempat / sewa ruangan -> Sewa Tempat', () {
      expect(
        StrukturTransaction.resolveKodeFromText(
            'Sewa ruangan pembinaan AB Afwan'),
        equals('Sewa Tempat'),
      );
      expect(
        StrukturTransaction.resolveKodeFromText('sewa tempat gedung aula'),
        equals('Sewa Tempat'),
      );
    });

    test('Rule 4: Kontribusi DP Bulan -> Kontribusi DP S4', () {
      expect(
        StrukturTransaction.resolveKodeFromText('Kontribusi DP Bulan Agustus'),
        equals('Kontribusi DP S4'),
      );
      expect(
        StrukturTransaction.resolveKodeFromText(
            'kontribusi dp bulan September 2026'),
        equals('Kontribusi DP S4'),
      );
    });

    test('Rule 5: admin bank transfer -> Biaya RTK', () {
      expect(
        StrukturTransaction.resolveKodeFromText(
            'admin bank transfer antar bank'),
        equals('Biaya RTK'),
      );
      expect(
        StrukturTransaction.resolveKodeFromText('Admin bank transfer'),
        equals('Biaya RTK'),
      );
    });

    test('Display Kode fallback to dynamic auto-resolution', () {
      final tx1 = StrukturTransaction(
        id: '1',
        title: 'Pembayaran DP KK Barqi',
        type: 'pemasukan',
        amount: 500000,
      );
      expect(tx1.displayKode, equals('Terima DP DTK'));

      final tx2 = StrukturTransaction(
        id: '2',
        title: 'Pengeluaran',
        type: 'pengeluaran',
        amount: 250000,
        note: 'konsumsi pembinaan AB Afwan',
      );
      expect(tx2.displayKode, equals('Biaya Konsumsi Acara'));

      final tx3 = StrukturTransaction(
        id: '3',
        title: 'Pengeluaran Lain',
        type: 'pengeluaran',
        amount: 100000,
        kode: 'Custom Kode',
      );
      expect(tx3.displayKode, equals('Custom Kode'));
    });

    test('JSON serialization preserves kode', () {
      final tx = StrukturTransaction(
        id: '99',
        title: 'Sewa ruangan',
        type: 'pengeluaran',
        amount: 750000,
        kode: 'Sewa Tempat',
      );

      final json = tx.toJson();
      expect(json['kode'], equals('Sewa Tempat'));

      final fromJsonTx = StrukturTransaction.fromJson(json);
      expect(fromJsonTx.kode, equals('Sewa Tempat'));
      expect(fromJsonTx.displayKode, equals('Sewa Tempat'));
    });
  });
}
