import 'package:flutter/material.dart';

/// Reusable App Footer widget for consistent footer across all screens
class AppFooter extends StatelessWidget {
  final String? copyrightText;
  final List<Widget>? footerActions;
  final bool showDivider;

  const AppFooter({
    super.key,
    this.copyrightText,
    this.footerActions,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDivider)
            Divider(
              color: colorScheme.primary.withValues(alpha: 0.1),
              thickness: 1,
            ),
          const SizedBox(height: 12),
          if (footerActions != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: footerActions!,
            ),
            const SizedBox(height: 12),
          ],
          if (copyrightText != null)
            Text(
              copyrightText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            )
          else
            Text(
              '© ${DateTime.now().year} JSEE Solutions. All rights reserved.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
