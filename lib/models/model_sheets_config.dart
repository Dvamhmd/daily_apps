import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SheetsConfig {
  String webAppUrl;
  String sheetName;
  bool autoSyncOnInput;
  int startRow;
  Map<String, String> columnMapping;
  DateTime? lastSyncTime;
  String? lastSyncStatus;
  String? lastSyncMessage;

  static const String prefKey = 'keuangan_sheets_config';

  SheetsConfig({
    this.webAppUrl = '',
    this.sheetName = 'Lap Keu',
    this.autoSyncOnInput = true,
    this.startRow = 2,
    Map<String, String>? columnMapping,
    this.lastSyncTime,
    this.lastSyncStatus,
    this.lastSyncMessage,
  }) : columnMapping = columnMapping ?? defaultColumnMapping();

  static Map<String, String> defaultColumnMapping() => {
        'no': 'A',
        'tanggal': 'B',
        'ku': 'C',
        'kategori': 'D',
        'keterangan': 'E',
        'jumlah': 'F',
        'debit': 'G',
        'kredit': 'H',
      };

  bool get isConfigured => webAppUrl.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'webAppUrl': webAppUrl,
        'sheetName': sheetName,
        'autoSyncOnInput': autoSyncOnInput,
        'startRow': startRow,
        'columnMapping': columnMapping,
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

    return SheetsConfig(
      webAppUrl: json['webAppUrl'] as String? ?? '',
      sheetName: json['sheetName'] as String? ?? 'Lap Keu',
      autoSyncOnInput: json['autoSyncOnInput'] as bool? ?? true,
      startRow: (json['startRow'] as num?)?.toInt() ?? 2,
      columnMapping: mapping,
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
