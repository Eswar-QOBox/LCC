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
import '../utils/app_theme.dart';
import '../models/document_submission.dart';
import 'package:intl/intl.dart';

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
    // Salary slips are optional, so we don't require them to exist
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
        final files = _slipItems.map((item) => XFile(item.path)).toList();
        final uploadResults = await _fileUploadService.uploadSalarySlips(files);

        // Save to step4BankStatement or create a separate field
        // Since salary slips are part of step 5, we can include them in step5PersonalData
        // or keep them in step4BankStatement as additional documents
        await appProvider.updateApplication(
          step4BankStatement: {
            'salarySlips': _slipItems.map((item) => item.path).toList(),
            'salarySlipItems': _slipItems.map((item) => {
              'path': item.path,
              'slipDate': item.slipDate?.toIso8601String(),
            }).toList(),
            'salarySlipsIsPdf': _isPdf,
            'salarySlipsPassword': _pdfPassword,
            'salarySlipsUploaded': uploadResults,
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
    );

    if (result != null && result.files.isNotEmpty) {
      String path;
      
      if (kIsWeb) {
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
        path = createBlobUrl(bytes, mimeType: 'application/pdf');
      } else {
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
          _slipItems = [SalarySlipItem(path: path)];
          _isPdf = true;
          _resetDraftState();
        });
        context
            .read<SubmissionProvider>()
            .setSalarySlips([path], isPdf: true);
        _showPasswordDialogIfNeeded();
      }
    }
  }

  void _removeSlip(int index) {
    context.read<SubmissionProvider>().removeSalarySlip(index);
    setState(() {
      _slipItems.removeAt(index);
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
        ));
        _isPdf = false;
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
                    color: colorScheme.shadow.withValues(alpha: 0.05),
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
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Salary Slips',
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
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    onPressed: () => context.go(AppRoutes.step4BankStatement),
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
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
                              label: _isPdf ? 'Change PDF' : 'Upload PDF',
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
              child: _isPdf && index == 0
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
                  : PlatformImage(imagePath: slipItem.path, fit: BoxFit.cover),
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
