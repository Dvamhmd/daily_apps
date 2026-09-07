import 'dart:convert';
import 'package:daily_apps/models/model_pribadi.dart';
import 'package:daily_apps/models/model_uangku.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PribadiSyncService {
  static String getMonthKey(DateTime? date, DateTime? selectedMonth) {
    final d = date ?? selectedMonth ?? DateTime.now();
    return '${d.year}_${d.month.toString().padLeft(2, '0')}';
  }

  /// Membaca daftar Uangku untuk bulan tertentu dari SharedPreferences
  static Future<List<Uangku>> loadUangkuList(String monthKey) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'uangku_$monthKey';
    var data = prefs.getStringList(key);

    // Migrasi/fallback legacy jika bulan ini belum punya data
    if (data == null) {
      final now = DateTime.now();
      final currentMonthKey =
          '${now.year}_${now.month.toString().padLeft(2, '0')}';
      if (monthKey == currentMonthKey) {
        final legacy = prefs.getStringList('uangku');
        if (legacy != null) {
          data = legacy;
        }
      }
    }

    if (data == null) return [];
    try {
      return data
          .map((e) => Uangku.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Menyimpan daftar Uangku untuk bulan tertentu ke SharedPreferences
  static Future<void> saveUangkuList(
      String monthKey, List<Uangku> uangkuList) async {
    final prefs = await SharedPreferences.getInstance();
    final data = uangkuList.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('uangku_$monthKey', data);
  }

  /// Menyelaraskan daftar Pos Dana dengan daftar Uangku (1-to-1)
  static List<PosDana> syncPosDanaWithUangkuList({
    required List<PosDana> currentPosList,
    required List<Uangku> uangkuList,
  }) {
    if (uangkuList.isEmpty) {
      return [];
    }

    final result = <PosDana>[];
    for (int i = 0; i < uangkuList.length; i++) {
      final u = uangkuList[i];
      final uName = u.nama.trim();
      final matchIndex = currentPosList.indexWhere(
        (p) => p.nama.trim().toLowerCase() == uName.toLowerCase(),
      );

      if (matchIndex != -1) {
        final existing = currentPosList[matchIndex];
        result.add(PosDana(
          id: existing.id.isNotEmpty
              ? existing.id
              : 'pos_${i + 1}_${uName.hashCode}',
          nama: uName,
          balance: existing.balance,
          deskripsi: existing.deskripsi ?? 'Pos dana Uangku: $uName',
          iconName: existing.iconName,
          colorValue: existing.colorValue,
        ));
      } else {
        result.add(PosDana(
          id: 'pos_${i + 1}_${uName.hashCode}',
          nama: uName,
          balance: u.jumlah,
          deskripsi: 'Pos dana Uangku: $uName',
        ));
      }
    }
    return result;
  }

  /// Memuat atau membuat PribadiData untuk bulan tertentu, otomatis sinkron dengan Uangku
  static Future<PribadiData> loadPribadiData(String monthKey) async {
    final prefs = await SharedPreferences.getInstance();
    final monthlyKey = 'pribadi_keuangan_data_$monthKey';
    final raw = prefs.getString(monthlyKey);
    final uList = await loadUangkuList(monthKey);

    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final loaded = PribadiData.fromJson(decoded);

          if (uList.isNotEmpty) {
            loaded.posDanaList = syncPosDanaWithUangkuList(
              currentPosList: loaded.posDanaList,
              uangkuList: uList,
            );
          } else if (loaded.posDanaList.any((p) =>
              p.id == 'pos_1' || p.id == 'pos_2' || p.id == 'pos_3')) {
            // Bersihkan pos dummy default jika Uangku kosong
            loaded.posDanaList = [];
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
          final newPosList = uList.isNotEmpty
              ? syncPosDanaWithUangkuList(
                  currentPosList: template.posDanaList,
                  uangkuList: uList,
                )
              : <PosDana>[];

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

    // Default data baru: jika ada data Uangku, buat Pos Dana sesuai Uangku
    final newPosList = uList.isNotEmpty
        ? syncPosDanaWithUangkuList(
            currentPosList: [],
            uangkuList: uList,
          )
        : <PosDana>[];

    return PribadiData(
      posDanaList: newPosList,
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

  /// Catat Pemasukan dari Uangku ke Keuangan Pribadi (otomatis membuat/menyesuaikan Pos Dana)
  static Future<void> recordPemasukanFromUangku({
    required String nama,
    required int nominal,
    DateTime? date,
    DateTime? selectedMonth,
    String? keterangan,
  }) async {
    final txDate = date ?? DateTime.now();
    final monthKey = getMonthKey(date, selectedMonth);
    final data = await loadPribadiData(monthKey);

    // Cari pos target yang sesuai atau buat baru
    final targetName = nama.trim();
    final idx = data.posDanaList.indexWhere(
      (p) =>
          p.nama.trim().toLowerCase() == targetName.toLowerCase() ||
          p.id.trim().toLowerCase() == targetName.toLowerCase(),
    );

    if (idx != -1) {
      data.posDanaList[idx].balance += nominal;
    } else {
      final newPos = PosDana(
        id: 'pos_${data.posDanaList.length + 1}_${targetName.hashCode}',
        nama: targetName,
        balance: nominal,
        deskripsi: 'Pos dana Uangku: $targetName',
      );
      data.posDanaList.add(newPos);
    }

    if (nominal > 0) {
      final titleText = keterangan ?? nama;
      final autoKode = PribadiTransaction.resolveKodeFromText(
        titleText,
        customRules: data.customKodeRules,
        type: 'pemasukan',
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
        manualSource: targetName,
        amount: nominal,
        note: keterangan ?? 'Pemasukan Uangku: $nama',
        timestamp: txDate,
        ku: autoKu != '-' ? autoKu : null,
        kode: autoKode != '-' ? autoKode : null,
      );

      data.transactions.add(tx);
    }

    await savePribadiData(monthKey, data);
  }

  /// Catat Pengeluaran dari Uangku ke Keuangan Pribadi (memotong saldo Pos Dana terkait)
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

    // Cari pos sumber yang sesuai
    String srcName = nama.trim();
    final idx = data.posDanaList.indexWhere(
      (p) =>
          p.nama.trim().toLowerCase() == srcName.toLowerCase() ||
          p.id.trim().toLowerCase() == srcName.toLowerCase(),
    );

    if (idx != -1) {
      data.posDanaList[idx].balance -= nominal;
      if (data.posDanaList[idx].balance < 0) {
        data.posDanaList[idx].balance = 0;
      }
      srcName = data.posDanaList[idx].nama;
    } else if (data.posDanaList.isNotEmpty) {
      data.posDanaList.first.balance -= nominal;
      if (data.posDanaList.first.balance < 0) {
        data.posDanaList.first.balance = 0;
      }
      srcName = data.posDanaList.first.nama;
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
      type: 'pengeluaran',
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
  /// Menyesuaikan Pos Dana & transaksi di Keuangan Pribadi tanpa membuat data duplikat.
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

      // Update Pos Dana
      final posIdx = data.posDanaList.indexWhere(
        (p) => p.nama.trim().toLowerCase() == namaLama.trim().toLowerCase(),
      );

      final selisih = jumlahBaru - jumlahLama;
      if (posIdx != -1) {
        data.posDanaList[posIdx].nama = namaBaru.trim();
        data.posDanaList[posIdx].balance += selisih;
        if (data.posDanaList[posIdx].balance < 0) {
          data.posDanaList[posIdx].balance = 0;
        }
      } else {
        data.posDanaList.add(
          PosDana(
            id: 'pos_${data.posDanaList.length + 1}_${namaBaru.hashCode}',
            nama: namaBaru.trim(),
            balance: jumlahBaru,
            deskripsi: 'Pos dana Uangku: ${namaBaru.trim()}',
          ),
        );
      }

      // Update seluruh transaksi yang mereferensikan namaLama
      for (int i = 0; i < data.transactions.length; i++) {
        final tx = data.transactions[i];
        if (tx.targetAccount?.trim().toLowerCase() ==
            namaLama.trim().toLowerCase()) {
          data.transactions[i] = PribadiTransaction(
            id: tx.id,
            title: tx.title == namaLama ? namaBaru : tx.title,
            type: tx.type,
            targetAccount: namaBaru.trim(),
            sourceAccount: tx.sourceAccount,
            manualSource: tx.manualSource == namaLama ? namaBaru.trim() : tx.manualSource,
            amount: tx.isPemasukan && tx.title == namaLama ? jumlahBaru : tx.amount,
            adminFee: tx.adminFee,
            timestamp: tx.timestamp,
            note: tx.note?.replaceAll(namaLama, namaBaru),
            ku: tx.ku,
            kode: tx.kode,
          );
        } else if (tx.sourceAccount?.trim().toLowerCase() ==
            namaLama.trim().toLowerCase()) {
          data.transactions[i] = PribadiTransaction(
            id: tx.id,
            title: tx.title,
            type: tx.type,
            targetAccount: tx.targetAccount,
            sourceAccount: namaBaru.trim(),
            manualSource: tx.manualSource,
            amount: tx.amount,
            adminFee: tx.adminFee,
            timestamp: tx.timestamp,
            note: tx.note?.replaceAll(namaLama, namaBaru),
            ku: tx.ku,
            kode: tx.kode,
          );
        }
      }

      // Cari transaksi pemasukan utama pos Uangku ini
      final txIndex = data.transactions.indexWhere((tx) =>
          tx.isPemasukan &&
          (tx.manualSource?.trim().toLowerCase() ==
                  namaBaru.trim().toLowerCase() ||
              tx.manualSource?.trim().toLowerCase() ==
                  namaLama.trim().toLowerCase() ||
              tx.title.trim().toLowerCase() ==
                  namaBaru.trim().toLowerCase() ||
              tx.title.trim().toLowerCase() ==
                  namaLama.trim().toLowerCase() ||
              tx.note?.trim().toLowerCase() ==
                  'pemasukan uangku: ${namaLama.trim().toLowerCase()}' ||
              tx.note?.trim().toLowerCase() ==
                  'pemasukan uangku: ${namaBaru.trim().toLowerCase()}'));

      if (txIndex != -1) {
        final existingTx = data.transactions[txIndex];
        final autoKode = PribadiTransaction.resolveKodeFromText(
          namaBaru,
          customRules: data.customKodeRules,
          type: existingTx.type,
        );
        final autoKu = PribadiTransaction.resolveKuFromText(
          namaBaru,
          customRules: data.customKodeRules,
        );

        data.transactions[txIndex] = PribadiTransaction(
          id: existingTx.id,
          title: namaBaru,
          type: existingTx.type,
          targetAccount: namaBaru.trim(),
          sourceAccount: existingTx.sourceAccount,
          manualSource: namaBaru.trim(),
          amount: jumlahBaru,
          adminFee: existingTx.adminFee,
          timestamp: tanggalCairBaru ?? existingTx.timestamp,
          note: 'Pemasukan Uangku: $namaBaru',
          ku: autoKu != '-' ? autoKu : existingTx.ku,
          kode: autoKode != '-' ? autoKode : existingTx.kode,
        );
      } else if (jumlahBaru > 0) {
        await recordPemasukanFromUangku(
          nama: namaBaru,
          nominal: jumlahBaru,
          date: tanggalCairBaru,
          selectedMonth: selectedMonth,
          keterangan: namaBaru,
        );
      }

      await savePribadiData(oldMonthKey, data);
    } else {
      // Jika tanggal cair berpindah bulan
      final oldData = await loadPribadiData(oldMonthKey);
      oldData.posDanaList.removeWhere(
        (p) => p.nama.trim().toLowerCase() == namaLama.trim().toLowerCase(),
      );

      final txIndex = oldData.transactions.indexWhere((tx) =>
          tx.isPemasukan &&
          (tx.manualSource?.trim().toLowerCase() ==
                  namaLama.trim().toLowerCase() ||
              tx.title.trim().toLowerCase() ==
                  namaLama.trim().toLowerCase() ||
              tx.note?.trim().toLowerCase() ==
                  'pemasukan uangku: ${namaLama.trim().toLowerCase()}'));

      if (txIndex != -1) {
        oldData.transactions.removeAt(txIndex);
      }
      await savePribadiData(oldMonthKey, oldData);

      // Catat di bulan baru
      await recordPemasukanFromUangku(
        nama: namaBaru,
        nominal: jumlahBaru,
        date: tanggalCairBaru,
        selectedMonth: selectedMonth,
        keterangan: namaBaru,
      );
    }
  }

  /// Sinkronisasi saat pos Uangku dihapus.
  /// Menghapus Pos Dana & transaksi pemasukan terkait dari Keuangan Pribadi.
  static Future<void> syncHapusUangku({
    required String nama,
    required int jumlah,
    DateTime? tanggalCair,
    DateTime? selectedMonth,
  }) async {
    final monthKey = getMonthKey(tanggalCair, selectedMonth);
    final data = await loadPribadiData(monthKey);

    // Hapus Pos Dana yang bersangkutan
    data.posDanaList.removeWhere(
      (p) => p.nama.trim().toLowerCase() == nama.trim().toLowerCase(),
    );

    // Cari seluruh transaksi pemasukan yang berasal dari pos Uangku ini
    final matchingIndices = <int>[];
    for (int i = 0; i < data.transactions.length; i++) {
      final tx = data.transactions[i];
      if (tx.isPemasukan &&
          (tx.manualSource?.trim().toLowerCase() ==
                  nama.trim().toLowerCase() ||
              tx.title.trim().toLowerCase() == nama.trim().toLowerCase() ||
              tx.targetAccount?.trim().toLowerCase() ==
                  nama.trim().toLowerCase() ||
              tx.note?.trim().toLowerCase() ==
                  'pemasukan uangku: ${nama.trim().toLowerCase()}')) {
        matchingIndices.add(i);
      }
    }

    if (matchingIndices.isNotEmpty) {
      for (final idx in matchingIndices.reversed) {
        data.transactions.removeAt(idx);
      }
    }

    await savePribadiData(monthKey, data);
  }

  /// Sinkronisasi dua arah: Simpan penambahan Pos Dana dari Keuangan Pribadi ke Uangku
  static Future<void> syncAddPosDanaToUangku({
    required String monthKey,
    required String nama,
    required int saldo,
  }) async {
    final uList = await loadUangkuList(monthKey);
    final idx = uList.indexWhere(
      (u) => u.nama.trim().toLowerCase() == nama.trim().toLowerCase(),
    );
    if (idx == -1) {
      uList.add(Uangku(nama.trim(), saldo));
      await saveUangkuList(monthKey, uList);
    }
  }

  /// Sinkronisasi dua arah: Simpan edit Pos Dana dari Keuangan Pribadi ke Uangku
  static Future<void> syncEditPosDanaToUangku({
    required String monthKey,
    required String namaLama,
    required String namaBaru,
    required int saldoBaru,
  }) async {
    final uList = await loadUangkuList(monthKey);
    final idx = uList.indexWhere(
      (u) => u.nama.trim().toLowerCase() == namaLama.trim().toLowerCase(),
    );
    if (idx != -1) {
      uList[idx] = uList[idx].copyWith(
        nama: namaBaru.trim(),
        jumlah: saldoBaru,
      );
      await saveUangkuList(monthKey, uList);
    } else {
      uList.add(Uangku(namaBaru.trim(), saldoBaru));
      await saveUangkuList(monthKey, uList);
    }
  }

  /// Sinkronisasi dua arah: Simpan penghapusan Pos Dana dari Keuangan Pribadi ke Uangku
  static Future<void> syncHapusPosDanaToUangku({
    required String monthKey,
    required String nama,
  }) async {
    final uList = await loadUangkuList(monthKey);
    uList.removeWhere(
      (u) => u.nama.trim().toLowerCase() == nama.trim().toLowerCase(),
    );
    await saveUangkuList(monthKey, uList);
  }
}
