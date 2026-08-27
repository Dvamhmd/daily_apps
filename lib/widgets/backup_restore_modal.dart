import 'dart:convert';
import 'dart:io';
import 'package:daily_apps/utils/backup_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class BackupRestoreModal extends StatefulWidget {
  final VoidCallback? onDataRestored;

  const BackupRestoreModal({super.key, this.onDataRestored});

  static Future<void> show(BuildContext context,
      {VoidCallback? onDataRestored}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackupRestoreModal(onDataRestored: onDataRestored),
    );
  }

  @override
  State<BackupRestoreModal> createState() => _BackupRestoreModalState();
}

class _BackupRestoreModalState extends State<BackupRestoreModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  BackupSummary? _liveSummary;
  bool _isLoadingSummary = true;
  bool _isExporting = false;
  bool _isImporting = false;

  // Selected file for import
  String? _selectedFileName;
  int? _selectedFileSize;
  BackupDataModel? _parsedBackupData;
  String? _importErrorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLiveSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLiveSummary() async {
    try {
      final summary = await BackupService.getLiveSummary();
      if (mounted) {
        setState(() {
          _liveSummary = summary;
          _isLoadingSummary = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
        });
      }
    }
  }

  Future<void> _handleExport() async {
    setState(() {
      _isExporting = true;
    });

    try {
      await BackupService.exportAndShareBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cadangan data berhasil dibuat!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Text('Gagal mengekspor data: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _handleCopyJson() async {
    try {
      final backup = await BackupService.generateBackupData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(backup.toJson());
      await Clipboard.setData(ClipboardData(text: jsonStr));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF5E35B1),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: const Row(
              children: [
                Icon(Icons.copy_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Data JSON cadangan disalin ke clipboard!'),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD32F2F),
            content: Text('Gagal menyalin data: $e'),
          ),
        );
      }
    }
  }

  Future<void> _pickBackupFile() async {
    setState(() {
      _importErrorMessage = null;
      _parsedBackupData = null;
      _selectedFileName = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      _selectedFileName = file.name;
      _selectedFileSize = file.size;

      String content = '';
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        final f = File(file.path!);
        content = await f.readAsString();
      }

      if (content.trim().isEmpty) {
        throw const FormatException('File cadangan yang dipilih kosong.');
      }

      final parsed = BackupService.parseAndValidateBackup(content);
      if (mounted) {
        setState(() {
          _parsedBackupData = parsed;
          _importErrorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _importErrorMessage = e.toString().replaceAll('FormatException: ', '');
          _parsedBackupData = null;
        });
      }
    }
  }

  Future<void> _confirmAndRestore() async {
    if (_parsedBackupData == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Konfirmasi Pemulihan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Seluruh data saat ini akan ditimpa dengan data dari file cadangan yang dipilih. Lanjutkan pemulihan?',
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5E35B1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Pulihkan Data'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isImporting = true;
    });

    try {
      await BackupService.restoreBackup(_parsedBackupData!, cleanRestore: true);

      if (mounted) {
        Navigator.pop(context); // Tutup modal

        widget.onDataRestored?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Seluruh data berhasil dipulihkan dari cadangan!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD32F2F),
            content: Text('Gagal memulihkan data: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Container(
      height: screenHeight * 0.85 + bottomInset,
      decoration: const BoxDecoration(
        color: Color(0xFFF7F9FC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
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
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5E35B1), Color(0xFF7E57C2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5E35B1).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.cloud_sync_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Backup Data',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Ekspor/Impor Data aplikasi Daily Apps',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: const Color(0xFF5E35B1),
              unselectedLabelColor: Colors.grey[600],
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Icons.file_upload_outlined, size: 18),
                  text: 'Ekspor (Backup)',
                ),
                Tab(
                  icon: Icon(Icons.file_download_outlined, size: 18),
                  text: 'Impor (Restore)',
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildExportTab(),
                _buildImportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        // Live summary card
        _buildSummaryCard(
          title: 'Ringkasan Data Saat Ini',
          subtitle: 'Semua data di bawah ini akan disertakan dalam file cadangan',
          icon: Icons.inventory_2_outlined,
          iconColor: const Color(0xFF5E35B1),
          summary: _liveSummary,
          isLoading: _isLoadingSummary,
        ),

        const SizedBox(height: 16),

        // Information banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8EAF6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF5E35B1).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFF5E35B1), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'File cadangan tersimpan dalam format standar JSON (.json) yang aman dan mencakup Keuangan, Struktur Keuangan, Rundown, serta Todo List.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Export button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5E35B1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 3,
            shadowColor: const Color(0xFF5E35B1).withValues(alpha: 0.4),
          ),
          onPressed: _isExporting ? null : _handleExport,
          child: _isExporting
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Menyiapkan file cadangan...'),
                  ],
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.share_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Ekspor & Bagikan File Cadangan',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 10),

        // Copy JSON Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF5E35B1),
            side: const BorderSide(color: Color(0xFF5E35B1)),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _handleCopyJson,
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text(
            'Salin Teks JSON Cadangan ke Clipboard',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildImportTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        // Pick file card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Langkah 1: Pilih File Cadangan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pilih file .json cadangan yang telah diekspor sebelumnya',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isImporting ? null : _pickBackupFile,
                icon: const Icon(Icons.folder_open_rounded, size: 20),
                label: Text(
                  _selectedFileName != null
                      ? 'Ganti File Cadangan'
                      : 'Pilih File Cadangan (.json)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        // Error message if any
        if (_importErrorMessage != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF5350)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFD32F2F)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Error: $_importErrorMessage',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFC62828),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // File preview card
        if (_parsedBackupData != null) ...[
          const SizedBox(height: 16),
          _buildParsedPreviewCard(_parsedBackupData!),
          const SizedBox(height: 16),

          // Warning
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFB74D)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFE65100), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Perhatian: Pemulihan akan menggantikan seluruh data yang ada saat ini dengan data dari file cadangan ini.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFE65100),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Restore button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 3,
            ),
            onPressed: _isImporting ? null : _confirmAndRestore,
            child: _isImporting
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Memulihkan data...'),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restore_rounded, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Pulihkan Data Sekarang',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required BackupSummary? summary,
    required bool isLoading,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (summary != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatChip(
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF1976D2),
                  label: 'Keuangan',
                  value:
                      '${summary.totalUangku + summary.totalTagihan} data (${summary.totalTabungan} tabungan)',
                ),
                _buildStatChip(
                  icon: Icons.corporate_fare_rounded,
                  color: const Color(0xFF5E35B1),
                  label: 'Keuangan Struktur',
                  value:
                      '${summary.totalStrukturMonths} bulan (${summary.totalStrukturTransactions} transaksi)',
                ),
                _buildStatChip(
                  icon: Icons.view_timeline_rounded,
                  color: const Color(0xFF00897B),
                  label: 'Rundown',
                  value: '${summary.totalRundowns} agenda',
                ),
                _buildStatChip(
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFFE65100),
                  label: 'Todo List',
                  value:
                      '${summary.totalTodoActiveItems} aktif, ${summary.totalTodoHistoryItems} riwayat',
                ),
                _buildStatChip(
                  icon: Icons.history_rounded,
                  color: const Color(0xFF455A64),
                  label: 'Riwayat Keuangan',
                  value: '${summary.totalRiwayatKeuangan} catatan',
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildParsedPreviewCard(BackupDataModel data) {
    final tglStr = DateFormat('dd MMMM yyyy, HH:mm').format(data.exportedAt);
    final sizeKb = _selectedFileSize != null
        ? '${(_selectedFileSize! / 1024).toStringAsFixed(1)} KB'
        : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF2E7D32),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'File Cadangan Valid',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    Text(
                      '$_selectedFileName $sizeKb',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                'Dibuat: $tglStr',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatChip(
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFF1976D2),
                label: 'Keuangan',
                value:
                    '${data.summary.totalUangku + data.summary.totalTagihan} data (${data.summary.totalTabungan} tabungan)',
              ),
              _buildStatChip(
                icon: Icons.corporate_fare_rounded,
                color: const Color(0xFF5E35B1),
                label: 'Struktur',
                value:
                    '${data.summary.totalStrukturMonths} bulan (${data.summary.totalStrukturTransactions} transaksi)',
              ),
              _buildStatChip(
                icon: Icons.view_timeline_rounded,
                color: const Color(0xFF00897B),
                label: 'Rundown',
                value: '${data.summary.totalRundowns} agenda',
              ),
              _buildStatChip(
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFFE65100),
                label: 'Todo List',
                value:
                    '${data.summary.totalTodoActiveItems} aktif, ${data.summary.totalTodoHistoryItems} riwayat',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
