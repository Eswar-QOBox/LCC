class DocumentSubmission {
  String? selfiePath;
  AadhaarDocument? aadhaar;
  PanDocument? pan;
  BankStatement? bankStatement;
  PersonalData? personalData;
  SalarySlips? salarySlips;
  DateTime? submittedAt;
  SubmissionStatus status;

  DocumentSubmission({
    this.selfiePath,
    this.aadhaar,
    this.pan,
    this.bankStatement,
    this.personalData,
    this.salarySlips,
    this.submittedAt,
    this.status = SubmissionStatus.inProgress,
  });

  bool get isComplete {
    return selfiePath != null &&
        aadhaar != null &&
        aadhaar!.isComplete &&
        pan != null &&
        pan!.isComplete &&
        bankStatement != null &&
        bankStatement!.isComplete &&
        personalData != null &&
        personalData!.isComplete &&
        salarySlips != null &&
        salarySlips!.isComplete;
  }

  /// Debug method to check which parts are missing
  List<String> getMissingParts() {
    final missing = <String>[];
    if (selfiePath == null) {
      missing.add('Selfie');
    }
    if (aadhaar == null || !aadhaar!.isComplete) {
      missing.add('Aadhaar (${aadhaar == null ? "not uploaded" : "incomplete"})');
    }
    if (pan == null || !pan!.isComplete) {
      missing.add('PAN (${pan == null ? "not uploaded" : "incomplete"})');
    }
    if (bankStatement == null || !bankStatement!.isComplete) {
      missing.add('Bank Statement (${bankStatement == null ? "not uploaded" : "incomplete"})');
    }
    if (personalData == null || !personalData!.isComplete) {
      if (personalData == null) {
        missing.add('Personal Data (not filled)');
      } else {
        final missingFields = personalData!.getMissingFields();
        missing.add('Personal Data - Missing: ${missingFields.join(", ")}');
      }
    }
    if (salarySlips == null || !salarySlips!.isComplete) {
      missing.add('Salary Slips (${salarySlips == null ? "not uploaded" : "incomplete"})');
    }
    return missing;
  }
}

class AadhaarDocument {
  String? frontPath;
  String? backPath;
  bool frontIsPdf;
  bool backIsPdf;

  AadhaarDocument({
    this.frontPath,
    this.backPath,
    this.frontIsPdf = false,
    this.backIsPdf = false,
  });

  bool get isComplete => frontPath != null && backPath != null;
}

class PanDocument {
  String? frontPath;
  bool isPdf;

  PanDocument({
    this.frontPath,
    this.isPdf = false,
  });

  bool get isComplete => frontPath != null;
}

class BankStatement {
  List<String> pages;
  String? pdfPassword;
  bool isPdf;
  DateTime? statementDate;

  BankStatement({
    this.pages = const [],
    this.pdfPassword,
    this.isPdf = false,
    this.statementDate,
  });

  bool get isComplete => pages.isNotEmpty;
}

class SalarySlipItem {
  String path;
  DateTime? slipDate; // Date of the payslip (date, month, year)
  bool isPdf; // Track if this item is a PDF file

  SalarySlipItem({
    required this.path,
    this.slipDate,
    this.isPdf = false,
  });
}

class SalarySlips {
  List<SalarySlipItem> slipItems;
  String? pdfPassword;
  bool isPdf;

  SalarySlips({
    List<SalarySlipItem>? slipItems,
    this.pdfPassword,
    this.isPdf = false,
  }) : slipItems = slipItems ?? [];

  // Legacy getter for backward compatibility
  List<String> get slips => slipItems.map((item) => item.path).toList();

  bool get isComplete => slipItems.isNotEmpty;
}

class PersonalData {
  // Basic Information
  String? nameAsPerAadhaar;
  DateTime? dateOfBirth;
  String? panNo;
  String? mobileNumber;
  String? personalEmailId;
  
  // Residence Information
  String? countryOfResidence;
  String? residenceAddress;
  String? residenceType;
  String? residenceStability;
  
  // Company Information
  String? companyName;
  String? companyAddress;
  
  // Personal Details
  String? nationality;
  String? countryOfBirth;
  String? occupation;
  String? educationalQualification;
  String? workType;
  String? industry;
  String? annualIncome;
  String? totalWorkExperience;
  String? currentCompanyExperience;
  String? loanAmount; // Enhanced: Separate loan amount field
  String? loanTenure; // Enhanced: Separate tenure field (in months/years)
  String? loanAmountTenure; // Legacy field for backward compatibility
  
  // Family Information
  String? maritalStatus; // Married/Unmarried
  String? spouseName;
  String? fatherName;
  String? motherName;
  
  // Reference Details
  String? reference1Name;
  String? reference1Address;
  String? reference1Contact;
  String? reference2Name;
  String? reference2Address;
  String? reference2Contact;

  PersonalData({
    this.nameAsPerAadhaar,
    this.dateOfBirth,
    this.panNo,
    this.mobileNumber,
    this.personalEmailId,
    this.countryOfResidence,
    this.residenceAddress,
    this.residenceType,
    this.residenceStability,
    this.companyName,
    this.companyAddress,
    this.nationality,
    this.countryOfBirth,
    this.occupation,
    this.educationalQualification,
    this.workType,
    this.industry,
    this.annualIncome,
    this.totalWorkExperience,
    this.currentCompanyExperience,
    this.loanAmount,
    this.loanTenure,
    this.loanAmountTenure,
    this.maritalStatus,
    this.spouseName,
    this.fatherName,
    this.motherName,
    this.reference1Name,
    this.reference1Address,
    this.reference1Contact,
    this.reference2Name,
    this.reference2Address,
    this.reference2Contact,
  });

  // Legacy getters for backward compatibility
  String? get fullName => nameAsPerAadhaar;
  String? get address => residenceAddress;
  String? get mobile => mobileNumber;
  String? get email => personalEmailId;
  String? get employmentStatus => occupation;

  bool get isComplete {
    return nameAsPerAadhaar != null &&
        nameAsPerAadhaar!.trim().isNotEmpty &&
        dateOfBirth != null &&
        panNo != null &&
        panNo!.trim().isNotEmpty &&
        mobileNumber != null &&
        mobileNumber!.trim().isNotEmpty &&
        personalEmailId != null &&
        personalEmailId!.trim().isNotEmpty &&
        residenceAddress != null &&
        residenceAddress!.trim().isNotEmpty;
  }

  /// Debug method to check which fields are missing
  List<String> getMissingFields() {
    final missing = <String>[];
    if (nameAsPerAadhaar == null || nameAsPerAadhaar!.trim().isEmpty) {
      missing.add('Name as per Aadhaar');
    }
    if (dateOfBirth == null) {
      missing.add('Date of Birth');
    }
    if (panNo == null || panNo!.trim().isEmpty) {
      missing.add('PAN No');
    }
    if (mobileNumber == null || mobileNumber!.trim().isEmpty) {
      missing.add('Mobile Number');
    }
    if (personalEmailId == null || personalEmailId!.trim().isEmpty) {
      missing.add('Personal Email ID');
    }
    if (residenceAddress == null || residenceAddress!.trim().isEmpty) {
      missing.add('Residence Address');
    }
    return missing;
  }
}

enum SubmissionStatus {
  inProgress,
  pendingVerification,
  approved,
  rejected,
}

class SelfieValidationResult {
  final bool isValid;
  final List<String> errors;

  SelfieValidationResult({
    required this.isValid,
    this.errors = const [],
  });
}

