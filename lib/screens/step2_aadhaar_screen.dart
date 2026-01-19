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
      
      // Helper to build full URL - transform /uploads/{category}/ to /api/v1/uploads/files/{category}/
      String? buildFullUrl(String? relativeUrl) {
        if (relativeUrl == null || relativeUrl.isEmpty) return null;
        if (relativeUrl.startsWith('http') || relativeUrl.startsWith('blob:')) return relativeUrl;
        // Convert /uploads/aadhaar/... to /api/v1/uploads/files/aadhaar/...
        String apiPath = relativeUrl;
        if (apiPath.startsWith('/uploads/') && !apiPath.contains('/uploads/files/')) {
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
        });
        // Also update SubmissionProvider
        context.read<SubmissionProvider>().setAadhaarFront(effectiveFront);
      }
      if (effectiveBack != null && effectiveBack.isNotEmpty) {
        setState(() {
          _backPath = effectiveBack;
        });
        context.read<SubmissionProvider>().setAadhaarBack(effectiveBack);
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

  Future<void> _captureFront() async {
    final image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image != null && mounted) {
      setState(() {
        _frontPath = image.path;
        _frontIsPdf = false;
        _frontRotation = 0.0;
        _resetDraftState();
      });
      context.read<SubmissionProvider>().setAadhaarFront(image.path);
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
      context.read<SubmissionProvider>().setAadhaarFront(image.path);
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
      context.read<SubmissionProvider>().setAadhaarBack(image.path);
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
      context.read<SubmissionProvider>().setAadhaarBack(image.path);
    }
  }

  Future<void> _uploadFrontPdf() async {
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
          _frontPath = path;
          _frontIsPdf = true;
          _frontRotation = 0.0;
          _resetDraftState();
        });
        context.read<SubmissionProvider>().setAadhaarFront(path);
        _showPasswordDialogIfNeeded('front');
      }
    }
  }

  Future<void> _uploadBackPdf() async {
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
          _backPath = path;
          _backIsPdf = true;
          _backRotation = 0.0;
          _resetDraftState();
        });
        context.read<SubmissionProvider>().setAadhaarBack(path);
        _showPasswordDialogIfNeeded('back');
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
            Text('Is this PDF password protected? (${side == 'front' ? 'Front' : 'Back'} side)'),
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
                  } else {
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
            context.read<SubmissionProvider>().setAadhaarFront(tempFile.path);
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
            context.read<SubmissionProvider>().setAadhaarBack(tempFile.path);
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
      provider.setAadhaarFront(_frontPath!);
    }
    if (_backPath != null) {
      provider.setAadhaarBack(_backPath!);
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
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    colorScheme.primary.withValues(alpha: 0.03),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AppBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.secondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.credit_card,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Aadhaar Card',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    onPressed: () => context.go(AppRoutes.step1Selfie),
                    color: colorScheme.primary,
                  ),
                ),
              ),
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
                    // Front & Back Side Preview
                    if (_frontPath != null && _backPath != null) ...[
                      // Use LayoutBuilder to handle overflow on small screens
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
                                ),
                                const SizedBox(height: 16),
                                _buildSidePreview(
                                  context,
                                  'Back',
                                  _backPath!,
                                  onTap: _captureBack,
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
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildSidePreview(
                                    context,
                                    'Back',
                                    _backPath!,
                                    onTap: _captureBack,
                                  ),
                                ),
                              ],
                            );
                          }
                        },
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
                        _buildSidePreview(context, 'Front', _frontPath!, onTap: _captureFront)
                      else
                        _buildUploadCard(
                          context,
                          'Front Side',
                          Icons.credit_card,
                          onCamera: _captureFront,
                          onGallery: _selectFrontFromGallery,
                          onPdf: _uploadFrontPdf,
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
                        _buildSidePreview(context, 'Back', _backPath!, onTap: _captureBack)
                      else
                        _buildUploadCard(
                          context,
                          'Back Side',
                          Icons.credit_card,
                          onCamera: _captureBack,
                          onGallery: _selectBackFromGallery,
                          onPdf: _uploadBackPdf,
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
    String path,
    {required VoidCallback onTap}
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
              _frontIsPdf && label == 'Front'
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
                  : _backIsPdf && label == 'Back'
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
                          angle: (label == 'Front' ? _frontRotation : _backRotation) * 3.14159 / 180,
                          child: PlatformImage(imagePath: path, fit: BoxFit.cover),
                        ),
              Positioned(
                top: 12,
                left: 12,
                right: 60, // Reserve space for camera button to prevent overflow
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  constraints: const BoxConstraints(
                    maxWidth: double.infinity,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              // Action buttons overlay
              Positioned(
                bottom: 12,
                right: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!((label == 'Front' && _frontIsPdf) || (label == 'Back' && _backIsPdf))) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.rotate_right, color: Colors.white, size: 20),
                          onPressed: () => _rotateImage(label.toLowerCase()),
                          padding: const EdgeInsets.all(10),
                          constraints: const BoxConstraints(),
                          tooltip: 'Rotate',
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white, size: 24),
                        onPressed: onTap,
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
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
    VoidCallback? onPdf,
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
          // Use Flexible/Expanded with proper constraints to prevent overflow
          LayoutBuilder(
            builder: (context, constraints) {
              // On very small screens, stack buttons vertically
              if (constraints.maxWidth < 300) {
                return Column(
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
                    if (onPdf != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: PremiumButton(
                          label: 'Upload PDF',
                          icon: Icons.picture_as_pdf,
                          isPrimary: false,
                          onPressed: onPdf,
                        ),
                      ),
                    ],
                  ],
                );
              } else {
                return Row(
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
                    if (onPdf != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: PremiumButton(
                          label: 'PDF',
                          icon: Icons.picture_as_pdf,
                          isPrimary: false,
                          onPressed: onPdf,
                        ),
                      ),
                    ],
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

