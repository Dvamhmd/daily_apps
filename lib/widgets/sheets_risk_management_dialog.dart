import 'package:flutter/material.dart';
import '../utils/rupiah_formatter.dart';
import '../utils/sheets_sync_service.dart';

enum SheetsConflictChoice {
  useAppData,
  useSheetData,
  cancel,
}

class SheetsRiskManagementDialog extends StatelessWidget {
  final SheetsSyncComparison comparison;
  final String sheetName;

  const SheetsRiskManagementDialog({
    super.key,
    required this.comparison,
    required this.sheetName,
  });

  static Future<SheetsConflictChoice?> show(
    BuildContext context, {
    required SheetsSyncComparison comparison,
    required String sheetName,
    bool useRootNavigator = true,
  }) {
    return showDialog<SheetsConflictChoice>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierDismissible: false,
      builder: (ctx) => SheetsRiskManagementDialog(
        comparison: comparison,
        sheetName: sheetName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFFD97706),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manajemen Risiko Data',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Ditemukan perbedaan data di Spreadsheet & Aplikasi',
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
              // Ringkasan Alasan Perbedaan
              if (comparison.discrepancyReasons.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: comparison.discrepancyReasons
                        .map(
                          (r) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ',
                                    style: TextStyle(
                                        color: Color(0xFFD97706),
                                        fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(
                                    r,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),

              // Kartu Perbandingan Berdampingan / Vertikal Bersih
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kartu Kiri: Data Aplikasi
                  Expanded(
                    child: _buildComparisonCard(
                      title: 'Data Aplikasi',
                      badge: 'Lokal',
                      themeColor: const Color(0xFF7C3AED),
                      bgColor: const Color(0xFFF5F3FF),
                      borderColor: const Color(0xFFDDD6FE),
                      rekeningCount: comparison.localRekeningCount,
                      rekeningDebit: comparison.localRekeningDebit,
                      rekeningKredit: comparison.localRekeningKredit,
                      onHandCount: comparison.localOnHandCount,
                      onHandDebit: comparison.localOnHandDebit,
                      onHandKredit: comparison.localOnHandKredit,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Kartu Kanan: Data Spreadsheet
                  Expanded(
                    child: _buildComparisonCard(
                      title: 'Spreadsheet',
                      badge: sheetName,
                      themeColor: const Color(0xFF059669),
                      bgColor: const Color(0xFFECFDF5),
                      borderColor: const Color(0xFFA7F3D0),
                      rekeningCount: comparison.remoteRekeningCount,
                      rekeningDebit: comparison.remoteRekeningDebit,
                      rekeningKredit: comparison.remoteRekeningKredit,
                      onHandCount: comparison.remoteOnHandCount,
                      onHandDebit: comparison.remoteOnHandDebit,
                      onHandKredit: comparison.remoteOnHandKredit,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                'Pilih sumber data yang ingin Anda pertahankan:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),

              // Opsi 1: Gunakan Data Aplikasi
              _buildChoiceButton(
                context,
                title: 'Gunakan Data Aplikasi',
                subtitle: 'Kirim data aplikasi & perbarui Google Spreadsheet',
                icon: Icons.upload_rounded,
                color: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFF5F3FF),
                borderColor: const Color(0xFFDDD6FE),
                onTap: () =>
                    Navigator.pop(context, SheetsConflictChoice.useAppData),
              ),
              const SizedBox(height: 8),

              // Opsi 2: Gunakan Data Spreadsheet
              _buildChoiceButton(
                context,
                title: 'Gunakan Data Spreadsheet',
                subtitle:
                    'Tarik data Spreadsheet & sesuaikan data aplikasi lokal',
                icon: Icons.download_rounded,
                color: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
                borderColor: const Color(0xFFA7F3D0),
                onTap: () =>
                    Navigator.pop(context, SheetsConflictChoice.useSheetData),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () =>
                Navigator.pop(context, SheetsConflictChoice.cancel),
            child: const Text(
              'Batal (Jangan Ubah Data)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonCard({
    required String title,
    required String badge,
    required Color themeColor,
    required Color bgColor,
    required Color borderColor,
    required int rekeningCount,
    required int rekeningDebit,
    required int rekeningKredit,
    required int onHandCount,
    required int onHandDebit,
    required int onHandKredit,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 12),

          // Rekening Info
          const Text('Rekening:',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569))),
          Text('$rekeningCount transaksi',
              style:
                  const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
          Text('Masuk: Rp ${RupiahFormatter.format(rekeningDebit)}',
              style: const TextStyle(
                  fontSize: 9.5,
                  color: Color(0xFF16A34A),
                  fontWeight: FontWeight.w500)),
          Text('Keluar: Rp ${RupiahFormatter.format(rekeningKredit)}',
              style: const TextStyle(
                  fontSize: 9.5,
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w500)),

          const SizedBox(height: 6),

          // On Hand Info
          const Text('Cash On Hand:',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569))),
          Text('$onHandCount transaksi',
              style:
                  const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
          Text('Masuk: Rp ${RupiahFormatter.format(onHandDebit)}',
              style: const TextStyle(
                  fontSize: 9.5,
                  color: Color(0xFF16A34A),
                  fontWeight: FontWeight.w500)),
          Text('Keluar: Rp ${RupiahFormatter.format(onHandKredit)}',
              style: const TextStyle(
                  fontSize: 9.5,
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildChoiceButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: color),
          ],
        ),
      ),
    );
  }
}
