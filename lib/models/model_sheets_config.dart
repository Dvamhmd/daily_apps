import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SheetsConfig {
  String webAppUrl;
  String sheetName;
  bool autoSyncOnInput;
  int startRow;
  String dateFormat;
  Map<String, String> columnMapping;
  DateTime? lastSyncTime;
  String? lastSyncStatus;
  String? lastSyncMessage;

  bool insertImageFormula;
  int evidenceTargetRow;
  Map<String, int> evidenceRowMapping;

  static const String prefKey = 'keuangan_sheets_config';

  SheetsConfig({
    this.webAppUrl = '',
    this.sheetName = 'Lap Keu',
    this.autoSyncOnInput = true,
    this.startRow = 2,
    this.dateFormat = 'dd/MM/yyyy',
    Map<String, String>? columnMapping,
    this.insertImageFormula = false,
    this.evidenceTargetRow = 2,
    Map<String, int>? evidenceRowMapping,
    this.lastSyncTime,
    this.lastSyncStatus,
    this.lastSyncMessage,
  })  : columnMapping = columnMapping ?? defaultColumnMapping(),
        evidenceRowMapping = evidenceRowMapping ?? defaultEvidenceRowMapping();

  static Map<String, String> defaultColumnMapping() => {
        'no': 'A',
        'tanggal': 'B',
        'ku': 'C',
        'kategori': 'D',
        'keterangan': 'E',
        'jumlah': 'F',
        'debit': 'G',
        'kredit': 'H',
        'bukti_saldo_rekening': 'I',
        'bukti_saldo_cash': 'J',
        'bukti_mutasi_1': 'K',
        'bukti_mutasi_2': 'L',
        'bukti_mutasi_3': 'M',
        'bukti_mutasi_4': 'N',
        'bukti_mutasi_5': 'O',
      };

  static Map<String, int> defaultEvidenceRowMapping() => {
        'bukti_saldo_rekening': 2,
        'bukti_saldo_cash': 2,
        'bukti_mutasi_1': 2,
        'bukti_mutasi_2': 2,
        'bukti_mutasi_3': 2,
        'bukti_mutasi_4': 2,
        'bukti_mutasi_5': 2,
      };

  int getEvidenceRow(String key, {int fallback = 2}) {
    return evidenceRowMapping[key] ?? evidenceTargetRow;
  }

  bool get isConfigured => webAppUrl.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'webAppUrl': webAppUrl,
        'sheetName': sheetName,
        'autoSyncOnInput': autoSyncOnInput,
        'startRow': startRow,
        'dateFormat': dateFormat,
        'columnMapping': columnMapping,
        'insertImageFormula': insertImageFormula,
        'evidenceTargetRow': evidenceTargetRow,
        'evidenceRowMapping': evidenceRowMapping,
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
          mapping[k.toString()] = v.toString().toUpperCase().trim();
        }
      });
    }

    final int defaultRow = (json['evidenceTargetRow'] as num?)?.toInt() ?? 2;
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
    } else {
      // Jika baru migrasi dari evidenceTargetRow lama, gunakan defaultRow untuk semua
      for (var k in rowMapping.keys) {
        rowMapping[k] = defaultRow;
      }
    }

    return SheetsConfig(
      webAppUrl: json['webAppUrl'] as String? ?? '',
      sheetName: json['sheetName'] as String? ?? 'Lap Keu',
      autoSyncOnInput: json['autoSyncOnInput'] as bool? ?? true,
      startRow: (json['startRow'] as num?)?.toInt() ?? 2,
      dateFormat: json['dateFormat'] as String? ?? 'dd/MM/yyyy',
      columnMapping: mapping,
      insertImageFormula: json['insertImageFormula'] as bool? ?? false,
      evidenceTargetRow: defaultRow,
      evidenceRowMapping: rowMapping,
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
