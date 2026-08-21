import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppMenuItem {
  final int index;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double angleDeg; // Angle in degrees from FAB center

  const AppMenuItem({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.angleDeg,
  });
}

class GtaSwitchWheel extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onPageSelected;

  const GtaSwitchWheel({
    super.key,
    required this.currentIndex,
    required this.onPageSelected,
  });

  static const List<AppMenuItem> menuItems = [
    AppMenuItem(
      index: 0,
      title: 'Keuangan',
      subtitle: 'Tagihan, Saldo & Tabungan',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF5E35B1), // Purple
      angleDeg: 165, // Elevated left to avoid bottom cutoff
    ),
    AppMenuItem(
      index: 1,
      title: 'Rundown',
      subtitle: 'Jadwal & Agenda Kegiatan',
      icon: Icons.event_note_rounded,
      color: Color(0xFF00897B), // Teal
      angleDeg: 130, // Top-Left
    ),
    AppMenuItem(
      index: 2,
      title: 'To-Do List',
      subtitle: 'Tugas & Catatan Harian',
      icon: Icons.checklist_rounded,
      color: Color(0xFFBA5A3A), // Calmer Terracotta
      angleDeg: 95, // Top
    ),
  ];

  @override
  State<GtaSwitchWheel> createState() => _GtaSwitchWheelState();
}

class _GtaSwitchWheelState extends State<GtaSwitchWheel>
    with SingleTickerProviderStateMixin {
  final GlobalKey _fabKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  final ValueNotifier<int?> _hoveredNotifier = ValueNotifier<int?>(null);

  Offset _fabCenterGlobal = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInQuad,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _hoveredNotifier.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _calculateFabPosition() {
    final renderBox = _fabKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      _fabCenterGlobal = Offset(
        position.dx + size.width / 2,
        position.dy + size.height / 2,
      );
    }
  }

  int? _calculateHoveredIndex(Offset touchPosition) {
    final dx = touchPosition.dx - _fabCenterGlobal.dx;
    final dy = touchPosition.dy - _fabCenterGlobal.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance < 28) {
      return widget.currentIndex;
    }

    // Convert vector dx, dy to angle in degrees (0 = right, 90 = top, 180 = left, 270 = bottom)
    double angleRad = math.atan2(-dy, dx);
    double angleDeg = angleRad * 180 / math.pi;
    if (angleDeg < 0) {
      angleDeg += 360;
    }

    // Sector angle ranges:
    // Keuangan (165 deg) -> [148 to 245]
    // Rundown (130 deg)  -> [112 to 148]
    // To-Do List (95 deg)-> [30 to 112]
    if (angleDeg >= 148 && angleDeg <= 245) {
      return 0; // Keuangan
    } else if (angleDeg >= 112 && angleDeg < 148) {
      return 1; // Rundown
    } else if (angleDeg >= 30 && angleDeg < 112) {
      return 2; // To-Do List
    }

    if (angleDeg > 245) return 0;
    if (angleDeg < 30) return 2;

    return widget.currentIndex;
  }

  void _showOverlay(Offset initialTouch) {
    if (_overlayEntry != null) return;

    _calculateFabPosition();
    _hoveredNotifier.value = _calculateHoveredIndex(initialTouch);
    _isDragging = true;
    HapticFeedback.selectionClick();

    final overlayState = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) {
        return RepaintBoundary(
          child: _GtaWheelOverlayView(
            animation: _scaleAnimation,
            fadeAnimation: _fadeAnimation,
            fabCenter: _fabCenterGlobal,
            hoveredNotifier: _hoveredNotifier,
            currentIndex: widget.currentIndex,
            onPanUpdate: (touchPos) {
              final newHover = _calculateHoveredIndex(touchPos);
              if (newHover != _hoveredNotifier.value) {
                if (newHover != null) {
                  HapticFeedback.selectionClick();
                }
                _hoveredNotifier.value = newHover;
              }
            },
            onPanEnd: () {
              _selectAndClose(_hoveredNotifier.value ?? widget.currentIndex);
            },
            onTapItem: (index) {
              _selectAndClose(index);
            },
            onDismiss: _dismissOverlay,
          ),
        );
      },
    );

    overlayState.insert(_overlayEntry!);
    _animController.forward(from: 0.0);
  }

  void _selectAndClose(int targetIndex) async {
    if (!_isDragging && _overlayEntry == null) return;
    _isDragging = false;

    await _animController.reverse();
    _removeOverlay();

    if (targetIndex != widget.currentIndex) {
      HapticFeedback.mediumImpact();
      // Save in background
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('default_main_page', targetIndex);
      });
      widget.onPageSelected(targetIndex);
    }
  }

  void _dismissOverlay() async {
    if (!_isDragging && _overlayEntry == null) return;
    _isDragging = false;
    await _animController.reverse();
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = GtaSwitchWheel.menuItems.firstWhere(
      (item) => item.index == widget.currentIndex,
      orElse: () => GtaSwitchWheel.menuItems[0],
    );

    return RepaintBoundary(
      child: GestureDetector(
        key: _fabKey,
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          _showOverlay(details.globalPosition);
        },
        onPanStart: (details) {
          _showOverlay(details.globalPosition);
        },
        onPanUpdate: (details) {
          if (_overlayEntry != null) {
            final newHover = _calculateHoveredIndex(details.globalPosition);
            if (newHover != _hoveredNotifier.value) {
              if (newHover != null) {
                HapticFeedback.selectionClick();
              }
              _hoveredNotifier.value = newHover;
            }
          }
        },
        onPanEnd: (_) {
          _selectAndClose(_hoveredNotifier.value ?? widget.currentIndex);
        },
        onPanCancel: () {
          _dismissOverlay();
        },
        onTapUp: (_) {
          _selectAndClose(_hoveredNotifier.value ?? widget.currentIndex);
        },
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                currentItem.color,
                currentItem.color.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: currentItem.color.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 2.2,
            ),
          ),
          child: Center(
            child: Icon(
              currentItem.icon,
              color: Colors.white,
              size: 27,
            ),
          ),
        ),
      ),
    );
  }
}

