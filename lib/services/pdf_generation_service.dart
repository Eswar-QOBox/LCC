import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../models/document_submission.dart';
import '../models/additional_document.dart';
import '../providers/auth_provider.dart';
import '../providers/submission_provider.dart';
import '../providers/application_provider.dart';
import 'storage_service.dart';
import '../utils/api_config.dart';
import 'additional_documents_service.dart';

class PdfGenerationService {
  /// Generate PDF with all application data
  Future<void> generateApplicationPdf({
    required BuildContext context,
    required SubmissionProvider submissionProvider,
    required ApplicationProvider applicationProvider,
    bool useSampleData = false,
  }) async {
    try {
      // Best-effort: hydrate missing docs from backend for submitted users
      // (especially business-loan additional documents which are not stored in application steps).
      await _hydrateSubmissionForPdfIfNeeded(
        context: context,
        submissionProvider: submissionProvider,
        applicationProvider: applicationProvider,
      );

      // Get all submission data
      DocumentSubmission submission = submissionProvider.submission;
      
      // Use sample data if requested or if submission is empty
      if (useSampleData || submission.personalData == null) {
        submission = _createSampleSubmission();
      }
      
      // Create PDF document
      final pdf = pw.Document();

      // Load logo
      final logo = await _loadLogo();
      
      // Add title page
      _addTitlePage(pdf, logo);
      
      // Add Personal Data section (always add, using sample if needed)
      _addPersonalDataSection(pdf, submission.personalData ?? _createSamplePersonalData());
      
      // Auth token for loading backend image URLs into the PDF
      final authToken = await StorageService.instance.getAccessToken();
      await _addDocumentsSection(pdf, submission, authToken: authToken);
      
      // Add Summary section
      _addSummarySection(pdf, submission);
      
      // Save and share PDF
      await _saveAndSharePdf(context, pdf);
      
    } catch (e) {
      throw Exception('Failed to generate PDF: $e');
    }
  }

  /// Best-effort hydration so "What's Included" and PDF generation
  /// can work even when the local draft is missing submitted uploads.
  Future<void> hydrateSubmissionForPdf({
    required BuildContext context,
    required SubmissionProvider submissionProvider,
    required ApplicationProvider applicationProvider,
  }) async {
    await _hydrateSubmissionForPdfIfNeeded(
      context: context,
      submissionProvider: submissionProvider,
      applicationProvider: applicationProvider,
    );
  }

