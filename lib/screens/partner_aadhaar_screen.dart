import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/submission_provider.dart';
import '../utils/app_routes.dart';
import 'step2_aadhaar_screen.dart';

class PartnerAadhaarScreen extends StatelessWidget {
  final int partnerIndex;
  final bool fromPreview;

  const PartnerAadhaarScreen({
    super.key,
    required this.partnerIndex,
    this.fromPreview = false,
  });

  @override
  Widget build(BuildContext context) {
    final partnerCount =
        context.watch<SubmissionProvider>().submission.businessDocuments?.partnerCount;
    final totalSteps = partnerCount != null ? (10 + 2 * partnerCount) : 10;
    final progressStep = partnerCount != null
        ? (6 + (partnerIndex - 1) * 2)
        : 6;

    final backRoute = partnerIndex == 1
        ? AppRoutes.partnerCount
        : '${AppRoutes.partnerPan}?i=${partnerIndex - 1}';

    final nextRoute = '${AppRoutes.partnerPan}?i=$partnerIndex';

    return Step2AadhaarScreen(
      fromPreview: fromPreview,
      isPartner: true,
      partnerIndex: partnerIndex,
      titleOverride: 'Partner $partnerIndex Aadhaar',
      progressStepOverride: progressStep,
      totalStepsOverride: totalSteps,
      backRouteOverride: backRoute,
      nextRouteOverride: nextRoute,
    );
  }
}

