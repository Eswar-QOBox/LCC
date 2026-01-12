import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

enum ToastType { success, error, warning, info }

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

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Remove any existing snackbars first
    scaffoldMessenger.clearSnackBars();

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    scaffoldMessenger.hideCurrentSnackBar();
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
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 6,
        duration: duration,
      ),
    );
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
}
