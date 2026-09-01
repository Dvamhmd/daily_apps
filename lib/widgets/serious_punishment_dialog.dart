import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/model_serious_mode.dart';
import '../models/model_todo.dart';
import '../pages/serious_punishment_config_page.dart';
import '../utils/serious_mode_service.dart';
import 'custom_toast.dart';

class SeriousPunishmentDialog extends StatefulWidget {
  final SeriousSectionEvaluation evaluation;
  final List<TodoDateGroup> allGroups;
  final VoidCallback? onCompleted;

  const SeriousPunishmentDialog({
    super.key,
    required this.evaluation,
    this.allGroups = const [],
    this.onCompleted,
  });

  static SeriousSectionEvaluation get defaultEvaluation =>
      SeriousSectionEvaluation(
        groupId: 'general_challenge',
        date: DateTime.now(),
        completedCount: 0,
        pendingCount: 1,
        message: 'Latih komitmen dan disiplin diri dengan tantangan hukuman olahraga fisik!',
        isPunishmentRequired: false,
        isPunishmentOptional: true,
        isExempt: false,
        pointsEarned: 0,
      );

  static Future<void> show(
    BuildContext context, {
    SeriousSectionEvaluation? evaluation,
    List<TodoDateGroup> allGroups = const [],
    VoidCallback? onCompleted,
  }) {
    final eval = evaluation ?? defaultEvaluation;
    return showDialog(
      context: context,
      barrierDismissible: eval.isExempt || eval.isPunishmentOptional,
      builder: (ctx) => SeriousPunishmentDialog(
        evaluation: eval,
        allGroups: allGroups,
        onCompleted: onCompleted,
      ),
    );
  }

  @override
  State<SeriousPunishmentDialog> createState() =>
      _SeriousPunishmentDialogState();
}

class _SeriousPunishmentDialogState extends State<SeriousPunishmentDialog> {
  static const Color darkBg = Color(0xFF0F172A);
  static const Color cardBg = Color(0xFF1E293B);
  static const Color accentGold = Color(0xFFF59E0B);
  static const Color accentFire = Color(0xFFEF4444);
  static const Color accentSuccess = Color(0xFF10B981);

