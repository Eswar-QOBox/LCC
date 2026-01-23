class LoanApplication {
  final String id;
  final String userId;
  final String loanType;
  final int currentStep;
  final String
  status; // draft, in_progress, paused, submitted, approved, rejected
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

  factory LoanApplication.fromJson(Map<String, dynamic> json) {
    return LoanApplication(
      id: json['id'] as String,
      userId: json['userId'] as String,
      loanType: json['loanType'] as String,
      currentStep: json['currentStep'] is int
          ? json['currentStep'] as int
          : int.tryParse(json['currentStep'].toString()) ?? 1,
      status: json['status'] as String,
      applicationId: json['applicationId'] as String,
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
