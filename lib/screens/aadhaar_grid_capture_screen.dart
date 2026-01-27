import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../utils/app_theme.dart';
import '../utils/grid_crop_helper_stub.dart'
    if (dart.library.io) '../utils/grid_crop_helper.dart' as grid_crop;

/// Full-screen Aadhaar capture with document grid overlay and auto-capture countdown.
/// [isFront] true = front side, false = back side (instruction text only).
/// Returns [XFile] on success, null on cancel.
class AadhaarGridCaptureScreen extends StatefulWidget {
  const AadhaarGridCaptureScreen({super.key, this.isFront = true});

  final bool isFront;

  @override
  State<AadhaarGridCaptureScreen> createState() => _AadhaarGridCaptureScreenState();
}

class _AadhaarGridCaptureScreenState extends State<AadhaarGridCaptureScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _errorMessage;
  int? _countdownRemaining; // 3, 2, 1 during auto-capture
  Timer? _countdownTimer;
  /// true = vertical/portrait card, false = normal/horizontal card
  bool _isVerticalCard = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _errorMessage = 'Aadhaar grid capture is available on mobile. Use Gallery on web.';
      return;
    }
    _initCamera();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _errorMessage = 'No camera found.');
        return;
      }
      // Back camera for document
      final camera = cameras.any((c) => c.lensDirection == CameraLensDirection.back)
          ? cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back)
          : cameras.first;

      // Use a moderate resolution to reduce memory usage on older devices.
      // High resolutions can cause crashes when decoding/cropping images.
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        imageFormatGroup: ImageFormatGroup.jpeg,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _isInitialized = true;
        _errorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not start camera: $e';
          _isInitialized = false;
        });
      }
    }
  }

  void _startAutoCapture() {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing || _countdownRemaining != null) return;
    setState(() => _countdownRemaining = 3);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = _countdownRemaining! - 1;
      setState(() => _countdownRemaining = next <= 0 ? null : next);
      if (next <= 0) {
        timer.cancel();
        _countdownTimer = null;
        _doCapture();
      }
    });
  }

  Future<void> _doCapture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;
    setState(() {
      _countdownRemaining = null;
      _isCapturing = true;
    });
    try {
      final XFile file = await _controller!.takePicture();
      // Crop to grid aspect so we save only the content inside the frame
      final String? croppedPath =
          await grid_crop.cropToGridAspect(file.path, _isVerticalCard);
      final String pathToUse = croppedPath ?? file.path;
      if (mounted) {
        Navigator.of(context).pop(XFile(pathToUse));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _onCancel() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildFallbackScaffold('Aadhaar Capture', _errorMessage ?? 'Use Gallery on web.');
    }
    if (_errorMessage != null && !_isInitialized) {
      return _buildFallbackScaffold('Aadhaar Capture', _errorMessage!);
    }
    if (!_isInitialized || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text('Starting camera...', style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraPreview(),
          _buildDocumentGridOverlay(),
          _buildTopBar(),
          if (_countdownRemaining != null) _buildCountdownOverlay(),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Scaffold _buildFallbackScaffold(String title, String message) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.badge_outlined, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _onCancel,
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _controller!;
    final size = controller.value.previewSize;
    if (size == null) return const Center(child: CircularProgressIndicator(color: Colors.white));
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: size.height,
              height: size.width,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocumentGridOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _AadhaarGridPainter(isVertical: _isVerticalCard),
        );
      },
    );
  }

  Widget _buildCountdownOverlay() {
    final n = _countdownRemaining;
    if (n == null || n <= 0) return const SizedBox.shrink();
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Text(
        '$n',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 120,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: IconButton(
            onPressed: _onCancel,
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            style: IconButton.styleFrom(backgroundColor: Colors.black45),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final sideLabel = widget.isFront ? 'Front' : 'Back';
    final instruction = 'Align Aadhaar $sideLabel within the frame';
    final capturing = _isCapturing || _countdownRemaining != null;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 28, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Normal card / Vertical card toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCardTypeChip(label: 'Normal card', isSelected: !_isVerticalCard, onTap: () => setState(() => _isVerticalCard = false)),
                    const SizedBox(width: 8),
                    _buildCardTypeChip(label: 'Vertical card', isSelected: _isVerticalCard, onTap: () => setState(() => _isVerticalCard = true)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                instruction,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: capturing ? null : _startAutoCapture,
                  icon: _isCapturing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.timer, size: 22),
                  label: Text(_countdownRemaining != null ? 'Capturing in $_countdownRemaining…' : (_isCapturing ? 'Saving…' : 'Auto capture')),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardTypeChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return Material(
      color: isSelected ? AppTheme.primaryColor : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Document-shaped rectangle: normal (horizontal) or vertical Aadhaar aspect, with grid and corner brackets.
class _AadhaarGridPainter extends CustomPainter {
  /// true = vertical/portrait card (tall), false = normal/horizontal card (wide)
  final bool isVertical;

  _AadhaarGridPainter({this.isVertical = false});

  /// Normal card: width/height ≈ 1.58. Vertical card: height/width ≈ 1.58.
  static const double _aspectRatio = 1.58;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.48);
    double frameW;
    double frameH;
    if (isVertical) {
      // Vertical/portrait: frame is taller than wide
      frameW = size.width * 0.58;
      frameH = frameW * _aspectRatio;
    } else {
      // Normal/horizontal: frame is wider than tall
      frameW = size.width * 0.88;
      frameH = frameW / _aspectRatio;
    }
    final rect = Rect.fromCenter(center: center, width: frameW, height: frameH);

    // Dark overlay with rectangular cutout
    final darkPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cardPath = Path()..addRect(rect);
    final cutoutPath = Path.combine(PathOperation.difference, darkPath, cardPath);
    canvas.drawPath(cutoutPath, Paint()..color = Colors.black.withValues(alpha: 0.55));

    // Frame outline
    canvas.drawRect(
      rect,
      Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.5,
    );

    // Grid: 2x2 lines inside the frame
    final grid = Paint()..color = Colors.white.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 1.2;
    canvas.drawLine(Offset(center.dx, rect.top), Offset(center.dx, rect.bottom), grid);
    canvas.drawLine(Offset(rect.left, center.dy), Offset(rect.right, center.dy), grid);

    // Corner brackets
    const bracketLen = 32.0;
    const strokeW = 3.0;
    final stroke = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = strokeW;
    final l = rect.left;
    final r = rect.right;
    final t = rect.top;
    final b = rect.bottom;

    canvas.drawPath(Path()..moveTo(l, t + bracketLen)..lineTo(l, t)..lineTo(l + bracketLen, t), stroke);
    canvas.drawPath(Path()..moveTo(r - bracketLen, t)..lineTo(r, t)..lineTo(r, t + bracketLen), stroke);
    canvas.drawPath(Path()..moveTo(l, b - bracketLen)..lineTo(l, b)..lineTo(l + bracketLen, b), stroke);
    canvas.drawPath(Path()..moveTo(r - bracketLen, b)..lineTo(r, b)..lineTo(r, b - bracketLen), stroke);
  }

  @override
  bool shouldRepaint(covariant _AadhaarGridPainter oldDelegate) => oldDelegate.isVertical != isVertical;
}
