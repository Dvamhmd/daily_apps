import 'dart:convert';
import 'package:daily_apps/models/model_pribadi.dart';
import 'package:daily_apps/models/model_rundown.dart';
import 'package:daily_apps/utils/pribadi_sync_service.dart';
import 'package:daily_apps/utils/riwayat_service.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RundownExpenseService {
  /// Notifier untuk memberitahukan bahwa data expense rundown telah berubah
  static final ValueNotifier<int> rundownDataUpdatedNotifier =
      ValueNotifier<int>(0);

  static void notifyRundownDataChanged() {
    rundownDataUpdatedNotifier.value++;
  }

  /// Helper untuk mengecek apakah sebuah transaksi di Keuangan Pribadi cocok dengan item expense rundown
  static bool matchesRundownItem({
    required PribadiTransaction tx,
    required Rundown rundown,
    required RundownExpenseItem item,
  }) {
    // 1. Cek pencocokan ID langsung (paling akurat)
    if (tx.rundownExpenseId != null && tx.rundownExpenseId!.isNotEmpty) {
      return tx.rundownExpenseId == item.id;
    }
    if (tx.rundownId != null && tx.rundownId!.isNotEmpty) {
      if (tx.rundownId != rundown.id) return false;
    }

    // 2. Fallback pencocokan teks judul & catatan transaksi
    final effectiveNama =
        (item.catatan != null && item.catatan!.trim().isNotEmpty)
            ? item.catatan!.trim().toLowerCase()
            : item.nama.trim().toLowerCase();
    final itemNama = item.nama.trim().toLowerCase();
    final rundownTitle = rundown.title.trim().toLowerCase();
    final titleLower = tx.title.trim().toLowerCase();
    final noteLower = (tx.note ?? '').trim().toLowerCase();

    final patterns = [
      '($rundownTitle) - $effectiveNama',
      '($rundownTitle) - $itemNama',
      'rundown: $rundownTitle - $effectiveNama',
      'rundown: $rundownTitle - $itemNama',
    ];

    for (final p in patterns) {
      if (titleLower.contains(p) || noteLower.contains(p)) {
        return true;
      }
    }
    return false;
  }

  /// Helper untuk memperbarui dan menyimpan status item expense tertentu di storage `rundowns_data`
  static Future<void> syncRundownExpenseItemToStorage(
    String rundownId,
    RundownExpenseItem updatedItem,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawData = prefs.getStringList('rundowns_data');
      if (rawData == null || rawData.isEmpty) return;

      final list = rawData
          .map((e) => Rundown.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
      final rIdx = list.indexWhere((r) => r.id == rundownId);
      if (rIdx != -1) {
        final rundown = list[rIdx];
        final updatedExpenses = List<RundownExpenseItem>.from(rundown.expenses);
        final eIdx = updatedExpenses.indexWhere((e) => e.id == updatedItem.id);
        if (eIdx != -1) {
          updatedExpenses[eIdx] = updatedItem;
          list[rIdx] = rundown.copyWith(expenses: updatedExpenses);
          await prefs.setStringList(
            'rundowns_data',
            list.map((e) => jsonEncode(e.toJson())).toList(),
          );
        }
      }
    } catch (_) {}
  }

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
  /// Memotong saldo Pos Dana di Keuangan Pribadi & Keuangan Utama, mencatat mutasi transaksi, dan riwayat.
  static Future<RundownExpenseItem> executeRealisasi({
    required Rundown rundown,
    required RundownExpenseItem item,
    required int nominalRealisasi,
    required String posDanaNama,
    DateTime? tanggalRealisasi,
    String? catatan,
    DateTime? selectedMonth,
  }) async {
    final txDate = tanggalRealisasi ?? rundown.startDate;
    final monthKey = PribadiSyncService.getMonthKey(txDate, selectedMonth);

    // 1. Potong saldo Pos Dana di Keuangan Pribadi & catat transaksi (otomatis selaras dengan Uangku)
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
      rundownId: rundown.id,
      rundownExpenseId: item.id,
    );

    // 2. Catat di Riwayat Keuangan Aplikasi
    final nominalFormat = RupiahFormatter.format(nominalRealisasi);
    await RiwayatService.catatRiwayat(
      kategori: 'Rundown',
      perubahan:
          'Realisasi $effectiveNama acara ${rundown.title} : $posDanaNama ($nominalFormat)',
      tipe: 'kurang',
      nominal: nominalRealisasi,
    );

    // 3. Buat updated item
    final updatedItem = item.copyWith(
      nominalRealisasi: nominalRealisasi,
      posDana: posDanaNama,
      tanggalRealisasi: txDate,
      isRealized: true,
      catatan: catatan,
    );

    // 4. Simpan langsung ke storage `rundowns_data` agar status lunas konsisten
    await syncRundownExpenseItemToStorage(rundown.id, updatedItem);

    // 5. Beritahu seluruh halaman keuangan & rundown untuk memperbarui tampilan
    PribadiSyncService.notifyFinanceDataChanged();
    notifyRundownDataChanged();

    return updatedItem;
  }

  /// Membatalkan realisasi (Rollback):
  /// Mengembalikan nominal realisasi ke Pos Dana HANYA jika transaksi belum dihapus/di-rollback dari Keuangan Pribadi.
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
    final txDate = item.tanggalRealisasi ?? rundown.startDate;
    final monthKey = PribadiSyncService.getMonthKey(txDate, selectedMonth);

    // 1. Muat data Keuangan Pribadi
    final data = await PribadiSyncService.loadPribadiData(monthKey);

    // 2. Cari apakah transaksi pengeluaran terkait masih ada di Keuangan Pribadi
    final txIdx = data.transactions.lastIndexWhere((tx) =>
        tx.isPengeluaran &&
        matchesRundownItem(tx: tx, rundown: rundown, item: item));

    if (txIdx != -1) {
      // Transaksi MASIH ADA -> Hapus transaksi dan kembalikan saldo ke Pos Dana
      data.transactions.removeAt(txIdx);

      final pIdx = data.posDanaList.indexWhere(
        (p) => p.nama.trim().toLowerCase() == posName.trim().toLowerCase(),
      );

      if (pIdx != -1) {
        data.posDanaList[pIdx].balance += nominal;
      }

      await PribadiSyncService.savePribadiData(monthKey, data);

      // Catat di Riwayat Keuangan
      final effectiveNama =
          (item.catatan != null && item.catatan!.trim().isNotEmpty)
              ? item.catatan!.trim()
              : item.nama;
      final nominalFormat = RupiahFormatter.format(nominal);
      await RiwayatService.catatRiwayat(
        kategori: 'Rundown',
        perubahan:
            'Batal Realisasi $effectiveNama acara ${rundown.title} : $posName ($nominalFormat)',
        tipe: 'tambah',
        nominal: nominal,
      );
    } else {
      // Transaksi SUDAH TIDAK ADA (misal: sudah di-rollback & dihapus dari Keuangan Pribadi).
      // Saldo sudah dipulihkan pada saat rollback di Keuangan Pribadi,
      // sehingga JANGAN kembalikan saldo lagi agar Pos Dana TIDAK bertambah 2 kali!
    }

    // 3. Update status item di rundown storage
    final updatedItem = item.copyWith(
      clearRealisasi: true,
    );
    await syncRundownExpenseItemToStorage(rundown.id, updatedItem);

    // 4. Beritahu seluruh halaman keuangan & rundown untuk memperbarui tampilan
    PribadiSyncService.notifyFinanceDataChanged();
    notifyRundownDataChanged();

    return updatedItem;
  }

  /// Dipanggil saat transaksi di Keuangan Pribadi dihapus / di-rollback:
  /// Mencari item rundown yang cocok dan mengubah statusnya menjadi Belum Lunas (clear realisasi).
  static Future<void> onTransactionDeleted(PribadiTransaction tx) async {
    final prefs = await SharedPreferences.getInstance();
    final rawData = prefs.getStringList('rundowns_data');
    if (rawData == null || rawData.isEmpty) return;

    try {
      final rundownList = rawData
          .map((e) => Rundown.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();

      bool anyChanged = false;
      for (int rIdx = 0; rIdx < rundownList.length; rIdx++) {
        final rundown = rundownList[rIdx];
        final updatedExpenses = List<RundownExpenseItem>.from(rundown.expenses);
        bool rChanged = false;

        for (int eIdx = 0; eIdx < updatedExpenses.length; eIdx++) {
          final item = updatedExpenses[eIdx];
          if (item.isRealized &&
              matchesRundownItem(tx: tx, rundown: rundown, item: item)) {
            updatedExpenses[eIdx] = item.copyWith(clearRealisasi: true);
            rChanged = true;
            anyChanged = true;
          }
        }

        if (rChanged) {
          rundownList[rIdx] = rundown.copyWith(expenses: updatedExpenses);
        }
      }

      if (anyChanged) {
        final newRaw =
            rundownList.map((e) => jsonEncode(e.toJson())).toList();
        await prefs.setStringList('rundowns_data', newRaw);
        notifyRundownDataChanged();
      }
    } catch (_) {}
  }

  /// Dipanggil saat banyak transaksi dihapus sekaligus
  static Future<void> onTransactionsDeleted(
      List<PribadiTransaction> txList) async {
    if (txList.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final rawData = prefs.getStringList('rundowns_data');
    if (rawData == null || rawData.isEmpty) return;

    try {
      final rundownList = rawData
          .map((e) => Rundown.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();

      bool anyChanged = false;
      for (final tx in txList) {
        for (int rIdx = 0; rIdx < rundownList.length; rIdx++) {
          final rundown = rundownList[rIdx];
          final updatedExpenses =
              List<RundownExpenseItem>.from(rundown.expenses);
          bool rChanged = false;

          for (int eIdx = 0; eIdx < updatedExpenses.length; eIdx++) {
            final item = updatedExpenses[eIdx];
            if (item.isRealized &&
                matchesRundownItem(tx: tx, rundown: rundown, item: item)) {
              updatedExpenses[eIdx] = item.copyWith(clearRealisasi: true);
              rChanged = true;
              anyChanged = true;
            }
          }

          if (rChanged) {
            rundownList[rIdx] = rundown.copyWith(expenses: updatedExpenses);
          }
        }
      }

      if (anyChanged) {
        final newRaw =
            rundownList.map((e) => jsonEncode(e.toJson())).toList();
        await prefs.setStringList('rundowns_data', newRaw);
        notifyRundownDataChanged();
      }
    } catch (_) {}
  }
}

