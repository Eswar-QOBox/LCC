import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/application_provider.dart';
import '../providers/submission_provider.dart';
import '../services/additional_documents_service.dart';
import '../services/ocr_service.dart';
import '../services/storage_service.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/blob_helper.dart';
import '../utils/ocr_pdf.dart';
import '../widgets/app_header.dart';
import '../widgets/platform_image.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_progress_indicator.dart';
import '../widgets/premium_toast.dart';
import '../widgets/prevent_close_on_back.dart';

class CoApplicantFirmKycScreen extends StatefulWidget {
  const CoApplicantFirmKycScreen({
    super.key,
    required this.firmType,
    this.fromPreview = false,
  });

  final String firmType;
  final bool fromPreview;

  @override
  State<CoApplicantFirmKycScreen> createState() =>
      _CoApplicantFirmKycScreenState();
}

class _CoApplicantFirmKycScreenState extends State<CoApplicantFirmKycScreen> {
  final AdditionalDocumentsService _documentsService =
      AdditionalDocumentsService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isSaving = false;
  String? _leadId;
  String? _authToken;

  final Map<String, Uint8List?> _pickedBytes = {};
  final Map<String, bool> _ocrCompleteByKey = {};
  final Map<String, String?> _ocrIssueByKey = {};

  bool get _isPartnership => widget.firmType == 'partnership';

