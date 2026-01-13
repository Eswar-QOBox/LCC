import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_toast.dart';
import '../models/loan_application.dart';
import '../services/loan_application_service.dart';
import '../providers/application_provider.dart';
import 'package:provider/provider.dart';

class LoanScreen extends StatefulWidget {
  const LoanScreen({super.key});

  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen> {
  final LoanApplicationService _applicationService = LoanApplicationService();
  List<LoanApplication> _applications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch applications that are in progress or paused
      final allApps = await _applicationService.getApplications(
        status: 'all',
        limit: 50,
      );

      // Filter for in-progress, paused, or draft applications
      final inProgressApps = allApps
          .where((app) => app.isInProgress || app.isPaused || app.isDraft)
          .toList();

      setState(() {
        _applications = inProgressApps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createAndStartApplication(String loanType) async {
    try {
      // Create new application
      final application = await _applicationService.createApplication(
        loanType: loanType,
        status: 'in_progress',
        currentStep: 1,
      );

      // Set in ApplicationProvider
      if (mounted) {
        context.read<ApplicationProvider>().setApplication(application);
        context.go(AppRoutes.instructions);
      }
    } catch (e) {
      if (mounted) {
        PremiumToast.show(
          context,
          message: 'Failed to create application: ${e.toString()}',
          type: ToastType.error,
        );
      }
    }
  }

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
                          colors: [colorScheme.primary, colorScheme.secondary],
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
                  onTap: () => _createAndStartApplication('Personal Loan'),
                ),
                const SizedBox(height: 12),
                _buildLoanTypeButton(
                  context,
                  icon: Icons.directions_car,
                  title: 'Car Loan',
                  subtitle: 'Finance your vehicle',
                  color: AppTheme.infoColor,
                  onTap: () => _createAndStartApplication('Car Loan'),
                ),
                const SizedBox(height: 12),
                _buildLoanTypeButton(
                  context,
                  icon: Icons.home,
                  title: 'Home Loan',
                  subtitle: 'Buy or renovate your home',
                  color: AppTheme.successColor,
                  onTap: () => _createAndStartApplication('Home Loan'),
                ),
                const SizedBox(height: 12),
                _buildLoanTypeButton(
                  context,
                  icon: Icons.business,
                  title: 'Business Loan',
                  subtitle: 'Grow your business',
                  color: AppTheme.warningColor,
                  onTap: () => _createAndStartApplication('Business Loan'),
                ),
                const SizedBox(height: 12),
                _buildLoanTypeButton(
                  context,
                  icon: Icons.school,
                  title: 'Education Loan',
                  subtitle: 'Fund your education',
                  color: colorScheme.secondary,
                  onTap: () => _createAndStartApplication('Education Loan'),
                ),
                const SizedBox(height: 32),

                // My Applications Section
                Row(
                  children: [
                    Icon(Icons.folder, color: colorScheme.primary, size: 24),
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
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_error != null)
                  PremiumCard(
                    gradientColors: [
                      Colors.white,
                      AppTheme.errorColor.withValues(alpha: 0.05),
                    ],
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Error Loading Applications',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        PremiumButton(
                          label: 'Retry',
                          icon: Icons.refresh,
                          isPrimary: false,
                          onPressed: _loadApplications,
                        ),
                      ],
                    ),
                  )
                else if (_applications.isNotEmpty)
                  ..._applications.map(
                    (app) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildContinueApplicationCard(context, app),
                    ),
                  )
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
        gradientColors: [Colors.white, color.withValues(alpha: 0.05)],
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
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
              child: Icon(icon, color: Colors.white, size: 28),
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
    LoanApplication application,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get icon and color based on loan type
    IconData loanIcon;
    Color loanColor;
    switch (application.loanType) {
      case 'Personal Loan':
        loanIcon = Icons.person;
        loanColor = colorScheme.primary;
        break;
      case 'Car Loan':
        loanIcon = Icons.directions_car;
        loanColor = AppTheme.infoColor;
        break;
      case 'Home Loan':
        loanIcon = Icons.home;
        loanColor = AppTheme.successColor;
        break;
      case 'Business Loan':
        loanIcon = Icons.business;
        loanColor = AppTheme.warningColor;
        break;
      case 'Education Loan':
        loanIcon = Icons.school;
        loanColor = colorScheme.secondary;
        break;
      default:
        loanIcon = Icons.account_balance_wallet;
        loanColor = colorScheme.primary;
    }

    return PremiumCard(
      gradientColors: [Colors.white, loanColor.withValues(alpha: 0.05)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [loanColor, loanColor.withValues(alpha: 0.7)],
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
                child: Icon(loanIcon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.loanType,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      application.isPaused
                          ? 'Paused - Continue where you left off'
                          : 'Continue where you left off',
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
                Icon(Icons.info_outline, color: loanColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Last saved: ${_getStepName(application.currentStep)}',
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
          Row(
            children: [
              Expanded(
                child: PremiumButton(
                  label: application.isPaused
                      ? 'Continue'
                      : 'Continue Application',
                  icon: Icons.play_arrow_rounded,
                  isPrimary: true,
                  onPressed: () async {
                    // If paused, resume it first
                    if (application.isPaused) {
                      try {
                        final continued = await _applicationService
                            .continueApplication(application.id);
                        if (mounted) {
                          context.read<ApplicationProvider>().setApplication(
                            continued,
                          );
                          _loadApplications(); // Refresh list
                        }
                      } catch (e) {
                        if (mounted) {
                          PremiumToast.show(
                            context,
                            message:
                                'Failed to continue application: ${e.toString()}',
                            type: ToastType.error,
                          );
                        }
                        return;
                      }
                    } else {
                      // Load and set application in provider
                      if (mounted) {
                        context.read<ApplicationProvider>().setApplication(
                          application,
                        );
                      }
                    }
                    if (mounted) {
                      context.go(_getRouteForStep(application.currentStep));
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
