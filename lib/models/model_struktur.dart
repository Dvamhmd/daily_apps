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

class StrukturTransaction {
  final String id;
  final String title;
  final String type; // 'pemasukan', 'pengeluaran', 'transfer_debit', 'tarik_tunai', 'debit_to_rekening', 'debit_to_cash', 'cash_to_rekening', 'cash_to_debit'
  final String? sourceAccount; // 'rekening', 'debit', 'cash'
  final String? targetAccount; // 'rekening', 'debit', 'cash'
  final String? manualSource; // text manual untuk sumber pemasukan
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

  /// Helper untuk auto-resolve kode transaksi berdasarkan kata kunci teks keterangan/judul
  static String resolveKodeFromText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('admin bank transfer') || lower.contains('admin bank')) {
      return 'Biaya RTK';
    }
    if (lower.contains('dp kk')) {
      return 'Terima DP DTK';
    }
    if (lower.contains('konsumsi')) {
      return 'Biaya Konsumsi Acara';
    }
    if (lower.contains('sewa tempat') || lower.contains('sewa ruangan')) {
      return 'Sewa Tempat';
    }
    if (lower.contains('kontribusi dp bulan')) {
      return 'Kontribusi DP S4';
    }
    return '-';
  }

  /// Getter untuk mendapatkan kode transaksi baik yang disimpan atau auto-resolved
  String get displayKode {
    if (kode != null && kode!.trim().isNotEmpty && kode!.trim() != '-') {
      return kode!.trim();
    }
    if (note != null && note!.trim().isNotEmpty) {
      final autoFromNote = resolveKodeFromText(note!);
      if (autoFromNote != '-') return autoFromNote;
    }
    final autoFromTitle = resolveKodeFromText(title);
    if (autoFromTitle != '-') return autoFromTitle;
    if (manualSource != null && manualSource!.trim().isNotEmpty) {
      final autoFromSource = resolveKodeFromText(manualSource!);
      if (autoFromSource != '-') return autoFromSource;
    }
    return '-';
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

  StrukturData({
    RekeningStruktur? rekeningStruktur,
    OnHandDebit? onHandDebit,
    OnHandCash? onHandCash,
    List<StrukturTransaction>? transactions,
  })  : rekeningStruktur = rekeningStruktur ?? RekeningStruktur(),
        onHandDebit = onHandDebit ?? OnHandDebit(),
        onHandCash = onHandCash ?? OnHandCash(),
        transactions = transactions ?? [];

  int get totalOnHand => onHandDebit.balance + onHandCash.balance;
  int get totalDanaStruktur =>
      rekeningStruktur.balance + onHandDebit.balance + onHandCash.balance;

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
      transactions: (json['transactions'] as List<dynamic>?)
              ?.map((e) =>
                  StrukturTransaction.fromJson(e as Map<String, dynamic>))
              .where((t) => t.isPemasukan || t.isPengeluaran)
              .toList() ??
          [],
    );
  }
}
