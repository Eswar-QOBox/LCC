import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/submission_provider.dart';
import '../utils/app_routes.dart';
import '../utils/blob_helper.dart';
import '../widgets/platform_image.dart';
import '../widgets/step_progress_indicator.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_toast.dart';
import '../utils/app_theme.dart';

class Step4BankStatementScreen extends StatefulWidget {
  const Step4BankStatementScreen({super.key});

  @override
  State<Step4BankStatementScreen> createState() =>
      _Step4BankStatementScreenState();
}

class _Step4BankStatementScreenState extends State<Step4BankStatementScreen> {
  List<String> _pages = [];
  String? _pdfPassword;
  bool _isPdf = false;
  bool _isDraftSaved = false;
  bool _isSavingDraft = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SubmissionProvider>();
    _pages = List.from(provider.submission.bankStatement?.pages ?? []);
    _isPdf = provider.submission.bankStatement?.isPdf ?? false;
    _pdfPassword = provider.submission.bankStatement?.pdfPassword;
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
          _resetDraftState();
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
      _resetDraftState();
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
              decoration: const InputDecoration(
                labelText: 'PDF Password (if required)',
                border: OutlineInputBorder(),
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

  void _proceedToNext() {
    if (_pages.isNotEmpty) {
      context.go(AppRoutes.step5PersonalData);
    } else {
      PremiumToast.showWarning(
        context,
        'Please upload bank statement (last 6 months)',
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

  Future<void> _saveDraft() async {
    if (_isSavingDraft || _isDraftSaved) return;

    setState(() {
      _isSavingDraft = true;
    });

    final provider = context.read<SubmissionProvider>();
    
    // Save current state to provider
    if (_pages.isNotEmpty) {
      provider.setBankStatementPages(_pages, isPdf: _isPdf);
    }
    if (_pdfPassword != null && _pdfPassword!.isNotEmpty) {
      provider.setBankStatementPassword(_pdfPassword!);
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
                        Icons.account_balance,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Bank Statement',
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
                    onPressed: () => context.go(AppRoutes.step3Pan),
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
            StepProgressIndicator(currentStep: 4, totalSteps: 6),
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
                                  Icons.account_balance,
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
                                      'Bank Statement Requirements',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Last 6 months statement required',
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
                          _buildPremiumRequirement(context, Icons.calendar_today, 'Must be last 6 months'),
                          const SizedBox(height: 12),
                          _buildPremiumRequirement(context, Icons.lock_outline, 'PDF password supported'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_pages.isEmpty) ...[
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
                                Icons.description_outlined,
                                size: 64,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Upload Bank Statement',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload PDF file (last 6 months)',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 32),
                            PremiumButton(
                              label: 'Upload PDF',
                              icon: Icons.picture_as_pdf,
                              isPrimary: true,
                              onPressed: _uploadPdf,
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      PremiumCard(
                        gradientColors: [
                          Colors.white,
                          colorScheme.primary.withValues(alpha: 0.02),
                        ],
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
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_pages.length} ${_pages.length == 1 ? 'page' : 'pages'}',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.successColor.withValues(alpha: 0.2),
                                        AppTheme.successColor.withValues(alpha: 0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, size: 18, color: AppTheme.successColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Ready',
                                        style: TextStyle(
                                          color: AppTheme.successColor,
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
                        itemCount: _pages.length,
                        itemBuilder: (context, index) {
                          return _buildPremiumPageCard(context, index);
                        },
                      ),
                      const SizedBox(height: 20),
                      PremiumButton(
                        label: 'Change PDF',
                        icon: Icons.picture_as_pdf,
                        isPrimary: false,
                        onPressed: _uploadPdf,
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

  Widget _buildPremiumPageCard(BuildContext context, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
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
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.5),
        child: Stack(
          children: [
            _isPdf && index == 0
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.1),
                          colorScheme.secondary.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.picture_as_pdf, size: 40, color: colorScheme.primary),
                          const SizedBox(height: 8),
                          Text(
                            'PDF',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : PlatformImage(imagePath: _pages[index], fit: BoxFit.cover),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _removePage(index),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.errorColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  'Page ${index + 1}',
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
    );
  }
}

