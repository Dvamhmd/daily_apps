import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class AvatarCropPreviewDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String displayName;

  const AvatarCropPreviewDialog({
    super.key,
    required this.imageBytes,
    this.displayName = 'Pemain',
  });

  static Future<String?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    String displayName = 'Pemain',
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AvatarCropPreviewDialog(
        imageBytes: imageBytes,
        displayName: displayName,
      ),
    );
  }

  @override
  State<AvatarCropPreviewDialog> createState() =>
      _AvatarCropPreviewDialogState();
}

class _AvatarCropPreviewDialogState extends State<AvatarCropPreviewDialog> {
  static const Color darkBg = Color(0xFF0F172A);
  static const Color cardBg = Color(0xFF1E293B);
  static const Color accentGold = Color(0xFFF59E0B);
  static const Color accentFire = Color(0xFFEF4444);

  final GlobalKey _cropBoundaryKey = GlobalKey();
  final TransformationController _transformController =
      TransformationController();

  double _zoomScale = 1.0;
  int _rotationTurns = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onTransformationChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformationChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _zoomScale).abs() > 0.05) {
      setState(() {
        _zoomScale = scale.clamp(0.5, 4.0);
      });
    }
  }

  void _setZoom(double value) {
    setState(() {
      _zoomScale = value;
      final matrix = Matrix4.diagonal3Values(_zoomScale, _zoomScale, 1.0);
      _transformController.value = matrix;
    });
  }

  void _resetTransform() {
    HapticFeedback.lightImpact();
    setState(() {
      _zoomScale = 1.0;
      _rotationTurns = 0;
      _transformController.value = Matrix4.identity();
    });
  }

  void _rotateClockwise() {
    HapticFeedback.selectionClick();
    setState(() {
      _rotationTurns = (_rotationTurns + 1) % 4;
    });
  }

  Future<Uint8List> _resizeAndCompressAvatar(
    Uint8List imageBytes, {
    int maxDimension = 160,
  }) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: maxDimension,
        targetHeight: maxDimension,
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image resizedImage = frameInfo.image;
      final ByteData? byteData =
          await resizedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('Error compressing avatar: $e');
    }
    return imageBytes;
  }

  Future<void> _handleSaveCroppedAvatar() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    HapticFeedback.mediumImpact();

    try {
      // Tunggu 1 frame agar render selesai
      await Future.delayed(const Duration(milliseconds: 50));

      final boundary = _cropBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('Gagal membaca area crop');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Gagal mengekspor foto');
      }

      final rawCroppedBytes = byteData.buffer.asUint8List();
      final compressedBytes =
          await _resizeAndCompressAvatar(rawCroppedBytes, maxDimension: 160);
      final base64String = base64Encode(compressedBytes);

      if (mounted) {
        Navigator.of(context).pop(base64String);
      }
    } catch (e) {
      debugPrint('Crop error: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyesuaikan foto: $e'),
            backgroundColor: accentFire,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: darkBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: accentGold.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF831843), Color(0xFF1E1B4B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.crop_rounded,
                        color: accentGold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sesuaikan Foto Avatar',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Geser & cubit untuk memposisikan foto',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                      onPressed: () => Navigator.of(context).pop(null),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    // Viewport Crop Area Lingkaran
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow effect behind viewport
                          Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: accentGold.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),

                          // RepaintBoundary Circular Capture Viewport
                          RepaintBoundary(
                            key: _cropBoundaryKey,
                            child: Container(
                              width: 230,
                              height: 230,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF0B0F19),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InteractiveViewer(
                                transformationController: _transformController,
                                minScale: 0.5,
                                maxScale: 5.0,
                                boundaryMargin: const EdgeInsets.all(220),
                                child: Center(
                                  child: RotatedBox(
                                    quarterTurns: _rotationTurns,
                                    child: Image.memory(
                                      widget.imageBytes,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Overlay Ring Border & Guide Grid (Ignore pointer agar geser tembus)
                          IgnorePointer(
                            child: Container(
                              width: 230,
                              height: 230,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: accentGold,
                                  width: 2.5,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  // Grid guide horizontal lines
                                  Positioned(
                                    top: 230 / 3,
                                    left: 20,
                                    right: 20,
                                    child: Container(
                                      height: 1,
                                      color: Colors.white.withValues(alpha: 0.18),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 230 / 3,
                                    left: 20,
                                    right: 20,
                                    child: Container(
                                      height: 1,
                                      color: Colors.white.withValues(alpha: 0.18),
                                    ),
                                  ),
                                  // Grid guide vertical lines
                                  Positioned(
                                    left: 230 / 3,
                                    top: 20,
                                    bottom: 20,
                                    child: Container(
                                      width: 1,
                                      color: Colors.white.withValues(alpha: 0.18),
                                    ),
                                  ),
                                  Positioned(
                                    right: 230 / 3,
                                    top: 20,
                                    bottom: 20,
                                    child: Container(
                                      width: 1,
                                      color: Colors.white.withValues(alpha: 0.18),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Zoom Slider & Quick Adjust Controls
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.zoom_out,
                                  color: Colors.white54, size: 18),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: accentGold,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: accentGold,
                                    overlayColor:
                                        accentGold.withValues(alpha: 0.2),
                                    trackHeight: 3.5,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 7),
                                  ),
                                  child: Slider(
                                    value: _zoomScale.clamp(0.8, 3.5),
                                    min: 0.8,
                                    max: 3.5,
                                    onChanged: _setZoom,
                                  ),
                                ),
                              ),
                              const Icon(Icons.zoom_in,
                                  color: Colors.white54, size: 18),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton.icon(
                                onPressed: _rotateClockwise,
                                icon: const Icon(Icons.rotate_right_rounded,
                                    color: Colors.white70, size: 17),
                                label: const Text(
                                  'Putar 90°',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 11.5),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 16,
                                color: Colors.white12,
                              ),
                              TextButton.icon(
                                onPressed: _resetTransform,
                                icon: const Icon(Icons.restart_alt_rounded,
                                    color: Colors.white70, size: 17),
                                label: const Text(
                                  'Reset Posisi',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 11.5),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Tips Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_outlined,
                            size: 14, color: accentGold.withValues(alpha: 0.8)),
                        const SizedBox(width: 6),
                        Text(
                          'Geser & cubit 2 jari foto pada lingkaran di atas',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Bottom Action Buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.of(context).pop(null),
                            child: const Text(
                              'Batal',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentGold,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 4,
                            ),
                            onPressed: _isProcessing
                                ? null
                                : _handleSaveCroppedAvatar,
                            child: _isProcessing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_rounded, size: 18),
                                      SizedBox(width: 6),
                                      Text(
                                        'Terapkan Foto',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ],
                                  ),
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
    );
  }
}
