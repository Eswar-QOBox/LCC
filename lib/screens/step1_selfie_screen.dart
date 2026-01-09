import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/submission_provider.dart';
import '../services/document_service.dart';
import '../models/document_submission.dart';
import '../utils/app_routes.dart';
import '../widgets/platform_image.dart';

class Step1SelfieScreen extends StatefulWidget {
  const Step1SelfieScreen({super.key});

  @override
  State<Step1SelfieScreen> createState() => _Step1SelfieScreenState();
}

class _Step1SelfieScreenState extends State<Step1SelfieScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  String? _imagePath;
  bool _isValidating = false;
  SelfieValidationResult? _validationResult;

  Future<void> _captureFromCamera() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (image != null) {
      _setImage(image.path);
    }
  }

  Future<void> _selectFromGallery() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image != null) {
      _setImage(image.path);
    }
  }

  void _setImage(String path) {
    setState(() {
      _imagePath = path;
      _validationResult = null;
    });
  }

  Future<void> _validateImage() async {
    if (_imagePath == null) return;

    setState(() {
      _isValidating = true;
    });

    // Simulate validation delay
    await Future.delayed(const Duration(milliseconds: 500));

    final result = await DocumentService.validateSelfie(_imagePath!);

    setState(() {
      _validationResult = result;
      _isValidating = false;
    });

    if (result.isValid) {
      context.read<SubmissionProvider>().setSelfie(_imagePath!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selfie validated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Validation Failed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Please ensure:'),
                const SizedBox(height: 8),
                ...result.errors.map((error) => Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text('• $error'),
                    )),
                const SizedBox(height: 16),
                const Text(
                  'Requirements:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text('• White background (passport style)'),
                const Text('• Face clearly visible'),
                const Text('• Good lighting'),
                const Text('• No filters / editing'),
                const Text('• No shadows'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _proceedToNext() {
    if (_imagePath != null && _validationResult?.isValid == true) {
      context.go(AppRoutes.step2Aadhaar);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture and validate your selfie first'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubmissionProvider>();
    _imagePath ??= provider.submission.selfiePath;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 1: Selfie / Photo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Requirements',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildRequirementItem('White background (passport style)'),
                    _buildRequirementItem('Face clearly visible'),
                    _buildRequirementItem('Good lighting'),
                    _buildRequirementItem('No filters / editing'),
                    _buildRequirementItem('No shadows'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_imagePath != null) ...[
              Container(
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _validationResult?.isValid == true
                        ? Colors.green
                        : Colors.grey,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: PlatformImage(
                    imagePath: _imagePath!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_validationResult != null) ...[
                if (_validationResult!.isValid)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text('Validation passed'),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.error, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Validation failed'),
                          ],
                        ),
                        if (_validationResult!.errors.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ..._validationResult!.errors.map(
                            (error) => Text('• $error'),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _captureFromCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Retake'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isValidating ? null : _validateImage,
                      icon: _isValidating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified),
                      label: const Text('Validate'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _captureFromCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _proceedToNext,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Next: Aadhaar Card'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

