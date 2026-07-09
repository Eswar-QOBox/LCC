import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/app_theme_mode.dart';
import '../widgets/auth_theme_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _orbitController;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Upload Documents for Eligibility',
      description:
          'JSEE Solutions helps you securely upload and organize your documents in one place for loan eligibility verification. No more emails, prints or paperwork.',
      icon: Icons.upload_file,
    ),
    OnboardingPage(
      title: 'Safe & Organized',
      description:
          'Your documents are stored safely and in an organized way, and can be shared with partner institutions for eligibility review.',
      icon: Icons.lock_outline,
    ),
    OnboardingPage(
      title: 'Track Submission Status',
      description:
          'See which documents are pending, what has been completed, and track your eligibility verification status without confusion.',
      icon: Icons.timeline,
    ),
    OnboardingPage(
      title: 'EMI Calculator Built‑In',
      description:
          'Use the EMI calculator to quickly check your monthly payments. For planning only. Loans are from external institutions.',
      icon: Icons.calculate_outlined,
    ),
    OnboardingPage(
      title: 'Welcome to JSEE Solutions',
      description:
          'A simple and secure document upload platform for loan eligibility verification. Upload documents and use the EMI calculator to plan—eligibility and loans are through external institutions.',
      icon: Icons.verified_user,
    ),
  ];

  MercotraceOnboardingSlideVisual get _visual =>
      MercotraceOnboardingSlideVisual
          .slides[_currentPage % MercotraceOnboardingSlideVisual.slides.length];

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _orbitController.dispose();
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

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = _visual;

    return Scaffold(
      backgroundColor: AppTheme.mercotraceSlate950,
      body: MercotraceMarketingBackground(
        visual: v,
        animated: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentPage > 0)
                          _CircleChromeButton(
                            onPressed: _prevPage,
                            child: const Icon(
                              Icons.chevron_left_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          )
                        else
                          const SizedBox(width: 40),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ValueListenableBuilder<ThemeMode>(
                              valueListenable: appThemeModeNotifier,
                              builder: (context, mode, _) {
                                final isDark = mode == ThemeMode.dark;
                                return _CircleChromeButton(
                                  onPressed: () {
                                    appThemeModeNotifier.value = isDark
                                        ? ThemeMode.light
                                        : ThemeMode.dark;
                                  },
                                  child: Icon(
                                    isDark
                                        ? Icons.light_mode_rounded
                                        : Icons.dark_mode_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _skipToLogin,
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    Colors.white.withValues(alpha: 0.8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text(
                                'Skip',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      itemCount: _pages.length,
                      itemBuilder: (context, index) {
                        return _buildSlideContent(
                          context,
                          theme,
                          _pages[index],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        final active = i == _currentPage;
                        return Padding(
                          padding: EdgeInsets.only(
                            right: i < _pages.length - 1 ? 8 : 0,
                          ),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _pageController.animateToPage(
                                i,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 8,
                              width: active ? 32 : 8,
                              decoration: BoxDecoration(
                                color: active
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: AuthLightCtaButton(
                      label: _currentPage == _pages.length - 1
                          ? 'Get Started'
                          : 'Next',
                      onPressed: _nextPage,
                      height: 56,
                      cornerRadius: 16,
                      labelAndIconColor: AppTheme.twBlue600,
                      labelFontSize: 18,
                      labelFontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(
                    height: math.max(
                      12,
                      MediaQuery.of(context).padding.bottom,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildSlideContent(
    BuildContext context,
    ThemeData theme,
    OnboardingPage page,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                _MercotraceHeroIcon(
                  icon: page.icon,
                  orbitAnimation: _orbitController,
                ),
                const SizedBox(height: 32),
                Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ) ??
                      const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Text(
                    page.description,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 17,
                          height: 1.55,
                          color: Colors.white.withValues(alpha: 0.9),
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ) ??
                        TextStyle(
                          fontSize: 17,
                          height: 1.55,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CircleChromeButton extends StatelessWidget {
  const _CircleChromeButton({
    required this.onPressed,
    required this.child,
  });

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.2),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _MercotraceHeroIcon extends StatelessWidget {
  const _MercotraceHeroIcon({
    required this.icon,
    required this.orbitAnimation,
  });

  final IconData icon;
  final Animation<double> orbitAnimation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.28),
                  blurRadius: 40,
                  spreadRadius: 12,
                ),
              ],
            ),
          ),
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 112,
                height: 112,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.4),
                        Colors.white.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                  child: Icon(icon, size: 40, color: Colors.white),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: orbitAnimation,
            builder: (context, child) {
              final ang = orbitAnimation.value * 2 * math.pi;
              final x = math.sin(ang) * 44;
              final y = -math.cos(ang) * 44;
              return Transform.translate(
                offset: Offset(x, y),
                child: child,
              );
            },
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}
