import 'package:flutter/material.dart';

import '../utils/app_routes.dart';
import 'step3_pan_screen.dart';

/// Business Loan (Proprietor): Spouse PAN.
///
/// Reuses the existing PAN UI + validation logic so the UX matches.
class Step5SpousePanScreen extends StatelessWidget {
  const Step5SpousePanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Step3PanScreen(
      isSpouse: true,
      titleOverride: 'Co-applicant PAN',
      progressStepOverride: 5,
      totalStepsOverride: 10,
      backRouteOverride: AppRoutes.step4SpouseAadhaar,
      nextRouteOverride: AppRoutes.step4BankStatement,
    );
  }
}

