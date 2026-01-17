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
  State<RequiredDocumentsScreen> createState() =>
      _RequiredDocumentsScreenState();
}

class _RequiredDocumentsScreenState extends State<RequiredDocumentsScreen> {
  final AdditionalDocumentsService _documentsService =
      AdditionalDocumentsService();
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

      // Get document requirements from lead
      final requirements =
          leadData['additionalDocumentRequirements'] as List<dynamic>? ?? [];

      // Get uploaded documents (includes rejected documents)
      List<UploadedDocument> uploadedDocs = [];
      try {
        uploadedDocs = await _documentsService.getUserDocuments(user.id);
      } catch (e) {
        print('Error fetching documents: $e');
        // Continue even if document fetch fails - we'll show requirements anyway
      }
      _uploadedDocuments = uploadedDocs;

      // Debug: Print all uploaded documents and their status
      print('=== UPLOADED DOCUMENTS (from screen) ===');
      print('Total uploaded docs: ${uploadedDocs.length}');
      if (uploadedDocs.isEmpty) {
        print(
          'WARNING: No uploaded documents found! This might be normal if no documents have been uploaded yet.',
        );
      } else {
        for (var doc in uploadedDocs) {
          print(
            'Doc: ${doc.documentType}, Status: ${doc.status}, File: ${doc.fileName}, ID: ${doc.id}',
          );
        }
      }
      print('=== REQUIREMENTS FROM LEAD ===');
      print('Requirements: $requirements');

      // Create document requirements list
      // CRITICAL: Include all requirements from lead, PLUS any rejected documents
      // Rejected documents MUST be shown even if not in additionalDocumentRequirements yet
      final uploadedDocTypes = uploadedDocs
          .map((doc) => doc.documentType)
          .where((type) => type.isNotEmpty)
          .toList();

      // Get rejected document types that should be shown
      // These are documents that were rejected and need to be re-uploaded
      final rejectedDocs = uploadedDocs
          .where(
            (doc) =>
                doc.status == DocumentStatus.rejected &&
                doc.documentType.isNotEmpty,
          )
          .toList();

      final rejectedDocTypes = rejectedDocs
          .map((doc) => doc.documentType)
          .where((type) => type.isNotEmpty)
          .toSet();

      print('=== REJECTED DOCUMENT TYPES ===');
      print('Rejected types: $rejectedDocTypes');

      // Combine requirements with rejected document types
      // This ensures rejected documents appear even if they're not in the requirements list yet
      final allRequiredDocTypes = <String>{};
      allRequiredDocTypes.addAll(
        requirements.map((id) => id.toString()).where((id) => id.isNotEmpty),
      );
      allRequiredDocTypes.addAll(rejectedDocTypes);

      print('=== ALL REQUIRED DOC TYPES ===');
      print('All required: $allRequiredDocTypes');
      print('Requirements from lead: $requirements');
      print('Rejected doc types found: $rejectedDocTypes');

      // IMPORTANT: If we have requirements but no uploaded docs, still show the requirements
      // This handles the case where documents were rejected but not yet re-uploaded
      if (allRequiredDocTypes.isEmpty && requirements.isNotEmpty) {
        print(
          'WARNING: No required doc types but requirements exist. Using requirements directly.',
        );
        allRequiredDocTypes.addAll(
          requirements.map((id) => id.toString()).where((id) => id.isNotEmpty),
        );
      }

      // Create document requirements from the combined list
      final requiredDocs = allRequiredDocTypes
          .map((id) {
            try {
              final req = DocumentRequirement.fromId(id, uploadedDocTypes);
              // If this is a rejected document, ensure it shows as rejected and has the rejection reason
              final rejectedDoc = rejectedDocs.firstWhere(
                (doc) {
                  // Match by exact documentType or handle variations (selfie vs selfies, etc.)
                  final docTypeLower = doc.documentType.toLowerCase();
                  final idLower = id.toLowerCase();
                  return docTypeLower == idLower ||
                      docTypeLower == '${idLower}s' ||
                      idLower == '${docTypeLower}s' ||
                      doc.documentType == id;
                },
                orElse: () => UploadedDocument(
                  id: '',
                  documentType: '',
                  fileName: '',
                  fileSize: '',
                  uploadedAt: DateTime.now(),
                  status: DocumentStatus.pending,
                  rejectionReason: null,
                ),
              );
              if (rejectedDoc.status == DocumentStatus.rejected) {
                req.status = DocumentStatus.rejected;
                print(
                  'Setting status to rejected for: $id, reason: ${rejectedDoc.rejectionReason}',
                );
              }
              return req;
            } catch (e) {
              // Skip invalid document requirement IDs
              print('Error creating requirement for $id: $e');
              return null;
            }
          })
          .whereType<DocumentRequirement>()
          .toList();

