import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../utils/app_routes.dart';
import '../utils/app_strings.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_toast.dart';
import '../providers/submission_provider.dart';
import '../providers/application_provider.dart';
import '../services/loan_application_service.dart';
import '../models/loan_application.dart';
import '../utils/app_theme.dart';

class InstructionsScreen extends StatefulWidget {
  final String? loanType;
  
  const InstructionsScreen({super.key, this.loanType});

  @override
  State<InstructionsScreen> createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends State<InstructionsScreen> {
  bool _isCreatingApplication = false;
  final LoanApplicationService _applicationService = LoanApplicationService();

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
            // Top brand bar with logo + JSEE Solutions
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.03),
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
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/JSEE_icon.jpg',
                      height: 42,
                      width: 42,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'JSEE Solutions',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // In-body Application Guide header row
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.go(AppRoutes.home),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new,
                                size: 20,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Application Guide',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
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
                                  Icons.info_outline,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Text(
                                  'Process Overview',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'You will be guided through a step-by-step process to submit your documents for verification. Please ensure all documents are clear and valid.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                            ),
                            textAlign: TextAlign.justify,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    PremiumCard(
                      gradientColors: [
                        Colors.white,
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
                                  color: colorScheme.secondary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.folder_special,
                                  color: colorScheme.secondary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Required Documents',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildDocumentItem(
                            context,
                            icon: Icons.face,
                            title: 'Selfie/Photo',
                            description: 'Passport-style photo with white background',
                          ),
                          const SizedBox(height: 16),
                          _buildDocumentItem(
                            context,
                            icon: Icons.badge,
                            title: 'Aadhaar Card',
                            description: 'Front and back sides required',
                          ),
                          const SizedBox(height: 16),
                          _buildDocumentItem(
                            context,
                            icon: Icons.credit_card,
                            title: 'PAN Card',
                            description: 'Front side required',
                          ),
                          const SizedBox(height: 16),
                          _buildDocumentItem(
                            context,
                            icon: Icons.account_balance,
                            title: 'Bank Statement',
                            description: 'Last 6 months statement',
                          ),
                          const SizedBox(height: 16),
                          _buildDocumentItem(
                            context,
                            icon: Icons.person,
                            title: 'Personal Information',
                            description: 'Complete the personal data form',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    PremiumCard(
                      gradientColors: [
                        Colors.white,
                        colorScheme.tertiary.withValues(alpha: 0.02),
                      ],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.tertiary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.lightbulb_outline,
                                  color: colorScheme.tertiary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Instructions',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildInstructionItem(
                            context,
                            'Ensure all documents are clear and readable',
                          ),
                          const SizedBox(height: 12),
                          _buildInstructionItem(
                            context,
                            'Use good lighting when capturing photos',
                          ),
                          const SizedBox(height: 12),
                          _buildInstructionItem(
                            context,
                            'Remove any filters or editing from photos',
                          ),
                          const SizedBox(height: 12),
                          _buildInstructionItem(
                            context,
                            'If uploading PDFs, ensure they are not password protected or provide the password',
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Consumer<SubmissionProvider>(
                      builder: (context, provider, _) {
                        final termsAccepted = provider.termsAccepted;
                        return PremiumCard(
                          gradientColors: [
                            Colors.white,
                            colorScheme.primary.withValues(alpha: 0.02),
                          ],
                          child: Row(
                            children: [
                              Checkbox(
                                value: termsAccepted,
                                onChanged: (value) {
                                  provider.setTermsAccepted(value ?? false);
                                },
                                activeColor: colorScheme.primary,
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    context.push(AppRoutes.termsAndConditions);
                                  },
                                  child: RichText(
                                    text: TextSpan(
                                      style: theme.textTheme.bodyLarge,
                                      children: [
                                        const TextSpan(
                                          text: 'I accept the ',
                                        ),
                                        TextSpan(
                                          text: 'Terms & Conditions',
                                          style: theme.textTheme.bodyLarge?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                            decoration: TextDecoration.underline,
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
                      },
                    ),
                    const SizedBox(height: 24),
                    Consumer<SubmissionProvider>(
                      builder: (context, provider, _) {
                        final termsAccepted = provider.termsAccepted;
                        return PremiumButton(
                          label: _isCreatingApplication 
                              ? 'Creating Application...' 
                              : 'Start Submission',
                          icon: _isCreatingApplication 
                              ? Icons.hourglass_empty 
                              : Icons.arrow_forward_rounded,
                          isPrimary: termsAccepted && !_isCreatingApplication,
                          onPressed: (termsAccepted && !_isCreatingApplication)
                              ? () async {
                                  // Check for in-progress applications first
                                  try {
                                    final applications = await _applicationService.getApplications(
                                      status: 'all',
                                      limit: 100,
                                    );
                                    
                                    // Check if there's an in-progress application
                                    final inProgressApps = applications.where(
                                      (app) => app.isDraft || 
                                              app.isInProgress || 
                                              app.isPaused || 
                                              app.isSubmitted,
                                    ).toList();

                                    // If we found an in-progress application, show dialog
                                    if (inProgressApps.isNotEmpty && mounted) {
                                      _showInProgressDialog(context, inProgressApps.first);
                                      return;
                                    }
                                  } catch (e) {
                                    // Error fetching applications, continue with creating new one
                                    debugPrint('Error checking for in-progress applications: $e');
                                  }

                                  // If loan type is provided, create application first
                                  if (widget.loanType != null) {
                                    setState(() {
                                      _isCreatingApplication = true;
                                    });

                                    try {
                                      // Clear old draft data before creating new application
                                      final submissionProvider = context.read<SubmissionProvider>();
                                      await submissionProvider.clearDraft();
                                      // Reset submission provider state
                                      submissionProvider.resetSubmission();

                                      // Create new application with selected loan type
                                      final application = await _applicationService.createApplication(
                                        loanType: widget.loanType!,
                                        currentStep: 1,
                                        status: 'draft',
                                      );

                                      // Set application in provider
                                      if (mounted) {
                                        context.read<ApplicationProvider>().setApplication(application);
                                        // Navigate to step 1
                                        context.go(AppRoutes.step1Selfie);
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        PremiumToast.show(
                                          context,
                                          message: 'Failed to create application: ${e.toString()}',
                                          type: ToastType.error,
                                        );
                                        setState(() {
                                          _isCreatingApplication = false;
                                        });
                                      }
                                    }
                                  } else {
                                    // No loan type, just navigate (for existing flow)
                                    context.go(AppRoutes.step1Selfie);
                                  }
                                }
                              : () {
                                  if (!termsAccepted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Row(
                                          children: [
                                            Icon(Icons.warning_amber_rounded,
                                                color: Colors.white),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Please accept Terms & Conditions to continue',
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: AppTheme.warningColor,
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                },
                        );
                      },
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

  void _showInProgressDialog(BuildContext context, LoanApplication application) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: AppTheme.warningColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  AppStrings.applicationInProgressTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Message
                Text(
                  AppStrings.applicationInProgressMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Application details
                PremiumCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Loan Type: ${application.loanType}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppStrings.stepName(application.currentStep),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(AppStrings.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PremiumButton(
                        label: AppStrings.viewExistingApplication,
                        icon: Icons.arrow_forward,
                        isPrimary: true,
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          // Load application and navigate to the appropriate step
                          final appProvider = context.read<ApplicationProvider>();
                          appProvider.setApplication(application);
                          context.go(AppRoutes.getStepRoute(application.currentStep));
                        },
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

  Widget _buildDocumentItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.15),
                  colorScheme.secondary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle,
            size: 18,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

