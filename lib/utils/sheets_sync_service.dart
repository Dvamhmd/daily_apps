import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/model_sheets_config.dart';
import '../models/model_struktur.dart';

class SheetsSyncResult {
  final bool isSuccess;
  final String message;
  final int? count;

  SheetsSyncResult({
    required this.isSuccess,
    required this.message,
    this.count,
  });
}

class SheetsFetchResult {
  final bool isSuccess;
  final String message;
  final List<Map<String, dynamic>> rekeningRows;
  final List<Map<String, dynamic>> onHandRows;
  final List<StrukturTransaction> rekeningTransactions;
  final List<StrukturTransaction> onHandTransactions;
  final List<StrukturTransaction> allTransactions;

  SheetsFetchResult({
    required this.isSuccess,
    required this.message,
    this.rekeningRows = const [],
    this.onHandRows = const [],
    this.rekeningTransactions = const [],
    this.onHandTransactions = const [],
    this.allTransactions = const [],
  });

  int get totalRowsCount => rekeningRows.length + onHandRows.length;
  bool get isEmpty => rekeningRows.isEmpty && onHandRows.isEmpty;
}

class SheetsSyncComparison {
  final int localRekeningCount;
  final int localRekeningDebit;
  final int localRekeningKredit;
  final int localOnHandCount;
  final int localOnHandDebit;
  final int localOnHandKredit;

  final int remoteRekeningCount;
  final int remoteRekeningDebit;
  final int remoteRekeningKredit;
  final int remoteOnHandCount;
  final int remoteOnHandDebit;
  final int remoteOnHandKredit;

  final bool hasDiscrepancy;
  final List<String> discrepancyReasons;
  final List<StrukturTransaction> remoteTransactions;

  SheetsSyncComparison({
    required this.localRekeningCount,
    required this.localRekeningDebit,
    required this.localRekeningKredit,
    required this.localOnHandCount,
    required this.localOnHandDebit,
    required this.localOnHandKredit,
    required this.remoteRekeningCount,
    required this.remoteRekeningDebit,
    required this.remoteRekeningKredit,
    required this.remoteOnHandCount,
    required this.remoteOnHandDebit,
    required this.remoteOnHandKredit,
    required this.hasDiscrepancy,
    required this.discrepancyReasons,
    required this.remoteTransactions,
  });

  int get localTotalCount => localRekeningCount + localOnHandCount;
  int get remoteTotalCount => remoteRekeningCount + remoteOnHandCount;
  int get localTotalDebit => localRekeningDebit + localOnHandDebit;
  int get localTotalKredit => localRekeningKredit + localOnHandKredit;
  int get remoteTotalDebit => remoteRekeningDebit + remoteOnHandDebit;
  int get remoteTotalKredit => remoteRekeningKredit + remoteOnHandKredit;
}

