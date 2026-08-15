class Tabungan {
  final String nama;
  final int jumlah;

  Tabungan(this.nama, this.jumlah);

  Map<String, dynamic> toJson() => {
        'nama': nama,
        'jumlah': jumlah,
      };

  factory Tabungan.fromJson(Map<String, dynamic> json) {
    return Tabungan(json['nama'], json['jumlah']);
  }
}
