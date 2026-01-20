import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/additional_document.dart';
import '../services/additional_documents_service.dart';
import '../providers/auth_provider.dart';
import '../utils/app_strings.dart';
import '../utils/app_theme.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';


class RequiredDocumentsScreen extends StatefulWidget {
  const RequiredDocumentsScreen({super.key});

  @override
  State<RequiredDocumentsScreen> createState() => _RequiredDocumentsScreenState();
}

class _RequiredDocumentsScreenState extends State<RequiredDocumentsScreen> with SingleTickerProviderStateMixin {
  final AdditionalDocumentsService _documentsService = AdditionalDocumentsService();
  final ImagePicker _imagePicker = ImagePicker();

  List<DocumentRequirement> _requiredDocuments = [];
  List<UploadedDocument> _uploadedDocuments = [];
  bool _isLoading = true;
  String? _error;
  String? _leadId;
  String? _userId;
  Map<String, bool> _uploadingStatus = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDocuments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      Map<String, dynamic> leadData;
      try {
        leadData = await _documentsService.getLeadByEmail(user.email);
        _leadId = leadData['id'] as String?;
      } catch (e) {
        // Show user-friendly error message for backend connection issues
        String errorMessage = e.toString().replaceFirst('Exception: ', '');
        
        // Check if it's a connection/network error
        if (errorMessage.toLowerCase().contains('failed host lookup') ||
            errorMessage.toLowerCase().contains('connection refused') ||
            errorMessage.toLowerCase().contains('socketexception') ||
            errorMessage.toLowerCase().contains('timeout') ||
            errorMessage.toLowerCase().contains('network') ||
            errorMessage.toLowerCase().contains('unable to reach')) {
          errorMessage = 'Unable to connect to server. Please check your internet connection and try again.';
        } else if (errorMessage.toLowerCase().contains('404') ||
                   errorMessage.toLowerCase().contains('not found')) {
          errorMessage = 'Service temporarily unavailable. Please try again later.';
        } else if (errorMessage.toLowerCase().contains('500') ||
                   errorMessage.toLowerCase().contains('server error')) {
          errorMessage = 'Server error. Please try again later.';
        }
        
        setState(() {
          _error = errorMessage;
          _requiredDocuments = [];
          _isLoading = false;
        });
        return;
      }

      if (_leadId == null) {
        setState(() {
        _error = 'Lead information not available. Please contact support.';
          _requiredDocuments = [];
          _isLoading = false;
        });
        return;
      }

      // Get document requirements
      final requirements = leadData['additionalDocumentRequirements'] as List<dynamic>? ?? [];
      
      // Get uploaded documents
      List<UploadedDocument> uploadedDocs = [];
      try {
        uploadedDocs = await _documentsService.getUserDocuments(user.id);
      } catch (e) {
        // If getting uploaded documents fails, continue with empty list
        // This allows the screen to still show required documents even if uploads can't be fetched
        uploadedDocs = [];
      }
      _uploadedDocuments = uploadedDocs;

      // Create document requirements list
      final uploadedDocTypes = uploadedDocs.map((doc) => doc.documentType).toList();
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

