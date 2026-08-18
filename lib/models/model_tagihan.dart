import 'package:intl/intl.dart';

class Tagihan {
  final String nama;
  final int jumlah;
  final DateTime? deadline;
  final bool isLunas;
  final DateTime? tanggalLunas;
  final String? dibayarDari;

  Tagihan(
    this.nama,
    this.jumlah, {
    this.deadline,
    this.isLunas = false,
    this.tanggalLunas,
    this.dibayarDari,
  });

  Map<String, dynamic> toJson() => {
        'nama': nama,
        'jumlah': jumlah,
        'deadline': deadline?.toIso8601String(),
        'isLunas': isLunas,
        'tanggalLunas': tanggalLunas?.toIso8601String(),
        'dibayarDari': dibayarDari,
      };

  factory Tagihan.fromJson(Map<String, dynamic> json) {
    return Tagihan(
      json['nama']?.toString() ?? '',
      (json['jumlah'] as num?)?.toInt() ?? 0,
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'].toString())
          : null,
      isLunas: json['isLunas'] == true,
      tanggalLunas: json['tanggalLunas'] != null
          ? DateTime.tryParse(json['tanggalLunas'].toString())
          : null,
      dibayarDari: json['dibayarDari']?.toString(),
    );
  }

  Tagihan copyWith({
    String? nama,
    int? jumlah,
    DateTime? deadline,
    bool? isLunas,
    DateTime? tanggalLunas,
    String? dibayarDari,
  }) {
    return Tagihan(
      nama ?? this.nama,
      jumlah ?? this.jumlah,
      deadline: deadline ?? this.deadline,
      isLunas: isLunas ?? this.isLunas,
      tanggalLunas: tanggalLunas ?? this.tanggalLunas,
      dibayarDari: dibayarDari ?? this.dibayarDari,
    );
  }

  String? get formattedDeadline {
    if (deadline == null) return null;
    final dateStr = DateFormat('dd/MM/yy').format(deadline!);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(deadline!.year, deadline!.month, deadline!.day);
    final diff = target.difference(today).inDays;

    if (diff > 0) {
      return '$dateStr ($diff hari)';
    } else if (diff == 0) {
      return '$dateStr (Hari ini)';
    } else {
      return '$dateStr (Lewat ${-diff} hari)';
    }
  }
}


