import 'package:daily_apps/models/model_struktur.dart'
    show CustomKodeRule, OnHandDebit, OnHandCash;
export 'package:daily_apps/models/model_struktur.dart'
    show CustomKodeRule, OnHandDebit, OnHandCash;

class RekeningPribadi {
  String bankName;
  String accountNumber;
  String accountHolder;
  int balance;

  RekeningPribadi({
    this.bankName = 'BCA',
    this.accountNumber = '',
    this.accountHolder = '',
    this.balance = 0,
  });

  Map<String, dynamic> toJson() => {
        'bankName': bankName,
        'accountNumber': accountNumber,
        'accountHolder': accountHolder,
        'balance': balance,
      };

  factory RekeningPribadi.fromJson(Map<String, dynamic> json) {
    return RekeningPribadi(
      bankName: json['bankName'] as String? ?? 'BCA',
      accountNumber: json['accountNumber'] as String? ?? '',
      accountHolder: json['accountHolder'] as String? ?? '',
      balance: (json['balance'] as num?)?.toInt() ?? 0,
    );
  }
}

class PersonalDefaultRules {
  static List<CustomKodeRule> defaultRules() => [
        ...defaultPemasukanRules(),
        ...defaultPengeluaranRules(),
      ];

  static List<CustomKodeRule> defaultPemasukanRules() => [
        CustomKodeRule(keyword: 'gaji', kode: 'Pemasukan Gaji', type: 'pemasukan'),
        CustomKodeRule(keyword: 'salary', kode: 'Pemasukan Gaji', type: 'pemasukan'),
        CustomKodeRule(keyword: 'bonus', kode: 'Bonus & THR', type: 'pemasukan'),
        CustomKodeRule(keyword: 'freelance', kode: 'Pendapatan Tambahan', type: 'pemasukan'),
        CustomKodeRule(keyword: 'investasi', kode: 'Investasi & Saham', type: 'pemasukan'),
      ];

  static List<CustomKodeRule> defaultPengeluaranRules() => [
        CustomKodeRule(keyword: 'makan', kode: 'Makanan & Minuman', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'restoran', kode: 'Makanan & Minuman', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'kafe', kode: 'Makanan & Minuman', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'kopi', kode: 'Makanan & Minuman', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'grabfood', kode: 'Makanan & Minuman', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'gofood', kode: 'Makanan & Minuman', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'shopeefood', kode: 'Makanan & Minuman', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'belanja', kode: 'Belanja & Kebutuhan', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'supermarket', kode: 'Belanja & Kebutuhan', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'minimarket', kode: 'Belanja & Kebutuhan', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'indomaret', kode: 'Belanja & Kebutuhan', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'alfamart', kode: 'Belanja & Kebutuhan', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'bensin', kode: 'Transportasi', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'pertalite', kode: 'Transportasi', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'pertamax', kode: 'Transportasi', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'parkir', kode: 'Transportasi', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'tol', kode: 'Transportasi', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'gojek', kode: 'Transportasi', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'grab', kode: 'Transportasi', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'listrik', kode: 'Tagihan & Utilitas', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'pln', kode: 'Tagihan & Utilitas', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'air', kode: 'Tagihan & Utilitas', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'pdam', kode: 'Tagihan & Utilitas', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'internet', kode: 'Komunikasi & Kuota', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'wifi', kode: 'Komunikasi & Kuota', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'pulsa', kode: 'Komunikasi & Kuota', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'kuota', kode: 'Komunikasi & Kuota', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'sewa', kode: 'Tempat Tinggal & Kos', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'kos', kode: 'Tempat Tinggal & Kos', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'kesehatan', kode: 'Kesehatan & Obat', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'obat', kode: 'Kesehatan & Obat', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'dokter', kode: 'Kesehatan & Obat', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'hiburan', kode: 'Hiburan & Hobi', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'bioskop', kode: 'Hiburan & Hobi', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'game', kode: 'Hiburan & Hobi', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'sedekah', kode: 'Sosial & Donasi', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'infaq', kode: 'Sosial & Donasi', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'zakat', kode: 'Sosial & Donasi', type: 'pengeluaran'),
        CustomKodeRule(keyword: 'admin', kode: 'Biaya Admin Bank', type: 'pengeluaran'),
      ];
}