  Future<void> _hydrateSubmissionForPdfIfNeeded({
    required BuildContext context,
    required SubmissionProvider submissionProvider,
    required ApplicationProvider applicationProvider,
  }) async {
    // Ensure loan type flags exist (needed to decide business/proprietor flow).
    final app = applicationProvider.currentApplication;
    if (app != null) {
      final s = submissionProvider.submission;
      s.loanType ??= app.loanType;
      // businessLoanType is stored on submission; if missing, keep as-is (some flows may not set it).
      // (We don't have a dedicated field on the app model for this in all cases.)
    }

    final submission = submissionProvider.submission;
    final isBusinessLoan = (submission.loanType ?? '').toLowerCase().contains('business');
    final businessLoanType = (submission.businessLoanType ?? '').toLowerCase();
    final isProprietor = businessLoanType == 'proprietor';
    final isPartnership = businessLoanType == 'partnership';
    final isPvtLimited = businessLoanType == 'pvt_limited';
    if (!isBusinessLoan) return;

    // If business docs already present, don't override.
    // (Still allow partial hydration when missing.)
    final docs = submission.businessDocuments;

    // Fetch user's uploaded docs and map to business doc types.
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    final service = AdditionalDocumentsService();
    List<UploadedDocument> uploaded;
    try {
      uploaded = await service.getUserDocuments(user.id);
    } catch (_) {
      // Best-effort only; if network fails, keep whatever we have.
      return;
    }

    String? latestUrlForType(String type) {
      final matches = uploaded.where((d) => d.documentType == type && (d.url ?? '').trim().isNotEmpty).toList();
      if (matches.isEmpty) return null;
      matches.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      return matches.first.url;
    }

    bool isPdfUrl(String? url, String? fallbackName) {
      final u = (url ?? '').toLowerCase();
      final n = (fallbackName ?? '').toLowerCase();
      return u.contains('.pdf') || n.endsWith('.pdf');
    }

    // Map business additional docs (types used in upload calls).
    final spouseAadhaarFront = latestUrlForType('custom_spouse_aadhaar_front');
    final spouseAadhaarBack = latestUrlForType('custom_spouse_aadhaar_back');
    final spousePan = latestUrlForType('spouse_pan');

    final companyPan = latestUrlForType('custom_applicant_company_pan_card');
    final partnershipDeed = latestUrlForType('custom_applicant_partnership_deed');
    final moa = latestUrlForType('custom_applicant_moa');
    final aoa = latestUrlForType('custom_applicant_aoa');
    final gst = latestUrlForType('custom_applicant_gst_registration');
    final labour = latestUrlForType('custom_applicant_labour_certificate');
    final msme = latestUrlForType('custom_applicant_msme_certificate');
    final ohp = latestUrlForType('custom_applicant_ohp_own_house_proof');

    // Partnership partner docs (custom_partner_{i}_*).
    final partnerRe =
        RegExp(r'^custom_partner_(\d+)_(aadhaar_front|aadhaar_back|pan)$');
    final Map<int, UploadedDocument> partnerLatest = {};
    for (final d in uploaded) {
      final m = partnerRe.firstMatch(d.documentType);
      if (m == null) continue;
      final url = (d.url ?? '').trim();
      if (url.isEmpty) continue;
      final idx = int.tryParse(m.group(1) ?? '');
      if (idx == null || idx <= 0) continue;
      final key = idx * 10 + (m.group(2) == 'aadhaar_front'
          ? 1
          : (m.group(2) == 'aadhaar_back' ? 2 : 3));
      final prev = partnerLatest[key];
      if (prev == null || d.uploadedAt.isAfter(prev.uploadedAt)) {
        partnerLatest[key] = d;
      }
    }
    int inferredPartnerCount = 0;
    for (final key in partnerLatest.keys) {
      final idx = key ~/ 10;
      if (idx > inferredPartnerCount) inferredPartnerCount = idx;
    }

    // If businessLoanType is missing in a submitted session:
    // - infer "partnership" if partner docs exist
    // - otherwise infer "proprietor" if spouse docs exist
    final inferredPartnership =
        inferredPartnerCount > 0 && !isPartnership && !isPvtLimited && !isProprietor;
    if (inferredPartnership) {
      submissionProvider.setBusinessLoanType('partnership');
    }
    final inferredPvtLimited = (moa != null || aoa != null) && !isPvtLimited && !isPartnership && !isProprietor;
    if (inferredPvtLimited) {
      submissionProvider.setBusinessLoanType('pvt_limited');
    }
    final inferredProprietor = (spouseAadhaarFront != null ||
            spouseAadhaarBack != null ||
            spousePan != null) &&
        !isProprietor &&
        !isPartnership &&
        !isPvtLimited;
    if (inferredProprietor) {
      submissionProvider.setBusinessLoanType('proprietor');
    }

    // Only set if missing to avoid overwriting local draft values.
    if ((docs?.spouseAadhaar?.frontPath ?? '').trim().isEmpty && spouseAadhaarFront != null) {
      submissionProvider.setSpouseAadhaarFront(
        spouseAadhaarFront,
        isPdf: isPdfUrl(spouseAadhaarFront, null),
      );
    }
    if ((docs?.spouseAadhaar?.backPath ?? '').trim().isEmpty && spouseAadhaarBack != null) {
      submissionProvider.setSpouseAadhaarBack(
        spouseAadhaarBack,
        isPdf: isPdfUrl(spouseAadhaarBack, null),
      );
    }
    if ((docs?.spousePan?.frontPath ?? '').trim().isEmpty && spousePan != null) {
      submissionProvider.setSpousePan(
        spousePan,
        isPdf: isPdfUrl(spousePan, null),
      );
    }

    if ((docs?.gstRegistration?.path ?? '').trim().isEmpty && gst != null) {
      submissionProvider.setGstRegistration(gst, isPdf: isPdfUrl(gst, null));
    }
    if ((docs?.labourCertificate?.path ?? '').trim().isEmpty && labour != null) {
      submissionProvider.setLabourCertificate(labour, isPdf: isPdfUrl(labour, null));
    }
    if ((docs?.companyPanCard?.path ?? '').trim().isEmpty && companyPan != null) {
      submissionProvider.setCompanyPanCard(companyPan, isPdf: isPdfUrl(companyPan, null));
    }
    if ((docs?.partnershipDeed?.path ?? '').trim().isEmpty && partnershipDeed != null) {
      submissionProvider.setPartnershipDeed(partnershipDeed, isPdf: isPdfUrl(partnershipDeed, null));
    }
    if ((docs?.moa?.path ?? '').trim().isEmpty && moa != null) {
      submissionProvider.setMoa(moa, isPdf: isPdfUrl(moa, null));
    }
    if ((docs?.aoa?.path ?? '').trim().isEmpty && aoa != null) {
      submissionProvider.setAoa(aoa, isPdf: isPdfUrl(aoa, null));
    }
    if ((docs?.msmeCertificate?.path ?? '').trim().isEmpty && msme != null) {
      submissionProvider.setMsmeCertificate(msme, isPdf: isPdfUrl(msme, null));
    }
    if ((docs?.ownHouseProof?.path ?? '').trim().isEmpty && ohp != null) {
      submissionProvider.setOwnHouseProof(ohp, isPdf: isPdfUrl(ohp, null));
    }

    // Hydrate partners if present (partnership flow).
    if (inferredPartnerCount > 0) {
      final existingCount = docs?.partnerCount ?? 0;
      if (existingCount < inferredPartnerCount) {
        submissionProvider.setPartnerCount(inferredPartnerCount);
      }

      for (var i = 1; i <= inferredPartnerCount; i++) {
        final frontKey = i * 10 + 1;
        final backKey = i * 10 + 2;
        final panKey = i * 10 + 3;
        final frontUrl = partnerLatest[frontKey]?.url;
        final backUrl = partnerLatest[backKey]?.url;
        final panUrl = partnerLatest[panKey]?.url;

        final currentDocs = submissionProvider.submission.businessDocuments;
        final partner =
            (currentDocs != null && currentDocs.partners.length >= i)
                ? currentDocs.partners[i - 1]
                : null;

        if (((partner?.aadhaar?.frontPath ?? '').trim().isEmpty) && (frontUrl ?? '').trim().isNotEmpty) {
          submissionProvider.setPartnerAadhaarFront(
            i,
            frontUrl!.trim(),
            isPdf: isPdfUrl(frontUrl, null),
          );
        }
        if (((partner?.aadhaar?.backPath ?? '').trim().isEmpty) && (backUrl ?? '').trim().isNotEmpty) {
          submissionProvider.setPartnerAadhaarBack(
            i,
            backUrl!.trim(),
            isPdf: isPdfUrl(backUrl, null),
          );
        }
        if (((partner?.pan?.frontPath ?? '').trim().isEmpty) && (panUrl ?? '').trim().isNotEmpty) {
          submissionProvider.setPartnerPan(
            i,
            panUrl!.trim(),
            isPdf: isPdfUrl(panUrl, null),
          );
        }
      }
    }
  }

