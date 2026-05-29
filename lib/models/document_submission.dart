class DocumentSubmission {
  /// The selected loan type (e.g. "Personal Loan", "Business Loan")
  String? loanType;

  /// Business subtype for Business Loan (e.g. "proprietor", "partnership", "pvt_limited")
  String? businessLoanType;

  /// Professional subtype for Professional Loan (e.g. "doctor", "ca")
  String? professionalLoanType;

  String? selfiePath;
  AadhaarDocument? aadhaar;
  PanDocument? pan;
  BankStatement? bankStatement;
  /// Co-applicant bank statement (joint personal loan only).
  BankStatement? coApplicantBankStatement;
  BusinessDocuments? businessDocuments;
  ProfessionalDocuments? professionalDocuments;
  StudentDocuments? studentDocuments;
  /// Mortgage Loan property documents (one or more named uploads).
  PropertyDetailsDocuments? propertyDetailsDocuments;
  PersonalData? personalData;
  SalarySlips? salarySlips;
  /// Co-applicant salary slips (joint personal loan only).
  SalarySlips? coApplicantSalarySlips;
  /// Co-applicant (joint applicant) for personal loan: when true, co-applicant Aadhaar & PAN required.
  bool hasCoApplicant = false;
  AadhaarDocument? coApplicantAadhaar;
  PanDocument? coApplicantPan;
  /// Extracted Aadhaar number for co-applicant (for duplicate validation).
  String? coApplicantExtractedAadhaarNumber;
  /// Name from co-applicant Aadhaar OCR (for bank / payslip name checks before personal data is filled).
  String? coApplicantExtractedNameFromAadhaar;
  /// Co-applicant personal details (when hasCoApplicant is true).
  CoApplicantPersonalData? coApplicantPersonalData;
  /// Co-applicant firm type for car loan: 'partnership' | 'pvt_limited' | null (individual).
  String? coApplicantFirmType;
  /// Co-applicant firm documents (when coApplicantFirmType is set).
  CoApplicantFirmDocuments? coApplicantFirmDocuments;
  DateTime? submittedAt;
  SubmissionStatus status;

  DocumentSubmission({
    this.loanType,
    this.businessLoanType,
    this.professionalLoanType,
    this.selfiePath,
    this.aadhaar,
    this.pan,
    this.bankStatement,
    this.coApplicantBankStatement,
    this.businessDocuments,
    this.professionalDocuments,
    this.studentDocuments,
    this.propertyDetailsDocuments,
    this.personalData,
    this.salarySlips,
    this.coApplicantSalarySlips,
    this.hasCoApplicant = false,
    this.coApplicantAadhaar,
    this.coApplicantPan,
    this.coApplicantExtractedAadhaarNumber,
    this.coApplicantExtractedNameFromAadhaar,
    this.coApplicantPersonalData,
    this.coApplicantFirmType,
    this.coApplicantFirmDocuments,
    this.submittedAt,
    this.status = SubmissionStatus.inProgress,
  });

  bool get isCoApplicantKycComplete =>
      (coApplicantAadhaar?.isComplete ?? false) && (coApplicantPan?.isComplete ?? false);

  bool get isComplete {
    final isBusinessLoan = (loanType ?? '').toLowerCase().contains('business');
    final businessType = (businessLoanType ?? '').toLowerCase();
    final isProprietor = businessType == 'proprietor';
    final isPartnership = businessType == 'partnership';
    final isPvtLimited = businessType == 'pvt_limited';

    // Business Loan (Proprietor) flow: no salary slips; requires extra business docs.
    if (isBusinessLoan && isProprietor) {
      return selfiePath != null &&
          aadhaar != null &&
          aadhaar!.isComplete &&
          pan != null &&
          pan!.isComplete &&
          bankStatement != null &&
          bankStatement!.isComplete &&
          businessDocuments != null &&
          businessDocuments!.isCompleteForProprietor &&
          personalData != null &&
          personalData!.isComplete;
    }

    // Business Loan (Partnership) flow: no salary slips; requires partner KYC + common business docs.
    if (isBusinessLoan && isPartnership) {
      return selfiePath != null &&
          aadhaar != null &&
          aadhaar!.isComplete &&
          pan != null &&
          pan!.isComplete &&
          bankStatement != null &&
          bankStatement!.isComplete &&
          businessDocuments != null &&
          businessDocuments!.isCompleteForPartnership &&
          personalData != null &&
          personalData!.isComplete;
    }

    // Business Loan (Pvt Limited) flow: same as partnership but company docs = Company PAN + MOA + AOA.
    if (isBusinessLoan && isPvtLimited) {
      return selfiePath != null &&
          aadhaar != null &&
          aadhaar!.isComplete &&
          pan != null &&
          pan!.isComplete &&
          bankStatement != null &&
          bankStatement!.isComplete &&
          businessDocuments != null &&
          businessDocuments!.isCompleteForPvtLimited &&
          personalData != null &&
          personalData!.isComplete;
    }

    // Any other Business Loan: never require salary slips (subtype may be restored later).
    if (isBusinessLoan) {
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

    // Professional Loan flow (Doctor/CA): requires professional docs only; no salary slips.
    final isProfessionalLoan = (loanType ?? '').toLowerCase().contains('professional');
    final professionalType = (professionalLoanType ?? '').toLowerCase();
    if (isProfessionalLoan && (professionalType == 'doctor' || professionalType == 'ca')) {
      return selfiePath != null &&
          aadhaar != null &&
          aadhaar!.isComplete &&
          pan != null &&
          pan!.isComplete &&
          bankStatement != null &&
          bankStatement!.isComplete &&
          professionalDocuments != null &&
          professionalDocuments!.isComplete(professionalType) &&
          personalData != null &&
          personalData!.isComplete;
    }

    // Student Loan flow: requires student docs; no salary slips (unless "if working" then payslips + ID).
    final isStudentLoan = (loanType ?? '').toLowerCase().contains('student');
    if (isStudentLoan) {
      return selfiePath != null &&
          aadhaar != null &&
          aadhaar!.isComplete &&
          pan != null &&
          pan!.isComplete &&
          bankStatement != null &&
          bankStatement!.isComplete &&
          studentDocuments != null &&
          studentDocuments!.isComplete &&
          personalData != null &&
          personalData!.isComplete;
    }

    // Default (personal loan flow): requires salary slips; if co-applicant, their KYC too.
    // Mortgage Loan additionally requires the property details documents.
    final isMortgageLoan = (loanType ?? '').toLowerCase().contains('mortgage');
    final propertyOk =
        !isMortgageLoan || (propertyDetailsDocuments?.isComplete ?? false);
    final personalBase = selfiePath != null &&
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
    if (!hasCoApplicant) return personalBase && propertyOk;
    return personalBase &&
        propertyOk &&
        isCoApplicantKycComplete &&
        coApplicantBankStatement != null &&
        coApplicantBankStatement!.isComplete &&
        coApplicantSalarySlips != null &&
        coApplicantSalarySlips!.isComplete &&
        (coApplicantPersonalData?.isComplete ?? false);
  }

  /// Debug method to check which parts are missing
  List<String> getMissingParts() {
    final missing = <String>[];
    final isBusinessLoan = (loanType ?? '').toLowerCase().contains('business');
    final businessType = (businessLoanType ?? '').toLowerCase();
    final isProprietor = businessType == 'proprietor';
    final isPartnership = businessType == 'partnership';
    final isPvtLimited = businessType == 'pvt_limited';

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
    if (isBusinessLoan && isProprietor) {
      if (businessDocuments == null || !businessDocuments!.isCompleteForProprietor) {
        missing.add(
          'Business Documents (${businessDocuments == null ? "not uploaded" : "incomplete"})',
        );
      }
    }
    if (isBusinessLoan && isPartnership) {
      if (businessDocuments == null || !businessDocuments!.isCompleteForPartnership) {
        missing.add(
          'Partners / Business Documents (${businessDocuments == null ? "not uploaded" : "incomplete"})',
        );
      }
    }
    if (isBusinessLoan && isPvtLimited) {
      if (businessDocuments == null || !businessDocuments!.isCompleteForPvtLimited) {
        missing.add(
          'Partners / Business Documents (MOA, AOA) (${businessDocuments == null ? "not uploaded" : "incomplete"})',
        );
      }
    }
    final isProfessionalLoan = (loanType ?? '').toLowerCase().contains('professional');
    final professionalType = (professionalLoanType ?? '').toLowerCase();
    if (isProfessionalLoan && (professionalType == 'doctor' || professionalType == 'ca')) {
      if (professionalDocuments == null || !professionalDocuments!.isComplete(professionalType)) {
        missing.add(
          'Professional Documents (${professionalDocuments == null ? "not uploaded" : "incomplete"})',
        );
      }
    }
    final isStudentLoan = (loanType ?? '').toLowerCase().contains('student');
    if (isStudentLoan) {
      if (studentDocuments == null || !studentDocuments!.isComplete) {
        missing.add(
          'Student Documents (${studentDocuments == null ? "not uploaded" : "incomplete"})',
        );
      }
    }
    if (personalData == null || !personalData!.isComplete) {
      if (personalData == null) {
        missing.add('Personal Data (not filled)');
      } else {
        final missingFields = personalData!.getMissingFields();
        missing.add('Personal Data - Missing: ${missingFields.join(", ")}');
      }
    }
    final isProfessionalDoctorOrCa = isProfessionalLoan && (professionalType == 'doctor' || professionalType == 'ca');
    if (!(isBusinessLoan && (isProprietor || isPartnership || isPvtLimited)) && !isProfessionalDoctorOrCa && !isStudentLoan) {
      if (salarySlips == null || !salarySlips!.isComplete) {
        final count = salarySlips?.uploadedCount ?? 0;
        missing.add(
          'Salary Slips (${salarySlips == null ? "not uploaded" : "$count/${SalarySlips.requiredSlipCount}"})',
        );
      }
    }
    final isMortgageLoan = (loanType ?? '').toLowerCase().contains('mortgage');
    if (isMortgageLoan && !(propertyDetailsDocuments?.isComplete ?? false)) {
      missing.add('Property Details (add at least one property document)');
    }
    if (hasCoApplicant) {
      if (!isCoApplicantKycComplete) {
        if (coApplicantAadhaar == null || !coApplicantAadhaar!.isComplete) {
          missing.add('Co-applicant Aadhaar (incomplete)');
        }
        if (coApplicantPan == null || !coApplicantPan!.isComplete) {
          missing.add('Co-applicant PAN (incomplete)');
        }
      }
      if (coApplicantBankStatement == null || !coApplicantBankStatement!.isComplete) {
        missing.add(
          'Co-applicant Bank Statement (${coApplicantBankStatement == null ? "not uploaded" : "incomplete"})',
        );
      }
      if (coApplicantSalarySlips == null || !coApplicantSalarySlips!.isComplete) {
        final count = coApplicantSalarySlips?.uploadedCount ?? 0;
        missing.add(
          'Co-applicant Salary Slips (${coApplicantSalarySlips == null ? "not uploaded" : "$count/${SalarySlips.requiredSlipCount}"})',
        );
      }
      if (coApplicantPersonalData == null || !coApplicantPersonalData!.isComplete) {
        missing.add('Co-applicant Personal Details (incomplete)');
      }
    }
    return missing;
  }
}

/// Co-applicant personal details (name, contact, address).
class CoApplicantPersonalData {
  String? nameAsPerAadhaar;
  DateTime? dateOfBirth;
  String? panNo;
  String? aadhaarNumber;
  String? mobileNumber;
  String? personalEmailId;
  String? residenceAddress;

  CoApplicantPersonalData({
    this.nameAsPerAadhaar,
    this.dateOfBirth,
    this.panNo,
    this.aadhaarNumber,
    this.mobileNumber,
    this.personalEmailId,
    this.residenceAddress,
  });

  bool get isComplete =>
      nameAsPerAadhaar != null &&
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
      residenceAddress!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'nameAsPerAadhaar': nameAsPerAadhaar,
        'dateOfBirth': dateOfBirth?.toUtc().toIso8601String(),
        'panNo': panNo,
        'aadhaarNumber': aadhaarNumber,
        'mobileNumber': mobileNumber,
        'personalEmailId': personalEmailId,
        'residenceAddress': residenceAddress,
      };

  static CoApplicantPersonalData? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final dob = json['dateOfBirth'];
    return CoApplicantPersonalData(
      nameAsPerAadhaar: json['nameAsPerAadhaar'] as String?,
      dateOfBirth: dob != null ? DateTime.tryParse(dob as String) : null,
      panNo: json['panNo'] as String?,
      aadhaarNumber: json['aadhaarNumber'] as String?,
      mobileNumber: json['mobileNumber'] as String?,
      personalEmailId: json['personalEmailId'] as String?,
      residenceAddress: json['residenceAddress'] as String?,
    );
  }
}