class PribadiTransaction {
  final String id;
  final String title;
  final String type; // 'transfer_debit', 'tarik_tunai', 'pemasukan', 'pengeluaran', 'setor_tunai', 'transfer_rekening'
  final String? sourceAccount; // 'rekening', 'debit', 'cash'
  final String? targetAccount; // 'rekening', 'debit', 'cash'
  final String? manualSource; // Asal dana untuk pemasukan (cth: 'Gaji Bulanan', 'Bonus')
  final int amount;
  final int adminFee;
  final DateTime timestamp;
  final String? note;
  final String? ku;
  final String? kode; // Kategori

  PribadiTransaction({
    required this.id,
    required this.title,
    required this.type,
    this.sourceAccount,
    this.targetAccount,
    this.manualSource,
    required this.amount,
    this.adminFee = 0,
    DateTime? timestamp,
    this.note,
    this.ku,
    this.kode,
  }) : timestamp = timestamp ?? DateTime.now();

  int get totalDeduction => amount + adminFee;

  bool get isPemasukan => type == 'pemasukan';
  bool get isPengeluaran => type == 'pengeluaran';
  bool get isAlokasiInternal => !isPemasukan && !isPengeluaran;

  /// Helper untuk auto-resolve KU transaksi berdasarkan kata kunci teks keterangan/judul dan daftar kustomisasi KU
  static String resolveKuFromText(String text,
      {List<CustomKodeRule>? customRules}) {
    if (text.trim().isEmpty) return '-';
    final lower = text.toLowerCase();
    final rules = (customRules ?? []).where((r) => r.type == 'ku').toList();
    if (rules.isEmpty) return '-';

    // Urutkan aturan dari keyword terpanjang ke terpendek agar match spesifik didahulukan
    final sortedRules = List<CustomKodeRule>.from(rules)
      ..sort((a, b) => b.keyword.length.compareTo(a.keyword.length));

    for (final rule in sortedRules) {
      final key = rule.keyword.trim().toLowerCase();
      if (key.isNotEmpty && lower.contains(key)) {
        return rule.kode.trim();
      }
    }
    return '-';
  }

  /// Helper untuk auto-resolve Kategori transaksi berdasarkan kata kunci teks keterangan/judul dan daftar kustomisasi Kategori
  /// [type] dapat diisi 'pemasukan' atau 'pengeluaran' agar kata kunci yang sama tidak bertabrakan/nyangkut.
  static String resolveKodeFromText(String text,
      {List<CustomKodeRule>? customRules, String? type}) {
    if (text.trim().isEmpty) return '-';
    final lower = text.toLowerCase();
    final rules = (customRules ?? []).where((r) {
      if (r.type == 'ku') return false;
      if (type != null && type.isNotEmpty) {
        if (type == 'pemasukan') {
          return r.type == 'pemasukan' || r.type == 'kategori_pemasukan';
        }
        if (type == 'pengeluaran') {
          return r.type == 'pengeluaran' ||
              r.type == 'kategori_pengeluaran' ||
              r.type == 'kategori';
        }
        return r.type == type;
      }
      return true;
    }).toList();
    if (rules.isEmpty) return '-';

    // Urutkan aturan dari keyword terpanjang ke terpendek agar match spesifik didahulukan
    final sortedRules = List<CustomKodeRule>.from(rules)
      ..sort((a, b) => b.keyword.length.compareTo(a.keyword.length));

    for (final rule in sortedRules) {
      final key = rule.keyword.trim().toLowerCase();
      if (key.isNotEmpty && lower.contains(key)) {
        return rule.kode.trim();
      }
    }
    return '-';
  }

  static String resolveKategoriFromText(String text,
          {List<CustomKodeRule>? customRules, String? type}) =>
      resolveKodeFromText(text, customRules: customRules, type: type);

  /// Getter untuk mendapatkan KU transaksi baik yang disimpan atau auto-resolved
  String getDisplayKu({List<CustomKodeRule>? customRules}) {
    if (ku != null && ku!.trim().isNotEmpty && ku!.trim() != '-') {
      return ku!.trim();
    }
    if (note != null && note!.trim().isNotEmpty) {
      final autoFromNote =
          resolveKuFromText(note!, customRules: customRules);
      if (autoFromNote != '-') return autoFromNote;
    }
    final autoFromTitle =
        resolveKuFromText(title, customRules: customRules);
    if (autoFromTitle != '-') return autoFromTitle;
    if (manualSource != null && manualSource!.trim().isNotEmpty) {
      final autoFromSource =
          resolveKuFromText(manualSource!, customRules: customRules);
      if (autoFromSource != '-') return autoFromSource;
    }
    return '-';
  }

