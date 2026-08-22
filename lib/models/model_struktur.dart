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

  CustomKodeRule({
    String? id,
    required this.keyword,
    required this.kode,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'keyword': keyword,
        'kode': kode,
      };

  factory CustomKodeRule.fromJson(Map<String, dynamic> json) {
    return CustomKodeRule(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      keyword: json['keyword'] as String? ?? '',
      kode: json['kode'] as String? ?? '',
    );
  }

  static List<CustomKodeRule> defaultRules() => [];
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
  final String? kode;

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
    this.kode,
  }) : timestamp = timestamp ?? DateTime.now();

  int get totalDeduction => amount + adminFee;

  bool get isPemasukan => type == 'pemasukan';
  bool get isPengeluaran => type == 'pengeluaran';
  bool get isAlokasiInternal => !isPemasukan && !isPengeluaran;

  /// Helper untuk auto-resolve kode transaksi berdasarkan kata kunci teks keterangan/judul dan daftar kustomisasi
  static String resolveKodeFromText(String text,
      {List<CustomKodeRule>? customRules}) {
    if (text.trim().isEmpty) return '-';
    final lower = text.toLowerCase();
    final rules = customRules ?? [];
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

  /// Getter untuk mendapatkan kode transaksi baik yang disimpan atau auto-resolved
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

  /// Menandakan apakah transaksi ini merupakan transaksi DP (Kode mengandung 'DP')
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

  StrukturData({
    RekeningStruktur? rekeningStruktur,
    OnHandDebit? onHandDebit,
    OnHandCash? onHandCash,
    List<StrukturTransaction>? transactions,
    List<CustomKodeRule>? customKodeRules,
  })  : rekeningStruktur = rekeningStruktur ?? RekeningStruktur(),
        onHandDebit = onHandDebit ?? OnHandDebit(),
        onHandCash = onHandCash ?? OnHandCash(),
        transactions = (transactions ?? [])
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
        customKodeRules = customKodeRules ?? [];

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
    );
  }
}
