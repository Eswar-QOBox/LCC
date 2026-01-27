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

class Step3PanScreen extends StatefulWidget {
  const Step3PanScreen({super.key});

  @override
  State<Step3PanScreen> createState() => _Step3PanScreenState();
}

class _Step3PanScreenState extends State<Step3PanScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final FileUploadService _fileUploadService = FileUploadService();
  String? _frontPath;
  bool _isSaving = false;
  bool _isPdf = false;
  String? _pdfPassword;
  double _rotation = 0.0;
  String? _authToken;
  bool _imageFailed = false;
  Uint8List? _frontBytes;

  // OCR extracted PAN number
  String? _extractedPanNumber;
  String? _extractedName;
  
  // Aadhaar name loaded from previous step (for cross-validation)
  String? _aadhaarName;
  
  // Internal validation flag (secret - not shown to user)
  bool _internalDocumentValid = true;

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
    _frontPath = provider.submission.pan?.frontPath;
    
    // Check if it's a PDF based on provider extended info if available or file extension
    // SubmissionProvider helper needed or direct check 
     if (_frontPath != null && _frontPath!.toLowerCase().endsWith('.pdf')) {
       _isPdf = true;
    }
    
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
        return '${ApiConfig.baseUrl}$apiPath';
      }
      
      // Prefer uploaded file URL over local blob path
      final effectiveFront = buildFullUrl(uploadedFile?['url'] as String?) ?? frontPath;

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
          _isPdf = stepData['isPdf'] as bool? ?? false;
          _pdfPassword = stepData['pdfPassword'] as String?;
        });
        // Also update SubmissionProvider
        context.read<SubmissionProvider>().setPanFront(effectiveFront, isPdf: stepData['isPdf'] as bool? ?? false);

        // Fetch image if network URL and not PDF
        if (effectiveFront.startsWith('http') && accessToken != null && (!_isPdf)) {
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
                  _imageFailed = false;
                });
              } else {
                setState(() { _imageFailed = true; });
              }
            } else {
               if (mounted) setState(() { _imageFailed = true; });
            }
          } catch (e) {
            if (mounted) setState(() { _imageFailed = true; });
          }
        }
      }
    }
    
    // Load Aadhaar name from previous step for cross-validation
    if (application.step2Aadhaar != null) {
      final aadhaarData = application.step2Aadhaar as Map<String, dynamic>;
      final aadhaarName = aadhaarData['aadhaarName'] as String?;
      if (aadhaarName != null && aadhaarName.isNotEmpty) {
        _aadhaarName = aadhaarName;
        debugPrint('Loaded Aadhaar name for cross-validation: $_aadhaarName');
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
      Map<String, dynamic>? uploadResult;
      
      // Check if image/pdf is already uploaded (remote URL)
      if (_frontPath!.startsWith('http')) {
        // Reuse existing upload data
        final currentApp = appProvider.currentApplication;
        if (currentApp?.step3Pan != null) {
          final stepData = currentApp!.step3Pan as Map<String, dynamic>;
          uploadResult = stepData['uploadedFile'] as Map<String, dynamic>?;
        }
      } else {
        // Upload PAN file (image or PDF)
        final panFile = XFile(_frontPath!);
        uploadResult = await _fileUploadService.uploadPan(panFile, isPdf: _isPdf);
      }

      // Save step data to backend
      await appProvider.updateApplication(
        currentStep: 4, // Move to next step
        step3Pan: {
          'frontPath': _frontPath,
          'uploadedFile': uploadResult,
          'isPdf': _isPdf,
          'pdfPassword': _pdfPassword,
          'savedAt': DateTime.now().toIso8601String(),
          // OCR extracted data for verification
          'extractedPanNumber': _extractedPanNumber,
          'extractedName': _extractedName,
          'aadhaarNameUsedForValidation': _aadhaarName,
          // Internal validation flag (for admin review - not shown to user)
          '_internalValidation': {
            'documentValid': _internalDocumentValid,
            'namesMatch': _aadhaarName != null && _extractedName != null
                ? _areNamesSimilar(_aadhaarName!, _extractedName!)
                : null,
          },
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
      });
      context.read<SubmissionProvider>().setPanFront(image.path, isPdf: false);
      
      // Perform OCR on PAN card
      await _performPanOCR(image.path);
    }
  }

  Future<void> _selectFromGallery() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() {
        _frontPath = image.path;
        _isPdf = false;
        _rotation = 0.0;
      });
      context.read<SubmissionProvider>().setPanFront(image.path, isPdf: false);
      
      // Perform OCR on PAN card
      await _performPanOCR(image.path);
    }
  }

  /// Perform OCR on PAN card image and show extracted data
  Future<void> _performPanOCR(String imagePath) async {
    if (!mounted) return;

    try {
      // Show loading indicator
      if (mounted) {
        PremiumToast.showInfo(
          context,
          'Extracting text from PAN card...',
          duration: const Duration(seconds: 2),
        );
      }

      final result = await OcrService.extractPanText(imagePath);

      if (!mounted) return;

      if (result.success) {
        final extractedData = <String>[];
        final provider = context.read<SubmissionProvider>();
        
        // Store extracted data and internal validation flag
        _extractedPanNumber = result.panNumber;
        _extractedName = result.name;
        _internalDocumentValid = result.isInternallyValid;
        
        if (result.hasPanNumber) {
          extractedData.add('PAN: ${result.panNumber}');
          // Auto-fill PAN number to personal data
          provider.updatePersonalDataField(panNo: result.panNumber);
        }
        if (result.hasName) {
          extractedData.add('Name: ${result.name}');
          // Auto-fill name to personal data
          provider.updatePersonalDataField(fullName: result.name);
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
          _frontPath = path;
          _isPdf = true;
          _rotation = 0.0;
        });
        context.read<SubmissionProvider>().setPanFront(path, isPdf: true);
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

  /// Normalize name for comparison (remove extra spaces, convert to uppercase)
  String _normalizeName(String name) {
    return name.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
  
  /// Check if two names are similar enough (handles minor OCR variations)
  bool _areNamesSimilar(String name1, String name2) {
    final normalized1 = _normalizeName(name1);
    final normalized2 = _normalizeName(name2);
    
    // Exact match
    if (normalized1 == normalized2) return true;
    
    // Check if one contains the other (handles partial name extraction)
    if (normalized1.contains(normalized2) || normalized2.contains(normalized1)) return true;
    
    // Check word overlap (at least 2 common words should match)
    final words1 = normalized1.split(' ').where((w) => w.length > 1).toSet();
    final words2 = normalized2.split(' ').where((w) => w.length > 1).toSet();
    final commonWords = words1.intersection(words2);
    
    // At least 2 words should match for names to be considered similar
    return commonWords.length >= 2;
  }

  /// Show validation error dialog - user cannot proceed until fixed
  void _showValidationErrorDialog({
    required String title,
    required String message,
    required String instruction,
    required IconData icon,
    String? aadhaarName,
    String? panName,
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
            if (aadhaarName != null || panName != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (aadhaarName != null)
                      Row(
                        children: [
                          const Icon(Icons.badge, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Aadhaar: $aadhaarName',
                              textAlign: TextAlign.left,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    if (aadhaarName != null && panName != null) const SizedBox(height: 8),
                    if (panName != null)
                      Row(
                        children: [
                          const Icon(Icons.credit_card, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'PAN: $panName',
                              textAlign: TextAlign.left,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
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
    if (_frontPath == null) {
      _showValidationErrorDialog(
        title: 'Missing PAN Card',
        message: 'You need to upload your PAN card to continue with the application.',
        instruction: 'Please capture or upload a clear image of your PAN card.',
        icon: Icons.credit_card_off,
      );
      return;
    }
    
    // Strict validation: Check if Aadhaar name and PAN name match
    if (_aadhaarName != null && _extractedName != null) {
      if (!_areNamesSimilar(_aadhaarName!, _extractedName!)) {
        _showValidationErrorDialog(
          title: 'Name Mismatch Detected',
          message: 'The name on your Aadhaar card does not match the name on your PAN card. Both documents must belong to the same person.',
          instruction: 'Please ensure you are uploading YOUR documents. If the names are correct but spelled differently, please contact support.',
          icon: Icons.person_off,
          aadhaarName: _aadhaarName,
          panName: _extractedName,
        );
        return;
      }
    }
    
    if (!_isSaving) {
      await _saveToBackend();
    }
    if (mounted) {
      context.go(AppRoutes.step4BankStatement);
    }
  }

  void _removeImage() {
    setState(() {
      _frontPath = null;
      _isPdf = false;
      _rotation = 0.0;
      _pdfPassword = null;
      _extractedPanNumber = null;
      _extractedName = null;
      _internalDocumentValid = true;
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
      _extractedPanNumber = null;
      _extractedName = null;
      _internalDocumentValid = true;
    });
    final provider = context.read<SubmissionProvider>();
    if (provider.submission.pan != null) {
      provider.submission.pan!.frontPath = null;
      if (provider.submission.pan!.frontPath == null) {
        provider.submission.pan = null;
      }
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
              title: 'PAN Card',
              icon: Icons.credit_card,
              showBackButton: true,
              onBackPressed: () => context.go(AppRoutes.step2Aadhaar),
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
                    
                    // Show PDF card if PDF mode, otherwise show photo section
                    if (_isPdf && _frontPath != null)
                      _buildPdfCardSection(context)
                    else ...[
                      // Front Side Section
                      _buildFrontSideSection(context),
                      
                      // Single Switch to PDF Button (only show if not in PDF mode)
                      const SizedBox(height: 24),
                      _buildPdfSwitchButton(context),
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
          // Steps 1-2: Completed
          for (int i = 1; i <= 2; i++) ...[
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
          ],
          // Step 3: Current
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
                      '3',
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
          // Steps 4-7: Pending
          for (int i = 4; i <= 7; i++) ...[
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
        color: const Color(0xFFEFF6FF), // blue-50
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFDBEAFE), // blue-100
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
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
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.badge,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PAN Card Requirements',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF1E293B), // slate-800
                  ),
                ),
                const SizedBox(height: 12),
                _buildRequirementItem(Icons.visibility, 'Must be clear and readable'),
                const SizedBox(height: 8),
                _buildRequirementItem(Icons.image, 'Front side only (PAN has only front)'),
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
        Icon(icon, color: AppTheme.primaryColor, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 14,
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _frontPath != null
                    ? const Color(0xFFF0FDF4) // green-50
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _frontPath != null ? 'UPLOADED' : 'PENDING',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _frontPath != null
                      ? const Color(0xFF22C55E) // green-500
                      : Colors.grey.shade400,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_frontPath != null)
          _buildImagePreview(context)
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
                  onPressed: _captureFromCamera,
                  isOutlined: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.file_upload,
                  label: 'Re-upload',
                  onPressed: _selectFromGallery,
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
                  onPressed: _captureFromCamera,
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.upload,
                  label: 'Upload',
                  onPressed: _selectFromGallery,
                  isOutlined: true,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildImagePreview(BuildContext context) {
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
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
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'PDF',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ((_frontPath!.startsWith('http') && (_authToken == null || _imageFailed))
                      ? Center(
                          child: _imageFailed
                              ? const Icon(Icons.broken_image, color: Colors.grey, size: 64)
                              : const CircularProgressIndicator())
                      : Transform.rotate(
                          angle: _rotation * 3.14159 / 180,
                          child: PlatformImage(
                            imagePath: _frontPath!,
                            imageBytes: _frontBytes,
                            fit: BoxFit.cover,
                            headers: _authToken != null ? {'Authorization': 'Bearer $_authToken'} : null,
                          ),
                        )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyUploadState(BuildContext context, String text) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_a_photo,
                color: Colors.grey,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade400,
                fontSize: 14,
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
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOutlined
                  ? AppTheme.primaryColor.withValues(alpha: 0.2)
                  : Colors.grey.shade200,
              width: 2,
            ),
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
              'PAN Card PDF',
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
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          if (_frontPath != null) {
            _removeImage();
          }
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
      _isPdf = false;
      _pdfPassword = null;
      _rotation = 0.0;
      _extractedPanNumber = null;
      _extractedName = null;
      _internalDocumentValid = true;
    });
    // Clear from provider
    final provider = context.read<SubmissionProvider>();
    if (provider.submission.pan != null) {
      provider.submission.pan = null;
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Continue to Bank Statement
        Material(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: _proceedToNext,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue to Bank Statement',
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

