import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/model_sheets_config.dart';
import '../models/model_struktur.dart';
import '../utils/sheets_sync_service.dart';

class GoogleSheetsConfigModal extends StatefulWidget {
  final SheetsConfig initialConfig;
  final List<StrukturTransaction> transactions;
  final List<CustomKodeRule> customRules;
  final int initialTab;
  final Function(SheetsConfig) onConfigSaved;
  final VoidCallback? onSyncCompleted;

  const GoogleSheetsConfigModal({
    super.key,
    required this.initialConfig,
    this.transactions = const [],
    this.customRules = const [],
    this.initialTab = 0,
    required this.onConfigSaved,
    this.onSyncCompleted,
  });

  static Future<void> show({
    required BuildContext context,
    required SheetsConfig config,
    List<StrukturTransaction> transactions = const [],
    List<CustomKodeRule> customRules = const [],
    int initialTab = 0,
    required Function(SheetsConfig) onConfigSaved,
    VoidCallback? onSyncCompleted,
    bool useRootNavigator = true,
  }) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: useRootNavigator,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GoogleSheetsConfigModal(
        initialConfig: config,
        transactions: transactions,
        customRules: customRules,
        initialTab: initialTab,
        onConfigSaved: onConfigSaved,
        onSyncCompleted: onSyncCompleted,
      ),
    );
  }

  @override
  State<GoogleSheetsConfigModal> createState() =>
      _GoogleSheetsConfigModalState();
}

class _GoogleSheetsConfigModalState extends State<GoogleSheetsConfigModal> {
  late SheetsConfig _config;
  int _activeTab = 0; // 0: Koneksi, 1: Pemetaan Cell, 2: Script & Panduan
  final Set<int> _loadedTabs = {};

  late TextEditingController _urlCtrl;
  late TextEditingController _sheetNameCtrl;
  late TextEditingController _startRowCtrl;

  static const List<Map<String, String>> dateFormatPresets = [
    {
      'pattern': 'dd/MM/yyyy',
      'label': 'DD/MM/YYYY (Hari/Bulan/Tahun)',
      'badge': 'Standar ID / UK',
      'desc': 'Contoh: 01/08/2026 (1 Agustus)',
    },
    {
      'pattern': 'MM/dd/yyyy',
      'label': 'MM/DD/YYYY (Bulan/Hari/Tahun)',
      'badge': 'Standar Sheets US',
      'desc': 'Contoh: 08/01/2026 (Solusi 1 Agu terdeteksi 8 Jan)',
    },
    {
      'pattern': 'yyyy-MM-dd',
      'label': 'YYYY-MM-DD (Tahun-Bulan-Hari)',
      'badge': 'Standar ISO Universal',
      'desc': 'Contoh: 2026-08-01 (Aman di semua bahasa)',
    },
    {
      'pattern': 'dd-MM-yyyy',
      'label': 'DD-MM-YYYY (Hari-Bulan-Tahun)',
      'badge': 'Pemisah Strip',
      'desc': 'Contoh: 01-08-2026',
    },
    {
      'pattern': 'yyyy/MM/dd',
      'label': 'YYYY/MM/DD (Tahun/Bulan/Hari)',
      'badge': 'Pemisah Garis Miring',
      'desc': 'Contoh: 2026/08/01',
    },
    {
      'pattern': 'dd MMM yyyy',
      'label': 'DD MMM YYYY (Bulan Singkat)',
      'badge': 'Teks Singkat',
      'desc': 'Contoh: 01 Agu 2026 (Bebas ambiguitas)',
    },
    {
      'pattern': 'dd MMMM yyyy',
      'label': 'DD MMMM YYYY (Bulan Lengkap)',
      'badge': 'Teks Lengkap',
      'desc': 'Contoh: 01 Agustus 2026',
    },
  ];

  late String _selectedDateFormat;
  late TextEditingController _customDateFormatCtrl;

  final Map<String, TextEditingController> _colControllers = {};
  final Map<String, bool> _fieldVisibility = {};

  bool _isTesting = false;
  bool _isSyncing = false;
  String? _testMessage;
  bool? _testSuccess;

  final List<Map<String, String>> _transactionFields = [
    {'key': 'no', 'label': 'Nomor Urut', 'desc': '1, 2, 3, ...'},
    {'key': 'tanggal', 'label': 'Tanggal', 'desc': 'Format Tanggal Transaksi'},
    {'key': 'ku', 'label': 'Kode Unit (KU)', 'desc': 'KU-01, KU-02, dsb.'},
    {'key': 'kategori', 'label': 'Kategori', 'desc': 'Kategori Transaksi'},
    {'key': 'keterangan', 'label': 'Keterangan', 'desc': 'Judul & Rincian'},
    {'key': 'jumlah', 'label': 'Jumlah', 'desc': 'Total Nominal Transaksi'},
    {'key': 'debit', 'label': 'Debit (Pemasukan)', 'desc': 'Nominal Masuk'},
    {'key': 'kredit', 'label': 'Kredit (Pengeluaran)', 'desc': 'Nominal Keluar'},
  ];

