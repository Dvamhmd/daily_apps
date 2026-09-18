import 'package:daily_apps/models/model_pribadi.dart';
import 'package:daily_apps/models/model_rundown.dart';
import 'package:daily_apps/utils/responsive_text.dart';
import 'package:daily_apps/utils/rundown_expense_service.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:daily_apps/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ModalEstimasiPengeluaran extends StatefulWidget {
  final Rundown rundown;
  final Function(Rundown updatedRundown) onRundownUpdated;
  final DateTime? selectedMonth;

  const ModalEstimasiPengeluaran({
    super.key,
    required this.rundown,
    required this.onRundownUpdated,
    this.selectedMonth,
  });

  static Future<void> show(
    BuildContext context, {
    required Rundown rundown,
    required Function(Rundown updatedRundown) onRundownUpdated,
    DateTime? selectedMonth,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalEstimasiPengeluaran(
        rundown: rundown,
        onRundownUpdated: onRundownUpdated,
        selectedMonth: selectedMonth,
      ),
    );
  }

  @override
  State<ModalEstimasiPengeluaran> createState() =>
      _ModalEstimasiPengeluaranState();
}

class _ModalEstimasiPengeluaranState extends State<ModalEstimasiPengeluaran> {
  static const Color primaryTeal = Color(0xFF00897B);
  late Rundown _rundown;
  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _rundown = widget.rundown;
  }

  void _updateRundown(Rundown updated) {
    setState(() {
      _rundown = updated;
    });
    widget.onRundownUpdated(updated);
  }

  Future<void> _openTambahEstimasiDialog() async {
    final result = await showDialog<List<RundownExpenseItem>>(
      context: context,
      builder: (ctx) => const DialogTambahEstimasi(),
    );

    if (result != null && result.isNotEmpty) {
      final updatedExpenses = List<RundownExpenseItem>.from(_rundown.expenses)
        ..addAll(result);
      final updatedRundown = _rundown.copyWith(expenses: updatedExpenses);
      _updateRundown(updatedRundown);

      if (mounted) {
        CustomToast.showSuccess(
          context,
          title: 'Estimasi Ditambahkan',
          subtitle: '${result.length} item estimasi pengeluaran berhasil ditambahkan.',
        );
      }
    }
  }

  Future<void> _openEditEstimasiDialog(RundownExpenseItem item, int index) async {
    if (item.isRealized) {
      CustomToast.showWarning(
        context,
        title: 'Item Sudah Terealisasi',
        subtitle: 'Batalkan status realisasi terlebih dahulu jika ingin mengubah estimasi.',
      );
      return;
    }

    final result = await showDialog<RundownExpenseItem>(
      context: context,
      builder: (ctx) => DialogEditEstimasi(item: item),
    );

    if (result != null) {
      final updatedExpenses = List<RundownExpenseItem>.from(_rundown.expenses);
      updatedExpenses[index] = result;
      final updatedRundown = _rundown.copyWith(expenses: updatedExpenses);
      _updateRundown(updatedRundown);

      if (mounted) {
        CustomToast.showSuccess(
          context,
          title: 'Estimasi Diperbarui',
          subtitle: 'Perubahan item "${result.nama}" berhasil disimpan.',
        );
      }
    }
  }

  Future<void> _deleteEstimasi(RundownExpenseItem item, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Item Estimasi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Text(
          item.isRealized
              ? 'Item "${item.nama}" sudah terealisasi. Jika dihapus, saldo Pos Dana "${item.posDana}" sebesar ${RupiahFormatter.format(item.nominalRealisasi ?? item.nominalEstimasi)} akan dikembalikan secara otomatis. Lanjutkan?'
              : 'Apakah kamu yakin ingin menghapus estimasi "${item.nama}"?',
          style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        if (item.isRealized) {
          await RundownExpenseService.revertRealisasi(
            rundown: _rundown,
            item: item,
            selectedMonth: widget.selectedMonth,
          );
        }

        final updatedExpenses = List<RundownExpenseItem>.from(_rundown.expenses)
          ..removeAt(index);
        final updatedRundown = _rundown.copyWith(expenses: updatedExpenses);
        _updateRundown(updatedRundown);

        if (mounted) {
          CustomToast.showSuccess(
            context,
            title: 'Item Dihapus',
            subtitle: 'Estimasi "${item.nama}" berhasil dihapus.',
          );
        }
      } catch (e) {
        if (mounted) {
          CustomToast.showError(
            context,
            title: 'Gagal Menghapus',
            subtitle: e.toString(),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openIsiRealisasiDialog(RundownExpenseItem item, int index) async {
    final result = await showDialog<RundownExpenseItem>(
      context: context,
      builder: (ctx) => DialogIsiRealisasi(
        rundown: _rundown,
        item: item,
        selectedMonth: widget.selectedMonth,
      ),
    );

    if (result != null) {
      final updatedExpenses = List<RundownExpenseItem>.from(_rundown.expenses);
      updatedExpenses[index] = result;
      final updatedRundown = _rundown.copyWith(expenses: updatedExpenses);
      _updateRundown(updatedRundown);

      if (mounted) {
        CustomToast.showSuccess(
          context,
          title: 'Realisasi Berhasil',
          subtitle:
              'Pengeluaran "${result.nama}" sebesar ${RupiahFormatter.format(result.nominalRealisasi ?? 0)} telah dipotong dari Pos Dana "${result.posDana}".',
        );
      }
    }
  }

  Future<void> _batalkanRealisasi(RundownExpenseItem item, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Batalkan Realisasi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Text(
          'Saldo sebesar ${RupiahFormatter.format(item.nominalRealisasi ?? item.nominalEstimasi)} akan dikembalikan ke Pos Dana "${item.posDana}". Apakah kamu yakin?',
          style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tutup', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Batalkan Realisasi'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final revertedItem = await RundownExpenseService.revertRealisasi(
          rundown: _rundown,
          item: item,
          selectedMonth: widget.selectedMonth,
        );

        final updatedExpenses = List<RundownExpenseItem>.from(_rundown.expenses);
        updatedExpenses[index] = revertedItem;
        final updatedRundown = _rundown.copyWith(expenses: updatedExpenses);
        _updateRundown(updatedRundown);

        if (mounted) {
          CustomToast.showSuccess(
            context,
            title: 'Realisasi Dibatalkan',
            subtitle:
                'Saldo berhasil dikembalikan ke Pos Dana "${item.posDana}".',
          );
        }
      } catch (e) {
        if (mounted) {
          CustomToast.showError(
            context,
            title: 'Gagal Membatalkan',
            subtitle: e.toString(),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final totalEstimasi = _rundown.totalEstimasiPengeluaran;
    final totalRealisasi = _rundown.totalRealisasiPengeluaran;
    final selisih = _rundown.selisihPengeluaran;
    final totalItems = _rundown.expenses.length;
    final realizedCount = _rundown.totalItemTerealisasi;

    return Container(
      height: mediaQuery.size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: primaryTeal,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimasi & Realisasi Biaya',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        _rundown.title,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  tooltip: 'Tutup',
                ),
              ],
            ),
          ),

          const Divider(height: 20, color: Color(0xFFE2E8F0)),

          // Main Scrollable Area
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryTeal),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Financial Summary Card
                        _buildFinancialSummaryCard(
                          totalEstimasi: totalEstimasi,
                          totalRealisasi: totalRealisasi,
                          selisih: selisih,
                          totalItems: totalItems,
                          realizedCount: realizedCount,
                        ),

                        const SizedBox(height: 16),

                        // Section Title + Add Button + Edit Button
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Rincian Item ($totalItems)',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _openTambahEstimasiDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryTeal,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text(
                                'Tambah Item',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_rundown.expenses.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isEditMode = !_isEditMode;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _isEditMode
                                      ? Colors.white
                                      : const Color(0xFF0284C7),
                                  backgroundColor: _isEditMode
                                      ? const Color(0xFF0284C7)
                                      : Colors.transparent,
                                  side: const BorderSide(
                                    color: Color(0xFF0284C7),
                                  ),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: Icon(
                                  _isEditMode
                                      ? Icons.check_rounded
                                      : Icons.edit_rounded,
                                  size: 14,
                                ),
                                label: Text(
                                  _isEditMode ? 'Selesai' : 'Edit',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Expense List
                        if (_rundown.expenses.isEmpty)
                          _buildEmptyState()
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _rundown.expenses.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final item = _rundown.expenses[index];
                              return _buildExpenseCard(item, index);
                            },
                          ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryCard({
    required int totalEstimasi,
    required int totalRealisasi,
    required int selisih,
    required int totalItems,
    required int realizedCount,
  }) {
    final double progress = totalItems > 0 ? (realizedCount / totalItems) : 0.0;
    final bool isHemat = selisih >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF004D40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF004D40).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Total Estimasi & Total Realisasi
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL ESTIMASI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.75),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rp ${RupiahFormatter.format(totalEstimasi)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL REALISASI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.75),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rp ${RupiahFormatter.format(totalRealisasi)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF80CBC4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 12),

          // Row 2: Status Selisih & Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isHemat
                        ? Icons.savings_outlined
                        : Icons.warning_amber_rounded,
                    color: isHemat
                        ? const Color(0xFF81C784)
                        : const Color(0xFFFFB74D),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isHemat
                        ? 'Sisa/Hemat: Rp ${RupiahFormatter.format(selisih)}'
                        : 'Lebih: Rp ${RupiahFormatter.format(selisih.abs())}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isHemat
                          ? const Color(0xFFA5D6A7)
                          : const Color(0xFFFFCC80),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$realizedCount / $totalItems Selesai',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4DB6AC)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primaryTeal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: primaryTeal,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Belum Ada Estimasi Biaya',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Catat pos pengeluaran yang dibutuhkan untuk acara ini (misal: Bensin, Konsumsi, Sewa Tempat, dll).',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _openTambahEstimasiDialog,
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryTeal,
              side: const BorderSide(color: primaryTeal),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Input Estimasi Pengeluaran'),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(RundownExpenseItem item, int index) {
    final bool isRealized = item.isRealized;
    final int estimasi = item.nominalEstimasi;
    final int? realisasi = item.nominalRealisasi;
    final int selisihItem = (realisasi != null) ? (estimasi - realisasi) : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isRealized
              ? const Color(0xFF81C784).withValues(alpha: 0.6)
              : const Color(0xFFE2E8F0),
          width: isRealized ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Kolom Nama (Sejajar proporsional flex 11)
          Expanded(
            flex: 11,
            child: Row(
              children: [
                // Dot Status Indicator
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isRealized
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFFFA000),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.nama,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isRealized && item.posDana != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          'Pos: ${item.posDana}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Pembatas '|' (Posisi sejajar vertikal di semua baris)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '|',
              style: TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 13,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),

          // 3. Kolom Nominal (Sejajar proporsional flex 9 rata kanan)
          Expanded(
            flex: 9,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rp ${RupiahFormatter.format(isRealized && realisasi != null ? realisasi : estimasi)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isRealized
                        ? const Color(0xFF00695C)
                        : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isRealized && selisihItem != 0)
                  Text(
                    selisihItem > 0
                        ? 'Hemat Rp ${RupiahFormatter.format(selisihItem)}'
                        : '+Rp ${RupiahFormatter.format(selisihItem.abs())}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: selisihItem > 0
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 4. Kolom Tombol Aksi (Lebar tetap 64px sejajar rata kanan)
          SizedBox(
            width: 64,
            child: Align(
              alignment: Alignment.centerRight,
              child: _isEditMode
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded,
                              size: 17, color: Color(0xFF0284C7)),
                          onPressed: () => _openEditEstimasiDialog(item, index),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(3),
                          tooltip: 'Edit Item',
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 17, color: Colors.redAccent),
                          onPressed: () => _deleteEstimasi(item, index),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(3),
                          tooltip: 'Hapus Item',
                        ),
                      ],
                    )
                  : (!isRealized
                      ? ElevatedButton(
                          onPressed: () => _openIsiRealisasiDialog(item, index),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryTeal,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            minimumSize: const Size(60, 26),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          child: const Text(
                            'Bayar',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : InkWell(
                          onTap: () => _batalkanRealisasi(item, index),
                          borderRadius: BorderRadius.circular(7),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                  color: const Color(0xFFA5D6A7), width: 0.8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_rounded,
                                    size: 12, color: Color(0xFF2E7D32)),
                                SizedBox(width: 2),
                                Text(
                                  'Lunas',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog Form Tambah Estimasi (Mendukung Input Multi Baris Sekaligus)
class DialogTambahEstimasi extends StatefulWidget {
  const DialogTambahEstimasi({super.key});

  @override
  State<DialogTambahEstimasi> createState() => _DialogTambahEstimasiState();
}

class _ExpenseRowInput {
  final TextEditingController namaCtrl;
  final TextEditingController nominalCtrl;

  _ExpenseRowInput({String nama = '', String nominal = ''})
      : namaCtrl = TextEditingController(text: nama),
        nominalCtrl = TextEditingController(text: nominal);

  void dispose() {
    namaCtrl.dispose();
    nominalCtrl.dispose();
  }
}

class _DialogTambahEstimasiState extends State<DialogTambahEstimasi> {
  static const Color primaryTeal = Color(0xFF00897B);
  final List<_ExpenseRowInput> _rows = [];

  @override
  void initState() {
    super.initState();
    _addRow();
  }

  void _addRow() {
    setState(() {
      _rows.add(_ExpenseRowInput());
    });
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final List<RundownExpenseItem> result = [];
    for (final r in _rows) {
      final nama = r.namaCtrl.text.trim();
      final cleanNominal =
          r.nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (nama.isNotEmpty && cleanNominal.isNotEmpty) {
        final nominal = int.tryParse(cleanNominal) ?? 0;
        if (nominal > 0) {
          result.add(
            RundownExpenseItem(
              id: DateTime.now().microsecondsSinceEpoch.toString() +
                  '_${result.length}',
              nama: nama,
              nominalEstimasi: nominal,
            ),
          );
        }
      }
    }

    if (result.isEmpty) {
      CustomToast.showWarning(
        context,
        title: 'Form Belum Lengkap',
        subtitle: 'Isi setidaknya 1 item pengeluaran dengan nama dan nominal.',
      );
      return;
    }

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: primaryTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_shopping_cart_rounded,
                color: primaryTeal, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Tambah Estimasi Pengeluaran',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dynamic Rows
            ...List.generate(_rows.length, (index) {
              final row = _rows[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${index + 1}.',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Nama
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: row.namaCtrl,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Nama',
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 7,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide:
                                const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Nominal
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: row.nominalCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 12.5),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          RupiahInputFormatter(),
                        ],
                        decoration: InputDecoration(
                          hintText: 'Nominal',
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 7,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide:
                                const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                      ),
                    ),
                    if (_rows.length > 1) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _removeRow(index),
                        icon: const Icon(
                          Icons.remove_circle_outline_rounded,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(2),
                        tooltip: 'Hapus Baris',
                      ),
                    ],
                  ],
                ),
              );
            }),

            const SizedBox(height: 4),
            // Tombol Tambah Baris Lagi
            TextButton.icon(
              onPressed: _addRow,
              style: TextButton.styleFrom(
                foregroundColor: primaryTeal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                '+ Tambah Baris Input Lainnya',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryTeal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Simpan Semua'),
        ),
      ],
    );
  }
}

