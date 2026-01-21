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
  
  // Document Steps
  static const String step1Selfie = '/step1-selfie';
  static const String step2Aadhaar = '/step2-aadhaar';
  static const String step3Pan = '/step3-pan';
  static const String step4BankStatement = '/step4-bank-statement';
  static const String step5PersonalData = '/step5-personal-data';
  static const String step5_1SalarySlips = '/step5-1-salary-slips';
  static const String step6Preview = '/step6-preview';
  
  // After Submission
  static const String submissionSuccess = '/submission-success';
  static const String pdfDownload = '/pdf-download';

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
      default:
        return step1Selfie;
    }
  }
}
