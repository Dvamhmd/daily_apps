import 'package:daily_apps/cards/card_tabungan.dart';
import 'package:daily_apps/cards/card_tagihan.dart';
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
      expect(find.text('Dana Aman :'), findsOneWidget);

      // Memastikan ada fitur Tabunganku tersendiri
      expect(find.text('Tabunganku'), findsOneWidget);

      // Memastikan ada teks Kekurangan Dana
      expect(find.text('Kekurangan Dana'), findsOneWidget);
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
      await tester.tap(find.text('Sesuaikan'));
      await tester.pumpAndSettle();

      // Pilih hanya tagihan berdeadline
      await tester.tap(find.text('Hanya Tagihan Berdeadline'));
      await tester.pumpAndSettle();

      // Klik Terapkan
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();

      // Sekarang Dana Aman hanya terpotong tagihan berdeadline (500.000 - 20.000 = 480.000)
      expect(find.text('480.000'), findsOneWidget);
      expect(find.text('Tagihan terhitung: 20.000 (1 tagihan)'), findsOneWidget);

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

    testWidgets('Tabungan menampilkan target nominal dan progress bar',
        (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('tabungan', [
        '{"nama":"Liburan","jumlah":3000000,"targetNominal":5000000}',
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

      // Cek nama, jumlah, persentase 60%, dan target nominal
      expect(find.text('Liburan : 3.000.000'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('Target: 5.000.000'), findsOneWidget);
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
  });
}



