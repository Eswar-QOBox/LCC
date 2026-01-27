import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_routes.dart';
import '../utils/app_strings.dart';
import '../utils/app_theme.dart';
import '../widgets/premium_toast.dart';

class LoanScreen extends StatefulWidget {
  const LoanScreen({super.key});

  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen> {
  bool _showAllLoans = false;
  late PageController _carouselController;
  int _currentCarouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _carouselController = PageController();
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Sticky Header with Glass Effect
            _buildHeader(context),
            
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Credit Score Carousel
                    _buildCreditScoreCarousel(context),
                    const SizedBox(height: 24),
                    
                    // Choose Loan Type Section
                    _buildLoanTypeSection(context),
                    const SizedBox(height: 24),
                    
                    // Why Choose Us Section
                    _buildWhyChooseUsSection(context),
                    const SizedBox(height: 100), // Space for FAB and bottom nav
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildChatButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo and Title
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/JSEE_icon.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'JSEE Solutions',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'PREMIUM FINANCE',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Notification Button
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Icon(
                        Icons.notifications_outlined,
                        color: colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
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

  Widget _buildCreditScoreCarousel(BuildContext context) {
    const carouselItems = [
      {
        'title': 'CURRENT CREDIT SCORE',
        'value': '784',
        'status': 'Excellent',
        'trend': '+24 pts',
        'updated': 'Updated 2 mins ago',
        'gradient': [
          Color(0xFF002B5B),
          Color(0xFF003B8E),
          Color(0xFF0052CC),
        ],
      },
      {
        'title': 'LOAN ELIGIBILITY',
        'value': '₹5,00,000',
        'status': 'Available',
        'trend': '+₹50K',
        'updated': 'Updated today',
        'gradient': [
          Color(0xFF1A4D2E),
          Color(0xFF2D7A3D),
          Color(0xFF3FA55F),
        ],
      },
      {
        'title': 'SAVINGS RATE',
        'value': '8.5%',
        'status': 'Active',
        'trend': '+0.5%',
        'updated': 'Updated 1 hour ago',
        'gradient': [
          Color(0xFF4A148C),
          Color(0xFF6A1B9A),
          Color(0xFF8E24AA),
        ],
      },
    ];

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _carouselController,
            onPageChanged: (index) {
              setState(() {
                _currentCarouselIndex = index;
              });
            },
            itemCount: carouselItems.length,
            itemBuilder: (context, index) {
              final item = carouselItems[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildCarouselCard(
                  context,
                  title: item['title'] as String,
                  value: item['value'] as String,
                  status: item['status'] as String,
                  trend: item['trend'] as String,
                  updated: item['updated'] as String,
                  gradient: (item['gradient'] as List).cast<Color>(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Page indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            carouselItems.length,
            (index) => Container(
              width: _currentCarouselIndex == index ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: _currentCarouselIndex == index
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselCard(
    BuildContext context, {
    required String title,
    required String value,
    required String status,
    required String trend,
    required String updated,
    required List<Color> gradient,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -40,
            bottom: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -40,
            top: -40,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          // Content
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            style: theme.textTheme.displayLarge?.copyWith(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.successColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  status,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF86EFAC),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      trend,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF86EFAC),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.history,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            updated,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoanTypeSection(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 350;
    
    // Small screens (< 350px): 2 columns, Large screens (>= 350px): 3 columns
    final crossAxisCount = isSmallScreen ? 2 : 3;
    final spacing = isSmallScreen ? 12.0 : 16.0;

    final allLoanTypes = [
      {
        'icon': Icons.person,
        'title': 'Personal Loan',
        'subtitle': 'For personal expenses',
        'iconColor': AppTheme.primaryColor,
        'iconBgColor': AppTheme.primaryColor.withValues(alpha: 0.1),
      },
      {
        'icon': Icons.directions_car,
        'title': 'Car Loan',
        'subtitle': 'Finance your vehicle',
        'iconColor': const Color(0xFF14B8A6),
        'iconBgColor': const Color(0xFF14B8A6).withValues(alpha: 0.1),
      },
      {
        'icon': Icons.school,
        'title': 'Education Loan',
        'subtitle': 'Fund your future',
        'iconColor': const Color(0xFFF59E0B),
        'iconBgColor': const Color(0xFFF59E0B).withValues(alpha: 0.1),
      },
      {
        'icon': Icons.home,
        'title': 'Home Loan',
        'subtitle': 'Buy or renovate',
        'iconColor': AppTheme.successColor,
        'iconBgColor': AppTheme.successColor.withValues(alpha: 0.1),
      },
      {
        'icon': Icons.business,
        'title': 'Business Loan',
        'subtitle': 'Grow your business',
        'iconColor': const Color(0xFF7C3AED),
        'iconBgColor': const Color(0xFF7C3AED).withValues(alpha: 0.1),
      },
      {
        'icon': Icons.home_work,
        'title': 'Mortgage',
        'subtitle': 'Secure your property',
        'iconColor': const Color(0xFFEC4899),
        'iconBgColor': const Color(0xFFEC4899).withValues(alpha: 0.1),
      },
    ];

    // On small screens: show 4 cards (2x2), on large: show all 6 (3x2)
    final loanTypesToShow = isSmallScreen && !_showAllLoans
        ? allLoanTypes.take(4).toList()
        : allLoanTypes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Choose Loan Type',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (isSmallScreen && !_showAllLoans)
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllLoans = true;
                  });
                },
                child: Text(
                  'View All',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              )
            else if (isSmallScreen && _showAllLoans)
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllLoans = false;
                  });
                },
                child: Text(
                  'Show Less',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // Calculate card width based on available space
            final availableWidth = constraints.maxWidth;
            final totalSpacing = spacing * (crossAxisCount - 1);
            final cardWidth = (availableWidth - totalSpacing) / crossAxisCount;
            
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: loanTypesToShow.map((loanType) {
                return SizedBox(
                  width: cardWidth,
                  height: 122,
                  child: _buildLoanTypeCard(
                    context,
                    icon: loanType['icon'] as IconData,
                    title: loanType['title'] as String,
                    subtitle: loanType['subtitle'] as String,
                    iconColor: loanType['iconColor'] as Color,
                    iconBgColor: loanType['iconBgColor'] as Color,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoanTypeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= 350;
    
    // Decrease font size for screens >= 350px
    final titleFontSize = isLargeScreen ? 12.0 : 14.0;
    final iconSize = isLargeScreen ? 18.0 : 20.0;
    final iconContainerSize = isLargeScreen ? 36.0 : 40.0;

    return InkWell(
      onTap: () => context.go('${AppRoutes.instructions}?loanType=$title'),
      borderRadius: BorderRadius.circular(24),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: EdgeInsets.all(isLargeScreen ? 14 : 16),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: iconContainerSize + 8,
                  height: iconContainerSize + 8,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: iconSize + 4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: titleFontSize,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWhyChooseUsSection(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 350;

    final features = [
      {
        'icon': Icons.check_circle,
        'title': 'Easy Process',
        'subtitle': 'Simple steps, high approval rates.',
        'iconColor': AppTheme.successColor,
        'iconBgColor': AppTheme.successColor.withValues(alpha: 0.15),
      },
      {
        'icon': Icons.security,
        'title': 'Secure',
        'subtitle': 'Advanced data protection.',
        'iconColor': AppTheme.primaryColor,
        'iconBgColor': AppTheme.primaryColor.withValues(alpha: 0.15),
      },
      {
        'icon': Icons.speed,
        'title': 'Fast Approval',
        'subtitle': 'Response within 24 hours.',
        'iconColor': const Color(0xFFF59E0B),
        'iconBgColor': const Color(0xFFF59E0B).withValues(alpha: 0.15),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Why Choose Us?',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: features.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final feature = features[index];
              return SizedBox(
                width: 200,
                child: _buildFeatureCard(
                  context,
                  icon: feature['icon'] as IconData,
                  title: feature['title'] as String,
                  subtitle: feature['subtitle'] as String,
                  iconColor: feature['iconColor'] as Color,
                  iconBgColor: feature['iconBgColor'] as Color,
                  isSmallScreen: isSmallScreen,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color iconBgColor,
    required bool isSmallScreen,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final iconSize = isSmallScreen ? 24.0 : 28.0;
    final iconContainerSize = isSmallScreen ? 48.0 : 56.0;
    final titleFontSize = isSmallScreen ? 13.0 : 14.0;
    final subtitleFontSize = isSmallScreen ? 10.0 : 11.0;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconContainerSize,
                height: iconContainerSize,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: iconSize,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: titleFontSize,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: subtitleFontSize,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatButton(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAssistanceDialog(context),
          borderRadius: BorderRadius.circular(28),
          child: const Icon(
            Icons.chat_bubble_outline,
            color: Colors.white,
            size: 28,
          ),
        ),
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
                _buildContactOption(
                  context,
                  icon: Icons.chat,
                  title: AppStrings.whatsapp,
                  subtitle: AppStrings.whatsappSubtitle,
                  color: const Color(0xFF25D366),
                  onTap: () {
                    Navigator.of(context).pop();
                    _openWhatsApp(context);
                  },
                ),
                const SizedBox(height: 12),
                _buildContactOption(
                  context,
                  icon: Icons.phone,
                  title: AppStrings.phone,
                  subtitle: AppStrings.phoneSubtitle,
                  color: AppTheme.primaryColor,
                  onTap: () {
                    Navigator.of(context).pop();
                    _openPhoneDialer(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactOption(
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
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
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

  Future<void> _openWhatsApp(BuildContext context) async {
    const String phoneNumber = '916303429063';
    final Uri whatsappUrl = Uri.parse('https://wa.me/$phoneNumber');

    try {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      try {
        final Uri whatsappIntent = Uri.parse('whatsapp://send?phone=$phoneNumber');
        await launchUrl(whatsappIntent, mode: LaunchMode.externalApplication);
      } catch (e2) {
        if (context.mounted) {
          PremiumToast.showError(context, AppStrings.assistanceWhatsappError);
        }
      }
    }
  }

  Future<void> _openPhoneDialer(BuildContext context) async {
    const String phoneNumber = '+916303429063';
    final Uri phoneUrl = Uri.parse('tel:$phoneNumber');

    try {
      await launchUrl(phoneUrl);
    } catch (e) {
      if (context.mounted) {
        PremiumToast.showError(context, AppStrings.assistancePhoneError);
      }
    }
  }
}

