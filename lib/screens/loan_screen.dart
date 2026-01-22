import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_routes.dart';
import '../utils/app_strings.dart';
import '../utils/app_theme.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_toast.dart';
import '../widgets/skeleton_box.dart';

class LoanScreen extends StatefulWidget {
  const LoanScreen({super.key});

  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen> {
  bool _isLoading = true;
  late PageController _promoPageController;
  int _currentPromoIndex = 0;
  Timer? _autoScrollTimer;
  Timer? _resumeScrollTimer;
  bool _isUserScrolling = false;
  static const int _initialPage = 1000; // Large number for infinite scroll
  static const Duration _autoScrollDuration = Duration(seconds: 3);
  static const Duration _resumeScrollDelay = Duration(seconds: 5);

  final List<_PromoCardData> _promoCards = const [
    _PromoCardData(
      title: 'Quick Personal Loans',
      subtitle: 'Get approved in 24 hours',
      ctaText: 'Apply Now',
      imagePath: 'assets/money.jpg',
      gradientColors: [Color(0xFF2196F3), Color(0xFF1976D2)],
    ),
    _PromoCardData(
      title: 'Secure & Safe',
      subtitle: 'Bank-level encryption for your data',
      ctaText: 'Learn More',
      imagePath: 'assets/Secure.jpg',
      gradientColors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
    ),
    _PromoCardData(
      title: 'Low Interest Rates',
      subtitle: 'Starting from 8.5% per annum',
      ctaText: 'Check Rates',
      imagePath: 'assets/Intrest Rate.jpg',
      gradientColors: [Color(0xFFFF9800), Color(0xFFF57C00)],
    ),
    _PromoCardData(
      title: 'JSEE Solutions',
      subtitle: 'Your trusted loan partner',
      ctaText: 'Get Started',
      imagePath: 'assets/JSEE_icon.jpg',
      gradientColors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
    ),
  ];

  Widget _buildTopBrandBar(BuildContext context) {
    final theme = Theme.of(context);

    // Matches bottom navigation bar color
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/JSEE_icon.jpg',
              height: 42,
              width: 42,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'JSEE Solutions',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Initialize PageController with a large initial page for infinite scroll
    _promoPageController = PageController(
      viewportFraction: 0.9,
      initialPage: _initialPage,
    );
    _promoPageController.addListener(_onPageChanged);
    _startAutoScroll();
    _loadLoanTypes();
  }

  void _onPageChanged() {
    if (!_promoPageController.hasClients) return;
    final page = _promoPageController.page ?? _initialPage;
    final index = (page.round() % _promoCards.length);
    if (index != _currentPromoIndex) {
      setState(() {
        _currentPromoIndex = index;
      });
    }
    // If user is scrolling, pause auto-scroll and schedule resume
    if (_isUserScrolling) {
      _pauseAutoScroll();
      _resumeScrollTimer?.cancel();
      _resumeScrollTimer = Timer(_resumeScrollDelay, () {
        _isUserScrolling = false;
        _resumeAutoScroll();
      });
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(_autoScrollDuration, (timer) {
      if (_promoPageController.hasClients) {
        final nextPage = _promoPageController.page!.toInt() + 1;
        _promoPageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _pauseAutoScroll() {
    _autoScrollTimer?.cancel();
    _isUserScrolling = true;
  }

  void _resumeAutoScroll() {
    if (!_isUserScrolling) {
      _startAutoScroll();
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _resumeScrollTimer?.cancel();
    _promoPageController.removeListener(_onPageChanged);
    _promoPageController.dispose();
    super.dispose();
  }

  Future<void> _loadLoanTypes() async {
    setState(() {
      _isLoading = true;
    });
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loanTypes = _buildLoanTypes(context);

    return Scaffold(
      floatingActionButton: _buildFloatingAssistanceButton(context),
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
        child: Column(
          children: [
            _buildTopBrandBar(context),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState(context)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Promotions Carousel
                          _buildPromoCarousel(context),
                          const SizedBox(height: 24),

                          // Loan Types Section
                          Text(
                            AppStrings.chooseLoanType,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.95,
                            children: loanTypes
                                .map(
                                  (loanType) => _buildLoanTypeGridCard(
                                    context,
                                    icon: loanType.icon,
                                    title: loanType.title,
                                    subtitle: loanType.subtitle,
                                    color: loanType.color,
                                    onTap: () => context.go(
                                      '${AppRoutes.instructions}?loanType=${loanType.title}',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 32),

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
                                        AppStrings.easyProcess,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        AppStrings.easyProcessSubtitle,
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
                                        AppStrings.secure,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        AppStrings.secureSubtitle,
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
                                        AppStrings.quick,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        AppStrings.quickSubtitle,
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
          ],
        ),
      ),
    );
  }

  Widget _buildPromoCarousel(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
          child: Text(
            'Featured Offers',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        GestureDetector(
          onPanStart: (_) => _pauseAutoScroll(),
          onPanEnd: (_) {
            _resumeScrollTimer?.cancel();
            _resumeScrollTimer = Timer(_resumeScrollDelay, () {
              _isUserScrolling = false;
              _resumeAutoScroll();
            });
          },
          child: SizedBox(
            height: 180,
            child: PageView.builder(
              controller: _promoPageController,
              onPageChanged: (_) => _pauseAutoScroll(),
              itemBuilder: (context, index) {
                final cardIndex = index % _promoCards.length;
                final promoCard = _promoCards[cardIndex];
                final isActive = cardIndex == _currentPromoIndex;
                return AnimatedScale(
                  scale: isActive ? 1.0 : 0.92,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: AnimatedOpacity(
                    opacity: isActive ? 1.0 : 0.7,
                    duration: const Duration(milliseconds: 300),
                    child: _buildModernPromoCard(context, promoCard),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Enhanced page indicators
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                _promoCards.length,
                (index) {
                  final isActive = index == _currentPromoIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        _pauseAutoScroll();
                        // Calculate the nearest page for infinite scroll
                        final currentPage = _promoPageController.page?.toInt() ?? _initialPage;
                        final remainder = currentPage % _promoCards.length;
                        final nearestPage = currentPage - remainder + index;
                        _promoPageController.animateToPage(
                          nearestPage,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                        _resumeScrollTimer?.cancel();
                        _resumeScrollTimer = Timer(_resumeScrollDelay, () {
                          _isUserScrolling = false;
                          _resumeAutoScroll();
                        });
                      },
                      child: _buildPageIndicator(isActive: isActive),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernPromoCard(BuildContext context, _PromoCardData data) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: data.gradientColors,
            ),
            boxShadow: [
              BoxShadow(
                color: data.gradientColors[0].withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Background pattern overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.15),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.05),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Brand badge with icon only
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'JSEE Solutions',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Title
                      Text(
                        data.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Subtitle
                      Text(
                        data.subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      // CTA as inline text with arrow
                      Row(
                        children: [
                          Text(
                            data.ctaText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildPageIndicator({required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: isActive ? 7 : 6,
      width: isActive ? 26 : 6,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryColor : AppTheme.primaryColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                ),
              ]
            : [],
      ),
    );
  }

  List<_LoanTypeOption> _buildLoanTypes(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return [
      _LoanTypeOption(
        icon: Icons.person,
        title: AppStrings.loanTypePersonal,
          subtitle: AppStrings.loanTypePersonalSubtitle,
          color: colorScheme.primary,
        ),
        _LoanTypeOption(
        icon: Icons.directions_car,
        title: AppStrings.loanTypeCar,
        subtitle: AppStrings.loanTypeCarSubtitle,
        color: AppTheme.infoColor,
      ),
      _LoanTypeOption(
        icon: Icons.home,
        title: AppStrings.loanTypeHome,
        subtitle: AppStrings.loanTypeHomeSubtitle,
        color: AppTheme.successColor,
      ),
      _LoanTypeOption(
        icon: Icons.business,
        title: AppStrings.loanTypeBusiness,
        subtitle: AppStrings.loanTypeBusinessSubtitle,
        color: AppTheme.warningColor,
      ),
      _LoanTypeOption(
        icon: Icons.school,
        title: AppStrings.loanTypeEducation,
        subtitle: AppStrings.loanTypeEducationSubtitle,
        color: colorScheme.secondary,
      ),
      _LoanTypeOption(
        icon: Icons.home_work,
        title: AppStrings.loanTypeMortgage,
        subtitle: AppStrings.loanTypeMortgageSubtitle,
        color: const Color(0xFF7C3AED),
      ),
      _LoanTypeOption(
        icon: Icons.business_center,
        title: AppStrings.loanTypeProperty,
        subtitle: AppStrings.loanTypePropertySubtitle,
        color: const Color(0xFF14B8A6),
      ),
      _LoanTypeOption(
        icon: Icons.emergency,
        title: AppStrings.loanTypeEmergency,
        subtitle: AppStrings.loanTypeEmergencySubtitle,
        color: const Color(0xFFDC2626),
      ),
    ];
  }

  Widget _buildLoadingState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SkeletonBox(width: 52, height: 52),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 120, height: 18),
                    SizedBox(height: 8),
                    SkeletonBox(width: 220, height: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const SkeletonBox(width: 160, height: 18),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
            children: List.generate(
              8,
              (index) => const SkeletonBox(),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: const [
              Expanded(child: SkeletonBox(height: 88)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 88)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 88)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoanTypeGridCard(
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
        padding: const EdgeInsets.all(16),
        gradientColors: [Colors.white, color.withValues(alpha: 0.05)],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
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
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingAssistanceButton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FloatingActionButton(
      onPressed: () => _showAssistanceDialog(context),
      backgroundColor: colorScheme.primary,
      child: const Icon(
        Icons.support_agent,
        color: Colors.white,
      ),
    );
  }

  void _showAssistanceDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                        Icons.support_agent,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppStrings.getAssistance,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  AppStrings.chooseContactMethod,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // WhatsApp Option
                InkWell(
                  onTap: () {
                    Future.microtask(() {
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      }
                      _openWhatsApp(context);
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: PremiumCard(
                    padding: const EdgeInsets.all(20),
                    gradientColors: [
                      const Color(0xFF25D366).withValues(alpha: 0.1),
                      Colors.white,
                    ],
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.chat,
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
                                AppStrings.whatsapp,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppStrings.whatsappSubtitle,
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
                ),
                const SizedBox(height: 12),
                // Phone Option
                InkWell(
                  onTap: () {
                    Future.microtask(() {
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      }
                      _openPhoneDialer(context);
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: PremiumCard(
                    padding: const EdgeInsets.all(20),
                    gradientColors: [
                      colorScheme.primary.withValues(alpha: 0.1),
                      Colors.white,
                    ],
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
                            Icons.phone,
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
                                AppStrings.phone,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppStrings.phoneSubtitle,
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    // Replace with your WhatsApp number (include country code without +)
    // Format: countrycode + number (e.g., 911234567890 for India)
    const String phoneNumber = '916303429063'; // +91 63034 29063
    final Uri whatsappUrl = Uri.parse('https://wa.me/$phoneNumber');

    try {
      await launchUrl(
        whatsappUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      // Handle error - try alternative method
      try {
        // Alternative: try WhatsApp intent directly
        final Uri whatsappIntent = Uri.parse('whatsapp://send?phone=$phoneNumber');
        await launchUrl(
          whatsappIntent,
          mode: LaunchMode.externalApplication,
        );
      } catch (e2) {
        debugPrint('Error opening WhatsApp: $e2');
        if (context.mounted) {
          PremiumToast.showError(
            context,
            AppStrings.assistanceWhatsappError,
          );
        }
      }
    }
  }

  Future<void> _openPhoneDialer(BuildContext context) async {
    // Replace with your support phone number
    const String phoneNumber = '+916303429063'; // +91 63034 29063
    final Uri phoneUrl = Uri.parse('tel:$phoneNumber');

    try {
      await launchUrl(phoneUrl);
    } catch (e) {
      debugPrint('Error opening phone dialer: $e');
      if (context.mounted) {
        PremiumToast.showError(
          context,
          AppStrings.assistancePhoneError,
        );
      }
    }
  }
}

class _LoanTypeOption {
  const _LoanTypeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
}

class _PromoCardData {
  const _PromoCardData({
    required this.title,
    required this.subtitle,
    required this.ctaText,
    required this.imagePath,
    required this.gradientColors,
  });

  final String title;
  final String subtitle;
  final String ctaText;
  final String imagePath;
  final List<Color> gradientColors;
}
