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
      final count = salarySlips?.uploadedCount ?? 0;
      missing.add(
        'Salary Slips (${salarySlips == null ? "not uploaded" : "$count/${SalarySlips.requiredSlipCount}"})',
      );
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

  bool get hasFile => path.trim().isNotEmpty;
}

class SalarySlips {
  static const int requiredSlipCount = 3;
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

  int get uploadedCount => slipItems.where((item) => item.hasFile).length;

  bool get isComplete => uploadedCount >= requiredSlipCount;
}

class PersonalData {
  // Basic Information
  String? nameAsPerAadhaar;
  DateTime? dateOfBirth;
  String? panNo;
  String? aadhaarNumber;
  String? mobileNumber;
  String? personalEmailId;
  
  // Residence Information
  String? countryOfResidence;
  String? residenceAddress;
  /// If true, user says their current address differs from Aadhaar address.
  bool? addressDifferentFromAadhaar;
  /// Current/address-proof address (only required when [addressDifferentFromAadhaar] is true).
  String? currentResidenceAddress;
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
  String? monthlyIncome; // Monthly income field
  String? currentEmi; // Current EMI (if any)
  String? existingLoans; // Number of existing loans
  String? creditScore; // Credit Score (CIBIL)
  
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
    this.aadhaarNumber,
    this.mobileNumber,
    this.personalEmailId,
    this.countryOfResidence,
    this.residenceAddress,
    this.addressDifferentFromAadhaar,
    this.currentResidenceAddress,
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
    this.monthlyIncome,
    this.currentEmi,
    this.existingLoans,
    this.creditScore,
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

  factory PersonalData.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDob;
    final dobRaw = json['dateOfBirth'];
    if (dobRaw is String) {
      parsedDob = DateTime.tryParse(dobRaw);
    }

    return PersonalData(
      // Basic Information
      nameAsPerAadhaar: json['nameAsPerAadhaar'] as String?,
      dateOfBirth: parsedDob,
      panNo: json['panNo'] as String?,
      aadhaarNumber: json['aadhaarNumber'] as String?,
      mobileNumber: json['mobileNumber'] as String?,
      personalEmailId: json['personalEmailId'] as String?,

      // Residence Information
      countryOfResidence: json['countryOfResidence'] as String?,
      residenceAddress: json['residenceAddress'] as String?,
      addressDifferentFromAadhaar: json['addressDifferentFromAadhaar'] as bool?,
      currentResidenceAddress: json['currentResidenceAddress'] as String?,
      residenceType: json['residenceType'] as String?,
      residenceStability: json['residenceStability'] as String?,

      // Company Information
      companyName: json['companyName'] as String?,
      companyAddress: json['companyAddress'] as String?,

      // Personal Details
      nationality: json['nationality'] as String?,
      countryOfBirth: json['countryOfBirth'] as String?,
      occupation: json['occupation'] as String?,
      educationalQualification: json['educationalQualification'] as String?,
      workType: json['workType'] as String?,
      industry: json['industry'] as String?,
      annualIncome: json['annualIncome'] as String?,
      totalWorkExperience: json['totalWorkExperience'] as String?,
      currentCompanyExperience: json['currentCompanyExperience'] as String?,
      loanAmount: json['loanAmount'] as String?,
      loanTenure: json['loanTenure'] as String?,
      loanAmountTenure: json['loanAmountTenure'] as String?,
      monthlyIncome: json['monthlyIncome'] as String?,
      currentEmi: json['currentEmi'] as String?,
      existingLoans: json['existingLoans'] as String?,
      creditScore: json['creditScore'] as String?,

      // Family Information
      maritalStatus: json['maritalStatus'] as String?,
      spouseName: json['spouseName'] as String?,
      fatherName: json['fatherName'] as String?,
      motherName: json['motherName'] as String?,

      // Reference Details
      reference1Name: json['reference1Name'] as String?,
      reference1Address: json['reference1Address'] as String?,
      reference1Contact: json['reference1Contact'] as String?,
      reference2Name: json['reference2Name'] as String?,
      reference2Address: json['reference2Address'] as String?,
      reference2Contact: json['reference2Contact'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // Basic Information
      'nameAsPerAadhaar': nameAsPerAadhaar,
      'dateOfBirth': dateOfBirth?.toUtc().toIso8601String(),
      'panNo': panNo,
      'aadhaarNumber': aadhaarNumber,
      'mobileNumber': mobileNumber,
      'personalEmailId': personalEmailId,

      // Residence Information
      'countryOfResidence': countryOfResidence,
      'residenceAddress': residenceAddress,
      'addressDifferentFromAadhaar': addressDifferentFromAadhaar,
      'currentResidenceAddress': currentResidenceAddress,
      'residenceType': residenceType,
      'residenceStability': residenceStability,

      // Company Information
      'companyName': companyName,
      'companyAddress': companyAddress,

      // Personal Details
      'nationality': nationality,
      'countryOfBirth': countryOfBirth,
      'occupation': occupation,
      'educationalQualification': educationalQualification,
      'workType': workType,
      'industry': industry,
      'annualIncome': annualIncome,
      'totalWorkExperience': totalWorkExperience,
      'currentCompanyExperience': currentCompanyExperience,
      'loanAmount': loanAmount,
      'loanTenure': loanTenure,
      'loanAmountTenure': loanAmountTenure,
      'monthlyIncome': monthlyIncome,
      'currentEmi': currentEmi,
      'existingLoans': existingLoans,
      'creditScore': creditScore,

      // Family Information
      'maritalStatus': maritalStatus,
      'spouseName': spouseName,
      'fatherName': fatherName,
      'motherName': motherName,

      // Reference Details
      'reference1Name': reference1Name,
      'reference1Address': reference1Address,
      'reference1Contact': reference1Contact,
      'reference2Name': reference2Name,
      'reference2Address': reference2Address,
      'reference2Contact': reference2Contact,
    };
  }

