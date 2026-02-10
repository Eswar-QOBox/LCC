import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/submission_provider.dart';
import '../utils/app_routes.dart';
import 'step3_pan_screen.dart';

class PartnerPanScreen extends StatelessWidget {
  final int partnerIndex;

  const PartnerPanScreen({
    super.key,
    required this.partnerIndex,
  });

  @override
  Widget build(BuildContext context) {
    final partnerCount =
        context.watch<SubmissionProvider>().submission.businessDocuments?.partnerCount ?? 0;
    final totalSteps = partnerCount > 0 ? (10 + 2 * partnerCount) : 10;
    final progressStep = partnerCount > 0
        ? (7 + (partnerIndex - 1) * 2)
        : 7;

    final backRoute = '${AppRoutes.partnerAadhaar}?i=$partnerIndex';

    final nextRoute = (partnerCount > 0 && partnerIndex < partnerCount)
        ? '${AppRoutes.partnerAadhaar}?i=${partnerIndex + 1}'
        : AppRoutes.step5BusinessDocs;

    return Step3PanScreen(
      isPartner: true,
      partnerIndex: partnerIndex,
      titleOverride: 'Partner $partnerIndex PAN',
      progressStepOverride: progressStep,
      totalStepsOverride: totalSteps,
      backRouteOverride: backRoute,
      nextRouteOverride: nextRoute,
    );
  }
}

