import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../providers/submission_provider.dart';
import '../providers/application_provider.dart';
import '../services/file_upload_service.dart';
import '../utils/app_routes.dart';
import '../utils/blob_helper.dart';
import '../widgets/platform_image.dart';
import '../widgets/step_progress_indicator.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_toast.dart';
import '../widgets/app_header.dart';
import '../utils/app_theme.dart';

class Step2AadhaarScreen extends StatefulWidget {
  const Step2AadhaarScreen({super.key});

  @override
  State<Step2AadhaarScreen> createState() => _Step2AadhaarScreenState();
}

class _Step2AadhaarScreenState extends State<Step2AadhaarScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final FileUploadService _fileUploadService = FileUploadService();
  String? _frontPath;
  String? _backPath;
  bool _isDraftSaved = false;
  bool _isSavingDraft = false;
  bool _isSaving = false;
  bool _frontIsPdf = false;
  bool _backIsPdf = false;
  String? _frontPdfPassword;
  String? _backPdfPassword;
  double _frontRotation = 0.0;
  double _backRotation = 0.0;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SubmissionProvider>();
    _frontPath = provider.submission.aadhaar?.frontPath;
    _backPath = provider.submission.aadhaar?.backPath;
    
    // Load existing data from backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingData();
    });
  }

  Future<void> _loadExistingData() async {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication) return;

    // Refresh application data from backend to get the latest saved data
    try {
      await appProvider.refreshApplication();
    } catch (e) {
      debugPrint('Aadhaar Screen: Failed to refresh application: $e');
    }

    final application = appProvider.currentApplication!;
    if (application.step2Aadhaar != null) {
      final stepData = application.step2Aadhaar as Map<String, dynamic>;
      final frontUpload = stepData['frontUpload'] as Map<String, dynamic>?;
      final backUpload = stepData['backUpload'] as Map<String, dynamic>?;
      final frontPath = stepData['frontPath'] as String?;
      final backPath = stepData['backPath'] as String?;
      final frontIsPdf = stepData['frontIsPdf'] as bool? ?? false;
      final backIsPdf = stepData['backIsPdf'] as bool? ?? false;
      final frontPdfPassword = stepData['frontPdfPassword'] as String?;
      final backPdfPassword = stepData['backPdfPassword'] as String?;

      // Helper to build full URL - transform /uploads/{category}/ to /api/v1/uploads/files/{category}/
      String? buildFullUrl(String? relativeUrl) {
        if (relativeUrl == null || relativeUrl.isEmpty) return null;
        if (relativeUrl.startsWith('http') || relativeUrl.startsWith('blob:')) {
          return relativeUrl;
        }
        // Convert /uploads/aadhaar/... to /api/v1/uploads/files/aadhaar/...
        String apiPath = relativeUrl;
        if (apiPath.startsWith('/uploads/') &&
            !apiPath.contains('/uploads/files/')) {
          apiPath = apiPath.replaceFirst('/uploads/', '/api/v1/uploads/files/');
        } else if (!apiPath.startsWith('/api/')) {
          apiPath = '/api/v1$apiPath';
        }
        return 'http://localhost:5000$apiPath';
      }
      
      // Prefer uploaded file URL over local blob path
      final effectiveFront = buildFullUrl(frontUpload?['url'] as String?) ?? frontPath;
      final effectiveBack = buildFullUrl(backUpload?['url'] as String?) ?? backPath;
      
      if (effectiveFront != null && effectiveFront.isNotEmpty) {
        setState(() {
          _frontPath = effectiveFront;
          _frontIsPdf = frontIsPdf;
          _frontPdfPassword = frontPdfPassword;
        });
        // Also update SubmissionProvider
        context
            .read<SubmissionProvider>()
            .setAadhaarFront(effectiveFront, isPdf: frontIsPdf);
      }
      if (effectiveBack != null && effectiveBack.isNotEmpty) {
        setState(() {
          _backPath = effectiveBack;
          _backIsPdf = backIsPdf;
          _backPdfPassword = backPdfPassword;
        });
        context
            .read<SubmissionProvider>()
            .setAadhaarBack(effectiveBack, isPdf: backIsPdf);
      }
    }
  }

  void _resetDraftState() {
    if (_isDraftSaved) {
      setState(() {
        _isDraftSaved = false;
      });
    }
  }

  void _removePdf() {
    setState(() {
      _frontPath = null;
      _backPath = null;
      _frontIsPdf = false;
      _backIsPdf = false;
      _frontPdfPassword = null;
      _backPdfPassword = null;
      _frontRotation = 0.0;
      _backRotation = 0.0;
      _resetDraftState();
    });
    // Clear Aadhaar data from provider by resetting to empty state
    // The provider will be updated when user uploads new files
    final provider = context.read<SubmissionProvider>();
    // Reset Aadhaar in provider - we'll set it again when new files are uploaded
    if (provider.submission.aadhaar != null) {
      provider.submission.aadhaar = null;
    }
  }

  void _removeFrontImage() {
    setState(() {
      _frontPath = null;
      _frontIsPdf = false;
      _frontRotation = 0.0;
      _frontPdfPassword = null;
      _resetDraftState();
    });
    final provider = context.read<SubmissionProvider>();
    if (provider.submission.aadhaar != null) {
      provider.submission.aadhaar!.frontPath = null;
      provider.submission.aadhaar!.frontIsPdf = false;
      if (provider.submission.aadhaar!.frontPath == null && 
          provider.submission.aadhaar!.backPath == null) {
        provider.submission.aadhaar = null;
      }
    }
  }

  void _removeBackImage() {
    setState(() {
      _backPath = null;
      _backIsPdf = false;
      _backRotation = 0.0;
      _backPdfPassword = null;
      _resetDraftState();
    });
    final provider = context.read<SubmissionProvider>();
    if (provider.submission.aadhaar != null) {
      provider.submission.aadhaar!.backPath = null;
      provider.submission.aadhaar!.backIsPdf = false;
      if (provider.submission.aadhaar!.frontPath == null && 
          provider.submission.aadhaar!.backPath == null) {
        provider.submission.aadhaar = null;
      }
    }
  }

  Future<void> _captureFront() async {
    final image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image != null && mounted) {
      setState(() {
        _frontPath = image.path;
        _frontIsPdf = false;
        _frontRotation = 0.0;
        _resetDraftState();
      });
      context.read<SubmissionProvider>().setAadhaarFront(image.path, isPdf: false);
    }
  }

  Future<void> _selectFrontFromGallery() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() {
        _frontPath = image.path;
        _frontIsPdf = false;
        _frontRotation = 0.0;
        _resetDraftState();
      });
      context.read<SubmissionProvider>().setAadhaarFront(image.path, isPdf: false);
    }
  }

  Future<void> _captureBack() async {
    final image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image != null && mounted) {
      setState(() {
        _backPath = image.path;
        _backIsPdf = false;
        _backRotation = 0.0;
        _resetDraftState();
      });
      context.read<SubmissionProvider>().setAadhaarBack(image.path, isPdf: false);
    }
  }

  Future<void> _selectBackFromGallery() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() {
        _backPath = image.path;
        _backIsPdf = false;
        _backRotation = 0.0;
        _resetDraftState();
      });
      context.read<SubmissionProvider>().setAadhaarBack(image.path, isPdf: false);
    }
  }

  Future<void> _uploadPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      String path;
      
      if (kIsWeb) {
        final bytes = result.files.single.bytes;
        if (bytes == null) {
          if (mounted) {
            PremiumToast.showError(context, 'Unable to read PDF file');
          }
          return;
        }
        path = createBlobUrl(bytes, mimeType: 'application/pdf');
      } else {
        if (result.files.single.path == null) {
          if (mounted) {
            PremiumToast.showError(context, 'Unable to access file');
          }
          return;
        }
        path = result.files.single.path!;
      }
      
      if (mounted) {
        setState(() {
          // Set both front and back to the same PDF
          _frontPath = path;
          _backPath = path;
          _frontIsPdf = true;
          _backIsPdf = true;
          _frontRotation = 0.0;
          _backRotation = 0.0;
          _resetDraftState();
        });
        final provider = context.read<SubmissionProvider>();
        provider.setAadhaarFront(path, isPdf: true);
        provider.setAadhaarBack(path, isPdf: true);
        _showPasswordDialogIfNeeded('both');
      }
    }
  }

  void _showPasswordDialogIfNeeded(String side) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Is this PDF password protected?${side == 'both' ? '' : ' (${side == 'front' ? 'Front' : 'Back'} side)'}'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'PDF Password (if required)',
                hintText: 'Enter password or leave blank',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () {
              final password = passwordController.text.trim();
              if (mounted) {
                setState(() {
                  if (side == 'front') {
                    _frontPdfPassword = password.isNotEmpty ? password : null;
                  } else if (side == 'back') {
                    _backPdfPassword = password.isNotEmpty ? password : null;
                  } else if (side == 'both') {
                    // For single PDF covering both sides, set same password for both
                    _frontPdfPassword = password.isNotEmpty ? password : null;
                    _backPdfPassword = password.isNotEmpty ? password : null;
                  }
                });
              }
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _rotateImage(String side) async {
    if (kIsWeb) {
      // On web, just update rotation angle for display
      if (mounted) {
        setState(() {
          if (side == 'front' && _frontPath != null && !_frontIsPdf) {
            _frontRotation = (_frontRotation + 90) % 360;
          } else if (side == 'back' && _backPath != null && !_backIsPdf) {
            _backRotation = (_backRotation + 90) % 360;
          }
          _resetDraftState();
        });
        PremiumToast.showSuccess(context, 'Image rotated');
      }
      return;
    }

    if (side == 'front' && _frontPath != null && !_frontIsPdf) {
      try {
        final imageBytes = await io.File(_frontPath!).readAsBytes();
        final image = img.decodeImage(imageBytes);
        if (image != null) {
          final rotated = img.copyRotate(image, angle: 90);
          final rotatedBytes = Uint8List.fromList(img.encodeJpg(rotated));
          
          // Save rotated image
          final tempFile = io.File('${_frontPath!}_rotated_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await tempFile.writeAsBytes(rotatedBytes);
          
          if (mounted) {
            setState(() {
              _frontRotation = (_frontRotation + 90) % 360;
              _frontPath = tempFile.path;
              _resetDraftState();
            });
            context.read<SubmissionProvider>().setAadhaarFront(tempFile.path, isPdf: false);
            PremiumToast.showSuccess(context, 'Image rotated');
          }
        }
      } catch (e) {
        if (mounted) {
          PremiumToast.showError(context, 'Failed to rotate image: $e');
        }
      }
    } else if (side == 'back' && _backPath != null && !_backIsPdf) {
      try {
        final imageBytes = await io.File(_backPath!).readAsBytes();
        final image = img.decodeImage(imageBytes);
        if (image != null) {
          final rotated = img.copyRotate(image, angle: 90);
          final rotatedBytes = Uint8List.fromList(img.encodeJpg(rotated));
          
          // Save rotated image
          final tempFile = io.File('${_backPath!}_rotated_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await tempFile.writeAsBytes(rotatedBytes);
          
          if (mounted) {
            setState(() {
              _backRotation = (_backRotation + 90) % 360;
              _backPath = tempFile.path;
              _resetDraftState();
            });
            context.read<SubmissionProvider>().setAadhaarBack(tempFile.path, isPdf: false);
            PremiumToast.showSuccess(context, 'Image rotated');
          }
        }
      } catch (e) {
        if (mounted) {
          PremiumToast.showError(context, 'Failed to rotate image: $e');
        }
      }
    }
  }

  Future<void> _saveToBackend() async {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication || _frontPath == null || _backPath == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Upload front image
      final frontFile = XFile(_frontPath!);
      final frontUpload = await _fileUploadService.uploadAadhaar(
        frontFile,
        side: 'front',
      );

      // Upload back image
      final backFile = XFile(_backPath!);
      final backUpload = await _fileUploadService.uploadAadhaar(
        backFile,
        side: 'back',
      );

      // Save step data to backend
      await appProvider.updateApplication(
        currentStep: 3, // Move to next step
        step2Aadhaar: {
          'frontPath': _frontPath,
          'backPath': _backPath,
          'frontUpload': frontUpload,
          'backUpload': backUpload,
          'frontIsPdf': _frontIsPdf,
          'backIsPdf': _backIsPdf,
          'frontPdfPassword': _frontPdfPassword,
          'backPdfPassword': _backPdfPassword,
          'savedAt': DateTime.now().toIso8601String(),
        },
      );

      if (mounted) {
        PremiumToast.showSuccess(
          context,
          'Aadhaar saved successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        PremiumToast.showError(
          context,
          'Failed to save Aadhaar: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _proceedToNext() async {
    if (_frontPath != null && _backPath != null) {
      if (!_isSaving) {
        await _saveToBackend();
      }
      if (mounted) {
        context.go(AppRoutes.step3Pan);
      }
    } else {
      PremiumToast.showWarning(
        context,
        'Please upload both front and back sides of Aadhaar card',
      );
    }
  }

  Future<void> _saveDraft() async {
    if (_isSavingDraft || _isDraftSaved) return;

    setState(() {
      _isSavingDraft = true;
    });

    final provider = context.read<SubmissionProvider>();
    
    // Save current state to provider
    if (_frontPath != null) {
      provider.setAadhaarFront(_frontPath!, isPdf: _frontIsPdf);
    }
    if (_backPath != null) {
      provider.setAadhaarBack(_backPath!, isPdf: _backIsPdf);
    }

    try {
      final success = await provider.saveDraft();
      
      if (mounted) {
        if (success) {
          setState(() {
            _isDraftSaved = true;
            _isSavingDraft = false;
          });
          PremiumToast.showSuccess(
            context,
            'Draft saved successfully!',
            duration: const Duration(seconds: 2),
          );
        } else {
          setState(() {
            _isSavingDraft = false;
          });
          PremiumToast.showError(
            context,
            'Failed to save draft. Please try again.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingDraft = false;
        });
        PremiumToast.showError(
          context,
          'Error saving draft: $e',
        );
      }
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
            // Consistent Header
            AppHeader(
              title: 'Aadhaar Card',
              icon: Icons.credit_card,
              showBackButton: true,
              onBackPressed: () => context.go(AppRoutes.step1Selfie),
              showHomeButton: true,
            ),
            StepProgressIndicator(currentStep: 2, totalSteps: 6),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Check if PDF is uploaded (single PDF for both sides)
                    if (_frontIsPdf && _backIsPdf && _frontPath != null) ...[
                      // Single PDF preview
                      _buildSidePreview(
                        context,
                        'Aadhaar PDF',
                        _frontPath!,
                        onTap: _uploadPdf,
                        onRemove: _removePdf,
                        isPdf: true,
                      ),
                    ] else if (_frontPath != null && _backPath != null) ...[
                      // Both images uploaded - show side by side
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // On small screens, stack vertically; on larger screens, show side by side
                          if (constraints.maxWidth < 600) {
                            return Column(
                              children: [
                                _buildSidePreview(
                                  context,
                                  'Front',
                                  _frontPath!,
                                  onTap: _captureFront,
                                  isPdf: _frontIsPdf,
                                  onRetake: _captureFront,
                                  onGallery: _selectFrontFromGallery,
                                  onRemoveImage: _removeFrontImage,
                                ),
                                const SizedBox(height: 16),
                                _buildSidePreview(
                                  context,
                                  'Back',
                                  _backPath!,
                                  onTap: _captureBack,
                                  isPdf: _backIsPdf,
                                  onRetake: _captureBack,
                                  onGallery: _selectBackFromGallery,
                                  onRemoveImage: _removeBackImage,
                                ),
                              ],
                            );
                          } else {
                            return Row(
                              children: [
                                Expanded(
                                  child: _buildSidePreview(
                                    context,
                                    'Front',
                                    _frontPath!,
                                    onTap: _captureFront,
                                    isPdf: _frontIsPdf,
                                    onRetake: _captureFront,
                                    onGallery: _selectFrontFromGallery,
                                    onRemoveImage: _removeFrontImage,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildSidePreview(
                                    context,
                                    'Back',
                                    _backPath!,
                                    onTap: _captureBack,
                                    isPdf: _backIsPdf,
                                    onRetake: _captureBack,
                                    onGallery: _selectBackFromGallery,
                                    onRemoveImage: _removeBackImage,
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ] else ...[
                      // Single PDF upload button (for both front and back)
                      if (_frontPath == null && _backPath == null) ...[
                        PremiumButton(
                          label: 'Add PDF',
                          icon: Icons.picture_as_pdf,
                          isPrimary: false,
                          onPressed: _uploadPdf,
                        ),
                        const SizedBox(height: 24),
                      ],
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
                        _buildSidePreview(
                          context, 
                          'Front', 
                          _frontPath!, 
                          onTap: _captureFront,
                          isPdf: _frontIsPdf,
                          onRetake: _captureFront,
                          onGallery: _selectFrontFromGallery,
                          onRemoveImage: _removeFrontImage,
                        )
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
                        _buildSidePreview(
                          context, 
                          'Back', 
                          _backPath!, 
                          onTap: _captureBack,
                          isPdf: _backIsPdf,
                          onRetake: _captureBack,
                          onGallery: _selectBackFromGallery,
                          onRemoveImage: _removeBackImage,
                        )
                      else
                        _buildUploadCard(
                          context,
                          'Back Side',
                          Icons.credit_card,
                          onCamera: _captureBack,
                          onGallery: _selectBackFromGallery,
                        ),
                    ],
                    const SizedBox(height: 40),
                    // Save as Draft and Rotate buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isDraftSaved ? null : _saveDraft,
                            icon: _isDraftSaved
                                ? const Icon(Icons.check_circle)
                                : (_isSavingDraft
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.save_outlined)),
                            label: Text(_isDraftSaved
                                ? 'Draft Saved'
                                : (_isSavingDraft ? 'Saving...' : 'Save as Draft')),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              foregroundColor: _isDraftSaved
                                  ? AppTheme.successColor
                                  : null,
                              side: BorderSide(
                                color: _isDraftSaved
                                    ? AppTheme.successColor
                                    : colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
    String path, {
    required VoidCallback onTap,
    VoidCallback? onRemove,
    bool isPdf = false,
    VoidCallback? onRetake,
    VoidCallback? onGallery,
    VoidCallback? onRemoveImage,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFront = label == 'Front' || label == 'Aadhaar PDF';
    final showPdf = (isFront && _frontIsPdf) || (!isFront && _backIsPdf);
    
    return Column(
      children: [
        Container(
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
                showPdf
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.picture_as_pdf,
                              size: 60,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'PDF',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Transform.rotate(
                        angle: (isFront ? _frontRotation : _backRotation) * 3.14159 / 180,
                        child: PlatformImage(imagePath: path, fit: BoxFit.cover),
                      ),
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
                // Remove button (X) for PDF and Images - top right
                if ((showPdf && onRemove != null) || (!showPdf && onRemoveImage != null))
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: showPdf ? onRemove : onRemoveImage,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
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
        // Action buttons below preview
        if (!showPdf && onRetake != null && onGallery != null) ...[
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: PremiumButton(
                      label: 'Retake',
                      icon: Icons.camera_alt,
                      isPrimary: false,
                      onPressed: onRetake,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PremiumButton(
                      label: 'Re-upload from Gallery',
                      icon: Icons.photo_library,
                      isPrimary: false,
                      onPressed: onGallery,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.primary),
                    ),
                    child: IconButton(
                      onPressed: () => _rotateImage(label.toLowerCase()),
                      icon: Icon(Icons.rotate_right, color: colorScheme.primary),
                      tooltip: 'Rotate Image',
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: PremiumButton(
                  label: 'Switch to PDF Upload',
                  icon: Icons.picture_as_pdf,
                  isPrimary: false,
                  onPressed: () {
                    // Remove current image(s) and trigger PDF upload
                    if (label == 'Front') {
                      _removeFrontImage();
                    } else if (label == 'Back') {
                      _removeBackImage();
                    }
                    // Trigger PDF upload dialog after a short delay to allow state update
                    Future.delayed(const Duration(milliseconds: 200), () {
                      if (mounted) {
                        _uploadPdf();
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ] else if (showPdf && onRemove != null) ...[
          const SizedBox(height: 16),
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: PremiumButton(
                  label: 'Change PDF',
                  icon: Icons.picture_as_pdf,
                  isPrimary: false,
                  onPressed: onTap,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: PremiumButton(
                  label: 'Switch to Photo Upload',
                  icon: Icons.camera_alt,
                  isPrimary: false,
                  onPressed: () {
                    // Remove PDF and allow photo upload
                    onRemove();
                  },
                ),
              ),
            ],
          ),
        ],
      ],
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
          // Stack buttons vertically for better fit
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: PremiumButton(
                  label: 'Camera',
                  icon: Icons.camera_alt,
                  isPrimary: false,
                  onPressed: onCamera,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
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

