import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/submission_provider.dart';
import '../providers/application_provider.dart';
import '../services/file_upload_service.dart';
import '../utils/app_routes.dart';
import '../utils/blob_helper.dart';
import '../widgets/platform_image.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '../widgets/premium_toast.dart';
import '../utils/app_theme.dart';
import '../widgets/app_header.dart';
import '../services/storage_service.dart';
import '../utils/api_config.dart';

class Step4BankStatementScreen extends StatefulWidget {
  const Step4BankStatementScreen({super.key});

  @override
  State<Step4BankStatementScreen> createState() =>
      _Step4BankStatementScreenState();
}

class _Step4BankStatementScreenState extends State<Step4BankStatementScreen> {
  final FileUploadService _fileUploadService = FileUploadService();
  List<String> _pages = [];
  String? _pdfPassword;
  bool _isPdf = false;
  bool _isSaving = false;
  DateTime? _statementEndDate;
  DateTime? _calculatedStartDate;
  String? _authToken;
  List<bool> _pageFailures = [];
  List<Uint8List?> _pageBytes = [];

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
    _pages = List.from(provider.submission.bankStatement?.pages ?? []);
    _isPdf = provider.submission.bankStatement?.isPdf ?? false;
    _pdfPassword = provider.submission.bankStatement?.pdfPassword;
    
    // Automatically use today's date
    _statementEndDate = DateTime.now();
    _calculateStartDate();
    
