import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/model_serious_mode.dart';
import '../utils/serious_mode_service.dart';
import '../widgets/custom_toast.dart';

class SeriousPunishmentConfigPage extends StatefulWidget {
  const SeriousPunishmentConfigPage({super.key});

  @override
  State<SeriousPunishmentConfigPage> createState() =>
      _SeriousPunishmentConfigPageState();
}

class _SeriousPunishmentConfigPageState
    extends State<SeriousPunishmentConfigPage> {
  static const Color darkBg = Color(0xFF0F172A);
  static const Color cardBg = Color(0xFF1E293B);
  static const Color cardBgElevated = Color(0xFF273549);
  static const Color accentGold = Color(0xFFF59E0B);
  static const Color accentFire = Color(0xFFEF4444);
  static const Color accentBlue = Color(0xFF38BDF8);

  String _currentMode = SeriousPunishmentMode.defaultMode;
  List<SeriousPunishmentItem> _customPunishments = [];
  bool _isLoading = true;
  bool _showDefaultList = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final mode = await SeriousModeService.getPunishmentMode();
      final customs = await SeriousModeService.getCustomPunishments();
      if (mounted) {
        setState(() {
          _currentMode = mode;
          _customPunishments = customs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _changeMode(String newMode) async {
    if (_currentMode == newMode) return;
    HapticFeedback.selectionClick();

    if (newMode == SeriousPunishmentMode.mandiri &&
        _customPunishments.isEmpty) {
      _showMandiriEmptyWarning();
    }

    await SeriousModeService.setPunishmentMode(newMode);
    setState(() {
      _currentMode = newMode;
    });

    if (mounted) {
      CustomToast.showSuccess(
        context,
        title: 'Opsi Hukuman Diubah',
        subtitle: 'Mode penerapan sekarang: ${SeriousPunishmentMode.getLabel(newMode)}',
      );
    }
  }

  void _showMandiriEmptyWarning() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: accentGold, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: accentGold, size: 24),
            SizedBox(width: 8),
            Text(
              'Perhatian Mode Mandiri',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Kamu belum menambahkan hukuman buatanmu sendiri.\n\nSilakan tekan tombol "+ Tambah Hukuman" di bawah agar hukuman kustommu bisa diterapkan saat ada task yang terlewat.',
          style: TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentGold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _openAddEditBottomSheet();
            },
            child: const Text('Buat Hukuman Sekarang'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddEditBottomSheet([SeriousPunishmentItem? existingItem]) async {
    final isEditing = existingItem != null;
    final titleController =
        TextEditingController(text: existingItem?.title ?? '');
    final repsController =
        TextEditingController(text: existingItem?.repsOrDuration ?? '');
    final targetMuscleController =
        TextEditingController(text: existingItem?.targetMuscle ?? '');
    final descController =
        TextEditingController(text: existingItem?.description ?? '');

    String selectedEmoji = existingItem?.emoji ?? '💪';
    String selectedCategory = existingItem?.category ?? 'Fisik';

    final presetEmojis = [
      '💪', '⚡', '🧘', '🏃', '🏋️', '🥊', '🚴', '🎯',
      '📚', '✍️', '🧹', '🥤', '🚫', '⏱️', '🧠', '🪜',
      '🚿', '🌱', '🚶', '🤸', '📖', '🥗', '📵', '🔥'
    ];

    final presetCategories = [
      'Fisik', 'Mental', 'Disiplin', 'Edukasi', 'Kebersihan', 'Kesehatan', 'Lainnya'
    ];

    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: darkBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: accentGold, width: 2),
                ),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header BottomSheet
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accentGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              selectedEmoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing
                                      ? 'Edit Hukuman Kustom'
                                      : 'Tambah Hukuman Kustom Baru',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  isEditing
                                      ? 'Perbarui detail hukuman buatanmu'
                                      : 'Tulis hukuman disiplin sesuai keinginanmu',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white60),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFF334155), height: 1),
                      const SizedBox(height: 14),

                      // Pilih Emoji
                      const Text(
                        'PILIH IKON EMOJI',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: presetEmojis.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final em = presetEmojis[idx];
                            final isSelected = em == selectedEmoji;
                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                setSheetState(() => selectedEmoji = em);
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? accentGold.withValues(alpha: 0.25)
                                      : cardBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? accentGold
                                        : const Color(0xFF334155),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Text(em, style: const TextStyle(fontSize: 20)),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Judul Hukuman
                      const Text(
                        'JUDUL HUKUMAN *',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: titleController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Contoh: Push Up 30x / Baca Buku 15 Menit',
                          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          filled: true,
                          fillColor: cardBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: accentGold, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Judul hukuman wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Repetisi / Durasi & Kategori
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DURASI / REPETISI',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: repsController,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Misal: 20 Repetisi / 15 Menit',
                                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                    filled: true,
                                    fillColor: cardBg,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFF334155)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFF334155)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: accentGold, width: 1.5),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'FOKUS / TARGET',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: targetMuscleController,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Misal: Core / Otak / Disiplin',
                                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                    filled: true,
                                    fillColor: cardBg,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFF334155)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFF334155)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: accentGold, width: 1.5),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Kategori Chips
                      const Text(
                        'KATEGORI',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: presetCategories.map((cat) {
                          final isSelected = cat == selectedCategory;
                          return InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              setSheetState(() => selectedCategory = cat);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? accentGold.withValues(alpha: 0.2)
                                    : cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? accentGold
                                      : const Color(0xFF334155),
                                ),
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? accentGold : const Color(0xFFCBD5E1),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Deskripsi Aturan
                      const Text(
                        'DESKRIPSI / ATURAN PENGERJAAN',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: descController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Tuliskan cara pengerjaan atau aturan hukuman ini...',
                          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          filled: true,
                          fillColor: cardBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: accentGold, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tombol Simpan
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentGold,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.check_circle_rounded, size: 20),
                          label: Text(
                            isEditing ? 'Simpan Perubahan' : 'Tambahkan Hukuman',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;

                            final item = SeriousPunishmentItem(
                              id: existingItem?.id ??
                                  'custom_${DateTime.now().millisecondsSinceEpoch}',
                              title: titleController.text.trim(),
                              description: descController.text.trim().isNotEmpty
                                  ? descController.text.trim()
                                  : 'Selesaikan tantangan disiplin ini dengan penuh komitmen.',
                              emoji: selectedEmoji,
                              category: selectedCategory,
                              repsOrDuration: repsController.text.trim(),
                              targetMuscle: targetMuscleController.text.trim().isNotEmpty
                                  ? targetMuscleController.text.trim()
                                  : 'Komitmen & Disiplin',
                              isCustom: true,
                            );

                            Navigator.pop(ctx);

                            if (isEditing) {
                              await SeriousModeService.updateCustomPunishment(item);
                            } else {
                              await SeriousModeService.addCustomPunishment(item);
                            }

                            if (!mounted) return;
                            await _loadData();

                            if (mounted) {
                              CustomToast.showSuccess(
                                this.context,
                                title: isEditing
                                    ? 'Hukuman Diperbarui'
                                    : 'Hukuman Kustom Ditambahkan! 🎉',
                                subtitle: item.title,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleDeleteCustom(SeriousPunishmentItem item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: accentFire, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: accentFire, size: 24),
            SizedBox(width: 8),
            Text(
              'Hapus Hukuman?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah kamu yakin ingin menghapus hukuman "${item.title}"?',
          style: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 13,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentFire,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SeriousModeService.deleteCustomPunishment(item.id);
      await _loadData();
      if (mounted) {
        CustomToast.showWarning(
          context,
          title: 'Hukuman Dihapus',
          subtitle: item.title,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customCount = _customPunishments.length;
    final totalDefaultCount = SeriousModeService.punishmentList.length;

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hukuman',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            Text(
              'Mode Serius • Personalisasi Disiplin',
              style: TextStyle(
                color: accentGold,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Tambah Hukuman Baru',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentGold.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, color: accentGold, size: 20),
            ),
            onPressed: () => _openAddEditBottomSheet(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentGold))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Top Info Banner
                _buildInfoBanner(),
                const SizedBox(height: 18),

                // 1. Selector 3 Opsi Penerapan Hukuman
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: accentGold, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'PILIHAN PENERAPAN HUKUMAN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accentGold.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        SeriousPunishmentMode.getShortLabel(_currentMode).toUpperCase(),
                        style: const TextStyle(
                          color: accentGold,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 3 Mode Option Cards
                _buildModeCard(
                  mode: SeriousPunishmentMode.mandiri,
                  title: '1. Mandiri',
                  desc: 'Hanya menerapkan hukuman yang kamu tulis dan buat sendiri.',
                  badge: '$customCount Hukuman Kustom',
                  iconEmoji: '✍️',
                  isSelected: _currentMode == SeriousPunishmentMode.mandiri,
                  accentColor: const Color(0xFF38BDF8),
                  badgeColor: const Color(0xFF0369A1),
                ),
                const SizedBox(height: 8),

                _buildModeCard(
                  mode: SeriousPunishmentMode.defaultMode,
                  title: '2. Default',
                  desc: 'Menerapkan 20 daftar hukuman olahraga fisik bawaan aplikasi.',
                  badge: '$totalDefaultCount Hukuman Default',
                  iconEmoji: '🏋️',
                  isSelected: _currentMode == SeriousPunishmentMode.defaultMode,
                  accentColor: accentGold,
                  badgeColor: const Color(0xFF92400E),
                ),
                const SizedBox(height: 8),

                _buildModeCard(
                  mode: SeriousPunishmentMode.campuran,
                  title: '3. Campuran',
                  desc: 'Menggabungkan hukuman default dan buatan sendiri secara acak.',
                  badge: '${totalDefaultCount + customCount} Total Hukuman',
                  iconEmoji: '🎲',
                  isSelected: _currentMode == SeriousPunishmentMode.campuran,
                  accentColor: const Color(0xFFA855F7),
                  badgeColor: const Color(0xFF6B21A8),
                ),

                const SizedBox(height: 24),

                // 2. Daftar Hukuman Kustom Pengguna
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note_rounded,
                            color: Color(0xFF38BDF8), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'HUKUMAN BUATAN SENDIRI ($customCount)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text(
                        'Tambah',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _openAddEditBottomSheet(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_customPunishments.isEmpty)
                  _buildEmptyCustomState()
                else
                  for (final item in _customPunishments) ...[
                    _buildCustomPunishmentCard(item),
                    const SizedBox(height: 8),
                  ],

                const SizedBox(height: 20),

                // 3. Daftar Hukuman Default Aplikasi (Collapsible)
                _buildDefaultPunishmentsCollapsible(totalDefaultCount),

                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentGold.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('🔥', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cara Kerja Hukuman Mode Serius',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Saat tanggal section to-do telah terlewat dan ada tugas yang belum selesai, sistem akan mengundi hukuman dari opsi penerapan yang kamu pilih di sini.',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String mode,
    required String title,
    required String desc,
    required String badge,
    required String iconEmoji,
    required bool isSelected,
    required Color accentColor,
    required Color badgeColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _changeMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? cardBgElevated
              : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFF334155),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Radio Circle
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accentColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? accentColor : const Color(0xFF64748B),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.black,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(iconEmoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCustomState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF334155),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          const Text('📝', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 10),
          const Text(
            'Belum Ada Hukuman Kustom',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Buat hukuman disiplinmu sendiri seperti membaca buku, lari keliling, atau bersih-bersih.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: accentGold,
              side: const BorderSide(color: accentGold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Buat Hukuman Pertama',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            onPressed: () => _openAddEditBottomSheet(),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomPunishmentCard(SeriousPunishmentItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF334155),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Text(item.emoji, style: const TextStyle(fontSize: 22)),
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
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (item.repsOrDuration.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.repsOrDuration,
                          style: const TextStyle(
                            color: accentGold,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Text(
                        item.category,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${item.targetMuscle}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white60, size: 20),
            color: cardBgElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (action) {
              if (action == 'edit') {
                _openAddEditBottomSheet(item);
              } else if (action == 'delete') {
                _handleDeleteCustom(item);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, color: accentBlue, size: 18),
                    SizedBox(width: 8),
                    Text('Edit', style: TextStyle(color: Colors.white, fontSize: 12.5)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: accentFire, size: 18),
                    SizedBox(width: 8),
                    Text('Hapus', style: TextStyle(color: accentFire, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultPunishmentsCollapsible(int totalCount) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _showDefaultList,
          onExpansionChanged: (val) => setState(() => _showDefaultList = val),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('🏋️', style: TextStyle(fontSize: 18)),
          ),
          title: const Text(
            'Daftar 20 Hukuman Default Aplikasi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: const Text(
            'Latihan fisik standar bawaan aplikasi',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
            ),
          ),
          children: [
            const Divider(color: Color(0xFF334155), height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: SeriousModeService.punishmentList.length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFF273549), height: 12),
              itemBuilder: (context, idx) {
                final item = SeriousModeService.punishmentList[idx];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${idx + 1}. ${item.title}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentGold.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.repsOrDuration,
                                  style: const TextStyle(
                                    color: accentGold,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.description,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
