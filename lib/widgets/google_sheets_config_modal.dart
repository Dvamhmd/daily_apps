import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/model_sheets_config.dart';
import '../models/model_struktur.dart';
import '../utils/sheets_sync_service.dart';

class GoogleSheetsConfigModal extends StatefulWidget {
  final SheetsConfig initialConfig;
  final List<StrukturTransaction> transactions;
  final List<CustomKodeRule> customRules;
  final Function(SheetsConfig) onConfigSaved;
  final VoidCallback? onSyncCompleted;

  const GoogleSheetsConfigModal({
    super.key,
    required this.initialConfig,
    required this.transactions,
    required this.customRules,
    required this.onConfigSaved,
    this.onSyncCompleted,
  });

  static Future<void> show({
    required BuildContext context,
    required SheetsConfig config,
    required List<StrukturTransaction> transactions,
    required List<CustomKodeRule> customRules,
    required Function(SheetsConfig) onConfigSaved,
    VoidCallback? onSyncCompleted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GoogleSheetsConfigModal(
        initialConfig: config,
        transactions: transactions,
        customRules: customRules,
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

  late TextEditingController _urlCtrl;
  late TextEditingController _sheetNameCtrl;
  late TextEditingController _startRowCtrl;

  final Map<String, TextEditingController> _colControllers = {};

  bool _isTesting = false;
  bool _isSyncing = false;
  String? _testMessage;
  bool? _testSuccess;

  final List<Map<String, String>> _fieldDefinitions = [
    {'key': 'no', 'label': 'Nomor Urut', 'desc': '1, 2, 3, ...'},
    {'key': 'tanggal', 'label': 'Tanggal', 'desc': 'Format DD/MM/YYYY'},
    {'key': 'ku', 'label': 'Kode Unit (KU)', 'desc': 'KU-01, KU-02, dsb.'},
    {'key': 'kategori', 'label': 'Kategori', 'desc': 'Kategori Transaksi'},
    {'key': 'keterangan', 'label': 'Keterangan', 'desc': 'Judul & Rincian'},
    {'key': 'jumlah', 'label': 'Jumlah', 'desc': 'Total Nominal Transaksi'},
    {'key': 'debit', 'label': 'Debit (Pemasukan)', 'desc': 'Nominal Masuk'},
    {'key': 'kredit', 'label': 'Kredit (Pengeluaran)', 'desc': 'Nominal Keluar'},
  ];

  @override
  void initState() {
    super.initState();
    _config = SheetsConfig.fromJson(widget.initialConfig.toJson());

    _urlCtrl = TextEditingController(text: _config.webAppUrl);
    _sheetNameCtrl = TextEditingController(text: _config.sheetName);
    _startRowCtrl = TextEditingController(text: _config.startRow.toString());

    for (var f in _fieldDefinitions) {
      final key = f['key']!;
      final colVal = _config.columnMapping[key] ??
          SheetsConfig.defaultColumnMapping()[key] ??
          'A';
      _colControllers[key] = TextEditingController(text: colVal);
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _sheetNameCtrl.dispose();
    _startRowCtrl.dispose();
    for (var c in _colControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _saveCurrentState() {
    _config.webAppUrl = _urlCtrl.text.trim();
    _config.sheetName = _sheetNameCtrl.text.trim().isEmpty
        ? 'Lap Keu'
        : _sheetNameCtrl.text.trim();
    _config.startRow = int.tryParse(_startRowCtrl.text.trim()) ?? 2;

    for (var f in _fieldDefinitions) {
      final key = f['key']!;
      final val = _colControllers[key]?.text.trim().toUpperCase() ?? '-';
      _config.columnMapping[key] = (val.isEmpty || val == '-') ? '-' : val;
    }

    _config.save();
    widget.onConfigSaved(_config);
  }

  Future<void> _handleTestConnection() async {
    _saveCurrentState();
    if (!_config.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan URL Web App Google Apps Script terlebih dahulu.'),
          backgroundColor: Colors.redAccent,
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
        _isTesting = false;
        _testSuccess = res.isSuccess;
        _testMessage = res.message;
      });
    }
  }

  Future<void> _handleSyncAll() async {
    _saveCurrentState();
    if (!_config.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan URL Web App Google Apps Script terlebih dahulu.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

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



  void _resetMappingToDefault() {
    final def = SheetsConfig.defaultColumnMapping();
    setState(() {
      _startRowCtrl.text = '2';
      for (var f in _fieldDefinitions) {
        final key = f['key']!;
        final val = def[key] ?? 'A';
        _colControllers[key]?.text = val;
      }
    });
    _saveCurrentState();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pemetaan kolom dikembalikan ke standar (A-H, Baris 2).'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
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
                _buildConnectionTab(),
                _buildCellMappingTab(),
                _buildScriptGuideTab(),
              ],
            ),
          ),
        ],
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
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                hintText:
                    'https://script.google.com/macros/s/AKfycb.../exec',
                hintStyle:
                    const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              decoration: const InputDecoration(
                hintText: 'Contoh: Lap Keu, Sheet1, Kas Struktur',
                hintStyle:
                    TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.tab_rounded,
                    color: Color(0xFF64748B), size: 18),
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

  // --- TAB 2: PEMETAAN CELL & KOLOM ---
  Widget _buildCellMappingTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Penjelasan
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
                    'Atur posisi kolom Google Spreadsheet untuk tiap data Tabel Lap Keu sesuai format yang Anda inginkan (misal: Kolom A, B, C, dst).',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Baris Mulai Data
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Baris Mulai Data (Start Row)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
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
          const SizedBox(height: 16),

          // Header List Mapping
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pemetaan Kolom Spreadsheet',
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

          // Daftar Kolom Field
          ..._fieldDefinitions.map((f) {
            final key = f['key']!;
            final label = f['label']!;
            final desc = f['desc']!;
            final ctrl = _colControllers[key]!;
            final isExcluded =
                ctrl.text.trim().isEmpty || ctrl.text.trim() == '-';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isExcluded ? const Color(0xFFF8FAFC) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isExcluded
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFFCBD5E1),
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
                          : const Color(0xFF107C41).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        isExcluded ? '-' : ctrl.text.trim().toUpperCase(),
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
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isExcluded
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF1E293B),
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
                              ),
                          ],
                        ),
                        Text(
                          isExcluded
                              ? 'Tidak akan dimasukkan ke spreadsheet'
                              : desc,
                          style: TextStyle(
                            fontSize: 10,
                            color: isExcluded
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tombol Saklar Kecualikan / Gunakan
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
                        if (isExcluded) {
                          final def =
                              SheetsConfig.defaultColumnMapping()[key] ?? 'A';
                          ctrl.text = def;
                        } else {
                          ctrl.text = '-';
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
                      enabled: !isExcluded,
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
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
                            : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.zero,
                        hintText: '-',
                        filled: isExcluded,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
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
          // Tombol Salin Script Utama
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
            child: Row(
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
                        style: TextStyle(fontSize: 10.5, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
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
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Salin',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF107C41),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
            'Tempelkan Kode Script',
            'Hapus kode default di editor, lalu tekan tombol "Salin" di atas dan Paste (Tempel) ke editor Google Apps Script.',
          ),
          _buildStepItem(
            '4',
            'Deploy Sebagai Web App',
            'Klik tombol "Deploy" (Terapkan) -> "New deployment" -> pilih type "Web app".\nAtur "Who has access" ke "Anyone" (Siapa saja), lalu klik Deploy & Izinkan Akses (Authorize).',
            isHighlight: true,
          ),
          _buildStepItem(
            '5',
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
