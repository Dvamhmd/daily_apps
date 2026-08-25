class RekeningStruktur {
  String bankName;
  String accountNumber;
  String accountHolder;
  int balance;

  RekeningStruktur({
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

  factory RekeningStruktur.fromJson(Map<String, dynamic> json) {
    return RekeningStruktur(
      bankName: json['bankName'] as String? ?? 'BCA',
      accountNumber: json['accountNumber'] as String? ?? '',
      accountHolder: json['accountHolder'] as String? ?? '',
      balance: (json['balance'] as num?)?.toInt() ?? 0,
    );
  }
}

class OnHandDebit {
  String bankName;
  String accountNumber;
  String accountHolder;
  int balance;

  OnHandDebit({
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

  factory OnHandDebit.fromJson(Map<String, dynamic> json) {
    return OnHandDebit(
      bankName: json['bankName'] as String? ?? 'BCA',
      accountNumber: json['accountNumber'] as String? ?? '',
      accountHolder: json['accountHolder'] as String? ?? '',
      balance: (json['balance'] as num?)?.toInt() ?? 0,
    );
  }
}

class OnHandCash {
  int balance;

  OnHandCash({
    this.balance = 0,
  });

  Map<String, dynamic> toJson() => {
        'balance': balance,
      };

  factory OnHandCash.fromJson(Map<String, dynamic> json) {
    return OnHandCash(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
    );
  }
}

class CustomKodeRule {
  String id;
  String keyword;
  String kode;
  String type; // 'ku' atau 'kategori'

  CustomKodeRule({
    String? id,
    required this.keyword,
    required this.kode,
    this.type = 'kategori',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'keyword': keyword,
        'kode': kode,
        'type': type,
      };

  factory CustomKodeRule.fromJson(Map<String, dynamic> json) {
    return CustomKodeRule(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      keyword: json['keyword'] as String? ?? '',
      kode: json['kode'] as String? ?? '',
      type: json['type'] as String? ?? 'kategori',
    );
  }

  static List<CustomKodeRule> defaultRules() => generalRules();

  static List<CustomKodeRule> generalRules() => [
        // Aturan KU (26 aturan)
        CustomKodeRule(keyword: 'rapat', kode: 'Sekretaris', type: 'ku'),
        CustomKodeRule(keyword: 'rakor', kode: 'Sekretaris', type: 'ku'),
        CustomKodeRule(keyword: 'rab', kode: 'Sekretaris', type: 'ku'),
        CustomKodeRule(keyword: 'rkub', kode: 'Sekretaris', type: 'ku'),
        CustomKodeRule(keyword: 'bensin', kode: 'Sekretaris', type: 'ku'),
        CustomKodeRule(keyword: 'ATK', kode: 'Sekretaris', type: 'ku'),
        CustomKodeRule(keyword: 'RTK', kode: 'Sekretaris', type: 'ku'),
        CustomKodeRule(keyword: 'simulasi', kode: 'Sekretaris', type: 'ku'),
        CustomKodeRule(keyword: 'admin', kode: 'SDK', type: 'ku'),
        CustomKodeRule(keyword: 'bank', kode: 'SDK', type: 'ku'),
        CustomKodeRule(keyword: 'pulsa', kode: 'SDK', type: 'ku'),
        CustomKodeRule(keyword: 'pembinaan AP', kode: 'SDM', type: 'ku'),
        CustomKodeRule(keyword: 'olahraga', kode: 'SDM', type: 'ku'),
        CustomKodeRule(keyword: 'silah', kode: 'SDM', type: 'ku'),
        CustomKodeRule(keyword: 'Pekabaran', kode: 'Publikasi', type: 'ku'),
        CustomKodeRule(keyword: 'Talwiyah', kode: 'Publikasi', type: 'ku'),
        CustomKodeRule(keyword: 'Pengabaran', kode: 'Publikasi', type: 'ku'),
        CustomKodeRule(keyword: 'pembinaan AB', kode: 'Publikasi', type: 'ku'),
        CustomKodeRule(keyword: 'Pratal', kode: 'Publikasi', type: 'ku'),
        CustomKodeRule(keyword: 'Moral', kode: 'Hukum', type: 'ku'),
        CustomKodeRule(keyword: 'Disiplin', kode: 'Hukum', type: 'ku'),
        CustomKodeRule(keyword: 'MPMD', kode: 'Hukum', type: 'ku'),
        CustomKodeRule(keyword: 'RPM', kode: 'Ekonomi', type: 'ku'),
        CustomKodeRule(keyword: 'Pangan', kode: 'Ekonomi', type: 'ku'),
        CustomKodeRule(keyword: 'Kedaulatan Pangan', kode: 'Ekonomi', type: 'ku'),
        CustomKodeRule(keyword: 'Bibit', kode: 'Ekonomi', type: 'ku'),

        // Aturan Kategori (14 aturan)
        CustomKodeRule(keyword: 'ATK', kode: 'ATK', type: 'kategori'),
        CustomKodeRule(keyword: 'RTK', kode: 'RTK', type: 'kategori'),
        CustomKodeRule(keyword: 'Bibit', kode: 'RTK', type: 'kategori'),
        CustomKodeRule(keyword: 'DP', kode: 'DP', type: 'kategori'),
        CustomKodeRule(keyword: 'Sewa', kode: 'Sewa Tempat', type: 'kategori'),
        CustomKodeRule(keyword: 'Konsumsi', kode: 'Konsumsi', type: 'kategori'),
        CustomKodeRule(keyword: 'admin', kode: 'Adm Bank/Pajak', type: 'kategori'),
        CustomKodeRule(keyword: 'dari S3', kode: 'Dana dari S3', type: 'kategori'),
        CustomKodeRule(keyword: 'bensin', kode: 'Transportasi Lokal', type: 'kategori'),
        CustomKodeRule(keyword: 'transport', kode: 'Transportasi Lokal', type: 'kategori'),
        CustomKodeRule(keyword: 'pulsa', kode: 'Komunikasi & Internet', type: 'kategori'),
        CustomKodeRule(keyword: 'internet', kode: 'Komunikasi & Internet', type: 'kategori'),
        CustomKodeRule(keyword: 'kuota', kode: 'Komunikasi & Internet', type: 'kategori'),
        CustomKodeRule(keyword: 'bunga', kode: 'Bunga Bank', type: 'kategori'),
      ];

  static List<CustomKodeRule> k12Rules() => [
        CustomKodeRule(keyword: 'DP KK', kode: 'Terima DP DTK', type: 'kategori'),
        CustomKodeRule(keyword: 'Kirim DP ke S3', kode: 'Kirim DP DTK ke S3', type: 'kategori'),
        CustomKodeRule(keyword: 'Dana kontribusi DP dari S3', kode: 'Kontribusi DP S4', type: 'kategori'),
        CustomKodeRule(keyword: 'Motor', kode: 'Motor, Peralatan & Elektronik', type: 'kategori'),
        CustomKodeRule(keyword: 'Sewa tempat', kode: 'Sewa Tempat', type: 'kategori'),
        CustomKodeRule(keyword: 'Bensin', kode: 'Biaya Transportasi Lokal', type: 'kategori'),
        CustomKodeRule(keyword: 'Konsumsi', kode: 'Biaya Konsumsi Acara', type: 'kategori'),
        CustomKodeRule(keyword: 'Internet', kode: 'Biaya Komunikasi dan Internet', type: 'kategori'),
        CustomKodeRule(keyword: 'Kuota', kode: 'Biaya Komunikasi dan Internet', type: 'kategori'),
        CustomKodeRule(keyword: 'Pulsa', kode: 'Biaya Komunikasi dan Internet', type: 'kategori'),
        CustomKodeRule(keyword: 'Air', kode: 'Biaya Listrik dan Air', type: 'kategori'),
        CustomKodeRule(keyword: 'Listrik', kode: 'Biaya Listrik dan Air', type: 'kategori'),
        CustomKodeRule(keyword: 'Spidol', kode: 'Biaya ATK', type: 'kategori'),
        CustomKodeRule(keyword: 'Bolpoin', kode: 'Biaya ATK', type: 'kategori'),
        CustomKodeRule(keyword: 'Pulpen', kode: 'Biaya ATK', type: 'kategori'),
        CustomKodeRule(keyword: 'Buku', kode: 'Biaya ATK', type: 'kategori'),
        CustomKodeRule(keyword: 'Kertas', kode: 'Biaya ATK', type: 'kategori'),
        CustomKodeRule(keyword: 'Print', kode: 'Biaya ATK', type: 'kategori'),
        CustomKodeRule(keyword: 'Pensil', kode: 'Biaya ATK', type: 'kategori'),
        CustomKodeRule(keyword: 'ATK', kode: 'Biaya ATK', type: 'kategori'),
        CustomKodeRule(keyword: 'Admin', kode: 'Biaya RTK', type: 'kategori'),
        CustomKodeRule(keyword: 'Bi Fast', kode: 'Biaya RTK', type: 'kategori'),
        CustomKodeRule(keyword: 'RTK', kode: 'Biaya RTK', type: 'kategori'),
        CustomKodeRule(keyword: 'Peralatan', kode: 'Pemeliharaan Bangunan, Peralatan', type: 'kategori'),
        CustomKodeRule(keyword: 'Bangunan', kode: 'Pemeliharaan Bangunan, Peralatan', type: 'kategori'),
      ];
}

class StrukturTransaction {
  final String id;
  final String title;
  final String type; // 'transfer_debit', 'tarik_tunai', 'pemasukan', 'pengeluaran', etc.
  final String? sourceAccount; // 'rekening', 'debit', 'cash'
  final String? targetAccount; // 'rekening', 'debit', 'cash'
  final String? manualSource; // Asal dana untuk pemasukan (cth: 'DP KK Angkatan')
  final int amount;
  final int adminFee;
  final DateTime timestamp;
  final String? note;
  final String? ku;
  final String? kode; // Kategori

  StrukturTransaction({
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
  static String resolveKodeFromText(String text,
      {List<CustomKodeRule>? customRules}) {
    if (text.trim().isEmpty) return '-';
    final lower = text.toLowerCase();
    final rules = (customRules ?? []).where((r) => r.type != 'ku').toList();
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
          {List<CustomKodeRule>? customRules}) =>
      resolveKodeFromText(text, customRules: customRules);

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
  String getDisplayKode({List<CustomKodeRule>? customRules}) {
    if (kode != null && kode!.trim().isNotEmpty && kode!.trim() != '-') {
      return kode!.trim();
    }
    if (note != null && note!.trim().isNotEmpty) {
      final autoFromNote =
          resolveKodeFromText(note!, customRules: customRules);
      if (autoFromNote != '-') return autoFromNote;
    }
    final autoFromTitle =
        resolveKodeFromText(title, customRules: customRules);
    if (autoFromTitle != '-') return autoFromTitle;
    if (manualSource != null && manualSource!.trim().isNotEmpty) {
      final autoFromSource =
          resolveKodeFromText(manualSource!, customRules: customRules);
      if (autoFromSource != '-') return autoFromSource;
    }
    return '-';
  }

  String get displayKode => getDisplayKode();
  String get displayKategori => getDisplayKode();

  /// Menandakan apakah transaksi ini merupakan transaksi DP (Kategori mengandung 'DP')
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

  factory StrukturTransaction.fromJson(Map<String, dynamic> json) {
    return StrukturTransaction(
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

class StrukturData {
  RekeningStruktur rekeningStruktur;
  OnHandDebit onHandDebit;
  OnHandCash onHandCash;
  List<StrukturTransaction> transactions;
  List<CustomKodeRule> customKodeRules;
  bool isSaldoRekeningUnlocked;

  StrukturData({
    RekeningStruktur? rekeningStruktur,
    OnHandDebit? onHandDebit,
    OnHandCash? onHandCash,
    List<StrukturTransaction>? transactions,
    List<CustomKodeRule>? customKodeRules,
    bool? isSaldoRekeningUnlocked,
  })  : rekeningStruktur = rekeningStruktur ?? RekeningStruktur(),
        onHandDebit = onHandDebit ?? OnHandDebit(),
        onHandCash = onHandCash ?? OnHandCash(),
        transactions = (transactions ?? [])
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
        customKodeRules = customKodeRules ?? [],
        isSaldoRekeningUnlocked = isSaldoRekeningUnlocked ?? false;

  int get totalOnHand => onHandDebit.balance + onHandCash.balance;
  int get totalDanaStruktur =>
      rekeningStruktur.balance + onHandDebit.balance + onHandCash.balance;

  int getTotalPemasukanDP({List<CustomKodeRule>? customRules}) {
    final rules = customRules ?? customKodeRules;
    int sum = 0;
    for (int i = 0; i < transactions.length; i++) {
      final t = transactions[i];
      if (t.isPemasukan && t.isDPTransaction(customRules: rules)) {
        sum += t.amount;
      }
    }
    return sum;
  }

  int get totalPemasukanDP => getTotalPemasukanDP();

  /// Menghitung dana operasional murni (Total Dana Struktur - Dana Pemasukan DP yang nantinya disetor ke atas)
  int getTotalDanaOperasional({List<CustomKodeRule>? customRules}) {
    final dp = getTotalPemasukanDP(customRules: customRules);
    final op = totalDanaStruktur - dp;
    return op < 0 ? 0 : op;
  }

  int get totalDanaOperasional => getTotalDanaOperasional();

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
        'rekeningStruktur': rekeningStruktur.toJson(),
        'onHandDebit': onHandDebit.toJson(),
        'onHandCash': onHandCash.toJson(),
        'transactions': transactions.map((e) => e.toJson()).toList(),
        'customKodeRules': customKodeRules.map((e) => e.toJson()).toList(),
        'isSaldoRekeningUnlocked': isSaldoRekeningUnlocked,
      };

  factory StrukturData.fromJson(Map<String, dynamic> json) {
    return StrukturData(
      rekeningStruktur: json['rekeningStruktur'] != null
          ? RekeningStruktur.fromJson(
              json['rekeningStruktur'] as Map<String, dynamic>)
          : RekeningStruktur(),
      onHandDebit: json['onHandDebit'] != null
          ? OnHandDebit.fromJson(json['onHandDebit'] as Map<String, dynamic>)
          : OnHandDebit(),
      onHandCash: json['onHandCash'] != null
          ? OnHandCash.fromJson(json['onHandCash'] as Map<String, dynamic>)
          : OnHandCash(),
      transactions: ((json['transactions'] as List<dynamic>?)
              ?.map((e) =>
                  StrukturTransaction.fromJson(e as Map<String, dynamic>))
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
