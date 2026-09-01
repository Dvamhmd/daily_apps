import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/model_serious_mode.dart';
import 'serious_mode_auth_dialog.dart';

enum TodoTransitionType {
  toSerious,
  toNormal,
  switchAccount,
  syncData,
  loading,
}

class TodoModeTransitionWidget extends StatefulWidget {
  final TodoTransitionType transitionType;
  final SeriousUser? user;
  final String? customTitle;
  final String? customSubtitle;
  final bool isDarkMode;

  const TodoModeTransitionWidget({
    super.key,
    this.transitionType = TodoTransitionType.loading,
    this.user,
    this.customTitle,
    this.customSubtitle,
    this.isDarkMode = false,
  });

  @override
  State<TodoModeTransitionWidget> createState() =>
      _TodoModeTransitionWidgetState();
}

class _TodoModeTransitionWidgetState extends State<TodoModeTransitionWidget>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _rotationController;
  late final AnimationController _dotController;

  late final Animation<double> _pulseAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse & Breathing Animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutBack,
      ),
    );

    // Continuous Rotation for Orbit/Rings
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Staggered Bouncing Dots
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.transitionType;
    final isDark = widget.isDarkMode ||
        type == TodoTransitionType.toSerious ||
        (type == TodoTransitionType.switchAccount && widget.user != null);

    // Config colors & text based on type
    final Color bgColor;
    final Color primaryAccent;
    final Color secondaryAccent;
    final String defaultTitle;
    final String defaultSubtitle;
    final String mainEmoji;
    final IconData fallbackIcon;

    switch (type) {
      case TodoTransitionType.toSerious:
        bgColor = const Color(0xFF0B1120);
        primaryAccent = const Color(0xFFF59E0B);
        secondaryAccent = const Color(0xFFEF4444);
        defaultTitle = 'Mengaktifkan Mode Serius 🔥';
        defaultSubtitle = 'Menyiapkan tantangan, sistem poin & anti-hapus...';
        mainEmoji = '🔥';
        fallbackIcon = Icons.local_fire_department_rounded;
        break;

      case TodoTransitionType.toNormal:
        bgColor = const Color(0xFFFBF8F6);
        primaryAccent = const Color(0xFFD97706);
        secondaryAccent = const Color(0xFF9C413A);
        defaultTitle = 'Beralih ke Mode Normal 📋';
        defaultSubtitle = 'Menyiapkan to-do list & rencana harian reguler...';
        mainEmoji = '📋';
        fallbackIcon = Icons.checklist_rounded;
        break;

      case TodoTransitionType.switchAccount:
        bgColor = const Color(0xFF0F172A);
        primaryAccent = const Color(0xFFA855F7);
        secondaryAccent = const Color(0xFFF59E0B);
        final name = widget.user?.displayName ?? widget.user?.username ?? 'Pemain';
        defaultTitle = 'Beralih Akun: $name 👑';
        defaultSubtitle = 'Menyinkronkan data tugas, progres & statistik akun...';
        mainEmoji = '👑';
        fallbackIcon = Icons.manage_accounts_rounded;
        break;

      case TodoTransitionType.syncData:
        bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
        primaryAccent = const Color(0xFF3B82F6);
        secondaryAccent = const Color(0xFF10B981);
        defaultTitle = 'Menyinkronkan Data ⚡';
        defaultSubtitle = 'Memperbarui daftar tugas dan jadwal alarm...';
        mainEmoji = '⚡';
        fallbackIcon = Icons.sync_rounded;
        break;

      case TodoTransitionType.loading:
        bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFFBF8F6);
        primaryAccent = isDark ? const Color(0xFFF59E0B) : const Color(0xFF9C413A);
        secondaryAccent = isDark ? const Color(0xFFEF4444) : const Color(0xFFD97706);
        defaultTitle = isDark ? 'Memuat Mode Serius...' : 'Memuat To-Do List...';
        defaultSubtitle = 'Mohon tunggu sebentar...';
        mainEmoji = isDark ? '🔥' : '📝';
        fallbackIcon = Icons.hourglass_top_rounded;
        break;
    }

    final title = widget.customTitle ?? defaultTitle;
    final subtitle = widget.customSubtitle ?? defaultSubtitle;

    return Container(
      color: bgColor,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Center Glowing Animated Graphic / Avatar
            _buildAnimatedBadge(
              primaryAccent: primaryAccent,
              secondaryAccent: secondaryAccent,
              mainEmoji: mainEmoji,
              fallbackIcon: fallbackIcon,
              isDark: isDark,
            ),

            const SizedBox(height: 32),

            // Animated Title
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.85 + (0.15 * _pulseAnimation.value),
                  child: child,
                );
              },
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Subtitle Description
            Container(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Bouncing Dots Wave Indicator
            _buildBouncingDots(primaryAccent, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBadge({
    required Color primaryAccent,
    required Color secondaryAccent,
    required String mainEmoji,
    required IconData fallbackIcon,
    required bool isDark,
  }) {
    final user = widget.user;
    final isAccountType = widget.transitionType == TodoTransitionType.switchAccount && user != null;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _rotationController]),
      builder: (context, _) {
        final scale = _scaleAnimation.value;
        final pulseVal = _pulseAnimation.value;

        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Pulsing Aura Ring 1
                Container(
                  width: 130 + (16 * pulseVal),
                  height: 130 + (16 * pulseVal),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primaryAccent.withValues(alpha: 0.25 * (1.0 - pulseVal * 0.4)),
                        secondaryAccent.withValues(alpha: 0.08 * (1.0 - pulseVal * 0.4)),
                        Colors.transparent,
                      ],
                      stops: const [0.2, 0.65, 1.0],
                    ),
                  ),
                ),

                // Rotating Gradient Ring with Dashes/Glow
                Transform.rotate(
                  angle: _rotationController.value * 2 * math.pi,
                  child: CustomPaint(
                    size: const Size(116, 116),
                    painter: _OrbitRingPainter(
                      primaryColor: primaryAccent,
                      secondaryColor: secondaryAccent,
                      progress: _rotationController.value,
                    ),
                  ),
                ),

                // Inner Breathing Glass Card
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              const Color(0xFF1E293B),
                              const Color(0xFF0F172A),
                            ]
                          : [
                              Colors.white,
                              const Color(0xFFF1F5F9),
                            ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryAccent.withValues(alpha: 0.35 + (0.15 * pulseVal)),
                        blurRadius: 18 + (6 * pulseVal),
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(
                      color: primaryAccent.withValues(alpha: 0.6 + (0.3 * pulseVal)),
                      width: 2.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isAccountType
                      ? _buildUserAvatarContent(user, size: 76)
                      : Text(
                          mainEmoji,
                          style: const TextStyle(fontSize: 40),
                        ),
                ),

                // Top Orbiting Mini Sparkle Badge
                Transform.rotate(
                  angle: -(_rotationController.value * 2 * math.pi),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: secondaryAccent,
                        boxShadow: [
                          BoxShadow(
                            color: secondaryAccent.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserAvatarContent(SeriousUser user, {double size = 76}) {
    if (user.avatarBase64 != null && user.avatarBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(user.avatarBase64!);
        return ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Text('👑', style: TextStyle(fontSize: size * 0.5)),
          ),
        );
      } catch (_) {}
    }

    final idx = user.avatarIndex
        .clamp(0, SeriousModeAuthDialog.presetAvatars.length - 1);
    final avatarData = SeriousModeAuthDialog.presetAvatars[idx];
    return Text(
      avatarData['emoji'] as String,
      style: TextStyle(fontSize: size * 0.5),
    );
  }

  Widget _buildBouncingDots(Color accentColor, bool isDark) {
    return AnimatedBuilder(
      animation: _dotController,
      builder: (context, _) {
        final t = _dotController.value * 2 * math.pi;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            // Sinusoidal bounce with phase delay for each dot
            final phase = index * 0.6;
            final offset = math.sin(t + phase).clamp(0.0, 1.0);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              transform: Matrix4.translationValues(0, -6.0 * offset, 0),
              width: 8.5,
              height: 8.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.4 + (0.6 * offset)),
                boxShadow: offset > 0.4
                    ? [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.5 * offset),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        );
      },
    );
  }
}

class _OrbitRingPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final double progress;

  _OrbitRingPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final sweepGradient = SweepGradient(
      colors: [
        primaryColor.withValues(alpha: 0.0),
        primaryColor.withValues(alpha: 0.8),
        secondaryColor.withValues(alpha: 0.9),
        secondaryColor.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.45, 0.75, 1.0],
      transform: GradientRotation(progress * 2 * math.pi),
    );

    final paint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * math.pi, false, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
