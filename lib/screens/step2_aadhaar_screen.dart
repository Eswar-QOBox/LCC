import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/submission_provider.dart';
import '../utils/app_routes.dart';
import '../widgets/platform_image.dart';
import '../widgets/step_progress_indicator.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';
import '../utils/app_theme.dart';

class Step2AadhaarScreen extends StatefulWidget {
  const Step2AadhaarScreen({super.key});

  @override
  State<Step2AadhaarScreen> createState() => _Step2AadhaarScreenState();
}

class _Step2AadhaarScreenState extends State<Step2AadhaarScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  String? _frontPath;
  String? _backPath;
  String? _pdfPassword;
  bool _isPdf = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SubmissionProvider>();
    _frontPath = provider.submission.aadhaar?.frontPath;
    _backPath = provider.submission.aadhaar?.backPath;
    _isPdf = provider.submission.aadhaar?.isPdf ?? false;
    _pdfPassword = provider.submission.aadhaar?.pdfPassword;
  }

  Future<void> _captureFront() async {
    if (_isPdf) {
      await _pickPdf('front');
    } else {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null && mounted) {
        setState(() => _frontPath = image.path);
        context.read<SubmissionProvider>().setAadhaarFront(image.path);
      }
    }
  }

  Future<void> _selectFrontFromGallery() async {
    if (_isPdf) {
      await _pickPdf('front');
    } else {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        setState(() => _frontPath = image.path);
        context.read<SubmissionProvider>().setAadhaarFront(image.path);
      }
    }
  }

  Future<void> _captureBack() async {
    if (_isPdf) {
      await _pickPdf('back');
    } else {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null && mounted) {
        setState(() => _backPath = image.path);
        context.read<SubmissionProvider>().setAadhaarBack(image.path);
      }
    }
  }

  Future<void> _selectBackFromGallery() async {
    if (_isPdf) {
      await _pickPdf('back');
    } else {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        setState(() => _backPath = image.path);
        context.read<SubmissionProvider>().setAadhaarBack(image.path);
      }
    }
  }

  Future<void> _pickPdf(String side) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null && mounted) {
      final path = result.files.single.path!;
      if (side == 'front') {
        setState(() {
          _frontPath = path;
          _isPdf = true;
        });
        context.read<SubmissionProvider>().setAadhaarFront(path, isPdf: true);
      } else {
        setState(() {
          _backPath = path;
          _isPdf = true;
        });
        context.read<SubmissionProvider>().setAadhaarBack(path);
      }

      // Check if PDF might be password protected
      if (mounted) {
        _showPasswordDialogIfNeeded();
      }
    }
  }

  void _showPasswordDialogIfNeeded() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Is this PDF password protected?'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'PDF Password (if required)',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              onChanged: (value) => _pdfPassword = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _pdfPassword = null;
              Navigator.of(context).pop();
            },
            child: const Text('Not Required'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_pdfPassword != null && _pdfPassword!.isNotEmpty) {
                context.read<SubmissionProvider>().setAadhaarPassword(_pdfPassword!);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _proceedToNext() {
    if (_frontPath != null && _backPath != null) {
      context.go(AppRoutes.step3Pan);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload both front and back sides of Aadhaar card'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.08),
              colorScheme.secondary.withValues(alpha: 0.04),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            StepProgressIndicator(currentStep: 2, totalSteps: 6),
            AppBar(
              title: const Text('Step 2: Aadhaar Card'),
              elevation: 0,
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(AppRoutes.step1Selfie),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PremiumCard(
                      gradientColors: [
                        Colors.white,
                        colorScheme.primary.withValues(alpha: 0.03),
                      ],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primary,
                                      colorScheme.secondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.badge,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Aadhaar Card Requirements',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Both sides required for verification',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildPremiumRequirement(context, Icons.photo_camera, 'Must include Front & Back'),
                          const SizedBox(height: 12),
                          _buildPremiumRequirement(context, Icons.visibility_off, 'No blur or glare'),
                          const SizedBox(height: 12),
                          _buildPremiumRequirement(context, Icons.lock_outline, 'PDF password supported'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Front & Back Side Preview
                    if (_frontPath != null && _backPath != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildSidePreview(
                              context,
                              'Front',
                              _frontPath!,
                              _isPdf,
                              onTap: _captureFront,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSidePreview(
                              context,
                              'Back',
                              _backPath!,
                              _isPdf,
                              onTap: _captureBack,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Front Side
                      Text(
                        'Front Side',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_frontPath != null)
                        _buildSidePreview(context, 'Front', _frontPath!, _isPdf, onTap: _captureFront)
                      else
                        _buildUploadCard(
                          context,
                          'Front Side',
                          Icons.credit_card,
                          onCamera: _captureFront,
                          onGallery: _selectFrontFromGallery,
                        ),
                      const SizedBox(height: 24),
                      // Back Side
                      Text(
                        'Back Side',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_backPath != null)
                        _buildSidePreview(context, 'Back', _backPath!, _isPdf, onTap: _captureBack)
                      else
                        _buildUploadCard(
                          context,
                          'Back Side',
                          Icons.credit_card,
                          onCamera: _captureBack,
                          onGallery: _selectBackFromGallery,
                        ),
                    ],
                    if (_pdfPassword != null) ...[
                      const SizedBox(height: 24),
                      PremiumCard(
                        gradientColors: [
                          AppTheme.accentColor.withValues(alpha: 0.1),
                          AppTheme.accentColor.withValues(alpha: 0.05),
                        ],
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.lock, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PDF Password Protected',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.accentColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Password: ${'●' * _pdfPassword!.length}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    PremiumButton(
                      label: 'Continue to PAN Card',
                      icon: Icons.arrow_forward_rounded,
                      isPrimary: true,
                      onPressed: _proceedToNext,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumRequirement(BuildContext context, IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildSidePreview(
    BuildContext context,
    String label,
    String path,
    bool isPdf,
    {required VoidCallback onTap}
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              isPdf
                  ? Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary.withValues(alpha: 0.1),
                            colorScheme.secondary.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.picture_as_pdf, size: 48, color: colorScheme.primary),
                            const SizedBox(height: 8),
                            Text(label, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    )
                  : PlatformImage(imagePath: path, fit: BoxFit.cover),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadCard(
    BuildContext context,
    String title,
    IconData icon, {
    required VoidCallback onCamera,
    required VoidCallback onGallery,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return PremiumCard(
      gradientColors: [
        Colors.white,
        colorScheme.primary.withValues(alpha: 0.02),
      ],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.1),
                  colorScheme.secondary.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Icon(icon, size: 48, color: colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: PremiumButton(
                  label: 'Camera',
                  icon: Icons.camera_alt,
                  isPrimary: false,
                  onPressed: onCamera,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PremiumButton(
                  label: 'Gallery',
                  icon: Icons.photo_library,
                  isPrimary: false,
                  onPressed: onGallery,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

