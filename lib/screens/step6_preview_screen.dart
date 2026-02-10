import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/storage_service.dart';
import '../models/document_submission.dart';
import '../providers/application_provider.dart';
import '../providers/submission_provider.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/platform_image.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_toast.dart';
import '../widgets/slide_to_confirm.dart';
import '../utils/api_config.dart';
import '../widgets/premium_progress_indicator.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SubmissionProvider()),
        ChangeNotifierProvider(create: (_) => ApplicationProvider()),
      ],
      child: MaterialApp(home: Step6PreviewScreen()),
    ),
  );
}

class Step6PreviewScreen extends StatefulWidget {
  const Step6PreviewScreen({
    super.key,
    this.mode,
    this.backRouteOverride,
  });

  /// When 'viewSubmitted', sync runs then redirects to ViewSubmittedScreen.
  final String? mode;
  
  /// When provided, Preview's Back button returns to this route.
  /// Falls back to `AppRoutes.step5PersonalData` when null/empty.
  final String? backRouteOverride;

  @override
  State<Step6PreviewScreen> createState() => _Step6PreviewScreenState();
}

class _Step6PreviewScreenState extends State<Step6PreviewScreen> {
  String? _authToken;
  bool _isLoadingAuth = true;
  
  // Change tracking for dynamic button (Submit vs Close)
  bool _hasChanges = false;
  Map<String, dynamic>? _initialApplicationSnapshot;

