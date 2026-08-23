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
  }) {
    final dateFormatted = DateFormat('dd/MM/yyyy').format(tx.timestamp);
    final rawKu = tx.getDisplayKu(customRules: customRules).trim();
    final String ku = (rawKu == '-' || rawKu.isEmpty) ? '' : rawKu;

    final rawKategori = tx.getDisplayKode(customRules: customRules).trim();
    final String kategori =
        (rawKategori == '-' || rawKategori.isEmpty) ? '' : rawKategori;

    final String itemTitle = tx.title.replaceFirst(
      RegExp(r'^(Pemasukan|Pengeluaran):\s*', caseSensitive: false),
      '',
    );
    final String? itemSubtitle = (tx.note != null &&
            tx.note!.isNotEmpty &&
            tx.note != tx.title &&
            tx.note != itemTitle)
        ? tx.note
        : null;

    final String fullKeterangan = itemSubtitle != null
        ? '$itemTitle ($itemSubtitle)'
        : itemTitle;

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
        ));
      }

      final payload = {
        'action': 'sync_all',
        'sheetName': config.sheetName,
        'startRow': config.startRow,
        'mapping': config.columnMapping,
        'rows': rows,
      };

      final res = await _sendPostRequest(config.webAppUrl, payload);
      final status = res['status'] as String?;
      final msg = res['message'] as String? ??
          'Berhasil sinkronisasi ${rows.length} data.';

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

  /// Mengembalikan script Google Apps Script siap salin (Copy-Paste)
  static String getGoogleAppsScriptCode() {
    return '''/**
 * =========================================================================
 * GOOGLE APPS SCRIPT - INTEGRASI TABEL LAP KEU KEUANGAN STRUKTUR
 * Aplikasi: Daily Apps
 * =========================================================================
 * 
 * PETUNJUK PEMASANGAN LANGKAH DEMI LANGKAH:
 * 1. Buka Google Spreadsheet tujuan Anda.
 * 2. Di menu atas, pilih "Extensions" (Ekstensi) -> "Apps Script".
 * 3. Hapus seluruh kode default yang ada di editor, lalu tempel (Paste) kode ini.
 * 4. Klik ikon Simpan (Disk) di toolbar atas.
 * 5. Klik tombol "Deploy" (Terapkan) berwarna biru di kanan atas -> pilih "New deployment" (Penerapan baru).
 *    (Jika update kode: Klik "Deploy" -> "Manage deployments" -> klik ikon Pensil (Edit) -> Version: "New version" -> Deploy).
 * 6. Klik ikon Roda Gigi (Select type) -> pilih "Web app" (Aplikasi web).
 * 7. Masukkan konfigurasi berikut:
 *    - Description : Integrasi Keuangan Struktur Daily Apps
 *    - Execute as  : Me (email akun Google Anda)
 *    - Who has access : Anyone (Siapa saja)  <-- PENTING SEKALI!
 * 8. Klik "Deploy", lalu jika diminta izin:
 *    - Klik "Authorize access" (Beri akses)
 *    - Pilih akun Google Anda
 *    - Klik "Advanced" (Lanjutan) di kiri bawah
 *    - Klik "Go to ... (unsafe)"
 *    - Klik "Allow" (Izinkan)
 * 9. Salin "Web app URL" (URL yang berakhiran /exec).
 * 10. Buka Daily Apps -> Masuk ke Keuangan Struktur -> Buka Pengaturan Google Spreadsheets -> Tempelkan URL tersebut.
 */

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
      return jsonResponse({
        status: "success",
        message: "Koneksi Berhasil! Terhubung ke Spreadsheet: '" + ss.getName() + "' (Tab: '" + sheet.getName() + "')",
        spreadsheetName: ss.getName(),
        sheetName: sheet.getName()
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
      kredit: "H"
    };

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

    // Ambil daftar mapping aktif yang valid
    var maxCol = 1;
    var activeMapping = {};
    for (var key in mapping) {
      var colIdx = colLetterToIndex(mapping[key]);
      if (colIdx > 0) {
        activeMapping[key] = colIdx;
        if (colIdx > maxCol) maxCol = colIdx;
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

    // Helper penulisan sel yang aman terhadap aturan Validasi Data / Dropdown Google Spreadsheet
    function safeWriteMatrix(targetSheet, startRowIdx, matrixData, numCols) {
      if (!matrixData || matrixData.length === 0) return;
      var numRows = matrixData.length;
      var range = targetSheet.getRange(startRowIdx, 1, numRows, numCols);
      var validations = range.getDataValidations();

      // 1. Cocokkan nilai matrixData dengan opsi dropdown yang ada di sel
      if (validations && validations.length > 0) {
        for (var r = 0; r < numRows; r++) {
          for (var c = 0; c < numCols; c++) {
            var rule = (validations[r] && validations[r][c]) ? validations[r][c] : null;
            if (rule && matrixData[r][c] !== "" && matrixData[r][c] !== null && matrixData[r][c] !== undefined) {
              matrixData[r][c] = matchDropdownValue(rule, matrixData[r][c]);
            }
          }
        }
      }

      // 2. Setel relaksasi validasi (setAllowInvalid: true) agar penulisan diizinkan penuh oleh Google Sheets
      try {
        if (validations && validations.length > 0) {
          var relaxedRules = [];
          var hasValidation = false;
          for (var r = 0; r < validations.length; r++) {
            var rowList = [];
            for (var c = 0; c < validations[r].length; c++) {
              var rule = validations[r][c];
              if (rule) {
                hasValidation = true;
                rowList.push(rule.copy().setAllowInvalid(true).build());
              } else {
                rowList.push(null);
              }
            }
            relaxedRules.push(rowList);
          }
          if (hasValidation) {
            range.setDataValidations(relaxedRules);
          }
        }
      } catch (eRel) {}

      // 3. Tulis batch matrix data ke spreadsheet
      try {
        range.setValues(matrixData);
        return;
      } catch (err) {}

      // 4. Fallback per-sel jika ada kegagalan khusus
      for (var r = 0; r < numRows; r++) {
        var currentRow = startRowIdx + r;
        for (var c = 0; c < numCols; c++) {
          var val = matrixData[r][c];
          var cell = targetSheet.getRange(currentRow, c + 1);
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
    }

    // --- AKSI 2: SINKRONISASI SEMUA DATA (BATCH) ---
    if (action === "sync_all") {
      var rows = data.rows || [];
      
      // Bersihkan data lama dari startRow ke bawah
      var lastRow = sheet.getLastRow();
      if (lastRow >= startRow) {
        var numRowsToClear = lastRow - startRow + 1;
        sheet.getRange(startRow, 1, numRowsToClear, maxCol).clearContent();
      }
      
      if (rows.length > 0) {
        var matrix = [];
        for (var r = 0; r < rows.length; r++) {
          var item = rows[r];
          var rowArr = new Array(maxCol).fill("");
          
          for (var field in activeMapping) {
            var targetCol = activeMapping[field] - 1; // 0-based
            if (targetCol >= 0 && targetCol < maxCol) {
              rowArr[targetCol] = (item[field] !== undefined && item[field] !== null) ? item[field] : "";
            }
          }
          matrix.push(rowArr);
        }
        
        safeWriteMatrix(sheet, startRow, matrix, maxCol);
      }
      
      return jsonResponse({
        status: "success",
        message: "Berhasil sinkronisasi " + rows.length + " baris data ke sheet '" + sheetName + "'",
        count: rows.length
      });
    }
    
    // Helper mencari baris kosong pertama berdasarkan kolom data yang dipetakan
    function getFirstEmptyDataRow(targetSheet, startRowIdx, checkColIdx) {
      var col = checkColIdx > 0 ? checkColIdx : 1;
      var lastRow = targetSheet.getLastRow();
      if (lastRow < startRowIdx) return startRowIdx;
      
      var range = targetSheet.getRange(startRowIdx, col, lastRow - startRowIdx + 1, 1);
      var values = range.getValues();
      for (var i = 0; i < values.length; i++) {
        var val = values[i][0];
        if (val === "" || val === null || val === undefined) {
          return startRowIdx + i;
        }
      }
      return lastRow + 1;
    }

    // --- AKSI 3: TAMBAH 1 BARIS REALTIME (ADD ROW) ---
    if (action === "add_row") {
      var item = data.row || {};
      var checkCol = 1;
      for (var k in activeMapping) {
        checkCol = activeMapping[k];
        break;
      }
      var nextRow = getFirstEmptyDataRow(sheet, startRow, checkCol);
      var rowArr = new Array(maxCol).fill("");
      
      for (var field in activeMapping) {
        var targetCol = activeMapping[field] - 1; // 0-based
        if (targetCol >= 0 && targetCol < maxCol) {
          rowArr[targetCol] = (item[field] !== undefined && item[field] !== null) ? item[field] : "";
        }
      }
      
      safeWriteMatrix(sheet, nextRow, [rowArr], maxCol);
      
      return jsonResponse({
        status: "success",
        message: "Berhasil menambahkan data ke baris " + nextRow,
        rowNumber: nextRow
      });
    }

    // --- AKSI 4: URUNGKAN (UNDO) BARIS TERAKHIR ---
    if (action === "undo_last" || action === "delete_last_row") {
      var lastRow = sheet.getLastRow();
      if (lastRow >= startRow) {
        // Bersihkan baris terakhir
        sheet.getRange(lastRow, 1, 1, maxCol).clearContent();
        return jsonResponse({
          status: "success",
          message: "Berhasil mengurungkan (Undo) data pada baris ke-" + lastRow + " di sheet '" + sheetName + "'",
          undoneRow: lastRow
        });
      } else {
        return jsonResponse({
          status: "error",
          message: "Tidak ada baris data untuk di-undo (sudah mencapai batas baris awal)."
        });
      }
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
