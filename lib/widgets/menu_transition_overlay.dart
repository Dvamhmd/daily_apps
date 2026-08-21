import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ----------------------------------------------------------------------------
/// MENU TRANSITION OVERLAY CONTROLLER & WRAPPER
/// ----------------------------------------------------------------------------

class MenuTransitionWrapper extends StatefulWidget {
  final int currentPageIndex;
  final Widget child;
  final VoidCallback? onTransitionComplete;

  const MenuTransitionWrapper({
    super.key,
    required this.currentPageIndex,
    required this.child,
    this.onTransitionComplete,
  });

  @override
  State<MenuTransitionWrapper> createState() => MenuTransitionWrapperState();
}

class MenuTransitionWrapperState extends State<MenuTransitionWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  int _targetIndex = 0;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _targetIndex = widget.currentPageIndex;

    // 550ms total: 0.0-0.45 in, 0.45-0.7 hold, 0.7-1.0 out (snappy & premium)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 35,
      ),
    ]).animate(_controller);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.75, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 55,
      ),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _isTransitioning = false;
          });
          widget.onTransitionComplete?.call();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Trigger a seamless animated transition to a target menu index
  void triggerTransition(int newIndex, VoidCallback onMidpoint) {
    if (_isTransitioning) return;

    setState(() {
      _targetIndex = newIndex;
      _isTransitioning = true;
    });

    _controller.forward(from: 0.0);

    // Swap underlying page halfway through when overlay is fully opaque
    Future.delayed(const Duration(milliseconds: 240), () {
      if (mounted) {
        onMidpoint();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // The actual page content
        widget.child,

        // High-Performance Animated Transition Overlay
        if (_isTransitioning)
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                if (_fadeAnimation.value <= 0.001) return const SizedBox.shrink();

                return Material(
                  color: Colors.transparent,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Smooth frosted dark backdrop
                      Container(
                        color: Colors.black.withValues(
                          alpha: 0.65 * _fadeAnimation.value,
                        ),
                      ),

                      // Centered Motion Graphic Box
                      Center(
                        child: Opacity(
                          opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: _scaleAnimation.value,
                            child: _buildGraphicContent(_targetIndex, _controller.value),
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
    );
  }

  Widget _buildGraphicContent(int targetIndex, double progress) {
    switch (targetIndex) {
      case 0:
        return const _KeuanganTransitionCard();
      case 1:
        return const _RundownTransitionCard();
      case 2:
        return const _TodoTransitionCard();
      default:
        return const _KeuanganTransitionCard();
    }
  }
}

/// ----------------------------------------------------------------------------
/// 1. KEUANGAN TRANSITION CARD & ANIMASI UANG BERGERAK
/// ----------------------------------------------------------------------------

class _KeuanganTransitionCard extends StatelessWidget {
  const _KeuanganTransitionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF8E24AA).withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B1FA2).withValues(alpha: 0.5),
            blurRadius: 36,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 110,
            height: 110,
            child: MoneyMotionGraphic(),
          ),
          const SizedBox(height: 16),
          const Text(
            'KEUANGAN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Menghitung saldo & tagihan...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standalone Reusable Money Motion Graphic (Uang Bergerak)
class MoneyMotionGraphic extends StatefulWidget {
  final double size;
  const MoneyMotionGraphic({super.key, this.size = 110});

  @override
  State<MoneyMotionGraphic> createState() => _MoneyMotionGraphicState();
}

class _MoneyMotionGraphicState extends State<MoneyMotionGraphic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          final t = _anim.value;

          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Floating Sparkles
                CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _SparklePainter(progress: t, color: const Color(0xFFFFD700)),
                ),

                // Banknote in background sliding subtly
                Transform.translate(
                  offset: Offset(
                    math.sin(t * 2 * math.pi) * 6,
                    -14 + math.cos(t * 2 * math.pi) * 3,
                  ),
                  child: Transform.rotate(
                    angle: -0.15 + math.sin(t * 2 * math.pi) * 0.08,
                    child: Container(
                      width: widget.size * 0.72,
                      height: widget.size * 0.38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E7D32), Color(0xFF66BB6A), Color(0xFF1B5E20)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFA5D6A7),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2E7D32).withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white70, width: 1.2),
                          ),
                          child: const Center(
                            child: Text(
                              'Rp',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Secondary Coin Left
                Transform.translate(
                  offset: Offset(-widget.size * 0.25, widget.size * 0.12),
                  child: Transform.scale(
                    scale: 0.65,
                    child: _buildCoin(t + 0.3),
                  ),
                ),

                // Secondary Coin Right
                Transform.translate(
                  offset: Offset(widget.size * 0.25, widget.size * 0.16),
                  child: Transform.scale(
                    scale: 0.6,
                    child: _buildCoin(t + 0.6),
                  ),
                ),

                // Main 3D Rotating Golden Coin
                Transform.translate(
                  offset: Offset(0, math.sin(t * 2 * math.pi) * 4),
                  child: _buildCoin(t),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoin(double progress) {
    // 3D Coin Flip Rotation
    final rotationAngle = progress * 2 * math.pi;
    final scaleX = math.cos(rotationAngle).abs();
    final isFront = math.cos(rotationAngle) >= 0;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(scaleX.clamp(0.08, 1.0), 1.0, 1.0)
        ..setEntry(3, 2, 0.002),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isFront
                ? const [Color(0xFFFFEA79), Color(0xFFFFB300), Color(0xFFFF8F00)]
                : const [Color(0xFFFFB300), Color(0xFFFF8F00), Color(0xFFE65100)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFFFFF9C4),
            width: 2.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF8F00).withValues(alpha: 0.65),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Inner Engraved Ring
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFD54F).withValues(alpha: 0.8),
                  width: 1.5,
                ),
              ),
            ),
            // Currency Coin Emblem
            Icon(
              Icons.monetization_on_rounded,
              color: const Color(0xFFFFFDE7).withValues(alpha: 0.95),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// 2. TO-DO LIST TRANSITION CARD & ANIMASI CENTANG TERCENNTANG
/// ----------------------------------------------------------------------------

class _TodoTransitionCard extends StatelessWidget {
  const _TodoTransitionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF261915).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFBA5A3A).withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFBA5A3A).withValues(alpha: 0.5),
            blurRadius: 36,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 110,
            height: 110,
            child: CheckmarkMotionGraphic(),
          ),
          const SizedBox(height: 16),
          const Text(
            'TO-DO LIST',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Menyiapkan daftar tugas...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standalone Reusable Checkmark Motion Graphic (Centang yang Tercentang)
class CheckmarkMotionGraphic extends StatefulWidget {
  final double size;
  const CheckmarkMotionGraphic({super.key, this.size = 110});

  @override
  State<CheckmarkMotionGraphic> createState() => _CheckmarkMotionGraphicState();
}

class _CheckmarkMotionGraphicState extends State<CheckmarkMotionGraphic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          final t = _anim.value;

          // Checkmark draw progression (0.1 to 0.7 of loop)
          final checkProgress = ((t - 0.1) / 0.55).clamp(0.0, 1.0);
          final curvedCheck = Curves.easeOutCubic.transform(checkProgress);

          // Burst effect after check is completed (>0.55)
          final burstProgress = ((t - 0.55) / 0.4).clamp(0.0, 1.0);

          // Scale pop bounce on completion
          double scalePop = 1.0;
          if (t >= 0.5 && t <= 0.8) {
            scalePop = 1.0 + 0.12 * math.sin((t - 0.5) / 0.3 * math.pi);
          }

          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Celebration Burst Particles
                if (burstProgress > 0.0 && burstProgress < 1.0)
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _CheckBurstPainter(
                      progress: burstProgress,
                      color: const Color(0xFFFF7043),
                    ),
                  ),

                // Main Checklist Box & Stroke
                Transform.scale(
                  scale: scalePop,
                  child: Container(
                    width: widget.size * 0.65,
                    height: widget.size * 0.65,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFBA5A3A), Color(0xFFE64A19)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFFCCBC),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFBA5A3A).withValues(alpha: 0.6),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: _AnimatedCheckmarkPainter(progress: curvedCheck),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedCheckmarkPainter extends CustomPainter {
  final double progress;

  _AnimatedCheckmarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // Coordinates normalized to box size
    final p1 = Offset(size.width * 0.26, size.height * 0.52);
    final p2 = Offset(size.width * 0.44, size.height * 0.72);
    final p3 = Offset(size.width * 0.76, size.height * 0.32);

    final path = Path();
    path.moveTo(p1.dx, p1.dy);

    if (progress <= 0.4) {
      final segT = progress / 0.4;
      final cur = Offset.lerp(p1, p2, segT)!;
      path.lineTo(cur.dx, cur.dy);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final segT = (progress - 0.4) / 0.6;
      final cur = Offset.lerp(p2, p3, segT)!;
      path.lineTo(cur.dx, cur.dy);
    }

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AnimatedCheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// ----------------------------------------------------------------------------
/// 3. RUNDOWN TRANSITION CARD & ANIMASI JADWAL BERGERAK
/// ----------------------------------------------------------------------------

class _RundownTransitionCard extends StatelessWidget {
  const _RundownTransitionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF132420).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF00897B).withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00897B).withValues(alpha: 0.5),
            blurRadius: 36,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 110,
            height: 110,
            child: ScheduleMotionGraphic(),
          ),
          const SizedBox(height: 16),
          const Text(
            'RUNDOWN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Menyusun agenda & timeline...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standalone Reusable Schedule Motion Graphic (Jadwal Bergerak)
class ScheduleMotionGraphic extends StatefulWidget {
  final double size;
  const ScheduleMotionGraphic({super.key, this.size = 110});

  @override
  State<ScheduleMotionGraphic> createState() => _ScheduleMotionGraphicState();
}

class _ScheduleMotionGraphicState extends State<ScheduleMotionGraphic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          final t = _anim.value;

          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Floating Sparkles
                CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _SparklePainter(
                    progress: t,
                    color: const Color(0xFF4DB6AC),
                  ),
                ),

                // Calendar Card Base
                Container(
                  width: widget.size * 0.68,
                  height: widget.size * 0.72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00897B).withValues(alpha: 0.5),
                        blurRadius: 22,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Top Header Bar
                      Container(
                        height: 22,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF00897B), Color(0xFF004D40)],
                          ),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            4,
                            (index) => Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Calendar Schedule Lines Animated
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildTimelineLine(0, t),
                              _buildTimelineLine(1, t),
                              _buildTimelineLine(2, t),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Floating Spinning Clock Badge in Corner
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
                      ),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: _ClockHandPainter(rotationProgress: t),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimelineLine(int index, double progress) {
    // Sequential pulse of timeline items
    final itemPhase = (progress * 3 - index) % 3;
    final bool isActive = itemPhase >= 0 && itemPhase < 1.0;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? const Color(0xFF00897B) : const Color(0xFFB2DFDB),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: isActive ? const Color(0xFF00897B) : const Color(0xFFE0F2F1),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClockHandPainter extends CustomPainter {
  final double rotationProgress;

  _ClockHandPainter({required this.rotationProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Center pin
    canvas.drawCircle(center, 2.5, Paint()..color = Colors.white);

    // Hour Hand (1 cycle)
    final hourAngle = rotationProgress * 2 * math.pi - math.pi / 2;
    final hourHand = Offset(
      center.dx + 8 * math.cos(hourAngle),
      center.dy + 8 * math.sin(hourAngle),
    );
    canvas.drawLine(center, hourHand, paint);

    // Minute Hand (4x faster)
    final minuteAngle = rotationProgress * 8 * math.pi - math.pi / 2;
    final minuteHand = Offset(
      center.dx + 12 * math.cos(minuteAngle),
      center.dy + 12 * math.sin(minuteAngle),
    );
    canvas.drawLine(center, minuteHand, paint);
  }

  @override
  bool shouldRepaint(covariant _ClockHandPainter oldDelegate) {
    return oldDelegate.rotationProgress != rotationProgress;
  }
}

/// ----------------------------------------------------------------------------
/// COMMON PARTICLE PAINTERS (ZERO MEMORY ALLOCATION & GPU ACCELERATED)
/// ----------------------------------------------------------------------------

class _SparklePainter extends CustomPainter {
  final double progress;
  final Color color;

  _SparklePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    final particles = [
      Offset(size.width * 0.15, size.height * 0.2),
      Offset(size.width * 0.85, size.height * 0.25),
      Offset(size.width * 0.18, size.height * 0.78),
      Offset(size.width * 0.82, size.height * 0.82),
    ];

    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      final phase = (progress + i * 0.25) % 1.0;
      final scale = math.sin(phase * math.pi).clamp(0.0, 1.0);
      final radius = 3.5 * scale;

      if (radius > 0.5) {
        paint.color = color.withValues(alpha: scale);
        // Draw 4-point sparkle star
        final path = Path();
        path.moveTo(p.dx, p.dy - radius * 1.8);
        path.lineTo(p.dx + radius * 0.5, p.dy - radius * 0.5);
        path.lineTo(p.dx + radius * 1.8, p.dy);
        path.lineTo(p.dx + radius * 0.5, p.dy + radius * 0.5);
        path.lineTo(p.dx, p.dy + radius * 1.8);
        path.lineTo(p.dx - radius * 0.5, p.dy + radius * 0.5);
        path.lineTo(p.dx - radius * 1.8, p.dy);
        path.lineTo(p.dx - radius * 0.5, p.dy - radius * 0.5);
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _CheckBurstPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckBurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    const int count = 8;
    final maxDist = size.width * 0.46;

    for (int i = 0; i < count; i++) {
      final angle = (i * (2 * math.pi / count)) + 0.2;
      final curDist = maxDist * progress;
      final particlePos = Offset(
        center.dx + curDist * math.cos(angle),
        center.dy + curDist * math.sin(angle),
      );

      final alpha = (1.0 - progress).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: alpha);
      final radius = 3.5 * (1.0 - progress * 0.5);

      canvas.drawCircle(particlePos, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckBurstPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
