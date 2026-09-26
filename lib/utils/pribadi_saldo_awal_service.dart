import 'package:daily_apps/models/model_pribadi.dart';
import 'package:daily_apps/models/model_struktur.dart';
import 'package:daily_apps/utils/pribadi_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PosSisaDanaInfo {
  final String nama;
  final int sisaSaldo;
  final String? iconName;
  final int? colorValue;
  final String? deskripsi;

  PosSisaDanaInfo({
    required this.nama,
    required this.sisaSaldo,
    this.iconName,
    this.colorValue,
    this.deskripsi,
  });
}

class PribadiSaldoAwalService {
  static const String saldoAwalKode = 'Saldo Awal';
  static const String saldoAwalKeterangan = 'Sisa Dana';

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

  /// Menghitung total sisa dana dari data keuangan pribadi bulan tertentu
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

  /// Mengambil rincian sisa dana per Pos Dana dari bulan sebelumnya
  static Future<List<PosSisaDanaInfo>> getBreakdownSisaDanaBulanSebelumnya(
      String currentMonthKey) async {
    final prevMonthKey = getPreviousMonthKey(currentMonthKey);
    final prevData = await PribadiSyncService.loadPribadiData(prevMonthKey);
    final results = <PosSisaDanaInfo>[];

    if (prevData.posDanaList.isNotEmpty) {
      for (final pos in prevData.posDanaList) {
        results.add(PosSisaDanaInfo(
          nama: pos.nama,
          sisaSaldo: pos.balance > 0 ? pos.balance : 0,
          iconName: pos.iconName,
          colorValue: pos.colorValue,
          deskripsi: pos.deskripsi,
        ));
      }
    } else {
      final sisa = calculateSisaDana(prevData);
      if (sisa > 0) {
        results.add(PosSisaDanaInfo(
          nama: 'Kas Harian',
          sisaSaldo: sisa,
        ));
      }
    }
    return results;
  }

  /// Mengambil total sisa dana bulan sebelumnya dari SharedPreferences
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

