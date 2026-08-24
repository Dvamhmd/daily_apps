import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/model_sheets_config.dart';
import '../utils/sheets_sync_service.dart';
import 'google_sheets_config_modal.dart';

class UploadEvidenceModal extends StatefulWidget {
  final SheetsConfig sheetsConfig;
  final String monthLabel;
  final Function(SheetsConfig)? onConfigChanged;
  final VoidCallback? onUploaded;

  const UploadEvidenceModal({
    super.key,
    required this.sheetsConfig,
    required this.monthLabel,
    this.onConfigChanged,
    this.onUploaded,
  });

  static Future<void> show(
    BuildContext context, {
    required SheetsConfig sheetsConfig,
    required String monthLabel,
    Function(SheetsConfig)? onConfigChanged,
    VoidCallback? onUploaded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UploadEvidenceModal(
        sheetsConfig: sheetsConfig,
        monthLabel: monthLabel,
        onConfigChanged: onConfigChanged,
        onUploaded: onUploaded,
      ),
    );
  }

  @override
  State<UploadEvidenceModal> createState() => _UploadEvidenceModalState();
}

class _EvidenceItem {
  final String key;
  final String label;
  final String iconDesc;
  Uint8List? bytes;
  String? fileName;
  String? mimeType;

  _EvidenceItem({
    required this.key,
    required this.label,
    required this.iconDesc,
  });

  bool get hasFile => bytes != null && bytes!.isNotEmpty;
}

class _UploadEvidenceModalState extends State<UploadEvidenceModal> {
  late SheetsConfig _config;
  bool _isUploading = false;
  String? _uploadStatusMessage;
  bool? _uploadSuccess;

  late _EvidenceItem _saldoRekening;
  late _EvidenceItem _saldoCash;
  final List<_EvidenceItem> _mutasiList = [];

