import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/document_submission.dart';
import '../providers/application_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/submission_provider.dart';
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

/// Mortgage Loan – Property Details step.
///
/// The applicant can add one or more properties; each property needs a name
/// and a single document upload (image or PDF). At least one complete property
/// is required to continue.
class Step5PropertyDetailsScreen extends StatefulWidget {
  const Step5PropertyDetailsScreen({super.key, this.fromPreview = false});

  /// When true, Back and Continue return to Preview (opened via Edit from Preview).
  final bool fromPreview;

  @override
  State<Step5PropertyDetailsScreen> createState() =>
      _Step5PropertyDetailsScreenState();
}

class _Step5PropertyDetailsScreenState
    extends State<Step5PropertyDetailsScreen> {
  final AdditionalDocumentsService _documentsService =
      AdditionalDocumentsService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _loadingLead = true;
  String? _leadId;
  String? _error;
  bool _isSaving = false;
  String? _authToken;

  /// Web-only picked bytes keyed by entry id (needed for multipart upload).
  final Map<String, Uint8List?> _pickedBytes = {};

  /// Per-entry property name controllers, keyed by entry id.
  final Map<String, TextEditingController> _nameControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAuthToken();
      _loadLeadId();
      _ensureAtLeastOneEntry();
    });
  }

  @override
  void dispose() {
    for (final c in _nameControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureAtLeastOneEntry() {
    final provider = context.read<SubmissionProvider>();
    final docs = provider.submission.propertyDetailsDocuments;
    if (docs == null || docs.entries.isEmpty) {
      provider.addPropertyDetailEntry();
    }
  }

  TextEditingController _controllerFor(PropertyDetailEntry entry) {
    final existing = _nameControllers[entry.id];
    if (existing != null) {
      if (existing.text != (entry.propertyName ?? '') &&
          !existing.selection.isValid) {
        existing.text = entry.propertyName ?? '';
      }
      return existing;
    }
    final controller = TextEditingController(text: entry.propertyName ?? '');
    _nameControllers[entry.id] = controller;
    return controller;
  }

  Future<void> _loadAuthToken() async {
    try {
      final token = await StorageService.instance.getAccessToken();
      if (token != null && mounted) setState(() => _authToken = token);
    } catch (_) {}
  }

  Future<void> _loadLeadId() async {
    final cachedLeadId = context.read<AuthProvider>().leadId;
    if (cachedLeadId != null) {
      setState(() {
        _leadId = cachedLeadId;
        _loadingLead = false;
      });
      return;
    }
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

  bool _isRemotePath(String? path) {
    final p = path ?? '';
    return p.startsWith('http') ||
        p.startsWith('/uploads/') ||
        p.startsWith('/api/');
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

  String _documentTypeFor(PropertyDetailEntry entry) =>
      'applicant_property_${entry.id}';

  Future<String?> _uploadIfNeeded(PropertyDetailEntry entry) async {
    final path = entry.path;
    if (path == null || path.trim().isEmpty) return null;
    if (_leadId == null) return path;
    if (_isRemotePath(path)) return path;
    final documentType = _documentTypeFor(entry);
    final fileName = _filenameFromPath(
      path,
      fallback: '${documentType}_${DateTime.now().millisecondsSinceEpoch}',
    );
    final bytes = kIsWeb ? _pickedBytes[entry.id] : null;
    final result = await _documentsService.uploadAdditionalDocument(
      filePath: path,
      fileName: fileName,
      documentType: documentType,
      leadId: _leadId!,
      fileBytes: bytes,
      displayName: (entry.propertyName ?? '').trim().isNotEmpty
          ? entry.propertyName!.trim()
          : null,
    );
    final url = (result['url'] as String?) ?? (result['path'] as String?);
    return url ?? path;
  }

  Future<void> _pickPdf(PropertyDetailEntry entry) async {
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
      if (!mounted) return;
      setState(() => _pickedBytes[entry.id] = bytes);
      context
          .read<SubmissionProvider>()
          .setPropertyDetailPath(entry.id, blobUrl, isPdf: true);
      return;
    }
    if (file.path == null) return;
    if (!mounted) return;
    context
        .read<SubmissionProvider>()
        .setPropertyDetailPath(entry.id, file.path!, isPdf: true);
  }

  Future<void> _pickImage(
    PropertyDetailEntry entry,
    ImageSource source,
  ) async {
    final picked = await _imagePicker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;
    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      final blobUrl = createBlobUrl(bytes, mimeType: 'image/jpeg');
      if (!mounted) return;
      setState(() => _pickedBytes[entry.id] = bytes);
      context
          .read<SubmissionProvider>()
          .setPropertyDetailPath(entry.id, blobUrl, isPdf: false);
      return;
    }
    if (!mounted) return;
    context
        .read<SubmissionProvider>()
        .setPropertyDetailPath(entry.id, picked.path, isPdf: false);
  }

  Future<void> _showPickerSheet(PropertyDetailEntry entry) async {
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
                    await _pickImage(entry, ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickImage(entry, ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('PDF'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickPdf(entry);
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

  void _addProperty() {
    if (_isSaving) return;
    context.read<SubmissionProvider>().addPropertyDetailEntry();
  }

  Future<void> _removeProperty(PropertyDetailEntry entry) async {
    if (_isSaving) return;
    final provider = context.read<SubmissionProvider>();
    final docs = provider.submission.propertyDetailsDocuments;
    // Best-effort: remove the previously-uploaded server document for this entry.
    if (_leadId != null && _isRemotePath(entry.path)) {
      try {
        await _documentsService.removeLeadDocumentsWithDocumentKey(
          _leadId!,
          _documentTypeFor(entry),
        );
      } catch (_) {}
    }
    _nameControllers.remove(entry.id)?.dispose();
    _pickedBytes.remove(entry.id);
    provider.removePropertyDetailEntry(entry.id);
    // Keep at least one entry visible.
    if (docs == null || docs.entries.length <= 1) {
      provider.addPropertyDetailEntry();
    }
  }

  ({bool ok, String? message}) _validateEntries(
    List<PropertyDetailEntry> entries,
  ) {
    final complete = entries.where((e) => e.isComplete).toList();
    if (complete.isEmpty) {
      return (
        ok: false,
        message:
            'Add at least one property with a name and an uploaded document.',
      );
    }
    // Any entry that has a name OR a file but is missing the other part is invalid.
    for (final e in entries) {
      final hasName = (e.propertyName ?? '').trim().isNotEmpty;
      final hasFile = e.path != null && e.path!.trim().isNotEmpty;
      if (hasName != hasFile) {
        return (
          ok: false,
          message:
              'Each property needs both a name and a document. Please complete or remove incomplete entries.',
        );
      }
    }
    final names = <String>{};
    for (final e in complete) {
      final key = e.propertyName!.trim().toLowerCase();
      if (!names.add(key)) {
        return (
          ok: false,
          message: 'Property names must be unique. "${e.propertyName!.trim()}" is repeated.',
        );
      }
    }
    return (ok: true, message: null);
  }

  Future<void> _saveAndProceed() async {
    if (_isSaving) return;
    final provider = context.read<SubmissionProvider>();
    final entries =
        provider.submission.propertyDetailsDocuments?.entries ?? const [];
    final validation = _validateEntries(List.of(entries));
    if (!validation.ok) {
      PremiumToast.showWarning(context, validation.message!);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final appProvider = context.read<ApplicationProvider>();
      for (final entry in List.of(entries)) {
        if (!entry.isComplete) continue;
        final uploaded = await _uploadIfNeeded(entry);
        if (uploaded != null) {
          provider.setPropertyDetailPath(
            entry.id,
            uploaded,
            isPdf: _isPdfPath(uploaded),
          );
        }
      }
      await appProvider.updateApplication(currentStep: 5);
      if (mounted) {
        PremiumToast.showSuccess(context, 'Property details saved.');
        context.go(
          widget.fromPreview
              ? AppRoutes.step6Preview
              : AppRoutes.step5PersonalData,
        );
      }
    } catch (e) {
      if (mounted) {
        PremiumToast.showError(
          context,
          'Failed to save property details: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleBack() {
    if (_isSaving) return;
    if (widget.fromPreview) {
      context.go(AppRoutes.step6Preview);
      return;
    }
    final submission = context.read<SubmissionProvider>().submission;
    // Property details follow the income docs; go back to the last income step.
    if (submission.hasCoApplicant) {
      context.go(AppRoutes.coApplicantSalarySlips);
    } else {
      context.go(AppRoutes.step5_1SalarySlips);
    }
  }

  Widget _buildPropertyCard(
    BuildContext context,
    PropertyDetailEntry entry,
    int index,
    int total,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final path = entry.path;
    final isPdf = _isPdfPath(path) || entry.isPdf;
    final hasFile = path != null && path.trim().isNotEmpty;
    final controller = _controllerFor(entry);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.home_work_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Property ${index + 1}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (total > 1)
                  IconButton(
                    tooltip: 'Remove property',
                    icon: const Icon(Icons.delete_outline),
                    color: AppTheme.errorColor,
                    onPressed: _isSaving ? null : () => _removeProperty(entry),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              enabled: !_isSaving,
              textInputAction: TextInputAction.next,
              onChanged: (value) => context
                  .read<SubmissionProvider>()
                  .updatePropertyName(entry.id, value),
              decoration: InputDecoration(
                labelText: 'Property name',
                hintText: 'e.g. Flat 302, Green Residency',
                prefixIcon: const Icon(Icons.label_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.35),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.picture_as_pdf,
                                          color: AppTheme.errorColor,
                                          size: 38,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'PDF selected',
                                          style:
                                              theme.textTheme.bodySmall?.copyWith(
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
                                            ? {
                                                'Authorization':
                                                    'Bearer $_authToken'
                                              }
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
            PremiumButton(
              label: !hasFile ? 'Upload document' : 'Replace document',
              icon: Icons.cloud_upload_outlined,
              isPrimary: true,
              onPressed: _isSaving ? null : () => _showPickerSheet(entry),
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
    final entries =
        submission.propertyDetailsDocuments?.entries ?? const <PropertyDetailEntry>[];

    return PreventCloseOnBack(
      onBack: _handleBack,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'Property Details',
                icon: Icons.home_work_outlined,
                showBackButton: true,
                onBackPressed: _isSaving ? null : _handleBack,
                showHomeButton: true,
                actions: const [
                  PreviewHeaderAction(
                    backRoute: AppRoutes.step5PropertyDetails,
                  ),
                ],
              ),
              if (_loadingLead)
                LinearProgressIndicator(
                  minHeight: 2,
                  color: AppTheme.primaryColor,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                ),
              const PremiumProgressIndicator(
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
                                color:
                                    AppTheme.primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
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
                                    'Property Details Required',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Add each property you are offering. Give every property a clear name and upload its document (sale deed, tax receipt, etc.) as an image or PDF. You can add as many properties as you need.',
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
                      for (int i = 0; i < entries.length; i++)
                        _buildPropertyCard(
                          context,
                          entries[i],
                          i,
                          entries.length,
                        ),
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        onPressed: _isSaving ? null : _addProperty,
                        icon: const Icon(Icons.add),
                        label: const Text('Add another property'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
