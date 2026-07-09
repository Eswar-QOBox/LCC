import 'package:intl/intl.dart';

enum DocumentCategory {
  applicant,
  spouse,
}

/// Case-insensitive match for CRM enum strings (e.g. `IDENTITY` vs `identity`) and Flutter keys.
bool leadDocumentTypeMatches(String a, String b) =>
    a.toLowerCase().trim() == b.toLowerCase().trim();

/// Remove trailing re-upload markers so we do not chain `… · Reuploaded · Reuploaded`.
String stripLeadDocumentReuploadSuffix(String name) {
  var s = name.trim();
  s = s.replaceFirst(RegExp(r'\s*[·•]\s*Reuploaded\s*$', caseSensitive: false), '');
  s = s.replaceFirst(RegExp(r'\s*\(Reuploaded\)\s*$', caseSensitive: false), '');
  s = s.trim();
  return s.isEmpty ? name.trim() : s;
}

bool leadDocumentDisplayNameHasReuploadTag(String name) =>
    name.toLowerCase().contains('reuploaded');

enum DocumentStatus {
  pending,
  uploading,
  uploaded,
  verified,
  rejected,
}

class DocumentRequirement {
  final String id;
  final String label;
  final DocumentCategory category;
  final bool isCustom;
  DocumentStatus status;
  final String? uploadedDocumentId;
  final DateTime? uploadedAt;

  DocumentRequirement({
    required this.id,
    required this.label,
    required this.category,
    this.isCustom = false,
    this.status = DocumentStatus.pending,
    this.uploadedDocumentId,
    this.uploadedAt,
  });

  factory DocumentRequirement.fromId(String id, List<String> uploadedDocTypes) {
    // Parse document ID to get label and category
    final isCustom = id.startsWith('custom_');
    DocumentCategory category;
    String label;

    if (isCustom) {
      // Custom document: custom_applicant_driving_license
      final parts = id.split('_');
      if (parts.length >= 3) {
        category = parts[1] == 'applicant' ? DocumentCategory.applicant : DocumentCategory.spouse;
        label = parts.sublist(2).join(' ').replaceAll('_', ' ');
        label = label.split(' ').map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        }).join(' ');
      } else {
        category = DocumentCategory.applicant;
        label = id;
      }
    } else {
      // Predefined document labels
      final predefinedLabels = {
        // Applicant documents
        'applicant_aadhaar': 'Aadhaar Card',
        'applicant_pan': 'PAN Card',
        'applicant_bank_statement': 'Bank Statement',
        'applicant_salary_slip': 'Salary Slip',
        'applicant_employment_letter': 'Employment Letter',
        'applicant_form16': 'Form 16',
        'applicant_it_return': 'IT Return',
        'applicant_address_proof': 'Address Proof',
        'applicant_photo': 'Passport Photo',
        'applicant_other': 'Other Document',
        // Professional loan (no "Custom" prefix)
        'applicant_professional_medical_degree': 'Medical Degree',
        'applicant_professional_medical_licence': 'Medical Licence',
        'applicant_professional_prescription': 'Prescription / Letterhead',
        'applicant_professional_ca_degree': 'CA Degree',
        'applicant_professional_certificate_of_practice': 'Certificate of Practice',
        'applicant_professional_icai_certificate': 'ICAI Certificate',
        'applicant_professional_itr_year1': 'IT Return Year 1',
        'applicant_professional_itr_year2': 'IT Return Year 2',
        'applicant_professional_balance_sheet': 'Balance Sheet',
        'applicant_professional_pl_statement': 'P&L Statement',
        'applicant_company_pan_card': 'Company PAN Card',
        'applicant_partnership_deed': 'Partnership Deed',
        'applicant_moa': 'MOA',
        'applicant_aoa': 'AOA',
        'applicant_gst_registration': 'GST Registration',
        'applicant_labour_certificate': 'Labour Certificate',
        'applicant_msme_certificate': 'MSME Certificate',
        'applicant_ohp_own_house_proof': 'Own House Proof',
        // Co-applicant firm documents (car loan – Partnership / PVT LTD)
        'coapplicant_firm_firm_pan': 'Co-applicant Firm PAN Card',
        'coapplicant_firm_gst': 'Co-applicant Firm GST',
        'coapplicant_firm_partnership_deed': 'Co-applicant Partnership Deed',
        'coapplicant_firm_incorporation_cert': 'Co-applicant Incorporation Certificate',
        'coapplicant_firm_aoa': 'Co-applicant AOA',
        'coapplicant_firm_moa': 'Co-applicant MOA',
        'coapplicant_firm_bank_statement': 'Co-applicant Firm Bank Statement',
        'coapplicant_firm_itr_1': 'Co-applicant Firm ITR Year 1',
        'coapplicant_firm_itr_2': 'Co-applicant Firm ITR Year 2',
        'coapplicant_firm_kyc_photo_1': 'Co-applicant KYC Photo 1',
        'coapplicant_firm_kyc_photo_2': 'Co-applicant KYC Photo 2',
        'coapplicant_firm_kyc_pan': 'Co-applicant KYC PAN',
        'coapplicant_firm_kyc_address_proof': 'Co-applicant KYC Address Proof',
        // Co-applicant documents (business proprietor: spouse / parent / etc.)
        'spouse_aadhaar': 'Co-applicant Aadhaar Card',
        'spouse_pan': 'Co-applicant PAN Card',
        'spouse_bank_statement': 'Co-applicant Bank Statement',
        'spouse_salary_slip': 'Co-applicant Salary Slip',
        'spouse_employment_letter': 'Co-applicant Employment Letter',
        'spouse_form16': 'Co-applicant Form 16',
        'spouse_it_return': 'Co-applicant IT Return',
        'spouse_other': 'Co-applicant Other Document',
        // Regular documents (default to applicant)
        'selfies': 'Selfie',
        'selfie': 'Selfie',
        'aadhaar': 'Aadhaar Card',
        'pan': 'PAN Card',
        'bank_statements': 'Bank Statement',
        'bank_statement': 'Bank Statement',
        'salary_slips': 'Salary Slip',
        'salary_slip': 'Salary Slip',
        // CRM “Request additional documents” catalog (must match web slugs)
        'additional_salary_certificate': 'Salary Certificate',
        'additional_bank_statement_6m': 'Bank Statement (Last 6 Months)',
        'additional_trade_license': 'Trade License Copy',
        'additional_visa_copy': 'Visa Copy',
        'additional_emirates_id_back': 'Emirates ID (Back)',
        'additional_passport_copy': 'Passport Copy',
        'additional_cancelled_cheque': 'Cancelled Cheque',
        'additional_tenancy_contract': 'Tenancy Contract',
        'additional_utility_bill': 'Utility Bill (Address Proof)',
        'additional_employment_letter': 'Employment Letter',
        'additional_credit_card_statement': 'Credit Card Statement',
        'additional_existing_loan_statement': 'Existing Loan Statement',
      };

      // Determine label
      label = predefinedLabels[id] ?? id.replaceAll('_', ' ').split(' ').map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1);
      }).join(' ');

      // Determine category based on document ID
      if (id.startsWith('spouse_')) {
        category = DocumentCategory.spouse;
      } else if (id.startsWith('applicant_')) {
        category = DocumentCategory.applicant;
      } else {
        // Regular documents (selfies, aadhaar, pan, etc.) default to applicant
        // Only explicitly spouse documents go to spouse category
        category = DocumentCategory.applicant;
      }
    }

    // Check if uploaded (CRM enums vs Flutter keys may differ only by case)
    final isUploaded =
        uploadedDocTypes.any((t) => leadDocumentTypeMatches(t, id));
    final status = isUploaded ? DocumentStatus.uploaded : DocumentStatus.pending;

    return DocumentRequirement(
      id: id,
      label: label,
      category: category,
      isCustom: isCustom,
      status: status,
    );
  }
}

