import 'dart:convert';
import 'package:daily_apps/models/model_pribadi.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PribadiSyncService {
  static String getMonthKey(DateTime? date, DateTime? selectedMonth) {
    final d = date ?? selectedMonth ?? DateTime.now();
    return '${d.year}_${d.month.toString().padLeft(2, '0')}';
  }

  /// Memuat atau membuat PribadiData untuk bulan tertentu
  static Future<PribadiData> loadPribadiData(String monthKey) async {
    final prefs = await SharedPreferences.getInstance();
    final monthlyKey = 'pribadi_keuangan_data_$monthKey';
    final raw = prefs.getString(monthlyKey);

    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final loaded = PribadiData.fromJson(decoded);
          if (loaded.posDanaList.isEmpty) {
            final totalLegacy = loaded.rekeningPribadi.balance +
                loaded.onHandDebit.balance +
                loaded.onHandCash.balance;
            loaded.posDanaList = [
              PosDana(
                id: 'pos_1',
                nama: 'Rekening Utama',
                balance: loaded.rekeningPribadi.balance > 0
                    ? loaded.rekeningPribadi.balance
                    : (totalLegacy > 0 ? totalLegacy : 0),
                deskripsi: 'Wadah Utama Pemasukan',
                iconName: 'account_balance',
              ),
              PosDana(
                id: 'pos_2',
                nama: 'Dompet & Kas',
                balance: (loaded.onHandDebit.balance +
                            loaded.onHandCash.balance) >
                        0
                    ? (loaded.onHandDebit.balance + loaded.onHandCash.balance)
                    : 0,
                deskripsi: 'Dana Operasional & Tunai',
                iconName: 'wallet',
              ),
              PosDana(
                id: 'pos_3',
                nama: 'Tabungan & Darurat',
                balance: 0,
                deskripsi: 'Simpanan Pribadi',
                iconName: 'savings',
              ),
            ];
          }
          return loaded;
        }
      } catch (_) {}
    }

    // Fallback dari template
    final templateRaw = prefs.getString('pribadi_keuangan_data');
    if (templateRaw != null) {
      try {
        final decoded = jsonDecode(templateRaw);
        if (decoded is Map<String, dynamic>) {
          final template = PribadiData.fromJson(decoded);
          final newPosList = template.posDanaList.isNotEmpty
              ? template.posDanaList
                  .map((p) => PosDana(
                        id: p.id,
                        nama: p.nama,
                        balance: 0,
                        deskripsi: p.deskripsi,
                        iconName: p.iconName,
                      ))
                  .toList()
              : [
                  PosDana(
                    id: 'pos_1',
                    nama: 'Rekening Utama',
                    balance: 0,
                    deskripsi: 'Wadah Utama Pemasukan',
                    iconName: 'account_balance',
                  ),
                  PosDana(
                    id: 'pos_2',
                    nama: 'Dompet & Kas',
                    balance: 0,
                    deskripsi: 'Dana Operasional & Tunai',
                    iconName: 'wallet',
                  ),
                  PosDana(
                    id: 'pos_3',
                    nama: 'Tabungan & Darurat',
                    balance: 0,
                    deskripsi: 'Simpanan Pribadi',
                    iconName: 'savings',
                  ),
                ];

          return PribadiData(
            posDanaList: newPosList,
            rekeningPribadi: RekeningPribadi(
              bankName: template.rekeningPribadi.bankName,
              accountNumber: template.rekeningPribadi.accountNumber,
              accountHolder: template.rekeningPribadi.accountHolder,
              balance: 0,
            ),
            onHandDebit: OnHandDebit(
              bankName: template.onHandDebit.bankName,
              accountNumber: template.onHandDebit.accountNumber,
              accountHolder: template.onHandDebit.accountHolder,
              balance: 0,
            ),
            onHandCash: OnHandCash(balance: 0),
            transactions: [],
            customKodeRules: List.from(template.customKodeRules),
          );
        }
      } catch (_) {}
    }

    // Default data baru
    return PribadiData(
      posDanaList: [
        PosDana(
          id: 'pos_1',
          nama: 'Rekening Utama',
          balance: 0,
          deskripsi: 'Wadah Utama Pemasukan',
          iconName: 'account_balance',
        ),
        PosDana(
          id: 'pos_2',
          nama: 'Dompet & Kas',
          balance: 0,
          deskripsi: 'Dana Operasional & Tunai',
          iconName: 'wallet',
        ),
        PosDana(
          id: 'pos_3',
          nama: 'Tabungan & Darurat',
          balance: 0,
          deskripsi: 'Simpanan Pribadi',
          iconName: 'savings',
        ),
      ],
      rekeningPribadi: RekeningPribadi(),
      onHandDebit: OnHandDebit(),
      onHandCash: OnHandCash(),
      transactions: [],
      customKodeRules: PersonalDefaultRules.defaultRules(),
    );
  }

  /// Simpan PribadiData ke SharedPreferences
  static Future<void> savePribadiData(
      String monthKey, PribadiData data) async {
    final prefs = await SharedPreferences.getInstance();
    final monthlyKey = 'pribadi_keuangan_data_$monthKey';
    final jsonStr = jsonEncode(data.toJson());
    await prefs.setString(monthlyKey, jsonStr);
    await prefs.setString('pribadi_keuangan_data', jsonStr);
  }

  /// Catat Pemasukan dari Uangku ke Keuangan Pribadi
  static Future<void> recordPemasukanFromUangku({
    required String nama,
    required int nominal,
    DateTime? date,
    DateTime? selectedMonth,
    String? keterangan,
  }) async {
    if (nominal <= 0) return;

    final txDate = date ?? DateTime.now();
    final monthKey = getMonthKey(date, selectedMonth);
    final data = await loadPribadiData(monthKey);

    // Cari pos target yang sesuai atau pos pertama (Rekening Utama)
    String targetName = 'Rekening Utama';
    if (data.posDanaList.isNotEmpty) {
      final idx = data.posDanaList.indexWhere(
        (p) =>
            p.nama.trim().toLowerCase() == nama.trim().toLowerCase() ||
            p.id.trim().toLowerCase() == nama.trim().toLowerCase(),
      );
      if (idx != -1) {
        data.posDanaList[idx].balance += nominal;
        targetName = data.posDanaList[idx].nama;
      } else {
        data.posDanaList.first.balance += nominal;
        targetName = data.posDanaList.first.nama;
      }
    } else {
      data.rekeningPribadi.balance += nominal;
    }

    final titleText = keterangan ?? nama;
    final autoKode = PribadiTransaction.resolveKodeFromText(
      titleText,
      customRules: data.customKodeRules,
    );
    final autoKu = PribadiTransaction.resolveKuFromText(
      titleText,
      customRules: data.customKodeRules,
    );

    final tx = PribadiTransaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: titleText,
      type: 'pemasukan',
      targetAccount: targetName,
      manualSource: nama,
      amount: nominal,
      note: keterangan ?? 'Pemasukan Uangku: $nama',
      timestamp: txDate,
      ku: autoKu != '-' ? autoKu : null,
      kode: autoKode != '-' ? autoKode : null,
    );

    data.transactions.add(tx);
    await savePribadiData(monthKey, data);
  }

  /// Catat Pengeluaran dari Uangku ke Keuangan Pribadi
  static Future<void> recordPengeluaranFromUangku({
    required String nama,
    required int nominal,
    DateTime? date,
    DateTime? selectedMonth,
    String? keterangan,
  }) async {
    if (nominal <= 0) return;

    final txDate = date ?? DateTime.now();
    final monthKey = getMonthKey(date, selectedMonth);
    final data = await loadPribadiData(monthKey);

    // Cari pos sumber yang sesuai atau pos pertama
    String srcName = 'Rekening Utama';
    if (data.posDanaList.isNotEmpty) {
      final idx = data.posDanaList.indexWhere(
        (p) =>
            p.nama.trim().toLowerCase() == nama.trim().toLowerCase() ||
            p.id.trim().toLowerCase() == nama.trim().toLowerCase(),
      );
      if (idx != -1) {
        data.posDanaList[idx].balance -= nominal;
        if (data.posDanaList[idx].balance < 0) {
          data.posDanaList[idx].balance = 0;
        }
        srcName = data.posDanaList[idx].nama;
      } else {
        data.posDanaList.first.balance -= nominal;
        if (data.posDanaList.first.balance < 0) {
          data.posDanaList.first.balance = 0;
        }
        srcName = data.posDanaList.first.nama;
      }
    } else {
      data.rekeningPribadi.balance -= nominal;
      if (data.rekeningPribadi.balance < 0) {
        data.rekeningPribadi.balance = 0;
      }
    }

    final titleText = keterangan ?? nama;
    final autoKode = PribadiTransaction.resolveKodeFromText(
      titleText,
      customRules: data.customKodeRules,
    );
    final autoKu = PribadiTransaction.resolveKuFromText(
      titleText,
      customRules: data.customKodeRules,
    );

    final tx = PribadiTransaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: titleText,
      type: 'pengeluaran',
      sourceAccount: srcName,
      amount: nominal,
      note: keterangan ?? 'Pengeluaran Uangku: $nama',
      timestamp: txDate,
      ku: autoKu != '-' ? autoKu : null,
      kode: autoKode != '-' ? autoKode : null,
    );

    data.transactions.add(tx);
    await savePribadiData(monthKey, data);
  }

  /// Sinkronisasi saat pos Uangku diedit (nama, nominal, atau tanggal cair)
  /// Menyesuaikan data transaksi yang sudah ada di Keuangan Pribadi tanpa membuat transaksi baru.
  static Future<void> syncEditUangku({
    required String namaLama,
    required int jumlahLama,
    required String namaBaru,
    required int jumlahBaru,
    DateTime? tanggalCairLama,
    DateTime? tanggalCairBaru,
    DateTime? selectedMonth,
  }) async {
    final oldMonthKey = getMonthKey(tanggalCairLama, selectedMonth);
    final newMonthKey = getMonthKey(tanggalCairBaru, selectedMonth);

    if (oldMonthKey == newMonthKey) {
      final data = await loadPribadiData(oldMonthKey);

      // Cari transaksi pemasukan yang cocok dengan pos Uangku ini
      final txIndex = data.transactions.indexWhere((tx) =>
          tx.isPemasukan &&
          (tx.manualSource?.trim().toLowerCase() ==
                  namaLama.trim().toLowerCase() ||
              tx.title.trim().toLowerCase() ==
                  namaLama.trim().toLowerCase() ||
              tx.note?.trim().toLowerCase() ==
                  'pemasukan uangku: ${namaLama.trim().toLowerCase()}'));

      if (txIndex != -1) {
        final existingTx = data.transactions[txIndex];
        final selisih = jumlahBaru - existingTx.amount;

        // Sesuaikan saldo Pos Dana target
        if (data.posDanaList.isNotEmpty) {
          final posIdx = data.posDanaList.indexWhere((p) =>
              p.nama.trim().toLowerCase() ==
                  existingTx.targetAccount?.trim().toLowerCase() ||
              p.id.trim().toLowerCase() ==
                  existingTx.targetAccount?.trim().toLowerCase());
          if (posIdx != -1) {
            data.posDanaList[posIdx].balance += selisih;
            if (data.posDanaList[posIdx].balance < 0) {
              data.posDanaList[posIdx].balance = 0;
            }
          } else {
            data.posDanaList.first.balance += selisih;
            if (data.posDanaList.first.balance < 0) {
              data.posDanaList.first.balance = 0;
            }
          }
        } else {
          data.rekeningPribadi.balance += selisih;
          if (data.rekeningPribadi.balance < 0) {
            data.rekeningPribadi.balance = 0;
          }
        }

        // Auto-resolve kode & ku baru jika ada perubahan nama
        final autoKode = PribadiTransaction.resolveKodeFromText(
          namaBaru,
          customRules: data.customKodeRules,
        );
        final autoKu = PribadiTransaction.resolveKuFromText(
          namaBaru,
          customRules: data.customKodeRules,
        );

        // Update transaksi di tempat tanpa membuat transaksi baru
        data.transactions[txIndex] = PribadiTransaction(
          id: existingTx.id,
          title: namaBaru,
          type: existingTx.type,
          targetAccount: existingTx.targetAccount,
          sourceAccount: existingTx.sourceAccount,
          manualSource: namaBaru,
          amount: jumlahBaru,
          adminFee: existingTx.adminFee,
          timestamp: tanggalCairBaru ?? existingTx.timestamp,
          note: 'Pemasukan Uangku: $namaBaru',
          ku: autoKu != '-' ? autoKu : existingTx.ku,
          kode: autoKode != '-' ? autoKode : existingTx.kode,
        );

        await savePribadiData(oldMonthKey, data);
      } else if (jumlahBaru > 0) {
        // Jika sebelumnya belum ada data transaksi, buatkan transaksi baru
        await recordPemasukanFromUangku(
          nama: namaBaru,
          nominal: jumlahBaru,
          date: tanggalCairBaru,
          selectedMonth: selectedMonth,
          keterangan: namaBaru,
        );
      }
    } else {
      // Jika bulan berubah karena tanggal cair berpindah bulan
      final oldData = await loadPribadiData(oldMonthKey);
      final txIndex = oldData.transactions.indexWhere((tx) =>
          tx.isPemasukan &&
          (tx.manualSource?.trim().toLowerCase() ==
                  namaLama.trim().toLowerCase() ||
              tx.title.trim().toLowerCase() ==
                  namaLama.trim().toLowerCase() ||
              tx.note?.trim().toLowerCase() ==
                  'pemasukan uangku: ${namaLama.trim().toLowerCase()}'));

      if (txIndex != -1) {
        final existingTx = oldData.transactions[txIndex];
        if (oldData.posDanaList.isNotEmpty) {
          final posIdx = oldData.posDanaList.indexWhere((p) =>
              p.nama.trim().toLowerCase() ==
                  existingTx.targetAccount?.trim().toLowerCase() ||
              p.id.trim().toLowerCase() ==
                  existingTx.targetAccount?.trim().toLowerCase());
          if (posIdx != -1) {
            oldData.posDanaList[posIdx].balance -= existingTx.amount;
            if (oldData.posDanaList[posIdx].balance < 0) {
              oldData.posDanaList[posIdx].balance = 0;
            }
          } else {
            oldData.posDanaList.first.balance -= existingTx.amount;
            if (oldData.posDanaList.first.balance < 0) {
              oldData.posDanaList.first.balance = 0;
            }
          }
        } else {
          oldData.rekeningPribadi.balance -= existingTx.amount;
          if (oldData.rekeningPribadi.balance < 0) {
            oldData.rekeningPribadi.balance = 0;
          }
        }
        oldData.transactions.removeAt(txIndex);
        await savePribadiData(oldMonthKey, oldData);
      }

      // Catat di bulan baru
      if (jumlahBaru > 0) {
        await recordPemasukanFromUangku(
          nama: namaBaru,
          nominal: jumlahBaru,
          date: tanggalCairBaru,
          selectedMonth: selectedMonth,
          keterangan: namaBaru,
        );
      }
    }
  }

  /// Sinkronisasi saat pos Uangku dihapus.
  /// Menghapus data transaksi pemasukan yang berkaitan dari Keuangan Pribadi dan menyesuaikan saldo.
  static Future<void> syncHapusUangku({
    required String nama,
    required int jumlah,
    DateTime? tanggalCair,
    DateTime? selectedMonth,
  }) async {
    final monthKey = getMonthKey(tanggalCair, selectedMonth);
    final data = await loadPribadiData(monthKey);

    // Cari seluruh transaksi pemasukan yang berasal dari pos Uangku ini
    final matchingIndices = <int>[];
    for (int i = 0; i < data.transactions.length; i++) {
      final tx = data.transactions[i];
      if (tx.isPemasukan &&
          (tx.manualSource?.trim().toLowerCase() ==
                  nama.trim().toLowerCase() ||
              tx.title.trim().toLowerCase() == nama.trim().toLowerCase() ||
              tx.note?.trim().toLowerCase() ==
                  'pemasukan uangku: ${nama.trim().toLowerCase()}')) {
        matchingIndices.add(i);
      }
    }

    if (matchingIndices.isNotEmpty) {
      // Hapus dari indeks terbesar ke terkecil agar tidak merusak urutan
      for (final idx in matchingIndices.reversed) {
        final tx = data.transactions[idx];
        // Kurangi saldo Pos Dana target
        if (data.posDanaList.isNotEmpty) {
          final posIdx = data.posDanaList.indexWhere((p) =>
              p.nama.trim().toLowerCase() ==
                  tx.targetAccount?.trim().toLowerCase() ||
              p.id.trim().toLowerCase() ==
                  tx.targetAccount?.trim().toLowerCase());
          if (posIdx != -1) {
            data.posDanaList[posIdx].balance -= tx.amount;
            if (data.posDanaList[posIdx].balance < 0) {
              data.posDanaList[posIdx].balance = 0;
            }
          } else {
            data.posDanaList.first.balance -= tx.amount;
            if (data.posDanaList.first.balance < 0) {
              data.posDanaList.first.balance = 0;
            }
          }
        } else {
          data.rekeningPribadi.balance -= tx.amount;
          if (data.rekeningPribadi.balance < 0) {
            data.rekeningPribadi.balance = 0;
          }
        }
        data.transactions.removeAt(idx);
      }

      await savePribadiData(monthKey, data);
    }
  }
}
