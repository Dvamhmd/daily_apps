import 'dart:convert';
import 'package:daily_apps/models/model_pribadi.dart';
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

    test('Hapus pos Uangku otomatis menghapus Pos Dana namun mempertahankan riwayat transaksi di Keuangan Pribadi', () async {
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
      // Transaksi tetap utuh (2 transaksi)
      expect(loaded.transactions.length, 2);
      expect(loaded.transactions.any((tx) => tx.title == 'Gaji'), true);
      expect(loaded.transactions.any((tx) => tx.title == 'Freelance'), true);
      expect(loaded.totalPosDana, 1000000);
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

      // Hapus pos dana dari Keuangan Pribadi
      await PribadiSyncService.syncHapusPosDanaToUangku(
        monthKey: monthKey,
        nama: 'Kas Kantor',
      );

      uList = await PribadiSyncService.loadUangkuList(monthKey);
      expect(uList.isEmpty, isTrue);
    });

    test('Tambah Uangku lalu catat pemasukan tidak menduplikasi saldo Pos Dana (tidak 2x)', () async {
      final testMonth = DateTime(2026, 9, 1);
      final monthKey = PribadiSyncService.getMonthKey(null, testMonth);

      // Simulasikan alur saat tombol "Tambah Uangku" ditekan di CardUangku:
      // 1. Simpan ke daftar Uangku
      final itemsUangku = [
        Uangku('Gaji Bulanan', 5000000),
      ];
      await PribadiSyncService.saveUangkuList(monthKey, itemsUangku);

      // 2. Panggil recordPemasukanFromUangku
      await PribadiSyncService.recordPemasukanFromUangku(
        nama: 'Gaji Bulanan',
        nominal: 5000000,
        selectedMonth: testMonth,
        keterangan: 'Gaji Bulanan',
      );

      final loaded = await PribadiSyncService.loadPribadiData(monthKey);
      expect(loaded.posDanaList.length, 1);
      expect(loaded.posDanaList.first.nama, 'Gaji Bulanan');
      // Saldo harus tepat 5.000.000 (BUKAN 10.000.000 / 2x lipat)
      expect(loaded.posDanaList.first.balance, 5000000);
      expect(loaded.totalDanaPribadi, 5000000);
      expect(loaded.totalPemasukan, 5000000);
      expect(loaded.transactions.length, 1);

      // 3. Quick Debit menambah saldo dengan benar
      await PribadiSyncService.recordPemasukanFromUangku(
        nama: 'Gaji Bulanan',
        nominal: 1000000,
        selectedMonth: testMonth,
        keterangan: 'Gaji Bulanan (Debit)',
      );

      final loadedAfterDebit = await PribadiSyncService.loadPribadiData(monthKey);
      expect(loadedAfterDebit.posDanaList.first.balance, 6000000);
      expect(loadedAfterDebit.totalDanaPribadi, 6000000);
      expect(loadedAfterDebit.totalPemasukan, 6000000);
      expect(loadedAfterDebit.transactions.length, 2);
    });

    test('Sanitasi otomatis memperbaiki saldo Pos Dana yang sebelumnya terduplikasi 2x', () async {
      final testMonth = DateTime(2026, 9, 1);
      final monthKey = PribadiSyncService.getMonthKey(null, testMonth);

      // Simpan Uangku
      final itemsUangku = [
        Uangku('Bonus', 2000000),
      ];
      await PribadiSyncService.saveUangkuList(monthKey, itemsUangku);

      // Simulasikan data lawas yang rusak dengan saldo 4.000.000 (2x lipat) dan 1 transaksi 2.000.000
      final corruptedData = PribadiData(
        posDanaList: [
          PosDana(id: 'pos_1', nama: 'Bonus', balance: 4000000),
        ],
        transactions: [
          PribadiTransaction(
            id: 'tx_1',
            title: 'Bonus',
            type: 'pemasukan',
            targetAccount: 'Bonus',
            amount: 2000000,
          ),
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pribadi_keuangan_data_$monthKey', jsonEncode(corruptedData.toJson()));

      // Saat loadPribadiData dipanggil, sanitasi otomatis memperbaiki saldo menjadi 2.000.000
      final repaired = await PribadiSyncService.loadPribadiData(monthKey);
      expect(repaired.posDanaList.first.balance, 2000000);
      expect(repaired.totalDanaPribadi, 2000000);
    });

    test('Hapus pos Uangku dan hapus seluruh transaksi di Keuangan Pribadi menghasilkan sisa dana tepat 0 (tidak ada residual)', () async {
      final testMonth = DateTime(2026, 9, 1);
      final monthKey = PribadiSyncService.getMonthKey(null, testMonth);

      // 1. Tambah pos di Uangku & catat pengeluaran di Keuangan Pribadi
      await PribadiSyncService.saveUangkuList(monthKey, [Uangku('Gaji', 5000000)]);
      await PribadiSyncService.recordPemasukanFromUangku(
        nama: 'Gaji',
        nominal: 5000000,
        selectedMonth: testMonth,
      );
      await PribadiSyncService.recordPengeluaranFromUangku(
        nama: 'Gaji',
        nominal: 500000,
        selectedMonth: testMonth,
        keterangan: 'Makan & Belanja',
      );

      // 2. Hapus Pos Dana di Uangku
      await PribadiSyncService.saveUangkuList(monthKey, []);
      await PribadiSyncService.syncHapusUangku(
        nama: 'Gaji',
        jumlah: 5000000,
        selectedMonth: testMonth,
      );

      // 3. Muat Keuangan Pribadi dan hapus sisa transaksi (bersihkan semua)
      final data = await PribadiSyncService.loadPribadiData(monthKey);
      data.transactions.clear();
      data.posDanaList.clear();
      data.rekeningPribadi.balance = 0;
      data.onHandDebit.balance = 0;
      data.onHandCash.balance = 0;
      await PribadiSyncService.savePribadiData(monthKey, data);

      // 4. Muat ulang dan pastikan total dana pribadi tepat Rp 0
      final finalData = await PribadiSyncService.loadPribadiData(monthKey);
      expect(finalData.posDanaList.isEmpty, true);
      expect(finalData.transactions.isEmpty, true);
      expect(finalData.totalPosDana, 0);
      expect(finalData.totalDanaPribadi, 0);
      expect(finalData.rekeningPribadi.balance, 0);
      expect(finalData.onHandDebit.balance, 0);
      expect(finalData.onHandCash.balance, 0);
    });

    test('Transaksi bayar tagihan tidak menggunakan awalan Bayar Tagihan dan data lama dibersihkan', () async {
      final jsonLegacy = {
        'id': 'tx_legacy',
        'title': 'Bayar Tagihan: Makan (BCA)',
        'type': 'pengeluaran',
        'sourceAccount': 'BCA',
        'amount': 50000,
        'note': 'Bayar Tagihan: Makan (BCA)',
      };

      final parsed = PribadiTransaction.fromJson(jsonLegacy);
      expect(parsed.title, 'Makan (BCA)');
      expect(parsed.note, 'Makan (BCA)');
    });

    test('Uangku Belum Cair tidak masuk ke Pos Dana Keuangan Pribadi (hanya mencatat dana real)', () async {
      final now = DateTime.now();
      final testMonth = DateTime(now.year, now.month, 1);
      final futureDate = DateTime(now.year, now.month, now.day + 10);
      final monthKey = PribadiSyncService.getMonthKey(null, testMonth);

      // Simpan item Uangku: 1 Cair (Gaji) dan 1 Belum Cair (Bonus Masa Depan)
      final itemsUangku = [
        Uangku('Gaji Kantor', 5000000), // Cair
        Uangku('Bonus Belum Cair', 3000000, tanggalCair: futureDate), // Belum Cair
      ];
      await PribadiSyncService.saveUangkuList(monthKey, itemsUangku);

      final loaded = await PribadiSyncService.loadPribadiData(monthKey);
      // Hanya 1 Pos Dana yang masuk (Gaji Kantor), Bonus Belum Cair TIDAK masuk
      expect(loaded.posDanaList.length, 1);
      expect(loaded.posDanaList.first.nama, 'Gaji Kantor');
      expect(loaded.posDanaList.first.balance, 5000000);
      expect(loaded.totalPosDana, 5000000);
      expect(loaded.totalDanaPribadi, 5000000);
    });

    test('Uangku Belum Cair dapat diedit dan dihapus tanpa nilainya kembali atau rusak', () async {
      final now = DateTime.now();
      final testMonth = DateTime(now.year, now.month, 1);
      final futureDate = DateTime(now.year, now.month, now.day + 10);
      final monthKey = PribadiSyncService.getMonthKey(null, testMonth);

      // 1. Simpan Uangku Belum Cair
      final initial = [
        Uangku('Proyek Belum Cair', 4000000, tanggalCair: futureDate),
      ];
      await PribadiSyncService.saveUangkuList(monthKey, initial);

      // 2. Edit nominal Uangku Belum Cair
      final updated = [
        Uangku('Proyek Belum Cair', 6000000, tanggalCair: futureDate),
      ];
      await PribadiSyncService.saveUangkuList(monthKey, updated);
      await PribadiSyncService.syncEditUangku(
        namaLama: 'Proyek Belum Cair',
        jumlahLama: 4000000,
        namaBaru: 'Proyek Belum Cair',
        jumlahBaru: 6000000,
        tanggalCairLama: futureDate,
        tanggalCairBaru: futureDate,
        selectedMonth: testMonth,
      );

      // Pastikan nominal di Uangku tetap 6.000.000 (tidak revert)
      var uList = await PribadiSyncService.loadUangkuList(monthKey);
      expect(uList.length, 1);
      expect(uList.first.jumlah, 6000000);

      // Dan di Keuangan Pribadi tetap kosong (karena belum cair)
      var loaded = await PribadiSyncService.loadPribadiData(monthKey);
      expect(loaded.posDanaList.isEmpty, true);

      // 3. Hapus Uangku Belum Cair
      await PribadiSyncService.saveUangkuList(monthKey, []);
      await PribadiSyncService.syncHapusUangku(
        nama: 'Proyek Belum Cair',
        jumlah: 6000000,
        tanggalCair: futureDate,
        selectedMonth: testMonth,
      );

      // Pastikan benar-benar terhapus
      uList = await PribadiSyncService.loadUangkuList(monthKey);
      expect(uList.isEmpty, true);
      loaded = await PribadiSyncService.loadPribadiData(monthKey);
      expect(loaded.posDanaList.isEmpty, true);
    });

    test('Uangku Belum Cair berubah menjadi Cair otomatis masuk ke Pos Dana & Transaksi Keuangan Pribadi', () async {
      final now = DateTime.now();
      final testMonth = DateTime(now.year, now.month, 1);
      final futureDate = DateTime(now.year, now.month, now.day + 10);
      final monthKey = PribadiSyncService.getMonthKey(null, testMonth);

      // 1. Awalnya belum cair
      final initial = [
        Uangku('Gaji Freelance', 2000000, tanggalCair: futureDate),
      ];
      await PribadiSyncService.saveUangkuList(monthKey, initial);
      var loaded = await PribadiSyncService.loadPribadiData(monthKey);
      expect(loaded.posDanaList.isEmpty, true);

      // 2. Diedit tanggal cair dihapus (menjadi cair)
      final cairList = [
        Uangku('Gaji Freelance', 2000000), // cair (tanggalCair = null)
      ];
      await PribadiSyncService.saveUangkuList(monthKey, cairList);
      await PribadiSyncService.syncEditUangku(
        namaLama: 'Gaji Freelance',
        jumlahLama: 2000000,
        namaBaru: 'Gaji Freelance',
        jumlahBaru: 2000000,
        tanggalCairLama: futureDate,
        tanggalCairBaru: null,
        selectedMonth: testMonth,
      );

      // Sekarang masuk ke Keuangan Pribadi
      loaded = await PribadiSyncService.loadPribadiData(monthKey);
      expect(loaded.posDanaList.length, 1);
      expect(loaded.posDanaList.first.nama, 'Gaji Freelance');
      expect(loaded.posDanaList.first.balance, 2000000);
      expect(loaded.transactions.length, 1);
      expect(loaded.transactions.first.amount, 2000000);
    });

    test('Pos Dana terintegrasi antar bulan: Hapus di satu bulan menghapus di bulan lain jika nominal 0, tetap ada jika nominal > 0', () async {
      final monthA = '2026_08';
      final monthB = '2026_09';
      final monthC = '2026_10';

      // Month A: Pos Dana "Dana Cadangan" = 0
      final dataA = PribadiData(
        posDanaList: [
          PosDana(id: 'pos_1', nama: 'Dana Cadangan', balance: 0),
          PosDana(id: 'pos_2', nama: 'BCA', balance: 1000000),
        ],
      );
      await PribadiSyncService.savePribadiData(monthA, dataA);
      await PribadiSyncService.saveUangkuList(monthA, [
        Uangku('Dana Cadangan', 0),
        Uangku('BCA', 1000000),
      ]);

      // Month B: Pos Dana "Dana Cadangan" = 0
      final dataB = PribadiData(
        posDanaList: [
          PosDana(id: 'pos_1', nama: 'Dana Cadangan', balance: 0),
          PosDana(id: 'pos_3', nama: 'Dompet', balance: 500000),
        ],
      );
      await PribadiSyncService.savePribadiData(monthB, dataB);
      await PribadiSyncService.saveUangkuList(monthB, [
        Uangku('Dana Cadangan', 0),
        Uangku('Dompet', 500000),
      ]);

      // Month C: Pos Dana "Dana Cadangan" = 750.000 (> 0)
      final dataC = PribadiData(
        posDanaList: [
          PosDana(id: 'pos_1', nama: 'Dana Cadangan', balance: 750000),
          PosDana(id: 'pos_4', nama: 'Tabungan', balance: 2000000),
        ],
      );
      await PribadiSyncService.savePribadiData(monthC, dataC);
      await PribadiSyncService.saveUangkuList(monthC, [
        Uangku('Dana Cadangan', 750000),
        Uangku('Tabungan', 2000000),
      ]);

      // Hapus Pos Dana "Dana Cadangan" dari Month A
      await PribadiSyncService.deletePosDanaAcrossAllMonths('Dana Cadangan');

      // Verifikasi Month A: "Dana Cadangan" hilang, "BCA" tetap ada
      final loadedA = await PribadiSyncService.loadPribadiData(monthA);
      expect(loadedA.posDanaList.any((p) => p.nama == 'Dana Cadangan'), isFalse);
      expect(loadedA.posDanaList.any((p) => p.nama == 'BCA'), isTrue);

      // Verifikasi Month B: "Dana Cadangan" juga ikut hilang (karena nominalnya 0)!
      final loadedB = await PribadiSyncService.loadPribadiData(monthB);
      expect(loadedB.posDanaList.any((p) => p.nama == 'Dana Cadangan'), isFalse);
      expect(loadedB.posDanaList.any((p) => p.nama == 'Dompet'), isTrue);

      // Verifikasi Month C: "Dana Cadangan" TETAP ADA (karena nominalnya 750.000 > 0)!
      final loadedC = await PribadiSyncService.loadPribadiData(monthC);
      expect(loadedC.posDanaList.any((p) => p.nama == 'Dana Cadangan'), isTrue);
      expect(loadedC.posDanaList.firstWhere((p) => p.nama == 'Dana Cadangan').balance, 750000);
      expect(loadedC.posDanaList.any((p) => p.nama == 'Tabungan'), isTrue);
    });

    test('Quick Debit pada Pos Dana yang belum memiliki transaksi langsung bertambah pada input pertama (tidak perlu 2x)', () async {
      final now = DateTime.now();
      final testMonth = DateTime(now.year, now.month, 1);
      final monthKey = PribadiSyncService.getMonthKey(null, testMonth);

      // Pos Dana dibuat dari template/Uangku tanpa transaksi riwayat
      final initialData = PribadiData(
        posDanaList: [
          PosDana(id: 'pos_kas', nama: 'Kas Tunai', balance: 1000000),
        ],
        transactions: [], // Belum ada transaksi sebelumnya
      );
      await PribadiSyncService.savePribadiData(monthKey, initialData);
      await PribadiSyncService.saveUangkuList(monthKey, [
        Uangku('Kas Tunai', 1000000),
      ]);

      // Lakukan Quick Debit Rp 500.000 (input pertama kali)
      await PribadiSyncService.recordPemasukanFromUangku(
        nama: 'Kas Tunai',
        nominal: 500000,
        selectedMonth: testMonth,
        keterangan: 'Kas Tunai (Debit)',
        isInitialCreation: false,
      );

      // Verifikasi langsung bertambah menjadi 1.500.000 pada input pertama
      final loaded = await PribadiSyncService.loadPribadiData(monthKey);
      expect(loaded.posDanaList.first.balance, 1500000);
      expect(loaded.totalDanaPribadi, 1500000);
      expect(loaded.transactions.length, 1);
      expect(loaded.transactions.first.amount, 500000);

      // Verifikasi Uangku juga tersinkron ke 1.500.000
      final uList = await PribadiSyncService.loadUangkuList(monthKey);
      expect(uList.first.jumlah, 1500000);
    });
  });
}