/// Dialog Edit Nama & Estimasi Item
class DialogEditEstimasi extends StatefulWidget {
  final RundownExpenseItem item;

  const DialogEditEstimasi({super.key, required this.item});

  @override
  State<DialogEditEstimasi> createState() => _DialogEditEstimasiState();
}

class _DialogEditEstimasiState extends State<DialogEditEstimasi> {
  static const Color primaryTeal = Color(0xFF00897B);
  late TextEditingController _namaCtrl;
  late TextEditingController _nominalCtrl;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController(text: widget.item.nama);
    _nominalCtrl = TextEditingController(
      text: RupiahFormatter.format(widget.item.nominalEstimasi),
    );
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _nominalCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final nama = _namaCtrl.text.trim();
    final cleanNominal = _nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (nama.isEmpty || cleanNominal.isEmpty) {
      CustomToast.showWarning(
        context,
        title: 'Data Belum Lengkap',
        subtitle: 'Nama dan nominal estimasi tidak boleh kosong.',
      );
      return;
    }

    final nominal = int.tryParse(cleanNominal) ?? 0;
    if (nominal <= 0) {
      CustomToast.showWarning(
        context,
        title: 'Nominal Tidak Valid',
        subtitle: 'Nominal estimasi harus lebih dari 0.',
      );
      return;
    }

