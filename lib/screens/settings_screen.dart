import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../widgets/premium_card.dart';
import '../widgets/skeleton_box.dart';
import '../providers/submission_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../models/loan_application.dart';
import '../services/loan_application_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LoanApplicationService _applicationService = LoanApplicationService();
  List<LoanApplication> _previousLoans = [];
  bool _isLoadingLoans = true;
  String? _loansError;

  @override
  void initState() {
    super.initState();
    _loadPreviousLoans();
  }

  Future<void> _loadPreviousLoans() async {
    setState(() {
      _isLoadingLoans = true;
      _loansError = null;
    });

    try {
      final apps = await _applicationService.getApplications(
        status: 'all',
        limit: 50,
      );
      
      // Filter only submitted and approved loans (excluding drafts)
      final previousLoans = apps.where((app) => 
        app.isSubmitted || app.isApproved || app.isRejected
      ).toList();
      
      // Sort by most recent first
      previousLoans.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      setState(() {
        _previousLoans = previousLoans;
        _isLoadingLoans = false;
      });
    } catch (e) {
      setState(() {
        _loansError = e.toString();
        _isLoadingLoans = false;
      });
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
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
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
                        Icons.settings,
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
                            'Settings',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage your app preferences',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    // Profile Section
                    Consumer<SubmissionProvider>(
                      builder: (context, provider, _) {
                        final personalData = provider.submission.personalData;
                        return PremiumCard(
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
                                          colorScheme.primary,
                                          colorScheme.secondary,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Profile',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              if (personalData != null &&
                                  (personalData.nameAsPerAadhaar != null ||
                                      personalData.mobileNumber != null ||
                                      personalData.personalEmailId != null))
                                ..._buildProfileFields(context, personalData)
                              else
                                _buildEmptyProfile(context),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Previous Loans Section
                    _buildPreviousLoansSection(context),
                    const SizedBox(height: 16),

                    // App Settings
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'App Preferences',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSettingItem(
                            context,
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            subtitle: 'Manage notification preferences',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Support
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Support',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSettingItem(
                            context,
                            icon: Icons.help_outline,
                            title: 'Help & Support',
                            subtitle: 'Get help and contact support',
                            onTap: () {},
                          ),
                          const Divider(height: 32),
                          _buildSettingItem(
                            context,
                            icon: Icons.info_outline,
                            title: 'About',
                            subtitle: 'App version and information',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Account
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSettingItem(
                            context,
                            icon: Icons.logout,
                            title: 'Logout',
                            subtitle: 'Sign out of your account',
                            onTap: () => _handleLogout(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: colorScheme.primary, size: 20),
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
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildProfileFields(BuildContext context, dynamic personalData) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return [
      if (personalData.nameAsPerAadhaar != null &&
          personalData.nameAsPerAadhaar!.isNotEmpty)
        _buildProfileItem(
          context,
          icon: Icons.person_outline,
          label: 'Name',
          value: personalData.nameAsPerAadhaar!,
        ),
      if (personalData.mobileNumber != null &&
          personalData.mobileNumber!.isNotEmpty) ...[
        const SizedBox(height: 16),
        _buildProfileItem(
          context,
          icon: Icons.phone_outlined,
          label: 'Phone Number',
          value: personalData.mobileNumber!,
        ),
      ],
      if (personalData.personalEmailId != null &&
          personalData.personalEmailId!.isNotEmpty) ...[
        const SizedBox(height: 16),
        _buildProfileItem(
          context,
          icon: Icons.email_outlined,
          label: 'Email',
          value: personalData.personalEmailId!,
        ),
      ],
      if (personalData.dateOfBirth != null) ...[
        const SizedBox(height: 16),
        _buildProfileItem(
          context,
          icon: Icons.calendar_today_outlined,
          label: 'Date of Birth',
          value: dateFormat.format(personalData.dateOfBirth!),
        ),
      ],
      if (personalData.panNo != null && personalData.panNo!.isNotEmpty) ...[
        const SizedBox(height: 16),
        _buildProfileItem(
          context,
          icon: Icons.badge_outlined,
          label: 'PAN Number',
          value: personalData.panNo!,
        ),
      ],
      if (personalData.residenceAddress != null &&
          personalData.residenceAddress!.isNotEmpty) ...[
        const SizedBox(height: 16),
        _buildProfileItem(
          context,
          icon: Icons.home_outlined,
          label: 'Address',
          value: personalData.residenceAddress!,
        ),
      ],
      if (personalData.occupation != null &&
          personalData.occupation!.isNotEmpty) ...[
        const SizedBox(height: 16),
        _buildProfileItem(
          context,
          icon: Icons.work_outline,
          label: 'Occupation',
          value: personalData.occupation!,
        ),
      ],
    ];
  }

  Widget _buildProfileItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyProfile(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Icon(
          Icons.person_outline,
          size: 48,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          'No Profile Information',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Complete a loan application to see your profile information here',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(
          'Logout',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: theme.textTheme.bodyMedium,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext loadingContext) =>
            const Center(child: CircularProgressIndicator()),
      );

      try {
        await authProvider.logout();

        if (context.mounted) {
          // Close loading dialog
          Navigator.of(context).pop();

          // Navigate to login screen
          context.go(AppRoutes.login);
        }
      } catch (e) {
        if (context.mounted) {
          // Close loading dialog
          Navigator.of(context).pop();

          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to logout: ${e.toString()}'),
              backgroundColor: colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildPreviousLoansSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PremiumCard(
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
                      colorScheme.primary,
                      colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.history,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Previous Loans',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_isLoadingLoans && _loansError == null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_previousLoans.length}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingLoans)
            _buildLoansLoadingState()
          else if (_loansError != null)
            _buildLoansErrorState(context)
          else if (_previousLoans.isEmpty)
            _buildNoLoansState(context)
          else
            _buildLoansList(context),
        ],
      ),
    );
  }

  Widget _buildLoansLoadingState() {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SkeletonBox(width: 40, height: 40),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(height: 14),
                        SizedBox(height: 6),
                        SkeletonBox(width: 120, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
              if (index < 2) ...[
                SizedBox(height: 12),
                Divider(height: 1),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoansErrorState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Icon(
          Icons.error_outline,
          size: 48,
          color: colorScheme.error,
        ),
        const SizedBox(height: 12),
        Text(
          'Failed to load loans',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _loansError!,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _loadPreviousLoans,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildNoLoansState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Icon(
          Icons.folder_open_outlined,
          size: 48,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          'No Previous Loans',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your loan history will appear here once you submit applications',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoansList(BuildContext context) {
    // Show only the first 5 loans to keep the profile clean
    final displayLoans = _previousLoans.take(5).toList();
    
    return Column(
      children: [
        ...displayLoans.asMap().entries.map((entry) {
          final index = entry.key;
          final loan = entry.value;
          return Column(
            children: [
              _buildLoanItem(context, loan),
              if (index < displayLoans.length - 1) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
              ],
            ],
          );
        }),
        if (_previousLoans.length > 5) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_previousLoans.length - 5} more loans available in Applications tab',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoanItem(BuildContext context, LoanApplication loan) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('dd MMM yyyy');

    // Get status information
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (loan.isApproved) {
      statusColor = AppTheme.successColor;
      statusIcon = Icons.check_circle;
      statusText = 'Approved';
    } else if (loan.isRejected) {
      statusColor = AppTheme.errorColor;
      statusIcon = Icons.cancel;
      statusText = 'Rejected';
    } else if (loan.isSubmitted) {
      statusColor = AppTheme.warningColor;
      statusIcon = Icons.pending;
      statusText = 'Under Review';
    } else {
      statusColor = AppTheme.infoColor;
      statusIcon = Icons.hourglass_empty;
      statusText = 'In Progress';
    }

    // Get loan type icon
    IconData loanIcon;
    Color loanColor;
    switch (loan.loanType) {
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [loanColor, loanColor.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(loanIcon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      loan.loanType,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'ID: ${loan.applicationId}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (loan.loanAmount != null) ...[
                    Icon(
                      Icons.currency_rupee,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    Text(
                      _formatAmount(loan.loanAmount!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    loan.submittedAt != null
                        ? dateFormat.format(loan.submittedAt!)
                        : dateFormat.format(loan.updatedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
