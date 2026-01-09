import 'package:flutter/foundation.dart';
import '../models/document_submission.dart';

class SubmissionProvider with ChangeNotifier {
  DocumentSubmission _submission = DocumentSubmission();

  DocumentSubmission get submission => _submission;

  // Selfie
  void setSelfie(String path) {
    _submission.selfiePath = path;
    notifyListeners();
  }

  // Aadhaar
  void setAadhaarFront(String path, {bool isPdf = false}) {
    _submission.aadhaar ??= AadhaarDocument(isPdf: isPdf);
    _submission.aadhaar!.frontPath = path;
    _submission.aadhaar!.isPdf = isPdf;
    notifyListeners();
  }

  void setAadhaarBack(String path) {
    _submission.aadhaar ??= AadhaarDocument();
    _submission.aadhaar!.backPath = path;
    notifyListeners();
  }

  void setAadhaarPassword(String password) {
    _submission.aadhaar ??= AadhaarDocument();
    _submission.aadhaar!.pdfPassword = password;
    notifyListeners();
  }

  // PAN
  void setPanFront(String path, {bool isPdf = false}) {
    _submission.pan ??= PanDocument(isPdf: isPdf);
    _submission.pan!.frontPath = path;
    _submission.pan!.isPdf = isPdf;
    notifyListeners();
  }

  void setPanPassword(String password) {
    _submission.pan ??= PanDocument();
    _submission.pan!.pdfPassword = password;
    notifyListeners();
  }

  // Bank Statement
  void setBankStatementPages(List<String> pages, {bool isPdf = false}) {
    _submission.bankStatement ??= BankStatement(isPdf: isPdf);
    _submission.bankStatement!.pages = pages;
    _submission.bankStatement!.isPdf = isPdf;
    notifyListeners();
  }

  void addBankStatementPage(String path) {
    _submission.bankStatement ??= BankStatement();
    _submission.bankStatement!.pages = [
      ..._submission.bankStatement!.pages,
      path,
    ];
    notifyListeners();
  }

  void setBankStatementPassword(String password) {
    _submission.bankStatement ??= BankStatement();
    _submission.bankStatement!.pdfPassword = password;
    notifyListeners();
  }

  // Personal Data
  void setPersonalData(PersonalData data) {
    _submission.personalData = data;
    notifyListeners();
  }

  void updatePersonalDataField({
    String? fullName,
    DateTime? dateOfBirth,
    String? address,
    String? mobile,
    String? email,
    String? employmentStatus,
    String? incomeDetails,
  }) {
    _submission.personalData ??= PersonalData();
    if (fullName != null) _submission.personalData!.fullName = fullName;
    if (dateOfBirth != null) {
      _submission.personalData!.dateOfBirth = dateOfBirth;
    }
    if (address != null) _submission.personalData!.address = address;
    if (mobile != null) _submission.personalData!.mobile = mobile;
    if (email != null) _submission.personalData!.email = email;
    if (employmentStatus != null) {
      _submission.personalData!.employmentStatus = employmentStatus;
    }
    if (incomeDetails != null) {
      _submission.personalData!.incomeDetails = incomeDetails;
    }
    notifyListeners();
  }

  // Submission
  Future<void> submit() async {
    if (!_submission.isComplete) {
      throw Exception('Submission is not complete');
    }

    _submission.submittedAt = DateTime.now();
    _submission.status = SubmissionStatus.pendingVerification;

    // Here you would upload to backend
    // await uploadToBackend(_submission);

    notifyListeners();
  }

  void reset() {
    _submission = DocumentSubmission();
    notifyListeners();
  }
}

