enum DocumentCategory {
  applicant,
  spouse,
}

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
        // Spouse documents
        'spouse_aadhaar': 'Spouse Aadhaar Card',
        'spouse_pan': 'Spouse PAN Card',
        'spouse_bank_statement': 'Spouse Bank Statement',
        'spouse_salary_slip': 'Spouse Salary Slip',
        'spouse_employment_letter': 'Spouse Employment Letter',
        'spouse_form16': 'Spouse Form 16',
        'spouse_it_return': 'Spouse IT Return',
        'spouse_other': 'Spouse Other Document',
        // Regular documents (default to applicant)
        'selfies': 'Selfie',
        'selfie': 'Selfie',
        'aadhaar': 'Aadhaar Card',
        'pan': 'PAN Card',
        'bank_statements': 'Bank Statement',
        'bank_statement': 'Bank Statement',
        'salary_slips': 'Salary Slip',
        'salary_slip': 'Salary Slip',
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

    // Check if uploaded
    final isUploaded = uploadedDocTypes.contains(id);
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
      id: json['id'] as String? ?? '',
      documentType: json['folder'] as String? ?? json['category'] as String? ?? '',
      fileName: json['name'] as String? ?? json['filename'] as String? ?? '',
      fileSize: json['size'] as String? ?? '0 KB',
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.parse(json['uploadedAt'] as String)
          : DateTime.now(),
      url: json['url'] as String?,
      status: _parseStatus(json['status'] as String?),
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  static DocumentStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'verified':
        return DocumentStatus.verified;
      case 'rejected':
        return DocumentStatus.rejected;
      case 'uploaded':
      default:
        return DocumentStatus.uploaded;
    }
  }
}
