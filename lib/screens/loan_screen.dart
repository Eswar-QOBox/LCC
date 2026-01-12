import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';

class InProgressApplication {
  final String loanType;
  final int currentStep;
  final IconData icon;
  final Color color;

  InProgressApplication({
    required this.loanType,
    required this.currentStep,
    required this.icon,
    required this.color,
  });
}

class LoanScreen extends StatelessWidget {
  const LoanScreen({super.key});

  // Demo in-progress applications
  static final List<InProgressApplication> _demoInProgressApps = [
    InProgressApplication(
      loanType: 'Education Loan',
      currentStep: 3,
      icon: Icons.school,
      color: AppTheme.infoColor,
    ),
  ];

  String _getRouteForStep(int step) {
    switch (step) {
      case 1:
        return AppRoutes.step1Selfie;
      case 2:
        return AppRoutes.step2Aadhaar;
      case 3:
        return AppRoutes.step3Pan;
      case 4:
        return AppRoutes.step4BankStatement;
      case 5:
        return AppRoutes.step5PersonalData;
      case 6:
        return AppRoutes.step6Preview;
      default:
        return AppRoutes.instructions;
    }
  }

  String _getStepName(int step) {
    switch (step) {
      case 1:
        return 'Step 1: Selfie';
      case 2:
        return 'Step 2: Aadhaar Card';
      case 3:
        return 'Step 3: PAN Card';
      case 4:
        return 'Step 4: Bank Statement';
      case 5:
        return 'Step 5: Personal Data';
      case 6:
        return 'Step 6: Preview';
      default:
        return 'Start Application';
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.secondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Loan Application',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Start your loan application process',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Loan Types Section
                Text(
                  'Choose Loan Type',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildLoanTypeButton(
                  context,
                  icon: Icons.person,
                  title: 'Personal Loan',
                  subtitle: 'For personal expenses',
                  color: colorScheme.primary,
                  onTap: () => context.go(AppRoutes.instructions),
                ),
                const SizedBox(height: 12),
                _buildLoanTypeButton(
                  context,
                  icon: Icons.directions_car,
                  title: 'Car Loan',
                  subtitle: 'Finance your vehicle',
                  color: AppTheme.infoColor,
                  onTap: () => context.go(AppRoutes.instructions),
                ),
                const SizedBox(height: 12),
                _buildLoanTypeButton(
                  context,
                  icon: Icons.home,
                  title: 'Home Loan',
                  subtitle: 'Buy or renovate your home',
                  color: AppTheme.successColor,
                  onTap: () => context.go(AppRoutes.instructions),
                ),
                const SizedBox(height: 12),
                _buildLoanTypeButton(
                  context,
                  icon: Icons.business,
                  title: 'Business Loan',
                  subtitle: 'Grow your business',
                  color: AppTheme.warningColor,
                  onTap: () => context.go(AppRoutes.instructions),
                ),
                const SizedBox(height: 12),
                _buildLoanTypeButton(
                  context,
                  icon: Icons.school,
                  title: 'Education Loan',
                  subtitle: 'Fund your education',
                  color: colorScheme.secondary,
                  onTap: () => context.go(AppRoutes.instructions),
                ),
                const SizedBox(height: 32),

                // My Applications Section
                Row(
                  children: [
                    Icon(
                      Icons.folder,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'My Applications',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_demoInProgressApps.isNotEmpty)
                  ..._demoInProgressApps.map((app) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildContinueApplicationCard(
                          context,
                          app.loanType,
                          app.currentStep,
                          app.icon,
                          app.color,
                        ),
                      ))
                else
                  PremiumCard(
                    gradientColors: [
                      Colors.white,
                      colorScheme.primary.withValues(alpha: 0.03),
                    ],
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No Active Applications',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your submitted loan applications will appear here',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Quick Info Cards
                Row(
                  children: [
                    Expanded(
                      child: PremiumCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: AppTheme.successColor,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Easy Process',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Simple steps',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PremiumCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.security,
                              color: colorScheme.primary,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Secure',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Data protected',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PremiumCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: AppTheme.warningColor,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Quick',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Fast approval',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoanTypeButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: PremiumCard(
        padding: const EdgeInsets.all(20),
        gradientColors: [
          Colors.white,
          color.withValues(alpha: 0.05),
        ],
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color,
                    color.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
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
            Icon(
              Icons.arrow_forward_ios,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueApplicationCard(
    BuildContext context,
    String loanType,
    int currentStep,
    IconData loanIcon,
    Color loanColor,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PremiumCard(
      gradientColors: [
        Colors.white,
        loanColor.withValues(alpha: 0.05),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      loanColor,
                      loanColor.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: loanColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  loanIcon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loanType,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Continue where you left off',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: loanColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: loanColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Last saved: ${_getStepName(currentStep)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: loanColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PremiumButton(
            label: 'Continue Application',
            icon: Icons.play_arrow_rounded,
            isPrimary: true,
            onPressed: () {
              context.go(_getRouteForStep(currentStep));
            },
          ),
        ],
      ),
    );
  }
}