class UploadedDocument {
  final String id;
  final String documentType;
  final String fileName;
  final String fileSize;
  final DateTime uploadedAt;
  final String? url;
  final DocumentStatus status;
  final String? rejectionReason;

  UploadedDocument({
    required this.id,
    required this.documentType,
    required this.fileName,
    required this.fileSize,
    required this.uploadedAt,
    this.url,
    this.status = DocumentStatus.uploaded,
    this.rejectionReason,
  });

  factory UploadedDocument.fromJson(Map<String, dynamic> json) {
    return UploadedDocument(
      id: _stringField(json['id']),
      documentType:
          _stringField(json['folder']).isNotEmpty ? _stringField(json['folder']) : _stringField(json['category']),
      fileName: _stringField(json['name']).isNotEmpty ? _stringField(json['name']) : _stringField(json['filename']),
      fileSize: _stringField(json['size']).isNotEmpty ? _stringField(json['size']) : '0 KB',
      uploadedAt: _parseUploadedAt(json['uploadedAt'] ?? json['created_at']),
      url: json['url']?.toString(),
      status: _parseStatus(json['status']?.toString()),
      rejectionReason: json['rejectionReason']?.toString(),
    );
  }

  static String _stringField(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    return v.toString();
  }

  /// Backend may store human-readable dates from CRM; ISO from Flutter. Never throw — dropped rows hid rejected state.
  static DateTime _parseUploadedAt(dynamic raw) {
    if (raw == null) return DateTime.now();
    final s = raw.toString().trim();
    if (s.isEmpty) return DateTime.now();
    try {
      return DateTime.parse(s);
    } catch (_) {
      for (final pattern in ['MMM d, yyyy', 'MMMM d, yyyy', 'd/MM/yyyy', 'MM/dd/yyyy']) {
        try {
          return DateFormat(pattern, 'en_US').parseLoose(s);
        } catch (_) {}
      }
    }
    return DateTime.now();
  }

  static DocumentStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return DocumentStatus.pending;
      case 'verified':
        return DocumentStatus.verified;
      case 'rejected':
        return DocumentStatus.rejected;
      case 'uploaded':
      case 'uploading':
        return DocumentStatus.uploading;
      default:
        return DocumentStatus.uploaded;
    }
  }
}
