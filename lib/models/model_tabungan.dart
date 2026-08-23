class Tabungan {
  final String nama;
  final int jumlah;
  final int? targetNominal;
  final DateTime? targetDate;

  Tabungan(
    this.nama,
    this.jumlah, {
    this.targetNominal,
    this.targetDate,
  });

  Map<String, dynamic> toJson() => {
        'nama': nama,
        'jumlah': jumlah,
        'targetNominal': targetNominal,
        'targetDate': targetDate?.toIso8601String(),
      };

  factory Tabungan.fromJson(Map<String, dynamic> json) {
    return Tabungan(
      json['nama']?.toString() ?? '',
      (json['jumlah'] as num?)?.toInt() ?? 0,
      targetNominal: json['targetNominal'] != null
          ? (json['targetNominal'] as num).toInt()
          : null,
      targetDate: json['targetDate'] != null
          ? DateTime.tryParse(json['targetDate'].toString())
          : null,
    );
  }

  double get progress {
    if (targetNominal == null || targetNominal! <= 0) return 0.0;
    final val = jumlah / targetNominal!;
    return val > 1.0 ? 1.0 : (val < 0.0 ? 0.0 : val);
  }

  int get percentage {
    if (targetNominal == null || targetNominal! <= 0) return 0;
    return ((jumlah / targetNominal!) * 100).round();
  }

  int get sisaTarget {
    if (targetNominal == null) return 0;
    final sisa = targetNominal! - jumlah;
    return sisa > 0 ? sisa : 0;
  }

  int? get sisaHari {
    if (targetDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate!.year, targetDate!.month, targetDate!.day);
    return target.difference(today).inDays;
  }
}

