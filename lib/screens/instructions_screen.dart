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
import '../widgets/auth_theme_widgets.dart';
import '../providers/submission_provider.dart';
import '../providers/application_provider.dart';
import '../providers/auth_provider.dart';
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

  /// Copy sits on [MercotraceMarketingBackground] (bright gradient). Theme
  /// [ColorScheme.onSurface] is tuned for solid scaffold colors — dark-on-blue
  /// (light mode) and white-on-blue without shadow (dark mode) both read poorly.
  static final List<Shadow> _marketingTextShadow = [
    Shadow(
      color: Colors.black.withValues(alpha: 0.28),
      blurRadius: 16,
      offset: const Offset(0, 2),
    ),
  ];

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
      backgroundColor: Colors.transparent,
      body: MercotraceMarketingBackground(
        slideVisualIndex: 0,
        child: SafeArea(
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
                        color: Colors.white,
                        shadows: _marketingTextShadow,
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
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 14,
                        height: 1.45,
                        shadows: _marketingTextShadow,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Process Overview Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.65),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
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
                                    color: AppTheme.textOnLightSurface,
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
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.18),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
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
                                color: AppTheme.textMutedOnLightSurface,
                                height: 1.45,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.justify,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Important disclaimer notice (facilitator role & document authenticity)
                    _buildDisclaimerNotice(context),
                    const SizedBox(height: 32),
                    // Required Documents Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              color: Colors.white.withValues(alpha: 0.95),
                              size: 20,
                              shadows: _marketingTextShadow,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Required Documents',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.white,
                                shadows: _marketingTextShadow,
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
                          iconColor: AppTheme.secondaryColor,
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
                          iconColor: AppTheme.warningColor,
                        ),
                        const SizedBox(height: 12),
                        if (_isBusinessProprietor) ...[
                          _buildDocumentItem(
                            context,
                            icon: Icons.badge_outlined,
                            title: 'Aadhaar (Spouse)',
                            description: 'Front and back sides required',
                            iconColor: AppTheme.successColor,
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.credit_card_outlined,
                            title: 'PAN (Spouse)',
                            description: 'Front side required',
                            iconColor: AppTheme.infoColor,
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
                            iconColor: AppTheme.warningColor,
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.school_outlined,
                            title: 'Admission Letter',
                            description: 'From your institution (photo or PDF)',
                            iconColor: AppTheme.warningColor,
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.description_outlined,
                            title: 'Academic Mark Sheets',
                            description: 'SSC, Inter, Graduation (photo or PDF)',
                            iconColor: AppTheme.warningColor,
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.work_outline,
                            title: 'If working: 3 months payslips + ID card',
                            description: 'Required only if you are currently working',
                            iconColor: AppTheme.successColor,
                          ),
                          const SizedBox(height: 12),
                        ] else if (_isBusinessProprietor) ...[
                          _buildDocumentItem(
                            context,
                            icon: Icons.receipt_long,
                            title: 'GST / Labour Certificate',
                            description: 'At least one required (photo or PDF)',
                            iconColor: AppTheme.secondaryColor,
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.workspace_premium,
                            title: 'MSME Certificate',
                            description: 'Photo or PDF',
                            iconColor: AppTheme.successColor,
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.home_outlined,
                            title: 'Own House Proof',
                            description: 'Photo or PDF',
                            iconColor: AppTheme.successColor,
                          ),
                          const SizedBox(height: 12),
                        ] else if (_isProfessionalLoan) ...[
                          if (_isProfessionalDoctor) ...[
                            _buildDocumentItem(
                              context,
                              icon: Icons.school,
                              title: 'MBBS / Medical Degree',
                              description: 'Degree certificate (photo or PDF)',
                              iconColor: AppTheme.infoColor,
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentItem(
                              context,
                              icon: Icons.badge,
                              title: 'Medical Licence',
                              description: 'Council registration (photo or PDF)',
                              iconColor: AppTheme.infoColor,
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentItem(
                              context,
                              icon: Icons.medical_services,
                              title: 'Prescription / Letterhead',
                              description: 'Proof of practice (photo or PDF)',
                              iconColor: AppTheme.infoColor,
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentItem(
                              context,
                              icon: Icons.receipt_long,
                              title: 'ITR (Income Tax Return)',
                              description: 'Last 2 years (photo or PDF)',
                              iconColor: AppTheme.successColor,
                            ),
                            const SizedBox(height: 12),
                          ] else if (_isProfessionalCa) ...[
                            _buildDocumentItem(
                              context,
                              icon: Icons.school_outlined,
                              title: 'CA Degree',
                              description: 'ICAI qualification (photo or PDF)',
                              iconColor: AppTheme.successColor,
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentItem(
                              context,
                              icon: Icons.description,
                              title: 'Certificate of Practice (COP)',
                              description: 'Photo or PDF',
                              iconColor: AppTheme.successColor,
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentItem(
                              context,
                              icon: Icons.card_membership,
                              title: 'ICAI Certificate',
                              description: 'Membership certificate (photo or PDF)',
                              iconColor: AppTheme.successColor,
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentItem(
                              context,
                              icon: Icons.receipt_long,
                              title: 'ITR (Income Tax Return)',
                              description: 'Last 2 years (photo or PDF)',
                              iconColor: AppTheme.successColor,
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentItem(
                              context,
                              icon: Icons.account_balance,
                              title: 'Balance Sheet',
                              description: 'Practice/firm assets, liabilities (photo or PDF)',
                              iconColor: AppTheme.successColor,
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentItem(
                              context,
                              icon: Icons.trending_up,
                              title: 'P&L Statement',
                              description: 'Profit & Loss (photo or PDF)',
                              iconColor: AppTheme.successColor,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ] else if (_isCarLoanFirmCoApplicant) ...[
                          _buildDocumentItem(
                            context,
                            icon: Icons.badge,
                            title: 'PAN Card (Firm)',
                            description: 'Firm PAN card (photo or PDF)',
                            iconColor: AppTheme.warningColor,
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.receipt_long,
                            title: 'GST',
                            description: 'GST registration certificate',
                            iconColor: AppTheme.secondaryColor,
                          ),
                          const SizedBox(height: 12),
                          if (_isCarLoanPartnership) ...[
                            _buildDocumentItem(
                              context,
                              icon: Icons.description_outlined,
                              title: 'Partnership Deed',
                              description: 'Partnership deed document',
                              iconColor: AppTheme.infoColor,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_isCarLoanPvtLtd) ...[
                            _buildDocumentItem(
                              context,
                              icon: Icons.verified_outlined,
                              title: 'Incorporation Certificate',
                              description: 'Company incorporation certificate',
                              iconColor: AppTheme.infoColor,
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentItem(
                              context,
                              icon: Icons.article_outlined,
                              title: 'AOA & MOA',
                              description: 'Articles & Memorandum of Association',
                              iconColor: AppTheme.successColor,
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
                            iconColor: AppTheme.successColor,
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.photo_camera,
                            title: '${_isCarLoanPartnership ? "Partners" : "Authorized Person"} Photo (×2)',
                            description: 'Two passport-style photos',
                            iconColor: AppTheme.successColor,
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.credit_card,
                            title: '${_isCarLoanPartnership ? "Partners" : "Authorized Person"} PAN',
                            description: 'PAN card (photo or PDF)',
                            iconColor: AppTheme.warningColor,
                          ),
                          const SizedBox(height: 12),
                          _buildDocumentItem(
                            context,
                            icon: Icons.home_outlined,
                            title: 'Address Proof',
                            description: 'Aadhaar, Passport, Voter ID or Driving Licence',
                            iconColor: AppTheme.secondaryColor,
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          if (_isPersonalLoan && widget.withCoApplicant) ...[
                            _buildDocumentItem(
                              context,
                              icon: Icons.person_add_alt_1,
                              title: 'Co-applicant Aadhaar & PAN',
                              description: 'Co-applicant Aadhaar (front & back) and PAN.',
                              iconColor: AppTheme.successColor,
                            ),
                            const SizedBox(height: 12),
                          ],
                          _buildDocumentItem(
                            context,
                            icon: Icons.description,
                            title: 'Salary Slips',
                            description: 'Last 3 months for income verification',
                            iconColor: AppTheme.successColor,
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
                          iconColor: AppTheme.secondaryColor,
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
                              color: Colors.white.withValues(alpha: 0.95),
                              size: 20,
                              shadows: _marketingTextShadow,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Instructions',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.white,
                                shadows: _marketingTextShadow,
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
                          'Slide to submit at the final step to confirm your submission.',
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
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.95),
                                      shadows: _marketingTextShadow,
                                    ),
                                    children: [
                                      const TextSpan(
                                        text: 'I accept the ',
                                      ),
                                      TextSpan(
                                        text: 'Terms & Conditions',
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                          decorationColor: Colors.white,
                                          shadows: _marketingTextShadow,
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
                                ? 'Creating submission...'
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
                                    final auth = context.read<AuthProvider>();
                                    final customerLeadId = auth.user?.role ==
                                            'admin'
                                        ? null
                                        : await auth.waitForLeadId();
                                    if (!mounted) return;
                                    final existingApps =
                                        await _applicationService.getApplications(
                                      status: 'all',
                                      limit: 50,
                                      customerLeadId: customerLeadId,
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
                                    if (customerLeadId == null &&
                                        auth.user?.role != 'admin') {
                                      PremiumToast.showError(
                                        context,
                                        'Your profile is not linked yet. Pull down to refresh, '
                                        'or log out and sign in again, then try starting the application.',
                                      );
                                      return;
                                    }
                                    // Create application so step screens have an applicationId
                                    // for uploads and saving step data (backend requires lead for customers).
                                    final application =
                                        await _applicationService.createApplication(
                                      loanType: loanType,
                                      currentStep: 1,
                                      status: 'draft',
                                      customerLeadId: customerLeadId,
                                      applicantDisplayName: (auth.user != null && auth.user!.name.trim().isNotEmpty)
                                          ? auth.user!.name.trim()
                                          : null,
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
                                        'Could not start submission. '
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
                  'Submission is in progress. Partner institutions may contact you regarding next steps.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Submission details
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

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(AppRoutes.home),
                color: Colors.white,
              ),
              const SizedBox(width: 4),
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
                      color: Colors.white,
                    ) ??
                    const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: Colors.white,
                    ),
              ),
            ],
          ),
        ),
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
                    color: AppTheme.textOnLightSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMutedOnLightSurface,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppTheme.textMutedOnLightSurface,
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerNotice(BuildContext context) {
    final theme = Theme.of(context);

    final headlineStyle = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.warningColor,
      fontWeight: FontWeight.w700,
      fontSize: 13,
      height: 1.45,
    );
    final bodyStyle = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.textMutedOnLightSurface,
      height: 1.5,
      fontSize: 13,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: AppTheme.warningColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important Disclaimer',
                  style: headlineStyle,
                ),
                const SizedBox(height: 6),
                Text(
                  'JSEE Solutions acts only as a facilitator and is not responsible for loan approval/rejection decisions made by banks or NBFCs.',
                  style: bodyStyle,
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 6),
                Text(
                  'You are responsible for providing correct and genuine documents. JSEE Solutions is not responsible for any issues arising from incorrect or fake documents.',
                  style: bodyStyle,
                  textAlign: TextAlign.justify,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(BuildContext context, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
          child: Icon(
            Icons.check_circle,
            size: 18,
            color: Colors.white,
            shadows: _marketingTextShadow,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.95),
              shadows: _marketingTextShadow,
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

