import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../widgets/auth_theme_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Upload Documents for Eligibility',
      description:
          'JSEE Solutions helps you securely upload and organize your documents in one place for loan eligibility verification. No more emails, prints or paperwork.',
      icon: Icons.upload_file,
      color: AppTheme.primaryColor,
    ),
    OnboardingPage(
      title: 'Safe & Organized',
      description:
          'Your documents are stored safely and in an organized way, and can be shared with partner institutions for eligibility review.',
      icon: Icons.lock_outline,
      color: AppTheme.infoColor,
    ),
    OnboardingPage(
      title: 'Track Submission Status',
      description:
          'See which documents are pending, what has been completed, and track your eligibility verification status without confusion.',
      icon: Icons.timeline,
      color: AppTheme.warningColor,
    ),
    OnboardingPage(
      title: 'EMI Calculator Built‑In',
      description:
          'Use the EMI calculator to quickly check your monthly payments. For planning only. Loans are from external institutions.',
      icon: Icons.calculate_outlined,
      color: AppTheme.successColor,
    ),
    OnboardingPage(
      title: 'Welcome to JSEE Solutions',
      description:
          'A simple and secure document upload platform for loan eligibility verification. Upload documents and use the EMI calculator to plan—eligibility and loans are through external institutions.',
      icon: Icons.verified_user,
      color: AppTheme.secondaryColor,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _skipToLogin() {
    context.go(AppRoutes.login);
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _skipToLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: AuthThemedBackground(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    const AuthLogoBadge(size: 44),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'JSEE Solutions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _skipToLogin,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.88),
                      ),
                      child: const Text('Skip'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _buildPage(_pages[index], theme);
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => _buildIndicator(index == _currentPage),
                  ),
                ),
                const SizedBox(height: 22),
                AuthGradientButton(
                  label: _currentPage == _pages.length - 1
                      ? 'Get Started'
                      : 'Next',
                  onPressed: _nextPage,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: AuthGlassCard(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.82),
                    AppTheme.secondaryColor.withValues(alpha: 0.36),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Icon(page.icon, size: 52, color: Colors.white),
            ),
            const SizedBox(height: 26),
            Text(
              page.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              page.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
                height: 1.45,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: const Text(
                'Secure • Guided • Fast',
                style: TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 7,
      width: isActive ? 26 : 9,
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              )
            : null,
        color: isActive ? null : Colors.white.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
