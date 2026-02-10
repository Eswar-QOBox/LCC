import 'package:flutter/material.dart';

import '../utils/app_routes.dart';
import 'step2_aadhaar_screen.dart';

/// Business Loan (Proprietor): Spouse Aadhaar.
///
/// Reuses the existing Aadhaar UI + validation logic so the UX matches.
class Step4SpouseAadhaarScreen extends StatelessWidget {
  const Step4SpouseAadhaarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Step2AadhaarScreen(
      isSpouse: true,
      titleOverride: 'Spouse Aadhaar',
      progressStepOverride: 4,
      totalStepsOverride: 10,
      backRouteOverride: AppRoutes.step3Pan,
      nextRouteOverride: AppRoutes.step5SpousePan,
    );
  }
}

