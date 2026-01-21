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

class Step3PanScreen extends StatefulWidget {
  const Step3PanScreen({super.key});

  @override
  State<Step3PanScreen> createState() => _Step3PanScreenState();
}

class _Step3PanScreenState extends State<Step3PanScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final FileUploadService _fileUploadService = FileUploadService();
  String? _frontPath;
  bool _isDraftSaved = false;
  bool _isSavingDraft = false;
  bool _isSaving = false;
  bool _isPdf = false;
  String? _pdfPassword;
  double _rotation = 0.0;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SubmissionProvider>();
    _frontPath = provider.submission.pan?.frontPath;
    
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
      debugPrint('PAN Screen: Failed to refresh application: $e');
    }

    final application = appProvider.currentApplication!;
    if (application.step3Pan != null) {
      final stepData = application.step3Pan as Map<String, dynamic>;
      final uploadedFile = stepData['uploadedFile'] as Map<String, dynamic>?;
      final frontPath = stepData['frontPath'] as String?;
      
      // Helper to build full URL - transform /uploads/{category}/ to /api/v1/uploads/files/{category}/
      String? buildFullUrl(String? relativeUrl) {
        if (relativeUrl == null || relativeUrl.isEmpty) return null;
        if (relativeUrl.startsWith('http') || relativeUrl.startsWith('blob:')) return relativeUrl;
        // Convert /uploads/pan/... to /api/v1/uploads/files/pan/...
        String apiPath = relativeUrl;
        if (apiPath.startsWith('/uploads/') && !apiPath.contains('/uploads/files/')) {
          apiPath = apiPath.replaceFirst('/uploads/', '/api/v1/uploads/files/');
        } else if (!apiPath.startsWith('/api/')) {
          apiPath = '/api/v1$apiPath';
        }
        return 'http://localhost:5000$apiPath';
      }
      
      // Prefer uploaded file URL over local blob path
      final effectiveFront = buildFullUrl(uploadedFile?['url'] as String?) ?? frontPath;
      
      if (effectiveFront != null && effectiveFront.isNotEmpty) {
        setState(() {
          _frontPath = effectiveFront;
          _isPdf = stepData['isPdf'] as bool? ?? false;
          _pdfPassword = stepData['pdfPassword'] as String?;
        });
        // Also update SubmissionProvider
        context.read<SubmissionProvider>().setPanFront(effectiveFront);
      }
    }
  }

  Future<void> _saveToBackend() async {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication || _frontPath == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Upload PAN file (image or PDF)
      final panFile = XFile(_frontPath!);
      final uploadResult = await _fileUploadService.uploadPan(panFile);

      // Save step data to backend
      await appProvider.updateApplication(
        currentStep: 4, // Move to next step
        step3Pan: {
          'frontPath': _frontPath,
          'uploadedFile': uploadResult,
          'isPdf': _isPdf,
          'pdfPassword': _pdfPassword,
          'savedAt': DateTime.now().toIso8601String(),
        },
      );

      if (mounted) {
        PremiumToast.showSuccess(
          context,
          'PAN saved successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        PremiumToast.showError(
          context,
          'Failed to save PAN: ${e.toString()}',
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

  Future<void> _captureFromCamera() async {
    final image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image != null && mounted) {
      setState(() {
        _frontPath = image.path;
        _isPdf = false;
        _rotation = 0.0;
        _resetDraftState();
      });
      context.read<SubmissionProvider>().setPanFront(image.path);
    }
  }

  Future<void> _selectFromGallery() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() {
        _frontPath = image.path;
        _isPdf = false;
        _rotation = 0.0;
        _resetDraftState();
      });
      context.read<SubmissionProvider>().setPanFront(image.path);
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
          _frontPath = path;
          _isPdf = true;
          _rotation = 0.0;
          _resetDraftState();
        });
        context.read<SubmissionProvider>().setPanFront(path);
        _showPasswordDialogIfNeeded();
      }
    }
  }

  void _showPasswordDialogIfNeeded() {
    final passwordController = TextEditingController();
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final password = passwordController.text;
              if (mounted) {
                setState(() {
                  _pdfPassword = password.isNotEmpty ? password : null;
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

  Future<void> _rotateImage() async {
    if (kIsWeb) {
      // On web, just update rotation angle for display
      if (mounted) {
        setState(() {
          if (_frontPath != null && !_isPdf) {
            _rotation = (_rotation + 90) % 360;
            _resetDraftState();
          }
        });
        PremiumToast.showSuccess(context, 'Image rotated');
      }
      return;
    }

    if (_frontPath != null && !_isPdf) {
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
              _rotation = (_rotation + 90) % 360;
              _frontPath = tempFile.path;
              _resetDraftState();
            });
            context.read<SubmissionProvider>().setPanFront(tempFile.path);
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

  Future<void> _proceedToNext() async {
    if (_frontPath != null) {
      if (!_isSaving) {
        await _saveToBackend();
      }
      if (mounted) {
        context.go(AppRoutes.step4BankStatement);
      }
    } else {
      PremiumToast.showWarning(
        context,
        'Please upload PAN card front side',
      );
    }
  }

  void _resetDraftState() {
    if (_isDraftSaved) {
      setState(() {
        _isDraftSaved = false;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _frontPath = null;
      _isPdf = false;
      _rotation = 0.0;
      _pdfPassword = null;
      _resetDraftState();
    });
    final provider = context.read<SubmissionProvider>();
    if (provider.submission.pan != null) {
      provider.submission.pan!.frontPath = null;
      if (provider.submission.pan!.frontPath == null) {
        provider.submission.pan = null;
      }
    }
  }

  void _removePdf() {
    setState(() {
      _frontPath = null;
      _isPdf = false;
      _pdfPassword = null;
      _resetDraftState();
    });
    final provider = context.read<SubmissionProvider>();
    if (provider.submission.pan != null) {
      provider.submission.pan!.frontPath = null;
      if (provider.submission.pan!.frontPath == null) {
        provider.submission.pan = null;
      }
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
      provider.setPanFront(_frontPath!);
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
              title: 'PAN Card',
              icon: Icons.badge,
              showBackButton: true,
              onBackPressed: () => context.go(AppRoutes.step2Aadhaar),
              showHomeButton: true,
            ),
            // Premium Progress Indicator (below AppBar)
            StepProgressIndicator(currentStep: 3, totalSteps: 6),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Premium Requirements Card
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
                                  Icons.credit_card,
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
                                      'PAN Card Requirements',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ensure your document meets these standards',
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
                          _buildPremiumRequirement(
                            context,
                            icon: Icons.visibility,
                            text: 'Must be clear and readable',
                          ),
                          const SizedBox(height: 12),
                          _buildPremiumRequirement(
                            context,
                            icon: Icons.image,
                            text: 'Front side only (PAN has only front)',
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Document Preview or Upload Options
                    if (_frontPath != null) ...[
                      // Premium Image Preview
                      Container(
                        height: 400,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.2),
                              blurRadius: 30,
                              spreadRadius: 2,
                              offset: const Offset(0, 15),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Stack(
                            children: [
                              _isPdf
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
                                      angle: _rotation * 3.14159 / 180,
                                      child: PlatformImage(
                                        imagePath: _frontPath!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                              // Remove button (X) for PDF and Images - top right
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _isPdf ? _removePdf : _removeImage,
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
                              // Overlay gradient
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
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Action Buttons
                      Column(
                        children: [
                          if (!_isPdf) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: PremiumButton(
                                    label: 'Retake',
                                    icon: Icons.camera_alt,
                                    isPrimary: false,
                                    onPressed: _captureFromCamera,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: PremiumButton(
                                    label: 'Re-upload from Gallery',
                                    icon: Icons.photo_library,
                                    isPrimary: false,
                                    onPressed: _selectFromGallery,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: colorScheme.primary),
                                  ),
                                  child: IconButton(
                                    onPressed: _rotateImage,
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
                                  // Remove current image and trigger PDF upload
                                  _removeImage();
                                  // Trigger PDF upload dialog after a short delay to allow state update
                                  Future.delayed(const Duration(milliseconds: 200), () {
                                    if (mounted) {
                                      _uploadPdf();
                                    }
                                  });
                                },
                              ),
                            ),
                          ] else ...[
                            Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: PremiumButton(
                                    label: 'Change PDF',
                                    icon: Icons.picture_as_pdf,
                                    isPrimary: false,
                                    onPressed: _uploadPdf,
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
                                      _removePdf();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ] else ...[
                      // Premium Upload Options
                      PremiumCard(
                        gradientColors: [
                          Colors.white,
                          colorScheme.primary.withValues(alpha: 0.02),
                        ],
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary.withValues(alpha: 0.1),
                                    colorScheme.secondary.withValues(alpha: 0.05),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 64,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Upload Your PAN Card',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Capture or select from gallery',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Stack buttons vertically for better fit
                            Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: PremiumButton(
                                    label: 'Camera',
                                    icon: Icons.camera_alt,
                                    isPrimary: false,
                                    onPressed: _captureFromCamera,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: PremiumButton(
                                    label: 'Gallery',
                                    icon: Icons.photo_library,
                                    isPrimary: false,
                                    onPressed: _selectFromGallery,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: PremiumButton(
                                    label: 'Upload PDF',
                                    icon: Icons.picture_as_pdf,
                                    isPrimary: false,
                                    onPressed: _uploadPdf,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    // Save as Draft button
                    Builder(
                      builder: (context) {
                        final colorScheme = Theme.of(context).colorScheme;
                        return OutlinedButton.icon(
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
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Premium Next Button
                    PremiumButton(
                      label: 'Continue to Bank Statement',
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

  Widget _buildPremiumRequirement(BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