    // Load existing data from backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingData();
    });
  }

  Future<void> _loadExistingData() async {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication) return;

    final application = appProvider.currentApplication!;
    if (application.step4BankStatement != null) {
      final stepData = application.step4BankStatement as Map<String, dynamic>;

        
        // Helper to build full URL
        String? buildFullUrl(String? relativeUrl) {
          if (relativeUrl == null || relativeUrl.isEmpty) return null;
          
          // Fix for localhost URLs in saved data
          if (relativeUrl.startsWith('http://localhost:5000')) {
             return relativeUrl.replaceFirst('http://localhost:5000', ApiConfig.baseUrl);
          }

          if (relativeUrl.startsWith('http') || relativeUrl.startsWith('blob:')) return relativeUrl;
          String apiPath = relativeUrl;
          if (apiPath.startsWith('/uploads/') && !apiPath.contains('/uploads/files/')) {
            apiPath = apiPath.replaceFirst('/uploads/', '/api/v1/uploads/files/');
          } else if (!apiPath.startsWith('/api/')) {
            apiPath = '/api/v1$apiPath';
          }
          return '${ApiConfig.baseUrl}$apiPath';
        }

        // Get access token for authenticated request
        final storage = StorageService.instance;
        final accessToken = await storage.getAccessToken();
        if (accessToken != null && mounted) {
          setState(() {
            _authToken = accessToken;
          });
        }
        

        
        setState(() {
          final rawPages = List<String>.from(stepData['pages'] as List);
          _pages = rawPages.map((p) => buildFullUrl(p) ?? p).toList();
          _isPdf = stepData['isPdf'] as bool? ?? false;
          // Initialize failure/bytes lists
          _pageFailures = List.filled(_pages.length, false);
          _pageBytes = List.filled(_pages.length, null);

          _pdfPassword = stepData['pdfPassword'] as String?;
          if (stepData['statementEndDate'] != null) {
            _statementEndDate = DateTime.parse(stepData['statementEndDate'] as String);
            _calculateStartDate();
          } else if (stepData['calculatedStartDate'] != null) {
            _calculatedStartDate = DateTime.parse(stepData['calculatedStartDate'] as String);
          }
        });

        // Verify images asynchronously if auth token is available
        if (accessToken != null && !_isPdf) {
          for (int i = 0; i < _pages.length; i++) {
            final page = _pages[i];
            if (page.startsWith('http')) {
              _verifyPage(page, i, accessToken);
            }
          }
        }
    }
  }

  Future<void> _verifyPage(String url, int index, String token) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (index >= _pageFailures.length) return; // Bounds check

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';
        final isLikelyImage = contentType.startsWith('image/');
        final bytes = response.bodyBytes;
        if (isLikelyImage && _isValidImageBytes(bytes)) {
          setState(() {
            _pageBytes[index] = bytes;
            _pageFailures[index] = false;
          });
        } else {
          setState(() { _pageFailures[index] = true; });
        }
      } else {
        setState(() { _pageFailures[index] = true; });
      }
    } catch (e) {
      if (mounted && index < _pageFailures.length) {
        setState(() { _pageFailures[index] = true; });
      }
    }
  }

  void _calculateStartDate() {
    if (_statementEndDate == null) {
      _calculatedStartDate = null;
      return;
    }

    // Calculate 6 months back, always starting from the 1st of that month
    // This ensures the date range is >= 6 months and < 7 months
    // Example: If user gives July 5, calculate to January 1 (6 months back, 1st of month)
    //          Range: Jan 1 to Jul 5 = 6 months and 4 days (>= 6 months, < 7 months)
    // Example: If user gives July 25, calculate to January 1 (6 months back, 1st of month)
    //          Range: Jan 1 to Jul 25 = 6 months and 24 days (>= 6 months, < 7 months)
    final endDate = _statementEndDate!;
    
    // Subtract 6 months and set to 1st of that month
    DateTime startDate;
    if (endDate.month > 6) {
      // Same year, just subtract 6 months
      startDate = DateTime(
        endDate.year,
        endDate.month - 6,
        1, // Always use 1st of the month
      );
    } else {
      // Previous year, add 6 months to get to previous year
      startDate = DateTime(
        endDate.year - 1,
        endDate.month + 6,
        1, // Always use 1st of the month
      );
    }
    
    // Verify the range is >= 6 months and < 7 months
    final monthsDifference = (endDate.year - startDate.year) * 12 + (endDate.month - startDate.month);
    if (monthsDifference < 6 || monthsDifference >= 7) {
      // Adjust if needed to ensure >= 6 and < 7 months
      if (monthsDifference < 6) {
        // Need to go back one more month
        if (startDate.month == 1) {
          startDate = DateTime(startDate.year - 1, 12, 1);
        } else {
          startDate = DateTime(startDate.year, startDate.month - 1, 1);
        }
      } else if (monthsDifference >= 7) {
        // Need to go forward one month
        if (startDate.month == 12) {
          startDate = DateTime(startDate.year + 1, 1, 1);
        } else {
          startDate = DateTime(startDate.year, startDate.month + 1, 1);
        }
      }
    }
    
    setState(() {
      _calculatedStartDate = startDate;
    });
  }

  /// Saves draft to DB. Returns true only if save succeeded; then safe to go to next step.
  Future<bool> _saveToBackend() async {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication || _pages.isEmpty) return false;

    setState(() {
      _isSaving = true;
    });

    try {
      final localPaths = _pages.where((p) => !p.startsWith('http')).toList();
      final remoteUrls = _pages.where((p) => p.startsWith('http')).toList();
      List<Map<String, dynamic>> finalUploadedFiles = [];

      if (remoteUrls.isNotEmpty) {
        final currentApp = appProvider.currentApplication;
        if (currentApp?.step4BankStatement != null) {
          final stepData = currentApp!.step4BankStatement as Map<String, dynamic>;
          final existingUploads = (stepData['uploadedFiles'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ?? [];
          for (final upload in existingUploads) {
            final url = upload['url'] as String?;
            if (url != null &&
                remoteUrls.any((r) => r.contains(url) || url.contains(r)) &&
                !finalUploadedFiles.any((f) => f['url'] == url)) {
              finalUploadedFiles.add(upload);
            }
          }
        }
      }

      if (localPaths.isNotEmpty) {
        final files = localPaths.map((path) => XFile(path)).toList();
        final newUploadResults = await _fileUploadService.uploadBankStatements(files);
        finalUploadedFiles.addAll(newUploadResults);
      }

      await appProvider.updateApplication(
        currentStep: 5,
        step4BankStatement: {
          'pages': _pages.toSet().toList(),
          'isPdf': _isPdf,
          'pdfPassword': _pdfPassword,
          'uploadedFiles': finalUploadedFiles,
          'statementEndDate': _statementEndDate?.toIso8601String(),
          'calculatedStartDate': _calculatedStartDate?.toIso8601String(),
          'savedAt': DateTime.now().toIso8601String(),
        },
      );

      if (mounted) {
        PremiumToast.showSuccess(context, 'Bank statement saved successfully!');
      }
      return true;
    } catch (e) {
      if (mounted) {
        PremiumToast.showError(
          context,
          'Failed to save bank statement: ${e.toString()}',
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
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
        // On web, use bytes to create a blob URL
        final bytes = result.files.single.bytes;
        if (bytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Unable to read PDF file. Please try again.'),
                backgroundColor: AppTheme.errorColor,
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: _uploadPdf,
                ),
              ),
            );
          }
          return;
        }
        // Create blob URL from bytes
        path = createBlobUrl(bytes, mimeType: 'application/pdf');
      } else {
        // On mobile/desktop, use file path
        if (result.files.single.path == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Unable to access file. Please try again.'),
                backgroundColor: AppTheme.errorColor,
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: _uploadPdf,
                ),
              ),
            );
          }
          return;
        }
        path = result.files.single.path!;
      }
      
      if (mounted) {
        setState(() {
          _pages = [path];
          _isPdf = true;
          _pageFailures = [false];
          _pageBytes = [null];
        });
        context
            .read<SubmissionProvider>()
            .setBankStatementPages([path], isPdf: true);
        _showPasswordDialogIfNeeded();
      }
    }
  }




  void _removePage(int index) {
    setState(() {
      _pages.removeAt(index);
      if (index < _pageFailures.length) {
        _pageFailures.removeAt(index);
        _pageBytes.removeAt(index);
      }
    });
    context
        .read<SubmissionProvider>()
        .setBankStatementPages(_pages, isPdf: _isPdf);
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
                border: const OutlineInputBorder(),
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
                context
                    .read<SubmissionProvider>()
                    .setBankStatementPassword(_pdfPassword!);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _proceedToNext() async {
    if (_pages.isEmpty) {
      PremiumToast.showWarning(
        context,
        'Please upload bank statement (last 6 months)',
      );
      return;
    }
    if (_isSaving) return;
    final saved = await _saveToBackend();
    if (mounted && saved) {
      context.go(AppRoutes.step5_1SalarySlips);
    }
  }

  String _formatDateWithYear(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Royal Blue Header
            AppHeader(
              title: 'Bank Statement',
              icon: Icons.account_balance,
              showBackButton: true,
              onBackPressed: () => context.go(AppRoutes.step3Pan),
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
                    const SizedBox(height: 20),
                    
                    // Required Statement Period Card
                    if (_statementEndDate != null && _calculatedStartDate != null)
                      _buildRequiredPeriodCard(context),
                    const SizedBox(height: 20),
                    
                    // Uploaded Pages Section
                    if (_pages.isNotEmpty)
                      _buildUploadedPagesSection(context)
                    else
                      _buildEmptyUploadState(context),
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
          // Steps 1-3: Completed
          for (int i = 1; i <= 3; i++) ...[
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
          // Step 4: Current
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
                      '4',
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
          // Steps 5-7: Pending
          for (int i = 5; i <= 7; i++) ...[
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEFF6FF), // blue-50
            Color(0xFFDBEAFE), // blue-100/50
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFDBEAFE).withValues(alpha: 0.5),
          width: 1,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance,
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
                      'Bank Statement Requirements',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last 6 months from today',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildRequirementItem(Icons.calendar_today, 'Must be last 6 months'),
          const SizedBox(height: 16),
          _buildRequirementItem(Icons.lock, 'PDF password supported'),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE), // blue-100
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF334155), // slate-700
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequiredPeriodCard(BuildContext context) {
    final theme = Theme.of(context);
    final days = _statementEndDate!.difference(_calculatedStartDate!).inDays.abs();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE).withValues(alpha: 0.3), // red-50/30
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFCDD2).withValues(alpha: 0.3), // red-200/30
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
                  color: const Color(0xFFD32F2F), // red-600
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.event,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Required Statement Period',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFFB71C1C), // red-700
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFCDD2).withValues(alpha: 0.2),
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
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning,
                      color: Color(0xFFD32F2F),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'IMPORTANT',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD32F2F),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: const Color(0xFF475569),
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'From '),
                      TextSpan(
                        text: _formatDateWithYear(_calculatedStartDate!),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const TextSpan(text: ' to '),
                      TextSpan(
                        text: _formatDateWithYear(_statementEndDate!),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'you need to submit your bank statement',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFD32F2F),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE), // red-50
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule,
                        color: Color(0xFFD32F2F),
                        size: 12,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$days DAYS (≈6 MONTHS)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD32F2F),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadedPagesSection(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey.shade100,
          width: 1,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Uploaded Pages',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_pages.length} ${_pages.length == 1 ? 'page' : 'pages'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4), // emerald-50
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF22C55E), // emerald-600
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'READY',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF22C55E),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // PDF Preview Cards
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: List.generate(_pages.length, (index) {
              return _buildPdfCard(context, index);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfCard(BuildContext context, int index) {
    final theme = Theme.of(context);

    return Container(
      width: 160,
      height: 213, // aspect ratio 3:4
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // blue-50
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFDBEAFE), // blue-100
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.picture_as_pdf,
                  size: 60,
                  color: Color(0xFF3B82F6), // blue-500
                ),
                const SizedBox(height: 8),
                Text(
                  'PDF',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2563EB), // blue-600
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
          // Delete button
          Positioned(
            top: -4,
            right: -4,
            child: Material(
              color: const Color(0xFFEF4444), // red-500
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () => _removePage(index),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 28,
                  height: 28,
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
                    size: 14,
                  ),
                ),
              ),
            ),
          ),
          // Page number badge
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade800.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Page ${index + 1}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade100, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Change PDF Button
          if (_pages.isNotEmpty)
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: _uploadPdf,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.file_upload, color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Change PDF',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_pages.isNotEmpty) const SizedBox(height: 12),
          // Continue Button
          Material(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: _proceedToNext,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      const Color(0xFF0052CC), // royal-blue
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue to Salary Slips',
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
          // Indicator bar
          Container(
            width: 128,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyUploadState(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'Upload Bank Statement',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload PDF file (last 6 months)',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          Material(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: _uploadPdf,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Upload PDF',
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
          ),
        ],
      ),
    );
  }
}

