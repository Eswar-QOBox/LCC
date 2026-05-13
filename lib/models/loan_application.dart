import 'dart:convert';

class LoanApplication {
  final String id;
  final String userId;
  final String loanType;
  final int currentStep;
  final String status; // draft, in_progress, paused, submitted, approved, rejected
  final String applicationId;
  final double? loanAmount;
  final Map<String, dynamic>? step1Selfie;
  final Map<String, dynamic>? step2Aadhaar;
  final Map<String, dynamic>? step3Pan;
  final Map<String, dynamic>? step4BankStatement;
  final Map<String, dynamic>? step5PersonalData;
  final Map<String, dynamic>? step6Preview;
  final Map<String, dynamic>? step7Submission;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? submittedAt;

  LoanApplication({
    required this.id,
    required this.userId,
    required this.loanType,
    required this.currentStep,
    required this.status,
    required this.applicationId,
    this.loanAmount,
    this.step1Selfie,
    this.step2Aadhaar,
    this.step3Pan,
    this.step4BankStatement,
    this.step5PersonalData,
    this.step6Preview,
    this.step7Submission,
    required this.createdAt,
    required this.updatedAt,
    this.submittedAt,
  });

  LoanApplication copyWith({String? loanType}) {
    return LoanApplication(
      id: id,
      userId: userId,
      loanType: loanType ?? this.loanType,
      currentStep: currentStep,
      status: status,
      applicationId: applicationId,
      loanAmount: loanAmount,
      step1Selfie: step1Selfie,
      step2Aadhaar: step2Aadhaar,
      step3Pan: step3Pan,
      step4BankStatement: step4BankStatement,
      step5PersonalData: step5PersonalData,
      step6Preview: step6Preview,
      step7Submission: step7Submission,
      createdAt: createdAt,
      updatedAt: updatedAt,
      submittedAt: submittedAt,
    );
  }

  static String _normalizeBackendLoanType(String raw) {
    if (raw == 'Education Loan') return 'Student Loan';
    return raw;
  }

  /// Parse a JHipster LoanSubmissionDTO.
  /// Step data and app-level status are stored in the 'remarks' field as JSON.
  factory LoanApplication.fromJhipsterJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';

    // Decode meta from remarks (set by loan_application_service on create/update)
    Map<String, dynamic> meta = {};
    final remarksRaw = json['remarks'] as String?;
    if (remarksRaw != null && remarksRaw.startsWith('{')) {
      try {
        meta = jsonDecode(remarksRaw) as Map<String, dynamic>;
      } catch (_) {}
    }

    final currentStep = (meta['currentStep'] as num?)?.toInt() ?? 1;
    final status = (meta['status'] as String?) ?? 'draft';
    final loanAmount = (meta['loanAmount'] as num?)?.toDouble();

    Map<String, dynamic>? safeMap(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : null;

    String? readLeadIdFromStep(Map<String, dynamic>? step) {
      if (step == null) return null;
      final uploaded = step['uploadedFile'];
      if (uploaded is Map) {
        final lead = uploaded['lead'];
        if (lead is Map && lead['id'] != null) {
          return lead['id'].toString();
        }
      }
      final lead = step['lead'];
      if (lead is Map && lead['id'] != null) {
        return lead['id'].toString();
      }
      return null;
    }

    /// When the list API omits top-level `lead`, CRM lead id may still exist under step uploads.
    String? inferLeadIdFromRemarksMeta(Map<String, dynamic> meta) {
      const keys = <String>[
        'step1Selfie',
        'step2Aadhaar',
        'step3Pan',
        'step4BankStatement',
        'step5PersonalData',
        'step6Preview',
        'step7Submission',
      ];
      for (final k in keys) {
        final v = meta[k];
        if (v is Map<String, dynamic>) {
          final lid = readLeadIdFromStep(v);
          if (lid != null && lid.isNotEmpty) return lid;
        } else if (v is Map) {
          final lid = readLeadIdFromStep(Map<String, dynamic>.from(v));
          if (lid != null && lid.isNotEmpty) return lid;
        }
      }
      return null;
    }

    final loanType = _normalizeBackendLoanType(
      json['loanType'] as String? ?? 'Personal Loan',
    );

    // applicantName is reused as applicationId in our mapping
    final applicationId = json['applicantName'] as String? ?? id;

    // lead.id is the userId equivalent in JHipster (CRM lead). Backend sometimes returns `lead: null`
    // on list DTOs; infer from remarks so we can filter client-side to the logged-in customer.
    final leadMap = json['lead'] as Map<String, dynamic>?;
    var userId = leadMap?['id']?.toString() ?? '';
    if (userId.isEmpty) {
      final inferred = inferLeadIdFromRemarksMeta(meta);
      if (inferred != null && inferred.isNotEmpty) {
        userId = inferred;
      }
    }

    DateTime parseDate(dynamic v) {
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {}
      }
      return DateTime.now();
    }

