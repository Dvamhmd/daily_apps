import 'package:daily_apps/models/model_pribadi.dart';
import 'package:daily_apps/models/model_struktur.dart';
import 'package:daily_apps/utils/pribadi_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PribadiSaldoAwalService {
  static const String saldoAwalKode = 'Saldo Awal';
  static const String saldoAwalKeterangan = 'Sisa dana bulan kemarin';

  /// Mendapatkan key bulan sebelumnya berdasarkan key bulan saat ini (format 'YYYY_MM')
  static String getPreviousMonthKey(String currentMonthKey) {
    try {
      final parts = currentMonthKey.split('_');
      if (parts.length == 2) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final prevDate = DateTime(year, month - 1, 1);
        return '${prevDate.year}_${prevDate.month.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    final now = DateTime.now();
    final prevDate = DateTime(now.year, now.month - 1, 1);
    return '${prevDate.year}_${prevDate.month.toString().padLeft(2, '0')}';
  }

  /// Mendapatkan DateTime tanggal 1 untuk bulan tertentu
  static DateTime getTanggalSatuBulan(String monthKey) {
    try {
      final parts = monthKey.split('_');
      if (parts.length == 2) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        return DateTime(year, month, 1, 0, 0, 0);
      }
    } catch (_) {}
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1, 0, 0, 0);
  }

  /// Menghitung sisa dana dari data keuangan pribadi bulan tertentu
  static int calculateSisaDana(PribadiData data) {
    if (data.posDanaList.isNotEmpty) {
      final totalPos = data.totalPosDana;
      if (totalPos > 0) return totalPos;
    }
    final selisih = data.totalPemasukan - data.totalPengeluaran;
    if (selisih > 0) return selisih;

    final totalPribadi = data.totalDanaPribadi.toInt();
    if (totalPribadi > 0) return totalPribadi;

    return selisih > 0 ? selisih : 0;
  }

  /// Mengambil sisa dana bulan sebelumnya dari SharedPreferences
  static Future<int> getSisaDanaBulanSebelumnya(String currentMonthKey) async {
    final prevMonthKey = getPreviousMonthKey(currentMonthKey);
    final prevData = await PribadiSyncService.loadPribadiData(prevMonthKey);
    return calculateSisaDana(prevData);
  }

  /// Memeriksa apakah opsi saldo awal aktif untuk bulan tertentu
  static Future<bool> isSaldoAwalEnabled(String currentMonthKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('pribadi_saldo_awal_enabled_$currentMonthKey') ?? false;
  }

  /// Menyimpan status aktif/nonaktif saldo awal untuk bulan tertentu
  static Future<void> setSaldoAwalEnabled(
      String currentMonthKey, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pribadi_saldo_awal_enabled_$currentMonthKey', enabled);
  }

  /// Memeriksa dan memastikan aturan kategori 'Saldo Awal' terdaftar
  static void ensureSaldoAwalRuleExists(PribadiData data) {
    final exists = data.customKodeRules.any((r) =>
        r.kode.trim().toLowerCase() == saldoAwalKode.toLowerCase() &&
        (r.type == 'pemasukan' || r.type == 'kategori_pemasukan'));
    if (!exists) {
      data.customKodeRules.add(
        CustomKodeRule(
          keyword: 'saldo awal',
          kode: saldoAwalKode,
          type: 'pemasukan',
        ),
      );
    }
  }

  /// Menyelaraskan transaksi Saldo Awal di bulan ini dengan sisa dana bulan sebelumnya secara dinamis
  static Future<bool> syncSaldoAwal({
    required String currentMonthKey,
    required PribadiData currentData,
    String? selectedTargetPos,
  }) async {
    ensureSaldoAwalRuleExists(currentData);
    final enabled = await isSaldoAwalEnabled(currentMonthKey);
    final prevMonthKey = getPreviousMonthKey(currentMonthKey);
    final prevData = await PribadiSyncService.loadPribadiData(prevMonthKey);
    final sisaDana = calculateSisaDana(prevData);
    final tanggalSatu = getTanggalSatuBulan(currentMonthKey);

    final txIndex = currentData.transactions.indexWhere((tx) =>
        tx.id == 'saldo_awal_$currentMonthKey' ||
        (tx.kode?.trim().toLowerCase() == saldoAwalKode.toLowerCase() &&
            tx.note?.trim().toLowerCase() == saldoAwalKeterangan.toLowerCase()));

    bool hasChanged = false;

    if (enabled) {
      String targetAccount = selectedTargetPos ??
          (currentData.posDanaList.isNotEmpty
              ? currentData.posDanaList.first.nama
              : 'Kas Harian');

      if (txIndex != -1) {
        final existingTx = currentData.transactions[txIndex];
        final oldAmount = existingTx.amount;
        final selisih = sisaDana - oldAmount;

        if (oldAmount != sisaDana ||
            existingTx.timestamp.day != 1 ||
            existingTx.targetAccount != targetAccount) {
          // Sesuaikan saldo Pos Dana jika ada perubahan nominal
          if (selisih != 0 && currentData.posDanaList.isNotEmpty) {
            final posIdx = currentData.posDanaList.indexWhere((p) =>
                p.nama.trim().toLowerCase() ==
                (existingTx.targetAccount ?? targetAccount).toLowerCase());
            if (posIdx != -1) {
              currentData.posDanaList[posIdx].balance += selisih;
              if (currentData.posDanaList[posIdx].balance < 0) {
                currentData.posDanaList[posIdx].balance = 0;
              }
            }
          }

          currentData.transactions[txIndex] = PribadiTransaction(
            id: 'saldo_awal_$currentMonthKey',
            title: saldoAwalKeterangan,
            type: 'pemasukan',
            targetAccount: targetAccount,
            manualSource: 'Bulan Lalu',
            amount: sisaDana,
            timestamp: tanggalSatu,
            note: saldoAwalKeterangan,
            kode: saldoAwalKode,
          );
          hasChanged = true;
        }
      } else {
        // Buat transaksi Saldo Awal baru
        final newTx = PribadiTransaction(
          id: 'saldo_awal_$currentMonthKey',
          title: saldoAwalKeterangan,
          type: 'pemasukan',
          targetAccount: targetAccount,
          manualSource: 'Bulan Lalu',
          amount: sisaDana,
          timestamp: tanggalSatu,
          note: saldoAwalKeterangan,
          kode: saldoAwalKode,
        );

        // Update saldo Pos Dana
        if (currentData.posDanaList.isNotEmpty) {
          final posIdx = currentData.posDanaList.indexWhere((p) =>
              p.nama.trim().toLowerCase() == targetAccount.toLowerCase());
          if (posIdx != -1) {
            currentData.posDanaList[posIdx].balance += sisaDana;
          } else {
            currentData.posDanaList.first.balance += sisaDana;
          }
        }

        currentData.transactions.add(newTx);
        currentData.transactions
            .sort((a, b) => a.timestamp.compareTo(b.timestamp));
        hasChanged = true;
      }
    } else {
      // Jika dinonaktifkan, hapus transaksi Saldo Awal jika ada
      if (txIndex != -1) {
        final existingTx = currentData.transactions[txIndex];
        if (currentData.posDanaList.isNotEmpty &&
            existingTx.targetAccount != null) {
          final posIdx = currentData.posDanaList.indexWhere((p) =>
              p.nama.trim().toLowerCase() ==
              existingTx.targetAccount!.trim().toLowerCase());
          if (posIdx != -1) {
            currentData.posDanaList[posIdx].balance -= existingTx.amount;
            if (currentData.posDanaList[posIdx].balance < 0) {
              currentData.posDanaList[posIdx].balance = 0;
            }
          }
        }
        currentData.transactions.removeAt(txIndex);
        hasChanged = true;
      }
    }

    return hasChanged;
  }
}
