import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:daily_apps/models/model_sheets_config.dart';
import 'package:daily_apps/models/model_struktur.dart';
import 'package:daily_apps/utils/custom_rule_import_helper.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:daily_apps/utils/sheets_sync_service.dart';
import 'package:daily_apps/widgets/google_sheets_config_modal.dart';
import 'package:daily_apps/widgets/upload_evidence_modal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StrukturPage extends StatefulWidget {
  const StrukturPage({super.key});

  @override
  State<StrukturPage> createState() => _StrukturPageState();
}

class _StrukturPageState extends State<StrukturPage> {
  static const Color primaryPurple = Color(0xFF5E35B1);
  static const Color darkPurple = Color(0xFF4527A0);
  static const Color primaryTeal = Color(0xFF00897B);

  static const List<String> _bankList = [
    'BCA',
    'Mandiri',
    'BRI',
    'BNI',
    'BSI',
    'CIMB Niaga',
    'Bank Jago',
    'SeaBank',
    'Blu by BCA',
    'Permata',
    'Danamon',
    'BTN',
    'Dana',
    'GoPay',
    'OVO',
    'ShopeePay',
    'Lainnya',
  ];

  static const List<String> _namaBulan = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  StrukturData _data = StrukturData();
  SheetsConfig _sheetsConfig = SheetsConfig();
  bool _isLoading = true;

