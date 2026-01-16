import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/additional_document.dart';
import '../services/additional_documents_service.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';

class RequiredDocumentsScreen extends StatefulWidget {
  const RequiredDocumentsScreen({super.key});

  @override
  State<RequiredDocumentsScreen> createState() => _RequiredDocumentsScreenState();
}

class _RequiredDocumentsScreenState extends State<RequiredDocumentsScreen> {
  final AdditionalDocumentsService _documentsService = AdditionalDocumentsService();
  final ImagePicker _imagePicker = ImagePicker();

  List<DocumentRequirement> _requiredDocuments = [];
  List<UploadedDocument> _uploadedDocuments = [];
  bool _isLoading = true;
  String? _error;
  String? _leadId;
  String? _userId;
  Map<String, bool> _uploadingStatus = {};

  @override
  void initState() {
    super.initState();
    _loadDocuments();
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
        // Show user-friendly error message
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
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
      final uploadedDocs = await _documentsService.getUserDocuments(user.id);
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
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
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
        title: const Text('Select Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('File'),
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

  List<DocumentRequirement> _getDocumentsByCategory(DocumentCategory category) {
    return _requiredDocuments.where((doc) => doc.category == category).toList();
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
              // Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.secondary,
                          ],
                        ),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Required Documents',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Upload additional documents',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadDocuments,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : _error != null
                        ? _buildErrorView()
                        : _requiredDocuments.isEmpty
                            ? _buildEmptyView()
                            : RefreshIndicator(
                                onRefresh: _loadDocuments,
                                child: ListView(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  children: [
                                    // Applicant Documents
                                    if (_getDocumentsByCategory(DocumentCategory.applicant).isNotEmpty)
                                      _buildSection(
                                        context,
                                        title: 'Applicant Documents',
                                        icon: Icons.person,
                                        documents: _getDocumentsByCategory(DocumentCategory.applicant),
                                      ),

                                    const SizedBox(height: 16),

                                    // Spouse Documents
                                    if (_getDocumentsByCategory(DocumentCategory.spouse).isNotEmpty)
                                      _buildSection(
                                        context,
                                        title: 'Spouse Documents',
                                        icon: Icons.people,
                                        documents: _getDocumentsByCategory(DocumentCategory.spouse),
                                      ),

                                    const SizedBox(height: 24),

                                    // Uploaded Documents
                                    if (_uploadedDocuments.isNotEmpty)
                                      _buildUploadedSection(context),
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

  Widget _buildErrorView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
                'Error Loading Documents',
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
                label: 'Retry',
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

  Widget _buildEmptyView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
                'No Additional Documents Required',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'All required documents have been uploaded or no additional documents are needed.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
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
        statusText = status == DocumentStatus.verified ? 'Verified' : 'Uploaded';
        break;
      case DocumentStatus.uploading:
        statusIcon = Icons.upload;
        statusColor = AppTheme.infoColor;
        statusText = 'Uploading...';
        break;
      case DocumentStatus.rejected:
        statusIcon = Icons.cancel;
        statusColor = AppTheme.errorColor;
        statusText = 'Rejected';
        break;
      case DocumentStatus.pending:
        statusIcon = Icons.pending;
        statusColor = AppTheme.warningColor;
        statusText = 'Pending';
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
                    ? 'Upload'
                    : 'Re-upload',
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

  Widget _buildUploadedSection(BuildContext context) {
    final theme = Theme.of(context);

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder, color: AppTheme.successColor),
              const SizedBox(width: 8),
              Text(
                'Uploaded Documents',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._uploadedDocuments.map((doc) => _buildUploadedDocumentItem(context, doc)),
        ],
      ),
    );
  }

  Widget _buildUploadedDocumentItem(BuildContext context, UploadedDocument document) {
    final theme = Theme.of(context);

    // Find requirement for this document to get label
    final requirement = _requiredDocuments.firstWhere(
      (req) => req.id == document.documentType,
      orElse: () => DocumentRequirement(
        id: document.documentType,
        label: document.documentType,
        category: DocumentCategory.applicant,
      ),
    );

    IconData statusIcon;
    Color statusColor;

    switch (document.status) {
      case DocumentStatus.verified:
        statusIcon = Icons.verified;
        statusColor = AppTheme.successColor;
        break;
      case DocumentStatus.rejected:
        statusIcon = Icons.cancel;
        statusColor = AppTheme.errorColor;
        break;
      default:
        statusIcon = Icons.check_circle;
        statusColor = AppTheme.infoColor;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.description, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requirement.label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${document.fileName} • ${document.fileSize}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(statusIcon, color: statusColor, size: 20),
        ],
      ),
    );
  }
}