      print('=== FINAL REQUIRED DOCS ===');
      for (var doc in requiredDocs) {
        print('Required: ${doc.id}, Status: ${doc.status}');
        // Find rejection reason for rejected documents
        if (doc.status == DocumentStatus.rejected) {
          final rejectedDoc = rejectedDocs.firstWhere(
            (rejDoc) {
              final docTypeLower = rejDoc.documentType.toLowerCase();
              final reqIdLower = doc.id.toLowerCase();
              return docTypeLower == reqIdLower ||
                  docTypeLower == '${reqIdLower}s' ||
                  reqIdLower == '${docTypeLower}s';
            },
            orElse: () => UploadedDocument(
              id: '',
              documentType: '',
              fileName: '',
              fileSize: '',
              uploadedAt: DateTime.now(),
              status: DocumentStatus.pending,
              rejectionReason: null,
            ),
          );
          if (rejectedDoc.rejectionReason != null) {
            print('  Rejection reason: ${rejectedDoc.rejectionReason}');
          }
        }
      }

      // IMPORTANT: Filter out documents that have been uploaded/verified
      // Only show documents that are pending or rejected
      final filteredRequiredDocs = requiredDocs.where((doc) {
        final status = _getDocumentStatus(doc);
        // Only show if pending or rejected (not uploaded/verified)
        return status == DocumentStatus.pending ||
            status == DocumentStatus.rejected;
      }).toList();

      print('=== FILTERED REQUIRED DOCS (after status check) ===');
      print(
        'Before filter: ${requiredDocs.length}, After filter: ${filteredRequiredDocs.length}',
      );
      for (var doc in filteredRequiredDocs) {
        print('Required: ${doc.id}, Status: ${_getDocumentStatus(doc)}');
      }