    final updated = widget.item.copyWith(
      nama: nama,
      nominalEstimasi: nominal,
    );

    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Edit Estimasi Pengeluaran',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _namaCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nama Pengeluaran',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nominalCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              RupiahInputFormatter(),
            ],
            decoration: InputDecoration(
              labelText: 'Nominal Estimasi',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryTeal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

/// Dialog Isi Realisasi (Pilih Pos Dana dari Keuangan Utama & Pribadi)
class DialogIsiRealisasi extends StatefulWidget {
  final Rundown rundown;
  final RundownExpenseItem item;
  final DateTime? selectedMonth;

  const DialogIsiRealisasi({
    super.key,
    required this.rundown,
    required this.item,
    this.selectedMonth,
  });

  @override
  State<DialogIsiRealisasi> createState() => _DialogIsiRealisasiState();
}

class _DialogIsiRealisasiState extends State<DialogIsiRealisasi> {
  static const Color primaryTeal = Color(0xFF00897B);
  late TextEditingController _nominalRealCtrl;
  late TextEditingController _catatanCtrl;
  List<PosDana> _posDanaList = [];
  String? _selectedPosDanaNama;
  bool _isLoading = true;
  DateTime _tanggalRealisasi = DateTime.now();

  @override
  void initState() {
    super.initState();
    _nominalRealCtrl = TextEditingController(
      text: RupiahFormatter.format(widget.item.nominalEstimasi),
    );
    _catatanCtrl = TextEditingController();
    _loadPosDana();
  }

  @override
  void dispose() {
    _nominalRealCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPosDana() async {
    final list = await RundownExpenseService.loadAvailablePosDana(
      date: widget.selectedMonth ?? widget.rundown.startDate,
      selectedMonth: widget.selectedMonth,
    );

    if (mounted) {
      setState(() {
        _posDanaList = list;
        if (list.isNotEmpty) {
          _selectedPosDanaNama = list.first.nama;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    final cleanNominal =
        _nominalRealCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNominal.isEmpty) {
      CustomToast.showWarning(
        context,
        title: 'Nominal Kosong',
        subtitle: 'Masukkan nominal realisasi yang dikeluarkan.',
      );
      return;
    }

    final nominalReal = int.tryParse(cleanNominal) ?? 0;
    if (nominalReal <= 0) {
      CustomToast.showWarning(
        context,
        title: 'Nominal Tidak Valid',
        subtitle: 'Nominal realisasi harus lebih dari 0.',
      );
      return;
    }

    if (_selectedPosDanaNama == null || _selectedPosDanaNama!.isEmpty) {
      CustomToast.showWarning(
        context,
        title: 'Pilih Pos Dana',
        subtitle: 'Silakan pilih Pos Dana sumber yang akan dipotong.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedItem = await RundownExpenseService.executeRealisasi(
        rundown: widget.rundown,
        item: widget.item,
        nominalRealisasi: nominalReal,
        posDanaNama: _selectedPosDanaNama!,
        tanggalRealisasi: _tanggalRealisasi,
        catatan: _catatanCtrl.text.trim().isNotEmpty
            ? _catatanCtrl.text.trim()
            : null,
        selectedMonth: widget.selectedMonth,
      );

      if (mounted) {
        Navigator.pop(context, updatedItem);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomToast.showError(
          context,
          title: 'Gagal Memproses Realisasi',
          subtitle: e.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final estimasi = widget.item.nominalEstimasi;
    final cleanNominal =
        _nominalRealCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final currentInputNominal = int.tryParse(cleanNominal) ?? 0;
    final int selisih = estimasi - currentInputNominal;

    PosDana? selectedPos;
    if (_selectedPosDanaNama != null) {
      final idx = _posDanaList.indexWhere(
        (p) => p.nama.toLowerCase() == _selectedPosDanaNama!.toLowerCase(),
      );
      if (idx != -1) selectedPos = _posDanaList[idx];
    }

    return AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_rounded,
                color: primaryTeal, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Isi Realisasi Pengeluaran',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 150,
              child: Center(
                child: CircularProgressIndicator(color: primaryTeal),
              ),
            )
          : SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Item
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.nama,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Estimasi Awal: ${RupiahFormatter.format(estimasi)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Input Nominal Realisasi
                  TextField(
                    controller: _nominalRealCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      RupiahInputFormatter(),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Nominal Realisasi (Rp)',
                      helperText: selisih >= 0
                          ? 'Hemat ${RupiahFormatter.format(selisih)} dari estimasi'
                          : 'Lebih ${RupiahFormatter.format(selisih.abs())} dari estimasi',
                      helperStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selisih >= 0
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Pilihan Pos Dana
                  const Text(
                    'Pilih Pos Dana Sumber (Keuangan):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),

                  if (_posDanaList.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Color(0xFFE65100), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Belum ada Pos Dana di Keuangan. Sistem akan membuat pos baru secara otomatis.',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF7C2D12)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: _selectedPosDanaNama,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: _posDanaList.map((p) {
                        return DropdownMenuItem<String>(
                          value: p.nama,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                p.nama,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Saldo: ${RupiahFormatter.format(p.balance)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPosDanaNama = val;
                        });
                      },
                    ),

                  // Preview Saldo Setelah Pemotongan
                  if (selectedPos != null && currentInputNominal > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDCFCE7)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 14, color: Color(0xFF16A34A)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Sisa saldo "${selectedPos.nama}": ${RupiahFormatter.format(selectedPos.balance - currentInputNominal < 0 ? 0 : selectedPos.balance - currentInputNominal)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF15803D),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Tanggal Realisasi
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _tanggalRealisasi,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _tanggalRealisasi = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded,
                              size: 18, color: primaryTeal),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tanggal: ${DateFormat('dd MMMM yyyy').format(_tanggalRealisasi)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down,
                              color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Catatan Opsional
                  TextField(
                    controller: _catatanCtrl,
                    decoration: InputDecoration(
                      labelText: 'Catatan / Keterangan (Opsional)',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryTeal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Realisasikan & Potong Saldo'),
        ),
      ],
    );
  }
}