  /// Menyelaraskan Pos Dana dan transaksi Saldo Awal di bulan ini dengan pos dana & sisa dana bulan sebelumnya secara dinamis
  static Future<bool> syncSaldoAwal({
    required String currentMonthKey,
    required PribadiData currentData,
    String? selectedTargetPos,
  }) async {
    ensureSaldoAwalRuleExists(currentData);
    final enabled = await isSaldoAwalEnabled(currentMonthKey);
    final breakdown = await getBreakdownSisaDanaBulanSebelumnya(currentMonthKey);
    final tanggalSatu = getTanggalSatuBulan(currentMonthKey);

    bool hasChanged = false;

    // Bersihkan legacy single transaksi saldo awal jika ada
    final legacyIdx = currentData.transactions.indexWhere(
        (tx) => tx.id == 'saldo_awal_$currentMonthKey');
    if (legacyIdx != -1) {
      final legacyTx = currentData.transactions.removeAt(legacyIdx);
      if (legacyTx.targetAccount != null) {
        final pIdx = currentData.posDanaList.indexWhere((p) =>
            p.nama.trim().toLowerCase() ==
            legacyTx.targetAccount!.trim().toLowerCase());
        if (pIdx != -1) {
          currentData.posDanaList[pIdx].balance -= legacyTx.amount;
          if (currentData.posDanaList[pIdx].balance < 0) {
            currentData.posDanaList[pIdx].balance = 0;
          }
        }
      }
      hasChanged = true;
    }

    if (enabled) {
      // 1. Pastikan setiap Pos Dana dari bulan sebelumnya dibuat di bulan saat ini jika belum ada
      for (final info in breakdown) {
        final posIdx = currentData.posDanaList.indexWhere(
          (p) => p.nama.trim().toLowerCase() == info.nama.trim().toLowerCase(),
        );

        if (posIdx == -1) {
          // Buat Pos Dana baru yang mewarisi konfigurasi pos bulan kemarin
          currentData.posDanaList.add(
            PosDana(
              id: 'pos_${currentData.posDanaList.length + 1}_${info.nama.hashCode}',
              nama: info.nama,
              balance: 0,
              deskripsi: info.deskripsi ?? 'Pos dana: ${info.nama}',
              iconName: info.iconName,
              colorValue: info.colorValue,
            ),
          );
          hasChanged = true;
        }
      }

      // 2. Buat atau perbarui transaksi Saldo Awal per Pos Dana
      for (final info in breakdown) {
        final targetAmount = info.sisaSaldo;
        final txId = 'saldo_awal_${currentMonthKey}_${info.nama}';
        final txNote = '$saldoAwalKeterangan (${info.nama})';

        final txIndex = currentData.transactions.indexWhere((tx) =>
            tx.id == txId ||
            (tx.kode?.trim().toLowerCase() == saldoAwalKode.toLowerCase() &&
                tx.targetAccount?.trim().toLowerCase() ==
                    info.nama.trim().toLowerCase() &&
                (tx.note
                        ?.trim()
                        .toLowerCase()
                        .startsWith('sisa dana') ??
                    false)));

        if (txIndex != -1) {
          final existingTx = currentData.transactions[txIndex];
          final oldAmount = existingTx.amount;
          final selisih = targetAmount - oldAmount;

          if (oldAmount != targetAmount ||
              existingTx.timestamp.day != 1 ||
              existingTx.targetAccount != info.nama) {
            // Sesuaikan saldo Pos Dana
            if (selisih != 0) {
              final posIdx = currentData.posDanaList.indexWhere((p) =>
                  p.nama.trim().toLowerCase() ==
                  info.nama.trim().toLowerCase());
              if (posIdx != -1) {
                currentData.posDanaList[posIdx].balance += selisih;
                if (currentData.posDanaList[posIdx].balance < 0) {
                  currentData.posDanaList[posIdx].balance = 0;
                }
              }
            }

            currentData.transactions[txIndex] = PribadiTransaction(
              id: txId,
              title: txNote,
              type: 'pemasukan',
              targetAccount: info.nama,
              manualSource: info.nama,
              amount: targetAmount,
              timestamp: tanggalSatu,
              note: txNote,
              kode: saldoAwalKode,
            );
            hasChanged = true;
          }
        } else if (targetAmount > 0) {
          // Buat transaksi Saldo Awal baru untuk Pos Dana ini
          final newTx = PribadiTransaction(
            id: txId,
            title: txNote,
            type: 'pemasukan',
            targetAccount: info.nama,
            manualSource: info.nama,
            amount: targetAmount,
            timestamp: tanggalSatu,
            note: txNote,
            kode: saldoAwalKode,
          );

          // Update saldo Pos Dana terkait
          final posIdx = currentData.posDanaList.indexWhere(
              (p) => p.nama.trim().toLowerCase() == info.nama.trim().toLowerCase());
          if (posIdx != -1) {
            currentData.posDanaList[posIdx].balance += targetAmount;
          }

          currentData.transactions.add(newTx);
          hasChanged = true;
        }
      }

      if (hasChanged) {
        currentData.transactions
            .sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }
    } else {
      // Jika dinonaktifkan, hapus seluruh transaksi Saldo Awal dari bulan sebelumnya
      final toRemove = <int>[];
      for (int i = 0; i < currentData.transactions.length; i++) {
        final tx = currentData.transactions[i];
        final isSaldoAwalTx = tx.id.startsWith('saldo_awal_$currentMonthKey') ||
            (tx.kode?.trim().toLowerCase() == saldoAwalKode.toLowerCase() &&
                (tx.note
                        ?.trim()
                        .toLowerCase()
                        .startsWith('sisa dana') ??
                    false));

        if (isSaldoAwalTx) {
          toRemove.add(i);
          if (tx.targetAccount != null) {
            final posIdx = currentData.posDanaList.indexWhere((p) =>
                p.nama.trim().toLowerCase() ==
                tx.targetAccount!.trim().toLowerCase());
            if (posIdx != -1) {
              currentData.posDanaList[posIdx].balance -= tx.amount;
              if (currentData.posDanaList[posIdx].balance < 0) {
                currentData.posDanaList[posIdx].balance = 0;
              }
            }
          }
        }
      }

      if (toRemove.isNotEmpty) {
        for (int i = toRemove.length - 1; i >= 0; i--) {
          currentData.transactions.removeAt(toRemove[i]);
        }
        hasChanged = true;
      }
    }

    return hasChanged;
  }
}
