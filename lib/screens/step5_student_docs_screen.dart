import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/document_submission.dart';
import '../providers/auth_provider.dart';
import '../providers/submission_provider.dart';
import '../providers/application_provider.dart';
import '../services/additional_documents_service.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/blob_helper.dart';
import '../widgets/app_header.dart';
import '../widgets/platform_image.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_toast.dart';
import '../widgets/premium_progress_indicator.dart';
import '../services/storage_service.dart';
import '../widgets/preview_header_action.dart';
import '../widgets/prevent_close_on_back.dart';

class Step5StudentDocsScreen extends StatefulWidget {
  const Step5StudentDocsScreen({
    super.key,
    this.fromPreview = false,
  });

  final bool fromPreview;

  @override
  State<Step5StudentDocsScreen> createState() => _Step5StudentDocsScreenState();
}

class _Step5StudentDocsScreenState extends State<Step5StudentDocsScreen> {
  final AdditionalDocumentsService _documentsService = AdditionalDocumentsService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _loadingLead = true;
  String? _leadId;
  String? _error;
  bool _isSaving = false;
  String? _authToken;
  final Map<String, Uint8List?> _pickedBytes = {};

  List<Map<String, String>> get _baseCards => [
        {'key': 'passport', 'title': 'Passport (optional)'},
        {'key': 'admission_letter', 'title': 'Admission Letter'},
        {'key': 'mark_sheet_ssc', 'title': 'SSC Mark Sheet'},
        {'key': 'mark_sheet_inter', 'title': 'Inter Mark Sheet'},
        {'key': 'mark_sheet_graduation', 'title': 'Graduation Mark Sheet'},
      ];

  List<Map<String, String>> get _workingCards => [
        {'key': 'payslip1', 'title': 'Payslip (Month 1)'},
        {'key': 'payslip2', 'title': 'Payslip (Month 2)'},
        {'key': 'payslip3', 'title': 'Payslip (Month 3)'},
        {'key': 'id_card', 'title': 'ID Card'},
      ];

  bool _isPdfPath(String? path) => (path ?? '').toLowerCase().endsWith('.pdf');

  IconData _iconForDocKey(String key) {
    switch (key) {
      case 'passport':
        return Icons.badge_outlined;
      case 'admission_letter':
        return Icons.school_outlined;
      case 'mark_sheet_ssc':
      case 'mark_sheet_inter':
      case 'mark_sheet_graduation':
        return Icons.description_outlined;
      case 'payslip1':
      case 'payslip2':
      case 'payslip3':
        return Icons.receipt_long;
      case 'id_card':
        return Icons.badge;
      default:
        return Icons.upload_file;
    }
  }