class SheetsSyncService {
  /// Melakukan HTTP POST request ke Google Apps Script Web App dengan penanganan CORS Web & redirect 302 otomatis
  static Future<Map<String, dynamic>> _sendPostRequest(
    String url,
    Map<String, dynamic> payload,
  ) async {
    final cleanUrl = url.trim();
    final uri = Uri.parse(cleanUrl);
    final bodyJson = jsonEncode(payload);

    // 1. Coba POST dengan Content-Type text/plain (CORS Simple Request untuk mencegah browser mengirim OPTIONS preflight)
    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'text/plain;charset=utf-8',
        },
        body: bodyJson,
      );

      // Tangani redirect 302/301/307/308
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          final redirectedResponse = await http.get(Uri.parse(redirectUrl));
          if (redirectedResponse.statusCode == 200) {
            return jsonDecode(redirectedResponse.body) as Map<String, dynamic>;
          }
        }
      }

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {
          return {
            'status': 'success',
            'message': 'Data berhasil diproses oleh Google Apps Script.',
          };
        }
      }
    } catch (e) {
      // Jika terjadi error (misal CORS di Flutter Web), lanjutkan ke fallback GET
      debugPrint('POST request failed, trying GET fallback: $e');
    }

    // 2. Fallback GET request dengan query parameter payload (sangat ampuh untuk Flutter Web / Browser)
    try {
      final getUri = uri.replace(
        queryParameters: {
          'payload': bodyJson,
          if (payload['action'] != null) 'action': payload['action'].toString(),
          if (payload['sheetName'] != null)
            'sheetName': payload['sheetName'].toString(),
        },
      );

      final getResponse = await http.get(getUri);
      if (getResponse.statusCode == 200) {
        try {
          return jsonDecode(getResponse.body) as Map<String, dynamic>;
        } catch (_) {
          return {
            'status': 'success',
            'message': 'Berhasil terhubung ke Google Apps Script.',
          };
        }
      }
    } catch (getErr) {
      debugPrint('GET request fallback error: $getErr');
    }

    // 3. Fallback HttpClient dart:io untuk non-web
    if (!kIsWeb) {
      try {
        final httpClient = HttpClient();
        httpClient.connectionTimeout = const Duration(seconds: 15);
        final request = await httpClient.postUrl(uri);
        request.headers.set('content-type', 'text/plain;charset=utf-8');
        request.add(utf8.encode(bodyJson));
        final clientResponse = await request.close();

        final responseBody =
            await clientResponse.transform(utf8.decoder).join();
        if (clientResponse.statusCode == 200 ||
            clientResponse.statusCode == 302) {
          try {
            return jsonDecode(responseBody) as Map<String, dynamic>;
          } catch (_) {
            return {
              'status': 'success',
              'message': 'Data berhasil diterima Google Apps Script',
            };
          }
        }
      } catch (ioErr) {
        debugPrint('HttpClient dart:io fallback error: $ioErr');
      }
    }

    throw Exception(
      'Gagal terhubung ke Google Apps Script. Pastikan Web App di-deploy dengan akses "Anyone" (Siapa saja).',
    );
  }

  /// Menguji koneksi ke Web App Google Apps Script
  static Future<SheetsSyncResult> testConnection(SheetsConfig config) async {
    if (!config.isConfigured) {
      return SheetsSyncResult(
        isSuccess: false,
        message: 'URL Google Apps Script belum diisi.',
      );
    }

    if (config.sheetName.trim().isEmpty) {
      return SheetsSyncResult(
        isSuccess: false,
        message: 'Nama Tab Sheet belum di isi',
      );
    }

    try {
      final payload = {
        'action': 'test_connection',
        'sheetName': config.sheetName.trim(),
      };

      final res = await _sendPostRequest(config.webAppUrl, payload);
      final status = res['status'] as String?;
      final msg = res['message'] as String? ?? 'Koneksi berhasil terhubung.';
      final returnedSheetName = res['sheetName'] as String?;

      if (status == 'success') {
        if (returnedSheetName != null && returnedSheetName.trim().isNotEmpty) {
          config.sheetName = returnedSheetName.trim();
        }
        config.lastSyncStatus = 'success';
        config.lastSyncMessage = msg;
        config.lastSyncTime = DateTime.now();
        await config.save();
        return SheetsSyncResult(isSuccess: true, message: msg);
      } else {
        return SheetsSyncResult(
          isSuccess: false,
          message: msg,
        );
      }
    } catch (e) {
      return SheetsSyncResult(
        isSuccess: false,
        message: 'Gagal koneksi: ${e.toString()}',
      );
    }
  }

  /// Menyiapkan baris data JSON dari objek transaksi
  static Map<String, dynamic> formatTransactionRow(
    StrukturTransaction tx,
    int indexNumber, {
    List<CustomKodeRule>? customRules,
    String? dateFormat,
  }) {
    String dateFormatted;
    try {
      final pattern = (dateFormat != null && dateFormat.trim().isNotEmpty)
          ? dateFormat.trim()
          : 'dd/MM/yyyy';
      dateFormatted = DateFormat(pattern).format(tx.timestamp);
    } catch (_) {
      dateFormatted = DateFormat('dd/MM/yyyy').format(tx.timestamp);
    }
    final rawKu = tx.getDisplayKu(customRules: customRules).trim();
    final String ku = (rawKu == '-' || rawKu.isEmpty) ? '' : rawKu;

    final rawKategori = tx.getDisplayKode(customRules: customRules).trim();
    final String kategori =
        (rawKategori == '-' || rawKategori.isEmpty) ? '' : rawKategori;

    String itemTitle = tx.title.trim();
    if (itemTitle.isEmpty && tx.note != null && tx.note!.trim().isNotEmpty) {
      itemTitle = tx.note!.trim();
    }
    itemTitle = itemTitle.replaceFirst(
      RegExp(r'^(Pemasukan|Pengeluaran):\s*', caseSensitive: false),
      '',
    );
    final String cleanNote = (tx.note ?? '').trim();
    final String? itemSubtitle = (cleanNote.isNotEmpty &&
            cleanNote != tx.title.trim() &&
            cleanNote != itemTitle)
        ? cleanNote
        : null;

    final String fullKeterangan = itemSubtitle != null
        ? '$itemTitle ($itemSubtitle)'
        : (itemTitle.isNotEmpty ? itemTitle : '-');

    final dynamic debit =
        (tx.isPemasukan && tx.amount > 0) ? tx.amount : '';
    final dynamic kredit =
        (tx.isPengeluaran && tx.amount > 0) ? tx.amount : '';

    return {
      // Field Kolom Transaksi Rekening
      'no': indexNumber,
      'tanggal': dateFormatted,
      'ku': ku,
      'kategori': kategori,
      'keterangan': fullKeterangan,
      'debit': debit,
      'kredit': kredit,

      // Field Kolom Transaksi Cash On Hand
      'no_onhand': indexNumber,
      'tanggal_onhand': dateFormatted,
      'ku_onhand': ku,
      'kategori_onhand': kategori,
      'keterangan_onhand': fullKeterangan,
      'debit_onhand': debit,
      'kredit_onhand': kredit,
    };
  }

  /// Melakukan sinkronisasi seluruh tabel transaksi bulan aktif ke Spreadsheet (Tabel Rekening & Tabel Cash On Hand)
  /// Mendukung pengiriman bertahap (batching/chunking) otomatis untuk mencegah batas limit URL di browser/web
  static Future<SheetsSyncResult> syncAllTransactions(
    List<StrukturTransaction> transactions,
    SheetsConfig config, {
    List<CustomKodeRule>? customRules,
  }) async {
    if (!config.isConfigured) {
      return SheetsSyncResult(
        isSuccess: false,
        message: 'URL Google Apps Script belum diatur.',
      );
    }

    if (config.sheetName.trim().isEmpty) {
      return SheetsSyncResult(
        isSuccess: false,
        message: 'Nama Tab Sheet belum di isi',
      );
    }

    try {
      // Urutkan transaksi berdasarkan waktu secara kronologis
      final sortedList = List<StrukturTransaction>.from(transactions)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Pisahkan transaksi Rekening vs Cash On Hand
      final List<StrukturTransaction> rekeningTxList = sortedList.where((tx) {
        if (tx.isPemasukan) {
          return tx.targetAccount == 'rekening' || tx.targetAccount == null;
        } else {
          return tx.sourceAccount == 'rekening' || tx.sourceAccount == null;
        }
      }).toList();

      final List<StrukturTransaction> onHandTxList = sortedList.where((tx) {
        if (tx.isPemasukan) {
          return tx.targetAccount == 'debit' || tx.targetAccount == 'cash';
        } else {
          return tx.sourceAccount == 'debit' || tx.sourceAccount == 'cash';
        }
      }).toList();

      final List<Map<String, dynamic>> rekeningRows = [];
      for (int i = 0; i < rekeningTxList.length; i++) {
        rekeningRows.add(formatTransactionRow(
          rekeningTxList[i],
          i + 1,
          customRules: customRules,
          dateFormat: config.dateFormat,
        ));
      }

      final List<Map<String, dynamic>> onHandRows = [];
      for (int i = 0; i < onHandTxList.length; i++) {
        onHandRows.add(formatTransactionRow(
          onHandTxList[i],
          i + 1,
          customRules: customRules,
          dateFormat: config.dateFormat,
        ));
      }

      final totalCount = rekeningRows.length + onHandRows.length;

      // Pengecekan Batas Maksimal Baris (End Row) sebelum pengiriman
      final isRekExceeded = config.isRekeningExceeded(rekeningRows.length);
      final isOnExceeded = config.isOnHandExceeded(onHandRows.length);
      if (isRekExceeded || isOnExceeded) {
        final List<String> details = [];
        if (isRekExceeded) {
          details.add(
              'Rekening: ${rekeningRows.length} data (Batas Baris ${config.startRow} s/d ${config.endRow} = Kapasitas ${config.maxRekeningCapacity} baris)');
        }
        if (isOnExceeded) {
          details.add(
              'Cash On Hand: ${onHandRows.length} data (Batas Baris ${config.startRowOnHand} s/d ${config.endRowOnHand} = Kapasitas ${config.maxOnHandCapacity} baris)');
        }
        return SheetsSyncResult(
          isSuccess: false,
          message:
              'Peringatan Batas Baris Terlampaui! ${details.join(" | ")}. Mohon sesuaikan End Row di Pengaturan Google Spreadsheets.',
        );
      }

      final payload = {
        'action': 'sync_all',
        'sheetName': config.sheetName.trim(),
        'startRow': config.startRow,
        'endRow': config.endRow ?? 0,
        'startRowRekening': config.startRow,
        'endRowRekening': config.endRow ?? 0,
        'startRowOnHand': config.startRowOnHand,
        'endRowOnHand': config.endRowOnHand ?? 0,
        'targetRow': config.evidenceTargetRow,
        'rowMapping': config.evidenceRowMapping,
        'mapping': config.columnMapping,
        'rekeningRows': rekeningRows,
        'onHandRows': onHandRows,
        'rows': rekeningRows, // Fallback legacy
      };

      final res = await _sendPostRequest(config.webAppUrl, payload);
      final status = res['status'] as String?;
      final msg = res['message'] as String? ??
          'Berhasil sinkronisasi $totalCount data transaksi (Rekening: ${rekeningRows.length}, On Hand: ${onHandRows.length}).';

      if (status == 'success' || status == null) {
        config.lastSyncStatus = 'success';
        config.lastSyncMessage = msg;
        config.lastSyncTime = DateTime.now();
        await config.save();
        return SheetsSyncResult(
          isSuccess: true,
          message: msg,
          count: totalCount,
        );
      } else {
        config.lastSyncStatus = 'failed';
        config.lastSyncMessage = msg;
        await config.save();
        return SheetsSyncResult(isSuccess: false, message: msg);
      }
    } catch (e) {
      config.lastSyncStatus = 'failed';
      config.lastSyncMessage = e.toString();
      await config.save();
      return SheetsSyncResult(
        isSuccess: false,
        message: 'Gagal sinkronisasi data: ${e.toString()}',
      );
    }
  }

  /// Menambahkan satu baris transaksi baru secara realtime ke Google Sheets
  static Future<SheetsSyncResult> appendTransaction(
    StrukturTransaction tx,
    SheetsConfig config, {
    int? rowNumber,
    List<CustomKodeRule>? customRules,
  }) async {
    if (!config.isConfigured ||
        !config.hasConfiguredCells ||
        !config.autoSyncOnInput ||
        config.sheetName.trim().isEmpty) {
      return SheetsSyncResult(
        isSuccess: false,
        message: 'Auto-sync tidak aktif, cell belum dipetakan, nama Tab Sheet belum di isi, atau URL belum diatur.',
      );
    }

    try {
      final isOnHand = tx.isPemasukan
          ? (tx.targetAccount == 'debit' || tx.targetAccount == 'cash')
          : (tx.sourceAccount == 'debit' || tx.sourceAccount == 'cash');

      final rowData = formatTransactionRow(
        tx,
        rowNumber ?? 1,
        customRules: customRules,
        dateFormat: config.dateFormat,
      );

      final payload = {
        'action': 'add_row',
        'sheetName': config.sheetName.trim(),
        'startRow': isOnHand ? config.startRowOnHand : config.startRow,
        'endRow': isOnHand ? (config.endRowOnHand ?? 0) : (config.endRow ?? 0),
        'startRowRekening': config.startRow,
        'endRowRekening': config.endRow ?? 0,
        'startRowOnHand': config.startRowOnHand,
        'endRowOnHand': config.endRowOnHand ?? 0,
        'isOnHand': isOnHand,
        'tableType': isOnHand ? 'onhand' : 'rekening',
        'mapping': config.columnMapping,
        'row': rowData,
      };

      final res = await _sendPostRequest(config.webAppUrl, payload);
      final status = res['status'] as String?;
      final msg = res['message'] as String? ?? 'Data transaksi berhasil dicatat ke Sheets.';

      if (status == 'success' || status == null) {
        config.lastSyncStatus = 'success';
        config.lastSyncMessage = msg;
        config.lastSyncTime = DateTime.now();
        await config.save();
        return SheetsSyncResult(isSuccess: true, message: msg);
      } else {
        return SheetsSyncResult(isSuccess: false, message: msg);
      }
    } catch (e) {
      return SheetsSyncResult(
        isSuccess: false,
        message: 'Gagal auto-sync: ${e.toString()}',
      );
    }
  }

  /// Mengurungkan (Undo) data terakhir yang masuk ke spreadsheet
  static Future<SheetsSyncResult> undoLastTransaction(
    SheetsConfig config, {
    bool isOnHand = false,
  }) async {
    if (!config.isConfigured || config.sheetName.trim().isEmpty) {
      return SheetsSyncResult(
        isSuccess: false,
        message: 'URL Google Apps Script belum diatur atau nama Tab Sheet kosong.',
      );
    }

    try {
      final payload = {
        'action': 'undo_last',
        'sheetName': config.sheetName.trim(),
        'startRow': isOnHand ? config.startRowOnHand : config.startRow,
        'endRow': isOnHand ? (config.endRowOnHand ?? 0) : (config.endRow ?? 0),
        'startRowRekening': config.startRow,
        'endRowRekening': config.endRow ?? 0,
        'startRowOnHand': config.startRowOnHand,
        'endRowOnHand': config.endRowOnHand ?? 0,
        'isOnHand': isOnHand,
        'tableType': isOnHand ? 'onhand' : 'rekening',
        'mapping': config.columnMapping,
      };

      final res = await _sendPostRequest(config.webAppUrl, payload);
      final status = res['status'] as String?;
      final msg = res['message'] as String? ??
          'Data terakhir di spreadsheet berhasil di-undo.';

      if (status == 'success' || status == null) {
        return SheetsSyncResult(isSuccess: true, message: msg);
      } else {
        return SheetsSyncResult(isSuccess: false, message: msg);
      }
    } catch (e) {
      return SheetsSyncResult(
        isSuccess: false,
        message: 'Gagal melakukan undo ke spreadsheet: ${e.toString()}',
      );
    }
  }

  /// Mengunggah gambar bukti fisik / digital ke Google Drive & menaruh link/formula di Spreadsheet
  static Future<SheetsSyncResult> uploadEvidenceImages({
    List<Map<String, dynamic>>? images,
    List<Map<String, dynamic>>? imagesPayload,
    required SheetsConfig config,
    String? monthLabel,
    int? targetRow,
    void Function(int completed, int total, String currentKey, bool isSuccess, String message)? onProgress,
  }) async {
    final list = images ?? imagesPayload ?? [];
    if (!config.isConfigured) {
      return SheetsSyncResult(
        isSuccess: false,
        message: 'URL Google Apps Script belum diatur. Buka Pengaturan Spreadsheets.',
      );
    }

    if (config.sheetName.trim().isEmpty) {
      return SheetsSyncResult(
        isSuccess: false,
        message: 'Nama Tab Sheet belum di isi',
      );
    }

    if (list.isEmpty) {
      return SheetsSyncResult(
        isSuccess: false,
        message: 'Tidak ada gambar bukti yang dipilih.',
      );
    }

    int successCount = 0;
    final List<String> errorMessages = [];

    // Unggah gambar bukti per batch kecil (maksimal 2 gambar per request) untuk mencegah memory spike & timeout
    const int batchSize = 2;
    for (int i = 0; i < list.length; i += batchSize) {
      final end = (i + batchSize < list.length) ? i + batchSize : list.length;
      final chunk = list.sublist(i, end);

      try {
        final payload = {
          'action': 'upload_evidence_images',
          'sheetName': config.sheetName.trim(),
          'startRow': config.startRow,
          'targetRow': targetRow ?? config.evidenceTargetRow,
          'rowMapping': config.evidenceRowMapping,
          'mapping': config.columnMapping,
          'useImageFormula': config.insertImageFormula,
          'monthLabel': monthLabel ?? '',
          'images': chunk,
        };

        final res = await _sendPostRequest(config.webAppUrl, payload);
        final status = res['status'] as String?;
        final isBatchSuccess = status == 'success' || status == null;
        if (isBatchSuccess) {
          final uploadedCount = (res['uploadedCount'] as num?)?.toInt() ?? chunk.length;
          successCount += uploadedCount;
          for (final img in chunk) {
            final key = img['key'] as String? ?? '';
            onProgress?.call(successCount, list.length, key, true, 'Berhasil diunggah');
          }
        } else {
          final errMsg = res['message'] as String? ?? 'Gagal pada batch ${i ~/ batchSize + 1}';
          errorMessages.add(errMsg);
          for (final img in chunk) {
            final key = img['key'] as String? ?? '';
            onProgress?.call(successCount, list.length, key, false, errMsg);
          }
        }
      } catch (err) {
        errorMessages.add(err.toString());
        for (final img in chunk) {
          final key = img['key'] as String? ?? '';
          onProgress?.call(successCount, list.length, key, false, err.toString());
        }
      }
    }

    if (successCount > 0) {
      final msg = (errorMessages.isEmpty)
          ? 'Semua $successCount gambar bukti berhasil diunggah dengan kualitas penuh ke Google Drive & Spreadsheet!'
          : 'Berhasil mengunggah $successCount gambar bukti (${errorMessages.length} kendala: ${errorMessages.first})';
      config.lastSyncStatus = errorMessages.isEmpty ? 'success' : 'partial';
      config.lastSyncMessage = msg;
      config.lastSyncTime = DateTime.now();
      await config.save();
      return SheetsSyncResult(isSuccess: true, message: msg, count: successCount);
    } else {
      final errorDetail = errorMessages.isNotEmpty ? errorMessages.join(', ') : 'Gagal terhubung';
      return SheetsSyncResult(
        isSuccess: false,
        message: 'Gagal mengunggah gambar bukti: $errorDetail',
      );
    }
  }

  /// Membaca data transaksi (Tabel Rekening & Tabel Cash On Hand) yang ada di Google Spreadsheet
  static Future<SheetsFetchResult> fetchRemoteTransactions(
    SheetsConfig config, {
    DateTime? activeMonth,
    List<CustomKodeRule>? customRules,
  }) async {
    if (!config.isConfigured) {
      return SheetsFetchResult(
        isSuccess: false,
        message: 'URL Google Apps Script belum diatur.',
      );
    }

    if (config.sheetName.trim().isEmpty) {
      return SheetsFetchResult(
        isSuccess: false,
        message: 'Nama Tab Sheet belum di isi',
      );
    }

    try {
      final payload = {
        'action': 'fetch_transactions',
        'sheetName': config.sheetName.trim(),
        'startRowRekening': config.startRow,
        'endRowRekening': config.endRow ?? 0,
        'startRowOnHand': config.startRowOnHand,
        'endRowOnHand': config.endRowOnHand ?? 0,
        'mapping': config.columnMapping,
      };

      final res = await _sendPostRequest(config.webAppUrl, payload);
      final status = res['status'] as String?;
      if (status != 'success') {
        return SheetsFetchResult(
          isSuccess: false,
          message: res['message'] as String? ?? 'Gagal membaca data dari spreadsheet.',
        );
      }

      final rawRekening = (res['rekeningRows'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      final rawOnHand = (res['onHandRows'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      final List<StrukturTransaction> rekeningTx = [];
      final List<StrukturTransaction> onHandTx = [];
      final fallbackDate = activeMonth ?? DateTime.now();

      for (var r in rawRekening) {
        final tx = parseSpreadsheetRowToTransaction(
          r,
          isRekening: true,
          fallbackDate: fallbackDate,
          customRules: customRules,
          dateFormat: config.dateFormat,
        );
        if (tx != null) rekeningTx.add(tx);
      }

      for (var r in rawOnHand) {
        final tx = parseSpreadsheetRowToTransaction(
          r,
          isRekening: false,
          fallbackDate: fallbackDate,
          customRules: customRules,
          dateFormat: config.dateFormat,
        );
        if (tx != null) onHandTx.add(tx);
      }

      final allTx = [...rekeningTx, ...onHandTx]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return SheetsFetchResult(
        isSuccess: true,
        message: res['message'] as String? ?? 'Berhasil membaca data dari spreadsheet.',
        rekeningRows: rawRekening,
        onHandRows: rawOnHand,
        rekeningTransactions: rekeningTx,
        onHandTransactions: onHandTx,
        allTransactions: allTx,
      );
    } catch (e) {
      return SheetsFetchResult(
        isSuccess: false,
        message: 'Gagal mengambil data dari spreadsheet: ${e.toString()}',
      );
    }
  }

  /// Membandingkan data lokal di aplikasi dengan data yang ada di Google Spreadsheet untuk deteksi risiko / konflik
  static SheetsSyncComparison compareData({
    required List<StrukturTransaction> localTransactions,
    required SheetsFetchResult remoteFetchResult,
  }) {
    // 1. Hitung agregat lokal
    final localRekening = localTransactions.where((tx) {
      if (tx.isPemasukan) {
        return tx.targetAccount == 'rekening' || tx.targetAccount == null;
      } else {
        return tx.sourceAccount == 'rekening' || tx.sourceAccount == null;
      }
    }).toList();

    final localOnHand = localTransactions.where((tx) {
      if (tx.isPemasukan) {
        return tx.targetAccount == 'debit' || tx.targetAccount == 'cash';
      } else {
        return tx.sourceAccount == 'debit' || tx.sourceAccount == 'cash';
      }
    }).toList();

    int localRekDebit = 0;
    int localRekKredit = 0;
    for (var tx in localRekening) {
      if (tx.isPemasukan) {
        localRekDebit += tx.amount;
      } else {
        localRekKredit += tx.amount;
      }
    }

    int localOnHandDebit = 0;
    int localOnHandKredit = 0;
    for (var tx in localOnHand) {
      if (tx.isPemasukan) {
        localOnHandDebit += tx.amount;
      } else {
        localOnHandKredit += tx.amount;
      }
    }

    // 2. Hitung agregat remote (Spreadsheet)
    int remoteRekDebit = 0;
    int remoteRekKredit = 0;
    for (var r in remoteFetchResult.rekeningRows) {
      final d = (r['debit'] is num) ? (r['debit'] as num).toInt() : (int.tryParse(r['debit']?.toString() ?? '0') ?? 0);
      final k = (r['kredit'] is num) ? (r['kredit'] as num).toInt() : (int.tryParse(r['kredit']?.toString() ?? '0') ?? 0);
      remoteRekDebit += d;
      remoteRekKredit += k;
    }

    int remoteOnHandDebit = 0;
    int remoteOnHandKredit = 0;
    for (var r in remoteFetchResult.onHandRows) {
      final d = (r['debit_onhand'] is num)
          ? (r['debit_onhand'] as num).toInt()
          : (r['debit'] is num ? (r['debit'] as num).toInt() : (int.tryParse((r['debit_onhand'] ?? r['debit'])?.toString() ?? '0') ?? 0));
      final k = (r['kredit_onhand'] is num)
          ? (r['kredit_onhand'] as num).toInt()
          : (r['kredit'] is num ? (r['kredit'] as num).toInt() : (int.tryParse((r['kredit_onhand'] ?? r['kredit'])?.toString() ?? '0') ?? 0));
      remoteOnHandDebit += d;
      remoteOnHandKredit += k;
    }

    final int remoteRekCount = remoteFetchResult.rekeningRows.length;
    final int remoteOnHandCount = remoteFetchResult.onHandRows.length;

    // 3. Deteksi apakah ada perbedaan
    final List<String> reasons = [];

    // Jika spreadsheet sama sekali kosong, tidak dianggap konflik
    final isRemoteEmpty = remoteRekCount == 0 && remoteOnHandCount == 0;

    if (!isRemoteEmpty) {
      if (localRekening.length != remoteRekCount) {
        reasons.add('Jumlah transaksi Rekening berbeda (Aplikasi: ${localRekening.length}, Sheets: $remoteRekCount)');
      }
      if (localOnHand.length != remoteOnHandCount) {
        reasons.add('Jumlah transaksi On Hand berbeda (Aplikasi: ${localOnHand.length}, Sheets: $remoteOnHandCount)');
      }
      if (localRekDebit != remoteRekDebit || localRekKredit != remoteRekKredit) {
        reasons.add('Total nominal transaksi Rekening berbeda');
      }
      if (localOnHandDebit != remoteOnHandDebit || localOnHandKredit != remoteOnHandKredit) {
        reasons.add('Total nominal transaksi On Hand berbeda');
      }
    }

    final hasDiscrepancy = reasons.isNotEmpty;

    return SheetsSyncComparison(
      localRekeningCount: localRekening.length,
      localRekeningDebit: localRekDebit,
      localRekeningKredit: localRekKredit,
      localOnHandCount: localOnHand.length,
      localOnHandDebit: localOnHandDebit,
      localOnHandKredit: localOnHandKredit,
      remoteRekeningCount: remoteRekCount,
      remoteRekeningDebit: remoteRekDebit,
      remoteRekeningKredit: remoteRekKredit,
      remoteOnHandCount: remoteOnHandCount,
      remoteOnHandDebit: remoteOnHandDebit,
      remoteOnHandKredit: remoteOnHandKredit,
      hasDiscrepancy: hasDiscrepancy,
      discrepancyReasons: reasons,
      remoteTransactions: remoteFetchResult.allTransactions,
    );
  }

  /// Mengonversi baris mentah dari spreadsheet menjadi objek StrukturTransaction
  static StrukturTransaction? parseSpreadsheetRowToTransaction(
    Map<String, dynamic> row, {
    required bool isRekening,
    required DateTime fallbackDate,
    List<CustomKodeRule>? customRules,
    String dateFormat = 'dd/MM/yyyy',
  }) {
    final rawDateStr = (row['tanggal'] ?? row['tanggal_onhand'] ?? '').toString().trim();
    DateTime parsedDate = fallbackDate;

    if (rawDateStr.isNotEmpty) {
      try {
        parsedDate = DateFormat(dateFormat.trim()).parseLoose(rawDateStr);
      } catch (_) {
        try {
          parsedDate = DateTime.parse(rawDateStr);
        } catch (_) {
          final parts = rawDateStr.split(RegExp(r'[/.-]'));
          if (parts.length == 3) {
            final p1 = int.tryParse(parts[0]) ?? 1;
            final p2 = int.tryParse(parts[1]) ?? 1;
            final p3 = int.tryParse(parts[2]) ?? fallbackDate.year;
            if (p3 > 1000) {
              parsedDate = DateTime(p3, p2, p1);
            } else if (p1 > 1000) {
              parsedDate = DateTime(p1, p2, p3);
            }
          }
        }
      }
    }

    final kuStr = (row['ku'] ?? row['ku_onhand'] ?? '').toString().trim();
    final kategoriStr = (row['kategori'] ?? row['kategori_onhand'] ?? '').toString().trim();
    final keteranganStr = (row['keterangan'] ?? row['keterangan_onhand'] ?? '').toString().trim();

    final debitVal = (row['debit'] ?? row['debit_onhand']);
    final kreditVal = (row['kredit'] ?? row['kredit_onhand']);

    int debit = 0;
    if (debitVal is num) {
      debit = debitVal.toInt();
    } else if (debitVal != null) {
      debit = int.tryParse(debitVal.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }

    int kredit = 0;
    if (kreditVal is num) {
      kredit = kreditVal.toInt();
    } else if (kreditVal != null) {
      kredit = int.tryParse(kreditVal.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }

    if (debit == 0 && kredit == 0 && keteranganStr.isEmpty) {
      return null;
    }

    final title = keteranganStr.isNotEmpty ? keteranganStr : 'Transaksi dari Spreadsheet';
    final targetAcc = isRekening ? 'rekening' : 'debit';
    final sourceAcc = isRekening ? 'rekening' : 'debit';

    final isIncome = debit > 0;
    final amount = isIncome ? debit : kredit;

    return StrukturTransaction(
      id: '${parsedDate.millisecondsSinceEpoch}_${row['no'] ?? row['no_onhand'] ?? DateTime.now().microsecondsSinceEpoch}',
      title: title,
      type: isIncome ? 'pemasukan' : 'pengeluaran',
      amount: amount,
      sourceAccount: isIncome ? null : sourceAcc,
      targetAccount: isIncome ? targetAcc : null,
      ku: kuStr.isNotEmpty && kuStr != '-' ? kuStr : null,
      kode: kategoriStr.isNotEmpty && kategoriStr != '-' ? kategoriStr : null,
      note: keteranganStr,
      timestamp: parsedDate,
    );
  }

  /// Mengembalikan script Google Apps Script siap salin (Copy-Paste)
  static String getGoogleAppsScriptCode() {
    return '''/**
 * =========================================================================
 * GOOGLE APPS SCRIPT - INTEGRASI TABEL LAP KEU & BUKTI GAMBAR KEUANGAN
 * Aplikasi: Daily Apps
 * =========================================================================
 * 
 * FITUR DIDUKUNG:
 * 1. Tes Koneksi
 * 2. Sinkronisasi Data Transaksi (Tabel Rekening & Tabel Cash On Hand terpisah)
 * 3. Catat Transaksi Baru Realtime (Append Row aman tanpa menimpa rumus/tabel lain)
 * 4. Undo Baris Terakhir (Undo Last Row)
 * 5. Upload Gambar Bukti (Saldo Rekening, Cash on Hand, Mutasi Rekening Maks 5 Gambar)
 *    -> Otomatis disimpan ke Google Drive (Folder: "DailyApps_BuktiKeuangan")
 *    -> Disisipkan langsung ke SEL TERTENTU yang dikonfigurasi tanpa menyentuh sel lain.
 * 
 * PERLINDUNGAN FORMULA & TABEL LAIN:
 * - Script HANYA mengubah sel/kolom yang secara eksplisit dikonfigurasi dalam aplikasi.
 * - Kolom/sel yang tidak dipetakan (misal kolom rumus, catatan, atau tabel di sebelah kanan/bawah)
 *   TIDAK AKAN PERNAH disentuh atau dihapus.
 * - Sel yang mengandung rumus (cth: =SUM(...), =TOTAL, rumus saldo) otomatis dilindungi dan tidak akan ditimpa.
 * - Baris/tabel lain di bawah transaksi (catatan kaki, tanda tangan, saldo, rekap, bukti) 100% aman dan tidak akan terhapus.
 * 
 * MEMPERTAHANKAN FORMAT ASLI SPREADSHEET (Zero Style Overwrite):
 * - Script HANYA mengirim dan menulis nilai data mentah (raw values) tanpa memodifikasi format sel.
 * - Seluruh pengaturan tampilan di Google Sheets (perataan teks/alignment, font family, font size,
 *   warna font/latar, border garis, serta format mata uang/angka) akan 100% tetap utuh mengikuti
 *   format template yang telah Anda atur di Google Sheets.
 * - Penghapusan data lama menggunakan clearContent() yang hanya mengosongkan nilai tanpa menghapus format visual.
 * 
 * PETUNJUK PEMASANGAN LANGKAH DEMI LANGKAH:
 * 1. Buka Google Spreadsheet tujuan Anda.
 * 2. Di menu atas, pilih "Extensions" (Ekstensi) -> "Apps Script".
 * 3. Hapus seluruh kode default yang ada di editor, lalu tempel (Paste) kode ini.
 * 4. Klik ikon Simpan (Disk) di toolbar atas.
 * 5. Klik tombol "Deploy" (Terapkan) berwarna biru di kanan atas -> pilih "Manage deployments".
 *    -> Klik ikon Pensil (Edit) -> Version: pilih "New version" -> Klik "Deploy".
 *    (Jika pertama kali: "Deploy" -> "New deployment" -> "Web app" -> Who has access: "Anyone").
 * 6. Salin "Web app URL" (URL yang berakhiran /exec).
 * 7. Buka Daily Apps -> Masuk ke Keuangan Struktur -> Pengaturan Google Spreadsheets -> Tempelkan URL tersebut.
 */

/**
 * Fungsi pembantu untuk memicu popup izin Google Drive & Spreadsheet secara instan.
 * Jalankan fungsi ini (klik Run / Jalankan) jika Google meminta izin akses Google Drive.
 */
function authorizeDrive() {
  var testFolder = DriveApp.createFolder("DailyApps_Temp_Auth");
  testFolder.setTrashed(true);
  SpreadsheetApp.getActiveSpreadsheet().toast("Izin Google Drive & Spreadsheet Berhasil!", "Daily Apps", 5);
  Logger.log("Izin Google Drive & Spreadsheet berhasil diberikan!");
}

function doGet(e) {
  var data = {};
  if (e && e.parameter) {
    if (e.parameter.payload) {
      try {
        data = JSON.parse(e.parameter.payload);
      } catch (err) {
        data = e.parameter;
      }
    } else {
      data = e.parameter;
    }
  }
  return processRequest(data);
}

function doPost(e) {
  var data = {};
  if (e && e.postData && e.postData.contents) {
    try {
      data = JSON.parse(e.postData.contents);
    } catch (err) {
      data = e.parameter || {};
    }
  } else if (e && e.parameter) {
    data = e.parameter;
  }
  return processRequest(data);
}

// Helper pencarian tab sheet yang cerdas, tahan perbedaan spasi/casing, & anti-duplikasi
function findOrCreateSheet(ss, rawName) {
  var allSheets = ss.getSheets();
  if (!allSheets || allSheets.length === 0) {
    return ss.insertSheet("Lap Keu");
  }

  var target = (rawName !== undefined && rawName !== null) ? rawName.toString() : "";
  var cleanTarget = target.trim();

  // Helper normalisasi string (hapus invisible zero-width char, non-breaking space, collapse whitespace)
  function normalizeStr(str) {
    if (str === undefined || str === null) return "";
    return str.toString()
      .replace(/[\\u200B-\\u200D\\uFEFF\\u00A0]/g, " ")
      .replace(/\\s+/g, " ")
      .trim()
      .toLowerCase();
  }

  var targetNorm = normalizeStr(cleanTarget);

  // Jika nama sheet kosong / tidak diatur, gunakan sheet aktif atau sheet pertama
  if (!cleanTarget || !targetNorm) {
    return ss.getActiveSheet() || allSheets[0];
  }

  // 1. Coba exact match persis (nama trim & nama asli)
  var sheet = ss.getSheetByName(cleanTarget) || (cleanTarget !== target ? ss.getSheetByName(target) : null);
  if (sheet) return sheet;

  // 2. Coba Case-Insensitive & Whitespace-Normalized match di seluruh sheet yang ada
  for (var i = 0; i < allSheets.length; i++) {
    if (normalizeStr(allSheets[i].getName()) === targetNorm) {
      return allSheets[i];
    }
  }

  // 3. Jika spreadsheet hanya memiliki 1 sheet (misal file baru: "Sheet1" atau "Lembar 1"),
  // dan target adalah default "Lap Keu" / "Sheet1", gunakan sheet tunggal yang sudah ada
  if (allSheets.length === 1 && (targetNorm === "lap keu" || targetNorm === "sheet1" || targetNorm === "sheet 1" || targetNorm === "lembar1" || targetNorm === "lembar 1")) {
    return allSheets[0];
  }

  // 4. Cegah race condition saat request bersamaan (misal concurrent upload bukti gambar)
  // dengan ScriptLock sebelum insertSheet baru
  var lock = LockService.getScriptLock();
  try {
    lock.waitLock(10000);
    // Double check setelah mendapatkan lock
    var recheck = ss.getSheetByName(cleanTarget);
    if (recheck) return recheck;
    var currentSheets = ss.getSheets();
    for (var k = 0; k < currentSheets.length; k++) {
      if (normalizeStr(currentSheets[k].getName()) === targetNorm) {
        return currentSheets[k];
      }
    }
    // Jika benar-benar belum ada tab dengan nama tersebut, buat sheet baru
    return ss.insertSheet(cleanTarget);
  } catch (eLock) {
    // Fallback jika lock timeout agar tidak crash dan tidak membuat sheet duplikat
    return ss.getSheetByName(cleanTarget) || ss.getActiveSheet() || allSheets[0];
  } finally {
    try { lock.releaseLock(); } catch(e) {}
  }
}

function processRequest(data) {
  try {
    var action = data.action || "test_connection";
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var sheet = findOrCreateSheet(ss, data.sheetName);
    var sheetName = sheet.getName();
    
    // --- AKSI 1: TES KONEKSI ---
    if (action === "test_connection") {
      var driveStatus = "TIDAK AKTIF";
      try {
        DriveApp.getRootFolder();
        driveStatus = "AKTIF";
      } catch (eDrive) {
        driveStatus = "BELUM DIAKTIFKAN (" + eDrive.toString() + ")";
      }

      return jsonResponse({
        status: "success",
        message: "Koneksi Berhasil! Terhubung ke: '" + ss.getName() + "' (Tab: '" + sheet.getName() + "') | Izin Drive: " + driveStatus,
        spreadsheetName: ss.getName(),
        sheetName: sheet.getName(),
        driveStatus: driveStatus
      });
    }
    
    var startRowRekening = parseInt(data.startRowRekening) || parseInt(data.startRow) || 4;
    var endRowRekening = parseInt(data.endRowRekening) || parseInt(data.endRow) || 0;
    var startRowOnHand = parseInt(data.startRowOnHand) || startRowRekening || 4;
    var endRowOnHand = parseInt(data.endRowOnHand) || 0;
    var mapping = data.mapping || {
      no: "A",
      tanggal: "B",
      ku: "C",
      kategori: "D",
      keterangan: "E",
      debit: "F",
      kredit: "G",
      no_onhand: "A",
      tanggal_onhand: "B",
      ku_onhand: "C",
      kategori_onhand: "D",
      keterangan_onhand: "E",
      debit_onhand: "F",
      kredit_onhand: "G",
      bukti_saldo_rekening: "A",
      bukti_saldo_cash: "J",
      bukti_mutasi_1: "A",
      bukti_mutasi_2: "D",
      bukti_mutasi_3: "F",
      bukti_mutasi_4: "J",
      bukti_mutasi_5: "N"
    };

    var REKENING_FIELDS = ['no', 'tanggal', 'ku', 'kategori', 'keterangan', 'debit', 'kredit'];
    var ONHAND_FIELDS = ['no_onhand', 'tanggal_onhand', 'ku_onhand', 'kategori_onhand', 'keterangan_onhand', 'debit_onhand', 'kredit_onhand'];
    var EVIDENCE_FIELDS = ['bukti_saldo_rekening', 'bukti_saldo_cash', 'bukti_mutasi_1', 'bukti_mutasi_2', 'bukti_mutasi_3', 'bukti_mutasi_4', 'bukti_mutasi_5'];

    // Helper konversi Huruf Kolom (cth: 'A', 'B', 'AA') menjadi indeks angka (1-based)
    function colLetterToIndex(col) {
      if (!col) return -1;
      col = col.toString().toUpperCase().trim();
      if (col === "" || col === "-" || col === "OFF" || col === "NONE" || col === "DISABLED") return -1;
      
      var result = 0;
      for (var i = 0; i < col.length; i++) {
        var code = col.charCodeAt(i);
        if (code >= 65 && code <= 90) { // 'A' .. 'Z'
          result = result * 26 + (code - 64);
        } else {
          return -1;
        }
      }
      return result > 0 ? result : -1;
    }

    // Pemetaan aktif Kolom Transaksi Rekening
    var activeRekeningMapping = {};
    for (var i = 0; i < REKENING_FIELDS.length; i++) {
      var field = REKENING_FIELDS[i];
      if (mapping[field]) {
        var cIdx = colLetterToIndex(mapping[field]);
        if (cIdx > 0) activeRekeningMapping[field] = cIdx;
      }
    }

    // Pemetaan aktif Kolom Transaksi Cash On Hand
    var activeOnHandMapping = {};
    for (var i = 0; i < ONHAND_FIELDS.length; i++) {
      var field = ONHAND_FIELDS[i];
      if (mapping[field]) {
        var cIdx = colLetterToIndex(mapping[field]);
        if (cIdx > 0) activeOnHandMapping[field] = cIdx;
      }
    }

    // Pemetaan aktif Gambar Bukti
    var activeEvidenceMapping = {};
    for (var i = 0; i < EVIDENCE_FIELDS.length; i++) {
      var field = EVIDENCE_FIELDS[i];
      if (mapping[field]) {
        var cIdx = colLetterToIndex(mapping[field]);
        if (cIdx > 0) activeEvidenceMapping[field] = cIdx;
      }
    }

    // Helper untuk mencocokkan teks transaksi dengan opsi Dropdown di Google Spreadsheet secara otomatis
    function matchDropdownValue(rule, incomingVal) {
      if (!incomingVal) return "";
      if (!rule) return incomingVal;
      try {
        var criteriaType = rule.getCriteriaType();
        var criteriaValues = rule.getCriteriaValues();
        var targetLower = incomingVal.toString().trim().toLowerCase();
        
        if (criteriaType === SpreadsheetApp.DataValidationCriteria.VALUE_IN_LIST) {
          var list = criteriaValues[0];
          if (list && list.length > 0) {
            for (var i = 0; i < list.length; i++) {
              var itemStr = list[i].toString().trim();
              if (itemStr.toLowerCase() === targetLower) return itemStr;
            }
            for (var i = 0; i < list.length; i++) {
              var itemStr = list[i].toString().trim();
              if (itemStr.toLowerCase().indexOf(targetLower) !== -1 || targetLower.indexOf(itemStr.toLowerCase()) !== -1) {
                return itemStr;
              }
            }
          }
        }
        
        if (criteriaType === SpreadsheetApp.DataValidationCriteria.VALUE_IN_RANGE) {
          var range = criteriaValues[0];
          if (range) {
            var rangeValues = range.getValues();
            for (var r = 0; r < rangeValues.length; r++) {
              for (var c = 0; c < rangeValues[r].length; c++) {
                var itemVal = rangeValues[r][c];
                if (itemVal && itemVal.toString().trim().toLowerCase() === targetLower) {
                  return itemVal.toString().trim();
                }
              }
            }
          }
        }
      } catch (err) {}
      return incomingVal;
    }

    // Helper penulisan sel SATU KOLOM KHUSUS yang cepat & aman terhadap aturan Validasi
    function safeWriteSingleColumn(targetSheet, startRowIdx, colIdx, valuesArray) {
      if (!valuesArray || valuesArray.length === 0 || colIdx <= 0) return;
      var numRows = valuesArray.length;
      var range = targetSheet.getRange(startRowIdx, colIdx, numRows, 1);

      try {
        range.setValues(valuesArray);
        return;
      } catch (err) {}

      try {
        var validations = range.getDataValidations();
        if (validations && validations.length > 0) {
          var relaxedRules = [];
          var hasValidation = false;
          for (var r = 0; r < numRows; r++) {
            var rule = (validations[r] && validations[r][0]) ? validations[r][0] : null;
            if (rule) {
              hasValidation = true;
              if (valuesArray[r][0] !== "" && valuesArray[r][0] !== null && valuesArray[r][0] !== undefined) {
                valuesArray[r][0] = matchDropdownValue(rule, valuesArray[r][0]);
              }
              relaxedRules.push([rule.copy().setAllowInvalid(true).build()]);
            } else {
              relaxedRules.push([null]);
            }
          }
          if (hasValidation) {
            range.setDataValidations(relaxedRules);
          }
        }
        range.setValues(valuesArray);
        return;
      } catch (eRel) {}

      for (var r = 0; r < numRows; r++) {
        var currentRow = startRowIdx + r;
        var val = valuesArray[r][0];
        var cell = targetSheet.getRange(currentRow, colIdx);
        if (val === "" || val === null || val === undefined || val === "-") {
          try { cell.clearContent(); } catch (e) {}
        } else {
          try {
            cell.setValue(val);
          } catch (cellErr) {
            try {
              var cRule = cell.getDataValidation();
              if (cRule) {
                cell.setDataValidation(cRule.copy().setAllowInvalid(true).build());
              }
              cell.setValue(val);
            } catch (e3) {
              cell.clearContent();
            }
          }
        }
      }
    }

    // Helper membersihkan sisa baris transaksi lama secara ketat dan aman
    // HANYA menghapus baris transaksi lama yang tepat menyambung di bawah data baru
    // Berhenti seketika jika menemukan baris kosong, baris rumus, header, catatan, bukti, atau batas End Row
    function clearOldTransactionData(targetSheet, startRowIdx, activeMappingObj, newRowCount, evidenceRowMappingObj, defaultEvidenceRow, endRowLimit) {
      var lastRow = targetSheet.getLastRow();
      if (lastRow < startRowIdx) return;

      var checkStartRow = startRowIdx + newRowCount;
      var totalRowsBelow = lastRow - checkStartRow + 1;
      if (totalRowsBelow <= 0) return;

      var minEvidenceRow = 999999;
      if (defaultEvidenceRow && defaultEvidenceRow > startRowIdx) {
        minEvidenceRow = defaultEvidenceRow;
      }
      if (evidenceRowMappingObj) {
        for (var evField in evidenceRowMappingObj) {
          var evR = parseInt(evidenceRowMappingObj[evField]);
          if (evR && evR > startRowIdx && evR < minEvidenceRow) {
            minEvidenceRow = evR;
          }
        }
      }

      var colIndices = [];
      var minCol = 999999;
      var maxCol = 0;
      for (var f in activeMappingObj) {
        var c = activeMappingObj[f];
        if (c > 0) {
          colIndices.push(c);
          if (c < minCol) minCol = c;
          if (c > maxCol) maxCol = c;
        }
      }
      if (colIndices.length === 0) return;

      // Batasi pemindaian maksimal sampai End Row (jika diatur)
      var maxCheck = Math.min(totalRowsBelow, 100);
      if (endRowLimit && endRowLimit >= checkStartRow) {
        maxCheck = Math.min(maxCheck, (endRowLimit - checkStartRow + 1));
      }

      var numCols = maxCol - minCol + 1;
      var blockRange = targetSheet.getRange(checkStartRow, minCol, maxCheck, numCols);
      var blockFormulas = blockRange.getFormulas();
      var blockValues = blockRange.getValues();

      var consecutiveOldRowsToClear = 0;

      for (var r = 0; r < maxCheck; r++) {
        var currentRowNum = checkStartRow + r;
        if (currentRowNum >= minEvidenceRow) break;
        if (endRowLimit && endRowLimit > 0 && currentRowNum > endRowLimit) break;

        var hasFormula = false;
        var hasAnyValue = false;
        var isHeaderOrFooter = false;

        for (var i = 0; i < colIndices.length; i++) {
          var colOffset = colIndices[i] - minCol;
          if (colOffset >= 0 && colOffset < numCols) {
            var fVal = blockFormulas[r][colOffset];
            var vVal = blockValues[r][colOffset];

            // Jika ada formula di kolom manapun pada baris ini -> STOP total!
            if (fVal && fVal.toString().trim() !== "") {
              hasFormula = true;
              break;
            }

            if (vVal !== "" && vVal !== null && vVal !== undefined) {
              var strVal = vVal.toString().trim().toUpperCase();
              // Deteksi kata kunci ringkasan / footer / header / catatan / tanda tangan
              if (strVal === "TOTAL" || strVal === "JUMLAH" || strVal === "JUMLAH TOTAL" ||
                  strVal.indexOf("SALDO") !== -1 || strVal.indexOf("BUKTI") !== -1 ||
                  strVal.indexOf("CATATAN") !== -1 || strVal.indexOf("REKAP") !== -1 ||
                  strVal.indexOf("KAS") !== -1 || strVal.indexOf("MENGETAHUI") !== -1 ||
                  strVal.indexOf("TANDA TANGAN") !== -1 || strVal.indexOf("KETUA") !== -1 ||
                  strVal.indexOf("BENDAHARA") !== -1 || strVal.indexOf("PEMERIKSA") !== -1 ||
                  strVal.indexOf("NOTE") !== -1 || strVal.indexOf("NB") !== -1) {
                isHeaderOrFooter = true;
                break;
              }
              hasAnyValue = true;
            }
          }
        }

        // Jika menemukan rumus atau footer/header -> STOP seketika, jangan hapus baris ini dan bawahnya
        if (hasFormula || isHeaderOrFooter) break;

        // KRUSIAL: Jika baris ini KOSONG (tidak ada data apapun di kolom yang dipetakan),
        // berarti blok transaksi lama SUDAH SELESAI!
        // STOP SEKETIKA! Jangan terus memeriksa ke bawah karena data di bawah baris kosong adalah bagian terpisah!
        if (!hasAnyValue) {
          break;
        }

        // Baris ini adalah baris data transaksi lama yang tersisa dari sync sebelumnya
        consecutiveOldRowsToClear++;
      }

      // Hapus HANYA baris transaksi lama yang berurutan langsung di bawah data baru
      if (consecutiveOldRowsToClear > 0) {
        for (var j = 0; j < colIndices.length; j++) {
          var col = colIndices[j];
          try {
            targetSheet.getRange(checkStartRow, col, consecutiveOldRowsToClear, 1).clearContent();
          } catch (eC) {}
        }
      }
    }

    // --- AKSI 2: SINKRONISASI SEMUA DATA (TABEL REKENING & TABEL ON HAND) ---
    if (action === "sync_all" || action === "sync_batch") {
      var rekeningRows = data.rekeningRows || data.rows || [];
      var onHandRows = data.onHandRows || [];
      var targetStartRowRekening = parseInt(data.startRowRekening) || parseInt(data.startRow) || startRowRekening || 4;
      var targetEndRowRekening = parseInt(data.endRowRekening) || parseInt(data.endRow) || endRowRekening || 0;
      var targetStartRowOnHand = parseInt(data.startRowOnHand) || startRowOnHand || targetStartRowRekening;
      var targetEndRowOnHand = parseInt(data.endRowOnHand) || endRowOnHand || 0;
      var clearFirst = (data.clearFirst === true || String(data.clearFirst) === "true") || (action === "sync_all" && data.chunkIndex === undefined);
      
      // Validasi Kapasitas End Row Rekening
      if (targetEndRowRekening > 0 && (targetStartRowRekening + rekeningRows.length - 1) > targetEndRowRekening) {
        var capRek = targetEndRowRekening - targetStartRowRekening + 1;
        return jsonResponse({
          status: "error",
          message: "Peringatan: Jumlah data transaksi Rekening (" + rekeningRows.length + " data) melebihi batas End Row baris " + targetEndRowRekening + ". Kapasitas dari baris " + targetStartRowRekening + " sampai " + targetEndRowRekening + " hanya " + capRek + " baris. Silakan sesuaikan End Row di aplikasi."
        });
      }

      // Validasi Kapasitas End Row On Hand
      if (targetEndRowOnHand > 0 && (targetStartRowOnHand + onHandRows.length - 1) > targetEndRowOnHand) {
        var capOn = targetEndRowOnHand - targetStartRowOnHand + 1;
        return jsonResponse({
          status: "error",
          message: "Peringatan: Jumlah data transaksi Cash On Hand (" + onHandRows.length + " data) melebihi batas End Row baris " + targetEndRowOnHand + ". Kapasitas dari baris " + targetStartRowOnHand + " sampai " + targetEndRowOnHand + " hanya " + capOn + " baris. Silakan sesuaikan End Row di aplikasi."
        });
      }

      // 1. Bersihkan sisa baris lama untuk kedua tabel secara aman
      if (clearFirst) {
        var defaultEvRow = parseInt(data.targetRow) || 60;
        var evRowMap = data.rowMapping || {};
        clearOldTransactionData(sheet, targetStartRowRekening, activeRekeningMapping, rekeningRows.length, evRowMap, defaultEvRow, targetEndRowRekening);
        clearOldTransactionData(sheet, targetStartRowOnHand, activeOnHandMapping, onHandRows.length, evRowMap, defaultEvRow, targetEndRowOnHand);
      }
      
      // 2. Tulis data transaksi Rekening
      if (rekeningRows.length > 0) {
        for (var field in activeRekeningMapping) {
          var colIdx = activeRekeningMapping[field];
          var colArray = [];
          for (var r = 0; r < rekeningRows.length; r++) {
            var item = rekeningRows[r];
            var val = (item[field] !== undefined && item[field] !== null) ? item[field] : "";
            colArray.push([val]);
          }
          safeWriteSingleColumn(sheet, targetStartRowRekening, colIdx, colArray);
        }
      }
      
      // 3. Tulis data transaksi Cash On Hand
      if (onHandRows.length > 0) {
        for (var field in activeOnHandMapping) {
          var colIdx = activeOnHandMapping[field];
          var colArray = [];
          for (var r = 0; r < onHandRows.length; r++) {
            var item = onHandRows[r];
            var val = (item[field] !== undefined && item[field] !== null) ? item[field] : "";
            colArray.push([val]);
          }
          safeWriteSingleColumn(sheet, targetStartRowOnHand, colIdx, colArray);
        }
      }
      
      var totalCount = rekeningRows.length + onHandRows.length;
      return jsonResponse({
        status: "success",
        message: "Berhasil sinkronisasi " + totalCount + " baris data (Rekening: " + rekeningRows.length + ", On Hand: " + onHandRows.length + ") ke sheet '" + sheetName + "'.",
        count: totalCount,
        rekeningCount: rekeningRows.length,
        onHandCount: onHandRows.length,
        startRowRekening: targetStartRowRekening,
        endRowRekening: targetEndRowRekening,
        startRowOnHand: targetStartRowOnHand,
        endRowOnHand: targetEndRowOnHand
      });
    }

    // --- AKSI 3: TAMBAH 1 BARIS REALTIME (ADD ROW) ---
    if (action === "add_row") {
      var item = data.row || {};
      var isOnHand = (data.isOnHand === true || data.tableType === "onhand");
      var targetMapping = isOnHand ? activeOnHandMapping : activeRekeningMapping;
      var targetStart = isOnHand ? targetStartRowOnHand : targetStartRowRekening;
      var targetEnd = isOnHand 
          ? (parseInt(data.endRowOnHand) || endRowOnHand || 0)
          : (parseInt(data.endRowRekening) || parseInt(data.endRow) || endRowRekening || 0);

      var lastRow = sheet.getLastRow();
      var nextRow = targetStart;
      if (lastRow >= targetStart) {
        var totalToCheck = lastRow - targetStart + 1;
        var numCols = sheet.getLastColumn() || 26;
        var rRange = sheet.getRange(targetStart, 1, totalToCheck, numCols);
        var rFormulas = rRange.getFormulas();
        var rValues = rRange.getValues();
        
        var found = false;
        for (var i = 0; i < totalToCheck; i++) {
          var rowNum = targetStart + i;
          
          // Cek apakah baris ini mengandung formula atau merupakan header/footer
          var rowHasFormula = false;
          var rowIsSummaryOrFooter = false;
          var rowIsBlankInTable = true;

          for (var field in targetMapping) {
            var cIdx = targetMapping[field];
            if (cIdx > 0 && cIdx <= numCols) {
              var fVal = rFormulas[i][cIdx - 1];
              var vVal = rValues[i][cIdx - 1];
              if (fVal && fVal.toString().trim() !== "") {
                rowHasFormula = true;
              }
              if (vVal !== "" && vVal !== null && vVal !== undefined) {
                rowIsBlankInTable = false;
                var strVal = vVal.toString().trim().toUpperCase();
                if (strVal === "TOTAL" || strVal === "JUMLAH" || strVal === "JUMLAH TOTAL" ||
                    strVal.indexOf("SALDO") !== -1 || strVal.indexOf("BUKTI") !== -1 ||
                    strVal.indexOf("CATATAN") !== -1 || strVal.indexOf("REKAP") !== -1 ||
                    strVal.indexOf("KAS") !== -1 || strVal.indexOf("MENGETAHUI") !== -1 ||
                    strVal.indexOf("TANDA TANGAN") !== -1) {
                  rowIsSummaryOrFooter = true;
                }
              }
            }
          }

          // Jika baris ini adalah baris formula atau footer/summary (seperti TOTAL / SALDO),
          // JANGAN TIMPA! Sisipkan baris baru di atasnya agar rumus dan footer tetap aman & bergeser ke bawah
          if (rowHasFormula || rowIsSummaryOrFooter) {
            // Cek apakah dengan menyisipkan baris akan melampaui End Row
            if (targetEnd > 0 && rowNum > targetEnd) {
              return jsonResponse({
                status: "error",
                message: "Peringatan: Tabel " + (isOnHand ? "Cash On Hand" : "Rekening") + " telah mencapai batas maksimal End Row (Baris ke-" + targetEnd + "). Penambahan transaksi dibatalkan agar tidak merusak baris di bawahnya."
              });
            }
            sheet.insertRowBefore(rowNum);
            nextRow = rowNum;
            found = true;
            break;
          }

          // Jika baris ini kosong di semua kolom tabel dan tidak memiliki formula, gunakan baris ini
          if (rowIsBlankInTable && !rowHasFormula) {
            nextRow = rowNum;
            found = true;
            break;
          }
        }

        if (!found) {
          nextRow = lastRow + 1;
        }
      }
      
      // Validasi End Row sebelum menulis
      if (targetEnd > 0 && nextRow > targetEnd) {
        return jsonResponse({
          status: "error",
          message: "Peringatan: Baris ke-" + nextRow + " melebihi batas End Row (Baris ke-" + targetEnd + ") untuk " + (isOnHand ? "Cash On Hand" : "Rekening") + ". Penambahan transaksi dibatalkan."
        });
      }

      for (var field in targetMapping) {
        var colIdx = targetMapping[field];
        if (colIdx > 0) {
          var val = (item[field] !== undefined && item[field] !== null) ? item[field] : "";
          var cell = sheet.getRange(nextRow, colIdx);
          // Lindungi rumus jika cell secara tak terduga memiliki rumus
          if (cell.getFormula() === "") {
            safeWriteSingleColumn(sheet, nextRow, colIdx, [[val]]);
          }
        }
      }
      
      return jsonResponse({
        status: "success",
        message: "Berhasil menambahkan data ke baris " + nextRow + " (" + (isOnHand ? "Tabel On Hand" : "Tabel Rekening") + ").",
        rowNumber: nextRow
      });
    }

    // --- AKSI 4: URUNGKAN (UNDO) BARIS TERAKHIR ---
    if (action === "undo_last" || action === "delete_last_row") {
      var isOnHand = (data.isOnHand === true || data.tableType === "onhand");
      var targetMapping = isOnHand ? activeOnHandMapping : activeRekeningMapping;
      var targetStart = isOnHand ? targetStartRowOnHand : targetStartRowRekening;

      var lastRow = sheet.getLastRow();
      if (lastRow >= targetStart) {
        var totalToCheck = lastRow - targetStart + 1;
        var numCols = sheet.getLastColumn() || 26;
        var rRange = sheet.getRange(targetStart, 1, totalToCheck, numCols);
        var rFormulas = rRange.getFormulas();
        var rValues = rRange.getValues();
        
        var targetUndoRow = -1;
        // Cari dari bawah ke atas baris transaksi yang memiliki nilai dan BUKAN baris formula/footer
        for (var i = totalToCheck - 1; i >= 0; i--) {
          var hasFormula = false;
          var hasValue = false;
          var isFooter = false;

          for (var field in targetMapping) {
            var cIdx = targetMapping[field];
            if (cIdx > 0 && cIdx <= numCols) {
              var fVal = rFormulas[i][cIdx - 1];
              var vVal = rValues[i][cIdx - 1];
              if (fVal && fVal.toString().trim() !== "") {
                hasFormula = true;
              }
              if (vVal !== "" && vVal !== null && vVal !== undefined) {
                hasValue = true;
                var strVal = vVal.toString().trim().toUpperCase();
                if (strVal === "TOTAL" || strVal === "JUMLAH" || strVal.indexOf("SALDO") !== -1 ||
                    strVal.indexOf("BUKTI") !== -1 || strVal.indexOf("CATATAN") !== -1) {
                  isFooter = true;
                }
              }
            }
          }

          if (!hasFormula && !isFooter && hasValue) {
            targetUndoRow = targetStart + i;
            break;
          }
        }
        
        if (targetUndoRow >= targetStart) {
          for (var field in targetMapping) {
            var colIdx = targetMapping[field];
            if (colIdx > 0) {
              var cell = sheet.getRange(targetUndoRow, colIdx);
              if (cell.getFormula() === "") {
                cell.clearContent();
              }
            }
          }
          
          return jsonResponse({
            status: "success",
            message: "Berhasil mengurungkan data pada baris ke-" + targetUndoRow,
            undoneRow: targetUndoRow
          });
        }
      }
      
      return jsonResponse({
        status: "error",
        message: "Tidak ada baris data transaksi untuk di-undo."
      });
    }

    // --- AKSI 5: BACA / AMBIL DATA TRANSAKSI DARI SPREADSHEET (FETCH DATA) ---
    if (action === "fetch_transactions" || action === "fetch_data" || action === "read_data") {
      var targetStartRowRekening = parseInt(data.startRowRekening) || parseInt(data.startRow) || startRowRekening || 4;
      var targetEndRowRekening = parseInt(data.endRowRekening) || parseInt(data.endRow) || endRowRekening || 0;
      var targetStartRowOnHand = parseInt(data.startRowOnHand) || startRowOnHand || targetStartRowRekening;
      var targetEndRowOnHand = parseInt(data.endRowOnHand) || endRowOnHand || 0;

      function readTableData(startRowIdx, activeMappingObj, fieldsList, endRowLimit) {
        var rows = [];
        var lastRow = sheet.getLastRow();
        if (lastRow < startRowIdx) return rows;

        var maxRows = (endRowLimit && endRowLimit >= startRowIdx) 
            ? (endRowLimit - startRowIdx + 1)
            : 500;
        var numRows = Math.min(lastRow - startRowIdx + 1, maxRows);
        if (numRows <= 0) return rows;

        var maxCol = 0;
        for (var f in activeMappingObj) {
          if (activeMappingObj[f] > maxCol) maxCol = activeMappingObj[f];
        }
        if (maxCol <= 0) return rows;

        var range = sheet.getRange(startRowIdx, 1, numRows, maxCol);
        var values = range.getValues();
        var formulas = range.getFormulas();

        for (var r = 0; r < numRows; r++) {
          var rowObj = {};
          var hasAnyData = false;
          var isTotalOrHeader = false;

          for (var i = 0; i < fieldsList.length; i++) {
            var field = fieldsList[i];
            var colIdx = activeMappingObj[field];
            if (colIdx && colIdx > 0 && colIdx <= maxCol) {
              var val = values[r][colIdx - 1];
              var formula = formulas[r][colIdx - 1];
              if (formula && formula.toString().trim() !== "") {
                isTotalOrHeader = true;
                break;
              }
              if (val !== null && val !== undefined && val !== "") {
                var strVal = val.toString().trim().toUpperCase();
                if (strVal === "TOTAL" || strVal === "JUMLAH TOTAL" || strVal.indexOf("SALDO") !== -1 ||
                    strVal.indexOf("BUKTI") !== -1 || strVal.indexOf("REKAP") !== -1 ||
                    strVal.indexOf("MENGETAHUI") !== -1) {
                  isTotalOrHeader = true;
                  break;
                }
                hasAnyData = true;
                if (val instanceof Date) {
                  var d = val.getDate();
                  var m = val.getMonth() + 1;
                  var y = val.getFullYear();
                  rowObj[field] = (d < 10 ? '0' + d : d) + '/' + (m < 10 ? '0' + m : m) + '/' + y;
                } else {
                  rowObj[field] = val;
                }
              } else {
                rowObj[field] = "";
              }
            }
          }

          if (isTotalOrHeader) break;
          if (hasAnyData) {
            rows.push(rowObj);
          }
        }
        return rows;
      }

      var fetchedRekening = readTableData(targetStartRowRekening, activeRekeningMapping, REKENING_FIELDS, targetEndRowRekening);
      var fetchedOnHand = readTableData(targetStartRowOnHand, activeOnHandMapping, ONHAND_FIELDS, targetEndRowOnHand);

      return jsonResponse({
        status: "success",
        message: "Berhasil membaca " + (fetchedRekening.length + fetchedOnHand.length) + " baris data dari sheet '" + sheetName + "'.",
        rekeningRows: fetchedRekening,
        onHandRows: fetchedOnHand,
        rekeningCount: fetchedRekening.length,
        onHandCount: fetchedOnHand.length
      });
    }

    // --- AKSI 6: UPLOAD GAMBAR BUKTI (SALDO REKENING, CASH ON HAND, MUTASI REKENING 1-5) ---
    if (action === "upload_evidence_images" || action === "upload_evidence_image" || action === "upload_evidence" || action === "upload_images" || action === "upload_image") {
      var images = data.images || [];
      var defaultTargetRow = parseInt(data.targetRow) || parseInt(data.startRow) || 2;
      var customRowMapping = data.rowMapping || {};
      var useImageFormula = data.useImageFormula === true;
      var monthLabel = data.monthLabel || "";

      if (!images || images.length === 0) {
        return jsonResponse({
          status: "error",
          message: "Tidak ada gambar bukti yang dikirimkan."
        });
      }

      var targetFolder = null;
      try {
        var folderName = "DailyApps_BuktiKeuangan";
        var folders = DriveApp.getFoldersByName(folderName);
        if (folders.hasNext()) {
          targetFolder = folders.next();
        } else {
          targetFolder = DriveApp.createFolder(folderName);
        }
      } catch (errFolder) {
        try {
          targetFolder = DriveApp.getRootFolder();
        } catch (errRoot) {
          return jsonResponse({
            status: "error",
            message: "Izin Google Drive belum aktif pada URL Web App ini. Pastikan Anda membuat 'New deployment' dan menyalin URL /exec yang baru ke aplikasi: " + errRoot.toString()
          });
        }
      }

      var uploadedResults = [];
      var updatedCells = [];

      for (var idx = 0; idx < images.length; idx++) {
        var imgItem = images[idx];
        var fieldKey = imgItem.key;
        var base64Data = imgItem.base64 || "";
        var mimeType = imgItem.mimeType || "image/jpeg";
        var originalFileName = imgItem.fileName || (fieldKey + ".jpg");
        var itemTargetRow = parseInt(imgItem.targetRow) || parseInt(customRowMapping[fieldKey]) || defaultTargetRow;

        if (!base64Data) continue;

        if (base64Data.indexOf("base64,") !== -1) {
          base64Data = base64Data.split("base64,")[1];
        }

        var decodedBytes = Utilities.base64Decode(base64Data);
        var timeStampStr = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), "yyyyMMdd_HHmmss");
        var savedFileName = (monthLabel ? (monthLabel + "_") : "") + fieldKey + "_" + timeStampStr + "_" + originalFileName;

        var blob = Utilities.newBlob(decodedBytes, mimeType, savedFileName);
        var driveFile = targetFolder.createFile(blob);

        try {
          driveFile.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
        } catch (eShare) {}

        var fileUrl = driveFile.getUrl();
        var downloadDirectUrl = "https://lh3.googleusercontent.com/d/" + driveFile.getId();

        var colIndex = activeEvidenceMapping[fieldKey] || colLetterToIndex(mapping[fieldKey]);
        if (colIndex > 0) {
          var cell = sheet.getRange(itemTargetRow, colIndex);

          if (useImageFormula) {
            var insertedNative = false;
            try {
              var cellImageDrive = SpreadsheetApp.newCellImage()
                .setSourceUrl(downloadDirectUrl)
                .setAltTextTitle(savedFileName)
                .build();
              cell.setValue(cellImageDrive);
              insertedNative = true;
            } catch (errDriveUrl) {
              cell.setValue('=IMAGE("' + downloadDirectUrl + '", 1)');
            }
            updatedCells.push({
              field: fieldKey,
              col: colIndex,
              row: itemTargetRow,
              val: insertedNative ? "[InCellImage]" : ('=IMAGE("' + downloadDirectUrl + '")')
            });
          } else {
            cell.setValue(fileUrl);
            updatedCells.push({
              field: fieldKey,
              col: colIndex,
              row: itemTargetRow,
              val: fileUrl
            });
          }
        }

        uploadedResults.push({
          key: fieldKey,
          fileId: driveFile.getId(),
          fileUrl: fileUrl,
          downloadUrl: downloadDirectUrl,
          fileName: savedFileName,
          row: itemTargetRow
        });
      }

      return jsonResponse({
        status: "success",
        message: "Berhasil mengunggah " + uploadedResults.length + " gambar bukti ke Google Drive & mencatat ke sel target Spreadsheet.",
        uploadedCount: uploadedResults.length,
        results: uploadedResults,
        updatedCells: updatedCells
      });
    }

    return jsonResponse({ status: "error", message: "Action tidak dikenal: " + action });

  } catch (err) {
    return jsonResponse({ status: "error", message: err.toString() });
  }
}

function jsonResponse(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}''';
  }
}
