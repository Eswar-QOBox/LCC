import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Same full-bleed stack as [OnboardingScreen] (Mercotrace `OnboardingScreen.tsx`).
class MercotraceMarketingBackground extends StatelessWidget {
  const MercotraceMarketingBackground({
    super.key,
    required this.child,
    this.visual,
    this.slideVisualIndex = 0,
    this.animated = false,
    this.showBranding = false,
  });

  final Widget child;
  final MercotraceOnboardingSlideVisual? visual;
  final int slideVisualIndex;
  final bool animated;
  final bool showBranding;

  MercotraceOnboardingSlideVisual get _resolved =>
      visual ??
      MercotraceOnboardingSlideVisual
          .slides[slideVisualIndex % MercotraceOnboardingSlideVisual.slides.length];

  @override
  Widget build(BuildContext context) {
    final v = _resolved;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppTheme.mercotraceSlate950),
        _gradientLayer(v),
        _patternLayer(v),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.6),
                radius: 0.55,
                colors: [
                  Colors.white.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        const _MercotraceMarketingParticleLayer(),
        if (showBranding)
          Positioned(left: 24, right: 24, bottom: 36, child: _BrandingCopy()),
        child,
      ],
    );
  }

  Widget _gradientLayer(MercotraceOnboardingSlideVisual v) {
    final decoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: v.gradient,
      ),
    );
    if (animated) {
      return Positioned.fill(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          decoration: decoration,
        ),
      );
    }
    return Positioned.fill(child: DecoratedBox(decoration: decoration));
  }

  Widget _patternLayer(MercotraceOnboardingSlideVisual v) {
    final inner = DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: v.patternCenter,
          radius: v.patternRadius,
          colors: [
            Colors.white.withValues(alpha: v.patternPeakWhite),
            Colors.transparent,
          ],
        ),
      ),
    );
    if (animated) {
      return Positioned.fill(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          child: Opacity(opacity: 0.3, child: inner),
        ),
      );
    }
    return Positioned.fill(
      child: Opacity(opacity: 0.3, child: inner),
    );
  }
}

class AuthThemedBackground extends StatelessWidget {
  const AuthThemedBackground({
    super.key,
    required this.child,
    this.showBranding = false,
  });

  final Widget child;
  final bool showBranding;

  @override
  Widget build(BuildContext context) {
    return MercotraceMarketingBackground(
      slideVisualIndex: 0,
      showBranding: showBranding,
      child: child,
    );
  }
}

class AuthGlassCard extends StatelessWidget {
  const AuthGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 48,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            blurRadius: 90,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: child,
        ),
      ),
    );
  }
}

/// Primary CTA on auth screens — white surface and primary-colored label (matches React `bg-white text-blue-600`).
class AuthLightCtaButton extends StatelessWidget {
  const AuthLightCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.trailingIcon = Icons.arrow_forward_rounded,
    this.height = 56,
    /// When set (e.g. Mercotrace onboarding `rounded-2xl`), overrides pill shape.
    this.cornerRadius,
    /// Defaults to [AppTheme.primaryColor]; Mercotrace uses `text-blue-600`.
    this.labelAndIconColor,
    this.labelFontSize,
    this.labelFontWeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData trailingIcon;
  final double height;
  final double? cornerRadius;
  final Color? labelAndIconColor;
  final double? labelFontSize;
  final FontWeight? labelFontWeight;

  @override
  Widget build(BuildContext context) {
    final accent = labelAndIconColor ?? AppTheme.primaryColor;
    final radius = cornerRadius ?? height / 2;
    final fontSize = labelFontSize ?? 16;
    final fontWeight = labelFontWeight ?? FontWeight.w700;
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: isLoading ? null : onPressed,
        child: SizedBox(
          height: height,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: accent,
                          fontSize: fontSize,
                          fontWeight: fontWeight,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(trailingIcon, size: 20, color: accent),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class AuthGradientButton extends StatelessWidget {
  const AuthGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.trailingIcon = Icons.arrow_forward_rounded,
    this.height = 58,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData trailingIcon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.secondaryColor,
            AppTheme.primaryColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.35),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          minimumSize: Size.fromHeight(height),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(trailingIcon, size: 18, color: Colors.white),
                ],
              ),
      ),
    );
  }
}

class AuthLogoBadge extends StatelessWidget {
  const AuthLogoBadge({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.50),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ClipOval(
          child: Image.asset(
            'assets/JSEE_icon.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) =>
                const Icon(Icons.shield_rounded, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// 15 × `w-2 h-2` at `bg-white/30` — Mercotrace onboarding particles.
class _MercotraceMarketingParticleLayer extends StatelessWidget {
  const _MercotraceMarketingParticleLayer();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            children: List.generate(15, (i) {
              final u = ((i * 7919) % 997) / 997.0;
              final v = ((i * 6271) % 991) / 991.0;
              return Positioned(
                left: u * w,
                top: v * h,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _BrandingCopy extends StatelessWidget {
  const _BrandingCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'JSEE Solutions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Smart Lending Management Platform',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