  @override
  void initState() {
    super.initState();
    _config = widget.sheetsConfig;

    _saldoRekening = _EvidenceItem(
      key: 'bukti_saldo_rekening',
      label: 'Saldo Rekening',
      iconDesc: 'Screenshot M-Banking / Mutasi Saldo Bank',
    );

    _saldoCash = _EvidenceItem(
      key: 'bukti_saldo_cash',
      label: 'Saldo Cash On Hand',
      iconDesc: 'Foto Fisik Uang Tunai di Tangan',
    );

    for (int i = 1; i <= 4; i++) {
      _mutasiList.add(_EvidenceItem(
        key: 'bukti_mutasi_$i',
        label: 'Mutasi Rekening $i',
        iconDesc: 'Halaman $i Bukti Mutasi',
      ));
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  int get _totalSelectedCount {
    int count = 0;
    if (_saldoRekening.hasFile) count++;
    if (_saldoCash.hasFile) count++;
    for (var m in _mutasiList) {
      if (m.hasFile) count++;
    }
    return count;
  }

  Future<void> _pickSingleImage(_EvidenceItem item) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final ext = file.extension?.toLowerCase() ?? 'jpg';
          String mime = 'image/jpeg';
          if (ext == 'png') mime = 'image/png';
          if (ext == 'webp') mime = 'image/webp';

          setState(() {
            item.bytes = file.bytes;
            item.fileName = file.name;
            item.mimeType = mime;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _pickMultipleMutasi() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final files = result.files.take(4).toList();

        setState(() {
          for (int i = 0; i < 4; i++) {
            if (i < files.length && files[i].bytes != null) {
              final ext = files[i].extension?.toLowerCase() ?? 'jpg';
              String mime = 'image/jpeg';
              if (ext == 'png') mime = 'image/png';
              if (ext == 'webp') mime = 'image/webp';

              _mutasiList[i].bytes = files[i].bytes;
              _mutasiList[i].fileName = files[i].name;
              _mutasiList[i].mimeType = mime;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar mutasi: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _clearImage(_EvidenceItem item) {
    setState(() {
      item.bytes = null;
      item.fileName = null;
      item.mimeType = null;
    });
  }

  void _showImagePreviewDialog(_EvidenceItem item) {
    if (!item.hasFile) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              // Image Container
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      item.bytes!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.fileName ?? '',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 16, color: Colors.redAccent),
                      label: const Text('Hapus',
                          style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      onPressed: () {
                        _clearImage(item);
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleUploadToSheets() async {
    if (!_config.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'URL Google Apps Script belum diatur. Buka Pengaturan Spreadsheets.'),
          backgroundColor: Colors.redAccent,
          action: SnackBarAction(
            label: 'Atur',
            textColor: Colors.white,
            onPressed: () {
              GoogleSheetsConfigModal.show(
                context: context,
                config: _config,
                onConfigSaved: (newCfg) {
                  setState(() => _config = newCfg);
                  widget.onConfigChanged?.call(newCfg);
                },
              );
            },
          ),
        ),
      );
      return;
    }

    if (_totalSelectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal 1 gambar bukti untuk diunggah.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatusMessage = null;
      _uploadSuccess = null;
    });

    final defaultTargetRow = _config.evidenceTargetRow;

    final List<Map<String, dynamic>> payloadImages = [];

    void addPayloadItem(_EvidenceItem item) {
      if (item.hasFile) {
        final itemRow =
            _config.getEvidenceRow(item.key, fallback: defaultTargetRow);
        payloadImages.add({
          'key': item.key,
          'base64': base64Encode(item.bytes!),
          'mimeType': item.mimeType ?? 'image/jpeg',
          'fileName': item.fileName ?? '${item.key}.jpg',
          'targetRow': itemRow,
        });
      }
    }

    addPayloadItem(_saldoRekening);
    addPayloadItem(_saldoCash);
    for (var m in _mutasiList) {
      addPayloadItem(m);
    }

    final result = await SheetsSyncService.uploadEvidenceImages(
      config: _config,
      imagesPayload: payloadImages,
      monthLabel: widget.monthLabel.replaceAll(' ', '_'),
      targetRow: defaultTargetRow,
    );

    if (mounted) {
      setState(() {
        _isUploading = false;
        _uploadSuccess = result.isSuccess;
        _uploadStatusMessage = result.message;
      });

      if (result.isSuccess) {
        widget.onUploaded?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
          widget.onConfigChanged?.call(_config);
        }
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
        margin: EdgeInsets.only(bottom: bottomInset),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(),

          // Body Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_upload_rounded,
                            color: Color(0xFF2563EB), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Gambar bukti akan otomatis disimpan ke Google Drive & tautan/formula dimasukkan ke Spreadsheet ${widget.monthLabel} sesuai pengaturan di Integrasi Google Spreadsheets.',
                            style: const TextStyle(
                                fontSize: 11.5, color: Color(0xFF1E40AF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. Section Saldo Rekening
                  _buildSectionHeader(
                    title: '1. Bukti Saldo Rekening',
                    subtitle: 'Wajib / Disarankan untuk validasi kas bank',
                    icon: Icons.account_balance_rounded,
                    color: const Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 8),
                  _buildSingleSlotCard(_saldoRekening),

                  const SizedBox(height: 20),

                  // 2. Section Saldo Cash On Hand
                  _buildSectionHeader(
                    title: '2. Bukti Saldo Cash On Hand',
                    subtitle: 'Foto fisik uang tunai di tangan',
                    icon: Icons.payments_rounded,
                    color: const Color(0xFF059669),
                  ),
                  const SizedBox(height: 8),
                  _buildSingleSlotCard(_saldoCash),

                  const SizedBox(height: 20),

                  // 3. Section Mutasi Rekening (Maks 4)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader(
                        title: '3. Bukti Mutasi Rekening',
                        subtitle: 'Maksimal 4 gambar mutasi',
                        icon: Icons.receipt_long_rounded,
                        color: const Color(0xFFD97706),
                      ),
                      TextButton.icon(
                        onPressed: _pickMultipleMutasi,
                        icon: const Icon(Icons.photo_library_rounded, size: 15),
                        label: const Text('Pilih Sekaligus (Maks 4)',
                            style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFD97706),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildMutasiGrid(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          _buildBottomActionBar(),
        ],
      ),
    ),
  );
}

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          // Drag Handle
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
                  color: const Color(0xFF107C41).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.drive_folder_upload_rounded,
                  color: Color(0xFF107C41),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upload Gambar Bukti ke Spreadsheets',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Saldo Rekening, Cash On Hand & Mutasi (${widget.monthLabel})',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_suggest_rounded,
                    color: Color(0xFF107C41)),
                tooltip: 'Pengaturan Kolom Spreadsheets',
                onPressed: () {
                  GoogleSheetsConfigModal.show(
                    context: context,
                    config: _config,
                    onConfigSaved: (newCfg) {
                      setState(() => _config = newCfg);
                      widget.onConfigChanged?.call(newCfg);
                    },
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleSlotCard(_EvidenceItem item) {
    final colMapped = _config.columnMapping[item.key] ?? '-';
    final rowMapped = _config.getEvidenceRow(item.key);
    final cellDisplay = colMapped == '-' ? '-' : '$colMapped$rowMapped';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.hasFile ? const Color(0xFF107C41) : const Color(0xFFE2E8F0),
          width: item.hasFile ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Preview Thumbnail / Placeholder
          GestureDetector(
            onTap: item.hasFile ? () => _showImagePreviewDialog(item) : () => _pickSingleImage(item),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: item.hasFile
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.memory(
                        item.bytes!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_rounded,
                            size: 24, color: Color(0xFF94A3B8)),
                        SizedBox(height: 2),
                        Text(
                          'Pilih',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Info Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Sel: $cellDisplay',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.hasFile ? (item.fileName ?? 'Gambar dipilih') : item.iconDesc,
                  style: TextStyle(
                    fontSize: 10,
                    color: item.hasFile
                        ? const Color(0xFF059669)
                        : const Color(0xFF94A3B8),
                    fontWeight:
                        item.hasFile ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Action Buttons
          if (item.hasFile) ...[
            IconButton(
              icon: const Icon(Icons.zoom_in_rounded,
                  color: Color(0xFF2563EB), size: 20),
              tooltip: 'Lihat Gambar',
              onPressed: () => _showImagePreviewDialog(item),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 20),
              tooltip: 'Hapus Gambar',
              onPressed: () => _clearImage(item),
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: () => _pickSingleImage(item),
              icon: const Icon(Icons.upload_file_rounded, size: 14),
              label: const Text('Pilih', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMutasiGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _mutasiList.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (ctx, index) {
        final item = _mutasiList[index];
        final colMapped = _config.columnMapping[item.key] ?? '-';
        final rowMapped = _config.getEvidenceRow(item.key);
        final cellDisplay = colMapped == '-' ? '-' : '$colMapped$rowMapped';

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: item.hasFile
                  ? const Color(0xFF107C41)
                  : const Color(0xFFE2E8F0),
              width: item.hasFile ? 1.4 : 1,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mutasi ${index + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Sel: $cellDisplay',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: GestureDetector(
                      onTap: item.hasFile
                          ? () => _showImagePreviewDialog(item)
                          : () => _pickSingleImage(item),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFCBD5E1),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: item.hasFile
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Image.memory(
                                  item.bytes!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_rounded,
                                      size: 15, color: Color(0xFF94A3B8)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Pilih Foto',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              if (item.hasFile)
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _clearImage(item),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomActionBar() {
    final count = _totalSelectedCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_uploadStatusMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _uploadSuccess == true
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _uploadSuccess == true
                        ? const Color(0xFFA7F3D0)
                        : const Color(0xFFFECDD3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _uploadSuccess == true
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      color: _uploadSuccess == true
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _uploadStatusMessage!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _uploadSuccess == true
                              ? const Color(0xFF065F46)
                              : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count Gambar Dipilih',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        _config.insertImageFormula
                            ? 'Format: Gambar di Sel (HD / In-Cell)'
                            : 'Format: Link URL Drive',
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _handleUploadToSheets,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: Text(
                    _isUploading
                        ? 'Mengunggah...'
                        : 'Upload ke Spreadsheets',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF107C41),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
