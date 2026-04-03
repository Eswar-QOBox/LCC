import 'dart:ui';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import '../services/ocr_service.dart';
import '../utils/ocr_pdf.dart';
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

class Step5ProfessionalDocsScreen extends StatefulWidget {
  const Step5ProfessionalDocsScreen({
    super.key,
    this.fromPreview = false,
  });

  /// When true, Back returns to Preview (e.g. when opened via Edit from Preview).
  final bool fromPreview;

  @override
  State<Step5ProfessionalDocsScreen> createState() => _Step5ProfessionalDocsScreenState();
}

class _Step5ProfessionalDocsScreenState extends State<Step5ProfessionalDocsScreen> {
  final AdditionalDocumentsService _documentsService = AdditionalDocumentsService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _loadingLead = true;
  String? _leadId;
  String? _error;
  bool _isSaving = false;
  String? _authToken;
  final Map<String, Uint8List?> _pickedBytes = {};
  /// OCR must succeed for each uploaded doc (on mobile) before proceeding.
  final Map<String, bool> _ocrCompleteByKey = {};
  final Map<String, String?> _ocrIssueByKey = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAuthToken();
      _loadLeadId();
      // When coming back from preview (or loading with existing docs), run OCR for any local paths so gating works.
      _runOcrForExistingLocalDocs();
    });
  }

  /// Run OCR for documents that already have a local path (e.g. after coming back from preview or draft with local files).
  Future<void> _runOcrForExistingLocalDocs() async {
    if (kIsWeb) return;
    if (!mounted) return;
    final provider = context.read<SubmissionProvider>();
    for (final c in _cards) {
      final key = c['key']!;
      final path = _getDocPath(provider.submission, key);
      if (path == null || path.trim().isEmpty) continue;
      if (_isRemotePath(path) || path.startsWith('blob:')) continue;
      if (_ocrCompleteByKey[key] == true) continue; // already done
      await _performDocumentOcr(key, path, _isPdfPath(path));
      if (!mounted) return;
    }
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

  String get _professionalType =>
      (context.read<SubmissionProvider>().submission.professionalLoanType ?? '').toLowerCase();
  bool get _isDoctor => _professionalType == 'doctor';
  bool get _isCa => _professionalType == 'ca';

  /// Document cards: Doctor = degree, licence, prescription, ITR (2 years); CA = degree, COP, ICAI, ITR (2 years), Balance sheet, P&L.
  List<Map<String, String>> get _cards {
    if (_isDoctor) {
      return [
        {'key': 'medical_degree', 'title': 'MBBS / Medical\nDegree Certificate'},
        {'key': 'medical_licence', 'title': 'Medical Council\nRegistration / Licence'},
        {'key': 'prescription', 'title': 'Prescription /\nClinic Letterhead'},
        {'key': 'itr_year1', 'title': 'ITR (Income Tax Return)\nYear 1'},
        {'key': 'itr_year2', 'title': 'ITR (Income Tax Return)\nYear 2'},
      ];
    }
    if (_isCa) {
      return [
        {'key': 'ca_degree', 'title': 'CA Degree\nCertificate'},
        {'key': 'certificate_of_practice', 'title': 'Certificate of Practice\n(COP)'},
        {'key': 'icai_certificate', 'title': 'ICAI Membership\nCertificate'},
        {'key': 'itr_year1', 'title': 'ITR (Income Tax Return)\nYear 1'},
        {'key': 'itr_year2', 'title': 'ITR (Income Tax Return)\nYear 2'},
        {'key': 'balance_sheet', 'title': 'Balance Sheet'},
        {'key': 'pl_statement', 'title': 'P&L (Profit & Loss)\nStatement'},
      ];
    }
    return [];
  }

  bool _isPdfPath(String? path) => (path ?? '').toLowerCase().endsWith('.pdf');

  IconData _iconForDocKey(String key) {
    switch (key) {
      case 'medical_degree':
        return Icons.school;
      case 'medical_licence':
        return Icons.badge;
      case 'prescription':
        return Icons.medical_services;
      case 'ca_degree':
        return Icons.school_outlined;
      case 'certificate_of_practice':
        return Icons.description;
      case 'icai_certificate':
        return Icons.card_membership;
      case 'itr_year1':
      case 'itr_year2':
        return Icons.receipt_long;
      case 'balance_sheet':
        return Icons.account_balance;
      case 'pl_statement':
        return Icons.trending_up;
      default:
        return Icons.upload_file;
    }
  }

  /// Hints in business-docs style: one line, photo or PDF.
  String _hintForDocKey(String key) {
    switch (key) {
      case 'medical_degree':
        return 'Upload MBBS / MD / MS or equivalent degree certificate. Photo or PDF.';
      case 'medical_licence':
        return 'Upload medical council registration or licence. Photo or PDF.';
      case 'prescription':
        return 'Upload prescription or clinic letterhead as proof of practice. Photo or PDF.';
      case 'ca_degree':
        return 'Upload CA qualification certificate from ICAI. Photo or PDF.';
      case 'certificate_of_practice':
        return 'Upload Certificate of Practice (COP). Photo or PDF.';
      case 'icai_certificate':
        return 'Upload ICAI membership certificate or card. Photo or PDF.';
      case 'itr_year1':
      case 'itr_year2':
        return 'Upload Income Tax Return (ITR) for the year. Photo or PDF.';
      case 'balance_sheet':
        return 'Snapshot of assets, liabilities and net worth (practice/firm). Photo or PDF.';
      case 'pl_statement':
        return 'Profit & Loss: revenue, expenses and profit/loss for the period. Photo or PDF.';
      default:
        return 'Upload the document. Photo or PDF.';
    }
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
    await _performDocumentOcr(key, file.path!, true);
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
    await _performDocumentOcr(key, picked.path, false);
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

  /// Run same OCR as Aadhaar/PAN/bank docs on this professional document (image or PDF first page).
  /// Skips on web and for remote paths. Sets _ocrCompleteByKey so Save & Continue is gated.
  Future<void> _performDocumentOcr(String key, String path, bool isPdf) async {
    if (kIsWeb) return;
    if (_isRemotePath(path)) return;
    if (path.startsWith('blob:')) return;
    try {
      Uint8List? imageBytes;
      if (isPdf && path.toLowerCase().endsWith('.pdf') && OcrPdf.isSupported) {
        try {
          final count = await OcrPdf.getPageCount(path);
          if (count > 0) {
            imageBytes = await OcrPdf.renderPageToJpegBytes(path, pageIndex: 0);
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[ProfessionalDocs] PDF render for OCR failed: $e');
        }
      }
      final result = imageBytes != null
          ? await OcrService.extractDocumentText(path, imageBytes: imageBytes)
          : await OcrService.extractDocumentText(path);
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _ocrCompleteByKey[key] = true;
          _ocrIssueByKey[key] = null;
        });
        PremiumToast.showSuccess(context, 'Document scanned.');
      } else {
        setState(() {
          _ocrCompleteByKey[key] = false;
          _ocrIssueByKey[key] = result.errorMessage;
        });
        PremiumToast.showWarning(
          context,
          'Could not read document text. Re-capture with better lighting or replace the document to continue.',
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ProfessionalDocs] OCR failed: $e');
      if (mounted) {
        setState(() {
          _ocrCompleteByKey[key] = false;
          _ocrIssueByKey[key] = e.toString();
        });
        PremiumToast.showWarning(
          context,
          'Could not scan document. Re-capture or replace the document to continue.',
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  void _setDocPathForKey(String key, String path, {required bool isPdf}) {
    final provider = context.read<SubmissionProvider>();
    switch (key) {
      case 'medical_degree':
        provider.setProfessionalMedicalDegree(path, isPdf: isPdf);
        break;
      case 'medical_licence':
        provider.setProfessionalMedicalLicence(path, isPdf: isPdf);
        break;
      case 'prescription':
        provider.setProfessionalPrescription(path, isPdf: isPdf);
        break;
      case 'ca_degree':
        provider.setProfessionalCaDegree(path, isPdf: isPdf);
        break;
      case 'certificate_of_practice':
        provider.setProfessionalCertificateOfPractice(path, isPdf: isPdf);
        break;
      case 'icai_certificate':
        provider.setProfessionalIcaiCertificate(path, isPdf: isPdf);
        break;
      case 'itr_year1':
        provider.setProfessionalItrYear1(path, isPdf: isPdf);
        break;
      case 'itr_year2':
        provider.setProfessionalItrYear2(path, isPdf: isPdf);
        break;
      case 'balance_sheet':
        provider.setProfessionalBalanceSheet(path, isPdf: isPdf);
        break;
      case 'pl_statement':
        provider.setProfessionalPlStatement(path, isPdf: isPdf);
        break;
    }
  }

  String? _getDocPath(DocumentSubmission submission, String key) {
    final p = submission.professionalDocuments;
    switch (key) {
      case 'medical_degree':
        return p?.medicalDegree?.path;
      case 'medical_licence':
        return p?.medicalLicence?.path;
      case 'prescription':
        return p?.prescription?.path;
      case 'ca_degree':
        return p?.caDegree?.path;
      case 'certificate_of_practice':
        return p?.certificateOfPractice?.path;
      case 'icai_certificate':
        return p?.icaiCertificate?.path;
      case 'itr_year1':
        return p?.itrYear1?.path;
      case 'itr_year2':
        return p?.itrYear2?.path;
      case 'balance_sheet':
        return p?.balanceSheet?.path;
      case 'pl_statement':
        return p?.plStatement?.path;
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
    'medical_degree': 'applicant_professional_medical_degree',
    'medical_licence': 'applicant_professional_medical_licence',
    'prescription': 'applicant_professional_prescription',
    'ca_degree': 'applicant_professional_ca_degree',
    'certificate_of_practice': 'applicant_professional_certificate_of_practice',
    'icai_certificate': 'applicant_professional_icai_certificate',
    'itr_year1': 'applicant_professional_itr_year1',
    'itr_year2': 'applicant_professional_itr_year2',
    'balance_sheet': 'applicant_professional_balance_sheet',
    'pl_statement': 'applicant_professional_pl_statement',
  };

  Future<String?> _uploadIfNeeded({
    required String key,
    required String? path,
  }) async {
    if (path == null || path.trim().isEmpty) return null;
    if (_leadId == null) return path;
    if (_isRemotePath(path)) return path;
    final documentType = _documentTypes[key] ?? 'applicant_professional_doc';
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

  void _showOcrValidationDialog(List<String> issues) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.document_scanner_outlined, color: AppTheme.errorColor, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Document OCR Incomplete',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Each document must be scanned successfully before you can continue.',
              style: TextStyle(height: 1.3),
            ),
            const SizedBox(height: 12),
            ...issues.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $e', style: const TextStyle(height: 1.25)),
            )),
            const SizedBox(height: 12),
            Text(
              'Re-capture or re-upload with better lighting and ensure the document is clearly visible.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.3),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndProceed() async {
    final submission = context.read<SubmissionProvider>().submission;
    final type = _professionalType;
    if (type != 'doctor' && type != 'ca') {
      PremiumToast.showError(context, 'Invalid professional type.');
      return;
    }
    if (submission.professionalDocuments == null ||
        !submission.professionalDocuments!.isComplete(type)) {
      PremiumToast.showWarning(
        context,
        'Please upload all required documents for ${_isDoctor ? "Doctor" : "CA"}.',
      );
      return;
    }
    // On mobile: require OCR success for every uploaded document (remote paths are treated as already verified).
    if (!kIsWeb) {
      final provider = context.read<SubmissionProvider>();
      final issues = <String>[];
      for (final c in _cards) {
        final key = c['key']!;
        final title = c['title']!.replaceAll('\n', ' ');
        final path = _getDocPath(provider.submission, key);
        if (path == null || path.trim().isEmpty) continue;
        if (_isRemotePath(path)) continue;
        if (_ocrCompleteByKey[key] != true) {
          final issue = _ocrIssueByKey[key] != null
              ? '$title: ${_ocrIssueByKey[key]}'
              : '$title: OCR not run or failed';
          issues.add(issue);
        }
      }
      if (issues.isNotEmpty) {
        _showOcrValidationDialog(issues);
        return;
      }
    }
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final provider = context.read<SubmissionProvider>();
      for (final c in _cards) {
        final key = c['key']!;
        final path = _getDocPath(provider.submission, key);
        final uploaded = await _uploadIfNeeded(key: key, path: path);
        if (uploaded != null) {
          _setDocPathForKey(key, uploaded, isPdf: _isPdfPath(uploaded));
        }
      }
      await context.read<ApplicationProvider>().updateApplication(currentStep: 5);
      if (mounted) {
        PremiumToast.showSuccess(context, 'Professional documents saved.');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final submission = context.watch<SubmissionProvider>().submission;

    if (!_isDoctor && !_isCa) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  'Professional loan type not set. Go back to home and start a Professional Loan.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Go to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PreventCloseOnBack(
      onBack: () {
        if (_isSaving) return;
        context.go(widget.fromPreview ? AppRoutes.step6Preview : AppRoutes.step4BankStatement);
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: _isDoctor ? 'Doctor Documents' : 'CA Documents',
              icon: _isDoctor ? Icons.medical_services_outlined : Icons.account_balance_outlined,
              showBackButton: true,
              onBackPressed: _isSaving ? null : () {
                context.go(widget.fromPreview ? AppRoutes.step6Preview : AppRoutes.step4BankStatement);
              },
              showHomeButton: true,
              actions: const [
                PreviewHeaderAction(backRoute: AppRoutes.step5ProfessionalDocs),
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
                                  'Required for Professional Loan',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isDoctor
                                      ? 'Upload MBBS/Medical Degree Certificate, Medical Council Registration/Licence and Prescription or clinic letterhead. You can upload photos or PDFs.'
                                      : 'Upload CA Degree Certificate, Certificate of Practice (COP) and ICAI Membership Certificate. You can upload photos or PDFs.',
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
                    ..._cards.map((c) {
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
                    }),
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
