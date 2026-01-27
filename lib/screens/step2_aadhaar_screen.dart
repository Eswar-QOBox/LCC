import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import '../providers/submission_provider.dart';
import '../providers/application_provider.dart';
import '../services/file_upload_service.dart';
import '../services/ocr_service.dart';
import '../utils/app_routes.dart';
import '../utils/blob_helper.dart';
import '../widgets/platform_image.dart';
import 'package:http/http.dart' as http;
import '../widgets/premium_toast.dart';
import '../utils/app_theme.dart';
import '../widgets/app_header.dart';
import '../services/storage_service.dart';
import '../utils/api_config.dart';

class Step2AadhaarScreen extends StatefulWidget {
  const Step2AadhaarScreen({super.key, this.fromPreview = false});

  /// When true, Back returns to Preview (e.g. when opened via Edit from Preview).
  final bool fromPreview;

  @override
  State<Step2AadhaarScreen> createState() => _Step2AadhaarScreenState();
}

class _Step2AadhaarScreenState extends State<Step2AadhaarScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final FileUploadService _fileUploadService = FileUploadService();
  String? _frontPath;
  String? _backPath;
  bool _isSaving = false;
  bool _frontIsPdf = false;
  bool _backIsPdf = false;
  String? _frontPdfPassword;
  String? _backPdfPassword;
  double _frontRotation = 0.0;
  double _backRotation = 0.0;
  String? _authToken;
  bool _frontImageFailed = false;
  bool _backImageFailed = false;
  Uint8List? _frontBytes;
  Uint8List? _backBytes;

  // OCR extracted Aadhaar numbers for cross-validation
  String? _frontAadhaarNumber;
  String? _backAadhaarNumber;
  
  // OCR extracted name from Aadhaar (for PAN name cross-validation)
  String? _aadhaarName;
  
  // Internal validation flags (secret - not shown to user)
  bool _frontInternalValid = true;
  bool _backInternalValid = true;

  bool _isValidImageBytes(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // Check for common image headers
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true; // JPEG
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true; // PNG
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) return true; // GIF
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return true; // WebP
    return false;
  }

  @override
  void initState() {
    super.initState();
    final provider = context.read<SubmissionProvider>();
    _frontPath = provider.submission.aadhaar?.frontPath;
    _backPath = provider.submission.aadhaar?.backPath;
    _frontIsPdf = provider.submission.aadhaar?.frontIsPdf ?? false;
    _backIsPdf = provider.submission.aadhaar?.backIsPdf ?? false;
    
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
        return '${ApiConfig.baseUrl}$apiPath';
      }
      
      // Prefer uploaded file URL over local blob path
      final effectiveFront = buildFullUrl(frontUpload?['url'] as String?) ?? frontPath;
      final effectiveBack = buildFullUrl(backUpload?['url'] as String?) ?? backPath;
      
      // Get access token for authenticated request
      final storage = StorageService.instance;
      final accessToken = await storage.getAccessToken();
      if (accessToken != null && mounted) {
        setState(() {
          _authToken = accessToken;
        });
      }
      
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
        // Also update SubmissionProvider
        context
            .read<SubmissionProvider>()
            .setAadhaarBack(effectiveBack, isPdf: backIsPdf);
      }
      
      // Fetch front image if network URL
      if (effectiveFront != null && effectiveFront.startsWith('http') && accessToken != null) {
        try {
          final response = await http.get(
            Uri.parse(effectiveFront),
            headers: {'Authorization': 'Bearer $accessToken'},
          );
          if (response.statusCode == 200 && mounted) {
            final contentType = response.headers['content-type'] ?? '';
            final isLikelyImage = contentType.startsWith('image/');
            final bytes = response.bodyBytes;
            if (isLikelyImage && _isValidImageBytes(bytes)) {
              setState(() {
                _frontBytes = bytes;
                _frontImageFailed = false;
              });
            } else {
              setState(() { _frontImageFailed = true; });
            }
          } else {
             if (mounted) setState(() { _frontImageFailed = true; });
          }
        } catch (e) {
          if (mounted) setState(() { _frontImageFailed = true; });
        }
      }

      // Fetch back image if network URL
      if (effectiveBack != null && effectiveBack.startsWith('http') && accessToken != null) {
         try {
          final response = await http.get(
            Uri.parse(effectiveBack),
            headers: {'Authorization': 'Bearer $accessToken'},
          );
          if (response.statusCode == 200 && mounted) {
            final contentType = response.headers['content-type'] ?? '';
            final isLikelyImage = contentType.startsWith('image/');
            final bytes = response.bodyBytes;
            if (isLikelyImage && _isValidImageBytes(bytes)) {
              setState(() {
                _backBytes = bytes;
                _backImageFailed = false;
              });
            } else {
              setState(() { _backImageFailed = true; });
            }
          } else {
             if (mounted) setState(() { _backImageFailed = true; });
          }
        } catch (e) {
          if (mounted) setState(() { _backImageFailed = true; });
        }
      }
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
      _frontAadhaarNumber = null;
      _backAadhaarNumber = null;
      _aadhaarName = null;
      _frontInternalValid = true;
      _backInternalValid = true;
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
      _frontAadhaarNumber = null;
      _aadhaarName = null; // Name comes from front side
      _frontInternalValid = true;
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
      _backAadhaarNumber = null;
      _backInternalValid = true;
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
      });
      context.read<SubmissionProvider>().setAadhaarFront(image.path, isPdf: false);
      
      // Perform OCR on front side
      await _performAadhaarOCR(image.path, isFront: true);
    }
  }

  Future<void> _selectFrontFromGallery() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() {
        _frontPath = image.path;
        _frontIsPdf = false;
        _frontRotation = 0.0;
      });
      context.read<SubmissionProvider>().setAadhaarFront(image.path, isPdf: false);
      
      // Perform OCR on front side
      await _performAadhaarOCR(image.path, isFront: true);
    }
  }

  Future<void> _captureBack() async {
    final image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image != null && mounted) {
      setState(() {
        _backPath = image.path;
        _backIsPdf = false;
        _backRotation = 0.0;
      });
      context.read<SubmissionProvider>().setAadhaarBack(image.path, isPdf: false);
      
      // Perform OCR on back side
      await _performAadhaarOCR(image.path, isFront: false);
    }
  }

  Future<void> _selectBackFromGallery() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() {
        _backPath = image.path;
        _backIsPdf = false;
        _backRotation = 0.0;
      });
      context.read<SubmissionProvider>().setAadhaarBack(image.path, isPdf: false);
      
      // Perform OCR on back side
      await _performAadhaarOCR(image.path, isFront: false);
    }
  }

  /// Perform OCR on Aadhaar image and show extracted data
  Future<void> _performAadhaarOCR(String imagePath, {required bool isFront}) async {
    if (!mounted) return;

    try {
      // Show loading indicator
      if (mounted) {
        PremiumToast.showInfo(
          context,
          'Extracting text from Aadhaar card...',
          duration: const Duration(seconds: 2),
        );
      }

      final result = await OcrService.extractAadhaarText(imagePath, isFront: isFront);

      if (!mounted) return;

      if (result.success) {
        final extractedData = <String>[];
        final provider = context.read<SubmissionProvider>();
        
        // Store the Aadhaar number for cross-validation
        if (result.hasAadhaarNumber) {
          if (isFront) {
            _frontAadhaarNumber = result.aadhaarNumber;
            _frontInternalValid = result.isInternallyValid;
          } else {
            _backAadhaarNumber = result.aadhaarNumber;
            _backInternalValid = result.isInternallyValid;
          }
        }
        
        if (isFront) {
          // Front side: Show Aadhaar number, Name, and DOB, auto-fill to personal data
          if (result.hasAadhaarNumber) {
            extractedData.add('Aadhaar: ${result.aadhaarNumber}');
            // Auto-fill Aadhaar number to personal data
            provider.updatePersonalDataField(aadhaarNumber: result.aadhaarNumber);
          }
          if (result.hasName) {
            extractedData.add('Name: ${result.name}');
            // Store name for PAN cross-validation
            _aadhaarName = result.name;
            // Auto-fill name to personal data
            provider.updatePersonalDataField(fullName: result.name);
          }
          if (result.hasDateOfBirth) {
            extractedData.add('DOB: ${result.dateOfBirth}');
            // Auto-fill DOB to personal data
            try {
              final dobParts = result.dateOfBirth!.split('/');
              if (dobParts.length == 3) {
                final dob = DateTime(
                  int.parse(dobParts[2]), // year
                  int.parse(dobParts[1]), // month
                  int.parse(dobParts[0]), // day
                );
                provider.updatePersonalDataField(dateOfBirth: dob);
              }
            } catch (e) {
              debugPrint('Error parsing DOB: $e');
            }
          }
        } else {
          // Back side: Show address, auto-fill address
          if (result.hasAddress) {
            extractedData.add('Address: ${result.address}');
            // Auto-fill address to personal data
            provider.updatePersonalDataField(address: result.address);
          }
          
          // Also store the back side Aadhaar number for cross-validation (extracted above)
          if (result.hasAadhaarNumber) {
            extractedData.add('Aadhaar verified: ${result.aadhaarNumber}');
          }
        }

        if (extractedData.isNotEmpty) {
          PremiumToast.showSuccess(
            context,
            'Extracted & auto-filled: ${extractedData.join(' • ')}',
            duration: const Duration(seconds: 5),
          );
        } else {
          PremiumToast.showWarning(
            context,
            'No data extracted. Please ensure image is clear.',
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        PremiumToast.showWarning(
          context,
          result.errorMessage ?? 'Could not extract text from image',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        debugPrint('OCR Error: $e');
        // Don't show error toast - OCR is optional feature
      }
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
              decoration: InputDecoration(
                labelText: 'PDF Password (if required)',
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
                floatingLabelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
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

  Future<void> _saveToBackend() async {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication || _frontPath == null || _backPath == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      Map<String, dynamic>? frontUpload;
      Map<String, dynamic>? backUpload;
      
      final currentApp = appProvider.currentApplication;
      final existingData = currentApp?.step2Aadhaar;

      // specific helper to check if path is remote
      bool isRemote(String? path) => path != null && path.startsWith('http');

      // Upload or reuse front image
      if (isRemote(_frontPath)) {
        frontUpload = existingData?['frontUpload'] as Map<String, dynamic>?;
      } else {
        final frontFile = XFile(_frontPath!);
        frontUpload = await _fileUploadService.uploadAadhaar(
          frontFile,
          side: 'front',
          isPdf: _frontIsPdf,
        );
      }

      // Upload or reuse back image
      // Optimization: If it's a PDF and paths are the same, don't upload again
      if (_frontIsPdf && _backIsPdf && _frontPath == _backPath && frontUpload != null) {
        backUpload = frontUpload; // Reuse the same upload response
      } else if (isRemote(_backPath)) {
        backUpload = existingData?['backUpload'] as Map<String, dynamic>?;
      } else {
        final backFile = XFile(_backPath!);
        backUpload = await _fileUploadService.uploadAadhaar(
          backFile,
          side: 'back',
          isPdf: _backIsPdf,
        );
      }

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
          // OCR extracted data for verification
          'frontAadhaarNumber': _frontAadhaarNumber,
          'backAadhaarNumber': _backAadhaarNumber,
          'aadhaarName': _aadhaarName, // Name from Aadhaar for PAN cross-validation
          // Internal validation flags (for admin review - not shown to user)
          '_internalValidation': {
            'frontDocumentValid': _frontInternalValid,
            'backDocumentValid': _backInternalValid,
            'aadhaarNumbersMatch': _frontAadhaarNumber != null && _backAadhaarNumber != null 
                ? _frontAadhaarNumber!.replaceAll(RegExp(r'[\s-]'), '') == _backAadhaarNumber!.replaceAll(RegExp(r'[\s-]'), '')
                : null,
          },
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

  /// Show validation error dialog - user cannot proceed until fixed
  void _showValidationErrorDialog({
    required String title,
    required String message,
    required String instruction,
    required IconData icon,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        actionsAlignment: MainAxisAlignment.start,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFFEF4444), size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 15, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFBBF24)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      instruction,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK, I\'ll Fix It', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _proceedToNext() async {
    if (_frontPath == null || _backPath == null) {
      _showValidationErrorDialog(
        title: 'Missing Documents',
        message: 'You need to upload both the front and back sides of your Aadhaar card to continue.',
        instruction: 'Please capture or upload both sides of your Aadhaar card.',
        icon: Icons.photo_library_outlined,
      );
      return;
    }
    
    // Strict validation: Check if Aadhaar numbers from front and back match
    if (_frontAadhaarNumber != null && _backAadhaarNumber != null) {
      // Normalize both numbers (remove spaces/dashes)
      final frontNormalized = _frontAadhaarNumber!.replaceAll(RegExp(r'[\s-]'), '');
      final backNormalized = _backAadhaarNumber!.replaceAll(RegExp(r'[\s-]'), '');
      
      if (frontNormalized != backNormalized) {
        _showValidationErrorDialog(
          title: 'Aadhaar Number Mismatch',
          message: 'The Aadhaar number on the front side ($frontNormalized) does not match the back side ($backNormalized).',
          instruction: 'Please ensure you upload the front and back of the SAME Aadhaar card. Re-capture or re-upload the correct images.',
          icon: Icons.error_outline,
        );
        return;
      }
    }
    
    if (!_isSaving) {
      await _saveToBackend();
    }
    if (mounted) {
      context.go(AppRoutes.step3Pan);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Blue Header
            AppHeader(
              title: 'Aadhaar Card',
              icon: Icons.badge_outlined,
              showBackButton: true,
              onBackPressed: () => context.go(widget.fromPreview ? AppRoutes.step6Preview : AppRoutes.step1Selfie),
              showHomeButton: true,
            ),
            
            // Progress Indicator
            _buildProgressIndicator(context),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Requirements Card
                    _buildRequirementsCard(context),
                    const SizedBox(height: 24),
                    
                    // Show PDF card if PDF mode, otherwise show front/back sections
                    if (_frontIsPdf && _backIsPdf && _frontPath != null)
                      _buildPdfCardSection(context)
                    else ...[
                      // Front Side Section
                      _buildFrontSideSection(context),
                      const SizedBox(height: 24),
                      
                      // Back Side Section
                      _buildBackSideSection(context),
                      
                      // Single Switch to PDF Button (only show if not in PDF mode)
                      if (!(_frontIsPdf && _backIsPdf && _frontPath != null)) ...[
                        const SizedBox(height: 24),
                        _buildPdfSwitchButton(context),
                      ],
                    ],
                    const SizedBox(height: 32),
                    
                    // Action Buttons
                    _buildActionButtons(context),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      color: Colors.white,
      child: Row(
        children: [
          // Step 1: Completed
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              ],
            ),
          ),
          // Step 2: Current
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
                      '2',
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
          // Steps 3-7: Pending
          for (int i = 3; i <= 7; i++) ...[
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFEFF6FF), // blue-50
            const Color(0xFFDBEAFE).withValues(alpha: 0.5), // blue-100
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFDBEAFE), // blue-100
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  const Color(0xFF0052CC),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.badge,
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
                  'Aadhaar Card Requirements',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF1E293B), // slate-800
                  ),
                ),
                const SizedBox(height: 12),
                _buildRequirementItem(Icons.photo_camera, 'Must Include Front & Back'),
                const SizedBox(height: 8),
                _buildRequirementItem(Icons.visibility, 'No blur or glare'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF475569), // slate-600
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFrontSideSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Front Side',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: const Color(0xFF1E293B),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: _frontPath != null
                    ? LinearGradient(
                        colors: [
                          const Color(0xFF22C55E), // green-500
                          const Color(0xFF16A34A), // green-600
                        ],
                      )
                    : null,
                color: _frontPath != null ? null : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _frontPath != null
                    ? [
                        BoxShadow(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_frontPath != null)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 12,
                    ),
                  if (_frontPath != null) const SizedBox(width: 4),
                  Text(
                    _frontPath != null ? 'UPLOADED' : 'PENDING',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _frontPath != null
                          ? Colors.white
                          : Colors.grey.shade600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_frontPath != null)
          _buildImagePreview(context, _frontPath!, isFront: true)
        else
          _buildEmptyUploadState(context, 'Click to capture front side'),
        const SizedBox(height: 12),
        if (_frontPath != null) ...[
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.sync,
                  label: 'Retake',
                  onPressed: _captureFront,
                  isOutlined: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.file_upload,
                  label: 'Re-upload',
                  onPressed: _selectFrontFromGallery,
                  isOutlined: true,
                ),
              ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.photo_camera,
                  label: 'Take Photo',
                  onPressed: _captureFront,
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.upload,
                  label: 'Upload',
                  onPressed: _selectFrontFromGallery,
                  isOutlined: true,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBackSideSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Back Side',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: const Color(0xFF1E293B),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _backPath != null
                    ? null
                    : Colors.grey.shade200,
                gradient: _backPath != null
                    ? LinearGradient(
                        colors: [
                          const Color(0xFF22C55E), // green-500
                          const Color(0xFF16A34A), // green-600
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _backPath != null
                    ? [
                        BoxShadow(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_backPath != null)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 12,
                    ),
                  if (_backPath != null) const SizedBox(width: 4),
                  Text(
                    _backPath != null ? 'UPLOADED' : 'PENDING',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _backPath != null
                          ? Colors.white
                          : Colors.grey.shade600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_backPath != null)
          _buildImagePreview(context, _backPath!, isFront: false)
        else
          _buildEmptyUploadState(context, 'Click to capture back side'),
        const SizedBox(height: 12),
        if (_backPath != null) ...[
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.sync,
                  label: 'Retake',
                  onPressed: _captureBack,
                  isOutlined: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.file_upload,
                  label: 'Re-upload',
                  onPressed: _selectBackFromGallery,
                  isOutlined: true,
                ),
              ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.photo_camera,
                  label: 'Take Photo',
                  onPressed: _captureBack,
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.upload,
                  label: 'Upload',
                  onPressed: _selectBackFromGallery,
                  isOutlined: true,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildImagePreview(BuildContext context, String path, {required bool isFront}) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade100,
              Colors.grey.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              (path.startsWith('http') && (_authToken == null || (isFront ? _frontImageFailed : _backImageFailed)))
                  ? ((isFront ? _frontImageFailed : _backImageFailed)
                      ? const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 64))
                      : const Center(child: CircularProgressIndicator()))
                  : Transform.rotate(
                      angle: (isFront ? _frontRotation : _backRotation) * 3.14159 / 180,
                      child: PlatformImage(
                        imagePath: path,
                        imageBytes: isFront ? _frontBytes : _backBytes,
                        fit: BoxFit.cover,
                        headers: _authToken != null ? {'Authorization': 'Bearer $_authToken'} : null,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String label) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: const Center(
          child: Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildEmptyUploadState(BuildContext context, String text) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade50,
              Colors.grey.shade100,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 2,
            style: BorderStyle.solid,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.1),
                    AppTheme.primaryColor.withValues(alpha: 0.2),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.add_a_photo,
                color: AppTheme.primaryColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
    bool isOutlined = false,
  }) {
    final theme = Theme.of(context);

    if (isPrimary) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  const Color(0xFF0052CC), // royal-blue
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isOutlined
                ? LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.1),
                      AppTheme.primaryColor.withValues(alpha: 0.05),
                    ],
                  )
                : null,
            color: isOutlined ? null : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOutlined
                  ? AppTheme.primaryColor
                  : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: isOutlined
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isOutlined ? AppTheme.primaryColor : Colors.grey.shade600,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isOutlined ? AppTheme.primaryColor : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdfCardSection(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Aadhaar Card PDF',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: const Color(0xFF1E293B),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF22C55E), // green-500
                    const Color(0xFF16A34A), // green-600
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'UPLOADED',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // PDF Preview Card
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFEFF6FF), // blue-50
                  const Color(0xFFDBEAFE), // blue-100
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.picture_as_pdf,
                        size: 64,
                        color: AppTheme.primaryColor.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'PDF',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
                // Delete button
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: const Color(0xFFEF4444),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () {
                        _removePdf();
                      },
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Change PDF Button
        _buildActionButton(
          context,
          icon: Icons.file_upload,
          label: 'Change PDF',
          onPressed: _uploadPdf,
          isOutlined: true,
        ),
        const SizedBox(height: 12),
        // Switch to Photos Button
        _buildPhotosSwitchButton(context),
      ],
    );
  }

  Widget _buildPdfSwitchButton(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          // Clear both front and back images before switching to PDF
          _removeFrontImage();
          _removeBackImage();
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _uploadPdf();
            }
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFDC2626).withValues(alpha: 0.1), // red-600
                const Color(0xFFEF4444).withValues(alpha: 0.05), // red-500
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFDC2626).withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.picture_as_pdf,
                color: const Color(0xFFDC2626), // red-600
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Switch to PDF Upload',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFDC2626), // red-600
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotosSwitchButton(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          _switchToPhotos();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.1),
                AppTheme.primaryColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_camera,
                color: AppTheme.primaryColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Switch to Photos',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _switchToPhotos() {
    setState(() {
      // Clear PDF mode
      _frontPath = null;
      _backPath = null;
      _frontIsPdf = false;
      _backIsPdf = false;
      _frontPdfPassword = null;
      _backPdfPassword = null;
      _frontRotation = 0.0;
      _backRotation = 0.0;
      _frontAadhaarNumber = null;
      _backAadhaarNumber = null;
      _aadhaarName = null;
      _frontInternalValid = true;
      _backInternalValid = true;
    });
    // Clear from provider
    final provider = context.read<SubmissionProvider>();
    if (provider.submission.aadhaar != null) {
      provider.submission.aadhaar = null;
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Continue to PAN Card
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: _proceedToNext,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor,
                    const Color(0xFF0052CC), // royal-blue
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
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
                    'Continue to PAN Card',
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
      ],
    );
  }

}