/// Firm documents for car loan co-applicant (Partnership or PVT LTD).
class CoApplicantFirmDocuments {
  String? firmPan;
  String? gst;
  String? partnershipDeed;
  String? incorporationCert;
  String? aoa;
  String? moa;
  String? bankStatement;
  String? itr1;
  String? itr2;
  String? kycPhoto1;
  String? kycPhoto2;
  String? kycPan;
  String? kycAddressProof;

  CoApplicantFirmDocuments({
    this.firmPan,
    this.gst,
    this.partnershipDeed,
    this.incorporationCert,
    this.aoa,
    this.moa,
    this.bankStatement,
    this.itr1,
    this.itr2,
    this.kycPhoto1,
    this.kycPhoto2,
    this.kycPan,
    this.kycAddressProof,
  });

  bool get isFirmPanUploaded => firmPan != null && firmPan!.trim().isNotEmpty;

  String? getField(String key) {
    switch (key) {
      case 'firm_pan': return firmPan;
      case 'gst': return gst;
      case 'partnership_deed': return partnershipDeed;
      case 'incorporation_cert': return incorporationCert;
      case 'aoa': return aoa;
      case 'moa': return moa;
      case 'bank_statement': return bankStatement;
      case 'itr_1': return itr1;
      case 'itr_2': return itr2;
      case 'kyc_photo_1': return kycPhoto1;
      case 'kyc_photo_2': return kycPhoto2;
      case 'kyc_pan': return kycPan;
      case 'kyc_address_proof': return kycAddressProof;
      default: return null;
    }
  }

