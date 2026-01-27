import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../utils/app_theme.dart';
import '../utils/grid_crop_helper_stub.dart'
    if (dart.library.io) '../utils/grid_crop_helper.dart' as grid_crop;

/// Full-screen PAN capture with horizontal card overlay only (no vertical option).
/// Returns [XFile] on success, null on cancel.
class PanHorizontalCardCaptureScreen extends StatefulWidget {
  const PanHorizontalCardCaptureScreen({super.key});

  @override
  State<PanHorizontalCardCaptureScreen> createState() =>
      _PanHorizontalCardCaptureScreenState();
}

class _PanHorizontalCardCaptureScreenState
    extends State<PanHorizontalCardCaptureScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _errorMessage;
  int? _countdownRemaining;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _errorMessage = 'PAN capture is available on mobile. Use Gallery on web.';
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
      final camera = cameras.any((c) => c.lensDirection == CameraLensDirection.back)
          ? cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back)
          : cameras.first;

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
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
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing ||
        _countdownRemaining != null) return;
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
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) return;
    setState(() {
      _countdownRemaining = null;
      _isCapturing = true;
    });
    try {
      final XFile file = await _controller!.takePicture();
      // Horizontal card only: always isVertical = false
      final String? croppedPath =
          await grid_crop.cropToGridAspect(file.path, false);
      final String pathToUse = croppedPath ?? file.path;
      if (mounted) {
        Navigator.of(context).pop(XFile(pathToUse));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Capture failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
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
      return _buildFallbackScaffold(
          'PAN Card', _errorMessage ?? 'Use Gallery on web.');
    }
    if (_errorMessage != null && !_isInitialized) {
      return _buildFallbackScaffold('PAN Card', _errorMessage!);
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
              Text(
                'Starting camera...',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
              ),
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
          _buildHorizontalCardOverlay(),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.credit_card, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _onCancel,
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor),
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
    if (size == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
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

  Widget _buildHorizontalCardOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _PanHorizontalCardPainter(),
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
          shadows: [
            Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
          ],
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
    const instruction = 'Align PAN card within the frame (horizontal only)';
    final capturing = _isCapturing || _countdownRemaining != null;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 28, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                instruction,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
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
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.timer, size: 22),
                  label: Text(
                    _countdownRemaining != null
                        ? 'Capturing in $_countdownRemaining…'
                        : (_isCapturing ? 'Saving…' : 'Auto capture'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal card only: wide rectangle with PAN card aspect (same as Aadhaar horizontal).
class _PanHorizontalCardPainter extends CustomPainter {
  static const double _aspectRatio = 1.58;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.48);
    final frameW = size.width * 0.88;
    final frameH = frameW / _aspectRatio;
    final rect = Rect.fromCenter(
        center: center, width: frameW, height: frameH);

    final darkPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cardPath = Path()..addRect(rect);
    final cutoutPath =
        Path.combine(PathOperation.difference, darkPath, cardPath);
    canvas.drawPath(
        cutoutPath, Paint()..color = Colors.black.withValues(alpha: 0.55));

    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(
        Offset(center.dx, rect.top), Offset(center.dx, rect.bottom), grid);
    canvas.drawLine(
        Offset(rect.left, center.dy), Offset(rect.right, center.dy), grid);

    const bracketLen = 32.0;
    const strokeW = 3.0;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW;
    final l = rect.left;
    final r = rect.right;
    final t = rect.top;
    final b = rect.bottom;

    canvas.drawPath(
        Path()
          ..moveTo(l, t + bracketLen)
          ..lineTo(l, t)
          ..lineTo(l + bracketLen, t),
        stroke);
    canvas.drawPath(
        Path()
          ..moveTo(r - bracketLen, t)
          ..lineTo(r, t)
          ..lineTo(r, t + bracketLen),
        stroke);
    canvas.drawPath(
        Path()
          ..moveTo(l, b - bracketLen)
          ..lineTo(l, b)
          ..lineTo(l + bracketLen, b),
        stroke);
    canvas.drawPath(
        Path()
          ..moveTo(r - bracketLen, b)
          ..lineTo(r, b)
          ..lineTo(r, b - bracketLen),
        stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