  String get _monthKey =>
      '${_selectedMonth.year}_${_selectedMonth.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadSheetsConfig();
  }

  Future<void> _loadSheetsConfig() async {
    final cfg = await SheetsConfig.load();
    if (mounted) {
      setState(() {
        _sheetsConfig = cfg;
      });
    }
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _isLoading = true;
    });
    _loadData();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      _isLoading = true;
    });
    _loadData();
  }

  void _showMonthYearPicker() {
    int tempYear = _selectedMonth.year;
    int tempMonth = _selectedMonth.month;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Bulan & Tahun',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      final now = DateTime.now();
                      setDialogState(() {
                        tempYear = now.year;
                        tempMonth = now.month;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Bulan Ini',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryPurple,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Year Selector
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded),
                            onPressed: () {
                              setDialogState(() => tempYear--);
                            },
                          ),
                          Text(
                            '$tempYear',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryPurple,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            onPressed: () {
                              setDialogState(() => tempYear++);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Month Grid (4 rows x 3 cols)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, idx) {
                        final monthNum = idx + 1;
                        final isSelected = tempMonth == monthNum;
                        final isCurrentActual =
                            (monthNum == DateTime.now().month &&
                                tempYear == DateTime.now().year);

                        return InkWell(
                          onTap: () {
                            setDialogState(() => tempMonth = monthNum);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryPurple
                                  : (isCurrentActual
                                      ? primaryPurple.withValues(alpha: 0.1)
                                      : Colors.grey[100]),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? primaryPurple
                                    : (isCurrentActual
                                        ? primaryPurple.withValues(alpha: 0.4)
                                        : Colors.transparent),
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _namaBulan[idx].substring(0, 3),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : (isCurrentActual
                                        ? FontWeight.w600
                                        : FontWeight.normal),
                                color: isSelected
                                    ? Colors.white
                                    : (isCurrentActual
                                        ? primaryPurple
                                        : Colors.black87),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Batal',
                              style: TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedMonth = DateTime(tempYear, tempMonth);
                              _isLoading = true;
                            });
                            _loadData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Terapkan'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final monthlyKey = 'struktur_keuangan_data_$_monthKey';
    final raw = prefs.getString(monthlyKey);

    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          if (mounted) {
            setState(() {
              _data = StrukturData.fromJson(decoded);
              _isLoading = false;
            });
          }
          return;
        }
      } catch (_) {}
    }

    // Migrasi data legacy jika ada data di 'struktur_keuangan_data'
    final legacyRaw = prefs.getString('struktur_keuangan_data');
    if (legacyRaw != null) {
      try {
        final decoded = jsonDecode(legacyRaw);
        if (decoded is Map<String, dynamic>) {
          final now = DateTime.now();
          // Jika membuka bulan ini, migrasikan data legacy
          if (_selectedMonth.year == now.year &&
              _selectedMonth.month == now.month) {
            final legacyData = StrukturData.fromJson(decoded);
            await prefs.setString(monthlyKey, legacyRaw);
            if (mounted) {
              setState(() {
                _data = legacyData;
                _isLoading = false;
              });
            }
            return;
          } else {
            // Untuk bulan baru, bawa metadata akun rekening, On Hand & aturan kustom (saldo awal 0)
            final templateData = StrukturData.fromJson(decoded);
            final newMonthData = StrukturData(
              rekeningStruktur: RekeningStruktur(
                bankName: templateData.rekeningStruktur.bankName,
                accountNumber: templateData.rekeningStruktur.accountNumber,
                accountHolder: templateData.rekeningStruktur.accountHolder,
                balance: 0,
              ),
              onHandDebit: OnHandDebit(
                bankName: templateData.onHandDebit.bankName,
                accountNumber: templateData.onHandDebit.accountNumber,
                accountHolder: templateData.onHandDebit.accountHolder,
                balance: 0,
              ),
              onHandCash: OnHandCash(balance: 0),
              transactions: [],
              customKodeRules: List.from(templateData.customKodeRules),
            );
            if (mounted) {
              setState(() {
                _data = newMonthData;
                _isLoading = false;
              });
            }
            await _saveData();
            return;
          }
        }
      } catch (_) {}
    }

    // Default initial values jika belum ada data sama sekali
    final defaultData = StrukturData(
      rekeningStruktur: RekeningStruktur(
        bankName: 'BCA',
        accountNumber: '',
        accountHolder: '',
        balance: 0,
      ),
      onHandDebit: OnHandDebit(
        bankName: 'BCA',
        accountNumber: '',
        accountHolder: '',
        balance: 0,
      ),
      onHandCash: OnHandCash(balance: 0),
      transactions: [],
      customKodeRules: [],
    );

    if (mounted) {
      setState(() {
        _data = defaultData;
        _isLoading = false;
      });
    }
    await _saveData();
  }

  Timer? _autoSyncDebounceTimer;

  @override
  void dispose() {
    _autoSyncDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final monthlyKey = 'struktur_keuangan_data_$_monthKey';
    await prefs.setString(monthlyKey, jsonEncode(_data.toJson()));
    // Simpan juga versi terkini ke key legacy sebagai cadangan/template
    await prefs.setString('struktur_keuangan_data', jsonEncode(_data.toJson()));
  }

  void _triggerAutoSyncSheets() {
    if (!_sheetsConfig.isConfigured || !_sheetsConfig.autoSyncOnInput) return;

    _autoSyncDebounceTimer?.cancel();
    _autoSyncDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      final allMutasi = _data.transactions
          .where((tx) => tx.isPemasukan || tx.isPengeluaran)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      SheetsSyncService.syncAllTransactions(
        allMutasi,
        _sheetsConfig,
        customRules: _data.customKodeRules,
      ).then((res) {
        if (mounted) {
          debugPrint('Auto-sync Sheets result: ${res.isSuccess} - ${res.message}');
          setState(() {});
        }
      });
    });
  }

  Future<void> _showGoogleSheetsConfigModal() async {
    final freshCfg = await SheetsConfig.load();
    if (!mounted) return;
    setState(() {
      _sheetsConfig = freshCfg;
    });

    final allMutasi = _data.transactions
        .where((tx) => tx.isPemasukan || tx.isPengeluaran)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    GoogleSheetsConfigModal.show(
      context: context,
      config: _sheetsConfig,
      transactions: allMutasi,
      customRules: _data.customKodeRules,
      onConfigSaved: (newCfg) {
        setState(() {
          _sheetsConfig = newCfg;
        });
      },
      onSyncCompleted: () {
        setState(() {});
      },
    );
  }

  Future<void> _showUploadEvidenceModal() async {
    final freshCfg = await SheetsConfig.load();
    if (!mounted) return;
    setState(() {
      _sheetsConfig = freshCfg;
    });

    UploadEvidenceModal.show(
      context,
      sheetsConfig: _sheetsConfig,
      monthLabel: '${_namaBulan[_selectedMonth.month - 1]} ${_selectedMonth.year}',
      onConfigChanged: (newCfg) {
        setState(() {
          _sheetsConfig = newCfg;
        });
      },
      onUploaded: () {
        setState(() {});
      },
    );
  }

  // --- MODAL KELOLA KUSTOM ATURAN TRANSAKSI (2 TAB: KU & KATEGORI) ---
  void _showKelolaKustomKodeModal() {
    String selectedTab = 'ku'; // 'ku' atau 'kategori'
    String searchQuery = '';
    String testInput = '';
    final searchCtrl = TextEditingController();
    final testCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final kuRules = _data.customKodeRules
                .where((r) => r.type == 'ku')
                .toList();
            final kategoriRules = _data.customKodeRules
                .where((r) => r.type != 'ku')
                .toList();

            final currentTabRules = selectedTab == 'ku' ? kuRules : kategoriRules;

            final rules = currentTabRules.where((r) {
              if (searchQuery.isEmpty) return true;
              return r.keyword.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  r.kode.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            final testKuResult = StrukturTransaction.resolveKuFromText(
              testInput,
              customRules: _data.customKodeRules,
            );
            final testKategoriResult = StrukturTransaction.resolveKodeFromText(
              testInput,
              customRules: _data.customKodeRules,
            );

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.90,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header Modal
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.style_rounded,
                            color: Color(0xFF6366F1), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kustom Aturan Transaksi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Atur kata kunci pemicu auto-input KU & Kategori',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Tombol Import di Header (Berlaku untuk KU & Kategori)
                      OutlinedButton.icon(
                        onPressed: () {
                          _showImportKustomKodeDialog(
                            selectedTab,
                            () => setModalState(() {}),
                          );
                        },
                        icon: const Icon(Icons.file_download_outlined,
                            size: 15, color: Color(0xFF059669)),
                        label: const Text(
                          'Import',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFECFDF5),
                          side: const BorderSide(color: Color(0xFFA7F3D0)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () => Navigator.pop(bottomSheetCtx),
                        icon: const Icon(Icons.close_rounded,
                            color: Color(0xFF64748B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2-Tab Selector (KU & Kategori)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        // Tab KU
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                selectedTab = 'ku';
                              });
                            },
                            borderRadius: BorderRadius.circular(9),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedTab == 'ku'
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: selectedTab == 'ku'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : [],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.badge_outlined,
                                    size: 15,
                                    color: selectedTab == 'ku'
                                        ? const Color(0xFF4F46E5)
                                        : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'KU (${kuRules.length})',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: selectedTab == 'ku'
                                          ? const Color(0xFF4F46E5)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Tab Kategori
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                selectedTab = 'kategori';
                              });
                            },
                            borderRadius: BorderRadius.circular(9),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedTab == 'kategori'
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: selectedTab == 'kategori'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : [],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.category_outlined,
                                    size: 15,
                                    color: selectedTab == 'kategori'
                                        ? const Color(0xFF4F46E5)
                                        : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Kategori (${kategoriRules.length})',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: selectedTab == 'kategori'
                                          ? const Color(0xFF4F46E5)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 15, color: Color(0xFF6366F1)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedTab == 'ku'
                                ? 'Aturan KU otomatis mengisi kolom "KU" saat kata kunci cocok dengan keterangan transaksi.'
                                : 'Aturan Kategori otomatis mengisi kolom "Kategori" saat kata kunci cocok dengan keterangan transaksi.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Search Bar & Tambah Button Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchCtrl,
                          onChanged: (val) {
                            setModalState(() {
                              searchQuery = val.trim();
                            });
                          },
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            hintText: selectedTab == 'ku'
                                ? 'Cari kata kunci / KU...'
                                : 'Cari kata kunci / Kategori...',
                            hintStyle: TextStyle(
                                fontSize: 12, color: Colors.grey[400]),
                            prefixIcon: Icon(Icons.search_rounded,
                                size: 18, color: Colors.grey[400]),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded,
                                        size: 16),
                                    onPressed: () {
                                      searchCtrl.clear();
                                      setModalState(() => searchQuery = '');
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Color(0xFF6366F1), width: 1.2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          _showFormKustomKodeDialog(
                            null,
                            selectedTab,
                            () => setModalState(() {}),
                          );
                        },
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(
                          selectedTab == 'ku' ? '+ Tambah KU' : '+ Tambah Kategori',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Interactive Live Test Box
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt_rounded,
                                size: 15, color: Color(0xFF059669)),
                            SizedBox(width: 4),
                            Text(
                              'Uji Coba Auto-Input Langsung:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: testCtrl,
                          onChanged: (val) {
                            setModalState(() {
                              testInput = val;
                            });
                          },
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1E293B),
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'Ketik contoh keterangan di sini...',
                            hintStyle: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF94A3B8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 9,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF10B981),
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // Result KU
                              const Text(
                                'KU: ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF047857),
                                ),
                              ),
                              _buildKuBadge(testKuResult, isLarge: false),
                              const SizedBox(width: 12),
                              // Result Kategori
                              const Text(
                                'Kategori: ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF047857),
                                ),
                              ),
                              _buildKodeBadge(testKategoriResult, isLarge: false),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Daftar Aturan Label & Reset Button Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daftar Aturan ${selectedTab == 'ku' ? 'KU' : 'Kategori'} (${rules.length}):',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                        ),
                      ),
                      if (rules.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            _confirmClearAllKodeRules(
                              selectedTab,
                              () => setModalState(() {}),
                            );
                          },
                          icon: const Icon(Icons.delete_sweep_rounded,
                              size: 14, color: Color(0xFFE11D48)),
                          label: Text(
                            'Kosongkan ${selectedTab == 'ku' ? 'KU' : 'Kategori'}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE11D48),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // List of Rules
                  Expanded(
                    child: rules.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF1F5F9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.rule_folder_outlined,
                                        size: 32, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    searchQuery.isNotEmpty
                                        ? 'Tidak ditemukan aturan yang cocok'
                                        : 'Daftar aturan ${selectedTab == 'ku' ? 'KU' : 'Kategori'} masih kosong (0)',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    searchQuery.isNotEmpty
                                        ? 'Coba kata kunci lain atau bersihkan pencarian.'
                                        : 'Tekan tombol "+ Tambah ${selectedTab == 'ku' ? 'KU' : 'Kategori'}" di atas untuk menambahkan aturan pertama.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: rules.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (ctx, idx) {
                              final rule = rules[idx];
                              final isKuRule = rule.type == 'ku';
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    // Kata Kunci (Pesan Keterangan)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFEF3C7),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                      color: const Color(
                                                          0xFFFDE68A)),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.key_rounded,
                                                        size: 11,
                                                        color:
                                                            Color(0xFFB45309)),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '"${rule.keyword}"',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Color(0xFF92400E),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 13,
                                                  color: Color(0xFF94A3B8)),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isKuRule
                                                        ? const Color(0xFFEFF6FF)
                                                        : const Color(0xFFEEF2FF),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                    border: Border.all(
                                                        color: isKuRule
                                                            ? const Color(0xFFBFDBFE)
                                                            : const Color(0xFFC7D2FE)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                          isKuRule
                                                              ? Icons.badge_outlined
                                                              : Icons.tag_rounded,
                                                          size: 11,
                                                          color: isKuRule
                                                              ? const Color(0xFF1D4ED8)
                                                              : const Color(0xFF4F46E5)),
                                                      const SizedBox(width: 3),
                                                      Flexible(
                                                        child: Text(
                                                          rule.kode,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: isKuRule
                                                                ? const Color(0xFF1E40AF)
                                                                : const Color(0xFF3730A3),
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    // Action Buttons: Edit & Delete
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 17, color: Color(0xFF6366F1)),
                                      tooltip: 'Edit Aturan',
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        _showFormKustomKodeDialog(
                                          rule,
                                          rule.type,
                                          () => setModalState(() {}),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 17,
                                          color: Color(0xFFE11D48)),
                                      tooltip: 'Hapus Aturan',
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        setState(() {
                                          _data.customKodeRules.removeWhere(
                                              (r) => r.id == rule.id);
                                        });
                                        _saveData();
                                        setModalState(() {});
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Aturan untuk "${rule.keyword}" berhasil dihapus'),
                                            behavior: SnackBarBehavior.floating,
                                            duration:
                                                const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- DIALOG FORM TAMBAH / EDIT KUSTOM ATURAN (KU / KATEGORI) ---
  void _showFormKustomKodeDialog(
    CustomKodeRule? existingRule,
    String targetType, // 'ku' atau 'kategori'
    VoidCallback onSaved,
  ) {
    final isEdit = existingRule != null;
    final type = existingRule != null ? existingRule.type : targetType;
    final isKu = type == 'ku';

    final keywordCtrl =
        TextEditingController(text: existingRule != null ? existingRule.keyword : '');
    final valueCtrl =
        TextEditingController(text: existingRule != null ? existingRule.kode : '');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isEdit ? Icons.edit_rounded : Icons.add_rounded,
                  color: const Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isEdit
                    ? 'Edit Aturan ${isKu ? "KU" : "Kategori"}'
                    : 'Tambah Aturan ${isKu ? "KU" : "Kategori"}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Kata Kunci Keterangan (Pemicu):',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: keywordCtrl,
                  decoration: InputDecoration(
                    hintText: isKu
                        ? 'Contoh: operasional, konsumsi, bensin'
                        : 'Contoh: konsumsi, bensin, sewa tempat',
                    hintStyle:
                        TextStyle(fontSize: 12, color: Colors.grey[400]),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    prefixIcon: const Icon(Icons.key_rounded,
                        size: 16, color: Color(0xFFB45309)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isKu
                      ? '2. Nilai KU yang Dihasilkan:'
                      : '2. Kategori yang Dihasilkan:',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: valueCtrl,
                  decoration: InputDecoration(
                    hintText: isKu
                        ? 'Contoh: KU 01, KU 02, KU 1'
                        : 'Contoh: Biaya Konsumsi Acara, Sewa Tempat, Biaya RTK',
                    hintStyle:
                        TextStyle(fontSize: 12, color: Colors.grey[400]),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    prefixIcon: Icon(
                        isKu ? Icons.badge_outlined : Icons.tag_rounded,
                        size: 16,
                        color: const Color(0xFF4F46E5)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '* Pencocokan tidak sensitif huruf besar/kecil (case-insensitive).',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final key = keywordCtrl.text.trim();
                final val = valueCtrl.text.trim();

                if (key.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Kata kunci pemicu wajib diisi!'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                if (val.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '⚠️ ${isKu ? "Nilai KU" : "Kategori"} wajib diisi!'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                setState(() {
                  if (isEdit) {
                    existingRule.keyword = key;
                    existingRule.kode = val;
                    existingRule.type = type;
                  } else {
                    _data.customKodeRules.add(
                      CustomKodeRule(keyword: key, kode: val, type: type),
                    );
                  }
                });

                _saveData();
                onSaved();
                Navigator.pop(dialogCtx);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEdit
                          ? 'Aturan "$key" -> "$val" berhasil diperbarui!'
                          : 'Aturan baru "$key" -> "$val" berhasil ditambahkan!',
                    ),
                    backgroundColor: const Color(0xFF059669),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(isEdit ? 'Simpan' : 'Tambah'),
            ),
          ],
        );
      },
    );
  }

  // --- DIALOG KONFIRMASI KOSONGKAN ATURAN (SESUAI TAB) ---
  void _confirmClearAllKodeRules(String tabType, VoidCallback onReset) {
    final isKu = tabType == 'ku';
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48)),
              const SizedBox(width: 8),
              Text(
                'Kosongkan Aturan ${isKu ? "KU" : "Kategori"}?',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Semua aturan ${isKu ? "KU" : "Kategori"} akan dihapus dan daftar menjadi kosong (0).',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _data.customKodeRules.removeWhere((r) =>
                      isKu ? r.type == 'ku' : r.type != 'ku');
                });
                _saveData();
                onReset();
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Semua aturan ${isKu ? "KU" : "Kategori"} berhasil dikosongkan!'),
                    backgroundColor: const Color(0xFF059669),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Kosongkan'),
            ),
          ],
        );
      },
    );
  }

  // --- MODAL / DIALOG IMPORT KONFIGURASI ATURAN DARI EXCEL & PASTE ---
  void _showImportKustomKodeDialog(
    String defaultTab,
    VoidCallback onImportSuccess,
  ) {
    int importMethod = 0; // 0 = File (.xlsx / .csv), 1 = Salin-Tempel (Paste)
    bool replaceAll = false; // false = Gabung (Merge), true = Timpa (Replace)
    String? pickedFileName;
    int? pickedFileSize;
    ImportResult? importResult;
    bool isLoading = false;
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (sbContext, setDialogState) {
            Future<void> handlePickFile() async {
              setDialogState(() => isLoading = true);
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['xlsx', 'xls', 'csv'],
                  withData: true,
                );

                if (result != null && result.files.isNotEmpty) {
                  final file = result.files.first;
                  pickedFileName = file.name;
                  pickedFileSize = file.size;

                  Uint8List? bytes = file.bytes;
                  if (bytes == null && !kIsWeb && file.path != null) {
                    try {
                      final ioFile = File(file.path!);
                      bytes = await ioFile.readAsBytes();
                    } catch (_) {}
                  }

                  if (bytes != null) {
                    final ext = file.extension?.toLowerCase() ??
                        (pickedFileName!.contains('.')
                            ? pickedFileName!.split('.').last.toLowerCase()
                            : '');
                    if (ext == 'csv') {
                      try {
                        final text = utf8.decode(bytes);
                        importResult = CustomRuleImportHelper.parseText(
                          text,
                          defaultType: defaultTab,
                        );
                      } catch (_) {
                        importResult =
                            CustomRuleImportHelper.parseExcelBytes(
                          bytes,
                          defaultType: defaultTab,
                        );
                      }
                    } else {
                      importResult =
                          CustomRuleImportHelper.parseExcelBytes(
                        bytes,
                        defaultType: defaultTab,
                      );
                    }
                  } else {
                    importResult = ImportResult.error(
                        'Tidak dapat membaca isi data file yang dipilih.');
                  }
                }
              } catch (e) {
                importResult = ImportResult.error('Gagal memilih file: $e');
              } finally {
                setDialogState(() => isLoading = false);
              }
            }

            void handleProcessText() {
              if (textCtrl.text.trim().isEmpty) {
                setDialogState(() {
                  importResult = ImportResult.error(
                      'Teks masih kosong. Silakan tempel data dari Excel.');
                });
                return;
              }
              setDialogState(() {
                importResult = CustomRuleImportHelper.parseText(
                  textCtrl.text,
                  defaultType: defaultTab,
                );
              });
            }

            Future<void> handlePasteClipboard() async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (!sbContext.mounted) return;
              if (data != null && data.text != null && data.text!.isNotEmpty) {
                textCtrl.text = data.text!;
                handleProcessText();
              } else {
                ScaffoldMessenger.of(sbContext).showSnackBar(
                  const SnackBar(
                    content: Text('Clipboard masih kosong atau tidak berisi teks.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }

            void handleUseSampleFormat() {
              textCtrl.text = CustomRuleImportHelper.getTemplateSampleText();
              handleProcessText();
            }

            final hasValidRules =
                importResult != null && importResult!.rules.isNotEmpty;

            return AlertDialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              contentPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.table_view_rounded,
                        color: Color(0xFF059669), size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import Konfigurasi Aturan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Masukkan aturan KU & Kategori sekaligus dari Excel',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF64748B), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(sbContext).size.width,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Toggle Pilihan Metode: File Excel vs Paste
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    importMethod = 0;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: importMethod == 0
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: importMethod == 0
                                        ? [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.05),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.file_present_rounded,
                                        size: 15,
                                        color: importMethod == 0
                                            ? const Color(0xFF059669)
                                            : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'File (.xlsx / .csv)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: importMethod == 0
                                                ? const Color(0xFF059669)
                                                : const Color(0xFF64748B),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    importMethod = 1;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: importMethod == 1
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: importMethod == 1
                                        ? [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.05),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.content_paste_rounded,
                                        size: 15,
                                        color: importMethod == 1
                                            ? const Color(0xFF059669)
                                            : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Salin-Tempel (Paste)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: importMethod == 1
                                                ? const Color(0xFF059669)
                                                : const Color(0xFF64748B),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Body Berdasarkan Tab Pilihan
                      if (importMethod == 0) ...[
                        // METODE FILE
                        InkWell(
                          onTap: isLoading ? null : handlePickFile,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.5),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              children: [
                                if (isLoading) ...[
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Membaca file Excel...',
                                    style: TextStyle(
                                        fontSize: 12, color: Color(0xFF065F46)),
                                  ),
                                ] else if (pickedFileName != null) ...[
                                  const Icon(Icons.check_circle_rounded,
                                      size: 28, color: Color(0xFF059669)),
                                  const SizedBox(height: 4),
                                  Text(
                                    pickedFileName!,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF065F46),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (pickedFileSize != null)
                                    Text(
                                      'Ukuran: ${(pickedFileSize! / 1024).toStringAsFixed(1)} KB • Klik untuk ganti file',
                                      style: const TextStyle(
                                          fontSize: 10.5,
                                          color: Color(0xFF047857)),
                                    ),
                                ] else ...[
                                  const Icon(Icons.file_download_outlined,
                                      size: 32, color: Color(0xFF059669)),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Pilih File Excel (.xlsx / .xls / .csv)',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Klik di sini untuk membuka file dari perangkat',
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF047857)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // METODE PASTE TEXT
                        // Format Panduan Ringkas (Hanya Tampil di Opsi Salin-Tempel/Paste)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      size: 14, color: Color(0xFF6366F1)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Format Kolom yang Dibutuhkan:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFCBD5E1)),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: const Text(
                                    'Jenis Aturan  |  Keterangan Pemicu  |  Hasil\n'
                                    'KU            |  rapat              |  Sekretaris\n'
                                    'KU            |  pengabaran         |  Publikasi\n'
                                    'Kategori      |  Konsumsi           |  Konsumsi',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      color: Color(0xFF334155),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextField(
                          controller: textCtrl,
                          maxLines: 4,
                          style: const TextStyle(
                              fontSize: 11, fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            hintText:
                                'Tempel baris tabel dari Excel di sini...',
                            hintStyle: const TextStyle(
                                fontSize: 11, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.all(10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                          ),
                          onChanged: (_) => handleProcessText(),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: handlePasteClipboard,
                              icon: const Icon(Icons.paste_rounded,
                                  size: 13, color: Color(0xFF059669)),
                              label: const Text(
                                'Tempel Clipboard',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF059669)),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: handleUseSampleFormat,
                              icon: const Icon(Icons.format_quote_rounded,
                                  size: 13, color: Color(0xFF6366F1)),
                              label: const Text(
                                'Gunakan Contoh Format',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6366F1)),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),

                      // Hasil Pratinjau / Error Box
                      if (importResult != null) ...[
                        if (importResult!.isSuccess) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        size: 15, color: Color(0xFF059669)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Berhasil Membaca ${importResult!.rules.length} Aturan:',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${importResult!.kuCount} KU • ${importResult!.kategoriCount} Kategori',
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  constraints:
                                      const BoxConstraints(maxHeight: 90),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: importResult!.rules.length > 5
                                        ? 5
                                        : importResult!.rules.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 6, thickness: 0.5),
                                    itemBuilder: (ctx, idx) {
                                      final r = importResult!.rules[idx];
                                      final isKu = r.type == 'ku';
                                      return Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: isKu
                                                  ? const Color(0xFFEFF6FF)
                                                  : const Color(0xFFEEF2FF),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isKu ? 'KU' : 'Kategori',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: isKu
                                                    ? const Color(0xFF1D4ED8)
                                                    : const Color(0xFF4F46E5),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '"${r.keyword}" ➔ "${r.kode}"',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                color: Color(0xFF334155),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                if (importResult!.rules.length > 5)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '... dan ${importResult!.rules.length - 5} aturan lainnya.',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 15, color: Color(0xFFDC2626)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    importResult!.errorMessage ??
                                        'Format data tidak sesuai.',
                                    style: const TextStyle(
                                        fontSize: 11, color: Color(0xFF991B1B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                      ],

                      // Pilihan Mode Simpan (Gabungkan vs Timpa)
                      const Text(
                        'Pilih Mode Penyimpanan:',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() => replaceAll = false);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                decoration: BoxDecoration(
                                  color: !replaceAll
                                      ? const Color(0xFFEFF6FF)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: !replaceAll
                                        ? const Color(0xFF3B82F6)
                                        : const Color(0xFFE2E8F0),
                                    width: !replaceAll ? 1.2 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          !replaceAll
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          size: 13,
                                          color: !replaceAll
                                              ? const Color(0xFF2563EB)
                                              : const Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Gabungkan',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Pertahankan aturan lama & tambah baru',
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          color: Color(0xFF64748B),
                                          height: 1.2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() => replaceAll = true);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                decoration: BoxDecoration(
                                  color: replaceAll
                                      ? const Color(0xFFFEF2F2)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: replaceAll
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFFE2E8F0),
                                    width: replaceAll ? 1.2 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          replaceAll
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          size: 13,
                                          color: replaceAll
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Timpa Semua',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Ganti semua aturan dengan data ini',
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          color: Color(0xFF64748B),
                                          height: 1.2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: hasValidRules
                      ? () {
                          final updated = CustomRuleImportHelper.applyImport(
                            currentRules: _data.customKodeRules,
                            importedRules: importResult!.rules,
                            replaceAll: replaceAll,
                          );

                          setState(() {
                            _data.customKodeRules = updated;
                          });

                          _saveData();
                          onImportSuccess();
                          Navigator.pop(dialogCtx);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                replaceAll
                                    ? '✅ Berhasil menimpa seluruh aturan dengan ${importResult!.rules.length} aturan baru!'
                                    : '✅ Berhasil mengimpor & menggabungkan ${importResult!.rules.length} aturan (${importResult!.kuCount} KU, ${importResult!.kategoriCount} Kategori)!',
                              ),
                              backgroundColor: const Color(0xFF059669),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[500],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    hasValidRules
                        ? 'Simpan (${importResult!.rules.length} Aturan)'
                        : 'Simpan',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- MODAL EDIT REKENING STRUKTUR ---
  void _showEditRekeningStrukturModal() {
    String selectedBank = _data.rekeningStruktur.bankName;
    final saldoCtrl = TextEditingController(
        text: RupiahFormatter.format(_data.rekeningStruktur.balance));
    final noRekCtrl =
        TextEditingController(text: _data.rekeningStruktur.accountNumber);
    final holderCtrl =
        TextEditingController(text: _data.rekeningStruktur.accountHolder);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Icon(Icons.account_balance_rounded,
                            color: primaryPurple),
                        SizedBox(width: 8),
                        Text(
                          'Pengaturan Rekening Struktur',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Pilih Bank
                    const Text('Pilih Bank / Jenis Rekening:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _bankList.contains(selectedBank)
                              ? selectedBank
                              : 'Lainnya',
                          items: _bankList.map((b) {
                            return DropdownMenuItem(
                              value: b,
                              child: Row(
                                children: [
                                  const Icon(Icons.account_balance_wallet_outlined,
                                      size: 18, color: primaryPurple),
                                  const SizedBox(width: 8),
                                  Text(b,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedBank = val);
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Saldo Rekening
                    const Text('Saldo Rekening Struktur (Rp):',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: saldoCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        RupiahInputFormatter(),
                      ],
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryPurple),
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryPurple),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // No Rekening & Pemilik
                    const Text('Nomor Rekening & Nama Pemilik (Opsional):',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noRekCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Nomor Rekening (contoh: 1234567890)',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: holderCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'Atas Nama (contoh: Bendahara Struktur)',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Simpan Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          final saldoClean =
                              saldoCtrl.text.replaceAll('.', '').trim();
                          final newSaldo = int.tryParse(saldoClean) ?? 0;

                          setState(() {
                            _data.rekeningStruktur.bankName = selectedBank;
                            _data.rekeningStruktur.balance = newSaldo;
                            _data.rekeningStruktur.accountNumber =
                                noRekCtrl.text.trim();
                            _data.rekeningStruktur.accountHolder =
                                holderCtrl.text.trim();
                          });
                          _saveData();
                          Navigator.pop(ctx);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Rekening Struktur berhasil diperbarui!'),
                              backgroundColor: primaryPurple,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Simpan Rekening',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- MODAL EDIT AKUN ON HAND DEBIT (INFO REKENING) ---
  void _showEditOnHandModal() {
    String selectedBank = _data.onHandDebit.bankName;
    final noRekCtrl =
        TextEditingController(text: _data.onHandDebit.accountNumber);
    final holderCtrl =
        TextEditingController(text: _data.onHandDebit.accountHolder);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Icon(Icons.wallet_rounded, color: primaryTeal),
                        SizedBox(width: 8),
                        Text(
                          'Pengaturan Akun On Hand Debit',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ubah data rekening On Hand Debit. Untuk perputaran saldo, gunakan tombol Alokasi Dana.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),

                    // 1. Pilih Bank / Jenis Rekening
                    const Text('Jenis Rekening / Bank On Hand Debit:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _bankList.contains(selectedBank)
                              ? selectedBank
                              : 'Lainnya',
                          items: _bankList.map((b) {
                            return DropdownMenuItem(
                              value: b,
                              child: Row(
                                children: [
                                  const Icon(Icons.credit_card_rounded,
                                      size: 18, color: primaryTeal),
                                  const SizedBox(width: 8),
                                  Text(b,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedBank = val);
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 2. Nomor Rekening Debit
                    const Text('Nomor Rekening On Hand Debit:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noRekCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Contoh: 0812345678 / 1234567890',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 3. Nama Pemilik Rekening / PIC
                    const Text('Nama Pemilik Rekening / Atas Nama:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: holderCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'Contoh: PIC Lapangan / Nama Pemilik',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Simpan Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _data.onHandDebit.bankName = selectedBank;
                            _data.onHandDebit.accountNumber =
                                noRekCtrl.text.trim();
                            _data.onHandDebit.accountHolder =
                                holderCtrl.text.trim();
                          });
                          _saveData();
                          Navigator.pop(ctx);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Data Akun On Hand Debit berhasil diperbarui!'),
                              backgroundColor: primaryTeal,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Simpan Pengaturan Akun',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- MODAL CATAT PEMASUKAN DANA ---
  void _showPemasukanDanaModal() {
    DateTime selectedDate = DateTime.now();
    if (_selectedMonth.year != DateTime.now().year ||
        _selectedMonth.month != DateTime.now().month) {
      selectedDate =
          DateTime(_selectedMonth.year, _selectedMonth.month, 1, 12, 0);
    }

    String targetWadah = 'rekening'; // 'rekening', 'debit', 'cash'
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final amountKey = GlobalKey();
    final noteKey = GlobalKey();
    final amountFocus = FocusNode();
    final noteFocus = FocusNode();

    bool amountHasError = false;
    bool noteHasError = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final cleanText = amountCtrl.text.replaceAll('.', '').trim();
            final nominal = int.tryParse(cleanText) ?? 0;

            String wadahName = '';
            Color wadahColor = primaryPurple;
            int currentWadahBalance = 0;
            if (targetWadah == 'rekening') {
              wadahName =
                  'Rekening Struktur (${_data.rekeningStruktur.bankName})';
              wadahColor = primaryPurple;
              currentWadahBalance = _data.rekeningStruktur.balance;
            } else if (targetWadah == 'debit') {
              wadahName = 'On Hand Debit (${_data.onHandDebit.bankName})';
              wadahColor = primaryTeal;
              currentWadahBalance = _data.onHandDebit.balance;
            } else {
              wadahName = 'On Hand Cash (Tunai)';
              wadahColor = const Color(0xFF059669);
              currentWadahBalance = _data.onHandCash.balance;
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.92,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Header Modal
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF059669).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_downward_rounded,
                              color: Color(0xFF059669), size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Catat Pemasukan Dana',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Tambah dana masuk ke struktur dari pihak luar / kas',
                                style: TextStyle(
                                    fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 1. Tanggal Pemasukan (Auto get hari ini + picker)
                    const Text('1. Tanggal Pemasukan:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setModalState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 16, color: Color(0xFF059669)),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat('d MMM yyyy')
                                      .format(selectedDate),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Ubah',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 2. Wadah Dana (Tujuan Penerimaan)
                    const Text('2. Wadah Dana (Masuk Ke):',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildAccountSelectorCard(
                          title: 'Rekening',
                          subtitle: _data.rekeningStruktur.bankName,
                          balance: _data.rekeningStruktur.balance,
                          icon: Icons.account_balance_rounded,
                          isSelected: targetWadah == 'rekening',
                          activeColor: primaryPurple,
                          onTap: () {
                            setModalState(() => targetWadah = 'rekening');
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildAccountSelectorCard(
                          title: 'Debit',
                          subtitle: _data.onHandDebit.bankName,
                          balance: _data.onHandDebit.balance,
                          icon: Icons.credit_card_rounded,
                          isSelected: targetWadah == 'debit',
                          activeColor: primaryTeal,
                          onTap: () {
                            setModalState(() => targetWadah = 'debit');
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildAccountSelectorCard(
                          title: 'Cash',
                          subtitle: 'Tunai',
                          balance: _data.onHandCash.balance,
                          icon: Icons.payments_rounded,
                          isSelected: targetWadah == 'cash',
                          activeColor: const Color(0xFF059669),
                          onTap: () {
                            setModalState(() => targetWadah = 'cash');
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 3. Jumlah Dana (Nominal Rp)
                    const Text('3. Jumlah Dana (Rp):',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    Container(
                      key: amountKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: amountCtrl,
                            focusNode: amountFocus,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              RupiahInputFormatter(),
                            ],
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669)),
                            decoration: InputDecoration(
                              prefixText: 'Rp ',
                              prefixStyle: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF059669)),
                              hintText: '0',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: amountHasError
                                      ? Colors.redAccent
                                      : const Color(0xFFE2E8F0),
                                  width: amountHasError ? 1.6 : 1.0,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: amountHasError
                                      ? Colors.redAccent
                                      : const Color(0xFFE2E8F0),
                                  width: amountHasError ? 1.6 : 1.0,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: amountHasError
                                      ? Colors.redAccent
                                      : const Color(0xFF059669),
                                  width: 1.8,
                                ),
                              ),
                            ),
                            onChanged: (val) {
                              if (amountHasError && nominal > 0) {
                                amountHasError = false;
                              }
                              setModalState(() {});
                            },
                          ),
                          if (amountHasError)
                            const Padding(
                              padding: EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                '⚠️ Jumlah dana harus lebih dari 0',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 4. Keterangan / Catatan (Wajib)
                    const Text('4. Keterangan Keperluan / Sumber (Wajib):',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    Container(
                      key: noteKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: noteCtrl,
                            focusNode: noteFocus,
                            decoration: InputDecoration(
                              hintText:
                                  'Contoh: DP KK Barqi, Donasi Hamba Allah, Kas Masuk',
                              hintStyle: const TextStyle(fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: noteHasError
                                      ? Colors.redAccent
                                      : const Color(0xFFE2E8F0),
                                  width: noteHasError ? 1.6 : 1.0,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: noteHasError
                                      ? Colors.redAccent
                                      : const Color(0xFFE2E8F0),
                                  width: noteHasError ? 1.6 : 1.0,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: noteHasError
                                      ? Colors.redAccent
                                      : const Color(0xFF059669),
                                  width: 1.8,
                                ),
                              ),
                            ),
                            onChanged: (val) {
                              if (noteHasError && val.trim().isNotEmpty) {
                                noteHasError = false;
                              }
                              setModalState(() {});
                            },
                          ),
                          if (noteHasError)
                            const Padding(
                              padding: EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                '⚠️ Keterangan pemasukan wajib diisi',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (nominal > 0) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF059669)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Saldo Baru $wadahName:',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B))),
                            Text(
                              'Rp ${RupiahFormatter.format(currentWadahBalance + nominal)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: wadahColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Tombol Simpan Pemasukan
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          if (nominal <= 0) {
                            setModalState(() => amountHasError = true);
                            if (amountKey.currentContext != null) {
                              Scrollable.ensureVisible(
                                amountKey.currentContext!,
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOut,
                                alignment: 0.3,
                              );
                            }
                            amountFocus.requestFocus();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('⚠️ Silakan masukkan Jumlah Dana (Rp)!'),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          if (noteCtrl.text.trim().isEmpty) {
                            setModalState(() => noteHasError = true);
                            if (noteKey.currentContext != null) {
                              Scrollable.ensureVisible(
                                noteKey.currentContext!,
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOut,
                                alignment: 0.3,
                              );
                            }
                            noteFocus.requestFocus();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('⚠️ Keterangan pemasukan wajib diisi!'),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          final noteText = noteCtrl.text.trim();
                          final autoKu =
                              StrukturTransaction.resolveKuFromText(
                                  noteText,
                                  customRules: _data.customKodeRules);
                          final autoKode =
                              StrukturTransaction.resolveKodeFromText(
                                  noteText,
                                  customRules: _data.customKodeRules);

                          final newTx = StrukturTransaction(
                            id: DateTime.now()
                                .microsecondsSinceEpoch
                                .toString(),
                            title: noteText,
                            type: 'pemasukan',
                            targetAccount: targetWadah,
                            amount: nominal,
                            adminFee: 0,
                            note: noteText,
                            ku: autoKu != '-' ? autoKu : null,
                            kode: autoKode != '-' ? autoKode : null,
                            timestamp: selectedDate,
                          );

                          setState(() {
                            // 1. Tambah Saldo Wadah
                            if (targetWadah == 'rekening') {
                              _data.rekeningStruktur.balance += nominal;
                            } else if (targetWadah == 'debit') {
                              _data.onHandDebit.balance += nominal;
                            } else {
                              _data.onHandCash.balance += nominal;
                            }

                            // 2. Catat Transaksi (Tambahkan dan urutkan chronological berdasarkan tanggal)
                            _data.transactions.add(newTx);
                            _data.transactions.sort((a, b) => a.timestamp.compareTo(b.timestamp));
                          });

                          _saveData();
                          _triggerAutoSyncSheets();
                          Navigator.pop(ctx);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Pemasukan Rp ${RupiahFormatter.format(nominal)} berhasil dicatat!',
                              ),
                              backgroundColor: const Color(0xFF059669),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Simpan Pemasukan',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- MODAL CATAT PENGELUARAN DANA ---
  void _showPengeluaranDanaModal({String initialSource = 'rekening'}) {
    DateTime selectedDate = DateTime.now();
    if (_selectedMonth.year != DateTime.now().year ||
        _selectedMonth.month != DateTime.now().month) {
      selectedDate =
          DateTime(_selectedMonth.year, _selectedMonth.month, 1, 12, 0);
    }

    String sourceAccount = initialSource; // 'rekening', 'debit', 'cash'
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final amountKey = GlobalKey();
    final noteKey = GlobalKey();
    final amountFocus = FocusNode();
    final noteFocus = FocusNode();

    bool amountHasError = false;
    bool noteHasError = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final cleanText = amountCtrl.text.replaceAll('.', '').trim();
            final nominal = int.tryParse(cleanText) ?? 0;

            int sourceBalance = 0;
            String sourceName = '';
            Color sourceColor = primaryPurple;

            if (sourceAccount == 'rekening') {
              sourceBalance = _data.rekeningStruktur.balance;
              sourceName =
                  'Rekening Struktur (${_data.rekeningStruktur.bankName})';
              sourceColor = primaryPurple;
            } else if (sourceAccount == 'debit') {
              sourceBalance = _data.onHandDebit.balance;
              sourceName = 'On Hand Debit (${_data.onHandDebit.bankName})';
              sourceColor = primaryTeal;
            } else {
              sourceBalance = _data.onHandCash.balance;
              sourceName = 'On Hand Cash (Tunai)';
              sourceColor = const Color(0xFF059669);
            }

            final isSaldoCukup = sourceBalance >= nominal && nominal > 0;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.92,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Header Modal
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFE11D48).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_upward_rounded,
                              color: Color(0xFFE11D48), size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Catat Pengeluaran Dana',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Catat pengeluaran operasional / belanja dari dana struktur',
                                style: TextStyle(
                                    fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 1. Tanggal Pengeluaran (Auto get hari ini + picker)
                    const Text('1. Tanggal Pengeluaran:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setModalState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 16, color: Color(0xFFE11D48)),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat('d MMM yyyy')
                                      .format(selectedDate),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Ubah',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE11D48),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 2. Sumber Dana (Asal Pengeluaran)
                    const Text('2. Sumber Dana (Dipotong Dari):',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildAccountSelectorCard(
                          title: 'Rekening',
                          subtitle: _data.rekeningStruktur.bankName,
                          balance: _data.rekeningStruktur.balance,
                          icon: Icons.account_balance_rounded,
                          isSelected: sourceAccount == 'rekening',
                          activeColor: primaryPurple,
                          onTap: () {
                            setModalState(() => sourceAccount = 'rekening');
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildAccountSelectorCard(
                          title: 'Debit',
                          subtitle: _data.onHandDebit.bankName,
                          balance: _data.onHandDebit.balance,
                          icon: Icons.credit_card_rounded,
                          isSelected: sourceAccount == 'debit',
                          activeColor: primaryTeal,
                          onTap: () {
                            setModalState(() => sourceAccount = 'debit');
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildAccountSelectorCard(
                          title: 'Cash',
                          subtitle: 'Tunai',
                          balance: _data.onHandCash.balance,
                          icon: Icons.payments_rounded,
                          isSelected: sourceAccount == 'cash',
                          activeColor: const Color(0xFF059669),
                          onTap: () {
                            setModalState(() => sourceAccount = 'cash');
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 3. Jumlah Dana (Nominal Rp)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('3. Jumlah Pengeluaran (Rp):',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155))),
                        InkWell(
                          onTap: () {
                            amountCtrl.text =
                                RupiahFormatter.format(sourceBalance);
                            if (amountHasError && sourceBalance > 0) {
                              amountHasError = false;
                            }
                            setModalState(() {});
                          },
                          child: const Text(
                            'Semua Saldo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE11D48),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      key: amountKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: amountCtrl,
                            focusNode: amountFocus,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              RupiahInputFormatter(),
                            ],
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE11D48)),
                            decoration: InputDecoration(
                              prefixText: 'Rp ',
                              prefixStyle: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE11D48)),
                              hintText: '0',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: amountHasError
                                      ? Colors.redAccent
                                      : const Color(0xFFE2E8F0),
                                  width: amountHasError ? 1.6 : 1.0,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: amountHasError
                                      ? Colors.redAccent
                                      : const Color(0xFFE2E8F0),
                                  width: amountHasError ? 1.6 : 1.0,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: amountHasError
                                      ? Colors.redAccent
                                      : const Color(0xFFE11D48),
                                  width: 1.8,
                                ),
                              ),
                            ),
                            onChanged: (val) {
                              if (amountHasError && nominal > 0 && isSaldoCukup) {
                                amountHasError = false;
                              }
                              setModalState(() {});
                            },
                          ),
                          if (amountHasError)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                nominal <= 0
                                    ? '⚠️ Jumlah pengeluaran harus lebih dari 0'
                                    : '⚠️ Saldo $sourceName tidak mencukupi (Saldo: Rp ${RupiahFormatter.format(sourceBalance)})',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (!isSaldoCukup && nominal > 0 && !amountHasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '⚠️ Saldo $sourceName tidak mencukupi (Saldo: Rp ${RupiahFormatter.format(sourceBalance)}).',
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold),
                        ),
                      ),

                    const SizedBox(height: 14),

                    // 4. Keterangan (Wajib)
                    const Text('4. Keterangan Keperluan (Wajib):',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    Container(
                      key: noteKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: noteCtrl,
                            focusNode: noteFocus,
                            decoration: InputDecoration(
                              hintText:
                                  'Contoh: konsumsi pembinaan AB Afwan, Sewa ruangan pembinaan AB Afwan',
                              hintStyle: const TextStyle(fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: noteHasError
                                      ? Colors.redAccent
                                      : const Color(0xFFE2E8F0),
                                  width: noteHasError ? 1.6 : 1.0,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: noteHasError
                                      ? Colors.redAccent
                                      : const Color(0xFFE2E8F0),
                                  width: noteHasError ? 1.6 : 1.0,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: noteHasError
                                      ? Colors.redAccent
                                      : const Color(0xFFE11D48),
                                  width: 1.8,
                                ),
                              ),
                            ),
                            onChanged: (val) {
                              if (noteHasError && val.trim().isNotEmpty) {
                                noteHasError = false;
                              }
                              setModalState(() {});
                            },
                          ),
                          if (noteHasError)
                            const Padding(
                              padding: EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                '⚠️ Keterangan keperluan wajib diisi',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (nominal > 0 && isSaldoCukup) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFE11D48)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Sisa Saldo Akun:',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B))),
                            Text(
                              'Rp ${RupiahFormatter.format(sourceBalance - nominal)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: sourceColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Tombol Simpan Pengeluaran
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          if (nominal <= 0) {
                            setModalState(() => amountHasError = true);
                            if (amountKey.currentContext != null) {
                              Scrollable.ensureVisible(
                                amountKey.currentContext!,
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOut,
                                alignment: 0.3,
                              );
                            }
                            amountFocus.requestFocus();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('⚠️ Silakan masukkan Jumlah Pengeluaran (Rp)!'),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          if (!isSaldoCukup) {
                            setModalState(() => amountHasError = true);
                            if (amountKey.currentContext != null) {
                              Scrollable.ensureVisible(
                                amountKey.currentContext!,
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOut,
                                alignment: 0.3,
                              );
                            }
                            amountFocus.requestFocus();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('⚠️ Saldo $sourceName tidak mencukupi! (Saldo: Rp ${RupiahFormatter.format(sourceBalance)})'),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          if (noteCtrl.text.trim().isEmpty) {
                            setModalState(() => noteHasError = true);
                            if (noteKey.currentContext != null) {
                              Scrollable.ensureVisible(
                                noteKey.currentContext!,
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOut,
                                alignment: 0.3,
                              );
                            }
                            noteFocus.requestFocus();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('⚠️ Keterangan Keperluan wajib diisi!'),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          final keterangan = noteCtrl.text.trim();
                          final autoKu =
                              StrukturTransaction.resolveKuFromText(
                                  keterangan,
                                  customRules: _data.customKodeRules);
                          final autoKode =
                              StrukturTransaction.resolveKodeFromText(
                                  keterangan,
                                  customRules: _data.customKodeRules);

                          final newTx = StrukturTransaction(
                            id: DateTime.now()
                                .microsecondsSinceEpoch
                                .toString(),
                            title: keterangan,
                            type: 'pengeluaran',
                            sourceAccount: sourceAccount,
                            amount: nominal,
                            adminFee: 0,
                            note: keterangan,
                            ku: autoKu != '-' ? autoKu : null,
                            kode: autoKode != '-' ? autoKode : null,
                            timestamp: selectedDate,
                          );

                          setState(() {
                            // 1. Kurangi Saldo Sumber
                            if (sourceAccount == 'rekening') {
                              _data.rekeningStruktur.balance -= nominal;
                            } else if (sourceAccount == 'debit') {
                              _data.onHandDebit.balance -= nominal;
                            } else {
                              _data.onHandCash.balance -= nominal;
                            }

                            // 2. Catat Transaksi (Tambahkan dan urutkan chronological berdasarkan tanggal)
                            _data.transactions.add(newTx);
                            _data.transactions.sort((a, b) => a.timestamp.compareTo(b.timestamp));
                          });

                          _saveData();
                          _triggerAutoSyncSheets();
                          Navigator.pop(ctx);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Pengeluaran Rp ${RupiahFormatter.format(nominal)} berhasil dicatat!',
                              ),
                              backgroundColor: const Color(0xFFE11D48),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Simpan Pengeluaran',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- MODAL ALOKASI DANA TERPADU (PERPUTARAN INTERNAL MULTI-ARAH) ---
  void _showDistribusiDanaModal({
    String initialSource = 'rekening',
    String? initialTarget,
  }) {
    DateTime selectedDate = DateTime.now();
    if (_selectedMonth.year != DateTime.now().year ||
        _selectedMonth.month != DateTime.now().month) {
      selectedDate =
          DateTime(_selectedMonth.year, _selectedMonth.month, 1, 12, 0);
    }

    String sourceAccount = initialSource; // 'rekening', 'debit', 'cash'

    // Determine initial target
    String targetAccount;
    if (initialTarget != null && initialTarget != sourceAccount) {
      targetAccount = initialTarget;
    } else {
      if (sourceAccount == 'rekening') {
        targetAccount = 'debit';
      } else if (sourceAccount == 'debit') {
        targetAccount = 'rekening';
      } else {
        targetAccount = 'rekening';
      }
    }

    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final amountKey = GlobalKey();
    final amountFocus = FocusNode();

    bool amountHasError = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final cleanText = amountCtrl.text.replaceAll('.', '').trim();
            final nominal = int.tryParse(cleanText) ?? 0;

            // List of target options based on source
            final List<String> availableTargets = ['rekening', 'debit', 'cash']
                .where((acc) => acc != sourceAccount)
                .toList();

            if (!availableTargets.contains(targetAccount)) {
              targetAccount = availableTargets.first;
            }

            // Sumber Saldo
            int sourceBalance = 0;
            String sourceName = '';
            Color sourceColor = primaryPurple;

            if (sourceAccount == 'rekening') {
              sourceBalance = _data.rekeningStruktur.balance;
              sourceName = 'Rekening Struktur';
              sourceColor = primaryPurple;
            } else if (sourceAccount == 'debit') {
              sourceBalance = _data.onHandDebit.balance;
              sourceName = 'On Hand Debit';
              sourceColor = primaryTeal;
            } else {
              sourceBalance = _data.onHandCash.balance;
              sourceName = 'On Hand Cash';
              sourceColor = const Color(0xFF059669);
            }

            // Target Info
            String targetName = '';
            Color targetColor = primaryPurple;

            if (targetAccount == 'rekening') {
              targetName = 'Rekening Struktur';
              targetColor = primaryPurple;
            } else if (targetAccount == 'debit') {
              targetName = 'On Hand Debit';
              targetColor = primaryTeal;
            } else {
              targetName = 'On Hand Cash';
              targetColor = const Color(0xFF059669);
            }

            // Hitung Biaya Admin:
            final isInterBankTransfer = (sourceAccount == 'rekening' &&
                    targetAccount == 'debit') ||
                (sourceAccount == 'debit' && targetAccount == 'rekening');

            final isBankSama = _data.rekeningStruktur.bankName.trim().toUpperCase() ==
                _data.onHandDebit.bankName.trim().toUpperCase();

            final adminFee = isInterBankTransfer && !isBankSama && nominal > 0 ? 2500 : 0;
            final totalPotongan = nominal + adminFee;
            final isSaldoCukup = sourceBalance >= totalPotongan && nominal > 0;

            // Label Aliran Dana
            String flowLabel = '';

            if (sourceAccount == 'rekening' && targetAccount == 'debit') {
              flowLabel = 'Transfer Bank / Top-Up Debit';
            } else if (sourceAccount == 'rekening' && targetAccount == 'cash') {
              flowLabel = 'Tarik Tunai dari Rekening';
            } else if (sourceAccount == 'debit' &&
                targetAccount == 'rekening') {
              flowLabel = 'Transfer Debit ke Rekening';
            } else if (sourceAccount == 'debit' && targetAccount == 'cash') {
              flowLabel = 'Tarik Tunai via ATM Debit';
            } else if (sourceAccount == 'cash' &&
                targetAccount == 'rekening') {
              flowLabel = 'Setor Tunai ke Rekening';
            } else if (sourceAccount == 'cash' && targetAccount == 'debit') {
              flowLabel = 'Setor Tunai / Top-up Debit';
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.92,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Header Modal
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryPurple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.sync_alt_rounded,
                              color: primaryPurple, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alokasi Antar-Wadah',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Pindahkan dana antar rekening, debit, dan cash',
                                style: TextStyle(
                                    fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 1. Tanggal Alokasi
                    const Text('1. Tanggal Transaksi:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setModalState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 16, color: primaryPurple),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat('d MMM yyyy')
                                      .format(selectedDate),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Ubah',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 2. Pilih Sumber Dana (Dari Mana)
                    const Text('2. Sumber Dana (Asal):',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildAccountSelectorCard(
                          title: 'Rekening',
                          subtitle: _data.rekeningStruktur.bankName,
                          balance: _data.rekeningStruktur.balance,
                          icon: Icons.account_balance_rounded,
                          isSelected: sourceAccount == 'rekening',
                          activeColor: primaryPurple,
                          onTap: () {
                            setModalState(() {
                              sourceAccount = 'rekening';
                              if (targetAccount == 'rekening') {
                                targetAccount = 'debit';
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildAccountSelectorCard(
                          title: 'Debit',
                          subtitle: _data.onHandDebit.bankName,
                          balance: _data.onHandDebit.balance,
                          icon: Icons.credit_card_rounded,
                          isSelected: sourceAccount == 'debit',
                          activeColor: primaryTeal,
                          onTap: () {
                            setModalState(() {
                              sourceAccount = 'debit';
                              if (targetAccount == 'debit') {
                                targetAccount = 'rekening';
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildAccountSelectorCard(
                          title: 'Cash',
                          subtitle: 'Tunai',
                          balance: _data.onHandCash.balance,
                          icon: Icons.payments_rounded,
                          isSelected: sourceAccount == 'cash',
                          activeColor: const Color(0xFF059669),
                          onTap: () {
                            setModalState(() {
                              sourceAccount = 'cash';
                              if (targetAccount == 'cash') {
                                targetAccount = 'rekening';
                              }
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 3. Pilih Tujuan Dana (Kemana)
                    const Text('3. Tujuan Dana:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (int i = 0; i < availableTargets.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          () {
                            final targetKey = availableTargets[i];
                            String tTitle = '';
                            String tSub = '';
                            int tBal = 0;
                            IconData tIcon = Icons.account_balance_rounded;
                            Color tColor = primaryPurple;

                            if (targetKey == 'rekening') {
                              tTitle = 'Rekening';
                              tSub = _data.rekeningStruktur.bankName;
                              tBal = _data.rekeningStruktur.balance;
                              tIcon = Icons.account_balance_rounded;
                              tColor = primaryPurple;
                            } else if (targetKey == 'debit') {
                              tTitle = 'Debit';
                              tSub = _data.onHandDebit.bankName;
                              tBal = _data.onHandDebit.balance;
                              tIcon = Icons.credit_card_rounded;
                              tColor = primaryTeal;
                            } else {
                              tTitle = 'Cash';
                              tSub = 'Tunai';
                              tBal = _data.onHandCash.balance;
                              tIcon = Icons.payments_rounded;
                              tColor = const Color(0xFF059669);
                            }

                            return _buildAccountSelectorCard(
                              title: tTitle,
                              subtitle: tSub,
                              balance: tBal,
                              icon: tIcon,
                              isSelected: targetAccount == targetKey,
                              activeColor: tColor,
                              onTap: () {
                                setModalState(() => targetAccount = targetKey);
                              },
                            );
                          }(),
                        ],
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Direction Banner Info
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.alt_route_rounded,
                              size: 16, color: Colors.blueGrey[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              flowLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 4. Input Nominal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('4. Nominal Alokasi (Rp):',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155))),
                        InkWell(
                          onTap: () {
                            final maxNominal = sourceBalance > adminFee
                                ? (sourceBalance - adminFee)
                                : 0;
                            amountCtrl.text =
                                RupiahFormatter.format(maxNominal);
                            if (amountHasError && maxNominal > 0) {
                              amountHasError = false;
                            }
                            setModalState(() {});
                          },
                          child: const Text(
                            'Semua Saldo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primaryPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      key: amountKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: amountCtrl,
                            focusNode: amountFocus,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              RupiahInputFormatter(),
                            ],
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              prefixText: 'Rp ',
                              hintText: '0',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: amountHasError
                                      ? Colors.redAccent
                                      : const Color(0xFFE2E8F0),
                                  width: amountHasError ? 1.6 : 1.0,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: amountHasError
                                      ? Colors.redAccent
                                      : const Color(0xFFE2E8F0),
                                  width: amountHasError ? 1.6 : 1.0,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: amountHasError
                                      ? Colors.redAccent
                                      : primaryPurple,
                                  width: 1.8,
                                ),
                              ),
                            ),
                            onChanged: (val) {
                              if (amountHasError && nominal > 0 && isSaldoCukup) {
                                amountHasError = false;
                              }
                              setModalState(() {});
                            },
                          ),
                          if (amountHasError)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                nominal <= 0
                                    ? '⚠️ Nominal alokasi harus lebih dari 0'
                                    : '⚠️ Saldo $sourceName tidak mencukupi (Saldo: Rp ${RupiahFormatter.format(sourceBalance)})',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Quick Chips
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        50000,
                        100000,
                        250000,
                        500000,
                        1000000,
                      ].map((amt) {
                        return ActionChip(
                          label: Text(RupiahFormatter.format(amt),
                              style: const TextStyle(fontSize: 11)),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onPressed: () {
                            amountCtrl.text = RupiahFormatter.format(amt);
                            if (amountHasError && amt > 0) {
                              amountHasError = false;
                            }
                            setModalState(() {});
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 14),

                    // 5. Kalkulasi & Rincian Biaya Admin
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isInterBankTransfer && !isBankSama && nominal > 0
                            ? Colors.amber.withValues(alpha: 0.1)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isInterBankTransfer && !isBankSama && nominal > 0
                              ? Colors.amber
                              : primaryTeal.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Alur Akun:',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF475569))),
                              Text(
                                '$sourceName ➔ $targetName',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Biaya Admin:',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF475569))),
                              Text(
                                adminFee > 0
                                    ? 'Rp ${RupiahFormatter.format(adminFee)} (Beda Bank)'
                                    : 'Rp 0 (Bebas Admin)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: adminFee > 0
                                      ? Colors.deepOrange
                                      : primaryTeal,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Potongan dari $sourceName:',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B))),
                              Text(
                                'Rp ${RupiahFormatter.format(totalPotongan)}',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: sourceColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Masuk ke $targetName:',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569))),
                              Text(
                                '+Rp ${RupiahFormatter.format(nominal)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: targetColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Sisa Saldo $sourceName:',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B))),
                              Text(
                                'Rp ${RupiahFormatter.format(sourceBalance - totalPotongan > 0 ? sourceBalance - totalPotongan : 0)}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (!isSaldoCukup && nominal > 0 && !amountHasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '⚠️ Saldo $sourceName tidak mencukupi untuk distribusi ini (Saldo: Rp ${RupiahFormatter.format(sourceBalance)}).',
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold),
                        ),
                      ),

                    const SizedBox(height: 14),

                    // Catatan (Opsional)
                    TextField(
                      controller: noteCtrl,
                      decoration: InputDecoration(
                        hintText:
                            'Keterangan (contoh: Tarik operasional lapangan, Setor sisa kas)',
                        hintStyle: const TextStyle(fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tombol Konfirmasi
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          if (nominal <= 0) {
                            setModalState(() => amountHasError = true);
                            if (amountKey.currentContext != null) {
                              Scrollable.ensureVisible(
                                amountKey.currentContext!,
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOut,
                                alignment: 0.3,
                              );
                            }
                            amountFocus.requestFocus();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('⚠️ Silakan masukkan Nominal Alokasi (Rp)!'),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          if (!isSaldoCukup) {
                            setModalState(() => amountHasError = true);
                            if (amountKey.currentContext != null) {
                              Scrollable.ensureVisible(
                                amountKey.currentContext!,
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOut,
                                alignment: 0.3,
                              );
                            }
                            amountFocus.requestFocus();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('⚠️ Saldo $sourceName tidak mencukupi untuk distribusi ini! (Saldo: Rp ${RupiahFormatter.format(sourceBalance)})'),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            // 1. Kurangi Saldo Sumber
                            if (sourceAccount == 'rekening') {
                              _data.rekeningStruktur.balance -= totalPotongan;
                            } else if (sourceAccount == 'debit') {
                              _data.onHandDebit.balance -= totalPotongan;
                            } else {
                              _data.onHandCash.balance -= totalPotongan;
                            }

                            // 2. Tambah Saldo Tujuan
                            if (targetAccount == 'rekening') {
                              _data.rekeningStruktur.balance += nominal;
                            } else if (targetAccount == 'debit') {
                              _data.onHandDebit.balance += nominal;
                            } else {
                              _data.onHandCash.balance += nominal;
                            }

                            // 3. Catat Pengeluaran untuk Admin Bank jika ada
                            if (adminFee > 0) {
                              _data.transactions.add(
                                StrukturTransaction(
                                  id: DateTime.now()
                                      .microsecondsSinceEpoch
                                      .toString(),
                                  title: 'Admin bank transfer beda bank',
                                  type: 'pengeluaran',
                                  sourceAccount: sourceAccount,
                                  amount: adminFee,
                                  adminFee: 0,
                                  note: noteCtrl.text.trim().isNotEmpty
                                      ? noteCtrl.text.trim()
                                      : null,
                                  timestamp: selectedDate,
                                ),
                              );
                              _data.transactions.sort((a, b) => a.timestamp.compareTo(b.timestamp));
                            }
                          });

                          _saveData();
                          if (adminFee > 0) {
                            _triggerAutoSyncSheets();
                          }
                          Navigator.pop(ctx);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Alokasi dana berhasil ($flowLabel)!',
                              ),
                              backgroundColor: primaryPurple,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPurple,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Konfirmasi Alokasi Dana',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- DIALOG KONFIRMASI HAPUS / ROLLBACK TRANSAKSI ---
  void _confirmDeleteTransaction(StrukturTransaction tx, [VoidCallback? onDeleted]) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.deepOrange, size: 24),
              SizedBox(width: 8),
              Text(
                'Hapus Transaksi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apakah Anda yakin ingin membatalkan transaksi "${tx.title}" sebesar Rp ${RupiahFormatter.format(tx.amount)}?',
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tx.isPemasukan
                            ? 'Saldo wadah penerima akan dikurangi Rp ${RupiahFormatter.format(tx.amount)}.'
                            : 'Saldo sumber dana akan dikembalikan sebesar Rp ${RupiahFormatter.format(tx.totalDeduction)}.',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  // Rollback saldo
                  if (tx.isPemasukan) {
                    if (tx.targetAccount == 'rekening') {
                      _data.rekeningStruktur.balance -= tx.amount;
                    } else if (tx.targetAccount == 'debit') {
                      _data.onHandDebit.balance -= tx.amount;
                    } else if (tx.targetAccount == 'cash') {
                      _data.onHandCash.balance -= tx.amount;
                    }
                  } else {
                    if (tx.sourceAccount == 'rekening') {
                      _data.rekeningStruktur.balance += tx.totalDeduction;
                    } else if (tx.sourceAccount == 'debit') {
                      _data.onHandDebit.balance += tx.totalDeduction;
                    } else if (tx.sourceAccount == 'cash') {
                      _data.onHandCash.balance += tx.totalDeduction;
                    }
                  }

                  _data.transactions.removeWhere((item) => item.id == tx.id);
                });
                _saveData();
                _triggerAutoSyncSheets();
                onDeleted?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Transaksi berhasil dibatalkan dan saldo telah dipulihkan.'),
                    backgroundColor: Colors.blueGrey,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Hapus & Rollback'),
            ),
          ],
        );
      },
    );
  }

  // --- DIALOG KONFIRMASI HAPUS & ROLLBACK SEMUA TRANSAKSI BULAN INI ---
  void _confirmDeleteAllTransactions([VoidCallback? onDeleted]) {
    final txList = _data.transactions
        .where((tx) => tx.isPemasukan || tx.isPengeluaran)
        .toList();

    if (txList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada data transaksi yang perlu dihapus pada bulan ini.'),
          backgroundColor: Colors.blueGrey,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          title: const Row(
            children: [
              Icon(Icons.delete_forever_rounded,
                  color: Colors.redAccent, size: 24),
              SizedBox(width: 8),
              Text(
                'Hapus & Rollback Semua',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apakah Anda yakin ingin menghapus dan membatalkan seluruh (${txList.length}) transaksi pada bulan ${_namaBulan[_selectedMonth.month - 1]} ${_selectedMonth.year}?',
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: Color(0xFFDC2626)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Seluruh saldo wadah (Rekening, Debit, Cash) akan di-rollback ke kondisi sebelum transaksi, dan tabel Google Spreadsheet akan otomatis dikosongkan.',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF991B1B)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  // Rollback saldo semua transaksi
                  for (final tx in _data.transactions) {
                    if (tx.isPemasukan) {
                      if (tx.targetAccount == 'rekening') {
                        _data.rekeningStruktur.balance -= tx.amount;
                      } else if (tx.targetAccount == 'debit') {
                        _data.onHandDebit.balance -= tx.amount;
                      } else if (tx.targetAccount == 'cash') {
                        _data.onHandCash.balance -= tx.amount;
                      }
                    } else if (tx.isPengeluaran) {
                      if (tx.sourceAccount == 'rekening') {
                        _data.rekeningStruktur.balance += tx.totalDeduction;
                      } else if (tx.sourceAccount == 'debit') {
                        _data.onHandDebit.balance += tx.totalDeduction;
                      } else if (tx.sourceAccount == 'cash') {
                        _data.onHandCash.balance += tx.totalDeduction;
                      }
                    }
                  }

                  // Hapus semua transaksi
                  _data.transactions.clear();
                });
                _saveData();
                _triggerAutoSyncSheets();
                onDeleted?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${txList.length} transaksi berhasil dihapus dan saldo telah dipulihkan.'),
                    backgroundColor: const Color(0xFFDC2626),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.delete_forever_rounded, size: 16),
              label: const Text('Hapus & Rollback Semua'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccountSelectorCard({
    required String title,
    required String subtitle,
    required int balance,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.1)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon,
                      size: 18,
                      color: isSelected
                          ? activeColor
                          : const Color(0xFF64748B)),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded,
                        size: 14, color: activeColor),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? activeColor : const Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style:
                    const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Rp ${RupiahFormatter.format(balance)}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? activeColor : const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: primaryPurple,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.corporate_fare_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Keuangan Struktur',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.style_rounded, color: Colors.white),
            tooltip: 'Kustom KU & Kategori',
            onPressed: () => _showKelolaKustomKodeModal(),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
            tooltip: 'Riwayat Mutasi & Distribusi',
            onPressed: () => _showRiwayatMutasiModal(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryPurple),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 0. Geser Bulan Bar (Bulan & Tahun Selector)
                  _buildMonthSelectorBar(),

                  const SizedBox(height: 10),

                  // 1. Banner Total Dana Struktur & Cash Flow
                  _buildTotalBanner(),

                  const SizedBox(height: 10),

                  // 2. Hub Tombol Aksi Distribusi & Alokasi Dana
                  _buildActionButtonsHub(),

                  const SizedBox(height: 10),

                  // 3. Kartu Rekening Struktur
                  _buildRekeningStrukturCard(),

                  const SizedBox(height: 10),

                  // 4. Kartu On Hand (Debit & Cash)
                  _buildOnHandCard(),

                  const SizedBox(height: 10),

                  // 5. Tabel Keuangan (Nama Bulan)
                  _buildTabelKeuangan(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthSelectorBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: primaryPurple.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.chevron_left_rounded,
              size: 24,
              color: primaryPurple,
            ),
            tooltip: 'Bulan Sebelumnya',
            onPressed: _prevMonth,
          ),
          Expanded(
            child: InkWell(
              onTap: _showMonthYearPicker,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: primaryPurple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: primaryPurple,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_namaBulan[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryPurple,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: primaryPurple,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: primaryPurple,
            ),
            tooltip: 'Bulan Berikutnya',
            onPressed: _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsHub() {
    return Column(
      children: [
        // Distribusi Dana: Pemasukan & Pengeluaran Row
        Row(
          children: [
            // 1. Pemasukan (+ Emerald)
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _showPemasukanDanaModal(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                  label: const Text(
                    'Pemasukan',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 2. Pengeluaran (- Rose)
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _showPengeluaranDanaModal(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.remove_circle_outline_rounded,
                      size: 20),
                  label: const Text(
                    'Pengeluaran',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 3. Alokasi Dana Internal (Full width)
        Container(
          width: double.infinity,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: primaryPurple.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () => _showDistribusiDanaModal(),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPurple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.swap_horiz_rounded, size: 20),
            label: const Text(
              'Alokasi Dana Internal',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryPurple, darkPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'TOTAL DANA STRUKTUR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white70, size: 22),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Rp ${RupiahFormatter.format(_data.totalDanaStruktur)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 1.5,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                Text(
                  'Rp ${RupiahFormatter.format(_data.totalDanaOperasional)}',
                  style: const TextStyle(
                    color: Color(0xFFFEF08A), // Kuning soft
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Monthly Inflow & Outflow Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_downward_rounded,
                            size: 14, color: Color(0xFF34D399)),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pemasukan',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 10)),
                          Text(
                            '+Rp ${RupiahFormatter.format(_data.totalPemasukan)}',
                            style: const TextStyle(
                              color: Color(0xFF34D399),
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF43F5E).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_upward_rounded,
                            size: 14, color: Color(0xFFFB7185)),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pengeluaran',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 10)),
                          Text(
                            '-Rp ${RupiahFormatter.format(_data.totalPengeluaran)}',
                            style: const TextStyle(
                              color: Color(0xFFFB7185),
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 10),

          // Mini Breakdown per Akun
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBannerSubStat(
                label: 'Rekening',
                amount: _data.rekeningStruktur.balance,
                icon: Icons.account_balance_rounded,
              ),
              _buildBannerSubStat(
                label: 'On Hand Debit',
                amount: _data.onHandDebit.balance,
                icon: Icons.credit_card_rounded,
              ),
              _buildBannerSubStat(
                label: 'On Hand Cash',
                amount: _data.onHandCash.balance,
                icon: Icons.payments_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerSubStat({
    required String label,
    required int amount,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Rp ${RupiahFormatter.format(amount)}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRekeningStrukturCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryPurple.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_rounded,
                        color: primaryPurple, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rekening Struktur',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Bank ${_data.rekeningStruktur.bankName} ${_data.rekeningStruktur.accountNumber.isNotEmpty ? "• ${_data.rekeningStruktur.accountNumber}" : ""}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded,
                    color: primaryPurple, size: 20),
                tooltip: 'Edit Rekening Struktur',
                onPressed: _showEditRekeningStrukturModal,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saldo Rekening Utama',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rp ${RupiahFormatter.format(_data.rekeningStruktur.balance)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryPurple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnHandCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryTeal.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.wallet_rounded,
                        color: primaryTeal, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dana On Hand (Dipegang)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Total On Hand: Rp ${RupiahFormatter.format(_data.totalOnHand)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: primaryTeal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.tune_rounded,
                    color: primaryTeal, size: 20),
                tooltip: 'Atur Akun On Hand',
                onPressed: _showEditOnHandModal,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Two Sub Cards: Debit & Cash
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. On Hand Debit
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: primaryPurple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _data.onHandDebit.bankName,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: primaryPurple,
                              ),
                            ),
                          ),
                          const Icon(Icons.credit_card_rounded,
                              size: 16, color: Color(0xFF64748B)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('On Hand Debit',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Text(
                        'Rp ${RupiahFormatter.format(_data.onHandDebit.balance)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (_data.onHandDebit.accountNumber.isNotEmpty ||
                          _data.onHandDebit.accountHolder.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_data.onHandDebit.accountNumber.isNotEmpty ? _data.onHandDebit.accountNumber : ""}${_data.onHandDebit.accountNumber.isNotEmpty && _data.onHandDebit.accountHolder.isNotEmpty ? " • " : ""}${_data.onHandDebit.accountHolder}',
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF94A3B8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // 2. On Hand Cash
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'TUNAI / FISIK',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ),
                          const Icon(Icons.payments_rounded,
                              size: 16, color: Color(0xFF64748B)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('On Hand Cash',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Text(
                        'Rp ${RupiahFormatter.format(_data.onHandCash.balance)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKuBadge(String ku, {bool isLarge = false}) {
    Color bg = const Color(0xFFEFF6FF); // Soft Blue 50
    Color fg = const Color(0xFF1D4ED8); // Blue 700
    Color border = const Color(0xFFBFDBFE); // Blue 200

    final lower = ku.toLowerCase();
    if (ku == '-' || ku.isEmpty) {
      bg = const Color(0xFFF8FAFC);
      fg = const Color(0xFF94A3B8);
      border = const Color(0xFFE2E8F0);
    } else if (lower.contains('1') || lower.contains('01')) {
      bg = const Color(0xFFEEF2FF);
      fg = const Color(0xFF4338CA);
      border = const Color(0xFFC7D2FE);
    } else if (lower.contains('2') || lower.contains('02')) {
      bg = const Color(0xFFF0FDF4);
      fg = const Color(0xFF15803D);
      border = const Color(0xFFBBF7D0);
    } else if (lower.contains('3') || lower.contains('03')) {
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFB45309);
      border = const Color(0xFFFDE68A);
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 8 : 6,
        vertical: isLarge ? 3 : 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        ku.isEmpty ? '-' : ku,
        style: TextStyle(
          fontSize: isLarge ? 10.5 : 9.5,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildKodeBadge(String kode, {bool isLarge = false}) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);
    Color border = const Color(0xFFE2E8F0);

    final lower = kode.toLowerCase();
    if (lower.contains('biaya rtk') || lower.contains('rtk')) {
      bg = const Color(0xFFFFE4E6);
      fg = const Color(0xFFBE123C);
      border = const Color(0xFFFECDD3);
    } else if (lower.contains('dp dtk') || lower.contains('terima dp')) {
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF047857);
      border = const Color(0xFF059669).withValues(alpha: 0.3);
    } else if (lower.contains('konsumsi')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
      border = const Color(0xFFFDE68A);
    } else if (lower.contains('sewa tempat') || lower.contains('sewa ruangan')) {
      bg = const Color(0xFFEDE9FE);
      fg = const Color(0xFF6D28D9);
      border = const Color(0xFFDDD6FE);
    } else if (lower.contains('kontribusi dp') || lower.contains('dp s4')) {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0369A1);
      border = const Color(0xFFBAE6FD);
    } else if (lower.contains('saldo awal')) {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0369A1);
      border = const Color(0xFFBAE6FD);
    } else if (lower.contains('dana dari s3') || lower.contains('s3')) {
      bg = const Color(0xFFF3E8FF);
      fg = const Color(0xFF7E22CE);
      border = const Color(0xFFE9D5FF);
    } else if (kode == '-' || kode.isEmpty) {
      bg = const Color(0xFFF8FAFC);
      fg = const Color(0xFF94A3B8);
      border = const Color(0xFFE2E8F0);
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 8 : 6,
        vertical: isLarge ? 3 : 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        kode.isEmpty ? '-' : kode,
        style: TextStyle(
          fontSize: isLarge ? 10.5 : 9.5,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildTabelKeuangan() {
    final monthName = _namaBulan[_selectedMonth.month - 1];
    final year = _selectedMonth.year;
    final allMutasi = _data.transactions
        .where((tx) => tx.isPemasukan || tx.isPengeluaran)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final previewList = allMutasi.length > 5
        ? allMutasi.sublist(allMutasi.length - 5)
        : allMutasi;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Elegant Creme / Amber 50
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF78350F).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Tabel Keuangan
          InkWell(
            onTap: () => _showDetailTabelKeuanganModal(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDE68A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.table_chart_rounded,
                            size: 16,
                            color: Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tabel Keuangan',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF78350F),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                '5 Transaksi terbaru • Ketuk detail',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: Color(0xFF92400E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (allMutasi.isNotEmpty) ...[
                        InkWell(
                          onTap: () => _confirmDeleteAllTransactions(),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: const Icon(
                              Icons.delete_sweep_rounded,
                              size: 14,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      InkWell(
                        onTap: () => _showDetailTabelKeuanganModal(),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${allMutasi.length} Data',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.open_in_new_rounded,
                                size: 12,
                                color: Color(0xFFB45309),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFFDE68A)),

          // Konten Tabel Preview (5 data transaksi terbaru: No, Tanggal, Keterangan, Jumlah, Kategori)
          if (previewList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 36,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada transaksi di bulan $monthName $year',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF78350F),
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Catat pemasukan atau pengeluaran untuk melihat ringkasan tabel di sini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Align(
                alignment: Alignment.topCenter,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFDE68A),
                        width: 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFFFEF3C7),
                        ),
                        headingTextStyle: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF78350F),
                        ),
                        dataTextStyle: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF451A03),
                        ),
                        horizontalMargin: 10,
                        columnSpacing: 14,
                        headingRowHeight: 32,
                        dataRowMinHeight: 38,
                        dataRowMaxHeight: 50,
                        columns: const [
                          DataColumn(
                            label: Center(child: Text('No')),
                            numeric: true,
                          ),
                          DataColumn(label: Text('Tanggal')),
                          DataColumn(label: Text('Keterangan')),
                          DataColumn(
                            label: Text('Jumlah'),
                            numeric: true,
                          ),
                          DataColumn(label: Center(child: Text('Kategori'))),
                        ],
                        rows: List<DataRow>.generate(
                          previewList.length,
                          (index) {
                            final tx = previewList[index];
                            final isEven = index % 2 == 0;
                            final dateFormatted =
                                DateFormat('dd/MM/yyyy').format(tx.timestamp);
                            final bool isDebit = tx.isPemasukan;
                            final String itemTitle = tx.title.replaceFirst(
                                RegExp(r'^(Pemasukan|Pengeluaran):\s*',
                                    caseSensitive: false),
                                '');
                            final String? itemSubtitle = (tx.note != null &&
                                    tx.note!.isNotEmpty &&
                                    tx.note != tx.title &&
                                    tx.note != itemTitle)
                                ? tx.note
                                : null;
                            final itemNumber = allMutasi.indexOf(tx) + 1;

                            return DataRow(
                              color: WidgetStateProperty.all(
                                isEven
                                    ? const Color(0xFFFFFDF5)
                                    : const Color(0xFFFFF7ED),
                              ),
                              cells: [
                                // 1. No
                                DataCell(
                                  Center(
                                    child: Text(
                                      '$itemNumber',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                  ),
                                ),
                                // 2. Tanggal
                                DataCell(
                                  Text(
                                    dateFormatted,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: Color(0xFF78350F),
                                      fontWeight: FontWeight.w500,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                                // 3. Keterangan
                                DataCell(
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 190),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          itemTitle,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10.5,
                                            color: Color(0xFF451A03),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (itemSubtitle != null &&
                                            itemSubtitle.isNotEmpty &&
                                            !itemTitle.contains(itemSubtitle))
                                          Text(
                                            itemSubtitle,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontStyle: FontStyle.italic,
                                              color: Color(0xFF92400E),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                // 4. Jumlah
                                DataCell(
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Rp ${RupiahFormatter.format(tx.amount)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10.5,
                                        color: isDebit
                                            ? const Color(0xFF059669)
                                            : const Color(0xFFE11D48),
                                      ),
                                    ),
                                  ),
                                ),
                                // 5. Kategori (Debit / Kredit)
                                DataCell(
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: isDebit
                                            ? const Color(0xFFD1FAE5)
                                            : const Color(0xFFFFE4E6),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isDebit
                                              ? const Color(0xFFA7F3D0)
                                              : const Color(0xFFFECDD3),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        isDebit ? 'Debit' : 'Kredit',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDebit
                                              ? const Color(0xFF047857)
                                              : const Color(0xFFBE123C),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- MODAL DETAIL TABEL KEUANGAN (3 TAB: LAPORAN KEUANGAN, RINCIAN PENGELUARAN, RINCIAN PEMASUKAN) ---
  void _showDetailTabelKeuanganModal() {
    String mainTab = 'laporan'; // 'laporan', 'pengeluaran', 'pemasukan'
    String selectedSubTab = 'semua'; // 'semua', 'pengeluaran', 'pemasukan' (untuk Laporan Keuangan)
    String searchQuery = '';
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final monthName = _namaBulan[_selectedMonth.month - 1];
            final year = _selectedMonth.year;
            final allMutasi = _data.transactions
                .where((tx) => tx.isPemasukan || tx.isPengeluaran)
                .toList()
              ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

            final pengeluaranList =
                allMutasi.where((tx) => tx.isPengeluaran).toList();
            final pemasukanList =
                allMutasi.where((tx) => tx.isPemasukan).toList();

            final int totalPengeluaranNominal =
                pengeluaranList.fold<int>(0, (sum, tx) => sum + tx.amount);

            final pemasukanDPList = pemasukanList
                .where((tx) => tx.isDPTransaction(
                    customRules: _data.customKodeRules))
                .toList();
            final int totalPemasukanDP = pemasukanDPList.fold<int>(
                0, (sum, tx) => sum + tx.amount);

            // Filter data untuk Tab Laporan Keuangan
            List<StrukturTransaction> activeList;
            if (selectedSubTab == 'pengeluaran') {
              activeList = pengeluaranList;
            } else if (selectedSubTab == 'pemasukan') {
              activeList = pemasukanList;
            } else {
              activeList = allMutasi;
            }

            if (searchQuery.isNotEmpty) {
              final query = searchQuery.toLowerCase();
              activeList = activeList.where((tx) {
                final title = tx.title.toLowerCase();
                final note = (tx.note ?? '').toLowerCase();
                final ku = tx
                    .getDisplayKu(customRules: _data.customKodeRules)
                    .toLowerCase();
                final kategori = tx
                    .getDisplayKode(customRules: _data.customKodeRules)
                    .toLowerCase();
                final amount = tx.amount.toString();
                final dateStr = DateFormat('dd/MM/yyyy').format(tx.timestamp);
                return title.contains(query) ||
                    note.contains(query) ||
                    ku.contains(query) ||
                    kategori.contains(query) ||
                    amount.contains(query) ||
                    dateStr.contains(query);
              }).toList();
            }

            int totalLaporanNominal = 0;
            for (final tx in activeList) {
              totalLaporanNominal += tx.amount;
            }

            const headerStyle = TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF78350F),
            );

            // --- TABEL SUMMARY BUILDER DUA KOLOM (KATEGORI / KU VS NOMINAL) ---
            Widget buildSummaryTwoColumnTable({
              required String tableTitle,
              required String colHeaderLeft,
              required String colHeaderRight,
              required Map<String, int> dataMap,
              required Map<String, int> countMap,
              required int totalAmount,
              required bool isPengeluaran,
              required bool isKuType,
            }) {
              final entries = dataMap.entries.toList();

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFFDE68A),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF78350F).withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Card Judul Tabel
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFFBEB),
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(13)),
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFFFDE68A),
                            width: 1.2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDE68A),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Icon(
                              isKuType
                                  ? Icons.account_balance_wallet_rounded
                                  : Icons.category_rounded,
                              size: 15,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tableTitle,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF78350F),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Header Kolom (2 Kolom)
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFFFDE68A),
                            width: 1.2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Text(
                                colHeaderLeft,
                                style: headerStyle,
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: const Color(0xFFFDE68A),
                          ),
                          Expanded(
                            flex: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              alignment: Alignment.centerRight,
                              child: Text(
                                colHeaderRight,
                                style: headerStyle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Data Rows
                    if (entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'Belum ada data ${isPengeluaran ? "pengeluaran" : "pemasukan"}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF94A3B8),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      ...List.generate(entries.length, (index) {
                        final entry = entries[index];
                        final isEven = index % 2 == 0;
                        final count = countMap[entry.key] ?? 0;
                        final amount = entry.value;

                        return Container(
                          decoration: BoxDecoration(
                            color: isEven
                                ? const Color(0xFFFFFDF5)
                                : const Color(0xFFFFF7ED),
                            border: Border(
                              bottom: BorderSide(
                                color: const Color(0xFFFDE68A)
                                    .withValues(alpha: 0.6),
                                width: 0.8,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Kolom Kiri: Kategori / KU
                              Expanded(
                                flex: 5,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 9),
                                  child: Row(
                                    children: [
                                      if (isKuType)
                                        _buildKuBadge(entry.key, isLarge: false)
                                      else
                                        _buildKodeBadge(entry.key,
                                            isLarge: false),
                                      const SizedBox(width: 8),
                                      if (count > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFFE2E8F0),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            '$count tx',
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 42,
                                color: const Color(0xFFFDE68A)
                                    .withValues(alpha: 0.6),
                              ),
                              // Kolom Kanan: Pengeluaran / Pemasukan Nominal
                              Expanded(
                                flex: 4,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 9),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Rp ${RupiahFormatter.format(amount)}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: amount > 0
                                            ? (isPengeluaran
                                                ? const Color(0xFFE11D48)
                                                : const Color(0xFF059669))
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                    // Baris Total
                    Container(
                      decoration: BoxDecoration(
                        color: isPengeluaran
                            ? const Color(0xFFFFF1F2)
                            : const Color(0xFFF0FDF4),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(13)),
                        border: Border(
                          top: BorderSide(
                            color: isPengeluaran
                                ? const Color(0xFFFECDD3)
                                : const Color(0xFFA7F3D0),
                            width: 1.2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isPengeluaran
                                      ? const Color(0xFF9F1239)
                                      : const Color(0xFF065F46),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 38,
                            color: isPengeluaran
                                ? const Color(0xFFFECDD3)
                                : const Color(0xFFA7F3D0),
                          ),
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Rp ${RupiahFormatter.format(totalAmount)}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: isPengeluaran
                                        ? const Color(0xFFE11D48)
                                        : const Color(0xFF059669),
                                  ),
                                ),
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

            return Container(
              height: MediaQuery.of(context).size.height * 0.93,
              decoration: const BoxDecoration(
                color: Color(0xFFFFFDF5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // --- TOP DRAG HANDLE & HEADER MODAL ---
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFFBEB),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFFDE68A)),
                      ),
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDE68A),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.table_chart_rounded,
                                color: Color(0xFFB45309),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Detail Tabel Keuangan Struktur',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF78350F),
                                    ),
                                  ),
                                  Text(
                                    'Periode: $monthName $year',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  Navigator.pop(bottomSheetContext),
                              icon: const Icon(Icons.close_rounded,
                                  color: Color(0xFF78350F)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // --- 3 TAB UTAMA (Laporan Keuangan, Rincian Pengeluaran, Rincian Pemasukan) ---
                        Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFDE68A),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // 1. Tab Lap Keu
                              Expanded(
                                child: InkWell(
                                  onTap: () => setModalState(
                                      () => mainTab = 'laporan'),
                                  borderRadius: BorderRadius.circular(9),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                    decoration: BoxDecoration(
                                      color: mainTab == 'laporan'
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(9),
                                      boxShadow: mainTab == 'laporan'
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF78350F)
                                                    .withValues(alpha: 0.1),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Lap Keu',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: mainTab == 'laporan'
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          color: mainTab == 'laporan'
                                              ? const Color(0xFF78350F)
                                              : const Color(0xFF92400E),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),

                              // 2. Tab Dana Keluar
                              Expanded(
                                child: InkWell(
                                  onTap: () => setModalState(
                                      () => mainTab = 'pengeluaran'),
                                  borderRadius: BorderRadius.circular(9),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                    decoration: BoxDecoration(
                                      color: mainTab == 'pengeluaran'
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(9),
                                      boxShadow: mainTab == 'pengeluaran'
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFFE11D48)
                                                    .withValues(alpha: 0.12),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Dana Keluar',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: mainTab == 'pengeluaran'
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          color: mainTab == 'pengeluaran'
                                              ? const Color(0xFFBE123C)
                                              : const Color(0xFF92400E),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),

                              // 3. Tab Dana Masuk
                              Expanded(
                                child: InkWell(
                                  onTap: () => setModalState(
                                      () => mainTab = 'pemasukan'),
                                  borderRadius: BorderRadius.circular(9),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                    decoration: BoxDecoration(
                                      color: mainTab == 'pemasukan'
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(9),
                                      boxShadow: mainTab == 'pemasukan'
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF059669)
                                                    .withValues(alpha: 0.12),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Dana Masuk',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: mainTab == 'pemasukan'
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          color: mainTab == 'pemasukan'
                                              ? const Color(0xFF047857)
                                              : const Color(0xFF92400E),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ==========================================
                  // KONTEN BODY MODAL BERDASARKAN MAIN TAB
                  // ==========================================
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        // ------------------------------------
                        // TAB 1: LAPORAN KEUANGAN (EXCEL-STYLE)
                        // ------------------------------------
                        if (mainTab == 'laporan') {
                          return Column(
                            children: [
                              // Filter & Search Header Tab Laporan Keuangan
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 10, 16, 10),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFFBEB),
                                  border: Border(
                                    bottom: BorderSide(
                                        color: Color(0xFFFDE68A)),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    // Search Bar & Spreadsheets Button
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: const Color(0xFFFDE68A)),
                                            ),
                                            child: TextField(
                                              controller: searchCtrl,
                                              onChanged: (val) {
                                                setModalState(() {
                                                  searchQuery = val.trim();
                                                });
                                              },
                                              style: const TextStyle(fontSize: 12),
                                              decoration: InputDecoration(
                                                hintText:
                                                    'Cari keterangan, KU, Kategori, nominal...',
                                                hintStyle: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: Color(0xFF94A3B8)),
                                                prefixIcon: const Icon(
                                                    Icons.search_rounded,
                                                    size: 18,
                                                    color: Color(0xFFB45309)),
                                                suffixIcon: searchQuery.isNotEmpty
                                                    ? IconButton(
                                                        icon: const Icon(
                                                            Icons.clear_rounded,
                                                            size: 16,
                                                            color: Color(0xFF94A3B8)),
                                                        onPressed: () {
                                                          searchCtrl.clear();
                                                          setModalState(() {
                                                            searchQuery = '';
                                                          });
                                                        },
                                                      )
                                                    : null,
                                                border: InputBorder.none,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10, vertical: 8),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () => _showUploadEvidenceModal(),
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            height: 38,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF107C41),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(0xFF0D6334),
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.cloud_upload_rounded,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(width: 5),
                                                Text(
                                                  'Upload Bukti',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () {
                                            _showGoogleSheetsConfigModal();
                                          },
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            height: 38,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(0xFF107C41),
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.settings_rounded,
                                                  size: 16,
                                                  color: Color(0xFF107C41),
                                                ),
                                                SizedBox(width: 5),
                                                Text(
                                                  'Atur Sheets',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF107C41),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Filter Sub Chips (Semua, Pengeluaran, Pemasukan)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildFilterChip(
                                            label: 'Semua (${allMutasi.length})',
                                            isSelected:
                                                selectedSubTab == 'semua',
                                            activeColor:
                                                const Color(0xFFB45309),
                                            fontSize: 10,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 5),
                                            onTap: () => setModalState(
                                                () => selectedSubTab = 'semua'),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: _buildFilterChip(
                                            label:
                                                'Pengeluaran (${pengeluaranList.length})',
                                            isSelected: selectedSubTab ==
                                                'pengeluaran',
                                            activeColor:
                                                const Color(0xFFE11D48),
                                            fontSize: 10,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 5),
                                            onTap: () => setModalState(() =>
                                                selectedSubTab = 'pengeluaran'),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: _buildFilterChip(
                                            label:
                                                'Pemasukan (${pemasukanList.length})',
                                            isSelected: selectedSubTab ==
                                                'pemasukan',
                                            activeColor:
                                                const Color(0xFF059669),
                                            fontSize: 10,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 5),
                                            onTap: () => setModalState(() =>
                                                selectedSubTab = 'pemasukan'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Tabel Content Laporan Keuangan
                              Expanded(
                                child: activeList.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(32),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.table_chart_outlined,
                                                size: 48,
                                                color: Color(0xFFD97706),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                searchQuery.isNotEmpty
                                                    ? 'Tidak ditemukan data "$searchQuery"'
                                                    : 'Belum ada data ${selectedSubTab == "semua" ? "transaksi" : selectedSubTab == "pengeluaran" ? "pengeluaran" : "pemasukan"}',
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF78350F),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                'Gunakan tombol pencatatan untuk menambah data keuangan.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF92400E),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : SingleChildScrollView(
                                        physics: const BouncingScrollPhysics(),
                                        padding: const EdgeInsets.all(12),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFFFDE68A),
                                                  width: 1.2),
                                            ),
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              physics:
                                                  const BouncingScrollPhysics(),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // --- EXCEL STYLE TWO-TIER HEADER ---
                                                  Container(
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: Color(0xFFFEF3C7),
                                                      border: Border(
                                                        bottom: BorderSide(
                                                            color: Color(
                                                                0xFFFDE68A),
                                                            width: 1.2),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        // 1. No (32)
                                                        const SizedBox(
                                                          width: 32,
                                                          height: 42,
                                                          child: Center(
                                                            child: Text('No',
                                                                style:
                                                                    headerStyle),
                                                          ),
                                                        ),
                                                        Container(
                                                            width: 1,
                                                            height: 42,
                                                            color: const Color(
                                                                0xFFFDE68A)),
                                                        // 2. Tanggal (84)
                                                        const SizedBox(
                                                          width: 84,
                                                          height: 42,
                                                          child: Center(
                                                            child: Text(
                                                                'Tanggal',
                                                                style:
                                                                    headerStyle),
                                                          ),
                                                        ),
                                                        Container(
                                                            width: 1,
                                                            height: 42,
                                                            color: const Color(
                                                                0xFFFDE68A)),
                                                        // 3. KU (95)
                                                        const SizedBox(
                                                          width: 95,
                                                          height: 42,
                                                          child: Center(
                                                            child: Text('KU',
                                                                style:
                                                                    headerStyle),
                                                          ),
                                                        ),
                                                        Container(
                                                            width: 1,
                                                            height: 42,
                                                            color: const Color(
                                                                0xFFFDE68A)),
                                                        // 4. Kategori (135)
                                                        const SizedBox(
                                                          width: 135,
                                                          height: 42,
                                                          child: Center(
                                                            child: Text(
                                                                'Kategori',
                                                                style:
                                                                    headerStyle),
                                                          ),
                                                        ),
                                                        Container(
                                                            width: 1,
                                                            height: 42,
                                                            color: const Color(
                                                                0xFFFDE68A)),
                                                        // 5. Keterangan (200)
                                                        const SizedBox(
                                                          width: 200,
                                                          height: 42,
                                                          child: Center(
                                                            child: Text(
                                                                'Keterangan',
                                                                style:
                                                                    headerStyle),
                                                          ),
                                                        ),
                                                        Container(
                                                            width: 1,
                                                            height: 42,
                                                            color: const Color(
                                                                0xFFFDE68A)),
                                                        // 6. Jumlah (100)
                                                        const SizedBox(
                                                          width: 100,
                                                          height: 42,
                                                          child: Center(
                                                            child: Text(
                                                                'Jumlah',
                                                                style:
                                                                    headerStyle),
                                                          ),
                                                        ),
                                                        Container(
                                                            width: 1,
                                                            height: 42,
                                                            color: const Color(
                                                                0xFFFDE68A)),
                                                        // 7. Nominal (Merged Debit & Kredit) (205)
                                                        SizedBox(
                                                          width: 205,
                                                          height: 42,
                                                          child: Column(
                                                            children: [
                                                              Container(
                                                                height: 20,
                                                                alignment:
                                                                    Alignment
                                                                        .center,
                                                                decoration:
                                                                    const BoxDecoration(
                                                                  border: Border(
                                                                    bottom:
                                                                        BorderSide(
                                                                      color: Color(
                                                                          0xFFFDE68A),
                                                                      width: 1,
                                                                    ),
                                                                  ),
                                                                ),
                                                                child:
                                                                    const Text(
                                                                  'Nominal',
                                                                  style:
                                                                      headerStyle,
                                                                ),
                                                              ),
                                                              Row(
                                                                children: [
                                                                  const SizedBox(
                                                                    width: 102,
                                                                    height: 21,
                                                                    child:
                                                                        Center(
                                                                      child:
                                                                          Text(
                                                                        'Debit',
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              9.5,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color: Color(
                                                                              0xFF047857),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    width: 1,
                                                                    height: 21,
                                                                    color: const Color(
                                                                        0xFFFDE68A),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 102,
                                                                    height: 21,
                                                                    child:
                                                                        Center(
                                                                      child:
                                                                          Text(
                                                                        'Kredit',
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              9.5,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color: Color(
                                                                              0xFFBE123C),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Container(
                                                            width: 1,
                                                            height: 42,
                                                            color: const Color(
                                                                0xFFFDE68A)),
                                                        // 8. Aksi (44)
                                                        const SizedBox(
                                                          width: 44,
                                                          height: 42,
                                                          child: Center(
                                                            child: Text('Aksi',
                                                                style:
                                                                    headerStyle),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  // --- DATA ROWS ---
                                                  ...List.generate(
                                                    activeList.length,
                                                    (index) {
                                                      final tx =
                                                          activeList[index];
                                                      final isEven =
                                                          index % 2 == 0;
                                                      final dateFormatted =
                                                          DateFormat(
                                                                  'dd/MM/yyyy')
                                                              .format(
                                                                  tx.timestamp);
                                                      final String displayKu =
                                                          tx.getDisplayKu(
                                                              customRules: _data
                                                                  .customKodeRules);
                                                      final String
                                                          displayKategori =
                                                          tx.getDisplayKode(
                                                              customRules: _data
                                                                  .customKodeRules);
                                                      final bool isDebit =
                                                          tx.isPemasukan;
                                                      final bool isKredit =
                                                          tx.isPengeluaran;
                                                      final String itemTitle =
                                                          tx.title.replaceFirst(
                                                              RegExp(r'^(Pemasukan|Pengeluaran):\s*',
                                                                  caseSensitive:
                                                                      false),
                                                              '');
                                                      final String? itemSubtitle =
                                                          (tx.note != null &&
                                                                  tx.note!
                                                                      .isNotEmpty &&
                                                                  tx.note !=
                                                                      tx.title &&
                                                                  tx.note !=
                                                                      itemTitle)
                                                          ? tx.note
                                                          : null;

                                                      return Container(
                                                        height: 38,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: isEven
                                                              ? const Color(
                                                                  0xFFFFFDF5)
                                                              : const Color(
                                                                  0xFFFFF7ED),
                                                          border: Border(
                                                            bottom: BorderSide(
                                                              color: const Color(
                                                                      0xFFFDE68A)
                                                                  .withValues(
                                                                      alpha:
                                                                          0.6),
                                                              width: 0.8,
                                                            ),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            // 1. No
                                                            SizedBox(
                                                              width: 32,
                                                              height: 38,
                                                              child: Center(
                                                                child: Text(
                                                                  '${index + 1}',
                                                                  style:
                                                                      const TextStyle(
                                                                    fontSize:
                                                                        9.5,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: Color(
                                                                        0xFF78350F),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            Container(
                                                                width: 1,
                                                                height: 38,
                                                                color: const Color(
                                                                        0xFFFDE68A)
                                                                    .withValues(
                                                                        alpha:
                                                                            0.6)),
                                                            // 2. Tanggal
                                                            SizedBox(
                                                              width: 84,
                                                              height: 38,
                                                              child: Center(
                                                                child: Text(
                                                                  dateFormatted,
                                                                  style:
                                                                      const TextStyle(
                                                                    fontSize:
                                                                        9.5,
                                                                    color: Color(
                                                                        0xFF451A03),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            Container(
                                                                width: 1,
                                                                height: 38,
                                                                color: const Color(
                                                                        0xFFFDE68A)
                                                                    .withValues(
                                                                        alpha:
                                                                            0.6)),
                                                            // 3. KU
                                                            Container(
                                                              width: 95,
                                                              height: 38,
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          4),
                                                              child: Center(
                                                                child:
                                                                    _buildKuBadge(
                                                                        displayKu,
                                                                        isLarge:
                                                                            false),
                                                              ),
                                                            ),
                                                            Container(
                                                                width: 1,
                                                                height: 38,
                                                                color: const Color(
                                                                        0xFFFDE68A)
                                                                    .withValues(
                                                                        alpha:
                                                                            0.6)),
                                                            // 4. Kategori
                                                            Container(
                                                              width: 135,
                                                              height: 38,
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          4),
                                                              child: Center(
                                                                child:
                                                                    _buildKodeBadge(
                                                                        displayKategori,
                                                                        isLarge:
                                                                            false),
                                                              ),
                                                            ),
                                                            Container(
                                                                width: 1,
                                                                height: 38,
                                                                color: const Color(
                                                                        0xFFFDE68A)
                                                                    .withValues(
                                                                        alpha:
                                                                            0.6)),
                                                            // 5. Keterangan
                                                            Container(
                                                              width: 200,
                                                              height: 38,
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          6,
                                                                      vertical:
                                                                          2),
                                                              child: Column(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    itemTitle,
                                                                    style:
                                                                        const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          9.5,
                                                                      color: Color(
                                                                          0xFF451A03),
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                  if (itemSubtitle !=
                                                                          null &&
                                                                      itemSubtitle
                                                                          .isNotEmpty &&
                                                                      !itemTitle
                                                                          .contains(
                                                                              itemSubtitle))
                                                                    Text(
                                                                      itemSubtitle,
                                                                      style:
                                                                          const TextStyle(
                                                                        fontSize:
                                                                            8.5,
                                                                        fontStyle:
                                                                            FontStyle.italic,
                                                                        color: Color(
                                                                            0xFF92400E),
                                                                      ),
                                                                      maxLines:
                                                                          1,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                ],
                                                              ),
                                                            ),
                                                            Container(
                                                                width: 1,
                                                                height: 38,
                                                                color: const Color(
                                                                        0xFFFDE68A)
                                                                    .withValues(
                                                                        alpha:
                                                                            0.6)),
                                                            // 6. Jumlah
                                                            Container(
                                                              width: 100,
                                                              height: 38,
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          6),
                                                              child: Align(
                                                                alignment:
                                                                    Alignment
                                                                        .centerRight,
                                                                child: Text(
                                                                  'Rp ${RupiahFormatter.format(tx.amount)}',
                                                                  style:
                                                                      const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        9.5,
                                                                    color: Color(
                                                                        0xFF451A03),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            Container(
                                                                width: 1,
                                                                height: 38,
                                                                color: const Color(
                                                                        0xFFFDE68A)
                                                                    .withValues(
                                                                        alpha:
                                                                            0.6)),
                                                            // 7. Sub-Kolom Debit
                                                            Container(
                                                              width: 102,
                                                              height: 38,
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          6),
                                                              child: Align(
                                                                alignment:
                                                                    Alignment
                                                                        .centerRight,
                                                                child: isDebit
                                                                    ? Text(
                                                                        'Rp ${RupiahFormatter.format(tx.amount)}',
                                                                        style:
                                                                            const TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          fontSize:
                                                                              9.5,
                                                                          color: Color(
                                                                              0xFF059669),
                                                                        ),
                                                                      )
                                                                    : const Text(
                                                                        '-',
                                                                        style:
                                                                            TextStyle(
                                                                          color: Color(
                                                                              0xFF94A3B8),
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          fontSize:
                                                                              9.5,
                                                                        ),
                                                                      ),
                                                              ),
                                                            ),
                                                            Container(
                                                                width: 1,
                                                                height: 38,
                                                                color: const Color(
                                                                        0xFFFDE68A)
                                                                    .withValues(
                                                                        alpha:
                                                                            0.6)),
                                                            // 8. Sub-Kolom Kredit
                                                            Container(
                                                              width: 102,
                                                              height: 38,
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          6),
                                                              child: Align(
                                                                alignment:
                                                                    Alignment
                                                                        .centerRight,
                                                                child: isKredit
                                                                    ? Text(
                                                                        'Rp ${RupiahFormatter.format(tx.amount)}',
                                                                        style:
                                                                            const TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          fontSize:
                                                                              9.5,
                                                                          color: Color(
                                                                              0xFFE11D48),
                                                                        ),
                                                                      )
                                                                    : const Text(
                                                                        '-',
                                                                        style:
                                                                            TextStyle(
                                                                          color: Color(
                                                                              0xFF94A3B8),
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          fontSize:
                                                                              9.5,
                                                                        ),
                                                                      ),
                                                              ),
                                                            ),
                                                            Container(
                                                                width: 1,
                                                                height: 38,
                                                                color: const Color(
                                                                        0xFFFDE68A)
                                                                    .withValues(
                                                                        alpha:
                                                                            0.6)),
                                                            // 9. Aksi
                                                            SizedBox(
                                                              width: 44,
                                                              height: 38,
                                                              child: IconButton(
                                                                padding:
                                                                    EdgeInsets
                                                                        .zero,
                                                                icon: const Icon(
                                                                  Icons
                                                                      .delete_outline_rounded,
                                                                  color: Colors
                                                                      .redAccent,
                                                                  size: 16,
                                                                ),
                                                                tooltip:
                                                                    'Hapus Transaksi',
                                                                onPressed: () {
                                                                  _confirmDeleteTransaction(
                                                                    tx,
                                                                    () {
                                                                      setModalState(
                                                                          () {});
                                                                    },
                                                                  );
                                                                },
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                              // Bottom Total Summary Bar Tab Laporan
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 10, 16, 12),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    top: BorderSide(color: Color(0xFFFDE68A)),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Total ${activeList.length} Transaksi',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF92400E),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              selectedSubTab == 'semua'
                                                  ? 'Total Akumulasi:'
                                                  : selectedSubTab == 'pengeluaran'
                                                      ? 'Total Pengeluaran:'
                                                      : 'Total Pemasukan:',
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF78350F),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: selectedSubTab == 'semua'
                                                ? const Color(0xFFFEF3C7)
                                                : selectedSubTab == 'pengeluaran'
                                                    ? const Color(0xFFFFF1F2)
                                                    : const Color(0xFFF0FDF4),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: selectedSubTab == 'semua'
                                                  ? const Color(0xFFFDE68A)
                                                  : selectedSubTab == 'pengeluaran'
                                                      ? const Color(0xFFFECDD3)
                                                      : const Color(0xFFA7F3D0),
                                            ),
                                          ),
                                          child: Text(
                                            'Rp ${RupiahFormatter.format(totalLaporanNominal)}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: selectedSubTab == 'semua'
                                                  ? const Color(0xFFB45309)
                                                  : selectedSubTab == 'pengeluaran'
                                                      ? const Color(0xFFE11D48)
                                                      : const Color(0xFF059669),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        // ------------------------------------
                        // TAB 2: RINCIAN PENGELUARAN (2 TABEL)
                        // ------------------------------------
                        if (mainTab == 'pengeluaran') {
                          // Tabel 1: Agregasi Berdasarkan Kategori Pengeluaran (Kategori mengandung "DP", "Saldo Awal", dan "Dana dari S3" tidak dimasukkan)
                          final Map<String, int> pengeluaranKategoriMap = {};
                          final Map<String, int> pengeluaranKategoriCountMap =
                              {};

                          // Tambahkan kategori yang sudah dikonfigurasi (kecuali mengandung "DP", "Saldo Awal", atau "Dana dari S3")
                          for (final r in _data.customKodeRules
                              .where((r) => r.type != 'ku')) {
                            final name = r.kode.trim();
                            final nameLower = name.toLowerCase();
                            final bool isSaldoAwal =
                                nameLower.contains('saldo awal');
                            final bool isDanaS3 = !isSaldoAwal &&
                                (nameLower.contains('dana dari s3') ||
                                    nameLower.contains('dana s3') ||
                                    nameLower == 's3');

                            if (name.isNotEmpty &&
                                !name.toUpperCase().contains('DP') &&
                                !isSaldoAwal &&
                                !isDanaS3 &&
                                !pengeluaranKategoriMap.containsKey(name)) {
                              pengeluaranKategoriMap[name] = 0;
                              pengeluaranKategoriCountMap[name] = 0;
                            }
                          }

                          // Agregasi dari transaksi pengeluaran (kecuali kategori yang mengandung "DP", "Saldo Awal", atau "Dana dari S3")
                          for (final tx in pengeluaranList) {
                            final rawKategori = tx
                                .getDisplayKode(
                                    customRules: _data.customKodeRules)
                                .trim();
                            final kategori =
                                rawKategori.isEmpty ? '-' : rawKategori;
                            final kategoriLower = kategori.toLowerCase();
                            final noteOrTitle =
                                '${tx.title} ${tx.note ?? ''}'.toLowerCase();
                            final bool isSaldoAwal =
                                kategoriLower.contains('saldo awal') ||
                                noteOrTitle.contains('saldo awal');
                            final bool isDanaS3 = !isSaldoAwal &&
                                (kategoriLower.contains('dana dari s3') ||
                                    kategoriLower.contains('dana s3') ||
                                    kategoriLower == 's3' ||
                                    noteOrTitle.contains('dana dari s3') ||
                                    noteOrTitle.contains('dana s3'));

                            // Lewati jika kategori mengandung "DP", "Saldo Awal", "Dana dari S3", atau merupakan transaksi DP
                            if (kategori.toUpperCase().contains('DP') ||
                                isSaldoAwal ||
                                isDanaS3 ||
                                tx.isDPTransaction(
                                    customRules: _data.customKodeRules)) {
                              continue;
                            }

                            String matchedKey = kategori;
                            for (final k in pengeluaranKategoriMap.keys) {
                              if (k.toLowerCase() == kategori.toLowerCase()) {
                                matchedKey = k;
                                break;
                              }
                            }
                            pengeluaranKategoriMap[matchedKey] =
                                (pengeluaranKategoriMap[matchedKey] ?? 0) +
                                    tx.amount;
                            pengeluaranKategoriCountMap[matchedKey] =
                                (pengeluaranKategoriCountMap[matchedKey] ?? 0) +
                                    1;
                          }

                          final int totalPengeluaranKategoriNominal =
                              pengeluaranKategoriMap.values
                                  .fold<int>(0, (sum, v) => sum + v);

                          // Tabel 2: Agregasi Berdasarkan Dana Kuasa Usaha (KU)
                          final Map<String, int> pengeluaranKuMap = {};
                          final Map<String, int> pengeluaranKuCountMap = {};

                          // Tambahkan KU yang sudah dikonfigurasi
                          for (final r in _data.customKodeRules
                              .where((r) => r.type == 'ku')) {
                            final name = r.kode.trim();
                            if (name.isNotEmpty &&
                                !pengeluaranKuMap.containsKey(name)) {
                              pengeluaranKuMap[name] = 0;
                              pengeluaranKuCountMap[name] = 0;
                            }
                          }

                          // Agregasi dari transaksi pengeluaran
                          for (final tx in pengeluaranList) {
                            final rawKu = tx
                                .getDisplayKu(
                                    customRules: _data.customKodeRules)
                                .trim();
                            final ku = rawKu.isEmpty ? '-' : rawKu;

                            String matchedKey = ku;
                            for (final k in pengeluaranKuMap.keys) {
                              if (k.toLowerCase() == ku.toLowerCase()) {
                                matchedKey = k;
                                break;
                              }
                            }
                            pengeluaranKuMap[matchedKey] =
                                (pengeluaranKuMap[matchedKey] ?? 0) +
                                    tx.amount;
                            pengeluaranKuCountMap[matchedKey] =
                                (pengeluaranKuCountMap[matchedKey] ?? 0) + 1;
                          }

                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Info Banner Rincian Pengeluaran
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF1F2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFFECDD3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFE4E6),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.trending_down_rounded,
                                          color: Color(0xFFE11D48),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Ringkasan Klasifikasi Pengeluaran',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF9F1239),
                                              ),
                                            ),
                                            Text(
                                              'Total ${pengeluaranList.length} transaksi kredit periode $monthName $year',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFFBE123C),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'Rp ${RupiahFormatter.format(totalPengeluaranNominal)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFE11D48),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Kategori Pengeluaran (Kecuali Kategori DP)
                                buildSummaryTwoColumnTable(
                                  tableTitle: 'Klasifikasi Kategori Pengeluaran',
                                  colHeaderLeft: 'Kategori Pengeluaran',
                                  colHeaderRight: 'Pengeluaran',
                                  dataMap: pengeluaranKategoriMap,
                                  countMap: pengeluaranKategoriCountMap,
                                  totalAmount: totalPengeluaranKategoriNominal,
                                  isPengeluaran: true,
                                  isKuType: false,
                                ),

                                const SizedBox(height: 20),

                                // Dana Kuasa Usaha (KU)
                                buildSummaryTwoColumnTable(
                                  tableTitle: 'Klasifikasi Dana Kuasa Usaha (KU)',
                                  colHeaderLeft: 'Dana Kuasa Usaha',
                                  colHeaderRight: 'Pengeluaran',
                                  dataMap: pengeluaranKuMap,
                                  countMap: pengeluaranKuCountMap,
                                  totalAmount: totalPengeluaranNominal,
                                  isPengeluaran: true,
                                  isKuType: true,
                                ),

                                const SizedBox(height: 16),
                              ],
                            ),
                          );
                        }

                        // ------------------------------------
                        // TAB 3: RINCIAN PEMASUKAN
                        // ------------------------------------
                        // Pemasukan Non-DP (DP dikecualikan dari Tabel Rincian Pemasukan)
                        final pemasukanNonDPList = pemasukanList
                            .where((tx) => !tx.isDPTransaction(
                                customRules: _data.customKodeRules))
                            .toList();
                        final int totalPemasukanNonDPNominal = pemasukanNonDPList
                            .fold<int>(0, (sum, tx) => sum + tx.amount);

                        // Agregasi Berdasarkan Kategori Pemasukan (Non-DP) & Default Layout
                        int saldoAwalNominal = 0;
                        int saldoAwalCount = 0;
                        int danaS3Nominal = 0;
                        int danaS3Count = 0;

                        final Map<String, int> pemasukanLainMap = {};
                        final Map<String, int> pemasukanLainCountMap = {};

                        // Agregasi dari transaksi pemasukan non-DP
                        for (final tx in pemasukanNonDPList) {
                          final rawKategori = tx
                              .getDisplayKode(
                                  customRules: _data.customKodeRules)
                              .trim();
                          final kategoriLower = rawKategori.toLowerCase();
                          final noteOrTitle =
                              '${tx.title} ${tx.note ?? ''}'.toLowerCase();

                          final bool isSaldoAwal =
                              kategoriLower.contains('saldo awal') ||
                              noteOrTitle.contains('saldo awal');

                          final bool isDanaS3 = !isSaldoAwal &&
                              (kategoriLower.contains('dana dari s3') ||
                                  kategoriLower.contains('dana s3') ||
                                  kategoriLower == 's3' ||
                                  noteOrTitle.contains('dana dari s3') ||
                                  noteOrTitle.contains('dana s3'));

                          if (isSaldoAwal) {
                            saldoAwalNominal += tx.amount;
                            saldoAwalCount++;
                          } else if (isDanaS3) {
                            danaS3Nominal += tx.amount;
                            danaS3Count++;
                          } else {
                            final name = rawKategori.isEmpty || rawKategori == '-'
                                ? 'Lainnya'
                                : rawKategori;
                            pemasukanLainMap[name] =
                                (pemasukanLainMap[name] ?? 0) + tx.amount;
                            pemasukanLainCountMap[name] =
                                (pemasukanLainCountMap[name] ?? 0) + 1;
                          }
                        }

                        // Sisa Saldo = Total Pemasukan (Non-DP) - Total Pengeluaran
                        final int sisaSaldo = totalPemasukanNonDPNominal -
                            totalPengeluaranNominal;

                        Widget buildPemasukanItemRow({
                          required String title,
                          required int count,
                          required int amount,
                          required bool isEven,
                          Color? customTextColor,
                        }) {
                          return Container(
                            decoration: BoxDecoration(
                              color: isEven
                                  ? const Color(0xFFFFFDF5)
                                  : const Color(0xFFFFF7ED),
                              border: Border(
                                bottom: BorderSide(
                                  color: const Color(0xFFFDE68A)
                                      .withValues(alpha: 0.6),
                                  width: 0.8,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Kolom Kiri: Rincian Pemasukan
                                Expanded(
                                  flex: 5,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 9),
                                    child: Row(
                                      children: [
                                        _buildKodeBadge(title, isLarge: false),
                                        const SizedBox(width: 8),
                                        if (count > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(0xFFE2E8F0),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              '$count tx',
                                              style: const TextStyle(
                                                fontSize: 9.5,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 42,
                                  color: const Color(0xFFFDE68A)
                                      .withValues(alpha: 0.6),
                                ),
                                // Kolom Kanan: Total Nominal
                                Expanded(
                                  flex: 4,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 9),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        'Rp ${RupiahFormatter.format(amount)}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: customTextColor ??
                                              (amount > 0
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFF94A3B8)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Info Banner Rincian Pemasukan
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFA7F3D0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.trending_up_rounded,
                                        color: Color(0xFF059669),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Ringkasan Klasifikasi Pemasukan',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF065F46),
                                            ),
                                          ),
                                          Text(
                                            'Total ${pemasukanNonDPList.length} transaksi debit periode $monthName $year',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF047857),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'Rp ${RupiahFormatter.format(totalPemasukanNonDPNominal)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Tabel Rincian Pemasukan (Format Default: Saldo Awal, Dana dari S3, Total Pemasukkan, Total Pengeluaran, Sisa Saldo)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFFDE68A),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF78350F)
                                          .withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Header Card Judul Tabel "Rincian Pemasukan"
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(13)),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Color(0xFFFDE68A),
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFDE68A),
                                              borderRadius:
                                                  BorderRadius.circular(7),
                                            ),
                                            child: const Icon(
                                              Icons
                                                  .account_balance_wallet_rounded,
                                              size: 15,
                                              color: Color(0xFFB45309),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: Text(
                                              'Rincian Pemasukan',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF78350F),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Header Kolom (2 Kolom: Rincian Pemasukan | Total)
                                    Container(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFEF3C7),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Color(0xFFFDE68A),
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 5,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                              child: const Text(
                                                'Rincian Pemasukan',
                                                style: headerStyle,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 1,
                                            height: 36,
                                            color: const Color(0xFFFDE68A),
                                          ),
                                          Expanded(
                                            flex: 4,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                              alignment: Alignment.centerRight,
                                              child: const Text(
                                                'Total',
                                                style: headerStyle,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Row 1: Saldo Awal
                                    buildPemasukanItemRow(
                                      title: 'Saldo Awal',
                                      count: saldoAwalCount,
                                      amount: saldoAwalNominal,
                                      isEven: true,
                                    ),

                                    // Row 2: Dana dari S3
                                    buildPemasukanItemRow(
                                      title: 'Dana dari S3',
                                      count: danaS3Count,
                                      amount: danaS3Nominal,
                                      isEven: false,
                                    ),

                                    // Rows Kategori Lain (jika ada transaksi pemasukan non-DP selain Saldo Awal & Dana dari S3)
                                    ...pemasukanLainMap.entries
                                        .map((entry) {
                                      final c =
                                          pemasukanLainCountMap[entry.key] ?? 0;
                                      return buildPemasukanItemRow(
                                        title: entry.key,
                                        count: c,
                                        amount: entry.value,
                                        isEven: true,
                                      );
                                    }),

                                    // Row 3: Total Pemasukkan (Saldo Awal + Dana dari S3 + Lainnya Non-DP)
                                    Container(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF0FDF4),
                                        border: Border(
                                          top: BorderSide(
                                            color: Color(0xFFA7F3D0),
                                            width: 1.2,
                                          ),
                                          bottom: BorderSide(
                                            color: Color(0xFFA7F3D0),
                                            width: 0.8,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 5,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 9),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                      Icons
                                                          .add_circle_outline_rounded,
                                                      size: 14,
                                                      color:
                                                          Color(0xFF059669)),
                                                  const SizedBox(width: 6),
                                                  const Text(
                                                    'Total Pemasukkan',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Color(0xFF065F46),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 1,
                                            height: 38,
                                            color: const Color(0xFFA7F3D0),
                                          ),
                                          Expanded(
                                            flex: 4,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 9),
                                              child: Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Text(
                                                  'Rp ${RupiahFormatter.format(totalPemasukanNonDPNominal)}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color: Color(0xFF059669),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Row 4: Total Pengeluaran
                                    Container(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFF1F2),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Color(0xFFFECDD3),
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 5,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 9),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                      Icons
                                                          .remove_circle_outline_rounded,
                                                      size: 14,
                                                      color:
                                                          Color(0xFFE11D48)),
                                                  const SizedBox(width: 6),
                                                  const Text(
                                                    'Total Pengeluaran',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Color(0xFF9F1239),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 1,
                                            height: 38,
                                            color: const Color(0xFFFECDD3),
                                          ),
                                          Expanded(
                                            flex: 4,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 9),
                                              child: Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Text(
                                                  'Rp ${RupiahFormatter.format(totalPengeluaranNominal)}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color: Color(0xFFE11D48),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Row 5: Sisa Saldo (Total Pemasukkan - Total Pengeluaran)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: sisaSaldo >= 0
                                            ? const Color(0xFFFEF3C7)
                                            : const Color(0xFFFFE4E6),
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                bottom:
                                                    Radius.circular(13)),
                                        border: Border(
                                          top: BorderSide(
                                            color: sisaSaldo >= 0
                                                ? const Color(0xFFFDE68A)
                                                : const Color(0xFFFECDD3),
                                            width: 1.4,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 5,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Sisa Saldo',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: sisaSaldo >= 0
                                                          ? const Color(
                                                              0xFF78350F)
                                                          : const Color(
                                                              0xFF9F1239),
                                                    ),
                                                  ),
                                                  Text(
                                                    'Total Pemasukkan - Total Pengeluaran',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color: sisaSaldo >= 0
                                                          ? const Color(
                                                              0xFF92400E)
                                                          : const Color(
                                                              0xFFBE123C),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 1,
                                            height: 44,
                                            color: sisaSaldo >= 0
                                                ? const Color(0xFFFDE68A)
                                                : const Color(0xFFFECDD3),
                                          ),
                                          Expanded(
                                            flex: 4,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                              child: Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Text(
                                                  sisaSaldo < 0
                                                      ? '-Rp ${RupiahFormatter.format(sisaSaldo.abs())}'
                                                      : 'Rp ${RupiahFormatter.format(sisaSaldo)}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color: sisaSaldo >= 0
                                                        ? const Color(
                                                            0xFF047857)
                                                        : const Color(
                                                            0xFFBE123C),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Tabel Total Dana Kontribusi (1 Kolom, 2 Baris: Baris 1 Judul "Total Dana Kontribusi", Baris 2 Langsung Total Uang)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFFDE68A),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF78350F)
                                          .withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Baris 1: Header / Judul "Total Dana Kontribusi"
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(13)),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Color(0xFFFDE68A),
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFDE68A),
                                              borderRadius:
                                                  BorderRadius.circular(7),
                                            ),
                                            child: const Icon(
                                              Icons.volunteer_activism_rounded,
                                              size: 15,
                                              color: Color(0xFFB45309),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: Text(
                                              'Total Dana Kontribusi',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF78350F),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Baris 2: Total Uang (1 Kolom Saja)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFFDF5),
                                        borderRadius: BorderRadius.vertical(
                                            bottom: Radius.circular(13)),
                                      ),
                                      child: Text(
                                        'Rp ${RupiahFormatter.format(totalPemasukanDP)}',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: totalPemasukanDP > 0
                                              ? const Color(0xFF059669)
                                              : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRiwayatMutasiModal() {
    String selectedTab = 'semua'; // 'semua', 'pemasukan', 'pengeluaran'

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allTx = _data.transactions
                .where((tx) => tx.isPemasukan || tx.isPengeluaran)
                .toList();
            int countPemasukan = 0;
            int countPengeluaran = 0;
            final List<StrukturTransaction> filteredTx = [];

            for (int i = 0; i < allTx.length; i++) {
              final tx = allTx[i];
              if (tx.isPemasukan) {
                countPemasukan++;
                if (selectedTab == 'pemasukan' || selectedTab == 'semua') {
                  filteredTx.add(tx);
                }
              } else if (tx.isPengeluaran) {
                countPengeluaran++;
                if (selectedTab == 'pengeluaran' || selectedTab == 'semua') {
                  filteredTx.add(tx);
                }
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Top Drag Handle & Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B)
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: Color(0xFF1E293B),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Riwayat Transaksi Keuangan',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'Periode: ${_namaBulan[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(bottomSheetContext),
                              icon: const Icon(Icons.close_rounded,
                                  color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Filter Tabs
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip(
                                label: 'Semua (${allTx.length})',
                                isSelected: selectedTab == 'semua',
                                activeColor: const Color(0xFF1E293B),
                                onTap: () =>
                                    setModalState(() => selectedTab = 'semua'),
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                label: 'Pemasukan / Debit ($countPemasukan)',
                                isSelected: selectedTab == 'pemasukan',
                                activeColor: const Color(0xFF059669),
                                onTap: () => setModalState(
                                    () => selectedTab = 'pemasukan'),
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                label: 'Pengeluaran / Kredit ($countPengeluaran)',
                                isSelected: selectedTab == 'pengeluaran',
                                activeColor: const Color(0xFFE11D48),
                                onTap: () => setModalState(
                                    () => selectedTab = 'pengeluaran'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content: Transaction List
                  Expanded(
                    child: filteredTx.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_outlined,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    selectedTab == 'semua'
                                        ? 'Belum ada transaksi di bulan ini'
                                        : 'Tidak ada transaksi kategori ini',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Gunakan tombol Pemasukan atau Pengeluaran untuk mencatat transaksi.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            addAutomaticKeepAlives: false,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            itemCount: filteredTx.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final tx = filteredTx[index];
                              final dateStr = DateFormat('d MMM yyyy, HH:mm')
                                   .format(tx.timestamp);

                              final bool isDebit = tx.isPemasukan;
                              final IconData txIcon = isDebit
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded;
                              final Color txColor = isDebit
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFE11D48);
                              final String badgeText = isDebit
                                  ? 'DEBIT'
                                  : 'KREDIT';
                              final Color badgeBg = isDebit
                                  ? const Color(0xFFD1FAE5)
                                  : const Color(0xFFFFE4E6);
                              final Color badgeFg = isDebit
                                  ? const Color(0xFF047857)
                                  : const Color(0xFFBE123C);
                              final String amountPrefix = isDebit ? '+' : '-';

                              String subtitleText = '';
                              if (isDebit) {
                                String wadah = 'Rekening';
                                if (tx.targetAccount == 'debit') {
                                  wadah = 'On Hand Debit';
                                } else if (tx.targetAccount == 'cash') {
                                  wadah = 'On Hand Cash';
                                }
                                subtitleText =
                                    'Dari: ${tx.manualSource ?? "Luar"} ➔ Wadah: $wadah';
                              } else {
                                String sumber = 'Rekening';
                                if (tx.sourceAccount == 'debit') {
                                  sumber = 'On Hand Debit';
                                } else if (tx.sourceAccount == 'cash') {
                                  sumber = 'On Hand Cash';
                                }
                                subtitleText = 'Sumber: $sumber';
                              }

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border:
                                      Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: txColor.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        txIcon,
                                        color: txColor,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: badgeBg,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  badgeText,
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color: badgeFg,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            tx.title.replaceFirst(
                                                RegExp(r'^(Pemasukan|Pengeluaran):\s*',
                                                    caseSensitive: false),
                                                ''),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          if (subtitleText.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              subtitleText,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                          if (tx.note != null &&
                                              tx.note!.isNotEmpty &&
                                              tx.note != tx.title &&
                                              !tx.title.contains(tx.note!)) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              '“${tx.note}”',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 3),
                                          Text(
                                            dateStr,
                                            style: const TextStyle(
                                                fontSize: 10.5,
                                                color: Color(0xFF94A3B8)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '$amountPrefix Rp ${RupiahFormatter.format(tx.amount)}',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: txColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        InkWell(
                                          onTap: () {
                                            _confirmDeleteTransaction(
                                                tx, () => setModalState(() {}));
                                          },
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18,
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
    double fontSize = 12,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: padding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? activeColor : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
