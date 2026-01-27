import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../utils/app_routes.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
    _navigateToNext();
  }

  void _navigateToNext() async {
    // Wait for minimum splash duration (2 seconds)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check authentication status
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Wait for auth check to complete if still loading
    while (authProvider.isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }

    // Navigate based on authentication status
    if (authProvider.isAuthenticated) {
      // User is logged in - go to home
      context.go(AppRoutes.home);
    } else {
      // User is not logged in - go to login
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isPortrait = screenHeight > screenWidth;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        minimum: EdgeInsets.zero,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: screenWidth,
                  maxHeight: screenHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isPortrait ? 24.0 : 48.0,
                    vertical: isPortrait ? 48.0 : 24.0,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Calculate responsive size based on available space
                      final availableWidth = constraints.maxWidth;
                      final availableHeight = constraints.maxHeight;
                      final minDimension = availableWidth < availableHeight
                          ? availableWidth
                          : availableHeight;
                      
                      // Use 70% of the smaller dimension, with min/max bounds
                      final imageSize = (minDimension * 0.7).clamp(150.0, 500.0);
                      
                      return SizedBox(
                        width: imageSize,
                        height: imageSize,
                        child: Image.asset(
                          'assets/main_logo.jpeg',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (context, error, stackTrace) {
                            // Robust error handling with fallback
                            return Container(
                              width: imageSize,
                              height: imageSize,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported_outlined,
                                    size: imageSize * 0.3,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Logo not found',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
