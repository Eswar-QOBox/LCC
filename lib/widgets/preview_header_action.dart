import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/app_routes.dart';

/// A consistent "Preview" icon button for the `AppHeader`.
///
/// Navigates to `AppRoutes.step6Preview` while remembering which screen to return to
/// via the `back` query param.
class PreviewHeaderAction extends StatelessWidget {
  const PreviewHeaderAction({
    super.key,
    required this.backRoute,
    this.tooltip = 'Preview',
  });

  /// The route to return to when user presses Back from Preview.
  ///
  /// Example: `AppRoutes.step2Aadhaar`.
  final String backRoute;

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final target = Uri(
      path: AppRoutes.step6Preview,
      queryParameters: {'back': backRoute},
    ).toString();

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.visibility, size: 20),
        onPressed: () => context.go(target),
        color: Colors.white,
        tooltip: tooltip,
      ),
    );
  }
}

