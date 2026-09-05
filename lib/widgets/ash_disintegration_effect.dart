import 'dart:math';
import 'package:flutter/material.dart';

/// Efek Animasi "Abu yang Tersapu Angin" untuk Tugas yang Menyerah di Mode Serius
class AshDisintegrationWrapper extends StatefulWidget {
  final Widget child;
  final bool isDisintegrating;
  final VoidCallback? onComplete;
  final int seed;
  final Duration duration;

  const AshDisintegrationWrapper({
    super.key,
    required this.child,
    required this.isDisintegrating,
    this.onComplete,
    this.seed = 0,
    this.duration = const Duration(milliseconds: 1350),
  });

  @override
  State<AshDisintegrationWrapper> createState() =>
      _AshDisintegrationWrapperState();
}

class _AshDisintegrationWrapperState extends State<AshDisintegrationWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_AshFlake> _particles;
  bool _hasTriggeredComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _generateParticles();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_hasTriggeredComplete) {
        _hasTriggeredComplete = true;
        widget.onComplete?.call();
      }
    });

    if (widget.isDisintegrating) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant AshDisintegrationWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDisintegrating && !oldWidget.isDisintegrating) {
      _hasTriggeredComplete = false;
      _generateParticles();
      _controller.forward(from: 0.0);
    }
  }

  void _generateParticles() {
    final rand = Random(widget.seed != 0 ? widget.seed : DateTime.now().millisecondsSinceEpoch);
    const particleCount = 45;
    _particles = List.generate(particleCount, (i) {
      final isEmber = rand.nextDouble() < 0.35;
      final Color color;
      if (isEmber) {
        final emberColors = [
          const Color(0xFFF59E0B), // amber
          const Color(0xFFEF4444), // red
          const Color(0xFFF97316), // orange
          const Color(0xFFFBBF24), // gold
        ];
        color = emberColors[rand.nextInt(emberColors.length)];
      } else {
        final ashColors = [
          const Color(0xFF94A3B8), // slate 400
          const Color(0xFF64748B), // slate 500
          const Color(0xFF475569), // slate 600
          const Color(0xFF334155), // slate 700
          const Color(0xFF1E293B), // slate 800
        ];
        color = ashColors[rand.nextInt(ashColors.length)];
      }

      return _AshFlake(
        startX: rand.nextDouble(),
        startY: rand.nextDouble(),
        radius: isEmber ? (1.5 + rand.nextDouble() * 2.5) : (2.0 + rand.nextDouble() * 3.5),
        vx: 80.0 + rand.nextDouble() * 140.0,
        vy: -30.0 - rand.nextDouble() * 70.0,
        swayFreq: 6.0 + rand.nextDouble() * 8.0,
        swayAmp: 10.0 + rand.nextDouble() * 20.0,
        phase: rand.nextDouble() * 2 * pi,
        color: color,
        isEmber: isEmber,
        birthProgress: rand.nextDouble() * 0.35, // delay kemunculan partikel bertahap
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isDisintegrating && _controller.value == 0.0) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        if (t >= 1.0) {
          return const SizedBox.shrink();
        }

        // Shaking & ember burning phase (0..0.25)
        double shakeX = 0.0;
        double shakeY = 0.0;
        if (t < 0.3) {
          final shakeIntensity = (1.0 - t / 0.3) * 2.5;
          shakeX = sin(t * 50) * shakeIntensity;
          shakeY = cos(t * 40) * shakeIntensity * 0.5;
        }

        // Wind shear and blow away translation
        final blowProgress = ((t - 0.1) / 0.9).clamp(0.0, 1.0);
        final curvedBlow = Curves.easeInQuad.transform(blowProgress);
        final translateX = curvedBlow * 90.0 + shakeX;
        final translateY = -curvedBlow * 30.0 + shakeY;
        final skewX = -0.15 * curvedBlow;
        final scale = (1.0 - curvedBlow * 0.35).clamp(0.0, 1.0);
        final opacity = (1.0 - ((t - 0.25) / 0.75).clamp(0.0, 1.0));

        final transformMatrix = Matrix4.identity()
          ..translate(translateX, translateY)
          ..scale(scale)
          ..setEntry(0, 1, skewX);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Konten Task Asli yang Hangus & Menghilang
            Transform(
              transform: transformMatrix,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    // Efek bara api dan abu gelap di pinggir
                    border: t < 0.7
                        ? Border.all(
                            color: Color.lerp(
                              const Color(0xFFEF4444),
                              const Color(0xFF475569),
                              t,
                            )!.withValues(alpha: (1.0 - t * 0.8)),
                            width: 1.5,
                          )
                        : null,
                    color: t < 0.6
                        ? Color.lerp(
                            Colors.transparent,
                            const Color(0xFF0F172A).withValues(alpha: 0.8),
                            t * 1.5,
                          )
                        : null,
                  ),
                  child: widget.child,
                ),
              ),
            ),

            // Lapisan Partikel Abu & Bara yang Terbang Tersapu Angin
            Positioned.fill(
              child: CustomPaint(
                painter: _AshParticlePainter(
                  particles: _particles,
                  progress: t,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AshFlake {
  final double startX; // 0..1
  final double startY; // 0..1
  final double radius;
  final double vx;
  final double vy;
  final double swayFreq;
  final double swayAmp;
  final double phase;
  final Color color;
  final bool isEmber;
  final double birthProgress;

  _AshFlake({
    required this.startX,
    required this.startY,
    required this.radius,
    required this.vx,
    required this.vy,
    required this.swayFreq,
    required this.swayAmp,
    required this.phase,
    required this.color,
    required this.isEmber,
    required this.birthProgress,
  });
}

class _AshParticlePainter extends CustomPainter {
  final List<_AshFlake> particles;
  final double progress;

  _AshParticlePainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.05 || progress >= 1.0) return;

    for (final p in particles) {
      if (progress < p.birthProgress) continue;

      final localT = ((progress - p.birthProgress) / (1.0 - p.birthProgress)).clamp(0.0, 1.0);
      final curvedT = Curves.easeOutQuad.transform(localT);

      // Posisi partikel berdasarkan tiupan angin ke kanan-atas dengan osilasi angin alami
      final originX = p.startX * size.width;
      final originY = p.startY * size.height;

      final currentX = originX + (p.vx * curvedT) + (sin(localT * p.swayFreq + p.phase) * p.swayAmp);
      final currentY = originY + (p.vy * curvedT) + (cos(localT * p.swayFreq + p.phase) * (p.swayAmp * 0.4));

      final alpha = (1.0 - localT * localT).clamp(0.0, 1.0);
      final currentRadius = p.radius * (1.0 - localT * 0.5);

      final paint = Paint()
        ..color = p.color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      // Glow effect untuk bara api (ember)
      if (p.isEmber && alpha > 0.2) {
        final glowPaint = Paint()
          ..color = p.color.withValues(alpha: alpha * 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
        canvas.drawCircle(Offset(currentX, currentY), currentRadius * 2.0, glowPaint);
      }

      // Gambar partikel abu / serpihan
      canvas.drawCircle(Offset(currentX, currentY), currentRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AshParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