  void setField(String key, String? value) {
    switch (key) {
      case 'firm_pan': firmPan = value; break;
      case 'gst': gst = value; break;
      case 'partnership_deed': partnershipDeed = value; break;
      case 'incorporation_cert': incorporationCert = value; break;
      case 'aoa': aoa = value; break;
      case 'moa': moa = value; break;
      case 'bank_statement': bankStatement = value; break;
      case 'itr_1': itr1 = value; break;
      case 'itr_2': itr2 = value; break;
      case 'kyc_photo_1': kycPhoto1 = value; break;
      case 'kyc_photo_2': kycPhoto2 = value; break;
      case 'kyc_pan': kycPan = value; break;
      case 'kyc_address_proof': kycAddressProof = value; break;
    }
  }

  Map<String, dynamic> toJson() => {
    'firmPan': firmPan,
    'gst': gst,
    'partnershipDeed': partnershipDeed,
    'incorporationCert': incorporationCert,
    'aoa': aoa,
    'moa': moa,
    'bankStatement': bankStatement,
    'itr1': itr1,
    'itr2': itr2,
    'kycPhoto1': kycPhoto1,
    'kycPhoto2': kycPhoto2,
    'kycPan': kycPan,
    'kycAddressProof': kycAddressProof,
  };

  static CoApplicantFirmDocuments? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return CoApplicantFirmDocuments(
      firmPan: json['firmPan'] as String?,
      gst: json['gst'] as String?,
      partnershipDeed: json['partnershipDeed'] as String?,
      incorporationCert: json['incorporationCert'] as String?,
      aoa: json['aoa'] as String?,
      moa: json['moa'] as String?,
      bankStatement: json['bankStatement'] as String?,
      itr1: json['itr1'] as String?,
      itr2: json['itr2'] as String?,
      kycPhoto1: json['kycPhoto1'] as String?,
      kycPhoto2: json['kycPhoto2'] as String?,
      kycPan: json['kycPan'] as String?,
      kycAddressProof: json['kycAddressProof'] as String?,
    );
  }
}