  /// Load JSEE Solutions logo from assets
  Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final byteData = await rootBundle.load('assets/main_logo.jpeg');
      final bytes = byteData.buffer.asUint8List();
      return pw.MemoryImage(bytes);
    } catch (e) {
      print('Failed to load logo: $e');
      return null;
    }
  }
  
  /// Create sample submission data for testing
  DocumentSubmission _createSampleSubmission() {
    final submission = DocumentSubmission(
      selfiePath: 'assets/1.png', // Use actual asset for testing
      aadhaar: AadhaarDocument(
        frontPath: 'assets/2.png',
        backPath: 'assets/3.png',
        frontIsPdf: false,
        backIsPdf: false,
      ),
      pan: PanDocument(
        frontPath: 'assets/4.png',
        isPdf: false,
      ),
      bankStatement: BankStatement(
        pages: ['assets/JSEE_icon.jpg'],
        isPdf: false,
        pdfPassword: null,
      ),
      personalData: _createSamplePersonalData(),
      salarySlips: SalarySlips(
        slipItems: [
          SalarySlipItem(path: 'assets/main_logo.jpeg', isPdf: false),
          SalarySlipItem(path: 'assets/Secure.jpg', isPdf: false),
        ],
        isPdf: false,
      ),
      submittedAt: DateTime.now(),
      status: SubmissionStatus.pendingVerification,
    );

    // Debug: print submission status
    print('Sample submission created:');
    print('Selfie path: ${submission.selfiePath}');
    print('Aadhaar front: ${submission.aadhaar?.frontPath}');
    print('Aadhaar back: ${submission.aadhaar?.backPath}');
    print('PAN path: ${submission.pan?.frontPath}');
    print('Bank statement pages: ${submission.bankStatement?.pages.length}');
    print('Salary slips: ${submission.salarySlips?.slipItems.length}');

    return submission;
  }
  
  /// Create sample personal data
  PersonalData _createSamplePersonalData() {
    return PersonalData(
      nameAsPerAadhaar: 'Rajesh Kumar',
      dateOfBirth: DateTime(1990, 5, 15),
      panNo: 'ABCDE1234F',
      mobileNumber: '9876543210',
      personalEmailId: 'rajesh.kumar@example.com',
      countryOfResidence: 'India',
      residenceAddress: '123, MG Road, Bangalore, Karnataka - 560001',
      residenceType: 'Owned',
      residenceStability: '5 years',
      companyName: 'Tech Solutions Pvt Ltd',
      companyAddress: '456, IT Park, Bangalore, Karnataka - 560048',
      nationality: 'Indian',
      countryOfBirth: 'India',
      occupation: 'Software Engineer',
      educationalQualification: 'B.Tech in Computer Science',
      workType: 'Full-time',
      industry: 'Information Technology',
      annualIncome: 'Rs. 12,00,000',
      totalWorkExperience: '8 years',
      currentCompanyExperience: '3 years',
      loanAmount: 'Rs. 5,00,000',
      loanTenure: '60',
      maritalStatus: 'Married',
      spouseName: 'Priya Kumar',
      fatherName: 'Ramesh Kumar',
      motherName: 'Sunita Kumar',
      reference1Name: 'Amit Sharma',
      reference1Address: '789, Park Street, Bangalore - 560002',
      reference1Contact: '9876543211',
      reference2Name: 'Vikram Singh',
      reference2Address: '321, Main Street, Bangalore - 560003',
      reference2Contact: '9876543212',
    );
  }
  
  /// Helper to build page background (border from 2nd page)
  pw.Widget _buildPageBackground(pw.Context context) {
    if (context.pageNumber > 1) {
      return pw.FullPage(
        ignoreMargins: true,
        child: pw.Container(
          margin: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 1),
          ),
        ),
      );
    }
    return pw.SizedBox();
  }

  /// Helper to build page footer (page numbers)
  pw.Widget _buildPageFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber}',
        style: pw.TextStyle(
          fontSize: 9,
          color: PdfColors.grey600,
        ),
      ),
    );
  }

  /// Add title page to PDF
  void _addTitlePage(pw.Document pdf, pw.MemoryImage? logo) {
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          buildBackground: _buildPageBackground,
        ),
        footer: _buildPageFooter,
        build: (pw.Context context) {
          return [
            // Top spacer
            pw.SizedBox(height: 50),
            
            // Main container with border
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.blue,
                  width: 2,
                ),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              padding: const pw.EdgeInsets.all(30),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Logo/Title area
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                          color: PdfColors.blue,
                          width: 2,
                        ),
                      ),
                    ),
                    padding: const pw.EdgeInsets.only(bottom: 20),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        if (logo != null) ...[
                          pw.Image(logo, width: 120), // Increased width for better visibility
                          pw.SizedBox(height: 15),
                        ],
                        pw.Text(
                          'JSEE SOLUTIONS LOAN APPLICATION',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 30),
                  
                  // Subtitle
                  pw.Text(
                    'Application Summary Report',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  
                  // Document info table
                  pw.Table(
                    border: pw.TableBorder.all(
                      color: PdfColors.grey400,
                      width: 1,
                    ),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2),
                      1: const pw.FlexColumnWidth(3),
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue100,
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text(
                              'Field',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text(
                              'Information',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text(
                              'Generated Date',
                              style: pw.TextStyle(fontSize: 11),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text(
                              DateFormat('dd MMM yyyy').format(DateTime.now()),
                              style: pw.TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text(
                              'Generated Time',
                              style: pw.TextStyle(fontSize: 11),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text(
                              DateFormat('hh:mm a').format(DateTime.now()),
                              style: pw.TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text(
                              'Document Type',
                              style: pw.TextStyle(fontSize: 11),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text(
                              'Loan Application Summary',
                              style: pw.TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 40),
                  
                  // Footer text
                  pw.Text(
                    'This is a confidential document containing loan application information.',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom spacer
            pw.SizedBox(height: 50),
          ];
        },
      ),
    );
  }
  
  /// Add Personal Data section
  void _addPersonalDataSection(pw.Document pdf, PersonalData data) {
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          buildBackground: _buildPageBackground,
        ),
        footer: _buildPageFooter,
        build: (pw.Context context) {
          return [
            // Page header with border
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: PdfColors.blue,
                    width: 3,
                  ),
                ),
              ),
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(
                'Personal Information',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            _buildPdfDataRow('Name (as per Aadhaar)', data.nameAsPerAadhaar),
            _buildPdfDataRow('Date of Birth', 
              data.dateOfBirth != null 
                ? DateFormat('dd MMM yyyy').format(data.dateOfBirth!) 
                : null),
            _buildPdfDataRow('PAN Number', data.panNo),
            _buildPdfDataRow('Mobile Number', data.mobileNumber),
            _buildPdfDataRow('Email ID', data.personalEmailId),
            pw.SizedBox(height: 15),
            _buildSectionHeader('Residence Information'),
            pw.SizedBox(height: 10),
            _buildPdfDataRow('Country of Residence', data.countryOfResidence),
            _buildPdfDataRow('Residence Address', data.residenceAddress),
            _buildPdfDataRow('Residence Type', data.residenceType),
            _buildPdfDataRow('Residence Stability', data.residenceStability),
            pw.SizedBox(height: 15),
            _buildSectionHeader('Work Information'),
            pw.SizedBox(height: 10),
            _buildPdfDataRow('Company Name', data.companyName),
            _buildPdfDataRow('Company Address', data.companyAddress),
            _buildPdfDataRow('Work Type', data.workType),
            _buildPdfDataRow('Industry', data.industry),
            _buildPdfDataRow('Annual Income', data.annualIncome != null ? _formatCurrency(data.annualIncome!) : null),
            _buildPdfDataRow('Total Work Experience', data.totalWorkExperience),
            _buildPdfDataRow('Current Company Experience', data.currentCompanyExperience),
            pw.SizedBox(height: 15),
            _buildSectionHeader('Personal Details'),
            pw.SizedBox(height: 10),
            _buildPdfDataRow('Occupation', data.occupation),
            _buildPdfDataRow('Educational Qualification', data.educationalQualification),
            if ((data.loanAmount != null && data.loanAmount!.isNotEmpty) || 
                (data.loanTenure != null && data.loanTenure!.isNotEmpty)) ...[
              pw.SizedBox(height: 15),
              _buildSectionHeader('Loan Details'),
              pw.SizedBox(height: 10),
              if (data.loanAmount != null && data.loanAmount!.isNotEmpty)
                _buildPdfDataRow('Loan Amount', _formatCurrency(data.loanAmount!)),
              if (data.loanTenure != null && data.loanTenure!.isNotEmpty)
                _buildPdfDataRow('Loan Tenure', '${data.loanTenure} months'),
            ] else if (data.loanAmountTenure != null && data.loanAmountTenure!.isNotEmpty) ...[
              pw.SizedBox(height: 15),
              _buildSectionHeader('Loan Details'),
              pw.SizedBox(height: 10),
              _buildPdfDataRow('Loan Amount/Tenure', data.loanAmountTenure != null ? _formatCurrency(data.loanAmountTenure!) : null),
            ],
            pw.SizedBox(height: 15),
            pw.Text(
              'Family Information',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            _buildPdfDataRow('Marital Status', data.maritalStatus),
            if (data.maritalStatus == 'Married' && data.spouseName != null && data.spouseName!.isNotEmpty)
              _buildPdfDataRow('Spouse Name', data.spouseName),
            _buildPdfDataRow('Father\'s Name', data.fatherName),
            _buildPdfDataRow('Mother\'s Name', data.motherName),
            pw.SizedBox(height: 15),
            _buildSectionHeader('References'),
            pw.SizedBox(height: 10),
            _buildPdfDataRow('Reference 1 Name', data.reference1Name),
            _buildPdfDataRow('Reference 1 Address', data.reference1Address),
            _buildPdfDataRow('Reference 1 Contact', data.reference1Contact),
            _buildPdfDataRow('Reference 2 Name', data.reference2Name),
            _buildPdfDataRow('Reference 2 Address', data.reference2Address),
            _buildPdfDataRow('Reference 2 Contact', data.reference2Contact),
          ];
        },
      ),
    );
  }
  
  /// Helper method to build simple data rows for document summary
  pw.Widget _buildSimpleDocRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '$label:',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Add Documents section (list of uploaded documents with images and detailed summary)
  Future<void> _addDocumentsSection(pw.Document pdf, DocumentSubmission submission, {String? authToken}) async {
    final isBusinessLoan = (submission.loanType ?? '').toLowerCase().contains('business');
    final business = submission.businessDocuments;
    final businessType = (submission.businessLoanType ?? '').toLowerCase();
    final hasPartners = business?.hasPartners ?? false;
    final isBusinessProprietor = isBusinessLoan &&
        (businessType == 'proprietor' ||
            (businessType.isEmpty && business?.spousePan != null));
    final isBusinessPartnership = isBusinessLoan &&
        (businessType == 'partnership' ||
            businessType == 'pvt_limited' ||
            (businessType.isEmpty && hasPartners));
    final isBusinessPvtLimited = isBusinessLoan && businessType == 'pvt_limited';
    final partnershipPartnerCount = business?.partnerCount ?? (hasPartners ? business!.partners.length : 0);

    // Load images asynchronously (from local/asset paths or from backend URLs)
    final selfieImage = await _loadImageForPdf(submission.selfiePath, authToken: authToken);
    final aadhaarFrontImage = await _loadImageForPdf(submission.aadhaar?.frontPath, authToken: authToken);
    final aadhaarBackImage = await _loadImageForPdf(submission.aadhaar?.backPath, authToken: authToken);
    final panImage = await _loadImageForPdf(submission.pan?.frontPath, authToken: authToken);

    // Bank statement + salary slips (images only)
    final bankImages = <pw.MemoryImage?>[];
    if (submission.bankStatement?.isPdf != true &&
        submission.bankStatement?.pages.isNotEmpty == true) {
      final pages = submission.bankStatement!.pages;
      final maxPages = pages.length > 3 ? 3 : pages.length;
      for (int i = 0; i < maxPages; i++) {
        bankImages.add(await _loadImageForPdf(pages[i], authToken: authToken));
      }
    }

    final slipImages = <pw.MemoryImage?>[];
    if (!isBusinessLoan &&
        submission.salarySlips?.slipItems.isNotEmpty == true) {
      final items = submission.salarySlips!.slipItems.where((i) => i.hasFile).toList();
      final maxSlips = items.length > 3 ? 3 : items.length;
      for (int i = 0; i < maxSlips; i++) {
        // Only embed images (skip PDFs)
        if (items[i].isPdf) {
          slipImages.add(null);
        } else {
          slipImages.add(await _loadImageForPdf(items[i].path, authToken: authToken));
        }
      }
    }

    // Business-loan docs (proprietor/partnership)
    final spouseAadhaarFrontImage = await _loadImageForPdf(
      business?.spouseAadhaar?.frontPath,
      authToken: authToken,
    );
    final spouseAadhaarBackImage = await _loadImageForPdf(
      business?.spouseAadhaar?.backPath,
      authToken: authToken,
    );
    final spousePanImage = await _loadImageForPdf(
      business?.spousePan?.frontPath,
      authToken: authToken,
    );
    final companyPanImage = await _loadImageForPdf(
      business?.companyPanCard?.path,
      authToken: authToken,
    );
    final partnershipDeedImage = await _loadImageForPdf(
      business?.partnershipDeed?.path,
      authToken: authToken,
    );
    final moaImage = await _loadImageForPdf(
      business?.moa?.path,
      authToken: authToken,
    );
    final aoaImage = await _loadImageForPdf(
      business?.aoa?.path,
      authToken: authToken,
    );
    final gstImage = await _loadImageForPdf(
      business?.gstRegistration?.path,
      authToken: authToken,
    );
    final labourImage = await _loadImageForPdf(
      business?.labourCertificate?.path,
      authToken: authToken,
    );
    final msmeImage = await _loadImageForPdf(
      business?.msmeCertificate?.path,
      authToken: authToken,
    );
    final ohpImage = await _loadImageForPdf(
      business?.ownHouseProof?.path,
      authToken: authToken,
    );

    final partnerImageEntries = <MapEntry<String, pw.MemoryImage?>>[];
    if (isBusinessLoan && isBusinessPartnership && partnershipPartnerCount > 0 && business != null) {
      final max = partnershipPartnerCount;
      for (var i = 0; i < max; i++) {
        final partner = business.partners.length > i ? business.partners[i] : null;
        final aadhaar = partner?.aadhaar;
        final pan = partner?.pan;
        final idx = i + 1;

        if (aadhaar?.frontPath != null && aadhaar!.frontIsPdf == false) {
          partnerImageEntries.add(
            MapEntry(
              'Partner $idx Aadhaar Front',
              await _loadImageForPdf(aadhaar.frontPath, authToken: authToken),
            ),
          );
        }
        if (aadhaar?.backPath != null && aadhaar!.backIsPdf == false) {
          partnerImageEntries.add(
            MapEntry(
              'Partner $idx Aadhaar Back',
              await _loadImageForPdf(aadhaar.backPath, authToken: authToken),
            ),
          );
        }
        if (pan?.frontPath != null && pan!.isPdf == false) {
          partnerImageEntries.add(
            MapEntry(
              'Partner $idx PAN',
              await _loadImageForPdf(pan.frontPath, authToken: authToken),
            ),
          );
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          buildBackground: _buildPageBackground,
        ),
        footer: _buildPageFooter,
        build: (pw.Context context) {
          return [
            // Page header with border
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: PdfColors.green,
                    width: 3,
                  ),
                ),
              ),
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(
                'Uploaded Documents',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green,
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // Simple Document Summary (Matching the image)
            _buildSimpleDocRow('Selfie', submission.selfiePath != null ? 'Uploaded' : 'Not uploaded'),
            _buildSimpleDocRow('Aadhaar Front', submission.aadhaar?.frontPath != null ? 'Uploaded' : 'Not uploaded'),
            _buildSimpleDocRow('Aadhaar Back', submission.aadhaar?.backPath != null ? 'Uploaded' : 'Not uploaded'),
            _buildSimpleDocRow('PAN Card', submission.pan?.frontPath != null ? 'Uploaded' : 'Not uploaded'),
            _buildSimpleDocRow('PAN Format', submission.pan?.isPdf == true ? 'PDF' : 'Image'),
            _buildSimpleDocRow('Bank Statement', submission.bankStatement?.pages.isNotEmpty == true 
              ? '${submission.bankStatement!.pages.length} page${submission.bankStatement!.pages.length == 1 ? '' : 's'} uploaded' 
              : 'Not uploaded'),
            _buildSimpleDocRow('Bank Statement Format', submission.bankStatement?.isPdf == true ? 'PDF' : 'Image'),
            if (!(isBusinessLoan && (isBusinessProprietor || isBusinessPartnership))) ...[
              _buildSimpleDocRow(
                'Salary Slips',
                (submission.salarySlips?.uploadedCount ?? 0) > 0
                    ? '${submission.salarySlips!.uploadedCount} slip${submission.salarySlips!.uploadedCount == 1 ? '' : 's'} uploaded'
                    : 'Not uploaded',
              ),
              _buildSimpleDocRow('Salary Slips Format', submission.salarySlips?.isPdf == true ? 'PDF' : 'Image'),
            ] else ...[
              _buildSimpleDocRow('Salary Slips', 'Not required (Business Loan)'),
            ],

            if (isBusinessLoan && isBusinessProprietor) ...[
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                'Business Loan Documents',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 8),
              _buildSimpleDocRow(
                'Spouse Aadhaar',
                (business?.spouseAadhaar?.isComplete ?? false) ? 'Uploaded' : 'Not uploaded',
              ),
              _buildSimpleDocRow(
                'Spouse PAN',
                (business?.spousePan?.isComplete ?? false) ? 'Uploaded' : 'Not uploaded',
              ),
              _buildSimpleDocRow(
                'GST Registration',
                (business?.gstRegistration?.isComplete ?? false) ? 'Uploaded' : 'Not uploaded',
              ),
              _buildSimpleDocRow(
                'Labour Certificate',
                (business?.labourCertificate?.isComplete ?? false) ? 'Uploaded' : 'Not uploaded',
              ),
              _buildSimpleDocRow(
                'MSME Certificate',
                (business?.msmeCertificate?.isComplete ?? false) ? 'Uploaded' : 'Not uploaded',
              ),
              _buildSimpleDocRow(
                'Own House Proof',
                (business?.ownHouseProof?.isComplete ?? false) ? 'Uploaded' : 'Not uploaded',
              ),
            ],
            if (isBusinessLoan && isBusinessPartnership) ...[
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                'Business Loan Documents',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 8),
              _buildSimpleDocRow(
                'Partners',
                partnershipPartnerCount > 0 ? '$partnershipPartnerCount partner(s)' : 'Not selected',
              ),
              _buildSimpleDocRow(
                'Partners KYC',
                (business?.isPartnerKycComplete ?? false) ? 'Completed' : 'Not uploaded',
              ),
              _buildSimpleDocRow(
                'Company PAN Card',
                (business?.companyPanCard?.isComplete ?? false) ? 'Uploaded' : 'Not uploaded',
              ),
              if (isBusinessPvtLimited) ...[
                _buildSimpleDocRow(
                  'MOA',
                  (business?.moa?.isComplete ?? false) ? 'Uploaded' : 'Not uploaded',
                ),
                _buildSimpleDocRow(
                  'AOA',
                  (business?.aoa?.isComplete ?? false) ? 'Uploaded' : 'Not uploaded',
                ),
              ] else
                _buildSimpleDocRow(
                  'Partnership Deed',
                  (business?.partnershipDeed?.isComplete ?? false) ? 'Uploaded' : 'Not uploaded',
                ),
              _buildSimpleDocRow(
                'GST Registration',
                (business?.gstRegistration?.isComplete ?? false) ? 'Uploaded' : 'Not uploaded',
              ),
              _buildSimpleDocRow(
                'Labour Certificate',
                (business?.labourCertificate?.isComplete ?? false) ? 'Uploaded' : 'Not uploaded',
              ),
              _buildSimpleDocRow(
                'MSME Certificate',
                (business?.msmeCertificate?.isComplete ?? false) ? 'Uploaded' : 'Not uploaded',
              ),
              _buildSimpleDocRow(
                'Own House Proof',
                (business?.ownHouseProof?.isComplete ?? false) ? 'Uploaded' : 'Not uploaded',
              ),
            ],
            
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 20),

            // Document Images Section (Only if images are present and NOT PDF)
            if (submission.selfiePath != null || 
                (submission.aadhaar?.frontPath != null && submission.aadhaar?.frontIsPdf == false) ||
                (submission.aadhaar?.backPath != null && submission.aadhaar?.backIsPdf == false) ||
                (submission.pan?.frontPath != null && submission.pan?.isPdf == false) ||
                (submission.bankStatement?.isPdf == false && submission.bankStatement?.pages.isNotEmpty == true) ||
                (!isBusinessLoan && (submission.salarySlips?.uploadedCount ?? 0) > 0) ||
                (isBusinessLoan && (isBusinessProprietor || isBusinessPartnership) && (
                  (business?.spouseAadhaar?.frontPath != null && business?.spouseAadhaar?.frontIsPdf == false) ||
                  (business?.spouseAadhaar?.backPath != null && business?.spouseAadhaar?.backIsPdf == false) ||
                  (business?.spousePan?.frontPath != null && business?.spousePan?.isPdf == false) ||
                  (business?.companyPanCard?.path != null && business?.companyPanCard?.isPdf == false) ||
                  (business?.partnershipDeed?.path != null && business?.partnershipDeed?.isPdf == false) ||
                  (business?.moa?.path != null && business?.moa?.isPdf == false) ||
                  (business?.aoa?.path != null && business?.aoa?.isPdf == false) ||
                  (business?.gstRegistration?.path != null && business?.gstRegistration?.isPdf == false) ||
                  (business?.labourCertificate?.path != null && business?.labourCertificate?.isPdf == false) ||
                  (business?.msmeCertificate?.path != null && business?.msmeCertificate?.isPdf == false) ||
                  (business?.ownHouseProof?.path != null && business?.ownHouseProof?.isPdf == false) ||
                  (isBusinessPartnership && partnerImageEntries.isNotEmpty)
                ))) ...[
              
              _buildSectionHeader('Document Images'),
              pw.SizedBox(height: 15),

              // Selfie Image
              if (submission.selfiePath != null)
                _buildPdfImageWidget('Selfie', selfieImage),

              // Aadhaar Images
              if ((submission.aadhaar?.frontPath != null && submission.aadhaar?.frontIsPdf == false) ||
                  (submission.aadhaar?.backPath != null && submission.aadhaar?.backIsPdf == false)) ...[
                pw.Row(
                  children: [
                    if (submission.aadhaar?.frontPath != null && submission.aadhaar?.frontIsPdf == false)
                      pw.Expanded(
                        child: _buildPdfImageWidget('Aadhaar Front', aadhaarFrontImage),
                      ),
                    if (submission.aadhaar?.frontPath != null && submission.aadhaar?.frontIsPdf == false &&
                        submission.aadhaar?.backPath != null && submission.aadhaar?.backIsPdf == false)
                      pw.SizedBox(width: 10),
                    if (submission.aadhaar?.backPath != null && submission.aadhaar?.backIsPdf == false)
                      pw.Expanded(
                        child: _buildPdfImageWidget('Aadhaar Back', aadhaarBackImage),
                      ),
                  ],
                ),
              ],

              // PAN Card Image
              if (submission.pan?.frontPath != null && submission.pan?.isPdf == false)
                _buildPdfImageWidget('PAN Card', panImage),

              // Bank statement pages (first up to 3)
              if (submission.bankStatement?.isPdf != true &&
                  submission.bankStatement?.pages.isNotEmpty == true) ...[
                pw.SizedBox(height: 10),
                _buildSectionHeader('Bank Statement (Pages)'),
                pw.SizedBox(height: 12),
                _buildPdfImageGrid(
                  [
                    for (int i = 0; i < bankImages.length; i++)
                      MapEntry('Bank Page ${i + 1}', bankImages[i]),
                  ],
                  columns: 2,
                  imageHeight: 110,
                ),
              ],

              // Salary slips (first up to 3, images only)
              if (!isBusinessLoan && (submission.salarySlips?.uploadedCount ?? 0) > 0) ...[
                pw.SizedBox(height: 10),
                _buildSectionHeader('Salary Slips'),
                pw.SizedBox(height: 12),
                _buildPdfImageGrid(
                  [
                    for (int i = 0; i < slipImages.length; i++)
                      MapEntry('Salary Slip ${i + 1}', slipImages[i]),
                  ],
                  columns: 2,
                  imageHeight: 110,
                ),
              ],

              if (isBusinessLoan && isBusinessProprietor) ...[
                pw.SizedBox(height: 10),
                _buildSectionHeader('Business Documents (Images)'),
                pw.SizedBox(height: 12),

                if ((business?.spouseAadhaar?.frontPath != null &&
                        business?.spouseAadhaar?.frontIsPdf == false) ||
                    (business?.spouseAadhaar?.backPath != null &&
                        business?.spouseAadhaar?.backIsPdf == false)) ...[
                  pw.Row(
                    children: [
                      if (business?.spouseAadhaar?.frontPath != null &&
                          business?.spouseAadhaar?.frontIsPdf == false)
                        pw.Expanded(
                          child: _buildPdfImageWidget(
                            'Spouse Aadhaar Front',
                            spouseAadhaarFrontImage,
                          ),
                        ),
                      if (business?.spouseAadhaar?.frontPath != null &&
                          business?.spouseAadhaar?.frontIsPdf == false &&
                          business?.spouseAadhaar?.backPath != null &&
                          business?.spouseAadhaar?.backIsPdf == false)
                        pw.SizedBox(width: 10),
                      if (business?.spouseAadhaar?.backPath != null &&
                          business?.spouseAadhaar?.backIsPdf == false)
                        pw.Expanded(
                          child: _buildPdfImageWidget(
                            'Spouse Aadhaar Back',
                            spouseAadhaarBackImage,
                          ),
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                ],

                if (business?.spousePan?.frontPath != null &&
                    business?.spousePan?.isPdf == false)
                  pw.SizedBox(height: 0),

                _buildPdfImageGrid(
                  [
                    if (business?.spousePan?.frontPath != null &&
                        business?.spousePan?.isPdf == false)
                      MapEntry('Spouse PAN', spousePanImage),
                    if (business?.gstRegistration?.path != null &&
                        business?.gstRegistration?.isPdf == false)
                      MapEntry('GST Registration', gstImage),
                    if (business?.labourCertificate?.path != null &&
                        business?.labourCertificate?.isPdf == false)
                      MapEntry('Labour Certificate', labourImage),
                    if (business?.msmeCertificate?.path != null &&
                        business?.msmeCertificate?.isPdf == false)
                      MapEntry('MSME Certificate', msmeImage),
                    if (business?.ownHouseProof?.path != null &&
                        business?.ownHouseProof?.isPdf == false)
                      MapEntry('Own House Proof', ohpImage),
                  ],
                  columns: 2,
                  imageHeight: 110,
                ),
              ],
              if (isBusinessLoan && isBusinessPartnership) ...[
                pw.SizedBox(height: 10),
                _buildSectionHeader('Business Documents (Images)'),
                pw.SizedBox(height: 12),
                _buildPdfImageGrid(
                  [
                    if (business?.companyPanCard?.path != null &&
                        business?.companyPanCard?.isPdf == false)
                      MapEntry('Company PAN Card', companyPanImage),
                    if (business?.partnershipDeed?.path != null &&
                        business?.partnershipDeed?.isPdf == false)
                      MapEntry('Partnership Deed', partnershipDeedImage),
                    if (business?.moa?.path != null &&
                        business?.moa?.isPdf == false)
                      MapEntry('MOA', moaImage),
                    if (business?.aoa?.path != null &&
                        business?.aoa?.isPdf == false)
                      MapEntry('AOA', aoaImage),
                    if (business?.gstRegistration?.path != null &&
                        business?.gstRegistration?.isPdf == false)
                      MapEntry('GST Registration', gstImage),
                    if (business?.labourCertificate?.path != null &&
                        business?.labourCertificate?.isPdf == false)
                      MapEntry('Labour Certificate', labourImage),
                    if (business?.msmeCertificate?.path != null &&
                        business?.msmeCertificate?.isPdf == false)
                      MapEntry('MSME Certificate', msmeImage),
                    if (business?.ownHouseProof?.path != null &&
                        business?.ownHouseProof?.isPdf == false)
                      MapEntry('Own House Proof', ohpImage),
                  ],
                  columns: 2,
                  imageHeight: 110,
                ),
              ],
            ],
              if (isBusinessLoan && isBusinessPartnership && partnerImageEntries.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                _buildSectionHeader('Partners (Images)'),
                pw.SizedBox(height: 12),
                _buildPdfImageGrid(
                  partnerImageEntries,
                  columns: 2,
                  imageHeight: 110,
                ),
              ],
          ];
        },
      ),
    );
  }

  /// Add Summary section
  void _addSummarySection(pw.Document pdf, DocumentSubmission submission) {
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          buildBackground: _buildPageBackground,
        ),
        footer: _buildPageFooter,
        build: (pw.Context context) {
          return [
            // Page header with border
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: PdfColors.orange,
                    width: 3,
                  ),
                ),
              ),
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(
                'Application Summary',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange,
                ),
              ),
            ),
            pw.SizedBox(height: 30),
            
            // Summary box with border
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.grey400,
                  width: 1,
                ),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Text(
                        'Status: ',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        submission.status.toString().split('.').last,
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.green,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 15),
                  if (submission.submittedAt != null)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Submitted At:',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          DateFormat('dd MMM yyyy, hh:mm a').format(submission.submittedAt!),
                          style: pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 40),
            
            // Info box
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.amber,
                  width: 1.5,
                ),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                color: PdfColors.amber50,
              ),
              padding: const pw.EdgeInsets.all(15),
              child: pw.Text(
                'Note: This PDF contains a summary of your application. The actual document files are stored securely on our servers.',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          ];
        },
      ),
    );
  }
  
  /// Format currency value - replace rupee symbol with Rs. for PDF compatibility
  String _formatCurrency(String value) {
    if (value.isEmpty) return value;
    
    // First sanitize to remove rupee symbol (handles all Unicode variations)
    String formatted = value.replaceAll('₹', '').replaceAll('\u20B9', '').trim();
    
    // Remove any existing Rs. or rs. to avoid duplication
    formatted = formatted.replaceAll(RegExp(r'^[Rr][Ss]\.?\s*', caseSensitive: false), '').trim();
    
    // Add Rs. prefix if value contains numbers
    if (formatted.isNotEmpty && RegExp(r'\d').hasMatch(formatted)) {
      formatted = 'Rs. $formatted';
    }
    
    return formatted;
  }
  
  /// Sanitize text to remove rupee symbols and other problematic Unicode characters
  String _sanitizeText(String? text) {
    if (text == null || text.isEmpty) return text ?? 'Not provided';
    // Replace rupee symbol (both regular and Unicode) with Rs.
    return text.replaceAll('₹', 'Rs.').replaceAll('\u20B9', 'Rs.');
  }
  
  /// Helper to build section header with border and background
  pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border(
          left: pw.BorderSide(
            color: PdfColors.blue,
            width: 4,
          ),
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue800,
        ),
      ),
    );
  }

  /// Load image from file path, asset, or HTTP/HTTPS URL; returns PDF-compatible image.
  Future<pw.MemoryImage?> _loadImageForPdf(String? imagePath, {String? authToken}) async {
    if (imagePath == null || imagePath.isEmpty) return null;

    try {
      String normalizeNetworkUrl(String raw) {
        var path = raw.trim();
        if (path.isEmpty) return path;
        // Stored as "baseUrl..." sometimes
        if (path.startsWith('baseUrl')) {
          path = path.replaceFirst('baseUrl', ApiConfig.baseUrl);
        }
        // Old localhost saved URLs
        if (path.startsWith('http://localhost:5000')) {
          path = path.replaceFirst('http://localhost:5000', ApiConfig.baseUrl);
        }
        // If already absolute URL
        if (path.startsWith('http://') || path.startsWith('https://')) return path;

        // Normalize missing-leading-slash variants.
        if (path.startsWith('uploads/') || path.startsWith('api/')) {
          path = '/$path';
        }
        if (!path.startsWith('/')) {
          // likely local filesystem path; return as-is so File() can try.
          return raw;
        }

        // Normalize /api/v1/uploads/<category>/... -> /api/v1/uploads/files/<category>/...
        if (path.startsWith('/api/v1/uploads/') &&
            !path.startsWith('/api/v1/uploads/files/')) {
          path = path.replaceFirst('/api/v1/uploads/', '/api/v1/uploads/files/');
        }

        // Normalize /uploads/<category>/... -> /api/v1/uploads/files/<category>/...
        if (path.startsWith('/uploads/') && !path.contains('/uploads/files/')) {
          path = path.replaceFirst('/uploads/', '/api/v1/uploads/files/');
        }

        // Treat /api/... and /api/v1/... as server paths
        if (path.startsWith('/api/')) {
          return '${ApiConfig.baseUrl}$path';
        }

        return raw;
      }

      final normalized = normalizeNetworkUrl(imagePath);

      // Load from HTTP/HTTPS URL (e.g. backend upload URLs)
      if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
        final uri = Uri.parse(normalized);
        final headers = <String, String>{};
        if (authToken != null && authToken.isNotEmpty) {
          headers['Authorization'] = 'Bearer $authToken';
        }
        final response = await http.get(uri, headers: headers);
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return pw.MemoryImage(response.bodyBytes);
        }
        return null;
      }

      // Check if it's an asset path (for testing)
      if (imagePath.startsWith('assets/')) {
        final byteData = await rootBundle.load(imagePath);
        final bytes = byteData.buffer.asUint8List();
        return pw.MemoryImage(bytes);
      }

      // Check if it's a sample data path (for testing)
      if (imagePath.startsWith('/sample/')) {
        return null; // Skip sample data images
      }

      // For web platform, we can't directly read files from paths
      if (kIsWeb) return null;

      final file = File(imagePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return pw.MemoryImage(bytes);
      }
    } catch (e) {
      if (kDebugMode) {
        print('PdfGenerationService: Failed to load image $imagePath: $e');
      }
    }
    return null;
  }

  /// Build image display widget for PDF with border and caption
  pw.Widget _buildPdfImageWidget(String title, pw.MemoryImage? image, {bool isUploaded = true}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 15),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: isUploaded && image != null ? PdfColors.green : PdfColors.grey400,
          width: 2,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Title
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: isUploaded && image != null ? PdfColors.green : PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 8),
          // Image or placeholder
          if (image != null) ...[
            pw.Container(
              height: 150,
              width: double.infinity,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Image(
                image,
                fit: pw.BoxFit.contain,
              ),
            ),
          ] else ...[
            pw.Container(
              height: 150,
              width: double.infinity,
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey300, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Center(
                child: pw.Text(
                  isUploaded ? 'Image not available for PDF display' : 'Not uploaded',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Compact image tile (for grid layouts)
  pw.Widget _buildPdfImageTile(
    String title,
    pw.MemoryImage? image, {
    bool isUploaded = true,
    double imageHeight = 110,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: isUploaded && image != null ? PdfColors.green : PdfColors.grey400,
          width: 1.5,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: isUploaded && image != null ? PdfColors.green : PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            height: imageHeight,
            width: double.infinity,
            decoration: pw.BoxDecoration(
              color: image != null ? PdfColors.white : PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: image != null
                ? pw.Image(image, fit: pw.BoxFit.contain)
                : pw.Center(
                    child: pw.Text(
                      isUploaded ? 'Preview not available' : 'Not uploaded',
                      style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Two-column (default) image grid for better placement
  pw.Widget _buildPdfImageGrid(
    List<MapEntry<String, pw.MemoryImage?>> items, {
    int columns = 2,
    double imageHeight = 110,
  }) {
    if (items.isEmpty) return pw.SizedBox();
    final filtered = items.where((e) => e.key.trim().isNotEmpty).toList();
    if (filtered.isEmpty) return pw.SizedBox();

    return pw.LayoutBuilder(
      builder: (context, constraints) {
        final gap = 10.0;
        final maxW = constraints?.maxWidth ?? 500.0;
        final col = columns <= 0 ? 2 : columns;
        final itemW = (maxW - (gap * (col - 1))) / col;
        return pw.Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final entry in filtered)
              pw.SizedBox(
                width: itemW,
                child: _buildPdfImageTile(
                  entry.key,
                  entry.value,
                  imageHeight: imageHeight,
                ),
              ),
          ],
        );
      },
    );
  }

  
  /// Helper to build data rows in PDF
  pw.Widget _buildPdfDataRow(String label, String? value) {
    final sanitizedValue = value == null ? 'Not provided' : _sanitizeText(value);
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColors.grey300,
            width: 1,
          ),
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
                color: PdfColors.blue700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              sanitizedValue,
              style: const pw.TextStyle(
                fontSize: 11,
                color: PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Save PDF and share it
  Future<void> _saveAndSharePdf(BuildContext context, pw.Document pdf) async {
    try {
      // Save PDF bytes - handle isolate spawn errors
      Uint8List bytes;
      try {
        // pdf.save() uses isolates internally for performance
        bytes = await pdf.save();
      } catch (e) {
        // Handle isolate spawn errors
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('isolate') || 
            errorStr.contains('spawn') || 
            errorStr.contains('concurrent') ||
            errorStr.contains('thread') ||
            errorStr.contains('platform')) {
          // Isolate spawn failed - this can happen on some platforms
          // Try once more with a small delay
          await Future.delayed(const Duration(milliseconds: 100));
          try {
            bytes = await pdf.save();
          } catch (retryError) {
            throw Exception(
              'PDF generation failed due to system limitations. '
              'Please try again or restart the app. '
              'Error: ${retryError.toString()}'
            );
          }
        } else {
          // Re-throw if it's not an isolate error
          throw Exception('Failed to save PDF: $e');
        }
      }
      
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'loan_application_$timestamp.pdf';
      
      if (kIsWeb) {
        // On web, use share_plus
        try {
          await Share.shareXFiles(
            [XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName)],
            text: 'My Loan Application Data',
            subject: 'Loan Application Export',
          );
        } catch (e) {
          throw Exception('Failed to share PDF on web. Error: $e');
        }
      } else {
        // On mobile/desktop, save to temp directory and share
        try {
          final directory = await getTemporaryDirectory();
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(bytes);
          
          await Share.shareXFiles(
            [XFile(file.path)],
            text: 'My Loan Application Data',
            subject: 'Loan Application Export',
          );
        } catch (e) {
          throw Exception('Failed to save or share PDF. Error: $e');
        }
      }
    } catch (e) {
      // Provide user-friendly error message
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('isolate') || errorStr.contains('spawn')) {
        throw Exception('PDF generation encountered a system error. Please try again or restart the app.');
      }
      // Re-throw with original error if it's already an Exception
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to generate PDF: $e');
    }
  }
}
