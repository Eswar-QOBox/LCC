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

  @override
  void initState() {
    super.initState();
    _loadLoanTypes();
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
          child: SafeArea(
            child: _isLoading
                ? _buildLoadingState(context)
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
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
                                Icons.home,
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
                                    AppStrings.homeTitle,
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppStrings.homeSubtitle,
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
                    Navigator.of(context).pop();
                    _openWhatsApp(context);
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
                    Navigator.of(context).pop();
                    _openPhoneDialer(context);
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
    const String phoneNumber = '917569093224'; // Replace with actual number
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
    const String phoneNumber = '+917569093224'; // Replace with actual number
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