  final List<Map<String, String>> _evidenceImageFields = [
    {
      'key': 'bukti_saldo_rekening',
      'label': 'Bukti Saldo Rekening',
      'desc': 'Screenshot Saldo Rekening Bank'
    },
    {
      'key': 'bukti_saldo_cash',
      'label': 'Bukti Saldo Cash On Hand',
      'desc': 'Foto Fisik Uang Tunai di Tangan'
    },
    {
      'key': 'bukti_mutasi_1',
      'label': 'Bukti Mutasi Rekening 1',
      'desc': 'Foto Mutasi Rekening Halaman 1'
    },
    {
      'key': 'bukti_mutasi_2',
      'label': 'Bukti Mutasi Rekening 2',
      'desc': 'Foto Mutasi Rekening Halaman 2'
    },
    {
      'key': 'bukti_mutasi_3',
      'label': 'Bukti Mutasi Rekening 3',
      'desc': 'Foto Mutasi Rekening Halaman 3'
    },
    {
      'key': 'bukti_mutasi_4',
      'label': 'Bukti Mutasi Rekening 4',
      'desc': 'Foto Mutasi Rekening Halaman 4'
    },
    {
      'key': 'bukti_mutasi_5',
      'label': 'Bukti Mutasi Rekening 5',
      'desc': 'Foto Mutasi Rekening Halaman 5'
    },
  ];

  List<Map<String, String>> get _fieldDefinitions => [
        ..._transactionFields,
        ..._evidenceImageFields,
      ];

  late TextEditingController _evidenceTargetRowCtrl;
  late bool _insertImageFormula;
  final Map<String, TextEditingController> _rowControllers = {};

  String _formatPreviewSample(String pattern) {
    try {
      final sampleDate = DateTime(2026, 8, 1, 14, 30);
      return DateFormat(pattern.trim()).format(sampleDate);
    } catch (_) {
      return 'Format tidak valid';
    }
  }

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab.clamp(0, 2);
    _loadedTabs.add(_activeTab);
    _config = SheetsConfig.fromJson(widget.initialConfig.toJson());

    _urlCtrl = TextEditingController(text: _config.webAppUrl);
    _sheetNameCtrl = TextEditingController(text: _config.sheetName);
    _startRowCtrl = TextEditingController(text: _config.startRow.toString());
    _evidenceTargetRowCtrl =
        TextEditingController(text: _config.evidenceTargetRow.toString());
    _insertImageFormula = _config.insertImageFormula;

    _selectedDateFormat = _config.dateFormat;
    final isPreset = dateFormatPresets.any((p) => p['pattern'] == _selectedDateFormat);
    _customDateFormatCtrl = TextEditingController(
      text: isPreset ? '' : _selectedDateFormat,
    );

    for (var f in _fieldDefinitions) {
      final key = f['key']!;
      final colVal = _config.columnMapping[key] ??
          SheetsConfig.defaultColumnMapping()[key] ??
          '-';
      final isExcluded = colVal == '-' || colVal.trim().isEmpty;
      _fieldVisibility[key] = !isExcluded;
      final suggested = SheetsConfig.suggestedColumn(key);
      _colControllers[key] =
          TextEditingController(text: isExcluded ? suggested : colVal);
    }