  // Legacy getters for backward compatibility
  String? get fullName => nameAsPerAadhaar;
  String? get address => residenceAddress;
  String? get mobile => mobileNumber;
  String? get email => personalEmailId;
  String? get employmentStatus => occupation;

  bool get isComplete {
    final needsCurrentAddress = addressDifferentFromAadhaar == true;
    return nameAsPerAadhaar != null &&
        nameAsPerAadhaar!.trim().isNotEmpty &&
        dateOfBirth != null &&
        panNo != null &&
        panNo!.trim().isNotEmpty &&
        aadhaarNumber != null &&
        aadhaarNumber!.trim().isNotEmpty &&
        mobileNumber != null &&
        mobileNumber!.trim().isNotEmpty &&
        personalEmailId != null &&
        personalEmailId!.trim().isNotEmpty &&
        residenceAddress != null &&
        residenceAddress!.trim().isNotEmpty &&
        (!needsCurrentAddress ||
            (currentResidenceAddress != null &&
                currentResidenceAddress!.trim().isNotEmpty));
  }

  /// Debug method to check which fields are missing
  List<String> getMissingFields() {
    final missing = <String>[];
    final needsCurrentAddress = addressDifferentFromAadhaar == true;
    if (nameAsPerAadhaar == null || nameAsPerAadhaar!.trim().isEmpty) {
      missing.add('Name as per Aadhaar');
    }
    if (dateOfBirth == null) {
      missing.add('Date of Birth');
    }
    if (panNo == null || panNo!.trim().isEmpty) {
      missing.add('PAN No');
    }
    if (aadhaarNumber == null || aadhaarNumber!.trim().isEmpty) {
      missing.add('Aadhaar Number');
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
    if (needsCurrentAddress &&
        (currentResidenceAddress == null ||
            currentResidenceAddress!.trim().isEmpty)) {
      missing.add('Current Residence Address');
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

