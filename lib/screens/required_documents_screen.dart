import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'simple_camera_capture_screen.dart';
import '../models/additional_document.dart';
import '../services/additional_documents_service.dart';
import '../providers/auth_provider.dart';
import '../utils/app_strings.dart';
import '../utils/app_theme.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_toast.dart';
import '../utils/local_file_persist.dart';

class RequiredDocumentsScreen extends StatefulWidget {
  const RequiredDocumentsScreen({super.key});

  @override
  State<RequiredDocumentsScreen> createState() =>
      _RequiredDocumentsScreenState();
}

class _RequiredDocumentsScreenState extends State<RequiredDocumentsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final AdditionalDocumentsService _documentsService =
      AdditionalDocumentsService();
  final ImagePicker _imagePicker = ImagePicker();

  List<DocumentRequirement> _requiredDocuments = [];
  List<UploadedDocument> _uploadedDocuments = [];
  bool _isLoading = true;
  String? _error;
  String? _leadId;
  String? _userId;
  final Map<String, bool> _uploadingStatus = {};
  /// After a successful **re-upload** (replacement file), upload stays disabled while status is pending so users do not tap again thinking nothing happened.
  final Set<String> _replacementSubmittedIds = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    // Ensure error is null at start
    _error = null;
    _isLoading = true;
    // Load documents after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDocuments();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadDocuments();
    }
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      _userId = user.id;

      // Get lead information - only returns lead if it matches user's email
      // Returns null if no lead found (valid empty state), throws only for actual errors
      Map<String, dynamic>? leadData;
      try {
      String? phoneNumber;
      if (user.email.endsWith('@phone.local')) {
        phoneNumber = user.email.split('@')[0];
      }

      if (kDebugMode) {
        print('Loading documents for user: ${user.email}, phone: $phoneNumber');
      }
      
      leadData = await _documentsService.getLeadByUser(
        user.email,
        phone: phoneNumber,
      );
        var resolvedId = leadData?['id']?.toString();
        if (resolvedId == null || resolvedId.isEmpty) {
          resolvedId = authProvider.leadId;
        }
        _leadId = resolvedId;

        if (kDebugMode) {
          print('Lead ID retrieved: $_leadId (fromLead=${leadData?['id']}, authLead=${authProvider.leadId})');
        }
      } catch (e) {
        // Only actual errors reach here (network, auth, server errors)
        // "Lead not found" returns null, not an exception
        String errorMessage = e.toString().replaceFirst('Exception: ', '');

        if (kDebugMode) {
          print('Error loading lead information: $e');
          print('Error message: $errorMessage');
        }

        // Double-check: if error message contains "not found", treat as empty state
        if (errorMessage.toLowerCase().contains('lead not found') ||
            errorMessage.toLowerCase().contains('not found for your email')) {
          if (kDebugMode) {
            print('Treating "not found" as empty state instead of error');
          }
          setState(() {
            _error = null; // No error, just empty state
            _requiredDocuments = [];
            _uploadedDocuments = [];
            _isLoading = false;
          });
          return;
        }

        // For actual errors, show error state
        if (errorMessage.isEmpty) {
          errorMessage =
              'Failed to get lead information. Please try again later.';
        }

        setState(() {
          _error = errorMessage;
          _requiredDocuments = [];
          _isLoading = false;
        });
        return;
      }

      // No CRM lead id: cannot load lead documents from API
      if (_leadId == null || _leadId!.isEmpty) {
        if (kDebugMode) {
          print(
            'No lead found - showing empty state (user logged in but no lead record)',
          );
        }
        setState(() {
          _error = null; // No error, just empty state
          _requiredDocuments = [];
          _uploadedDocuments = [];
          _isLoading = false;
        });
        return;
      }

      // Get document requirements (may be empty; rejected CRM docs still surface via lead-documents API)
      final requirements = leadData != null
          ? (leadData['additionalDocumentRequirements'] ??
                  leadData['additional_documents'] ??
                  leadData['additionalDocuments']) as List<dynamic>? ??
              []
          : <dynamic>[];

      // Get uploaded documents
      List<UploadedDocument> uploadedDocs = [];
      try {
        uploadedDocs = await _documentsService.getLeadDocuments(_leadId!);
      } catch (e) {
        // If getting uploaded documents fails, continue with empty list
        // This allows the screen to still show required documents even if uploads can't be fetched
        uploadedDocs = [];
      }
      _uploadedDocuments = uploadedDocs;

      // Create document requirements list
      final uploadedDocTypes = uploadedDocs
          .map((doc) => doc.documentType)
          .toList();
      final requiredDocs = requirements
          .map((id) {
            try {
              return DocumentRequirement.fromId(id as String, uploadedDocTypes);
            } catch (e) {
              // Skip invalid document requirement IDs
              return null;
            }
          })
          .whereType<DocumentRequirement>()
          .toList();

      // Add missing requirements for verified and rejected uploads
      // This ensures they appear in the UI even if removed from backend requirements
      for (var upload in uploadedDocs) {
        // skip if already in requirements
        if (requiredDocs.any((req) => leadDocumentTypeMatches(req.id, upload.documentType))) {
          continue;
        }

        // Add if verified, rejected, or still pending on server (so CRM pipeline docs appear without extra_requirements rows)
        if (upload.status == DocumentStatus.verified ||
            upload.status == DocumentStatus.rejected ||
            upload.status == DocumentStatus.pending) {
          
          if (kDebugMode) {
             print('Adding synthetic requirement for ${upload.status} document: ${upload.documentType}');
          }
          
          final syntheticReq = DocumentRequirement.fromId(
            upload.documentType, 
            uploadedDocTypes
          );
          
          // Force status update from upload
          syntheticReq.status = upload.status;
          
          requiredDocs.add(syntheticReq);
        }
      }

      // Re-enable upload after admin verifies or rejects again.
      for (final id in List<String>.from(_replacementSubmittedIds)) {
        final st = _latestUploadStatusForRequirementId(id, uploadedDocs);
        if (st == DocumentStatus.verified || st == DocumentStatus.rejected) {
          _replacementSubmittedIds.remove(id);
        }
      }

      setState(() {
        _requiredDocuments = requiredDocs;
        _isLoading = false;
      });
    } catch (e) {
      // Handle any other errors
      String errorMessage = e.toString().replaceFirst('Exception: ', '');

      if (kDebugMode) {
        print('Unexpected error in _loadDocuments: $e');
        print('Error message: $errorMessage');
      }

      // Check if it's a "not found" error - treat as empty state
      if (errorMessage.toLowerCase().contains('lead not found') ||
          errorMessage.toLowerCase().contains('not found for your email')) {
        if (kDebugMode) {
          print('Treating "not found" in outer catch as empty state');
        }
        setState(() {
          _error = null; // No error, just empty state
          _requiredDocuments = [];
          _uploadedDocuments = [];
          _isLoading = false;
        });
        return;
      }

      // Check if it's a provider/widget tree error (shouldn't happen but handle gracefully)
      if (errorMessage.toLowerCase().contains('provider') ||
          errorMessage.toLowerCase().contains('not found in widget tree')) {
        errorMessage = 'Application error. Please restart the app.';
      } else if (errorMessage.isEmpty) {
        errorMessage = 'An unexpected error occurred. Please try again later.';
      }

      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadDocument(DocumentRequirement requirement) async {
    if (_leadId == null || _userId == null) {
      _showError('Lead information not available');
      return;
    }

    final wasReupload = _latestRejectedForRequirement(requirement) != null;

    setState(() {
      _uploadingStatus[requirement.id] = true;
    });

    try {
      XFile? pickedFile;

      // Show file source selection
      final source = await _showFileSourceDialog();
      if (source == null) {
        setState(() {
          _uploadingStatus[requirement.id] = false;
        });
        return;
      }

      if (source == 'camera') {
        if (kIsWeb) {
          // On web, still use system camera
          pickedFile = await _imagePicker.pickImage(
            source: ImageSource.camera,
            imageQuality: 50,
            requestFullMetadata: false,
          );
        } else {
          // On mobile, use in-app simple camera UI (no grids)
          if (!mounted) return;
          pickedFile = await Navigator.of(context).push<XFile?>(
            MaterialPageRoute(
              builder: (_) => const SimpleCameraCaptureScreen(),
            ),
          );
        }
      } else if (source == 'gallery') {
        pickedFile = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 50,
        );
      } else if (source == 'file') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        );
        if (result != null && result.files.single.path != null) {
          pickedFile = XFile(result.files.single.path!);
        }
      }

      if (pickedFile == null) {
        setState(() {
          _uploadingStatus[requirement.id] = false;
        });
        return;
      }

      // Validate file size (50MB limit)
      final fileSize = await pickedFile.length();
      if (fileSize > 50 * 1024 * 1024) {
        _showError('File size must be less than 50MB');
        setState(() {
          _uploadingStatus[requirement.id] = false;
        });
        return;
      }

      // Read file bytes for web
      List<int>? fileBytes;
      String filePath = pickedFile.path;

      if (kIsWeb) {
        fileBytes = await pickedFile.readAsBytes();
        // For web, we need to use a dummy path since we're using bytes
        filePath = pickedFile.name;
      }

      // Optional crop for images on mobile (skip for web / PDFs)
      String finalPath = filePath;
      if (!kIsWeb &&
          !filePath.toLowerCase().endsWith('.pdf') &&
          (fileBytes == null)) {
        final croppedPath = await _cropImage(filePath);
        if (croppedPath != null && croppedPath.isNotEmpty) {
          finalPath = croppedPath;
        }
        // Persist to stable temp location so later operations don't lose the file.
        finalPath = await persistLocalPathIfNeeded(
          finalPath,
          preferredExtension: 'jpg',
          subdir: 'lcc_required_documents',
          prefix: 'doc_${requirement.id}',
        );
      }

      // Upload document
      await _documentsService.uploadAdditionalDocument(
        filePath: finalPath,
        fileName: pickedFile.name,
        documentType: requirement.id,
        leadId: _leadId!,
        fileBytes: fileBytes,
        displayName: _displayNameForReupload(requirement),
      );

      // Refresh documents
      await _loadDocuments();

      if (mounted) {
        if (wasReupload) {
          setState(() {
            _replacementSubmittedIds.add(requirement.id);
          });
        }
        PremiumToast.showSuccess(
          context,
          wasReupload
              ? 'Replacement submitted for review.'
              : 'Document uploaded successfully',
        );
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('413')) {
        errorMessage = 'File is too large for the server. Please try a smaller file.';
      } else {
        errorMessage = 'Failed to upload document: ${errorMessage.replaceFirst('Exception: ', '')}';
      }
      _showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _uploadingStatus[requirement.id] = false;
        });
      }
    }
  }

  Future<String?> _showFileSourceDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.selectSource),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text(AppStrings.camera),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text(AppStrings.gallery),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text(AppStrings.file),
              onTap: () => Navigator.pop(context, 'file'),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      PremiumToast.showError(context, message);
    }
  }

  /// Simple image cropper for uploaded documents (mobile only).
  Future<String?> _cropImage(String path) async {
    if (kIsWeb) return path;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: path,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Document',
            toolbarColor: AppTheme.primaryColor,
            toolbarWidgetColor: Colors.white,
            hideBottomControls: false,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Crop Document'),
        ],
      );
      return cropped?.path ?? path;
    } catch (_) {
      // If cropping fails, fall back to original image
      return path;
    }
  }

  DocumentStatus _getDocumentStatus(DocumentRequirement requirement) {
    final uploadedDoc = _firstUploadedForRequirement(requirement);

    if (uploadedDoc.id.isEmpty) {
      return _uploadingStatus[requirement.id] == true
          ? DocumentStatus.uploading
          : DocumentStatus.pending;
    }

    return uploadedDoc.status;
  }

  UploadedDocument _firstUploadedForRequirement(DocumentRequirement requirement) {
    return _uploadedDocuments.firstWhere(
      (doc) => leadDocumentTypeMatches(doc.documentType, requirement.id),
      orElse: () => UploadedDocument(
        id: '',
        documentType: '',
        fileName: '',
        fileSize: '',
        uploadedAt: DateTime.now(),
      ),
    );
  }

  UploadedDocument? _latestRejectedForRequirement(DocumentRequirement requirement) {
    UploadedDocument? best;
    for (final d in _uploadedDocuments) {
      if (!leadDocumentTypeMatches(d.documentType, requirement.id)) continue;
      if (d.status != DocumentStatus.rejected) continue;
      if (best == null || d.uploadedAt.isAfter(best.uploadedAt)) {
        best = d;
      }
    }
    return best;
  }

  /// Server `name` for re-upload after reject: same display base as rejected row + middle dot + Reuploaded.
  String? _displayNameForReupload(DocumentRequirement requirement) {
    final rejected = _latestRejectedForRequirement(requirement);
    if (rejected == null) return null;
    final raw = rejected.fileName.trim();
    final base = raw.isNotEmpty
        ? stripLeadDocumentReuploadSuffix(raw)
        : requirement.label;
    final core = base.trim().isNotEmpty ? base.trim() : requirement.label;
    return '$core · Reuploaded';
  }

  /// Latest server row for this requirement (by `uploadedAt`), for gating re-upload lock.
  DocumentStatus _latestUploadStatusForRequirementId(
    String requirementId,
    List<UploadedDocument> uploads,
  ) {
    UploadedDocument? latest;
    for (final d in uploads) {
      if (!leadDocumentTypeMatches(d.documentType, requirementId)) continue;
      if (latest == null || d.uploadedAt.isAfter(latest.uploadedAt)) {
        latest = d;
      }
    }
    if (latest == null || latest.id.isEmpty) return DocumentStatus.pending;
    return latest.status;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.08),
              colorScheme.secondary.withValues(alpha: 0.04),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header (similar to applications screen)
              Container(
                color: colorScheme.primary,
                padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.description,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            AppStrings.requiredDocumentsTitle,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: _loadDocuments,
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Tabs
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: colorScheme.primary,
                        labelColor: colorScheme.primary,
                        unselectedLabelColor: colorScheme.onSurfaceVariant,
                        labelStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                        tabs: const [
                          Tab(text: AppStrings.submittedTab),
                          Tab(text: AppStrings.verifiedTab),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _error != null
                    ? _buildErrorView()
                    : _requiredDocuments.isEmpty
                    ? _buildNoDocumentsView()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // Submitted Documents Tab
                          _buildSubmittedDocumentsTab(),
                          // Verified Documents Tab
                          _buildVerifiedDocumentsTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        PremiumCard(
          gradientColors: [
            Colors.white,
            AppTheme.errorColor.withValues(alpha: 0.05),
          ],
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              Text(
                AppStrings.errorLoadingDocuments,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              PremiumButton(
                label: AppStrings.retry,
                icon: Icons.refresh,
                isPrimary: false,
                onPressed: _loadDocuments,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoDocumentsView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        PremiumCard(
          child: Column(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: AppTheme.successColor,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.noAdditionalDocuments,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.noAdditionalDocumentsMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              PremiumButton(
                label: AppStrings.refresh,
                icon: Icons.refresh,
                isPrimary: false,
                onPressed: _loadDocuments,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<DocumentRequirement> documents,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Single column with natural height per card to avoid overflow
          ...documents.map((doc) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildDocumentCard(context, doc),
          )),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(
    BuildContext context,
    DocumentRequirement requirement,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final status = _getDocumentStatus(requirement);
    final isUploading = _uploadingStatus[requirement.id] == true;
    final uploadedRow = _firstUploadedForRequirement(requirement);

    IconData statusIcon;
    Color statusColor;
    String statusText;
    Color borderColor;

    switch (status) {
      case DocumentStatus.uploaded:
      case DocumentStatus.verified:
        statusIcon = Icons.check_circle;
        statusColor = AppTheme.successColor;
        statusText = status == DocumentStatus.verified
            ? AppStrings.verified
            : 'Uploaded';
        borderColor = AppTheme.successColor.withValues(alpha: 0.25);
        break;
      case DocumentStatus.uploading:
        statusIcon = Icons.upload;
        statusColor = AppTheme.infoColor;
        statusText = AppStrings.uploading;
        borderColor = AppTheme.infoColor.withValues(alpha: 0.25);
        break;
      case DocumentStatus.rejected:
        statusIcon = Icons.cancel;
        statusColor = AppTheme.errorColor;
        statusText = AppStrings.rejected;
        borderColor = AppTheme.errorColor.withValues(alpha: 0.25);
        break;
      case DocumentStatus.pending:
        statusIcon = Icons.pending;
        statusColor = AppTheme.warningColor;
        statusText = AppStrings.pending;
        borderColor = AppTheme.warningColor.withValues(alpha: 0.25);
        break;
    }

    final awaitingReviewAfterReupload = _replacementSubmittedIds.contains(requirement.id) &&
        (status == DocumentStatus.pending || status == DocumentStatus.uploaded);

    final isPrimaryAction =
        status == DocumentStatus.pending || status == DocumentStatus.rejected;
    final buttonLabel = status == DocumentStatus.pending ||
            status == DocumentStatus.rejected
        ? AppStrings.upload
        : AppStrings.reupload;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  uploadedRow.id.isNotEmpty &&
                          leadDocumentDisplayNameHasReuploadTag(uploadedRow.fileName)
                      ? stripLeadDocumentReuploadSuffix(uploadedRow.fileName)
                      : requirement.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (uploadedRow.id.isNotEmpty &&
                  leadDocumentDisplayNameHasReuploadTag(uploadedRow.fileName)) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.35)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Reuploaded',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (requirement.isCustom) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Custom',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(statusIcon, size: 12, color: statusColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  statusText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (uploadedRow.id.isNotEmpty &&
              leadDocumentDisplayNameHasReuploadTag(uploadedRow.fileName)) ...[
            const SizedBox(height: 2),
            Text(
              uploadedRow.fileName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          if (isUploading)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              child: PremiumButton(
                label: buttonLabel,
                icon: Icons.upload,
                isPrimary: isPrimaryAction,
                onPressed: awaitingReviewAfterReupload
                    ? null
                    : () => _uploadDocument(requirement),
              ),
            ),
            if (awaitingReviewAfterReupload) ...[
              const SizedBox(height: 6),
              Text(
                'Replacement sent. Upload is disabled until this document is verified or rejected again.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSubmittedDocumentsTab() {
    final submittedDocs = _getSubmittedDocuments();

    if (submittedDocs.isEmpty) {
      return _buildEmptyTabView(
        icon: Icons.upload_outlined,
        title: AppStrings.noSubmittedDocuments,
        message: AppStrings.noSubmittedDocumentsMessage,
        actionLabel: AppStrings.viewVerified,
        onAction: () => _tabController.animateTo(1),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView(
        physics: const ClampingScrollPhysics(), // Only vertical scrolling
        padding: const EdgeInsets.all(24),
        children: [
          // Applicant Documents
          if (_getSubmittedDocumentsByCategory(
            DocumentCategory.applicant,
          ).isNotEmpty)
            _buildSection(
              context,
              title: 'Applicant Documents',
              icon: Icons.person,
              documents: _getSubmittedDocumentsByCategory(
                DocumentCategory.applicant,
              ),
            ),

          if (_getSubmittedDocumentsByCategory(
                DocumentCategory.applicant,
              ).isNotEmpty &&
              _getSubmittedDocumentsByCategory(
                DocumentCategory.spouse,
              ).isNotEmpty)
            const SizedBox(height: 16),

          // Spouse Documents
          if (_getSubmittedDocumentsByCategory(
            DocumentCategory.spouse,
          ).isNotEmpty)
            _buildSection(
              context,
              title: 'Spouse Documents',
              icon: Icons.people,
              documents: _getSubmittedDocumentsByCategory(
                DocumentCategory.spouse,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVerifiedDocumentsTab() {
    final verifiedDocs = _getVerifiedDocuments();

    if (verifiedDocs.isEmpty) {
      return _buildEmptyTabView(
        icon: Icons.verified_outlined,
        title: AppStrings.noVerifiedDocuments,
        message: AppStrings.noVerifiedDocumentsMessage,
        actionLabel: AppStrings.viewSubmitted,
        onAction: () => _tabController.animateTo(0),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView(
        physics: const ClampingScrollPhysics(), // Only vertical scrolling
        padding: const EdgeInsets.all(24),
        children: [
          // Applicant Documents
          if (_getVerifiedDocumentsByCategory(
            DocumentCategory.applicant,
          ).isNotEmpty)
            _buildVerifiedSection(
              context,
              title: 'Applicant Documents',
              icon: Icons.person,
              documents: _getVerifiedDocumentsByCategory(
                DocumentCategory.applicant,
              ),
            ),

          if (_getVerifiedDocumentsByCategory(
                DocumentCategory.applicant,
              ).isNotEmpty &&
              _getVerifiedDocumentsByCategory(
                DocumentCategory.spouse,
              ).isNotEmpty)
            const SizedBox(height: 16),

          // Spouse Documents
          if (_getVerifiedDocumentsByCategory(
            DocumentCategory.spouse,
          ).isNotEmpty)
            _buildVerifiedSection(
              context,
              title: 'Spouse Documents',
              icon: Icons.people,
              documents: _getVerifiedDocumentsByCategory(
                DocumentCategory.spouse,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyTabView({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        PremiumCard(
          child: Column(
            children: [
              Icon(icon, size: 64, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              PremiumButton(
                label: actionLabel,
                icon: Icons.swap_horiz,
                isPrimary: true,
                onPressed: onAction,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<DocumentRequirement> _getSubmittedDocuments() {
    return _requiredDocuments.where((doc) {
      final status = _getDocumentStatus(doc);
      return status == DocumentStatus.uploaded ||
          status == DocumentStatus.pending ||
          status == DocumentStatus.rejected ||
          status == DocumentStatus.uploading;
    }).toList();
  }

  List<DocumentRequirement> _getVerifiedDocuments() {
    return _requiredDocuments.where((doc) {
      final status = _getDocumentStatus(doc);
      return status == DocumentStatus.verified;
    }).toList();
  }

  List<DocumentRequirement> _getSubmittedDocumentsByCategory(
    DocumentCategory category,
  ) {
    return _getSubmittedDocuments()
        .where((doc) => doc.category == category)
        .toList();
  }

  List<DocumentRequirement> _getVerifiedDocumentsByCategory(
    DocumentCategory category,
  ) {
    return _getVerifiedDocuments()
        .where((doc) => doc.category == category)
        .toList();
  }

  Widget _buildVerifiedSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<DocumentRequirement> documents,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Single column, top to bottom (compact)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1,
              mainAxisSpacing: 6,
              childAspectRatio: 3.2,
            ),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              return _buildVerifiedDocumentItem(context, documents[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedDocumentItem(
    BuildContext context,
    DocumentRequirement requirement,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final uploadedDoc = _firstUploadedForRequirement(requirement);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.successColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  uploadedDoc.id.isNotEmpty &&
                          leadDocumentDisplayNameHasReuploadTag(uploadedDoc.fileName)
                      ? stripLeadDocumentReuploadSuffix(uploadedDoc.fileName)
                      : requirement.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (uploadedDoc.id.isNotEmpty &&
                  leadDocumentDisplayNameHasReuploadTag(uploadedDoc.fileName)) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.35)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Reuploaded',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (requirement.isCustom)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Custom',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppTheme.successColor,
                size: 12,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  AppStrings.verified,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (uploadedDoc.id.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              uploadedDoc.fileName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
              maxLines: leadDocumentDisplayNameHasReuploadTag(uploadedDoc.fileName) ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
