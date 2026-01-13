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
}

class AadhaarDocument {
  String? frontPath;
  String? backPath;

  AadhaarDocument({
    this.frontPath,
    this.backPath,
  });

  bool get isComplete => frontPath != null && backPath != null;
}

class PanDocument {
  String? frontPath;

  PanDocument({
    this.frontPath,
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

class SalarySlips {
  List<String> slips;
  String? pdfPassword;
  bool isPdf;

  SalarySlips({
    this.slips = const [],
    this.pdfPassword,
    this.isPdf = false,
  });

  bool get isComplete => slips.isNotEmpty;
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
  String? loanAmountTenure;
  
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
        nameAsPerAadhaar!.isNotEmpty &&
        dateOfBirth != null &&
        panNo != null &&
        panNo!.isNotEmpty &&
        mobileNumber != null &&
        mobileNumber!.isNotEmpty &&
        personalEmailId != null &&
        personalEmailId!.isNotEmpty &&
        residenceAddress != null &&
        residenceAddress!.isNotEmpty;
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