  static const List<Map<String, String>> _kycCards = [
    {'key': 'kyc_photo_1', 'title': 'Photo 1'},
    {'key': 'kyc_photo_2', 'title': 'Photo 2'},
    {'key': 'kyc_pan', 'title': 'PAN Card'},
    {
      'key': 'kyc_address_proof',
      'title': 'Address Proof\n(Aadhaar / Passport /\nVoter ID / DL)',
    },
  ];

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
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.user;
      if (user == null) return;
      String? phone;
      if (user.email.endsWith('@phone.local')) {
        phone = user.email.split('@')[0];
      }
      final leadData =
          await _documentsService.getLeadByUser(user.email, phone: phone);
      if (mounted) setState(() => _leadId = leadData?['id'] as String?);
    } catch (_) {}
  }

  bool _isPdfPath(String? path) =>
      (path ?? '').toLowerCase().endsWith('.pdf');

  bool _isRemotePath(String? path) {
    final p = path ?? '';
    return p.startsWith('http') ||
        p.startsWith('/uploads/') ||
        p.startsWith('/api/');
  }

  String? _getDocPath(String key) {
    return context
        .read<SubmissionProvider>()
        .submission
        .coApplicantFirmDocuments
        ?.getField(key);
  }

  void _setDocPath(String key, String path, {required bool isPdf}) {
    context.read<SubmissionProvider>().setCoApplicantFirmDocument(key, path);
  }

  IconData _iconForKey(String key) {
    switch (key) {
      case 'kyc_photo_1':
      case 'kyc_photo_2':
        return Icons.photo_camera;
      case 'kyc_pan':
        return Icons.credit_card;
      case 'kyc_address_proof':
        return Icons.home_outlined;
      default:
        return Icons.upload_file;
    }
  }

  Future<void> _performDocumentOcr(
      String key, String path, bool isPdf) async {
    if (kIsWeb) return;
    if (_isRemotePath(path)) return;
    if (path.startsWith('blob:')) return;
    try {
      Uint8List? imageBytes;
      if (isPdf && path.toLowerCase().endsWith('.pdf') && OcrPdf.isSupported) {
        try {
          final count = await OcrPdf.getPageCount(path);
          if (count > 0) {
            imageBytes =
                await OcrPdf.renderPageToJpegBytes(path, pageIndex: 0);
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[FirmKYC] PDF render for OCR failed: $e');
          }
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
          'Could not read document text. Re-capture with better lighting.',
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FirmKYC] OCR failed: $e');
      if (mounted) {
        setState(() {
          _ocrCompleteByKey[key] = false;
          _ocrIssueByKey[key] = e.toString();
        });
      }
    }
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
      if (bytes == null) return;
      final blobUrl = createBlobUrl(bytes, mimeType: 'application/pdf');
      setState(() => _pickedBytes[key] = bytes);
      _setDocPath(key, blobUrl, isPdf: true);
      return;
    }
    if (file.path == null) return;
    _setDocPath(key, file.path!, isPdf: true);
    await _performDocumentOcr(key, file.path!, true);
  }

  Future<void> _pickImage(String key, ImageSource source) async {
    final picked =
        await _imagePicker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;
    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      final blobUrl = createBlobUrl(bytes, mimeType: 'image/jpeg');
      setState(() => _pickedBytes[key] = bytes);
      _setDocPath(key, blobUrl, isPdf: false);
      return;
    }
    _setDocPath(key, picked.path, isPdf: false);
    await _performDocumentOcr(key, picked.path, false);
  }

  Future<void> _showPickerSheet(String key) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
                    Navigator.of(ctx).pop();
                    await _pickImage(key, ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _pickImage(key, ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('PDF'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
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
                        child:
                            Icon(Icons.close, color: Colors.white, size: 20),
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
  }) async {
    if (path == null || path.trim().isEmpty) return null;
    if (_leadId == null) return path;
    if (_isRemotePath(path)) return path;

    final documentType = 'coapplicant_firm_$key';
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
    final provider = context.read<SubmissionProvider>();

    if (_isSaving) return;
    setState(() => _isSaving = true);

    final appProvider = context.read<ApplicationProvider>();
    final router = GoRouter.of(context);

    try {
      for (final card in _kycCards) {
        final key = card['key']!;
        final path = _getDocPath(key);
        final uploaded = await _uploadIfNeeded(key: key, path: path);
        if (uploaded != null && uploaded != path) {
          provider.setCoApplicantFirmDocument(key, uploaded);
        }
      }

      if (mounted) {
        if (!widget.fromPreview) {
          await appProvider.updateApplication(currentStep: 7);
        }
        if (mounted) {
          PremiumToast.showSuccess(context, 'KYC documents saved.');
          if (widget.fromPreview) {
            router.go(AppRoutes.step6Preview);
          } else {
            router.go(AppRoutes.step5PersonalData);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        PremiumToast.showError(
          context,
          'Failed to save KYC documents: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kycLabel =
        _isPartnership ? 'Partners KYC' : 'Authorized Person KYC';

    final backRoute = widget.fromPreview
        ? AppRoutes.step6Preview
        : '${AppRoutes.coApplicantFirmDocs}?firmType=${widget.firmType}';

    return PreventCloseOnBack(
      onBack: () {
        if (_isSaving) return;
        context.go(backRoute);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: kycLabel,
                icon: Icons.badge_outlined,
                showBackButton: true,
                onBackPressed: () {
                  if (_isSaving) return;
                  context.go(backRoute);
                },
                showHomeButton: true,
              ),
              const PremiumProgressIndicator(
                currentStep: 7,
                totalSteps: 11,
                maxVisibleSteps: 7,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionCard(context),
                      const SizedBox(height: 32),
                      PremiumButton(
                        label: _isSaving ? 'Saving...' : 'Save & Continue',
                        isPrimary: true,
                        isLoading: _isSaving,
                        onPressed: _isSaving ? null : _saveAndProceed,
                      ),
                      const SizedBox(height: 20),
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

  Widget _buildSectionCard(BuildContext context) {
    final theme = Theme.of(context);
    final kycLabel =
        _isPartnership ? 'Partners KYC' : 'Authorized Person KYC';

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.badge_outlined,
                    color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                kycLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: _kycCards
                .map((c) => _buildDocCard(context, c['key']!, c['title']!))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard(BuildContext context, String key, String title) {
    final submission = context.watch<SubmissionProvider>().submission;
    final path = submission.coApplicantFirmDocuments?.getField(key);
    final hasDoc = path != null && path.trim().isNotEmpty;
    final isPdf = _isPdfPath(path);
    final ocrOk = _ocrCompleteByKey[key] == true;
    final isRemote = _isRemotePath(path);
    final showOcrBadge =
        hasDoc && !kIsWeb && !isRemote && !path.startsWith('blob:');

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => _showPickerSheet(key),
      child: Container(
        decoration: BoxDecoration(
          color: hasDoc
              ? AppTheme.primaryColor.withValues(alpha: 0.07)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasDoc
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : colorScheme.outline.withValues(alpha: 0.2),
            width: hasDoc ? 1.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasDoc && !isPdf)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openImagePreview(path),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: PlatformImage(
                            imagePath: path,
                            fit: BoxFit.cover,
                            headers: _authToken != null
                                ? {'Authorization': 'Bearer $_authToken'}
                                : null,
                          ),
                        ),
                      ),
                    )
                  else if (hasDoc && isPdf)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.picture_as_pdf,
                              color: AppTheme.errorColor, size: 40),
                          const SizedBox(height: 4),
                          Text(
                            'PDF',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _iconForKey(key),
                            color: colorScheme.onSurfaceVariant,
                            size: 36,
                          ),
                          const SizedBox(height: 6),
                          Icon(
                            Icons.add_circle_outline,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: hasDoc ? FontWeight.w600 : FontWeight.normal,
                      color: hasDoc
                          ? AppTheme.primaryColor
                          : colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (hasDoc)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () {
                    context
                        .read<SubmissionProvider>()
                        .setCoApplicantFirmDocument(key, null);
                    setState(() {
                      _pickedBytes.remove(key);
                      _ocrCompleteByKey.remove(key);
                      _ocrIssueByKey.remove(key);
                    });
                  },
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 13),
                  ),
                ),
              ),
            if (showOcrBadge)
              Positioned(
                bottom: 32,
                right: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: ocrOk
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    ocrOk ? Icons.check : Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
