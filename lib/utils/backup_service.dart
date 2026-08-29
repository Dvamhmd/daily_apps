import 'dart:convert';
import 'dart:io';
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
    return BackupDataModel(
      version: (json['version'] as num?)?.toInt() ?? 1,
      appName: json['appName'] as String? ?? 'Daily Apps',
      exportedAt: json['exportedAt'] != null
          ? DateTime.tryParse(json['exportedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      summary: json['summary'] is Map<String, dynamic>
          ? BackupSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : const BackupSummary(),
      preferences: json['preferences'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['preferences'] as Map)
          : {},
    );
  }
}

class BackupService {
  /// Menghitung ringkasan data yang tersimpan di perangkat saat ini
  static Future<BackupSummary> getLiveSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    int countUangku = 0;
    int countTagihan = 0;
    int countTabungan = (prefs.getStringList('tabungan') ?? []).length;
    int countTagihanLunas = (prefs.getStringList('tagihan_lunas') ?? []).length;
    int countRiwayatKeuangan =
        (prefs.getStringList('riwayat_keuangan_list') ?? []).length;
    int countStrukturMonths = 0;
    int countStrukturTransactions = 0;
    int countPribadiMonths = 0;
    int countPribadiTransactions = 0;
    int countRundowns = 0;
    int countTodoGroups = 0;
    int countTodoActiveItems = 0;
    int countTodoHistoryGroups = 0;
    int countTodoHistoryItems = 0;

    // Scan seluruh key SharedPreferences
    for (final key in keys) {
      if (key.startsWith('uangku_') || key == 'uangku') {
        final list = prefs.getStringList(key) ?? [];
        countUangku += list.length;
      } else if (key.startsWith('tagihan_') && key != 'tagihan_lunas') {
        final list = prefs.getStringList(key) ?? [];
        countTagihan += list.length;
      } else if (key == 'tagihan') {
        final list = prefs.getStringList(key) ?? [];
        countTagihan += list.length;
      } else if (key.startsWith('struktur_keuangan_data')) {
        countStrukturMonths++;
        final raw = prefs.getString(key);
        if (raw != null) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map<String, dynamic>) {
              final data = StrukturData.fromJson(decoded);
              countStrukturTransactions += data.transactions.length;
            }
          } catch (_) {}
        }
      } else if (key.startsWith('pribadi_keuangan_data')) {
        countPribadiMonths++;
        final raw = prefs.getString(key);
        if (raw != null) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map<String, dynamic>) {
              final data = PribadiData.fromJson(decoded);
              countPribadiTransactions += data.transactions.length;
            }
          } catch (_) {}
        }
      }
    }

    // Rundowns
    final rawRundowns = prefs.getStringList('rundowns_data') ?? [];
    countRundowns = rawRundowns.length;

    // Todo List Aktif
    final rawTodos = prefs.getString('todo_list_data');
    if (rawTodos != null && rawTodos.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTodos);
        if (decoded is List) {
          countTodoGroups = decoded.length;
          for (final g in decoded) {
            if (g is Map<String, dynamic>) {
              final group = TodoDateGroup.fromJson(g);
              countTodoActiveItems += group.items.length;
            }
          }
        }
      } catch (_) {}
    }

    // Todo List Riwayat
    final rawTodoHistory = prefs.getString('todo_history_data');
    if (rawTodoHistory != null && rawTodoHistory.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTodoHistory);
        if (decoded is List) {
          countTodoHistoryGroups = decoded.length;
          for (final g in decoded) {
            if (g is Map<String, dynamic>) {
              final group = TodoDateGroup.fromJson(g);
              countTodoHistoryItems += group.items.length;
            }
          }
        }
      } catch (_) {}
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
    final bytes = Uint8List.fromList(utf8.encode(jsonString));

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = customFileName ?? 'DailyApps_Backup_$timestamp.json';

    if (kIsWeb) {
      return await saveFileWeb(bytes, fileName, askLocation: true);
    }

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Pilih Lokasi Simpan File Cadangan',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );

    if (outputPath == null) {
      // Pengguna membatalkan pemilihan lokasi
      return null;
    }

    try {
      final file = File(outputPath);
      if (!await file.exists() || (await file.length()) == 0) {
        await file.writeAsString(jsonString, flush: true);
      }
    } catch (_) {}

    return outputPath;
  }

  /// Menyimpan file backup JSON langsung ke folder Download perangkat / browser download
  static Future<String> saveBackupToDefaultDownload({
    String? customFileName,
  }) async {
    final backupData = await generateBackupData();
    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(backupData.toJson());
    final bytes = Uint8List.fromList(utf8.encode(jsonString));

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = customFileName ?? 'DailyApps_Backup_$timestamp.json';

    if (kIsWeb) {
      final res = await saveFileWeb(bytes, fileName, askLocation: false);
      return res ?? fileName;
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

        if (type == 'string' && rawVal is String) {
          await prefs.setString(key, rawVal);
        } else if (type == 'string_list' && rawVal is List) {
          final stringList = rawVal.map((e) => e.toString()).toList();
          await prefs.setStringList(key, stringList);
        } else if (type == 'int' && rawVal is num) {
          await prefs.setInt(key, rawVal.toInt());
        } else if (type == 'bool' && rawVal is bool) {
          await prefs.setBool(key, rawVal);
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
        }
      }
    }

    return true;
  }
}
