import 'package:flutter/foundation.dart';
import '../models/loan_application.dart';
import '../services/loan_application_service.dart';
import '../utils/developer_mode.dart';

/// Provider to manage the current loan application being worked on
class ApplicationProvider with ChangeNotifier {
  final LoanApplicationService _applicationService = LoanApplicationService();
  
  LoanApplication? _currentApplication;
  bool _isLoading = false;
  String? _error;

  LoanApplication? get currentApplication => _currentApplication;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasApplication => _currentApplication != null;

  /// Set the current application
  void setApplication(LoanApplication application) {
    _currentApplication = application;
    _error = null;
    notifyListeners();
  }

  /// Clear the current application
  void clearApplication() {
    _currentApplication = null;
    _error = null;
    notifyListeners();
  }

  /// Backend may normalize loan labels to Personal Loan; preserve selected label in app.
  Future<LoanApplication> _preserveNormalizedLoanLabels(LoanApplication fromServer) async {
    if (fromServer.loanType != 'Personal Loan') return fromServer;
    if (_currentApplication?.loanType == 'Professional Loan') {
      return fromServer.copyWith(loanType: 'Professional Loan');
    }
    if (_currentApplication?.loanType == 'Student Loan') {
      return fromServer.copyWith(loanType: 'Student Loan');
    }
    final isStoredAsPro = await isProfessionalLoanApplicationId(fromServer.id);
    if (isStoredAsPro) {
      return fromServer.copyWith(loanType: 'Professional Loan');
    }
    final isStoredAsStudent = await isStudentLoanApplicationId(fromServer.id);
    if (isStoredAsStudent) {
      return fromServer.copyWith(loanType: 'Student Loan');
    }
    return fromServer;
  }

  /// Load application by ID
  Future<void> loadApplication(String applicationId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final application = await _applicationService.getApplication(applicationId);
      _currentApplication = await _preserveNormalizedLoanLabels(application);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Update the current application
  Future<void> updateApplication({
    int? currentStep,
    String? status,
    Map<String, dynamic>? step1Selfie,
    Map<String, dynamic>? step2Aadhaar,
    Map<String, dynamic>? step3Pan,
    Map<String, dynamic>? step4BankStatement,
    Map<String, dynamic>? step5PersonalData,
    Map<String, dynamic>? step6Preview,
    Map<String, dynamic>? step7Submission,
  }) async {
    if (_currentApplication == null) {
      throw Exception('No current application');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await _applicationService.updateApplication(
        _currentApplication!.id,
        currentStep: currentStep,
        status: status,
        step1Selfie: step1Selfie,
        step2Aadhaar: step2Aadhaar,
        step3Pan: step3Pan,
        step4BankStatement: step4BankStatement,
        step5PersonalData: step5PersonalData,
        step6Preview: step6Preview,
        step7Submission: step7Submission,
      );
      _currentApplication = await _preserveNormalizedLoanLabels(updated);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Refresh the current application from server
  Future<void> refreshApplication() async {
    if (_currentApplication == null) return;
    await loadApplication(_currentApplication!.id);
  }
}
