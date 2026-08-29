import 'dart:async';
import 'dart:convert';
import 'package:daily_apps/models/model_pribadi.dart';
import 'package:daily_apps/utils/custom_rule_import_helper.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:daily_apps/widgets/custom_toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PribadiPage extends StatefulWidget {
  const PribadiPage({super.key});

  @override
  State<PribadiPage> createState() => _PribadiPageState();
}

class _PribadiPageState extends State<PribadiPage> {
  // Light Theme Palette - Royal Indigo & Velvet Slate
  static const Color lightBg = Color(0xFFF8FAFC); // Slate 50
  static const Color lightCard = Colors.white;
  static const Color lightCardElevated = Color(0xFFF1F5F9); // Slate 100
  static const Color lightBorder = Color(0xFFE2E8F0); // Slate 200
  static const Color primaryDark = Color(0xFF1E1B4B); // Deep Royal Indigo (AppBar)
  static const Color primaryGreen = Color(0xFF059669); // Emerald Mint 600 (Pemasukan)
  static const Color primaryBlue = Color(0xFF4F46E5); // Indigo Accent 600
  static const Color primaryRose = Color(0xFFE11D48); // Soft Coral Rose 600 (Pengeluaran)
  static const Color textDark = Color(0xFF0F172A); // Slate 900
  static const Color textMuted = Color(0xFF64748B); // Slate 500

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
  PribadiData _data = PribadiData();
  bool _isLoading = true;

  // Filter & Sort state untuk tabel keuangan
  String _selectedFilter = 'semua';
  String _searchQuery = '';
  bool _isSortAscending = false;

