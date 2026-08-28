import 'dart:async';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/utils/todo_alarm_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TodoAlarmPopupDialog extends StatefulWidget {
  final TodoDateGroup group;
  final VoidCallback? onDismiss;

  const TodoAlarmPopupDialog({
    super.key,
    required this.group,
    this.onDismiss,
  });

  static bool _isShowing = false;

  static Future<void> show(
    BuildContext context, {
    required TodoDateGroup group,
    VoidCallback? onDismiss,
  }) async {
    if (_isShowing) return;
    _isShowing = true;

    try {
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.75),
        barrierLabel: 'Alarm Reminder',
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, anim1, anim2) {
          return TodoAlarmPopupDialog(
            group: group,
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
    with SingleTickerProviderStateMixin {
  static const Color primaryTerracotta = Color(0xFFBA5A3A);

  late AnimationController _bellAnimController;
  late Animation<double> _bellRotationAnim;

  int _remainingSeconds = 300; // 5 menit
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();

    // Animasi lonceng bergetar
    _bellAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _bellRotationAnim = Tween<double>(begin: -0.15, end: 0.15).animate(
      CurvedAnimation(
        parent: _bellAnimController,
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
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: primaryTerracotta.withValues(alpha: 0.35),
                blurRadius: 30,
                spreadRadius: 4,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Banner with Ringing Animation
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFBA5A3A),
                        Color(0xFF8C3E26),
                      ],
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      // Animated Bell Icon
                      AnimatedBuilder(
                        animation: _bellRotationAnim,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _bellRotationAnim.value,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.notifications_active_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // Pesan Utama
                      const Text(
                        'Tugasmu ada yang belum selesai Nih',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Tanggal Section
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '📅 ${widget.group.formattedFullDate}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Body: List of Unfinished Tasks
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.35,
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'DAFTAR TUGAS BELUM SELESAI (${pendingTasks.length})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.6,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.volume_up_rounded,
                                  size: 13,
                                  color: Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formattedCountdown,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (pendingTasks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'Semua tugas telah diselesaikan! 🎉',
                              style: TextStyle(
                                color: Color(0xFF16A34A),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: pendingTasks.length,
                            separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final item = pendingTasks[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: primaryTerracotta,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E293B),
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

                const Divider(height: 1, color: Color(0xFFF1F5F9)),

                // Action Button: "Iyaa tau"
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _handleAcknowledge,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryTerracotta,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded, size: 22, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Iyaa tau',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