  SeriousGroupPunishmentState? _punishmentState;
  List<SeriousPunishmentItem> _assignedItems = [];
  String _punishmentMode = SeriousPunishmentMode.defaultMode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPunishmentState();
  }

  Future<void> _loadPunishmentState() async {
    final eval = widget.evaluation;
    final state = await SeriousModeService.getOrCreatePunishmentState(
      eval.groupId,
      eval.pendingCount,
    );
    final assignedItems = await SeriousModeService.getPunishmentItemsByIdsAsync(
      state.assignedPunishmentIds,
    );
    final mode = await SeriousModeService.getPunishmentMode();

    if (mounted) {
      setState(() {
        _punishmentState = state;
        _assignedItems = assignedItems;
        _punishmentMode = mode;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleItem(String punishmentId) async {
    if (_punishmentState == null) return;
    HapticFeedback.selectionClick();

    final updatedState = await SeriousModeService.togglePunishmentItemCompleted(
      groupId: widget.evaluation.groupId,
      punishmentId: punishmentId,
      allGroups: widget.allGroups,
    );

    if (mounted) {
      setState(() {
        _punishmentState = updatedState;
      });

      if (updatedState.isAllCompleted) {
        HapticFeedback.heavyImpact();
      }
    }
  }

  Future<void> _handleConfirmAllDone() async {
    if (_punishmentState == null) return;

    if (mounted) {
      CustomToast.showSuccess(
        context,
        title: 'Hukuman Olahraga Selesai! 💪',
        subtitle: 'Poin penuh jadwal hari ini berhasil dipertahankan!',
      );
    }
    widget.onCompleted?.call();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSurrender() async {
    if (_punishmentState == null) return;
    final remaining = _punishmentState!.remainingCount;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: accentFire, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: accentFire, size: 26),
              SizedBox(width: 10),
              Text(
                'Menyerah?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          content: Text(
            'Apakah kamu yakin ingin menyerah dari hukuman olahraga ini?\n\nPoin kamu akan dikurangi $remaining poin (-1 poin untuk setiap tugas yang belum selesai).',
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFFCBD5E1),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentFire,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Ya, Saya Menyerah'),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      await SeriousModeService.surrenderPunishment(
        groupId: widget.evaluation.groupId,
        allGroups: widget.allGroups,
      );

      if (mounted) {
        CustomToast.showWarning(
          context,
          title: 'Menyerah Diterima',
          subtitle: 'Pengurangan $remaining poin telah diterapkan pada akun Anda.',
        );
        widget.onCompleted?.call();
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eval = widget.evaluation;
    final formattedDate = DateFormat('dd/MM/yyyy').format(eval.date);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 680),
        decoration: BoxDecoration(
          color: darkBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: eval.isExempt
                ? accentSuccess
                : (eval.isPunishmentOptional ? accentGold : accentFire),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (eval.isExempt
                      ? accentSuccess
                      : (eval.isPunishmentOptional ? accentGold : accentFire))
                  .withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: eval.isExempt
                      ? [const Color(0xFF065F46), const Color(0xFF047857)]
                      : (eval.isPunishmentOptional
                          ? [const Color(0xFF78350F), const Color(0xFF92400E)]
                          : [const Color(0xFF991B1B), const Color(0xFF450A0A)]),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(
                children: [
                  Text(
                    eval.isExempt
                        ? '👑'
                        : (eval.isPunishmentOptional ? '⚡' : '🏋️'),
                    style: const TextStyle(fontSize: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eval.isExempt
                              ? 'OVER PRODUKTIF'
                              : (eval.isPunishmentOptional
                                  ? 'SANGAT PRODUKTIF (OPSIONAL)'
                                  : 'HUKUMAN OLAHRAGA FISIK'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          'Section $formattedDate • ${eval.completedCount} Selesai • ${eval.pendingCount} Terlewat',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: accentGold),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Pesan Evaluasi
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.chat_bubble_outline_rounded,
                                        color: accentGold, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'EVALUASI SECTION (${eval.completedCount} TUGAS SELESAI)',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: accentGold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '"${eval.message}"',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FontStyle.italic,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Jika OVER PRODUKTIF (>15 task selesai)
                          if (eval.isExempt) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF064E3B),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: accentSuccess.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Text('🛋️', style: TextStyle(fontSize: 22)),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Kamu telah menyelesaikan lebih dari 15 task! Bebas dari hukuman fisik. Waktunya istirahat dan pulihkan energimu!',
                                      style: TextStyle(
                                        color: Color(0xFFD1FAE5),
                                        fontSize: 12,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentSuccess,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text(
                                  'Siap, Istirahat Dulu! 🛌',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            // Progress Bar Hukuman
                            if (_punishmentState != null &&
                                _punishmentState!.totalAssigned > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _punishmentState!.isAllCompleted
                                        ? accentSuccess
                                        : accentGold.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              _punishmentState!.isAllCompleted
                                                  ? Icons.check_circle_rounded
                                                  : Icons.fitness_center_rounded,
                                              size: 16,
                                              color: _punishmentState!
                                                      .isAllCompleted
                                                  ? accentSuccess
                                                  : accentGold,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'PROGRES HUKUMAN FISIK',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                                color: _punishmentState!
                                                        .isAllCompleted
                                                    ? accentSuccess
                                                    : accentGold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${_punishmentState!.completedCount}/${_punishmentState!.totalAssigned} Selesai',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: _punishmentState!
                                                    .isAllCompleted
                                                ? accentSuccess
                                                : Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: _punishmentState!.progress,
                                        minHeight: 6,
                                        backgroundColor:
                                            Colors.white.withValues(alpha: 0.1),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          _punishmentState!.isAllCompleted
                                              ? accentSuccess
                                              : accentGold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _punishmentState!.isAllCompleted
                                          ? '🎉 Seluruh latihan selesai! Poin penuh hari ini bertahan.'
                                          : '🛡️ Selesaikan semua latihan agar poin tidak berkurang (-1 per task).',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: _punishmentState!.isAllCompleted
                                            ? const Color(0xFF6EE7B7)
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Daftar Latihan Olahraga Checklist
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'DAFTAR HUKUMAN (${_assignedItems.length})',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF94A3B8),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const SeriousPunishmentConfigPage(),
                                      ),
                                    ).then((_) => _loadPunishmentState());
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _punishmentMode == SeriousPunishmentMode.mandiri
                                          ? const Color(0xFF0369A1).withValues(alpha: 0.3)
                                          : (_punishmentMode == SeriousPunishmentMode.campuran
                                              ? const Color(0xFF6B21A8).withValues(alpha: 0.3)
                                              : accentFire.withValues(alpha: 0.15)),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _punishmentMode == SeriousPunishmentMode.mandiri
                                            ? const Color(0xFF38BDF8).withValues(alpha: 0.4)
                                            : (_punishmentMode == SeriousPunishmentMode.campuran
                                                ? const Color(0xFFA855F7).withValues(alpha: 0.4)
                                                : accentFire.withValues(alpha: 0.4)),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${SeriousPunishmentMode.getEmoji(_punishmentMode)} ${SeriousPunishmentMode.getShortLabel(_punishmentMode)}',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: _punishmentMode == SeriousPunishmentMode.mandiri
                                                ? const Color(0xFF7DD3FC)
                                                : (_punishmentMode == SeriousPunishmentMode.campuran
                                                    ? const Color(0xFFD8B4FE)
                                                    : accentFire),
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        const Icon(
                                          Icons.tune_rounded,
                                          size: 10,
                                          color: Colors.white70,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Items List
                            for (final item in _assignedItems) ...[
                              () {
                                final isDone = _punishmentState
                                        ?.completedPunishmentIds
                                        .contains(item.id) ??
                                    false;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: isDone
                                        ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                                        : cardBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isDone
                                          ? accentSuccess
                                          : Colors.white.withValues(alpha: 0.12),
                                      width: isDone ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => _toggleItem(item.id),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Checkbox Circle
                                            Container(
                                              margin: const EdgeInsets.only(top: 2),
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: isDone
                                                    ? accentSuccess
                                                    : const Color(0xFF0F172A),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isDone
                                                      ? accentSuccess
                                                      : const Color(0xFF64748B),
                                                  width: 2,
                                                ),
                                              ),
                                              child: isDone
                                                  ? const Icon(
                                                      Icons.check_rounded,
                                                      size: 15,
                                                      color: Colors.white,
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            // Details
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        item.emoji,
                                                        style: const TextStyle(
                                                            fontSize: 18),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          item.title,
                                                          style: TextStyle(
                                                            fontSize: 13.5,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: isDone
                                                                ? const Color(0xFF6EE7B7)
                                                                : Colors.white,
                                                            decoration: isDone
                                                                ? TextDecoration
                                                                    .lineThrough
                                                                : TextDecoration
                                                                    .none,
                                                          ),
                                                        ),
                                                      ),
                                                      if (item.repsOrDuration
                                                          .isNotEmpty)
                                                        Container(
                                                          padding: const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 6,
                                                              vertical: 2),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: accentGold
                                                                .withValues(
                                                                    alpha: 0.18),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                          ),
                                                          child: Text(
                                                            item.repsOrDuration,
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 9.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: accentGold,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    item.description,
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      color: isDone
                                                          ? const Color(0xFF94A3B8)
                                                          : const Color(0xFFCBD5E1),
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.shield_outlined,
                                                        size: 11,
                                                        color: Color(0xFF64748B),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Target: ${item.targetMuscle}',
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color: Color(0xFF94A3B8),
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
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
                              }(),
                            ],
                          ],
                        ],
                      ),
                    ),
            ),

            // Bottom Buttons
            if (!eval.isExempt)
              Container(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1120),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(22)),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_punishmentState != null &&
                        _punishmentState!.isAllCompleted) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentSuccess,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.verified_rounded, size: 18),
                          label: const Text(
                            'Selesai & Pertahankan Poin! 🛡️',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          onPressed: _handleConfirmAllDone,
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: accentFire,
                                side: BorderSide(
                                  color: accentFire.withValues(alpha: 0.5),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.flag_rounded, size: 16),
                              label: Text(
                                'Menyerah (-${_punishmentState?.remainingCount ?? eval.pendingCount} PTS)',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: _handleSurrender,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentGold,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.save_rounded, size: 16),
                              label: Text(
                                'Simpan Progres (${_punishmentState?.completedCount ?? 0}/${_punishmentState?.totalAssigned ?? eval.pendingCount})',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                widget.onCompleted?.call();
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
