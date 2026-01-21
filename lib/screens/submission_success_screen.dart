import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/submission_provider.dart';
import '../providers/application_provider.dart';
import '../services/pdf_generation_service.dart';
import '../widgets/premium_toast.dart';
import '../utils/app_routes.dart';
import '../models/document_submission.dart';

class SubmissionSuccessScreen extends StatefulWidget {
  const SubmissionSuccessScreen({super.key});

  @override
  State<SubmissionSuccessScreen> createState() => _SubmissionSuccessScreenState();
}

class _SubmissionSuccessScreenState extends State<SubmissionSuccessScreen> {
  final PdfGenerationService _pdfService = PdfGenerationService();
  bool _isGeneratingPdf = false;

  Future<void> _generatePdf() async {
    if (_isGeneratingPdf) return;

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      final submissionProvider = context.read<SubmissionProvider>();
      final applicationProvider = context.read<ApplicationProvider>();

      // Sync latest data from backend before generating PDF
      // This ensures we have the complete and most recent data
      if (applicationProvider.hasApplication) {
        try {
          // Refresh application data from backend to get the latest saved data
          await applicationProvider.refreshApplication();

          // Sync the backend data to local submission provider
          await _syncBackendDataToLocal(applicationProvider, submissionProvider);
        } catch (e) {
          debugPrint('Submission Success: Failed to sync latest data: $e');
          // Continue with local data if sync fails
        }
      }

      await _pdfService.generateApplicationPdf(
        context: context,
        submissionProvider: submissionProvider,
        applicationProvider: applicationProvider,
        useSampleData: false, // Use real data for submitted applications
      );

      if (mounted) {
        PremiumToast.showSuccess(
          context,
          'PDF generated and downloaded successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to generate PDF';
        final errorStr = e.toString().toLowerCase();

        // Provide user-friendly error messages
        if (errorStr.contains('isolate') || errorStr.contains('spawn')) {
          errorMessage = 'PDF generation encountered a system error. Please try again or restart the app.';
        } else if (errorStr.contains('permission') || errorStr.contains('access')) {
          errorMessage = 'Permission denied. Please grant storage permissions and try again.';
        } else if (errorStr.contains('network') || errorStr.contains('connection')) {
          errorMessage = 'Network error. Please check your connection and try again.';
        } else {
          errorMessage = 'Failed to generate PDF: ${e.toString().replaceFirst('Exception: ', '')}';
        }

        PremiumToast.showError(
          context,
          errorMessage,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  /// Sync backend data to local submission provider
  /// This ensures PDF generation uses the most complete and up-to-date data
  Future<void> _syncBackendDataToLocal(
    ApplicationProvider appProvider,
    SubmissionProvider submissionProvider,
  ) async {
    final application = appProvider.currentApplication;
    if (application == null) return;

    // Helper function to build full URL from relative path
    String? buildFullUrl(String? relativePath) {
      if (relativePath == null || relativePath.isEmpty) return null;
      // If it's already a full URL or blob URL, return as-is
      if (relativePath.startsWith('http') || relativePath.startsWith('blob:')) {
        return relativePath;
      }
      // Convert /uploads/selfies/... to /api/v1/uploads/files/selfies/...
      String apiPath = relativePath;
      if (apiPath.startsWith('/uploads/') &&
          !apiPath.contains('/uploads/files/')) {
        apiPath = apiPath.replaceFirst('/uploads/', '/api/v1/uploads/files/');
      } else if (!apiPath.startsWith('/api/')) {
        apiPath = '/api/v1$apiPath';
      }
      return 'http://localhost:5000$apiPath';
    }

    // Sync selfie data
    if (application.step1Selfie != null) {
      final stepData = application.step1Selfie as Map<String, dynamic>;
      final imagePath = stepData['imagePath'] as String?;
      final uploadedFile = stepData['uploadedFile'] as Map<String, dynamic>?;
      // Prefer uploaded file URL over local path
      final relativeUrl = uploadedFile?['url'] as String?;
      final effectivePath = buildFullUrl(relativeUrl) ?? imagePath;
      if (effectivePath != null && effectivePath.isNotEmpty) {
        submissionProvider.setSelfie(effectivePath);
      }
    }

    // Sync Aadhaar data
    if (application.step2Aadhaar != null) {
      final stepData = application.step2Aadhaar as Map<String, dynamic>;
      final frontPath = stepData['frontPath'] as String?;
      final backPath = stepData['backPath'] as String?;
      final frontUpload = stepData['frontUpload'] as Map<String, dynamic>?;
      final backUpload = stepData['backUpload'] as Map<String, dynamic>?;
      // Prefer uploaded file URLs
      final effectiveFront =
          buildFullUrl(frontUpload?['url'] as String?) ?? frontPath;
      final effectiveBack =
          buildFullUrl(backUpload?['url'] as String?) ?? backPath;
      if (effectiveFront != null && effectiveFront.isNotEmpty) {
        submissionProvider.setAadhaarFront(effectiveFront);
      }
      if (effectiveBack != null && effectiveBack.isNotEmpty) {
        submissionProvider.setAadhaarBack(effectiveBack);
      }
    }

    // Sync PAN data
    if (application.step3Pan != null) {
      final stepData = application.step3Pan as Map<String, dynamic>;
      final frontPath = stepData['frontPath'] as String?;
      // PAN uses 'uploadedFile' not 'frontUpload'
      final uploadedFile = stepData['uploadedFile'] as Map<String, dynamic>?;
      final effectiveFront =
          buildFullUrl(uploadedFile?['url'] as String?) ?? frontPath;
      if (effectiveFront != null && effectiveFront.isNotEmpty) {
        submissionProvider.setPanFront(effectiveFront);
      }
    }

    // Sync Bank Statement and Salary Slips data
    if (application.step4BankStatement != null) {
      final stepData = application.step4BankStatement as Map<String, dynamic>;

      // Bank Statement pages
      final pages = (stepData['pages'] as List<dynamic>?)?.cast<String>() ?? [];
      final isPdf = stepData['isPdf'] as bool? ?? false;
      final uploadedPages = stepData['uploadedPages'] as List<dynamic>?;
      List<String> effectivePages = [];
      if (uploadedPages != null && uploadedPages.isNotEmpty) {
        for (var upload in uploadedPages) {
          if (upload is Map<String, dynamic>) {
            final url = buildFullUrl(upload['url'] as String?);
            if (url != null && url.isNotEmpty) {
              effectivePages.add(url);
            }
          }
        }
      }
      if (effectivePages.isEmpty && pages.isNotEmpty) {
        effectivePages = pages;
      }
      if (effectivePages.isNotEmpty) {
        submissionProvider.setBankStatementPages(effectivePages, isPdf: isPdf);
      }
      final password = stepData['pdfPassword'] as String?;
      if (password != null && password.isNotEmpty) {
        submissionProvider.setBankStatementPassword(password);
      }

      // Salary slips are also stored in step4BankStatement
      final salarySlips =
          (stepData['salarySlips'] as List<dynamic>?)?.cast<String>() ?? [];
      final salaryIsPdf = stepData['salarySlipsIsPdf'] as bool? ?? false;
      final uploadedSalarySlips =
          stepData['salarySlipsUploaded'] as List<dynamic>?;
      List<String> effectiveSalarySlips = [];
      if (uploadedSalarySlips != null && uploadedSalarySlips.isNotEmpty) {
        for (var upload in uploadedSalarySlips) {
          if (upload is Map<String, dynamic>) {
            final url = buildFullUrl(upload['url'] as String?);
            if (url != null && url.isNotEmpty) {
              effectiveSalarySlips.add(url);
            }
          }
        }
      }
      if (effectiveSalarySlips.isEmpty && salarySlips.isNotEmpty) {
        effectiveSalarySlips = salarySlips;
      }
      if (effectiveSalarySlips.isNotEmpty) {
        submissionProvider.setSalarySlips(
          effectiveSalarySlips,
          isPdf: salaryIsPdf,
        );
      }
      final salaryPassword = stepData['salarySlipsPassword'] as String?;
      if (salaryPassword != null && salaryPassword.isNotEmpty) {
        submissionProvider.setSalarySlipsPassword(salaryPassword);
      }
    }

    // Sync Personal Data
    if (application.step5PersonalData != null) {
      final stepData = application.step5PersonalData as Map<String, dynamic>;
      final personalData = PersonalData(
        nameAsPerAadhaar: stepData['nameAsPerAadhaar'] as String?,
        dateOfBirth: stepData['dateOfBirth'] != null
            ? DateTime.tryParse(stepData['dateOfBirth'] as String)
            : null,
        panNo: stepData['panNo'] as String?,
        mobileNumber: stepData['mobileNumber'] as String?,
        personalEmailId: stepData['personalEmailId'] as String?,
        countryOfResidence: stepData['countryOfResidence'] as String?,
        residenceAddress: stepData['residenceAddress'] as String?,
        residenceType: stepData['residenceType'] as String?,
        residenceStability: stepData['residenceStability'] as String?,
        companyName: stepData['companyName'] as String?,
        companyAddress: stepData['companyAddress'] as String?,
        nationality: stepData['nationality'] as String?,
        countryOfBirth: stepData['countryOfBirth'] as String?,
        occupation: stepData['occupation'] as String?,
        educationalQualification:
            stepData['educationalQualification'] as String?,
        workType: stepData['workType'] as String?,
        industry: stepData['industry'] as String?,
        annualIncome: stepData['annualIncome'] as String?,
        totalWorkExperience: stepData['totalWorkExperience'] as String?,
        currentCompanyExperience:
            stepData['currentCompanyExperience'] as String?,
        loanAmount: stepData['loanAmount'] as String?,
        loanTenure: stepData['loanTenure'] as String?,
        loanAmountTenure: stepData['loanAmountTenure'] as String?,
        maritalStatus: stepData['maritalStatus'] as String?,
        spouseName: stepData['spouseName'] as String?,
        fatherName: stepData['fatherName'] as String?,
        motherName: stepData['motherName'] as String?,
        reference1Name: stepData['reference1Name'] as String?,
        reference1Address: stepData['reference1Address'] as String?,
        reference1Contact: stepData['reference1Contact'] as String?,
        reference2Name: stepData['reference2Name'] as String?,
        reference2Address: stepData['reference2Address'] as String?,
        reference2Contact: stepData['reference2Contact'] as String?,
      );
      submissionProvider.setPersonalData(personalData);
    }

    if (kDebugMode) {
      print('📥 Submission Success: Synced latest backend data to local state');
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
                  onPressed: _isGeneratingPdf ? null : _generatePdf,
                  icon: _isGeneratingPdf
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(_isGeneratingPdf ? 'Generating PDF...' : 'Download Application PDF'),
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

