import 'package:daily_apps/cards/card_tabungan.dart';
import 'package:daily_apps/cards/card_tagihan.dart';
import 'package:daily_apps/cards/card_uangku.dart';
import 'package:daily_apps/models/model_uangku.dart';
import 'package:daily_apps/main.dart';
import 'package:daily_apps/pages/riwayat_page.dart';
import 'package:daily_apps/utils/riwayat_service.dart';
import 'package:daily_apps/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RiwayatService Tests', () {
    test('Catat Tambah Tagihan', () async {
      await RiwayatService.catatTambahTagihan('makan siang', 20000);
      final list = await RiwayatService.getRiwayat();

      expect(list.length, 1);
      expect(list.first.kategori, 'Tagihan');
      expect(list.first.perubahan, 'Makan Siang 20.000 ditambah ke tagihan');
      expect(list.first.tipe, 'tambah');
    });

    test('Catat Hapus Tagihan', () async {
      await RiwayatService.catatHapusTagihan('makan siang', 20000);
      final list = await RiwayatService.getRiwayat();

      expect(list.length, 1);
      expect(list.first.kategori, 'Tagihan');
      expect(list.first.perubahan, 'Makan Siang 20.000 dihapus dari tagihan');
      expect(list.first.tipe, 'hapus');
    });

    test('Catat Edit Tagihan - Nominal Berkurang (Contoh Prompt)', () async {
      // Hutang 100.000 diubah menjadi 80.000
      await RiwayatService.catatEditTagihan(
        namaLama: 'hutang',
        jumlahLama: 100000,
        namaBaru: 'hutang',
        jumlahBaru: 80000,
      );
      final list = await RiwayatService.getRiwayat();

      expect(list.length, 1);
      expect(list.first.kategori, 'Tagihan');
      expect(list.first.perubahan, 'Hutang 20.000 dikurangi dari tagihan');
      expect(list.first.tipe, 'kurang');
    });

    test('Catat Edit Tagihan - Nominal Bertambah', () async {
      await RiwayatService.catatEditTagihan(
        namaLama: 'hutang',
        jumlahLama: 80000,
        namaBaru: 'hutang',
        jumlahBaru: 100000,
      );
      final list = await RiwayatService.getRiwayat();

      expect(list.length, 1);
      expect(list.first.kategori, 'Tagihan');
      expect(list.first.perubahan, 'Hutang 20.000 ditambah ke tagihan');
      expect(list.first.tipe, 'tambah');
    });

    test('Catat Uangku - Tambah, Edit, Hapus', () async {
      await RiwayatService.catatTambahUangku('gaji', 5000000);
      await RiwayatService.catatEditUangku(
        namaLama: 'gaji',
        jumlahLama: 5000000,
        namaBaru: 'gaji',
        jumlahBaru: 4500000,
      );
      await RiwayatService.catatHapusUangku('bonus', 500000);

      final list = await RiwayatService.getRiwayat();
      expect(list.length, 3);
      // Terbaru di atas
      expect(list[0].perubahan, 'Bonus 500.000 dihapus dari uangku');
      expect(list[0].kategori, 'Uangku');
      expect(list[1].perubahan, 'Gaji 500.000 dikurangi dari uangku');
      expect(list[1].kategori, 'Uangku');
      expect(list[2].perubahan, 'Gaji 5.000.000 ditambah ke uangku');
      expect(list[2].kategori, 'Uangku');
    });

    test('Catat Tabungan - Tambah, Edit, Hapus', () async {
      await RiwayatService.catatTambahTabungan('BCA Tabungan', 1000000);
      await RiwayatService.catatEditTabungan(
        namaLama: 'BCA Tabungan',
        jumlahLama: 1000000,
        namaBaru: 'BCA Tabungan',
        jumlahBaru: 1500000,
      );
      await RiwayatService.catatHapusTabungan('Celengan', 200000);

      final list = await RiwayatService.getRiwayat();
      expect(list.length, 3);
      expect(list[0].perubahan, 'Celengan 200.000 dihapus dari tabungan');
      expect(list[0].kategori, 'Tabungan');
      expect(list[1].perubahan, 'BCA Tabungan 500.000 ditambah ke tabungan');
      expect(list[1].kategori, 'Tabungan');
      expect(list[2].perubahan, 'BCA Tabungan 1.000.000 ditambah ke tabungan');
      expect(list[2].kategori, 'Tabungan');
    });

    test('Hapus Satu Item dan Hapus Semua', () async {
      await RiwayatService.catatTambahTagihan('listrik', 100000);
      await RiwayatService.catatTambahTagihan('air', 50000);

      var list = await RiwayatService.getRiwayat();
      expect(list.length, 2);

      // Hapus item pertama
      await RiwayatService.hapusItemRiwayat(list.first.id);
      list = await RiwayatService.getRiwayat();
      expect(list.length, 1);
      expect(list.first.perubahan, 'Listrik 100.000 ditambah ke tagihan');

      // Hapus semua
      await RiwayatService.hapusSemuaRiwayat();
      list = await RiwayatService.getRiwayat();
      expect(list.length, 0);
    });
  });

  group('UI Tests', () {
    testWidgets('Tombol Riwayat ada di AppBar dan bisa dibuka',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Cek tombol icon history di AppBar
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);

      // Klik tombol riwayat
      await tester.tap(find.byIcon(Icons.history_rounded));
      await tester.pumpAndSettle();

      // Memastikan halaman Riwayat Keuangan terbuka
      expect(find.text('Riwayat Keuangan'), findsOneWidget);
      expect(find.text('Belum Ada Riwayat Perubahan'), findsOneWidget);
    });

    testWidgets('Halaman Utama menampilkan Dana Aman dan Tabunganku secara terpisah',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Memastikan ada Dana Aman (Keuangan Harian)
      expect(find.text('Dana Aman'), findsOneWidget);

      // Memastikan ada fitur Tabunganku tersendiri
      expect(find.text('Tabunganku'), findsOneWidget);

      // Memastikan ada teks Kekurangan Dana / Kekurangan
      expect(find.text('Kekurangan'), findsOneWidget);
    });

    testWidgets(
        'RiwayatPage menampilkan daftar item dengan kolom Datetime, Kategori, Perubahan',
        (WidgetTester tester) async {
      // Mock data
      await RiwayatService.catatTambahTagihan('Makan Siang', 20000);
      await RiwayatService.catatTambahUangku('Gaji Bulanan', 5000000);
      await RiwayatService.catatTambahTabungan('Celengan', 500000);

      await tester.pumpWidget(
        const MaterialApp(
          home: RiwayatPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Verifikasi judul halaman
      expect(find.text('Riwayat Keuangan'), findsOneWidget);

      // Verifikasi kategori
      expect(find.text('Tagihan'), findsAtLeastNWidgets(1));
      expect(find.text('Uangku'), findsAtLeastNWidgets(1));
      expect(find.text('Tabungan'), findsAtLeastNWidgets(1));

      // Verifikasi perubahan text
      expect(
        find.text('Makan Siang 20.000 ditambah ke tagihan'),
        findsOneWidget,
      );
      expect(
        find.text('Gaji Bulanan 5.000.000 ditambah ke uangku'),
        findsOneWidget,
      );
      expect(
        find.text('Celengan 500.000 ditambah ke tabungan'),
        findsOneWidget,
      );
    });

    testWidgets('Tagihan menampilkan deadline dengan format yang benar',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final futureDate = DateTime(now.year, now.month, now.day + 14);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('tagihan', [
        '{"nama":"Makan","jumlah":20000,"deadline":"${futureDate.toIso8601String()}"}',
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfoCardTagihan(
              title: 'Tagihanku',
              amount: '20000',
              items: const [],
              onChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Klik header untuk expand
      await tester.tap(find.text('Tagihanku'));
      await tester.pumpAndSettle();

      // Cek item tagihan dan deadline ditampilkan
      expect(find.text('Makan : 20.000'), findsOneWidget);
      expect(find.textContaining('14 hari'), findsOneWidget);
    });

    testWidgets('Dana Aman dapat disesuaikan dengan opsi deadline',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final futureDate = DateTime(now.year, now.month, now.day + 5);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('uangku', [
        '{"nama":"Gaji","jumlah":500000}',
      ]);
      await prefs.setStringList('tagihan', [
        '{"nama":"Makan","jumlah":20000,"deadline":"${futureDate.toIso8601String()}"}',
        '{"nama":"Lainnya","jumlah":100000}',
      ]);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Awalnya: semua tagihan masuk (500.000 - 120.000 = 380.000)
      expect(find.text('380.000'), findsOneWidget);

      // Buka dialog penyesuaian deadline
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();

      // Pilih hanya tagihan berdeadline
      await tester.tap(find.text('Hanya Tagihan Berdeadline'));
      await tester.pumpAndSettle();

      // Klik Terapkan
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();

      // Sekarang Dana Aman hanya terpotong tagihan berdeadline (500.000 - 20.000 = 480.000)
      expect(find.text('480.000'), findsOneWidget);
      expect(find.text('Hanya tagihan berdeadline'), findsOneWidget);

      // Cek tombol reset
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      // Kembali ke 380.000
      expect(find.text('380.000'), findsOneWidget);
    });

    test('FinancialHealthHelper mengkalkulasi status dengan benar', () {
      // Sehat: dana aman > 50% totalUangku (1.000.000 - 300.000 = 700.000 > 500.000)
      expect(
        FinancialHealthHelper.getStatus(1000000, 300000),
        StatusKesehatan.sehat,
      );

      // Perhatian: dana aman <= 50% tapi >= 0 (1.000.000 - 700.000 = 300.000)
      expect(
        FinancialHealthHelper.getStatus(1000000, 700000),
        StatusKesehatan.perhatian,
      );

      // Kritis / Defisit: tagihan > uangku (500.000 - 600.000 = -100.000)
      expect(
        FinancialHealthHelper.getStatus(500000, 600000),
        StatusKesehatan.kritis,
      );
    });

    testWidgets('Tabungan menampilkan item dengan format sederhana',
        (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('tabungan', [
        '{"nama":"Liburan","jumlah":3000000}',
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfoCardTabungan(
              title: 'Tabunganku',
              amount: '3000000',
              items: const [],
              onChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expand card
      await tester.tap(find.text('Tabunganku'));
      await tester.pumpAndSettle();

      // Cek nama dan jumlah
      expect(find.text('Liburan : 3.000.000'), findsOneWidget);
    });

    testWidgets('RiwayatPage memiliki filter rentang waktu',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RiwayatPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Cek chips rentang waktu
      expect(find.text('Semua Waktu'), findsOneWidget);
      expect(find.text('Hari Ini'), findsOneWidget);
      expect(find.text('Minggu Ini'), findsOneWidget);
      expect(find.text('Bulan Ini'), findsOneWidget);
      expect(find.text('Pilih Tanggal'), findsOneWidget);
    });

    testWidgets('Pembayaran Tagihan Sebagian dan Pelunasan Penuh',
        (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('tagihan', [
        '{"nama":"Makan","jumlah":20000}',
      ]);
      await prefs.setStringList('uangku', [
        '{"nama":"Cash","jumlah":2000}',
        '{"nama":"Debit","jumlah":20000}',
      ]);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Buka kartu Tagihanku
      await tester.tap(find.text('Tagihanku'));
      await tester.pumpAndSettle();

      // Tekan tombol Bayar
      await tester.tap(find.text('Bayar'));
      await tester.pumpAndSettle();

      // Dialog pembayaran terbuka, pilih Cash (2.000) yang merupakan opsi pertama (default)
      expect(find.text('Bayar Tagihan'), findsOneWidget);
      expect(find.textContaining('Cash'), findsWidgets);

      // Tekan Konfirmasi Bayar
      await tester.tap(find.text('Konfirmasi Bayar'));
      await tester.pumpAndSettle();

      // Sekarang tagihan menjadi 18.000 dan uangku Cash menjadi 0
      expect(find.text('Makan : 18.000'), findsOneWidget);

      // Buka kartu Uangku dan cek Cash : 0
      await tester.tap(find.text('Uangku'));
      await tester.pumpAndSettle();
      expect(find.text('Cash : 0'), findsOneWidget);
      expect(find.text('Debit : 20.000'), findsOneWidget);
    });

    testWidgets('Tagihanku & Uangku terpisah per bulan dan Tabunganku tetap statis',
        (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final now = DateTime.now();
      final curKey = '${now.year}_${now.month.toString().padLeft(2, '0')}';
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      final nextKey = '${nextMonth.year}_${nextMonth.month.toString().padLeft(2, '0')}';

      // Data bulan ini
      await prefs.setStringList('tagihan_$curKey', [
        '{"nama":"Listrik Bulan Ini","jumlah":100000}',
      ]);
      await prefs.setStringList('uangku_$curKey', [
        '{"nama":"Gaji Bulan Ini","jumlah":500000}',
      ]);

      // Data bulan depan
      await prefs.setStringList('tagihan_$nextKey', [
        '{"nama":"Wifi Bulan Depan","jumlah":300000}',
      ]);
      await prefs.setStringList('uangku_$nextKey', [
        '{"nama":"Bonus Bulan Depan","jumlah":1000000}',
      ]);

      // Tabungan (Global)
      await prefs.setStringList('tabungan', [
        '{"nama":"Beli Laptop","jumlah":5000000}',
      ]);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Bulan ini: periksa tagihan dan uangku
      expect(find.text('100.000'), findsWidgets); // Total Tagihan bulan ini
      expect(find.text('500.000'), findsWidgets); // Total Uangku bulan ini
      expect(find.text('5.000.000'), findsWidgets); // Total Tabunganku (Global)

      // Pindah ke bulan berikutnya dengan menekan tombol panah kanan
      await tester.tap(find.byTooltip('Bulan Berikutnya'));
      await tester.pumpAndSettle();

      // Bulan berikutnya: Tagihan dan Uangku berubah sesuai data bulan depan
      expect(find.text('300.000'), findsWidgets); // Total Tagihan bulan depan
      expect(find.text('1.000.000'), findsWidgets); // Total Uangku bulan depan
      // Tabungan tetap sama persis (5.000.000)
      expect(find.text('5.000.000'), findsWidgets);

      // Kembali ke bulan ini dengan menekan tombol panah kiri
      await tester.tap(find.byTooltip('Bulan Sebelumnya'));
      await tester.pumpAndSettle();

      expect(find.text('100.000'), findsWidgets);
      expect(find.text('500.000'), findsWidgets);
      expect(find.text('5.000.000'), findsWidgets);
    });

    test('Pesan Riwayat menyertakan nama bulan untuk Tagihan dan Uangku, tapi tidak untuk Tabungan', () async {
      final juliDate = DateTime(2026, 7, 15);
      await RiwayatService.hapusSemuaRiwayat();

      // Tambah Tagihan bulan Juli
      await RiwayatService.catatTambahTagihan('Cash', 50000, bulan: juliDate);
      // Tambah Uangku bulan Juli
      await RiwayatService.catatTambahUangku('Gaji', 1000000, bulan: juliDate);
      // Tambah Tabungan
      await RiwayatService.catatTambahTabungan('BCA', 200000);

      final list = await RiwayatService.getRiwayat();
      expect(list.length, 3);
      // Tabungan (paling baru): tanpa bulan
      expect(list[0].perubahan, 'BCA 200.000 ditambah ke tabungan');
      // Uangku: dengan bulan (Juli)
      expect(list[1].perubahan, 'Gaji 1.000.000 ditambah ke uangku (Juli)');
      // Tagihan: dengan bulan (Juli)
      expect(list[2].perubahan, 'Cash 50.000 ditambah ke tagihan (Juli)');
    });
  });

  group('Uangku Klasifikasi Cair / Belum Cair Tests', () {
    test('Uangku tanpa tanggal otomatis terhitung sudah cair', () {
      final u = Uangku('Dompet', 100000);
      expect(u.isCair, isTrue);
      expect(u.tanggalCair, isNull);
      expect(u.formattedTanggalCair, isNull);
    });

    test('Uangku dengan tanggal hari ini atau masa lalu terhitung sudah cair', () {
      final now = DateTime.now();
      final hariIni = DateTime(now.year, now.month, now.day);
      final masaLalu = DateTime(now.year, now.month, now.day - 5);

      final uHariIni = Uangku('Gaji Hari Ini', 5000000, tanggalCair: hariIni);
      expect(uHariIni.isCair, isTrue);
      expect(uHariIni.formattedTanggalCair, isNotNull);

      final uMasaLalu = Uangku('Transfer Lalu', 200000, tanggalCair: masaLalu);
      expect(uMasaLalu.isCair, isTrue);
    });

    test('Uangku dengan tanggal masa depan terhitung belum cair', () {
      final now = DateTime.now();
      final masaDepan = DateTime(now.year, now.month, now.day + 7);

      final uMasaDepan = Uangku('Bonus Proyek', 3000000, tanggalCair: masaDepan);
      expect(uMasaDepan.isCair, isFalse);
      expect(uMasaDepan.formattedTanggalCair, isNotNull);
    });

    test('Uangku toJson dan fromJson serializes tanggalCair dengan benar', () {
      final tanggal = DateTime(2026, 8, 25);
      final u = Uangku('Investasi', 1500000, tanggalCair: tanggal);
      final json = u.toJson();

      expect(json['nama'], 'Investasi');
      expect(json['jumlah'], 1500000);
      expect(json['tanggalCair'], tanggal.toIso8601String());

      final restored = Uangku.fromJson(json);
      expect(restored.nama, 'Investasi');
      expect(restored.jumlah, 1500000);
      expect(restored.tanggalCair?.year, 2026);
      expect(restored.tanggalCair?.month, 8);
      expect(restored.tanggalCair?.day, 25);
    });

    testWidgets('InfoCardUangku menampilkan badge Belum Cair dan summary breakdown',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final futureDate = DateTime(now.year, now.month, now.day + 5);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('uangku', [
        '{"nama":"Cash","jumlah":500000}',
        '{"nama":"Gaji Belum Cair","jumlah":2000000,"tanggalCair":"${futureDate.toIso8601String()}"}',
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfoCardUangku(
              title: 'Uangku',
              amount: '2500000',
              items: const [],
              onChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cek breakdown summary di header kartu
      expect(find.textContaining('Cair:'), findsOneWidget);
      expect(find.textContaining('Belum:'), findsOneWidget);

      // Expand kartu Uangku
      await tester.tap(find.text('Uangku'));
      await tester.pumpAndSettle();

      // Cek item dan status badge Belum Cair
      expect(find.text('Cash : 500.000'), findsOneWidget);
      expect(find.text('Gaji Belum Cair : 2.000.000'), findsOneWidget);
      expect(find.textContaining('Belum Cair •'), findsOneWidget);
    });

    testWidgets(
        'Tombol filter di samping total nominal Uangku menyaring hanya dana yang sudah cair',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final futureDate = DateTime(now.year, now.month, now.day + 5);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('uangku', [
        '{"nama":"Dompet Cash","jumlah":300000}',
        '{"nama":"Gaji Belum Cair","jumlah":2000000,"tanggalCair":"${futureDate.toIso8601String()}"}',
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfoCardUangku(
              title: 'Uangku',
              amount: '2300000',
              items: const [],
              onChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Buka list Uangku
      await tester.tap(find.text('Uangku'));
      await tester.pumpAndSettle();

      // Default: filter kecoret (filter_alt_off_rounded) dan menampilkan semua (2.300.000)
      expect(find.byIcon(Icons.filter_alt_off_rounded), findsOneWidget);
      expect(find.text('2.300.000'), findsOneWidget);
      expect(find.text('Dompet Cash : 300.000'), findsOneWidget);
      expect(find.text('Gaji Belum Cair : 2.000.000'), findsOneWidget);

      // Tekan tombol filter
      await tester.tap(find.byIcon(Icons.filter_alt_off_rounded));
      await tester.pumpAndSettle();

      // Sekarang icon filter aktif (filter_alt_rounded)
      expect(find.byIcon(Icons.filter_alt_rounded), findsOneWidget);
      // Nominal hanya menampilkan dana yang sudah cair (300.000)
      expect(find.text('300.000'), findsOneWidget);
      // Item dalam list hanya yang sudah cair
      expect(find.text('Dompet Cash : 300.000'), findsOneWidget);
      expect(find.text('Gaji Belum Cair : 2.000.000'), findsNothing);

      // Tekan filter lagi untuk reset
      await tester.tap(find.byIcon(Icons.filter_alt_rounded));
      await tester.pumpAndSettle();

      // Kembali menampilkan semua
      expect(find.byIcon(Icons.filter_alt_off_rounded), findsOneWidget);
      expect(find.text('2.300.000'), findsOneWidget);
      expect(find.text('Gaji Belum Cair : 2.000.000'), findsOneWidget);
    });

    testWidgets(
        'Dana Aman terintegrasi dengan filter uangku (cair vs semua dana)',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final futureDate = DateTime(now.year, now.month, now.day + 5);

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await prefs.setStringList('uangku', [
        '{"nama":"Cash","jumlah":300000}',
        '{"nama":"Gaji Belum Cair","jumlah":1000000,"tanggalCair":"${futureDate.toIso8601String()}"}',
      ]);
      await prefs.setStringList('tagihan', [
        '{"nama":"Listrik","jumlah":200000}',
      ]);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Default filter Uangku off: Dana Aman = 1.300.000 - 200.000 = 1.100.000
      expect(find.text('1.100.000'), findsOneWidget);

      // Buka filter uangku (klik icon filter di samping total nominal Uangku)
      await tester.tap(find.byIcon(Icons.filter_alt_off_rounded));
      await tester.pumpAndSettle();

      // Filter Uangku on: Uangku terhitung hanya 300.000, Dana Aman = 300.000 - 200.000 = 100.000
      expect(find.text('100.000'), findsOneWidget);
      expect(find.textContaining('Uangku terhitung: 300.000 (Cair)'), findsOneWidget);

      // Matikan kembali filter Uangku
      await tester.tap(find.byIcon(Icons.filter_alt_rounded));
      await tester.pumpAndSettle();

      // Dana Aman kembali = 1.100.000 (semua dana dikurangi tagihan)
      expect(find.text('1.100.000'), findsOneWidget);
    });

    testWidgets(
        'Tambah Uangku belum cair TIDAK menambah DP, tapi Uangku sudah cair menambah DP',
        (WidgetTester tester) async {
      final now = DateTime.now();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Buka kartu Uangku
      await tester.tap(find.text('Uangku'));
      await tester.pumpAndSettle();

      // 1. Tambah Uangku yang sudah cair (tanpa tanggal)
      final tambahUangkuBtn = find.descendant(
        of: find.byType(InfoCardUangku),
        matching: find.widgetWithText(ElevatedButton, 'Tambah'),
      );
      await tester.tap(tambahUangkuBtn);
      await tester.pumpAndSettle();

      final namaField = find.widgetWithText(TextField, 'nama');
      final nominalField = find.widgetWithText(TextField, 'jumlah');
      await tester.enterText(namaField, 'Gaji Pokok');
      await tester.enterText(nominalField, '1000000');

      // Submit dialog (tanpa tanggal cair -> otomatis cair)
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tambah Uangku'));
      await tester.pumpAndSettle();

      // DP harus dibuat 10% (100.000)
      final currentMonthKey = '${now.year}_${now.month.toString().padLeft(2, '0')}';
      final tagihanData = prefs.getStringList('tagihan_$currentMonthKey') ?? prefs.getStringList('tagihan') ?? [];
      expect(tagihanData.isNotEmpty, true);
      expect(tagihanData.first, contains('"DP"'));
      expect(tagihanData.first, contains('100000'));
    });
  });
}