class UploadedDoc {
  String? path;
  bool isPdf;

  UploadedDoc({this.path, this.isPdf = false});

  bool get isComplete => path != null && path!.trim().isNotEmpty;
}

class BusinessDocuments {
  /// Spouse (wife/husband) documents
  AadhaarDocument? spouseAadhaar;
  PanDocument? spousePan;

  /// Partnership flow
  int? partnerCount;
  List<PartnerKyc> partners;

  /// Business certificates (photo or PDF)
  /// Partnership flow (company-level docs)
  UploadedDoc? companyPanCard;
  UploadedDoc? partnershipDeed;

  /// Pvt Limited flow: MOA & AOA
  UploadedDoc? moa;
  UploadedDoc? aoa;

  UploadedDoc? gstRegistration;
  UploadedDoc? labourCertificate;
  UploadedDoc? msmeCertificate;
  UploadedDoc? ownHouseProof; // OHP

  BusinessDocuments({
    this.spouseAadhaar,
    this.spousePan,
    this.partnerCount,
    List<PartnerKyc>? partners,
    this.companyPanCard,
    this.partnershipDeed,
    this.moa,
    this.aoa,
    this.gstRegistration,
    this.labourCertificate,
    this.msmeCertificate,
    this.ownHouseProof,
  }) : partners = partners ?? [];

