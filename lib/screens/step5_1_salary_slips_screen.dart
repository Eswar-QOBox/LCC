import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/submission_provider.dart';
import '../providers/application_provider.dart';
import '../services/file_upload_service.dart';
import '../utils/app_routes.dart';
import '../utils/blob_helper.dart';
import '../widgets/platform_image.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_toast.dart';
import '../widgets/app_header.dart';
import '../utils/app_theme.dart';
import '../models/document_submission.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '../utils/api_config.dart';
import '../widgets/preview_header_action.dart';

// Conditional import for file operations - only on non-web platforms
import 'dart:io' if (dart.library.html) '../services/file_helper_stub.dart' as io;

class Step5_1SalarySlipsScreen extends StatefulWidget {
  const Step5_1SalarySlipsScreen({super.key});

  @override
  State<Step5_1SalarySlipsScreen> createState() =>
      _Step5_1SalarySlipsScreenState();
}

class _Step5_1SalarySlipsScreenState extends State<Step5_1SalarySlipsScreen> {
  static const int _requiredSlipCount = SalarySlips.requiredSlipCount;

  final FileUploadService _fileUploadService = FileUploadService();
  final ImagePicker _imagePicker = ImagePicker();
  List<SalarySlipItem> _slipItems = [];
  String? _pdfPassword;
  bool _isSaving = false;
  bool _hasSyncedWithProvider = false;
  String? _authToken;
  List<bool> _slipFailures = [];
  List<Uint8List?> _slipBytes = [];
  late final List<DateTime> _requiredMonths;

