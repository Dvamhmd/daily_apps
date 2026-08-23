import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:daily_apps/models/model_struktur.dart';

class ImportResult {
  final List<CustomKodeRule> rules;
  final int totalRowsRead;
  final int kuCount;
  final int kategoriCount;
  final List<String> warnings;
  final String? errorMessage;
  final bool isSuccess;

  ImportResult({
    required this.rules,
    required this.totalRowsRead,
    required this.kuCount,
    required this.kategoriCount,
    this.warnings = const [],
    this.errorMessage,
    this.isSuccess = true,
  });

  factory ImportResult.error(String message) {
    return ImportResult(
      rules: [],
      totalRowsRead: 0,
      kuCount: 0,
      kategoriCount: 0,
      errorMessage: message,
      isSuccess: false,
    );
  }
}

class CustomRuleImportHelper {
  /// Mem-parsing file Excel (.xlsx / .xls) dari bytes
  static ImportResult parseExcelBytes(Uint8List bytes, {String? defaultType}) {
    try {
      final excel = Excel.decodeBytes(bytes);
      final List<List<String>> allRows = [];

      for (final table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null) continue;

        for (final row in sheet.rows) {
          final rowStrings = row.map((cell) {
            if (cell == null || cell.value == null) return '';
            final val = cell.value;
            if (val is TextCellValue) return val.value.text ?? '';
            return val.toString().trim();
          }).toList();

          // Abaikan jika seluruh kolom dalam satu baris kosong
          if (rowStrings.any((s) => s.trim().isNotEmpty)) {
            allRows.add(rowStrings);
          }
        }
      }

      if (allRows.isEmpty) {
        return ImportResult.error('File Excel tidak memiliki data atau baris kosong.');
      }

      return parseTableRows(allRows, defaultType: defaultType);
    } catch (e) {
      return ImportResult.error('Gagal membaca file Excel: $e');
    }
  }

  /// Mem-parsing teks terformat (hasil Copy-Paste dari Excel / CSV / TSV)
  static ImportResult parseText(String text, {String? defaultType}) {
    try {
      final trimmed = text.trim();
      if (trimmed.isEmpty) {
        return ImportResult.error('Teks konfigurasi masih kosong.');
      }

      final lines = const LineSplitter().convert(trimmed);
      final List<List<String>> allRows = [];

      for (var line in lines) {
        final lineTrim = line.trim();
        if (lineTrim.isEmpty) continue;

        List<String> cells;
        if (lineTrim.contains('\t')) {
          // Tab-delimited (Format standar copy-paste dari Excel/Sheets)
          cells = lineTrim.split('\t');
        } else if (lineTrim.contains('|')) {
          // Pipe-delimited (Markdown table)
          cells = lineTrim
              .split('|')
              .map((c) => c.trim())
              .where((c) => c.isNotEmpty && !c.contains('---'))
              .toList();
          if (cells.isEmpty) continue;
        } else if (lineTrim.contains(';')) {
          // Semicolon-delimited (CSV regional)
          cells = _splitCsvLine(lineTrim, ';');
        } else if (lineTrim.contains(',')) {
          // Comma-delimited (Standard CSV)
          cells = _splitCsvLine(lineTrim, ',');
        } else {
          // Single cell or space delimited
          cells = [lineTrim];
        }

        final cleanedCells = cells.map((c) => c.trim()).toList();
        if (cleanedCells.any((c) => c.isNotEmpty)) {
          allRows.add(cleanedCells);
        }
      }

      if (allRows.isEmpty) {
        return ImportResult.error('Tidak ditemukan data yang valid dari teks yang dimasukkan.');
      }

      return parseTableRows(allRows, defaultType: defaultType);
    } catch (e) {
      return ImportResult.error('Gagal membaca teks konfigurasi: $e');
    }
  }

  /// Helper untuk memisahkan baris CSV sederhana dengan memperhatikan tanda kutip
  static List<String> _splitCsvLine(String line, String delimiter) {
    final List<String> result = [];
    final buffer = StringBuffer();
    bool insideQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        insideQuotes = !insideQuotes;
      } else if (char == delimiter && !insideQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString().trim());
    return result;
  }

  /// Helper utama untuk memproses baris-baris tabel menjadi `List<CustomKodeRule>`
  static ImportResult parseTableRows(
    List<List<String>> rows, {
    String? defaultType,
  }) {
    if (rows.isEmpty) {
      return ImportResult.error('Tidak ada baris data untuk diproses.');
    }

    final List<CustomKodeRule> parsedRules = [];
    final List<String> warnings = [];

    int colType = 0;
    int colKeyword = 1;
    int colResult = 2;

    int startIndex = 0;
    final firstRow = rows.first.map((e) => e.trim().toLowerCase()).toList();

    // Deteksi apakah baris pertama adalah Header
    final isHeader = _isHeaderRow(firstRow);
    if (isHeader) {
      startIndex = 1;
      // Cari indeks kolom berdasarkan nama header
      for (int i = 0; i < firstRow.length; i++) {
        final colName = firstRow[i];
        if (colName.contains('jenis') ||
            colName.contains('tipe') ||
            colName.contains('type') ||
            colName == 'aturan') {
          colType = i;
        } else if (colName.contains('pemicu') ||
            colName.contains('keterangan') ||
            colName.contains('keyword') ||
            colName.contains('kata kunci') ||
            colName == 'ket') {
          colKeyword = i;
        } else if (colName.contains('hasil') ||
            colName.contains('result') ||
            colName.contains('output') ||
            colName.contains('kode') ||
            colName == 'kategori' ||
            colName == 'ku' ||
            colName.contains('nilai')) {
          colResult = i;
        }
      }
    }

    for (int i = startIndex; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      String rawType = '';
      String rawKeyword = '';
      String rawResult = '';

      if (row.length >= 3) {
        rawType = colType < row.length ? row[colType].trim() : '';
        rawKeyword = colKeyword < row.length ? row[colKeyword].trim() : '';
        rawResult = colResult < row.length ? row[colResult].trim() : '';
      } else if (row.length == 2) {
        // Jika 2 kolom: kemungkinan [Keyword, Hasil] atau [Jenis, Keyword]
        final first = row[0].trim();
        final second = row[1].trim();
        final firstLower = first.toLowerCase();

        if (firstLower == 'ku' || firstLower == 'kategori') {
          rawType = first;
          rawKeyword = second;
          rawResult = second;
        } else {
          rawType = defaultType ?? 'kategori';
          rawKeyword = first;
          rawResult = second;
        }
      } else if (row.length == 1) {
        warnings.add('Baris ${i + 1} diabaikan karena hanya memiliki 1 kolom: "${row[0]}".');
        continue;
      }

      // Bersihkan teks kutip ganda jika ada
      rawKeyword = _stripQuotes(rawKeyword);
      rawResult = _stripQuotes(rawResult);
      rawType = _stripQuotes(rawType);

      if (rawKeyword.isEmpty || rawResult.isEmpty) {
        if (rawKeyword.isNotEmpty || rawResult.isNotEmpty) {
          warnings.add('Baris ${i + 1} dilewati karena kolom keterangan atau hasil kosong.');
        }
        continue;
      }

      // Tentukan tipe 'ku' atau 'kategori'
      String normalizedType = 'kategori';
      final typeLower = rawType.toLowerCase();
      if (typeLower.contains('ku') || typeLower == 'k') {
        normalizedType = 'ku';
      } else if (typeLower.contains('kat') || typeLower.contains('category')) {
        normalizedType = 'kategori';
      } else if (defaultType != null && defaultType.isNotEmpty) {
        normalizedType = defaultType == 'ku' ? 'ku' : 'kategori';
      }

      parsedRules.add(
        CustomKodeRule(
          keyword: rawKeyword,
          kode: rawResult,
          type: normalizedType,
        ),
      );
    }

    if (parsedRules.isEmpty) {
      return ImportResult(
        rules: [],
        totalRowsRead: rows.length,
        kuCount: 0,
        kategoriCount: 0,
        warnings: warnings,
        errorMessage: 'Tidak ada aturan valid yang berhasil dibaca. Pastikan format kolom sesuai.',
        isSuccess: false,
      );
    }

    final kuCount = parsedRules.where((r) => r.type == 'ku').length;
    final kategoriCount = parsedRules.where((r) => r.type != 'ku').length;

    return ImportResult(
      rules: parsedRules,
      totalRowsRead: rows.length,
      kuCount: kuCount,
      kategoriCount: kategoriCount,
      warnings: warnings,
      isSuccess: true,
    );
  }

  static bool _isHeaderRow(List<String> row) {
    if (row.isEmpty) return false;
    final combined = row.join(' ').toLowerCase();
    return combined.contains('jenis') ||
        combined.contains('pemicu') ||
        combined.contains('keterangan') ||
        combined.contains('hasil') ||
        combined.contains('keyword') ||
        combined.contains('aturan') ||
        combined.contains('kode');
  }

  static String _stripQuotes(String s) {
    var str = s.trim();
    if ((str.startsWith('"') && str.endsWith('"')) ||
        (str.startsWith("'") && str.endsWith("'"))) {
      if (str.length >= 2) {
        str = str.substring(1, str.length - 1).trim();
      }
    }
    return str;
  }

  /// Menggabungkan hasil import dengan aturan yang ada
  static List<CustomKodeRule> applyImport({
    required List<CustomKodeRule> currentRules,
    required List<CustomKodeRule> importedRules,
    required bool replaceAll,
    String? targetTypeFilter, // 'all', 'ku', 'kategori'
  }) {
    if (replaceAll) {
      if (targetTypeFilter == 'ku') {
        final remainingKategori =
            currentRules.where((r) => r.type != 'ku').toList();
        final newKuRules = importedRules.where((r) => r.type == 'ku').toList();
        return [...remainingKategori, ...newKuRules];
      } else if (targetTypeFilter == 'kategori') {
        final remainingKu =
            currentRules.where((r) => r.type == 'ku').toList();
        final newKategoriRules =
            importedRules.where((r) => r.type != 'ku').toList();
        return [...remainingKu, ...newKategoriRules];
      } else {
        return List<CustomKodeRule>.from(importedRules);
      }
    } else {
      // Merge: Update aturan yang memiliki keyword sama & tipe sama, atau tambahkan yang baru
      final result = List<CustomKodeRule>.from(currentRules);

      for (final newRule in importedRules) {
        final index = result.indexWhere((r) =>
            r.type == newRule.type &&
            r.keyword.trim().toLowerCase() ==
                newRule.keyword.trim().toLowerCase());

        if (index != -1) {
          // Update nilai kode jika sudah ada
          result[index].kode = newRule.kode;
        } else {
          // Tambahkan sebagai aturan baru
          result.add(newRule);
        }
      }
      return result;
    }
  }

  /// Menghasilkan file Excel template (.xlsx) berisi contoh format
  static Uint8List generateTemplateExcelBytes() {
    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Aturan Transaksi';
    final sheet = excel[sheetName];

    sheet.appendRow([
      TextCellValue('Jenis Aturan'),
      TextCellValue('Keterangan Pemicu'),
      TextCellValue('Hasil'),
    ]);

    sheet.appendRow([
      TextCellValue('KU'),
      TextCellValue('rapat'),
      TextCellValue('Sekretaris'),
    ]);
    sheet.appendRow([
      TextCellValue('KU'),
      TextCellValue('pengabaran'),
      TextCellValue('Publikasi'),
    ]);
    sheet.appendRow([
      TextCellValue('Kategori'),
      TextCellValue('Konsumsi'),
      TextCellValue('Konsumsi'),
    ]);
    sheet.appendRow([
      TextCellValue('Kategori'),
      TextCellValue('fotocopy'),
      TextCellValue('ATK & Perlengkapan'),
    ]);
    sheet.appendRow([
      TextCellValue('KU'),
      TextCellValue('dekorasi'),
      TextCellValue('Perlengkapan'),
    ]);

    final bytes = excel.save();
    return Uint8List.fromList(bytes ?? []);
  }

  /// Menghasilkan contoh teks CSV / Paste
  static String getTemplateSampleText() {
    return 'Jenis Aturan\tKeterangan Pemicu\tHasil\n'
        'KU\trapat\tSekretaris\n'
        'KU\tpengabaran\tPublikasi\n'
        'Kategori\tKonsumsi\tKonsumsi\n'
        'Kategori\tfotocopy\tATK & Perlengkapan\n'
        'KU\tdekorasi\tPerlengkapan';
  }
}
