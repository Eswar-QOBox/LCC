import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document_submission.dart';
import '../utils/aadhaar_utils.dart';

// Conditional import for file operations - only on non-web platforms
import 'dart:io' if (dart.library.html) '../services/file_helper_stub.dart' as io;

class SubmissionProvider with ChangeNotifier {
  DocumentSubmission _submission = DocumentSubmission();
  bool _termsAccepted = false;
  bool _isInitialized = false;
  static const String _draftKey = 'submission_draft';
  static const String _termsAcceptedKey = 'terms_accepted_draft';
  static const int _requiredSalarySlipCount = SalarySlips.requiredSlipCount;

  DocumentSubmission get submission => _submission;
  bool get termsAccepted => _termsAccepted;
  bool get isInitialized => _isInitialized;

  // Loan meta
  void setLoanType(String? loanType) {
    _submission.loanType = loanType;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setBusinessLoanType(String? businessLoanType) {
    _submission.businessLoanType = businessLoanType;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setProfessionalLoanType(String? professionalLoanType) {
    _submission.professionalLoanType = professionalLoanType;
    notifyListeners();
    unawaited(saveDraft());
  }

  // Professional docs (Doctor / CA)
  void setProfessionalMedicalDegree(String path, {bool isPdf = false}) {
    _submission.professionalDocuments ??= ProfessionalDocuments();
    _submission.professionalDocuments!.medicalDegree ??= UploadedDoc();
    _submission.professionalDocuments!.medicalDegree!.path = path;
    _submission.professionalDocuments!.medicalDegree!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setProfessionalMedicalLicence(String path, {bool isPdf = false}) {
    _submission.professionalDocuments ??= ProfessionalDocuments();
    _submission.professionalDocuments!.medicalLicence ??= UploadedDoc();
    _submission.professionalDocuments!.medicalLicence!.path = path;
    _submission.professionalDocuments!.medicalLicence!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setProfessionalPrescription(String path, {bool isPdf = false}) {
    _submission.professionalDocuments ??= ProfessionalDocuments();
    _submission.professionalDocuments!.prescription ??= UploadedDoc();
    _submission.professionalDocuments!.prescription!.path = path;
    _submission.professionalDocuments!.prescription!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setProfessionalCaDegree(String path, {bool isPdf = false}) {
    _submission.professionalDocuments ??= ProfessionalDocuments();
    _submission.professionalDocuments!.caDegree ??= UploadedDoc();
    _submission.professionalDocuments!.caDegree!.path = path;
    _submission.professionalDocuments!.caDegree!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setProfessionalCertificateOfPractice(String path, {bool isPdf = false}) {
    _submission.professionalDocuments ??= ProfessionalDocuments();
    _submission.professionalDocuments!.certificateOfPractice ??= UploadedDoc();
    _submission.professionalDocuments!.certificateOfPractice!.path = path;
    _submission.professionalDocuments!.certificateOfPractice!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setProfessionalIcaiCertificate(String path, {bool isPdf = false}) {
    _submission.professionalDocuments ??= ProfessionalDocuments();
    _submission.professionalDocuments!.icaiCertificate ??= UploadedDoc();
    _submission.professionalDocuments!.icaiCertificate!.path = path;
    _submission.professionalDocuments!.icaiCertificate!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setProfessionalItrYear1(String path, {bool isPdf = false}) {
    _submission.professionalDocuments ??= ProfessionalDocuments();
    _submission.professionalDocuments!.itrYear1 ??= UploadedDoc();
    _submission.professionalDocuments!.itrYear1!.path = path;
    _submission.professionalDocuments!.itrYear1!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setProfessionalItrYear2(String path, {bool isPdf = false}) {
    _submission.professionalDocuments ??= ProfessionalDocuments();
    _submission.professionalDocuments!.itrYear2 ??= UploadedDoc();
    _submission.professionalDocuments!.itrYear2!.path = path;
    _submission.professionalDocuments!.itrYear2!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setProfessionalBalanceSheet(String path, {bool isPdf = false}) {
    _submission.professionalDocuments ??= ProfessionalDocuments();
    _submission.professionalDocuments!.balanceSheet ??= UploadedDoc();
    _submission.professionalDocuments!.balanceSheet!.path = path;
    _submission.professionalDocuments!.balanceSheet!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setProfessionalPlStatement(String path, {bool isPdf = false}) {
    _submission.professionalDocuments ??= ProfessionalDocuments();
    _submission.professionalDocuments!.plStatement ??= UploadedDoc();
    _submission.professionalDocuments!.plStatement!.path = path;
    _submission.professionalDocuments!.plStatement!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  // Student loan documents
  void setStudentPassport(String path, {bool isPdf = false}) {
    _submission.studentDocuments ??= StudentDocuments();
    _submission.studentDocuments!.passport ??= UploadedDoc();
    _submission.studentDocuments!.passport!.path = path;
    _submission.studentDocuments!.passport!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setStudentAdmissionLetter(String path, {bool isPdf = false}) {
    _submission.studentDocuments ??= StudentDocuments();
    _submission.studentDocuments!.admissionLetter ??= UploadedDoc();
    _submission.studentDocuments!.admissionLetter!.path = path;
    _submission.studentDocuments!.admissionLetter!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setStudentMarkSheetSsc(String path, {bool isPdf = false}) {
    _submission.studentDocuments ??= StudentDocuments();
    _submission.studentDocuments!.markSheetSsc ??= UploadedDoc();
    _submission.studentDocuments!.markSheetSsc!.path = path;
    _submission.studentDocuments!.markSheetSsc!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setStudentMarkSheetInter(String path, {bool isPdf = false}) {
    _submission.studentDocuments ??= StudentDocuments();
    _submission.studentDocuments!.markSheetInter ??= UploadedDoc();
    _submission.studentDocuments!.markSheetInter!.path = path;
    _submission.studentDocuments!.markSheetInter!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setStudentMarkSheetGraduation(String path, {bool isPdf = false}) {
    _submission.studentDocuments ??= StudentDocuments();
    _submission.studentDocuments!.markSheetGraduation ??= UploadedDoc();
    _submission.studentDocuments!.markSheetGraduation!.path = path;
    _submission.studentDocuments!.markSheetGraduation!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setStudentIsWorking(bool value) {
    _submission.studentDocuments ??= StudentDocuments();
    _submission.studentDocuments!.isWorking = value;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setStudentPayslip1(String path, {bool isPdf = false}) {
    _submission.studentDocuments ??= StudentDocuments();
    _submission.studentDocuments!.payslip1 ??= UploadedDoc();
    _submission.studentDocuments!.payslip1!.path = path;
    _submission.studentDocuments!.payslip1!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setStudentPayslip2(String path, {bool isPdf = false}) {
    _submission.studentDocuments ??= StudentDocuments();
    _submission.studentDocuments!.payslip2 ??= UploadedDoc();
    _submission.studentDocuments!.payslip2!.path = path;
    _submission.studentDocuments!.payslip2!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setStudentPayslip3(String path, {bool isPdf = false}) {
    _submission.studentDocuments ??= StudentDocuments();
    _submission.studentDocuments!.payslip3 ??= UploadedDoc();
    _submission.studentDocuments!.payslip3!.path = path;
    _submission.studentDocuments!.payslip3!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setStudentIdCard(String path, {bool isPdf = false}) {
    _submission.studentDocuments ??= StudentDocuments();
    _submission.studentDocuments!.idCard ??= UploadedDoc();
    _submission.studentDocuments!.idCard!.path = path;
    _submission.studentDocuments!.idCard!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  // Mortgage property details (one or more named uploads)
  PropertyDetailEntry addPropertyDetailEntry() {
    _submission.propertyDetailsDocuments ??= PropertyDetailsDocuments();
    final entry = PropertyDetailEntry(
      id: 'prop_${DateTime.now().microsecondsSinceEpoch}',
    );
    _submission.propertyDetailsDocuments!.entries.add(entry);
    notifyListeners();
    unawaited(saveDraft());
    return entry;
  }

  void updatePropertyName(String id, String name) {
    final docs = _submission.propertyDetailsDocuments;
    if (docs == null) return;
    final idx = docs.entries.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    docs.entries[idx].propertyName = name;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setPropertyDetailPath(String id, String path, {bool isPdf = false}) {
    _submission.propertyDetailsDocuments ??= PropertyDetailsDocuments();
    final docs = _submission.propertyDetailsDocuments!;
    final idx = docs.entries.indexWhere((e) => e.id == id);
    if (idx == -1) {
      docs.entries.add(
        PropertyDetailEntry(id: id, path: path, isPdf: isPdf),
      );
    } else {
      docs.entries[idx].path = path;
      docs.entries[idx].isPdf = isPdf;
    }
    notifyListeners();
    unawaited(saveDraft());
  }

  void removePropertyDetailEntry(String id) {
    final docs = _submission.propertyDetailsDocuments;
    if (docs == null) return;
    docs.entries.removeWhere((e) => e.id == id);
    notifyListeners();
    unawaited(saveDraft());
  }

  // Business docs
  void setSpouseAadhaarFront(String path, {bool isPdf = false}) {
    _submission.businessDocuments ??= BusinessDocuments();
    _submission.businessDocuments!.spouseAadhaar ??= AadhaarDocument();
    _submission.businessDocuments!.spouseAadhaar!.frontPath = path;
    _submission.businessDocuments!.spouseAadhaar!.frontIsPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setSpouseAadhaarBack(String path, {bool isPdf = false}) {
    _submission.businessDocuments ??= BusinessDocuments();
    _submission.businessDocuments!.spouseAadhaar ??= AadhaarDocument();
    _submission.businessDocuments!.spouseAadhaar!.backPath = path;
    _submission.businessDocuments!.spouseAadhaar!.backIsPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void clearSpouseAadhaar() {
    if (_submission.businessDocuments == null) return;
    _submission.businessDocuments!.spouseAadhaar = null;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setSpousePan(String path, {bool isPdf = false}) {
    _submission.businessDocuments ??= BusinessDocuments();
    _submission.businessDocuments!.spousePan ??= PanDocument();
    _submission.businessDocuments!.spousePan!.frontPath = path;
    _submission.businessDocuments!.spousePan!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setGstRegistration(String path, {bool isPdf = false}) {
    _submission.businessDocuments ??= BusinessDocuments();
    _submission.businessDocuments!.gstRegistration ??= UploadedDoc();
    _submission.businessDocuments!.gstRegistration!.path = path;
    _submission.businessDocuments!.gstRegistration!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setCompanyPanCard(String path, {bool isPdf = false}) {
    _submission.businessDocuments ??= BusinessDocuments();
    _submission.businessDocuments!.companyPanCard ??= UploadedDoc();
    _submission.businessDocuments!.companyPanCard!.path = path;
    _submission.businessDocuments!.companyPanCard!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setPartnershipDeed(String path, {bool isPdf = false}) {
    _submission.businessDocuments ??= BusinessDocuments();
    _submission.businessDocuments!.partnershipDeed ??= UploadedDoc();
    _submission.businessDocuments!.partnershipDeed!.path = path;
    _submission.businessDocuments!.partnershipDeed!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setMoa(String path, {bool isPdf = false}) {
    _submission.businessDocuments ??= BusinessDocuments();
    _submission.businessDocuments!.moa ??= UploadedDoc();
    _submission.businessDocuments!.moa!.path = path;
    _submission.businessDocuments!.moa!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setAoa(String path, {bool isPdf = false}) {
    _submission.businessDocuments ??= BusinessDocuments();
    _submission.businessDocuments!.aoa ??= UploadedDoc();
    _submission.businessDocuments!.aoa!.path = path;
    _submission.businessDocuments!.aoa!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setLabourCertificate(String path, {bool isPdf = false}) {
    _submission.businessDocuments ??= BusinessDocuments();
    _submission.businessDocuments!.labourCertificate ??= UploadedDoc();
    _submission.businessDocuments!.labourCertificate!.path = path;
    _submission.businessDocuments!.labourCertificate!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setMsmeCertificate(String path, {bool isPdf = false}) {
    _submission.businessDocuments ??= BusinessDocuments();
    _submission.businessDocuments!.msmeCertificate ??= UploadedDoc();
    _submission.businessDocuments!.msmeCertificate!.path = path;
    _submission.businessDocuments!.msmeCertificate!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setOwnHouseProof(String path, {bool isPdf = false}) {
    _submission.businessDocuments ??= BusinessDocuments();
    _submission.businessDocuments!.ownHouseProof ??= UploadedDoc();
    _submission.businessDocuments!.ownHouseProof!.path = path;
    _submission.businessDocuments!.ownHouseProof!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setPartnerCount(int count) {
    _submission.businessDocuments ??= BusinessDocuments();
    final b = _submission.businessDocuments!;
    b.partnerCount = count;
    final existing = b.partners;
    if (existing.length < count) {
      b.partners = [
        ...existing,
        ...List.generate(count - existing.length, (_) => PartnerKyc()),
      ];
    } else if (existing.length > count) {
      b.partners = existing.take(count).toList();
    }
    notifyListeners();
    unawaited(saveDraft());
  }

  void setPartnerAadhaarFront(
    int partnerIndex1Based,
    String path, {
    bool isPdf = false,
  }) {
    _submission.businessDocuments ??= BusinessDocuments();
    final b = _submission.businessDocuments!;
    final idx = partnerIndex1Based - 1;
    final ensureLen = (b.partnerCount ?? 0) > 0 ? b.partnerCount! : (idx + 1);
    if (b.partners.length < ensureLen) {
      b.partners = [
        ...b.partners,
        ...List.generate(ensureLen - b.partners.length, (_) => PartnerKyc()),
      ];
    }
    b.partners[idx].aadhaar ??= AadhaarDocument();
    b.partners[idx].aadhaar!.frontPath = path;
    b.partners[idx].aadhaar!.frontIsPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setPartnerAadhaarBack(
    int partnerIndex1Based,
    String path, {
    bool isPdf = false,
  }) {
    _submission.businessDocuments ??= BusinessDocuments();
    final b = _submission.businessDocuments!;
    final idx = partnerIndex1Based - 1;
    final ensureLen = (b.partnerCount ?? 0) > 0 ? b.partnerCount! : (idx + 1);
    if (b.partners.length < ensureLen) {
      b.partners = [
        ...b.partners,
        ...List.generate(ensureLen - b.partners.length, (_) => PartnerKyc()),
      ];
    }
    b.partners[idx].aadhaar ??= AadhaarDocument();
    b.partners[idx].aadhaar!.backPath = path;
    b.partners[idx].aadhaar!.backIsPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setPartnerExtractedAadhaarNumber(int partnerIndex1Based, String? number) {
    _submission.businessDocuments ??= BusinessDocuments();
    final b = _submission.businessDocuments!;
    final idx = partnerIndex1Based - 1;
    final ensureLen = (b.partnerCount ?? 0) > 0 ? b.partnerCount! : (idx + 1);
    if (b.partners.length < ensureLen) {
      b.partners = [
        ...b.partners,
        ...List.generate(ensureLen - b.partners.length, (_) => PartnerKyc()),
      ];
    }
    b.partners[idx].extractedAadhaarNumber = number?.trim().replaceAll(RegExp(r'[\s-]'), '');
    notifyListeners();
    unawaited(saveDraft());
  }

  void setPartnerPan(
    int partnerIndex1Based,
    String path, {
    bool isPdf = false,
  }) {
    _submission.businessDocuments ??= BusinessDocuments();
    final b = _submission.businessDocuments!;
    final idx = partnerIndex1Based - 1;
    final ensureLen = (b.partnerCount ?? 0) > 0 ? b.partnerCount! : (idx + 1);
    if (b.partners.length < ensureLen) {
      b.partners = [
        ...b.partners,
        ...List.generate(ensureLen - b.partners.length, (_) => PartnerKyc()),
      ];
    }
    b.partners[idx].pan ??= PanDocument();
    b.partners[idx].pan!.frontPath = path;
    b.partners[idx].pan!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

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
    unawaited(saveDraft());
  }

  // Aadhaar
  void setAadhaarFront(String path, {bool isPdf = false}) {
    _submission.aadhaar ??= AadhaarDocument();
    _submission.aadhaar!.frontPath = path;
    _submission.aadhaar!.frontIsPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setAadhaarBack(String path, {bool isPdf = false}) {
    _submission.aadhaar ??= AadhaarDocument();
    _submission.aadhaar!.backPath = path;
    _submission.aadhaar!.backIsPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void clearAadhaar() {
    _submission.aadhaar = null;
    notifyListeners();
    unawaited(saveDraft());
  }

  void clearAadhaarFront() {
    final a = _submission.aadhaar;
    if (a == null) return;
    a.frontPath = null;
    a.frontIsPdf = false;
    if (a.frontPath == null && a.backPath == null) {
      _submission.aadhaar = null;
    }
    notifyListeners();
    unawaited(saveDraft());
  }

  void clearAadhaarBack() {
    final a = _submission.aadhaar;
    if (a == null) return;
    a.backPath = null;
    a.backIsPdf = false;
    if (a.frontPath == null && a.backPath == null) {
      _submission.aadhaar = null;
    }
    notifyListeners();
    unawaited(saveDraft());
  }

  // PAN
  void setPanFront(String path, {bool isPdf = false}) {
    _submission.pan ??= PanDocument();
    _submission.pan!.frontPath = path;
    _submission.pan!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void clearPan() {
    _submission.pan = null;
    notifyListeners();
    unawaited(saveDraft());
  }

  void clearSpousePan() {
    if (_submission.businessDocuments == null) return;
    _submission.businessDocuments!.spousePan = null;
    notifyListeners();
    unawaited(saveDraft());
  }

  void clearPartnerPan(int partnerIndex1Based) {
    final b = _submission.businessDocuments;
    if (b == null) return;
    final idx = partnerIndex1Based - 1;
    if (idx < 0 || idx >= b.partners.length) return;
    b.partners[idx].pan = null;
    notifyListeners();
    unawaited(saveDraft());
  }

  void clearPartnerAadhaar(int partnerIndex1Based) {
    final b = _submission.businessDocuments;
    if (b == null) return;
    final idx = partnerIndex1Based - 1;
    if (idx < 0 || idx >= b.partners.length) return;
    b.partners[idx].aadhaar = null;
    notifyListeners();
    unawaited(saveDraft());
  }

  // Co-applicant (personal / joint loan)
  void setHasCoApplicant(bool value) {
    _submission.hasCoApplicant = value;
    if (!value) {
      _submission.coApplicantAadhaar = null;
      _submission.coApplicantPan = null;
      _submission.coApplicantPersonalData = null;
      _submission.coApplicantExtractedAadhaarNumber = null;
    }
    notifyListeners();
    unawaited(saveDraft());
  }

  void setCoApplicantAadhaarFront(String path, {bool isPdf = false}) {
    _submission.coApplicantAadhaar ??= AadhaarDocument();
    _submission.coApplicantAadhaar!.frontPath = path;
    _submission.coApplicantAadhaar!.frontIsPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setCoApplicantAadhaarBack(String path, {bool isPdf = false}) {
    _submission.coApplicantAadhaar ??= AadhaarDocument();
    _submission.coApplicantAadhaar!.backPath = path;
    _submission.coApplicantAadhaar!.backIsPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setCoApplicantExtractedAadhaarNumber(String? number) {
    _submission.coApplicantExtractedAadhaarNumber =
        number?.trim().replaceAll(RegExp(r'[\s-]'), '');
    notifyListeners();
    unawaited(saveDraft());
  }

  void clearCoApplicantAadhaar() {
    _submission.coApplicantAadhaar = null;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setCoApplicantPan(String path, {bool isPdf = false}) {
    _submission.coApplicantPan ??= PanDocument();
    _submission.coApplicantPan!.frontPath = path;
    _submission.coApplicantPan!.isPdf = isPdf;
    notifyListeners();
    unawaited(saveDraft());
  }

  void clearCoApplicantPan() {
    _submission.coApplicantPan = null;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setCoApplicantPersonalData(CoApplicantPersonalData data) {
    _submission.coApplicantPersonalData = data;
    notifyListeners();
    unawaited(saveDraft());
  }

  void updateCoApplicantPersonalDataField({
    String? nameAsPerAadhaar,
    DateTime? dateOfBirth,
    String? panNo,
    String? aadhaarNumber,
    String? mobileNumber,
    String? personalEmailId,
    String? residenceAddress,
  }) {
    _submission.coApplicantPersonalData ??= CoApplicantPersonalData();
    final d = _submission.coApplicantPersonalData!;
    if (nameAsPerAadhaar != null) d.nameAsPerAadhaar = nameAsPerAadhaar;
    if (dateOfBirth != null) d.dateOfBirth = dateOfBirth;
    if (panNo != null) d.panNo = panNo;
    if (aadhaarNumber != null) d.aadhaarNumber = aadhaarNumber;
    if (mobileNumber != null) d.mobileNumber = mobileNumber;
    if (personalEmailId != null) d.personalEmailId = personalEmailId;
    if (residenceAddress != null) d.residenceAddress = residenceAddress;
    notifyListeners();
    unawaited(saveDraft());
  }

  // Co-applicant firm docs (car loan)
  void setCoApplicantFirmType(String? type) {
    _submission.coApplicantFirmType = type;
    notifyListeners();
    unawaited(saveDraft());
  }

  void setCoApplicantFirmDocument(String key, String? path) {
    _submission.coApplicantFirmDocuments ??= CoApplicantFirmDocuments();
    _submission.coApplicantFirmDocuments!.setField(key, path);
    notifyListeners();
    unawaited(saveDraft());
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

  void setBankStatementExtractedAccountHolderName(String? name) {
    _submission.bankStatement ??= BankStatement();
    _submission.bankStatement!.extractedAccountHolderName = name;
    notifyListeners();
  }

  void setBankStatementNameMatchesAadhaar(bool? value) {
    _submission.bankStatement ??= BankStatement();
    _submission.bankStatement!.nameMatchesAadhaar = value;
    notifyListeners();
  }

  void setCoApplicantExtractedNameFromAadhaar(String? name) {
    _submission.coApplicantExtractedNameFromAadhaar = name;
    notifyListeners();
    unawaited(saveDraft());
  }

  // Co-applicant Bank Statement
  void setCoApplicantBankStatementPages(List<String> pages, {bool isPdf = false}) {
    _submission.coApplicantBankStatement ??= BankStatement(isPdf: isPdf);
    _submission.coApplicantBankStatement!.pages = pages;
    _submission.coApplicantBankStatement!.isPdf = isPdf;
    notifyListeners();
  }

  void setCoApplicantBankStatementPassword(String password) {
    _submission.coApplicantBankStatement ??= BankStatement();
    _submission.coApplicantBankStatement!.pdfPassword = password;
    notifyListeners();
  }

  void setCoApplicantBankStatementExtractedAccountHolderName(String? name) {
    _submission.coApplicantBankStatement ??= BankStatement();
    _submission.coApplicantBankStatement!.extractedAccountHolderName = name;
    notifyListeners();
  }

  void setCoApplicantBankStatementNameMatchesAadhaar(bool? value) {
    _submission.coApplicantBankStatement ??= BankStatement();
    _submission.coApplicantBankStatement!.nameMatchesAadhaar = value;
    notifyListeners();
  }

  // Salary Slips
  void setSalarySlips(List<String> slips, {bool isPdf = false}) {
    _submission.salarySlips ??= SalarySlips(isPdf: isPdf);
    // Convert list of paths to SalarySlipItem list
    _submission.salarySlips!.slipItems = slips
        .map(
          (path) => SalarySlipItem(
            path: path,
            isPdf: isPdf || path.toLowerCase().endsWith('.pdf'),
          ),
        )
        .toList();
    _submission.salarySlips!.isPdf =
        _submission.salarySlips!.slipItems.any((i) => i.isPdf);
    notifyListeners();
  }

  void setSalarySlipItems(List<SalarySlipItem> items) {
    _submission.salarySlips ??= SalarySlips();
    _submission.salarySlips!.slipItems = List<SalarySlipItem>.from(items);
    _submission.salarySlips!.isPdf =
        _submission.salarySlips!.slipItems.any((i) => i.isPdf);
    notifyListeners();
  }

  void addSalarySlip(String path, {DateTime? slipDate, bool isPdf = false}) {
    _submission.salarySlips ??= SalarySlips();
    _submission.salarySlips!.slipItems.add(
      SalarySlipItem(path: path, slipDate: slipDate, isPdf: isPdf),
    );
    notifyListeners();
  }

  void setSalarySlipAt(int index, String path, {DateTime? slipDate, bool isPdf = false}) {
    _submission.salarySlips ??= SalarySlips();
    if (index < 0) return;

    // Ensure we have enough "slots" up to [index].
    while (_submission.salarySlips!.slipItems.length <= index) {
      _submission.salarySlips!.slipItems.add(
        SalarySlipItem(path: '', slipDate: null, isPdf: false),
      );
    }

    if (index < _submission.salarySlips!.slipItems.length) {
      _submission.salarySlips!.slipItems[index] = SalarySlipItem(
        path: path,
        slipDate: slipDate,
        isPdf: isPdf,
      );
      _submission.salarySlips!.isPdf =
          _submission.salarySlips!.slipItems.any((i) => i.isPdf);
      notifyListeners();
      return;
    }

    // Unreachable due to while loop above.
  }

  void updateSalarySlipDate(int index, DateTime? slipDate) {
    if (_submission.salarySlips != null && 
        index >= 0 && 
        index < _submission.salarySlips!.slipItems.length) {
      _submission.salarySlips!.slipItems[index].slipDate = slipDate;
      notifyListeners();
    }
  }

  void removeSalarySlip(int index) {
    if (_submission.salarySlips != null && 
        index >= 0 && 
        index < _submission.salarySlips!.slipItems.length) {
      // Clear the slot instead of shifting other items.
      final existingDate = _submission.salarySlips!.slipItems[index].slipDate;
      _submission.salarySlips!.slipItems[index] = SalarySlipItem(
        path: '',
        slipDate: existingDate,
        isPdf: false,
      );
      _submission.salarySlips!.isPdf =
          _submission.salarySlips!.slipItems.any((i) => i.isPdf);
      notifyListeners();
    }
  }

  void setSalarySlipsPassword(String password) {
    _submission.salarySlips ??= SalarySlips();
    _submission.salarySlips!.pdfPassword = password;
    notifyListeners();
  }

  // Co-applicant Salary Slips
  void setCoApplicantSalarySlips(List<String> slips, {bool isPdf = false}) {
    _submission.coApplicantSalarySlips ??= SalarySlips(isPdf: isPdf);
    _submission.coApplicantSalarySlips!.slipItems = slips
        .map(
          (path) => SalarySlipItem(
            path: path,
            isPdf: isPdf || path.toLowerCase().endsWith('.pdf'),
          ),
        )
        .toList();
    _submission.coApplicantSalarySlips!.isPdf =
        _submission.coApplicantSalarySlips!.slipItems.any((i) => i.isPdf);
    notifyListeners();
  }

  void setCoApplicantSalarySlipItems(List<SalarySlipItem> items) {
    _submission.coApplicantSalarySlips ??= SalarySlips();
    _submission.coApplicantSalarySlips!.slipItems = List<SalarySlipItem>.from(items);
    _submission.coApplicantSalarySlips!.isPdf =
        _submission.coApplicantSalarySlips!.slipItems.any((i) => i.isPdf);
    notifyListeners();
  }

  void setCoApplicantSalarySlipAt(int index, String path, {DateTime? slipDate, bool isPdf = false}) {
    _submission.coApplicantSalarySlips ??= SalarySlips();
    if (index < 0) return;
    while (_submission.coApplicantSalarySlips!.slipItems.length <= index) {
      _submission.coApplicantSalarySlips!.slipItems.add(
        SalarySlipItem(path: '', slipDate: null, isPdf: false),
      );
    }
    if (index < _submission.coApplicantSalarySlips!.slipItems.length) {
      _submission.coApplicantSalarySlips!.slipItems[index] = SalarySlipItem(
        path: path,
        slipDate: slipDate,
        isPdf: isPdf,
      );
      _submission.coApplicantSalarySlips!.isPdf =
          _submission.coApplicantSalarySlips!.slipItems.any((i) => i.isPdf);
      notifyListeners();
    }
  }

  void updateCoApplicantSalarySlipDate(int index, DateTime? slipDate) {
    if (_submission.coApplicantSalarySlips != null &&
        index >= 0 &&
        index < _submission.coApplicantSalarySlips!.slipItems.length) {
      _submission.coApplicantSalarySlips!.slipItems[index].slipDate = slipDate;
      notifyListeners();
    }
  }

  void removeCoApplicantSalarySlip(int index) {
    if (_submission.coApplicantSalarySlips != null &&
        index >= 0 &&
        index < _submission.coApplicantSalarySlips!.slipItems.length) {
      final existingDate = _submission.coApplicantSalarySlips!.slipItems[index].slipDate;
      _submission.coApplicantSalarySlips!.slipItems[index] = SalarySlipItem(
        path: '',
        slipDate: existingDate,
        isPdf: false,
      );
      _submission.coApplicantSalarySlips!.isPdf =
          _submission.coApplicantSalarySlips!.slipItems.any((i) => i.isPdf);
      notifyListeners();
    }
  }

  void setCoApplicantSalarySlipsPassword(String password) {
    _submission.coApplicantSalarySlips ??= SalarySlips();
    _submission.coApplicantSalarySlips!.pdfPassword = password;
    notifyListeners();
  }

  // Personal Data
  void setPersonalData(PersonalData data) {
    _submission.personalData = data;
    notifyListeners();
    unawaited(saveDraft());
  }

  void updatePersonalDataField({
    String? fullName,
    DateTime? dateOfBirth,
    String? address,
    bool? addressDifferentFromAadhaar,
    String? currentResidenceAddress,
    String? mobile,
    String? email,
    String? employmentStatus,
    String? incomeDetails,
    String? panNo,
    String? aadhaarNumber,
    String? fatherName,
    String? motherName,
  }) {
    _submission.personalData ??= PersonalData();
    // Map legacy fields to new fields for backward compatibility
    if (fullName != null) _submission.personalData!.nameAsPerAadhaar = fullName;
    if (dateOfBirth != null) {
      _submission.personalData!.dateOfBirth = dateOfBirth;
    }
    if (address != null) _submission.personalData!.residenceAddress = address;
    if (addressDifferentFromAadhaar != null) {
      _submission.personalData!.addressDifferentFromAadhaar =
          addressDifferentFromAadhaar;
    }
    if (currentResidenceAddress != null) {
      _submission.personalData!.currentResidenceAddress = currentResidenceAddress;
    }
    if (mobile != null) _submission.personalData!.mobileNumber = mobile;
    if (email != null) _submission.personalData!.personalEmailId = email;
    if (employmentStatus != null) {
      _submission.personalData!.occupation = employmentStatus;
    }
    if (incomeDetails != null) {
      _submission.personalData!.annualIncome = incomeDetails;
    }
    if (panNo != null) _submission.personalData!.panNo = panNo;
    if (aadhaarNumber != null) _submission.personalData!.aadhaarNumber = aadhaarNumber;
    if (fatherName != null) _submission.personalData!.fatherName = fatherName;
    if (motherName != null) _submission.personalData!.motherName = motherName;
    notifyListeners();
    unawaited(saveDraft());
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

    bool shouldCheckExistence(String path) {
      final p = path.trim();
      if (p.isEmpty) return false;
      // Server/blob paths should not be validated via local filesystem.
      return !(p.startsWith('http') ||
          p.startsWith('/uploads/') ||
          p.startsWith('uploads/') ||
          p.startsWith('/api/') ||
          p.startsWith('api/') ||
          p.startsWith('blob:'));
    }

    // Validate selfie
    if (_submission.selfiePath != null) {
      final path = _submission.selfiePath!;
      if (shouldCheckExistence(path)) {
        final file = io.File(path);
        if (!await file.exists()) {
          debugPrint('⚠️ Selfie file not found: $path');
          _submission.selfiePath = null;
          hasInvalidFiles = true;
        }
      }
    }

    // Validate Aadhaar
    if (_submission.aadhaar != null) {
      if (_submission.aadhaar!.frontPath != null) {
        final path = _submission.aadhaar!.frontPath!;
        if (shouldCheckExistence(path)) {
          final file = io.File(path);
          if (!await file.exists()) {
            debugPrint('⚠️ Aadhaar front file not found: $path');
            _submission.aadhaar!.frontPath = null;
            hasInvalidFiles = true;
          }
        }
      }
      if (_submission.aadhaar!.backPath != null) {
        final path = _submission.aadhaar!.backPath!;
        if (shouldCheckExistence(path)) {
          final file = io.File(path);
          if (!await file.exists()) {
            debugPrint('⚠️ Aadhaar back file not found: $path');
            _submission.aadhaar!.backPath = null;
            hasInvalidFiles = true;
          }
        }
      }
      // If both paths are null, clear the aadhaar document
      if (_submission.aadhaar!.frontPath == null && _submission.aadhaar!.backPath == null) {
        _submission.aadhaar = null;
      }
    }

    // Validate PAN
    if (_submission.pan != null && _submission.pan!.frontPath != null) {
      final path = _submission.pan!.frontPath!;
      if (shouldCheckExistence(path)) {
        final file = io.File(path);
        if (!await file.exists()) {
          debugPrint('⚠️ PAN file not found: $path');
          _submission.pan!.frontPath = null;
          hasInvalidFiles = true;
        }
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
        if (!shouldCheckExistence(pagePath)) {
          validPages.add(pagePath);
          continue;
        }
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

    // Validate Co-applicant Bank Statement
    if (_submission.coApplicantBankStatement != null &&
        _submission.coApplicantBankStatement!.pages.isNotEmpty) {
      final validPages = <String>[];
      for (final pagePath in _submission.coApplicantBankStatement!.pages) {
        if (!shouldCheckExistence(pagePath)) {
          validPages.add(pagePath);
          continue;
        }
        final file = io.File(pagePath);
        if (await file.exists()) {
          validPages.add(pagePath);
        } else {
          debugPrint('⚠️ Co-applicant bank statement page not found: $pagePath');
          hasInvalidFiles = true;
        }
      }
      _submission.coApplicantBankStatement!.pages = validPages;
      if (_submission.coApplicantBankStatement!.pages.isEmpty) {
        _submission.coApplicantBankStatement = null;
      }
    }

    // Validate Business Documents (Business Loan - Proprietor)
    if (_submission.businessDocuments != null) {
      final b = _submission.businessDocuments!;

      // Spouse Aadhaar
      if (b.spouseAadhaar != null) {
        if (b.spouseAadhaar!.frontPath != null) {
          final path = b.spouseAadhaar!.frontPath!;
          if (shouldCheckExistence(path)) {
            final file = io.File(path);
            if (!await file.exists()) {
              debugPrint('⚠️ Spouse Aadhaar front file not found: $path');
              b.spouseAadhaar!.frontPath = null;
              hasInvalidFiles = true;
            }
          }
        }
        if (b.spouseAadhaar!.backPath != null) {
          final path = b.spouseAadhaar!.backPath!;
          if (shouldCheckExistence(path)) {
            final file = io.File(path);
            if (!await file.exists()) {
              debugPrint('⚠️ Spouse Aadhaar back file not found: $path');
              b.spouseAadhaar!.backPath = null;
              hasInvalidFiles = true;
            }
          }
        }
        if (b.spouseAadhaar!.frontPath == null && b.spouseAadhaar!.backPath == null) {
          b.spouseAadhaar = null;
        }
      }

      // Spouse PAN
      if (b.spousePan != null && b.spousePan!.frontPath != null) {
        final path = b.spousePan!.frontPath!;
        if (shouldCheckExistence(path)) {
          final file = io.File(path);
          if (!await file.exists()) {
            debugPrint('⚠️ Spouse PAN file not found: $path');
            b.spousePan!.frontPath = null;
            hasInvalidFiles = true;
          }
        }
        if (b.spousePan!.frontPath == null) {
          b.spousePan = null;
        }
      }

      Future<void> validateUploadedDoc(UploadedDoc? doc, String label, void Function() clear) async {
        final path = doc?.path;
        if (path == null || path.trim().isEmpty) return;
        if (!shouldCheckExistence(path)) return;
        final file = io.File(path);
        if (!await file.exists()) {
          debugPrint('⚠️ $label file not found: $path');
          clear();
          hasInvalidFiles = true;
        }
      }

      await validateUploadedDoc(
        b.companyPanCard,
        'Company PAN Card',
        () => b.companyPanCard = null,
      );
      await validateUploadedDoc(
        b.partnershipDeed,
        'Partnership Deed',
        () => b.partnershipDeed = null,
      );
      await validateUploadedDoc(
        b.gstRegistration,
        'GST Registration',
        () => b.gstRegistration = null,
      );
      await validateUploadedDoc(
        b.labourCertificate,
        'Labour Certificate',
        () => b.labourCertificate = null,
      );
      await validateUploadedDoc(
        b.msmeCertificate,
        'MSME Certificate',
        () => b.msmeCertificate = null,
      );
      await validateUploadedDoc(
        b.ownHouseProof,
        'Own House Proof',
        () => b.ownHouseProof = null,
      );

      // If everything is null, clear businessDocuments.
      final hasPartnerInfo = (b.partnerCount ?? 0) > 0 || b.partners.isNotEmpty;
      if (b.spouseAadhaar == null &&
          b.spousePan == null &&
          !hasPartnerInfo &&
          b.companyPanCard == null &&
          b.partnershipDeed == null &&
          b.gstRegistration == null &&
          b.labourCertificate == null &&
          b.msmeCertificate == null &&
          b.ownHouseProof == null) {
        _submission.businessDocuments = null;
      }
    }

    // Validate Salary Slips
    if (_submission.salarySlips != null && _submission.salarySlips!.slipItems.isNotEmpty) {
      for (int i = 0; i < _submission.salarySlips!.slipItems.length; i++) {
        final slipItem = _submission.salarySlips!.slipItems[i];
        if (!slipItem.hasFile) continue;
        if (!shouldCheckExistence(slipItem.path)) continue;
        final file = io.File(slipItem.path);
        if (!await file.exists()) {
          debugPrint('⚠️ Salary slip file not found: ${slipItem.path}');
          _submission.salarySlips!.slipItems[i] = SalarySlipItem(
            path: '',
            slipDate: slipItem.slipDate,
            isPdf: false,
          );
          hasInvalidFiles = true;
        }
      }

      // Ensure we always have a stable number of slots (helps UI keep cards stable).
      while (_submission.salarySlips!.slipItems.length < _requiredSalarySlipCount) {
        _submission.salarySlips!.slipItems.add(
          SalarySlipItem(path: '', slipDate: null, isPdf: false),
        );
      }

      if (_submission.salarySlips!.slipItems.every((i) => !i.hasFile)) {
        _submission.salarySlips = null;
      } else {
        _submission.salarySlips!.isPdf =
            _submission.salarySlips!.slipItems.any((i) => i.isPdf);
      }
    }

    // Validate Co-applicant Salary Slips
    if (_submission.coApplicantSalarySlips != null &&
        _submission.coApplicantSalarySlips!.slipItems.isNotEmpty) {
      for (int i = 0; i < _submission.coApplicantSalarySlips!.slipItems.length; i++) {
        final slipItem = _submission.coApplicantSalarySlips!.slipItems[i];
        if (!slipItem.hasFile) continue;
        if (!shouldCheckExistence(slipItem.path)) continue;
        final file = io.File(slipItem.path);
        if (!await file.exists()) {
          debugPrint('⚠️ Co-applicant salary slip file not found: ${slipItem.path}');
          _submission.coApplicantSalarySlips!.slipItems[i] = SalarySlipItem(
            path: '',
            slipDate: slipItem.slipDate,
            isPdf: false,
          );
          hasInvalidFiles = true;
        }
      }

      while (_submission.coApplicantSalarySlips!.slipItems.length < _requiredSalarySlipCount) {
        _submission.coApplicantSalarySlips!.slipItems.add(
          SalarySlipItem(path: '', slipDate: null, isPdf: false),
        );
      }

      if (_submission.coApplicantSalarySlips!.slipItems.every((i) => !i.hasFile)) {
        _submission.coApplicantSalarySlips = null;
      } else {
        _submission.coApplicantSalarySlips!.isPdf =
            _submission.coApplicantSalarySlips!.slipItems.any((i) => i.isPdf);
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

  /// Reset submission state (clear in-memory data)
  void resetSubmission() {
    _submission = DocumentSubmission();
    _termsAccepted = false;
    notifyListeners();
    debugPrint('✅ Submission state reset');
  }

  // JSON serialization helpers
  Map<String, dynamic> _submissionToJson(DocumentSubmission submission) {
    return {
      'loanType': submission.loanType,
      'businessLoanType': submission.businessLoanType,
      'professionalLoanType': submission.professionalLoanType,
      'selfiePath': submission.selfiePath,
      'aadhaar': submission.aadhaar != null
          ? {
              'frontPath': submission.aadhaar!.frontPath,
              'backPath': submission.aadhaar!.backPath,
              'frontIsPdf': submission.aadhaar!.frontIsPdf,
              'backIsPdf': submission.aadhaar!.backIsPdf,
            }
          : null,
      'pan': submission.pan != null
          ? {
              'frontPath': submission.pan!.frontPath,
            }
          : null,
      'hasCoApplicant': submission.hasCoApplicant,
      'coApplicantAadhaar': submission.coApplicantAadhaar != null
          ? {
              'frontPath': submission.coApplicantAadhaar!.frontPath,
              'backPath': submission.coApplicantAadhaar!.backPath,
              'frontIsPdf': submission.coApplicantAadhaar!.frontIsPdf,
              'backIsPdf': submission.coApplicantAadhaar!.backIsPdf,
            }
          : null,
      'coApplicantPan': submission.coApplicantPan != null
          ? {
              'frontPath': submission.coApplicantPan!.frontPath,
              'isPdf': submission.coApplicantPan!.isPdf,
            }
          : null,
      'coApplicantExtractedAadhaarNumber': submission.coApplicantExtractedAadhaarNumber != null && submission.coApplicantExtractedAadhaarNumber!.trim().isNotEmpty
          ? AadhaarUtils.maskAadhaar(submission.coApplicantExtractedAadhaarNumber)
          : null,
      'coApplicantExtractedNameFromAadhaar': submission.coApplicantExtractedNameFromAadhaar,
      'coApplicantPersonalData': submission.coApplicantPersonalData?.toJson(),
      'coApplicantFirmType': submission.coApplicantFirmType,
      'coApplicantFirmDocuments': submission.coApplicantFirmDocuments?.toJson(),
      'coApplicantBankStatement': submission.coApplicantBankStatement != null
          ? {
              'pages': submission.coApplicantBankStatement!.pages,
              'pdfPassword': submission.coApplicantBankStatement!.pdfPassword,
              'isPdf': submission.coApplicantBankStatement!.isPdf,
              'statementDate': submission.coApplicantBankStatement!.statementDate?.toIso8601String(),
              'extractedAccountHolderName': submission.coApplicantBankStatement!.extractedAccountHolderName,
              'nameMatchesAadhaar': submission.coApplicantBankStatement!.nameMatchesAadhaar,
            }
          : null,
      'bankStatement': submission.bankStatement != null
          ? {
              'pages': submission.bankStatement!.pages,
              'pdfPassword': submission.bankStatement!.pdfPassword,
              'isPdf': submission.bankStatement!.isPdf,
              'statementDate': submission.bankStatement!.statementDate?.toIso8601String(),
              'extractedAccountHolderName': submission.bankStatement!.extractedAccountHolderName,
              'nameMatchesAadhaar': submission.bankStatement!.nameMatchesAadhaar,
            }
          : null,
      'businessDocuments': submission.businessDocuments != null
          ? {
              'spouseAadhaar': submission.businessDocuments!.spouseAadhaar != null
                  ? {
                      'frontPath': submission.businessDocuments!.spouseAadhaar!.frontPath,
                      'backPath': submission.businessDocuments!.spouseAadhaar!.backPath,
                      'frontIsPdf': submission.businessDocuments!.spouseAadhaar!.frontIsPdf,
                      'backIsPdf': submission.businessDocuments!.spouseAadhaar!.backIsPdf,
                    }
                  : null,
              'spousePan': submission.businessDocuments!.spousePan != null
                  ? {
                      'frontPath': submission.businessDocuments!.spousePan!.frontPath,
                      'isPdf': submission.businessDocuments!.spousePan!.isPdf,
                    }
                  : null,
              'partnerCount': submission.businessDocuments!.partnerCount,
              'partners': submission.businessDocuments!.partners
                  .map(
                    (p) => {
                      'aadhaar': p.aadhaar != null
                          ? {
                              'frontPath': p.aadhaar!.frontPath,
                              'backPath': p.aadhaar!.backPath,
                              'frontIsPdf': p.aadhaar!.frontIsPdf,
                              'backIsPdf': p.aadhaar!.backIsPdf,
                            }
                          : null,
                      'pan': p.pan != null
                          ? {
                              'frontPath': p.pan!.frontPath,
                              'isPdf': p.pan!.isPdf,
                            }
                          : null,
                      'extractedAadhaarNumber': p.extractedAadhaarNumber != null && p.extractedAadhaarNumber!.trim().isNotEmpty
                          ? AadhaarUtils.maskAadhaar(p.extractedAadhaarNumber)
                          : null,
                    },
                  )
                  .toList(),
              'companyPanCard': submission.businessDocuments!.companyPanCard != null
                  ? {
                      'path': submission.businessDocuments!.companyPanCard!.path,
                      'isPdf': submission.businessDocuments!.companyPanCard!.isPdf,
                    }
                  : null,
              'partnershipDeed': submission.businessDocuments!.partnershipDeed != null
                  ? {
                      'path': submission.businessDocuments!.partnershipDeed!.path,
                      'isPdf': submission.businessDocuments!.partnershipDeed!.isPdf,
                    }
                  : null,
              'moa': submission.businessDocuments!.moa != null
                  ? {
                      'path': submission.businessDocuments!.moa!.path,
                      'isPdf': submission.businessDocuments!.moa!.isPdf,
                    }
                  : null,
              'aoa': submission.businessDocuments!.aoa != null
                  ? {
                      'path': submission.businessDocuments!.aoa!.path,
                      'isPdf': submission.businessDocuments!.aoa!.isPdf,
                    }
                  : null,
              'gstRegistration': submission.businessDocuments!.gstRegistration != null
                  ? {
                      'path': submission.businessDocuments!.gstRegistration!.path,
                      'isPdf': submission.businessDocuments!.gstRegistration!.isPdf,
                    }
                  : null,
              'labourCertificate': submission.businessDocuments!.labourCertificate != null
                  ? {
                      'path': submission.businessDocuments!.labourCertificate!.path,
                      'isPdf': submission.businessDocuments!.labourCertificate!.isPdf,
                    }
                  : null,
              'msmeCertificate': submission.businessDocuments!.msmeCertificate != null
                  ? {
                      'path': submission.businessDocuments!.msmeCertificate!.path,
                      'isPdf': submission.businessDocuments!.msmeCertificate!.isPdf,
                    }
                  : null,
              'ownHouseProof': submission.businessDocuments!.ownHouseProof != null
                  ? {
                      'path': submission.businessDocuments!.ownHouseProof!.path,
                      'isPdf': submission.businessDocuments!.ownHouseProof!.isPdf,
                    }
                  : null,
            }
          : null,
      'professionalDocuments': submission.professionalDocuments != null
          ? {
              'medicalDegree': submission.professionalDocuments!.medicalDegree != null
                  ? {
                      'path': submission.professionalDocuments!.medicalDegree!.path,
                      'isPdf': submission.professionalDocuments!.medicalDegree!.isPdf,
                    }
                  : null,
              'medicalLicence': submission.professionalDocuments!.medicalLicence != null
                  ? {
                      'path': submission.professionalDocuments!.medicalLicence!.path,
                      'isPdf': submission.professionalDocuments!.medicalLicence!.isPdf,
                    }
                  : null,
              'prescription': submission.professionalDocuments!.prescription != null
                  ? {
                      'path': submission.professionalDocuments!.prescription!.path,
                      'isPdf': submission.professionalDocuments!.prescription!.isPdf,
                    }
                  : null,
              'caDegree': submission.professionalDocuments!.caDegree != null
                  ? {
                      'path': submission.professionalDocuments!.caDegree!.path,
                      'isPdf': submission.professionalDocuments!.caDegree!.isPdf,
                    }
                  : null,
              'certificateOfPractice': submission.professionalDocuments!.certificateOfPractice != null
                  ? {
                      'path': submission.professionalDocuments!.certificateOfPractice!.path,
                      'isPdf': submission.professionalDocuments!.certificateOfPractice!.isPdf,
                    }
                  : null,
              'icaiCertificate': submission.professionalDocuments!.icaiCertificate != null
                  ? {
                      'path': submission.professionalDocuments!.icaiCertificate!.path,
                      'isPdf': submission.professionalDocuments!.icaiCertificate!.isPdf,
                    }
                  : null,
              'itrYear1': submission.professionalDocuments!.itrYear1 != null
                  ? {
                      'path': submission.professionalDocuments!.itrYear1!.path,
                      'isPdf': submission.professionalDocuments!.itrYear1!.isPdf,
                    }
                  : null,
              'itrYear2': submission.professionalDocuments!.itrYear2 != null
                  ? {
                      'path': submission.professionalDocuments!.itrYear2!.path,
                      'isPdf': submission.professionalDocuments!.itrYear2!.isPdf,
                    }
                  : null,
              'balanceSheet': submission.professionalDocuments!.balanceSheet != null
                  ? {
                      'path': submission.professionalDocuments!.balanceSheet!.path,
                      'isPdf': submission.professionalDocuments!.balanceSheet!.isPdf,
                    }
                  : null,
              'plStatement': submission.professionalDocuments!.plStatement != null
                  ? {
                      'path': submission.professionalDocuments!.plStatement!.path,
                      'isPdf': submission.professionalDocuments!.plStatement!.isPdf,
                    }
                  : null,
            }
          : null,
      'studentDocuments': submission.studentDocuments != null
          ? {
              'passport': submission.studentDocuments!.passport != null
                  ? {
                      'path': submission.studentDocuments!.passport!.path,
                      'isPdf': submission.studentDocuments!.passport!.isPdf,
                    }
                  : null,
              'admissionLetter': submission.studentDocuments!.admissionLetter != null
                  ? {
                      'path': submission.studentDocuments!.admissionLetter!.path,
                      'isPdf': submission.studentDocuments!.admissionLetter!.isPdf,
                    }
                  : null,
              'markSheetSsc': submission.studentDocuments!.markSheetSsc != null
                  ? {
                      'path': submission.studentDocuments!.markSheetSsc!.path,
                      'isPdf': submission.studentDocuments!.markSheetSsc!.isPdf,
                    }
                  : null,
              'markSheetInter': submission.studentDocuments!.markSheetInter != null
                  ? {
                      'path': submission.studentDocuments!.markSheetInter!.path,
                      'isPdf': submission.studentDocuments!.markSheetInter!.isPdf,
                    }
                  : null,
              'markSheetGraduation': submission.studentDocuments!.markSheetGraduation != null
                  ? {
                      'path': submission.studentDocuments!.markSheetGraduation!.path,
                      'isPdf': submission.studentDocuments!.markSheetGraduation!.isPdf,
                    }
                  : null,
              'isWorking': submission.studentDocuments!.isWorking,
              'payslip1': submission.studentDocuments!.payslip1 != null
                  ? {
                      'path': submission.studentDocuments!.payslip1!.path,
                      'isPdf': submission.studentDocuments!.payslip1!.isPdf,
                    }
                  : null,
              'payslip2': submission.studentDocuments!.payslip2 != null
                  ? {
                      'path': submission.studentDocuments!.payslip2!.path,
                      'isPdf': submission.studentDocuments!.payslip2!.isPdf,
                    }
                  : null,
              'payslip3': submission.studentDocuments!.payslip3 != null
                  ? {
                      'path': submission.studentDocuments!.payslip3!.path,
                      'isPdf': submission.studentDocuments!.payslip3!.isPdf,
                    }
                  : null,
              'idCard': submission.studentDocuments!.idCard != null
                  ? {
                      'path': submission.studentDocuments!.idCard!.path,
                      'isPdf': submission.studentDocuments!.idCard!.isPdf,
                    }
                  : null,
            }
          : null,
      'propertyDetailsDocuments':
          submission.propertyDetailsDocuments?.toJson(),
      'personalData': submission.personalData != null
          ? {
              'nameAsPerAadhaar': submission.personalData!.nameAsPerAadhaar,
              'dateOfBirth': submission.personalData!.dateOfBirth?.toIso8601String(),
              'panNo': submission.personalData!.panNo,
              'aadhaarNumber': submission.personalData!.aadhaarNumber,
              'mobileNumber': submission.personalData!.mobileNumber,
              'personalEmailId': submission.personalData!.personalEmailId,
              'countryOfResidence': submission.personalData!.countryOfResidence,
              'residenceAddress': submission.personalData!.residenceAddress,
              'addressDifferentFromAadhaar': submission.personalData!.addressDifferentFromAadhaar,
              'currentResidenceAddress': submission.personalData!.currentResidenceAddress,
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
              'loanAmount': submission.personalData!.loanAmount,
              'loanTenure': submission.personalData!.loanTenure,
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
              'slipItems': submission.salarySlips!.slipItems.map((item) => {
                'path': item.path,
                'slipDate': item.slipDate?.toIso8601String(),
                'isPdf': item.isPdf, // Include isPdf for each item
              }).toList(),
              'slips': submission.salarySlips!.slips, // Legacy support
              'pdfPassword': submission.salarySlips!.pdfPassword,
              'isPdf': submission.salarySlips!.isPdf,
            }
          : null,
      'coApplicantSalarySlips': submission.coApplicantSalarySlips != null
          ? {
              'slipItems': submission.coApplicantSalarySlips!.slipItems.map((item) => {
                'path': item.path,
                'slipDate': item.slipDate?.toIso8601String(),
                'isPdf': item.isPdf,
              }).toList(),
              'slips': submission.coApplicantSalarySlips!.slips,
              'pdfPassword': submission.coApplicantSalarySlips!.pdfPassword,
              'isPdf': submission.coApplicantSalarySlips!.isPdf,
            }
          : null,
      'submittedAt': submission.submittedAt?.toIso8601String(),
      'status': submission.status.toString().split('.').last,
    };
  }

  DocumentSubmission _submissionFromJson(Map<String, dynamic> json) {
    final submission = DocumentSubmission(
      loanType: json['loanType'] as String?,
      businessLoanType: json['businessLoanType'] as String?,
      professionalLoanType: json['professionalLoanType'] as String?,
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
        frontIsPdf: aadhaarData['frontIsPdf'] as bool? ?? false,
        backIsPdf: aadhaarData['backIsPdf'] as bool? ?? false,
      );
    }

    if (json['pan'] != null) {
      final panData = json['pan'] as Map<String, dynamic>;
      submission.pan = PanDocument(
        frontPath: panData['frontPath'] as String?,
      );
    }

    submission.hasCoApplicant = json['hasCoApplicant'] as bool? ?? false;
    if (json['coApplicantAadhaar'] != null) {
      final a = json['coApplicantAadhaar'] as Map<String, dynamic>;
      submission.coApplicantAadhaar = AadhaarDocument(
        frontPath: a['frontPath'] as String?,
        backPath: a['backPath'] as String?,
        frontIsPdf: a['frontIsPdf'] as bool? ?? false,
        backIsPdf: a['backIsPdf'] as bool? ?? false,
      );
    }
    if (json['coApplicantPan'] != null) {
      final p = json['coApplicantPan'] as Map<String, dynamic>;
      submission.coApplicantPan = PanDocument(
        frontPath: p['frontPath'] as String?,
        isPdf: p['isPdf'] as bool? ?? false,
      );
    }
    submission.coApplicantExtractedAadhaarNumber =
        json['coApplicantExtractedAadhaarNumber'] as String?;
    submission.coApplicantExtractedNameFromAadhaar =
        json['coApplicantExtractedNameFromAadhaar'] as String?;
    if (json['coApplicantPersonalData'] != null) {
      submission.coApplicantPersonalData = CoApplicantPersonalData.fromJson(
        json['coApplicantPersonalData'] as Map<String, dynamic>?,
      );
    }
    submission.coApplicantFirmType = json['coApplicantFirmType'] as String?;
    if (json['coApplicantFirmDocuments'] != null) {
      submission.coApplicantFirmDocuments = CoApplicantFirmDocuments.fromJson(
        json['coApplicantFirmDocuments'] as Map<String, dynamic>?,
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
        extractedAccountHolderName: bankData['extractedAccountHolderName'] as String?,
        nameMatchesAadhaar: bankData['nameMatchesAadhaar'] as bool?,
      );
    }

    if (json['coApplicantBankStatement'] != null) {
      final bankData = json['coApplicantBankStatement'] as Map<String, dynamic>;
      submission.coApplicantBankStatement = BankStatement(
        pages: (bankData['pages'] as List<dynamic>?)?.cast<String>() ?? [],
        pdfPassword: bankData['pdfPassword'] as String?,
        isPdf: bankData['isPdf'] as bool? ?? false,
        statementDate: bankData['statementDate'] != null
            ? DateTime.tryParse(bankData['statementDate'] as String)
            : null,
        extractedAccountHolderName: bankData['extractedAccountHolderName'] as String?,
        nameMatchesAadhaar: bankData['nameMatchesAadhaar'] as bool?,
      );
    }

    if (json['businessDocuments'] != null) {
      final b = json['businessDocuments'] as Map<String, dynamic>;
      final docs = BusinessDocuments();

      if (b['spouseAadhaar'] != null) {
        final a = b['spouseAadhaar'] as Map<String, dynamic>;
        docs.spouseAadhaar = AadhaarDocument(
          frontPath: a['frontPath'] as String?,
          backPath: a['backPath'] as String?,
          frontIsPdf: a['frontIsPdf'] as bool? ?? false,
          backIsPdf: a['backIsPdf'] as bool? ?? false,
        );
      }
      if (b['spousePan'] != null) {
        final p = b['spousePan'] as Map<String, dynamic>;
        docs.spousePan = PanDocument(
          frontPath: p['frontPath'] as String?,
          isPdf: p['isPdf'] as bool? ?? false,
        );
      }

      docs.partnerCount = (b['partnerCount'] as num?)?.toInt();
      if (b['partners'] is List) {
        final rawPartners = b['partners'] as List<dynamic>;
        docs.partners = rawPartners.map((raw) {
          if (raw is! Map<String, dynamic>) return PartnerKyc();
          AadhaarDocument? parseAadhaar(dynamic r) {
            if (r is! Map<String, dynamic>) return null;
            return AadhaarDocument(
              frontPath: r['frontPath'] as String?,
              backPath: r['backPath'] as String?,
              frontIsPdf: r['frontIsPdf'] as bool? ?? false,
              backIsPdf: r['backIsPdf'] as bool? ?? false,
            );
          }

          PanDocument? parsePan(dynamic r) {
            if (r is! Map<String, dynamic>) return null;
            return PanDocument(
              frontPath: r['frontPath'] as String?,
              isPdf: r['isPdf'] as bool? ?? false,
            );
          }

          return PartnerKyc(
            aadhaar: parseAadhaar(raw['aadhaar']),
            pan: parsePan(raw['pan']),
            extractedAadhaarNumber: raw['extractedAadhaarNumber'] as String?,
          );
        }).toList();
      }

      UploadedDoc? parseUploadedDoc(dynamic raw) {
        if (raw is! Map<String, dynamic>) return null;
        return UploadedDoc(
          path: raw['path'] as String?,
          isPdf: raw['isPdf'] as bool? ?? false,
        );
      }

      docs.gstRegistration = parseUploadedDoc(b['gstRegistration']);
      docs.labourCertificate = parseUploadedDoc(b['labourCertificate']);
      docs.msmeCertificate = parseUploadedDoc(b['msmeCertificate']);
      docs.ownHouseProof = parseUploadedDoc(b['ownHouseProof']);
      docs.companyPanCard = parseUploadedDoc(b['companyPanCard']);
      docs.partnershipDeed = parseUploadedDoc(b['partnershipDeed']);
      docs.moa = parseUploadedDoc(b['moa']);
      docs.aoa = parseUploadedDoc(b['aoa']);

      // Only attach if something exists.
      if (docs.spouseAadhaar != null ||
          docs.spousePan != null ||
          docs.partnerCount != null ||
          docs.partners.isNotEmpty ||
          docs.companyPanCard != null ||
          docs.partnershipDeed != null ||
          docs.moa != null ||
          docs.aoa != null ||
          docs.gstRegistration != null ||
          docs.labourCertificate != null ||
          docs.msmeCertificate != null ||
          docs.ownHouseProof != null) {
        submission.businessDocuments = docs;
      }
    }

    if (json['professionalDocuments'] != null) {
      final p = json['professionalDocuments'] as Map<String, dynamic>;
      UploadedDoc? parseUploadedDoc(dynamic raw) {
        if (raw is! Map<String, dynamic>) return null;
        return UploadedDoc(
          path: raw['path'] as String?,
          isPdf: raw['isPdf'] as bool? ?? false,
        );
      }
      submission.professionalDocuments = ProfessionalDocuments(
        medicalDegree: parseUploadedDoc(p['medicalDegree']),
        medicalLicence: parseUploadedDoc(p['medicalLicence']),
        prescription: parseUploadedDoc(p['prescription']),
        caDegree: parseUploadedDoc(p['caDegree']),
        certificateOfPractice: parseUploadedDoc(p['certificateOfPractice']),
        icaiCertificate: parseUploadedDoc(p['icaiCertificate']),
        itrYear1: parseUploadedDoc(p['itrYear1']),
        itrYear2: parseUploadedDoc(p['itrYear2']),
        balanceSheet: parseUploadedDoc(p['balanceSheet']),
        plStatement: parseUploadedDoc(p['plStatement']),
      );
    }

    if (json['studentDocuments'] != null) {
      final s = json['studentDocuments'] as Map<String, dynamic>;
      UploadedDoc? parseUploadedDoc(dynamic raw) {
        if (raw is! Map<String, dynamic>) return null;
        return UploadedDoc(
          path: raw['path'] as String?,
          isPdf: raw['isPdf'] as bool? ?? false,
        );
      }
      submission.studentDocuments = StudentDocuments(
        passport: parseUploadedDoc(s['passport']),
        admissionLetter: parseUploadedDoc(s['admissionLetter']),
        markSheetSsc: parseUploadedDoc(s['markSheetSsc']),
        markSheetInter: parseUploadedDoc(s['markSheetInter']),
        markSheetGraduation: parseUploadedDoc(s['markSheetGraduation']),
        isWorking: s['isWorking'] as bool? ?? false,
        payslip1: parseUploadedDoc(s['payslip1']),
        payslip2: parseUploadedDoc(s['payslip2']),
        payslip3: parseUploadedDoc(s['payslip3']),
        idCard: parseUploadedDoc(s['idCard']),
      );
    }

    if (json['propertyDetailsDocuments'] != null) {
      submission.propertyDetailsDocuments = PropertyDetailsDocuments.fromJson(
        Map<String, dynamic>.from(
          json['propertyDetailsDocuments'] as Map,
        ),
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
        aadhaarNumber: personalData['aadhaarNumber'] as String?,
        mobileNumber: personalData['mobileNumber'] as String?,
        personalEmailId: personalData['personalEmailId'] as String?,
        countryOfResidence: personalData['countryOfResidence'] as String?,
        residenceAddress: personalData['residenceAddress'] as String?,
        addressDifferentFromAadhaar: personalData['addressDifferentFromAadhaar'] as bool?,
        currentResidenceAddress: personalData['currentResidenceAddress'] as String?,
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
        loanAmount: personalData['loanAmount'] as String?,
        loanTenure: personalData['loanTenure'] as String?,
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
      
      // Try to load from new format with dates
      List<SalarySlipItem> slipItems = [];
      final isPdf = salaryData['isPdf'] as bool? ?? false;
      if (salaryData['slipItems'] != null) {
        final items = salaryData['slipItems'] as List<dynamic>;
        slipItems = items.map((item) {
          final itemMap = item as Map<String, dynamic>;
          return SalarySlipItem(
            path: itemMap['path'] as String,
            slipDate: itemMap['slipDate'] != null 
                ? DateTime.tryParse(itemMap['slipDate'] as String)
                : null,
            isPdf: itemMap['isPdf'] as bool? ?? isPdf, // Use item-level isPdf or fallback to global
          );
        }).toList();
      } else if (salaryData['slips'] != null) {
        // Legacy format - convert to new format
        final slips = (salaryData['slips'] as List<dynamic>?)?.cast<String>() ?? [];
        slipItems = slips.map((path) => SalarySlipItem(path: path, isPdf: isPdf)).toList();
      }
      
      submission.salarySlips = SalarySlips(
        slipItems: slipItems,
        pdfPassword: salaryData['pdfPassword'] as String?,
        isPdf: salaryData['isPdf'] as bool? ?? false,
      );
    }

    if (json['coApplicantSalarySlips'] != null) {
      final salaryData = json['coApplicantSalarySlips'] as Map<String, dynamic>;
      List<SalarySlipItem> slipItems = [];
      final isPdf = salaryData['isPdf'] as bool? ?? false;
      if (salaryData['slipItems'] != null) {
        final items = salaryData['slipItems'] as List<dynamic>;
        slipItems = items.map((item) {
          final itemMap = item as Map<String, dynamic>;
          return SalarySlipItem(
            path: itemMap['path'] as String,
            slipDate: itemMap['slipDate'] != null
                ? DateTime.tryParse(itemMap['slipDate'] as String)
                : null,
            isPdf: itemMap['isPdf'] as bool? ?? isPdf,
          );
        }).toList();
      } else if (salaryData['slips'] != null) {
        final slips = (salaryData['slips'] as List<dynamic>?)?.cast<String>() ?? [];
        slipItems = slips.map((path) => SalarySlipItem(path: path, isPdf: isPdf)).toList();
      }
      submission.coApplicantSalarySlips = SalarySlips(
        slipItems: slipItems,
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

