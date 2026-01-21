import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/submission_provider.dart';
import '../providers/application_provider.dart';
import '../services/pdf_generation_service.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_toast.dart';
import '../utils/app_theme.dart';
import '../utils/app_routes.dart';
import 'package:go_router/go_router.dart';

class PdfDownloadScreen extends StatefulWidget {
  const PdfDownloadScreen({super.key});
  @override
  State<PdfDownloadScreen> createState() => _PdfDownloadScreenState();
}

class _PdfDownloadScreenState extends State<PdfDownloadScreen> {
  final PdfGenerationService _pdfService = PdfGenerationService();
  bool _isGenerating = false;
  bool _useSampleData = false; // Use real data by default for production

  Future<void> _generatePdf() async {
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final submissionProvider = context.read<SubmissionProvider>();
      final applicationProvider = context.read<ApplicationProvider>();

      await _pdfService.generateApplicationPdf(
        context: context,
        submissionProvider: submissionProvider,
        applicationProvider: applicationProvider,
        useSampleData: _useSampleData,
      );

      if (mounted) {
        PremiumToast.showSuccess(
          context,
          'PDF generated and ready to download!',
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to generate PDF';
        final errorStr = e.toString().toLowerCase();
        
        // Provide user-friendly error messages
        if (errorStr.contains('isolate') || errorStr.contains('spawn')) {
          errorMessage = 'PDF generation encountered a system error. Please try again or restart the app.';
        } else if (errorStr.contains('permission') || errorStr.contains('access')) {
          errorMessage = 'Permission denied. Please grant storage permissions and try again.';
        } else if (errorStr.contains('network') || errorStr.contains('connection')) {
          errorMessage = 'Network error. Please check your connection and try again.';
        } else {
          errorMessage = 'Failed to generate PDF: ${e.toString().replaceFirst('Exception: ', '')}';
        }
        
        PremiumToast.showError(
          context,
          errorMessage,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final submissionProvider = context.watch<SubmissionProvider>();
    final submission = submissionProvider.submission;

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
            // App Bar
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
                        Icons.picture_as_pdf,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Download PDF',
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
                foregroundColor: colorScheme.onSurface,
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
                    onPressed: () => context.go(AppRoutes.submissionSuccess),
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Card
                    PremiumCard(
                      gradientColors: [
                        AppTheme.primaryColor.withValues(alpha: 0.1),
                        AppTheme.secondaryColor.withValues(alpha: 0.05),
                      ],
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryColor,
                                  AppTheme.secondaryColor,
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.picture_as_pdf,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Download Your Application',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Generate a PDF summary of your loan application',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // What's Included Section
                    PremiumCard(
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
                                  Icons.checklist,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'What\'s Included',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildIncludedItem(
                            context, 
                            'Personal Information', 
                            _useSampleData || submission.personalData != null,
                            isSample: _useSampleData && submission.personalData == null,
                          ),
                          _buildIncludedItem(
                            context, 
                            'Selfie', 
                            _useSampleData || submission.selfiePath != null,
                            isSample: _useSampleData && submission.selfiePath == null,
                          ),
                          _buildIncludedItem(
                            context, 
                            'Aadhaar Card', 
                            _useSampleData || submission.aadhaar?.isComplete == true,
                            isSample: _useSampleData && submission.aadhaar?.isComplete != true,
                          ),
                          _buildIncludedItem(
                            context, 
                            'PAN Card', 
                            _useSampleData || submission.pan?.isComplete == true,
                            isSample: _useSampleData && submission.pan?.isComplete != true,
                          ),
                          _buildIncludedItem(
                            context, 
                            'Bank Statement', 
                            _useSampleData || submission.bankStatement?.isComplete == true,
                            isSample: _useSampleData && submission.bankStatement?.isComplete != true,
                          ),
                          _buildIncludedItem(
                            context, 
                            'Salary Slips', 
                            _useSampleData || submission.salarySlips?.isComplete == true,
                            isSample: _useSampleData && submission.salarySlips?.isComplete != true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sample Data Toggle
                    PremiumCard(
                      gradientColors: [
                        Colors.orange.withValues(alpha: 0.05),
                        Colors.orange.withValues(alpha: 0.02),
                      ],
                      child: Row(
                        children: [
                          Icon(
                            Icons.science,
                            color: Colors.orange.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Use Sample Data',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Toggle to use sample data for testing',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _useSampleData,
                            onChanged: (value) {
                              setState(() {
                                _useSampleData = value;
                              });
                            },
                            activeColor: Colors.orange,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Generate Button
                    PremiumButton(
                      label: _isGenerating ? 'Generating PDF...' : 'Generate & Download PDF',
                      icon: Icons.download,
                      isLoading: _isGenerating,
                      onPressed: _isGenerating ? null : _generatePdf,
                    ),
                    const SizedBox(height: 16),
                    
                    // Info Card
                    PremiumCard(
                      gradientColors: [
                        Colors.blue.withValues(alpha: 0.05),
                        Colors.blue.withValues(alpha: 0.02),
                      ],
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'The PDF will contain a summary of your application data. Document files are stored securely on our servers.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildIncludedItem(BuildContext context, String label, bool isIncluded, {bool isSample = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isIncluded 
                ? (isSample 
                    ? Colors.orange.withValues(alpha: 0.1)
                    : AppTheme.successColor.withValues(alpha: 0.1))
                : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncluded 
                ? (isSample ? Icons.science : Icons.check_circle)
                : Icons.cancel,
              color: isIncluded 
                ? (isSample ? Colors.orange : AppTheme.successColor)
                : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isIncluded ? Colors.black87 : Colors.grey,
                      decoration: isIncluded ? null : TextDecoration.lineThrough,
                      fontWeight: isIncluded ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSample)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Sample',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
