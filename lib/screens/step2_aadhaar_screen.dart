import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import '../providers/submission_provider.dart';
import '../providers/application_provider.dart';
import '../services/file_upload_service.dart';
import '../services/ocr_service.dart';
import '../utils/app_routes.dart';
import '../utils/blob_helper.dart';
import '../widgets/platform_image.dart';
import 'package:http/http.dart' as http;
import '../widgets/premium_toast.dart';
import '../utils/app_theme.dart';
import '../widgets/app_header.dart';
import '../services/storage_service.dart';
import '../utils/api_config.dart';
import '../utils/aadhaar_utils.dart';
import '../utils/aadhaar_image_masker.dart';
import 'aadhaar_grid_capture_screen.dart';
import '../utils/local_file_persist.dart';
import '../utils/ocr_pdf.dart';
import '../models/additional_document.dart';
import '../services/additional_documents_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/premium_progress_indicator.dart';
import '../widgets/preview_header_action.dart';
import '../widgets/prevent_close_on_back.dart';
import '../utils/debug_log.dart';

class Step2AadhaarScreen extends StatefulWidget {
  const Step2AadhaarScreen({
    super.key,
    this.fromPreview = false,
    this.isSpouse = false,
    this.isPartner = false,
    this.isCoApplicant = false,
    this.partnerIndex,
    this.titleOverride,
    this.backRouteOverride,
    this.nextRouteOverride,
    this.progressStepOverride,
    this.totalStepsOverride,
  });

  /// When true, Back returns to Preview (e.g. when opened via Edit from Preview).
  final bool fromPreview;

  /// When true, behaves like spouse Aadhaar screen (same UI/validations, different storage/save).
  final bool isSpouse;

  /// Partnership flow: when true, saves into partner KYC bucket (no personal-data updates).
  final bool isPartner;

  /// Co-applicant (joint loan): when true, saves into submission co-applicant Aadhaar.
  final bool isCoApplicant;

  /// 1-based partner index for partnership flow.
  final int? partnerIndex;

  /// Optional UI/flow overrides for spouse mode.
  final String? titleOverride;
  final String? backRouteOverride;
  final String? nextRouteOverride;
  final int? progressStepOverride;
  final int? totalStepsOverride;

  @override
  State<Step2AadhaarScreen> createState() => _Step2AadhaarScreenState();
}