  String get _monthKey =>
      '${_selectedMonth.year}_${_selectedMonth.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _loadData();
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
              backgroundColor: lightCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: lightBorder),
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
                      color: textDark,
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
                        color: primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Bulan Ini',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen,
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
                        color: lightCardElevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded,
                                color: textDark),
                            onPressed: () {
                              setDialogState(() => tempYear--);
                            },
                          ),
                          Text(
                            '$tempYear',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded,
                                color: textDark),
                            onPressed: () {
                              setDialogState(() => tempYear++);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Month Grid
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(12, (index) {
                        final monthNum = index + 1;
                        final isSelected =
                            monthNum == tempMonth && tempYear == _selectedMonth.year;
                        final isChosenInDialog = monthNum == tempMonth;

                        return SizedBox(
                          width: 68,
                          child: InkWell(
                            onTap: () {
                              setDialogState(() => tempMonth = monthNum);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isChosenInDialog
                                    ? primaryGreen
                                    : (isSelected
                                        ? primaryGreen.withValues(alpha: 0.15)
                                        : lightCardElevated),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isChosenInDialog
                                      ? primaryGreen
                                      : lightBorder,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _namaBulan[index].substring(0, 3),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isChosenInDialog
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isChosenInDialog
                                      ? Colors.white
                                      : textDark,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal',
                      style: TextStyle(color: textMuted)),
                ),
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
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Pilih'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final monthlyKey = 'pribadi_keuangan_data_$_monthKey';
    final raw = prefs.getString(monthlyKey);

    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          if (mounted) {
            final loaded = PribadiData.fromJson(decoded);
            if (loaded.posDanaList.isEmpty) {
              final totalLegacy = loaded.rekeningPribadi.balance +
                  loaded.onHandDebit.balance +
                  loaded.onHandCash.balance;
              loaded.posDanaList = [
                PosDana(
                  id: 'pos_1',
                  nama: 'Rekening Utama',
                  balance: loaded.rekeningPribadi.balance > 0
                      ? loaded.rekeningPribadi.balance
                      : (totalLegacy > 0 ? totalLegacy : 0),
                  deskripsi: 'Wadah Utama Pemasukan',
                  iconName: 'account_balance',
                ),
                PosDana(
                  id: 'pos_2',
                  nama: 'Dompet & Kas',
                  balance: (loaded.onHandDebit.balance +
                              loaded.onHandCash.balance) >
                          0
                      ? (loaded.onHandDebit.balance + loaded.onHandCash.balance)
                      : 0,
                  deskripsi: 'Dana Operasional & Tunai',
                  iconName: 'wallet',
                ),
                PosDana(
                  id: 'pos_3',
                  nama: 'Tabungan & Darurat',
                  balance: 0,
                  deskripsi: 'Simpanan Pribadi',
                  iconName: 'savings',
                ),
              ];
            }
            setState(() {
              _data = loaded;
              _isLoading = false;
            });
          }
          return;
        }
      } catch (_) {}
    }

    // Fallback template data dari 'pribadi_keuangan_data'
    final templateRaw = prefs.getString('pribadi_keuangan_data');
    if (templateRaw != null) {
      try {
        final decoded = jsonDecode(templateRaw);
        if (decoded is Map<String, dynamic>) {
          final template = PribadiData.fromJson(decoded);
          final newPosList = template.posDanaList.isNotEmpty
              ? template.posDanaList
                  .map((p) => PosDana(
                        id: p.id,
                        nama: p.nama,
                        balance: 0,
                        deskripsi: p.deskripsi,
                        iconName: p.iconName,
                      ))
                  .toList()
              : [
                  PosDana(
                    id: 'pos_1',
                    nama: 'Rekening Utama',
                    balance: 0,
                    deskripsi: 'Wadah Utama Pemasukan',
                    iconName: 'account_balance',
                  ),
                  PosDana(
                    id: 'pos_2',
                    nama: 'Dompet & Kas',
                    balance: 0,
                    deskripsi: 'Dana Operasional & Tunai',
                    iconName: 'wallet',
                  ),
                  PosDana(
                    id: 'pos_3',
                    nama: 'Tabungan & Darurat',
                    balance: 0,
                    deskripsi: 'Simpanan Pribadi',
                    iconName: 'savings',
                  ),
                ];

          final newMonthData = PribadiData(
            posDanaList: newPosList,
            rekeningPribadi: RekeningPribadi(
              bankName: template.rekeningPribadi.bankName,
              accountNumber: template.rekeningPribadi.accountNumber,
              accountHolder: template.rekeningPribadi.accountHolder,
              balance: 0,
            ),
            onHandDebit: OnHandDebit(
              bankName: template.onHandDebit.bankName,
              accountNumber: template.onHandDebit.accountNumber,
              accountHolder: template.onHandDebit.accountHolder,
              balance: 0,
            ),
            onHandCash: OnHandCash(balance: 0),
            transactions: [],
            customKodeRules: List.from(template.customKodeRules),
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
      } catch (_) {}
    }

    // Default data baru
    final defaultData = PribadiData(
      posDanaList: [
        PosDana(
          id: 'pos_1',
          nama: 'Rekening Utama',
          balance: 0,
          deskripsi: 'Wadah Utama Pemasukan',
          iconName: 'account_balance',
        ),
        PosDana(
          id: 'pos_2',
          nama: 'Dompet & Kas',
          balance: 0,
          deskripsi: 'Dana Operasional & Tunai',
          iconName: 'wallet',
        ),
        PosDana(
          id: 'pos_3',
          nama: 'Tabungan & Darurat',
          balance: 0,
          deskripsi: 'Simpanan Pribadi',
          iconName: 'savings',
        ),
      ],
      rekeningPribadi: RekeningPribadi(
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
      customKodeRules: PersonalDefaultRules.defaultRules(),
    );

    if (mounted) {
      setState(() {
        _data = defaultData;
        _isLoading = false;
      });
    }
    await _saveData();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final monthlyKey = 'pribadi_keuangan_data_$_monthKey';
    final jsonStr = jsonEncode(_data.toJson());
    await prefs.setString(monthlyKey, jsonStr);
    await prefs.setString('pribadi_keuangan_data', jsonStr);
  }

  // ==========================================
  // MODAL KELOLA KATEGORI KUSTOM (LIGHT THEMED)
  // ==========================================
  void _showKelolaKustomKodeModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: lightCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Header handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.rule_folder_rounded,
                            color: primaryGreen,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kelola Kategori Pribadi',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),
                              Text(
                                'Aturan otomatisasi kata kunci kategori transaksi',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.file_upload_outlined,
                              color: primaryGreen),
                          tooltip: 'Impor Aturan',
                          onPressed: () {
                            _showImportKustomKodeDialog(
                                modalContext, setModalState);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: textMuted),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: lightBorder, height: 1),
                  Expanded(
                    child: _buildKodeRuleList(
                        'kategori', modalContext, setModalState),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKodeRuleList(
    String type,
    BuildContext modalContext,
    StateSetter setModalState,
  ) {
    final rules = _data.customKodeRules.where((r) => r.type == type).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ${rules.length} Aturan Kategori',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
              Row(
                children: [
                  if (rules.isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_sweep_outlined,
                          size: 16, color: primaryRose),
                      label: const Text(
                        'Reset',
                        style: TextStyle(fontSize: 11, color: primaryRose),
                      ),
                      onPressed: () {
                        _confirmClearAllKodeRules(type, () {
                          setModalState(() {});
                          setState(() {});
                        });
                      },
                    ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: () {
                      _showFormKustomKodeDialog(
                        modalContext,
                        setModalState,
                        defaultType: type,
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Tambah Kategori',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(color: lightBorder, height: 1),
        Expanded(
          child: rules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_rounded,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      const Text(
                        'Belum ada aturan Kategori',
                        style: TextStyle(
                            color: textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: rules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final rule = rules[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: lightCardElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: lightBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: primaryGreen.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Kata Kunci',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: primaryGreen,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      rule.keyword,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: textDark,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Text(
                                      'Kategori: ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: textMuted,
                                      ),
                                    ),
                                    Text(
                                      rule.kode,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 18, color: primaryBlue),
                            tooltip: 'Edit',
                            onPressed: () {
                              _showFormKustomKodeDialog(
                                modalContext,
                                setModalState,
                                existingRule: rule,
                                defaultType: type,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18, color: primaryRose),
                            tooltip: 'Hapus',
                            onPressed: () async {
                              _data.customKodeRules.remove(rule);
                              await _saveData();
                              setModalState(() {});
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showFormKustomKodeDialog(
    BuildContext modalContext,
    StateSetter setModalState, {
    CustomKodeRule? existingRule,
    String defaultType = 'kategori',
  }) {
    final keywordCtrl =
        TextEditingController(text: existingRule?.keyword ?? '');
    final kodeCtrl = TextEditingController(text: existingRule?.kode ?? '');

    showDialog(
      context: modalContext,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: lightCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: lightBorder),
              ),
              title: Text(
                existingRule == null ? 'Tambah Kategori' : 'Edit Kategori',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textDark,
                ),
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kata Kunci (Pemicu)',
                        style: TextStyle(fontSize: 12, color: textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: keywordCtrl,
                      style: const TextStyle(color: textDark, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Contoh: makan, bensin, gaji, wifi',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: lightCardElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: lightBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: lightBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: primaryGreen, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Nama Kategori',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: kodeCtrl,
                      style: const TextStyle(color: textDark, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Contoh: Makanan & Minuman, Transportasi',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: lightCardElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: lightBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: lightBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: primaryGreen, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  child: const Text('Batal',
                      style: TextStyle(color: textMuted)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final kw = keywordCtrl.text.trim();
                    final kd = kodeCtrl.text.trim();
                    if (kw.isEmpty || kd.isEmpty) return;

                    if (existingRule != null) {
                      existingRule.keyword = kw;
                      existingRule.kode = kd;
                      existingRule.type = 'kategori';
                    } else {
                      _data.customKodeRules.add(
                        CustomKodeRule(
                          keyword: kw,
                          kode: kd,
                          type: 'kategori',
                        ),
                      );
                    }
                    await _saveData();
                    if (mounted) {
                      setModalState(() {});
                      setState(() {});
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmClearAllKodeRules(String type, VoidCallback onReset) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder),
        ),
        title: const Text('Reset Aturan Kategori?',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textDark)),
        content: const Text(
          'Seluruh aturan Kategori akan dihapus dan dikembalikan ke daftar kategori bawaan.',
          style: TextStyle(fontSize: 13, color: textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Batal', style: TextStyle(color: textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _data.customKodeRules.removeWhere((r) => r.type == 'kategori');
              final defaults =
                  PersonalDefaultRules.defaultRules().where((r) => r.type == 'kategori');
              _data.customKodeRules.addAll(defaults);
              await _saveData();
              onReset();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Reset Bawaan'),
          ),
        ],
      ),
    );
  }

  void _showImportKustomKodeDialog(
      BuildContext modalContext, StateSetter setModalState) {
    final textCtrl = TextEditingController();

    showDialog(
      context: modalContext,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder),
        ),
        title: const Text('Impor Aturan Kode',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textDark)),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tempel teks atau pilih file Excel (.xlsx / .csv). Format per baris: KataKunci [TAB] Kategori [TAB] Pos',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textCtrl,
                maxLines: 5,
                style: const TextStyle(color: textDark, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'makan\tMakanan & Minuman\npln\tTagihan',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: lightCardElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: lightBorder),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final res = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['xlsx', 'xls', 'csv', 'txt'],
                    withData: true,
                  );
                  if (res != null && res.files.single.bytes != null) {
                    final bytes = res.files.single.bytes!;
                    final parseRes =
                        CustomRuleImportHelper.parseExcelBytes(bytes);
                    if (parseRes.isSuccess && parseRes.rules.isNotEmpty) {
                      _data.customKodeRules.addAll(parseRes.rules);
                      await _saveData();
                      setModalState(() {});
                      setState(() {});
                      if (mounted) {
                        Navigator.pop(dlgCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Berhasil mengimpor ${parseRes.rules.length} aturan!'),
                            backgroundColor: primaryGreen,
                          ),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.file_open_rounded, size: 16),
                label: const Text('Pilih File dari Perangkat',
                    style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryGreen,
                  side: const BorderSide(color: lightBorder),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child:
                const Text('Batal', style: TextStyle(color: textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final raw = textCtrl.text.trim();
              if (raw.isEmpty) return;
              final parseRes = CustomRuleImportHelper.parseText(raw);
              if (parseRes.isSuccess && parseRes.rules.isNotEmpty) {
                _data.customKodeRules.addAll(parseRes.rules);
                await _saveData();
                setModalState(() {});
                setState(() {});
                if (mounted) {
                  Navigator.pop(dlgCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Berhasil mengimpor ${parseRes.rules.length} aturan!'),
                      backgroundColor: primaryGreen,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Proses Teks'),
          ),
        ],
      ),
    );
  }



  // ==========================================
  // MODAL PEMASUKAN DANA PRIBADI
  // ==========================================
  void _showPemasukanDanaModal({String initialTarget = 'rekening'}) {
    final amountCtrl = TextEditingController();
    final keteranganCtrl = TextEditingController();
    String targetAccount = _data.posDanaList.isNotEmpty
        ? _data.posDanaList.first.id
        : initialTarget;
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final autoKode = PribadiTransaction.resolveKodeFromText(
              keteranganCtrl.text,
              customRules: _data.customKodeRules,
            );

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: lightCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
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
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_downward_rounded,
                            color: primaryGreen,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Tambah Pemasukan Pribadi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 1. Pos Dana Tujuan (Berjajar Rapi)
                    const Text('Pos Dana Tujuan',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textMuted)),
                    const SizedBox(height: 8),
                    if (_data.posDanaList.isNotEmpty)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _data.posDanaList.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2.7,
                        ),
                        itemBuilder: (context, index) {
                          final pos = _data.posDanaList[index];
                          final isSelected = targetAccount == pos.id ||
                              targetAccount == pos.nama;

                          return InkWell(
                            onTap: () =>
                                setModalState(() => targetAccount = pos.id),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryGreen.withValues(alpha: 0.12)
                                    : lightCardElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? primaryGreen
                                      : lightBorder,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? primaryGreen.withValues(alpha: 0.2)
                                          : Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.account_balance_wallet_rounded,
                                      size: 14,
                                      color: isSelected
                                          ? primaryGreen
                                          : textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          pos.nama,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            color: isSelected
                                                ? primaryGreen
                                                : textDark,
                                          ),
                                        ),
                                        Text(
                                          'Rp ${RupiahFormatter.format(pos.balance)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isSelected
                                                ? primaryGreen
                                                    .withValues(alpha: 0.85)
                                                : textMuted,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: primaryGreen,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: lightCardElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: lightBorder),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 16, color: primaryBlue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pemasukan akan dicatat ke Pos Dana Default.',
                                style: TextStyle(
                                    fontSize: 11, color: textMuted),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 14),

                    // 2. Input Tanggal
                    const Text('Tanggal',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textMuted)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: lightCardElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: lightBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 15, color: primaryGreen),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat('dd MMMM yyyy')
                                      .format(selectedDate),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: textDark,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(Icons.edit_calendar_rounded,
                                size: 16, color: textMuted),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 3. Input Jumlah
                    const Text('Jumlah',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        RupiahInputFormatter(),
                      ],
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: const TextStyle(
                          color: primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        hintText: '0',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: lightCardElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: lightBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: lightBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: primaryGreen, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 4. Input Keterangan (setelah Jumlah)
                    const Text('Keterangan',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: keteranganCtrl,
                      onChanged: (_) => setModalState(() {}),
                      style: const TextStyle(color: textDark, fontSize: 13),
                      decoration: InputDecoration(
                        hintText:
                            'Contoh: Gaji Bulanan, Bonus Proyek, Freelance, dll',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: lightCardElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: lightBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: lightBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: primaryGreen, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Auto-resolved Category Preview
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: lightCardElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: lightBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              size: 16, color: primaryGreen),
                          const SizedBox(width: 8),
                          const Text('Kategori Auto:',
                              style: TextStyle(
                                  fontSize: 11, color: textMuted)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: primaryGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              autoKode != '-' ? autoKode : 'Umum',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: primaryGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tombol Simpan
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final desc = keteranganCtrl.text.trim();
                          final amt = RupiahFormatter.parse(amountCtrl.text);
                          if (desc.isEmpty || amt <= 0) return;

                          String targetName = targetAccount;
                          if (_data.posDanaList.isNotEmpty) {
                            final idx = _data.posDanaList.indexWhere((p) =>
                                p.id == targetAccount ||
                                p.nama == targetAccount);
                            if (idx != -1) {
                              _data.posDanaList[idx].balance += amt;
                              targetName = _data.posDanaList[idx].nama;
                            } else {
                              _data.posDanaList.first.balance += amt;
                              targetName = _data.posDanaList.first.nama;
                            }
                          }

                          final tx = PribadiTransaction(
                            id: DateTime.now()
                                .microsecondsSinceEpoch
                                .toString(),
                            title: desc,
                            type: 'pemasukan',
                            targetAccount: targetName,
                            amount: amt,
                            note: desc,
                            timestamp: selectedDate,
                            ku: null,
                            kode: autoKode != '-' ? autoKode : null,
                          );

                          _data.transactions.add(tx);
                          await _saveData();
                          if (mounted) {
                            setState(() {});
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Simpan Pemasukan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
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

  // ==========================================
  // MODAL PENGELUARAN DANA PRIBADI
  // ==========================================
  void _showPengeluaranDanaModal({String initialSource = 'rekening'}) {
    final keteranganCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final adminFeeCtrl = TextEditingController();
    String sourceAccount = _data.posDanaList.isNotEmpty
        ? _data.posDanaList.first.id
        : initialSource;
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final autoKode = PribadiTransaction.resolveKodeFromText(
              keteranganCtrl.text,
              customRules: _data.customKodeRules,
            );

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: lightCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
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
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryRose.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            color: primaryRose,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Tambah Pengeluaran Pribadi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 1. Sumber Pos Dana Pengeluaran (GridView Rapi 2 Kolom)
                    const Text('Sumber Pos Dana Pengeluaran',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textMuted)),
                    const SizedBox(height: 8),
                    if (_data.posDanaList.isNotEmpty)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _data.posDanaList.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2.7,
                        ),
                        itemBuilder: (context, index) {
                          final pos = _data.posDanaList[index];
                          final isSelected = sourceAccount == pos.id ||
                              sourceAccount == pos.nama;

                          return InkWell(
                            onTap: () =>
                                setModalState(() => sourceAccount = pos.id),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryRose.withValues(alpha: 0.12)
                                    : lightCardElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? primaryRose
                                      : lightBorder,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? primaryRose.withValues(alpha: 0.2)
                                          : Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.account_balance_wallet_rounded,
                                      size: 14,
                                      color: isSelected
                                          ? primaryRose
                                          : textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          pos.nama,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            color: isSelected
                                                ? primaryRose
                                                : textDark,
                                          ),
                                        ),
                                        Text(
                                          'Rp ${RupiahFormatter.format(pos.balance)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isSelected
                                                ? primaryRose
                                                    .withValues(alpha: 0.85)
                                                : textMuted,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: primaryRose,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: lightCardElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: lightBorder),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 16, color: primaryRose),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pengeluaran akan dipotong dari Pos Dana Default.',
                                style: TextStyle(
                                    fontSize: 11, color: textMuted),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 14),

                    // 2. Input Tanggal (Auto Get Hari Ini)
                    const Text('Tanggal',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textMuted)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: lightCardElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: lightBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 15, color: primaryRose),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat('dd MMMM yyyy')
                                      .format(selectedDate),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: textDark,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(Icons.edit_calendar_rounded,
                                size: 16, color: textMuted),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 3. Input Nominal (Nominal & Biaya Admin)
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nominal Pengeluaran',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textMuted)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: amountCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  RupiahInputFormatter(),
                                ],
                                style: const TextStyle(
                                  color: textDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  prefixText: 'Rp ',
                                  prefixStyle: const TextStyle(
                                      color: primaryRose,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                  hintText: '0',
                                  hintStyle:
                                      const TextStyle(color: Colors.grey),
                                  filled: true,
                                  fillColor: lightCardElevated,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: lightBorder),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: lightBorder),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: primaryRose, width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Biaya Admin',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textMuted)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: adminFeeCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  RupiahInputFormatter(),
                                ],
                                style: const TextStyle(
                                    color: textDark,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  prefixText: 'Rp ',
                                  prefixStyle:
                                      const TextStyle(color: textMuted),
                                  hintText: '0',
                                  hintStyle:
                                      const TextStyle(color: Colors.grey),
                                  filled: true,
                                  fillColor: lightCardElevated,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: lightBorder),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: lightBorder),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: primaryRose, width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 4. Input Keterangan
                    const Text('Keterangan',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: keteranganCtrl,
                      onChanged: (_) => setModalState(() {}),
                      style: const TextStyle(color: textDark, fontSize: 13),
                      decoration: InputDecoration(
                        hintText:
                            'Contoh: Makan Siang, Bensin, Belanja, Tagihan, dll',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: lightCardElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: lightBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: lightBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: primaryRose, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 5. Auto-resolved Category Preview
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: lightCardElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: lightBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              size: 16, color: primaryRose),
                          const SizedBox(width: 8),
                          const Text('Kategori Auto:',
                              style: TextStyle(
                                  fontSize: 11, color: textMuted)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: primaryRose.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              autoKode != '-' ? autoKode : 'Umum',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: primaryRose,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 6. Tombol Simpan Pengeluaran
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final desc = keteranganCtrl.text.trim();
                          final amt = RupiahFormatter.parse(amountCtrl.text);
                          final fee = RupiahFormatter.parse(adminFeeCtrl.text);
                          if (desc.isEmpty || amt <= 0) return;

                          String srcName = sourceAccount;
                          if (_data.posDanaList.isNotEmpty) {
                            final idx = _data.posDanaList.indexWhere((p) =>
                                p.id == sourceAccount ||
                                p.nama == sourceAccount);
                            if (idx != -1) {
                              _data.posDanaList[idx].balance -= (amt + fee);
                              srcName = _data.posDanaList[idx].nama;
                            } else {
                              _data.posDanaList.first.balance -= (amt + fee);
                              srcName = _data.posDanaList.first.nama;
                            }
                          }

                          final tx = PribadiTransaction(
                            id: DateTime.now()
                                .microsecondsSinceEpoch
                                .toString(),
                            title: desc,
                            type: 'pengeluaran',
                            sourceAccount: srcName,
                            amount: amt,
                            adminFee: fee,
                            note: desc,
                            timestamp: selectedDate,
                            ku: null,
                            kode: autoKode != '-' ? autoKode : null,
                          );

                          _data.transactions.add(tx);
                          await _saveData();
                          if (mounted) {
                            setState(() {});
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRose,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Simpan Pengeluaran',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
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

  // ==========================================
  // MODAL DISTRIBUSI / ALOKASI DANA PRIBADI
  // ==========================================
  void _showDistribusiDanaModal() {
    String fromPosId =
        _data.posDanaList.isNotEmpty ? _data.posDanaList.first.id : '';
    String toPosId = _data.posDanaList.length > 1
        ? _data.posDanaList[1].id
        : (_data.posDanaList.isNotEmpty ? _data.posDanaList.first.id : '');
    final amountCtrl = TextEditingController();
    final feeCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final fromPos = _data.posDanaList.firstWhere(
              (p) => p.id == fromPosId,
              orElse: () => _data.posDanaList.first,
            );
            final toPos = _data.posDanaList.firstWhere(
              (p) => p.id == toPosId,
              orElse: () => _data.posDanaList.length > 1
                  ? _data.posDanaList[1]
                  : _data.posDanaList.first,
            );

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: lightCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
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
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.swap_horiz_rounded,
                            color: primaryBlue,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Alokasi & Pindah Saldo Antar Pos',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text('Dari Pos Dana (Sumber)',
                        style: TextStyle(fontSize: 12, color: textMuted)),
                    const SizedBox(height: 6),
                    if (_data.posDanaList.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _data.posDanaList.map((pos) {
                          final isSel = fromPosId == pos.id;
                          return InkWell(
                            onTap: () =>
                                setModalState(() => fromPosId = pos.id),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? primaryBlue.withValues(alpha: 0.15)
                                    : lightCardElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSel ? primaryBlue : lightBorder,
                                ),
                              ),
                              child: Text(
                                pos.nama,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSel ? primaryBlue : textDark,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 14),
                    const Text('Ke Pos Dana (Tujuan)',
                        style: TextStyle(fontSize: 12, color: textMuted)),
                    const SizedBox(height: 6),
                    if (_data.posDanaList.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _data.posDanaList.map((pos) {
                          final isSel = toPosId == pos.id;
                          return InkWell(
                            onTap: () =>
                                setModalState(() => toPosId = pos.id),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? primaryGreen.withValues(alpha: 0.15)
                                    : lightCardElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSel ? primaryGreen : lightBorder,
                                ),
                              ),
                              child: Text(
                                pos.nama,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSel ? primaryGreen : textDark,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: lightCardElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: lightBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(fromPos.nama,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textDark)),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 16, color: primaryBlue),
                          const SizedBox(width: 12),
                          Text(toPos.nama,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryGreen)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Nominal Alokasi',
                        style: TextStyle(fontSize: 12, color: textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        RupiahInputFormatter(),
                      ],
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: const TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.bold),
                        hintText: '0',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: lightCardElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: lightBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Biaya Admin (Bila Ada)',
                        style: TextStyle(fontSize: 12, color: textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: feeCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        RupiahInputFormatter(),
                      ],
                      style: const TextStyle(
                          color: textDark, fontSize: 13),
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: const TextStyle(color: textMuted),
                        hintText: '0',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: lightCardElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: lightBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Catatan / Keterangan',
                        style: TextStyle(fontSize: 12, color: textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteCtrl,
                      style: const TextStyle(color: textDark, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Keterangan alokasi saldo...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: lightCardElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: lightBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final amt = RupiahFormatter.parse(amountCtrl.text);
                          final fee = RupiahFormatter.parse(feeCtrl.text);
                          if (amt <= 0 || fromPosId == toPosId) return;

                          fromPos.balance -= (amt + fee);
                          toPos.balance += amt;

                          final tx = PribadiTransaction(
                            id: DateTime.now()
                                .microsecondsSinceEpoch
                                .toString(),
                            title:
                                'Pindah Saldo (${fromPos.nama} -> ${toPos.nama})',
                            type: 'transfer_pos',
                            sourceAccount: fromPos.nama,
                            targetAccount: toPos.nama,
                            amount: amt,
                            adminFee: fee,
                            note: noteCtrl.text.trim().isNotEmpty
                                ? noteCtrl.text.trim()
                                : null,
                            kode: 'Mutasi Internal',
                            ku: 'Alokasi Pos Dana',
                          );

                          _data.transactions.add(tx);
                          await _saveData();
                          if (mounted) {
                            setState(() {});
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Proses Alokasi Saldo',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
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



  // ==========================================
  // MODAL EDIT TRANSAKSI
  // ==========================================
  void _showEditTransactionModal(
      PribadiTransaction tx, [VoidCallback? onSaved]) {
    final titleCtrl = TextEditingController(text: tx.title);
    final amountCtrl = TextEditingController(
        text: tx.amount > 0 ? RupiahFormatter.format(tx.amount) : '');
    final adminFeeCtrl = TextEditingController(
        text: tx.adminFee > 0 ? RupiahFormatter.format(tx.adminFee) : '0');
    final noteCtrl = TextEditingController(text: tx.note ?? '');
    final kodeCtrl = TextEditingController(text: tx.kode ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: lightCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Edit Transaksi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Judul Transaksi',
                    style: TextStyle(fontSize: 12, color: textMuted)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: textDark, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: lightCardElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: lightBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nominal',
                              style:
                                  TextStyle(fontSize: 12, color: textMuted)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: amountCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              RupiahInputFormatter(),
                            ],
                            style: const TextStyle(
                                color: textDark,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              prefixText: 'Rp ',
                              prefixStyle: const TextStyle(
                                  color: primaryGreen,
                                  fontWeight: FontWeight.bold),
                              filled: true,
                              fillColor: lightCardElevated,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: lightBorder),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Admin Fee',
                              style:
                                  TextStyle(fontSize: 12, color: textMuted)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: adminFeeCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              RupiahInputFormatter(),
                            ],
                            style: const TextStyle(
                                color: textDark, fontSize: 13),
                            decoration: InputDecoration(
                              prefixText: 'Rp ',
                              prefixStyle: const TextStyle(color: textMuted),
                              filled: true,
                              fillColor: lightCardElevated,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: lightBorder),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Kategori',
                    style: TextStyle(fontSize: 12, color: textMuted)),
                const SizedBox(height: 6),
                TextField(
                  controller: kodeCtrl,
                  style: const TextStyle(
                      color: textDark, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Contoh: Makanan & Minuman, Gaji, dll',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: lightCardElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: lightBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Catatan',
                    style: TextStyle(fontSize: 12, color: textMuted)),
                const SizedBox(height: 6),
                TextField(
                  controller: noteCtrl,
                  style: const TextStyle(color: textDark, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: lightCardElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: lightBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final newAmt = RupiahFormatter.parse(amountCtrl.text);
                      final newFee = RupiahFormatter.parse(adminFeeCtrl.text);
                      final newTitle = titleCtrl.text.trim();
                      if (newTitle.isEmpty || newAmt <= 0) return;

                      final updatedTx = PribadiTransaction(
                        id: tx.id,
                        title: newTitle,
                        type: tx.type,
                        sourceAccount: tx.sourceAccount,
                        targetAccount: tx.targetAccount,
                        manualSource: tx.manualSource,
                        amount: newAmt,
                        adminFee: newFee,
                        timestamp: tx.timestamp,
                        note: noteCtrl.text.trim().isNotEmpty
                            ? noteCtrl.text.trim()
                            : null,
                        ku: null,
                        kode: kodeCtrl.text.trim().isNotEmpty
                            ? kodeCtrl.text.trim()
                            : null,
                      );

                      // 1. Rollback saldo dari transaksi lama
                      _rollbackTransactionBalance(tx);

                      // 2. Terapkan saldo dari transaksi baru
                      _applyTransactionBalance(updatedTx);

                      // 3. Sanitasi & proteksi batas saldo (Manajemen Risiko anti-minus)
                      _sanitizeAllBalances();

                      final idx =
                          _data.transactions.indexWhere((t) => t.id == tx.id);
                      if (idx != -1) {
                        _data.transactions[idx] = updatedTx;
                      }

                      await _saveData();
                      if (mounted) {
                        setState(() {});
                        onSaved?.call();
                        Navigator.of(context).pop();
                        CustomToast.showSuccess(
                          context,
                          title: 'Transaksi Diperbarui',
                          subtitle:
                              'Perubahan transaksi & saldo berhasil disimpan.',
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Simpan Perubahan',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- LOGIKA ROLLBACK SALDO TRANSAKSI (MANAJEMEN RISIKO) ---
  void _rollbackTransactionBalance(PribadiTransaction tx) {
    final total = tx.amount + tx.adminFee;
    if (tx.isPemasukan) {
      // Pemasukan menambah saldo target, jadi saat rollback kita kurangi dari target
      bool handled = false;
      if (_data.posDanaList.isNotEmpty) {
        final posIdx = _data.posDanaList.indexWhere(
            (p) => p.nama == tx.targetAccount || p.id == tx.targetAccount);
        if (posIdx != -1) {
          _data.posDanaList[posIdx].balance -= tx.amount;
          if (_data.posDanaList[posIdx].balance < 0) {
            _data.posDanaList[posIdx].balance = 0;
          }
          handled = true;
        }
      }
      if (!handled) {
        if (tx.targetAccount == 'rekening') {
          _data.rekeningPribadi.balance -= tx.amount;
          if (_data.rekeningPribadi.balance < 0) {
            _data.rekeningPribadi.balance = 0;
          }
        } else if (tx.targetAccount == 'debit') {
          _data.onHandDebit.balance -= tx.amount;
          if (_data.onHandDebit.balance < 0) {
            _data.onHandDebit.balance = 0;
          }
        } else if (tx.targetAccount == 'cash') {
          _data.onHandCash.balance -= tx.amount;
          if (_data.onHandCash.balance < 0) {
            _data.onHandCash.balance = 0;
          }
        } else if (_data.posDanaList.isNotEmpty) {
          _data.posDanaList.first.balance -= tx.amount;
          if (_data.posDanaList.first.balance < 0) {
            _data.posDanaList.first.balance = 0;
          }
        }
      }
    } else if (tx.isPengeluaran) {
      // Pengeluaran memotong saldo source, jadi saat rollback kita kembalikan ke source
      bool handled = false;
      if (_data.posDanaList.isNotEmpty) {
        final posIdx = _data.posDanaList.indexWhere(
            (p) => p.nama == tx.sourceAccount || p.id == tx.sourceAccount);
        if (posIdx != -1) {
          _data.posDanaList[posIdx].balance += total;
          handled = true;
        }
      }
      if (!handled) {
        if (tx.sourceAccount == 'rekening') {
          _data.rekeningPribadi.balance += total;
        } else if (tx.sourceAccount == 'debit') {
          _data.onHandDebit.balance += total;
        } else if (tx.sourceAccount == 'cash') {
          _data.onHandCash.balance += total;
        } else if (_data.posDanaList.isNotEmpty) {
          _data.posDanaList.first.balance += total;
        }
      }
    } else {
      // Transfer / Alokasi internal:
      // Kembalikan ke source (tambah)
      bool srcHandled = false;
      if (_data.posDanaList.isNotEmpty) {
        final srcIdx = _data.posDanaList.indexWhere(
            (p) => p.nama == tx.sourceAccount || p.id == tx.sourceAccount);
        if (srcIdx != -1) {
          _data.posDanaList[srcIdx].balance += total;
          srcHandled = true;
        }
      }
      if (!srcHandled) {
        if (tx.sourceAccount == 'rekening') {
          _data.rekeningPribadi.balance += total;
        } else if (tx.sourceAccount == 'debit') {
          _data.onHandDebit.balance += total;
        } else if (tx.sourceAccount == 'cash') {
          _data.onHandCash.balance += total;
        } else if (_data.posDanaList.isNotEmpty) {
          _data.posDanaList.first.balance += total;
        }
      }

      // Kurangi dari target (kurang)
      bool tgtHandled = false;
      if (_data.posDanaList.isNotEmpty) {
        final tgtIdx = _data.posDanaList.indexWhere(
            (p) => p.nama == tx.targetAccount || p.id == tx.targetAccount);
        if (tgtIdx != -1) {
          _data.posDanaList[tgtIdx].balance -= tx.amount;
          if (_data.posDanaList[tgtIdx].balance < 0) {
            _data.posDanaList[tgtIdx].balance = 0;
          }
          tgtHandled = true;
        }
      }
      if (!tgtHandled) {
        if (tx.targetAccount == 'rekening') {
          _data.rekeningPribadi.balance -= tx.amount;
          if (_data.rekeningPribadi.balance < 0) {
            _data.rekeningPribadi.balance = 0;
          }
        } else if (tx.targetAccount == 'debit') {
          _data.onHandDebit.balance -= tx.amount;
          if (_data.onHandDebit.balance < 0) {
            _data.onHandDebit.balance = 0;
          }
        } else if (tx.targetAccount == 'cash') {
          _data.onHandCash.balance -= tx.amount;
          if (_data.onHandCash.balance < 0) {
            _data.onHandCash.balance = 0;
          }
        } else if (_data.posDanaList.isNotEmpty) {
          _data.posDanaList.first.balance -= tx.amount;
          if (_data.posDanaList.first.balance < 0) {
            _data.posDanaList.first.balance = 0;
          }
        }
      }
    }
  }

  // --- LOGIKA MENERAPKAN SALDO TRANSAKSI BARU ---
  void _applyTransactionBalance(PribadiTransaction tx) {
    final total = tx.amount + tx.adminFee;
    if (tx.isPemasukan) {
      bool handled = false;
      if (_data.posDanaList.isNotEmpty) {
        final posIdx = _data.posDanaList.indexWhere(
            (p) => p.nama == tx.targetAccount || p.id == tx.targetAccount);
        if (posIdx != -1) {
          _data.posDanaList[posIdx].balance += tx.amount;
          handled = true;
        }
      }
      if (!handled) {
        if (tx.targetAccount == 'rekening') {
          _data.rekeningPribadi.balance += tx.amount;
        } else if (tx.targetAccount == 'debit') {
          _data.onHandDebit.balance += tx.amount;
        } else if (tx.targetAccount == 'cash') {
          _data.onHandCash.balance += tx.amount;
        } else if (_data.posDanaList.isNotEmpty) {
          _data.posDanaList.first.balance += tx.amount;
        }
      }
    } else if (tx.isPengeluaran) {
      bool handled = false;
      if (_data.posDanaList.isNotEmpty) {
        final posIdx = _data.posDanaList.indexWhere(
            (p) => p.nama == tx.sourceAccount || p.id == tx.sourceAccount);
        if (posIdx != -1) {
          _data.posDanaList[posIdx].balance -= total;
          if (_data.posDanaList[posIdx].balance < 0) {
            _data.posDanaList[posIdx].balance = 0;
          }
          handled = true;
        }
      }
      if (!handled) {
        if (tx.sourceAccount == 'rekening') {
          _data.rekeningPribadi.balance -= total;
          if (_data.rekeningPribadi.balance < 0) {
            _data.rekeningPribadi.balance = 0;
          }
        } else if (tx.sourceAccount == 'debit') {
          _data.onHandDebit.balance -= total;
          if (_data.onHandDebit.balance < 0) {
            _data.onHandDebit.balance = 0;
          }
        } else if (tx.sourceAccount == 'cash') {
          _data.onHandCash.balance -= total;
          if (_data.onHandCash.balance < 0) {
            _data.onHandCash.balance = 0;
          }
        } else if (_data.posDanaList.isNotEmpty) {
          _data.posDanaList.first.balance -= total;
          if (_data.posDanaList.first.balance < 0) {
            _data.posDanaList.first.balance = 0;
          }
        }
      }
    }
  }

  // --- MANAJEMEN RISIKO: SANITASI SELURUH SALDO AGAR TIDAK ADA YANG MINUS (< 0) ---
  void _sanitizeAllBalances() {
    for (final pos in _data.posDanaList) {
      if (pos.balance < 0) pos.balance = 0;
    }
    if (_data.rekeningPribadi.balance < 0) _data.rekeningPribadi.balance = 0;
    if (_data.onHandDebit.balance < 0) _data.onHandDebit.balance = 0;
    if (_data.onHandCash.balance < 0) _data.onHandCash.balance = 0;
  }

  void _confirmDeleteTransaction(PribadiTransaction tx,
      [VoidCallback? onDeleted]) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder),
        ),
        title: const Text('Hapus Transaksi?',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textDark)),
        content: Text(
          'Transaksi "${tx.title}" sebesar ${RupiahFormatter.format(tx.amount)} akan dihapus dan saldo akun akan disesuaikan kembali.',
          style: const TextStyle(fontSize: 13, color: textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Batal', style: TextStyle(color: textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);

              // 1. Rollback saldo transaksi yang dihapus
              _rollbackTransactionBalance(tx);

              // 2. Sanitasi saldo dari nilai negatif
              _sanitizeAllBalances();

              _data.transactions.removeWhere((t) => t.id == tx.id);
              await _saveData();
              if (mounted) {
                setState(() {});
                onDeleted?.call();
                CustomToast.showSuccess(
                  context,
                  title: 'Transaksi Dihapus',
                  subtitle:
                      'Transaksi "${tx.title}" berhasil dihapus & saldo dipulihkan.',
                  icon: Icons.delete_outline_rounded,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRose,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // --- DIALOG KONFIRMASI HAPUS & ROLLBACK SEMUA TRANSAKSI BULAN INI ---
  void _confirmDeleteAllTransactions([VoidCallback? onDeleted]) {
    final txList = _data.transactions;
    if (txList.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryRose.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_sweep_rounded,
                  color: primaryRose, size: 20),
            ),
            const SizedBox(width: 8),
            const Text(
              'Hapus Semua Transaksi?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textDark,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin menghapus seluruh (${txList.length}) transaksi pada bulan ${_namaBulan[_selectedMonth.month - 1]} ${_selectedMonth.year}?',
              style: const TextStyle(fontSize: 13, color: textDark),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Seluruh saldo akun dan pos dana akan dipulihkan (rollback) secara aman dan tidak akan menghasilkan saldo negatif.',
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
            child: const Text('Batal', style: TextStyle(color: textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final deletedCount = _data.transactions.length;

              // 1. Rollback saldo seluruh transaksi secara aman dari transaksi terakhir
              for (final tx in _data.transactions.reversed) {
                _rollbackTransactionBalance(tx);
              }

              // 2. Sanitasi & proteksi anti-minus seluruh wadah dana
              _sanitizeAllBalances();

              // 3. Bersihkan seluruh transaksi
              _data.transactions.clear();
              await _saveData();
              if (mounted) {
                setState(() {});
                onDeleted?.call();
                CustomToast.showSuccess(
                  context,
                  title: 'Semua Transaksi Dihapus',
                  subtitle:
                      '$deletedCount transaksi berhasil dihapus & saldo dipulihkan dengan aman.',
                  icon: Icons.delete_sweep_rounded,
                );
              }
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text('Hapus Semua'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // UI BUILD METHODS (LIGHT THEMED)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final monthLabel =
        '${_namaBulan[_selectedMonth.month - 1]} ${_selectedMonth.year}';

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: primaryDark,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Keuangan Pribadi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.rule_folder_rounded, color: Colors.white),
            tooltip: 'Kelola Kategori',
            onPressed: _showKelolaKustomKodeModal,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
            tooltip: 'Pilih Bulan',
            onPressed: _showMonthYearPicker,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryBlue))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: primaryBlue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMonthSelectorBar(monthLabel),
                    const SizedBox(height: 12),
                    _buildTotalBanner(),
                    const SizedBox(height: 12),
                    _buildActionButtonsHub(),
                    const SizedBox(height: 12),
                    _buildCardPosDana(),
                    const SizedBox(height: 18),
                    _buildTabelKeuangan(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMonthSelectorBar(String monthLabel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: textDark),
            onPressed: _prevMonth,
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: InkWell(
                onTap: _showMonthYearPicker,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 15, color: primaryBlue),
                      const SizedBox(width: 8),
                      Text(
                        monthLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: textDark),
            onPressed: _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalBanner() {
    final monthName = _namaBulan[_selectedMonth.month - 1];
    final year = _selectedMonth.year;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF312E81), // Royal Indigo 900
            Color(0xFF1E1B4B), // Midnight Indigo
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_rounded,
                          size: 12, color: Colors.white70),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'TOTAL DANA PRIBADI ($monthName $year)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white70, size: 22),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Rp ${RupiahFormatter.format(_data.totalDanaPribadi)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Monthly Inflow & Outflow Chips (Pemasukan & Pengeluaran Per Bulan)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_downward_rounded,
                            size: 15, color: Color(0xFF34D399)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pemasukan',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '+Rp ${RupiahFormatter.format(_data.totalPemasukan)}',
                                style: const TextStyle(
                                  color: Color(0xFF34D399),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF43F5E).withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_upward_rounded,
                            size: 15, color: Color(0xFFFB7185)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pengeluaran',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '-Rp ${RupiahFormatter.format(_data.totalPengeluaran)}',
                                style: const TextStyle(
                                  color: Color(0xFFFB7185),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CARD POS DANA
  // ==========================================
  Widget _buildCardPosDana() {
    return Container(
      decoration: BoxDecoration(
        color: lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _showKelolaPosDanaModal,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.folder_special_rounded,
                          color: primaryBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pos Dana',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_data.posDanaList.length} Pos Dana Terdaftar',
                              style: const TextStyle(
                                fontSize: 11,
                                color: textMuted,
                                fontWeight: FontWeight.w500,
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
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: lightCardElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: lightBorder),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded,
                          size: 12, color: primaryBlue),
                      SizedBox(width: 4),
                      Text(
                        'Kelola',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MODAL KELOLA POS DANA (WADAH PEMASUKAN)
  // ==========================================
  void _showKelolaPosDanaModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 16,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: lightCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
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
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.folder_special_rounded,
                              color: primaryGreen,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pos Dana',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),
                              Text(
                                '${_data.posDanaList.length} Pos • Rp ${RupiahFormatter.format(_data.totalPosDana)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (_data.posDanaList.length >= 2) ...[
                            IconButton(
                              onPressed: () {
                                _showDistribusiDanaModal();
                              },
                              icon: const Icon(Icons.swap_horiz_rounded,
                                  color: primaryBlue, size: 20),
                              tooltip: 'Pindah Saldo Antar Pos',
                            ),
                            const SizedBox(width: 4),
                          ],
                          ElevatedButton.icon(
                            onPressed: () {
                              _showTambahEditPosDanaDialog(onSaved: () {
                                setModalState(() {});
                                setState(() {});
                              });
                            },
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Tambah Pos'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_data.posDanaList.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          const Icon(Icons.inbox_rounded,
                              size: 48, color: textMuted),
                          const SizedBox(height: 8),
                          const Text(
                            'Belum ada Pos Dana',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tambahkan Pos Dana untuk mulai mencatat pemasukan & mengelompokkan saldo Anda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _data.posDanaList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final pos = _data.posDanaList[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: lightCardElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: lightBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: primaryGreen.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    size: 18,
                                    color: primaryGreen,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pos.nama,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Rp ${RupiahFormatter.format(pos.balance)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: primaryGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18, color: textMuted),
                                  onPressed: () {
                                    _showTambahEditPosDanaDialog(
                                      pos: pos,
                                      onSaved: () {
                                        setModalState(() {});
                                        setState(() {});
                                      },
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 18, color: primaryRose),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        backgroundColor: lightCard,
                                        title: const Text('Hapus Pos Dana?'),
                                        content: Text(
                                            'Yakin ingin menghapus pos "${pos.nama}"?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: const Text('Batal'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryRose,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Hapus'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      _data.posDanaList.removeWhere(
                                          (p) => p.id == pos.id);
                                      await _saveData();
                                      setModalState(() {});
                                      setState(() {});
                                    }
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

  void _showTambahEditPosDanaDialog({PosDana? pos, VoidCallback? onSaved}) {
    final isEdit = pos != null;
    final namaCtrl = TextEditingController(text: isEdit ? pos.nama : '');
    final saldoCtrl = TextEditingController(
        text: isEdit && pos.balance > 0 ? RupiahFormatter.format(pos.balance) : '0');
    final descCtrl =
        TextEditingController(text: isEdit ? (pos.deskripsi ?? '') : '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            isEdit ? 'Edit Pos Dana' : 'Tambah Pos Dana Baru',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nama Pos Dana',
                    style: TextStyle(fontSize: 12, color: textMuted)),
                const SizedBox(height: 6),
                TextField(
                  controller: namaCtrl,
                  style: const TextStyle(color: textDark, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Contoh: Tabungan, Gaji, Kas Harian, dll',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: lightCardElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: lightBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Saldo Pos Dana',
                    style: TextStyle(fontSize: 12, color: textMuted)),
                const SizedBox(height: 6),
                TextField(
                  controller: saldoCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    RupiahInputFormatter(),
                  ],
                  style: const TextStyle(
                      color: textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    prefixStyle: const TextStyle(
                        color: primaryGreen, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: lightCardElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: lightBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Deskripsi / Keterangan (Opsional)',
                    style: TextStyle(fontSize: 12, color: textMuted)),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: textDark, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Keterangan wadah dana...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: lightCardElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: lightBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final nama = namaCtrl.text.trim();
                if (nama.isEmpty) return;
                final saldo = RupiahFormatter.parse(saldoCtrl.text);
                final desc = descCtrl.text.trim().isNotEmpty
                    ? descCtrl.text.trim()
                    : null;

                if (isEdit) {
                  pos.nama = nama;
                  pos.balance = saldo;
                  pos.deskripsi = desc;
                } else {
                  _data.posDanaList.add(
                    PosDana(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      nama: nama,
                      balance: saldo,
                      deskripsi: desc,
                    ),
                  );
                }

                await _saveData();
                if (mounted) {
                  Navigator.pop(ctx);
                  onSaved?.call();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtonsHub() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _showPemasukanDanaModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Pemasukan',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () =>
                _showPengeluaranDanaModal(initialSource: 'rekening'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRose,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Pengeluaran',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TABEL TRANSAKSI KEUANGAN PRIBADI (PREVIEW 3 BARIS)
  // ==========================================
  Widget _buildTabelKeuangan() {
    final allTransactions = _data.transactions.reversed.toList();
    final previewTransactions = allTransactions.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Kartu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.table_chart_rounded,
                        color: primaryBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DAFTAR TRANSAKSI',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${allTransactions.length} Transaksi Tercatat',
                            style: const TextStyle(
                              fontSize: 11,
                              color: textMuted,
                              fontWeight: FontWeight.w500,
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
              const SizedBox(width: 8),
              if (allTransactions.isNotEmpty)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _confirmDeleteAllTransactions(),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryRose.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: primaryRose.withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_sweep_rounded,
                              size: 15, color: primaryRose),
                          SizedBox(width: 4),
                          Text(
                            'Hapus Semua',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primaryRose,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Tampilan Data Tabel
          if (allTransactions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              decoration: BoxDecoration(
                color: lightCardElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: lightBorder),
              ),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_rounded,
                      size: 44, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  const Text(
                    'Belum ada transaksi di bulan ini',
                    style: TextStyle(
                      color: textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Klik tombol Pemasukan atau Pengeluaran di atas untuk mencatat transaksi baru.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: textMuted),
                  ),
                ],
              ),
            )
          else ...[
            // Header Tabel
            _buildTransactionTableHeader(),
            const SizedBox(height: 6),

            // Baris Data Preview (Maksimal 3 Baris)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: previewTransactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final tx = previewTransactions[index];
                return _buildTransactionTableRow(tx, onRefresh: () {
                  setState(() {});
                });
              },
            ),

            const SizedBox(height: 12),

            // Tombol Menu Detail Tabel
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showDetailTabelModal,
                icon: const Icon(Icons.table_rows_rounded, size: 16),
                label: Text(
                  'Buka Detail Tabel Transaksi (${allTransactions.length})',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: lightCardElevated,
                  foregroundColor: primaryBlue,
                  elevation: 0,
                  side: const BorderSide(color: lightBorder),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // KOMPONEN HEADER TABEL TRANSAKSI (5 KOLOM)
  // tanggal | kategori | jumlah | tipe | aksi
  // ==========================================
  Widget _buildTransactionTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: lightCardElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: lightBorder),
      ),
      child: const Row(
        children: [
          // 1. Tanggal
          SizedBox(
            width: 72,
            child: Text(
              'TANGGAL',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(width: 6),
          // 2. Kategori
          Expanded(
            flex: 4,
            child: Text(
              'KATEGORI',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(width: 6),
          // 3. Jumlah
          Expanded(
            flex: 4,
            child: Text(
              'JUMLAH',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(width: 8),
          // 4. Tipe (Debit / Kredit)
          SizedBox(
            width: 62,
            child: Center(
              child: Text(
                'TIPE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SizedBox(width: 6),
          // 5. Aksi
          SizedBox(
            width: 58,
            child: Center(
              child: Text(
                'AKSI',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // KOMPONEN BARIS TABEL TRANSAKSI (5 KOLOM)
  // ==========================================
  Widget _buildTransactionTableRow(PribadiTransaction tx,
      {VoidCallback? onRefresh}) {
    final isPemasukan = tx.isPemasukan;
    final isPengeluaran = tx.isPengeluaran;
    final isDebit = isPemasukan;
    final typeLabel = isDebit ? 'Debit' : 'Kredit';
    final typeColor = isDebit ? primaryGreen : primaryRose;
    final amountColor = isDebit ? primaryGreen : (isPengeluaran ? primaryRose : primaryBlue);
    final dateFormatted = DateFormat('dd/MM/yy').format(tx.timestamp);
    final rawKategori = tx.getDisplayKode(customRules: _data.customKodeRules);
    final displayKategori =
        (rawKategori != '-' && rawKategori.trim().isNotEmpty)
            ? rawKategori
            : 'Umum';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: lightCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: lightBorder),
      ),
      child: Row(
        children: [
          // 1. Kolom Tanggal
          SizedBox(
            width: 72,
            child: Text(
              dateFormatted,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // 2. Kolom Kategori (Custom Pengguna)
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    displayKategori,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                ),
                if (tx.title.isNotEmpty && tx.title != displayKategori) ...[
                  const SizedBox(height: 2),
                  Text(
                    tx.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          // 3. Kolom Jumlah
          Expanded(
            flex: 4,
            child: Text(
              '${isPemasukan ? '+' : (isPengeluaran ? '-' : '')}${RupiahFormatter.format(tx.amount)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 4. Kolom Tipe (Debit / Kredit)
          SizedBox(
            width: 62,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: typeColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // 5. Kolom Aksi (Edit & Hapus)
          SizedBox(
            width: 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () => _showEditTransactionModal(tx, onRefresh),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.edit_outlined,
                        size: 16, color: primaryBlue),
                  ),
                ),
                const SizedBox(width: 2),
                InkWell(
                  onTap: () => _confirmDeleteTransaction(tx, onRefresh),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 16, color: primaryRose),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MODAL MENU DETAIL TABEL TRANSAKSI
  // ==========================================
  void _showDetailTabelModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final transactions = _getFilteredTransactions();

            // Hitung total ringkasan
            int totalDebit = 0;
            int totalKredit = 0;
            for (final t in _data.transactions) {
              if (t.isPemasukan) {
                totalDebit += t.amount;
              } else if (t.isPengeluaran) {
                totalKredit += t.amount;
              }
            }
            final saldoBersih = totalDebit - totalKredit;

            return Container(
              height: MediaQuery.of(context).size.height * 0.90,
              decoration: const BoxDecoration(
                color: lightCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle Bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header Modal
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.table_chart_rounded,
                            color: primaryBlue,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Detail Tabel Transaksi',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),
                              Text(
                                '${_namaBulan[_selectedMonth.month - 1]} ${_selectedMonth.year} • ${transactions.length} Transaksi',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: textMuted),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: lightBorder, height: 1),

                  // Ringkasan Debit / Kredit Banner
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: lightCardElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: lightBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Debit',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '+ Rp ${RupiahFormatter.format(totalDebit)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 28,
                            width: 1,
                            color: lightBorder,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Kredit',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '- Rp ${RupiahFormatter.format(totalKredit)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: primaryRose,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 28,
                            width: 1,
                            color: lightBorder,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Selisih Bersih',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Rp ${RupiahFormatter.format(saldoBersih)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: saldoBersih >= 0
                                        ? primaryGreen
                                        : primaryRose,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Filter & Search Controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Filter Chips (Semua, Debit, Kredit, Kategori)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildModalFilterChip(
                                  'Semua', 'semua', setModalState),
                              _buildModalFilterChip(
                                  'Debit', 'pemasukan', setModalState),
                              _buildModalFilterChip(
                                  'Kredit', 'pengeluaran', setModalState),
                              _buildModalFilterChip(
                                  'Kategori', 'kategori', setModalState),
                            ],
                          ),
                        ),
                        if (_selectedFilter != 'kategori') ...[
                          const SizedBox(height: 8),
                          // Search Bar & Tombol Sort
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  style: const TextStyle(
                                      color: textDark, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Cari kategori, judul, atau catatan...',
                                    hintStyle:
                                        const TextStyle(color: Colors.grey),
                                    prefixIcon: const Icon(
                                        Icons.search_rounded,
                                        size: 18,
                                        color: textMuted),
                                    filled: true,
                                    fillColor: lightCardElevated,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide:
                                          const BorderSide(color: lightBorder),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide:
                                          const BorderSide(color: lightBorder),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: primaryBlue, width: 1.5),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                  onChanged: (val) {
                                    setModalState(() {
                                      _searchQuery = val.trim().toLowerCase();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  setModalState(() {
                                    _isSortAscending = !_isSortAscending;
                                  });
                                  setState(() {});
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _isSortAscending
                                        ? primaryBlue.withValues(alpha: 0.12)
                                        : lightCardElevated,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _isSortAscending
                                          ? primaryBlue
                                          : lightBorder,
                                    ),
                                  ),
                                  child: Icon(
                                    _isSortAscending
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded,
                                    size: 18,
                                    color: _isSortAscending
                                        ? primaryBlue
                                        : textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Konten Berdasarkan Tab: Kategori (2 Tabel) atau Transaksi (Tabel 5 Kolom)
                  if (_selectedFilter == 'kategori')
                    Expanded(
                      child: _buildCategorySummaryTables(
                        totalDebit: totalDebit,
                        totalKredit: totalKredit,
                      ),
                    )
                  else ...[
                    // Header Tabel Tetap
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildTransactionTableHeader(),
                    ),

                    const SizedBox(height: 6),

                    // Data Tabel Lengkap
                    Expanded(
                      child: transactions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.receipt_long_rounded,
                                      size: 48, color: Colors.grey[300]),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Tidak ada transaksi yang cocok',
                                    style: TextStyle(
                                      color: textMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              itemCount: transactions.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final tx = transactions[index];
                                return _buildTransactionTableRow(
                                  tx,
                                  onRefresh: () {
                                    setModalState(() {});
                                    setState(() {});
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // TABEL RINGKASAN KATEGORI (2 TABEL: PEMASUKAN & PENGELUARAN)
  // ==========================================
  Widget _buildCategorySummaryTables({
    required int totalDebit,
    required int totalKredit,
  }) {
    // 1. Agregasi Pemasukan berdasarkan Kategori
    final Map<String, int> pemasukanByCat = {};
    for (final t in _data.transactions) {
      if (t.isPemasukan && t.amount > 0) {
        final rawCat = t.getDisplayKode(customRules: _data.customKodeRules);
        final catName = (rawCat != '-' && rawCat.trim().isNotEmpty)
            ? rawCat.trim()
            : 'Umum';
        pemasukanByCat[catName] = (pemasukanByCat[catName] ?? 0) + t.amount;
      }
    }
    // Filter kategori yang jumlahnya > 0
    final pemasukanEntries = pemasukanByCat.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 2. Agregasi Pengeluaran berdasarkan Kategori
    final Map<String, int> pengeluaranByCat = {};
    for (final t in _data.transactions) {
      if (t.isPengeluaran && t.amount > 0) {
        final rawCat = t.getDisplayKode(customRules: _data.customKodeRules);
        final catName = (rawCat != '-' && rawCat.trim().isNotEmpty)
            ? rawCat.trim()
            : 'Umum';
        pengeluaranByCat[catName] = (pengeluaranByCat[catName] ?? 0) + t.amount;
      }
    }
    // Filter kategori yang jumlahnya > 0
    final pengeluaranEntries = pengeluaranByCat.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // ==========================================
        // TABEL 1: PEMASUKAN (BERDASARKAN KATEGORI)
        // ==========================================
        Container(
          decoration: BoxDecoration(
            color: lightCardElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card Pemasukan
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: primaryGreen.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                  border: const Border(bottom: BorderSide(color: lightBorder)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: primaryGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.arrow_downward_rounded,
                          size: 14, color: primaryGreen),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Tabel Pemasukan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
              ),

              // Header Kolom (2 Kolom: Kategori & Jumlah)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  color: lightCard,
                  border: Border(bottom: BorderSide(color: lightBorder)),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Text(
                        'KATEGORI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'JUMLAH',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Baris Data Pemasukan
              if (pemasukanEntries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 14),
                  child: Center(
                    child: Text(
                      'Tidak ada pemasukan tercatat di bulan ini',
                      style: TextStyle(fontSize: 11.5, color: textMuted),
                    ),
                  ),
                )
              else
                ...pemasukanEntries.map((entry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: lightBorder)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: const BoxDecoration(
                                  color: primaryGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            '+ Rp ${RupiahFormatter.format(entry.value)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              // Total Pemasukan Row
              if (pemasukanEntries.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: primaryGreen.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 6,
                        child: Text(
                          'Total Pemasukan',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          '+ Rp ${RupiahFormatter.format(totalDebit)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
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

        // ==========================================
        // TABEL 2: PENGELUARAN (BERDASARKAN KATEGORI)
        // ==========================================
        Container(
          decoration: BoxDecoration(
            color: lightCardElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card Pengeluaran
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: primaryRose.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                  border: const Border(bottom: BorderSide(color: lightBorder)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: primaryRose.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded,
                          size: 14, color: primaryRose),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Tabel Pengeluaran',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
              ),

              // Header Kolom (2 Kolom: Kategori & Jumlah)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  color: lightCard,
                  border: Border(bottom: BorderSide(color: lightBorder)),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Text(
                        'KATEGORI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'JUMLAH',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Baris Data Pengeluaran
              if (pengeluaranEntries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 14),
                  child: Center(
                    child: Text(
                      'Tidak ada pengeluaran tercatat di bulan ini',
                      style: TextStyle(fontSize: 11.5, color: textMuted),
                    ),
                  ),
                )
              else
                ...pengeluaranEntries.map((entry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: lightBorder)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: const BoxDecoration(
                                  color: primaryRose,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            '- Rp ${RupiahFormatter.format(entry.value)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primaryRose,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              // Total Pengeluaran Row
              if (pengeluaranEntries.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: primaryRose.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 6,
                        child: Text(
                          'Total Pengeluaran',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          '- Rp ${RupiahFormatter.format(totalKredit)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: primaryRose,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModalFilterChip(
      String label, String value, StateSetter setModalState) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setModalState(() {
            _selectedFilter = value;
          });
          setState(() {
            _selectedFilter = value;
          });
        },
        backgroundColor: lightCardElevated,
        selectedColor: primaryBlue.withValues(alpha: 0.15),
        checkmarkColor: primaryBlue,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? primaryBlue : textDark,
        ),
        side: BorderSide(
          color: isSelected ? primaryBlue : lightBorder,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  List<PribadiTransaction> _getFilteredTransactions() {
    var list = List<PribadiTransaction>.from(_data.transactions);

    if (_selectedFilter == 'pemasukan') {
      list = list.where((t) => t.isPemasukan).toList();
    } else if (_selectedFilter == 'pengeluaran') {
      list = list.where((t) => t.isPengeluaran).toList();
    }

    if (_searchQuery.isNotEmpty) {
      list = list.where((t) {
        final title = t.title.toLowerCase();
        final note = (t.note ?? '').toLowerCase();
        final kode =
            t.getDisplayKode(customRules: _data.customKodeRules).toLowerCase();
        return title.contains(_searchQuery) ||
            note.contains(_searchQuery) ||
            kode.contains(_searchQuery);
      }).toList();
    }

    if (_isSortAscending) {
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } else {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    return list;
  }
}


