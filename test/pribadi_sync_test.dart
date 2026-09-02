import 'package:daily_apps/utils/pribadi_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PribadiSyncService Tests', () {
    test('Pemasukan dari Uangku tercatat di PribadiData', () async {
      final testMonth = DateTime(2026, 9, 1);
      final monthKey = PribadiSyncService.getMonthKey(null, testMonth);

      // Catat pemasukan gaji dari Uangku
      await PribadiSyncService.recordPemasukanFromUangku(
        nama: 'Gaji Kantor',
        nominal: 5000000,
        selectedMonth: testMonth,
        keterangan: 'Gaji Kantor',
      );

      final loaded = await PribadiSyncService.loadPribadiData(monthKey);
      expect(loaded.transactions.length, 1);
      expect(loaded.transactions.first.title, 'Gaji Kantor');
      expect(loaded.transactions.first.type, 'pemasukan');
      expect(loaded.transactions.first.amount, 5000000);
      expect(loaded.transactions.first.getDisplayKode(customRules: loaded.customKodeRules), 'Pemasukan Gaji');
      expect(loaded.posDanaList.first.balance, 5000000);
      expect(loaded.totalDanaPribadi, 5000000);
    });

    test('Pengeluaran dari Uangku tercatat dan memotong saldo di PribadiData', () async {
      final testMonth = DateTime(2026, 9, 1);
      final monthKey = PribadiSyncService.getMonthKey(null, testMonth);

      // Pemasukan awal
      await PribadiSyncService.recordPemasukanFromUangku(
        nama: 'Rekening Utama',
        nominal: 1000000,
        selectedMonth: testMonth,
      );

      // Pengeluaran / Kredit
      await PribadiSyncService.recordPengeluaranFromUangku(
        nama: 'Belanja Bulanan',
        nominal: 300000,
        selectedMonth: testMonth,
        keterangan: 'Belanja Bulanan (Kredit)',
      );

      final loaded = await PribadiSyncService.loadPribadiData(monthKey);
      expect(loaded.transactions.length, 2);
      expect(loaded.transactions.last.type, 'pengeluaran');
      expect(loaded.transactions.last.amount, 300000);
      expect(loaded.transactions.last.getDisplayKode(customRules: loaded.customKodeRules), 'Belanja & Kebutuhan');
      expect(loaded.posDanaList.first.balance, 700000);
      expect(loaded.totalDanaPribadi, 700000);
    });

    test('Edit Uangku menyesuaikan transaksi Keuangan Pribadi yang sudah ada tanpa membuat data baru', () async {
      final testMonth = DateTime(2026, 9, 1);
      final monthKey = PribadiSyncService.getMonthKey(null, testMonth);

      // 1. Buat pos dana Gaji 2 juta di Uangku
      await PribadiSyncService.recordPemasukanFromUangku(
        nama: 'Gaji',
        nominal: 2000000,
        selectedMonth: testMonth,
        keterangan: 'Gaji',
      );

      var loaded = await PribadiSyncService.loadPribadiData(monthKey);
      expect(loaded.transactions.length, 1);
      expect(loaded.transactions.first.title, 'Gaji');
      expect(loaded.transactions.first.amount, 2000000);
      expect(loaded.posDanaList.first.balance, 2000000);

      // 2. Edit pos dana Gaji menjadi 3.5 juta
      await PribadiSyncService.syncEditUangku(
        namaLama: 'Gaji',
        jumlahLama: 2000000,
        namaBaru: 'Gaji Bulanan',
        jumlahBaru: 3500000,
        selectedMonth: testMonth,
      );

      loaded = await PribadiSyncService.loadPribadiData(monthKey);
      // Tetap 1 transaksi (tidak membuat data baru)
      expect(loaded.transactions.length, 1);
      expect(loaded.transactions.first.title, 'Gaji Bulanan');
      expect(loaded.transactions.first.amount, 3500000);
      expect(loaded.posDanaList.first.balance, 3500000);

      // 3. Edit pos dana Gaji menjadi 1.5 juta (dikurangi)
      await PribadiSyncService.syncEditUangku(
        namaLama: 'Gaji Bulanan',
        jumlahLama: 3500000,
        namaBaru: 'Gaji',
        jumlahBaru: 1500000,
        selectedMonth: testMonth,
      );

      loaded = await PribadiSyncService.loadPribadiData(monthKey);
      // Tetap 1 transaksi
      expect(loaded.transactions.length, 1);
      expect(loaded.transactions.first.title, 'Gaji');
      expect(loaded.transactions.first.amount, 1500000);
      expect(loaded.posDanaList.first.balance, 1500000);
    });

    test('Hapus pos Uangku otomatis menghapus data pemasukan terkait dari Keuangan Pribadi dan menyesuaikan saldo', () async {
      final testMonth = DateTime(2026, 9, 1);
      final monthKey = PribadiSyncService.getMonthKey(null, testMonth);

      // Buat 2 pos dana Uangku
      await PribadiSyncService.recordPemasukanFromUangku(
        nama: 'Gaji',
        nominal: 3000000,
        selectedMonth: testMonth,
        keterangan: 'Gaji',
      );
      await PribadiSyncService.recordPemasukanFromUangku(
        nama: 'Freelance',
        nominal: 1000000,
        selectedMonth: testMonth,
        keterangan: 'Freelance',
      );

      var loaded = await PribadiSyncService.loadPribadiData(monthKey);
      expect(loaded.transactions.length, 2);
      expect(loaded.posDanaList.first.balance, 4000000);

      // Hapus pos dana Gaji dari Uangku
      await PribadiSyncService.syncHapusUangku(
        nama: 'Gaji',
        jumlah: 3000000,
        selectedMonth: testMonth,
      );

      loaded = await PribadiSyncService.loadPribadiData(monthKey);
      // Transaksi Gaji hilang, hanya tersisa Freelance
      expect(loaded.transactions.length, 1);
      expect(loaded.transactions.first.title, 'Freelance');
      expect(loaded.transactions.first.amount, 1000000);
      expect(loaded.posDanaList.first.balance, 1000000);
      expect(loaded.totalDanaPribadi, 1000000);
    });
  });
}
