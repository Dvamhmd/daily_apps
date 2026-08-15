import 'package:daily_apps/models/model_tagihan.dart';
import 'package:daily_apps/pages/riwayat_page.dart';
import 'package:daily_apps/utils/notification_service.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum StatusKesehatan { sehat, perhatian, kritis }

class FinancialHealthHelper {
  static StatusKesehatan getStatus(int totalUangku, int totalTagihan) {
    final danaAman = totalUangku - totalTagihan;
    if (danaAman < 0) {
      return StatusKesehatan.kritis;
    }
    if (totalUangku > 0 && danaAman > (0.5 * totalUangku)) {
      return StatusKesehatan.sehat;
    }
    return StatusKesehatan.perhatian;
  }

  static Color getStatusColor(StatusKesehatan status) {
    switch (status) {
      case StatusKesehatan.sehat:
        return const Color(0xFF2E7D32); // Green
      case StatusKesehatan.perhatian:
        return const Color(0xFFE65100); // Amber/Orange
      case StatusKesehatan.kritis:
        return const Color(0xFFD46A6A); // Red
    }
  }

  static String getStatusTitle(StatusKesehatan status) {
    switch (status) {
      case StatusKesehatan.sehat:
        return 'Keuangan Sehat';
      case StatusKesehatan.perhatian:
        return 'Perlu Perhatian';
      case StatusKesehatan.kritis:
        return 'Kritis / Defisit';
    }
  }

  static String getStatusDesc(StatusKesehatan status) {
    switch (status) {
      case StatusKesehatan.sehat:
        return 'Dana aman kamu lebih dari 50% pemasukan. Alokasi dana sangat aman!';
      case StatusKesehatan.perhatian:
        return 'Dana aman tersisa cukup tipis. Batasi pengeluaran non-primer.';
      case StatusKesehatan.kritis:
        return 'Beban tagihan melebihi saldo uangku! Segera sesuaikan anggaran.';
    }
  }

  static IconData getStatusIcon(StatusKesehatan status) {
    switch (status) {
      case StatusKesehatan.sehat:
        return Icons.health_and_safety_rounded;
      case StatusKesehatan.perhatian:
        return Icons.warning_rounded;
      case StatusKesehatan.kritis:
        return Icons.error_rounded;
    }
  }
}

class AppDrawer extends StatelessWidget {
  final int totalUangku;
  final int totalTagihan;
  final int totalTabungan;
  final VoidCallback onDataChanged;

  const AppDrawer({
    super.key,
    required this.totalUangku,
    required this.totalTagihan,
    required this.totalTabungan,
    required this.onDataChanged,
  });

  @override
  Widget build(BuildContext context) {
    final status =
        FinancialHealthHelper.getStatus(totalUangku, totalTagihan);
    final statusColor = FinancialHealthHelper.getStatusColor(status);
    final statusTitle = FinancialHealthHelper.getStatusTitle(status);
    final statusDesc = FinancialHealthHelper.getStatusDesc(status);
    final statusIcon = FinancialHealthHelper.getStatusIcon(status);

    final danaAman = totalUangku - totalTagihan;

    return Drawer(
      backgroundColor: const Color(0xFFF7F9FC),
      child: Column(
        children: [
          // Drawer Header with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF5E35B1), Color(0xFF7E57C2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Apps',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Manajemen Keuangan Harian',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // Financial Health Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.08),
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
                          Icon(statusIcon, color: statusColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            statusTitle,
                            style: GoogleFonts.poppins(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        statusDesc,
                        style: GoogleFonts.poppins(
                          color: Colors.grey[700],
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                      const Divider(height: 18),
                      // Mini Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniStat('Uangku', totalUangku, const Color(0xFF1976D2)),
                          _buildMiniStat('Tagihan', totalTagihan, const Color(0xFFD46A6A)),
                          _buildMiniStat('Dana Aman', danaAman, statusColor),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                Text(
                  'FITUR & MENU',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),

                // Menu items
                _buildMenuItem(
                  context: context,
                  icon: Icons.history_rounded,
                  iconColor: const Color(0xFF5E35B1),
                  title: 'Riwayat Keuangan',
                  subtitle: 'Catatan seluruh transaksi & perubahan',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RiwayatPage()),
                    ).then((_) => onDataChanged());
                  },
                ),

                _buildMenuItem(
                  context: context,
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: const Color(0xFF2E7D32),
                  title: 'Arsip Tagihan Lunas',
                  subtitle: 'Lihat daftar tagihan yang telah dibayar',
                  onTap: () {
                    Navigator.pop(context);
                    _showArsipTagihanLunas(context);
                  },
                ),

                _buildMenuItem(
                  context: context,
                  icon: Icons.notifications_active_rounded,
                  iconColor: const Color(0xFFE65100),
                  title: 'Pengingat Notifikasi',
                  subtitle: 'Pengingat deadline tagihan H-3 & H-1',
                  onTap: () {
                    Navigator.pop(context);
                    _showPengaturanNotifikasi(context);
                  },
                ),
              ],
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Daily Apps v1.0.0',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[400],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, int amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
        ),
        Text(
          RupiahFormatter.format(amount),
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey[500],
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
      ),
    );
  }

  void _showArsipTagihanLunas(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final rawLunas = prefs.getStringList('tagihan_lunas') ?? [];
    final listLunas =
        rawLunas.map((e) => Tagihan.fromJson(jsonDecode(e))).toList();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
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
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF2E7D32),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Arsip Tagihan Lunas',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Daftar tagihan yang telah diselesaikan',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: listLunas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 48,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada tagihan yang dibayar',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Klik tombol "Bayar" pada kartu Tagihan saat sudah melunasi.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: listLunas.length,
                      itemBuilder: (ctx, i) {
                        final item = listLunas[i];
                        final tglStr = item.tanggalLunas != null
                            ? '${item.tanggalLunas!.day}/${item.tanggalLunas!.month}/${item.tanggalLunas!.year}'
                            : '-';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F9FC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.nama,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Lunas: $tglStr ${item.dibayarDari != null ? '• dari ${item.dibayarDari}' : ''}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                RupiahFormatter.format(item.jumlah),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: const Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPengaturanNotifikasi(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active_rounded,
                color: Color(0xFFE65100), size: 24),
            const SizedBox(width: 8),
            Text(
              'Pengingat Deadline',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aplikasi akan mengirimkan notifikasi otomatis ke HP kamu:',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            _buildNotificationFeatureItem(
              '🔔 H-3 Sebelum Jatuh Tempo',
              'Memberi waktu persiapan dana untuk membayar tagihan.',
            ),
            const SizedBox(height: 8),
            _buildNotificationFeatureItem(
              '⚠️ H-1 Sebelum Jatuh Tempo',
              'Mengingatkan tagihan yang jatuh tempo besok agar tidak terlewat.',
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E35B1),
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.security_update_good_rounded, color: Colors.white, size: 18),
              label: Text(
                'Minta Izin Notifikasi',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              onPressed: () async {
                await NotificationService.requestPermissions();
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Izin notifikasi telah diminta!',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: const Color(0xFF2E7D32),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Tutup', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationFeatureItem(String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
