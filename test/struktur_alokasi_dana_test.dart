import 'package:flutter_test/flutter_test.dart';
import 'package:daily_apps/models/model_struktur.dart';

void main() {
  group('Keuangan Struktur - Alokasi Dana Internal Tests', () {
    test('Alokasi dana internal dari Rekening ke Cash tidak masuk pemasukan maupun pengeluaran', () {
      final data = StrukturData(
        rekeningStruktur: RekeningStruktur(balance: 1000000),
        onHandCash: OnHandCash(balance: 0),
        onHandDebit: OnHandDebit(balance: 0),
      );

      expect(data.totalDanaStruktur, 1000000);
      expect(data.totalPemasukan, 0);
      expect(data.totalPengeluaran, 0);

      final now = DateTime.now();

      // 1. Transaksi kredit pada Rekening
      final kreditTx = StrukturTransaction(
        id: '1',
        title: 'Tarik Tunai dari Rekening',
        type: 'pengeluaran',
        sourceAccount: 'rekening',
        targetAccount: 'cash',
        amount: 300000,
        isInternalTransfer: true,
        timestamp: now,
      );

      // 2. Transaksi debit pada Cash
      final debitTx = StrukturTransaction(
        id: '2',
        title: 'Terima Tunai dari Rekening',
        type: 'pemasukan',
        sourceAccount: 'rekening',
        targetAccount: 'cash',
        amount: 300000,
        isInternalTransfer: true,
        timestamp: now,
      );

      data.rekeningStruktur.balance -= 300000;
      data.onHandCash.balance += 300000;
      data.transactions.addAll([kreditTx, debitTx]);

      // Verifikasi saldo wadah & total dana struktur
      expect(data.rekeningStruktur.balance, 700000);
      expect(data.onHandCash.balance, 300000);
      expect(data.totalDanaStruktur, 1000000);

      // Verifikasi bahwa alokasi internal TIDAK masuk pemasukan atau pengeluaran
      expect(data.totalPemasukan, 0);
      expect(data.totalPengeluaran, 0);

      // Namun transaksi tetap tercatat di tabel untuk melacak aliran dana
      expect(data.transactions.length, 2);
      expect(kreditTx.isAlokasiInternal, true);
      expect(debitTx.isAlokasiInternal, true);
      expect(kreditTx.isPurePengeluaran, false);
      expect(debitTx.isPurePemasukan, false);
      expect(kreditTx.isPengeluaran, true); // tetap bertipe pengeluaran untuk tabel debit/kredit
      expect(debitTx.isPemasukan, true); // tetap bertipe pemasukan untuk tabel debit/kredit
    });

    test('Alokasi dana internal dengan admin bank mencatat hanya admin bank sebagai pengeluaran', () {
      final data = StrukturData(
        rekeningStruktur: RekeningStruktur(balance: 1000000, bankName: 'BCA'),
        onHandDebit: OnHandDebit(balance: 0, bankName: 'BRI'),
      );

      final now = DateTime.now();
      const nominal = 500000;
      const adminFee = 2500;

      // 1. Kredit Rekening (pokok transfer internal)
      final kreditTx = StrukturTransaction(
        id: '10',
        title: 'Transfer ke On Hand Debit',
        type: 'pengeluaran',
        sourceAccount: 'rekening',
        targetAccount: 'debit',
        amount: nominal,
        isInternalTransfer: true,
        timestamp: now,
      );

      // 2. Debit On Hand (pokok transfer internal)
      final debitTx = StrukturTransaction(
        id: '11',
        title: 'Transfer dari Rekening Struktur',
        type: 'pemasukan',
        sourceAccount: 'rekening',
        targetAccount: 'debit',
        amount: nominal,
        isInternalTransfer: true,
        timestamp: now,
      );

      // 3. Pengeluaran Admin Bank (murni keluar)
      final feeTx = StrukturTransaction(
        id: '12',
        title: 'Admin bank transfer beda bank',
        type: 'pengeluaran',
        sourceAccount: 'rekening',
        amount: adminFee,
        adminFee: 0,
        ku: 'SDK',
        kode: 'Adm Bank/Pajak',
        isInternalTransfer: false,
        timestamp: now,
      );

      data.rekeningStruktur.balance -= (nominal + adminFee);
      data.onHandDebit.balance += nominal;
      data.transactions.addAll([kreditTx, debitTx, feeTx]);

      // Total Dana Struktur berkurang hanya sebesar admin bank
      expect(data.rekeningStruktur.balance, 497500);
      expect(data.onHandDebit.balance, 500000);
      expect(data.totalDanaStruktur, 997500);

      // Pemasukan tetap 0, Pengeluaran HANYA 2.500 (admin bank)
      expect(data.totalPemasukan, 0);
      expect(data.totalPengeluaran, 2500);

      expect(feeTx.isAlokasiInternal, false);
      expect(feeTx.isPurePengeluaran, true);
    });

    test('Pemasukan murni dari luar tetap terhitung sebagai pemasukan', () {
      final data = StrukturData(
        rekeningStruktur: RekeningStruktur(balance: 0),
      );

      final incomingTx = StrukturTransaction(
        id: '20',
        title: 'Dana dari S3',
        type: 'pemasukan',
        targetAccount: 'rekening',
        manualSource: 'S3',
        amount: 2000000,
        isInternalTransfer: false,
        kode: 'Dana dari S3',
      );

      data.rekeningStruktur.balance += incomingTx.amount;
      data.transactions.add(incomingTx);

      expect(incomingTx.isAlokasiInternal, false);
      expect(incomingTx.isPurePemasukan, true);
      expect(data.totalPemasukan, 2000000);
      expect(data.totalPengeluaran, 0);
      expect(data.totalDanaStruktur, 2000000);
    });

    test('Pengeluaran murni ke luar tetap terhitung sebagai pengeluaran', () {
      final data = StrukturData(
        onHandCash: OnHandCash(balance: 500000),
      );

      final expenseTx = StrukturTransaction(
        id: '30',
        title: 'Beli Konsumsi Rapat',
        type: 'pengeluaran',
        sourceAccount: 'cash',
        amount: 75000,
        isInternalTransfer: false,
        ku: 'Sekretaris',
        kode: 'Konsumsi',
      );

      data.onHandCash.balance -= expenseTx.amount;
      data.transactions.add(expenseTx);

      expect(expenseTx.isAlokasiInternal, false);
      expect(expenseTx.isPurePengeluaran, true);
      expect(data.totalPemasukan, 0);
      expect(data.totalPengeluaran, 75000);
      expect(data.totalDanaStruktur, 425000);
    });

    test('Serialization and deserialization retains isInternalTransfer correctly', () {
      final tx = StrukturTransaction(
        id: '40',
        title: 'Setor Tunai ke Rekening Struktur',
        type: 'pemasukan',
        sourceAccount: 'cash',
        targetAccount: 'rekening',
        amount: 250000,
        isInternalTransfer: true,
      );

      final json = tx.toJson();
      expect(json['isInternalTransfer'], true);

      final restored = StrukturTransaction.fromJson(json);
      expect(restored.isInternalTransfer, true);
      expect(restored.isAlokasiInternal, true);
      expect(restored.isPurePemasukan, false);
    });
  });
}