class _GtaWheelOverlayView extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> fadeAnimation;
  final Offset fabCenter;
  final ValueNotifier<int?> hoveredNotifier;
  final int currentIndex;
  final ValueChanged<Offset> onPanUpdate;
  final VoidCallback onPanEnd;
  final ValueChanged<int> onTapItem;
  final VoidCallback onDismiss;

  const _GtaWheelOverlayView({
    required this.animation,
    required this.fadeAnimation,
    required this.fabCenter,
    required this.hoveredNotifier,
    required this.currentIndex,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onTapItem,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final center = fabCenter != Offset.zero
        ? fabCenter
        : Offset(screenSize.width - 45, screenSize.height - 45);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Background Translucent Dimming with Pan Tracking (Ultra-high performance, no shader lag)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) => onPanUpdate(details.globalPosition),
              onPanEnd: (_) => onPanEnd(),
              onTap: onDismiss,
              child: AnimatedBuilder(
                animation: fadeAnimation,
                builder: (context, child) {
                  return Container(
                    color: Colors.black.withValues(
                      alpha: 0.72 * fadeAnimation.value,
                    ),
                  );
                },
              ),
            ),
          ),

          // GTA V Top HUD Banner
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            right: 20,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: fadeAnimation.value,
                    child: ValueListenableBuilder<int?>(
                      valueListenable: hoveredNotifier,
                      builder: (context, hoveredIndex, child) {
                        final activeItem = GtaSwitchWheel.menuItems.firstWhere(
                          (item) => item.index == (hoveredIndex ?? currentIndex),
                          orElse: () => GtaSwitchWheel.menuItems[0],
                        );

                        return Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF18181B).withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: activeItem.color.withValues(alpha: 0.8),
                                width: 1.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: activeItem.color.withValues(alpha: 0.4),
                                  blurRadius: 22,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: activeItem.color.withValues(alpha: 0.25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    activeItem.icon,
                                    color: activeItem.color,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          activeItem.title.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        if (activeItem.index == currentIndex) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white24,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'HALAMAN UTAMA',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      activeItem.subtitle,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.75),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom Hint Text
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: fadeAnimation.value,
                    child: const Text(
                      'Geser jari ke arah menu lalu lepaskan untuk berpindah',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Arc Ring & Radial Character Options
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                const double radius = 135.0;

                return Stack(
                  children: [
                    // Arc Paint & Connector Line
                    ValueListenableBuilder<int?>(
                      valueListenable: hoveredNotifier,
                      builder: (context, hoveredIndex, child) {
                        return CustomPaint(
                          size: screenSize,
                          painter: _WheelArcPainter(
                            center: center,
                            radius: radius,
                            animProgress: animation.value,
                            hoveredIndex: hoveredIndex,
                            menuItems: GtaSwitchWheel.menuItems,
                          ),
                        );
                      },
                    ),

                    // Origin Anchor Ring
                    Positioned(
                      left: center.dx - 32 * animation.value,
                      top: center.dy - 32 * animation.value,
                      child: Container(
                        width: 64 * animation.value,
                        height: 64 * animation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 2,
                          ),
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        child: const Icon(
                          Icons.navigation_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),

                    // Radial Menu Items
                    ...GtaSwitchWheel.menuItems.map((item) {
                      final double angleRad = item.angleDeg * math.pi / 180.0;
                      final itemCenterX =
                          center.dx + radius * math.cos(angleRad) * animation.value;
                      final itemCenterY =
                          center.dy - radius * math.sin(angleRad) * animation.value;

                      return ValueListenableBuilder<int?>(
                        valueListenable: hoveredNotifier,
                        builder: (context, hoveredIndex, child) {
                          final bool isHovered = hoveredIndex == item.index;
                          final bool isCurrent = currentIndex == item.index;
                          final double itemSize = isHovered ? 68.0 : 54.0;

                          return Positioned(
                            left: itemCenterX - itemSize / 2,
                            top: itemCenterY - itemSize / 2,
                            child: GestureDetector(
                              onTap: () => onTapItem(item.index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                curve: Curves.easeOutCubic,
                                width: itemSize,
                                height: itemSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: isHovered
                                        ? [
                                            item.color,
                                            item.color.withValues(alpha: 0.8),
                                          ]
                                        : [
                                            const Color(0xFF2C2C34),
                                            const Color(0xFF18181B),
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    if (isHovered)
                                      BoxShadow(
                                        color: item.color.withValues(alpha: 0.75),
                                        blurRadius: 24,
                                        spreadRadius: 4,
                                      ),
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: isHovered
                                        ? Colors.white
                                        : (isCurrent ? item.color : Colors.white30),
                                    width: isHovered
                                        ? 3.0
                                        : (isCurrent ? 2.2 : 1.2),
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    item.icon,
                                    color: isHovered
                                        ? Colors.white
                                        : (isCurrent
                                            ? item.color
                                            : Colors.white70),
                                    size: isHovered ? 32 : 24,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelArcPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final double animProgress;
  final int? hoveredIndex;
  final List<AppMenuItem> menuItems;

  _WheelArcPainter({
    required this.center,
    required this.radius,
    required this.animProgress,
    required this.hoveredIndex,
    required this.menuItems,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (animProgress <= 0.05) return;

    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15 * animProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final rect = Rect.fromCircle(center: center, radius: radius * animProgress);
    const startAngle = 80 * math.pi / 180.0;
    const sweepAngle = 100 * math.pi / 180.0;

    canvas.drawArc(rect, -startAngle - sweepAngle, sweepAngle, false, basePaint);

    if (hoveredIndex != null) {
      final activeItem = menuItems.firstWhere((i) => i.index == hoveredIndex);
      final angleRad = activeItem.angleDeg * math.pi / 180.0;
      final target = Offset(
        center.dx + (radius * animProgress) * math.cos(angleRad),
        center.dy - (radius * animProgress) * math.sin(angleRad),
      );

      glowPaint.color = activeItem.color.withValues(alpha: 0.8 * animProgress);
      canvas.drawLine(center, target, glowPaint);

      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9 * animProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawLine(center, target, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WheelArcPainter oldDelegate) {
    return oldDelegate.animProgress != animProgress ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.center != center;
  }
}
