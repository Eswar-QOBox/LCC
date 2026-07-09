import '../models/document_submission.dart';
import 'app_routes.dart';

/// Shared rules for Business Loan (Proprietor / Partnership / Pvt Ltd) flows.
class BusinessLoanFlow {
  static const String proprietor = 'proprietor';
  static const String partnership = 'partnership';
  static const String pvtLimited = 'pvt_limited';

  static bool isBusinessLoan(String? loanType) {
    return (loanType ?? '').toLowerCase().contains('business');
  }

  static String normalizeType(String? raw) {
    final t = (raw ?? '').trim().toLowerCase();
    if (t == proprietor || t == 'sole proprietor') return proprietor;
    if (t == partnership || t == 'partner') return partnership;
    if (t == pvtLimited ||
        t == 'pvt ltd' ||
        t == 'pvt. ltd' ||
        t == 'private limited' ||
        t == 'private_limited') {
      return pvtLimited;
    }
    return t;
  }

  static bool isKnownSubtype(String? type) {
    final t = normalizeType(type);
    return t == proprietor || t == partnership || t == pvtLimited;
  }

  /// Resolves business subtype from stored value or uploaded business documents.
  static String? resolveBusinessLoanType({
    String? loanType,
    String? businessLoanType,
    DocumentSubmission? submission,
  }) {
    final normalized = normalizeType(businessLoanType);
    if (isKnownSubtype(normalized)) return normalized;

    final lt = loanType ?? submission?.loanType;
    if (!isBusinessLoan(lt)) return null;

    final bd = submission?.businessDocuments;
    if (bd != null) {
      if ((bd.moa?.isComplete ?? false) || (bd.aoa?.isComplete ?? false)) {
        return pvtLimited;
      }
      if ((bd.partnershipDeed?.isComplete ?? false) ||
          (bd.partnerCount ?? 0) > 0 ||
          bd.partners.isNotEmpty) {
        return partnership;
      }
      if ((bd.spousePan?.isComplete ?? false) ||
          (bd.spouseAadhaar?.isComplete ?? false)) {
        return proprietor;
      }
    }
    return null;
  }

  static bool isProprietor({
    String? loanType,
    String? businessLoanType,
    DocumentSubmission? submission,
  }) {
    return resolveBusinessLoanType(
          loanType: loanType,
          businessLoanType: businessLoanType,
          submission: submission,
        ) ==
        proprietor;
  }

  static bool isPartnershipOrPvt({
    String? loanType,
    String? businessLoanType,
    DocumentSubmission? submission,
  }) {
    final t = resolveBusinessLoanType(
      loanType: loanType,
      businessLoanType: businessLoanType,
      submission: submission,
    );
    return t == partnership || t == pvtLimited;
  }

  /// Salary slips are never required for any Business Loan subtype.
  static bool requiresSalarySlips({
    String? loanType,
    String? businessLoanType,
    DocumentSubmission? submission,
  }) {
    if (isBusinessLoan(loanType) || isBusinessLoan(submission?.loanType)) {
      return false;
    }
    return true;
  }

  /// Route after the main applicant bank statement step (not co-applicant).
  static String routeAfterBankStatement({
    required String loanType,
    String? businessLoanType,
    DocumentSubmission? submission,
    bool fromPreview = false,
    bool isCoApplicant = false,
    bool isProfessionalDoctorOrCa = false,
    bool isStudent = false,
  }) {
    if (fromPreview) return AppRoutes.step6Preview;
    if (isCoApplicant) return AppRoutes.coApplicantSalarySlips;

    if (isBusinessLoan(loanType)) {
      final type = resolveBusinessLoanType(
        loanType: loanType,
        businessLoanType: businessLoanType,
        submission: submission,
      );
      switch (type) {
        case proprietor:
          return AppRoutes.step5BusinessDocs;
        case partnership:
        case pvtLimited:
          return AppRoutes.partnerCount;
        default:
          // Unknown business subtype: never send to salary slips.
          return AppRoutes.partnerCount;
      }
    }
    if (isProfessionalDoctorOrCa) return AppRoutes.step5ProfessionalDocs;
    if (isStudent) return AppRoutes.step5StudentDocs;
    return AppRoutes.step5_1SalarySlips;
  }

  /// When a business loan user lands on the salary slips screen, send them forward.
  static String routeIfBusinessLoanOnSalarySlipsScreen({
    required String loanType,
    String? businessLoanType,
    DocumentSubmission? submission,
    bool fromPreview = false,
  }) {
    if (fromPreview) return AppRoutes.step6Preview;
    if (!isBusinessLoan(loanType) && !isBusinessLoan(submission?.loanType)) {
      return AppRoutes.step5PersonalData;
    }
    return routeAfterBankStatement(
      loanType: loanType.isNotEmpty ? loanType : (submission?.loanType ?? ''),
      businessLoanType: businessLoanType,
      submission: submission,
    );
  }
}
