import 'package:intl/intl.dart';

class Uangku {
  final String nama;
  final int jumlah;
  final DateTime? tanggalCair;

  Uangku(
    this.nama,
    this.jumlah, {
    this.tanggalCair,
  });

  Map<String, dynamic> toJson() => {
        'nama': nama,
        'jumlah': jumlah,
        'tanggalCair': tanggalCair?.toIso8601String(),
      };

  factory Uangku.fromJson(Map<String, dynamic> json) {
    return Uangku(
      json['nama']?.toString() ?? '',
      (json['jumlah'] as num?)?.toInt() ?? 0,
      tanggalCair: json['tanggalCair'] != null
          ? DateTime.tryParse(json['tanggalCair'].toString())
          : null,
    );
  }

  Uangku copyWith({
    String? nama,
    int? jumlah,
    DateTime? tanggalCair,
    bool clearTanggalCair = false,
  }) {
    return Uangku(
      nama ?? this.nama,
      jumlah ?? this.jumlah,
      tanggalCair:
          clearTanggalCair ? null : (tanggalCair ?? this.tanggalCair),
    );
  }

  /// Jika tidak ada tanggal yang diinput, otomatis dianggap sudah cair (opsional).
  /// Jika ada tanggal, dihitung sudah cair jika tanggal <= hari ini.
  bool get isCair {
    if (tanggalCair == null) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target =
        DateTime(tanggalCair!.year, tanggalCair!.month, tanggalCair!.day);
    return target.isBefore(today) || target.isAtSameMomentAs(today);
  }

  String? get formattedTanggalCair {
    if (tanggalCair == null) return null;
    return DateFormat('dd/MM/yy').format(tanggalCair!);
  }
}