      setState(() {
        _requiredDocuments = filteredRequiredDocs;
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

      // Refresh documents to get updated status
      // This ensures the new uploaded document status is shown instead of old rejected status
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
      _showError(
        'Failed to upload document: ${e.toString().replaceFirst('Exception: ', '')}',
      );
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
        SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  List<DocumentRequirement> _getDocumentsByCategory(DocumentCategory category) {
    return _requiredDocuments.where((doc) => doc.category == category).toList();
  }

  DocumentStatus _getDocumentStatus(DocumentRequirement requirement) {
    // Check if currently uploading
    if (_uploadingStatus[requirement.id] == true) {
      return DocumentStatus.uploading;
    }

    // Find all documents for this requirement (there might be multiple - old rejected and new uploaded)
    // Match by documentType (which comes from folder) or by requirement.id
    // Handle both regular documents (selfies, aadhaar, pan) and additional documents (applicant_*, spouse_*)
    final matchingDocs = _uploadedDocuments.where((doc) {
      // Direct match
      if (doc.documentType == requirement.id) {
        return true;
      }
      // For regular documents like "selfies", the folder might be "selfies" and requirement.id might be "selfies"
      // For additional documents, folder might be "applicant_aadhaar" and requirement.id is "applicant_aadhaar"
      // Also handle case where requirement.id might be slightly different (e.g., "selfie" vs "selfies")
      final docTypeLower = doc.documentType.toLowerCase();
      final reqIdLower = requirement.id.toLowerCase();
      if (docTypeLower == reqIdLower ||
          docTypeLower == '${reqIdLower}s' ||
          reqIdLower == '${docTypeLower}s') {
        return true;
      }
      return false;
    }).toList();

    print('=== Status Check for ${requirement.id} ===');
    print('Found ${matchingDocs.length} matching documents');
    for (var doc in matchingDocs) {
      print(
        '  - Doc: ${doc.documentType}, Status: ${doc.status}, File: ${doc.fileName}',
      );
    }

    if (matchingDocs.isEmpty) {
      print('Status for ${requirement.id}: PENDING (no matching docs)');
      return DocumentStatus.pending;
    }

    // IMPORTANT: Prioritize status in this order: verified > uploaded > rejected
    // This ensures that if a new document was uploaded after rejection, it shows the new status
    final verifiedDocs = matchingDocs
        .where((doc) => doc.status == DocumentStatus.verified)
        .toList();
    if (verifiedDocs.isNotEmpty) {
      verifiedDocs.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      print(
        'Status for ${requirement.id}: VERIFIED (found ${verifiedDocs.length} verified doc(s))',
      );
      return DocumentStatus.verified;
    }

    final uploadedDocs = matchingDocs
        .where((doc) => doc.status == DocumentStatus.uploaded)
        .toList();
    if (uploadedDocs.isNotEmpty) {
      uploadedDocs.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      print(
        'Status for ${requirement.id}: UPLOADED (found ${uploadedDocs.length} uploaded doc(s), newest: ${uploadedDocs.first.fileName})',
      );
      // Don't show rejected status if we have an uploaded document
      return DocumentStatus.uploaded;
    }

    // Only show rejected if there are NO uploaded/verified documents
    final rejectedDocs = matchingDocs
        .where((doc) => doc.status == DocumentStatus.rejected)
        .toList();
    if (rejectedDocs.isNotEmpty) {
      rejectedDocs.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      print(
        'Status for ${requirement.id}: REJECTED (found ${rejectedDocs.length} rejected doc(s), no newer upload)',
      );
      return DocumentStatus.rejected;
    }

    // Default to pending
    print(
      'Status for ${requirement.id}: PENDING (matching docs found but no valid status)',
    );
    return DocumentStatus.pending;
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
                          colors: [colorScheme.primary, colorScheme.secondary],
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
                    ? const Center(child: CircularProgressIndicator())
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
                            if (_getDocumentsByCategory(
                              DocumentCategory.applicant,
                            ).isNotEmpty)
                              _buildSection(
                                context,
                                title: 'Applicant Documents',
                                icon: Icons.person,
                                documents: _getDocumentsByCategory(
                                  DocumentCategory.applicant,
                                ),
                              ),

                            const SizedBox(height: 16),

                            // Spouse Documents
                            if (_getDocumentsByCategory(
                              DocumentCategory.spouse,
                            ).isNotEmpty)
                              _buildSection(
                                context,
                                title: 'Spouse Documents',
                                icon: Icons.people,
                                documents: _getDocumentsByCategory(
                                  DocumentCategory.spouse,
                                ),
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
              Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
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

  Widget _buildDocumentItem(
    BuildContext context,
    DocumentRequirement requirement,
  ) {
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
            ? 'Verified'
            : 'Uploaded';
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
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
                // Show rejection reason if document is rejected
                if (status == DocumentStatus.rejected) ...[
                  const SizedBox(height: 4),
                  Builder(
                    builder: (context) {
                      final rejectedDoc = _uploadedDocuments.firstWhere(
                        (doc) {
                          // Match by exact documentType or handle variations (selfie vs selfies, etc.)
                          final docTypeLower = doc.documentType.toLowerCase();
                          final reqIdLower = requirement.id.toLowerCase();
                          return (doc.status == DocumentStatus.rejected) &&
                              (docTypeLower == reqIdLower ||
                                  docTypeLower == '${reqIdLower}s' ||
                                  reqIdLower == '${docTypeLower}s' ||
                                  doc.documentType == requirement.id);
                        },
                        orElse: () => UploadedDocument(
                          id: '',
                          documentType: '',
                          fileName: '',
                          fileSize: '',
                          uploadedAt: DateTime.now(),
                          status: DocumentStatus.rejected,
                          rejectionReason: null,
                        ),
                      );
                      final reason = rejectedDoc.rejectionReason;
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.errorColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: AppTheme.errorColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'This document was rejected. Please upload a new version.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppTheme.errorColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (reason != null && reason.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Reason: $reason',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.errorColor.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          // Show button based on status
          if (status == DocumentStatus.uploading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (status == DocumentStatus.verified)
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: AppTheme.successColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: PremiumButton(
                label:
                    status == DocumentStatus.pending ||
                        status == DocumentStatus.rejected
                    ? 'Upload'
                    : 'Re-upload',
                icon: Icons.upload,
                isPrimary:
                    status == DocumentStatus.pending ||
                    status == DocumentStatus.rejected,
                onPressed: isUploading
                    ? null
                    : () => _uploadDocument(requirement),
              ),
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
          ..._uploadedDocuments.map(
            (doc) => _buildUploadedDocumentItem(context, doc),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadedDocumentItem(
    BuildContext context,
    UploadedDocument document,
  ) {
    final theme = Theme.of(context);

    // Find requirement for this document to get label
    final requirement = _requiredDocuments.firstWhere(
      (req) => req.id == document.documentType,
      orElse: () => DocumentRequirement(
        id: document.documentType,
        label: document.documentType,
        category: DocumentCategory.applicant,
        status: document.status,
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
