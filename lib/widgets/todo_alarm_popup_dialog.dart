import 'dart:async';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/utils/todo_alarm_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TodoAlarmPopupDialog extends StatefulWidget {
  final TodoDateGroup group;
  final VoidCallback? onDismiss;
  final bool isSeriousMode;

  const TodoAlarmPopupDialog({
    super.key,
    required this.group,
    this.onDismiss,
    this.isSeriousMode = false,
  });

  static bool _isShowing = false;

  static Future<void> show(
    BuildContext context, {
    required TodoDateGroup group,
    VoidCallback? onDismiss,
    bool isSeriousMode = false,
  }) async {
    if (_isShowing) return;
    _isShowing = true;

    try {
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        barrierLabel: 'Alarm Reminder',
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (context, anim1, anim2) {
          return TodoAlarmPopupDialog(
            group: group,
            isSeriousMode: isSeriousMode,
            onDismiss: () {
              onDismiss?.call();
            },
          );
        },
        transitionBuilder: (context, anim1, anim2, child) {
          final curved =
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
          return ScaleTransition(
            scale: curved,
            child: FadeTransition(
              opacity: anim1,
              child: child,
            ),
          );
        },
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<TodoAlarmPopupDialog> createState() => _TodoAlarmPopupDialogState();
}

class _TodoAlarmPopupDialogState extends State<TodoAlarmPopupDialog>
    with TickerProviderStateMixin {
  static const Color primaryTerracotta = Color(0xFFBA5A3A);
  static const Color softTerracottaBg = Color(0xFFFDF6F3);

  static const Color seriousBg = Color(0xFF0F172A);
  static const Color seriousCardBg = Color(0xFF1E293B);
  static const Color seriousGold = Color(0xFFF59E0B);
  static const Color seriousBorder = Color(0xFF334155);

  late AnimationController _bellAnimController;
  late Animation<double> _bellRotationAnim;
  late AnimationController _pulseAnimController;
  late Animation<double> _pulseScaleAnim;

  int _remainingSeconds = 300; // 5 menit
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();

    // Animasi lonceng berdering bolak-balik
    _bellAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _bellRotationAnim = Tween<double>(begin: -0.16, end: 0.16).animate(
      CurvedAnimation(
        parent: _bellAnimController,
        curve: Curves.easeInOut,
      ),
    );

    // Animasi pulse ring di belakang lonceng
    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseScaleAnim = Tween<double>(begin: 0.95, end: 1.06).animate(
      CurvedAnimation(
        parent: _pulseAnimController,
        curve: Curves.easeInOut,
      ),
    );

    // Hitung mundur 5 menit
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _countdownTimer?.cancel();
        _handleAcknowledge();
      }
    });

    // Getar awal
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _bellAnimController.dispose();
    _pulseAnimController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _handleAcknowledge() {
    HapticFeedback.mediumImpact();
    TodoAlarmService.stopAlarmSound();
    widget.onDismiss?.call();
    Navigator.of(context, rootNavigator: true).pop();
  }

  String get _formattedCountdown {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isSeriousMode;
    final pendingTasks = widget.group.pendingItems;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleAcknowledge();
      },
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: isDark ? seriousCardBg : Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: isDark
                ? Border.all(
                    color: seriousGold.withValues(alpha: 0.35),
                    width: 1.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: (isDark ? seriousGold : primaryTerracotta)
                    .withValues(alpha: isDark ? 0.22 : 0.28),
                blurRadius: 36,
                spreadRadius: 2,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? const [
                              Color(0xFF1E293B),
                              Color(0xFF0F172A),
                            ]
                          : const [
                              Color(0xFFC86745),
                              Color(0xFFBA5A3A),
                              Color(0xFF8C3E26),
                            ],
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Column(
                    children: [
                      // Animated Pulsing Glowing Bell
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _bellAnimController,
                          _pulseAnimController,
                        ]),
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer Glowing Aura Ring
                              Transform.scale(
                                scale: _pulseScaleAnim.value,
                                child: Container(
                                  width: 82,
                                  height: 82,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (isDark ? seriousGold : Colors.white)
                                        .withValues(alpha: isDark ? 0.2 : 0.14),
                                  ),
                                ),
                              ),
                              // Inner Ring with Bell
                              Transform.rotate(
                                angle: _bellRotationAnim.value,
                                child: Container(
                                  width: 66,
                                  height: 66,
                                  decoration: BoxDecoration(
                                    color: (isDark
                                            ? seriousGold
                                            : Colors.white)
                                        .withValues(alpha: isDark ? 0.25 : 0.22),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? seriousGold
                                          : Colors.white.withValues(alpha: 0.55),
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                            alpha: isDark ? 0.35 : 0.12),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.notifications_active_rounded,
                                    color: isDark ? seriousGold : Colors.white,
                                    size: 34,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),

                      // Pesan Utama: "Tugasmu belum selesai nih"
                      Text(
                        isDark
                            ? 'Tugas Belum Selesai 🔥'
                            : 'Tugasmu belum selesai nih',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Tanggal Badge Capsule
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? seriousGold.withValues(alpha: 0.18)
                              : Colors.black.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? seriousGold.withValues(alpha: 0.45)
                                : Colors.white.withValues(alpha: 0.24),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              color: isDark ? seriousGold : Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.group.formattedFullDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? seriousGold : Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Body: List of Unfinished Tasks
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.32,
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? seriousGold
                                      : primaryTerracotta,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'DAFTAR TUGAS (${pendingTasks.length})',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF450A0A)
                                  : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFFEF4444)
                                        .withValues(alpha: 0.5)
                                    : const Color(0xFFFECACA),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.volume_up_rounded,
                                  size: 13,
                                  color: Color(0xFFEF4444),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formattedCountdown,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (pendingTasks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'Semua tugas telah diselesaikan! 🎉',
                              style: TextStyle(
                                color: Color(0xFF16A34A),
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: pendingTasks.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final item = pendingTasks[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? seriousBg
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark
                                        ? seriousBorder
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? seriousGold
                                                .withValues(alpha: 0.15)
                                            : softTerracottaBg,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.check_box_outline_blank_rounded,
                                        size: 13,
                                        color: isDark
                                            ? seriousGold
                                            : primaryTerracotta,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1E293B),
                                          height: 1.3,
                                        ),
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

                Divider(
                  height: 1,
                  color: isDark ? seriousBorder : const Color(0xFFF1F5F9),
                ),

                // Action Button: "Iyaa tau"
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _handleAcknowledge,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDark ? seriousGold : primaryTerracotta,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        elevation: 3,
                        shadowColor: (isDark ? seriousGold : primaryTerracotta)
                            .withValues(alpha: 0.45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 22,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Iyaa tau',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
