import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document_submission.dart';

// Conditional import for file operations - only on non-web platforms
import 'dart:io' if (dart.library.html) '../services/file_helper_stub.dart' as io;

class SubmissionProvider with ChangeNotifier {
  DocumentSubmission _submission = DocumentSubmission();
  bool _termsAccepted = false;
  bool _isInitialized = false;
  static const String _draftKey = 'submission_draft';
  static const String _termsAcceptedKey = 'terms_accepted_draft';

  DocumentSubmission get submission => _submission;
  bool get termsAccepted => _termsAccepted;
  bool get isInitialized => _isInitialized;

  /// Initialize the provider by loading any existing draft
  Future<void> initialize() async {
    if (_isInitialized) return;
    await loadDraft();
    _isInitialized = true;
  }

  // Selfie
  void setSelfie(String path) {
    _submission.selfiePath = path;
    notifyListeners();
  }

  // Aadhaar
  void setAadhaarFront(String path) {
    _submission.aadhaar ??= AadhaarDocument();
    _submission.aadhaar!.frontPath = path;
    notifyListeners();
  }

  void setAadhaarBack(String path) {
    _submission.aadhaar ??= AadhaarDocument();
    _submission.aadhaar!.backPath = path;
    notifyListeners();
  }

  // PAN
  void setPanFront(String path) {
    _submission.pan ??= PanDocument();
    _submission.pan!.frontPath = path;
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

  // Salary Slips
  void setSalarySlips(List<String> slips, {bool isPdf = false}) {
    _submission.salarySlips ??= SalarySlips(isPdf: isPdf);
    _submission.salarySlips!.slips = slips;
    _submission.salarySlips!.isPdf = isPdf;
    notifyListeners();
  }

  void addSalarySlip(String path) {
    _submission.salarySlips ??= SalarySlips();
    _submission.salarySlips!.slips = [
      ..._submission.salarySlips!.slips,
      path,
    ];
    notifyListeners();
  }

  void setSalarySlipsPassword(String password) {
    _submission.salarySlips ??= SalarySlips();
    _submission.salarySlips!.pdfPassword = password;
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
    // Map legacy fields to new fields for backward compatibility
    if (fullName != null) _submission.personalData!.nameAsPerAadhaar = fullName;
    if (dateOfBirth != null) {
      _submission.personalData!.dateOfBirth = dateOfBirth;
    }
    if (address != null) _submission.personalData!.residenceAddress = address;
    if (mobile != null) _submission.personalData!.mobileNumber = mobile;
    if (email != null) _submission.personalData!.personalEmailId = email;
    if (employmentStatus != null) {
      _submission.personalData!.occupation = employmentStatus;
    }
    if (incomeDetails != null) {
      _submission.personalData!.annualIncome = incomeDetails;
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

  // Terms & Conditions
  void acceptTerms() {
    _termsAccepted = true;
    notifyListeners();
  }

  void setTermsAccepted(bool value) {
    _termsAccepted = value;
    notifyListeners();
  }

  void reset() {
    _submission = DocumentSubmission();
    _termsAccepted = false;
    notifyListeners();
  }

  // Draft functionality
  Future<bool> saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftData = _submissionToJson(_submission);
      final jsonString = jsonEncode(draftData);
      
      // Save to SharedPreferences
      final saved = await prefs.setString(_draftKey, jsonString);
      await prefs.setBool(_termsAcceptedKey, _termsAccepted);
      
      if (saved) {
        debugPrint('✅ Draft saved successfully. Data size: ${jsonString.length} bytes');
        return true;
      } else {
        debugPrint('❌ Failed to save draft to SharedPreferences');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving draft: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<bool> loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftJson = prefs.getString(_draftKey);
      if (draftJson == null) return false;

      final draftData = jsonDecode(draftJson) as Map<String, dynamic>;
      _submission = _submissionFromJson(draftData);
      _termsAccepted = prefs.getBool(_termsAcceptedKey) ?? false;
      
      // Validate file paths and remove invalid ones
      await _validateAndCleanFilePaths();
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error loading draft: $e');
      return false;
    }
  }

  /// Validates file paths and removes invalid ones (files that don't exist)
  Future<void> _validateAndCleanFilePaths() async {
    if (kIsWeb) {
      // On web, we can't check file existence from paths
      // Files are typically stored as blobs/URLs, so we skip validation
      return;
    }

    bool hasInvalidFiles = false;

    // Validate selfie
    if (_submission.selfiePath != null) {
      final file = io.File(_submission.selfiePath!);
      if (!await file.exists()) {
        debugPrint('⚠️ Selfie file not found: ${_submission.selfiePath}');
        _submission.selfiePath = null;
        hasInvalidFiles = true;
      }
    }

    // Validate Aadhaar
    if (_submission.aadhaar != null) {
      if (_submission.aadhaar!.frontPath != null) {
        final file = io.File(_submission.aadhaar!.frontPath!);
        if (!await file.exists()) {
          debugPrint('⚠️ Aadhaar front file not found: ${_submission.aadhaar!.frontPath}');
          _submission.aadhaar!.frontPath = null;
          hasInvalidFiles = true;
        }
      }
      if (_submission.aadhaar!.backPath != null) {
        final file = io.File(_submission.aadhaar!.backPath!);
        if (!await file.exists()) {
          debugPrint('⚠️ Aadhaar back file not found: ${_submission.aadhaar!.backPath}');
          _submission.aadhaar!.backPath = null;
          hasInvalidFiles = true;
        }
      }
      // If both paths are null, clear the aadhaar document
      if (_submission.aadhaar!.frontPath == null && _submission.aadhaar!.backPath == null) {
        _submission.aadhaar = null;
      }
    }

    // Validate PAN
    if (_submission.pan != null && _submission.pan!.frontPath != null) {
      final file = io.File(_submission.pan!.frontPath!);
      if (!await file.exists()) {
        debugPrint('⚠️ PAN file not found: ${_submission.pan!.frontPath}');
        _submission.pan!.frontPath = null;
        hasInvalidFiles = true;
      }
      // If path is null, clear the pan document
      if (_submission.pan!.frontPath == null) {
        _submission.pan = null;
      }
    }

    // Validate Bank Statement
    if (_submission.bankStatement != null && _submission.bankStatement!.pages.isNotEmpty) {
      final validPages = <String>[];
      for (final pagePath in _submission.bankStatement!.pages) {
        final file = io.File(pagePath);
        if (await file.exists()) {
          validPages.add(pagePath);
        } else {
          debugPrint('⚠️ Bank statement page not found: $pagePath');
          hasInvalidFiles = true;
        }
      }
      _submission.bankStatement!.pages = validPages;
      // If no valid pages, clear the bank statement
      if (_submission.bankStatement!.pages.isEmpty) {
        _submission.bankStatement = null;
      }
    }

    // Validate Salary Slips
    if (_submission.salarySlips != null && _submission.salarySlips!.slips.isNotEmpty) {
      final validSlips = <String>[];
      for (final slipPath in _submission.salarySlips!.slips) {
        final file = io.File(slipPath);
        if (await file.exists()) {
          validSlips.add(slipPath);
        } else {
          debugPrint('⚠️ Salary slip file not found: $slipPath');
          hasInvalidFiles = true;
        }
      }
      _submission.salarySlips!.slips = validSlips;
      // If no valid slips, clear the salary slips
      if (_submission.salarySlips!.slips.isEmpty) {
        _submission.salarySlips = null;
      }
    }

    if (hasInvalidFiles) {
      debugPrint('⚠️ Some files from draft were deleted. Draft loaded with missing files.');
      // Optionally save the cleaned draft back
      await saveDraft();
    }
  }

  Future<bool> hasDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_draftKey);
    } catch (e) {
      return false;
    }
  }

  Future<bool> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
      await prefs.remove(_termsAcceptedKey);
      return true;
    } catch (e) {
      debugPrint('Error clearing draft: $e');
      return false;
    }
  }

  // JSON serialization helpers
  Map<String, dynamic> _submissionToJson(DocumentSubmission submission) {
    return {
      'selfiePath': submission.selfiePath,
      'aadhaar': submission.aadhaar != null
          ? {
              'frontPath': submission.aadhaar!.frontPath,
              'backPath': submission.aadhaar!.backPath,
            }
          : null,
      'pan': submission.pan != null
          ? {
              'frontPath': submission.pan!.frontPath,
            }
          : null,
      'bankStatement': submission.bankStatement != null
          ? {
              'pages': submission.bankStatement!.pages,
              'pdfPassword': submission.bankStatement!.pdfPassword,
              'isPdf': submission.bankStatement!.isPdf,
              'statementDate': submission.bankStatement!.statementDate?.toIso8601String(),
            }
          : null,
      'personalData': submission.personalData != null
          ? {
              'nameAsPerAadhaar': submission.personalData!.nameAsPerAadhaar,
              'dateOfBirth': submission.personalData!.dateOfBirth?.toIso8601String(),
              'panNo': submission.personalData!.panNo,
              'mobileNumber': submission.personalData!.mobileNumber,
              'personalEmailId': submission.personalData!.personalEmailId,
              'countryOfResidence': submission.personalData!.countryOfResidence,
              'residenceAddress': submission.personalData!.residenceAddress,
              'residenceType': submission.personalData!.residenceType,
              'residenceStability': submission.personalData!.residenceStability,
              'companyName': submission.personalData!.companyName,
              'companyAddress': submission.personalData!.companyAddress,
              'nationality': submission.personalData!.nationality,
              'countryOfBirth': submission.personalData!.countryOfBirth,
              'occupation': submission.personalData!.occupation,
              'educationalQualification': submission.personalData!.educationalQualification,
              'workType': submission.personalData!.workType,
              'industry': submission.personalData!.industry,
              'annualIncome': submission.personalData!.annualIncome,
              'totalWorkExperience': submission.personalData!.totalWorkExperience,
              'currentCompanyExperience': submission.personalData!.currentCompanyExperience,
              'loanAmountTenure': submission.personalData!.loanAmountTenure,
              'maritalStatus': submission.personalData!.maritalStatus,
              'spouseName': submission.personalData!.spouseName,
              'fatherName': submission.personalData!.fatherName,
              'motherName': submission.personalData!.motherName,
              'reference1Name': submission.personalData!.reference1Name,
              'reference1Address': submission.personalData!.reference1Address,
              'reference1Contact': submission.personalData!.reference1Contact,
              'reference2Name': submission.personalData!.reference2Name,
              'reference2Address': submission.personalData!.reference2Address,
              'reference2Contact': submission.personalData!.reference2Contact,
            }
          : null,
      'salarySlips': submission.salarySlips != null
          ? {
              'slips': submission.salarySlips!.slips,
              'pdfPassword': submission.salarySlips!.pdfPassword,
              'isPdf': submission.salarySlips!.isPdf,
            }
          : null,
      'submittedAt': submission.submittedAt?.toIso8601String(),
      'status': submission.status.toString().split('.').last,
    };
  }

  DocumentSubmission _submissionFromJson(Map<String, dynamic> json) {
    final submission = DocumentSubmission(
      selfiePath: json['selfiePath'] as String?,
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : null,
      status: _statusFromString(json['status'] as String? ?? 'inProgress'),
    );

    if (json['aadhaar'] != null) {
      final aadhaarData = json['aadhaar'] as Map<String, dynamic>;
      submission.aadhaar = AadhaarDocument(
        frontPath: aadhaarData['frontPath'] as String?,
        backPath: aadhaarData['backPath'] as String?,
      );
    }

    if (json['pan'] != null) {
      final panData = json['pan'] as Map<String, dynamic>;
      submission.pan = PanDocument(
        frontPath: panData['frontPath'] as String?,
      );
    }

    if (json['bankStatement'] != null) {
      final bankData = json['bankStatement'] as Map<String, dynamic>;
      submission.bankStatement = BankStatement(
        pages: (bankData['pages'] as List<dynamic>?)?.cast<String>() ?? [],
        pdfPassword: bankData['pdfPassword'] as String?,
        isPdf: bankData['isPdf'] as bool? ?? false,
        statementDate: bankData['statementDate'] != null
            ? DateTime.parse(bankData['statementDate'] as String)
            : null,
      );
    }

    if (json['personalData'] != null) {
      final personalData = json['personalData'] as Map<String, dynamic>;
      submission.personalData = PersonalData(
        nameAsPerAadhaar: personalData['nameAsPerAadhaar'] as String?,
        dateOfBirth: personalData['dateOfBirth'] != null
            ? DateTime.parse(personalData['dateOfBirth'] as String)
            : null,
        panNo: personalData['panNo'] as String?,
        mobileNumber: personalData['mobileNumber'] as String?,
        personalEmailId: personalData['personalEmailId'] as String?,
        countryOfResidence: personalData['countryOfResidence'] as String?,
        residenceAddress: personalData['residenceAddress'] as String?,
        residenceType: personalData['residenceType'] as String?,
        residenceStability: personalData['residenceStability'] as String?,
        companyName: personalData['companyName'] as String?,
        companyAddress: personalData['companyAddress'] as String?,
        nationality: personalData['nationality'] as String?,
        countryOfBirth: personalData['countryOfBirth'] as String?,
        occupation: personalData['occupation'] as String?,
        educationalQualification: personalData['educationalQualification'] as String?,
        workType: personalData['workType'] as String?,
        industry: personalData['industry'] as String?,
        annualIncome: personalData['annualIncome'] as String?,
        totalWorkExperience: personalData['totalWorkExperience'] as String?,
        currentCompanyExperience: personalData['currentCompanyExperience'] as String?,
        loanAmountTenure: personalData['loanAmountTenure'] as String?,
        maritalStatus: personalData['maritalStatus'] as String?,
        spouseName: personalData['spouseName'] as String?,
        fatherName: personalData['fatherName'] as String?,
        motherName: personalData['motherName'] as String?,
        reference1Name: personalData['reference1Name'] as String?,
        reference1Address: personalData['reference1Address'] as String?,
        reference1Contact: personalData['reference1Contact'] as String?,
        reference2Name: personalData['reference2Name'] as String?,
        reference2Address: personalData['reference2Address'] as String?,
        reference2Contact: personalData['reference2Contact'] as String?,
      );
    }

    if (json['salarySlips'] != null) {
      final salaryData = json['salarySlips'] as Map<String, dynamic>;
      submission.salarySlips = SalarySlips(
        slips: (salaryData['slips'] as List<dynamic>?)?.cast<String>() ?? [],
        pdfPassword: salaryData['pdfPassword'] as String?,
        isPdf: salaryData['isPdf'] as bool? ?? false,
      );
    }

    return submission;
  }

  SubmissionStatus _statusFromString(String status) {
    switch (status) {
      case 'pendingVerification':
        return SubmissionStatus.pendingVerification;
      case 'approved':
        return SubmissionStatus.approved;
      case 'rejected':
        return SubmissionStatus.rejected;
      default:
        return SubmissionStatus.inProgress;
    }
  }
}

