import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/submission_provider.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_progress_indicator.dart';
import '../widgets/premium_toast.dart';
import '../widgets/preview_header_action.dart';
import '../widgets/prevent_close_on_back.dart';

class PartnerCountScreen extends StatefulWidget {
  const PartnerCountScreen({super.key});

  @override
  State<PartnerCountScreen> createState() => _PartnerCountScreenState();
}

class _PartnerCountScreenState extends State<PartnerCountScreen> {
  // Number of *additional* partners (excluding the applicant).
  // Partnership can be 2 people total, so this can be 1.
  int _count = 1;

  @override
  void initState() {
    super.initState();
    final existing =
        context.read<SubmissionProvider>().submission.businessDocuments?.partnerCount;
    if (existing != null && existing >= 1) {
      _count = existing;
    }
  }

  void _submit() {
    if (_count < 1) {
      PremiumToast.showWarning(context, 'Partners must be at least 1');
      return;
    }
    context.read<SubmissionProvider>().setPartnerCount(_count);
    context.go('${AppRoutes.partnerAadhaar}?i=1');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PreventCloseOnBack(
      onBack: () => context.go(AppRoutes.step4BankStatement),
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Partners',
              icon: Icons.groups,
              showBackButton: true,
              onBackPressed: () => context.go(AppRoutes.step4BankStatement),
              showHomeButton: true,
              actions: const [
                PreviewHeaderAction(backRoute: AppRoutes.partnerCount),
              ],
            ),
            PremiumProgressIndicator(currentStep: 5, totalSteps: 10),
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
                                child: const Icon(Icons.groups, color: AppTheme.primaryColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'How many partners?',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'We will collect Aadhaar + PAN for each partner.',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colorScheme.outline.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: _count <= 1
                                      ? null
                                      : () => setState(() => _count -= 1),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      '$_count',
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _count >= 10
                                      ? null
                                      : () => setState(() => _count += 1),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Note: Partner KYC step only checks “uploaded or not”.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    PremiumButton(
                      label: 'Continue',
                      onPressed: _submit,
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
}

