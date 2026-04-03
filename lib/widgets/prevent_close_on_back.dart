import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/app_routes.dart';

/// Wraps a screen so that system back / swipe-back does not close the app.
/// When back is triggered: if [onBack] is provided it is called; otherwise
/// if router can pop we pop, else we go to [backRoute] or home.
class PreventCloseOnBack extends StatelessWidget {
  const PreventCloseOnBack({
    super.key,
    required this.child,
    this.backRoute,
    this.onBack,
  });

  final Widget child;

  /// Route to go to when there is nothing to pop (e.g. when flow used context.go).
  /// If null, uses [AppRoutes.home]. Ignored if [onBack] is set.
  final String? backRoute;

  /// When set, called on back/swipe instead of default pop or go(backRoute).
  /// Use this to match the screen's app bar back behavior (e.g. go to previous step).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (onBack != null) {
          onBack!();
          return;
        }
        final router = GoRouter.of(context);
        if (router.canPop()) {
          context.pop();
        } else {
          context.go(backRoute ?? AppRoutes.home);
        }
      },
      child: child,
    );
  }
}