  Future<String> _cropSalarySlipImageIfPossible(String path) async {
    if (kIsWeb) return path;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: path,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Salary Slip',
            toolbarColor: AppTheme.primaryColor,
            toolbarWidgetColor: Colors.white,
            hideBottomControls: false,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Salary Slip',
          ),
        ],
      );
      return cropped?.path ?? path; // If user cancels, keep original.
    } catch (_) {
      return path;
    }
  }

  Future<String> _persistLocalPathIfNeeded(String path, {String? preferredExtension}) async {
    // Keep remote/blob paths as-is.
    if (kIsWeb) return path;
    if (path.startsWith('http') || path.startsWith('/uploads/') || path.startsWith('/api/')) return path;
    if (path.startsWith('blob:')) return path;

    try {
      final dir = io.Directory('${io.Directory.systemTemp.path}/lcc_salary_slips');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final lastSlash = path.lastIndexOf('/');
      final basename = lastSlash >= 0 ? path.substring(lastSlash + 1) : path;
      final dot = basename.lastIndexOf('.');
      final ext = (preferredExtension != null && preferredExtension.isNotEmpty)
          ? preferredExtension
          : (dot >= 0 ? basename.substring(dot + 1) : 'jpg');

      final uniqueName = 'salary_slip_${DateTime.now().microsecondsSinceEpoch}.$ext';
      final targetPath = '${dir.path}/$uniqueName';
      final copied = await io.File(path).copy(targetPath);
      return copied.path;
    } catch (_) {
      // If anything fails, fall back to original path.
      return path;
    }
  }

  bool _isServerStoredPath(String path) {
    return path.startsWith('http') || path.startsWith('/uploads/') || path.startsWith('/api/');
  }

  List<DateTime> _computeRequiredMonths() {
    final now = DateTime.now();
    // Start from first day of current month, then take the previous 3 months.
    final firstOfThisMonth = DateTime(now.year, now.month, 1);
    DateTime subtractMonths(DateTime date, int monthsBack) {
      final monthIndex = date.year * 12 + (date.month - 1);
      final newIndex = monthIndex - monthsBack;
      final normalizedYear = newIndex ~/ 12;
      final normalizedMonth = (newIndex % 12) + 1;
      return DateTime(normalizedYear, normalizedMonth, 1);
    }

    return [
      subtractMonths(firstOfThisMonth, 1),
      subtractMonths(firstOfThisMonth, 2),
      subtractMonths(firstOfThisMonth, 3),
    ];
  }

  void _normalizeSlipItemsToRequiredMonths() {
    // Always keep a stable number of "slots" so cards don't shift.
    if (_slipItems.length != _requiredSlipCount) {
      final existing = List<SalarySlipItem>.from(_slipItems);
      _slipItems = List.generate(_requiredSlipCount, (i) {
        final item = i < existing.length ? existing[i] : null;
        return SalarySlipItem(
          path: item?.path ?? '',
          slipDate: item?.slipDate ?? _requiredMonths[i],
          isPdf: item?.isPdf ?? false,
        );
      });
    }

    for (int i = 0; i < _requiredSlipCount; i++) {
      _slipItems[i].slipDate ??= _requiredMonths[i];
    }

    _slipFailures = List.filled(_requiredSlipCount, false);
    _slipBytes = List.filled(_requiredSlipCount, null);
  }

  int get _uploadedSlipCount =>
      _slipItems.where((item) => item.hasFile).length;

  bool get _hasAllRequiredSlips => _uploadedSlipCount >= _requiredSlipCount;

  int get _remainingSlipCount =>
      (_requiredSlipCount - _uploadedSlipCount).clamp(0, _requiredSlipCount);

  int get _nextSlotIndex {
    for (int i = 0; i < _requiredSlipCount; i++) {
      if (!_slipItems[i].hasFile) return i;
    }
    return 0;
  }

  String get _nextMonthLabel {
    final idx = _nextSlotIndex;
    if (idx >= _requiredMonths.length) return '';
    return DateFormat('MMMM yyyy').format(_requiredMonths[idx]);
  }

  Future<void> _showUploadOptionsForSlot(int slotIndex) async {
    if (slotIndex < 0 || slotIndex >= _requiredSlipCount) return;

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
                Text(
                  'Upload for ${DateFormat('MMM yyyy').format(_requiredMonths[slotIndex])}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Camera'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickImageForSlot(ImageSource.camera, slotIndex);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickImageForSlot(ImageSource.gallery, slotIndex);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('PDF'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickPdfForSlot(slotIndex);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImageForSlot(ImageSource source, int slotIndex) async {
    if (slotIndex < 0 || slotIndex >= _requiredSlipCount) return;

    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (image == null || !mounted) return;

    // Manual crop before saving (mobile/desktop only).
    final croppedPath = await _cropSalarySlipImageIfPossible(image.path);
    final storedPath = await _persistLocalPathIfNeeded(croppedPath, preferredExtension: 'jpg');
    await _setSlipForSlot(slotIndex, storedPath, isPdf: false);
  }

  Future<void> _pickPdfForSlot(int slotIndex) async {
    if (slotIndex < 0 || slotIndex >= _requiredSlipCount) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    String? path;
    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null) return;
      path = createBlobUrl(bytes, mimeType: 'application/pdf');
    } else {
      if (file.path == null) return;
      path = await _persistLocalPathIfNeeded(file.path!, preferredExtension: 'pdf');
    }

    await _setSlipForSlot(slotIndex, path, isPdf: true);
    _showPasswordDialogIfNeeded();
  }

  Future<void> _setSlipForSlot(int slotIndex, String path, {required bool isPdf}) async {
    if (slotIndex < 0 || slotIndex >= _requiredSlipCount) return;
    final slotMonth = _requiredMonths[slotIndex];

    final provider = context.read<SubmissionProvider>();

    setState(() {
      _slipItems[slotIndex] =
          SalarySlipItem(path: path, slipDate: slotMonth, isPdf: isPdf);

      // Ensure lists are sized correctly
      if (slotIndex < _slipFailures.length) _slipFailures[slotIndex] = false;
      if (slotIndex < _slipBytes.length) _slipBytes[slotIndex] = null;
    });

    provider.setSalarySlipAt(slotIndex, path, slipDate: slotMonth, isPdf: isPdf);
    provider.updateSalarySlipDate(slotIndex, slotMonth);
  }

  bool _isValidImageBytes(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // Check for common image headers
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true; // JPEG
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true; // PNG
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) return true; // GIF
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return true; // WebP
    return false;
  }

  @override
  void initState() {
    super.initState();
    _requiredMonths = _computeRequiredMonths();
    _loadDraftData();
    
    // Load existing data from backend and sync with provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingData();
      // Sync with provider after draft loads (in case it loads after initState)
      _syncWithProvider();
    });
  }

  void _loadDraftData() {
    final provider = context.read<SubmissionProvider>();
    final existing = List<SalarySlipItem>.from(
      provider.submission.salarySlips?.slipItems ?? const [],
    );
    _pdfPassword = provider.submission.salarySlips?.pdfPassword;

    _slipItems = List.generate(_requiredSlipCount, (i) {
      final item = i < existing.length ? existing[i] : null;
      final path = item?.path ?? '';
      return SalarySlipItem(
        path: path,
        slipDate: item?.slipDate ?? _requiredMonths[i],
        isPdf: item?.isPdf ?? path.toLowerCase().endsWith('.pdf'),
      );
    });
    _normalizeSlipItemsToRequiredMonths();
  }

  void _syncWithProvider() {
    if (_hasSyncedWithProvider) return; // Only sync once
    
    final provider = context.read<SubmissionProvider>();
    final salarySlips = provider.submission.salarySlips;
    if (salarySlips != null) {
      final currentSlipItems = List<SalarySlipItem>.from(salarySlips.slipItems);
      final currentPassword = salarySlips.pdfPassword;
      
      // Update local state if provider has different data (from draft)
      if (currentSlipItems.length != _slipItems.length ||
          currentPassword != _pdfPassword) {
        if (mounted) {
          setState(() {
            _slipItems = List.generate(_requiredSlipCount, (i) {
              final item = i < currentSlipItems.length ? currentSlipItems[i] : null;
              final path = item?.path ?? '';
              return SalarySlipItem(
                path: path,
                slipDate: item?.slipDate ?? _requiredMonths[i],
                isPdf: item?.isPdf ?? path.toLowerCase().endsWith('.pdf'),
              );
            });
            _pdfPassword = currentPassword;
            _hasSyncedWithProvider = true;
            _normalizeSlipItemsToRequiredMonths();
          });
        }
      } else {
        _hasSyncedWithProvider = true;
      }
    } else {
      _hasSyncedWithProvider = true;
    }
  }

  Future<void> _loadExistingData() async {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication) return;

    final application = appProvider.currentApplication!;
    if (application.step4BankStatement != null) {
      final stepData = application.step4BankStatement as Map<String, dynamic>;
      
      if (stepData['salarySlipItems'] != null) {
        
        // Helper to build full URL
        String? buildFullUrl(String? relativeUrl) {
          if (relativeUrl == null || relativeUrl.isEmpty) return null;
          
          // Fix for localhost URLs in saved data
          if (relativeUrl.startsWith('http://localhost:5000')) {
             return relativeUrl.replaceFirst('http://localhost:5000', ApiConfig.baseUrl);
          }

          if (relativeUrl.startsWith('http') || relativeUrl.startsWith('blob:')) return relativeUrl;
          String apiPath = relativeUrl;
          if (apiPath.startsWith('/uploads/') && !apiPath.contains('/uploads/files/')) {
            apiPath = apiPath.replaceFirst('/uploads/', '/api/v1/uploads/files/');
          } else if (!apiPath.startsWith('/api/')) {
            apiPath = '/api/v1$apiPath';
          }
          return '${ApiConfig.baseUrl}$apiPath';
        }
        
        // Get access token for authenticated request
        final storage = StorageService.instance;
        final accessToken = await storage.getAccessToken();
        if (accessToken != null && mounted) {
          setState(() {
            _authToken = accessToken;
          });
        }

        final itemsList = stepData['salarySlipItems'] as List;
        final loadedItemsRaw = itemsList.map((item) {
          final map = item as Map<String, dynamic>;
          final rawPath = map['path'] as String?;
          final fullPath = buildFullUrl(rawPath) ?? rawPath ?? '';
          return SalarySlipItem(
            path: fullPath,
            slipDate: map['slipDate'] != null ? DateTime.parse(map['slipDate']) : null,
            isPdf: fullPath.toLowerCase().endsWith('.pdf') || (stepData['salarySlipsIsPdf'] == true),
          );
        }).toList();

        final loadedSlots = List.generate(_requiredSlipCount, (i) {
          final item = i < loadedItemsRaw.length ? loadedItemsRaw[i] : null;
          final path = item?.path ?? '';
          return SalarySlipItem(
            path: path,
            slipDate: item?.slipDate ?? _requiredMonths[i],
            isPdf: item?.isPdf ?? path.toLowerCase().endsWith('.pdf'),
          );
        });

        if (loadedSlots.any((e) => e.hasFile)) {
          setState(() {
            _slipItems = loadedSlots;
            _pdfPassword = stepData['salarySlipsPassword'];
             _hasSyncedWithProvider = true;
             
            // Initialize failure/bytes lists
            _normalizeSlipItemsToRequiredMonths();
          });
          
          // Verify images asynchronously if auth token is available
          if (accessToken != null) {
            for (int i = 0; i < _slipItems.length; i++) {
              final item = _slipItems[i];
              if (item.hasFile && !item.isPdf && item.path.startsWith('http')) {
                _verifySlip(item.path, i, accessToken);
              }
            }
          }

          // Update provider
          final provider = context.read<SubmissionProvider>();
          provider.setSalarySlipItems(_slipItems);
          if (_pdfPassword != null) {
            provider.setSalarySlipsPassword(_pdfPassword!);
          }
          
          // Update dates
          for (int i = 0; i < _slipItems.length; i++) {
            if (_slipItems[i].slipDate != null) {
              provider.updateSalarySlipDate(i, _slipItems[i].slipDate!);
            }
          }
        }
      }
    }
  }

  Future<void> _verifySlip(String url, int index, String token) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (index >= _slipFailures.length) return; // Bounds check

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';
        final isLikelyImage = contentType.startsWith('image/');
        final bytes = response.bodyBytes;
        if (isLikelyImage && _isValidImageBytes(bytes)) {
          setState(() {
            _slipBytes[index] = bytes;
            _slipFailures[index] = false;
          });
        } else {
          setState(() { _slipFailures[index] = true; });
        }
      } else {
        setState(() { _slipFailures[index] = true; });
      }
    } catch (e) {
      if (mounted && index < _slipFailures.length) {
        setState(() { _slipFailures[index] = true; });
      }
    }
  }


  /// Saves draft to DB when slips are uploaded. Returns true if ok to go to next step (saved or nothing to save).
  Future<bool> _saveToBackend() async {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication) return false;

    if (_uploadedSlipCount == 0) {
      return true; // optional step, nothing to save
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Only upload truly-local filesystem paths. (Server URLs like /uploads/... should not be re-uploaded.)
      final itemsWithFiles = _slipItems.where((i) => i.hasFile).toList();
      final localItems = itemsWithFiles
          .where(
            (item) =>
                !_isServerStoredPath(item.path) &&
                !item.path.startsWith('blob:'),
          )
          .toList();
      final remoteItems = itemsWithFiles
          .where(
            (item) => _isServerStoredPath(item.path),
          )
          .toList();
      List<Map<String, dynamic>> finalUploadedFiles = [];

      if (remoteItems.isNotEmpty) {
        final currentApp = appProvider.currentApplication;
        if (currentApp?.step4BankStatement != null) {
          final stepData = currentApp!.step4BankStatement as Map<String, dynamic>;
          final existingUploads = (stepData['salarySlipsUploaded'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ?? [];
          for (final upload in existingUploads) {
            final url = upload['url'] as String?;
            if (url != null &&
                remoteItems.any((item) => item.path.contains(url) || url.contains(item.path)) &&
                !finalUploadedFiles.any((f) => f['url'] == url)) {
              finalUploadedFiles.add(upload);
            }
          }
        }
      }

      if (localItems.isNotEmpty) {
        final files = localItems.map((item) => XFile(item.path)).toList();
        final newUploadResults = await _fileUploadService.uploadSalarySlips(files);
        finalUploadedFiles.addAll(newUploadResults);
      }

      // Replace local paths with uploaded URLs so the application stores server references (not device cache paths).
      final uploadedUrls = finalUploadedFiles
          .map((m) => m['url'])
          .whereType<String>()
          .toList();

      final localSlotIndices = <int>[];
      for (int i = 0; i < _slipItems.length; i++) {
        final item = _slipItems[i];
        final needsUpload =
            item.hasFile &&
            !_isServerStoredPath(item.path) &&
            !item.path.startsWith('blob:');
        if (needsUpload) localSlotIndices.add(i);
      }

      final updatedSlipItems = List<SalarySlipItem>.from(_slipItems);
      for (int i = 0; i < localSlotIndices.length; i++) {
        if (i >= uploadedUrls.length) break;
        final slot = localSlotIndices[i];
        final url = uploadedUrls[i];
        final old = updatedSlipItems[slot];
        updatedSlipItems[slot] = SalarySlipItem(
          path: url,
          slipDate: old.slipDate,
          isPdf: old.isPdf,
        );
      }

      if (mounted) {
        setState(() {
          _slipItems = updatedSlipItems;
          _normalizeSlipItemsToRequiredMonths();
        });
      }

      // Keep provider in sync with server URLs
      final provider = context.read<SubmissionProvider>();
      provider.setSalarySlipItems(updatedSlipItems);
      for (int i = 0; i < updatedSlipItems.length; i++) {
        provider.updateSalarySlipDate(i, updatedSlipItems[i].slipDate);
      }

      final finalIsPdf = updatedSlipItems.any((i) => i.isPdf);

      await appProvider.updateApplication(
        step4BankStatement: {
          // Store all 3 slips (do not deduplicate).
          'salarySlips': updatedSlipItems.map((item) => item.path).toList(),
          'salarySlipItems': updatedSlipItems.map((item) => {
            'path': item.path,
            'slipDate': item.slipDate?.toIso8601String(),
          }).toList(),
          'salarySlipsIsPdf': finalIsPdf,
          'salarySlipsPassword': _pdfPassword,
          'salarySlipsUploaded': finalUploadedFiles,
        },
      );

      if (mounted) {
        PremiumToast.showSuccess(context, 'Salary slips saved successfully!');
      }
      return true;
    } catch (e) {
      if (mounted) {
        PremiumToast.showError(
          context,
          'Failed to save salary slips: ${e.toString()}',
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _removeSlip(int index) {
    context.read<SubmissionProvider>().removeSalarySlip(index);
    setState(() {
      final slotMonth = _requiredMonths[index];
      _slipItems[index] = SalarySlipItem(
        path: '',
        slipDate: slotMonth,
        isPdf: false,
      );
      if (index < _slipFailures.length) _slipFailures[index] = false;
      if (index < _slipBytes.length) _slipBytes[index] = null;
    });
  }

  void _showPasswordDialogIfNeeded() {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Is this PDF password protected?'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'PDF Password (if required)',
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
                floatingLabelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
                hintText: 'Enter password or leave blank',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () {
              final password = passwordController.text.trim();
              if (password.isNotEmpty) {
                setState(() {
                  _pdfPassword = password;
                });
                context.read<SubmissionProvider>().setSalarySlipsPassword(password);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _proceedToNext() async {
    if (_isSaving) return;
    if (!_hasAllRequiredSlips) {
      PremiumToast.showError(
        context,
        'Please upload $_requiredSlipCount salary slips (last 3 months) to continue.',
      );
      return;
    }
    final saved = await _saveToBackend();
    if (mounted && saved) {
      context.go(AppRoutes.step5PersonalData);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider to trigger rebuilds when draft loads
    context.watch<SubmissionProvider>();
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: _hasAllRequiredSlips
              ? PremiumButton(
                  label: 'Continue to Personal Data',
                  icon: Icons.arrow_forward_rounded,
                  isPrimary: true,
                  onPressed: _proceedToNext,
                )
              : Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _nextMonthLabel,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    PremiumButton(
                      label: 'Upload',
                      icon: Icons.upload_file,
                      isPrimary: true,
                      width: 140,
                      onPressed: () => _showUploadOptionsForSlot(_nextSlotIndex),
                    ),
                  ],
                ),
        ),
      ),
      body: Column(
          children: [
            // Consistent Header
            AppHeader(
              title: 'Salary Slips',
              icon: Icons.receipt_long,
              showBackButton: true,
              onBackPressed: () => context.go(AppRoutes.step4BankStatement),
              showHomeButton: true,
              actions: const [
                PreviewHeaderAction(backRoute: AppRoutes.step5_1SalarySlips),
              ],
            ),
            _buildProgressIndicator(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PremiumCard(
                      gradientColors: [
                        colorScheme.surface,
                        colorScheme.primary.withValues(alpha: 0.03),
                      ],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primary,
                                      colorScheme.secondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.receipt_long,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Upload Salary Slips',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Upload your salary slips for income verification',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildPremiumRequirement(context, Icons.description, 'Upload $_requiredSlipCount salary slips (last 3 months)'),
                          const SizedBox(height: 12),
                          _buildPremiumRequirement(context, Icons.calendar_today, 'Months are auto-selected (last 3 months)'),
                          const SizedBox(height: 12),
                          _buildPremiumRequirement(context, Icons.lock_outline, 'PDF password supported'),
                          const SizedBox(height: 12),
                          _buildPremiumRequirement(context, Icons.add_photo_alternate, 'Upload up to $_requiredSlipCount payslips'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Required Months',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _requiredMonths.map((m) {
                              final label = DateFormat('MMM yyyy').format(m);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: colorScheme.primary.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _hasAllRequiredSlips
                                          ? AppTheme.successColor
                                          : AppTheme.warningColor,
                                      (_hasAllRequiredSlips
                                              ? AppTheme.successColor
                                              : AppTheme.warningColor)
                                          .withValues(alpha: 0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _hasAllRequiredSlips ? Icons.check_circle : Icons.info,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$_uploadedSlipCount/$_requiredSlipCount Salary Slips Uploaded',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    PremiumCard(
                      gradientColors: [
                        colorScheme.primary.withValues(alpha: 0.05),
                        Colors.white,
                      ],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Progress',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _uploadedSlipCount / _requiredSlipCount,
                              minHeight: 10,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _hasAllRequiredSlips ? AppTheme.successColor : colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _hasAllRequiredSlips
                                ? 'All set. You can continue.'
                                : 'Upload $_remainingSlipCount more slip(s) to continue.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _requiredSlipCount,
                      itemBuilder: (context, index) {
                        if (_slipItems[index].hasFile) {
                          return _buildPremiumSlipCard(context, index);
                        }
                        return _buildPremiumEmptySlipSlot(context, index);
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_pdfPassword != null) ...[
                      const SizedBox(height: 24),
                      PremiumCard(
                        gradientColors: [
                          AppTheme.accentColor.withValues(alpha: 0.1),
                          AppTheme.accentColor.withValues(alpha: 0.05),
                        ],
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.lock, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PDF Password Protected',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.accentColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Password: ${'●' * _pdfPassword!.length}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildPremiumRequirement(BuildContext context, IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumSlipCard(BuildContext context, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final slipItem = _slipItems[index];
    final monthFormat = DateFormat('MMM yyyy');
    final slotLabel = index < _requiredMonths.length ? monthFormat.format(_requiredMonths[index]) : 'Month';
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.15),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Make it easy to replace: tap card to change this slot.
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showUploadOptionsForSlot(index),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              height: double.infinity,
              color: colorScheme.surface,
              child: slipItem.isPdf
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.picture_as_pdf,
                            size: 40,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'PDF',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ((slipItem.path.startsWith('http') && (_authToken == null || (index < _slipFailures.length && _slipFailures[index])))
                        ? Center(child: (index < _slipFailures.length && _slipFailures[index]) 
                            ? const Icon(Icons.broken_image, color: Colors.grey) 
                            : const CircularProgressIndicator())
                        : PlatformImage(
                        imagePath: slipItem.path,
                        imageBytes: (index < _slipBytes.length) ? _slipBytes[index] : null,
                        fit: BoxFit.cover,
                        headers: _authToken != null ? {'Authorization': 'Bearer $_authToken'} : null,
                      )),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  // Keep close button red for consistency across previews.
                  color: AppTheme.errorColor.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.errorColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 16),
                  onPressed: () => _removeSlip(index),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  slipItem.isPdf ? 'PDF' : 'IMAGE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.8),
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          slotLabel,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Tap to Replace',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumEmptySlipSlot(BuildContext context, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final monthFormat = DateFormat('MMM yyyy');
    final slotLabel = index < _requiredMonths.length ? monthFormat.format(_requiredMonths[index]) : 'Month';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          // Encourage sequential filling for simpler UX.
          final firstEmpty = _nextSlotIndex;
          if (index != firstEmpty) {
            PremiumToast.showError(
              context,
              'Please upload slips in order (top-left to bottom-right).',
            );
            return;
          }
          _showUploadOptionsForSlot(index);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.25),
              width: 1.5,
            ),
            color: colorScheme.surface,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.upload_file,
                    size: 42,
                    color: colorScheme.primary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    slotLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap to upload',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      color: Colors.white,
      child: Row(
        children: [
          // Steps 1-4: Completed
          for (int i = 1; i <= 4; i++) ...[
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Step 5: Current
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        blurRadius: 12,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '5',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: Colors.grey.shade200,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              ],
            ),
          ),
          // Steps 6-7: Pending
          for (int i = 6; i <= 7; i++) ...[
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$i',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  if (i < 7)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: Colors.grey.shade200,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
