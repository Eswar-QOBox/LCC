import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/premium_card.dart';
import '../utils/app_theme.dart';

class DemoApplication {
  final String id;
  final String loanType;
  final String loanAmount;
  final String status;
  final DateTime submittedDate;
  final IconData icon;

  DemoApplication({
    required this.id,
    required this.loanType,
    required this.loanAmount,
    required this.status,
    required this.submittedDate,
    required this.icon,
  });
}

class ApplicationsScreen extends StatelessWidget {
  const ApplicationsScreen({super.key});

  // Demo applications data
  static final List<DemoApplication> _demoApplications = [
    DemoApplication(
      id: 'APP-2024-001',
      loanType: 'Personal Loan',
      loanAmount: '₹5,00,000',
      status: 'pendingVerification',
      submittedDate: DateTime.now().subtract(const Duration(days: 2)),
      icon: Icons.person,
    ),
    DemoApplication(
      id: 'APP-2024-002',
      loanType: 'Home Loan',
      loanAmount: '₹25,00,000',
      status: 'approved',
      submittedDate: DateTime.now().subtract(const Duration(days: 15)),
      icon: Icons.home,
    ),
    DemoApplication(
      id: 'APP-2024-003',
      loanType: 'Car Loan',
      loanAmount: '₹8,50,000',
      status: 'pendingVerification',
      submittedDate: DateTime.now().subtract(const Duration(days: 5)),
      icon: Icons.directions_car,
    ),
    DemoApplication(
      id: 'APP-2024-004',
      loanType: 'Business Loan',
      loanAmount: '₹15,00,000',
      status: 'rejected',
      submittedDate: DateTime.now().subtract(const Duration(days: 30)),
      icon: Icons.business,
    ),
    DemoApplication(
      id: 'APP-2024-005',
      loanType: 'Education Loan',
      loanAmount: '₹3,00,000',
      status: 'approved',
      submittedDate: DateTime.now().subtract(const Duration(days: 45)),
      icon: Icons.school,
    ),
  ];

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
                          colors: [
                            colorScheme.primary,
                            colorScheme.secondary,
                          ],
                        ),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Applications',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'View and manage your applications',
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
                child: _demoApplications.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        children: [
                          // Empty State
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
                                  'No Applications Yet',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
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
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _demoApplications.length,
                        itemBuilder: (context, index) {
                          final application = _demoApplications[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildApplicationCard(context, application),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplicationCard(
    BuildContext context,
    DemoApplication application,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('dd MMM yyyy');

    // Get status color and text
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (application.status) {
      case 'approved':
        statusColor = AppTheme.successColor;
        statusText = 'Approved';
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = AppTheme.errorColor;
        statusText = 'Rejected';
        statusIcon = Icons.cancel;
        break;
      case 'pendingVerification':
      default:
        statusColor = AppTheme.warningColor;
        statusText = 'Verification Pending';
        statusIcon = Icons.verified_user;
        break;
    }

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
                child: Icon(
                  application.icon,
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
                      application.loanType,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      application.id,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusIcon,
                      color: statusColor,
                      size: 16,
                    ),
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
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  context,
                  icon: Icons.currency_rupee,
                  label: 'Loan Amount',
                  value: application.loanAmount,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem(
                  context,
                  icon: Icons.calendar_today,
                  label: 'Submitted',
                  value: dateFormat.format(application.submittedDate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
