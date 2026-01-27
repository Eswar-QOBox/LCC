import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../utils/app_theme.dart';

/// Full-screen selfie capture with a face grid overlay.
/// Uses live camera on mobile; on web, falls back to image picker and pops without opening camera.
/// Returns [XFile] on success, null on cancel/back.
class FaceGridCaptureScreen extends StatefulWidget {
  const FaceGridCaptureScreen({super.key});

  @override
  State<FaceGridCaptureScreen> createState() => _FaceGridCaptureScreenState();
}

class _FaceGridCaptureScreenState extends State<FaceGridCaptureScreen> {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _errorMessage;
  bool _useFrontCamera = true;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _errorMessage = 'Face grid capture is available on mobile. Use Gallery on web.';
      return;
    }
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _errorMessage = 'No camera found.');
        return;
      }
      // Prefer front camera for selfie
      final camera = _useFrontCamera && _cameras.any((c) => c.lensDirection == CameraLensDirection.front)
          ? _cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front)
          : _cameras.first;

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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final XFile file = await _controller!.takePicture();
      if (mounted) {
        Navigator.of(context).pop(file);
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
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.black87,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('Selfie Capture'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.face_retouching_natural, size: 64, color: Colors.white54),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Use Gallery to select a photo.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
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

    if (_errorMessage != null && !_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black87,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('Selfie Capture'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.white54),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
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
          _buildFaceGridOverlay(),
          _buildTopBar(),
          _buildBottomBar(),
        ],
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

  Widget _buildFaceGridOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _FaceGridPainter(),
        );
      },
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
            style: IconButton.styleFrom(
              backgroundColor: Colors.black45,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Position your face in the oval',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _isCapturing ? null : _capture,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: _isCapturing
                        ? Colors.white24
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                  child: _isCapturing
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.camera_alt, color: Colors.white, size: 36),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaceGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.45);
    final ovalW = size.width * 0.72;
    final ovalH = size.height * 0.42;
    final ovalRect = Rect.fromCenter(center: center, width: ovalW, height: ovalH);

    // Dark overlay with oval cutout
    final darkPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final ovalPath = Path()..addOval(ovalRect);
    final cutoutPath = Path.combine(PathOperation.difference, darkPath, ovalPath);
    canvas.drawPath(
      cutoutPath,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // Face oval outline
    canvas.drawPath(
      ovalPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Corner brackets (grid style) at oval bounds
    const bracketLen = 28.0;
    const strokeW = 3.0;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW;

    final left = ovalRect.left;
    final right = ovalRect.right;
    final top = ovalRect.top;
    final bottom = ovalRect.bottom;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(left, top + bracketLen)
        ..lineTo(left, top)
        ..lineTo(left + bracketLen, top),
      stroke,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(right - bracketLen, top)
        ..lineTo(right, top)
        ..lineTo(right, top + bracketLen),
      stroke,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(left, bottom - bracketLen)
        ..lineTo(left, bottom)
        ..lineTo(left + bracketLen, bottom),
      stroke,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(right - bracketLen, bottom)
        ..lineTo(right, bottom)
        ..lineTo(right, bottom - bracketLen),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
