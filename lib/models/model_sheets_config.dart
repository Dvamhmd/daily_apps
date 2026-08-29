import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SheetsConfig {
  String webAppUrl;
  String sheetName;
  bool autoSyncOnInput;
  int startRow; // Start row untuk Transaksi Rekening
  int startRowOnHand; // Start row untuk Transaksi Cash On Hand
  String dateFormat;
  Map<String, String> columnMapping;
  DateTime? lastSyncTime;
  String? lastSyncStatus;
  String? lastSyncMessage;

  bool insertImageFormula;
  int evidenceTargetRow;
  Map<String, int> evidenceRowMapping;
  bool hasConfiguredCells;

  static const String prefKey = 'keuangan_sheets_config';

  SheetsConfig({
    this.webAppUrl = '',
    this.sheetName = '',
    this.autoSyncOnInput = false,
    this.startRow = 4,
    this.startRowOnHand = 4,
    this.dateFormat = 'dd/MM/yyyy',
    Map<String, String>? columnMapping,
    this.insertImageFormula = false,
    this.evidenceTargetRow = 2,
    Map<String, int>? evidenceRowMapping,
    this.hasConfiguredCells = false,
    this.lastSyncTime,
    this.lastSyncStatus,
    this.lastSyncMessage,
  })  : columnMapping = columnMapping ?? defaultColumnMapping(),
        evidenceRowMapping = evidenceRowMapping ?? defaultEvidenceRowMapping();

  static Map<String, String> defaultColumnMapping() => {
        // 1. Kolom Transaksi Rekening
        'no': 'A',
        'tanggal': 'B',
        'ku': 'C',
        'kategori': 'D',
        'keterangan': 'E',
        'debit': 'F',
        'kredit': 'G',

        // 2. Kolom Transaksi Cash On Hand
        'no_onhand': 'A',
        'tanggal_onhand': 'B',
        'ku_onhand': 'C',
        'kategori_onhand': 'D',
        'keterangan_onhand': 'E',
        'debit_onhand': 'F',
        'kredit_onhand': 'G',

        // 3. Bukti Gambar
        'bukti_saldo_rekening': '-',
        'bukti_saldo_cash': '-',
        'bukti_mutasi_1': '-',
        'bukti_mutasi_2': '-',
        'bukti_mutasi_3': '-',
        'bukti_mutasi_4': '-',
        'bukti_mutasi_5': '-',
      };

  static String suggestedColumn(String key) {
    const suggested = {
      // Rekening
      'no': 'A',
      'tanggal': 'B',
      'ku': 'C',
      'kategori': 'D',
      'keterangan': 'E',
      'debit': 'F',
      'kredit': 'G',

      // Cash On Hand (sama seperti Rekening: A - G)
      'no_onhand': 'A',
      'tanggal_onhand': 'B',
      'ku_onhand': 'C',
      'kategori_onhand': 'D',
      'keterangan_onhand': 'E',
      'debit_onhand': 'F',
      'kredit_onhand': 'G',

      // Bukti Gambar
      'bukti_saldo_rekening': 'A',
      'bukti_saldo_cash': 'J',
      'bukti_mutasi_1': 'A',
      'bukti_mutasi_2': 'D',
      'bukti_mutasi_3': 'F',
      'bukti_mutasi_4': 'J',
      'bukti_mutasi_5': 'N',
    };
    return suggested[key] ?? 'A';
  }

  static Map<String, int> defaultEvidenceRowMapping() => {
        'bukti_saldo_rekening': 60,
        'bukti_saldo_cash': 60,
        'bukti_mutasi_1': 82,
        'bukti_mutasi_2': 82,
        'bukti_mutasi_3': 82,
        'bukti_mutasi_4': 82,
        'bukti_mutasi_5': 82,
      };

  int getEvidenceRow(String key, {int? fallback}) {
    return evidenceRowMapping[key] ??
        fallback ??
        defaultEvidenceRowMapping()[key] ??
        evidenceTargetRow;
  }

  bool get isConfigured => webAppUrl.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'webAppUrl': webAppUrl,
        'sheetName': sheetName,
        'autoSyncOnInput': autoSyncOnInput,
        'startRow': startRow,
        'startRowOnHand': startRowOnHand,
        'dateFormat': dateFormat,
        'columnMapping': columnMapping,
        'insertImageFormula': insertImageFormula,
        'evidenceTargetRow': evidenceTargetRow,
        'evidenceRowMapping': evidenceRowMapping,
        'hasConfiguredCells': hasConfiguredCells,
        'lastSyncTime': lastSyncTime?.toIso8601String(),
        'lastSyncStatus': lastSyncStatus,
        'lastSyncMessage': lastSyncMessage,
      };

  factory SheetsConfig.fromJson(Map<String, dynamic> json) {
    Map<String, String> mapping = defaultColumnMapping();
    if (json['columnMapping'] is Map) {
      final raw = json['columnMapping'] as Map;
      raw.forEach((k, v) {
        if (k != null && v != null) {
          final keyStr = k.toString();
          if (keyStr != 'jumlah') {
            mapping[keyStr] = v.toString().toUpperCase().trim();
          }
        }
      });
    }

    final int defaultRow = (json['evidenceTargetRow'] as num?)?.toInt() ?? 60;
    Map<String, int> rowMapping = defaultEvidenceRowMapping();
    if (json['evidenceRowMapping'] is Map) {
      final rawRow = json['evidenceRowMapping'] as Map;
      rawRow.forEach((k, v) {
        if (k != null && v != null) {
          final parsed = int.tryParse(v.toString());
          if (parsed != null && parsed > 0) {
            rowMapping[k.toString()] = parsed;
          }
        }
      });
    }

    final int parsedStartRow = (json['startRow'] as num?)?.toInt() ?? 4;
    final int parsedStartRowOnHand =
        (json['startRowOnHand'] as num?)?.toInt() ?? parsedStartRow;

    return SheetsConfig(
      webAppUrl: json['webAppUrl'] as String? ?? '',
      sheetName: (json['sheetName'] as String? ?? '').trim(),
      autoSyncOnInput: json['autoSyncOnInput'] as bool? ?? false,
      startRow: parsedStartRow,
      startRowOnHand: parsedStartRowOnHand,
      dateFormat: json['dateFormat'] as String? ?? 'dd/MM/yyyy',
      columnMapping: mapping,
      insertImageFormula: json['insertImageFormula'] as bool? ?? false,
      evidenceTargetRow: defaultRow,
      evidenceRowMapping: rowMapping,
      hasConfiguredCells: json['hasConfiguredCells'] as bool? ?? false,
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.tryParse(json['lastSyncTime'] as String)
          : null,
      lastSyncStatus: json['lastSyncStatus'] as String?,
      lastSyncMessage: json['lastSyncMessage'] as String?,
    );
  }

  static Future<SheetsConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return SheetsConfig.fromJson(decoded);
        }
      } catch (_) {}
    }
    return SheetsConfig();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, jsonEncode(toJson()));
  }
}
