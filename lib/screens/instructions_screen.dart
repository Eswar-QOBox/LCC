import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../utils/app_routes.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';
import '../providers/submission_provider.dart';
import '../utils/app_theme.dart';

class InstructionsScreen extends StatelessWidget {
  const InstructionsScreen({super.key});

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
            AppBar(
              title: const Text('Document Submission'),
              elevation: 0,
              backgroundColor: Colors.transparent,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                  child: Row(
                                    children: [
                                      Text(
                                        'I accept the ',
                                        style: theme.textTheme.bodyLarge,
                                      ),
                                      Text(
                                        'Terms & Conditions',
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
                          label: 'Start Submission',
                          icon: Icons.arrow_forward_rounded,
                          isPrimary: termsAccepted,
                          onPressed: termsAccepted
                              ? () {
                                  context.go(AppRoutes.step1Selfie);
                                }
                              : () {
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
                                },
                        );
                      },
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