  String get displayKu => getDisplayKu();

  /// Getter untuk mendapatkan Kategori transaksi baik yang disimpan atau auto-resolved
  /// Otomatis memfilter berdasarkan tipe transaksi (pemasukan vs pengeluaran) agar tidak bertabrakan
  String getDisplayKode({List<CustomKodeRule>? customRules}) {
    if (kode != null && kode!.trim().isNotEmpty && kode!.trim() != '-') {
      return kode!.trim();
    }
    final txType = isPemasukan
        ? 'pemasukan'
        : (isPengeluaran ? 'pengeluaran' : null);

    if (note != null && note!.trim().isNotEmpty) {
      final autoFromNote =
          resolveKodeFromText(note!, customRules: customRules, type: txType);
      if (autoFromNote != '-') return autoFromNote;
    }
    final autoFromTitle =
        resolveKodeFromText(title, customRules: customRules, type: txType);
    if (autoFromTitle != '-') return autoFromTitle;
    if (manualSource != null && manualSource!.trim().isNotEmpty) {
      final autoFromSource =
          resolveKodeFromText(manualSource!, customRules: customRules, type: txType);
      if (autoFromSource != '-') return autoFromSource;
    }
    return '-';
  }

  String get displayKode => getDisplayKode();
  String get displayKategori => getDisplayKode();

  bool isDPTransaction({List<CustomKodeRule>? customRules}) {
    final kd = getDisplayKode(customRules: customRules).toUpperCase();
    if (kd.contains('DP')) return true;
    if (kode != null && kode!.toUpperCase().contains('DP')) return true;
    return false;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'sourceAccount': sourceAccount,
        'targetAccount': targetAccount,
        'manualSource': manualSource,
        'amount': amount,
        'adminFee': adminFee,
        'timestamp': timestamp.toIso8601String(),
        'note': note,
        'ku': ku,
        'kode': kode,
      };

  factory PribadiTransaction.fromJson(Map<String, dynamic> json) {
    return PribadiTransaction(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? 'transfer_debit',
      sourceAccount: json['sourceAccount'] as String?,
      targetAccount: json['targetAccount'] as String?,
      manualSource: json['manualSource'] as String?,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      adminFee: (json['adminFee'] as num?)?.toInt() ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      note: json['note'] as String?,
      ku: json['ku'] as String?,
      kode: json['kode'] as String?,
    );
  }
}

class PosDana {
  String id;
  String nama;
  int balance;
  String? deskripsi;
  String? iconName;
  int? colorValue;

  PosDana({
    required this.id,
    required this.nama,
    this.balance = 0,
    this.deskripsi,
    this.iconName,
    this.colorValue,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'balance': balance,
        'deskripsi': deskripsi,
        'iconName': iconName,
        'colorValue': colorValue,
      };

  factory PosDana.fromJson(Map<String, dynamic> json) {
    return PosDana(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      nama: json['nama'] as String? ?? 'Pos Dana',
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      deskripsi: json['deskripsi'] as String?,
      iconName: json['iconName'] as String?,
      colorValue: (json['colorValue'] as num?)?.toInt(),
    );
  }
}

class PribadiData {
  List<PosDana> posDanaList;
  RekeningPribadi rekeningPribadi;
  OnHandDebit onHandDebit;
  OnHandCash onHandCash;
  List<PribadiTransaction> transactions;
  List<CustomKodeRule> customKodeRules;
  bool isSaldoRekeningUnlocked;

  PribadiData({
    List<PosDana>? posDanaList,
    RekeningPribadi? rekeningPribadi,
    OnHandDebit? onHandDebit,
    OnHandCash? onHandCash,
    List<PribadiTransaction>? transactions,
    List<CustomKodeRule>? customKodeRules,
    bool? isSaldoRekeningUnlocked,
  })  : posDanaList = posDanaList ?? [],
        rekeningPribadi = rekeningPribadi ?? RekeningPribadi(),
        onHandDebit = onHandDebit ?? OnHandDebit(),
        onHandCash = onHandCash ?? OnHandCash(),
        transactions = (transactions ?? [])
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
        customKodeRules = customKodeRules ?? [],
        isSaldoRekeningUnlocked = isSaldoRekeningUnlocked ?? false;

