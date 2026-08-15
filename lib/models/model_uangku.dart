class Uangku {
  final String nama;
  final int jumlah;

  Uangku(this.nama, this.jumlah);

  Map<String, dynamic> toJson() => {
    'nama': nama,
    'jumlah': jumlah,
  };

  factory Uangku.fromJson(Map<String, dynamic> json) {
    return Uangku(json['nama'], json['jumlah']);
  }
}
