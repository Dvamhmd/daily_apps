import 'package:daily_apps/models/model_uangku.dart';
import 'package:daily_apps/utils/pribadi_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PribadiSyncService Tests', () {
    test('3 Item pada Uangku otomatis menjadi 3 Pos Dana di Keuangan Pribadi', () async {
      final testMonth = DateTime(2026, 9, 1);
      final monthKey = PribadiSyncService.getMonthKey(null, testMonth);

      // Simpan 3 item di Uangku
      final itemsUangku = [
        Uangku('Gaji Utama', 5000000),
        Uangku('Freelance Side-Job', 2500000),
        Uangku('Bonus Proyek', 1500000),
      ];
      await PribadiSyncService.saveUangkuList(monthKey, itemsUangku);

      // Muat data Keuangan Pribadi
      final loaded = await PribadiSyncService.loadPribadiData(monthKey);

      // Harus ada tepat 3 Pos Dana dengan nama dan saldo yang sesuai
      expect(loaded.posDanaList.length, 3);
      expect(loaded.posDanaList[0].nama, 'Gaji Utama');
      expect(loaded.posDanaList[0].balance, 5000000);
      expect(loaded.posDanaList[1].nama, 'Freelance Side-Job');
      expect(loaded.posDanaList[1].balance, 2500000);
      expect(loaded.posDanaList[2].nama, 'Bonus Proyek');
      expect(loaded.posDanaList[2].balance, 1500000);
      expect(loaded.totalPosDana, 9000000);
      expect(loaded.totalDanaPribadi, 9000000);
    });

    test('Pemasukan dari Uangku tercatat di PribadiData dan Pos Dana terkait', () async {
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
      expect(loaded.posDanaList.length, 1);
      expect(loaded.posDanaList.first.nama, 'Gaji Kantor');
      expect(loaded.transactions.length, 1);
      expect(loaded.transactions.first.title, 'Gaji Kantor');
      expect(loaded.transactions.first.type, 'pemasukan');
      expect(loaded.transactions.first.amount, 5000000);
      expect(loaded.transactions.first.getDisplayKode(customRules: loaded.customKodeRules), 'Pemasukan Gaji');
      expect(loaded.posDanaList.first.balance, 5000000);
      expect(loaded.totalDanaPribadi, 5000000);
    });

    test('Pengeluaran dari Uangku tercatat dan memotong saldo di Pos Dana Keuangan Pribadi', () async {
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
        nama: 'Rekening Utama',
        nominal: 300000,
        selectedMonth: testMonth,
        keterangan: 'Belanja Bulanan (Kredit)',
      );

      final loaded = await PribadiSyncService.loadPribadiData(monthKey);
      expect(loaded.posDanaList.length, 1);
      expect(loaded.transactions.length, 2);
      expect(loaded.transactions.last.type, 'pengeluaran');
      expect(loaded.transactions.last.amount, 300000);
      expect(loaded.transactions.last.getDisplayKode(customRules: loaded.customKodeRules), 'Belanja & Kebutuhan');
      expect(loaded.posDanaList.first.balance, 700000);
      expect(loaded.totalDanaPribadi, 700000);
    });

    test('Edit Uangku menyesuaikan nama dan saldo Pos Dana Keuangan Pribadi', () async {
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
      expect(loaded.posDanaList.length, 1);
      expect(loaded.posDanaList.first.nama, 'Gaji');
      expect(loaded.posDanaList.first.balance, 2000000);

      // 2. Edit pos dana Gaji menjadi 3.5 juta dan ubah nama menjadi 'Gaji Bulanan'
      await PribadiSyncService.syncEditUangku(
        namaLama: 'Gaji',
        jumlahLama: 2000000,
        namaBaru: 'Gaji Bulanan',
        jumlahBaru: 3500000,
        selectedMonth: testMonth,
      );

      loaded = await PribadiSyncService.loadPribadiData(monthKey);
      expect(loaded.posDanaList.length, 1);
      expect(loaded.posDanaList.first.nama, 'Gaji Bulanan');
      expect(loaded.posDanaList.first.balance, 3500000);
      expect(loaded.transactions.length, 1);
      expect(loaded.transactions.first.title, 'Gaji Bulanan');
      expect(loaded.transactions.first.amount, 3500000);

      // 3. Edit pos dana Gaji menjadi 1.5 juta (dikurangi)
      await PribadiSyncService.syncEditUangku(
        namaLama: 'Gaji Bulanan',
        jumlahLama: 3500000,
        namaBaru: 'Gaji Pokok',
        jumlahBaru: 1500000,
        selectedMonth: testMonth,
      );

      loaded = await PribadiSyncService.loadPribadiData(monthKey);
      expect(loaded.posDanaList.length, 1);
      expect(loaded.posDanaList.first.nama, 'Gaji Pokok');
      expect(loaded.posDanaList.first.balance, 1500000);
      expect(loaded.transactions.first.title, 'Gaji Pokok');
      expect(loaded.transactions.first.amount, 1500000);
    });

    test('Hapus pos Uangku otomatis menghapus Pos Dana dan data pemasukan terkait dari Keuangan Pribadi', () async {
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
      expect(loaded.posDanaList.length, 2);
      expect(loaded.transactions.length, 2);
      expect(loaded.totalPosDana, 4000000);

      // Hapus pos dana Gaji dari Uangku
      await PribadiSyncService.syncHapusUangku(
        nama: 'Gaji',
        jumlah: 3000000,
        selectedMonth: testMonth,
      );

      loaded = await PribadiSyncService.loadPribadiData(monthKey);
      // Pos Dana Gaji hilang, hanya tersisa Freelance
      expect(loaded.posDanaList.length, 1);
      expect(loaded.posDanaList.first.nama, 'Freelance');
      expect(loaded.posDanaList.first.balance, 1000000);
      expect(loaded.transactions.length, 1);
      expect(loaded.transactions.first.title, 'Freelance');
      expect(loaded.transactions.first.amount, 1000000);
      expect(loaded.totalDanaPribadi, 1000000);
    });

    test('Dua arah: Tambah, edit, dan hapus Pos Dana di Keuangan Pribadi tersimpan ke Uangku', () async {
      final testMonth = DateTime(2026, 9, 1);
      final monthKey = PribadiSyncService.getMonthKey(null, testMonth);

      // Tambah pos dana dari Keuangan Pribadi
      await PribadiSyncService.syncAddPosDanaToUangku(
        monthKey: monthKey,
        nama: 'Kas Operasional',
        saldo: 1200000,
      );

      var uList = await PribadiSyncService.loadUangkuList(monthKey);
      expect(uList.length, 1);
      expect(uList.first.nama, 'Kas Operasional');
      expect(uList.first.jumlah, 1200000);

      // Edit pos dana dari Keuangan Pribadi
      await PribadiSyncService.syncEditPosDanaToUangku(
        monthKey: monthKey,
        namaLama: 'Kas Operasional',
        namaBaru: 'Kas Kantor',
        saldoBaru: 1500000,
      );

      uList = await PribadiSyncService.loadUangkuList(monthKey);
      expect(uList.length, 1);
      expect(uList.first.nama, 'Kas Kantor');
      expect(uList.first.jumlah, 1500000);

      // Hapus pos dana dari Keuangan Pribadi
      await PribadiSyncService.syncHapusPosDanaToUangku(
        monthKey: monthKey,
        nama: 'Kas Kantor',
      );

      uList = await PribadiSyncService.loadUangkuList(monthKey);
      expect(uList.isEmpty, isTrue);
    });
  });
}