class _Step2AadhaarScreenState extends State<Step2AadhaarScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final FileUploadService _fileUploadService = FileUploadService();
  final AdditionalDocumentsService _additionalDocumentsService =
      AdditionalDocumentsService();
  String? _frontPath;
  String? _backPath;
  bool _isSaving = false;
  bool _frontIsPdf = false;
  bool _backIsPdf = false;
  String? _frontPdfPassword;
  String? _backPdfPassword;
  double _frontRotation = 0.0;
  double _backRotation = 0.0;
  String? _authToken;
  bool _frontImageFailed = false;
  bool _backImageFailed = false;
  Uint8List? _frontBytes;
  Uint8List? _backBytes;

  // OCR extracted Aadhaar numbers for cross-validation
  String? _frontAadhaarNumber;
  String? _backAadhaarNumber;
  
  // OCR extracted name from Aadhaar (for PAN name cross-validation)
  String? _aadhaarName;
  // Raw text from Aadhaar front (for PAN name validation: at least one word match)
  String? _aadhaarFrontRawText;
  
  // Internal validation flags (secret - not shown to user)
  bool _frontInternalValid = true;
  bool _backInternalValid = true;

  // OCR completeness flags (used to enforce "must extract")
  bool _frontOcrComplete = false;
  bool _backOcrComplete = false;
  String? _frontOcrIssue;
  String? _backOcrIssue;

  /// Normalized rects (0-1) for first two digit-groups on front image. Used for masking before upload.
  List<Map<String, double>>? _frontAadhaarNumberRect;

  /// Normalized rects (0-1) for first two digit-groups on back image. Used for masking before upload.
  List<Map<String, double>>? _backAadhaarNumberRect;

  /// When true, first 8 digits are masked in the uploaded image. When false, original uploaded as-is.
  bool _maskAadhaar = true;

  /// Returns display/storage string for Aadhaar based on _maskAadhaar.
  String _aadhaarDisplay(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 4) return raw;
    if (_maskAadhaar) return AadhaarUtils.maskAadhaar(raw);
    // Full number with spaces: 1234 5678 9012
    if (digits.length >= 12) {
      return '${digits.substring(0, 4)} ${digits.substring(4, 8)} ${digits.substring(8, 12)}';
    }
    if (digits.length >= 8) {
      return '${digits.substring(0, 4)} ${digits.substring(4, 8)} ${digits.substring(8)}';
    }
    if (digits.length >= 4) {
      return '${digits.substring(0, digits.length - 4)} ${digits.substring(digits.length - 4)}';
    }
    return digits;
  }

  /// Parse stored rect data — handles both legacy single-Map and new List format.
  static List<Map<String, double>>? _parseRectsFromStorage(dynamic raw) {
    if (raw is List) {
      final result = <Map<String, double>>[];
      for (final item in raw) {
        if (item is Map) {
          result.add(item.map<String, double>(
              (k, v) => MapEntry(k.toString(), (v is num) ? v.toDouble() : 0.0)));
        }
      }
      return result.isEmpty ? null : result;
    }
    if (raw is Map) {
      return [raw.map<String, double>(
          (k, v) => MapEntry(k.toString(), (v is num) ? v.toDouble() : 0.0))];
    }
    return null;
  }

  bool _isRemoteOrServerPath(String? path) {
    if (path == null) return false;
    final p = path.trim();
    if (p.isEmpty) return false;
    // Treat backend / blob paths as non-local (can't be checked/OCR'ed reliably).
    return p.startsWith('http') ||
        p.startsWith('blob:') ||
        p.startsWith('/uploads/') ||
        p.startsWith('uploads/') ||
        p.startsWith('/api/') ||
        p.startsWith('api/');
  }

  void _syncOcrFlagsFromProvider() {
    if (widget.isSpouse || widget.isPartner || widget.isCoApplicant) return;
    final data = context.read<SubmissionProvider>().submission.personalData;
    if (data == null) return;
    final hasName = (data.nameAsPerAadhaar ?? '').trim().isNotEmpty;
    final hasAadhaar = (data.aadhaarNumber ?? '').trim().isNotEmpty;
    final hasDob = data.dateOfBirth != null;
    final hasAddress = (data.residenceAddress ?? '').trim().isNotEmpty;

    // Consider front complete if DOB is present and at least one of name/aadhaar (per user feedback)
    _frontOcrComplete = hasDob && (hasName || hasAadhaar);
    _backOcrComplete = hasAddress;
  }

  Future<void> _initOcrForExistingDocs() async {
    if (!mounted) return;

    // Applicant flow: when data came from backend we already set _frontOcrComplete/_backOcrComplete in _loadExistingData.
    // Do not overwrite with _syncOcrFlagsFromProvider (which needs DOB/address in personalData) so we don't ask for OCR again.
    if (!widget.isSpouse && !widget.isPartner && !widget.isCoApplicant) {
      if (_frontOcrComplete && _backOcrComplete) return;
      setState(() {
        _syncOcrFlagsFromProvider();
      });
      return;
    }

    // Spouse/Partner flow: re-run OCR for local files; for remote/server paths, consider OCR satisfied
    // (we can't OCR remote URLs, and forcing re-upload is bad UX).
    final front = _frontPath?.trim();
    final back = _backPath?.trim();
    if (front == null || front.isEmpty || back == null || back.isEmpty) return;

    // PDF single-file mode
    if (_frontIsPdf && _backIsPdf && front == back) {
      if (_isRemoteOrServerPath(front)) {
        setState(() {
          _frontOcrComplete = true;
          _backOcrComplete = true;
          _frontOcrIssue = null;
          _backOcrIssue = null;
        });
        return;
      }
      if (!_frontOcrComplete || !_backOcrComplete) {
        await _performAadhaarOcrFromPdf(front);
      }
      return;
    }

    if (!_frontOcrComplete) {
      if (_isRemoteOrServerPath(front)) {
        setState(() {
          _frontOcrComplete = true;
          _frontOcrIssue = null;
        });
      } else {
        await _performAadhaarOCR(front, isFront: true);
      }
    }

    if (!mounted) return;

    if (!_backOcrComplete) {
      if (_isRemoteOrServerPath(back)) {
        setState(() {
          _backOcrComplete = true;
          _backOcrIssue = null;
        });
      } else {
        await _performAadhaarOCR(back, isFront: false);
      }
    }
  }

  // Address proof flow: if true, user says their current address differs from Aadhaar address.
  bool _addressDifferentFromAadhaar = false;

  bool _isValidImageBytes(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // Check for common image headers
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true; // JPEG
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true; // PNG
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) return true; // GIF
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return true; // WebP
    return false;
  }

  /// Strip Aadhaar card system text from OCR address so only user address is shown.
  static String? _filterAadhaarAddressForDisplay(String? raw) {
    if (raw == null || raw.trim().isEmpty) return raw;
    const systemPatterns = [
      'GOVERNMENT OF INDIA',
      'UNIQUE IDENTIFICATION AUTHORITY OF INDIA',
      'UIDAI',
      'AADHAAR',
      'IDENTIFICATION',
      'Address :',
      'Address:',
    ];
    String out = raw;
    for (final p in systemPatterns) {
      out = out.replaceAll(RegExp(RegExp.escape(p), caseSensitive: false), ' ');
    }
    out = out
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s,:\-]+'), '')
        .replaceAll(RegExp(r'[\s,:\-]+$'), '')
        .trim();
    return out.isEmpty ? null : out;
  }

  @override
  void initState() {
    super.initState();
    final provider = context.read<SubmissionProvider>();
    if (widget.isSpouse) {
      _frontPath = provider.submission.businessDocuments?.spouseAadhaar?.frontPath;
      _backPath = provider.submission.businessDocuments?.spouseAadhaar?.backPath;
      _frontIsPdf =
          provider.submission.businessDocuments?.spouseAadhaar?.frontIsPdf ?? false;
      _backIsPdf =
          provider.submission.businessDocuments?.spouseAadhaar?.backIsPdf ?? false;
    } else if (widget.isPartner) {
      final idx = (widget.partnerIndex ?? 1) - 1;
      final partners = provider.submission.businessDocuments?.partners ?? [];
      final partnerAadhaar = partners.asMap().containsKey(idx)
          ? partners[idx].aadhaar
          : null;
      _frontPath = partnerAadhaar?.frontPath;
      _backPath = partnerAadhaar?.backPath;
      _frontIsPdf = partnerAadhaar?.frontIsPdf ?? false;
      _backIsPdf = partnerAadhaar?.backIsPdf ?? false;
      if (partners.asMap().containsKey(idx) && (partners[idx].extractedAadhaarNumber ?? '').trim().isNotEmpty) {
        _frontAadhaarNumber = partners[idx].extractedAadhaarNumber;
        _backAadhaarNumber = partners[idx].extractedAadhaarNumber;
      }
    } else if (widget.isCoApplicant) {
      _frontPath = provider.submission.coApplicantAadhaar?.frontPath;
      _backPath = provider.submission.coApplicantAadhaar?.backPath;
      _frontIsPdf = provider.submission.coApplicantAadhaar?.frontIsPdf ?? false;
      _backIsPdf = provider.submission.coApplicantAadhaar?.backIsPdf ?? false;
      final ext = provider.submission.coApplicantExtractedAadhaarNumber;
      if ((ext ?? '').trim().isNotEmpty) {
        _frontAadhaarNumber = ext;
        _backAadhaarNumber = ext;
      }
    } else {
      _frontPath = provider.submission.aadhaar?.frontPath;
      _backPath = provider.submission.aadhaar?.backPath;
      _frontIsPdf = provider.submission.aadhaar?.frontIsPdf ?? false;
      _backIsPdf = provider.submission.aadhaar?.backIsPdf ?? false;
    }
    
    // Load existing data from backend
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadAuthToken();
      await _loadExistingData();
      if (!kIsWeb) {
        await _recoverLostCameraData();
      }
      await _initOcrForExistingDocs();
    });
  }

  Future<void> _loadAuthToken() async {
    try {
      final storage = StorageService.instance;
      final accessToken = await storage.getAccessToken();
      if (accessToken != null && mounted) {
        setState(() {
          _authToken = accessToken;
        });
      }
    } catch (_) {}
  }

  /// If Android killed the app while the camera was open, recover the captured image
  /// when user returns to this screen (e.g. after relaunch).
  Future<void> _recoverLostCameraData() async {
    try {
      final LostDataResponse response = await _imagePicker.retrieveLostData();
      if (response.isEmpty || !mounted) return;
      final files = response.files;
      if (files != null && files.isNotEmpty) {
        final path = files.single.path;
        debugPrint('[Aadhaar] retrieveLostData recovered path=$path');
        if (path.isNotEmpty && mounted) {
          // Assign to the empty slot. When both are empty, assign to BACK so we never
          // show a single recovered image (often the back side) as the front side.
          final frontFilled = (_frontPath ?? '').trim().isNotEmpty;
          final backFilled = (_backPath ?? '').trim().isNotEmpty;
          final isFront = frontFilled ? false : (backFilled ? true : false);
          final storedPath = await persistLocalPathIfNeeded(
            path,
            preferredExtension: 'jpg',
            subdir: 'lcc_aadhaar',
            prefix: isFront ? 'aadhaar_front' : 'aadhaar_back',
          );
          await _applySideImage(storedPath, isFront: isFront);
        }
      } else if (response.exception != null) {
        debugPrint('[Aadhaar] retrieveLostData exception: ${response.exception}');
      }
    } on UnimplementedError {
      // retrieveLostData is Android-only
    } catch (e, st) {
      debugPrint('[Aadhaar] retrieveLostData error: $e $st');
    }
  }

  Future<void> _loadExistingData() async {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication) return;

    if (widget.isSpouse || widget.isPartner) {
      // Spouse/Partner Aadhaar is stored as "additional documents".
      // We MUST hydrate from backend uploads; otherwise users who already uploaded
      // (or have data on backend) are forced to re-upload / re-OCR.
      try {
        final user = context.read<AuthProvider>().user;
        if (user == null) return;

        final uploaded = await _additionalDocumentsService.getUserDocuments(user.id);

        UploadedDocument? latestDocForType(String type) {
          final matches = uploaded
              .where(
                (d) =>
                    d.documentType == type && (d.url ?? '').trim().isNotEmpty,
              )
              .toList();
          if (matches.isEmpty) return null;
          matches.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
          return matches.first;
        }

        bool isPdfDoc(UploadedDocument? d) {
          final u = (d?.url ?? '').toLowerCase();
          final n = (d?.fileName ?? '').toLowerCase();
          return u.contains('.pdf') || n.endsWith('.pdf');
        }

        final partnerIndex = widget.partnerIndex ?? 1;
        final frontType = widget.isSpouse
            ? 'spouse_aadhaar_front'
            : 'partner_${partnerIndex}_aadhaar_front';
        final backType = widget.isSpouse
            ? 'spouse_aadhaar_back'
            : 'partner_${partnerIndex}_aadhaar_back';

        final frontDoc = latestDocForType(frontType);
        final backDoc = latestDocForType(backType);
        final frontUrl = (frontDoc?.url ?? '').trim();
        final backUrl = (backDoc?.url ?? '').trim();

        if (mounted) {
          // Only set if missing to avoid overwriting local draft values.
          if ((_frontPath ?? '').trim().isEmpty && frontUrl.isNotEmpty) {
            setState(() {
              _frontPath = frontUrl;
              _frontIsPdf = isPdfDoc(frontDoc);
            });
            final provider = context.read<SubmissionProvider>();
            if (widget.isSpouse) {
              provider.setSpouseAadhaarFront(_frontPath!, isPdf: _frontIsPdf);
            } else {
              provider.setPartnerAadhaarFront(
                partnerIndex,
                _frontPath!,
                isPdf: _frontIsPdf,
              );
            }
          }

          if ((_backPath ?? '').trim().isEmpty && backUrl.isNotEmpty) {
            setState(() {
              _backPath = backUrl;
              _backIsPdf = isPdfDoc(backDoc);
            });
            final provider = context.read<SubmissionProvider>();
            if (widget.isSpouse) {
              provider.setSpouseAadhaarBack(_backPath!, isPdf: _backIsPdf);
            } else {
              provider.setPartnerAadhaarBack(
                partnerIndex,
                _backPath!,
                isPdf: _backIsPdf,
              );
            }
          }
        }

        // Best-effort: fetch preview bytes for remote images (not PDFs).
        final token = _authToken;
        Future<void> fetchPreviewIfNeeded(String? url, {required bool isFront}) async {
          if (url == null) return;
          final u = url.trim();
          if (u.isEmpty || !u.startsWith('http')) return;
          if ((isFront ? _frontIsPdf : _backIsPdf) == true) return;
          if (token == null || token.trim().isEmpty) return;
          try {
            final response = await http.get(
              Uri.parse(u),
              headers: {'Authorization': 'Bearer $token'},
            );
            if (!mounted) return;
            if (response.statusCode == 200) {
              final contentType = response.headers['content-type'] ?? '';
              final isLikelyImage = contentType.startsWith('image/');
              final bytes = response.bodyBytes;
              if (isLikelyImage && _isValidImageBytes(bytes)) {
                setState(() {
                  if (isFront) {
                    _frontBytes = bytes;
                    _frontImageFailed = false;
                  } else {
                    _backBytes = bytes;
                    _backImageFailed = false;
                  }
                });
              } else {
                setState(() {
                  if (isFront) _frontImageFailed = true;
                  if (!isFront) _backImageFailed = true;
                });
              }
            } else {
              if (!mounted) return;
              setState(() {
                if (isFront) _frontImageFailed = true;
                if (!isFront) _backImageFailed = true;
              });
            }
          } catch (_) {
            if (!mounted) return;
            setState(() {
              if (isFront) _frontImageFailed = true;
              if (!isFront) _backImageFailed = true;
            });
          }
        }

        await fetchPreviewIfNeeded(_frontPath, isFront: true);
        await fetchPreviewIfNeeded(_backPath, isFront: false);
      } catch (e) {
        debugPrint('[Aadhaar] spouse/partner loadExistingData failed: $e');
      }

      return;
    }

    // Refresh application data from backend to get the latest saved data
    try {
      await appProvider.refreshApplication();
    } catch (e) {
      debugPrint('Aadhaar Screen: Failed to refresh application: $e');
    }

    final application = appProvider.currentApplication!;
    if (application.step2Aadhaar != null) {
      final stepData = application.step2Aadhaar as Map<String, dynamic>;
      final frontUpload = stepData['frontUpload'] as Map<String, dynamic>?;
      final backUpload = stepData['backUpload'] as Map<String, dynamic>?;
      final frontPath = stepData['frontPath'] as String?;
      final backPath = stepData['backPath'] as String?;
      final frontIsPdf = stepData['frontIsPdf'] as bool? ?? false;
      final backIsPdf = stepData['backIsPdf'] as bool? ?? false;
      final frontPdfPassword = stepData['frontPdfPassword'] as String?;
      final backPdfPassword = stepData['backPdfPassword'] as String?;
      final addressDifferentFromAadhaar = stepData['addressDifferentFromAadhaar'] as bool? ?? false;
      final frontAadhaarNumber = stepData['frontAadhaarNumber'] as String?;
      final backAadhaarNumber = stepData['backAadhaarNumber'] as String?;
      final rawRect = stepData['frontAadhaarNumberRect'];
      final frontAadhaarNumberRect = _parseRectsFromStorage(rawRect);
      final rawBackRect = stepData['backAadhaarNumberRect'];
      final backAadhaarNumberRect = _parseRectsFromStorage(rawBackRect);
      final aadhaarName = stepData['aadhaarName'] as String?;
      final aadhaarFrontRawText = stepData['aadhaarFrontRawText'] as String?;

      // Helper to build full URL - transform /uploads/{category}/ to /api/v1/uploads/files/{category}/
      String? buildFullUrl(String? relativeUrl) {
        if (relativeUrl == null || relativeUrl.isEmpty) return null;
        if (relativeUrl.startsWith('http') || relativeUrl.startsWith('blob:')) {
          return relativeUrl;
        }
        // Convert /uploads/aadhaar/... to /api/v1/uploads/files/aadhaar/...
        String apiPath = relativeUrl;
        if (apiPath.startsWith('/uploads/') &&
            !apiPath.contains('/uploads/files/')) {
          apiPath = apiPath.replaceFirst('/uploads/', '/api/v1/uploads/files/');
        } else if (!apiPath.startsWith('/api/')) {
          apiPath = '/api/v1$apiPath';
        }
        return '${ApiConfig.baseUrl}$apiPath';
      }
      
      // Prefer uploaded file URL over local blob path (same as business/bank flow: use backend data, do not re-OCR).
      final effectiveFront = buildFullUrl(frontUpload?['url'] as String?) ?? frontPath;
      final effectiveBack = buildFullUrl(backUpload?['url'] as String?) ?? backPath;
      
      // Get access token for authenticated request
      final storage = StorageService.instance;
      final accessToken = await storage.getAccessToken();
      if (accessToken != null && mounted) {
        setState(() {
          _authToken = accessToken;
        });
      }
      
      if (effectiveFront != null && effectiveFront.isNotEmpty) {
        setState(() {
          _frontPath = effectiveFront;
          _frontIsPdf = frontIsPdf;
          _frontPdfPassword = frontPdfPassword;
        });
        // Also update SubmissionProvider
        context
            .read<SubmissionProvider>()
            .setAadhaarFront(effectiveFront, isPdf: frontIsPdf);
      }
      
      if (effectiveBack != null && effectiveBack.isNotEmpty) {
        setState(() {
          _backPath = effectiveBack;
          _backIsPdf = backIsPdf;
          _backPdfPassword = backPdfPassword;
        });
        // Also update SubmissionProvider
        context
            .read<SubmissionProvider>()
            .setAadhaarBack(effectiveBack, isPdf: backIsPdf);
      }

      // Load address toggle state (for Step 5 conditional field)
      if (mounted) {
        final provider = context.read<SubmissionProvider>();
        provider.updatePersonalDataField(
          addressDifferentFromAadhaar: addressDifferentFromAadhaar,
        );
        if (frontAadhaarNumber != null && frontAadhaarNumber.trim().isNotEmpty) {
          provider.updatePersonalDataField(aadhaarNumber: AadhaarUtils.maskAadhaar(frontAadhaarNumber));
        }
        if (aadhaarName != null && aadhaarName.trim().isNotEmpty) {
          provider.updatePersonalDataField(fullName: aadhaarName);
        }

        // When data is from backend (business/bank flow): do not re-run OCR. Mark OCR complete from step data.
        final hasFrontOcrFromBackend = (frontAadhaarNumber ?? '').trim().isNotEmpty &&
            (aadhaarName ?? '').trim().isNotEmpty;
        final hasBackOcrFromBackend = (backAadhaarNumber ?? '').trim().isNotEmpty;

        setState(() {
          _addressDifferentFromAadhaar = addressDifferentFromAadhaar;
          _frontAadhaarNumber = frontAadhaarNumber;
          _backAadhaarNumber = backAadhaarNumber;
          _frontAadhaarNumberRect = frontAadhaarNumberRect;
          _backAadhaarNumberRect = backAadhaarNumberRect;
          _aadhaarName = aadhaarName;
          _aadhaarFrontRawText = aadhaarFrontRawText;
          if (hasFrontOcrFromBackend) {
            _frontOcrComplete = true;
            _frontOcrIssue = null;
          }
          if (hasBackOcrFromBackend) {
            _backOcrComplete = true;
            _backOcrIssue = null;
          }
          if (!hasFrontOcrFromBackend || !hasBackOcrFromBackend) {
            _syncOcrFlagsFromProvider();
          }
        });
      }
      
      // Fetch front image if network URL
      if (effectiveFront != null && effectiveFront.startsWith('http') && accessToken != null) {
        try {
          final response = await http.get(
            Uri.parse(effectiveFront),
            headers: {'Authorization': 'Bearer $accessToken'},
          );
          if (response.statusCode == 200 && mounted) {
            final contentType = response.headers['content-type'] ?? '';
            final isLikelyImage = contentType.startsWith('image/');
            final bytes = response.bodyBytes;
            if (isLikelyImage && _isValidImageBytes(bytes)) {
              setState(() {
                _frontBytes = bytes;
                _frontImageFailed = false;
              });
            } else {
              setState(() { _frontImageFailed = true; });
            }
          } else {
             if (mounted) setState(() { _frontImageFailed = true; });
          }
        } catch (e) {
          if (mounted) setState(() { _frontImageFailed = true; });
        }
      }

      // Fetch back image if network URL
      if (effectiveBack != null && effectiveBack.startsWith('http') && accessToken != null) {
         try {
          final response = await http.get(
            Uri.parse(effectiveBack),
            headers: {'Authorization': 'Bearer $accessToken'},
          );
          if (response.statusCode == 200 && mounted) {
            final contentType = response.headers['content-type'] ?? '';
            final isLikelyImage = contentType.startsWith('image/');
            final bytes = response.bodyBytes;
            if (isLikelyImage && _isValidImageBytes(bytes)) {
              setState(() {
                _backBytes = bytes;
                _backImageFailed = false;
              });
            } else {
              setState(() { _backImageFailed = true; });
            }
          } else {
             if (mounted) setState(() { _backImageFailed = true; });
          }
        } catch (e) {
          if (mounted) setState(() { _backImageFailed = true; });
        }
      }
    }
  }

  void _removePdf() {
    setState(() {
      _frontPath = null;
      _backPath = null;
      _frontIsPdf = false;
      _backIsPdf = false;
      _frontPdfPassword = null;
      _backPdfPassword = null;
      _frontRotation = 0.0;
      _backRotation = 0.0;
      _frontAadhaarNumber = null;
      _backAadhaarNumber = null;
      _frontAadhaarNumberRect = null;
      _backAadhaarNumberRect = null;
      _aadhaarName = null;
      _aadhaarFrontRawText = null;
      _frontInternalValid = true;
      _backInternalValid = true;
      _addressDifferentFromAadhaar = false;
    });
    final provider = context.read<SubmissionProvider>();
    if (widget.isSpouse) {
      provider.clearSpouseAadhaar();
    } else if (widget.isPartner) {
      provider.clearPartnerAadhaar(widget.partnerIndex ?? 1);
    } else if (widget.isCoApplicant) {
      provider.clearCoApplicantAadhaar();
    } else {
      provider.clearAadhaar();
    }
  }

  void _removeFrontImage() {
    setState(() {
      _frontPath = null;
      _frontIsPdf = false;
      _frontRotation = 0.0;
      _frontPdfPassword = null;
      _frontAadhaarNumber = null;
      _frontAadhaarNumberRect = null;
      _aadhaarName = null; // Name comes from front side
      _aadhaarFrontRawText = null;
      _frontInternalValid = true;
    });
    final provider = context.read<SubmissionProvider>();
    if (widget.isSpouse) {
      provider.clearSpouseAadhaar();
    } else if (widget.isPartner) {
      provider.clearPartnerAadhaar(widget.partnerIndex ?? 1);
    } else if (widget.isCoApplicant) {
      provider.clearCoApplicantAadhaar();
    } else {
      provider.clearAadhaarFront();
    }
  }

  void _removeBackImage() {
    setState(() {
      _backPath = null;
      _backIsPdf = false;
      _backRotation = 0.0;
      _backPdfPassword = null;
      _backAadhaarNumber = null;
      _backAadhaarNumberRect = null;
      _backInternalValid = true;
    });
    final provider = context.read<SubmissionProvider>();
    if (widget.isSpouse) {
      provider.clearSpouseAadhaar();
    } else if (widget.isPartner) {
      provider.clearPartnerAadhaar(widget.partnerIndex ?? 1);
    } else if (widget.isCoApplicant) {
      provider.clearCoApplicantAadhaar();
    } else {
      provider.clearAadhaarBack();
    }
  }

  Future<String?> _cropImage(String path) async {
    debugPrint('[Aadhaar] _cropImage ENTER path=$path kIsWeb=$kIsWeb');
    if (kIsWeb) {
      debugPrint('[Aadhaar] _cropImage SKIP (web), returning path');
      return path;
    }
    try {
      debugPrint('[Aadhaar] _cropImage calling ImageCropper().cropImage()');
      final cropped = await ImageCropper().cropImage(
        sourcePath: path,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Aadhaar',
            toolbarColor: AppTheme.primaryColor,
            toolbarWidgetColor: Colors.white,
            statusBarColor: AppTheme.primaryColor,
            activeControlsWidgetColor: AppTheme.primaryColor,
            hideBottomControls: false,
            showCropGrid: true,
            cropGridStrokeWidth: 2,
            cropFrameStrokeWidth: 3,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Crop Aadhaar'),
        ],
      );
      final result = cropped?.path ?? path;
      debugPrint('[Aadhaar] _cropImage DONE cropped.path=${cropped?.path} result=$result');
      return result;
    } catch (e, st) {
      debugPrint('[Aadhaar] _cropImage CAUGHT: $e');
      debugPrint('[Aadhaar] _cropImage STACK: $st');
      return path;
    }
  }

  /// Same logic for front and back: crop path, update state/provider, run OCR.
  Future<void> _applySideImage(String path, {required bool isFront}) async {
    debugPrint('[Aadhaar] _applySideImage ENTER path=$path isFront=$isFront mounted=$mounted');
    if (!mounted) {
      debugPrint('[Aadhaar] _applySideImage EARLY EXIT (!mounted)');
      return;
    }
    try {
      if (isFront) {
        debugPrint('[Aadhaar] _applySideImage setState front');
        setState(() {
          _frontPath = path;
          _frontBytes = null;
          _frontIsPdf = false;
          _frontRotation = 0.0;
        });
        final provider = context.read<SubmissionProvider>();
        if (widget.isSpouse) {
          provider.setSpouseAadhaarFront(path, isPdf: false);
        } else if (widget.isPartner) {
          provider.setPartnerAadhaarFront(widget.partnerIndex ?? 1, path, isPdf: false);
        } else if (widget.isCoApplicant) {
          provider.setCoApplicantAadhaarFront(path, isPdf: false);
        } else {
          provider.setAadhaarFront(path, isPdf: false);
        }
      } else {
        debugPrint('[Aadhaar] _applySideImage setState back');
        setState(() {
          _backPath = path;
          _backBytes = null;
          _backIsPdf = false;
          _backRotation = 0.0;
        });
        final provider = context.read<SubmissionProvider>();
        if (widget.isSpouse) {
          provider.setSpouseAadhaarBack(path, isPdf: false);
        } else if (widget.isPartner) {
          provider.setPartnerAadhaarBack(widget.partnerIndex ?? 1, path, isPdf: false);
        } else if (widget.isCoApplicant) {
          provider.setCoApplicantAadhaarBack(path, isPdf: false);
        } else {
          provider.setAadhaarBack(path, isPdf: false);
        }
      }
      debugPrint('[Aadhaar] _applySideImage calling _performAadhaarOCR');
      await _performAadhaarOCR(path, isFront: isFront);
      debugPrint('[Aadhaar] _applySideImage DONE');
    } catch (e, st) {
      debugPrint('[Aadhaar] _applySideImage CAUGHT: $e');
      debugPrint('[Aadhaar] _applySideImage STACK: $st');
      rethrow;
    }
  }

  Future<void> _captureFront() async {
    debugPrint('[Aadhaar] _captureFront ENTER');
    try {
      if (kIsWeb) {
        debugPrint('[Aadhaar] _captureFront (web) using pickImage(camera)');
        final image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          requestFullMetadata: false,
        );
        debugPrint('[Aadhaar] _captureFront pickImage returned: image=${image != null} path=${image?.path} mounted=$mounted');
        if (image != null && mounted) {
          final path = await _cropImage(image.path);
          if (path != null && mounted) {
            final storedPath = await persistLocalPathIfNeeded(
              path,
              preferredExtension: 'jpg',
              subdir: 'lcc_aadhaar',
              prefix: 'aadhaar_front',
            );
            if (mounted) await _applySideImage(storedPath, isFront: true);
          }
        }
        return;
      }
      // Use in-app camera so our activity stays in foreground (avoids "Lost connection" when system camera takes over)
      debugPrint('[Aadhaar] _captureFront (mobile) opening AadhaarGridCaptureScreen');
      final result = await Navigator.of(context).push<XFile>(
        MaterialPageRoute<XFile>(
          builder: (context) => const AadhaarGridCaptureScreen(isFront: true),
        ),
      );
      debugPrint('[Aadhaar] _captureFront AadhaarGridCaptureScreen returned: result=${result != null} path=${result?.path} mounted=$mounted');
      if (result != null && mounted) {
        final path = await _cropImage(result.path);
        if (path != null && mounted) {
          final storedPath = await persistLocalPathIfNeeded(
            path,
            preferredExtension: 'jpg',
            subdir: 'lcc_aadhaar',
            prefix: 'aadhaar_front',
          );
          if (mounted) await _applySideImage(storedPath, isFront: true);
        }
      }
    } catch (e, st) {
      debugPrint('[Aadhaar] _captureFront CAUGHT: $e');
      debugPrint('[Aadhaar] _captureFront STACK: $st');
    }
  }

  Future<void> _selectFrontFromGallery() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      final path = await _cropImage(image.path);
      if (path != null && mounted) {
        final storedPath = await persistLocalPathIfNeeded(
          path,
          preferredExtension: 'jpg',
          subdir: 'lcc_aadhaar',
          prefix: 'aadhaar_front',
        );
        if (mounted) await _applySideImage(storedPath, isFront: true);
      }
    }
  }

  Future<void> _captureBack() async {
    debugPrint('[Aadhaar] _captureBack ENTER');
    try {
      if (kIsWeb) {
        debugPrint('[Aadhaar] _captureBack (web) using pickImage(camera)');
        final image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          requestFullMetadata: false,
        );
        debugPrint('[Aadhaar] _captureBack pickImage returned: image=${image != null} path=${image?.path} mounted=$mounted');
        if (image != null && mounted) {
          final path = await _cropImage(image.path);
          if (path != null && mounted) {
            final storedPath = await persistLocalPathIfNeeded(
              path,
              preferredExtension: 'jpg',
              subdir: 'lcc_aadhaar',
              prefix: 'aadhaar_back',
            );
            if (mounted) await _applySideImage(storedPath, isFront: false);
          }
        }
        return;
      }
      debugPrint('[Aadhaar] _captureBack (mobile) opening AadhaarGridCaptureScreen');
      final result = await Navigator.of(context).push<XFile>(
        MaterialPageRoute<XFile>(
          builder: (context) => const AadhaarGridCaptureScreen(isFront: false),
        ),
      );
      debugPrint('[Aadhaar] _captureBack AadhaarGridCaptureScreen returned: result=${result != null} path=${result?.path} mounted=$mounted');
      if (result != null && mounted) {
        final path = await _cropImage(result.path);
        if (path != null && mounted) {
          final storedPath = await persistLocalPathIfNeeded(
            path,
            preferredExtension: 'jpg',
            subdir: 'lcc_aadhaar',
            prefix: 'aadhaar_back',
          );
          if (mounted) await _applySideImage(storedPath, isFront: false);
        }
      }
    } catch (e, st) {
      debugPrint('[Aadhaar] _captureBack CAUGHT: $e');
      debugPrint('[Aadhaar] _captureBack STACK: $st');
    }
  }

  Future<void> _selectBackFromGallery() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      final path = await _cropImage(image.path);
      if (path != null && mounted) {
        final storedPath = await persistLocalPathIfNeeded(
          path,
          preferredExtension: 'jpg',
          subdir: 'lcc_aadhaar',
          prefix: 'aadhaar_back',
        );
        if (mounted) await _applySideImage(storedPath, isFront: false);
      }
    }
  }

  /// Perform OCR on Aadhaar image and show extracted data
  Future<void> _performAadhaarOCR(String imagePath, {required bool isFront}) async {
    debugPrint('[Aadhaar] _performAadhaarOCR ENTER imagePath=$imagePath isFront=$isFront mounted=$mounted');
    if (!mounted) {
      debugPrint('[Aadhaar] _performAadhaarOCR EARLY EXIT (!mounted)');
      return;
    }

    try {
      // Show loading indicator
      if (mounted) {
        PremiumToast.showInfo(
          context,
          'Extracting text from Aadhaar card...',
          duration: const Duration(seconds: 2),
        );
      }

      debugPrint('[Aadhaar] _performAadhaarOCR calling OcrService.extractAadhaarText');
      final result = await OcrService.extractAadhaarText(imagePath, isFront: isFront);
      debugPrint('[Aadhaar] _performAadhaarOCR OcrService returned success=${result.success}');

      if (!mounted) return;

      if (result.success) {
        final extractedData = <String>[];
        final provider = context.read<SubmissionProvider>();
        
        // Store the Aadhaar number for cross-validation
        if (result.hasAadhaarNumber) {
          if (isFront) {
            _frontAadhaarNumber = result.aadhaarNumber;
            _frontInternalValid = result.isInternallyValid;
          } else {
            _backAadhaarNumber = result.aadhaarNumber;
            _backInternalValid = result.isInternallyValid;
          }
        }

        // Store number bounding rects for masking before upload
        if (result.aadhaarNumberRect != null) {
          if (isFront) {
            setState(() => _frontAadhaarNumberRect = result.aadhaarNumberRect!.rects);
          } else {
            setState(() => _backAadhaarNumberRect = result.aadhaarNumberRect!.rects);
          }
        }

        if (isFront) {
          // Front side: Show Aadhaar number, Name, and DOB, auto-fill to personal data
          if (result.hasAadhaarNumber) {
            final display = _aadhaarDisplay(result.aadhaarNumber);
            extractedData.add('Aadhaar: $display');
            if (!widget.isSpouse && !widget.isPartner && !widget.isCoApplicant) {
              provider.updatePersonalDataField(aadhaarNumber: AadhaarUtils.maskAadhaar(result.aadhaarNumber));
            }
          }
          if (result.hasName) {
            extractedData.add('Name: ${result.name}');
            // Store name for PAN cross-validation
            _aadhaarName = result.name;
            if (widget.isCoApplicant) {
              provider.setCoApplicantExtractedNameFromAadhaar(result.name);
            } else if (!widget.isSpouse && !widget.isPartner) {
              // Auto-fill name to personal data (applicant only)
              provider.updatePersonalDataField(fullName: result.name);
            }
          }
          // Store raw text from Aadhaar front for PAN name validation (at least one word match)
          if (result.fullText != null && result.fullText!.isNotEmpty) {
            _aadhaarFrontRawText = result.fullText;
          }
          if (result.hasDateOfBirth) {
            extractedData.add('DOB: ${result.dateOfBirth}');
            if (!widget.isSpouse && !widget.isPartner && !widget.isCoApplicant) {
              // Auto-fill DOB to personal data (applicant only)
              try {
                final dobParts = result.dateOfBirth!.split('/');
                if (dobParts.length == 3) {
                  final dob = DateTime(
                    int.parse(dobParts[2]), // year
                    int.parse(dobParts[1]), // month
                    int.parse(dobParts[0]), // day
                  );
                  provider.updatePersonalDataField(dateOfBirth: dob);
                }
              } catch (e) {
                debugPrint('Error parsing DOB: $e');
              }
            }
          }

          final missing = <String>[];
          if (!result.hasAadhaarNumber) missing.add('Aadhaar Number');
          if (!result.hasName) missing.add('Name');
          if (!result.hasDateOfBirth) missing.add('DOB');
          // Consider front complete if DOB is present (user said "even if DOB is mentioned it shows incomplete")
          final frontComplete = missing.isEmpty ||
              (result.hasDateOfBirth && (result.hasName || result.hasAadhaarNumber));
          // #region agent log
          debugAgentLog(
            location: 'step2_aadhaar_screen.dart:_performAadhaarOCR(front)',
            message: 'Aadhaar front OCR result',
            data: {
              'hasDOB': result.hasDateOfBirth,
              'hasName': result.hasName,
              'hasAadhaarNumber': result.hasAadhaarNumber,
              'missing': missing,
              'frontComplete': frontComplete,
            },
            hypothesisId: 'H-A',
          );
          // #endregion
          setState(() {
            _frontOcrComplete = frontComplete;
            _frontOcrIssue =
                frontComplete ? null : 'Missing: ${missing.join(', ')}';
          });
          if (!frontComplete && missing.isNotEmpty && mounted) {
            PremiumToast.showWarning(
              context,
              'Aadhaar front OCR incomplete: ${missing.join(', ')}',
              duration: const Duration(seconds: 3),
            );
          }
        } else {
          // Back side: Show address, auto-fill address
          if (result.hasAddress) {
            final filteredAddress = _filterAadhaarAddressForDisplay(result.address);
            // #region agent log
            debugAgentLog(
              location: 'step2_aadhaar_screen.dart:address(back)',
              message: 'Address filter result',
              data: {
                'rawLength': result.address?.length ?? 0,
                'filteredLength': filteredAddress?.length ?? 0,
                'usedFiltered': filteredAddress != null && filteredAddress.length >= 10,
              },
              hypothesisId: 'H-B',
            );
            // #endregion
            if (filteredAddress != null && filteredAddress.length >= 10) {
              extractedData.add('Address: $filteredAddress');
              if (!widget.isSpouse && !widget.isPartner && !widget.isCoApplicant) {
                provider.updatePersonalDataField(address: filteredAddress);
              }
            } else {
              extractedData.add('Address: ${result.address}');
              if (!widget.isSpouse && !widget.isPartner && !widget.isCoApplicant && result.address != null && result.address!.trim().length >= 10) {
                provider.updatePersonalDataField(address: result.address!.trim());
              }
            }
          }
          
          // Also store the back side Aadhaar number for cross-validation (extracted above)
          if (result.hasAadhaarNumber) {
            extractedData.add('Aadhaar verified: ${_aadhaarDisplay(result.aadhaarNumber)}');
          }

          final missing = <String>[];
          if (!result.hasAddress) missing.add('Address');
          setState(() {
            _backOcrComplete = missing.isEmpty;
            _backOcrIssue =
                missing.isEmpty ? null : 'Missing: ${missing.join(', ')}';
          });
          if (missing.isNotEmpty && mounted) {
            PremiumToast.showWarning(
              context,
              'Aadhaar back OCR incomplete: ${missing.join(', ')}',
              duration: const Duration(seconds: 3),
            );
          }
        }

        if (extractedData.isNotEmpty) {
          PremiumToast.showSuccess(
            context,
            'Verified',
            duration: const Duration(seconds: 2),
          );
        } else {
          PremiumToast.showWarning(
            context,
            'No data extracted. Please ensure image is clear.',
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        PremiumToast.showWarning(
          context,
          result.errorMessage ?? 'Could not extract text from image',
          duration: const Duration(seconds: 3),
        );
        setState(() {
          if (isFront) {
            _frontOcrComplete = false;
            _frontOcrIssue = result.errorMessage ?? 'OCR failed';
          } else {
            _backOcrComplete = false;
            _backOcrIssue = result.errorMessage ?? 'OCR failed';
          }
        });
      }
    } catch (e, st) {
      if (mounted) {
        debugPrint('[Aadhaar] _performAadhaarOCR CAUGHT: $e');
        debugPrint('[Aadhaar] _performAadhaarOCR STACK: $st');
        setState(() {
          if (isFront) {
            _frontOcrComplete = false;
            _frontOcrIssue = 'OCR failed';
          } else {
            _backOcrComplete = false;
            _backOcrIssue = 'OCR failed';
          }
        });
      }
    }
  }

  /// PDF-only OCR path.
  /// Keeps the existing image OCR flow untouched.
  Future<void> _performAadhaarOcrFromPdf(String pdfPath) async {
    if (!mounted) return;

    if (!OcrPdf.isSupported) {
      PremiumToast.showWarning(
        context,
        'PDF OCR is not supported on this platform. Please upload Aadhaar photos.',
        duration: const Duration(seconds: 3),
      );
      setState(() {
        _frontOcrComplete = false;
        _backOcrComplete = false;
        _frontOcrIssue = 'PDF OCR not supported';
        _backOcrIssue = 'PDF OCR not supported';
      });
      return;
    }

    if (pdfPath.startsWith('http') || pdfPath.startsWith('blob:')) {
      PremiumToast.showWarning(
        context,
        'PDF OCR requires a local PDF file. Please re-upload the PDF from this device or upload photos.',
        duration: const Duration(seconds: 4),
      );
      setState(() {
        _frontOcrComplete = false;
        _backOcrComplete = false;
        _frontOcrIssue = 'Remote PDF not supported for OCR';
        _backOcrIssue = 'Remote PDF not supported for OCR';
      });
      return;
    }

    try {
      PremiumToast.showInfo(
        context,
        'Extracting Aadhaar details from PDF...',
        duration: const Duration(seconds: 2),
      );

      final pageCount = await OcrPdf.getPageCount(pdfPath);
      final frontIndex = 0;
      final backIndex = pageCount >= 2 ? 1 : 0;

      final frontBytes = await OcrPdf.renderPageToJpegBytes(pdfPath, pageIndex: frontIndex);
      await _performAadhaarOCRFromBytes(frontBytes, isFront: true);

      final backBytes = await OcrPdf.renderPageToJpegBytes(pdfPath, pageIndex: backIndex);
      await _performAadhaarOCRFromBytes(backBytes, isFront: false);
    } catch (e, st) {
      debugPrint('[Aadhaar] _performAadhaarOcrFromPdf FAILED: $e');
      debugPrint('[Aadhaar] _performAadhaarOcrFromPdf STACK: $st');
      if (!mounted) return;
      PremiumToast.showWarning(
        context,
        'Unable to OCR this PDF (password-protected PDFs are not supported). Please upload photos.',
        duration: const Duration(seconds: 4),
      );
      setState(() {
        _frontOcrComplete = false;
        _backOcrComplete = false;
        _frontOcrIssue = 'PDF OCR failed';
        _backOcrIssue = 'PDF OCR failed';
      });
    }
  }

  Future<void> _performAadhaarOCRFromBytes(Uint8List bytes, {required bool isFront}) async {
    if (!mounted) return;
    try {
      final result = await OcrService.extractAadhaarText(
        'pdf://aadhaar/${isFront ? 'front' : 'back'}',
        imageBytes: bytes,
        isFront: isFront,
      );

      if (!mounted) return;

      // Reuse the same success/error UI and provider updates as image OCR.
      if (result.success) {
        final extractedData = <String>[];
        final provider = context.read<SubmissionProvider>();

        if (result.hasAadhaarNumber) {
          if (isFront) {
            _frontAadhaarNumber = result.aadhaarNumber;
            _frontInternalValid = result.isInternallyValid;
          } else {
            _backAadhaarNumber = result.aadhaarNumber;
            _backInternalValid = result.isInternallyValid;
          }
        }

        // Store number bounding rects for masking before upload
        if (result.aadhaarNumberRect != null) {
          if (isFront) {
            setState(() => _frontAadhaarNumberRect = result.aadhaarNumberRect!.rects);
          } else {
            setState(() => _backAadhaarNumberRect = result.aadhaarNumberRect!.rects);
          }
        }

        if (isFront) {
          if (result.hasAadhaarNumber) {
            final display = _aadhaarDisplay(result.aadhaarNumber);
            extractedData.add('Aadhaar: $display');
            provider.updatePersonalDataField(aadhaarNumber: AadhaarUtils.maskAadhaar(result.aadhaarNumber));
          }
          if (result.hasName) {
            extractedData.add('Name: ${result.name}');
            _aadhaarName = result.name;
            provider.updatePersonalDataField(fullName: result.name);
          }
          if (result.fullText != null && result.fullText!.isNotEmpty) {
            _aadhaarFrontRawText = result.fullText;
          }
          if (result.hasDateOfBirth) {
            extractedData.add('DOB: ${result.dateOfBirth}');
            try {
              final dobParts = result.dateOfBirth!.split('/');
              if (dobParts.length == 3) {
                final dob = DateTime(
                  int.parse(dobParts[2]),
                  int.parse(dobParts[1]),
                  int.parse(dobParts[0]),
                );
                provider.updatePersonalDataField(dateOfBirth: dob);
              }
            } catch (e) {
              debugPrint('Error parsing DOB: $e');
            }
          }

          final missing = <String>[];
          if (!result.hasAadhaarNumber) missing.add('Aadhaar Number');
          if (!result.hasName) missing.add('Name');
          if (!result.hasDateOfBirth) missing.add('DOB');
          final frontComplete = missing.isEmpty ||
              (result.hasDateOfBirth && (result.hasName || result.hasAadhaarNumber));
          // #region agent log
          debugAgentLog(
            location: 'step2_aadhaar_screen.dart:_performAadhaarOCRFromBytes(front)',
            message: 'Aadhaar front OCR result',
            data: {
              'hasDOB': result.hasDateOfBirth,
              'hasName': result.hasName,
              'hasAadhaarNumber': result.hasAadhaarNumber,
              'missing': missing,
              'frontComplete': frontComplete,
            },
            hypothesisId: 'H-A',
          );
          // #endregion
          setState(() {
            _frontOcrComplete = frontComplete;
            _frontOcrIssue = frontComplete ? null : 'Missing: ${missing.join(', ')}';
          });
          if (!frontComplete && missing.isNotEmpty && mounted) {
            PremiumToast.showWarning(
              context,
              'Aadhaar front OCR incomplete: ${missing.join(', ')}',
              duration: const Duration(seconds: 3),
            );
          }
        } else {
          if (result.hasAddress) {
            final filteredAddress = _filterAadhaarAddressForDisplay(result.address);
            // #region agent log
            debugAgentLog(
              location: 'step2_aadhaar_screen.dart:address(backBytes)',
              message: 'Address filter result',
              data: {
                'rawLength': result.address?.length ?? 0,
                'filteredLength': filteredAddress?.length ?? 0,
                'usedFiltered': filteredAddress != null && filteredAddress.length >= 10,
              },
              hypothesisId: 'H-B',
            );
            // #endregion
            if (filteredAddress != null && filteredAddress.length >= 10) {
              extractedData.add('Address: $filteredAddress');
              provider.updatePersonalDataField(address: filteredAddress);
            } else if (result.address != null && result.address!.trim().length >= 10) {
              extractedData.add('Address: ${result.address}');
              provider.updatePersonalDataField(address: result.address!.trim());
            }
          }
          if (result.hasAadhaarNumber) {
            extractedData.add('Aadhaar verified: ${_aadhaarDisplay(result.aadhaarNumber)}');
          }
          final missing = <String>[];
          if (!result.hasAddress) missing.add('Address');
          setState(() {
            _backOcrComplete = missing.isEmpty;
            _backOcrIssue = missing.isEmpty ? null : 'Missing: ${missing.join(', ')}';
          });
          if (missing.isNotEmpty && mounted) {
            PremiumToast.showWarning(
              context,
              'Aadhaar back OCR incomplete: ${missing.join(', ')}',
              duration: const Duration(seconds: 3),
            );
          }
        }

        if (extractedData.isNotEmpty) {
          PremiumToast.showSuccess(
            context,
            'Verified',
            duration: const Duration(seconds: 2),
          );
        }
      } else {
        setState(() {
          if (isFront) {
            _frontOcrComplete = false;
            _frontOcrIssue = result.errorMessage ?? 'OCR failed';
          } else {
            _backOcrComplete = false;
            _backOcrIssue = result.errorMessage ?? 'OCR failed';
          }
        });
      }
    } catch (e, st) {
      debugPrint('[Aadhaar] _performAadhaarOCRFromBytes CAUGHT: $e');
      debugPrint('[Aadhaar] _performAadhaarOCRFromBytes STACK: $st');
      if (!mounted) return;
      setState(() {
        if (isFront) {
          _frontOcrComplete = false;
          _frontOcrIssue = 'OCR failed';
        } else {
          _backOcrComplete = false;
          _backOcrIssue = 'OCR failed';
        }
      });
    }
  }

  Future<void> _uploadPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      String path;
      
      if (kIsWeb) {
        final bytes = result.files.single.bytes;
        if (bytes == null) {
          if (mounted) {
            PremiumToast.showError(context, 'Unable to read PDF file');
          }
          return;
        }
        path = createBlobUrl(bytes, mimeType: 'application/pdf');
      } else {
        if (result.files.single.path == null) {
          if (mounted) {
            PremiumToast.showError(context, 'Unable to access file');
          }
          return;
        }
        path = await persistLocalPathIfNeeded(
          result.files.single.path!,
          preferredExtension: 'pdf',
          subdir: 'lcc_aadhaar',
          prefix: 'aadhaar_pdf',
        );
      }
      
      if (mounted) {
        setState(() {
          // Set both front and back to the same PDF
          _frontPath = path;
          _backPath = path;
          _frontIsPdf = true;
          _backIsPdf = true;
          _frontRotation = 0.0;
          _backRotation = 0.0;
          _frontOcrComplete = false;
          _backOcrComplete = false;
        });
        final provider = context.read<SubmissionProvider>();
        if (widget.isSpouse) {
          provider.setSpouseAadhaarFront(path, isPdf: true);
          provider.setSpouseAadhaarBack(path, isPdf: true);
        } else if (widget.isPartner) {
          provider.setPartnerAadhaarFront(widget.partnerIndex ?? 1, path, isPdf: true);
          provider.setPartnerAadhaarBack(widget.partnerIndex ?? 1, path, isPdf: true);
        } else if (widget.isCoApplicant) {
          provider.setCoApplicantAadhaarFront(path, isPdf: true);
          provider.setCoApplicantAadhaarBack(path, isPdf: true);
        } else {
          provider.setAadhaarFront(path, isPdf: true);
          provider.setAadhaarBack(path, isPdf: true);
        }
        await _performAadhaarOcrFromPdf(path);
        _showPasswordDialogIfNeeded('both');
      }
    }
  }

  void _showPasswordDialogIfNeeded(String side) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Is this PDF password protected?${side == 'both' ? '' : ' (${side == 'front' ? 'Front' : 'Back'} side)'}'),
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
              if (mounted) {
                setState(() {
                  if (side == 'front') {
                    _frontPdfPassword = password.isNotEmpty ? password : null;
                  } else if (side == 'back') {
                    _backPdfPassword = password.isNotEmpty ? password : null;
                  } else if (side == 'both') {
                    // For single PDF covering both sides, set same password for both
                    _frontPdfPassword = password.isNotEmpty ? password : null;
                    _backPdfPassword = password.isNotEmpty ? password : null;
                  }
                });
              }
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Saves draft to DB. Returns true only if save succeeded; then safe to go to next step.
  Future<bool> _saveToBackend() async {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication || _frontPath == null || _backPath == null) {
      return false;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.isSpouse || widget.isPartner) {
        // Spouse/Partner mode: upload as "additional documents" (same UI; different persistence).
        String? leadId;
        try {
          final user = context.read<AuthProvider>().user;
          if (user != null) {
            String? phoneNumber;
            if (user.email.endsWith('@phone.local')) {
              phoneNumber = user.email.split('@')[0];
            }
            final lead = await _additionalDocumentsService.getLeadByUser(
              user.email,
              phone: phoneNumber,
            );
            leadId = lead?['id'] as String?;
          }
        } catch (_) {
          leadId = null;
        }

        Future<String> uploadAdditional({
          required String path,
          required String documentType,
          required Uint8List? bytes,
        }) async {
          if (leadId == null) return path;
          final p = path.trim();
          if (p.startsWith('http') || p.startsWith('/uploads/') || p.startsWith('/api/')) {
            return p;
          }
          final fileName = p.split('/').last.split('\\').last;
          final res = await _additionalDocumentsService.uploadAdditionalDocument(
            filePath: p,
            fileName: fileName,
            documentType: documentType,
            leadId: leadId,
            fileBytes: bytes?.toList(),
          );
          return (res['url'] as String?) ?? (res['path'] as String?) ?? p;
        }

        final provider = context.read<SubmissionProvider>();
        final partnerIndex = widget.partnerIndex ?? 1;

        // Mask front image for spouse/partner when toggle is ON
        Uint8List? spouseMaskedFrontBytes;
        if (_maskAadhaar && !_frontIsPdf && _frontAadhaarNumberRect != null) {
          final clampedRects = AadhaarUtils.clampNumberRectsForOverlay(_frontAadhaarNumberRect);
          if (clampedRects != null) {
            Uint8List? srcBytes = _frontBytes;
            if (srcBytes == null && !kIsWeb) {
              try { srcBytes = await XFile(_frontPath!).readAsBytes(); } catch (_) {}
            }
            if (srcBytes != null) {
              spouseMaskedFrontBytes = await AadhaarImageMasker.maskAadhaarInImage(srcBytes, clampedRects);
            }
          }
        }

        final uploadedFront = await uploadAdditional(
          path: _frontPath!,
          documentType: widget.isSpouse
              ? 'spouse_aadhaar_front'
              : 'partner_${partnerIndex}_aadhaar_front',
          bytes: spouseMaskedFrontBytes ?? (kIsWeb ? _frontBytes : null),
        );
        // Mask back image for spouse/partner when toggle is ON
        Uint8List? spouseMaskedBackBytes;
        if (_maskAadhaar && !_backIsPdf && _backAadhaarNumberRect != null) {
          final clampedRects = AadhaarUtils.clampNumberRectsForOverlay(_backAadhaarNumberRect);
          if (clampedRects != null) {
            Uint8List? srcBytes = _backBytes;
            if (srcBytes == null && !kIsWeb) {
              try { srcBytes = await XFile(_backPath!).readAsBytes(); } catch (_) {}
            }
            if (srcBytes != null) {
              spouseMaskedBackBytes = await AadhaarImageMasker.maskAadhaarInImage(srcBytes, clampedRects);
            }
          }
        }

        final uploadedBack = await uploadAdditional(
          path: _backPath!,
          documentType: widget.isSpouse
              ? 'spouse_aadhaar_back'
              : 'partner_${partnerIndex}_aadhaar_back',
          bytes: spouseMaskedBackBytes ?? (kIsWeb ? _backBytes : null),
        );
        if (widget.isSpouse) {
          provider.setSpouseAadhaarFront(uploadedFront, isPdf: _frontIsPdf);
          provider.setSpouseAadhaarBack(uploadedBack, isPdf: _backIsPdf);
        } else {
          provider.setPartnerAadhaarFront(partnerIndex, uploadedFront, isPdf: _frontIsPdf);
          provider.setPartnerAadhaarBack(partnerIndex, uploadedBack, isPdf: _backIsPdf);
          final normalizedNumber = (_frontAadhaarNumber ?? _backAadhaarNumber ?? '')
              .trim()
              .replaceAll(RegExp(r'[\s-]'), '');
          if (normalizedNumber.isNotEmpty) {
            provider.setPartnerExtractedAadhaarNumber(partnerIndex, normalizedNumber);
          }
        }

        // Keep backend constraint: currentStep must be 1..7
        await appProvider.updateApplication(currentStep: 5);
        return true;
      }

      if (widget.isCoApplicant) {
        final provider = context.read<SubmissionProvider>();
        provider.setCoApplicantAadhaarFront(_frontPath!, isPdf: _frontIsPdf);
        provider.setCoApplicantAadhaarBack(_backPath!, isPdf: _backIsPdf);
        final normalizedNumber = (_frontAadhaarNumber ?? _backAadhaarNumber ?? '')
            .trim()
            .replaceAll(RegExp(r'[\s-]'), '');
        if (normalizedNumber.isNotEmpty) {
          provider.setCoApplicantExtractedAadhaarNumber(normalizedNumber);
        }
        await appProvider.updateApplication(currentStep: 5);
        return true;
      }

      Map<String, dynamic>? frontUpload;
      Map<String, dynamic>? backUpload;

      final currentApp = appProvider.currentApplication;
      final existingData = currentApp?.step2Aadhaar;
      bool isRemote(String? path) => path != null && path.startsWith('http');

      // When mask toggle is ON and we have the number rects, burn black masks
      // over each digit-group of the first 8 digits into the actual image bytes
      // so the backend receives an irrecoverably masked image.
      Uint8List? maskedFrontBytes;
      if (_maskAadhaar && !_frontIsPdf && _frontAadhaarNumberRect != null) {
        final clampedRects = AadhaarUtils.clampNumberRectsForOverlay(_frontAadhaarNumberRect);
        if (clampedRects != null) {
          Uint8List? srcBytes = _frontBytes;
          if (srcBytes == null && !kIsWeb && _frontPath != null && !isRemote(_frontPath)) {
            try {
              srcBytes = await XFile(_frontPath!).readAsBytes();
            } catch (_) {}
          }
          if (srcBytes != null) {
            debugPrint('[Step2Aadhaar] Masking front image before upload...');
            maskedFrontBytes = await AadhaarImageMasker.maskAadhaarInImage(srcBytes, clampedRects);
            debugPrint('[Step2Aadhaar] Masking result: ${maskedFrontBytes != null ? '${maskedFrontBytes.length} bytes' : 'failed (uploading original)'}');
          }
        }
      }

      if (isRemote(_frontPath)) {
        frontUpload = existingData?['frontUpload'] as Map<String, dynamic>?;
      } else {
        frontUpload = await _fileUploadService.uploadAadhaar(
          XFile(_frontPath!),
          side: 'front',
          isPdf: _frontIsPdf,
          maskedBytes: maskedFrontBytes,
          leadId: context.read<AuthProvider>().leadId,
        );
      }

      // Mask back image the same way as front
      Uint8List? maskedBackBytes;
      if (_maskAadhaar && !_backIsPdf && _backAadhaarNumberRect != null) {
        final clampedRects = AadhaarUtils.clampNumberRectsForOverlay(_backAadhaarNumberRect);
        if (clampedRects != null) {
          Uint8List? srcBytes = _backBytes;
          if (srcBytes == null && !kIsWeb && _backPath != null && !isRemote(_backPath)) {
            try {
              srcBytes = await XFile(_backPath!).readAsBytes();
            } catch (_) {}
          }
          if (srcBytes != null) {
            debugPrint('[Step2Aadhaar] Masking back image before upload...');
            maskedBackBytes = await AadhaarImageMasker.maskAadhaarInImage(srcBytes, clampedRects);
            debugPrint('[Step2Aadhaar] Back masking result: ${maskedBackBytes != null ? '${maskedBackBytes.length} bytes' : 'failed (uploading original)'}');
          }
        }
      }

      if (_frontIsPdf && _backIsPdf && _frontPath == _backPath && frontUpload != null) {
        backUpload = frontUpload;
      } else if (isRemote(_backPath)) {
        backUpload = existingData?['backUpload'] as Map<String, dynamic>?;
      } else {
        backUpload = await _fileUploadService.uploadAadhaar(
          XFile(_backPath!),
          side: 'back',
          isPdf: _backIsPdf,
          maskedBytes: maskedBackBytes,
          leadId: context.read<AuthProvider>().leadId,
        );
      }

      await appProvider.updateApplication(
        currentStep: 3,
        step2Aadhaar: {
          'frontPath': _frontPath,
          'backPath': _backPath,
          'frontUpload': frontUpload,
          'backUpload': backUpload,
          'frontIsPdf': _frontIsPdf,
          'backIsPdf': _backIsPdf,
          'frontPdfPassword': _frontPdfPassword,
          'backPdfPassword': _backPdfPassword,
          'savedAt': DateTime.now().toIso8601String(),
          'frontAadhaarNumber': _frontAadhaarNumber != null ? AadhaarUtils.maskAadhaar(_frontAadhaarNumber) : null,
          'backAadhaarNumber': _backAadhaarNumber != null ? AadhaarUtils.maskAadhaar(_backAadhaarNumber) : null,
          'frontAadhaarNumberRect': _frontAadhaarNumberRect,
          'backAadhaarNumberRect': _backAadhaarNumberRect,
          'aadhaarName': _aadhaarName,
          'aadhaarFrontRawText': _aadhaarFrontRawText,
          'frontImageMasked': maskedFrontBytes != null,
          'backImageMasked': maskedBackBytes != null,
          'addressDifferentFromAadhaar': _addressDifferentFromAadhaar,
          '_internalValidation': {
            'frontDocumentValid': _frontInternalValid,
            'backDocumentValid': _backInternalValid,
            'aadhaarNumbersMatch': _frontAadhaarNumber != null && _backAadhaarNumber != null
                ? _frontAadhaarNumber!.replaceAll(RegExp(r'[\s-]'), '') == _backAadhaarNumber!.replaceAll(RegExp(r'[\s-]'), '')
                : null,
          },
        },
      );

      if (mounted) {
        PremiumToast.showSuccess(context, 'Aadhaar saved successfully!');
      }
      return true;
    } catch (e) {
      if (mounted) {
        PremiumToast.showError(
          context,
          'Failed to save Aadhaar: ${e.toString()}',
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

  /// Show validation error dialog - user cannot proceed until fixed
  void _showValidationErrorDialog({
    required String title,
    required String message,
    required String instruction,
    required IconData icon,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        actionsAlignment: MainAxisAlignment.start,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.errorColor, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 15, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warningColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, color: AppTheme.warningColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      instruction,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK, I\'ll Fix It', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _proceedToNext() async {
    if (_frontPath == null || _backPath == null) {
      _showValidationErrorDialog(
        title: 'Missing Documents',
        message: 'You need to upload both the front and back sides of your Aadhaar card to continue.',
        instruction: 'Please capture or upload both sides of your Aadhaar card.',
        icon: Icons.photo_library_outlined,
      );
      return;
    }

    // Applicant-only strict validations. Spouse/Partner flows should be simple.
    if (!widget.isSpouse && !widget.isPartner && !widget.isCoApplicant) {
      if (!_frontOcrComplete || !_backOcrComplete) {
        final issues = <String>[];
        if (!_frontOcrComplete) {
          issues.add('Front: ${_frontOcrIssue ?? 'missing required fields'}');
        }
        if (!_backOcrComplete) {
          issues.add('Back: ${_backOcrIssue ?? 'missing required fields'}');
        }
        _showValidationErrorDialog(
          title: 'Aadhaar OCR Incomplete',
          message: 'Please fix Aadhaar OCR before continuing.\n\n${issues.join('\n')}',
          instruction: 'Re-capture / re-upload with better lighting and crop tightly.',
          icon: Icons.document_scanner_outlined,
        );
        return;
      }

      // Strict validation: Check if Aadhaar numbers from front and back match
      if (_frontAadhaarNumber != null && _backAadhaarNumber != null) {
        // Normalize both numbers (remove spaces/dashes)
        final frontNormalized =
            _frontAadhaarNumber!.replaceAll(RegExp(r'[\s-]'), '');
        final backNormalized =
            _backAadhaarNumber!.replaceAll(RegExp(r'[\s-]'), '');

        if (frontNormalized != backNormalized) {
          _showValidationErrorDialog(
            title: 'Aadhaar Number Mismatch',
            message:
                'The Aadhaar number on the front side (${_aadhaarDisplay(_frontAadhaarNumber)}) does not match the back side (${_aadhaarDisplay(_backAadhaarNumber)}).',
            instruction:
                'Please ensure you upload the front and back of the SAME Aadhaar card. Re-capture or re-upload the correct images.',
            icon: Icons.error_outline,
          );
          return;
        }
      }
    }

    // Spouse / Partner: Aadhaar cannot be the same as the main applicant (or, for partners, as another partner)
    if (widget.isSpouse || widget.isPartner || widget.isCoApplicant) {
      final provider = context.read<SubmissionProvider>();
      final mainAadhaar = (provider.submission.personalData?.aadhaarNumber ?? '').trim();
      final spouseOrPartnerAadhaar = (_frontAadhaarNumber ?? _backAadhaarNumber ?? '').trim();
      final currentNorm = spouseOrPartnerAadhaar.replaceAll(RegExp(r'[\s-]'), '');

      if (currentNorm.isEmpty) {
        // No number to validate
      } else {
        final currentLast4 = currentNorm.length >= 4 ? currentNorm.substring(currentNorm.length - 4) : currentNorm;
        // Cannot be same as main applicant (main may be stored masked; compare last 4)
        if (mainAadhaar.isNotEmpty) {
          final mainNorm = mainAadhaar.replaceAll(RegExp(r'[\s-]'), '');
          final mainLast4 = mainNorm.length >= 4 ? mainNorm.substring(mainNorm.length - 4) : mainNorm;
          if (mainLast4 == currentLast4 && mainLast4.length == 4) {
            _showValidationErrorDialog(
              title: widget.isSpouse
                  ? 'Spouse Aadhaar Invalid'
                  : widget.isCoApplicant
                      ? 'Co-applicant Aadhaar Invalid'
                      : 'Partner Aadhaar Invalid',
              message: widget.isSpouse
                  ? 'The spouse Aadhaar number cannot be the same as the main applicant\'s Aadhaar. Please upload the spouse\'s own Aadhaar card.'
                  : widget.isCoApplicant
                      ? 'Co-applicant Aadhaar cannot be the same as the main applicant\'s Aadhaar. Please upload the co-applicant\'s own Aadhaar card.'
                      : 'Partner ${widget.partnerIndex ?? 1} Aadhaar cannot be the same as the main applicant\'s Aadhaar. Please upload the partner\'s own Aadhaar card.',
              instruction: 'Use a different person\'s Aadhaar card for this step.',
              icon: Icons.person_off_outlined,
            );
            return;
          }
        }

        // Partner only: cannot be same as any other partner (other may be masked; compare last 4)
        if (widget.isPartner) {
          final partners = provider.submission.businessDocuments?.partners ?? [];
          final thisIndex = (widget.partnerIndex ?? 1) - 1;
          for (int i = 0; i < partners.length; i++) {
            if (i == thisIndex) continue;
            final other = (partners[i].extractedAadhaarNumber ?? '').trim().replaceAll(RegExp(r'[\s-]'), '');
            if (other.isEmpty) continue;
            final otherLast4 = other.length >= 4 ? other.substring(other.length - 4) : other;
            if (otherLast4 == currentLast4 && otherLast4.length == 4) {
              _showValidationErrorDialog(
                title: 'Partner Aadhaar Invalid',
                message: 'Partner ${widget.partnerIndex ?? 1} Aadhaar cannot be the same as Partner ${i + 1}\'s Aadhaar. Each partner must have a unique Aadhaar card.',
                instruction: 'Use a different person\'s Aadhaar card for this step.',
                icon: Icons.person_off_outlined,
              );
              return;
            }
          }
        }
      }
    }

    if (_isSaving) return;
    final saved = await _saveToBackend();
    if (mounted && saved) {
      context.go(widget.nextRouteOverride ??
          (widget.isCoApplicant ? AppRoutes.coApplicantPan : AppRoutes.step3Pan));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PreventCloseOnBack(
      onBack: () {
        final back = widget.backRouteOverride ??
            (widget.isCoApplicant
                ? AppRoutes.step4BankStatement
                : (widget.fromPreview ? AppRoutes.step6Preview : AppRoutes.step1Selfie));
        context.go(back);
      },
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Blue Header
            AppHeader(
              title: widget.titleOverride ??
                  (widget.isSpouse
                      ? 'Spouse Aadhaar'
                      : widget.isCoApplicant
                          ? 'Co-applicant Aadhaar'
                          : (widget.isPartner ? 'Partner Aadhaar' : 'Aadhaar Card')),
              icon: Icons.badge_outlined,
              showBackButton: true,
              onBackPressed: () {
                final back = widget.backRouteOverride ??
                    (widget.isCoApplicant
                        ? AppRoutes.step4BankStatement
                        : (widget.fromPreview
                            ? AppRoutes.step6Preview
                            : AppRoutes.step1Selfie));
                context.go(back);
              },
              showHomeButton: true,
              actions: [
                PreviewHeaderAction(
                  backRoute: widget.isCoApplicant
                      ? AppRoutes.coApplicantAadhaar
                      : (widget.isSpouse
                          ? AppRoutes.step4SpouseAadhaar
                          : (widget.isPartner
                              ? '${AppRoutes.partnerAadhaar}?i=${widget.partnerIndex ?? 1}'
                              : AppRoutes.step2Aadhaar)),
                ),
              ],
            ),
            
            // Progress Indicator
            Builder(
              builder: (context) {
                final appProvider = context.read<ApplicationProvider>();
                final submissionProvider = context.read<SubmissionProvider>();
                final loanType = (appProvider.currentApplication?.loanType ??
                        submissionProvider.submission.loanType ??
                        '')
                    .toLowerCase();
                final businessLoanType =
                    (submissionProvider.submission.businessLoanType ?? '')
                        .toLowerCase();
                final isBusinessProprietor =
                    loanType.contains('business') && businessLoanType == 'proprietor';

                final totalSteps =
                    widget.totalStepsOverride ?? (isBusinessProprietor ? 10 : 7);

                return _buildProgressIndicator(
                  context,
                  currentStep: widget.progressStepOverride ?? 2,
                  totalSteps: totalSteps,
                );
              },
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Requirements Card
                    _buildRequirementsCard(context),
                    const SizedBox(height: 16),
                    // Mask Aadhaar toggle (applicant only; spouse/partner use same preference for consistency)
                    _buildMaskAadhaarToggle(context),
                    const SizedBox(height: 24),
                    
                    // Show PDF card if PDF mode, otherwise show front/back sections
                    if (_frontIsPdf && _backIsPdf && _frontPath != null)
                      _buildPdfCardSection(context)
                    else ...[
                      // Front Side Section
                      _buildFrontSideSection(context),
                      const SizedBox(height: 24),
                      
                      // Back Side Section
                      _buildBackSideSection(context),

                      // Address proof toggle (applicant only)
                      if (!widget.isSpouse && !widget.isPartner && !widget.isCoApplicant) ...[
                        const SizedBox(height: 16),
                        _buildAddressDifferentToggle(context),
                      ],
                      
                      // Single Switch to PDF Button (only show if not in PDF mode)
                      if (!(_frontIsPdf && _backIsPdf && _frontPath != null)) ...[
                        const SizedBox(height: 24),
                        _buildPdfSwitchButton(context),
                      ],
                    ],
                    const SizedBox(height: 32),
                    
                    // Action Buttons
                    _buildActionButtons(context),
                    const SizedBox(height: 40),
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

  Widget _buildRequirementsCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF0F5FF), // blue-50
            const Color(0xFFDEECFF).withValues(alpha: 0.5), // blue-100
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFDEECFF), // blue-100
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.secondaryColor,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.badge,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aadhaar Card Requirements',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF172030), // slate-800
                  ),
                ),
                const SizedBox(height: 12),
                _buildRequirementItem(Icons.photo_camera, 'Must Include Front & Back'),
                const SizedBox(height: 8),
                _buildRequirementItem(Icons.visibility, 'No blur or glare'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF576175), // slate-600
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaskAadhaarToggle(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, size: 22, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mask Aadhaar number',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _maskAadhaar
                      ? 'First 8 digits will be masked in both uploaded images'
                      : 'Original images uploaded as-is (no masking)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _maskAadhaar,
            onChanged: (value) {
              setState(() => _maskAadhaar = value);
              // Always persist masked Aadhaar (RBI compliance); toggle only affects on-screen display
              if (!widget.isSpouse && !widget.isPartner && !widget.isCoApplicant) {
                final num = _frontAadhaarNumber ?? _backAadhaarNumber;
                if (num != null && num.trim().isNotEmpty) {
                  context.read<SubmissionProvider>().updatePersonalDataField(
                    aadhaarNumber: AadhaarUtils.maskAadhaar(num),
                  );
                }
              }
            },
            activeColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildFrontSideSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Front Side',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: const Color(0xFF172030),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: _frontPath != null
                    ? LinearGradient(
                        colors: [
                          AppTheme.successColor, // green-500
                          AppTheme.successColor, // green-600
                        ],
                      )
                    : null,
                color: _frontPath != null ? null : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _frontPath != null
                    ? [
                        BoxShadow(
                          color: AppTheme.successColor.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_frontPath != null)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 12,
                    ),
                  if (_frontPath != null) const SizedBox(width: 4),
                  Text(
                    _frontPath != null ? 'UPLOADED' : 'PENDING',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _frontPath != null
                          ? Colors.white
                          : Colors.grey.shade600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_frontPath != null)
          _buildImagePreview(context, _frontPath!, isFront: true)
        else
          _buildEmptyUploadState(context, 'Click to capture front side'),
        const SizedBox(height: 12),
        if (_frontPath != null) ...[
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.sync,
                  label: 'Retake',
                  onPressed: _captureFront,
                  isOutlined: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.file_upload,
                  label: 'Re-upload',
                  onPressed: _selectFrontFromGallery,
                  isOutlined: true,
                ),
              ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.photo_camera,
                  label: 'Take Photo',
                  onPressed: _captureFront,
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.upload,
                  label: 'Upload',
                  onPressed: _selectFrontFromGallery,
                  isOutlined: true,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBackSideSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Back Side',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: const Color(0xFF172030),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _backPath != null
                    ? null
                    : Colors.grey.shade200,
                gradient: _backPath != null
                    ? LinearGradient(
                        colors: [
                          AppTheme.successColor, // green-500
                          AppTheme.successColor, // green-600
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _backPath != null
                    ? [
                        BoxShadow(
                          color: AppTheme.successColor.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_backPath != null)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 12,
                    ),
                  if (_backPath != null) const SizedBox(width: 4),
                  Text(
                    _backPath != null ? 'UPLOADED' : 'PENDING',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _backPath != null
                          ? Colors.white
                          : Colors.grey.shade600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_backPath != null)
          _buildImagePreview(context, _backPath!, isFront: false)
        else
          _buildEmptyUploadState(context, 'Click to capture back side'),
        const SizedBox(height: 12),
        if (_backPath != null) ...[
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.sync,
                  label: 'Retake',
                  onPressed: _captureBack,
                  isOutlined: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.file_upload,
                  label: 'Re-upload',
                  onPressed: _selectBackFromGallery,
                  isOutlined: true,
                ),
              ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.photo_camera,
                  label: 'Take Photo',
                  onPressed: _captureBack,
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.upload,
                  label: 'Upload',
                  onPressed: _selectBackFromGallery,
                  isOutlined: true,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAddressDifferentToggle(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.home_work_outlined,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Address different from Aadhaar?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF172030),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _addressDifferentFromAadhaar
                      ? 'You will be asked to enter your current/address-proof address in Personal Details.'
                      : 'If your current address is different, turn this on to enter it later.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF576175),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: _addressDifferentFromAadhaar,
            onChanged: _isSaving
                ? null
                : (value) {
                    setState(() {
                      _addressDifferentFromAadhaar = value;
                    });
                    final provider = context.read<SubmissionProvider>();
                    if (value) {
                      provider.updatePersonalDataField(
                        addressDifferentFromAadhaar: true,
                      );
                    } else {
                      // If user switches back to "same as Aadhaar", clear the separate address field.
                      provider.updatePersonalDataField(
                        addressDifferentFromAadhaar: false,
                        currentResidenceAddress: '',
                      );
                    }
                    if (!value) {
                      PremiumToast.showInfo(
                        context,
                        'Using Aadhaar address as current address.',
                        duration: const Duration(seconds: 2),
                      );
                    } else {
                      PremiumToast.showInfo(
                        context,
                        'You can enter current address in Personal Details.',
                        duration: const Duration(seconds: 2),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(BuildContext context, String path, {required bool isFront}) {
    final canPreview = !(path.startsWith('http') &&
        (_authToken == null || (isFront ? _frontImageFailed : _backImageFailed)));

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade100,
              Colors.grey.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
              children: [
                (path.startsWith('http') && (_authToken == null || (isFront ? _frontImageFailed : _backImageFailed)))
                    ? ((isFront ? _frontImageFailed : _backImageFailed)
                        ? const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 64))
                        : const Center(child: CircularProgressIndicator()))
                    : Transform.rotate(
                        angle: (isFront ? _frontRotation : _backRotation) * 3.14159 / 180,
                        child: PlatformImage(
                          key: ValueKey(path),
                          imagePath: path,
                          imageBytes: isFront ? _frontBytes : _backBytes,
                          fit: BoxFit.contain,
                          headers: _authToken != null ? {'Authorization': 'Bearer $_authToken'} : null,
                        ),
                      ),
                  if (canPreview) ...[
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openAadhaarPreviewDialog(
                            context,
                            path: path,
                            isFront: isFront,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _tapToPreviewPill(),
                    ),
                  ],
              ],
          ),
        ),
      ),
    );
  }

  Widget _tapToPreviewPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.open_in_full, size: 14, color: Colors.white),
          SizedBox(width: 6),
          Text(
            'Tap to preview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAadhaarPreviewDialog(
    BuildContext context, {
    required String path,
    required bool isFront,
  }) async {
    final rotationDeg = isFront ? _frontRotation : _backRotation;
    final bytes = isFront ? _frontBytes : _backBytes;
    final headers =
        _authToken != null ? <String, String>{'Authorization': 'Bearer $_authToken'} : null;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                Container(
                  color: Colors.black,
                  child: Center(
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Transform.rotate(
                        angle: rotationDeg * 3.14159 / 180,
                        child: PlatformImage(
                          imagePath: path,
                          imageBytes: bytes,
                          fit: BoxFit.contain,
                          headers: headers,
                        ),
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
        );
      },
    );
  }

  Widget _buildEmptyUploadState(BuildContext context, String text) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade50,
              Colors.grey.shade100,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 2,
            style: BorderStyle.solid,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.1),
                    AppTheme.primaryColor.withValues(alpha: 0.2),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.add_a_photo,
                color: AppTheme.primaryColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
    bool isOutlined = false,
  }) {
    final theme = Theme.of(context);

    if (isPrimary) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.secondaryColor, // royal-blue
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isOutlined
                ? LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.1),
                      AppTheme.primaryColor.withValues(alpha: 0.05),
                    ],
                  )
                : null,
            color: isOutlined ? null : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOutlined
                  ? AppTheme.primaryColor
                  : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: isOutlined
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isOutlined ? AppTheme.primaryColor : Colors.grey.shade600,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isOutlined ? AppTheme.primaryColor : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdfCardSection(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Aadhaar Card PDF',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: const Color(0xFF172030),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.successColor, // green-500
                    AppTheme.successColor, // green-600
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.successColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'UPLOADED',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // PDF Preview Card
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFF0F5FF), // blue-50
                  const Color(0xFFDEECFF), // blue-100
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.picture_as_pdf,
                        size: 64,
                        color: AppTheme.primaryColor.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'PDF',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
                // Delete button
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: AppTheme.errorColor,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () {
                        _removePdf();
                      },
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Change PDF Button
        _buildActionButton(
          context,
          icon: Icons.file_upload,
          label: 'Change PDF',
          onPressed: _uploadPdf,
          isOutlined: true,
        ),
        const SizedBox(height: 12),
        // Switch to Photos Button
        _buildPhotosSwitchButton(context),
      ],
    );
  }

  Widget _buildPdfSwitchButton(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          // Clear both front and back images before switching to PDF
          _removeFrontImage();
          _removeBackImage();
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _uploadPdf();
            }
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.errorColor.withValues(alpha: 0.1), // red-600
                AppTheme.errorColor.withValues(alpha: 0.05), // red-500
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.errorColor.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.errorColor.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.picture_as_pdf,
                color: AppTheme.errorColor, // red-600
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Switch to PDF Upload',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.errorColor, // red-600
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotosSwitchButton(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          _switchToPhotos();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.1),
                AppTheme.primaryColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_camera,
                color: AppTheme.primaryColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Switch to Photos',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _switchToPhotos() {
    setState(() {
      // Clear PDF mode
      _frontPath = null;
      _backPath = null;
      _frontIsPdf = false;
      _backIsPdf = false;
      _frontPdfPassword = null;
      _backPdfPassword = null;
      _frontRotation = 0.0;
      _backRotation = 0.0;
      _frontAadhaarNumber = null;
      _backAadhaarNumber = null;
      _frontAadhaarNumberRect = null;
      _backAadhaarNumberRect = null;
      _aadhaarName = null;
      _aadhaarFrontRawText = null;
      _frontInternalValid = true;
      _backInternalValid = true;
    });
    // Clear from provider
    final provider = context.read<SubmissionProvider>();
    if (provider.submission.aadhaar != null) {
      provider.submission.aadhaar = null;
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Continue to next
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: _proceedToNext,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.secondaryColor, // royal-blue
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                      'Continue to Next',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

}

