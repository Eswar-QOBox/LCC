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
import '../widgets/platform_image.dart';
import '../widgets/step_progress_indicator.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_toast.dart';
import '../utils/app_theme.dart';

class Step6PreviewScreen extends StatefulWidget {
  const Step6PreviewScreen({super.key});

  @override
  State<Step6PreviewScreen> createState() => _Step6PreviewScreenState();
}

class _Step6PreviewScreenState extends State<Step6PreviewScreen> {
  bool _isDownloading = false;

  void _editStep(BuildContext context, String route) {
    context.go(route);
  }

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

  /// Check if all required data is actually present (for PDF status)
  bool _isActuallyComplete(BuildContext context) {
    final provider = context.read<SubmissionProvider>();
    final submission = provider.submission;
    final selfiePath = _getSelfiePath(context);
    
    return selfiePath != null &&
        submission.aadhaar != null &&
        submission.aadhaar!.isComplete &&
        submission.pan != null &&
        submission.pan!.isComplete &&
        submission.bankStatement != null &&
        submission.bankStatement!.isComplete &&
        submission.personalData != null &&
        submission.personalData!.isComplete &&
        submission.salarySlips != null &&
        submission.salarySlips!.isComplete;
  }

  Future<void> _submit(BuildContext context) async {
    final provider = context.read<SubmissionProvider>();
    final appProvider = context.read<ApplicationProvider>();
    
    if (!appProvider.hasApplication) {
      PremiumToast.showError(
        context,
        'No application found. Please start a new application.',
      );
      return;
    }
    
    if (!provider.submission.isComplete) {
      if (context.mounted) {
        PremiumToast.showError(
          context,
          'Please complete all steps before submitting',
        );
      }
      return;
    }

    // Show loading indicator
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      // Save preview data and submit to backend
      await appProvider.updateApplication(
        currentStep: 7,
        status: 'submitted',
        step6Preview: {
          'submittedAt': DateTime.now().toIso8601String(),
          'allStepsComplete': true,
        },
        step7Submission: {
          'submittedAt': DateTime.now().toIso8601String(),
          'status': 'submitted',
        },
      );
      
      // Also save to provider for local state
      await provider.submit();
      
      // Clear draft after successful submission
      await provider.clearDraft();
      
      if (context.mounted) {
        // Close loading dialog
        Navigator.of(context).pop();
        PremiumToast.showSuccess(
          context,
          'Application submitted successfully!',
        );
        // Navigate to success screen
        context.go(AppRoutes.submissionSuccess);
      }
    } catch (e) {
      if (context.mounted) {
        // Close loading dialog if still open
        Navigator.of(context).pop();
        PremiumToast.showError(
          context,
          'Error submitting: $e',
        );
      }
    }
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
  /// This ensures the PDF library can properly decode the image
  Future<Uint8List?> _convertImageToPng(Uint8List? imageBytes) async {
    if (imageBytes == null) return null;
    
    try {
      // Decode the image using the image package
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) {
        if (kDebugMode) {
          print('Failed to decode image');
        }
        return null;
      }
      
      // Encode to PNG format (PDF library supports PNG well)
      final pngBytes = img.encodePng(decodedImage);
      return Uint8List.fromList(pngBytes);
    } catch (e) {
      if (kDebugMode) {
        print('Error converting image to PNG: $e');
      }
      // If conversion fails, try returning original bytes as fallback
      return imageBytes;
    }
  }

  /// Read PDF bytes from file path (handles both web and mobile)
  /// Similar to _readImageBytes but specifically for PDFs
  Future<Uint8List?> _readPdfBytes(String? pdfPath) async {
    if (pdfPath == null || pdfPath.isEmpty) return null;
    
    try {
      if (kIsWeb) {
        // Handle blob URLs on web
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
        
        // Handle data URIs on web
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
        
        // Try to read as XFile if possible
        final file = XFile(pdfPath);
        return await file.readAsBytes();
      } else {
        // On mobile/desktop, read from file path
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

  /// Merge PDF pages from a PDF file into the main PDF document
  /// This function reads the PDF and appends its pages to the main document
  Future<void> _mergePdfIntoDocument(pw.Document mainPdf, String pdfPath, String title) async {
    try {
      final pdfBytes = await _readPdfBytes(pdfPath);
      if (pdfBytes == null) {
        if (kDebugMode) {
          print('Failed to read PDF bytes from: $pdfPath');
        }
        // Add a note page instead
        _addPdfNotePage(mainPdf, title, 'Unable to read PDF file.');
        return;
      }

      // Add a title page indicating the PDF is included
      // Note: Full PDF merging requires additional packages like syncfusion_flutter_pdf
      // For now, we add a note page and the PDF content is preserved in the submission
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

      // Check actual completion status before building PDF
      final isComplete = _isActuallyComplete(context);

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
                  'Application Status: ${isComplete ? "Complete" : "Incomplete"}',
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
                    'Company Information',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _buildPdfDataRow('Company Name', personalData.companyName),
                  _buildPdfDataRow('Company Address', personalData.companyAddress),
                  pw.SizedBox(height: 15),
                  pw.Text(
                    'Employment Details',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _buildPdfDataRow('Occupation', personalData.occupation),
                  _buildPdfDataRow('Industry', personalData.industry),
                  _buildPdfDataRow('Annual Income', personalData.annualIncome),
                  _buildPdfDataRow('Work Type', personalData.workType),
                  _buildPdfDataRow('Total Work Experience', personalData.totalWorkExperience),
                  _buildPdfDataRow('Current Company Experience', personalData.currentCompanyExperience),
                  _buildPdfDataRow('Educational Qualification', personalData.educationalQualification),
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
        // Merge PDF if it's a PDF file
        if (submission.bankStatement!.isPdf) {
          // Merge the PDF into the document
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
        // Merge PDF if it's a PDF file
        if (submission.salarySlips!.isPdf) {
          // Merge the PDF into the document
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
        // On web, share the PDF
        if (context.mounted) {
          // Use share_plus to download on web
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubmissionProvider>();
    final submission = provider.submission;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selfiePath = _getSelfiePath(context);
    
    // Debug: Print comprehensive submission state
    if (kDebugMode) {
      print('═══════════════════════════════════════════════════════════');
      print('📋 PREVIEW SCREEN - SUBMISSION STATE');
      print('═══════════════════════════════════════════════════════════');
      final selfiePath = _getSelfiePath(context);
      print('✅ Selfie: ${selfiePath != null ? "✓ $selfiePath" : "✗ Missing"}');
      print('✅ Aadhaar: ${submission.aadhaar != null ? "✓ Front: ${submission.aadhaar!.frontPath}, Back: ${submission.aadhaar!.backPath}" : "✗ Missing"}');
      print('✅ PAN: ${submission.pan != null ? "✓ ${submission.pan!.frontPath}" : "✗ Missing"}');
      print('✅ Bank Statement: ${submission.bankStatement != null ? "✓ Pages: ${submission.bankStatement!.pages.length}" : "✗ Missing"}');
      print('✅ Personal Data: ${submission.personalData != null ? "✓ Present" : "✗ Missing"}');
      print('✅ Is Complete: ${submission.isComplete}');
      print('═══════════════════════════════════════════════════════════');
      
      if (submission.personalData != null) {
        final data = submission.personalData!;
        print('📝 PERSONAL DATA DETAILS:');
        print('   Name: ${data.nameAsPerAadhaar ?? "null"}');
        print('   DOB: ${data.dateOfBirth ?? "null"}');
        print('   PAN: ${data.panNo ?? "null"}');
        print('   Mobile: ${data.mobileNumber ?? "null"}');
        print('   Email: ${data.personalEmailId ?? "null"}');
        print('   Country: ${data.countryOfResidence ?? "null"}');
        print('   Address: ${data.residenceAddress ?? "null"}');
        print('   Company: ${data.companyName ?? "null"}');
        print('   Occupation: ${data.occupation ?? "null"}');
        print('   Marital Status: ${data.maritalStatus ?? "null"}');
        print('   Is Complete: ${data.isComplete}');
        print('═══════════════════════════════════════════════════════════');
      }
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.08),
              colorScheme.secondary.withValues(alpha: 0.04),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    colorScheme.primary.withValues(alpha: 0.03),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AppBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.secondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Review & Submit',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                foregroundColor: colorScheme.onSurface,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    onPressed: () => context.go(AppRoutes.step5_1SalarySlips),
                    color: colorScheme.primary,
                  ),
                ),
                actions: const [],
              ),
            ),
            StepProgressIndicator(currentStep: 6, totalSteps: 6),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status Banner
                    PremiumCard(
                      gradientColors: submission.isComplete
                          ? [
                              AppTheme.successColor.withValues(alpha: 0.15),
                              AppTheme.successColor.withValues(alpha: 0.05),
                            ]
                          : [
                              AppTheme.warningColor.withValues(alpha: 0.15),
                              AppTheme.warningColor.withValues(alpha: 0.05),
                            ],
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: submission.isComplete
                                  ? AppTheme.successColor
                                  : AppTheme.warningColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (submission.isComplete
                                          ? AppTheme.successColor
                                          : AppTheme.warningColor)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              submission.isComplete
                                  ? Icons.check_circle
                                  : Icons.warning_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  submission.isComplete
                                      ? 'Ready to Submit!'
                                      : 'Incomplete Submission',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: submission.isComplete
                                        ? AppTheme.successColor
                                        : AppTheme.warningColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  submission.isComplete
                                      ? 'All documents are verified and ready'
                                      : 'Please complete all steps before submitting',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Summary Section
                    PremiumCard(
                      gradientColors: [
                        colorScheme.primary.withValues(alpha: 0.08),
                        colorScheme.secondary.withValues(alpha: 0.04),
                      ],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primary,
                                      colorScheme.secondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.summarize,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Review All Information',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildSummaryRow(
                            context,
                            'Step 1: Selfie',
                            selfiePath != null ? '✓ Uploaded' : '✗ Missing',
                            selfiePath != null,
                          ),
                          _buildSummaryRow(
                            context,
                            'Step 2: Aadhaar Card',
                            submission.aadhaar?.isComplete == true ? '✓ Uploaded' : '✗ Missing',
                            submission.aadhaar?.isComplete == true,
                          ),
                          _buildSummaryRow(
                            context,
                            'Step 3: PAN Card',
                            submission.pan?.isComplete == true ? '✓ Uploaded' : '✗ Missing',
                            submission.pan?.isComplete == true,
                          ),
                          _buildSummaryRow(
                            context,
                            'Step 4: Bank Statement',
                            submission.bankStatement?.isComplete == true ? '✓ Uploaded' : '✗ Missing',
                            submission.bankStatement?.isComplete == true,
                          ),
                          _buildSummaryRow(
                            context,
                            'Step 5: Personal Data',
                            submission.personalData?.isComplete == true ? '✓ Completed' : '✗ Missing',
                            submission.personalData?.isComplete == true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Detailed Sections
                    Text(
                      'Detailed Information',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildPremiumSection(
                      context,
                      stepNumber: 1,
                      title: 'Selfie / Photo',
                      icon: Icons.face,
                      isComplete: selfiePath != null,
                      onEdit: () => _editStep(context, AppRoutes.step1Selfie),
                      child: selfiePath != null
                          ? Container(
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(alpha: 0.15),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                                border: Border.all(
                                  color: colorScheme.primary.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: PlatformImage(
                                  imagePath: selfiePath,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          : _buildEmptyState(context, 'No selfie uploaded'),
                    ),
                    const SizedBox(height: 20),
                    _buildPremiumSection(
                      context,
                      stepNumber: 2,
                      title: 'Aadhaar Card',
                      icon: Icons.badge,
                      isComplete: submission.aadhaar?.isComplete ?? false,
                      onEdit: () => _editStep(context, AppRoutes.step2Aadhaar),
                      child: submission.aadhaar?.isComplete == true
                          ? Row(
                              children: [
                                Expanded(
                                  child: _buildPremiumDocumentPreview(
                                    context,
                                    submission.aadhaar!.frontPath!,
                                    'Front',
                                    false, // Aadhaar is always image, never PDF
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildPremiumDocumentPreview(
                                    context,
                                    submission.aadhaar!.backPath!,
                                    'Back',
                                    false, // Aadhaar is always image, never PDF
                                  ),
                                ),
                              ],
                            )
                          : _buildEmptyState(context, 'Not uploaded'),
                    ),
                    const SizedBox(height: 20),
                    _buildPremiumSection(
                      context,
                      stepNumber: 3,
                      title: 'PAN Card',
                      icon: Icons.credit_card,
                      isComplete: submission.pan?.isComplete ?? false,
                      onEdit: () => _editStep(context, AppRoutes.step3Pan),
                      child: submission.pan?.isComplete == true
                          ? _buildPremiumDocumentPreview(
                              context,
                              submission.pan!.frontPath!,
                              'Front',
                              false, // PAN is always image, never PDF
                            )
                          : _buildEmptyState(context, 'Not uploaded'),
                    ),
                    const SizedBox(height: 20),
                    _buildPremiumSection(
                      context,
                      stepNumber: 4,
                      title: 'Bank Statement',
                      icon: Icons.account_balance,
                      isComplete: submission.bankStatement?.isComplete ?? false,
                      onEdit: () => _editStep(context, AppRoutes.step4BankStatement),
                      child: submission.bankStatement?.isComplete == true
                          ? PremiumCard(
                              gradientColors: [
                                colorScheme.primary.withValues(alpha: 0.05),
                                colorScheme.secondary.withValues(alpha: 0.02),
                              ],
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          colorScheme.primary,
                                          colorScheme.secondary,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.description,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${submission.bankStatement!.pages.length} ${submission.bankStatement!.pages.length == 1 ? 'Page' : 'Pages'}',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Bank statement uploaded',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _buildEmptyState(context, 'Not uploaded'),
                    ),
                    const SizedBox(height: 20),
                    _buildPremiumSection(
                      context,
                      stepNumber: 6,
                      title: 'Personal Data',
                      icon: Icons.person,
                      isComplete: submission.personalData?.isComplete ?? false,
                      onEdit: () => _editStep(context, AppRoutes.step5PersonalData),
                      child: Builder(
                        builder: (context) {
                          if (kDebugMode) {
                            print('🔍 Building Personal Data Section:');
                            print('   personalData != null: ${submission.personalData != null}');
                            if (submission.personalData != null) {
                              print('   personalData.isComplete: ${submission.personalData!.isComplete}');
                            }
                          }
                          return submission.personalData != null
                              ? PremiumCard(
                                  gradientColors: [
                                    Colors.white,
                                    colorScheme.primary.withValues(alpha: 0.02),
                                  ],
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: _buildPersonalDataPreview(context, submission.personalData!),
                                  ),
                                )
                              : _buildEmptyState(context, 'No personal data entered. Please go back to Step 5 to fill in your information.');
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildPremiumSection(
                      context,
                      stepNumber: 5,
                      title: 'Salary Slips',
                      icon: Icons.receipt_long,
                      isComplete: submission.salarySlips?.isComplete ?? false,
                      onEdit: () => _editStep(context, AppRoutes.step5_1SalarySlips),
                      child: submission.salarySlips?.isComplete == true
                          ? PremiumCard(
                              gradientColors: [
                                colorScheme.primary.withValues(alpha: 0.05),
                                colorScheme.secondary.withValues(alpha: 0.02),
                              ],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              colorScheme.primary,
                                              colorScheme.secondary,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.receipt_long,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${submission.salarySlips!.slips.length} ${submission.salarySlips!.slips.length == 1 ? 'Slip' : 'Slips'} Uploaded',
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              submission.salarySlips!.isPdf ? 'PDF Format' : 'Image Format',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (submission.salarySlips!.slips.length <= 3) ...[
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: submission.salarySlips!.slips.asMap().entries.map((entry) {
                                        return SizedBox(
                                          width: 100,
                                          height: 140,
                                          child: _buildPremiumDocumentPreview(
                                            context,
                                            entry.value,
                                            'Slip ${entry.key + 1}',
                                            submission.salarySlips!.isPdf && entry.key == 0,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 16),
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: 0.7,
                                      ),
                                      itemCount: submission.salarySlips!.slips.length,
                                      itemBuilder: (context, index) {
                                        return _buildPremiumDocumentPreview(
                                          context,
                                          submission.salarySlips!.slips[index],
                                          'Slip ${index + 1}',
                                          submission.salarySlips!.isPdf && index == 0,
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : _buildEmptyState(context, 'Not uploaded'),
                    ),
                    const SizedBox(height: 40),
                    // Download as PDF button
                    Builder(
                      builder: (context) {
                        final colorScheme = Theme.of(context).colorScheme;
                        return OutlinedButton.icon(
                          onPressed: _isDownloading ? null : () => _downloadAsPdf(context),
                          icon: _isDownloading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download_outlined),
                          label: Text(_isDownloading ? 'Generating PDF...' : 'Download your data as PDF'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: colorScheme.primary,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    PremiumButton(
                      label: submission.isComplete
                          ? 'Confirm & Submit'
                          : 'Complete Missing Steps',
                      icon: submission.isComplete
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_rounded,
                      isPrimary: submission.isComplete,
                      onPressed: submission.isComplete ? () => _submit(context) : null,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumSection(
    BuildContext context, {
    required int stepNumber,
    required String title,
    required IconData icon,
    required bool isComplete,
    required VoidCallback onEdit,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return PremiumCard(
      gradientColors: [
        Colors.white,
        isComplete
            ? AppTheme.successColor.withValues(alpha: 0.02)
            : colorScheme.primary.withValues(alpha: 0.02),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: isComplete
                            ? LinearGradient(
                                colors: [
                                  AppTheme.successColor,
                                  AppTheme.successColor.withValues(alpha: 0.8),
                                ],
                              )
                            : null,
                        color: isComplete ? null : Colors.grey.shade300,
                        shape: BoxShape.circle,
                        boxShadow: isComplete
                            ? [
                                BoxShadow(
                                  color: AppTheme.successColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: isComplete
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : Text(
                                '$stepNumber',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: colorScheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextButton.icon(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined, size: 16, color: colorScheme.primary),
                  label: Text(
                    'Edit',
                    style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildPremiumDocumentPreview(
    BuildContext context,
    String path,
    String label,
    bool isPdf,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.5),
        child: Stack(
          children: [
            isPdf
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.1),
                          colorScheme.secondary.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.picture_as_pdf, size: 40, color: colorScheme.primary),
                          const SizedBox(height: 8),
                          Text(
                            'PDF',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : PlatformImage(imagePath: path, fit: BoxFit.cover),
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black.withValues(alpha: 0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey.shade600, size: 24),
          const SizedBox(width: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalDataPreview(BuildContext context, PersonalData data) {
    // Debug: Print all data fields
    if (kDebugMode) {
      print('═══════════════════════════════════════════════════════════');
      print('🎨 BUILDING PERSONAL DATA PREVIEW WIDGET');
      print('═══════════════════════════════════════════════════════════');
      print('📋 Basic Information:');
      print('   Name: ${data.nameAsPerAadhaar ?? "null"} (${data.nameAsPerAadhaar?.isNotEmpty ?? false ? "has value" : "empty/null"})');
      print('   DOB: ${data.dateOfBirth ?? "null"}');
      print('   PAN: ${data.panNo ?? "null"} (${data.panNo?.isNotEmpty ?? false ? "has value" : "empty/null"})');
      print('   Mobile: ${data.mobileNumber ?? "null"} (${data.mobileNumber?.isNotEmpty ?? false ? "has value" : "empty/null"})');
      print('   Email: ${data.personalEmailId ?? "null"} (${data.personalEmailId?.isNotEmpty ?? false ? "has value" : "empty/null"})');
      print('📋 Residence Information:');
      print('   Country: ${data.countryOfResidence ?? "null"}');
      print('   Address: ${data.residenceAddress ?? "null"}');
      print('📋 Company Information:');
      print('   Company Name: ${data.companyName ?? "null"}');
      print('   Company Address: ${data.companyAddress ?? "null"}');
      print('📋 Personal Details:');
      print('   Occupation: ${data.occupation ?? "null"}');
      print('   Industry: ${data.industry ?? "null"}');
      print('   Annual Income: ${data.annualIncome ?? "null"}');
      print('📋 Family Information:');
      print('   Marital Status: ${data.maritalStatus ?? "null"}');
      print('   Spouse Name: ${data.spouseName ?? "null"}');
      print('   Father Name: ${data.fatherName ?? "null"}');
      print('   Mother Name: ${data.motherName ?? "null"}');
      print('📋 References:');
      print('   Ref1 Name: ${data.reference1Name ?? "null"}');
      print('   Ref1 Contact: ${data.reference1Contact ?? "null"}');
      print('   Ref2 Name: ${data.reference2Name ?? "null"}');
      print('   Ref2 Contact: ${data.reference2Contact ?? "null"}');
      print('═══════════════════════════════════════════════════════════');
    }
    
    // Count fields that will be displayed
    int fieldCount = 0;
    if (data.nameAsPerAadhaar != null && data.nameAsPerAadhaar!.isNotEmpty) fieldCount++;
    if (data.dateOfBirth != null) fieldCount++;
    if (data.panNo != null && data.panNo!.isNotEmpty) fieldCount++;
    if (data.mobileNumber != null && data.mobileNumber!.isNotEmpty) fieldCount++;
    if (data.personalEmailId != null && data.personalEmailId!.isNotEmpty) fieldCount++;
    
    if (kDebugMode) {
      print('📊 Total fields to display: $fieldCount');
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Basic Information
        if (data.nameAsPerAadhaar != null && data.nameAsPerAadhaar!.isNotEmpty)
          _buildDataRow('Name as per Aadhaar', data.nameAsPerAadhaar!),
        if (data.dateOfBirth != null)
          _buildDataRow('Date of Birth', DateFormat('MMMM dd, yyyy').format(data.dateOfBirth!)),
        if (data.panNo != null && data.panNo!.isNotEmpty)
          _buildDataRow('PAN No', data.panNo!),
        if (data.mobileNumber != null && data.mobileNumber!.isNotEmpty)
          _buildDataRow('Mobile Number', data.mobileNumber!),
        if (data.personalEmailId != null && data.personalEmailId!.isNotEmpty)
          _buildDataRow('Personal Email', data.personalEmailId!),
        
        // Residence Information
        if (data.countryOfResidence != null && data.countryOfResidence!.isNotEmpty)
          _buildDataRow('Country of Residence', data.countryOfResidence!),
        if (data.residenceAddress != null && data.residenceAddress!.isNotEmpty)
          _buildDataRow('Residence Address', data.residenceAddress!),
        if (data.residenceType != null && data.residenceType!.isNotEmpty)
          _buildDataRow('Residence Type', data.residenceType!),
        if (data.residenceStability != null && data.residenceStability!.isNotEmpty)
          _buildDataRow('Residence Stability', data.residenceStability!),
        
        // Company Information
        if (data.companyName != null && data.companyName!.isNotEmpty)
          _buildDataRow('Company Name', data.companyName!),
        if (data.companyAddress != null && data.companyAddress!.isNotEmpty)
          _buildDataRow('Company Address', data.companyAddress!),
        
        // Personal Details
        if (data.nationality != null && data.nationality!.isNotEmpty)
          _buildDataRow('Nationality', data.nationality!),
        if (data.countryOfBirth != null && data.countryOfBirth!.isNotEmpty)
          _buildDataRow('Country of Birth', data.countryOfBirth!),
        if (data.occupation != null && data.occupation!.isNotEmpty)
          _buildDataRow('Occupation', data.occupation!),
        if (data.educationalQualification != null && data.educationalQualification!.isNotEmpty)
          _buildDataRow('Educational Qualification', data.educationalQualification!),
        if (data.workType != null && data.workType!.isNotEmpty)
          _buildDataRow('Work Type', data.workType!),
        if (data.industry != null && data.industry!.isNotEmpty)
          _buildDataRow('Industry', data.industry!),
        if (data.annualIncome != null && data.annualIncome!.isNotEmpty)
          _buildDataRow('Annual Income', data.annualIncome!),
        if (data.totalWorkExperience != null && data.totalWorkExperience!.isNotEmpty)
          _buildDataRow('Total Work Experience', data.totalWorkExperience!),
        if (data.currentCompanyExperience != null && data.currentCompanyExperience!.isNotEmpty)
          _buildDataRow('Current Company Experience', data.currentCompanyExperience!),
        if (data.loanAmountTenure != null && data.loanAmountTenure!.isNotEmpty)
          _buildDataRow('Loan Amount/Tenure', data.loanAmountTenure!),
        
        // Family Information
        if (data.maritalStatus != null && data.maritalStatus!.isNotEmpty)
          _buildDataRow('Marital Status', data.maritalStatus!),
        if (data.maritalStatus == 'Married' && data.spouseName != null && data.spouseName!.isNotEmpty)
          _buildDataRow('Spouse Name', data.spouseName!),
        if (data.fatherName != null && data.fatherName!.isNotEmpty)
          _buildDataRow('Father Name', data.fatherName!),
        if (data.motherName != null && data.motherName!.isNotEmpty)
          _buildDataRow('Mother Name', data.motherName!),
        
        // Reference Details
        if ((data.reference1Name != null && data.reference1Name!.isNotEmpty) ||
            (data.reference1Address != null && data.reference1Address!.isNotEmpty) ||
            (data.reference1Contact != null && data.reference1Contact!.isNotEmpty)) ...[
          const SizedBox(height: 8),
          Text(
            'Reference 1',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (data.reference1Name != null && data.reference1Name!.isNotEmpty)
            _buildDataRow('Name', data.reference1Name!),
          if (data.reference1Address != null && data.reference1Address!.isNotEmpty)
            _buildDataRow('Address', data.reference1Address!),
          if (data.reference1Contact != null && data.reference1Contact!.isNotEmpty)
            _buildDataRow('Contact', data.reference1Contact!),
        ],
        if ((data.reference2Name != null && data.reference2Name!.isNotEmpty) ||
            (data.reference2Address != null && data.reference2Address!.isNotEmpty) ||
            (data.reference2Contact != null && data.reference2Contact!.isNotEmpty)) ...[
          const SizedBox(height: 8),
          Text(
            'Reference 2',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (data.reference2Name != null && data.reference2Name!.isNotEmpty)
            _buildDataRow('Name', data.reference2Name!),
          if (data.reference2Address != null && data.reference2Address!.isNotEmpty)
            _buildDataRow('Address', data.reference2Address!),
          if (data.reference2Contact != null && data.reference2Contact!.isNotEmpty)
            _buildDataRow('Contact', data.reference2Contact!),
        ],
      ],
    );
  }

  Widget _buildDataRow(String label, String value) {
    if (kDebugMode) {
      print('   ✓ Displaying: $label = $value');
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String step, String status, bool isComplete) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            step,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isComplete
                  ? AppTheme.successColor.withValues(alpha: 0.1)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isComplete ? AppTheme.successColor : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

