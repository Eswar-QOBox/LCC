import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/app_routes.dart';
import '../utils/app_strings.dart';
import '../utils/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/premium_toast.dart';

class BusinessLoanTypeScreen extends StatelessWidget {
  const BusinessLoanTypeScreen({super.key});

  void _goToInstructions(BuildContext context, String businessLoanType) {
    context.go(
      '${AppRoutes.instructions}?loanType=${AppStrings.loanTypeBusiness}&businessLoanType=$businessLoanType',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Business Loan Type',
              icon: Icons.business,
              showBackButton: true,
              onBackPressed: () => context.go(AppRoutes.home),
              showHomeButton: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Business Type',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This helps us show the right document checklist.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _typeCard(
                      context,
                      title: 'Proprietor',
                      subtitle: 'Sole proprietor business',
                      icon: Icons.person,
                      iconColor: AppTheme.primaryColor,
                      onTap: () => _goToInstructions(context, 'proprietor'),
                      enabled: true,
                    ),
                    const SizedBox(height: 12),
                    _typeCard(
                      context,
                      title: 'Partnership',
                      subtitle: 'Two or more partners',
                      icon: Icons.groups,
                      iconColor: const Color(0xFF14B8A6),
                      onTap: () => _goToInstructions(context, 'partnership'),
                      enabled: true,
                    ),
                    const SizedBox(height: 12),
                    _typeCard(
                      context,
                      title: 'Pvt Limited',
                      subtitle: 'Private limited company (MOA & AOA)',
                      icon: Icons.apartment,
                      iconColor: const Color(0xFF7C3AED),
                      onTap: () => _goToInstructions(context, 'pvt_limited'),
                      enabled: true,
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

  Widget _typeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: enabled ? 0.9 : 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!enabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppTheme.warningColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      'Soon',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

