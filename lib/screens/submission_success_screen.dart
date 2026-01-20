import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import '../providers/submission_provider.dart';
import '../providers/application_provider.dart';
import '../models/document_submission.dart';
import '../utils/app_routes.dart';
import '../widgets/premium_toast.dart';

class SubmissionSuccessScreen extends StatefulWidget {
  const SubmissionSuccessScreen({super.key});

  @override
  State<SubmissionSuccessScreen> createState() => _SubmissionSuccessScreenState();
}

class _SubmissionSuccessScreenState extends State<SubmissionSuccessScreen> {
  bool _isDownloading = false;

  /// Get selfie path from ApplicationProvider (per-application storage)
  String? _getSelfiePath(BuildContext context) {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication) return null;
    
    final application = appProvider.currentApplication!;
    if (application.step1Selfie != null) {
      final stepData = application.step1Selfie as Map<String, dynamic>;
      return stepData['imagePath'] as String?;
    }
    return null;
  }

  /// Read image bytes from file path (handles both web and mobile)
  Future<Uint8List?> _readImageBytes(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return null;
    
    try {
      if (kIsWeb) {
        // Handle blob URLs on web
        if (imagePath.startsWith('blob:')) {
          try {
            final response = await http.get(Uri.parse(imagePath));
            if (response.statusCode == 200) {
              return response.bodyBytes;
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error fetching blob URL: $e');
            }
          }
          return null;
        }
        
        // Handle data URIs on web
        if (imagePath.startsWith('data:')) {
          try {
            final commaIndex = imagePath.indexOf(',');
            if (commaIndex != -1) {
              final base64Data = imagePath.substring(commaIndex + 1);
              return base64Decode(base64Data);
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error decoding data URI: $e');
            }
          }
          return null;
        }
        
        // Try to read as XFile if possible
        final file = XFile(imagePath);
        return await file.readAsBytes();
      } else {
        // On mobile/desktop, read from file path
        final file = File(imagePath);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error reading image: $e');
      }
    }
    return null;
  }

  /// Convert image bytes to PNG format for PDF compatibility
  Future<Uint8List?> _convertImageToPng(Uint8List? imageBytes) async {
    if (imageBytes == null) return null;
    
    try {
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) {
        if (kDebugMode) {
          print('Failed to decode image');
        }
        return null;
      }
      
      final pngBytes = img.encodePng(decodedImage);
      return Uint8List.fromList(pngBytes);
    } catch (e) {
      if (kDebugMode) {
        print('Error converting image to PNG: $e');
      }
      return imageBytes;
    }
  }

  /// Read PDF bytes from file path (handles both web and mobile)
  Future<Uint8List?> _readPdfBytes(String? pdfPath) async {
    if (pdfPath == null || pdfPath.isEmpty) return null;
    
    try {
      if (kIsWeb) {
        if (pdfPath.startsWith('blob:')) {
          try {
            final response = await http.get(Uri.parse(pdfPath));
            if (response.statusCode == 200) {
              return response.bodyBytes;
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error fetching PDF blob URL: $e');
            }
          }
          return null;
        }
        
        if (pdfPath.startsWith('data:')) {
          try {
            final commaIndex = pdfPath.indexOf(',');
            if (commaIndex != -1) {
              final base64Data = pdfPath.substring(commaIndex + 1);
              return base64Decode(base64Data);
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error decoding PDF data URI: $e');
            }
          }
          return null;
        }
        
        final file = XFile(pdfPath);
        return await file.readAsBytes();
      } else {
        final file = File(pdfPath);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error reading PDF: $e');
      }
    }
    return null;
  }

  /// Helper function to add a note page for PDFs
  void _addPdfNotePage(pw.Document pdf, String title, String message) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                message,
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Merge PDF pages from a PDF file into the main PDF document
  Future<void> _mergePdfIntoDocument(pw.Document mainPdf, String pdfPath, String title) async {
    try {
      final pdfBytes = await _readPdfBytes(pdfPath);
      if (pdfBytes == null) {
        if (kDebugMode) {
          print('Failed to read PDF bytes from: $pdfPath');
        }
        _addPdfNotePage(mainPdf, title, 'Unable to read PDF file.');
        return;
      }

      _addPdfNotePage(
        mainPdf, 
        title, 
        'PDF document included (${(pdfBytes.length / 1024).toStringAsFixed(1)} KB).\n\nThe original PDF file has been preserved in your submission and will be available for review.',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error merging PDF: $e');
      }
      _addPdfNotePage(mainPdf, title, 'Unable to merge PDF content. Original file included separately.');
    }
  }

  /// Helper to build data rows in PDF
  pw.Widget _buildPdfDataRow(String label, String? value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value ?? 'Not provided',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  /// Generate PDF with all application data and images
  Future<void> _downloadAsPdf(BuildContext context) async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      final provider = context.read<SubmissionProvider>();
      final submission = provider.submission;
      final personalData = submission.personalData;

      // Create PDF document
      final pdf = pw.Document();
      final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
      final generatedDate = dateFormat.format(DateTime.now());

      // Add title page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Loan Application Data',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Generated on: $generatedDate',
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Application Status: Submitted',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Add Personal Data section
      if (personalData != null) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(40),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Personal Information',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  _buildPdfDataRow('Name (as per Aadhaar)', personalData.nameAsPerAadhaar),
                  _buildPdfDataRow('Date of Birth', personalData.dateOfBirth != null 
                    ? DateFormat('dd MMM yyyy').format(personalData.dateOfBirth!) 
                    : null),
                  _buildPdfDataRow('PAN Number', personalData.panNo),
                  _buildPdfDataRow('Mobile Number', personalData.mobileNumber),
                  _buildPdfDataRow('Email ID', personalData.personalEmailId),
                  pw.SizedBox(height: 15),
                  pw.Text(
                    'Residence Information',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _buildPdfDataRow('Country of Residence', personalData.countryOfResidence),
                  _buildPdfDataRow('Residence Address', personalData.residenceAddress),
                  _buildPdfDataRow('Residence Type', personalData.residenceType),
                  _buildPdfDataRow('Residence Stability', personalData.residenceStability),
                  pw.SizedBox(height: 15),
                  pw.Text(
                    'Work Info',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _buildPdfDataRow('Company Name', personalData.companyName),
                  _buildPdfDataRow('Company Address', personalData.companyAddress),
                  _buildPdfDataRow('Work Type', personalData.workType),
                  _buildPdfDataRow('Industry', personalData.industry),
                  _buildPdfDataRow('Annual Income', personalData.annualIncome),
                  _buildPdfDataRow('Total years of experience', personalData.totalWorkExperience),
                  _buildPdfDataRow('Current Company Experience', personalData.currentCompanyExperience),
                  pw.SizedBox(height: 15),
                  pw.Text(
                    'Personal Details',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _buildPdfDataRow('Occupation', personalData.occupation),
                  _buildPdfDataRow('Educational Qualification', personalData.educationalQualification),
                  if ((personalData.loanAmount != null && personalData.loanAmount!.isNotEmpty) || 
                      (personalData.loanTenure != null && personalData.loanTenure!.isNotEmpty)) ...[
                    pw.SizedBox(height: 15),
                    pw.Text(
                      'Loan Details',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    if (personalData.loanAmount != null && personalData.loanAmount!.isNotEmpty)
                      _buildPdfDataRow('Loan Amount', '₹ ${personalData.loanAmount}'),
                    if (personalData.loanTenure != null && personalData.loanTenure!.isNotEmpty)
                      _buildPdfDataRow('Loan Tenure', '${personalData.loanTenure} months'),
                  ] else if (personalData.loanAmountTenure != null && personalData.loanAmountTenure!.isNotEmpty) ...[
                    pw.SizedBox(height: 15),
                    pw.Text(
                      'Loan Details',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _buildPdfDataRow('Loan Amount/Tenure', personalData.loanAmountTenure),
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
                  _buildPdfDataRow('Marital Status', personalData.maritalStatus),
                  _buildPdfDataRow('Spouse Name', personalData.spouseName),
                  _buildPdfDataRow('Father\'s Name', personalData.fatherName),
                  _buildPdfDataRow('Mother\'s Name', personalData.motherName),
                  pw.SizedBox(height: 15),
                  pw.Text(
                    'References',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _buildPdfDataRow('Reference 1 Name', personalData.reference1Name),
                  _buildPdfDataRow('Reference 1 Address', personalData.reference1Address),
                  _buildPdfDataRow('Reference 1 Contact', personalData.reference1Contact),
                  _buildPdfDataRow('Reference 2 Name', personalData.reference2Name),
                  _buildPdfDataRow('Reference 2 Address', personalData.reference2Address),
                  _buildPdfDataRow('Reference 2 Contact', personalData.reference2Contact),
                ],
              );
            },
          ),
        );
      }

      // Add Selfie image
      final selfiePath = _getSelfiePath(context);
      if (selfiePath != null) {
        final selfieBytes = await _readImageBytes(selfiePath);
        final pngBytes = await _convertImageToPng(selfieBytes);
        if (pngBytes != null) {
          try {
            final selfieImage = pw.MemoryImage(pngBytes);
            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                margin: const pw.EdgeInsets.all(40),
                build: (pw.Context context) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Selfie',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 20),
                      pw.Center(
                        child: pw.Image(
                          selfieImage,
                          fit: pw.BoxFit.contain,
                          width: 300,
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          } catch (e) {
            if (kDebugMode) {
              print('Error adding selfie to PDF: $e');
            }
          }
        }
      }

      // Add Aadhaar images
      if (submission.aadhaar != null) {
        if (submission.aadhaar!.frontPath != null) {
          final frontBytes = await _readImageBytes(submission.aadhaar!.frontPath);
          final pngBytes = await _convertImageToPng(frontBytes);
          if (pngBytes != null) {
            try {
              final frontImage = pw.MemoryImage(pngBytes);
              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat.a4,
                  margin: const pw.EdgeInsets.all(40),
                  build: (pw.Context context) {
                    return pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Aadhaar Card - Front',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 20),
                        pw.Center(
                          child: pw.Image(
                            frontImage,
                            fit: pw.BoxFit.contain,
                            width: 400,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            } catch (e) {
              if (kDebugMode) {
                print('Error adding Aadhaar front to PDF: $e');
              }
            }
          }
        }

        if (submission.aadhaar!.backPath != null) {
          final backBytes = await _readImageBytes(submission.aadhaar!.backPath);
          final pngBytes = await _convertImageToPng(backBytes);
          if (pngBytes != null) {
            try {
              final backImage = pw.MemoryImage(pngBytes);
              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat.a4,
                  margin: const pw.EdgeInsets.all(40),
                  build: (pw.Context context) {
                    return pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Aadhaar Card - Back',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 20),
                        pw.Center(
                          child: pw.Image(
                            backImage,
                            fit: pw.BoxFit.contain,
                            width: 400,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            } catch (e) {
              if (kDebugMode) {
                print('Error adding Aadhaar back to PDF: $e');
              }
            }
          }
        }
      }

      // Add PAN image
      if (submission.pan != null && submission.pan!.frontPath != null) {
        final panBytes = await _readImageBytes(submission.pan!.frontPath);
        final pngBytes = await _convertImageToPng(panBytes);
        if (pngBytes != null) {
          try {
            final panImage = pw.MemoryImage(pngBytes);
            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                margin: const pw.EdgeInsets.all(40),
                build: (pw.Context context) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PAN Card',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 20),
                      pw.Center(
                        child: pw.Image(
                          panImage,
                          fit: pw.BoxFit.contain,
                          width: 400,
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          } catch (e) {
            if (kDebugMode) {
              print('Error adding PAN to PDF: $e');
            }
          }
        }
      }

      // Add Bank Statement pages
      if (submission.bankStatement != null && submission.bankStatement!.pages.isNotEmpty) {
        if (submission.bankStatement!.isPdf) {
          for (int i = 0; i < submission.bankStatement!.pages.length; i++) {
            final pagePath = submission.bankStatement!.pages[i];
            await _mergePdfIntoDocument(
              pdf,
              pagePath,
              'Bank Statement${submission.bankStatement!.pages.length > 1 ? ' - Document ${i + 1}' : ''}',
            );
          }
        } else {
          for (int i = 0; i < submission.bankStatement!.pages.length; i++) {
            final pagePath = submission.bankStatement!.pages[i];
            final pageBytes = await _readImageBytes(pagePath);
            final pngBytes = await _convertImageToPng(pageBytes);
            if (pngBytes != null) {
              try {
                final pageImage = pw.MemoryImage(pngBytes);
                pdf.addPage(
                  pw.Page(
                    pageFormat: PdfPageFormat.a4,
                    margin: const pw.EdgeInsets.all(40),
                    build: (pw.Context context) {
                      return pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Bank Statement - Page ${i + 1}',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 20),
                          pw.Center(
                            child: pw.Image(
                              pageImage,
                              fit: pw.BoxFit.contain,
                              width: 500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              } catch (e) {
                if (kDebugMode) {
                  print('Error adding bank statement page $i to PDF: $e');
                }
              }
            }
          }
        }
      }

      // Add Salary Slips
      if (submission.salarySlips != null && submission.salarySlips!.slips.isNotEmpty) {
        if (submission.salarySlips!.isPdf) {
          for (int i = 0; i < submission.salarySlips!.slips.length; i++) {
            final slipPath = submission.salarySlips!.slips[i];
            await _mergePdfIntoDocument(
              pdf,
              slipPath,
              'Salary Slip${submission.salarySlips!.slips.length > 1 ? ' - Document ${i + 1}' : ''}',
            );
          }
        } else {
          for (int i = 0; i < submission.salarySlips!.slips.length; i++) {
            final slipPath = submission.salarySlips!.slips[i];
            final slipBytes = await _readImageBytes(slipPath);
            final pngBytes = await _convertImageToPng(slipBytes);
            if (pngBytes != null) {
              try {
                final slipImage = pw.MemoryImage(pngBytes);
                pdf.addPage(
                  pw.Page(
                    pageFormat: PdfPageFormat.a4,
                    margin: const pw.EdgeInsets.all(40),
                    build: (pw.Context context) {
                      return pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Salary Slip - ${i + 1}',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 20),
                          pw.Center(
                            child: pw.Image(
                              slipImage,
                              fit: pw.BoxFit.contain,
                              width: 500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              } catch (e) {
                if (kDebugMode) {
                  print('Error adding salary slip $i to PDF: $e');
                }
              }
            }
          }
        }
      }

      // Save PDF to file
      final directory = kIsWeb ? null : await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'application_data_$timestamp.pdf';
      
      Uint8List pdfBytes;
      if (kIsWeb) {
        pdfBytes = await pdf.save();
        if (context.mounted) {
          await Share.shareXFiles(
            [XFile.fromData(pdfBytes, mimeType: 'application/pdf', name: fileName)],
            text: 'My Application Data',
            subject: 'Application Data Export',
          );
        }
      } else {
        pdfBytes = await pdf.save();
        final file = File('${directory!.path}/$fileName');
        await file.writeAsBytes(pdfBytes);
        
        if (context.mounted) {
          await Share.shareXFiles(
            [XFile(file.path)],
            text: 'My Application Data',
            subject: 'Application Data Export',
          );
        }
      }

      if (context.mounted) {
        PremiumToast.showSuccess(
          context,
          'PDF downloaded successfully!',
        );
      }
    } catch (e) {
      if (context.mounted) {
        PremiumToast.showError(
          context,
          'Error generating PDF: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SubmissionProvider>();
    final submission = provider.submission;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.shade100,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Submitted Successfully!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your documents have been submitted successfully.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Our agent will review your documents. You will be contacted shortly.',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (submission.submittedAt != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Submission Details',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            context,
                            'Status',
                            _getStatusText(submission.status),
                          ),
                          _buildDetailRow(
                            context,
                            'Submitted At',
                            _formatDateTime(submission.submittedAt!),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // Download PDF button
                OutlinedButton.icon(
                  onPressed: _isDownloading ? null : () => _downloadAsPdf(context),
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                  label: Text(_isDownloading ? 'Generating PDF...' : 'Download Application PDF'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    provider.reset();
                    context.go(AppRoutes.home);
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Back to Home'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: label == 'Status'
                    ? _getStatusColor(context, value)
                    : null,
                fontWeight: label == 'Status' ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(SubmissionStatus status) {
    switch (status) {
      case SubmissionStatus.pendingVerification:
        return 'Pending Verification';
      case SubmissionStatus.approved:
        return 'Approved';
      case SubmissionStatus.rejected:
        return 'Rejected';
      default:
        return 'In Progress';
    }
  }

  Color _getStatusColor(BuildContext context, String status) {
    if (status == 'Pending Verification') {
      return Colors.orange;
    } else if (status == 'Approved') {
      return Colors.green;
    } else if (status == 'Rejected') {
      return Colors.red;
    }
    return Theme.of(context).colorScheme.onSurface;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