    return LoanApplication(
      id: id,
      userId: userId,
      loanType: loanType,
      currentStep: currentStep,
      status: status,
      applicationId: applicationId,
      loanAmount: loanAmount,
      step1Selfie: safeMap(meta['step1Selfie']),
      step2Aadhaar: safeMap(meta['step2Aadhaar']),
      step3Pan: safeMap(meta['step3Pan']),
      step4BankStatement: safeMap(meta['step4BankStatement']),
      step5PersonalData: safeMap(meta['step5PersonalData']),
      step6Preview: safeMap(meta['step6Preview']),
      step7Submission: safeMap(meta['step7Submission']),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['respondedAt'] ?? json['createdAt']),
      submittedAt: status == 'submitted' ? parseDate(json['respondedAt'] ?? json['createdAt']) : null,
    );
  }

  /// Parse the old Flask/MongoDB JSON format (kept for backwards compatibility).
  factory LoanApplication.fromJson(Map<String, dynamic> json) {
    // If this looks like a JHipster response (has 'loanType' but no 'userId' or 'applicationId')
    if (json.containsKey('loanType') && !json.containsKey('applicationId')) {
      return LoanApplication.fromJhipsterJson(json);
    }

    return LoanApplication(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? '',
      loanType: _normalizeBackendLoanType(json['loanType'] as String? ?? ''),
      currentStep: json['currentStep'] is int
          ? json['currentStep'] as int
          : int.tryParse(json['currentStep']?.toString() ?? '') ?? 1,
      status: json['status'] as String? ?? 'draft',
      applicationId: json['applicationId'] as String? ?? json['id'] as String,
      loanAmount: json['loanAmount'] != null
          ? (json['loanAmount'] is int
              ? (json['loanAmount'] as int).toDouble()
              : json['loanAmount'] as double)
          : null,
      step1Selfie: json['step1Selfie'] as Map<String, dynamic>?,
      step2Aadhaar: json['step2Aadhaar'] as Map<String, dynamic>?,
      step3Pan: json['step3Pan'] as Map<String, dynamic>?,
      step4BankStatement: json['step4BankStatement'] as Map<String, dynamic>?,
      step5PersonalData: json['step5PersonalData'] as Map<String, dynamic>?,
      step6Preview: json['step6Preview'] as Map<String, dynamic>?,
      step7Submission: json['step7Submission'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : null,
    );
  }

  /// Serialise all app-level fields that JHipster doesn't have native columns for.
  /// This map is JSON-encoded into the 'remarks' field on PUT/POST.
  Map<String, dynamic> toMetaMap() {
    return {
      'currentStep': currentStep,
      'status': status,
      if (loanAmount != null) 'loanAmount': loanAmount,
      if (step1Selfie != null) 'step1Selfie': step1Selfie,
      if (step2Aadhaar != null) 'step2Aadhaar': step2Aadhaar,
      if (step3Pan != null) 'step3Pan': step3Pan,
      if (step4BankStatement != null) 'step4BankStatement': step4BankStatement,
      if (step5PersonalData != null) 'step5PersonalData': step5PersonalData,
      if (step6Preview != null) 'step6Preview': step6Preview,
      if (step7Submission != null) 'step7Submission': step7Submission,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'loanType': loanType,
      'currentStep': currentStep,
      'status': status,
      'applicationId': applicationId,
      'loanAmount': loanAmount,
      'step1Selfie': step1Selfie,
      'step2Aadhaar': step2Aadhaar,
      'step3Pan': step3Pan,
      'step4BankStatement': step4BankStatement,
      'step5PersonalData': step5PersonalData,
      'step6Preview': step6Preview,
      'step7Submission': step7Submission,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'submittedAt': submittedAt?.toIso8601String(),
    };
  }

  bool get isPaused => status == 'paused';
  bool get isInProgress => status == 'in_progress';
  bool get isDraft => status == 'draft';
  bool get isSubmitted => status == 'submitted';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get canContinue => isPaused || isDraft;
  bool get canPause => isInProgress;
}
