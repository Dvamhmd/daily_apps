class ModelRiwayat {
  final String id;
  final DateTime datetime;
  final String kategori; // 'Tagihan' atau 'Uangku'
  final String perubahan; // Deskripsi perubahan
  final String tipe; // 'tambah', 'kurang', 'edit', 'hapus'
  final int? nominal; // Nominal selisih atau total jika ada

  ModelRiwayat({
    required this.id,
    required this.datetime,
    required this.kategori,
    required this.perubahan,
    required this.tipe,
    this.nominal,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'datetime': datetime.toIso8601String(),
        'kategori': kategori,
        'perubahan': perubahan,
        'tipe': tipe,
        'nominal': nominal,
      };

  factory ModelRiwayat.fromJson(Map<String, dynamic> json) {
    return ModelRiwayat(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      datetime: json['datetime'] != null
          ? DateTime.tryParse(json['datetime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      kategori: json['kategori']?.toString() ?? '',
      perubahan: json['perubahan']?.toString() ?? '',
      tipe: json['tipe']?.toString() ?? 'info',
      nominal: (json['nominal'] as num?)?.toInt(),
    );
  }
}
