import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/app_strings.dart';
import '../utils/app_theme.dart';

/// Sticky home-style header with a light glass effect, brand mark, and optional actions.
class BrandGlassHeader extends StatelessWidget {
  const BrandGlassHeader({
    super.key,
    this.trailing,
    this.title = AppStrings.homeTitle,
    this.showLogo = true,
  });

  final Widget? trailing;
  final String title;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.82),
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              if (showLogo) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Image.asset(
                      'assets/JSEE_icon.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.account_balance,
                          color: AppTheme.primaryColor,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    letterSpacing: 0.3,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
