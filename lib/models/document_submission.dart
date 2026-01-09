class DocumentSubmission {
  String? selfiePath;
  AadhaarDocument? aadhaar;
  PanDocument? pan;
  BankStatement? bankStatement;
  PersonalData? personalData;
  DateTime? submittedAt;
  SubmissionStatus status;

  DocumentSubmission({
    this.selfiePath,
    this.aadhaar,
    this.pan,
    this.bankStatement,
    this.personalData,
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
        personalData!.isComplete;
  }
}

class AadhaarDocument {
  String? frontPath;
  String? backPath;
  String? pdfPassword;
  bool isPdf;

  AadhaarDocument({
    this.frontPath,
    this.backPath,
    this.pdfPassword,
    this.isPdf = false,
  });

  bool get isComplete => frontPath != null && backPath != null;
}

class PanDocument {
  String? frontPath;
  String? pdfPassword;
  bool isPdf;

  PanDocument({
    this.frontPath,
    this.pdfPassword,
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

class PersonalData {
  String? fullName;
  DateTime? dateOfBirth;
  String? address;
  String? mobile;
  String? email;
  String? employmentStatus;
  String? incomeDetails;

  PersonalData({
    this.fullName,
    this.dateOfBirth,
    this.address,
    this.mobile,
    this.email,
    this.employmentStatus,
    this.incomeDetails,
  });

  bool get isComplete {
    return fullName != null &&
        fullName!.isNotEmpty &&
        dateOfBirth != null &&
        address != null &&
        address!.isNotEmpty &&
        mobile != null &&
        mobile!.isNotEmpty &&
        email != null &&
        email!.isNotEmpty &&
        employmentStatus != null &&
        employmentStatus!.isNotEmpty;
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