  bool get hasGstOrLabour {
    return (gstRegistration?.isComplete ?? false) ||
        (labourCertificate?.isComplete ?? false);
  }

  /// At least one of GST, Labour licence, or UDYAM / MSME (policy: any one is enough).
  bool get hasGstLabourOrMsme {
    return hasGstOrLabour || (msmeCertificate?.isComplete ?? false);
  }

  bool get hasPartners => (partnerCount ?? 0) > 0 || partners.isNotEmpty;

  bool get isPartnerKycComplete {
    final count = partnerCount;
    if (count == null) {
      return partners.isNotEmpty && partners.every((p) => p.isComplete);
    }
    if (count <= 0) return false;
    if (partners.length < count) return false;
    return partners.take(count).every((p) => p.isComplete);
  }

  bool get isCommonBusinessDocsComplete {
    return hasGstLabourOrMsme &&
        ownHouseProof != null &&
        ownHouseProof!.isComplete;
  }

  bool get isPartnershipCompanyDocsComplete {
    return (companyPanCard?.isComplete ?? false) && (partnershipDeed?.isComplete ?? false);
  }

  bool get isPvtLimitedCompanyDocsComplete {
    return (companyPanCard?.isComplete ?? false) &&
        (moa?.isComplete ?? false) &&
        (aoa?.isComplete ?? false);
  }

  bool get isCompleteForProprietor {
    return spouseAadhaar != null &&
        spouseAadhaar!.isComplete &&
        spousePan != null &&
        spousePan!.isComplete &&
        isCommonBusinessDocsComplete;
  }

  bool get isCompleteForPartnership {
    return isPartnerKycComplete && isPartnershipCompanyDocsComplete && isCommonBusinessDocsComplete;
  }

  bool get isCompleteForPvtLimited {
    return isPartnerKycComplete && isPvtLimitedCompanyDocsComplete && isCommonBusinessDocsComplete;
  }

  /// Backwards-compatible "complete" flag.
  ///
  /// - If partners exist (partnership flow), uses `isCompleteForPartnership`.
  /// - Otherwise, uses `isCompleteForProprietor`.
  bool get isComplete => hasPartners ? isCompleteForPartnership : isCompleteForProprietor;
}

/// Professional Loan documents: Doctor (degree, licence, prescription, ITR) or CA (degree, COP, ICAI, ITR, Balance sheet, P&L).
class ProfessionalDocuments {
  /// Doctor: Medical degree certificate
  UploadedDoc? medicalDegree;
  /// Doctor: Medical licence / registration
  UploadedDoc? medicalLicence;
  /// Doctor: Prescription / clinic letterhead
  UploadedDoc? prescription;

  /// CA: CA degree / certificate
  UploadedDoc? caDegree;
  /// CA: Certificate of Practice
  UploadedDoc? certificateOfPractice;
  /// CA: ICAI membership certificate
  UploadedDoc? icaiCertificate;

  /// Both: ITR (Income Tax Return) for last 2 years
  UploadedDoc? itrYear1;
  UploadedDoc? itrYear2;

  /// CA only: Balance sheet (assets, liabilities, net worth)
  UploadedDoc? balanceSheet;
  /// CA only: P&L (Profit & Loss) statement
  UploadedDoc? plStatement;

  ProfessionalDocuments({
    this.medicalDegree,
    this.medicalLicence,
    this.prescription,
    this.caDegree,
    this.certificateOfPractice,
    this.icaiCertificate,
    this.itrYear1,
    this.itrYear2,
    this.balanceSheet,
    this.plStatement,
  });

  bool isComplete(String professionalType) {
    final t = professionalType.toLowerCase();
    final itrComplete = (itrYear1?.isComplete ?? false) && (itrYear2?.isComplete ?? false);
    if (t == 'doctor') {
      return (medicalDegree?.isComplete ?? false) &&
          (medicalLicence?.isComplete ?? false) &&
          (prescription?.isComplete ?? false) &&
          itrComplete;
    }
    if (t == 'ca') {
      return (caDegree?.isComplete ?? false) &&
          (certificateOfPractice?.isComplete ?? false) &&
          (icaiCertificate?.isComplete ?? false) &&
          itrComplete &&
          (balanceSheet?.isComplete ?? false) &&
          (plStatement?.isComplete ?? false);
    }
    return false;
  }
}