      setState(() {
        _requiredDocuments = requiredDocs;
        _isLoading = false;
      });
    } catch (e) {
      // Handle any other errors
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      
      // Check if it's a connection/network error
      if (errorMessage.toLowerCase().contains('failed host lookup') ||
          errorMessage.toLowerCase().contains('connection refused') ||
          errorMessage.toLowerCase().contains('socketexception') ||
          errorMessage.toLowerCase().contains('timeout') ||
          errorMessage.toLowerCase().contains('network') ||
          errorMessage.toLowerCase().contains('unable to reach') ||
          errorMessage.toLowerCase().contains('connection closed') ||
          errorMessage.toLowerCase().contains('connection reset')) {
        errorMessage = 'Unable to connect to server. Please check your internet connection and try again.';
      } else if (errorMessage.toLowerCase().contains('provider') ||
                 errorMessage.toLowerCase().contains('not found in widget tree')) {
        errorMessage = 'Application error. Please restart the app.';
      } else if (errorMessage.toLowerCase().contains('404') ||
                 errorMessage.toLowerCase().contains('not found')) {
        errorMessage = 'Service temporarily unavailable. Please try again later.';
      } else if (errorMessage.toLowerCase().contains('500') ||
                 errorMessage.toLowerCase().contains('server error')) {
        errorMessage = 'Server error. Please try again later.';
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
        pickedFile = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
      } else if (source == 'gallery') {
        pickedFile = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
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

      // Upload document
      await _documentsService.uploadAdditionalDocument(
        filePath: filePath,
        fileName: pickedFile.name,
        documentType: requirement.id,
        leadId: _leadId!,
        fileBytes: fileBytes,
      );

      // Refresh documents
      await _loadDocuments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document uploaded successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to upload document: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      setState(() {
        _uploadingStatus[requirement.id] = false;
      });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }


  DocumentStatus _getDocumentStatus(DocumentRequirement requirement) {
    final uploadedDoc = _uploadedDocuments.firstWhere(
      (doc) => doc.documentType == requirement.id,
      orElse: () => UploadedDocument(
        id: '',
        documentType: '',
        fileName: '',
        fileSize: '',
        uploadedAt: DateTime.now(),
      ),
    );

    if (uploadedDoc.id.isEmpty) {
      return _uploadingStatus[requirement.id] == true
          ? DocumentStatus.uploading
          : DocumentStatus.pending;
    }

    return uploadedDoc.status;
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
                        unselectedLabelStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                            ),
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
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorColor,
              ),
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
          const SizedBox(height: 16),
          ...documents.map((doc) => _buildDocumentItem(context, doc)),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(BuildContext context, DocumentRequirement requirement) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final status = _getDocumentStatus(requirement);
    final isUploading = _uploadingStatus[requirement.id] == true;

    IconData statusIcon;
    Color statusColor;
    String statusText;

    switch (status) {
      case DocumentStatus.uploaded:
      case DocumentStatus.verified:
        statusIcon = Icons.check_circle;
        statusColor = AppTheme.successColor;
        statusText = status == DocumentStatus.verified
            ? AppStrings.verified
            : 'Uploaded';
        break;
      case DocumentStatus.uploading:
        statusIcon = Icons.upload;
        statusColor = AppTheme.infoColor;
        statusText = AppStrings.uploading;
        break;
      case DocumentStatus.rejected:
        statusIcon = Icons.cancel;
        statusColor = AppTheme.errorColor;
        statusText = AppStrings.rejected;
        break;
      case DocumentStatus.pending:
        statusIcon = Icons.pending;
        statusColor = AppTheme.warningColor;
        statusText = AppStrings.pending;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      requirement.label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (requirement.isCustom) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Custom',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (status != DocumentStatus.uploading)
            Flexible(
              child: PremiumButton(
                label: status == DocumentStatus.pending || status == DocumentStatus.rejected
                    ? AppStrings.upload
                    : AppStrings.reupload,
                icon: Icons.upload,
                isPrimary: status == DocumentStatus.pending || status == DocumentStatus.rejected,
                onPressed: isUploading ? null : () => _uploadDocument(requirement),
              ),
            )
          else
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
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
          if (_getSubmittedDocumentsByCategory(DocumentCategory.applicant).isNotEmpty)
            _buildSection(
              context,
              title: 'Applicant Documents',
              icon: Icons.person,
              documents: _getSubmittedDocumentsByCategory(DocumentCategory.applicant),
            ),

          if (_getSubmittedDocumentsByCategory(DocumentCategory.applicant).isNotEmpty &&
              _getSubmittedDocumentsByCategory(DocumentCategory.spouse).isNotEmpty)
            const SizedBox(height: 16),

          // Spouse Documents
          if (_getSubmittedDocumentsByCategory(DocumentCategory.spouse).isNotEmpty)
            _buildSection(
              context,
              title: 'Spouse Documents',
              icon: Icons.people,
              documents: _getSubmittedDocumentsByCategory(DocumentCategory.spouse),
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
          if (_getVerifiedDocumentsByCategory(DocumentCategory.applicant).isNotEmpty)
            _buildVerifiedSection(
              context,
              title: 'Applicant Documents',
              icon: Icons.person,
              documents: _getVerifiedDocumentsByCategory(DocumentCategory.applicant),
            ),

          if (_getVerifiedDocumentsByCategory(DocumentCategory.applicant).isNotEmpty &&
              _getVerifiedDocumentsByCategory(DocumentCategory.spouse).isNotEmpty)
            const SizedBox(height: 16),

          // Spouse Documents
          if (_getVerifiedDocumentsByCategory(DocumentCategory.spouse).isNotEmpty)
            _buildVerifiedSection(
              context,
              title: 'Spouse Documents',
              icon: Icons.people,
              documents: _getVerifiedDocumentsByCategory(DocumentCategory.spouse),
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
              Icon(
                icon,
                size: 64,
                color: colorScheme.onSurfaceVariant,
              ),
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

  List<DocumentRequirement> _getSubmittedDocumentsByCategory(DocumentCategory category) {
    return _getSubmittedDocuments().where((doc) => doc.category == category).toList();
  }

  List<DocumentRequirement> _getVerifiedDocumentsByCategory(DocumentCategory category) {
    return _getVerifiedDocuments().where((doc) => doc.category == category).toList();
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
          const SizedBox(height: 16),
          ...documents.map((doc) => _buildVerifiedDocumentItem(context, doc)),
        ],
      ),
    );
  }

  Widget _buildVerifiedDocumentItem(BuildContext context, DocumentRequirement requirement) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final uploadedDoc = _uploadedDocuments.firstWhere(
      (doc) => doc.documentType == requirement.id,
      orElse: () => UploadedDocument(
        id: '',
        documentType: '',
        fileName: '',
        fileSize: '',
        uploadedAt: DateTime.now(),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified,
              color: AppTheme.successColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
              children: [
                Text(
                  requirement.label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                    if (requirement.isCustom) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Custom',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (uploadedDoc.id.isNotEmpty) ...[
                const SizedBox(height: 4),
                  Text(
                    '${uploadedDoc.fileName} • ${uploadedDoc.fileSize}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.successColor,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  AppStrings.verified,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
