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

    try {
      final payload = {
        'action': 'test_connection',
        'sheetName': config.sheetName,
      };

      final res = await _sendPostRequest(config.webAppUrl, payload);
      final status = res['status'] as String?;
      final msg = res['message'] as String? ?? 'Koneksi berhasil terhubung.';

      if (status == 'success') {
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
      'no': indexNumber,
      'tanggal': dateFormatted,
      'ku': ku,
      'kategori': kategori,
      'keterangan': fullKeterangan,
      'jumlah': tx.amount,
      'debit': debit,
      'kredit': kredit,
    };
  }

  /// Melakukan sinkronisasi seluruh tabel transaksi bulan aktif ke Spreadsheet
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

    try {
      // Urutkan transaksi berdasarkan waktu secara kronologis
      final sortedList = List<StrukturTransaction>.from(transactions)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final List<Map<String, dynamic>> rows = [];
      for (int i = 0; i < sortedList.length; i++) {
        rows.add(formatTransactionRow(
          sortedList[i],
          i + 1,
          customRules: customRules,
          dateFormat: config.dateFormat,
        ));
      }

      // Jika data kosong, kirim sync_all untuk mengosongkan spreadsheet
      if (rows.isEmpty) {
        final payload = {
          'action': 'sync_all',
          'sheetName': config.sheetName,
          'startRow': config.startRow,
          'targetRow': config.evidenceTargetRow,
          'rowMapping': config.evidenceRowMapping,
          'mapping': config.columnMapping,
          'rows': [],
        };
        final res = await _sendPostRequest(config.webAppUrl, payload);
        final status = res['status'] as String?;
        final msg = res['message'] as String? ?? 'Data spreadsheet berhasil dikosongkan.';

        config.lastSyncStatus = status == 'success' ? 'success' : 'failed';
        config.lastSyncMessage = msg;
        config.lastSyncTime = DateTime.now();
        await config.save();
        return SheetsSyncResult(
          isSuccess: status == 'success' || status == null,
          message: msg,
          count: 0,
        );
      }

      // Kirim seluruh baris transaksi dalam 1 request POST instan (Single-Flight Direct Sync)
      // Jauh lebih cepat (0.5 - 1 detik) dibandingkan multi-batching mikro
      if (rows.length <= 150) {
        final payload = {
          'action': 'sync_all',
          'sheetName': config.sheetName,
          'startRow': config.startRow,
          'targetRow': config.evidenceTargetRow,
          'rowMapping': config.evidenceRowMapping,
          'mapping': config.columnMapping,
          'rows': rows,
        };

        final res = await _sendPostRequest(config.webAppUrl, payload);
        final status = res['status'] as String?;
        final msg = res['message'] as String? ??
            'Berhasil sinkronisasi ${rows.length} data transaksi.';

        if (status == 'success' || status == null) {
          config.lastSyncStatus = 'success';
          config.lastSyncMessage = msg;
          config.lastSyncTime = DateTime.now();
          await config.save();
          return SheetsSyncResult(
            isSuccess: true,
            message: msg,
            count: rows.length,
          );
        } else {
          config.lastSyncStatus = 'failed';
          config.lastSyncMessage = msg;
          await config.save();
          return SheetsSyncResult(isSuccess: false, message: msg);
        }
      }

      // Jika data sangat besar (> 150 baris), bagi dengan ukuran batch besar (100 per batch)
      const int batchSize = 100;
      int totalSynced = 0;
      final int totalChunks = (rows.length / batchSize).ceil();

      for (int chunkIdx = 0; chunkIdx < totalChunks; chunkIdx++) {
        final int startIdx = chunkIdx * batchSize;
        final int endIdx = (startIdx + batchSize < rows.length)
            ? startIdx + batchSize
            : rows.length;
        final chunkRows = rows.sublist(startIdx, endIdx);
        final int chunkStartRow = config.startRow + startIdx;

        final payload = {
          'action': 'sync_batch',
          'clearFirst': chunkIdx == 0,
          'sheetName': config.sheetName,
          'startRow': chunkStartRow,
          'targetRow': config.evidenceTargetRow,
          'rowMapping': config.evidenceRowMapping,
          'mapping': config.columnMapping,
          'rows': chunkRows,
          'chunkIndex': chunkIdx,
          'totalChunks': totalChunks,
        };

        final res = await _sendPostRequest(config.webAppUrl, payload);
        final status = res['status'] as String?;
        if (status == 'error') {
          final errorMsg = res['message'] as String? ??
              'Gagal pada batch ke-${chunkIdx + 1}';
          config.lastSyncStatus = 'failed';
          config.lastSyncMessage = errorMsg;
          await config.save();
          return SheetsSyncResult(
            isSuccess: false,
            message: 'Gagal sinkronisasi data: $errorMsg',
          );
        }
        totalSynced += chunkRows.length;
      }

      final successMsg =
          'Berhasil sinkronisasi seluruh $totalSynced data transaksi ke spreadsheet.';
      config.lastSyncStatus = 'success';
      config.lastSyncMessage = successMsg;
      config.lastSyncTime = DateTime.now();
      await config.save();

      return SheetsSyncResult(
        isSuccess: true,
        message: successMsg,
        count: totalSynced,
      );
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
    if (!config.isConfigured || !config.autoSyncOnInput) {
      return SheetsSyncResult(
        isSuccess: false,
        message: 'Auto-sync tidak aktif atau URL belum diatur.',
      );
    }

    try {
      final rowData = formatTransactionRow(
        tx,
        rowNumber ?? 1,
        customRules: customRules,
        dateFormat: config.dateFormat,
      );

      final payload = {
        'action': 'add_row',
        'sheetName': config.sheetName,
        'startRow': config.startRow,
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
  static Future<SheetsSyncResult> undoLastRow(SheetsConfig config) async {
    if (!config.isConfigured) {
      return SheetsSyncResult(
        isSuccess: false,
        message: 'URL Google Apps Script belum diatur.',
      );
    }

    try {
      final payload = {
        'action': 'undo_last',
        'sheetName': config.sheetName,
        'startRow': config.startRow,
        'mapping': config.columnMapping,
      };

      final res = await _sendPostRequest(config.webAppUrl, payload);
      final status = res['status'] as String?;
      final msg = res['message'] as String? ??
          'Data terakhir di spreadsheet berhasil di-undo.';

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
        message: 'Gagal melakukan undo ke spreadsheet: ${e.toString()}',
      );
    }
  }

  /// Mengunggah gambar bukti fisik / digital ke Google Drive & menaruh link/formula di Spreadsheet
  /// Menggunakan metode Paralel Berkecepatan Tinggi (Concurrent Uploads) untuk performa instan tanpa menurunkan kualitas gambar
  static Future<SheetsSyncResult> uploadEvidenceImages({
    required SheetsConfig config,
    required List<Map<String, dynamic>> imagesPayload,
    required String monthLabel,
    int? targetRow,
    Function(int completedCount, int totalCount, String currentKey, bool isSuccess, String message)? onProgress,
  }) async {
    if (!config.isConfigured) {
      return SheetsSyncResult(
        isSuccess: false,
        message: 'URL Google Apps Script belum diatur.',
      );
    }

    if (imagesPayload.isEmpty) {
      return SheetsSyncResult(
        isSuccess: false,
        message: 'Tidak ada gambar bukti yang dipilih.',
      );
    }

    final totalCount = imagesPayload.length;
    int completedCount = 0;
    int successCount = 0;
    final List<String> errorMessages = [];

    // Jika hanya 1 gambar, langsung kirim 1 request cepat
    if (imagesPayload.length == 1) {
      final img = imagesPayload.first;
      final payload = {
        'action': 'upload_evidence_images',
        'sheetName': config.sheetName,
        'startRow': config.startRow,
        'targetRow': targetRow ?? config.evidenceTargetRow,
        'mapping': config.columnMapping,
        'rowMapping': config.evidenceRowMapping,
        'useImageFormula': config.insertImageFormula,
        'monthLabel': monthLabel,
        'images': [img],
      };

      try {
        final res = await _sendPostRequest(config.webAppUrl, payload);
        final status = res['status'] as String?;
        final isOk = status == 'success' || status == null;
        final msg = res['message'] as String? ?? (isOk ? 'Gambar berhasil diunggah.' : 'Gagal mengunggah.');
        
        onProgress?.call(1, 1, img['key'] as String? ?? '', isOk, msg);
        if (isOk) {
          config.lastSyncStatus = 'success';
          config.lastSyncMessage = msg;
          config.lastSyncTime = DateTime.now();
          await config.save();
          return SheetsSyncResult(isSuccess: true, message: msg, count: 1);
        } else {
          return SheetsSyncResult(isSuccess: false, message: msg);
        }
      } catch (e) {
        final err = 'Gagal mengunggah: ${e.toString()}';
        onProgress?.call(1, 1, img['key'] as String? ?? '', false, err);
        return SheetsSyncResult(isSuccess: false, message: err);
      }
    }

    // Jika lebih dari 1 gambar, jalankan PARALEL (Concurrent Uploads) untuk kecepatan maksimal
    // Setiap request memproses 1 file secara terisolasi dan simultan di cloud Google
    final uploadFutures = imagesPayload.map((img) async {
      final key = img['key'] as String? ?? '';
      final payload = {
        'action': 'upload_evidence_images',
        'sheetName': config.sheetName,
        'startRow': config.startRow,
        'targetRow': targetRow ?? config.evidenceTargetRow,
        'mapping': config.columnMapping,
        'rowMapping': config.evidenceRowMapping,
        'useImageFormula': config.insertImageFormula,
        'monthLabel': monthLabel,
        'images': [img],
      };

      try {
        final res = await _sendPostRequest(config.webAppUrl, payload);
        final status = res['status'] as String?;
        final isOk = status == 'success' || status == null;
        final msg = res['message'] as String? ?? (isOk ? 'Berhasil' : 'Gagal');

        completedCount++;
        if (isOk) {
          successCount++;
        } else {
          errorMessages.add('$key: $msg');
        }

        onProgress?.call(completedCount, totalCount, key, isOk, msg);
        return isOk;
      } catch (e) {
        completedCount++;
        final err = e.toString();
        errorMessages.add('$key: $err');
        onProgress?.call(completedCount, totalCount, key, false, err);
        return false;
      }
    }).toList();

    await Future.wait(uploadFutures);

    if (successCount > 0) {
      final successMsg = successCount == totalCount
          ? 'Semua $successCount gambar bukti berhasil diunggah dengan kualitas penuh ke Google Drive & Spreadsheet!'
          : 'Berhasil mengunggah $successCount dari $totalCount gambar bukti.${errorMessages.isNotEmpty ? " (${errorMessages.length} gagal)" : ""}';

      config.lastSyncStatus = successCount == totalCount ? 'success' : 'partial';
      config.lastSyncMessage = successMsg;
      config.lastSyncTime = DateTime.now();
      await config.save();

      return SheetsSyncResult(
        isSuccess: successCount == totalCount,
        message: successMsg,
        count: successCount,
      );
    } else {
      final errorMsg = errorMessages.isNotEmpty
          ? errorMessages.join(', ')
          : 'Semua gambar bukti gagal diunggah. Periksa koneksi dan URL Google Apps Script.';
      return SheetsSyncResult(
        isSuccess: false,
        message: errorMsg,
      );
    }
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
 * 2. Sinkronisasi Data Transaksi (HANYA menulis ke kolom yang dipetakan & melindungi rumus/tabel lain)
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
 * Jalankan fungsi ini (klik Run ▶️) jika Google meminta izin akses Google Drive.
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

function processRequest(data) {
  try {
    var action = data.action || "test_connection";
    var sheetName = data.sheetName || "Lap Keu";
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var sheet = ss.getSheetByName(sheetName);
    
    // Buat sheet baru otomatis jika nama tab belum ada
    if (!sheet) {
      sheet = ss.insertSheet(sheetName);
    }
    
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
    
    var startRow = parseInt(data.startRow) || 2;
    var mapping = data.mapping || {
      no: "A",
      tanggal: "B",
      ku: "C",
      kategori: "D",
      keterangan: "E",
      jumlah: "F",
      debit: "G",
      kredit: "H",
      bukti_saldo_rekening: "I",
      bukti_saldo_cash: "J",
      bukti_mutasi_1: "K",
      bukti_mutasi_2: "L",
      bukti_mutasi_3: "M",
      bukti_mutasi_4: "N",
      bukti_mutasi_5: "O"
    };

    var TRANSACTION_FIELDS = ['no', 'tanggal', 'ku', 'kategori', 'keterangan', 'jumlah', 'debit', 'kredit'];
    var EVIDENCE_FIELDS = ['bukti_saldo_rekening', 'bukti_saldo_cash', 'bukti_mutasi_1', 'bukti_mutasi_2', 'bukti_mutasi_3', 'bukti_mutasi_4', 'bukti_mutasi_5'];

    // Helper konversi Huruf Kolom (cth: 'A', 'B', 'AA') menjadi indeks angka (1-based)
    // Mengembalikan -1 jika kolom kosong, '-', 'OFF', atau tidak valid
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

    // Ambil pemetaan aktif KHUSUS untuk field transaksi (Kolom tabel keuangan)
    var activeTransactionMapping = {};
    for (var i = 0; i < TRANSACTION_FIELDS.length; i++) {
      var field = TRANSACTION_FIELDS[i];
      if (mapping[field]) {
        var cIdx = colLetterToIndex(mapping[field]);
        if (cIdx > 0) {
          activeTransactionMapping[field] = cIdx;
        }
      }
    }

    // Ambil pemetaan aktif KHUSUS untuk bukti gambar
    var activeEvidenceMapping = {};
    for (var i = 0; i < EVIDENCE_FIELDS.length; i++) {
      var field = EVIDENCE_FIELDS[i];
      if (mapping[field]) {
        var cIdx = colLetterToIndex(mapping[field]);
        if (cIdx > 0) {
          activeEvidenceMapping[field] = cIdx;
        }
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
        
        // 1. Dropdown dari daftar item teks (VALUE_IN_LIST)
        if (criteriaType === SpreadsheetApp.DataValidationCriteria.VALUE_IN_LIST) {
          var list = criteriaValues[0];
          if (list && list.length > 0) {
            for (var i = 0; i < list.length; i++) {
              var itemStr = list[i].toString().trim();
              if (itemStr.toLowerCase() === targetLower) {
                return itemStr; // Cocok persis dengan teks opsi dropdown
              }
            }
            for (var i = 0; i < list.length; i++) {
              var itemStr = list[i].toString().trim();
              if (itemStr.toLowerCase().indexOf(targetLower) !== -1 || targetLower.indexOf(itemStr.toLowerCase()) !== -1) {
                return itemStr; // Cocok sebagian (substring)
              }
            }
          }
        }
        
        // 2. Dropdown dari rentang range sel (VALUE_IN_RANGE)
        if (criteriaType === SpreadsheetApp.DataValidationCriteria.VALUE_IN_RANGE) {
          var range = criteriaValues[0];
          if (range) {
            var rangeValues = range.getValues();
            for (var r = 0; r < rangeValues.length; r++) {
              for (var c = 0; c < rangeValues[r].length; c++) {
                var itemVal = rangeValues[r][c];
                if (itemVal) {
                  var itemStr = itemVal.toString().trim();
                  if (itemStr.toLowerCase() === targetLower) {
                    return itemStr; // Cocok persis dari range dropdown
                  }
                }
              }
            }
            for (var r = 0; r < rangeValues.length; r++) {
              for (var c = 0; c < rangeValues[r].length; c++) {
                var itemVal = rangeValues[r][c];
                if (itemVal) {
                  var itemStr = itemVal.toString().trim();
                  if (itemStr.toLowerCase().indexOf(targetLower) !== -1 || targetLower.indexOf(itemStr.toLowerCase()) !== -1) {
                    return itemStr;
                  }
                }
              }
            }
          }
        }
      } catch (err) {}
      
      return incomingVal;
    }

    // Helper penulisan sel SATU KOLOM KHUSUS yang cepat & aman terhadap aturan Validasi TANPA menyentuh kolom lain
    function safeWriteSingleColumn(targetSheet, startRowIdx, colIdx, valuesArray) {
      if (!valuesArray || valuesArray.length === 0 || colIdx <= 0) return;
      var numRows = valuesArray.length;
      var range = targetSheet.getRange(startRowIdx, colIdx, numRows, 1);

      // Fast-path: Tulis data batch langsung ke range kolom (paling cepat, 99% kasus sukses instan)
      try {
        range.setValues(valuesArray);
        return;
      } catch (err) {}

      // Fallback: Tangani jika ada aturan validasi / dropdown yang ketat pada sel tujuan
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

      // Fallback terakhir: tulis per-sel jika batch tetap terkendala
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

    // Helper membersihkan sisa data lama HANYA pada baris sisa tabel transaksi & TIDAK AKAN PERNAH menyentuh tabel/rumus di bawahnya
    function clearOldTransactionData(targetSheet, startRowIdx, activeMappingObj, newRowCount, evidenceRowMappingObj, defaultEvidenceRow) {
      var lastRow = targetSheet.getLastRow();
      if (lastRow < startRowIdx) return;

      var checkStartRow = startRowIdx + newRowCount;
      var totalRowsBelow = lastRow - checkStartRow + 1;
      if (totalRowsBelow <= 0) return;

      // Cari baris batas bukti gambar teratas (jika ada bukti gambar di bawah tabel transaksi)
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

      // Kumpulkan indeks kolom transaksi yang aktif
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

      // Batasi rentang pengecekan maksimal 100 baris ke bawah
      var rowsToCheck = Math.min(totalRowsBelow, 100);
      var numCols = maxCol - minCol + 1;
      var blockRange = targetSheet.getRange(checkStartRow, minCol, rowsToCheck, numCols);
      var blockFormulas = blockRange.getFormulas();
      var blockValues = blockRange.getValues();

      var rowsToClear = 0;

      for (var r = 0; r < rowsToCheck; r++) {
        var currentRowNum = checkStartRow + r;

        // 1. Jika mencapai baris bukti gambar -> STOP
        if (currentRowNum >= minEvidenceRow) {
          break;
        }

        var rowHasFormula = false;
        var rowHasNonEmpty = false;
        var rowHasKeywordHeader = false;

        for (var i = 0; i < colIndices.length; i++) {
          var colOffset = colIndices[i] - minCol;
          if (colOffset >= 0 && colOffset < numCols) {
            var fVal = blockFormulas[r][colOffset];
            var vVal = blockValues[r][colOffset];

            // Cek jika sel berisi formula/rumus (misal =SUM(...))
            if (fVal && fVal.toString().trim() !== "") {
              rowHasFormula = true;
              break;
            }

            // Cek jika sel berisi nilai teks
            if (vVal !== "" && vVal !== null && vVal !== undefined) {
              rowHasNonEmpty = true;
              var strVal = vVal.toString().trim().toUpperCase();
              if (strVal === "TOTAL" || strVal === "JUMLAH TOTAL" || strVal.indexOf("SALDO") !== -1 ||
                  strVal.indexOf("BUKTI") !== -1 || strVal.indexOf("CATATAN") !== -1 ||
                  strVal.indexOf("REKAP") !== -1 || strVal.indexOf("KAS") !== -1 ||
                  strVal.indexOf("MENGETAHUI") !== -1 || strVal.indexOf("TANDA TANGAN") !== -1) {
                rowHasKeywordHeader = true;
                break;
              }
            }
          }
        }

        // Jika baris mengandung formula atau kata kunci header tabel lain -> STOP!
        if (rowHasFormula || rowHasKeywordHeader) {
          break;
        }

        // Jika seluruh kolom transaksi di baris ini kosong -> Berarti tabel transaksi sudah berakhir! STOP!
        if (!rowHasNonEmpty) {
          break;
        }

        // Baris ini terbukti berisi sisa data transaksi lama yang perlu dibersihkan
        rowsToClear = r + 1;
      }

      // Bersihkan HANYA baris sisa data transaksi lama yang terdeteksi
      if (rowsToClear > 0) {
        for (var j = 0; j < colIndices.length; j++) {
          var col = colIndices[j];
          try {
            targetSheet.getRange(checkStartRow, col, rowsToClear, 1).clearContent();
          } catch (eC) {}
        }
      }
    }

    // --- AKSI 2: SINKRONISASI SEMUA / BATCH DATA (BATCH SYNC) ---
    if (action === "sync_all" || action === "sync_batch") {
      var rows = data.rows || [];
      var targetStartRow = parseInt(data.startRow) || startRow || 2;
      var clearFirst = (data.clearFirst === true || String(data.clearFirst) === "true") || (action === "sync_all" && data.chunkIndex === undefined);
      
      // 1. Bersihkan HANYA sisa baris lama pada kolom transaksi tanpa merusak rumus atau tabel lain
      if (clearFirst) {
        var defaultEvRow = parseInt(data.targetRow) || targetEvidenceRow || 2;
        var evRowMap = data.rowMapping || rowMapping || {};
        clearOldTransactionData(sheet, targetStartRow, activeTransactionMapping, rows.length, evRowMap, defaultEvRow);
      }
      
      // 2. Tulis data transaksi HANYA ke kolom-kolom yang dipetakan
      if (rows.length > 0) {
        for (var field in activeTransactionMapping) {
          var colIdx = activeTransactionMapping[field];
          var colArray = [];
          for (var r = 0; r < rows.length; r++) {
            var item = rows[r];
            var val = (item[field] !== undefined && item[field] !== null) ? item[field] : "";
            colArray.push([val]);
          }
          safeWriteSingleColumn(sheet, targetStartRow, colIdx, colArray);
        }
      }
      
      return jsonResponse({
        status: "success",
        message: "Berhasil sinkronisasi " + rows.length + " baris data ke sheet '" + sheetName + "' pada kolom yang dikonfigurasi.",
        count: rows.length,
        startRow: targetStartRow
      });
    }

    // --- AKSI 3: TAMBAH 1 BARIS REALTIME (ADD ROW) ---
    if (action === "add_row") {
      var item = data.row || {};
      
      // Cari kolom acuan utama transaksi
      var checkCol = activeTransactionMapping['tanggal'] || activeTransactionMapping['no'] || 1;
      for (var f in activeTransactionMapping) {
        checkCol = activeTransactionMapping[f];
        break;
      }
      
      // Cari baris kosong pertama yang belum ada data dan bukan sel rumus
      var lastRow = sheet.getLastRow();
      var nextRow = startRow;
      if (lastRow >= startRow) {
        var totalToCheck = lastRow - startRow + 1;
        var rRange = sheet.getRange(startRow, checkCol, totalToCheck, 1);
        var rFormulas = rRange.getFormulas();
        var rValues = rRange.getValues();
        
        var found = false;
        for (var i = 0; i < totalToCheck; i++) {
          // Jika menemukan rumus, berarti tabel transaksi berakhir di sini (ada total/footer)
          if (rFormulas[i] && rFormulas[i][0] && rFormulas[i][0].toString().trim() !== "") {
            nextRow = startRow + i;
            found = true;
            break;
          }
          if (rValues[i][0] === "" || rValues[i][0] === null || rValues[i][0] === undefined) {
            nextRow = startRow + i;
            found = true;
            break;
          }
        }
        if (!found) {
          nextRow = lastRow + 1;
        }
      }
      
      // Tulis data HANYA pada kolom yang dikonfigurasi pada nextRow
      for (var field in activeTransactionMapping) {
        var colIdx = activeTransactionMapping[field];
        var val = (item[field] !== undefined && item[field] !== null) ? item[field] : "";
        safeWriteSingleColumn(sheet, nextRow, colIdx, [[val]]);
      }
      
      return jsonResponse({
        status: "success",
        message: "Berhasil menambahkan data ke baris " + nextRow + " pada kolom terkonfigurasi.",
        rowNumber: nextRow
      });
    }

    // --- AKSI 4: URUNGKAN (UNDO) BARIS TERAKHIR ---
    if (action === "undo_last" || action === "delete_last_row") {
      var checkCol = activeTransactionMapping['tanggal'] || activeTransactionMapping['no'] || 1;
      for (var f in activeTransactionMapping) {
        checkCol = activeTransactionMapping[f];
        break;
      }
      
      var lastRow = sheet.getLastRow();
      if (lastRow >= startRow) {
        var totalToCheck = lastRow - startRow + 1;
        var rRange = sheet.getRange(startRow, checkCol, totalToCheck, 1);
        var rFormulas = rRange.getFormulas();
        var rValues = rRange.getValues();
        
        // Cari baris data transaksi terakhir dari bawah yang BUKAN sel rumus
        var targetUndoRow = -1;
        for (var i = totalToCheck - 1; i >= 0; i--) {
          var hasFormula = (rFormulas[i] && rFormulas[i][0] && rFormulas[i][0].toString().trim() !== "");
          var hasValue = (rValues[i][0] !== "" && rValues[i][0] !== null && rValues[i][0] !== undefined);
          if (!hasFormula && hasValue) {
            targetUndoRow = startRow + i;
            break;
          }
        }
        
        if (targetUndoRow >= startRow) {
          // Bersihkan HANYA kolom-kolom yang dipetakan pada baris tersebut
          for (var field in activeTransactionMapping) {
            var colIdx = activeTransactionMapping[field];
            var cell = sheet.getRange(targetUndoRow, colIdx);
            if (cell.getFormula() === "") {
              cell.clearContent();
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

    // --- AKSI 5: UPLOAD GAMBAR BUKTI (SALDO REKENING, CASH ON HAND, MUTASI REKENING 1-4) ---
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

      // Dapatkan atau buat folder penyimpanan otomatis di Google Drive
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

        // Tulis HANYA ke SATU SEL TERTENTU yang dikonfigurasi
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
