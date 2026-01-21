class AppStrings {
  // Navigation
  static const String navHome = 'Home';
  static const String navApplications = 'My Applications';
  static const String navDocuments = 'My Documents';
  static const String navCalculator = 'Calculator';
  static const String navAccounts = 'Accounts';

  // Loan screen
  static const String homeTitle = 'Home';
  static const String homeSubtitle = 'Start your loan application process';
  static const String chooseLoanType = 'Choose Loan Type';
  static const String easyProcess = 'Easy Process';
  static const String easyProcessSubtitle = 'Simple steps';
  static const String secure = 'Secure';
  static const String secureSubtitle = 'Data protected';
  static const String quick = 'Quick';
  static const String quickSubtitle = 'Fast approval';
  static const String getAssistance = 'Get Assistance';
  static const String chooseContactMethod = 'Choose how you\'d like to contact us';
  static const String whatsapp = 'WhatsApp';
  static const String whatsappSubtitle = 'Chat with us on WhatsApp';
  static const String phone = 'Phone';
  static const String phoneSubtitle = 'Call us directly';
  static const String assistanceWhatsappError =
      'Unable to open WhatsApp. Please make sure WhatsApp is installed or try again after restarting the app.';
  static const String assistancePhoneError =
      'Unable to open phone dialer. Please try again after restarting the app.';

  static const String loanTypePersonal = 'Personal Loan';
  static const String loanTypePersonalSubtitle = 'For personal expenses';
  static const String loanTypeCar = 'Car Loan';
  static const String loanTypeCarSubtitle = 'Finance your vehicle';
  static const String loanTypeHome = 'Home Loan';
  static const String loanTypeHomeSubtitle = 'Buy or renovate your home';
  static const String loanTypeBusiness = 'Business Loan';
  static const String loanTypeBusinessSubtitle = 'Grow your business';
  static const String loanTypeEducation = 'Education Loan';
  static const String loanTypeEducationSubtitle = 'Fund your education';
  static const String loanTypeMortgage = 'Mortgage Loan';
  static const String loanTypeMortgageSubtitle = 'Secure your property';
  static const String loanTypeProperty = 'Loan Against Property';
  static const String loanTypePropertySubtitle = 'Unlock property value';
  static const String loanTypeEmergency = 'Emergency Loan';
  static const String loanTypeEmergencySubtitle = 'Quick financial support';

  // Applications screen
  static const String applicationsTitle = 'My Applications';
  static const String tabApplied = 'Applied';
  static const String tabApproved = 'Approved';
  static const String tabIncomplete = 'Incomplete';
  static const String errorLoadingApplications = 'Error Loading Applications';
  static const String retry = 'Retry';
  static const String noApplications = 'No Applications';
  static const String startApplication = 'Start Application';
  static const String refresh = 'Refresh';
  static const String statusRepaymentScheduled = 'Repayment Scheduled';
  static const String statusUnderReview = 'Under Review';
  static const String statusIncomplete = 'Incomplete Application';
  static const String statusContinue = 'Continue where you left off';
  static const String statusInProgress = 'In Progress';
  static const String loanAmountLabel = 'Loan Amount';
  static const String interestLabel = 'Interest';
  static const String tenureLabel = 'Tenure';
  static const String emiLabel = 'EMI';

  // Documents screen
  static const String requiredDocumentsTitle = 'Required Documents';
  static const String errorLoadingDocuments = 'Error Loading Documents';
  static const String noAdditionalDocuments = 'No Additional Documents Required';
  static const String noAdditionalDocumentsMessage =
      'All required documents have been uploaded or no additional documents are needed.';
  static const String submittedTab = 'Submitted';
  static const String verifiedTab = 'Verified';
  static const String upload = 'Upload';
  static const String reupload = 'Re-upload';
  static const String verified = 'Verified';
  static const String rejected = 'Rejected';
  static const String pending = 'Pending';
  static const String uploading = 'Uploading...';
  static const String selectSource = 'Select Source';
  static const String camera = 'Camera';
  static const String gallery = 'Gallery';
  static const String file = 'File';
  static const String noSubmittedDocuments = 'No Submitted Documents';
  static const String noSubmittedDocumentsMessage = 'Documents you upload will appear here';
  static const String noVerifiedDocuments = 'No Verified Documents';
  static const String noVerifiedDocumentsMessage =
      'Verified documents will appear here once reviewed';
  static const String viewSubmitted = 'View Submitted';
  static const String viewVerified = 'View Verified';

  static String applicationsEmptyMessage(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 'Your submitted and in-progress applications will appear here';
      case 1:
        return 'Your approved applications will appear here';
      case 2:
        return 'Your incomplete draft applications will appear here';
      default:
        return 'Your applications will appear here';
    }
  }

  static String stepName(int step) {
    switch (step) {
      case 1:
        return 'Step 1: Selfie';
      case 2:
        return 'Step 2: Aadhaar Card';
      case 3:
        return 'Step 3: PAN Card';
      case 4:
        return 'Step 4: Bank Statement';
      case 5:
        return 'Step 5: Personal Data';
      case 6:
        return 'Step 6: Preview';
      default:
        return 'Start Application';
    }
  }

  // Application restriction messages
  static const String applicationInProgressTitle = 'Application In Progress';
  static const String applicationInProgressMessage = 
      'You have an in-progress application. Please complete it before starting a new one.';
  static const String viewExistingApplication = 'View Existing Application';
  static const String cancel = 'Cancel';
}
