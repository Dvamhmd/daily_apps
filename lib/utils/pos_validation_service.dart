import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PosValidationService {
  /// Memeriksa apakah nama pos dana sudah digunakan di Uangku, Tagihanku, atau Tabunganku.
  /// Mengembalikan pesan error deskriptif jika nama sudah terdaftar, atau null jika valid.
  static Future<String?> checkDuplicateName({
    required String newName,
    String? currentName,
  }) async {
    final cleanNewName = newName.trim();
    if (cleanNewName.isEmpty) return null;

    final cleanCurrentName = currentName?.trim().toLowerCase();
    final lowerNewName = cleanNewName.toLowerCase();

    // Jika sedang mode edit dan nama tidak diubah sama sekali, maka valid
    if (cleanCurrentName != null && cleanCurrentName == lowerNewName) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();

    // 1. Cek di Uangku (key: 'uangku' serta fallback key bulanan terbaru)
    final rawUangku = prefs.getStringList('uangku') ?? [];
    for (final itemStr in rawUangku) {
      try {
        final map = jsonDecode(itemStr) as Map<String, dynamic>;
        final nama = (map['nama'] ?? '').toString().trim();
        if (nama.toLowerCase() == lowerNewName) {
          if (cleanCurrentName != null && nama.toLowerCase() == cleanCurrentName) {
            continue;
          }
          return 'Nama pos "$cleanNewName" sudah digunakan di Uangku.';
        }
      } catch (_) {}
    }

    // 2. Cek di Tagihanku (key: 'tagihan')
    final rawTagihan = prefs.getStringList('tagihan') ?? [];
    for (final itemStr in rawTagihan) {
      try {
        final map = jsonDecode(itemStr) as Map<String, dynamic>;
        final nama = (map['nama'] ?? '').toString().trim();
        if (nama.toLowerCase() == lowerNewName) {
          if (cleanCurrentName != null && nama.toLowerCase() == cleanCurrentName) {
            continue;
          }
          return 'Nama pos "$cleanNewName" sudah digunakan di Tagihanku.';
        }
      } catch (_) {}
    }

    // 3. Cek di Tabunganku (key: 'tabungan')
    final rawTabungan = prefs.getStringList('tabungan') ?? [];
    for (final itemStr in rawTabungan) {
      try {
        final map = jsonDecode(itemStr) as Map<String, dynamic>;
        final nama = (map['nama'] ?? '').toString().trim();
        if (nama.toLowerCase() == lowerNewName) {
          if (cleanCurrentName != null && nama.toLowerCase() == cleanCurrentName) {
            continue;
          }
          return 'Nama pos "$cleanNewName" sudah digunakan di Tabunganku.';
        }
      } catch (_) {}
    }

    return null; // Nama unik dan valid
  }
}
