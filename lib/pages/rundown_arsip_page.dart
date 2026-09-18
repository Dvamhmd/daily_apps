import 'dart:convert';
import 'package:daily_apps/models/model_rundown.dart';
import 'package:daily_apps/pages/rundown_detail_page.dart';
import 'package:daily_apps/utils/responsive_text.dart';
import 'package:daily_apps/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RundownArsipPage extends StatefulWidget {
  final VoidCallback? onRundownsChanged;

  const RundownArsipPage({
    super.key,
    this.onRundownsChanged,
  });

  @override
  State<RundownArsipPage> createState() => _RundownArsipPageState();
}

class _RundownArsipPageState extends State<RundownArsipPage> {
  static const Color primaryTeal = Color(0xFF00897B);

  List<Rundown> _allRundowns = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final rawData = prefs.getStringList('rundowns_data') ?? [];
    setState(() {
      _allRundowns = rawData
          .map((e) => Rundown.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final rawData = _allRundowns.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('rundowns_data', rawData);
    widget.onRundownsChanged?.call();
  }

  List<Rundown> get _archivedRundowns {
    final list = _allRundowns.where((r) => r.isArchived).toList();
    if (_searchQuery.trim().isEmpty) return list;
    final query = _searchQuery.toLowerCase().trim();
    return list.where((r) => r.title.toLowerCase().contains(query)).toList();
  }

  Future<void> _restoreRundown(Rundown rundown) async {
    HapticFeedback.mediumImpact();
    final index = _allRundowns.indexWhere((r) => r.id == rundown.id);
    if (index != -1) {
      setState(() {
        _allRundowns[index] = _allRundowns[index].copyWith(isArchived: false);
      });
      await _saveData();

      if (mounted) {
        CustomToast.showSuccess(
          context,
          title: 'Rundown Dipulihkan',
          subtitle: 'Rundown "${rundown.title}" berhasil dikembalikan ke daftar aktif.',
        );
      }
    }
  }

  Future<void> _deleteRundown(Rundown rundown) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Hapus Rundown Permanen',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Apakah kamu yakin ingin menghapus rundown "${rundown.title}" secara permanen dari arsip?',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Hapus Permanen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final index = _allRundowns.indexWhere((r) => r.id == rundown.id);
      if (index != -1) {
        setState(() {
          _allRundowns.removeAt(index);
        });
        await _saveData();
      }
    }
  }

  void _navigateToDetail(Rundown rundown) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RundownDetailPage(
          rundown: rundown,
          onRundownChanged: (updated) {
            final index = _allRundowns.indexWhere((r) => r.id == updated.id);
            if (index != -1) {
              setState(() {
                _allRundowns[index] = updated;
              });
              _saveData();
            }
          },
          onRundownDeleted: () {
            final index = _allRundowns.indexWhere((r) => r.id == rundown.id);
            if (index != -1) {
              setState(() {
                _allRundowns.removeAt(index);
              });
              _saveData();
            }
          },
        ),
      ),
    );
  }

  String _formatDateShort(DateTime date) {
    try {
      return DateFormat('d MMM yyyy').format(date);
    } catch (_) {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final archivedList = _archivedRundowns;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: primaryTeal,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Arsip Rundown',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: primaryTeal),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: ResponsiveContentWrapper(
                  maxWidth: 720,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Box (if there are archived items or searching)
                      if (_allRundowns.any((r) => r.isArchived) ||
                          _searchQuery.isNotEmpty) ...[
                        _buildSearchBar(),
                        const SizedBox(height: 16),
                      ],

                      // Section Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Daftar Rundown Diarsipkan (${archivedList.length})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      if (archivedList.isEmpty) ...[
                        _buildEmptyState(),
                      ] else ...[
                        _buildArchivedList(archivedList),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00897B).withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        decoration: InputDecoration(
          hintText: 'Cari rundown di arsip...',
          hintStyle: const TextStyle(
            fontSize: 13,
            color: Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: primaryTeal,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildArchivedList(List<Rundown> list) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final rundown = list[index];
        return _buildArchivedCard(rundown);
      },
    );
  }

  Widget _buildArchivedCard(Rundown rundown) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFCBD5E1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToDetail(rundown),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Title & Action
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF64748B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: Color(0xFF64748B),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  rundown.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFFDE68A),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Text(
                                  'ARSIP',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFB45309),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 13,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                rundown.totalDays == 1
                                    ? _formatDateShort(rundown.startDate)
                                    : '${_formatDateShort(rundown.startDate)} - ${_formatDateShort(rundown.endDate)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded,
                          color: Color(0xFF94A3B8), size: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onSelected: (val) {
                        if (val == 'restore') {
                          _restoreRundown(rundown);
                        } else if (val == 'detail') {
                          _navigateToDetail(rundown);
                        } else if (val == 'delete') {
                          _deleteRundown(rundown);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'detail',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_rounded,
                                  size: 18, color: primaryTeal),
                              SizedBox(width: 8),
                              Text('Lihat Rincian'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'restore',
                          child: Row(
                            children: [
                              Icon(Icons.unarchive_outlined,
                                  size: 18, color: primaryTeal),
                              SizedBox(width: 8),
                              Text('Pulihkan ke Aktif'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  size: 18, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text('Hapus Permanen',
                                  style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Middle: Days & Themes Preview
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF64748B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${rundown.totalDays} HARI KEGIATAN',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Text(
                            '${rundown.days.length} Sesi Terjadwal',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...rundown.days.take(3).map((day) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF94A3B8),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Day ${day.dayNumber}: ',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  day.theme.isNotEmpty
                                      ? day.theme
                                      : 'Agenda Hari Ke-${day.dayNumber}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (rundown.days.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '+ ${rundown.days.length - 3} hari kegiatan lainnya',
                            style: const TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Bottom Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _restoreRundown(rundown),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.unarchive_outlined, size: 15),
                      label: const Text(
                        'Pulihkan ke Aktif',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Lihat Rincian',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFCBD5E1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF64748B).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 38,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Belum Ada Rundown Diarsipkan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Tidak ditemukan rundown arsip yang cocok dengan "$_searchQuery".'
                : 'Rundown acara yang telah selesai dapat diarsipkan dari menu pada daftar utama agar tidak memenuhi layar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