  num get totalOnHand =>
      (onHandDebit.balance < 0 ? 0 : onHandDebit.balance) +
      (onHandCash.balance < 0 ? 0 : onHandCash.balance);

  int get totalPosDana =>
      posDanaList.fold<int>(0, (sum, p) => sum + (p.balance < 0 ? 0 : p.balance));

  num get totalDanaPribadi {
    final val = posDanaList.isNotEmpty
        ? totalPosDana
        : ((rekeningPribadi.balance < 0 ? 0 : rekeningPribadi.balance) +
            totalOnHand);
    return val < 0 ? 0 : val;
  }

  num getTotalPemasukanDP({List<CustomKodeRule>? customRules}) {
    final rules = customRules ?? customKodeRules;
    num sum = 0;
    for (int i = 0; i < transactions.length; i++) {
      final t = transactions[i];
      if (t.isPemasukan && t.isDPTransaction(customRules: rules)) {
        sum += t.amount;
      }
    }
    return sum;
  }

  num get totalPemasukanDP => getTotalPemasukanDP();

  /// Menghitung dana operasional / dana bebas pribadi
  num getTotalDanaOperasional({List<CustomKodeRule>? customRules}) {
    final dp = getTotalPemasukanDP(customRules: customRules);
    final op = totalDanaPribadi - dp;
    return op < 0 ? 0 : op;
  }

  num get totalDanaOperasional => getTotalDanaOperasional();

  int get totalPemasukan {
    int sum = 0;
    for (int i = 0; i < transactions.length; i++) {
      final t = transactions[i];
      if (t.isPemasukan) sum += t.amount;
    }
    return sum;
  }

  int get totalPengeluaran {
    int sum = 0;
    for (int i = 0; i < transactions.length; i++) {
      final t = transactions[i];
      if (t.isPengeluaran) {
        sum += t.amount;
      }
    }
    return sum;
  }

  Map<String, dynamic> toJson() => {
        'posDanaList': posDanaList.map((e) => e.toJson()).toList(),
        'rekeningPribadi': rekeningPribadi.toJson(),
        'onHandDebit': onHandDebit.toJson(),
        'onHandCash': onHandCash.toJson(),
        'transactions': transactions.map((e) => e.toJson()).toList(),
        'customKodeRules': customKodeRules.map((e) => e.toJson()).toList(),
        'isSaldoRekeningUnlocked': isSaldoRekeningUnlocked,
      };

  factory PribadiData.fromJson(Map<String, dynamic> json) {
    final rawPosList = json['posDanaList'] as List<dynamic>?;
    final parsedPosList = rawPosList
            ?.map((e) => PosDana.fromJson(e as Map<String, dynamic>))
            .toList() ??
        <PosDana>[];

    return PribadiData(
      posDanaList: parsedPosList,
      rekeningPribadi: json['rekeningPribadi'] != null
          ? RekeningPribadi.fromJson(
              json['rekeningPribadi'] as Map<String, dynamic>)
          : (json['rekeningStruktur'] != null
              ? RekeningPribadi.fromJson(
                  json['rekeningStruktur'] as Map<String, dynamic>)
              : RekeningPribadi()),
      onHandDebit: json['onHandDebit'] != null
          ? OnHandDebit.fromJson(json['onHandDebit'] as Map<String, dynamic>)
          : OnHandDebit(),
      onHandCash: json['onHandCash'] != null
          ? OnHandCash.fromJson(json['onHandCash'] as Map<String, dynamic>)
          : OnHandCash(),
      transactions: ((json['transactions'] as List<dynamic>?)
              ?.map((e) =>
                  PribadiTransaction.fromJson(e as Map<String, dynamic>))
              .where((t) => t.isPemasukan || t.isPengeluaran)
              .toList() ??
          [])
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
      customKodeRules: (json['customKodeRules'] as List<dynamic>?)
              ?.map(
                  (e) => CustomKodeRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isSaldoRekeningUnlocked:
          json['isSaldoRekeningUnlocked'] as bool? ?? false,
    );
  }
}