/// Student Loan documents: PAN, Aadhaar, optional Passport, Admission letter, Mark sheets (SSC, Inter, Graduation), 6 months bank statement; if working: 3 months payslips, ID card.
class StudentDocuments {
  UploadedDoc? passport;
  UploadedDoc? admissionLetter;
  UploadedDoc? markSheetSsc;
  UploadedDoc? markSheetInter;
  UploadedDoc? markSheetGraduation;
  /// If true, 3 months payslips and ID card are required.
  bool isWorking;
  UploadedDoc? payslip1;
  UploadedDoc? payslip2;
  UploadedDoc? payslip3;
  UploadedDoc? idCard;

  StudentDocuments({
    this.passport,
    this.admissionLetter,
    this.markSheetSsc,
    this.markSheetInter,
    this.markSheetGraduation,
    this.isWorking = false,
    this.payslip1,
    this.payslip2,
    this.payslip3,
    this.idCard,
  });

  bool get isComplete {
    // Passport is optional; admission letter and all three mark sheets are required.
    final base = (admissionLetter?.isComplete ?? false) &&
        (markSheetSsc?.isComplete ?? false) &&
        (markSheetInter?.isComplete ?? false) &&
        (markSheetGraduation?.isComplete ?? false);
    if (!isWorking) return base;
    return base &&
        (payslip1?.isComplete ?? false) &&
        (payslip2?.isComplete ?? false) &&
        (payslip3?.isComplete ?? false) &&
        (idCard?.isComplete ?? false);
  }
}

/// A single Mortgage property entry: a user-given name plus one uploaded document.
class PropertyDetailEntry {
  /// Stable id used for the upload document type key and resume matching.
  final String id;
  String? propertyName;
  String? path;
  bool isPdf;

  PropertyDetailEntry({
    required this.id,
    this.propertyName,
    this.path,
    this.isPdf = false,
  });

  bool get isComplete =>
      (propertyName ?? '').trim().isNotEmpty &&
      path != null &&
      path!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'propertyName': propertyName,
        'path': path,
        'isPdf': isPdf,
      };

  static PropertyDetailEntry fromJson(Map<String, dynamic> json) =>
      PropertyDetailEntry(
        id: (json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString())
            .toString(),
        propertyName: json['propertyName'] as String?,
        path: json['path'] as String?,
        isPdf: json['isPdf'] as bool? ?? false,
      );
}

/// Mortgage Loan property documents: one or more named property uploads.
class PropertyDetailsDocuments {
  List<PropertyDetailEntry> entries;

  PropertyDetailsDocuments({List<PropertyDetailEntry>? entries})
      : entries = entries ?? <PropertyDetailEntry>[];

  /// At least one entry with both a name and an uploaded file.
  bool get isComplete => entries.any((e) => e.isComplete);

  /// Only the fully-filled entries (name + file).
  List<PropertyDetailEntry> get completeEntries =>
      entries.where((e) => e.isComplete).toList();

  Map<String, dynamic> toJson() => {
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  static PropertyDetailsDocuments? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final rawEntries = json['entries'];
    final list = <PropertyDetailEntry>[];
    if (rawEntries is List) {
      for (final e in rawEntries) {
        if (e is Map) {
          list.add(PropertyDetailEntry.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return PropertyDetailsDocuments(entries: list);
  }
}

class PartnerKyc {
  AadhaarDocument? aadhaar;
  PanDocument? pan;
  /// OCR-extracted Aadhaar number for validation (e.g. partner cannot be same as applicant or other partners).
  String? extractedAadhaarNumber;

  PartnerKyc({this.aadhaar, this.pan, this.extractedAadhaarNumber});

  bool get isComplete => (aadhaar?.isComplete ?? false) && (pan?.isComplete ?? false);
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
  /// Account holder name extracted via OCR (approx match with Aadhaar name)
  String? extractedAccountHolderName;
  /// True when Aadhaar name words were found in bank statement OCR text; required to proceed.
  bool? nameMatchesAadhaar;

  BankStatement({
    this.pages = const [],
    this.pdfPassword,
    this.isPdf = false,
    this.statementDate,
    this.extractedAccountHolderName,
    this.nameMatchesAadhaar,
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
        residenceAddress!.trim().isNotEmpty;
    // Current/address-proof address is optional per business rule (electricity bill & address proof not compulsory)
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
    // Current residence / address proof is optional (not compulsory per business rule)
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

