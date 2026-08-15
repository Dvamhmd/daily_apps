import 'dart:convert';
import 'package:daily_apps/models/model_riwayat.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RiwayatService {
  static const String _storageKey = 'riwayat_keuangan';
  static int _counter = 0;

  /// Helper untuk merapikan kapitalisasi nama
  static String capitalize(String text) {
    if (text.trim().isEmpty) return text;
    return text
        .trim()
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
  }

  /// Mengambil semua riwayat dari SharedPreferences (terbaru di atas)
  static Future<List<ModelRiwayat>> getRiwayat() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_storageKey) ?? [];
    return data.map((item) => ModelRiwayat.fromJson(jsonDecode(item))).toList();
  }

  /// Menyimpan satu catatan riwayat baru
  static Future<void> catatRiwayat({
    required String kategori,
    required String perubahan,
    required String tipe,
    int? nominal,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_storageKey) ?? [];

    final baru = ModelRiwayat(
      id: '${DateTime.now().microsecondsSinceEpoch}_${++_counter}',
      datetime: DateTime.now(),
      kategori: kategori,
      perubahan: perubahan,
      tipe: tipe,
      nominal: nominal,
    );

    // Sisipkan di posisi pertama agar riwayat terbaru tampil di atas
    data.insert(0, jsonEncode(baru.toJson()));
    await prefs.setStringList(_storageKey, data);
  }

  /// Catat saat menambah Tagihan
  static Future<void> catatTambahTagihan(String nama, int jumlah) async {
    final namaFormat = capitalize(nama);
    final jumlahFormat = RupiahFormatter.format(jumlah);
    await catatRiwayat(
      kategori: 'Tagihan',
      perubahan: '$namaFormat $jumlahFormat ditambahkan ke tagihan',
      tipe: 'tambah',
      nominal: jumlah,
    );
  }

  /// Catat saat menghapus Tagihan
  static Future<void> catatHapusTagihan(String nama, int jumlah) async {
    final namaFormat = capitalize(nama);
    final jumlahFormat = RupiahFormatter.format(jumlah);
    await catatRiwayat(
      kategori: 'Tagihan',
      perubahan: '$namaFormat $jumlahFormat dihapus dari tagihan',
      tipe: 'hapus',
      nominal: jumlah,
    );
  }

  /// Catat saat mengubah Tagihan
  static Future<void> catatEditTagihan({
    required String namaLama,
    required int jumlahLama,
    required String namaBaru,
    required int jumlahBaru,
  }) async {
    final namaLamaFormat = capitalize(namaLama);
    final namaBaruFormat = capitalize(namaBaru);

    if (namaLamaFormat == namaBaruFormat && jumlahLama == jumlahBaru) {
      return; // Tidak ada perubahan
    }

    if (namaLamaFormat == namaBaruFormat) {
      if (jumlahBaru < jumlahLama) {
        final selisih = jumlahLama - jumlahBaru;
        final selisihFormat = RupiahFormatter.format(selisih);
        await catatRiwayat(
          kategori: 'Tagihan',
          perubahan: '$namaBaruFormat $selisihFormat dikurangi dari tagihan',
          tipe: 'kurang',
          nominal: selisih,
        );
      } else {
        final selisih = jumlahBaru - jumlahLama;
        final selisihFormat = RupiahFormatter.format(selisih);
        await catatRiwayat(
          kategori: 'Tagihan',
          perubahan: '$namaBaruFormat $selisihFormat ditambahkan ke tagihan',
          tipe: 'tambah',
          nominal: selisih,
        );
      }
    } else if (jumlahLama == jumlahBaru) {
      await catatRiwayat(
        kategori: 'Tagihan',
        perubahan: '$namaLamaFormat diubah namanya menjadi $namaBaruFormat',
        tipe: 'edit',
        nominal: jumlahBaru,
      );
    } else {
      if (jumlahBaru < jumlahLama) {
        final selisih = jumlahLama - jumlahBaru;
        final selisihFormat = RupiahFormatter.format(selisih);
        await catatRiwayat(
          kategori: 'Tagihan',
          perubahan:
              '$namaLamaFormat diubah menjadi $namaBaruFormat ($selisihFormat dikurangi dari tagihan)',
          tipe: 'kurang',
          nominal: selisih,
        );
      } else {
        final selisih = jumlahBaru - jumlahLama;
        final selisihFormat = RupiahFormatter.format(selisih);
        await catatRiwayat(
          kategori: 'Tagihan',
          perubahan:
              '$namaLamaFormat diubah menjadi $namaBaruFormat ($selisihFormat ditambahkan ke tagihan)',
          tipe: 'tambah',
          nominal: selisih,
        );
      }
    }
  }

  /// Catat saat menambah Uangku
  static Future<void> catatTambahUangku(String nama, int jumlah) async {
    final namaFormat = capitalize(nama);
    final jumlahFormat = RupiahFormatter.format(jumlah);
    await catatRiwayat(
      kategori: 'Uangku',
      perubahan: '$namaFormat $jumlahFormat ditambahkan ke uangku',
      tipe: 'tambah',
      nominal: jumlah,
    );
  }

  /// Catat saat menghapus Uangku
  static Future<void> catatHapusUangku(String nama, int jumlah) async {
    final namaFormat = capitalize(nama);
    final jumlahFormat = RupiahFormatter.format(jumlah);
    await catatRiwayat(
      kategori: 'Uangku',
      perubahan: '$namaFormat $jumlahFormat dihapus dari uangku',
      tipe: 'hapus',
      nominal: jumlah,
    );
  }

  /// Catat saat mengubah Uangku
  static Future<void> catatEditUangku({
    required String namaLama,
    required int jumlahLama,
    required String namaBaru,
    required int jumlahBaru,
  }) async {
    final namaLamaFormat = capitalize(namaLama);
    final namaBaruFormat = capitalize(namaBaru);

    if (namaLamaFormat == namaBaruFormat && jumlahLama == jumlahBaru) {
      return; // Tidak ada perubahan
    }

    if (namaLamaFormat == namaBaruFormat) {
      if (jumlahBaru < jumlahLama) {
        final selisih = jumlahLama - jumlahBaru;
        final selisihFormat = RupiahFormatter.format(selisih);
        await catatRiwayat(
          kategori: 'Uangku',
          perubahan: '$namaBaruFormat $selisihFormat dikurangi dari uangku',
          tipe: 'kurang',
          nominal: selisih,
        );
      } else {
        final selisih = jumlahBaru - jumlahLama;
        final selisihFormat = RupiahFormatter.format(selisih);
        await catatRiwayat(
          kategori: 'Uangku',
          perubahan: '$namaBaruFormat $selisihFormat ditambahkan ke uangku',
          tipe: 'tambah',
          nominal: selisih,
        );
      }
    } else if (jumlahLama == jumlahBaru) {
      await catatRiwayat(
        kategori: 'Uangku',
        perubahan: '$namaLamaFormat diubah namanya menjadi $namaBaruFormat',
        tipe: 'edit',
        nominal: jumlahBaru,
      );
    } else {
      if (jumlahBaru < jumlahLama) {
        final selisih = jumlahLama - jumlahBaru;
        final selisihFormat = RupiahFormatter.format(selisih);
        await catatRiwayat(
          kategori: 'Uangku',
          perubahan:
              '$namaLamaFormat diubah menjadi $namaBaruFormat ($selisihFormat dikurangi dari uangku)',
          tipe: 'kurang',
          nominal: selisih,
        );
      } else {
        final selisih = jumlahBaru - jumlahLama;
        final selisihFormat = RupiahFormatter.format(selisih);
        await catatRiwayat(
          kategori: 'Uangku',
          perubahan:
              '$namaLamaFormat diubah menjadi $namaBaruFormat ($selisihFormat ditambahkan ke uangku)',
          tipe: 'tambah',
          nominal: selisih,
        );
      }
    }
  }

  /// Catat saat menambah Tabungan
  static Future<void> catatTambahTabungan(String nama, int jumlah) async {
    final namaFormat = capitalize(nama);
    final jumlahFormat = RupiahFormatter.format(jumlah);
    await catatRiwayat(
      kategori: 'Tabungan',
      perubahan: '$namaFormat $jumlahFormat ditambahkan ke tabungan',
      tipe: 'tambah',
      nominal: jumlah,
    );
  }

  /// Catat saat menghapus Tabungan
  static Future<void> catatHapusTabungan(String nama, int jumlah) async {
    final namaFormat = capitalize(nama);
    final jumlahFormat = RupiahFormatter.format(jumlah);
    await catatRiwayat(
      kategori: 'Tabungan',
      perubahan: '$namaFormat $jumlahFormat dihapus dari tabungan',
      tipe: 'hapus',
      nominal: jumlah,
    );
  }

  /// Catat saat mengubah Tabungan
  static Future<void> catatEditTabungan({
    required String namaLama,
    required int jumlahLama,
    required String namaBaru,
    required int jumlahBaru,
  }) async {
    final namaLamaFormat = capitalize(namaLama);
    final namaBaruFormat = capitalize(namaBaru);

    if (namaLamaFormat == namaBaruFormat && jumlahLama == jumlahBaru) {
      return; // Tidak ada perubahan
    }

    if (namaLamaFormat == namaBaruFormat) {
      if (jumlahBaru < jumlahLama) {
        final selisih = jumlahLama - jumlahBaru;
        final selisihFormat = RupiahFormatter.format(selisih);
        await catatRiwayat(
          kategori: 'Tabungan',
          perubahan: '$namaBaruFormat $selisihFormat dikurangi dari tabungan',
          tipe: 'kurang',
          nominal: selisih,
        );
      } else {
        final selisih = jumlahBaru - jumlahLama;
        final selisihFormat = RupiahFormatter.format(selisih);
        await catatRiwayat(
          kategori: 'Tabungan',
          perubahan: '$namaBaruFormat $selisihFormat ditambahkan ke tabungan',
          tipe: 'tambah',
          nominal: selisih,
        );
      }
    } else if (jumlahLama == jumlahBaru) {
      await catatRiwayat(
        kategori: 'Tabungan',
        perubahan: '$namaLamaFormat diubah namanya menjadi $namaBaruFormat',
        tipe: 'edit',
        nominal: jumlahBaru,
      );
    } else {
      if (jumlahBaru < jumlahLama) {
        final selisih = jumlahLama - jumlahBaru;
        final selisihFormat = RupiahFormatter.format(selisih);
        await catatRiwayat(
          kategori: 'Tabungan',
          perubahan:
              '$namaLamaFormat diubah menjadi $namaBaruFormat ($selisihFormat dikurangi dari tabungan)',
          tipe: 'kurang',
          nominal: selisih,
        );
      } else {
        final selisih = jumlahBaru - jumlahLama;
        final selisihFormat = RupiahFormatter.format(selisih);
        await catatRiwayat(
          kategori: 'Tabungan',
          perubahan:
              '$namaLamaFormat diubah menjadi $namaBaruFormat ($selisihFormat ditambahkan ke tabungan)',
          tipe: 'tambah',
          nominal: selisih,
        );
      }
    }
  }

  /// Menghapus satu item riwayat berdasarkan ID
  static Future<void> hapusItemRiwayat(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_storageKey) ?? [];
    data.removeWhere((item) {
      final map = jsonDecode(item);
      return map['id'] == id;
    });
    await prefs.setStringList(_storageKey, data);
  }

  /// Menghapus seluruh riwayat
  static Future<void> hapusSemuaRiwayat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
