class Tagihan {
  final String nama;
  final int jumlah;

  Tagihan(this.nama, this.jumlah);

  Map<String, dynamic> toJson() => {
    'nama': nama,
    'jumlah': jumlah,
  };

  factory Tagihan.fromJson(Map<String, dynamic> json) {
    return Tagihan(json['nama'], json['jumlah']);
  }
}
