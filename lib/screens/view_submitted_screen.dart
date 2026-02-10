import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/application_provider.dart';
import '../providers/submission_provider.dart';
import '../services/pdf_generation_service.dart';
import '../utils/app_routes.dart';
import '../widgets/premium_toast.dart';

/// Classic, clean screen for viewing a submitted application.
/// White background, royal blue accents. Shows application data, Download and Close.
class ViewSubmittedScreen extends StatefulWidget {
  const ViewSubmittedScreen({super.key});

  @override
  State<ViewSubmittedScreen> createState() => _ViewSubmittedScreenState();
}

class _ViewSubmittedScreenState extends State<ViewSubmittedScreen> {
  static const Color _royalBlue = Color(0xFF002366);
  bool _isDownloading = false;

  Future<void> _downloadPdf() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final submissionProvider = context.read<SubmissionProvider>();
      final applicationProvider = context.read<ApplicationProvider>();
      await PdfGenerationService().generateApplicationPdf(
        context: context,
        submissionProvider: submissionProvider,
        applicationProvider: applicationProvider,
        useSampleData: false,
      );
      if (context.mounted) {
        PremiumToast.showSuccess(
          context,
          'PDF generated and ready to download!',
        );
      }
    } catch (e) {
      if (context.mounted) {
        PremiumToast.showError(
          context,
          'Failed to generate PDF: ${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Widget _dataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                color: _royalBlue,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: _royalBlue,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<ApplicationProvider>().currentApplication;
    final submission = context.watch<SubmissionProvider>().submission;
    final applicationId = app?.applicationId ?? '—';
    final status = app?.status ?? 'submitted';
    final loanType = app?.loanType ?? '—';
    final submittedAt = app?.submittedAt ?? submission.submittedAt;
    final pd = submission.personalData;
    final businessDocs = submission.businessDocuments;
    final isBusinessLoan = loanType.toLowerCase().contains('business');
    final businessLoanType = (submission.businessLoanType ?? '').toLowerCase();
    final hasPartners = businessDocs?.hasPartners ?? false;
    final isBusinessProprietor = isBusinessLoan &&
        (businessLoanType == 'proprietor' ||
            (businessLoanType.isEmpty && businessDocs?.spousePan != null));
    final isBusinessPartnership = isBusinessLoan &&
        (businessLoanType == 'partnership' ||
            businessLoanType == 'pvt_limited' ||
            (businessLoanType.isEmpty && hasPartners));
    final isBusinessPvtLimited = isBusinessLoan && businessLoanType == 'pvt_limited';

    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final dobFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _royalBlue),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Text(
          'Submitted Application',
          style: TextStyle(
            color: _royalBlue,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    // Application summary
                    _sectionTitle('Application'),
                    _dataRow('Application ID', applicationId),
                    _dataRow('Loan Type', loanType),
                    _dataRow('Status', status.toUpperCase()),
                    if (submittedAt != null)
                      _dataRow('Submitted', dateFormat.format(submittedAt)),
                    // Personal data
                    _sectionTitle('Personal Data'),
                    _dataRow('Name', pd?.nameAsPerAadhaar ?? ''),
                    _dataRow(
                      'Date of Birth',
                      pd?.dateOfBirth != null
                          ? dobFormat.format(pd!.dateOfBirth!)
                          : '',
                    ),
                    _dataRow('PAN', pd?.panNo ?? ''),
                    _dataRow('Aadhaar', pd?.aadhaarNumber ?? ''),
                    _dataRow('Mobile', pd?.mobileNumber ?? ''),
                    _dataRow('Email', pd?.personalEmailId ?? ''),
                    _dataRow('Address', pd?.residenceAddress ?? ''),
                    if ((pd?.companyName ?? '').isNotEmpty)
                      _dataRow('Company', pd?.companyName ?? ''),
                    if ((pd?.occupation ?? '').isNotEmpty)
                      _dataRow('Occupation', pd?.occupation ?? ''),
                    if ((pd?.annualIncome ?? '').isNotEmpty)
                      _dataRow('Annual Income', pd?.annualIncome ?? ''),
                    if ((pd?.loanAmount ?? '').isNotEmpty)
                      _dataRow('Loan Amount', pd?.loanAmount ?? ''),
                    // Documents summary
                    _sectionTitle('Documents'),
                    _dataRow(
                      'Selfie',
                      submission.selfiePath != null ? 'Uploaded' : '—',
                    ),
                    _dataRow(
                      'Aadhaar',
                      submission.aadhaar?.isComplete == true
                          ? 'Uploaded'
                          : '—',
                    ),
                    _dataRow(
                      'PAN Card',
                      submission.pan?.isComplete == true ? 'Uploaded' : '—',
                    ),
                    _dataRow(
                      'Bank Statement',
                      submission.bankStatement?.isComplete == true
                          ? '${submission.bankStatement!.pages.length} page(s)'
                          : '—',
                    ),
                    _dataRow(
                      'Salary Slips',
                      (isBusinessProprietor || isBusinessPartnership)
                          ? 'Not required (Business Loan)'
                          : (submission.salarySlips?.isComplete == true
                              ? '${submission.salarySlips!.uploadedCount} slip(s)'
                              : '—'),
                    ),
                    if (isBusinessProprietor) ...[
                      _sectionTitle('Business Documents'),
                      _dataRow(
                        'Spouse Aadhaar',
                        businessDocs?.spouseAadhaar?.isComplete == true ? 'Uploaded' : '—',
                      ),
                      _dataRow(
                        'Spouse PAN',
                        businessDocs?.spousePan?.isComplete == true ? 'Uploaded' : '—',
                      ),
                      _dataRow(
                        'GST / Labour',
                        (businessDocs?.hasGstOrLabour ?? false) ? 'Uploaded' : '—',
                      ),
                      _dataRow(
                        'MSME',
                        businessDocs?.msmeCertificate?.isComplete == true ? 'Uploaded' : '—',
                      ),
                      _dataRow(
                        'Own House Proof',
                        businessDocs?.ownHouseProof?.isComplete == true ? 'Uploaded' : '—',
                      ),
                    ],
                    if (isBusinessPartnership) ...[
                      _sectionTitle('Partners / Business Documents'),
                      _dataRow(
                        'Partners',
                        (businessDocs?.partnerCount ?? 0) > 0
                            ? '${businessDocs!.partnerCount} partner(s)'
                            : (hasPartners ? '${businessDocs!.partners.length} partner(s)' : '—'),
                      ),
                      _dataRow(
                        'Partners KYC',
                        (businessDocs?.isPartnerKycComplete ?? false) ? 'Completed' : '—',
                      ),
                      _dataRow(
                        'Company PAN Card',
                        businessDocs?.companyPanCard?.isComplete == true ? 'Uploaded' : '—',
                      ),
                      if (isBusinessPvtLimited) ...[
                        _dataRow(
                          'MOA',
                          businessDocs?.moa?.isComplete == true ? 'Uploaded' : '—',
                        ),
                        _dataRow(
                          'AOA',
                          businessDocs?.aoa?.isComplete == true ? 'Uploaded' : '—',
                        ),
                      ] else
                        _dataRow(
                          'Partnership Deed',
                          businessDocs?.partnershipDeed?.isComplete == true ? 'Uploaded' : '—',
                        ),
                      _dataRow(
                        'GST / Labour',
                        (businessDocs?.hasGstOrLabour ?? false) ? 'Uploaded' : '—',
                      ),
                      _dataRow(
                        'MSME',
                        businessDocs?.msmeCertificate?.isComplete == true ? 'Uploaded' : '—',
                      ),
                      _dataRow(
                        'Own House Proof',
                        businessDocs?.ownHouseProof?.isComplete == true ? 'Uploaded' : '—',
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isDownloading ? null : _downloadPdf,
                      icon: _isDownloading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download, size: 20),
                      label: Text(
                        _isDownloading ? 'Generating...' : 'Download',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _royalBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => context.go(AppRoutes.home),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _royalBlue,
                        side: const BorderSide(color: _royalBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
