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
import '../widgets/premium_toast.dart';
import '../utils/app_theme.dart';
import '../widgets/app_header.dart';
import '../services/storage_service.dart';
import '../utils/api_config.dart';

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
  String? _authToken;
  bool _networkImageFailed = false;

  bool _isValidImageBytes(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // Check for common image headers
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
    // GIF: 47 49 46 38
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) return true;
    // WebP: 52 49 46 46 ... 57 45 42 50
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return true;
    return false;
  }

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

  /// Called when user taps Retake: clear current photo (and validation) then open camera.
  /// Ensures "Retake" works after first capture.
  void _retakePhoto() {
    if (!mounted) return;
    setState(() {
      _imagePath = null;
      _imageBytes = null;
      _validationResult = null;
      _networkImageFailed = false;
    });
    _captureFromCamera();
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
          // Reset validation when image changes - this will revert border to original color
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
      Map<String, dynamic>? uploadResult;
      
      // Check if image is already uploaded (remote URL)
      if (_imagePath!.startsWith('http')) {
        // Reuse existing upload data
        final currentApp = appProvider.currentApplication;
        if (currentApp?.step1Selfie != null) {
          final stepData = currentApp!.step1Selfie as Map<String, dynamic>;
          uploadResult = stepData['uploadedFile'] as Map<String, dynamic>?;
        }
      } else {
        // New local file - upload it
        final imageFile = XFile(_imagePath!);
        uploadResult = await _fileUploadService.uploadSelfie(imageFile);
      }

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
      if (mounted) {
        final submissionProvider = context.read<SubmissionProvider>();
        submissionProvider.setSelfie(_imagePath!);
      }

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
    final submissionProvider = context.read<SubmissionProvider>();
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
          if (apiPath.startsWith('/uploads/') &&
              !apiPath.contains('/uploads/files/')) {
            apiPath = apiPath.replaceFirst('/uploads/', '/api/v1/uploads/files/');
          } else if (!apiPath.startsWith('/api/')) {
            apiPath = '/api/v1$apiPath';
          }
          effectivePath = '${ApiConfig.baseUrl}$apiPath';
        }
        debugPrint('📷 Selfie Screen: effectivePath = $effectivePath');
      } else {
        effectivePath = imagePath;
        // Fix for "baseUrl" prefix if present in the saved imagePath
        if (effectivePath != null && effectivePath.startsWith('baseUrl')) {
           effectivePath = effectivePath.replaceFirst('baseUrl', ApiConfig.baseUrl);
        }
        debugPrint(
          '📷 Selfie Screen: Using imagePath as effectivePath = $effectivePath',
        );
      }

      if (effectivePath != null && effectivePath.isNotEmpty && mounted) {
        setState(() {
          _imagePath = effectivePath;
          // Mark as already validated since it was saved
          _validationResult = SelfieValidationResult(isValid: true, errors: []);
        });

        // Also sync to SubmissionProvider
        submissionProvider.setSelfie(effectivePath);

        // Try to load image bytes from URL for display
        try {
          if (effectivePath.startsWith('http')) {
            // Get access token for authenticated request
            final storage = StorageService.instance;
            final accessToken = await storage.getAccessToken();
            final headers = <String, String>{};
            if (accessToken != null) {
              headers['Authorization'] = 'Bearer $accessToken';
              if (mounted) {
                setState(() {
                  _authToken = accessToken;
                });
              }
              
              debugPrint('📷 Selfie Screen: Fetching image from $effectivePath');
              final response = await http.get(Uri.parse(effectivePath), headers: headers);
              debugPrint('📷 Selfie Screen: Fetch status: ${response.statusCode}, Content-Type: ${response.headers['content-type']}, Size: ${response.bodyBytes.length}');
              
              if (response.statusCode == 200 && mounted) {
                final contentType = response.headers['content-type'] ?? '';
                final bytes = response.bodyBytes;
                
                // Validate that we actually received image data, not HTML or other content
                if (bytes.isNotEmpty && _isValidImageBytes(bytes)) {
                  setState(() {
                    _imageBytes = bytes;
                    _networkImageFailed = false;
                  });
                  debugPrint('📷 Selfie Screen: Successfully loaded image (${bytes.length} bytes)');
                } else {
                  final header = bytes.length >= 10 
                      ? bytes.sublist(0, 10).map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')
                      : 'too short';
                  debugPrint('📷 Selfie Screen: Invalid image data received. Content-Type: $contentType, Header: $header');
                  
                  // Check if it's HTML (common error response)
                  if (bytes.length > 10 && bytes[0] == 0x3c && bytes[1] == 0x21) {
                    final htmlSnippet = String.fromCharCodes(bytes.sublist(0, bytes.length > 100 ? 100 : bytes.length));
                    debugPrint('📷 Selfie Screen: Server returned HTML instead of image: $htmlSnippet');
                  }
                  
                  setState(() {
                    _networkImageFailed = true;
                  });
                }
              } else {
                debugPrint('Failed to load selfie: ${response.statusCode}');
                if (mounted) {
                  setState(() {
                    _networkImageFailed = true; // Mark as failed so we don't try Image.network
                  });
                }
              }
            } else {
               debugPrint('Skipping selfie fetch: no access token');
               // If no token, we can't show protected image. 
               // PlatformImage (in build) waits for _authToken != null anyway.
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
    } else {
      // Backend has no step1Selfie (e.g. after returning from Aadhaar step) — use SubmissionProvider
      // so the selfie is not lost when navigating Preview → Edit Aadhaar → Back (to Selfie)
      final existingSelfiePath = submissionProvider.submission.selfiePath;
      if (existingSelfiePath != null && existingSelfiePath.isNotEmpty && mounted) {
        debugPrint('📷 Selfie Screen: Restoring selfie from SubmissionProvider: $existingSelfiePath');
        setState(() {
          _imagePath = existingSelfiePath;
          _validationResult = SelfieValidationResult(isValid: true, errors: []);
        });
        if (existingSelfiePath.startsWith('http')) {
          try {
            final storage = StorageService.instance;
            final accessToken = await storage.getAccessToken();
            if (accessToken != null && mounted) {
              setState(() => _authToken = accessToken);
              final response = await http.get(Uri.parse(existingSelfiePath), headers: {'Authorization': 'Bearer $accessToken'});
              if (response.statusCode == 200 && mounted && _isValidImageBytes(response.bodyBytes)) {
                setState(() { _imageBytes = response.bodyBytes; _networkImageFailed = false; });
              } else if (mounted) {
                setState(() => _networkImageFailed = true);
              }
            }
          } catch (_) {
            debugPrint('Could not load selfie bytes from SubmissionProvider path');
          }
        } else {
          try {
            final imageFile = XFile(existingSelfiePath);
            final bytes = await imageFile.readAsBytes();
            if (mounted) setState(() => _imageBytes = bytes);
          } catch (_) {}
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Blue Header
            AppHeader(
              title: 'Identity Verification',
              icon: Icons.account_circle,
              showBackButton: true,
              onBackPressed: () => context.go(AppRoutes.home),
              showHomeButton: true,
            ),
            
            // Progress Indicator with numbered circles
            _buildProgressIndicator(context),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Requirements Card
                    _buildRequirementsCard(context),
                    const SizedBox(height: 24),
                    // Selfie Display Area
                    _buildSelfieDisplayArea(context),
                    const SizedBox(height: 16),
                    
                    // Capture / Retake and Gallery Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            context,
                            icon: Icons.photo_camera,
                            label: _imagePath != null ? 'Retake' : 'Capture',
                            onPressed: _imagePath != null ? _retakePhoto : _captureFromCamera,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionButton(
                            context,
                            icon: Icons.collections,
                            label: 'Gallery',
                            onPressed: _selectFromGallery,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Validate Photo Button (only show if image exists and not validated)
                    if (_imagePath != null && _validationResult?.isValid != true)
                      _buildValidateButton(context),
                    
                    const SizedBox(height: 100), // Space for footer
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildFooter(context),
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      color: Colors.white,
      child: Row(
        children: [
          // Step 1: Current
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        blurRadius: 12,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '1',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: Colors.grey.shade200,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              ],
            ),
          ),
          // Steps 2-7: Pending
          for (int i = 2; i <= 7; i++) ...[
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$i',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  if (i < 7)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: Colors.grey.shade200,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequirementsCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF), // sky-50
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE0F2FE), // sky-100
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.info,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Requirements',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: const Color(0xFF1E293B), // slate-800
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRequirementItem('White background (passport style)'),
          const SizedBox(height: 12),
          _buildRequirementItem('Face clearly visible'),
          const SizedBox(height: 12),
          _buildRequirementItem('Good lighting'),
          const SizedBox(height: 12),
          _buildRequirementItem('No filters / editing'),
          const SizedBox(height: 12),
          _buildRequirementItem('No shadows'),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFFBAE6FD), // sky-200
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check,
            size: 16,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF475569), // slate-600
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelfieDisplayArea(BuildContext context) {
    final theme = Theme.of(context);

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.grey.shade50,
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Image or placeholder
              _imagePath != null
                  ? Center(
                      child: (_imagePath!.startsWith('http') && (_authToken == null || _networkImageFailed))
                          ? (_networkImageFailed
                              ? const Icon(Icons.broken_image, color: Colors.grey, size: 64)
                              : const CircularProgressIndicator())
                          : PlatformImage(
                              imagePath: _imagePath!,
                              imageBytes: _imageBytes,
                              fit: BoxFit.cover,
                              headers: _authToken != null ? {'Authorization': 'Bearer $_authToken'} : null,
                            ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 64,
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Capture your selfie',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
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

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValidateButton(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppTheme.primaryColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _isValidating ? null : _validateImage,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isValidating)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                const Icon(Icons.verified, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Validate Photo',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Colors.white.withValues(alpha: 0.95),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: _imagePath != null && _validationResult?.isValid == true
                  ? _proceedToNext
                  : null,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Next: Aadhaar Card',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 128,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.shade400.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }

}
