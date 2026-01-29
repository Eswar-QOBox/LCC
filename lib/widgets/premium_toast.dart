import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

enum ToastType { success, error, warning, info }

/// Top overlay entry for current toast so we can dismiss it when showing a new one.
OverlayEntry? _currentTopToastEntry;

class PremiumToast {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;

    // Determine colors based on type
    Color backgroundColor;
    Color textColor;
    Color iconColor;
    IconData defaultIcon;

    switch (type) {
      case ToastType.success:
        backgroundColor = AppTheme.successColor;
        textColor = Colors.white;
        iconColor = Colors.white;
        defaultIcon = Icons.check_circle;
        break;
      case ToastType.error:
        backgroundColor = AppTheme.errorColor;
        textColor = Colors.white;
        iconColor = Colors.white;
        defaultIcon = Icons.error;
        break;
      case ToastType.warning:
        backgroundColor = AppTheme.warningColor;
        textColor = Colors.white;
        iconColor = Colors.white;
        defaultIcon = Icons.warning;
        break;
      case ToastType.info:
        backgroundColor = colorScheme.primary;
        textColor = Colors.white;
        iconColor = Colors.white;
        defaultIcon = Icons.info;
        break;
    }

    // Dismiss any existing top toast
    _currentTopToastEntry?.remove();
    _currentTopToastEntry = null;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: topPadding + 8,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  icon ?? defaultIcon,
                  color: iconColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      entry.remove();
                      _currentTopToastEntry = null;
                      onAction();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      actionLabel,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    _currentTopToastEntry = entry;
    overlay.insert(entry);

    Future.delayed(duration, () {
      if (_currentTopToastEntry == entry) {
        entry.remove();
        _currentTopToastEntry = null;
      }
    });
  }

  // Convenience methods
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: ToastType.success,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: ToastType.error,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: ToastType.warning,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: ToastType.info,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Show a snackbar-style message at the top (use instead of ScaffoldMessenger.showSnackBar).
  static void showSnackBarAtTop(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (isError) {
      showError(context, message, duration: duration);
    } else {
      showInfo(context, message, duration: duration);
    }
  }
}