  void _openImagePreview(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: PlatformImage(
                        imagePath: imagePath,
                        fit: BoxFit.contain,
                        headers: _authToken != null
                            ? {'Authorization': 'Bearer $_authToken'}
                            : null,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: AppTheme.errorColor,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Load existing data from backend when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingData();
      _captureInitialState();
    });
  }
  
  /// Capture initial application state to detect changes later
  void _captureInitialState() {
    final appProvider = context.read<ApplicationProvider>();
    if (appProvider.hasApplication) {
      final app = appProvider.currentApplication!;
      _initialApplicationSnapshot = {
        'step1Selfie': app.step1Selfie,
        'step2Aadhaar': app.step2Aadhaar,
        'step3Pan': app.step3Pan,
        'step4BankStatement': app.step4BankStatement,
        'step5PersonalData': app.step5PersonalData,
      };
      if (kDebugMode) {
        print('📸 Captured initial application snapshot');
      }
    }
  }
  
  /// Check if current application state differs from initial snapshot
  void _checkForChanges() {
    if (_initialApplicationSnapshot == null) {
      setState(() => _hasChanges = false);
      return;
    }
    
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication) {
      setState(() => _hasChanges = false);
      return;
    }
    
    final app = appProvider.currentApplication!;
    final hasChanges = 
      app.step1Selfie.toString() != _initialApplicationSnapshot!['step1Selfie'].toString() ||
      app.step2Aadhaar.toString() != _initialApplicationSnapshot!['step2Aadhaar'].toString() ||
      app.step3Pan.toString() != _initialApplicationSnapshot!['step3Pan'].toString() ||
      app.step4BankStatement.toString() != _initialApplicationSnapshot!['step4BankStatement'].toString() ||
      app.step5PersonalData.toString() != _initialApplicationSnapshot!['step5PersonalData'].toString();
    
    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
      if (kDebugMode) {
        print('🔄 Changes detected: $_hasChanges');
      }
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for changes when user returns from an edit screen
    _checkForChanges();
  }


  /// Load existing data from ApplicationProvider (backend) and sync to SubmissionProvider (local state)
  /// This ensures data persists across page refreshes on web
  Future<void> _loadExistingData() async {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication) {
      if (widget.mode == 'viewSubmitted' && mounted) {
        context.go(AppRoutes.viewSubmitted);
      }
      return;
    }

    // Refresh application data from backend to get the latest saved data
    try {
      await appProvider.refreshApplication();
    } catch (e) {
      debugPrint('Preview Screen: Failed to refresh application: $e');
    }

    // Get access token for authenticated request
    try {
      final storage = StorageService.instance;
      final accessToken = await storage.getAccessToken();
      if (mounted) {
        setState(() {
          _authToken = accessToken;
          _isLoadingAuth = false;
        });
      }
    } catch (e) {
      debugPrint('Preview Screen: Failed to get access token: $e');
      if (mounted) {
        setState(() {
          _isLoadingAuth = false;
        });
      }
    }

    final application = appProvider.currentApplication!;
    final submissionProvider = context.read<SubmissionProvider>();

    // Ensure local draft knows the current loan type (used for completeness rules).
    submissionProvider.setLoanType(application.loanType);


    // Helper function to build full URL from relative path
    // Transform /uploads/{category}/ to /api/v1/uploads/files/{category}/
    String? buildFullUrl(String? relativePath) {
      if (relativePath == null || relativePath.isEmpty) return null;
      
      String path = relativePath;
      
      // Fix for "baseUrl" prefix if present
      if (path.startsWith('baseUrl')) {
         path = path.replaceFirst('baseUrl', ApiConfig.baseUrl);
      }
      
      // Fix for localhost URLs
      if (path.startsWith('http://localhost:5000')) {
         path = path.replaceFirst('http://localhost:5000', ApiConfig.baseUrl);
      }

      // If it's already a full URL or blob URL, return as-is
      if (path.startsWith('http') || path.startsWith('blob:')) {
        return path;
      }
      
      // Normalize paths that come without a leading slash (e.g. "uploads/...", "api/...")
      if (path.startsWith('uploads/') || path.startsWith('api/')) {
        path = '/$path';
      }
      if (!path.startsWith('/')) {
        path = '/$path';
      }

      // Some backends return file URLs like /api/v1/uploads/<category>/<file>
      // but the actual file-serving route is /api/v1/uploads/files/<category>/<file>.
      // Normalize that here so previews work (notably Salary Slips).
      if (path.startsWith('/api/v1/uploads/') &&
          !path.startsWith('/api/v1/uploads/files/')) {
        path = path.replaceFirst('/api/v1/uploads/', '/api/v1/uploads/files/');
      }

      // Convert /uploads/selfies/... to /api/v1/uploads/files/selfies/...
      String apiPath = path;
      if (apiPath.startsWith('/uploads/') &&
          !apiPath.contains('/uploads/files/')) {
        apiPath = apiPath.replaceFirst('/uploads/', '/api/v1/uploads/files/');
      } else if (!apiPath.startsWith('/api/')) {
        // Ensure we don't end up with "/api/v1uploads/..." (missing slash)
        apiPath = apiPath.startsWith('/') ? '/api/v1$apiPath' : '/api/v1/$apiPath';
      }
      return '${ApiConfig.baseUrl}$apiPath';
    }

    // Sync selfie data
    if (application.step1Selfie != null) {
      try {
        if (application.step1Selfie is Map<String, dynamic>) {
          final stepData = application.step1Selfie as Map<String, dynamic>;
          final imagePath = stepData['imagePath'] as String?;
          final uploadedFile = stepData['uploadedFile'] as Map<String, dynamic>?;
          // Prefer uploaded file URL over local path (local paths don't survive refresh on web)
          final relativeUrl = uploadedFile?['url'] as String?;
          final effectivePath = buildFullUrl(relativeUrl) ?? buildFullUrl(imagePath);
          if (effectivePath != null && effectivePath.isNotEmpty) {
            submissionProvider.setSelfie(effectivePath);
          }
        } else if (application.step1Selfie is String) {
          final s = application.step1Selfie as String;
          final effectivePath = buildFullUrl(s) ?? s;
          if (effectivePath.isNotEmpty) {
            submissionProvider.setSelfie(effectivePath);
          }
        }
      } catch (e) {
        debugPrint('Preview Screen: Failed to parse selfie: $e');
      }
    }

    // Sync Aadhaar data
    if (application.step2Aadhaar != null) {
      final stepData = application.step2Aadhaar as Map<String, dynamic>;
      final frontPath = stepData['frontPath'] as String?;
      final backPath = stepData['backPath'] as String?;
      final frontUpload = stepData['frontUpload'] as Map<String, dynamic>?;
      final backUpload = stepData['backUpload'] as Map<String, dynamic>?;
      final frontIsPdf = stepData['frontIsPdf'] as bool? ?? false;
      final backIsPdf = stepData['backIsPdf'] as bool? ?? false;
      
      // Prefer uploaded file URLs
      final effectiveFront =
          buildFullUrl(frontUpload?['url'] as String?) ?? buildFullUrl(frontPath);
      final effectiveBack =
          buildFullUrl(backUpload?['url'] as String?) ?? buildFullUrl(backPath);
      if (effectiveFront != null && effectiveFront.isNotEmpty) {
        submissionProvider.setAadhaarFront(effectiveFront, isPdf: frontIsPdf);
      }
      if (effectiveBack != null && effectiveBack.isNotEmpty) {
        submissionProvider.setAadhaarBack(effectiveBack, isPdf: backIsPdf);
      }
    }



    // Robust URL normalization helper for de-duplication
    String normalizeForDedup(String url) {
      if (url.isEmpty) return url;
      try {
        final uri = Uri.parse(url);
        // Return only the filename, ensuring we identify the same file regardless of path prefix
        // e.g. /api/v1/uploads/file.pdf and /uploads/file.pdf become file.pdf
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : url;
      } catch (e) {
        // Fallback: split by slash
        if (url.contains('/')) {
          return url.split('/').last;
        }
        return url;
      }
    }

    // Sync PAN data
    if (application.step3Pan != null) {
      final stepData = application.step3Pan as Map<String, dynamic>;
      final frontPath = stepData['frontPath'] as String?;
      final isPdf = stepData['isPdf'] as bool? ?? false;
      // PAN uses 'uploadedFile' not 'frontUpload'
      final uploadedFile = stepData['uploadedFile'] as Map<String, dynamic>?;
      final effectiveFront =
          buildFullUrl(uploadedFile?['url'] as String?) ?? buildFullUrl(frontPath);
      if (effectiveFront != null && effectiveFront.isNotEmpty) {
        submissionProvider.setPanFront(effectiveFront, isPdf: isPdf);
      }
    }

    // Sync Bank Statement and Salary Slips data (both are in step4BankStatement)
    if (application.step4BankStatement != null) {
      final stepData = application.step4BankStatement as Map<String, dynamic>;

      // Bank Statement pages
      final pages = (stepData['pages'] as List<dynamic>?)?.cast<String>() ?? [];
      final isPdf = stepData['isPdf'] as bool? ?? false;
      final uploadedPages = (stepData['uploadedFiles'] ?? stepData['uploadedPages']) as List<dynamic>?;
      List<String> effectivePages = [];
      if (uploadedPages != null && uploadedPages.isNotEmpty) {
        for (var upload in uploadedPages) {
          if (upload is Map<String, dynamic>) {
            final url = buildFullUrl(upload['url'] as String?);
            if (url != null && url.isNotEmpty) {
              effectivePages.add(url);
            }
          }
        }
      }
      if (effectivePages.isEmpty && pages.isNotEmpty) {
        effectivePages = pages.map((p) => buildFullUrl(p) ?? p).toList();
      }
      if (effectivePages.isNotEmpty) {
        // Robust De-duplication: Keep first occurrence of each unique normalized path
        final uniquePages = <String>[];
        final seenPaths = <String>{};
        
        for (final page in effectivePages) {
          final normalized = normalizeForDedup(page);
          if (!seenPaths.contains(normalized)) {
            seenPaths.add(normalized);
            uniquePages.add(page);
          }
        }
        
        if (kDebugMode) {
          print('Preview: De-duplicated Bank Pages: ${effectivePages.length} -> ${uniquePages.length}');
        }
        submissionProvider.setBankStatementPages(uniquePages, isPdf: isPdf);
      }
      final password = stepData['pdfPassword'] as String?;
      if (password != null && password.isNotEmpty) {
        submissionProvider.setBankStatementPassword(password);
      }

      // Salary slips are also stored in step4BankStatement
      final salarySlips =
          (stepData['salarySlips'] as List<dynamic>?)?.cast<String>() ?? [];
      final salaryIsPdf = stepData['salarySlipsIsPdf'] as bool? ?? false;
      final uploadedSalarySlips =
          stepData['salarySlipsUploaded'] as List<dynamic>?;
      List<String> effectiveSalarySlips = [];
      if (uploadedSalarySlips != null && uploadedSalarySlips.isNotEmpty) {
        for (var upload in uploadedSalarySlips) {
          if (upload is Map<String, dynamic>) {
            final raw = (upload['url'] as String?) ?? (upload['path'] as String?);
            final url = buildFullUrl(raw);
            if (url != null && url.isNotEmpty) {
              effectiveSalarySlips.add(url);
            }
          }
        }
      }
      if (effectiveSalarySlips.isEmpty && salarySlips.isNotEmpty) {
        effectiveSalarySlips = salarySlips.map((p) => buildFullUrl(p) ?? p).toList();
      }
      if (effectiveSalarySlips.isNotEmpty) {
        // Robust De-duplication salary slips
        final uniqueSlips = <String>[];
        final seenPaths = <String>{};
        
        for (final slip in effectiveSalarySlips) {
          final normalized = normalizeForDedup(slip);
          if (!seenPaths.contains(normalized)) {
            seenPaths.add(normalized);
            uniqueSlips.add(slip);
          }
        }
        
        if (kDebugMode) {
          print('Preview: De-duplicated Salary Slips: ${effectiveSalarySlips.length} -> ${uniqueSlips.length}');
        }

        // Preserve per-item PDF state (avoid marking all slips as PDF).
        submissionProvider.setSalarySlips(
          uniqueSlips,
          isPdf: salaryIsPdf,
        );
      }
      final salaryPassword = stepData['salarySlipsPassword'] as String?;
      if (salaryPassword != null && salaryPassword.isNotEmpty) {
        submissionProvider.setSalarySlipsPassword(salaryPassword);
      }
    }

    // Sync Personal Data
    if (application.step5PersonalData != null) {
      final stepData = application.step5PersonalData as Map<String, dynamic>;
      final personalData = PersonalData(
        nameAsPerAadhaar: stepData['nameAsPerAadhaar'] as String?,
        dateOfBirth: stepData['dateOfBirth'] != null
            ? DateTime.tryParse(stepData['dateOfBirth'] as String)
            : null,
        panNo: stepData['panNo'] as String?,
        aadhaarNumber: stepData['aadhaarNumber'] as String?,
        mobileNumber: stepData['mobileNumber'] as String?,
        personalEmailId: stepData['personalEmailId'] as String?,
        countryOfResidence: stepData['countryOfResidence'] as String?,
        residenceAddress: stepData['residenceAddress'] as String?,
        residenceType: stepData['residenceType'] as String?,
        residenceStability: stepData['residenceStability'] as String?,
        companyName: stepData['companyName'] as String?,
        companyAddress: stepData['companyAddress'] as String?,
        nationality: stepData['nationality'] as String?,
        countryOfBirth: stepData['countryOfBirth'] as String?,
        occupation: stepData['occupation'] as String?,
        educationalQualification:
            stepData['educationalQualification'] as String?,
        workType: stepData['workType'] as String?,
        industry: stepData['industry'] as String?,
        annualIncome: stepData['annualIncome'] as String?,
        totalWorkExperience: stepData['totalWorkExperience'] as String?,
        currentCompanyExperience:
            stepData['currentCompanyExperience'] as String?,
        loanAmount: stepData['loanAmount'] as String?,
        loanTenure: stepData['loanTenure'] as String?,
        loanAmountTenure: stepData['loanAmountTenure'] as String?,
        maritalStatus: stepData['maritalStatus'] as String?,
        spouseName: stepData['spouseName'] as String?,
        fatherName: stepData['fatherName'] as String?,
        motherName: stepData['motherName'] as String?,
        reference1Name: stepData['reference1Name'] as String?,
        reference1Address: stepData['reference1Address'] as String?,
        reference1Contact: stepData['reference1Contact'] as String?,
        reference2Name: stepData['reference2Name'] as String?,
        reference2Address: stepData['reference2Address'] as String?,
        reference2Contact: stepData['reference2Contact'] as String?,
      );
      submissionProvider.setPersonalData(personalData);
    }

    if (kDebugMode) {
      print('📥 Preview Screen: Loaded existing data from ApplicationProvider');
    }

    // When opened for "View Submitted", redirect to the dedicated screen after sync
    if (widget.mode == 'viewSubmitted' && mounted) {
      context.go(AppRoutes.viewSubmitted);
    }
  }

  void _editStep(BuildContext context, String route) {
    // When editing Aadhaar from Preview, pass ?from=preview so Back returns to Preview
    final target = route == AppRoutes.step2Aadhaar
        ? '${AppRoutes.step2Aadhaar}?from=preview'
        : route;
    context.go(target);
  }

  /// Build full URL from relative path (same logic as _loadExistingData)
  String? _buildFullUrlForSelfie(String? path) {
    if (path == null || path.isEmpty) return null;
    String p = path;
    if (p.startsWith('baseUrl')) {
      p = p.replaceFirst('baseUrl', ApiConfig.baseUrl);
    }
    if (p.startsWith('http://localhost:5000')) {
      p = p.replaceFirst('http://localhost:5000', ApiConfig.baseUrl);
    }
    if (p.startsWith('http') || p.startsWith('blob:')) return p;

    // Normalize missing leading slash variants.
    if (p.startsWith('uploads/') || p.startsWith('api/')) {
      p = '/$p';
    }
    if (!p.startsWith('/')) {
      p = '/$p';
    }

    // Normalize /api/v1/uploads/<category>/... -> /api/v1/uploads/files/<category>/...
    if (p.startsWith('/api/v1/uploads/') && !p.startsWith('/api/v1/uploads/files/')) {
      p = p.replaceFirst('/api/v1/uploads/', '/api/v1/uploads/files/');
    }

    if (p.startsWith('/uploads/') && !p.contains('/uploads/files/')) {
      p = p.replaceFirst('/uploads/', '/api/v1/uploads/files/');
    } else if (!p.startsWith('/api/')) {
      p = p.startsWith('/') ? '/api/v1$p' : '/api/v1/$p';
    }
    return '${ApiConfig.baseUrl}$p';
  }

  /// Get selfie path from either SubmissionProvider (local) or ApplicationProvider (backend)
  String? _getSelfiePath(BuildContext context) {
    // Prefer local submission state if available
    final submissionProvider = context.read<SubmissionProvider>();
    final localSelfiePath = submissionProvider.submission.selfiePath;
    if (localSelfiePath != null && localSelfiePath.isNotEmpty) {
      return localSelfiePath;
    }

    // Fallback to application-backed selfie data (use same effectivePath logic as _loadExistingData)
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication) return null;

    final application = appProvider.currentApplication!;
    if (kDebugMode) {
      print(
        '_getSelfiePath: step1Selfie type: ${application.step1Selfie?.runtimeType}',
      );
      print('_getSelfiePath: step1Selfie value: ${application.step1Selfie}');
    }

    if (application.step1Selfie != null) {
      try {
        if (application.step1Selfie is Map<String, dynamic>) {
          final stepData = application.step1Selfie as Map<String, dynamic>;
          final imagePath = stepData['imagePath'] as String?;
          final uploadedFile = stepData['uploadedFile'] as Map<String, dynamic>?;
          final relativeUrl = uploadedFile?['url'] as String?;
          final effectivePath = _buildFullUrlForSelfie(relativeUrl) ?? _buildFullUrlForSelfie(imagePath);
          if (kDebugMode && effectivePath != null) {
            print('_getSelfiePath: effectivePath = $effectivePath');
          }
          return effectivePath;
        } else if (application.step1Selfie is String) {
          return _buildFullUrlForSelfie(application.step1Selfie as String) ?? application.step1Selfie as String;
        }
      } catch (e) {
        if (kDebugMode) {
          print('_getSelfiePath: Error parsing step1Selfie: $e');
        }
      }
    }
    return null;
  }


  Future<void> _submit(BuildContext context) async {
    final provider = context.read<SubmissionProvider>();
    final appProvider = context.read<ApplicationProvider>();

    if (!appProvider.hasApplication) {
      PremiumToast.showError(
        context,
        'No application found. Please start a new application.',
      );
      return;
    }

    if (!provider.submission.isComplete) {
      if (context.mounted) {
        PremiumToast.showError(
          context,
          'Please complete all steps before submitting',
        );
      }
      return;
    }

    // Show loading indicator
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      // Save preview data and submit to backend
      await appProvider.updateApplication(
        currentStep: 7,
        status: 'submitted',
        step6Preview: {
          'submittedAt': DateTime.now().toIso8601String(),
          'allStepsComplete': true,
        },
        step7Submission: {
          'submittedAt': DateTime.now().toIso8601String(),
          'status': 'submitted',
        },
      );

      // Also save to provider for local state
      await provider.submit();

      // Clear draft after successful submission
      await provider.clearDraft();

      if (context.mounted) {
        // Close loading dialog
        Navigator.of(context).pop();
        PremiumToast.showSuccess(
          context,
          'Application submitted successfully!',
        );
        // Navigate to success screen
        context.go(AppRoutes.submissionSuccess);
      }
    } catch (e) {
      if (context.mounted) {
        // Close loading dialog if still open
        Navigator.of(context).pop();
        PremiumToast.showError(context, 'Error submitting: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == 'viewSubmitted') {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: const Color(0xFF002366)),
        ),
      );
    }
    final provider = context.watch<SubmissionProvider>();
    final appProvider = context.watch<ApplicationProvider>();
    final submission = provider.submission;
    // Check submission status from backend application data
    final isSubmitted = appProvider.currentApplication?.isSubmitted ?? false;
    final isBusinessLoan =
        (appProvider.currentApplication?.loanType ?? '').toLowerCase().contains('business');
    final businessLoanType = (submission.businessLoanType ?? '').toLowerCase();
    final isBusinessProprietor = isBusinessLoan && businessLoanType == 'proprietor';
    final isBusinessPartnership = isBusinessLoan && businessLoanType == 'partnership';
    final isBusinessPvtLimited = isBusinessLoan && businessLoanType == 'pvt_limited';
    final partnerCount = submission.businessDocuments?.partnerCount ?? 0;
    final isPartnerFlow = isBusinessPartnership || isBusinessPvtLimited;
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selfiePath = _getSelfiePath(context);

    // Debug: Print comprehensive submission state
    if (kDebugMode) {
      print('═══════════════════════════════════════════════════════════');
      print('📋 PREVIEW SCREEN - SUBMISSION STATE');
      print('═══════════════════════════════════════════════════════════');
      final selfiePath = _getSelfiePath(context);
      print('✅ Selfie: ${selfiePath != null ? "✓ $selfiePath" : "✗ Missing"}');
      print(
        '✅ Aadhaar: ${submission.aadhaar != null ? "✓ Front: ${submission.aadhaar!.frontPath}, Back: ${submission.aadhaar!.backPath}" : "✗ Missing"}',
      );
      print(
        '✅ PAN: ${submission.pan != null ? "✓ ${submission.pan!.frontPath}" : "✗ Missing"}',
      );
      print(
        '✅ Bank Statement: ${submission.bankStatement != null ? "✓ Pages: ${submission.bankStatement!.pages.length}" : "✗ Missing"}',
      );
      print(
        '✅ Personal Data: ${submission.personalData != null ? "✓ Present" : "✗ Missing"}',
      );
      print('✅ Is Complete: ${submission.isComplete}');
      print('═══════════════════════════════════════════════════════════');

      if (submission.personalData != null) {
        final data = submission.personalData!;
        print('📝 PERSONAL DATA DETAILS:');
        print(
          '   Name: "${data.nameAsPerAadhaar ?? "null"}" (empty: ${data.nameAsPerAadhaar?.isEmpty ?? true})',
        );
        print('   DOB: ${data.dateOfBirth ?? "null"}');
        print(
          '   PAN: "${data.panNo ?? "null"}" (empty: ${data.panNo?.isEmpty ?? true})',
        );
        print(
          '   Mobile: "${data.mobileNumber ?? "null"}" (empty: ${data.mobileNumber?.isEmpty ?? true})',
        );
        print(
          '   Email: "${data.personalEmailId ?? "null"}" (empty: ${data.personalEmailId?.isEmpty ?? true})',
        );
        print(
          '   Address: "${data.residenceAddress ?? "null"}" (empty: ${data.residenceAddress?.isEmpty ?? true})',
        );
        print('   Is Complete: ${data.isComplete}');
        if (!data.isComplete) {
          final missingFields = data.getMissingFields();
          print('   Missing Fields: ${missingFields.join(", ")}');
        }
        print('═══════════════════════════════════════════════════════════');
      } else {
        print('❌ PERSONAL DATA: Not filled at all');
      }
    }

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
            AppHeader(
              title: 'Review & Submit',
              icon: Icons.check_circle_outline,
              showBackButton: true,
              onBackPressed: () {
                final back = (widget.backRouteOverride ?? '').trim();
                final safeBack =
                    (back.isNotEmpty && back.startsWith('/')) ? back : AppRoutes.step5PersonalData;
                context.go(safeBack);
              },
              showHomeButton: true,
            ),
            Builder(
              builder: (context) {
                final appProvider = context.read<ApplicationProvider>();
                final submissionProvider = context.read<SubmissionProvider>();
                final loanType = (appProvider.currentApplication?.loanType ??
                        submissionProvider.submission.loanType ??
                        '')
                    .toLowerCase();
                final businessLoanType =
                    (submissionProvider.submission.businessLoanType ?? '').toLowerCase();
                final isBusinessProprietor =
                    loanType.contains('business') && businessLoanType == 'proprietor';
                final isBusinessPartnership =
                    loanType.contains('business') && businessLoanType == 'partnership';
                final isBusinessPvtLimited =
                    loanType.contains('business') && businessLoanType == 'pvt_limited';
                final partnerCount =
                    submissionProvider.submission.businessDocuments?.partnerCount ?? 0;
                final isPartnerFlow = isBusinessPartnership || isBusinessPvtLimited;

                return _buildProgressIndicator(
                  context,
                  currentStep: isBusinessProprietor
                      ? 10
                      : (isPartnerFlow && partnerCount > 0
                          ? (10 + 2 * partnerCount)
                          : 7),
                  totalSteps: isBusinessProprietor
                      ? 10
                      : (isPartnerFlow && partnerCount > 0
                          ? (10 + 2 * partnerCount)
                          : 7),
                );
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status Banner
                    PremiumCard(
                      gradientColors: submission.isComplete
                          ? [
                              AppTheme.successColor.withValues(alpha: 0.15),
                              AppTheme.successColor.withValues(alpha: 0.05),
                            ]
                          : [
                              AppTheme.warningColor.withValues(alpha: 0.15),
                              AppTheme.warningColor.withValues(alpha: 0.05),
                            ],
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: submission.isComplete
                                  ? AppTheme.successColor
                                  : AppTheme.warningColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (submission.isComplete
                                              ? AppTheme.successColor
                                              : AppTheme.warningColor)
                                          .withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              submission.isComplete
                                  ? Icons.check_circle
                                  : Icons.warning_rounded,
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
                                  submission.isComplete
                                      ? 'Ready to Submit!'
                                      : 'Incomplete Submission',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: submission.isComplete
                                        ? AppTheme.successColor
                                        : AppTheme.warningColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  submission.isComplete
                                      ? 'All documents are verified and ready'
                                      : 'Please complete all steps before submitting',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Summary Section
                    PremiumCard(
                      gradientColors: [
                        colorScheme.primary.withValues(alpha: 0.08),
                        colorScheme.secondary.withValues(alpha: 0.04),
                      ],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primary,
                                      colorScheme.secondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.summarize,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Review All Information',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildSummaryRow(
                            context,
                            'Step 1: Selfie',
                            selfiePath != null ? '✓ Uploaded' : '✗ Missing',
                            selfiePath != null,
                          ),
                          _buildSummaryRow(
                            context,
                            'Step 2: Aadhaar Card',
                            submission.aadhaar?.isComplete == true
                                ? '✓ Uploaded'
                                : '✗ Missing',
                            submission.aadhaar?.isComplete == true,
                          ),
                          _buildSummaryRow(
                            context,
                            'Step 3: PAN Card',
                            submission.pan?.isComplete == true
                                ? '✓ Uploaded'
                                : '✗ Missing',
                            submission.pan?.isComplete == true,
                          ),
                          _buildSummaryRow(
                            context,
                            'Step 4: Bank Statement',
                            submission.bankStatement?.isComplete == true
                                ? '✓ Uploaded'
                                : '✗ Missing',
                            submission.bankStatement?.isComplete == true,
                          ),
                          if (isBusinessProprietor) ...[
                            _buildSummaryRow(
                              context,
                              'Step 5: Spouse Aadhaar',
                              submission.businessDocuments?.spouseAadhaar?.isComplete == true
                                  ? '✓ Uploaded'
                                  : '✗ Missing',
                              submission.businessDocuments?.spouseAadhaar?.isComplete == true,
                            ),
                            _buildSummaryRow(
                              context,
                              'Step 6: Spouse PAN',
                              submission.businessDocuments?.spousePan?.isComplete == true
                                  ? '✓ Uploaded'
                                  : '✗ Missing',
                              submission.businessDocuments?.spousePan?.isComplete == true,
                            ),
                            _buildSummaryRow(
                              context,
                              'Step 7: GST / Labour',
                              (submission.businessDocuments?.hasGstOrLabour ?? false)
                                  ? '✓ Uploaded'
                                  : '✗ Missing',
                              (submission.businessDocuments?.hasGstOrLabour ?? false),
                            ),
                            _buildSummaryRow(
                              context,
                              'Step 8: MSME',
                              submission.businessDocuments?.msmeCertificate?.isComplete == true
                                  ? '✓ Uploaded'
                                  : '✗ Missing',
                              submission.businessDocuments?.msmeCertificate?.isComplete == true,
                            ),
                            _buildSummaryRow(
                              context,
                              'Step 9: Own House Proof',
                              submission.businessDocuments?.ownHouseProof?.isComplete == true
                                  ? '✓ Uploaded'
                                  : '✗ Missing',
                              submission.businessDocuments?.ownHouseProof?.isComplete == true,
                            ),
                            _buildSummaryRow(
                              context,
                              'Step 10: Personal Data',
                              submission.personalData?.isComplete == true
                                  ? '✓ Completed'
                                  : '✗ Missing',
                              submission.personalData?.isComplete == true,
                            ),
                          ] else if (isPartnerFlow) ...[
                            _buildSummaryRow(
                              context,
                              'Step 5: Partners KYC',
                              (submission.businessDocuments?.isPartnerKycComplete ?? false)
                                  ? '✓ Completed'
                                  : '✗ Missing',
                              (submission.businessDocuments?.isPartnerKycComplete ?? false),
                            ),
                            _buildSummaryRow(
                              context,
                              'Step ${6 + 2 * partnerCount}: Company PAN Card',
                              submission.businessDocuments?.companyPanCard?.isComplete == true
                                  ? '✓ Uploaded'
                                  : '✗ Missing',
                              submission.businessDocuments?.companyPanCard?.isComplete == true,
                            ),
                            if (isBusinessPvtLimited) ...[
                              _buildSummaryRow(
                                context,
                                'Step ${6 + 2 * partnerCount}: MOA',
                                submission.businessDocuments?.moa?.isComplete == true
                                    ? '✓ Uploaded'
                                    : '✗ Missing',
                                submission.businessDocuments?.moa?.isComplete == true,
                              ),
                              _buildSummaryRow(
                                context,
                                'Step ${6 + 2 * partnerCount}: AOA',
                                submission.businessDocuments?.aoa?.isComplete == true
                                    ? '✓ Uploaded'
                                    : '✗ Missing',
                                submission.businessDocuments?.aoa?.isComplete == true,
                              ),
                            ] else
                              _buildSummaryRow(
                                context,
                                'Step ${6 + 2 * partnerCount}: Partnership Deed',
                                submission.businessDocuments?.partnershipDeed?.isComplete == true
                                    ? '✓ Uploaded'
                                    : '✗ Missing',
                                submission.businessDocuments?.partnershipDeed?.isComplete == true,
                              ),
                            _buildSummaryRow(
                              context,
                              'Step ${6 + 2 * partnerCount}: GST / Labour',
                              (submission.businessDocuments?.hasGstOrLabour ?? false)
                                  ? '✓ Uploaded'
                                  : '✗ Missing',
                              (submission.businessDocuments?.hasGstOrLabour ?? false),
                            ),
                            _buildSummaryRow(
                              context,
                              'Step ${7 + 2 * partnerCount}: MSME',
                              submission.businessDocuments?.msmeCertificate?.isComplete == true
                                  ? '✓ Uploaded'
                                  : '✗ Missing',
                              submission.businessDocuments?.msmeCertificate?.isComplete == true,
                            ),
                            _buildSummaryRow(
                              context,
                              'Step ${8 + 2 * partnerCount}: Own House Proof',
                              submission.businessDocuments?.ownHouseProof?.isComplete == true
                                  ? '✓ Uploaded'
                                  : '✗ Missing',
                              submission.businessDocuments?.ownHouseProof?.isComplete == true,
                            ),
                            _buildSummaryRow(
                              context,
                              'Step ${9 + 2 * partnerCount}: Personal Data',
                              submission.personalData?.isComplete == true
                                  ? '✓ Completed'
                                  : '✗ Missing',
                              submission.personalData?.isComplete == true,
                            ),
                          ] else ...[
                            _buildSummaryRow(
                              context,
                              'Step 5: Salary Slips',
                              submission.salarySlips?.isComplete == true
                                  ? '✓ Uploaded'
                                  : '✗ Missing',
                              submission.salarySlips?.isComplete == true,
                            ),
                            _buildSummaryRow(
                              context,
                              'Step 6: Personal Data',
                              submission.personalData?.isComplete == true
                                  ? '✓ Completed'
                                  : '✗ Missing',
                              submission.personalData?.isComplete == true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Detailed Sections
                    Text(
                      'Detailed Information',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildPremiumSection(
                      context,
                      stepNumber: 1,
                      title: 'Selfie / Photo',
                      icon: Icons.face,
                      isComplete: selfiePath != null,
                      onEdit: () => _editStep(context, AppRoutes.step1Selfie),
                      child: selfiePath != null
                          ? Container(
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.15,
                                    ),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                                border: Border.all(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _openImagePreview(selfiePath),
                                          child: PlatformImage(
                                            imagePath: selfiePath,
                                            fit: BoxFit.cover,
                                            headers: _authToken != null
                                                ? {
                                                    'Authorization': 'Bearer $_authToken'
                                                  }
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 12,
                                      bottom: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.55),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          'Tap to preview',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _buildEmptyState(context, 'No selfie uploaded'),
                    ),
                    const SizedBox(height: 20),
                    _buildPremiumSection(
                      context,
                      stepNumber: 2,
                      title: 'Aadhaar Card',
                      icon: Icons.badge,
                      isComplete: submission.aadhaar?.isComplete ?? false,
                      onEdit: () => _editStep(context, AppRoutes.step2Aadhaar),
                      child:
                          submission.aadhaar?.isComplete == true &&
                              submission.aadhaar!.frontPath != null &&
                              submission.aadhaar!.backPath != null
                          ? (submission.aadhaar!.frontIsPdf && 
                             submission.aadhaar!.backIsPdf && 
                             submission.aadhaar!.frontPath == submission.aadhaar!.backPath)
                              ? _buildPremiumDocumentPreview(
                                  context,
                                  submission.aadhaar!.frontPath!,
                                  'Aadhaar PDF',
                                  true,
                                  height: 220,
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildPremiumDocumentPreview(
                                      context,
                                      submission.aadhaar!.frontPath!,
                                      'Front',
                                      submission.aadhaar!.frontIsPdf,
                                      height: 220,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildPremiumDocumentPreview(
                                      context,
                                      submission.aadhaar!.backPath!,
                                      'Back',
                                      submission.aadhaar!.backIsPdf,
                                      height: 220,
                                    ),
                                  ],
                                )
                          : _buildEmptyState(context, 'Not uploaded'),
                    ),
                    const SizedBox(height: 20),
                    _buildPremiumSection(
                      context,
                      stepNumber: 3,
                      title: 'PAN Card',
                      icon: Icons.credit_card,
                      isComplete: submission.pan?.isComplete ?? false,
                      onEdit: () => _editStep(context, AppRoutes.step3Pan),
                      child: submission.pan?.isComplete == true
                          ? _buildPremiumDocumentPreview(
                              context,
                              submission.pan!.frontPath!,
                              'Front',
                              submission.pan!.isPdf,
                            )
                          : _buildEmptyState(context, 'Not uploaded'),
                    ),
                    const SizedBox(height: 20),
                    _buildPremiumSection(
                      context,
                      stepNumber: 4,
                      title: 'Bank Statement',
                      icon: Icons.account_balance,
                      isComplete: submission.bankStatement?.isComplete ?? false,
                      onEdit: () =>
                          _editStep(context, AppRoutes.step4BankStatement),
                      child: submission.bankStatement?.isComplete == true
                          ? PremiumCard(
                              gradientColors: [
                                colorScheme.primary.withValues(alpha: 0.05),
                                colorScheme.secondary.withValues(alpha: 0.02),
                              ],
                              child: Row(
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
                                    child: const Icon(
                                      Icons.description,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${submission.bankStatement!.pages.length} ${submission.bankStatement!.pages.length == 1 ? 'Page' : 'Pages'}',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Bank statement uploaded',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _buildEmptyState(context, 'Not uploaded'),
                    ),
                    const SizedBox(height: 20),
                    if (isBusinessProprietor) ...[
                      _buildPremiumSection(
                        context,
                        stepNumber: 5,
                        title: 'Spouse Aadhaar',
                        icon: Icons.badge_outlined,
                        isComplete: submission.businessDocuments?.spouseAadhaar?.isComplete ?? false,
                        onEdit: () => _editStep(context, AppRoutes.step4SpouseAadhaar),
                        child: (submission.businessDocuments?.spouseAadhaar?.isComplete == true)
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildPremiumDocumentPreview(
                                    context,
                                    submission.businessDocuments!.spouseAadhaar!.frontPath!,
                                    'Front',
                                    submission.businessDocuments!.spouseAadhaar!.frontIsPdf,
                                    height: 220,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildPremiumDocumentPreview(
                                    context,
                                    submission.businessDocuments!.spouseAadhaar!.backPath!,
                                    'Back',
                                    submission.businessDocuments!.spouseAadhaar!.backIsPdf,
                                    height: 220,
                                  ),
                                ],
                              )
                            : _buildEmptyState(context, 'Not uploaded'),
                      ),
                      const SizedBox(height: 20),
                      _buildPremiumSection(
                        context,
                        stepNumber: 6,
                        title: 'Spouse PAN',
                        icon: Icons.credit_card_outlined,
                        isComplete: submission.businessDocuments?.spousePan?.isComplete ?? false,
                        onEdit: () => _editStep(context, AppRoutes.step5SpousePan),
                        child: submission.businessDocuments?.spousePan?.isComplete == true
                            ? _buildPremiumDocumentPreview(
                                context,
                                submission.businessDocuments!.spousePan!.frontPath!,
                                'Front',
                                submission.businessDocuments!.spousePan!.isPdf,
                              )
                            : _buildEmptyState(context, 'Not uploaded'),
                      ),
                      const SizedBox(height: 20),
                      _buildPremiumSection(
                        context,
                        stepNumber: 7,
                        title: 'GST / Labour',
                        icon: Icons.receipt_long,
                        isComplete: submission.businessDocuments?.hasGstOrLabour ?? false,
                        onEdit: () => _editStep(context, AppRoutes.step5BusinessDocs),
                        child: (submission.businessDocuments?.hasGstOrLabour ?? false)
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (submission.businessDocuments?.gstRegistration?.isComplete == true)
                                    _buildPremiumDocumentPreview(
                                      context,
                                      submission.businessDocuments!.gstRegistration!.path!,
                                      'GST',
                                      submission.businessDocuments!.gstRegistration!.isPdf,
                                      height: 220,
                                    ),
                                  if (submission.businessDocuments?.gstRegistration?.isComplete == true &&
                                      submission.businessDocuments?.labourCertificate?.isComplete == true)
                                    const SizedBox(height: 12),
                                  if (submission.businessDocuments?.labourCertificate?.isComplete == true)
                                    _buildPremiumDocumentPreview(
                                      context,
                                      submission.businessDocuments!.labourCertificate!.path!,
                                      'Labour',
                                      submission.businessDocuments!.labourCertificate!.isPdf,
                                      height: 220,
                                    ),
                                ],
                              )
                            : _buildEmptyState(context, 'Not uploaded'),
                      ),
                      const SizedBox(height: 20),
                      _buildPremiumSection(
                        context,
                        stepNumber: 8,
                        title: 'MSME',
                        icon: Icons.workspace_premium,
                        isComplete: submission.businessDocuments?.msmeCertificate?.isComplete ?? false,
                        onEdit: () => _editStep(context, AppRoutes.step6Msme),
                        child: submission.businessDocuments?.msmeCertificate?.isComplete == true
                            ? _buildPremiumDocumentPreview(
                                context,
                                submission.businessDocuments!.msmeCertificate!.path!,
                                'MSME',
                                submission.businessDocuments!.msmeCertificate!.isPdf,
                                height: 220,
                              )
                            : _buildEmptyState(context, 'Not uploaded'),
                      ),
                      const SizedBox(height: 20),
                      _buildPremiumSection(
                        context,
                        stepNumber: 9,
                        title: 'Own House Proof',
                        icon: Icons.home_outlined,
                        isComplete: submission.businessDocuments?.ownHouseProof?.isComplete ?? false,
                        onEdit: () => _editStep(context, AppRoutes.step7Ohp),
                        child: submission.businessDocuments?.ownHouseProof?.isComplete == true
                            ? _buildPremiumDocumentPreview(
                                context,
                                submission.businessDocuments!.ownHouseProof!.path!,
                                'Own House Proof',
                                submission.businessDocuments!.ownHouseProof!.isPdf,
                                height: 220,
                              )
                            : _buildEmptyState(context, 'Not uploaded'),
                      ),
                      const SizedBox(height: 20),
                    ] else if (isPartnerFlow) ...[
                      _buildPremiumSection(
                        context,
                        stepNumber: 5,
                        title: 'Partners KYC',
                        icon: Icons.groups,
                        isComplete: submission.businessDocuments?.isPartnerKycComplete ?? false,
                        onEdit: () => _editStep(context, AppRoutes.partnerCount),
                        child: (partnerCount > 0)
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: List.generate(partnerCount, (i) {
                                  final partnerIndex = i + 1;
                                  final partner = (submission.businessDocuments?.partners.length ?? 0) > i
                                      ? submission.businessDocuments!.partners[i]
                                      : null;
                                  final aadhaar = partner?.aadhaar;
                                  final pan = partner?.pan;
                                  final hasAadhaar = aadhaar?.isComplete ?? false;
                                  final hasPan = pan?.isComplete ?? false;

                                  return Padding(
                                    padding: EdgeInsets.only(bottom: partnerIndex == partnerCount ? 0 : 16),
                                    child: PremiumCard(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Partner $partnerIndex',
                                                  style: theme.textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () => context.go(
                                                  '${AppRoutes.partnerAadhaar}?i=$partnerIndex&from=preview',
                                                ),
                                                child: const Text('Edit'),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          if (hasAadhaar) ...[
                                            _buildPremiumDocumentPreview(
                                              context,
                                              aadhaar!.frontPath!,
                                              'Aadhaar Front',
                                              aadhaar.frontIsPdf,
                                              height: 180,
                                            ),
                                            const SizedBox(height: 12),
                                            _buildPremiumDocumentPreview(
                                              context,
                                              aadhaar.backPath!,
                                              'Aadhaar Back',
                                              aadhaar.backIsPdf,
                                              height: 180,
                                            ),
                                          ] else
                                            _buildEmptyState(context, 'Aadhaar not uploaded'),
                                          const SizedBox(height: 12),
                                          if (hasPan)
                                            _buildPremiumDocumentPreview(
                                              context,
                                              pan!.frontPath!,
                                              'PAN',
                                              pan.isPdf,
                                              height: 180,
                                            )
                                          else
                                            _buildEmptyState(context, 'PAN not uploaded'),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              )
                            : _buildEmptyState(context, 'Not selected'),
                      ),
                      const SizedBox(height: 20),
                      _buildPremiumSection(
                        context,
                        stepNumber: 6 + 2 * partnerCount,
                        title: 'Business Documents',
                        icon: Icons.receipt_long,
                        isComplete: (submission.businessDocuments?.companyPanCard?.isComplete ?? false) &&
                            (isBusinessPvtLimited
                                ? ((submission.businessDocuments?.moa?.isComplete ?? false) &&
                                    (submission.businessDocuments?.aoa?.isComplete ?? false))
                                : (submission.businessDocuments?.partnershipDeed?.isComplete ?? false)) &&
                            (submission.businessDocuments?.hasGstOrLabour ?? false),
                        onEdit: () => _editStep(context, AppRoutes.step5BusinessDocs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (submission.businessDocuments?.companyPanCard?.isComplete == true)
                              _buildPremiumDocumentPreview(
                                context,
                                submission.businessDocuments!.companyPanCard!.path!,
                                'Company PAN Card',
                                submission.businessDocuments!.companyPanCard!.isPdf,
                                height: 220,
                              )
                            else
                              _buildEmptyState(context, 'Company PAN Card not uploaded'),
                            const SizedBox(height: 12),
                            if (isBusinessPvtLimited) ...[
                              if (submission.businessDocuments?.moa?.isComplete == true)
                                _buildPremiumDocumentPreview(
                                  context,
                                  submission.businessDocuments!.moa!.path!,
                                  'MOA',
                                  submission.businessDocuments!.moa!.isPdf,
                                  height: 220,
                                )
                              else
                                _buildEmptyState(context, 'MOA not uploaded'),
                              const SizedBox(height: 12),
                              if (submission.businessDocuments?.aoa?.isComplete == true)
                                _buildPremiumDocumentPreview(
                                  context,
                                  submission.businessDocuments!.aoa!.path!,
                                  'AOA',
                                  submission.businessDocuments!.aoa!.isPdf,
                                  height: 220,
                                )
                              else
                                _buildEmptyState(context, 'AOA not uploaded'),
                              const SizedBox(height: 12),
                            ] else ...[
                              if (submission.businessDocuments?.partnershipDeed?.isComplete == true)
                                _buildPremiumDocumentPreview(
                                  context,
                                  submission.businessDocuments!.partnershipDeed!.path!,
                                  'Partnership Deed',
                                  submission.businessDocuments!.partnershipDeed!.isPdf,
                                  height: 220,
                                )
                              else
                                _buildEmptyState(context, 'Partnership Deed not uploaded'),
                              const SizedBox(height: 12),
                            ],
                            if (submission.businessDocuments?.gstRegistration?.isComplete == true)
                              _buildPremiumDocumentPreview(
                                context,
                                submission.businessDocuments!.gstRegistration!.path!,
                                'GST',
                                submission.businessDocuments!.gstRegistration!.isPdf,
                                height: 220,
                              ),
                            if (submission.businessDocuments?.gstRegistration?.isComplete == true &&
                                submission.businessDocuments?.labourCertificate?.isComplete == true)
                              const SizedBox(height: 12),
                            if (submission.businessDocuments?.labourCertificate?.isComplete == true)
                              _buildPremiumDocumentPreview(
                                context,
                                submission.businessDocuments!.labourCertificate!.path!,
                                'Labour',
                                submission.businessDocuments!.labourCertificate!.isPdf,
                                height: 220,
                              ),
                            if ((submission.businessDocuments?.hasGstOrLabour ?? false) == false)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _buildEmptyState(context, 'GST/Labour not uploaded'),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildPremiumSection(
                        context,
                        stepNumber: 7 + 2 * partnerCount,
                        title: 'MSME',
                        icon: Icons.workspace_premium,
                        isComplete: submission.businessDocuments?.msmeCertificate?.isComplete ?? false,
                        onEdit: () => _editStep(context, AppRoutes.step6Msme),
                        child: submission.businessDocuments?.msmeCertificate?.isComplete == true
                            ? _buildPremiumDocumentPreview(
                                context,
                                submission.businessDocuments!.msmeCertificate!.path!,
                                'MSME',
                                submission.businessDocuments!.msmeCertificate!.isPdf,
                                height: 220,
                              )
                            : _buildEmptyState(context, 'Not uploaded'),
                      ),
                      const SizedBox(height: 20),
                      _buildPremiumSection(
                        context,
                        stepNumber: 8 + 2 * partnerCount,
                        title: 'Own House Proof',
                        icon: Icons.home_outlined,
                        isComplete: submission.businessDocuments?.ownHouseProof?.isComplete ?? false,
                        onEdit: () => _editStep(context, AppRoutes.step7Ohp),
                        child: submission.businessDocuments?.ownHouseProof?.isComplete == true
                            ? _buildPremiumDocumentPreview(
                                context,
                                submission.businessDocuments!.ownHouseProof!.path!,
                                'Own House Proof',
                                submission.businessDocuments!.ownHouseProof!.isPdf,
                                height: 220,
                              )
                            : _buildEmptyState(context, 'Not uploaded'),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      _buildPremiumSection(
                        context,
                        stepNumber: 5,
                        title: 'Salary Slips',
                        icon: Icons.receipt_long,
                        isComplete: submission.salarySlips?.isComplete ?? false,
                        onEdit: () => _editStep(context, AppRoutes.step5_1SalarySlips),
                        child: submission.salarySlips?.isComplete == true
                            ? PremiumCard(
                                gradientColors: [
                                  colorScheme.primary.withValues(alpha: 0.05),
                                  colorScheme.secondary.withValues(alpha: 0.02),
                                ],
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
                                          child: const Icon(
                                            Icons.receipt_long,
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
                                                '${submission.salarySlips!.slips.length} ${submission.salarySlips!.slips.length == 1 ? 'Slip' : 'Slips'} Uploaded',
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                submission.salarySlips!.isPdf ? 'PDF Format' : 'Image Format',
                                                style: theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (submission.salarySlips!.slips.length <= 3) ...[
                                      const SizedBox(height: 16),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: submission.salarySlips!.slips.asMap().entries.map((entry) {
                                          return SizedBox(
                                            width: 100,
                                            height: 140,
                                            child: _buildPremiumDocumentPreview(
                                              context,
                                              entry.value,
                                              'Slip ${entry.key + 1}',
                                              submission.salarySlips!.isPdf && entry.key == 0,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ] else ...[
                                      const SizedBox(height: 16),
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                          childAspectRatio: 0.7,
                                        ),
                                        itemCount: submission.salarySlips!.slips.length,
                                        itemBuilder: (context, index) {
                                          return _buildPremiumDocumentPreview(
                                            context,
                                            submission.salarySlips!.slipItems[index].path,
                                            'Slip ${index + 1}',
                                            submission.salarySlips!.isPdf && index == 0,
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : _buildEmptyState(context, 'Not uploaded'),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _buildPremiumSection(
                      context,
                      stepNumber: isBusinessProprietor
                          ? 10
                          : (isPartnerFlow && partnerCount > 0
                              ? (9 + 2 * partnerCount)
                              : 6),
                      title: 'Personal Data',
                      icon: Icons.person,
                      isComplete: submission.personalData?.isComplete ?? false,
                      onEdit: () => _editStep(context, AppRoutes.step5PersonalData),
                      child: Builder(
                        builder: (context) {
                          if (kDebugMode) {
                            print('🔍 Building Personal Data Section:');
                            print('   personalData != null: ${submission.personalData != null}');
                            if (submission.personalData != null) {
                              print('   personalData.isComplete: ${submission.personalData!.isComplete}');
                            }
                          }
                          return submission.personalData != null
                              ? PremiumCard(
                                  gradientColors: [
                                    Colors.white,
                                    colorScheme.primary.withValues(alpha: 0.02),
                                  ],
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: _buildPersonalDataPreview(
                                      context,
                                      submission.personalData!,
                                    ),
                                  ),
                                )
                              : _buildEmptyState(context, 'No personal data entered');
                        },
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Dynamic button: Close if submitted, Submit if not submitted
                    if (!isSubmitted) ...[
                      // Not submitted - show Submit button
                      SlideToConfirm(
                        label: submission.isComplete
                            ? 'Slide to Submit'
                            : 'Complete Missing Steps',
                        enabled: submission.isComplete,
                        onSubmitted: submission.isComplete
                            ? () => _submit(context)
                            : null,
                      ),
                    ] else ...[
                      // Already submitted - show Download PDF and Close
                      Row(
                        children: [
                          Expanded(
                            child: PremiumCard(
                              gradientColors: [
                                colorScheme.primary.withValues(alpha: 0.08),
                                colorScheme.secondary.withValues(alpha: 0.04),
                              ],
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => context.go(AppRoutes.pdfDownload),
                                  icon: const Icon(Icons.download),
                                  label: const Text('Download PDF'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PremiumCard(
                              gradientColors: [
                                colorScheme.primary.withValues(alpha: 0.05),
                                colorScheme.secondary.withValues(alpha: 0.03),
                              ],
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => context.go(AppRoutes.home),
                                  icon: const Icon(Icons.close),
                                  label: const Text('Close'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.surfaceContainerHighest,
                                    foregroundColor: colorScheme.onSurface,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

  Widget _buildPremiumSection(
    BuildContext context, {
    required int stepNumber,
    required String title,
    required IconData icon,
    required bool isComplete,
    required VoidCallback onEdit,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PremiumCard(
      gradientColors: [
        Colors.white,
        isComplete
            ? AppTheme.successColor.withValues(alpha: 0.02)
            : colorScheme.primary.withValues(alpha: 0.02),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: isComplete
                            ? LinearGradient(
                                colors: [
                                  AppTheme.successColor,
                                  AppTheme.successColor.withValues(alpha: 0.8),
                                ],
                              )
                            : null,
                        color: isComplete ? null : Colors.grey.shade300,
                        shape: BoxShape.circle,
                        boxShadow: isComplete
                            ? [
                                BoxShadow(
                                  color: AppTheme.successColor.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        // Keep layout consistent, but remove the green tick icon
                        // (user requested no tick mark before headings in Preview).
                        child: Text(
                          '$stepNumber',
                          style: TextStyle(
                            color: isComplete ? Colors.white : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: colorScheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextButton.icon(
                  onPressed: onEdit,
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  label: Text(
                    'Edit',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildPremiumDocumentPreview(
    BuildContext context,
    String path,
    String label,
    bool isPdf, {
    double height = 140,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    // Prefer path extension: if path looks like image, always show image; else use isPdf / .pdf
    final pathWithoutQuery = path.split(RegExp(r'[?#]')).first.toLowerCase();
    final looksLikeImage = pathWithoutQuery.endsWith('.jpg') ||
        pathWithoutQuery.endsWith('.jpeg') ||
        pathWithoutQuery.endsWith('.png') ||
        pathWithoutQuery.endsWith('.gif') ||
        pathWithoutQuery.endsWith('.webp');
    final showAsPdf = !looksLikeImage && (isPdf || pathWithoutQuery.endsWith('.pdf'));
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.5),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openDocumentPreview(
              context,
              path: path,
              label: label,
              showAsPdf: showAsPdf,
            ),
            child: Stack(
              children: [
                showAsPdf
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary.withValues(alpha: 0.1),
                              colorScheme.secondary.withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.picture_as_pdf,
                                size: 40,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'PDF',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to preview',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildImagePreview(path, colorScheme),
                // "Preview" affordance (so user knows it is tappable)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.open_in_full, size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Preview',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDocumentPreview(
    BuildContext context, {
    required String path,
    required String label,
    required bool showAsPdf,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                Container(
                  color: Colors.black,
                  child: Center(
                    child: showAsPdf
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.picture_as_pdf,
                                  size: 56,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Preview not available for PDFs here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: PlatformImage(
                              imagePath: path,
                              fit: BoxFit.contain,
                              headers: _authToken != null
                                  ? {'Authorization': 'Bearer $_authToken'}
                                  : null,
                            ),
                          ),
                  ),
                ),
                // Close button
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          // Keep close button red for clear affordance.
                          color: AppTheme.errorColor.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImagePreview(String path, ColorScheme colorScheme) {
    // Check if path is valid
    if (path.isEmpty) {
      return Container(
        decoration: BoxDecoration(color: Colors.grey.shade100),
        child: Center(
          child: Icon(
            Icons.image_not_supported,
            size: 40,
            color: Colors.grey.shade400,
          ),
        ),
      );
    }

    // Wait for auth to be ready before showing remote images
    if (path.startsWith('http') && _isLoadingAuth) {
      return Container(
        decoration: BoxDecoration(color: Colors.grey.shade50),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Use PlatformImage with better error handling
    return SizedBox.expand(
      child: PlatformImage(
        imagePath: path,
        fit: BoxFit.cover,
        headers: _authToken != null
            ? {'Authorization': 'Bearer $_authToken'}
            : null,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey.shade600, size: 24),
          const SizedBox(width: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalDataPreview(BuildContext context, PersonalData data) {
    // Debug: Print all data fields
    if (kDebugMode) {
      print('═══════════════════════════════════════════════════════════');
      print('🎨 BUILDING PERSONAL DATA PREVIEW WIDGET');
      print('═══════════════════════════════════════════════════════════');
      print('📋 Basic Information:');
      print(
        '   Name: ${data.nameAsPerAadhaar ?? "null"} (${data.nameAsPerAadhaar?.isNotEmpty ?? false ? "has value" : "empty/null"})',
      );
      print('   DOB: ${data.dateOfBirth ?? "null"}');
      print(
        '   PAN: ${data.panNo ?? "null"} (${data.panNo?.isNotEmpty ?? false ? "has value" : "empty/null"})',
      );
      print(
        '   Mobile: ${data.mobileNumber ?? "null"} (${data.mobileNumber?.isNotEmpty ?? false ? "has value" : "empty/null"})',
      );
      print(
        '   Email: ${data.personalEmailId ?? "null"} (${data.personalEmailId?.isNotEmpty ?? false ? "has value" : "empty/null"})',
      );
      print('📋 Residence Information:');
      print('   Country: ${data.countryOfResidence ?? "null"}');
      print('   Address: ${data.residenceAddress ?? "null"}');
      print('📋 Work Info:');
      print('   Company Name: ${data.companyName ?? "null"}');
      print('   Company Address: ${data.companyAddress ?? "null"}');
      print('   Work Type: ${data.workType ?? "null"}');
      print('   Industry: ${data.industry ?? "null"}');
      print('   Annual Income: ${data.annualIncome ?? "null"}');
      print('   Total Work Experience: ${data.totalWorkExperience ?? "null"}');
      print(
        '   Current Company Experience: ${data.currentCompanyExperience ?? "null"}',
      );
      print('📋 Personal Details:');
      print('   Occupation: ${data.occupation ?? "null"}');
      print('📋 Family Information:');
      print('   Marital Status: ${data.maritalStatus ?? "null"}');
      print('   Spouse Name: ${data.spouseName ?? "null"}');
      print('   Father Name: ${data.fatherName ?? "null"}');
      print('   Mother Name: ${data.motherName ?? "null"}');
      print('📋 References:');
      print('   Ref1 Name: ${data.reference1Name ?? "null"}');
      print('   Ref1 Contact: ${data.reference1Contact ?? "null"}');
      print('   Ref2 Name: ${data.reference2Name ?? "null"}');
      print('   Ref2 Contact: ${data.reference2Contact ?? "null"}');
      print('═══════════════════════════════════════════════════════════');
    }

    // Count fields that will be displayed
    int fieldCount = 0;
    if (data.nameAsPerAadhaar != null && data.nameAsPerAadhaar!.isNotEmpty)
      fieldCount++;
    if (data.dateOfBirth != null) fieldCount++;
    if (data.panNo != null && data.panNo!.isNotEmpty) fieldCount++;
    if (data.mobileNumber != null && data.mobileNumber!.isNotEmpty)
      fieldCount++;
    if (data.personalEmailId != null && data.personalEmailId!.isNotEmpty)
      fieldCount++;

    if (kDebugMode) {
      print('📊 Total fields to display: $fieldCount');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Basic Information
        if (data.nameAsPerAadhaar != null && data.nameAsPerAadhaar!.isNotEmpty)
          _buildDataRow('Name as per Aadhaar', data.nameAsPerAadhaar!),
        if (data.dateOfBirth != null)
          _buildDataRow(
            'Date of Birth',
            DateFormat('MMMM dd, yyyy').format(data.dateOfBirth!),
          ),
        if (data.panNo != null && data.panNo!.isNotEmpty)
          _buildDataRow('PAN No', data.panNo!),
        if (data.mobileNumber != null && data.mobileNumber!.isNotEmpty)
          _buildDataRow('Mobile Number', data.mobileNumber!),
        if (data.personalEmailId != null && data.personalEmailId!.isNotEmpty)
          _buildDataRow('Personal Email', data.personalEmailId!),

        // Residence Information
        if (data.countryOfResidence != null &&
            data.countryOfResidence!.isNotEmpty)
          _buildDataRow('Country of Residence', data.countryOfResidence!),
        if (data.residenceAddress != null && data.residenceAddress!.isNotEmpty)
          _buildDataRow('Residence Address', data.residenceAddress!),
        if (data.residenceType != null && data.residenceType!.isNotEmpty)
          _buildDataRow('Residence Type', data.residenceType!),
        if (data.residenceStability != null &&
            data.residenceStability!.isNotEmpty)
          _buildDataRow('Residence Stability', data.residenceStability!),

        // Work Info (formerly Company Information)
        if (data.companyName != null && data.companyName!.isNotEmpty)
          _buildDataRow('Company Name', data.companyName!),
        if (data.companyAddress != null && data.companyAddress!.isNotEmpty)
          _buildDataRow('Company Address', data.companyAddress!),
        if (data.workType != null && data.workType!.isNotEmpty)
          _buildDataRow('Work Type', data.workType!),
        if (data.industry != null && data.industry!.isNotEmpty)
          _buildDataRow('Industry', data.industry!),
        if (data.annualIncome != null && data.annualIncome!.isNotEmpty)
          _buildDataRow('Annual Income', data.annualIncome!),
        if (data.totalWorkExperience != null &&
            data.totalWorkExperience!.isNotEmpty)
          _buildDataRow('Total years of experience', data.totalWorkExperience!),
        if (data.currentCompanyExperience != null &&
            data.currentCompanyExperience!.isNotEmpty)
          _buildDataRow(
            'Current Company Experience',
            data.currentCompanyExperience!,
          ),

        // Personal Details
        if (data.nationality != null && data.nationality!.isNotEmpty)
          _buildDataRow('Nationality', data.nationality!),
        if (data.countryOfBirth != null && data.countryOfBirth!.isNotEmpty)
          _buildDataRow('Country of Birth', data.countryOfBirth!),
        if (data.occupation != null && data.occupation!.isNotEmpty)
          _buildDataRow('Occupation', data.occupation!),
        if (data.educationalQualification != null &&
            data.educationalQualification!.isNotEmpty)
          _buildDataRow(
            'Educational Qualification',
            data.educationalQualification!,
          ),
        if ((data.loanAmount != null && data.loanAmount!.isNotEmpty) ||
            (data.loanTenure != null && data.loanTenure!.isNotEmpty)) ...[
          if (data.loanAmount != null && data.loanAmount!.isNotEmpty)
            _buildDataRow('Loan Amount', '₹ ${data.loanAmount}'),
          if (data.loanTenure != null && data.loanTenure!.isNotEmpty)
            _buildDataRow('Loan Tenure', '${data.loanTenure} months'),
        ] else if (data.loanAmountTenure != null &&
            data.loanAmountTenure!.isNotEmpty)
          _buildDataRow('Loan Amount/Tenure', data.loanAmountTenure!),

        // Family Information
        if (data.maritalStatus != null && data.maritalStatus!.isNotEmpty)
          _buildDataRow('Marital Status', data.maritalStatus!),
        if (data.maritalStatus == 'Married' &&
            data.spouseName != null &&
            data.spouseName!.isNotEmpty)
          _buildDataRow('Spouse Name', data.spouseName!),
        if (data.fatherName != null && data.fatherName!.isNotEmpty)
          _buildDataRow('Father Name', data.fatherName!),
        if (data.motherName != null && data.motherName!.isNotEmpty)
          _buildDataRow('Mother Name', data.motherName!),

        // Reference Details
        if ((data.reference1Name != null && data.reference1Name!.isNotEmpty) ||
            (data.reference1Address != null &&
                data.reference1Address!.isNotEmpty) ||
            (data.reference1Contact != null &&
                data.reference1Contact!.isNotEmpty)) ...[
          const SizedBox(height: 8),
          Text(
            'Reference 1',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (data.reference1Name != null && data.reference1Name!.isNotEmpty)
            _buildDataRow('Name', data.reference1Name!),
          if (data.reference1Address != null &&
              data.reference1Address!.isNotEmpty)
            _buildDataRow('Address', data.reference1Address!),
          if (data.reference1Contact != null &&
              data.reference1Contact!.isNotEmpty)
            _buildDataRow('Contact', data.reference1Contact!),
        ],
        if ((data.reference2Name != null && data.reference2Name!.isNotEmpty) ||
            (data.reference2Address != null &&
                data.reference2Address!.isNotEmpty) ||
            (data.reference2Contact != null &&
                data.reference2Contact!.isNotEmpty)) ...[
          const SizedBox(height: 8),
          Text(
            'Reference 2',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (data.reference2Name != null && data.reference2Name!.isNotEmpty)
            _buildDataRow('Name', data.reference2Name!),
          if (data.reference2Address != null &&
              data.reference2Address!.isNotEmpty)
            _buildDataRow('Address', data.reference2Address!),
          if (data.reference2Contact != null &&
              data.reference2Contact!.isNotEmpty)
            _buildDataRow('Contact', data.reference2Contact!),
        ],
      ],
    );
  }

  Widget _buildDataRow(String label, String value) {
    if (kDebugMode) {
      print('   ✓ Displaying: $label = $value');
    }
    final trimmed = value.trim();
    final isLikelyUnbrokenLongText =
        trimmed.length >= 18 && !trimmed.contains(' ');
    final isEmail = trimmed.contains('@');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: (isEmail || isLikelyUnbrokenLongText)
                ? InkWell(
                    onTap: () => _showFullValueSheet(
                      context,
                      title: label,
                      value: trimmed,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              trimmed,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.open_in_new,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.9),
                          ),
                        ],
                      ),
                    ),
                  )
                : Text(
                    trimmed,
                    overflow: TextOverflow.visible,
                    softWrap: true,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFullValueSheet(
    BuildContext context, {
    required String title,
    required String value,
  }) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.12),
                    ),
                  ),
                  child: SelectableText(
                    value,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: value));
                          if (context.mounted) {
                            PremiumToast.showSuccess(context, 'Copied');
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        label: const Text('Close'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.onSurface,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String step,
    String status,
    bool isComplete,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            step,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isComplete
                  ? AppTheme.successColor.withValues(alpha: 0.1)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isComplete
                    ? AppTheme.successColor
                    : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(
    BuildContext context, {
    required int currentStep,
    required int totalSteps,
  }) {
    return PremiumProgressIndicator(
      currentStep: currentStep,
      totalSteps: totalSteps,
      maxVisibleSteps: 7,
    );
  }
}
