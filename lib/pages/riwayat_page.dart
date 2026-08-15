import 'package:daily_apps/models/model_riwayat.dart';
import 'package:daily_apps/utils/riwayat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  List<ModelRiwayat> _riwayatList = [];
  bool _isLoading = true;
  String _selectedFilter = 'Semua'; // 'Semua', 'Tagihan', 'Uangku'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRiwayat();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRiwayat() async {
    setState(() => _isLoading = true);
    final data = await RiwayatService.getRiwayat();
    setState(() {
      _riwayatList = data;
      _isLoading = false;
    });
  }

  List<ModelRiwayat> get _filteredRiwayat {
    return _riwayatList.where((item) {
      final matchesFilter = _selectedFilter == 'Semua' ||
          item.kategori.toLowerCase() == _selectedFilter.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          item.perubahan.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.kategori.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();
  }

  int get _countTagihan =>
      _riwayatList.where((e) => e.kategori.toLowerCase() == 'tagihan').length;

  int get _countUangku =>
      _riwayatList.where((e) => e.kategori.toLowerCase() == 'uangku').length;

  int get _countTabungan =>
      _riwayatList.where((e) => e.kategori.toLowerCase() == 'tabungan').length;

  String _formatDateTime(DateTime dt) {
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    final jam = dt.hour.toString().padLeft(2, '0');
    final menit = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${bulan[dt.month - 1]} ${dt.year} • $jam:$menit';
  }

  void _konfirmasiHapusSemua() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFD46A6A), size: 28),
            const SizedBox(width: 10),
            Text(
              'Hapus Semua Riwayat?',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Seluruh catatan perubahan keuangan akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD46A6A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await RiwayatService.hapusSemuaRiwayat();
              await _loadRiwayat();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Semua riwayat berhasil dihapus',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: const Color(0xFF5E35B1),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            },
            child: Text(
              'Hapus Semua',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _hapusItem(ModelRiwayat item) async {
    await RiwayatService.hapusItemRiwayat(item.id);
    await _loadRiwayat();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '1 riwayat dihapus',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFF5E35B1),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Color _getKategoriColor(String kategori) {
    final cat = kategori.toLowerCase();
    if (cat == 'tagihan') {
      return const Color(0xFFE91E63); // Pink
    } else if (cat == 'tabungan') {
      return const Color(0xFFE65100); // Dark Orange / Amber
    }
    return const Color(0xFF2E7D32); // Dark Green
  }

  Color _getKategoriBgColor(String kategori) {
    final cat = kategori.toLowerCase();
    if (cat == 'tagihan') {
      return const Color(0xFFFFEBEE); // Soft Pink/Red
    } else if (cat == 'tabungan') {
      return const Color(0xFFFFF3E0); // Soft Orange / Amber
    }
    return const Color(0xFFD9FAD1); // Soft Green
  }

  IconData _getTipeIcon(String tipe) {
    switch (tipe) {
      case 'tambah':
        return Icons.add_circle_outline_rounded;
      case 'kurang':
        return Icons.remove_circle_outline_rounded;
      case 'hapus':
        return Icons.delete_outline_rounded;
      case 'edit':
        return Icons.edit_note_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _getTipeColor(String tipe) {
    switch (tipe) {
      case 'tambah':
        return const Color(0xFF2E7D32); // Green
      case 'kurang':
        return const Color(0xFFE65100); // Orange
      case 'hapus':
        return const Color(0xFFD46A6A); // Red
      case 'edit':
        return const Color(0xFF1976D2); // Blue
      default:
        return const Color(0xFF5E35B1); // Purple
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRiwayat;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5E35B1),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: Text(
          'Riwayat Keuangan',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (_riwayatList.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded,
                  color: Colors.white, size: 26),
              tooltip: 'Hapus Semua Riwayat',
              onPressed: _konfirmasiHapusSemua,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Top Filter & Search Section
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Field
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Cari riwayat perubahan...',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF5E35B1), size: 22),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Semua', _riwayatList.length),
                      const SizedBox(width: 8),
                      _buildFilterChip('Tagihan', _countTagihan),
                      const SizedBox(width: 8),
                      _buildFilterChip('Uangku', _countUangku),
                      const SizedBox(width: 8),
                      _buildFilterChip('Tabungan', _countTabungan),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF5E35B1),
                    ),
                  )
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadRiwayat,
                        color: const Color(0xFF5E35B1),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return _buildRiwayatCard(item, index);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String title, int count) {
    final isSelected = _selectedFilter.toLowerCase() == title.toLowerCase();

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          _selectedFilter = title;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5E35B1) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF5E35B1)
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiwayatCard(ModelRiwayat item, int index) {
    final kategoriColor = _getKategoriColor(item.kategori);
    final kategoriBg = _getKategoriBgColor(item.kategori);
    final tipeColor = _getTipeColor(item.tipe);
    final tipeIcon = _getTipeIcon(item.tipe);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Datetime & Kategori Badge & Delete Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Datetime column
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _formatDateTime(item.datetime),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),

                Row(
                  children: [
                    // Kategori Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kategoriBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: kategoriColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        item.kategori,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: kategoriColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Delete item icon
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 16, color: Colors.grey[400]),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 16,
                      tooltip: 'Hapus entri ini',
                      onPressed: () => _hapusItem(item),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 0.7),
            const SizedBox(height: 10),

            // Perubahan Content Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Indicator
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tipeColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    tipeIcon,
                    color: tipeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Perubahan text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Perubahan:',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.perubahan,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF5E35B1).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearching
                    ? Icons.search_off_rounded
                    : Icons.history_toggle_off_rounded,
                size: 64,
                color: const Color(0xFF5E35B1),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isSearching
                  ? 'Riwayat Tidak Ditemukan'
                  : 'Belum Ada Riwayat Perubahan',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Coba kata kunci lain untuk mencari riwayat perubahan.'
                  : 'Setiap kamu menambah, mengubah, atau menghapus Tagihan dan Uangku, riwayat perubahannya akan otomatis tercatat di sini.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
