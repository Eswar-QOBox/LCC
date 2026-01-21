import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/app_routes.dart';
import '../utils/app_strings.dart';
import '../utils/app_theme.dart';
import '../models/loan_application.dart';
import '../services/loan_application_service.dart';
import '../providers/application_provider.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';
import '../widgets/skeleton_box.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> with SingleTickerProviderStateMixin {
  final LoanApplicationService _applicationService = LoanApplicationService();
  List<LoanApplication> _applications = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;
  int _selectedTabIndex = 0; // 0: Applied, 1: Approved, 2: Incomplete

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
    _loadApplications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apps = await _applicationService.getApplications(
        status: 'all',
        limit: 100,
      );
      
      setState(() {
        _applications = apps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
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
              Container(
                color: colorScheme.primary,
                padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.folder,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            AppStrings.applicationsTitle,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Tabs
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: colorScheme.primary,
                        labelColor: colorScheme.primary,
                        unselectedLabelColor: colorScheme.onSurfaceVariant,
                        labelStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        tabs: const [
                          Tab(text: AppStrings.tabApplied),
                          Tab(text: AppStrings.tabApproved),
                          Tab(text: AppStrings.tabIncomplete),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _error != null
                        ? ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              PremiumCard(
                                gradientColors: [
                                  Colors.white,
                                  AppTheme.errorColor.withValues(alpha: 0.05),
                                ],
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 64,
                                      color: AppTheme.errorColor,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      AppStrings.errorLoadingApplications,
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
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
                                      label: AppStrings.retry,
                                      icon: Icons.refresh,
                                      isPrimary: false,
                                      onPressed: _loadApplications,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              // Applied Tab (Submitted/In Progress)
                              _buildApplicationsList(
                                context,
                                _getAppliedApplications(),
                              ),
                              // Approved Tab
                              _buildApplicationsList(
                                context,
                                _getApprovedApplications(),
                              ),
                              // Incomplete Tab (Draft)
                              _buildApplicationsList(
                                context,
                                _getIncompleteApplications(),
                              ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleApplicationTap(
    BuildContext context,
    LoanApplication application,
  ) async {
    // Only allow navigation for incomplete (draft) applications
    if (!application.isDraft) {
      return;
    }

    try {
      // Show loading indicator
      if (!context.mounted) return;
      
      // Load the application using the provider
      final appProvider = context.read<ApplicationProvider>();
      await appProvider.loadApplication(application.id);
      
      if (!context.mounted) return;
      
      // Navigate to the appropriate step
      context.go(AppRoutes.getStepRoute(application.currentStep));
    } catch (e) {
      if (!context.mounted) return;
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load application: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Widget _buildApplicationCard(
    BuildContext context,
    LoanApplication application,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('dd MMM yyyy');
    final isIncomplete = application.isDraft;

    // Get icon and color based on loan type
    IconData loanIcon;
    Color loanColor;
    switch (application.loanType) {
      case AppStrings.loanTypePersonal:
        loanIcon = Icons.person;
        loanColor = colorScheme.primary;
        break;
      case AppStrings.loanTypeCar:
        loanIcon = Icons.directions_car;
        loanColor = AppTheme.infoColor;
        break;
      case AppStrings.loanTypeHome:
        loanIcon = Icons.home;
        loanColor = AppTheme.successColor;
        break;
      case AppStrings.loanTypeBusiness:
        loanIcon = Icons.business;
        loanColor = AppTheme.warningColor;
        break;
      case AppStrings.loanTypeEducation:
        loanIcon = Icons.school;
        loanColor = colorScheme.secondary;
        break;
      case AppStrings.loanTypeMortgage:
        loanIcon = Icons.home_work;
        loanColor = const Color(0xFF7C3AED);
        break;
      case AppStrings.loanTypeProperty:
        loanIcon = Icons.business_center;
        loanColor = const Color(0xFF14B8A6);
        break;
      case AppStrings.loanTypeEmergency:
        loanIcon = Icons.emergency;
        loanColor = const Color(0xFFDC2626);
        break;
      default:
        loanIcon = Icons.account_balance_wallet;
        loanColor = colorScheme.primary;
    }

    // Get status information
    Color statusColor;
    IconData statusIcon;
    String statusDescription;

    if (application.isApproved) {
      statusColor = AppTheme.successColor;
      statusIcon = Icons.check_circle;
      statusDescription = AppStrings.statusRepaymentScheduled;
    } else if (application.isSubmitted) {
      statusColor = AppTheme.warningColor;
      statusIcon = Icons.pending_actions;
      statusDescription = AppStrings.statusUnderReview;
    } else if (application.isDraft) {
      statusColor = colorScheme.onSurfaceVariant;
      statusIcon = Icons.edit;
      statusDescription = AppStrings.statusIncomplete;
    } else if (application.isPaused) {
      statusColor = AppTheme.warningColor;
      statusIcon = Icons.pause_circle;
      statusDescription = AppStrings.statusContinue;
    } else {
      statusColor = AppTheme.infoColor;
      statusIcon = Icons.hourglass_empty;
      statusDescription = AppStrings.statusInProgress;
    }

    return InkWell(
      onTap: isIncomplete
          ? () => _handleApplicationTap(context, application)
          : null,
      borderRadius: BorderRadius.circular(16),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Status Badge Row
          Row(
            children: [
              // Status Icon Badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Status Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusDescription,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (application.isApproved && application.submittedAt != null)
                      Text(
                        'Next installment on ${dateFormat.format(application.submittedAt!.add(const Duration(days: 30)))}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    else if (application.submittedAt != null)
                      Text(
                        'Submitted on ${dateFormat.format(application.submittedAt!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Text(
                        'Created on ${dateFormat.format(application.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              // Loan Type Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [loanColor, loanColor.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(loanIcon, color: Colors.white, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Loan Type Name
          Text(
            application.loanType,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ID: ${application.applicationId}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          
          // Loan Details Grid
          if (application.loanAmount != null || application.isApproved)
            Row(
              children: [
                if (application.loanAmount != null)
                  Expanded(
                    child: _buildDetailItem(
                      context,
                      label: AppStrings.loanAmountLabel,
                      value: '₹${_formatAmount(application.loanAmount!)}',
                    ),
                  ),
                if (application.loanAmount != null && application.isApproved)
                  const SizedBox(width: 12),
                if (application.isApproved)
                  Expanded(
                    child: _buildDetailItem(
                      context,
                      label: AppStrings.interestLabel,
                      value: '12.5%', // Default or from API
                    ),
                  ),
              ],
            ),
          if (application.loanAmount != null && application.isApproved) const SizedBox(height: 12),
          if (application.isApproved)
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    context,
                    label: AppStrings.tenureLabel,
                    value: '60 month', // Default or from API
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailItem(
                    context,
                    label: AppStrings.emiLabel,
                    value: application.loanAmount != null
                        ? '₹${_calculateEMI(application.loanAmount!, 12.5, 60)}'
                        : 'N/A',
                  ),
                ),
              ],
            ),
          if (!application.isApproved && !application.isDraft) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: loanColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: loanColor, size: 18),
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
          ],
          if (isIncomplete) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app,
                    color: colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap to continue application',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: colorScheme.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  String _getStepName(int step) {
    return AppStrings.stepName(step);
  }

  String _calculateEMI(double principal, double rate, int months) {
    if (rate == 0) return principal.toStringAsFixed(0);
    final monthlyRate = rate / 12 / 100;
    final emi = principal * monthlyRate * pow(1 + monthlyRate, months) / 
                (pow(1 + monthlyRate, months) - 1);
    return emi.toStringAsFixed(0);
  }

  Widget _buildDetailItem(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  List<LoanApplication> _getAppliedApplications() {
    return _applications.where((app) {
      return app.isSubmitted || app.isInProgress || app.isPaused;
    }).toList();
  }

  List<LoanApplication> _getApprovedApplications() {
    return _applications.where((app) => app.isApproved).toList();
  }

  List<LoanApplication> _getIncompleteApplications() {
    return _applications.where((app) => app.isDraft).toList();
  }

  Widget _buildApplicationsList(BuildContext context, List<LoanApplication> applications) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (applications.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          PremiumCard(
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.noApplications,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.applicationsEmptyMessage(_selectedTabIndex),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                PremiumButton(
                  label: AppStrings.startApplication,
                  icon: Icons.add_circle_outline,
                  isPrimary: true,
                  onPressed: () => context.go(
                    '${AppRoutes.instructions}?loanType=${AppStrings.loanTypePersonal}',
                  ),
                ),
                const SizedBox(height: 8),
                PremiumButton(
                  label: AppStrings.refresh,
                  icon: Icons.refresh,
                  isPrimary: false,
                  onPressed: _loadApplications,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadApplications,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: applications.length,
        itemBuilder: (context, index) {
          final application = applications[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildApplicationCard(context, application),
          );
        },
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  Widget _buildLoadingState() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: List.generate(
        4,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  children: [
                    SkeletonBox(width: 40, height: 40),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(height: 14),
                          SizedBox(height: 8),
                          SkeletonBox(width: 140, height: 12),
                        ],
                      ),
                    ),
                    SkeletonBox(width: 48, height: 48),
                  ],
                ),
                SizedBox(height: 16),
                SkeletonBox(width: 160, height: 16),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 36)),
                    SizedBox(width: 12),
                    Expanded(child: SkeletonBox(height: 36)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
