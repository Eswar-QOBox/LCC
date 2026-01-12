import 'package:flutter/material.dart';

class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final List<Color>? gradientColors;
  final double? borderRadius;
  final List<BoxShadow>? shadows;
  final Border? border;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.gradientColors,
    this.borderRadius,
    this.shadows,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: gradientColors != null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors!,
              )
            : null,
        color: gradientColors == null
            ? (backgroundColor ?? colorScheme.surface)
            : null,
        borderRadius: BorderRadius.circular(borderRadius ?? 24),
        border: border ??
            Border.all(
              color: colorScheme.primary.withValues(alpha: 0.1),
              width: 1,
            ),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 10),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
      ),
      child: child,
    );
  }
}

