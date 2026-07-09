class AppRoutes {
  // Auth & Onboarding
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  
  // Main Flow
  static const String home = '/home';
  static const String instructions = '/instructions';
  static const String termsAndConditions = '/terms';
  static const String businessLoanType = '/business-loan-type';
  static const String professionalLoanType = '/professional-loan-type';
  static const String step5ProfessionalDocs = '/step5-professional-docs';
  static const String step5StudentDocs = '/step5-student-docs';
  static const String step5PropertyDetails = '/step5-property-details';

  // Document Steps
  static const String step1Selfie = '/step1-selfie';
  static const String step2Aadhaar = '/step2-aadhaar';
  static const String step3Pan = '/step3-pan';
  static const String step4SpouseAadhaar = '/step4-spouse-aadhaar';
  static const String step5SpousePan = '/step5-spouse-pan';
  static const String step4BankStatement = '/step4-bank-statement';
  static const String coApplicantChoice = '/co-applicant-choice';
  static const String coApplicantAadhaar = '/co-applicant-aadhaar';
  static const String coApplicantPan = '/co-applicant-pan';
  static const String coApplicantBankStatement = '/co-applicant-bank-statement';
  static const String coApplicantSalarySlips = '/co-applicant-salary-slips';
  static const String coApplicantFirmDocs = '/co-applicant-firm-docs';
  static const String coApplicantFirmKyc = '/co-applicant-firm-kyc';
  static const String step5PersonalData = '/step5-personal-data';
  static const String step5_1SalarySlips = '/step5-1-salary-slips';
  static const String step5BusinessDocs = '/step5-business-docs';
  static const String step6Msme = '/step6-msme';
  static const String step7Ohp = '/step7-ohp';
  static const String step6Preview = '/step6-preview';

  // Partnership Flow
  static const String partnerCount = '/partner-count';
  static const String partnerAadhaar = '/partner-aadhaar';
  static const String partnerPan = '/partner-pan';
  
  // After Submission
  static const String submissionSuccess = '/submission-success';
  static const String pdfDownload = '/pdf-download';
  static const String viewSubmitted = '/view-submitted';
  
  // Tools
  static const String loanCalculator = '/loan-calculator';

  // Settings & Support
  static const String support = '/support';

  /// Get the route for a specific step number
  static String getStepRoute(int step) {
    switch (step) {
      case 1:
        return step1Selfie;
      case 2:
        return step2Aadhaar;
      case 3:
        return step3Pan;
      case 4:
        return step4BankStatement;
      case 5:
        return step5PersonalData;
      case 6:
        return step6Preview;
      case 7:
        return step6Preview;
      default:
        return step1Selfie;
    }
  }
}
