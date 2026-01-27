import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_routes.dart';
import '../utils/app_strings.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_toast.dart';
import '../widgets/slide_to_confirm.dart';
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
      backgroundColor: const Color(0xFFF4F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and logo
            _buildHeader(context),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and subtitle
                    Text(
                      'Application Guide',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Follow these steps for a smooth loan application.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Process Overview Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                'i',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Process Overview',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'You will be guided through a step-by-step process to submit your documents for verification. Please ensure all documents are clear and valid. At the final step, slide to submit to confirm your application.',
                                  textAlign: TextAlign.justify,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.8),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Required Documents Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              color: colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Required Documents',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDocumentItem(
                          context,
                          icon: Icons.face,
                          title: 'Selfie/Photo',
                          description: 'Passport-style photo with white background',
                          iconColor: const Color(0xFF7C3AED),
                        ),
                        const SizedBox(height: 12),
                        _buildDocumentItem(
                          context,
                          icon: Icons.badge,
                          title: 'Aadhaar Card',
                          description: 'Front and back sides required',
                          iconColor: AppTheme.successColor,
                        ),
                        const SizedBox(height: 12),
                        _buildDocumentItem(
                          context,
                          icon: Icons.credit_card,
                          title: 'PAN Card',
                          description: 'Front side required',
                          iconColor: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(height: 12),
                        _buildDocumentItem(
                          context,
                          icon: Icons.account_balance,
                          title: 'Bank Statement',
                          description: 'Last 6 months statement',
                          iconColor: AppTheme.primaryColor,
                        ),
                        const SizedBox(height: 12),
                        _buildDocumentItem(
                          context,
                          icon: Icons.description,
                          title: 'Salary Slips',
                          description: 'Last 3 months for income verification',
                          iconColor: const Color(0xFF0D9488),
                        ),
                        const SizedBox(height: 12),
                        _buildDocumentItem(
                          context,
                          icon: Icons.person,
                          title: 'Personal Information',
                          description: 'Complete the personal data form',
                          iconColor: const Color(0xFF7C3AED),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Instructions Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Instructions',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInstructionItem(
                          context,
                          'Ensure all documents are clear and readable.',
                        ),
                        const SizedBox(height: 12),
                        _buildInstructionItem(
                          context,
                          'Use good lighting when capturing photos.',
                        ),
                        const SizedBox(height: 12),
                        _buildInstructionItem(
                          context,
                          'Remove any filters or editing from photos.',
                        ),
                        const SizedBox(height: 12),
                        _buildInstructionItem(
                          context,
                          'If uploading PDFs, ensure they are not password protected or provide the password.',
                        ),
                        const SizedBox(height: 12),
                        _buildInstructionItem(
                          context,
                          'Slide to submit at the final step to confirm your application.',
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Terms & Conditions
                    Consumer<SubmissionProvider>(
                      builder: (context, provider, _) {
                        final termsAccepted = provider.termsAccepted;
                        return Row(
                          children: [
                            Checkbox(
                              value: termsAccepted,
                              onChanged: (value) {
                                provider.setTermsAccepted(value ?? false);
                              },
                              activeColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
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
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Consumer<SubmissionProvider>(
                      builder: (context, provider, _) {
                        final termsAccepted = provider.termsAccepted;
                        final canStart = termsAccepted && !_isCreatingApplication;
                        return SlideToConfirm(
                          label: _isCreatingApplication
                              ? 'Creating Application...'
                              : 'Slide to start',
                          enabled: canStart,
                          onSubmitted: canStart
                              ? () async {
                                  // Since login is bypassed, skip API calls and navigate directly
                                  try {
                                    // Clear old draft data before starting new submission
                                    final submissionProvider =
                                        context.read<SubmissionProvider>();
                                    await submissionProvider.clearDraft();
                                    // Reset submission provider state
                                    submissionProvider.resetSubmission();

                                    // Set loan type in submission provider if provided
                                    if (widget.loanType != null) {
                                      debugPrint(
                                        'Starting submission for loan type: ${widget.loanType}',
                                      );
                                    }

                                    // Navigate directly to step 1 (bypassing API calls)
                                    if (mounted) {
                                      context.go(AppRoutes.step1Selfie);
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      debugPrint('Error starting submission: $e');
                                      // Even if there's an error, try to navigate
                                      context.go(AppRoutes.step1Selfie);
                                    }
                                  }
                                }
                              : null,
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
                  'Application is in progress. Please talk to our agent.',
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
                        label: 'Call to our agents',
                        icon: Icons.phone,
                        isPrimary: true,
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _openPhoneDialer(context);
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

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(AppRoutes.home),
            color: colorScheme.onSurface,
          ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Image.asset(
                'assets/JSEE_icon.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'JSEE Solutions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: colorScheme.onSurfaceVariant,
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
            textAlign: TextAlign.left,
          ),
        ),
      ],
    );
  }

  Future<void> _openPhoneDialer(BuildContext context) async {
    // Replace with your support phone number
    const String phoneNumber = '+916303429063'; // +91 63034 29063
    final Uri phoneUrl = Uri.parse('tel:$phoneNumber');

    try {
      await launchUrl(phoneUrl);
    } catch (e) {
      debugPrint('Error opening phone dialer: $e');
      if (context.mounted) {
        PremiumToast.showError(
          context,
          AppStrings.assistancePhoneError,
        );
      }
    }
  }
}

