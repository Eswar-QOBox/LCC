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
    final isVerySmallScreen = screenWidth < 320; // Very small devices
    
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            if (index == 1) {
              _refreshPendingApplications();
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.primaryColor,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white.withValues(alpha: 0.7),
          showSelectedLabels: !isVerySmallScreen,
          showUnselectedLabels: !isVerySmallScreen,
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 10 : 11,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: isSmallScreen ? 10 : 11,
          ),
          iconSize: isSmallScreen ? 22 : 24,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home),
              activeIcon: const Icon(Icons.home),
              label: labels[0],
              tooltip: AppStrings.navHome,
            ),
            BottomNavigationBarItem(
              icon: _buildBadgeIcon(
                icon: Icons.folder_outlined,
                showDot: _hasPendingApplications,
              ),
              activeIcon: _buildBadgeIcon(
                icon: Icons.folder,
                showDot: _hasPendingApplications,
              ),
              label: labels[1],
              tooltip: AppStrings.navApplications,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.description_outlined),
              activeIcon: const Icon(Icons.description),
              label: labels[2],
              tooltip: AppStrings.navDocuments,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calculate_outlined),
              activeIcon: const Icon(Icons.calculate),
              label: labels[3],
              tooltip: AppStrings.navCalculator,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: const Icon(Icons.settings),
              label: labels[4],
              tooltip: AppStrings.navAccounts,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeIcon({
    required IconData icon,
    required bool showDot,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (showDot)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
