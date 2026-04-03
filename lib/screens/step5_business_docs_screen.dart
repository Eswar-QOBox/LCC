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
class Step5BusinessDocsScreen extends StatefulWidget {
  const Step5BusinessDocsScreen({super.key, this.fromPreview = false});

  /// When true, Back and Continue return to Preview (opened via Edit from Preview).
  final bool fromPreview;

  @override
  State<Step5BusinessDocsScreen> createState() => _Step5BusinessDocsScreenState();
}

class _Step5BusinessDocsScreenState extends State<Step5BusinessDocsScreen> {
  final AdditionalDocumentsService _documentsService = AdditionalDocumentsService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _loadingLead = true;
  String? _leadId;
  String? _error;

  bool _isSaving = false;
  String? _authToken;

  // Web: store picked bytes so we can upload.
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
    const docKeys = ['company_pan', 'partnership_deed', 'moa', 'aoa', 'gst', 'labour'];
    for (final key in docKeys) {
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
      if (token != null && mounted) {
        setState(() => _authToken = token);
      }
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

  bool _isPdfPath(String? path) => (path ?? '').toLowerCase().endsWith('.pdf');

  IconData _iconForDocKey(String key) {
    switch (key) {
      case 'company_pan':
        return Icons.badge;
      case 'partnership_deed':
        return Icons.description_outlined;
      case 'moa':
        return Icons.description;
      case 'aoa':
        return Icons.article_outlined;
      case 'gst':
        return Icons.receipt_long;
      case 'labour':
        return Icons.badge_outlined;
      default:
        return Icons.upload_file;
    }
  }

  String _hintForDocKey(String key) {
    switch (key) {
      case 'company_pan':
        return 'Upload your Company PAN card (photo or PDF).';
      case 'partnership_deed':
        return 'Upload your Partnership Deed (photo or PDF).';
      case 'moa':
        return 'Upload Memorandum of Association (photo or PDF).';
      case 'aoa':
        return 'Upload Articles of Association (photo or PDF).';
      case 'gst':
        return 'Upload your GST registration certificate.';
      case 'labour':
        return 'Upload your Labour certificate.';
      default:
        return 'Upload the document.';
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
                    // Keep close button red for consistency across previews.
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
        if (mounted) {
          PremiumToast.showError(context, 'Unable to read PDF. Please try again.');
        }
        return;
      }
      final blobUrl = createBlobUrl(bytes, mimeType: 'application/pdf');
      setState(() {
        _pickedBytes[key] = bytes;
      });
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
      setState(() {
        _pickedBytes[key] = bytes;
      });
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

  void _setDocPathForKey(String key, String path, {required bool isPdf}) {
    final provider = context.read<SubmissionProvider>();
    switch (key) {
      case 'company_pan':
        provider.setCompanyPanCard(path, isPdf: isPdf);
        break;
      case 'partnership_deed':
        provider.setPartnershipDeed(path, isPdf: isPdf);
        break;
      case 'moa':
        provider.setMoa(path, isPdf: isPdf);
        break;
      case 'aoa':
        provider.setAoa(path, isPdf: isPdf);
        break;
      case 'gst':
        provider.setGstRegistration(path, isPdf: isPdf);
        break;
      case 'labour':
        provider.setLabourCertificate(path, isPdf: isPdf);
        break;
    }
  }

  String? _getDocPath(DocumentSubmission submission, String key) {
    final b = submission.businessDocuments;
    switch (key) {
      case 'company_pan':
        return b?.companyPanCard?.path;
      case 'partnership_deed':
        return b?.partnershipDeed?.path;
      case 'moa':
        return b?.moa?.path;
      case 'aoa':
        return b?.aoa?.path;
      case 'gst':
        return b?.gstRegistration?.path;
      case 'labour':
        return b?.labourCertificate?.path;
      default:
        return null;
    }
  }

  bool _isRemotePath(String? path) {
    final p = path ?? '';
    return p.startsWith('http') || p.startsWith('/uploads/') || p.startsWith('/api/');
  }

  /// Run same OCR as Aadhaar/PAN/professional docs. Skips on web and for remote paths.
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
          if (kDebugMode) debugPrint('[BusinessDocs] PDF render for OCR failed: $e');
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
      if (kDebugMode) debugPrint('[BusinessDocs] OCR failed: $e');
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

  static String _titleForDocKey(String key) {
    switch (key) {
      case 'company_pan': return 'Company PAN Card';
      case 'partnership_deed': return 'Partnership Deed';
      case 'moa': return 'MOA';
      case 'aoa': return 'AOA';
      case 'gst': return 'GST Registration';
      case 'labour': return 'Labour Certificate';
      default: return key;
    }
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

  Future<String?> _uploadIfNeeded({
    required String key,
    required String? path,
    required String documentType,
  }) async {
    if (path == null || path.trim().isEmpty) return null;
    if (_leadId == null) return path; // cannot upload; keep local/blob
    if (_isRemotePath(path)) return path;

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

  Future<void> _saveAndProceed() async {
    final submission = context.read<SubmissionProvider>().submission;
    final businessLoanType = (submission.businessLoanType ?? '').toLowerCase();
    final isPartnership = businessLoanType == 'partnership';
    final isPvtLimited = businessLoanType == 'pvt_limited';
    final companyPan = _getDocPath(submission, 'company_pan');
    final partnershipDeed = _getDocPath(submission, 'partnership_deed');
    final moa = _getDocPath(submission, 'moa');
    final aoa = _getDocPath(submission, 'aoa');
    if (isPartnership &&
        ((companyPan == null || companyPan.trim().isEmpty) ||
            (partnershipDeed == null || partnershipDeed.trim().isEmpty))) {
      PremiumToast.showWarning(
        context,
        'Please upload Company PAN Card and Partnership Deed.',
      );
      return;
    }
    if (isPvtLimited &&
        ((companyPan == null || companyPan.trim().isEmpty) ||
            (moa == null || moa.trim().isEmpty) ||
            (aoa == null || aoa.trim().isEmpty))) {
      PremiumToast.showWarning(
        context,
        'Please upload Company PAN Card, MOA and AOA.',
      );
      return;
    }
    // GST / Labour / UDYAM: any one is enough; UDYAM can be uploaded on the next step
    // if you skip both here (step6 enforces at least one of the three overall).

    // On mobile: require OCR success for every uploaded document (remote paths treated as already verified).
    if (!kIsWeb) {
      final provider = context.read<SubmissionProvider>();
      const docKeys = ['company_pan', 'partnership_deed', 'moa', 'aoa', 'gst', 'labour'];
      final issues = <String>[];
      for (final key in docKeys) {
        final path = _getDocPath(provider.submission, key);
        if (path == null || path.trim().isEmpty) continue;
        if (_isRemotePath(path)) continue;
        if (_ocrCompleteByKey[key] != true) {
          final issue = _ocrIssueByKey[key] != null
              ? '${_titleForDocKey(key)}: ${_ocrIssueByKey[key]}'
              : '${_titleForDocKey(key)}: OCR not run or failed';
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
      // Upload via AdditionalDocumentsService so backend stores them under additional-doc folders.
      final provider = context.read<SubmissionProvider>();

      if (isPartnership) {
        final uploadedCompanyPan = await _uploadIfNeeded(
          key: 'company_pan',
          path: provider.submission.businessDocuments?.companyPanCard?.path,
          documentType: 'applicant_company_pan_card',
        );
        if (uploadedCompanyPan != null) {
          provider.setCompanyPanCard(uploadedCompanyPan, isPdf: _isPdfPath(uploadedCompanyPan));
        }

        final uploadedDeed = await _uploadIfNeeded(
          key: 'partnership_deed',
          path: provider.submission.businessDocuments?.partnershipDeed?.path,
          documentType: 'applicant_partnership_deed',
        );
        if (uploadedDeed != null) {
          provider.setPartnershipDeed(uploadedDeed, isPdf: _isPdfPath(uploadedDeed));
        }
      }

      if (isPvtLimited) {
        final uploadedCompanyPan = await _uploadIfNeeded(
          key: 'company_pan',
          path: provider.submission.businessDocuments?.companyPanCard?.path,
          documentType: 'applicant_company_pan_card',
        );
        if (uploadedCompanyPan != null) {
          provider.setCompanyPanCard(uploadedCompanyPan, isPdf: _isPdfPath(uploadedCompanyPan));
        }

        final uploadedMoa = await _uploadIfNeeded(
          key: 'moa',
          path: provider.submission.businessDocuments?.moa?.path,
          documentType: 'applicant_moa',
        );
        if (uploadedMoa != null) {
          provider.setMoa(uploadedMoa, isPdf: _isPdfPath(uploadedMoa));
        }

        final uploadedAoa = await _uploadIfNeeded(
          key: 'aoa',
          path: provider.submission.businessDocuments?.aoa?.path,
          documentType: 'applicant_aoa',
        );
        if (uploadedAoa != null) {
          provider.setAoa(uploadedAoa, isPdf: _isPdfPath(uploadedAoa));
        }
      }

      final uploadedGst = await _uploadIfNeeded(
        key: 'gst',
        path: provider.submission.businessDocuments?.gstRegistration?.path,
        documentType: 'applicant_gst_registration',
      );
      if (uploadedGst != null) {
        provider.setGstRegistration(uploadedGst, isPdf: _isPdfPath(uploadedGst));
      }

      final uploadedLabour = await _uploadIfNeeded(
        key: 'labour',
        path: provider.submission.businessDocuments?.labourCertificate?.path,
        documentType: 'applicant_labour_certificate',
      );
      if (uploadedLabour != null) {
        provider.setLabourCertificate(uploadedLabour, isPdf: _isPdfPath(uploadedLabour));
      }

      if (mounted) {
        // Track progress in application (backend only allows 1..7)
        await context.read<ApplicationProvider>().updateApplication(currentStep: 7);
        PremiumToast.showSuccess(context, 'GST/Labour saved successfully!');
        if (widget.fromPreview) {
          context.go(AppRoutes.step6Preview);
        } else {
          context.go(AppRoutes.step6Msme);
        }
      }
    } catch (e) {
      if (mounted) {
        PremiumToast.showError(
          context,
          'Failed to save business documents: ${e.toString()}',
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

    final businessLoanType = (submission.businessLoanType ?? '').toLowerCase();
    final partnerCount = submission.businessDocuments?.partnerCount ?? 0;
    final isPartnership = businessLoanType == 'partnership';
    final isPvtLimited = businessLoanType == 'pvt_limited';
    final isPartnerFlow = isPartnership || isPvtLimited;
    final cards = <Map<String, String>>[
      if (isPartnership) {'key': 'company_pan', 'title': 'Company PAN\nCard'},
      if (isPartnership) {'key': 'partnership_deed', 'title': 'Partnership\nDeed'},
      if (isPvtLimited) {'key': 'company_pan', 'title': 'Company PAN\nCard'},
      if (isPvtLimited) {'key': 'moa', 'title': 'MOA'},
      if (isPvtLimited) {'key': 'aoa', 'title': 'AOA'},
      {'key': 'gst', 'title': 'GST\nRegistration'},
      {'key': 'labour', 'title': 'Labour\nCertificate'},
    ];
    final totalSteps =
        isPartnerFlow && partnerCount > 0 ? (10 + 2 * partnerCount) : 10;
    final currentStep =
        isPartnerFlow && partnerCount > 0 ? (6 + 2 * partnerCount) : 7;

    return PreventCloseOnBack(
      onBack: () {
        if (_isSaving) return;
        if (widget.fromPreview) {
          context.go(AppRoutes.step6Preview);
          return;
        }
        context.go(
          isPartnerFlow && partnerCount > 0
              ? '${AppRoutes.partnerPan}?i=$partnerCount'
              : AppRoutes.step4BankStatement,
        );
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'GST / Labour / UDYAM',
              icon: Icons.receipt_long,
              showBackButton: true,
              onBackPressed: _isSaving
                  ? null
                  : () {
                      if (widget.fromPreview) {
                        context.go(AppRoutes.step6Preview);
                        return;
                      }
                      context.go(
                        isPartnerFlow && partnerCount > 0
                            ? '${AppRoutes.partnerPan}?i=$partnerCount'
                            : AppRoutes.step4BankStatement,
                      );
                    },
              showHomeButton: true,
              actions: const [
                PreviewHeaderAction(backRoute: AppRoutes.step5BusinessDocs),
              ],
            ),
            if (_loadingLead)
              LinearProgressIndicator(
                minHeight: 2,
                color: AppTheme.primaryColor,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              ),
            _buildProgressIndicator(context, currentStep: currentStep, totalSteps: totalSteps),
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
                            child: Icon(
                              Icons.info_outline,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Required for Business Loan',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isPartnership
                                      ? 'Upload Company PAN Card and Partnership Deed. For GST, Labour licence, or UDYAM / MSME: only one document is required in total—you can upload GST or Labour here, or UDYAM on the next step. Photos or PDFs.'
                                      : isPvtLimited
                                          ? 'Upload Company PAN Card, MOA, and AOA. For GST, Labour licence, or UDYAM / MSME: only one document is required in total—you can upload GST or Labour here, or UDYAM on the next step. Photos or PDFs.'
                                          : 'GST, Labour licence, and UDYAM / MSME are not all required—upload any one. You can use GST or Labour here, or tap Continue and upload UDYAM on the next step. Photos or PDFs.',
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
                    ...cards.map((c) {
                      final key = c['key']!;
                      final title = c['title']!;
                      final path = _getDocPath(submission, key);
                      final isPdf = _isPdfPath(path);
                      final hasFile = path != null && path.trim().isNotEmpty;
                      final isUploaded = hasFile;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PremiumCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Header (icon + title + status)
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
                                        fontSize:
                                            (theme.textTheme.titleLarge?.fontSize ?? 20) + 2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isUploaded
                                          ? AppTheme.successColor.withValues(alpha: 0.12)
                                          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: (isUploaded ? AppTheme.successColor : colorScheme.outline)
                                            .withValues(alpha: 0.18),
                                      ),
                                    ),
                                    child: Text(
                                      isUploaded ? 'UPLOADED' : 'PENDING',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: isUploaded
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

                              // 1) Preview (image/PDF/empty)
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
                                        if (hasFile && !isPdf)
                                          Positioned(
                                            left: 10,
                                            bottom: 10,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.55),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                'Tap to preview',
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
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
                                              decoration: BoxDecoration(
                                                color: AppTheme.successColor,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.18),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
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

                              // Upload button
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

  Widget _buildProgressIndicator(
    BuildContext context, {
    required int currentStep,
    required int totalSteps,
  }) {
    return PremiumProgressIndicator(
      currentStep: currentStep,
      totalSteps: totalSteps,
      maxVisibleSteps: 7,
    );
  }
}

