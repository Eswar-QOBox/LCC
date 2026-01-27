import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/loan_application.dart';
import '../services/loan_application_service.dart';
import '../utils/app_strings.dart';
import '../utils/app_theme.dart';
import 'loan_screen.dart';
import 'applications_screen.dart';
import 'settings_screen.dart';
import 'required_documents_screen.dart';
import 'loan_calculator_screen.dart';

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentIndex = 0; // Default to Home tab
  final LoanApplicationService _applicationService = LoanApplicationService();
  bool _hasPendingApplications = false;

  final List<Widget> _screens = [
    const LoanScreen(),
    const ApplicationsScreen(),
    const RequiredDocumentsScreen(),
    const LoanCalculatorScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _refreshPendingApplications();
  }

  Future<void> _refreshPendingApplications() async {
    try {
      final applications = await _applicationService.getApplications(
        status: 'all',
        limit: 50,
      );
      if (!mounted) return;
      final hasPending = applications.any(_isPendingApplication);
      setState(() {
        _hasPendingApplications = hasPending;
      });
    } catch (_) {
      // Ignore failures; keep last known state.
    }
  }

  bool _isPendingApplication(LoanApplication application) {
    return application.isDraft ||
        application.isInProgress ||
        application.isPaused ||
        application.isSubmitted;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360; // Small phones like iPhone SE
    
    // Use shorter labels for small screens
    final labels = isSmallScreen
        ? [
            'Home',
            'Apps',
            'Docs',
            'Calc',
            'Settings',
          ]
        : [
            AppStrings.navHome,
            AppStrings.navApplications,
            AppStrings.navDocuments,
            AppStrings.navCalculator,
            AppStrings.navAccounts,
          ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            padding: EdgeInsets.only(
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  context,
                  icon: Icons.home,
                  activeIcon: Icons.home,
                  label: labels[0],
                  isActive: _currentIndex == 0,
                  onTap: () => _setIndex(0),
                ),
                _buildNavItem(
                  context,
                  icon: Icons.assignment_outlined,
                  activeIcon: Icons.assignment,
                  label: labels[1],
                  isActive: _currentIndex == 1,
                  onTap: () => _setIndex(1),
                  showBadge: _hasPendingApplications,
                ),
                _buildNavItem(
                  context,
                  icon: Icons.folder_outlined,
                  activeIcon: Icons.folder,
                  label: labels[2],
                  isActive: _currentIndex == 2,
                  onTap: () => _setIndex(2),
                ),
                _buildNavItem(
                  context,
                  icon: Icons.calculate_outlined,
                  activeIcon: Icons.calculate,
                  label: labels[3],
                  isActive: _currentIndex == 3,
                  onTap: () => _setIndex(3),
                ),
                _buildNavItem(
                  context,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: labels[4],
                  isActive: _currentIndex == 4,
                  onTap: () => _setIndex(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (index == 1) {
      _refreshPendingApplications();
    }
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    bool showBadge = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isActive ? activeIcon : icon,
                    color: isActive
                        ? AppTheme.primaryColor
                        : colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                  if (showBadge)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.surface,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive
                      ? AppTheme.primaryColor
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
