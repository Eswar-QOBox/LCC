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
import '../widgets/step_progress_indicator.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_toast.dart';
import '../widgets/app_header.dart';
import '../utils/app_theme.dart';
import '../models/document_submission.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '../utils/api_config.dart';

class Step5_1SalarySlipsScreen extends StatefulWidget {
  const Step5_1SalarySlipsScreen({super.key});

  @override
  State<Step5_1SalarySlipsScreen> createState() =>
      _Step5_1SalarySlipsScreenState();
}

class _Step5_1SalarySlipsScreenState extends State<Step5_1SalarySlipsScreen> {
  final FileUploadService _fileUploadService = FileUploadService();
  final ImagePicker _imagePicker = ImagePicker();
  List<SalarySlipItem> _slipItems = [];
  String? _pdfPassword;
  bool _isPdf = false;
  bool _isDraftSaved = false;
  bool _isSavingDraft = false;
  bool _isSaving = false;
  bool _hasSyncedWithProvider = false;
  String? _authToken;
  List<bool> _slipFailures = [];
  List<Uint8List?> _slipBytes = [];

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
    _loadDraftData();
    
    // Load existing data from backend and sync with provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingData();
      // Sync with provider after draft loads (in case it loads after initState)
      _syncWithProvider();
    });
  }

  void _loadDraftData() {
    final provider = context.read<SubmissionProvider>();
    _slipItems = List<SalarySlipItem>.from(
      provider.submission.salarySlips?.slipItems ?? []
    );
    _isPdf = provider.submission.salarySlips?.isPdf ?? false;
    _pdfPassword = provider.submission.salarySlips?.pdfPassword;
  }

  void _syncWithProvider() {
    if (_hasSyncedWithProvider) return; // Only sync once
    
    final provider = context.read<SubmissionProvider>();
    final salarySlips = provider.submission.salarySlips;
    if (salarySlips != null) {
      final currentSlipItems = List<SalarySlipItem>.from(salarySlips.slipItems);
      final currentIsPdf = salarySlips.isPdf;
      final currentPassword = salarySlips.pdfPassword;
      
      // Update local state if provider has different data (from draft)
      if (currentSlipItems.length != _slipItems.length || 
          currentIsPdf != _isPdf || 
          currentPassword != _pdfPassword) {
        if (mounted) {
          setState(() {
            _slipItems = currentSlipItems;
            _isPdf = currentIsPdf;
            _pdfPassword = currentPassword;
            _hasSyncedWithProvider = true;
          });
        }
      } else {
        _hasSyncedWithProvider = true;
      }
    } else {
      _hasSyncedWithProvider = true;
    }
  }

  Future<void> _loadExistingData() async {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication) return;

    final application = appProvider.currentApplication!;
    if (application.step4BankStatement != null) {
      final stepData = application.step4BankStatement as Map<String, dynamic>;
      
      if (stepData['salarySlipItems'] != null) {
        
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

        final itemsList = stepData['salarySlipItems'] as List;
        final loadedItems = itemsList.map((item) {
          final map = item as Map<String, dynamic>;
          final rawPath = map['path'] as String?;
          final fullPath = buildFullUrl(rawPath) ?? rawPath ?? '';
          return SalarySlipItem(
            path: fullPath,
            slipDate: map['slipDate'] != null ? DateTime.parse(map['slipDate']) : null,
            isPdf: fullPath.toLowerCase().endsWith('.pdf') || (stepData['salarySlipsIsPdf'] == true),
          );
        }).toList();

        if (loadedItems.isNotEmpty) {
          setState(() {
            _slipItems = loadedItems;
            _isPdf = stepData['salarySlipsIsPdf'] ?? false;
            _pdfPassword = stepData['salarySlipsPassword'];
             _hasSyncedWithProvider = true;
             
            // Initialize failure/bytes lists
            _slipFailures = List.filled(_slipItems.length, false);
            _slipBytes = List.filled(_slipItems.length, null);
          });
          
          // Verify images asynchronously if auth token is available
          if (accessToken != null && !_isPdf) {
            for (int i = 0; i < _slipItems.length; i++) {
              final item = _slipItems[i];
              if (item.path.startsWith('http')) {
                _verifySlip(item.path, i, accessToken);
              }
            }
          }

          // Update provider
          final provider = context.read<SubmissionProvider>();
          final paths = loadedItems.map((item) => item.path).toList();
          provider.setSalarySlips(paths, isPdf: _isPdf);
          if (_pdfPassword != null) {
            provider.setSalarySlipsPassword(_pdfPassword!);
          }
          
          // Update dates
          for (int i = 0; i < loadedItems.length; i++) {
            if (loadedItems[i].slipDate != null) {
              provider.updateSalarySlipDate(i, loadedItems[i].slipDate!);
            }
          }
        }
      }
    }
  }

  Future<void> _verifySlip(String url, int index, String token) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (index >= _slipFailures.length) return; // Bounds check

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';
        final isLikelyImage = contentType.startsWith('image/');
        final bytes = response.bodyBytes;
        if (isLikelyImage && _isValidImageBytes(bytes)) {
          setState(() {
            _slipBytes[index] = bytes;
            _slipFailures[index] = false;
          });
        } else {
          setState(() { _slipFailures[index] = true; });
        }
      } else {
        setState(() { _slipFailures[index] = true; });
      }
    } catch (e) {
      if (mounted && index < _slipFailures.length) {
        setState(() { _slipFailures[index] = true; });
      }
    }
  }


   Future<void> _saveToBackend() async {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Only save if slips are uploaded (this step is optional)
      if (_slipItems.isNotEmpty) {
        // 1. Separate local files and remote URLs
        final localItems = _slipItems.where((item) => !item.path.startsWith('http')).toList();
        final remoteItems = _slipItems.where((item) => item.path.startsWith('http')).toList();

        List<Map<String, dynamic>> finalUploadedFiles = [];

        // 2. Handle remote URLs (preserve existing metadata)
        // Note: Salary slips are stored in step4BankStatement in the backend
        if (remoteItems.isNotEmpty) {
          final currentApp = appProvider.currentApplication;
          if (currentApp?.step4BankStatement != null) {
            final stepData = currentApp!.step4BankStatement as Map<String, dynamic>;
            final existingUploads = (stepData['salarySlipsUploaded'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ?? [];
            
            for (final upload in existingUploads) {
              final url = upload['url'] as String?;
              if (url != null && 
                  remoteItems.any((item) => item.path.contains(url) || url.contains(item.path)) &&
                  !finalUploadedFiles.any((f) => f['url'] == url)) {
                finalUploadedFiles.add(upload);
              }
            }
          }
        }

        // 3. Upload new local files
        if (localItems.isNotEmpty) {
          final files = localItems.map((item) => XFile(item.path)).toList();
          final newUploadResults = await _fileUploadService.uploadSalarySlips(files);
          finalUploadedFiles.addAll(newUploadResults);
        }

        // Save to step4BankStatement or create a separate field
        // Since salary slips are part of step 5, we can include them in step5PersonalData
        // or keep them in step4BankStatement as additional documents
        await appProvider.updateApplication(
          step4BankStatement: {
            'salarySlips': _slipItems.map((item) => item.path).toSet().toList(), // De-duplicate paths
            'salarySlipItems': _slipItems.map((item) => {
              'path': item.path, // Mixed paths
              'slipDate': item.slipDate?.toIso8601String(),
            }).toList(),
            'salarySlipsIsPdf': _isPdf,
            'salarySlipsPassword': _pdfPassword,
            'salarySlipsUploaded': finalUploadedFiles,
          },
        );
      }

      if (mounted) {
        PremiumToast.showSuccess(
          context,
          'Salary slips saved successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        PremiumToast.showError(
          context,
          'Failed to save salary slips: ${e.toString()}',
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


  Future<void> _uploadPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true, // Allow multiple PDF selection
    );

    if (result != null && result.files.isNotEmpty) {
      final List<SalarySlipItem> newSlipItems = [];
      
      for (final file in result.files) {
        String? path;
        
        if (kIsWeb) {
          final bytes = file.bytes;
          if (bytes == null) {
            continue; // Skip this file if bytes are null
          }
          path = createBlobUrl(bytes, mimeType: 'application/pdf');
        } else {
          if (file.path == null) {
            continue; // Skip this file if path is null
          }
          path = file.path!;
        }
        
        // At this point, path is guaranteed to be non-null
        // For each PDF, show date picker
        final DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          helpText: 'Select Payslip Date',
          fieldLabelText: 'Payslip Date (Date, Month, Year)',
          fieldHintText: 'DD/MM/YYYY',
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primaryColor,
                ),
              ),
              child: child!,
            );
          },
        );
        
        newSlipItems.add(SalarySlipItem(
          path: path,
          slipDate: pickedDate,
          isPdf: true, // Mark as PDF
        ));
      }
      
      if (mounted && newSlipItems.isNotEmpty) {
        final provider = context.read<SubmissionProvider>();
        
        // Get current count before adding
        final currentCount = _slipItems.length;
        
        setState(() {
          _slipItems.addAll(newSlipItems);
          _isPdf = true;
          // Extend fail/byte lists
          _slipFailures.addAll(List.filled(newSlipItems.length, false));
          _slipBytes.addAll(List.filled(newSlipItems.length, null));
          _resetDraftState();
        });
        
        // Update provider with all new slip items
        for (int i = 0; i < newSlipItems.length; i++) {
          final item = newSlipItems[i];
          provider.addSalarySlip(item.path, slipDate: item.slipDate, isPdf: item.isPdf);
          if (item.slipDate != null) {
            provider.updateSalarySlipDate(currentCount + i, item.slipDate!);
          }
        }
        
        _showPasswordDialogIfNeeded();
        
        PremiumToast.showSuccess(
          context,
          '${newSlipItems.length} PDF${newSlipItems.length > 1 ? 's' : ''} added successfully!',
        );
      }
    }
  }

  void _removeSlip(int index) {
    context.read<SubmissionProvider>().removeSalarySlip(index);
    setState(() {
      _slipItems.removeAt(index);
      if (index < _slipFailures.length) {
        _slipFailures.removeAt(index);
        _slipBytes.removeAt(index);
      }
      _resetDraftState();
    });
  }

  Future<void> _captureFromCamera() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (image != null && mounted) {
      await _addSlipWithDate(image.path);
    }
  }

  Future<void> _selectFromGallery() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image != null && mounted) {
      await _addSlipWithDate(image.path);
    }
  }

  Future<void> _addSlipWithDate(String path) async {
    // Show date picker dialog
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Payslip Date',
      fieldLabelText: 'Payslip Date (Date, Month, Year)',
      fieldHintText: 'DD/MM/YYYY',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (mounted) {
      setState(() {
        _slipItems.add(SalarySlipItem(
          path: path,
          slipDate: pickedDate,
          isPdf: false, // Images are not PDFs
        ));
        _isPdf = false;
        // Add to fail/byte lists
        _slipFailures.add(false);
        _slipBytes.add(null);
        _resetDraftState();
      });
      
      // Update provider
      final provider = context.read<SubmissionProvider>();
      provider.addSalarySlip(path, slipDate: pickedDate);
      if (pickedDate != null) {
        provider.updateSalarySlipDate(_slipItems.length - 1, pickedDate);
      }
    }
  }

  Future<void> _updateSlipDate(int index) async {
    final currentDate = _slipItems[index].slipDate ?? DateTime.now();
    
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Payslip Date',
      fieldLabelText: 'Payslip Date (Date, Month, Year)',
      fieldHintText: 'DD/MM/YYYY',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      setState(() {
        _slipItems[index].slipDate = pickedDate;
        _resetDraftState();
      });
      context.read<SubmissionProvider>().updateSalarySlipDate(index, pickedDate);
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
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () {
              final password = passwordController.text.trim();
              if (password.isNotEmpty) {
                setState(() {
                  _pdfPassword = password;
                });
                context.read<SubmissionProvider>().setSalarySlipsPassword(password);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _resetDraftState() {
    if (_isDraftSaved) {
      setState(() {
        _isDraftSaved = false;
      });
    }
  }

  Future<void> _saveDraft() async {
    if (_isSavingDraft || _isDraftSaved) return;

    setState(() {
      _isSavingDraft = true;
    });

    final provider = context.read<SubmissionProvider>();
    
    if (_slipItems.isNotEmpty) {
      final paths = _slipItems.map((item) => item.path).toList();
      provider.setSalarySlips(paths, isPdf: _isPdf);
      // Update dates in provider
      for (int i = 0; i < _slipItems.length; i++) {
        if (_slipItems[i].slipDate != null) {
          provider.updateSalarySlipDate(i, _slipItems[i].slipDate!);
        }
      }
    }
    if (_pdfPassword != null && _pdfPassword!.isNotEmpty) {
      provider.setSalarySlipsPassword(_pdfPassword!);
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

  Future<void> _proceedToNext() async {
    // Salary slips are optional, so we can proceed even if empty
    // But if slips are uploaded, save them
    if (_slipItems.isNotEmpty && !_isSaving) {
      await _saveToBackend();
    }
    if (mounted) {
      context.go(AppRoutes.step5PersonalData);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider to trigger rebuilds when draft loads
    context.watch<SubmissionProvider>();
    
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
              colorScheme.surface,
            ],
          ),
        ),
        child: Column(
          children: [
            // Consistent Header
            AppHeader(
              title: 'Salary Slips',
              icon: Icons.receipt_long,
              showBackButton: true,
              onBackPressed: () => context.go(AppRoutes.step4BankStatement),
              showHomeButton: true,
            ),
            StepProgressIndicator(currentStep: 5, totalSteps: 6),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PremiumCard(
                      gradientColors: [
                        colorScheme.surface,
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
                                  Icons.receipt_long,
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
                                      'Upload Salary Slips',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Upload your salary slips for income verification',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildPremiumRequirement(context, Icons.description, 'Upload salary slips for last 3 months'),
                          const SizedBox(height: 12),
                          _buildPremiumRequirement(context, Icons.calendar_today, 'Please specify date, month and year for each payslip'),
                          const SizedBox(height: 12),
                          _buildPremiumRequirement(context, Icons.lock_outline, 'PDF password supported'),
                          const SizedBox(height: 12),
                          _buildPremiumRequirement(context, Icons.add_photo_alternate, 'Multiple payslips can be uploaded'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_slipItems.isEmpty)
                      _buildEmptyState(context)
                    else ...[
                      PremiumCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.successColor,
                                        AppTheme.successColor.withValues(alpha: 0.7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, size: 18, color: Colors.white),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${_slipItems.length} Salary Slip${_slipItems.length > 1 ? 's' : ''} Uploaded',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: _slipItems.length,
                        itemBuilder: (context, index) {
                          return _buildPremiumSlipCard(context, index);
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: PremiumButton(
                              label: 'Add Image',
                              icon: Icons.add_photo_alternate,
                              isPrimary: false,
                              onPressed: () => _showImageSourceDialog(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PremiumButton(
                              label: 'Add PDF',
                              icon: Icons.picture_as_pdf,
                              isPrimary: false,
                              onPressed: _uploadPdf,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_pdfPassword != null) ...[
                      const SizedBox(height: 24),
                      PremiumCard(
                        gradientColors: [
                          AppTheme.accentColor.withValues(alpha: 0.1),
                          AppTheme.accentColor.withValues(alpha: 0.05),
                        ],
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.lock, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PDF Password Protected',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.accentColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Password: ${'●' * _pdfPassword!.length}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
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
                    PremiumButton(
                      label: 'Continue to Personal Data',
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

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PremiumCard(
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'No Salary Slips Uploaded',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload your salary slips to continue',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: PremiumButton(
                  label: 'Camera',
                  icon: Icons.camera_alt,
                  isPrimary: false,
                  onPressed: _captureFromCamera,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PremiumButton(
                  label: 'Gallery',
                  icon: Icons.photo_library,
                  isPrimary: false,
                  onPressed: _selectFromGallery,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PremiumButton(
            label: 'Upload PDF',
            icon: Icons.picture_as_pdf,
            isPrimary: true,
            onPressed: _uploadPdf,
          ),
        ],
      ),
    );
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.of(context).pop();
                _captureFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _selectFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumSlipCard(BuildContext context, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final slipItem = _slipItems[index];
    final dateFormat = DateFormat('dd MMM yyyy'); // Clear date format: date, month, year
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.15),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              color: colorScheme.surface,
              child: slipItem.isPdf
                  ? Center(
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
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ((slipItem.path.startsWith('http') && (_authToken == null || (index < _slipFailures.length && _slipFailures[index])))
                        ? Center(child: (index < _slipFailures.length && _slipFailures[index]) 
                            ? const Icon(Icons.broken_image, color: Colors.grey) 
                            : const CircularProgressIndicator())
                        : PlatformImage(
                        imagePath: slipItem.path,
                        imageBytes: (index < _slipBytes.length) ? _slipBytes[index] : null,
                        fit: BoxFit.cover,
                        headers: _authToken != null ? {'Authorization': 'Bearer $_authToken'} : null,
                      )),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
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
                  icon: const Icon(Icons.close, color: Colors.white, size: 16),
                  onPressed: () => _removeSlip(index),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.8),
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          slipItem.slipDate != null
                              ? dateFormat.format(slipItem.slipDate!)
                              : 'Tap to set date',
                          style: TextStyle(
                            color: slipItem.slipDate != null 
                                ? Colors.white 
                                : Colors.orange.shade300,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _updateSlipDate(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: slipItem.slipDate != null
                            ? AppTheme.successColor.withValues(alpha: 0.9)
                            : AppTheme.warningColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        slipItem.slipDate != null
                            ? 'Date Set ✓'
                            : 'Set Date',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
