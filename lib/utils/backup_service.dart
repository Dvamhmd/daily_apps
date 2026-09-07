import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:daily_apps/models/model_pribadi.dart';
import 'package:daily_apps/models/model_struktur.dart';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/utils/web_file_saver.dart';
import 'package:daily_apps/widgets/upload_evidence_modal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupSummary {
  final int totalUangku;
  final int totalTagihan;
  final int totalTabungan;
  final int totalTagihanLunas;
  final int totalRiwayatKeuangan;
  final int totalStrukturMonths;
  final int totalStrukturTransactions;
  final int totalPribadiMonths;
  final int totalPribadiTransactions;
  final int totalRundowns;
  final int totalTodoGroups;
  final int totalTodoActiveItems;
  final int totalTodoHistoryGroups;
  final int totalTodoHistoryItems;

  const BackupSummary({
    this.totalUangku = 0,
    this.totalTagihan = 0,
    this.totalTabungan = 0,
    this.totalTagihanLunas = 0,
    this.totalRiwayatKeuangan = 0,
    this.totalStrukturMonths = 0,
    this.totalStrukturTransactions = 0,
    this.totalPribadiMonths = 0,
    this.totalPribadiTransactions = 0,
    this.totalRundowns = 0,
    this.totalTodoGroups = 0,
    this.totalTodoActiveItems = 0,
    this.totalTodoHistoryGroups = 0,
    this.totalTodoHistoryItems = 0,
  });

  Map<String, dynamic> toJson() => {
        'totalUangku': totalUangku,
        'totalTagihan': totalTagihan,
        'totalTabungan': totalTabungan,
        'totalTagihanLunas': totalTagihanLunas,
        'totalRiwayatKeuangan': totalRiwayatKeuangan,
        'totalStrukturMonths': totalStrukturMonths,
        'totalStrukturTransactions': totalStrukturTransactions,
        'totalPribadiMonths': totalPribadiMonths,
        'totalPribadiTransactions': totalPribadiTransactions,
        'totalRundowns': totalRundowns,
        'totalTodoGroups': totalTodoGroups,
        'totalTodoActiveItems': totalTodoActiveItems,
        'totalTodoHistoryGroups': totalTodoHistoryGroups,
        'totalTodoHistoryItems': totalTodoHistoryItems,
      };

  factory BackupSummary.fromJson(Map<String, dynamic> json) {
    return BackupSummary(
      totalUangku: (json['totalUangku'] as num?)?.toInt() ?? 0,
      totalTagihan: (json['totalTagihan'] as num?)?.toInt() ?? 0,
      totalTabungan: (json['totalTabungan'] as num?)?.toInt() ?? 0,
      totalTagihanLunas: (json['totalTagihanLunas'] as num?)?.toInt() ?? 0,
      totalRiwayatKeuangan:
          (json['totalRiwayatKeuangan'] as num?)?.toInt() ?? 0,
      totalStrukturMonths:
          (json['totalStrukturMonths'] as num?)?.toInt() ?? 0,
      totalStrukturTransactions:
          (json['totalStrukturTransactions'] as num?)?.toInt() ?? 0,
      totalPribadiMonths:
          (json['totalPribadiMonths'] as num?)?.toInt() ?? 0,
      totalPribadiTransactions:
          (json['totalPribadiTransactions'] as num?)?.toInt() ?? 0,
      totalRundowns: (json['totalRundowns'] as num?)?.toInt() ?? 0,
      totalTodoGroups: (json['totalTodoGroups'] as num?)?.toInt() ?? 0,
      totalTodoActiveItems:
          (json['totalTodoActiveItems'] as num?)?.toInt() ?? 0,
      totalTodoHistoryGroups:
          (json['totalTodoHistoryGroups'] as num?)?.toInt() ?? 0,
      totalTodoHistoryItems:
          (json['totalTodoHistoryItems'] as num?)?.toInt() ?? 0,
    );
  }
}

class BackupDataModel {
  final int version;
  final String appName;
  final DateTime exportedAt;
  final BackupSummary summary;
  final Map<String, dynamic> preferences;

