import '../models/document_submission.dart';
import 'app_routes.dart';

/// Shared rules for Home Loan and Mortgage Loan flows.
///
/// Both reuse the salaried KYC + income flow. Mortgage Loan additionally
/// requires a Property Details step (one or more named property documents)
/// inserted between the income documents and Personal Data.
class HomeMortgageLoanFlow {
  static bool isMortgageLoan(String? loanType) =>
      (loanType ?? '').toLowerCase().contains('mortgage');

  static bool isHomeLoan(String? loanType) =>
      (loanType ?? '').toLowerCase().contains('home');

  /// Loan types that pick co-applicant before instructions (from the home grid).
  static bool usesCoApplicantEntry(String? loanType) {
    final t = (loanType ?? '').toLowerCase();
    return t.contains('home') || t.contains('mortgage') || t.contains('car');
  }

  /// Whether the Mortgage Property Details step still needs to be completed.
  static bool needsPropertyDetails({
    required String? loanType,
    required DocumentSubmission? submission,
  }) {
    if (!isMortgageLoan(loanType)) return false;
    return !(submission?.propertyDetailsDocuments?.isComplete ?? false);
  }

  /// Route to use once salary slips (and any co-applicant income docs) are done.
  ///
  /// Mortgage inserts the Property Details step before Personal Data; all other
  /// loan types fall through to the existing Personal Data / Preview decision.
  static String routeAfterIncomeDocs({
    required String? loanType,
    required DocumentSubmission? submission,
    required bool personalDataComplete,
  }) {
    if (needsPropertyDetails(loanType: loanType, submission: submission)) {
      return AppRoutes.step5PropertyDetails;
    }
    return personalDataComplete
        ? AppRoutes.step6Preview
        : AppRoutes.step5PersonalData;
  }
}
