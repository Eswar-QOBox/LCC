import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../models/document_submission.dart';
import '../providers/submission_provider.dart';
import '../providers/application_provider.dart';

class PdfGenerationService {
  /// Generate PDF with all application data
  Future<void> generateApplicationPdf({
    required BuildContext context,
    required SubmissionProvider submissionProvider,
    required ApplicationProvider applicationProvider,
    bool useSampleData = false,
  }) async {
    try {
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
      
      // Add Documents section (references to uploaded files)
      await _addDocumentsSection(pdf, submission);
      
      // Add Summary section
      _addSummarySection(pdf, submission);
      
      // Save and share PDF
      await _saveAndSharePdf(context, pdf);
      
    } catch (e) {
      throw Exception('Failed to generate PDF: $e');
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
  Future<void> _addDocumentsSection(pw.Document pdf, DocumentSubmission submission) async {
    // Load images asynchronously
    final selfieImage = await _loadImageForPdf(submission.selfiePath);
    final aadhaarFrontImage = await _loadImageForPdf(submission.aadhaar?.frontPath);
    final aadhaarBackImage = await _loadImageForPdf(submission.aadhaar?.backPath);
    final panImage = await _loadImageForPdf(submission.pan?.frontPath);

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
            _buildSimpleDocRow('Salary Slips', submission.salarySlips?.slipItems.isNotEmpty == true 
              ? '${submission.salarySlips!.slipItems.length} slip${submission.salarySlips!.slipItems.length == 1 ? '' : 's'} uploaded' 
              : 'Not uploaded'),
            _buildSimpleDocRow('Salary Slips Format', submission.salarySlips?.isPdf == true ? 'PDF' : 'Image'),
            
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 20),

            // Document Images Section (Only if images are present and NOT PDF)
            if (submission.selfiePath != null || 
                (submission.aadhaar?.frontPath != null && submission.aadhaar?.frontIsPdf == false) ||
                (submission.aadhaar?.backPath != null && submission.aadhaar?.backIsPdf == false) ||
                (submission.pan?.frontPath != null && submission.pan?.isPdf == false)) ...[
              
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

  /// Load image from file path or asset and return PDF-compatible image
  Future<pw.MemoryImage?> _loadImageForPdf(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return null;

    try {
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
      // In a real implementation, you'd need to handle web differently
      if (kIsWeb) {
        return null;
      }

      final file = File(imagePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return pw.MemoryImage(bytes);
      }
    } catch (e) {
      // Silently fail if image can't be loaded
      print('Failed to load image $imagePath: $e');
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
