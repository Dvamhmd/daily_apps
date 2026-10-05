import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_apps/models/model_pribadi.dart';
import 'package:daily_apps/models/model_uangku.dart';
import 'package:daily_apps/pages/pribadi_page.dart';
import 'package:daily_apps/utils/pribadi_sync_service.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Alokasi Dana Antar Pos Tests', () {
    test('Alokasi dana antar pos memindahkan saldo tanpa mencatat transaksi dan tanpa mengubah total pemasukan/pengeluaran', () async {
      final now = DateTime.now();
      final monthKey = '${now.year}_${now.month.toString().padLeft(2, '0')}';

      // Setup 2 Pos Dana
      final posA = PosDana(
        id: 'pos_1',
        nama: 'Gaji Bulanan',
        balance: 5000000,
        deskripsi: 'Gaji utama',
      );
      final posB = PosDana(
        id: 'pos_2',
        nama: 'Tabungan',
        balance: 1000000,
        deskripsi: 'Wadah tabungan',
      );

      final data = PribadiData(
        posDanaList: [posA, posB],
        rekeningPribadi: RekeningPribadi(balance: 6000000),
      );

      await PribadiSyncService.savePribadiData(monthKey, data);
      await PribadiSyncService.saveUangkuList(monthKey, [
        Uangku('Gaji Bulanan', 5000000),
        Uangku('Tabungan', 1000000),
      ]);

      // Alokasikan Rp 2.000.000 dari Pos A (Gaji) ke Pos B (Tabungan)
      final alokasiNominal = 2000000;
      posA.balance -= alokasiNominal;
      posB.balance += alokasiNominal;

      // Simpan perubahan Pos Dana dan sinkronkan ke Uangku
      await PribadiSyncService.savePribadiData(monthKey, data);
      await PribadiSyncService.syncEditPosDanaToUangku(
        monthKey: monthKey,
        namaLama: posA.nama,
        namaBaru: posA.nama,
        saldoBaru: posA.balance,
      );
      await PribadiSyncService.syncEditPosDanaToUangku(
        monthKey: monthKey,
        namaLama: posB.nama,
        namaBaru: posB.nama,
        saldoBaru: posB.balance,
      );

      // Verifikasi data yang tersimpan
      final reloadedData = await PribadiSyncService.loadPribadiData(monthKey);
      final reloadedUangku = await PribadiSyncService.loadUangkuList(monthKey);

      // 1. Saldo Pos A berkurang menjadi 3.000.000
      expect(reloadedData.posDanaList.firstWhere((p) => p.id == 'pos_1').balance, 3000000);
      // 2. Saldo Pos B bertambah menjadi 3.000.000
      expect(reloadedData.posDanaList.firstWhere((p) => p.id == 'pos_2').balance, 3000000);

      // 3. Total pemasukan dan pengeluaran tetap 0 (tidak terpengaruh)
      expect(reloadedData.totalPemasukan, 0);
      expect(reloadedData.totalPengeluaran, 0);

      // 4. Tidak ada transaksi yang dicatat di daftar transaksi
      expect(reloadedData.transactions.isEmpty, isTrue);

      // 5. Saldo Uangku tersinkronisasi tepat
      expect(reloadedUangku.firstWhere((u) => u.nama == 'Gaji Bulanan').jumlah, 3000000);
      expect(reloadedUangku.firstWhere((u) => u.nama == 'Tabungan').jumlah, 3000000);
    });

    testWidgets('UI: Edit Pos Dana menampilkan section Alokasi Dana Antar Pos dan dapat melakukan pemindahan dana', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final monthKey = '${now.year}_${now.month.toString().padLeft(2, '0')}';

      final posA = PosDana(
        id: 'pos_1',
        nama: 'Gaji',
        balance: 5000000,
      );
      final posB = PosDana(
        id: 'pos_2',
        nama: 'Dana Darurat',
        balance: 1000000,
      );

      final data = PribadiData(
        posDanaList: [posA, posB],
      );

      await PribadiSyncService.savePribadiData(monthKey, data);
      await PribadiSyncService.saveUangkuList(monthKey, [
        Uangku('Gaji', 5000000),
        Uangku('Dana Darurat', 1000000),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PribadiPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Buka modal Kelola Pos Dana dari card wadah dana
      final kelolaButton = find.byIcon(Icons.folder_special_rounded);
      if (kelolaButton.evaluate().isNotEmpty) {
        await tester.tap(kelolaButton.first);
        await tester.pumpAndSettle();
      }

      // Cari icon edit pada pos dana
      final editIcon = find.byIcon(Icons.edit_outlined);
      expect(editIcon, findsWidgets);

      // Tap edit pada pos dana pertama (Gaji)
      await tester.tap(editIcon.first);
      await tester.pumpAndSettle();

      // Dialog Edit Pos Dana terbuka dan menampilkan title & section Alokasi Dana Antar Pos
      expect(find.text('Edit Pos Dana'), findsOneWidget);
      expect(find.text('Alokasi Dana Antar Pos'), findsOneWidget);
      expect(find.text('Kirim ke Pos Lain'), findsOneWidget);
      expect(find.text('Tarik dari Pos Lain'), findsOneWidget);
      expect(find.text('Alokasikan Dana Sekarang'), findsOneWidget);

      // Masukkan nominal alokasi Rp 1.500.000 pada alokasiNominalCtrl
      final nominalField = find.widgetWithText(TextField, '0');
      expect(nominalField, findsWidgets);
      await tester.ensureVisible(nominalField.first);
      await tester.enterText(nominalField.first, '1500000');
      await tester.pumpAndSettle();

      // Tap tombol Alokasikan Dana Sekarang
      final alokasiButton = find.widgetWithText(ElevatedButton, 'Alokasikan Dana Sekarang');
      expect(alokasiButton, findsOneWidget);
      await tester.ensureVisible(alokasiButton);
      await tester.tap(alokasiButton);
      await tester.pumpAndSettle();

      // Saldo Pos Dana Gaji terupdate menjadi 3.500.000 dan Dana Darurat menjadi 2.500.000
      final reloaded = await PribadiSyncService.loadPribadiData(monthKey);
      expect(reloaded.posDanaList.firstWhere((p) => p.nama == 'Gaji').balance, 3500000);
      expect(reloaded.posDanaList.firstWhere((p) => p.nama == 'Dana Darurat').balance, 2500000);

      // Transaksi tetap 0
      expect(reloaded.transactions.isEmpty, isTrue);
      expect(reloaded.totalPemasukan, 0);
      expect(reloaded.totalPengeluaran, 0);
    });

    testWidgets('UI: Alokasi Saldo langsung mengupdate tampilan popup Kelola Pos Dana realtime', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final monthKey = '${now.year}_${now.month.toString().padLeft(2, '0')}';

      final posA = PosDana(
        id: 'pos_1',
        nama: 'Gaji',
        balance: 5000000,
      );
      final posB = PosDana(
        id: 'pos_2',
        nama: 'Tabungan',
        balance: 1000000,
      );

      final data = PribadiData(
        posDanaList: [posA, posB],
      );

      await PribadiSyncService.savePribadiData(monthKey, data);
      await PribadiSyncService.saveUangkuList(monthKey, [
        Uangku('Gaji', 5000000),
        Uangku('Tabungan', 1000000),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PribadiPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Buka modal Kelola Pos Dana
      final cardPosDana = find.text('Pos Dana');
      expect(cardPosDana, findsWidgets);
      await tester.tap(cardPosDana.first);
      await tester.pumpAndSettle();

      // Pastikan saldo awal terlihat di modal: Rp 5.000.000 dan Rp 1.000.000
      expect(find.text('Rp 5.000.000'), findsWidgets);
      expect(find.text('Rp 1.000.000'), findsWidgets);

      // Tap icon swap (Pindah Saldo Antar Pos) di header modal
      final swapHeaderIcon = find.byTooltip('Pindah Saldo Antar Pos');
      expect(swapHeaderIcon, findsOneWidget);
      await tester.tap(swapHeaderIcon);
      await tester.pumpAndSettle();

      // Dialog / modal alokasi terbuka
      expect(find.text('Alokasi & Pindah Saldo Antar Pos'), findsOneWidget);

      // Masukkan nominal alokasi Rp 2.000.000
      final nominalField = find.widgetWithText(TextField, '0');
      expect(nominalField, findsWidgets);
      await tester.enterText(nominalField.first, '2000000');
      await tester.pumpAndSettle();

      // Tekan tombol Proses Alokasi Saldo
      final prosesButton = find.widgetWithText(ElevatedButton, 'Proses Alokasi Saldo');
      expect(prosesButton, findsOneWidget);
      await tester.tap(prosesButton);
      await tester.pumpAndSettle();

      // Modal Kelola Pos Dana masih terbuka, dan saldonya LANGSUNG TERUPDATE menjadi Rp 3.000.000 untuk keduanya
      expect(find.text('Rp 3.000.000'), findsNWidgets(2));
    });

    testWidgets('UI: Memilih pos dana sumber dan tujuan yang sama men-disable tombol proses alokasi saldo dan menampilkan notif Error: Pos dana sama', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final monthKey = '${now.year}_${now.month.toString().padLeft(2, '0')}';

      final posA = PosDana(
        id: 'pos_1',
        nama: 'Gaji',
        balance: 5000000,
      );
      final posB = PosDana(
        id: 'pos_2',
        nama: 'Tabungan',
        balance: 1000000,
      );

      final data = PribadiData(
        posDanaList: [posA, posB],
      );

      await PribadiSyncService.savePribadiData(monthKey, data);
      await PribadiSyncService.saveUangkuList(monthKey, [
        Uangku('Gaji', 5000000),
        Uangku('Tabungan', 1000000),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PribadiPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Buka modal Kelola Pos Dana
      final cardPosDana = find.text('Pos Dana');
      await tester.tap(cardPosDana.first);
      await tester.pumpAndSettle();

      // Buka modal Pindah Saldo Antar Pos
      final swapHeaderIcon = find.byTooltip('Pindah Saldo Antar Pos');
      await tester.tap(swapHeaderIcon);
      await tester.pumpAndSettle();

      // Awalnya: from = Gaji (pos_1), to = Tabungan (pos_2). Tombol enabled.
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Proses Alokasi Saldo');
      expect(buttonFinder, findsOneWidget);
      ElevatedButton btnWidget = tester.widget(buttonFinder);
      expect(btnWidget.onPressed, isNotNull);

      // Tap 'Gaji' pada bagian 'Ke Pos Dana (Tujuan)' sehingga from == to == Gaji
      final gajiItems = find.text('Gaji (Rp 5.000.000)');
      // gajiItems.at(0) = chip sumber, gajiItems.at(1) = chip tujuan, gajiItems.at(2) = flow indicator
      await tester.tap(gajiItems.at(1)); // Tap chip tujuan
      await tester.pumpAndSettle();

      // 1. Notif / Text "Error: Pos dana sama" muncul
      expect(find.text('Error: Pos dana sama'), findsWidgets);

      // 2. Tombol Proses Alokasi Saldo menjadi disabled (onPressed == null)
      btnWidget = tester.widget(buttonFinder);
      expect(btnWidget.onPressed, isNull);

      // Jika kita pilih tujuan kembali ke 'Tabungan', error hilang dan tombol aktif lagi
      final tabunganItems = find.text('Tabungan (Rp 1.000.000)');
      await tester.tap(tabunganItems.at(1));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(find.text('Error: Pos dana sama'), findsNothing);
      btnWidget = tester.widget(buttonFinder);
      expect(btnWidget.onPressed, isNotNull);
    });
  });
}
