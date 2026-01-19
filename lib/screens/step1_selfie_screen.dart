import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/application_provider.dart';
import '../providers/submission_provider.dart';
import '../services/document_service.dart';
import '../services/file_upload_service.dart';
import '../models/document_submission.dart';
import '../utils/app_routes.dart';
import '../widgets/platform_image.dart';
import '../widgets/step_progress_indicator.dart';
import '../widgets/premium_toast.dart';
import '../utils/app_theme.dart';
import '../services/storage_service.dart';

class Step1SelfieScreen extends StatefulWidget {
  const Step1SelfieScreen({super.key});

  @override
  State<Step1SelfieScreen> createState() => _Step1SelfieScreenState();
}

class _Step1SelfieScreenState extends State<Step1SelfieScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final FileUploadService _fileUploadService = FileUploadService();
  String? _imagePath;
  Uint8List? _imageBytes;
  bool _isValidating = false;
  bool _isSaving = false;
  SelfieValidationResult? _validationResult;

  Future<void> _captureFromCamera() async {
    if (!mounted) return;
    
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (image != null && mounted) {
        await _setImage(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to capture image. Please try again.'),
            backgroundColor: AppTheme.errorColor,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _captureFromCamera,
            ),
          ),
        );
      }
    }
  }

  Future<void> _selectFromGallery() async {
    if (!mounted) return;
    
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (image != null && mounted) {
        await _setImage(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to select image from gallery. Please try again.'),
            backgroundColor: AppTheme.errorColor,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _selectFromGallery,
            ),
          ),
        );
      }
    }
  }


  Future<void> _setImage(XFile imageFile) async {
    if (!mounted) return;
    
    try {
      // Validate file path
      if (imageFile.path.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Invalid image file. Please select a different image.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      // Read bytes for validation (works on both web and mobile)
      // Add timeout to prevent hanging on large files
      final bytes = await imageFile.readAsBytes().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Image loading timed out');
        },
      );

      if (!mounted) return;

      // Validate bytes
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image file is empty'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Limit image size to prevent memory issues (max 20MB)
      if (bytes.length > 20 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Image file is too large. Please select an image smaller than 20MB.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _imagePath = imageFile.path;
          _imageBytes = bytes;
          _validationResult = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to load image. Please try again.'),
            backgroundColor: AppTheme.errorColor,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                // Retry logic can be added if needed
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _validateImage() async {
    if (_imagePath == null || _imageBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please capture or select an image first'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    setState(() {
      _isValidating = true;
    });

    try {
      // Simulate validation delay
      await Future.delayed(const Duration(milliseconds: 500));

      final result = await DocumentService.validateSelfie(
        _imagePath!,
        imageBytes: _imageBytes,
      );

      if (!mounted) return;

      setState(() {
        _validationResult = result;
        _isValidating = false;
      });

      if (result.isValid) {
        if (mounted) {
          PremiumToast.showSuccess(
            context,
            'Selfie validated successfully!',
          );
          // Don't auto-save - only save when user proceeds (passport photo/authentication)
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Validation Failed'),
              content: SingleChildScrollView(
                child: Column(
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _isValidating = false;
        });
        PremiumToast.showError(
          context,
          'Error validating selfie: $e',
        );
      }
    }
  }

  Future<void> _saveToBackend() async {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication || _imagePath == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Upload image
      final imageFile = XFile(_imagePath!);
      final uploadResult = await _fileUploadService.uploadSelfie(imageFile);

      // Save step data to backend
      await appProvider.updateApplication(
        currentStep: 2, // Move to next step
        step1Selfie: {
          'imagePath': _imagePath,
          'uploadedFile': uploadResult,
          'validated': true,
          'validatedAt': DateTime.now().toIso8601String(),
        },
      );

      // Also update local submission state so preview step sees selfie as completed
      final submissionProvider = context.read<SubmissionProvider>();
      submissionProvider.setSelfie(_imagePath!);

      if (mounted) {
        PremiumToast.showSuccess(
          context,
          'Selfie saved successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        PremiumToast.showError(
          context,
          'Failed to save selfie: ${e.toString()}',
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

  void _proceedToNext() async {
    if (_imagePath != null && _validationResult?.isValid == true) {
      // Ensure data is saved before proceeding
      if (!_isSaving) {
        await _saveToBackend();
      }
      if (mounted) {
        context.go(AppRoutes.step2Aadhaar);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture and validate your selfie first'),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Load existing data from backend if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingData();
    });
  }

  Future<void> _loadExistingData() async {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication) {
      debugPrint('📷 Selfie Screen: No application in provider');
      return;
    }

    // Refresh application data from backend to get the latest saved data
    try {
      await appProvider.refreshApplication();
      debugPrint('📷 Selfie Screen: Refreshed application from backend');
    } catch (e) {
      debugPrint('📷 Selfie Screen: Failed to refresh application: $e');
    }

    final application = appProvider.currentApplication!;
    debugPrint('📷 Selfie Screen: step1Selfie = ${application.step1Selfie}');
    
    // Always load existing selfie if it exists in backend
    if (application.step1Selfie != null) {
      final stepData = application.step1Selfie as Map<String, dynamic>;
      final uploadedFile = stepData['uploadedFile'] as Map<String, dynamic>?;
      final imagePath = stepData['imagePath'] as String?;
      
      debugPrint('📷 Selfie Screen: uploadedFile = $uploadedFile');
      debugPrint('📷 Selfie Screen: imagePath = $imagePath');
      
      // Prefer uploaded file URL over local blob path (blob URLs don't persist on web refresh)
      String? effectivePath;
      if (uploadedFile != null && uploadedFile['url'] != null) {
        final relativeUrl = uploadedFile['url'] as String;
        debugPrint('📷 Selfie Screen: relativeUrl = $relativeUrl');
        // Build full URL - transform /uploads/{category}/ to /api/v1/uploads/files/{category}/
        if (relativeUrl.startsWith('http')) {
          effectivePath = relativeUrl;
        } else {
          // Convert /uploads/selfies/... to /api/v1/uploads/files/selfies/...
          String apiPath = relativeUrl;
          if (apiPath.startsWith('/uploads/') && !apiPath.contains('/uploads/files/')) {
            apiPath = apiPath.replaceFirst('/uploads/', '/api/v1/uploads/files/');
          } else if (!apiPath.startsWith('/api/')) {
            apiPath = '/api/v1$apiPath';
          }
          effectivePath = 'http://localhost:5000$apiPath';
        }
        debugPrint('📷 Selfie Screen: effectivePath = $effectivePath');
      } else {
        effectivePath = imagePath;
        debugPrint('📷 Selfie Screen: Using imagePath as effectivePath = $effectivePath');
      }
      
      if (effectivePath != null && effectivePath.isNotEmpty) {
        setState(() {
          _imagePath = effectivePath;
          // Mark as already validated since it was saved
          _validationResult = SelfieValidationResult(isValid: true, errors: []);
        });
        
        // Try to load image bytes from URL for display
        try {
          if (effectivePath.startsWith('http')) {
            // Get access token for authenticated request
            final storage = StorageService.instance;
            final accessToken = await storage.getAccessToken();
            final headers = <String, String>{};
            if (accessToken != null) {
              headers['Authorization'] = 'Bearer $accessToken';
            }
            final response = await http.get(Uri.parse(effectivePath), headers: headers);
            if (response.statusCode == 200 && mounted) {
              setState(() {
                _imageBytes = response.bodyBytes;
              });
            } else {
              debugPrint('Failed to load selfie: ${response.statusCode}');
            }
          } else {
            // Try to load from local path
            final imageFile = XFile(effectivePath);
            final bytes = await imageFile.readAsBytes();
            if (mounted) {
              setState(() {
                _imageBytes = bytes;
              });
            }
          }
        } catch (e) {
          // If we can't load the bytes, that's okay - PlatformImage will handle it
          debugPrint('Could not load selfie image bytes: $e');
        }
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
              colorScheme.primary.withValues(alpha: 0.05),
              colorScheme.secondary.withValues(alpha: 0.02),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            // Premium AppBar
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                            colors: [
                              colorScheme.surface,
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
                        Icons.face,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Identity Verification',
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
                    onPressed: () => context.go(AppRoutes.home),
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
            
            // Progress Indicator (below AppBar)
            const StepProgressIndicator(currentStep: 1, totalSteps: 6),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Requirements Card with Gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                            colors: [
                              colorScheme.surface,
                              colorScheme.primary.withValues(alpha: 0.03),
                            ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        colorScheme.primary,
                                        colorScheme.secondary,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.info_outline,
                                    color: colorScheme.onPrimary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Requirements',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildRequirementItem('White background (passport style)'),
                            _buildRequirementItem('Face clearly visible'),
                            _buildRequirementItem('Good lighting'),
                            _buildRequirementItem('No filters / editing'),
                            _buildRequirementItem('No shadows'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_imagePath != null) ...[
                      // Image Preview with Enhanced Design
                      Container(
                        height: 350,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (_validationResult?.isValid == true
                                      ? AppTheme.successColor
                                      : colorScheme.primary)
                                  .withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: _validationResult?.isValid == true
                                ? AppTheme.successColor
                                : colorScheme.primary,
                            width: 3,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(17),
                          child: Stack(
                            children: [
                              PlatformImage(
                                imagePath: _imagePath!,
                                imageBytes: _imageBytes,
                                fit: BoxFit.cover,
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
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_validationResult != null) ...[
                        if (_validationResult!.isValid)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.successColor.withValues(alpha: 0.1),
                                  AppTheme.successColor.withValues(alpha: 0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.successColor,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Validation Passed!',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.successColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Your selfie meets all requirements',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.errorColor.withValues(alpha: 0.1),
                                  AppTheme.errorColor.withValues(alpha: 0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.errorColor,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.errorColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.error,
                                        color: colorScheme.onError,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'Validation Failed',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_validationResult!.errors.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  ..._validationResult!.errors.map(
                                    (error) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.circle,
                                            size: 6,
                                            color: AppTheme.errorColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(error)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              child: OutlinedButton.icon(
                                onPressed: _captureFromCamera,
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Retake'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              child: OutlinedButton.icon(
                                onPressed: _selectFromGallery,
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Gallery'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary,
                                    colorScheme.secondary,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(alpha: 0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _isValidating ? null : _validateImage,
                                icon: _isValidating
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                                        ),
                                      )
                                    : Icon(Icons.verified, color: colorScheme.onPrimary),
                                label: Text(
                                  'Validate',
                                  style: TextStyle(
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Capture Options with Enhanced Design
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              colorScheme.primary.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 80,
                              color: colorScheme.primary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Capture Your Selfie',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please use the camera to capture a live selfie',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCaptureButton(
                                    context,
                                    icon: Icons.camera_alt,
                                    label: 'Camera',
                                    onPressed: _captureFromCamera,
                                    isPrimary: true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildCaptureButton(
                                    context,
                                    icon: Icons.photo_library,
                                    label: 'Gallery',
                                    onPressed: _selectFromGallery,
                                    isPrimary: false,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    // Next Button with Gradient
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.secondary,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _proceedToNext,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Next: Aadhaar Card',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_forward, color: colorScheme.onPrimary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (isPrimary) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [colorScheme.primary, colorScheme.secondary],
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: colorScheme.onPrimary, size: 28),
          label: Text(
            label,
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 24),
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
          ),
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary, width: 2),
      ),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: colorScheme.primary),
        label: Text(
          label,
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
