import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_routes.dart';
import '../utils/app_strings.dart';
import '../utils/developer_mode.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_toast.dart';
import '../widgets/slide_to_confirm.dart';
import '../providers/submission_provider.dart';
import '../providers/application_provider.dart';
import '../services/loan_application_service.dart';
import '../models/loan_application.dart';
import '../utils/app_theme.dart';

class InstructionsScreen extends StatefulWidget {
  final String? loanType;
  final String? businessLoanType;
  final String? professionalLoanType;
  final bool withCoApplicant;
  /// Co-applicant firm type for Car Loan: 'partnership' | 'pvt_limited' | null.
  final String? coApplicantFirmType;

  const InstructionsScreen({
    super.key,
    this.loanType,
    this.businessLoanType,
    this.professionalLoanType,
    this.withCoApplicant = false,
    this.coApplicantFirmType,
  });

  @override
  State<InstructionsScreen> createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends State<InstructionsScreen> {
  bool _isCreatingApplication = false;
  final LoanApplicationService _applicationService = LoanApplicationService();

  bool get _isBusinessProprietor {
    final loanType = (widget.loanType ?? '').toLowerCase();
    final businessLoanType = (widget.businessLoanType ?? '').toLowerCase();
    return loanType.contains('business') && businessLoanType == 'proprietor';
  }

  bool get _isProfessionalLoan {
    final loanType = (widget.loanType ?? '').toLowerCase();
    final proType = (widget.professionalLoanType ?? '').toLowerCase();
    return loanType.contains('professional') && (proType == 'doctor' || proType == 'ca');
  }

  bool get _isStudentLoan {
    final loanType = (widget.loanType ?? '').toLowerCase();
    return loanType.contains('student');
  }

  /// Personal loan (includes optional co-applicant / joint application flow).
  bool get _isPersonalLoan {
    final loanType = (widget.loanType ?? '').toLowerCase();
    return loanType.contains('personal') &&
        !_isBusinessProprietor &&
        !_isProfessionalLoan &&
        !_isStudentLoan;
  }

  String get _professionalType => (widget.professionalLoanType ?? '').toLowerCase();
  bool get _isProfessionalDoctor => _professionalType == 'doctor';
  bool get _isProfessionalCa => _professionalType == 'ca';

  bool get _isCarLoan => (widget.loanType ?? '').toLowerCase().contains('car');
  bool get _isCarLoanPartnership =>
      _isCarLoan && widget.coApplicantFirmType == 'partnership';
  bool get _isCarLoanPvtLtd =>
      _isCarLoan && widget.coApplicantFirmType == 'pvt_limited';
  bool get _isCarLoanFirmCoApplicant =>
      _isCarLoanPartnership || _isCarLoanPvtLtd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and logo
            _buildHeader(context),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and subtitle
                    Text(
                      _isProfessionalLoan
                          ? 'Professional Loan – Application Guide'
                          : _isStudentLoan
                              ? 'Student Loan – Application Guide'
                              : _isCarLoanFirmCoApplicant
                                  ? 'Car Loan – ${_isCarLoanPartnership ? "Partnership Firm" : "PVT LTD"} Co-applicant'
                                  : 'Application Guide',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isProfessionalLoan
                          ? 'Documents and steps for ${_isProfessionalDoctor ? "Doctor" : "CA"} professional loan.'
                          : _isStudentLoan
                              ? 'Documents and steps for student loan.'
                              : _isCarLoanFirmCoApplicant
                                  ? 'Firm documents and ${_isCarLoanPartnership ? "Partners" : "Authorized Person"} KYC required. Follow the steps below.'
                                  : _isPersonalLoan
                                      ? (widget.withCoApplicant
                                          ? 'Apply with a co-applicant (joint loan). Follow the steps below.'
                                          : 'Apply alone. Follow the steps below.')
                                      : 'Follow these steps for a smooth loan application.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Process Overview Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                'i',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Process Overview',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isPersonalLoan
                                      ? (widget.withCoApplicant
                                          ? 'Step-by-step: 1) Selfie 2) Aadhaar 3) PAN 4) Bank Statement 5) Co-applicant Aadhaar & PAN 6) Salary Slips 7) Personal Details 8) Preview & Submit. Please ensure all documents are clear and valid. At the final step, slide to submit to confirm your application.'
                                          : 'Step-by-step: 1) Selfie 2) Aadhaar 3) PAN 4) Bank Statement 5) Salary Slips 6) Personal Details 7) Preview & Submit. Please ensure all documents are clear and valid. At the final step, slide to submit to confirm your application.')
                                      : 'You will be guided through a step-by-step process to submit your documents for verification. Please ensure all documents are clear and valid. At the final step, slide to submit to confirm your application.',
                                  textAlign: TextAlign.justify,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.8),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // KYC & authorization notice
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: AppTheme.primaryColor,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'I voluntarily submit my Aadhaar and other required documents for KYC and loan processing and authorize the Company to verify and use them in accordance with applicable laws.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.45,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.justify,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Required Documents Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              color: colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Required Documents',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDocumentItem(
                          context,
                          icon: Icons.face,
                          title: _isBusinessProprietor
                              ? 'Selfie (Proprietor)'
                              : _isProfessionalLoan
                                  ? 'Selfie (Professional)'
                                  : _isStudentLoan
                                      ? 'Selfie (Student)'
                                      : 'Selfie/Photo',
                          description: _isBusinessProprietor
                              ? 'Clear photo of proprietor'
                              : _isProfessionalLoan
                                  ? 'Passport-style photo'
                                  : 'Passport-style photo with white background',
                          iconColor: const Color(0xFF7C3AED),
                        ),
                        const SizedBox(height: 12),
                        _buildDocumentItem(
                          context,
                          icon: Icons.badge,
                          title: _isBusinessProprietor
                              ? 'Aadhaar (Proprietor)'
                              : _isProfessionalLoan
                                  ? 'Aadhaar Card (Professional)'
                                  : _isStudentLoan
                                      ? 'Aadhaar Card (Student)'
                                      : 'Aadhaar Card',
                          description: 'Front and back sides required',
                          iconColor: AppTheme.successColor,
                        ),
                        const SizedBox(height: 12),
                        _buildDocumentItem(
                          context,
                          icon: Icons.credit_card,
                          title: _isBusinessProprietor
                              ? 'PAN (Proprietor)'
                              : _isProfessionalLoan
                                  ? 'PAN Card (Professional)'
                                  : _isStudentLoan
                                      ? 'PAN Card (Student)'
                                      : 'PAN Card',
                          description: 'Front side required',
                          iconColor: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(height: 12),
                        if (_isBusinessProprietor) ...[
                          _buildDocumentItem(
                            context,
                            icon: Icons.badge_outlined,
                            title: 'Aadhaar (Spouse)',
                            description: 'Front and back sides required',
                            iconColor: const Color(0xFF14B8A6),
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.credit_card_outlined,
                            title: 'PAN (Spouse)',
                            description: 'Front side required',
                            iconColor: const Color(0xFF0EA5E9),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _buildDocumentItem(
                          context,
                          icon: Icons.account_balance,
                          title: _isProfessionalLoan
                              ? 'Bank Statement (Professional)'
                              : _isStudentLoan
                                  ? 'Bank Statement (6 months)'
                                  : 'Bank Statement',
                          description: 'Last 6 months statement',
                          iconColor: AppTheme.primaryColor,
                        ),
                        const SizedBox(height: 12),
                        if (_isStudentLoan) ...[
                          _buildDocumentItem(
                            context,
                            icon: Icons.badge_outlined,
                            title: 'Passport (optional)',
                            description: 'Photo or PDF, if available',
                            iconColor: const Color(0xFFF59E0B),
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.school_outlined,
                            title: 'Admission Letter',
                            description: 'From your institution (photo or PDF)',
                            iconColor: const Color(0xFFF59E0B),
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.description_outlined,
                            title: 'Academic Mark Sheets',
                            description: 'SSC, Inter, Graduation (photo or PDF)',
                            iconColor: const Color(0xFFF59E0B),
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.work_outline,
                            title: 'If working: 3 months payslips + ID card',
                            description: 'Required only if you are currently working',
                            iconColor: const Color(0xFF0D9488),
                          ),
                          const SizedBox(height: 12),
                        ] else if (_isBusinessProprietor) ...[
                          _buildDocumentItem(
                            context,
                            icon: Icons.receipt_long,
                            title: 'GST / Labour Certificate',
                            description: 'At least one required (photo or PDF)',
                            iconColor: const Color(0xFF7C3AED),
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.workspace_premium,
                            title: 'MSME Certificate',
                            description: 'Photo or PDF',
                            iconColor: const Color(0xFF0D9488),
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.home_outlined,
                            title: 'Own House Proof',
                            description: 'Photo or PDF',
                            iconColor: const Color(0xFF14B8A6),
                          ),
                          const SizedBox(height: 12),
                        ] else if (_isProfessionalLoan) ...[
                          if (_isProfessionalDoctor) ...[
                            _buildDocumentItem(
                              context,
                              icon: Icons.school,
                              title: 'MBBS / Medical Degree',
                              description: 'Degree certificate (photo or PDF)',
                              iconColor: const Color(0xFF0EA5E9),
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentItem(
                              context,
                              icon: Icons.badge,
                              title: 'Medical Licence',
                              description: 'Council registration (photo or PDF)',
                              iconColor: const Color(0xFF0EA5E9),
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentItem(
                              context,
                              icon: Icons.medical_services,
                              title: 'Prescription / Letterhead',
                              description: 'Proof of practice (photo or PDF)',
                              iconColor: const Color(0xFF0EA5E9),
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentItem(
                              context,
                              icon: Icons.receipt_long,
                              title: 'ITR (Income Tax Return)',
                              description: 'Last 2 years (photo or PDF)',
                              iconColor: const Color(0xFF0D9488),
                            ),
                            const SizedBox(height: 12),
                          ] else if (_isProfessionalCa) ...[
                            _buildDocumentItem(
                              context,
                              icon: Icons.school_outlined,
                              title: 'CA Degree',
                              description: 'ICAI qualification (photo or PDF)',
                              iconColor: const Color(0xFF059669),
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentItem(
                              context,
                              icon: Icons.description,
                              title: 'Certificate of Practice (COP)',
                              description: 'Photo or PDF',
                              iconColor: const Color(0xFF059669),
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentItem(
                              context,
                              icon: Icons.card_membership,
                              title: 'ICAI Certificate',
                              description: 'Membership certificate (photo or PDF)',
                              iconColor: const Color(0xFF059669),
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentItem(
                              context,
                              icon: Icons.receipt_long,
                              title: 'ITR (Income Tax Return)',
                              description: 'Last 2 years (photo or PDF)',
                              iconColor: const Color(0xFF0D9488),
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentItem(
                              context,
                              icon: Icons.account_balance,
                              title: 'Balance Sheet',
                              description: 'Practice/firm assets, liabilities (photo or PDF)',
                              iconColor: const Color(0xFF059669),
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentItem(
                              context,
                              icon: Icons.trending_up,
                              title: 'P&L Statement',
                              description: 'Profit & Loss (photo or PDF)',
                              iconColor: const Color(0xFF059669),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ] else if (_isCarLoanFirmCoApplicant) ...[
                          _buildDocumentItem(
                            context,
                            icon: Icons.badge,
                            title: 'PAN Card (Firm)',
                            description: 'Firm PAN card (photo or PDF)',
                            iconColor: const Color(0xFFF59E0B),
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.receipt_long,
                            title: 'GST',
                            description: 'GST registration certificate',
                            iconColor: const Color(0xFF7C3AED),
                          ),
                          const SizedBox(height: 12),
                          if (_isCarLoanPartnership) ...[
                            _buildDocumentItem(
                              context,
                              icon: Icons.description_outlined,
                              title: 'Partnership Deed',
                              description: 'Partnership deed document',
                              iconColor: const Color(0xFF0EA5E9),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_isCarLoanPvtLtd) ...[
                            _buildDocumentItem(
                              context,
                              icon: Icons.verified_outlined,
                              title: 'Incorporation Certificate',
                              description: 'Company incorporation certificate',
                              iconColor: const Color(0xFF0EA5E9),
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentItem(
                              context,
                              icon: Icons.article_outlined,
                              title: 'AOA & MOA',
                              description: 'Articles & Memorandum of Association',
                              iconColor: const Color(0xFF059669),
                            ),
                            const SizedBox(height: 12),
                          ],
                          _buildDocumentItem(
                            context,
                            icon: Icons.account_balance,
                            title: 'Bank Statement (Firm)',
                            description: 'Last 6 months firm bank statement',
                            iconColor: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.receipt,
                            title: 'ITR (Firm)',
                            description: 'Latest 2 years ITR (firm)',
                            iconColor: const Color(0xFF0D9488),
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.photo_camera,
                            title: '${_isCarLoanPartnership ? "Partners" : "Authorized Person"} Photo (×2)',
                            description: 'Two passport-style photos',
                            iconColor: const Color(0xFF14B8A6),
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.credit_card,
                            title: '${_isCarLoanPartnership ? "Partners" : "Authorized Person"} PAN',
                            description: 'PAN card (photo or PDF)',
                            iconColor: const Color(0xFFF59E0B),
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.home_outlined,
                            title: 'Address Proof',
                            description: 'Aadhaar, Passport, Voter ID or Driving Licence',
                            iconColor: const Color(0xFF7C3AED),
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          if (_isPersonalLoan && widget.withCoApplicant) ...[
                            _buildDocumentItem(
                              context,
                              icon: Icons.person_add_alt_1,
                              title: 'Co-applicant Aadhaar & PAN',
                              description: 'Co-applicant Aadhaar (front & back) and PAN.',
                              iconColor: const Color(0xFF14B8A6),
                            ),
                            const SizedBox(height: 12),
                          ],
                          _buildDocumentItem(
                            context,
                            icon: Icons.description,
                            title: 'Salary Slips',
                            description: 'Last 3 months for income verification',
                            iconColor: const Color(0xFF0D9488),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _buildDocumentItem(
                          context,
                          icon: Icons.person,
                          title: _isBusinessProprietor
                              ? 'Personal Details (Proprietor)'
                              : _isProfessionalLoan
                                  ? 'Personal Details (Professional)'
                                  : 'Personal Information',
                          description: _isProfessionalLoan
                              ? 'KYC, residence, qualification & practice details'
                              : 'Complete the personal data form',
                          iconColor: const Color(0xFF7C3AED),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Instructions Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Instructions',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInstructionItem(
                          context,
                          'Ensure all documents are clear and readable.',
                        ),
                        const SizedBox(height: 12),
                        _buildInstructionItem(
                          context,
                          'Use good lighting when capturing photos.',
                        ),
                        const SizedBox(height: 12),
                        _buildInstructionItem(
                          context,
                          'Remove any filters or editing from photos.',
                        ),
                        const SizedBox(height: 12),
                        _buildInstructionItem(
                          context,
                          'If uploading PDFs, ensure they are not password protected or provide the password.',
                        ),
                        const SizedBox(height: 12),
                        _buildInstructionItem(
                          context,
                          'Slide to submit at the final step to confirm your application.',
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Terms & Conditions
                    Consumer<SubmissionProvider>(
                      builder: (context, provider, _) {
                        final termsAccepted = provider.termsAccepted;
                        return Row(
                          children: [
                            Checkbox(
                              value: termsAccepted,
                              onChanged: (value) {
                                provider.setTermsAccepted(value ?? false);
                              },
                              activeColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  context.push(AppRoutes.termsAndConditions);
                                },
                                child: RichText(
                                  text: TextSpan(
                                    style: theme.textTheme.bodyLarge,
                                    children: [
                                      const TextSpan(
                                        text: 'I accept the ',
                                      ),
                                      TextSpan(
                                        text: 'Terms & Conditions',
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // Match Review & Submit screen: full-width slide, same size as "Slide to Submit"
                    Consumer<SubmissionProvider>(
                      builder: (context, provider, _) {
                        final termsAccepted = provider.termsAccepted;
                        final canStart = termsAccepted && !_isCreatingApplication;
                        return SizedBox(
                          width: double.infinity,
                          child: SlideToConfirm(
                            label: _isCreatingApplication
                                ? 'Creating Application...'
                                : 'Slide to start',
                            height: 60,
                            borderRadius: const BorderRadius.all(Radius.circular(16)),
                            enabled: canStart,
                            onSubmitted: canStart
                              ? () async {
                                  if (!mounted) return;
                                  setState(() => _isCreatingApplication = true);
                                  try {
                                    // Before creating a new application, check existing ones.
                                    final existingApps =
                                        await _applicationService.getApplications(
                                      status: 'all',
                                      limit: 50,
                                    );

                                    final hasApproved = existingApps
                                        .any((app) => app.isApproved);

                                    // When developer mode is on, allow multiple applications
                                    final developerMode =
                                        await isDeveloperModeEnabled();
                                    if (!developerMode) {
                                      // Any submitted/in-progress applications that are NOT approved yet
                                      final blockingApps = existingApps.where(
                                        (app) =>
                                            app.isSubmitted ||
                                            app.isInProgress ||
                                            app.isPaused,
                                      );

                                      if (!hasApproved &&
                                          blockingApps.isNotEmpty) {
                                        // Show "talk to our agent" style dialog and do NOT create a new app
                                        final latest =
                                            List<LoanApplication>.from(
                                                blockingApps)
                                              ..sort(
                                                (a, b) => b.updatedAt
                                                    .compareTo(a.updatedAt),
                                              );
                                        _showInProgressDialog(
                                            context, latest.first);
                                        return;
                                      }
                                    }

                                    // Clear old draft data before starting new submission
                                    final submissionProvider =
                                        context.read<SubmissionProvider>();
                                    await submissionProvider.clearDraft();
                                    submissionProvider.resetSubmission();

                                    final loanType =
                                        widget.loanType ?? 'personal';
                                    // Store loan meta in the draft model (used for completeness rules).
                                    submissionProvider.setLoanType(loanType);
                                    submissionProvider.setBusinessLoanType(
                                      widget.businessLoanType,
                                    );
                                    submissionProvider.setProfessionalLoanType(
                                      widget.professionalLoanType,
                                    );
                                    submissionProvider.setHasCoApplicant(
                                      widget.withCoApplicant,
                                    );
                                    if (widget.coApplicantFirmType != null) {
                                      submissionProvider.setCoApplicantFirmType(
                                        widget.coApplicantFirmType,
                                      );
                                    }
                                    debugPrint(
                                        'Creating application for loan type: $loanType');
                                    // Create application so step screens have an applicationId
                                    // for uploads and saving step data
                                    final application =
                                        await _applicationService.createApplication(
                                      loanType: loanType,
                                      currentStep: 1,
                                      status: 'draft',
                                    );
                                    if (!mounted) return;
                                    // Backend may return a different label; keep selected loan type in app.
                                    final applicationToSet = loanType == 'Professional Loan'
                                        ? application.copyWith(loanType: 'Professional Loan')
                                        : loanType == 'Student Loan'
                                            ? application.copyWith(loanType: 'Student Loan')
                                            : application;
                                    if (loanType == 'Professional Loan') {
                                      await setProfessionalLoanApplicationId(applicationToSet.id);
                                    }
                                    if (loanType == 'Student Loan') {
                                      await setStudentLoanApplicationId(applicationToSet.id);
                                    }
                                    context
                                        .read<ApplicationProvider>()
                                        .setApplication(applicationToSet);
                                    debugPrint(
                                        'Application created: ${application.id}');
                                    context.go(AppRoutes.step1Selfie);
                                  } catch (e) {
                                    if (mounted) {
                                      debugPrint(
                                          'Error creating application: $e');
                                      PremiumToast.showError(
                                        context,
                                        'Could not start application. '
                                        'Please check your connection and try again.',
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(
                                          () => _isCreatingApplication = false);
                                    }
                                  }
                                }
                              : null,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInProgressDialog(BuildContext context, LoanApplication application) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: AppTheme.warningColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  AppStrings.applicationInProgressTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Message
                Text(
                  'Application is in progress. Please talk to our agent.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Application details
                PremiumCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Loan Type: ${application.loanType}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppStrings.stepName(application.currentStep),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(AppStrings.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PremiumButton(
                        label: 'Call to our agents',
                        icon: Icons.phone,
                        isPrimary: true,
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _openPhoneDialer(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(AppRoutes.home),
            color: colorScheme.onSurface,
          ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Image.asset(
                'assets/JSEE_icon.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'JSEE Solutions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle,
            size: 18,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.5,
            ),
            textAlign: TextAlign.left,
          ),
        ),
      ],
    );
  }

  Future<void> _openPhoneDialer(BuildContext context) async {
    // Replace with your support phone number
    const String phoneNumber = '+916303429063'; // +91 63034 29063
    final Uri phoneUrl = Uri.parse('tel:$phoneNumber');

    try {
      await launchUrl(phoneUrl);
    } catch (e) {
      debugPrint('Error opening phone dialer: $e');
      if (context.mounted) {
        PremiumToast.showError(
          context,
          AppStrings.assistancePhoneError,
        );
      }
    }
  }
}