  BackupDataModel({
    this.version = 1,
    this.appName = 'Daily Apps',
    DateTime? exportedAt,
    required this.summary,
    required this.preferences,
  }) : exportedAt = exportedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'version': version,
        'appName': appName,
        'exportedAt': exportedAt.toIso8601String(),
        'summary': summary.toJson(),
        'preferences': preferences,
      };

  factory BackupDataModel.fromJson(Map<String, dynamic> json) {
    final prefsMap = json['preferences'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['preferences'] as Map)
        : <String, dynamic>{};

    // Selalu hitung summary langsung dari payload preferences untuk akurasi maksimal
    final calculatedSummary =
        BackupService.calculateSummaryFromRawMap(prefsMap);

    return BackupDataModel(
      version: (json['version'] as num?)?.toInt() ?? 1,
      appName: json['appName'] as String? ?? 'Daily Apps',
      exportedAt: json['exportedAt'] != null
          ? DateTime.tryParse(json['exportedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      summary: calculatedSummary,
      preferences: prefsMap,
    );
  }
}

class BackupService {
  /// Menghitung ringkasan data secara komprehensif dari Map key-value SharedPreferences
  static BackupSummary calculateSummaryFromRawMap(Map<String, dynamic> rawMap) {
    int countUangku = 0;
    int countTagihan = 0;
    int countTabungan = 0;
    int countTagihanLunas = 0;
    int countRiwayatKeuangan = 0;
    int countStrukturMonths = 0;
    int countStrukturTransactions = 0;
    int countPribadiMonths = 0;
    int countPribadiTransactions = 0;
    int countRundowns = 0;
    int countTodoGroups = 0;
    int countTodoActiveItems = 0;
    int countTodoHistoryGroups = 0;
    int countTodoHistoryItems = 0;

    final seenActiveGroupIds = <String>{};
    final seenHistoryGroupIds = <String>{};

    for (final entry in rawMap.entries) {
      final key = entry.key;
      dynamic value = entry.value;

      // Jika value disimpan dengan format wrapper preferences ({'type': ..., 'value': ...})
      if (value is Map && value.containsKey('value')) {
        value = value['value'];
      }

      // 1. Tabungan
      if (key == 'tabungan') {
        if (value is List) {
          countTabungan += value.length;
        } else if (value is String) {
          try {
            final dec = jsonDecode(value);
            if (dec is List) countTabungan += dec.length;
          } catch (_) {}
        }
      }
      // 2. Tagihan Lunas
      else if (key == 'tagihan_lunas' || key.startsWith('tagihan_lunas_')) {
        if (value is List) {
          countTagihanLunas += value.length;
        } else if (value is String) {
          try {
            final dec = jsonDecode(value);
            if (dec is List) countTagihanLunas += dec.length;
          } catch (_) {}
        }
      }
      // 3. Riwayat Keuangan
      else if (key == 'riwayat_keuangan' ||
          key.startsWith('riwayat_keuangan_') ||
          key == 'riwayat_keuangan_list' ||
          key.startsWith('riwayat_keuangan_list_')) {
        if (value is List) {
          countRiwayatKeuangan += value.length;
        } else if (value is String) {
          try {
            final dec = jsonDecode(value);
            if (dec is List) countRiwayatKeuangan += dec.length;
          } catch (_) {}
        }
      }
      // 4. Rundowns
      else if (key == 'rundowns_data' || key.startsWith('rundowns_data_')) {
        if (value is List) {
          countRundowns += value.length;
        } else if (value is String) {
          try {
            final dec = jsonDecode(value);
            if (dec is List) countRundowns += dec.length;
          } catch (_) {}
        }
      }
      // 5. Uangku
      else if (key == 'uangku' ||
          (key.startsWith('uangku_') && key != 'uangku_only_cair')) {
        if (value is List) {
          countUangku += value.length;
        } else if (value is String) {
          try {
            final dec = jsonDecode(value);
            if (dec is List) countUangku += dec.length;
          } catch (_) {}
        }
      }
      // 6. Tagihan (Aktif)
      else if (key == 'tagihan' ||
          (key.startsWith('tagihan_') && !key.startsWith('tagihan_lunas'))) {
        if (value is List) {
          countTagihan += value.length;
        } else if (value is String) {
          try {
            final dec = jsonDecode(value);
            if (dec is List) countTagihan += dec.length;
          } catch (_) {}
        }
      }
      // 7. Keuangan Struktur
      else if (key == 'struktur_keuangan_data' ||
          key.startsWith('struktur_keuangan_data_')) {
        countStrukturMonths++;
        if (value is String) {
          try {
            final dec = jsonDecode(value);
            if (dec is Map<String, dynamic>) {
              final data = StrukturData.fromJson(dec);
              countStrukturTransactions += data.transactions.length;
            }
          } catch (_) {}
        } else if (value is Map<String, dynamic>) {
          try {
            final data = StrukturData.fromJson(value);
            countStrukturTransactions += data.transactions.length;
          } catch (_) {}
        }
      }
      // 8. Keuangan Pribadi
      else if (key == 'pribadi_keuangan_data' ||
          key.startsWith('pribadi_keuangan_data_')) {
        countPribadiMonths++;
        if (value is String) {
          try {
            final dec = jsonDecode(value);
            if (dec is Map<String, dynamic>) {
              final data = PribadiData.fromJson(dec);
              countPribadiTransactions += data.transactions.length;
            }
          } catch (_) {}
        } else if (value is Map<String, dynamic>) {
          try {
            final data = PribadiData.fromJson(value);
            countPribadiTransactions += data.transactions.length;
          } catch (_) {}
        }
      }
      // 9. Todo Groups & Items (Mendeteksi Normal, Serious, User-scoped, & Legacy keys)
      else if (key == 'daily_apps_todo_groups_v1' ||
          key == 'daily_apps_serious_todo_groups_v1' ||
          key.startsWith('daily_apps_todo_groups_v1_') ||
          key.startsWith('daily_apps_serious_todo_groups_v1_') ||
          key == 'todo_date_groups_v1' ||
          key.startsWith('todo_date_groups_v1_') ||
          key == 'todo_list_data' ||
          (key.startsWith('todo_list_data_') && !key.contains('undo')) ||
          key == 'todo_history_data' ||
          key.startsWith('todo_history_data_')) {
        void processGroupJson(dynamic groupJson) {
          if (groupJson == null) return;
          try {
            Map<String, dynamic>? groupMap;
            if (groupJson is String) {
              final dec = jsonDecode(groupJson);
              if (dec is Map<String, dynamic>) {
                groupMap = dec;
              } else if (dec is Map) {
                groupMap = Map<String, dynamic>.from(dec);
              }
            } else if (groupJson is Map<String, dynamic>) {
              groupMap = groupJson;
            } else if (groupJson is Map) {
              groupMap = Map<String, dynamic>.from(groupJson);
            }

            if (groupMap != null) {
              final group = TodoDateGroup.fromJson(groupMap);
              final gid = group.id.isNotEmpty
                  ? group.id
                  : 'g_${key}_${group.date.millisecondsSinceEpoch}_${group.items.length}';

              if (group.isArchived) {
                if (seenHistoryGroupIds.add(gid)) {
                  countTodoHistoryGroups++;
                  countTodoHistoryItems += group.items.length;
                }
              } else {
                if (seenActiveGroupIds.add(gid)) {
                  countTodoGroups++;
                  countTodoActiveItems += group.items.length;
                }
              }
            }
          } catch (_) {}
        }

        if (value is String) {
          try {
            final dec = jsonDecode(value);
            if (dec is List) {
              for (final item in dec) {
                processGroupJson(item);
              }
            } else if (dec is Map) {
              processGroupJson(dec);
            }
          } catch (_) {}
        } else if (value is List) {
          for (final item in value) {
            processGroupJson(item);
          }
        }
      }
    }

    return BackupSummary(
      totalUangku: countUangku,
      totalTagihan: countTagihan,
      totalTabungan: countTabungan,
      totalTagihanLunas: countTagihanLunas,
      totalRiwayatKeuangan: countRiwayatKeuangan,
      totalStrukturMonths: countStrukturMonths,
      totalStrukturTransactions: countStrukturTransactions,
      totalPribadiMonths: countPribadiMonths,
      totalPribadiTransactions: countPribadiTransactions,
      totalRundowns: countRundowns,
      totalTodoGroups: countTodoGroups,
      totalTodoActiveItems: countTodoActiveItems,
      totalTodoHistoryGroups: countTodoHistoryGroups,
      totalTodoHistoryItems: countTodoHistoryItems,
    );
  }

  /// Menghitung ringkasan data yang tersimpan di perangkat saat ini
  static Future<BackupSummary> getLiveSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final Map<String, dynamic> rawMap = {};

    for (final key in keys) {
      rawMap[key] = prefs.get(key);
    }

    return calculateSummaryFromRawMap(rawMap);
  }

  /// Membuat payload data cadangan lengkap dari SharedPreferences
  static Future<BackupDataModel> generateBackupData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final summary = await getLiveSummary();

    final Map<String, dynamic> preferencesMap = {};

    for (final key in keys) {
      final value = prefs.get(key);
      if (value is String) {
        preferencesMap[key] = {
          'type': 'string',
          'value': value,
        };
      } else if (value is List<String>) {
        preferencesMap[key] = {
          'type': 'string_list',
          'value': value,
        };
      } else if (value is int) {
        preferencesMap[key] = {
          'type': 'int',
          'value': value,
        };
      } else if (value is bool) {
        preferencesMap[key] = {
          'type': 'bool',
          'value': value,
        };
      } else if (value is double) {
        preferencesMap[key] = {
          'type': 'double',
          'value': value,
        };
      } else if (value is List) {
        // Fallback for generic list
        preferencesMap[key] = {
          'type': 'string_list',
          'value': value.map((e) => e.toString()).toList(),
        };
      }
    }

    return BackupDataModel(
      version: 1,
      appName: 'Daily Apps',
      exportedAt: DateTime.now(),
      summary: summary,
      preferences: preferencesMap,
    );
  }

  /// Mengekspor file backup dengan dialog pemilihan lokasi dan nama file (Save As...)
  static Future<String?> saveBackupWithLocationPicker({
    String? customFileName,
  }) async {
    final backupData = await generateBackupData();
    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(backupData.toJson());

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final defaultFileName = customFileName ?? 'DailyApps_Backup_$timestamp.json';

    if (kIsWeb) {
      final saved = await saveFileWeb(
        Uint8List.fromList(utf8.encode(jsonString)),
        defaultFileName,
        askLocation: true,
      );
      return saved;
    }

    final outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Pilih Lokasi & Simpan File Cadangan',
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (outputFile == null) return null;

    final file = File(outputFile);
    await file.writeAsString(jsonString, flush: true);
    return file.path;
  }

  /// Mengekspor file backup langsung ke folder Download perangkat / browser
  static Future<String> saveBackupToDefaultDownload({
    String? customFileName,
  }) async {
    final backupData = await generateBackupData();
    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(backupData.toJson());

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = customFileName ?? 'DailyApps_Backup_$timestamp.json';

    if (kIsWeb) {
      await saveFileWeb(
        Uint8List.fromList(utf8.encode(jsonString)),
        fileName,
        askLocation: false,
      );
      return fileName;
    }

    Directory? targetDir;

    if (Platform.isAndroid) {
      final androidDownload = Directory('/storage/emulated/0/Download');
      try {
        if (await androidDownload.exists()) {
          targetDir = androidDownload;
        }
      } catch (_) {}

      if (targetDir == null) {
        try {
          final ext = await getExternalStorageDirectory();
          if (ext != null) targetDir = ext;
        } catch (_) {}
      }
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      try {
        final dl = await getDownloadsDirectory();
        if (dl != null && await dl.exists()) {
          targetDir = dl;
        }
      } catch (_) {}
      if (targetDir == null) {
        try {
          final docs = await getApplicationDocumentsDirectory();
          if (await docs.exists()) {
            targetDir = docs;
          }
        } catch (_) {}
      }
    }

    targetDir ??= await getTemporaryDirectory();

    final file = File('${targetDir.path}/$fileName');
    await file.writeAsString(jsonString, flush: true);
    return file.path;
  }

  /// Alias kompatibilitas untuk menyimpan ke folder Download default
  static Future<String> saveBackupToLocalStorage() async {
    return saveBackupToDefaultDownload();
  }

  /// Mengekspor file backup JSON sementara dan memicu sheet Share
  static Future<void> exportAndShareBackup() async {
    final backupData = await generateBackupData();
    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(backupData.toJson());
    final bytes = Uint8List.fromList(utf8.encode(jsonString));

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'DailyApps_Backup_$timestamp.json';

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            name: fileName,
            mimeType: 'application/json',
          ),
        ],
        subject: 'Backup Data Daily Apps',
        text:
            'File Cadangan Data Aplikasi Daily Apps (${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())})',
      ),
    );
  }

  /// Membaca dan memvalidasi string JSON cadangan
  static BackupDataModel parseAndValidateBackup(String jsonContent) {
    if (jsonContent.trim().isEmpty) {
      throw const FormatException('File cadangan kosong.');
    }

    final decoded = jsonDecode(jsonContent);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Format file tidak sesuai standar Daily Apps.');
    }

    if (!decoded.containsKey('preferences') || decoded['preferences'] is! Map) {
      throw const FormatException(
          'File tidak memiliki struktur data preferences yang valid.');
    }

    return BackupDataModel.fromJson(decoded);
  }

  /// Memulihkan seluruh data cadangan ke dalam SharedPreferences
  static Future<bool> restoreBackup(
    BackupDataModel backupModel, {
    bool cleanRestore = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (cleanRestore) {
      // Hapus seluruh data yang ada sebelum pemulihan bersih
      await prefs.clear();
      // Bersihkan memory cache bukti
      try {
        await EvidenceCacheService.clearAll();
      } catch (_) {}
    }

    final preferences = backupModel.preferences;

    for (final entry in preferences.entries) {
      final key = entry.key;
      final valObj = entry.value;

      if (valObj is Map) {
        final type = valObj['type']?.toString();
        final rawVal = valObj['value'];

        if (type == 'string' && rawVal != null) {
          await prefs.setString(key, rawVal.toString());
        } else if (type == 'string_list' && rawVal is List) {
          final stringList = rawVal.map((e) => e.toString()).toList();
          await prefs.setStringList(key, stringList);
        } else if (type == 'int' && rawVal is num) {
          await prefs.setInt(key, rawVal.toInt());
        } else if (type == 'bool' && rawVal is bool) {
          await prefs.setBool(key, rawVal);
        } else if (type == 'bool' && rawVal != null) {
          await prefs.setBool(key, rawVal.toString().toLowerCase() == 'true');
        } else if (type == 'double' && rawVal is num) {
          await prefs.setDouble(key, rawVal.toDouble());
        } else if (rawVal is String) {
          await prefs.setString(key, rawVal);
        } else if (rawVal is List) {
          await prefs.setStringList(
              key, rawVal.map((e) => e.toString()).toList());
        } else if (rawVal is int) {
          await prefs.setInt(key, rawVal);
        } else if (rawVal is bool) {
          await prefs.setBool(key, rawVal);
        } else if (rawVal is double) {
          await prefs.setDouble(key, rawVal);
        }
      } else if (valObj is String) {
        await prefs.setString(key, valObj);
      } else if (valObj is List) {
        await prefs.setStringList(
            key, valObj.map((e) => e.toString()).toList());
      } else if (valObj is bool) {
        await prefs.setBool(key, valObj);
      } else if (valObj is int) {
        await prefs.setInt(key, valObj);
      } else if (valObj is double) {
        await prefs.setDouble(key, valObj);
      }
    }

    return true;
  }
}
