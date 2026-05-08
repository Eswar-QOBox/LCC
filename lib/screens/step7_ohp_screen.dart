import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/application_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/submission_provider.dart';
import '../services/additional_documents_service.dart';
import '../utils/api_config.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/blob_helper.dart';
import '../utils/local_file_persist.dart';
import '../widgets/app_header.dart';
import '../widgets/platform_image.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_toast.dart';
import '../widgets/premium_progress_indicator.dart';
import '../services/storage_service.dart';
import '../widgets/preview_header_action.dart';
import '../widgets/prevent_close_on_back.dart';

class Step7OhpScreen extends StatefulWidget {
  const Step7OhpScreen({super.key, this.fromPreview = false});

  /// When true, Back and Continue return to Preview (opened via Edit from Preview).
  final bool fromPreview;

  @override
  State<Step7OhpScreen> createState() => _Step7OhpScreenState();
}

class _Step7OhpScreenState extends State<Step7OhpScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final AdditionalDocumentsService _docsService = AdditionalDocumentsService();

  String? _path;
  bool _isPdf = false;
  Uint8List? _bytes;
  bool _isSaving = false;
  bool _loadingLead = true;
  String? _leadId;
  String? _authToken;

  bool _isBusinessWithCommonDocs() {
    final app = context.read<ApplicationProvider>().currentApplication;
    final loanType = (app?.loanType ?? '').toLowerCase();
    final businessLoanType =
        (context.read<SubmissionProvider>().submission.businessLoanType ?? '').toLowerCase();
    return loanType.contains('business') &&
        (businessLoanType == 'proprietor' || businessLoanType == 'partnership' || businessLoanType == 'pvt_limited');
  }

  bool _isRemotePath(String p) =>
      p.startsWith('http') || p.startsWith('/uploads/') || p.startsWith('/api/');

  String? _buildFullUrl(String? relativeUrl) {
    if (relativeUrl == null || relativeUrl.isEmpty) return null;
    if (relativeUrl.startsWith('http') || relativeUrl.startsWith('blob:')) return relativeUrl;
    var apiPath = relativeUrl;
    if (apiPath.startsWith('/uploads/') && !apiPath.contains('/uploads/files/')) {
      apiPath = apiPath.replaceFirst('/uploads/', '/api/v1/uploads/files/');
    } else if (!apiPath.startsWith('/api/')) {
      apiPath = '/api/v1$apiPath';
    }
    return '${ApiConfig.baseUrl}$apiPath';
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

  @override
  void initState() {
    super.initState();
    final submission = context.read<SubmissionProvider>().submission;
    _path = submission.businessDocuments?.ownHouseProof?.path;
    _isPdf = submission.businessDocuments?.ownHouseProof?.isPdf ?? false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAuthToken();
      _loadLeadId();
    });
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
    final cachedLeadId = context.read<AuthProvider>().leadId;
    if (cachedLeadId != null) {
      setState(() { _leadId = cachedLeadId; _loadingLead = false; });
      return;
    }
    setState(() => _loadingLead = true);
    try {
      final user = context.read<AuthProvider>().user;
      if (user == null) {
        setState(() {
          _leadId = null;
          _loadingLead = false;
        });
        return;
      }
      String? phoneNumber;
      if (user.email.endsWith('@phone.local')) {
        phoneNumber = user.email.split('@')[0];
      }
      final leadData = await _docsService.getLeadByUser(user.email, phone: phoneNumber);
      setState(() {
        _leadId = leadData?['id'] as String?;
        _loadingLead = false;
      });
    } catch (_) {
      setState(() {
        _leadId = null;
        _loadingLead = false;
      });
    }
  }

  Future<void> _showPickerSheet() async {
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
                    await _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('PDF'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickPdf();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(source: source, imageQuality: 90);
    if (picked == null || !mounted) return;

    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      final blobUrl = createBlobUrl(bytes, mimeType: 'image/jpeg');
      setState(() {
        _path = blobUrl;
        _bytes = bytes;
        _isPdf = false;
      });
      context.read<SubmissionProvider>().setOwnHouseProof(blobUrl, isPdf: false);
      return;
    }

    final storedPath = await persistLocalPathIfNeeded(
      picked.path,
      preferredExtension: 'jpg',
      subdir: 'lcc_ohp',
      prefix: 'ohp',
    );
    setState(() {
      _path = storedPath;
      _bytes = null;
      _isPdf = false;
    });
    context.read<SubmissionProvider>().setOwnHouseProof(storedPath, isPdf: false);
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    String path;
    Uint8List? bytes;
    if (kIsWeb) {
      bytes = result.files.single.bytes;
      if (bytes == null) {
        PremiumToast.showError(context, 'Unable to read PDF file');
        return;
      }
      path = createBlobUrl(bytes, mimeType: 'application/pdf');
    } else {
      if (result.files.single.path == null) {
        PremiumToast.showError(context, 'Unable to access file');
        return;
      }
      path = await persistLocalPathIfNeeded(
        result.files.single.path!,
        preferredExtension: 'pdf',
        subdir: 'lcc_ohp',
        prefix: 'ohp_pdf',
      );
    }

    setState(() {
      _path = path;
      _bytes = bytes;
      _isPdf = true;
    });
    context.read<SubmissionProvider>().setOwnHouseProof(path, isPdf: true);
  }

  String _filenameFromPath(String path, {required String fallback}) {
    if (path.contains('/')) return path.split('/').last;
    if (path.contains('\\')) return path.split('\\').last;
    return fallback;
  }

  Future<String?> _uploadIfNeeded({
    required String? path,
    required String documentType,
    required Uint8List? bytes,
  }) async {
    if (path == null || path.trim().isEmpty) return null;
    if (_leadId == null) return path;
    if (_isRemotePath(path)) return path;

    final fileName = _filenameFromPath(path, fallback: '${documentType}_${DateTime.now().millisecondsSinceEpoch}');
    final result = await _docsService.uploadAdditionalDocument(
      filePath: path,
      fileName: fileName,
      documentType: documentType,
      leadId: _leadId!,
      fileBytes: bytes?.toList(),
    );
    return (result['url'] as String?) ?? (result['path'] as String?) ?? path;
  }

  Future<void> _saveAndProceed() async {
    if (!_isBusinessWithCommonDocs()) {
      PremiumToast.showError(context, 'This step is only for Business Loan.');
      return;
    }
    if ((_path ?? '').isEmpty) {
      PremiumToast.showWarning(context, 'Please upload Own House Proof.');
      return;
    }
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      final uploaded = await _uploadIfNeeded(
        path: _path,
        documentType: 'applicant_ohp_own_house_proof',
        bytes: kIsWeb ? _bytes : null,
      );
      if (uploaded != null) {
        context.read<SubmissionProvider>().setOwnHouseProof(uploaded, isPdf: _isPdf);
      }
      // Track progress in application (backend only allows 1..7)
      await context.read<ApplicationProvider>().updateApplication(currentStep: 7);
      if (mounted) {
        PremiumToast.showSuccess(context, 'Own House Proof saved successfully!');
        if (widget.fromPreview) {
          context.go(AppRoutes.step6Preview);
        } else {
          context.go(AppRoutes.step5PersonalData);
        }
      }
    } catch (e) {
      if (mounted) PremiumToast.showError(context, 'Failed to save Own House Proof: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final path = _path;
    final hasFile = path != null && path.trim().isNotEmpty;
    final previewPath = hasFile ? (_buildFullUrl(path) ?? path) : null;

    return PreventCloseOnBack(
      onBack: () {
        if (_isSaving) return;
        if (widget.fromPreview) {
          context.go(AppRoutes.step6Preview);
          return;
        }
        context.go(AppRoutes.step6Msme);
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Own House Proof',
              icon: Icons.home_outlined,
              showBackButton: true,
              onBackPressed: _isSaving
                  ? null
                  : () {
                      if (widget.fromPreview) {
                        context.go(AppRoutes.step6Preview);
                        return;
                      }
                      context.go(AppRoutes.step6Msme);
                    },
              showHomeButton: true,
              actions: const [
                PreviewHeaderAction(backRoute: AppRoutes.step7Ohp),
              ],
            ),
            if (_loadingLead)
              LinearProgressIndicator(
                minHeight: 2,
                color: AppTheme.primaryColor,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              ),
            Builder(
              builder: (context) {
                final submission =
                    context.watch<SubmissionProvider>().submission;
                final businessLoanType =
                    (submission.businessLoanType ?? '').toLowerCase();
                final partnerCount =
                    submission.businessDocuments?.partnerCount ?? 0;
                final isPartnership = businessLoanType == 'partnership' || businessLoanType == 'pvt_limited';
                final totalSteps =
                    isPartnership && partnerCount > 0 ? (10 + 2 * partnerCount) : 10;
                final currentStep =
                    isPartnership && partnerCount > 0 ? (8 + 2 * partnerCount) : 9;
                return _buildProgressIndicator(
                  context,
                  currentStep: currentStep,
                  totalSteps: totalSteps,
                );
              },
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
                                  'Upload Own House Proof',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Photo or PDF is allowed.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header (icon + title + status)
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.home_outlined,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Own House Proof',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    fontSize:
                                        (theme.textTheme.titleLarge?.fontSize ?? 20) + 2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                                    color: hasFile ? AppTheme.successColor : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upload your Own House Proof (photo or PDF).',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Preview
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
                                          : _isPdf
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
                                                    onTap: () => _openImagePreview(previewPath),
                                                    child: PlatformImage(
                                                      imagePath: previewPath!,
                                                      fit: BoxFit.cover,
                                                      headers: _authToken != null
                                                          ? {'Authorization': 'Bearer $_authToken'}
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                    ),
                                    if (hasFile && !_isPdf)
                                      Positioned(
                                        left: 10,
                                        bottom: 10,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
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
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 18,
                                          ),
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
                            onPressed: _isSaving ? null : _showPickerSheet,
                          ),
                        ],
                      ),
                    ),
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
              top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.12)),
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


