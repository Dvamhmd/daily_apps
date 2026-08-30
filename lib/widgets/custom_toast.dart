import 'dart:async';
import 'package:flutter/material.dart';

enum ToastType {
  success,
  info,
  warning,
  error,
}

class CustomToast {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static OverlayEntry? _currentOverlayEntry;
  static _CustomToastWidgetState? _currentState;

  /// Menampilkan toast pesan dengan animasi masuk dan keluar yang halus,
  /// selalu berada di top layer (root overlay) di atas modal / dialog / menu,
  /// dan otomatis menghilang setelah durasi yang ditentukan (default: 1.5 - 2.5 detik).
  static void show(
    BuildContext? context, {
    required String title,
    String? subtitle,
    ToastType type = ToastType.success,
    Duration duration = const Duration(milliseconds: 1800),
    Duration animationDuration = const Duration(milliseconds: 300),
    IconData? icon,
    VoidCallback? onTap,
  }) {
    // Tutup toast sebelumnya secara langsung jika masih ada
    dismiss(immediate: true);

    OverlayState? overlay;
    if (context != null) {
      try {
        overlay = Overlay.maybeOf(context, rootOverlay: true);
      } catch (_) {}
    }
    overlay ??= navigatorKey.currentState?.overlay;

    if (overlay == null) {
      debugPrint('CustomToast: OverlayState tidak ditemukan.');
      return;
    }

    final overlayEntry = OverlayEntry(
      builder: (ctx) => _CustomToastOverlay(
        title: title,
        subtitle: subtitle,
        type: type,
        displayDuration: duration,
        animationDuration: animationDuration,
        customIcon: icon,
        onTap: onTap,
        onDismissed: () {
          _removeCurrentEntry();
        },
        onStateCreated: (state) {
          _currentState = state;
        },
      ),
    );

    _currentOverlayEntry = overlayEntry;
    overlay.insert(overlayEntry);
  }

  /// Shortcut pesan sukses
  static void showSuccess(
    BuildContext? context, {
    required String title,
    String? subtitle,
    Duration duration = const Duration(milliseconds: 1800),
    IconData icon = Icons.check_circle_rounded,
    VoidCallback? onTap,
  }) {
    show(
      context,
      title: title,
      subtitle: subtitle,
      type: ToastType.success,
      duration: duration,
      icon: icon,
      onTap: onTap,
    );
  }

  /// Shortcut pesan error/gagal
  static void showError(
    BuildContext? context, {
    required String title,
    String? subtitle,
    Duration duration = const Duration(milliseconds: 2500),
    IconData icon = Icons.error_rounded,
    VoidCallback? onTap,
  }) {
    show(
      context,
      title: title,
      subtitle: subtitle,
      type: ToastType.error,
      duration: duration,
      icon: icon,
      onTap: onTap,
    );
  }

  /// Shortcut pesan warning/peringatan
  static void showWarning(
    BuildContext? context, {
    required String title,
    String? subtitle,
    Duration duration = const Duration(milliseconds: 2200),
    IconData icon = Icons.warning_amber_rounded,
    VoidCallback? onTap,
  }) {
    show(
      context,
      title: title,
      subtitle: subtitle,
      type: ToastType.warning,
      duration: duration,
      icon: icon,
      onTap: onTap,
    );
  }

  /// Shortcut pesan info
  static void showInfo(
    BuildContext? context, {
    required String title,
    String? subtitle,
    Duration duration = const Duration(milliseconds: 2000),
    IconData icon = Icons.info_outline_rounded,
    VoidCallback? onTap,
  }) {
    show(
      context,
      title: title,
      subtitle: subtitle,
      type: ToastType.info,
      duration: duration,
      icon: icon,
      onTap: onTap,
    );
  }