    for (var f in _evidenceImageFields) {
      final key = f['key']!;
      final rowVal = _config.getEvidenceRow(key);
      _rowControllers[key] = TextEditingController(text: rowVal.toString());
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _sheetNameCtrl.dispose();
    _startRowCtrl.dispose();
    _evidenceTargetRowCtrl.dispose();
    _customDateFormatCtrl.dispose();
    for (var c in _colControllers.values) {
      c.dispose();
    }
    for (var c in _rowControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _getMappingValidationError() {
    for (var f in _fieldDefinitions) {
      final key = f['key']!;
      final isVisible = _fieldVisibility[key] ?? true;
      if (isVisible) {
        final val = _colControllers[key]?.text.trim().toUpperCase() ?? '';
        if (val.isEmpty || val == '-') {
          return 'Kolom untuk "${f['label']}" wajib diisi. Masukkan huruf kolom (misal: A, B, C) atau matikan ikon mata.';
        }
      }
    }
    for (var f in _evidenceImageFields) {
      final key = f['key']!;
      final isVisible = _fieldVisibility[key] ?? true;
      if (isVisible) {
        final rowVal = int.tryParse(_rowControllers[key]?.text.trim() ?? '');
        if (rowVal == null || rowVal <= 0) {
          return 'Nomor baris untuk "${f['label']}" wajib diisi angka positif (misal: 60, 82).';
        }
      }
    }
    return null;
  }

  void _saveCurrentState({bool markCellsConfigured = false}) {
    _config.webAppUrl = _urlCtrl.text.trim();
    _config.sheetName = _sheetNameCtrl.text.trim();
    _config.startRow = int.tryParse(_startRowCtrl.text.trim()) ?? 2;
    _config.evidenceTargetRow =
        int.tryParse(_evidenceTargetRowCtrl.text.trim()) ?? 60;
    _config.insertImageFormula = _insertImageFormula;
    _config.dateFormat = _selectedDateFormat.trim().isEmpty
        ? 'dd/MM/yyyy'
        : _selectedDateFormat.trim();
    if (markCellsConfigured) {
      _config.hasConfiguredCells = true;
    }

    for (var f in _fieldDefinitions) {
      final key = f['key']!;
      final isVisible = _fieldVisibility[key] ?? true;
      if (!isVisible) {
        _config.columnMapping[key] = '-';
      } else {
        final val = _colControllers[key]?.text.trim().toUpperCase() ?? '';
        _config.columnMapping[key] = val.isEmpty
            ? (SheetsConfig.defaultColumnMapping()[key] ?? 'A')
            : val;
      }
    }

    for (var f in _evidenceImageFields) {
      final key = f['key']!;
      final rowVal = int.tryParse(_rowControllers[key]?.text.trim() ?? '') ??
          SheetsConfig.defaultEvidenceRowMapping()[key] ??
          60;
      _config.evidenceRowMapping[key] = rowVal > 0
          ? rowVal
          : (SheetsConfig.defaultEvidenceRowMapping()[key] ?? 60);
    }

    _config.save();
    widget.onConfigSaved(_config);
  }

  Future<void> _handleTestConnection() async {
    final mappingError = _getMappingValidationError();
    if (mappingError != null) {
      setState(() {
        _activeTab = 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(mappingError)),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _saveCurrentState();
    if (!_config.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Masukkan URL Web App Google Apps Script terlebih dahulu.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_sheetNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Nama Tab Sheet belum di isi')),
            ],
          ),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testMessage = null;
      _testSuccess = null;
    });

    final res = await SheetsSyncService.testConnection(_config);

    if (mounted) {
      setState(() {
        if (_config.sheetName.isNotEmpty) {
          _sheetNameCtrl.text = _config.sheetName;
        }
        _isTesting = false;
        _testSuccess = res.isSuccess;
        _testMessage = res.message;
      });
    }
  }

  Future<void> _handleSyncAll() async {
    final mappingError = _getMappingValidationError();
    if (mappingError != null) {
      setState(() {
        _activeTab = 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(mappingError)),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _saveCurrentState();
    if (!_config.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Masukkan URL Web App Google Apps Script terlebih dahulu.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_sheetNameCtrl.text.trim().isEmpty) {
      setState(() {
        _activeTab = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Nama Tab Sheet belum di isi')),
            ],
          ),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_config.hasConfiguredCells) {
      setState(() {
        _activeTab = 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pemetaan cell belum pernah dikonfigurasi. Silakan periksa dan simpan pemetaan cell terlebih dahulu.',
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _showMappingConfirmationDialog();
  }

  Future<void> _showMappingConfirmationDialog() async {
    final startRow = _config.startRow;
    final sheetName = _config.sheetName;
    final dateFormat = _config.dateFormat;
    final dateSample = _formatPreviewSample(dateFormat);

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF107C41).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.fact_check_rounded,
                  color: Color(0xFF107C41),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Konfirmasi Pemetaan Cell',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pratinjau cell sebelum kirim data',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Sheet & Format
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Sheet Tujuan:',
                              style: TextStyle(
                                  fontSize: 11.5, color: Color(0xFF475569)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                sheetName,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Baris Mulai Data:',
                              style: TextStyle(
                                  fontSize: 11.5, color: Color(0xFF475569)),
                            ),
                            Text(
                              'Baris $startRow',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Format Tanggal:',
                              style: TextStyle(
                                  fontSize: 11.5, color: Color(0xFF475569)),
                            ),
                            Text(
                              '$dateFormat ($dateSample)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Section Kolom Transaksi
                  const Text(
                    'Pemetaan Kolom Transaksi',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: _transactionFields.map((f) {
                        final key = f['key']!;
                        final label = f['label']!;
                        final isVisible = _fieldVisibility[key] ?? true;
                        final colVal = isVisible
                            ? (_colControllers[key]?.text.trim().toUpperCase() ??
                                '-')
                            : 'Dikecualikan';
                        final isExcluded = !isVisible || colVal == '-';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isExcluded
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF334155),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isExcluded
                                      ? const Color(0xFFF1F5F9)
                                      : const Color(0xFF107C41)
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  isExcluded ? 'Dikecualikan' : 'Kolom $colVal',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: isExcluded
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF107C41),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Section Kolom Gambar Bukti
                  const Text(
                    'Pemetaan Gambar Bukti',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        ..._evidenceImageFields.map((f) {
                          final key = f['key']!;
                          final label = f['label']!;
                          final isVisible = _fieldVisibility[key] ?? true;
                          final colVal =
                              _colControllers[key]?.text.trim().toUpperCase() ??
                                  '-';
                          final rowVal =
                              _rowControllers[key]?.text.trim() ??
                              (SheetsConfig.defaultEvidenceRowMapping()[key]?.toString() ?? '60');
                          final isExcluded =
                              !isVisible || colVal.isEmpty || colVal == '-';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isExcluded
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF334155),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isExcluded
                                        ? const Color(0xFFF1F5F9)
                                        : const Color(0xFF0284C7)
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    isExcluded
                                        ? 'Dikecualikan'
                                        : 'Sel $colVal$rowVal',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: isExcluded
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Format Sisipkan Bukti:',
                              style: TextStyle(
                                  fontSize: 10.5, color: Color(0xFF64748B)),
                            ),
                            Text(
                              _insertImageFormula
                                  ? 'Sisipkan di Sel (HD)'
                                  : 'Link Google Drive',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: _insertImageFormula
                                    ? const Color(0xFF107C41)
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Pertanyaan Konfirmasi
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.help_outline_rounded,
                          color: Color(0xFFD97706),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Apakah seluruh pemetaan cell di atas sudah benar dan sesuai dengan tabel Google Spreadsheet Anda?',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _activeTab = 1;
                      });
                    },
                    icon: const Icon(Icons.tune_rounded, size: 15),
                    label: const Text(
                      'Cell',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF107C41),
                      side: const BorderSide(color: Color(0xFF107C41)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Batal',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _saveCurrentState(markCellsConfigured: true);
                      _executeSyncAll();
                    },
                    icon: const Icon(Icons.send_rounded, size: 15),
                    label: const Text(
                      'Konfirmasi',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF107C41),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeSyncAll() async {
    setState(() {
      _isSyncing = true;
    });

    final res = await SheetsSyncService.syncAllTransactions(
      widget.transactions,
      _config,
      customRules: widget.customRules,
    );

    if (mounted) {
      setState(() {
        _isSyncing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                res.isSuccess ? Icons.check_circle : Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(res.message)),
            ],
          ),
          backgroundColor:
              res.isSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (res.isSuccess && widget.onSyncCompleted != null) {
        widget.onSyncCompleted!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _saveCurrentState();
        }
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        margin: EdgeInsets.only(bottom: bottomInset),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle & Header
            _buildHeader(),

            // Tab Navigation Bar
            _buildTabBar(),

            // Body Content
            Expanded(
              child: IndexedStack(
                index: _activeTab,
                children: [
                  _loadedTabs.contains(0)
                      ? _buildConnectionTab()
                      : const SizedBox.shrink(),
                  _loadedTabs.contains(1)
                      ? _buildColumnMappingTab()
                      : const SizedBox.shrink(),
                  _loadedTabs.contains(2)
                      ? _buildScriptGuideTab()
                      : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF107C41).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.table_chart_rounded,
                  color: Color(0xFF107C41),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Integrasi Google Spreadsheets',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Sinkronisasi Tabel Lap Keu via Google Apps Script',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  _saveCurrentState();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                splashRadius: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildTabItem(0, Icons.link_rounded, 'Koneksi'),
            _buildTabItem(1, Icons.view_column_rounded, 'Pemetaan Cell'),
            _buildTabItem(2, Icons.code_rounded, 'Script & Panduan'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String title) {
    final isActive = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _saveCurrentState();
          setState(() {
            _activeTab = index;
            _loadedTabs.add(index);
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color:
                    isActive ? const Color(0xFF107C41) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 1: KONEKSI & AUTO-SYNC ---
  Widget _buildConnectionTab() {
    final lastSyncStr = _config.lastSyncTime != null
        ? DateFormat('dd MMM yyyy, HH:mm').format(_config.lastSyncTime!)
        : 'Belum pernah';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Status Koneksi
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _config.isConfigured
                    ? [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)]
                    : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _config.isConfigured
                    ? const Color(0xFF86EFAC)
                    : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _config.isConfigured
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                    color: _config.isConfigured
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFD97706),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _config.isConfigured
                            ? 'Google Spreadsheets Siap'
                            : 'Konfigurasi Belum Lengkap',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _config.isConfigured
                              ? const Color(0xFF14532D)
                              : const Color(0xFF78350F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Terakhir Sinkron: $lastSyncStr',
                        style: TextStyle(
                          fontSize: 11,
                          color: _config.isConfigured
                              ? const Color(0xFF15803D)
                              : const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Input URL Web App
          const Text(
            'URL Web App Google Apps Script',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TextField(
              controller: _urlCtrl,
              onChanged: (v) => _saveCurrentState(),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              textAlignVertical: TextAlignVertical.center,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                hintText:
                    'https://script.google.com/macros/s/AKfycb.../exec',
                hintStyle:
                    const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: InputBorder.none,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_urlCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _urlCtrl.clear();
                          _saveCurrentState();
                          setState(() {});
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.paste_rounded, size: 18),
                      tooltip: 'Tempel dari Clipboard',
                      onPressed: () async {
                        final data =
                            await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null) {
                          _urlCtrl.text = data!.text!.trim();
                          _saveCurrentState();
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Input Nama Sheet
          const Text(
            'Nama Tab Sheet di Spreadsheet',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TextField(
              controller: _sheetNameCtrl,
              onChanged: (v) => _saveCurrentState(),
              style: const TextStyle(fontSize: 12.5),
              textAlignVertical: TextAlignVertical.center,
              decoration: const InputDecoration(
                hintText: 'Masukkan nama Tab',
                hintStyle:
                    TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.tab_rounded,
                    color: Color(0xFF64748B), size: 18),
                prefixIconConstraints:
                    BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Switch Auto-Sync on Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _config.autoSyncOnInput
                        ? const Color(0xFF107C41).withValues(alpha: 0.12)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.sync_alt_rounded,
                    color: _config.autoSyncOnInput
                        ? const Color(0xFF107C41)
                        : const Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-Sync Saat Input Data',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Otomatis kirim ke Google Sheets setiap ada transaksi baru',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _config.autoSyncOnInput,
                  activeThumbColor: const Color(0xFF107C41),
                  onChanged: (val) {
                    setState(() {
                      _config.autoSyncOnInput = val;
                    });
                    _saveCurrentState();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Feedback Pesan Tes
          if (_testMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_testSuccess ?? false)
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (_testSuccess ?? false)
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    (_testSuccess ?? false)
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    color: (_testSuccess ?? false)
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _testMessage!,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: (_testSuccess ?? false)
                            ? const Color(0xFF14532D)
                            : const Color(0xFF7F1D1D),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Tombol Action Tes & Sinkronkan Semua
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isTesting ? null : _handleTestConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_rounded, size: 16),
                  label: const Text(
                    'Tes Koneksi',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF107C41),
                    side: const BorderSide(color: Color(0xFF107C41)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _handleSyncAll,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_rounded, size: 16),
                  label: Text(
                    _isSyncing
                        ? 'Menyinkronkan...'
                        : 'Kirim Semua (${widget.transactions.length})',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF107C41),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _resetMappingToDefault() {
    final def = SheetsConfig.defaultColumnMapping();
    final defRows = SheetsConfig.defaultEvidenceRowMapping();
    setState(() {
      _startRowCtrl.text = '4';
      _evidenceTargetRowCtrl.text = '60';
      _insertImageFormula = false;
      _selectedDateFormat = 'dd/MM/yyyy';
      _customDateFormatCtrl.text = '';
      for (var f in _fieldDefinitions) {
        final key = f['key']!;
        final val = def[key] ?? '-';
        final isExcluded = val == '-' || val.trim().isEmpty;
        _fieldVisibility[key] = !isExcluded;
        final suggested = SheetsConfig.suggestedColumn(key);
        _colControllers[key]?.text = isExcluded ? suggested : val;
      }
      for (var f in _evidenceImageFields) {
        final key = f['key']!;
        final val = defRows[key] ?? 60;
        _rowControllers[key]?.text = val.toString();
      }
    });
    _saveCurrentState();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pemetaan kolom & baris dikembalikan ke pengaturan standar.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildFieldRow(Map<String, String> f) {
    final key = f['key']!;
    final label = f['label']!;
    final desc = key == 'tanggal'
        ? 'Pola: $_selectedDateFormat (${_formatPreviewSample(_selectedDateFormat)})'
        : f['desc']!;
    final ctrl = _colControllers[key]!;
    final isVisible = _fieldVisibility[key] ?? true;
    final isExcluded = !isVisible;
    final colText = ctrl.text.trim().toUpperCase();
    final isMissingColumn = isVisible && (colText.isEmpty || colText == '-');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isExcluded
            ? const Color(0xFFF8FAFC)
            : (isMissingColumn ? const Color(0xFFFFF1F2) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExcluded
              ? const Color(0xFFE2E8F0)
              : (isMissingColumn
                  ? const Color(0xFFF87171)
                  : const Color(0xFFCBD5E1)),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // Badge Kolom
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isExcluded
                  ? const Color(0xFFE2E8F0)
                  : (isMissingColumn
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFF107C41).withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: isMissingColumn
                  ? const Icon(
                      Icons.priority_high_rounded,
                      size: 18,
                      color: Color(0xFFDC2626),
                    )
                  : Text(
                      isExcluded ? '-' : (colText.isEmpty ? '?' : colText),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isExcluded
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF107C41),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Label & Keterangan
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isExcluded
                              ? const Color(0xFF94A3B8)
                              : (isMissingColumn
                                  ? const Color(0xFF991B1B)
                                  : const Color(0xFF1E293B)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isExcluded)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Dikecualikan',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (isMissingColumn)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Text(
                          'Wajib Diisi',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  isExcluded
                      ? 'Tidak akan dimasukkan ke spreadsheet'
                      : (isMissingColumn
                          ? 'Wajib isi kolom (cth: A, B) atau matikan ikon mata'
                          : desc),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: isExcluded
                        ? const Color(0xFFCBD5E1)
                        : (isMissingColumn
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF94A3B8)),
                    fontWeight:
                        isMissingColumn ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          // Tombol Saklar Kecualikan / Gunakan (Ikon Mata)
          IconButton(
            icon: Icon(
              isExcluded
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
              color: isExcluded
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF107C41),
            ),
            tooltip: isExcluded
                ? 'Gunakan kolom ini'
                : 'Kecualikan (Jangan gunakan kolom ini)',
            onPressed: () {
              setState(() {
                final willBeVisible = isExcluded;
                _fieldVisibility[key] = willBeVisible;
                if (willBeVisible) {
                  if (ctrl.text.trim().isEmpty || ctrl.text.trim() == '-') {
                    ctrl.text = SheetsConfig.suggestedColumn(key);
                  }
                }
              });
              _saveCurrentState();
            },
          ),
          const SizedBox(width: 4),
          // Input Huruf Kolom
          SizedBox(
            width: 48,
            height: 34,
            child: TextField(
              controller: ctrl,
              enabled: isVisible,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                LengthLimitingTextInputFormatter(3),
              ],
              onChanged: (val) {
                setState(() {});
                _saveCurrentState();
              },
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: isExcluded
                    ? const Color(0xFF94A3B8)
                    : (isMissingColumn
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF0F172A)),
              ),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.zero,
                hintText: isExcluded ? '-' : 'A-Z',
                hintStyle: TextStyle(
                  fontSize: 10,
                  color: isMissingColumn
                      ? const Color(0xFFF87171)
                      : const Color(0xFF94A3B8),
                ),
                filled: isExcluded || isMissingColumn,
                fillColor: isExcluded
                    ? const Color(0xFFF1F5F9)
                    : (isMissingColumn
                        ? const Color(0xFFFFF1F2)
                        : Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isMissingColumn
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isMissingColumn
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFCBD5E1),
                    width: 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isMissingColumn
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF107C41),
                    width: 1.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceFieldRow(Map<String, String> field) {
    final key = field['key']!;
    final label = field['label']!;
    final desc = field['desc']!;
    final colCtrl = _colControllers[key]!;
    final rowCtrl = _rowControllers[key]!;
    final isVisible = _fieldVisibility[key] ?? true;
    final isExcluded = !isVisible;
    final colText = colCtrl.text.trim().toUpperCase();
    final rowText = rowCtrl.text.trim();
    final rowNum = int.tryParse(rowText);
    final isMissingColumn = isVisible && (colText.isEmpty || colText == '-');
    final isMissingRow =
        isVisible && (rowText.isEmpty || rowNum == null || rowNum <= 0);
    final hasError = isMissingColumn || isMissingRow;
    final cellStr = isExcluded
        ? '-'
        : (hasError
            ? (colText.isEmpty ? '?' : colText) +
                (rowText.isEmpty ? '?' : rowText)
            : '$colText$rowText');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isExcluded
            ? const Color(0xFFF8FAFC)
            : (hasError ? const Color(0xFFFFF1F2) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExcluded
              ? const Color(0xFFE2E8F0)
              : (hasError
                  ? const Color(0xFFF87171)
                  : const Color(0xFFCBD5E1).withValues(alpha: 0.8)),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // Target Cell Badge (e.g. I2, J5)
          Container(
            width: 46,
            height: 36,
            decoration: BoxDecoration(
              color: isExcluded
                  ? const Color(0xFFE2E8F0)
                  : (hasError
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFF107C41).withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isExcluded
                    ? Colors.transparent
                    : (hasError
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFF107C41).withValues(alpha: 0.25)),
              ),
            ),
            child: Center(
              child: hasError
                  ? const Icon(
                      Icons.priority_high_rounded,
                      size: 18,
                      color: Color(0xFFDC2626),
                    )
                  : Text(
                      cellStr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isExcluded
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF107C41),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          // Label & Keterangan
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isExcluded
                              ? const Color(0xFF94A3B8)
                              : (hasError
                                  ? const Color(0xFF991B1B)
                                  : const Color(0xFF1E293B)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isExcluded)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Dikecualikan',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (hasError)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          isMissingColumn && isMissingRow
                              ? 'Kolom & Baris Kosong'
                              : (isMissingColumn
                                  ? 'Kolom Wajib Diisi'
                                  : 'Baris Wajib Diisi'),
                          style: const TextStyle(
                            fontSize: 8.5,
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  isExcluded
                      ? 'Tidak akan dimasukkan ke spreadsheet'
                      : (hasError
                          ? 'Wajib isi kolom & baris atau matikan ikon mata'
                          : desc),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: isExcluded
                        ? const Color(0xFFCBD5E1)
                        : (hasError
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF94A3B8)),
                    fontWeight: hasError ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          // Tombol Saklar Kecualikan / Gunakan (Ikon Mata)
          IconButton(
            icon: Icon(
              isExcluded
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
              color: isExcluded
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF107C41),
            ),
            tooltip: isExcluded
                ? 'Gunakan kolom ini'
                : 'Kecualikan (Jangan gunakan)',
            onPressed: () {
              setState(() {
                final willBeVisible = isExcluded;
                _fieldVisibility[key] = willBeVisible;
                if (willBeVisible) {
                  if (colCtrl.text.trim().isEmpty ||
                      colCtrl.text.trim() == '-') {
                    colCtrl.text = SheetsConfig.suggestedColumn(key);
                  }
                  if (rowCtrl.text.trim().isEmpty ||
                      (int.tryParse(rowCtrl.text.trim()) ?? 0) <= 0) {
                    final defRow =
                        SheetsConfig.defaultEvidenceRowMapping()[key] ?? 60;
                    rowCtrl.text = defRow.toString();
                  }
                }
              });
              _saveCurrentState();
            },
          ),
          const SizedBox(width: 4),
          // Input Huruf Kolom (e.g. I)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kolom',
                style: TextStyle(
                  fontSize: 8.5,
                  color: isMissingColumn
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 1),
              SizedBox(
                width: 38,
                height: 32,
                child: TextField(
                  controller: colCtrl,
                  enabled: isVisible,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                    LengthLimitingTextInputFormatter(3),
                  ],
                  onChanged: (val) {
                    setState(() {});
                    _saveCurrentState();
                  },
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: isExcluded
                        ? const Color(0xFF94A3B8)
                        : (isMissingColumn
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF0F172A)),
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    hintText: isExcluded ? '-' : 'A-Z',
                    hintStyle: TextStyle(
                      fontSize: 9.5,
                      color: isMissingColumn
                          ? const Color(0xFFF87171)
                          : const Color(0xFF94A3B8),
                    ),
                    filled: isExcluded || isMissingColumn,
                    fillColor: isExcluded
                        ? const Color(0xFFF1F5F9)
                        : (isMissingColumn
                            ? const Color(0xFFFFF1F2)
                            : Colors.white),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: isMissingColumn
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: isMissingColumn
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFCBD5E1),
                        width: isMissingColumn ? 1.5 : 1.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: isMissingColumn
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF107C41),
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          // Input Nomor Baris (e.g. 2, 5, 10)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Baris',
                style: TextStyle(
                  fontSize: 8.5,
                  color: isMissingRow
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 1),
              SizedBox(
                width: 44,
                height: 32,
                child: TextField(
                  controller: rowCtrl,
                  enabled: isVisible,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  onChanged: (val) {
                    setState(() {});
                    _saveCurrentState();
                  },
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: isExcluded
                        ? const Color(0xFF94A3B8)
                        : (isMissingRow
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF0F172A)),
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    hintText: isExcluded ? '-' : '2',
                    hintStyle: TextStyle(
                      fontSize: 10,
                      color: isMissingRow
                          ? const Color(0xFFF87171)
                          : const Color(0xFF94A3B8),
                    ),
                    filled: isExcluded || isMissingRow,
                    fillColor: isExcluded
                        ? const Color(0xFFF1F5F9)
                        : (isMissingRow
                            ? const Color(0xFFFFF1F2)
                            : Colors.white),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: isMissingRow
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: isMissingRow
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFCBD5E1),
                        width: isMissingRow ? 1.5 : 1.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: isMissingRow
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF107C41),
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateFormatSection() {
    final previewText = _formatPreviewSample(_selectedDateFormat);
    final isCustom = !dateFormatPresets.any((p) => p['pattern'] == _selectedDateFormat);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF0284C7),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Format & Urutan Tanggal Spreadsheet',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Atur urutan Hari, Bulan, dan Tahun saat data dikirim',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dropdown Opsi Format Tanggal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: isCustom ? '__custom__' : _selectedDateFormat,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                items: [
                  ...dateFormatPresets.map((preset) {
                    final pattern = preset['pattern']!;
                    final label = preset['label']!;
                    final badge = preset['badge']!;
                    return DropdownMenuItem<String>(
                      value: pattern,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const DropdownMenuItem<String>(
                    value: '__custom__',
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Kustom (Ketik Pola DateFormat Sendiri)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                        ),
                        Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF0369A1)),
                      ],
                    ),
                  ),
                ],
                onChanged: (newVal) {
                  if (newVal == null) return;
                  setState(() {
                    if (newVal == '__custom__') {
                      if (_customDateFormatCtrl.text.isEmpty) {
                        _customDateFormatCtrl.text = _selectedDateFormat;
                      }
                    } else {
                      _selectedDateFormat = newVal;
                    }
                  });
                  _saveCurrentState();
                },
              ),
            ),
          ),

          // Jika Kustom dipilih, tampilkan input pola
          if (isCustom) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _customDateFormatCtrl,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Contoh: dd/MM/yyyy atau yyyy-MM-dd',
                hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                labelText: 'Pola DateFormat Kustom',
                labelStyle: const TextStyle(fontSize: 11.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _selectedDateFormat = val.trim().isEmpty ? 'dd/MM/yyyy' : val.trim();
                });
                _saveCurrentState();
              },
            ),
          ],

          const SizedBox(height: 10),

          // Live Preview Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.visibility_rounded,
                  color: Color(0xFF16A34A),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                      children: [
                        const TextSpan(text: 'Contoh 1 Agustus 2026 dikirim sebagai: '),
                        TextSpan(
                          text: previewText,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF14532D),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Tips Box Penjelasan Masalah Tanggal Terbalik di Spreadsheet US
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEFCE8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFEF08A)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Color(0xFFCA8A04),
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tips Masalah Tanggal: Jika di Google Sheets Anda 01/08/2026 terbaca sebagai 8 Januari (karena lokal US), pilih format MM/DD/YYYY atau YYYY-MM-DD.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF854D0E),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: PEMETAAN KOLOM ---
  Widget _buildColumnMappingTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_config.hasConfiguredCells) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFD97706), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pemetaan cell belum pernah dikonfigurasi. Silakan periksa posisi kolom & baris di bawah, lalu klik "Simpan Pemetaan" sebelum mengirim data.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Info Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Color(0xFF2563EB), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Atur posisi kolom Google Spreadsheet untuk data transaksi & bukti gambar sesuai format yang Anda inginkan (misal: Kolom A, B, C, dst).',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Info Box: Format Visual Spreadsheet 100% Terjaga
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_rounded,
                    color: Color(0xFF16A34A), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Format Sel Spreadsheet Terjaga: Pengiriman data hanya mengisi nilai sel (raw data). Seluruh pengaturan font, ukuran huruf, perataan teks (alignment), warna, border, dan format angka (Rp) akan 100% mengikuti format template di Google Sheets Anda tanpa terubah.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF14532D),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Header List Mapping Transaksi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '1. Kolom Data Transaksi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              TextButton.icon(
                onPressed: _resetMappingToDefault,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Reset Standar',
                    style: TextStyle(fontSize: 11.5)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Baris Mulai Data
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Baris Mulai Data Transaksi (Start Row)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Posisi awal baris penulisan data transaksi',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 60,
                  height: 38,
                  child: TextField(
                    controller: _startRowCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (v) => _saveCurrentState(),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Pengaturan Format & Urutan Tanggal Spreadsheet
          _buildDateFormatSection(),

          // Daftar Kolom Field Transaksi
          ..._transactionFields.map((f) => _buildFieldRow(f)),

          const SizedBox(height: 20),

          // Section 2: Pemetaan Kolom & Baris Bukti Gambar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '2. Kolom & Baris Gambar Bukti',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Bisa Beda Baris Per-Slot',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Switch / Toggle Sisipkan Gambar di Sel (Native In-Cell Image)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _insertImageFormula
                  ? const Color(0xFFF0FDF4)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _insertImageFormula
                    ? const Color(0xFFA7F3D0)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sisipkan Gambar di dalam Sel (Kualitas Tajam / HD)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        _insertImageFormula
                            ? 'Foto disisipkan langsung ke dalam sel (seperti menu Sisipkan > Gambar > Di dalam Sel), kualitas asli jernih & tidak blur.'
                            : 'Spreadsheet akan menaruh Link URL Google Drive (bisa diklik).',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _insertImageFormula,
                  activeThumbColor: const Color(0xFF107C41),
                  onChanged: (val) {
                    setState(() {
                      _insertImageFormula = val;
                    });
                    _saveCurrentState();
                  },
                ),
              ],
            ),
          ),

          // Daftar Kolom & Baris Field Gambar Bukti
          ..._evidenceImageFields.map((f) => _buildEvidenceFieldRow(f)),

          const SizedBox(height: 20),

          // Action Button: Simpan Pemetaan Cell
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final err = _getMappingValidationError();
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(err)),
                        ],
                      ),
                      backgroundColor: const Color(0xFFDC2626),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                _saveCurrentState(markCellsConfigured: true);
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Konfigurasi cell berhasil',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Color(0xFF059669),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text(
                'Simpan Pemetaan Cell',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF107C41),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _shareScriptFile(String scriptCode) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box != null ? box.localToGlobal(Offset.zero) & box.size : null;

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Code_AppsScript_DailyApps.txt');
      await file.writeAsString(scriptCode);

      final xFile = XFile(
        file.path,
        mimeType: 'text/plain',
        name: 'Code_AppsScript_DailyApps.txt',
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text:
              'Kode Google Apps Script Daily Apps (100% Utuh Tanpa Terpotong).\nBuka file ini di Laptop, salin isinya, dan tempelkan ke editor Google Apps Script.',
          subject: 'Google Apps Script - Daily Apps',
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membagikan file script: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- TAB 3: SCRIPT & PANDUAN ---
  Widget _buildScriptGuideTab() {
    final scriptCode = SheetsSyncService.getGoogleAppsScriptCode();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Salin / Kirim Script Utama
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF107C41), Color(0xFF0D6334)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF107C41).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.integration_instructions_rounded,
                        color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Google Apps Script Code',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Kode siap pakai untuk ditempel di Apps Script Google Spreadsheet',
                            style: TextStyle(
                                fontSize: 10.5, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Tombol Aksi: Kirim File (.txt) & Salin Teks
                Row(
                  children: [
                    // Tombol 1: Kirim File Dokumen (Solusi anti-terpotong)
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        onPressed: () => _shareScriptFile(scriptCode),
                        icon: const Icon(Icons.share_rounded, size: 15),
                        label: const Text(
                          'Kirim File (.txt)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF107C41),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Tombol 2: Salin Teks Biasa
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: scriptCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Kode Google Apps Script berhasil disalin ke Clipboard!'),
                              backgroundColor: Color(0xFF107C41),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded,
                            size: 14, color: Colors.white),
                        label: const Text(
                          'Salin Teks',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white70),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Hint Banner
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded,
                          size: 14, color: Color(0xFFFFD54F)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Kirim via WhatsApp Dokumen / Email ke Laptop agar kode 100% utuh tidak terpotong.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Langkah-langkah Setup
          const Text(
            'Panduan Pemasangan (5 Menit)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),

          _buildStepItem(
            '1',
            'Buka Google Spreadsheet',
            'Buka Google Spreadsheet tujuan Anda pada browser di PC / HP.',
          ),
          _buildStepItem(
            '2',
            'Buka Editor Apps Script',
            'Klik menu "Extensions" (Ekstensi) -> pilih "Apps Script".',
          ),
          _buildStepItem(
            '3',
            'Tempelkan Kode Script & Simpan',
            'Buka file script yang dikirim ke Laptop (atau tekan tombol Salin), lalu Paste (Tempel) seluruh isinya ke editor Google Apps Script, lalu klik ikon Simpan (Disk).',
          ),
          _buildStepItem(
            '4',
            'Beri Izin Akses (Authorize)',
            'Pilih fungsi "authorizeDrive" di dropdown toolbar atas -> klik tombol "Run" (Run / Jalankan) -> klik "Review Permissions / Tinjau Izin" -> pilih Akun Google -> klik "Advanced / Lanjutan" -> klik "Go to ... (unsafe)" -> klik "Allow / Izinkan".',
            isHighlight: true,
          ),
          _buildStepItem(
            '5',
            'Deploy Sebagai Web App',
            'Klik tombol "Deploy" (Terapkan) -> "Manage deployments" -> klik ikon Pensil (Edit) -> Version: "New version" -> Deploy.\n(Jika baru pertama: Deploy -> "New deployment" -> type "Web app" -> "Who has access": "Anyone" -> Deploy).',
          ),
          _buildStepItem(
            '6',
            'Salin Web App URL ke Aplikasi',
            'Salin "Web app URL" yang muncul (berakhiran /exec), lalu buka Tab "Koneksi" di modal ini dan Paste pada kolom URL.',
          ),

          const SizedBox(height: 16),

          // Code Preview Box
          const Text(
            'Pratinjau Kode Script',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              scriptCode,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
                fontFamily: 'monospace',
                height: 1.4,
              ),
              maxLines: 15,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStepItem(
    String stepNum,
    String title,
    String description, {
    bool isHighlight = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlight
              ? const Color(0xFFFECACA)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isHighlight
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF107C41),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNum,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isHighlight
                        ? const Color(0xFF991B1B)
                        : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isHighlight
                        ? const Color(0xFF7F1D1D)
                        : const Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
