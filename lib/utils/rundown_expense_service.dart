import 'package:daily_apps/models/model_pribadi.dart';
import 'package:daily_apps/models/model_rundown.dart';
import 'package:daily_apps/utils/pribadi_sync_service.dart';
import 'package:daily_apps/utils/riwayat_service.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';

class RundownExpenseService {
  /// Mengambil daftar Pos Dana yang tersedia beserta saldonya
  static Future<List<PosDana>> loadAvailablePosDana({
    DateTime? date,
    DateTime? selectedMonth,
  }) async {
    final monthKey = PribadiSyncService.getMonthKey(date, selectedMonth);
    final data = await PribadiSyncService.loadPribadiData(monthKey);
    final uList = await PribadiSyncService.loadUangkuList(monthKey);

    if (data.posDanaList.isNotEmpty) {
      return data.posDanaList;
    }

    if (uList.isNotEmpty) {
      return uList
          .map((u) => PosDana(
                id: 'pos_${u.nama.hashCode}',
                nama: u.nama,
                balance: u.jumlah,
                deskripsi: 'Pos dana: ${u.nama}',
              ))
          .toList();
    }

    return [];
  }

  /// Memproses realisasi pengeluaran item rundown:
  /// Memotong saldo Pos Dana di Keuangan Utama & Keuangan Pribadi, mencatat mutasi transaksi, dan riwayat.
  static Future<RundownExpenseItem> executeRealisasi({
    required Rundown rundown,
    required RundownExpenseItem item,
    required int nominalRealisasi,
    required String posDanaNama,
    DateTime? tanggalRealisasi,
    String? catatan,
    DateTime? selectedMonth,
  }) async {
    final txDate = tanggalRealisasi ?? DateTime.now();
    final monthKey = PribadiSyncService.getMonthKey(txDate, selectedMonth);

    // 1. Potong saldo di Uangku (Keuangan Utama)
    final uList = await PribadiSyncService.loadUangkuList(monthKey);
    final uIdx = uList.indexWhere(
      (u) => u.nama.trim().toLowerCase() == posDanaNama.trim().toLowerCase(),
    );

    if (uIdx != -1) {
      final curU = uList[uIdx];
      final sisa = curU.jumlah - nominalRealisasi;
      uList[uIdx] = curU.copyWith(jumlah: sisa < 0 ? 0 : sisa);
      await PribadiSyncService.saveUangkuList(monthKey, uList);
    }

    // 2. Potong saldo Pos Dana di Keuangan Pribadi & catat transaksi
    final effectiveNama = (catatan != null && catatan.trim().isNotEmpty)
        ? catatan.trim()
        : item.nama;
    final keteranganTx = '(${rundown.title}) - $effectiveNama';
    await PribadiSyncService.recordPengeluaranFromUangku(
      nama: posDanaNama,
      nominal: nominalRealisasi,
      date: txDate,
      selectedMonth: selectedMonth,
      keterangan: keteranganTx,
    );

    // 3. Catat di Riwayat Keuangan Aplikasi
    final nominalFormat = RupiahFormatter.format(nominalRealisasi);
    await RiwayatService.catatRiwayat(
      kategori: 'Rundown',
      perubahan:
          'Realisasi $effectiveNama acara ${rundown.title} : $posDanaNama ($nominalFormat)',
      tipe: 'kurang',
      nominal: nominalRealisasi,
    );

    // 4. Beritahu seluruh halaman keuangan untuk memperbarui tampilan
    PribadiSyncService.notifyFinanceDataChanged();

    // 5. Return updated item
    return item.copyWith(
      nominalRealisasi: nominalRealisasi,
      posDana: posDanaNama,
      tanggalRealisasi: txDate,
      isRealized: true,
      catatan: catatan,
    );
  }

  /// Membatalkan realisasi (Rollback):
  /// Mengembalikan nominal realisasi ke Pos Dana di Keuangan Utama & Keuangan Pribadi.
  static Future<RundownExpenseItem> revertRealisasi({
    required Rundown rundown,
    required RundownExpenseItem item,
    DateTime? selectedMonth,
  }) async {
    if (!item.isRealized || item.posDana == null) {
      return item;
    }

    final nominal = item.nominalRealisasi ?? item.nominalEstimasi;
    final posName = item.posDana!;
    final txDate = item.tanggalRealisasi ?? DateTime.now();
    final monthKey = PribadiSyncService.getMonthKey(txDate, selectedMonth);

    // 1. Kembalikan saldo di Uangku (Keuangan Utama)
    final uList = await PribadiSyncService.loadUangkuList(monthKey);
    final uIdx = uList.indexWhere(
      (u) => u.nama.trim().toLowerCase() == posName.trim().toLowerCase(),
    );

    if (uIdx != -1) {
      final curU = uList[uIdx];
      uList[uIdx] = curU.copyWith(jumlah: curU.jumlah + nominal);
      await PribadiSyncService.saveUangkuList(monthKey, uList);
    }

    // 2. Kembalikan saldo di Keuangan Pribadi
    final data = await PribadiSyncService.loadPribadiData(monthKey);
    final pIdx = data.posDanaList.indexWhere(
      (p) => p.nama.trim().toLowerCase() == posName.trim().toLowerCase(),
    );

    if (pIdx != -1) {
      data.posDanaList[pIdx].balance += nominal;
    }

    // Hapus atau batalkan transaksi pengeluaran terkait dari list
    final effectiveNama =
        (item.catatan != null && item.catatan!.trim().isNotEmpty)
            ? item.catatan!.trim()
            : item.nama;
    final targetKetEffective =
        '(${rundown.title}) - $effectiveNama'.toLowerCase();
    final targetKetOriginal =
        '(${rundown.title}) - ${item.nama}'.toLowerCase();
    final targetKetEffectiveLegacy =
        'rundown: ${rundown.title} - $effectiveNama'.toLowerCase();
    final targetKetOriginalLegacy =
        'rundown: ${rundown.title} - ${item.nama}'.toLowerCase();

    final txIdx = data.transactions.lastIndexWhere((tx) =>
        tx.isPengeluaran &&
        tx.sourceAccount?.trim().toLowerCase() == posName.toLowerCase() &&
        (tx.title.toLowerCase().contains(targetKetEffective) ||
            tx.title.toLowerCase().contains(targetKetOriginal) ||
            tx.title.toLowerCase().contains(targetKetEffectiveLegacy) ||
            tx.title.toLowerCase().contains(targetKetOriginalLegacy) ||
            (tx.note != null &&
                (tx.note!.toLowerCase().contains(targetKetEffective) ||
                    tx.note!.toLowerCase().contains(targetKetOriginal) ||
                    tx.note!.toLowerCase().contains(targetKetEffectiveLegacy) ||
                    tx.note!.toLowerCase().contains(targetKetOriginalLegacy)))));

    if (txIdx != -1) {
      data.transactions.removeAt(txIdx);
    }

    await PribadiSyncService.savePribadiData(monthKey, data);

    // 3. Catat di Riwayat Keuangan
    final nominalFormat = RupiahFormatter.format(nominal);
    await RiwayatService.catatRiwayat(
      kategori: 'Rundown',
      perubahan:
          'Batal Realisasi $effectiveNama acara ${rundown.title} : $posName ($nominalFormat)',
      tipe: 'tambah',
      nominal: nominal,
    );

    // 4. Beritahu seluruh halaman keuangan untuk memperbarui tampilan
    PribadiSyncService.notifyFinanceDataChanged();

    return item.copyWith(
      clearRealisasi: true,
    );
  }
}