  /// Shortcut umum untuk menampilkan toast sederhana berdasarkan pesan teks
  static void showToast(
    BuildContext? context,
    String message, {
    bool isSuccess = true,
    ToastType? type,
    String? subtitle,
    Duration? duration,
    IconData? icon,
  }) {
    final resolvedType = type ?? (isSuccess ? ToastType.success : ToastType.info);
    show(
      context,
      title: message,
      subtitle: subtitle,
      type: resolvedType,
      duration: duration ?? const Duration(milliseconds: 1800),
      icon: icon,
    );
  }

  /// Menutup toast yang sedang aktif
  static void dismiss({bool immediate = false}) {
    if (immediate) {
      _removeCurrentEntry();
    } else {
      _currentState?.dismiss();
    }
  }

  static void _removeCurrentEntry() {
    _currentState = null;
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = null;
  }
}

class _CustomToastOverlay extends StatefulWidget {
  final String title;
  final String? subtitle;
  final ToastType type;
  final Duration displayDuration;
  final Duration animationDuration;
  final IconData? customIcon;
  final VoidCallback? onTap;
  final VoidCallback onDismissed;
  final ValueChanged<_CustomToastWidgetState> onStateCreated;

  const _CustomToastOverlay({
    required this.title,
    this.subtitle,
    required this.type,
    required this.displayDuration,
    required this.animationDuration,
    this.customIcon,
    this.onTap,
    required this.onDismissed,
    required this.onStateCreated,
  });

  @override
  State<_CustomToastOverlay> createState() => _CustomToastWidgetState();
}

class _CustomToastWidgetState extends State<_CustomToastOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _dismissTimer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    widget.onStateCreated(this);

    _animController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    // Mulai animasi masuk yang halus
    _animController.forward().then((_) {
      if (mounted) {
        // Mulai timer penahan display (1.5 detik)
        _dismissTimer = Timer(widget.displayDuration, () {
          dismiss();
        });
      }
    });
  }

  void dismiss() {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    _dismissTimer?.cancel();

    _animController.reverse().then((_) {
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Color _getBorderColor() {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFF10B981).withValues(alpha: 0.4);
      case ToastType.error:
        return const Color(0xFFEF4444).withValues(alpha: 0.4);
      case ToastType.warning:
        return const Color(0xFFF59E0B).withValues(alpha: 0.4);
      case ToastType.info:
        return const Color(0xFF3B82F6).withValues(alpha: 0.4);
    }
  }

  Color _getIconColor() {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFF34D399);
      case ToastType.error:
        return const Color(0xFFF87171);
      case ToastType.warning:
        return const Color(0xFFFBBF24);
      case ToastType.info:
        return const Color(0xFF60A5FA);
    }
  }

  Color _getIconBgColor() {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFF10B981).withValues(alpha: 0.18);
      case ToastType.error:
        return const Color(0xFFEF4444).withValues(alpha: 0.18);
      case ToastType.warning:
        return const Color(0xFFF59E0B).withValues(alpha: 0.18);
      case ToastType.info:
        return const Color(0xFF3B82F6).withValues(alpha: 0.18);
    }
  }

  IconData _getDefaultIcon() {
    if (widget.customIcon != null) return widget.customIcon!;
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle_rounded;
      case ToastType.error:
        return Icons.error_rounded;
      case ToastType.warning:
        return Icons.warning_amber_rounded;
      case ToastType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Positioned(
      top: topPadding + 16,
      left: 16,
      right: 16,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth > 540 ? 460 : double.infinity,
            ),
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: GestureDetector(
                    onTap: () {
                      widget.onTap?.call();
                      dismiss();
                    },
                    onVerticalDragUpdate: (details) {
                      if (details.primaryDelta != null &&
                          details.primaryDelta! < -4) {
                        dismiss();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1E293B),
                            Color(0xFF0F172A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _getBorderColor(),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: _getIconColor().withValues(alpha: 0.15),
                            blurRadius: 14,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon badge
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: _getIconBgColor(),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getDefaultIcon(),
                              color: _getIconColor(),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Text Content
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                if (widget.subtitle != null &&
                                    widget.subtitle!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.subtitle!,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white.withValues(alpha: 0.75),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Close button
                          Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
