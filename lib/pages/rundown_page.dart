import 'dart:convert';
import 'package:daily_apps/models/model_rundown.dart';
import 'package:daily_apps/pages/rundown_arsip_page.dart';
import 'package:daily_apps/pages/rundown_detail_page.dart';
import 'package:daily_apps/utils/responsive_text.dart';
import 'package:daily_apps/widgets/custom_toast.dart';
import 'package:daily_apps/widgets/dialog_tambah_rundown.dart';
import 'package:daily_apps/widgets/gta_switch_wheel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RundownPage extends StatefulWidget {
  final ValueChanged<int> onPageSelected;

  const RundownPage({
    super.key,
    required this.onPageSelected,
  });

  @override
  State<RundownPage> createState() => _RundownPageState();
}

class _RundownPageState extends State<RundownPage> {
  static const Color primaryTeal = Color(0xFF00897B);

  List<Rundown> _rundownList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRundowns();
  }

  List<Rundown> get _activeRundowns =>
      _rundownList.where((r) => !r.isArchived).toList();

  List<Rundown> get _archivedRundowns =>
      _rundownList.where((r) => r.isArchived).toList();

  Future<void> _loadRundowns() async {
    final prefs = await SharedPreferences.getInstance();
    final rawData = prefs.getStringList('rundowns_data') ?? [];
    setState(() {
      _rundownList = rawData
          .map((e) => Rundown.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _saveRundowns() async {
    final prefs = await SharedPreferences.getInstance();
    final rawData =
        _rundownList.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('rundowns_data', rawData);
  }

  Future<void> _openTambahRundownModal() async {
    final newRundown = await ModalTambahRundown.show(context);
    if (newRundown != null) {
      setState(() {
        _rundownList.insert(0, newRundown);
      });
      await _saveRundowns();

      if (mounted) {
        CustomToast.showSuccess(
          context,
          title: 'Rundown Dibuat',
          subtitle: 'Rundown "${newRundown.title}" berhasil dibuat!',
        );

        // Langsung arahkan ke rincian rundown yang baru dibuat
        _navigateToDetail(newRundown);
      }
    }
  }

  Future<void> _openArsipPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RundownArsipPage(
          onRundownsChanged: _loadRundowns,
        ),
      ),
    );
    // Reload when returning
    _loadRundowns();
  }

  Future<void> _editRundown(Rundown target) async {
    final updated = await ModalTambahRundown.show(context, rundown: target);
    if (updated != null) {
      final index = _rundownList.indexWhere((r) => r.id == target.id);
      if (index != -1) {
        setState(() {
          _rundownList[index] = updated;
        });
        await _saveRundowns();

        if (mounted) {
          CustomToast.showSuccess(
            context,
            title: 'Rundown Diperbarui',
            subtitle: 'Rundown "${updated.title}" berhasil diperbarui!',
          );
        }
      }
    }
  }

  Future<void> _archiveRundown(Rundown rundown) async {
    HapticFeedback.mediumImpact();
    final index = _rundownList.indexWhere((r) => r.id == rundown.id);
    if (index != -1) {
      setState(() {
        _rundownList[index] = _rundownList[index].copyWith(isArchived: true);
      });
      await _saveRundowns();

      if (mounted) {
        CustomToast.showSuccess(
          context,
          title: 'Rundown Diarsipkan',
          subtitle: 'Rundown "${rundown.title}" berhasil dipindahkan ke Arsip.',
        );
      }
    }
  }

  Future<void> _deleteRundown(Rundown deleted) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Hapus Rundown',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Apakah kamu yakin ingin menghapus rundown "${deleted.title}"?',
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
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final index = _rundownList.indexWhere((r) => r.id == deleted.id);
      if (index != -1) {
        setState(() {
          _rundownList.removeAt(index);
        });
        await _saveRundowns();
      }
    }
  }

  void _navigateToDetail(Rundown rundown) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RundownDetailPage(
          rundown: rundown,
          onRundownChanged: (updated) {
            final index = _rundownList.indexWhere((r) => r.id == updated.id);
            if (index != -1) {
              setState(() {
                _rundownList[index] = updated;
              });
              _saveRundowns();
            }
          },
          onRundownDeleted: () {
            final index = _rundownList.indexWhere((r) => r.id == rundown.id);
            if (index != -1) {
              setState(() {
                _rundownList.removeAt(index);
              });
              _saveRundowns();
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
    final activeList = _activeRundowns;
    final archivedCount = _archivedRundowns.length;

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
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Rundown Acara',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          // Tombol Arsip Rundown
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.inventory_2_outlined,
                    color: Colors.white, size: 22),
                if (archivedCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Arsip Rundown ($archivedCount)',
            onPressed: _openArsipPage,
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: GtaSwitchWheel(
        currentIndex: 1, // Rundown index
        onPageSelected: widget.onPageSelected,
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
                      // Section Title & Action
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Daftar Rundown (${activeList.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (activeList.isNotEmpty)
                            TextButton.icon(
                              onPressed: _openTambahRundownModal,
                              icon: const Icon(Icons.add,
                                  size: 16, color: primaryTeal),
                              label: const Text(
                                'Tambah',
                                style: TextStyle(
                                  color: primaryTeal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // List of Active Rundowns or Empty State
                      if (activeList.isEmpty) ...[
                        _buildEmptyState(archivedCount),
                      ] else ...[
                        _buildRundownList(activeList),
                      ],

                      const SizedBox(height: 100), // Spacing for FAB
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildRundownList(List<Rundown> list) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final rundown = list[index];
        return _buildRundownCard(rundown);
      },
    );
  }

  Widget _buildRundownCard(Rundown rundown) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF00897B).withValues(alpha: 0.15),
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
                        color: primaryTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.event_note_rounded,
                        color: primaryTeal,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rundown.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
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
                        if (val == 'hapus') {
                          _deleteRundown(rundown);
                        } else if (val == 'edit') {
                          _editRundown(rundown);
                        } else if (val == 'detail') {
                          _navigateToDetail(rundown);
                        } else if (val == 'archive') {
                          _archiveRundown(rundown);
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
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(Icons.archive_outlined,
                                  size: 18, color: Color(0xFFD97706)),
                              SizedBox(width: 8),
                              Text('Arsipkan Rundown'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded,
                                  size: 18, color: Color(0xFF0284C7)),
                              SizedBox(width: 8),
                              Text('Edit Rundown'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'hapus',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  size: 18, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text('Hapus',
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
                              color: primaryTeal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${rundown.totalDays} HARI KEGIATAN',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: primaryTeal,
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
                      // List of themes (up to 3 previews)
                      ...rundown.days.take(3).map((day) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: primaryTeal,
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
                              color: primaryTeal,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Bottom Tap Cue
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Lihat Rincian Rundown',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryTeal,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: primaryTeal,
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

  Widget _buildEmptyState(int archivedCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00897B).withValues(alpha: 0.15),
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
              color: const Color(0xFF00897B).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.schedule_rounded,
              size: 38,
              color: primaryTeal,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Belum Ada Rundown Kegiatan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            archivedCount > 0
                ? 'Semua rundown aktif telah diarsipkan. Kamu memiliki $archivedCount rundown di menu Arsip (ikon di kanan atas).'
                : 'Semua susunan acara dan timeline yang kamu buat akan terkumpul di sini. Mulai buat rundown pertama kamu sekarang!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _openTambahRundownModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_task_rounded, size: 18),
            label: const Text(
              'Buat Rundown Pertama',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          if (archivedCount > 0) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _openArsipPage,
              icon: const Icon(Icons.inventory_2_outlined, size: 16, color: primaryTeal),
              label: Text(
                'Buka Arsip Rundown ($archivedCount)',
                style: const TextStyle(
                  color: primaryTeal,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