  String _hintForDocKey(String key) {
    switch (key) {
      case 'passport':
        return 'Optional. Upload passport if you have one. Photo or PDF.';
      case 'admission_letter':
        return 'Upload admission letter from institution. Photo or PDF.';
      case 'mark_sheet_ssc':
        return 'Upload SSC (10th) mark sheet. Photo or PDF.';
      case 'mark_sheet_inter':
        return 'Upload Inter (12th) mark sheet. Photo or PDF.';
      case 'mark_sheet_graduation':
        return 'Upload graduation mark sheet. Photo or PDF.';
      case 'payslip1':
      case 'payslip2':
      case 'payslip3':
        return 'Upload payslip. Photo or PDF.';
      case 'id_card':
        return 'Upload employer ID card. Photo or PDF.';
      default:
        return 'Upload the document. Photo or PDF.';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAuthToken();
      _loadLeadId();
    });
  }

  Future<void> _loadAuthToken() async {
    try {
      final token = await StorageService.instance.getAccessToken();
      if (token != null && mounted) setState(() => _authToken = token);
    } catch (_) {}
  }

  Future<void> _loadLeadId() async {
    setState(() {
      _loadingLead = true;
      _error = null;
    });
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.user;
      if (user == null) {
        setState(() {
          _leadId = null;
          _error = 'User not logged in.';
          _loadingLead = false;
        });
        return;
      }
      String? phoneNumber;
      if (user.email.endsWith('@phone.local')) {
        phoneNumber = user.email.split('@')[0];
      }
      final leadData = await _documentsService.getLeadByUser(
        user.email,
        phone: phoneNumber,
      );
      setState(() {
        _leadId = leadData?['id'] as String?;
        _loadingLead = false;
      });
      if (_leadId == null && mounted) {
        PremiumToast.showWarning(
          context,
          'Lead not found. Uploads may not sync to server.',
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loadingLead = false;
      });
    }
  }

  void _setDocPathForKey(String key, String path, {required bool isPdf}) {
    final provider = context.read<SubmissionProvider>();
    switch (key) {
      case 'passport':
        provider.setStudentPassport(path, isPdf: isPdf);
        break;
      case 'admission_letter':
        provider.setStudentAdmissionLetter(path, isPdf: isPdf);
        break;
      case 'mark_sheet_ssc':
        provider.setStudentMarkSheetSsc(path, isPdf: isPdf);
        break;
      case 'mark_sheet_inter':
        provider.setStudentMarkSheetInter(path, isPdf: isPdf);
        break;
      case 'mark_sheet_graduation':
        provider.setStudentMarkSheetGraduation(path, isPdf: isPdf);
        break;
      case 'payslip1':
        provider.setStudentPayslip1(path, isPdf: isPdf);
        break;
      case 'payslip2':
        provider.setStudentPayslip2(path, isPdf: isPdf);
        break;
      case 'payslip3':
        provider.setStudentPayslip3(path, isPdf: isPdf);
        break;
      case 'id_card':
        provider.setStudentIdCard(path, isPdf: isPdf);
        break;
    }
  }

  String? _getDocPath(DocumentSubmission submission, String key) {
    final s = submission.studentDocuments;
    if (s == null) return null;
    switch (key) {
      case 'passport':
        return s.passport?.path;
      case 'admission_letter':
        return s.admissionLetter?.path;
      case 'mark_sheet_ssc':
        return s.markSheetSsc?.path;
      case 'mark_sheet_inter':
        return s.markSheetInter?.path;
      case 'mark_sheet_graduation':
        return s.markSheetGraduation?.path;
      case 'payslip1':
        return s.payslip1?.path;
      case 'payslip2':
        return s.payslip2?.path;
      case 'payslip3':
        return s.payslip3?.path;
      case 'id_card':
        return s.idCard?.path;
      default:
        return null;
    }
  }

  bool _isRemotePath(String? path) {
    final p = path ?? '';
    return p.startsWith('http') || p.startsWith('/uploads/') || p.startsWith('/api/');
  }

  String _filenameFromPath(String path, {required String fallback}) {
    try {
      final uri = Uri.tryParse(path);
      final segments = uri?.pathSegments;
      if (segments != null && segments.isNotEmpty) {
        final last = segments.last;
        if (last.trim().isNotEmpty) return last;
      }
    } catch (_) {}
    if (path.contains('/')) return path.split('/').last;
    if (path.contains('\\')) return path.split('\\').last;
    return fallback;
  }

  static const Map<String, String> _documentTypes = {
    'passport': 'applicant_student_passport',
    'admission_letter': 'applicant_student_admission_letter',
    'mark_sheet_ssc': 'applicant_student_mark_sheet_ssc',
    'mark_sheet_inter': 'applicant_student_mark_sheet_inter',
    'mark_sheet_graduation': 'applicant_student_mark_sheet_graduation',
    'payslip1': 'applicant_student_payslip_1',
    'payslip2': 'applicant_student_payslip_2',
    'payslip3': 'applicant_student_payslip_3',
    'id_card': 'applicant_student_id_card',
  };

  Future<String?> _uploadIfNeeded({required String key, required String? path}) async {
    if (path == null || path.trim().isEmpty) return null;
    if (_leadId == null) return path;
    if (_isRemotePath(path)) return path;
    final documentType = _documentTypes[key] ?? 'applicant_student_doc';
    final fileName = _filenameFromPath(
      path,
      fallback: '${documentType}_${DateTime.now().millisecondsSinceEpoch}',
    );
    final bytes = kIsWeb ? _pickedBytes[key] : null;
    final result = await _documentsService.uploadAdditionalDocument(
      filePath: path,
      fileName: fileName,
      documentType: documentType,
      leadId: _leadId!,
      fileBytes: bytes,
    );
    final url = (result['url'] as String?) ?? (result['path'] as String?);
    return url ?? path;
  }

  void _openImagePreview(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: PlatformImage(
                        imagePath: imagePath,
                        fit: BoxFit.contain,
                        headers: _authToken != null
                            ? {'Authorization': 'Bearer $_authToken'}
                            : null,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: AppTheme.errorColor.withValues(alpha: 0.95),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.close, color: Colors.white, size: 20),
                      ),
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

  Future<void> _pickPdf(String key) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) PremiumToast.showError(context, 'Unable to read PDF. Please try again.');
        return;
      }
      final blobUrl = createBlobUrl(bytes, mimeType: 'application/pdf');
      setState(() => _pickedBytes[key] = bytes);
      _setDocPathForKey(key, blobUrl, isPdf: true);
      return;
    }
    if (file.path == null) return;
    _setDocPathForKey(key, file.path!, isPdf: true);
  }

  Future<void> _pickImage(String key, ImageSource source) async {
    final picked = await _imagePicker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;
    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      final blobUrl = createBlobUrl(bytes, mimeType: 'image/jpeg');
      setState(() => _pickedBytes[key] = bytes);
      _setDocPathForKey(key, blobUrl, isPdf: false);
      return;
    }
    _setDocPathForKey(key, picked.path, isPdf: false);
  }

  Future<void> _showPickerSheet(String key) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Camera'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickImage(key, ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickImage(key, ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('PDF'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickPdf(key);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveAndProceed() async {
    final submission = context.read<SubmissionProvider>().submission;
    if (submission.studentDocuments == null ||
        !submission.studentDocuments!.isComplete) {
      PremiumToast.showWarning(
        context,
        'Please upload admission letter and all academic mark sheets (SSC, Inter, Graduation). Passport is optional.',
      );
      return;
    }
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final provider = context.read<SubmissionProvider>();
      final allCards = [..._baseCards];
      if (submission.studentDocuments!.isWorking) {
        allCards.addAll(_workingCards);
      }
      for (final c in allCards) {
        final key = c['key']!;
        final path = _getDocPath(provider.submission, key);
        final uploaded = await _uploadIfNeeded(key: key, path: path);
        if (uploaded != null) {
          _setDocPathForKey(key, uploaded, isPdf: _isPdfPath(uploaded));
        }
      }
      await context.read<ApplicationProvider>().updateApplication(currentStep: 5);
      if (mounted) {
        PremiumToast.showSuccess(context, 'Student documents saved.');
        context.go(widget.fromPreview ? AppRoutes.step6Preview : AppRoutes.step5PersonalData);
      }
    } catch (e) {
      if (mounted) {
        PremiumToast.showError(
          context,
          'Failed to save documents: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildDocCard(BuildContext context, Map<String, String> c) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final submission = context.watch<SubmissionProvider>().submission;
    final key = c['key']!;
    final title = c['title']!;
    final path = _getDocPath(submission, key);
    final isPdf = _isPdfPath(path);
    final hasFile = path != null && path.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _iconForDocKey(key),
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: (theme.textTheme.titleLarge?.fontSize ?? 20) + 2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasFile
                        ? AppTheme.successColor.withValues(alpha: 0.12)
                        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: (hasFile ? AppTheme.successColor : colorScheme.outline)
                          .withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    hasFile ? 'UPLOADED' : 'PENDING',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: hasFile
                          ? AppTheme.successColor
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _hintForDocKey(key),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.12),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: !hasFile
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.upload_file,
                                      color: colorScheme.onSurfaceVariant,
                                      size: 34,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'No file selected',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : isPdf
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.picture_as_pdf,
                                          color: AppTheme.errorColor,
                                          size: 38,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'PDF selected',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _openImagePreview(path),
                                      child: PlatformImage(
                                        imagePath: path,
                                        fit: BoxFit.cover,
                                        headers: _authToken != null
                                            ? {'Authorization': 'Bearer $_authToken'}
                                            : null,
                                      ),
                                    ),
                                  ),
                      ),
                      if (hasFile)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: AppTheme.successColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 18),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            PremiumButton(
              label: !hasFile ? 'Upload' : 'Replace',
              icon: Icons.cloud_upload_outlined,
              isPrimary: true,
              onPressed: _isSaving ? null : () => _showPickerSheet(key),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final submission = context.watch<SubmissionProvider>().submission;
    final isWorking = submission.studentDocuments?.isWorking ?? false;

    return PreventCloseOnBack(
      onBack: () {
        if (_isSaving) return;
        context.go(
          widget.fromPreview ? AppRoutes.step6Preview : AppRoutes.step4BankStatement,
        );
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Student Documents',
              icon: Icons.school_outlined,
              showBackButton: true,
              onBackPressed: _isSaving
                  ? null
                  : () {
                      context.go(
                        widget.fromPreview ? AppRoutes.step6Preview : AppRoutes.step4BankStatement,
                      );
                    },
              showHomeButton: true,
              actions: const [
                PreviewHeaderAction(backRoute: AppRoutes.step5StudentDocs),
              ],
            ),
            if (_loadingLead)
              LinearProgressIndicator(
                minHeight: 2,
                color: AppTheme.primaryColor,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              ),
            PremiumProgressIndicator(
              currentStep: 5,
              totalSteps: 7,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PremiumCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.info_outline, color: AppTheme.primaryColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Required for Student Loan',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Admission letter and mark sheets (SSC, Inter, Graduation) are required. Passport is optional. PAN, Aadhaar and Bank statement are collected in earlier steps. Salary slips are not required for most students—only turn on "Are you currently working?" below if you have a job and need to upload 3 months payslips and ID card.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.3,
                                  ),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _error!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppTheme.errorColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._baseCards.map((c) => _buildDocCard(context, c)),
                    const SizedBox(height: 12),
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.work_outline, color: AppTheme.primaryColor, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Are you currently working?',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Switch(
                                value: isWorking,
                                onChanged: _isSaving
                                    ? null
                                    : (value) {
                                        context.read<SubmissionProvider>().setStudentIsWorking(value);
                                      },
                                activeColor: AppTheme.primaryColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Most students leave this off. Turn on only if you have a job and need to upload payslips and employer ID.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isWorking) ...[
                      const SizedBox(height: 12),
                      ..._workingCards.map((c) => _buildDocCard(context, c)),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.12),
              ),
            ),
          ),
          child: PremiumButton(
            label: _isSaving ? 'Saving...' : 'Save & Continue',
            icon: Icons.arrow_forward,
            isPrimary: true,
            onPressed: _isSaving ? null : _saveAndProceed,
          ),
        ),
      ),
    ),
  );
  }
}
