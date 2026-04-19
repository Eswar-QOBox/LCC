import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/submission_provider.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_progress_indicator.dart';
import '../widgets/preview_header_action.dart';
import '../widgets/prevent_close_on_back.dart';

class CoApplicantChoiceScreen extends StatelessWidget {
  const CoApplicantChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<SubmissionProvider>();
    final loanTypeParam = GoRouterState.of(context).uri.queryParameters['loanType'];
    final withCoApplicantParam =
        GoRouterState.of(context).uri.queryParameters['withCoApplicant'] == 'true';
    final normalizedLoanType = (loanTypeParam ?? '').trim();
    final isHomeOrCarEntry =
        normalizedLoanType == 'Home Loan' || normalizedLoanType == 'Car Loan';
    final hasLoanTypeFromSelection = normalizedLoanType.isNotEmpty;
    final selectedLoanType = isHomeOrCarEntry ? normalizedLoanType : 'Personal Loan';
    final backRoute = hasLoanTypeFromSelection
        ? AppRoutes.home
        : AppRoutes.step4BankStatement;

    return PreventCloseOnBack(
      onBack: () => context.go(backRoute),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'Co-applicant',
                icon: Icons.person_add_alt_1,
                showBackButton: true,
                onBackPressed: () => context.go(backRoute),
                showHomeButton: true,
                actions: const [
                  PreviewHeaderAction(backRoute: AppRoutes.coApplicantChoice),
                ],
              ),
              if (!hasLoanTypeFromSelection)
                const PremiumProgressIndicator(
                  currentStep: 5,
                  totalSteps: 10,
                  maxVisibleSteps: 7,
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PremiumCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.person_add_alt_1,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Applying alone or with a co-applicant?',
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'A co-applicant shares responsibility for the loan. We will collect their Aadhaar and PAN.',
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
                            _optionTile(
                              context,
                              icon: Icons.person,
                              title: 'Single applicant',
                              subtitle: 'I am applying alone',
                              selected:
                                  !provider.submission.hasCoApplicant && !withCoApplicantParam,
                              onTap: () {
                                provider.setHasCoApplicant(false);
                                if (hasLoanTypeFromSelection) {
                                  context.go(
                                    '${AppRoutes.instructions}?loanType=${Uri.encodeComponent(selectedLoanType)}',
                                  );
                                  return;
                                }
                                context.go(AppRoutes.step5_1SalarySlips);
                              },
                            ),
                            const SizedBox(height: 12),
                            _optionTile(
                              context,
                              icon: Icons.people,
                              title: 'With co-applicant',
                              subtitle: 'Joint application with another person',
                              selected: (provider.submission.hasCoApplicant ||
                                      withCoApplicantParam) &&
                                  (provider.submission.coApplicantFirmType == null),
                              onTap: () {
                                provider.setHasCoApplicant(true);
                                provider.setCoApplicantFirmType(null);
                                if (hasLoanTypeFromSelection) {
                                  context.go(
                                    '${AppRoutes.instructions}?loanType=${Uri.encodeComponent(selectedLoanType)}&withCoApplicant=true',
                                  );
                                  return;
                                }
                                context.go(AppRoutes.coApplicantAadhaar);
                              },
                            ),
                            if (normalizedLoanType == 'Car Loan') ...[
                              const SizedBox(height: 12),
                              _optionTile(
                                context,
                                icon: Icons.business,
                                title: 'Partnership Firm co-applicant',
                                subtitle: 'Firm PAN, GST, Partnership deed, ITR + Partners KYC',
                                selected: provider.submission.hasCoApplicant &&
                                    provider.submission.coApplicantFirmType == 'partnership',
                                onTap: () {
                                  provider.setHasCoApplicant(true);
                                  provider.setCoApplicantFirmType('partnership');
                                  context.go(
                                    '${AppRoutes.instructions}?loanType=${Uri.encodeComponent(selectedLoanType)}&withCoApplicant=true&coApplicantFirmType=partnership',
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              _optionTile(
                                context,
                                icon: Icons.apartment,
                                title: 'PVT LTD co-applicant',
                                subtitle: 'Firm PAN, GST, MOA, AOA, ITR + Authorized person KYC',
                                selected: provider.submission.hasCoApplicant &&
                                    provider.submission.coApplicantFirmType == 'pvt_limited',
                                onTap: () {
                                  provider.setHasCoApplicant(true);
                                  provider.setCoApplicantFirmType('pvt_limited');
                                  context.go(
                                    '${AppRoutes.instructions}?loanType=${Uri.encodeComponent(selectedLoanType)}&withCoApplicant=true&coApplicantFirmType=pvt_limited',
                                  );
                                },
                              ),
                            ],
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
      ),
    );
  }

  Widget _optionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: selected
          ? AppTheme.primaryColor.withValues(alpha: 0.1)
          : colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryColor
                  : colorScheme.outline.withValues(alpha: 0.2),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 28,
                color: selected ? AppTheme.primaryColor : colorScheme.onSurfaceVariant,
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
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AppTheme.primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}
