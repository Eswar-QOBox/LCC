import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'dart:io' if (dart.library.html) '../services/file_helper_stub.dart' as io;
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
import 'pan_horizontal_card_capture_screen.dart';
import '../utils/local_file_persist.dart';
import '../utils/ocr_pdf.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:image/image.dart' as img;
import '../services/additional_documents_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/premium_progress_indicator.dart';
import '../widgets/preview_header_action.dart';
import '../widgets/prevent_close_on_back.dart';

class Step3PanScreen extends StatefulWidget {
  const Step3PanScreen({
    super.key,
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

  /// When true, behaves like spouse PAN screen (same UI/validations, different storage/save).
  final bool isSpouse;

  /// Partnership flow: when true, saves into partner KYC bucket (no personal-data updates).
  final bool isPartner;

  /// Co-applicant (joint loan): when true, saves into submission co-applicant PAN.
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
  State<Step3PanScreen> createState() => _Step3PanScreenState();
}

class _Step3PanScreenState extends State<Step3PanScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final FileUploadService _fileUploadService = FileUploadService();
  final AdditionalDocumentsService _additionalDocumentsService =
      AdditionalDocumentsService();
  String? _frontPath;
  bool _isSaving = false;
  bool _isPdf = false;
  String? _pdfPassword;
  double _rotation = 0.0;
  String? _authToken;
  bool _imageFailed = false;
  Uint8List? _frontBytes;

  // OCR extracted PAN number
  String? _extractedPanNumber;
  String? _extractedName;
  String? _extractedFatherName;
  
  // Aadhaar name loaded from previous step (for cross-validation)
  String? _aadhaarName;
  // Raw text from Aadhaar front (for PAN name validation: at least one word present)
  String? _aadhaarFrontRawText;
  
  // Internal validation flag (secret - not shown to user)
  bool _internalDocumentValid = true;

  // OCR completeness flag (used to enforce "must extract")
  bool _panOcrComplete = false;
  String? _panOcrIssue;

  bool _isRemoteOrServerPath(String? path) {
    if (path == null) return false;
    final p = path.trim();
    if (p.isEmpty) return false;
    return p.startsWith('http') ||
        p.startsWith('blob:') ||
        p.startsWith('/uploads/') ||
        p.startsWith('uploads/') ||
        p.startsWith('/api/') ||
        p.startsWith('api/');
  }

  Future<void> _initOcrForExistingPan() async {
    if (!mounted) return;

    // Applicant flow: if step3Pan was loaded from backend with extracted fields,
    // `_panOcrComplete` is already set. We don't re-run OCR automatically.
    if (!widget.isSpouse) return;

    final path = _frontPath?.trim();
    if (path == null || path.isEmpty) return;

    // If spouse doc is already a remote/server path, don't force a re-upload just to OCR.
    if (_isRemoteOrServerPath(path)) {
      setState(() {
        _panOcrComplete = true;
        _panOcrIssue = null;
      });
      return;
    }

    // Local: re-run OCR so the user can proceed without re-uploading.
    if (_isPdf) {
      await _performPanOcrFromPdf(path);
    } else {
      await _performPanOCR(path);
    }
  }

  String _normalizeForNameCompare(String input) {
    return input
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _nameTokens(String input) {
    final n = _normalizeForNameCompare(input);
    if (n.isEmpty) return const [];
    return n.split(' ').where((w) => w.isNotEmpty).toList();
  }

  static const Set<String> _commonSurnameLikeTokens = {
    'KUMAR',
    'KUMARI',
    'SINGH',
    'DEVI',
    'RAO',
    'REDDY',
    'SHARMA',
    'PATEL',
    'GUPTA',
    'YADAV',
    'DAS',
    'KHAN',
    'BIBI',
    'BEGUM',
    'LAL',
    'CHAND',
    'PRASAD',
    'NAIR',
    'MENON',
    'PILLAI',
    'IYER',
    'JAIN',
  };

  int _editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final m = a.length;
    final n = b.length;
    final prev = List<int>.generate(n + 1, (j) => j);
    final curr = List<int>.filled(n + 1, 0);
    for (int i = 1; i <= m; i++) {
      curr[0] = i;
      for (int j = 1; j <= n; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final del = prev[j] + 1;
        final ins = curr[j - 1] + 1;
        final sub = prev[j - 1] + cost;
        curr[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
      }
      for (int j = 0; j <= n; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[n];
  }

  bool _tokenMatches(String a, String b) {
    // exact
    if (a == b) return true;
    // initial match: "M" vs "MARKAPURAM"
    if (a.length == 1 && b.startsWith(a)) return true;
    if (b.length == 1 && a.startsWith(b)) return true;
    // prefix match for truncated words: "MARKAP" vs "MARKAPURAM"
    if (a.length >= 3 && b.length >= 3) {
      if (a.startsWith(b) || b.startsWith(a)) return true;
    }
    // minor OCR typo tolerance for longer tokens
    if (a.length >= 5 && b.length >= 5) {
      final d = _editDistance(a, b);
      if (d <= 1) return true;
    }
    return false;
  }

  ({int matches, double ratio, Set<String> matchedLongTokens, bool initialMatched, bool aadhaarHasInitial, bool candidateHasInitial})
      _nameMatchQuality(String aadhaarName, String candidate) {
    final aToks = _nameTokens(aadhaarName);
    final cToks = _nameTokens(candidate);
    if (aToks.isEmpty || cToks.isEmpty) {
      return (
        matches: 0,
        ratio: 0,
        matchedLongTokens: <String>{},
        initialMatched: false,
        aadhaarHasInitial: false,
        candidateHasInitial: false,
      );
    }

    final used = List<bool>.filled(cToks.length, false);
    int matchCount = 0;
    bool initialMatched = false;
    final matchedLongTokens = <String>{};
    final aadhaarHasInitial = aToks.any((t) => t.length == 1);
    final candidateHasInitial = cToks.any((t) => t.length == 1);
    for (final a in aToks) {
      for (int j = 0; j < cToks.length; j++) {
        if (used[j]) continue;
        if (_tokenMatches(a, cToks[j])) {
          used[j] = true;
          matchCount++;
          if (a.length == 1 || cToks[j].length == 1) {
            initialMatched = true;
          }
          final longToken = (a.length >= 3) ? a : (cToks[j].length >= 3 ? cToks[j] : null);
          if (longToken != null) matchedLongTokens.add(longToken);
          break;
        }
      }
    }

    final denom = aToks.length > cToks.length ? aToks.length : cToks.length;
    final ratio = denom == 0 ? 0.0 : (matchCount / denom);
    return (
      matches: matchCount,
      ratio: ratio,
      matchedLongTokens: matchedLongTokens,
      initialMatched: initialMatched,
      aadhaarHasInitial: aadhaarHasInitial,
      candidateHasInitial: candidateHasInitial,
    );
  }

  bool _isAadhaarPanNameMatch(String aadhaarName, String panName) {
    // Adaptive strictness:
    // - For longer names (>=3 tokens), require >=2 matches to avoid false positives.
    // - For short names (1-2 tokens), allow >=1 *strong* match (non-common token),
    //   and require initials to match only when BOTH sides have initials.
    final q = _nameMatchQuality(aadhaarName, panName);
    final aLen = _nameTokens(aadhaarName).length;
    final pLen = _nameTokens(panName).length;
    final maxLen = aLen > pLen ? aLen : pLen;

    final hasStrongToken = q.matchedLongTokens.any((t) =>
        t.length >= 4 && !_commonSurnameLikeTokens.contains(t));
    if (!hasStrongToken) return false;

    if (maxLen >= 3) {
      return q.matches >= 2 && q.ratio >= 0.5;
    }

    // maxLen 1 or 2
    if (q.matches < 1 || q.ratio < 0.5) return false;

    // If both contain initials, enforce initial match; otherwise allow (OCR may drop the initial).
    if (q.aadhaarHasInitial && q.candidateHasInitial && !q.initialMatched) {
      return false;
    }
    return true;
  }

  /// PAN OCR can sometimes swap "Name" and "Father's Name" depending on how labels were read.
  /// If Aadhaar name matches the PAN fatherName more than panName, swap them.
  void _maybeSwapPanNameAndFatherNameUsingAadhaar() {
    final aadhaar = _aadhaarName;
    final panName = _extractedName;
    final father = _extractedFatherName;
    if (aadhaar == null ||
        aadhaar.trim().isEmpty ||
        panName == null ||
        panName.trim().isEmpty ||
        father == null ||
        father.trim().isEmpty) {
      return;
    }

    final qName = _nameMatchQuality(aadhaar, panName);
    final qFather = _nameMatchQuality(aadhaar, father);

    // Prefer the candidate with more matches; if tie, prefer higher ratio.
    final fatherIsBetter = (qFather.matches > qName.matches) ||
        (qFather.matches == qName.matches && qFather.ratio > qName.ratio);

    if (fatherIsBetter) {
      final tmp = _extractedName;
      _extractedName = _extractedFatherName;
      _extractedFatherName = tmp;
      debugPrint(
        'PAN: swapped extractedName/extractedFatherName based on Aadhaar match '
        '(name=${qName.matches}/${qName.ratio.toStringAsFixed(2)}, '
        'father=${qFather.matches}/${qFather.ratio.toStringAsFixed(2)})',
      );
    }
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

  Future<String> _cropPanImageIfPossible(String path) async {
    if (kIsWeb) return path;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: path,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop PAN',
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
          IOSUiSettings(title: 'Crop PAN'),
        ],
      );
      return cropped?.path ?? path;
    } catch (_) {
      return path;
    }
  }

  @override
  void initState() {
    super.initState();
    final provider = context.read<SubmissionProvider>();
    if (widget.isSpouse) {
      _frontPath = provider.submission.businessDocuments?.spousePan?.frontPath;
      _isPdf = provider.submission.businessDocuments?.spousePan?.isPdf ?? false;
    } else if (widget.isPartner) {
      final idx = (widget.partnerIndex ?? 1) - 1;
      final partnerPan =
          provider.submission.businessDocuments?.partners
              .asMap()
              .containsKey(idx) ==
                  true
              ? provider.submission.businessDocuments!.partners[idx].pan
              : null;
      _frontPath = partnerPan?.frontPath;
      _isPdf = partnerPan?.isPdf ?? false;
    } else if (widget.isCoApplicant) {
      _frontPath = provider.submission.coApplicantPan?.frontPath;
      _isPdf = provider.submission.coApplicantPan?.isPdf ?? false;
    } else {
      _frontPath = provider.submission.pan?.frontPath;
      // Check if it's a PDF based on provider extended info if available or file extension
      // SubmissionProvider helper needed or direct check 
      if (_frontPath != null && _frontPath!.toLowerCase().endsWith('.pdf')) {
        _isPdf = true;
      }
    }
    
    // Load existing data from backend
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadAuthToken();
      await _loadExistingData();
      await _initOcrForExistingPan();
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

  Future<void> _loadExistingData() async {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication) return;

    if (widget.isSpouse || widget.isPartner || widget.isCoApplicant) {
      // Spouse/Partner/Co-applicant PAN is stored in local draft / additional-doc uploads.
      // Don't load applicant PAN step from backend.
      return;
    }

    // Refresh application data from backend to get the latest saved data
    try {
      await appProvider.refreshApplication();
    } catch (e) {
      debugPrint('PAN Screen: Failed to refresh application: $e');
    }

    final application = appProvider.currentApplication!;
    if (application.step3Pan != null) {
      final stepData = application.step3Pan as Map<String, dynamic>;
      final uploadedFile = stepData['uploadedFile'] as Map<String, dynamic>?;
      final frontPath = stepData['frontPath'] as String?;
      final extractedPanNumber = stepData['extractedPanNumber'] as String?;
      final extractedName = stepData['extractedName'] as String?;
      final extractedFatherName = stepData['extractedFatherName'] as String?;
      
      // Helper to build full URL - transform /uploads/{category}/ to /api/v1/uploads/files/{category}/
      String? buildFullUrl(String? relativeUrl) {
        if (relativeUrl == null || relativeUrl.isEmpty) return null;
        if (relativeUrl.startsWith('http') || relativeUrl.startsWith('blob:')) return relativeUrl;
        // Convert /uploads/pan/... to /api/v1/uploads/files/pan/...
        String apiPath = relativeUrl;
        if (apiPath.startsWith('/uploads/') && !apiPath.contains('/uploads/files/')) {
          apiPath = apiPath.replaceFirst('/uploads/', '/api/v1/uploads/files/');
        } else if (!apiPath.startsWith('/api/')) {
          apiPath = '/api/v1$apiPath';
        }
        return '${ApiConfig.baseUrl}$apiPath';
      }
      
      // Prefer uploaded file URL over local blob path
      final effectiveFront = buildFullUrl(uploadedFile?['url'] as String?) ?? frontPath;

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
          _isPdf = stepData['isPdf'] as bool? ?? false;
          _pdfPassword = stepData['pdfPassword'] as String?;
          _extractedPanNumber = extractedPanNumber;
          _extractedName = extractedName;
          _extractedFatherName = extractedFatherName;
          _panOcrComplete =
              (extractedPanNumber ?? '').trim().isNotEmpty &&
              (extractedName ?? '').trim().isNotEmpty &&
              (extractedFatherName ?? '').trim().isNotEmpty;
        });
        // Also update SubmissionProvider
        context.read<SubmissionProvider>().setPanFront(effectiveFront, isPdf: stepData['isPdf'] as bool? ?? false);

        // Keep Personal Details in sync whenever PAN is uploaded/loaded (applicant only).
        if (!widget.isSpouse) {
          final provider = context.read<SubmissionProvider>();
          if (extractedPanNumber != null && extractedPanNumber.trim().isNotEmpty) {
            provider.updatePersonalDataField(panNo: extractedPanNumber);
          }
          if (extractedName != null && extractedName.trim().isNotEmpty) {
            provider.updatePersonalDataField(fullName: extractedName);
          }
          if (extractedFatherName != null &&
              extractedFatherName.trim().isNotEmpty) {
            provider.updatePersonalDataField(fatherName: extractedFatherName);
          }
        }

        // Fetch image if network URL and not PDF
        if (effectiveFront.startsWith('http') && accessToken != null && (!_isPdf)) {
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
                  _imageFailed = false;
                });
              } else {
                setState(() { _imageFailed = true; });
              }
            } else {
               if (mounted) setState(() { _imageFailed = true; });
            }
          } catch (e) {
            if (mounted) setState(() { _imageFailed = true; });
          }
        }
      }
    }
    
    // Load Aadhaar name and front raw text from previous step for cross-validation
    if (application.step2Aadhaar != null) {
      final aadhaarData = application.step2Aadhaar as Map<String, dynamic>;
      final aadhaarName = aadhaarData['aadhaarName'] as String?;
      if (aadhaarName != null && aadhaarName.isNotEmpty) {
        _aadhaarName = aadhaarName;
        debugPrint('Loaded Aadhaar name for cross-validation: $_aadhaarName');
      }
      final aadhaarFrontRawText = aadhaarData['aadhaarFrontRawText'] as String?;
      if (aadhaarFrontRawText != null && aadhaarFrontRawText.isNotEmpty) {
        _aadhaarFrontRawText = aadhaarFrontRawText;
        debugPrint('Loaded Aadhaar front raw text for PAN name validation (length: ${_aadhaarFrontRawText!.length})');
      }
    }

    // Fallback: if step2 isn't saved yet, still validate using provider auto-filled name.
    if (!widget.isSpouse && !widget.isPartner) {
      _refreshAadhaarValidationContextFromProvider();
    }

    // If PAN names were loaded from backend, fix potential swap using Aadhaar.
    if (mounted) {
      setState(() {
        _maybeSwapPanNameAndFatherNameUsingAadhaar();
      });
      // Ensure Personal Details reflects the corrected fields.
      if (!widget.isSpouse && !widget.isPartner) {
        final provider = context.read<SubmissionProvider>();
        if ((_extractedName ?? '').trim().isNotEmpty) {
          provider.updatePersonalDataField(fullName: _extractedName);
        }
        if ((_extractedFatherName ?? '').trim().isNotEmpty) {
          provider.updatePersonalDataField(fatherName: _extractedFatherName);
        }
      }
    }
  }

  /// Saves draft to DB. Returns true only if save succeeded; then safe to go to next step.
  Future<bool> _saveToBackend() async {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication || _frontPath == null) return false;

    final submissionProvider = context.read<SubmissionProvider>();
    final loanType = (appProvider.currentApplication?.loanType ?? '').toLowerCase();
    final businessLoanType =
        (submissionProvider.submission.businessLoanType ?? '').toLowerCase();
    final isBusinessProprietor = loanType.contains('business') && businessLoanType == 'proprietor';

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.isSpouse || widget.isPartner) {
        // Spouse/Partner mode: upload as additional document.
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

        var uploadPath = _frontPath!;
        if (leadId != null &&
            !uploadPath.startsWith('http') &&
            !uploadPath.startsWith('/uploads/') &&
            !uploadPath.startsWith('/api/')) {
          final fileName = uploadPath.split('/').last.split('\\').last;
          final res = await _additionalDocumentsService.uploadAdditionalDocument(
            filePath: uploadPath,
            fileName: fileName,
            documentType: widget.isSpouse
                ? 'spouse_pan'
                : 'partner_${widget.partnerIndex ?? 1}_pan',
            leadId: leadId,
            fileBytes: kIsWeb ? _frontBytes?.toList() : null,
          );
          uploadPath =
              (res['url'] as String?) ?? (res['path'] as String?) ?? uploadPath;
        }

        if (widget.isSpouse) {
          context.read<SubmissionProvider>().setSpousePan(uploadPath, isPdf: _isPdf);
        } else {
          context
              .read<SubmissionProvider>()
              .setPartnerPan(widget.partnerIndex ?? 1, uploadPath, isPdf: _isPdf);
        }
        await appProvider.updateApplication(currentStep: 6);
        return true;
      }

      if (widget.isCoApplicant) {
        context.read<SubmissionProvider>().setCoApplicantPan(_frontPath!, isPdf: _isPdf);
        await appProvider.updateApplication(currentStep: 6);
        return true;
      }

      Map<String, dynamic>? uploadResult;
      if (_frontPath!.startsWith('http')) {
        final currentApp = appProvider.currentApplication;
        if (currentApp?.step3Pan != null) {
          final stepData = currentApp!.step3Pan as Map<String, dynamic>;
          uploadResult = stepData['uploadedFile'] as Map<String, dynamic>?;
        }
      } else {
        uploadResult = await _fileUploadService.uploadPan(
          XFile(_frontPath!),
          isPdf: _isPdf,
          leadId: context.read<AuthProvider>().leadId,
        );
      }

      await appProvider.updateApplication(
        currentStep: isBusinessProprietor ? 4 : 4,
        step3Pan: {
          'frontPath': _frontPath,
          'uploadedFile': uploadResult,
          'isPdf': _isPdf,
          'pdfPassword': _pdfPassword,
          'savedAt': DateTime.now().toIso8601String(),
          'extractedPanNumber': _extractedPanNumber,
          'extractedName': _extractedName,
          'extractedFatherName': _extractedFatherName,
          'aadhaarNameUsedForValidation': _aadhaarName,
          '_internalValidation': {
            'documentValid': _internalDocumentValid,
            'namesMatch': _aadhaarName != null && _extractedName != null
                ? _areNamesSimilar(_aadhaarName!, _extractedName!)
                : null,
          },
        },
      );

      if (mounted) {
        PremiumToast.showSuccess(context, 'PAN saved successfully!');
      }
      return true;
    } catch (e) {
      if (mounted) {
        PremiumToast.showError(context, 'Failed to save PAN: ${e.toString()}');
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

  Future<void> _captureFromCamera() async {
    if (kIsWeb) {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        requestFullMetadata: false,
      );
      if (image != null && mounted) {
        final croppedPath = await _cropPanImageIfPossible(image.path);
        final storedPath = await persistLocalPathIfNeeded(
          croppedPath,
          preferredExtension: 'jpg',
          subdir: 'lcc_pan',
          prefix: 'pan',
        );
        setState(() {
          _frontPath = storedPath;
          _frontBytes = null;
          _isPdf = false;
          _rotation = 0.0;
        });
        if (widget.isSpouse) {
          context.read<SubmissionProvider>().setSpousePan(storedPath, isPdf: false);
        } else {
          context.read<SubmissionProvider>().setPanFront(storedPath, isPdf: false);
        }
        await _performPanOCR(storedPath);
      }
      return;
    }
    // Use in-app PAN grid capture so our activity stays in foreground (avoids crash when system camera takes over)
    final result = await Navigator.of(context).push<XFile>(
      MaterialPageRoute<XFile>(
        builder: (context) => const PanHorizontalCardCaptureScreen(),
      ),
    );
    if (result != null && mounted) {
      final croppedPath = await _cropPanImageIfPossible(result.path);
      final storedPath = await persistLocalPathIfNeeded(
        croppedPath,
        preferredExtension: 'jpg',
        subdir: 'lcc_pan',
        prefix: 'pan',
      );
      setState(() {
        _frontPath = storedPath;
        _frontBytes = null;
        _isPdf = false;
        _rotation = 0.0;
      });
      if (widget.isSpouse) {
        context.read<SubmissionProvider>().setSpousePan(storedPath, isPdf: false);
      } else {
        context.read<SubmissionProvider>().setPanFront(storedPath, isPdf: false);
      }
      await _performPanOCR(storedPath);
    }
  }

  Future<void> _selectFromGallery() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      final croppedPath = await _cropPanImageIfPossible(image.path);
      final storedPath = await persistLocalPathIfNeeded(
        croppedPath,
        preferredExtension: 'jpg',
        subdir: 'lcc_pan',
        prefix: 'pan',
      );

      setState(() {
        _frontPath = storedPath;
        _isPdf = false;
        _rotation = 0.0;
      });
      if (widget.isSpouse) {
        context.read<SubmissionProvider>().setSpousePan(storedPath, isPdf: false);
      } else {
        context.read<SubmissionProvider>().setPanFront(storedPath, isPdf: false);
      }
      
      // Perform OCR on PAN card
      await _performPanOCR(storedPath);
    }
  }

  /// Perform OCR on PAN card image and show extracted data
  Future<void> _performPanOCR(String imagePath, {Uint8List? imageBytes}) async {
    if (!mounted) return;

    try {
      // Show loading indicator
      if (mounted) {
        PremiumToast.showInfo(
          context,
          'Extracting text from PAN card...',
          duration: const Duration(seconds: 2),
        );
      }

      final result = await OcrService.extractPanText(imagePath, imageBytes: imageBytes);

      if (!mounted) return;

      if (result.success) {
        final extractedData = <String>[];
        final provider = context.read<SubmissionProvider>();
        
        // Store extracted data and internal validation flag
        _extractedPanNumber = result.panNumber;
        _extractedName = result.name;
        _extractedFatherName = result.fatherName;
        _internalDocumentValid = result.isInternallyValid;

        if (kDebugMode) {
          debugPrint(
              '[DocValidation] PAN OCR pan=${result.panNumber} '
              'name="${result.name}" father="${result.fatherName}" '
              'internalValid=${result.isInternallyValid}');
        }

        // Ensure Aadhaar name context is available for later validation (applicant only).
        if (!widget.isSpouse) {
          _refreshAadhaarValidationContextFromProvider();
          _maybeSwapPanNameAndFatherNameUsingAadhaar();
        }

        final missing = <String>[];
        if (!result.hasPanNumber) missing.add('PAN Number');
        if (!result.hasName) missing.add('Name');
        // Father name is optional (some PAN cards do not have it) — do not block on it
        setState(() {
          _panOcrComplete = result.hasPanNumber && result.hasName;
          _panOcrIssue = missing.isEmpty ? null : 'Missing: ${missing.join(', ')}';
        });
        if (missing.isNotEmpty && mounted) {
          PremiumToast.showWarning(
            context,
            'PAN OCR incomplete: ${missing.join(', ')}',
            duration: const Duration(seconds: 3),
          );
        }
        
        if (result.hasPanNumber) {
          extractedData.add('PAN: ${result.panNumber}');
          // Auto-fill PAN number to personal data (applicant only)
          if (!widget.isSpouse) {
            provider.updatePersonalDataField(panNo: result.panNumber);
          }
        }
        if ((_extractedName ?? '').trim().isNotEmpty) {
          extractedData.add('Name: $_extractedName');
          // Auto-fill name to personal data (applicant only)
          // Use post-processed values (in case of swap).
          if (!widget.isSpouse) {
            provider.updatePersonalDataField(fullName: _extractedName);
          }
        }
        if ((_extractedFatherName ?? '').trim().isNotEmpty) {
          extractedData.add('Father: $_extractedFatherName');
          // Auto-fill father/parent name to personal data (applicant only)
          // Use post-processed values (in case of swap).
          if (!widget.isSpouse) {
            provider.updatePersonalDataField(fatherName: _extractedFatherName);
          }
        }

        debugPrint(
          'PAN post-processed - PAN: ${_extractedPanNumber ?? '-'}, '
          'Name: ${_extractedName ?? '-'}, Father: ${_extractedFatherName ?? '-'}',
        );

        if (extractedData.isNotEmpty) {
          PremiumToast.showSuccess(
            context,
            'Extracted & auto-filled: ${extractedData.join(' • ')}',
            duration: const Duration(seconds: 5),
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
          _panOcrComplete = false;
          _panOcrIssue = result.errorMessage ?? 'OCR failed';
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('OCR Error: $e');
        setState(() {
          _panOcrComplete = false;
          _panOcrIssue = 'OCR failed';
        });
      }
    }
  }

  /// Checks whether a PDF is encrypted by scanning the full file for the
  /// `/Encrypt` dictionary reference. The xref/trailer lives at the *end* of
  /// the file, so we must search the whole thing — not just the first few KB.
  Future<bool> _isPdfEncrypted(String? path, Uint8List? bytes) async {
    final Uint8List allBytes;
    if (kIsWeb && bytes != null) {
      allBytes = bytes;
    } else if (!kIsWeb && path != null && path.isNotEmpty) {
      try {
        allBytes = await io.File(path).readAsBytes();
      } catch (_) {
        return false;
      }
    } else {
      return false;
    }
    return _bytesContainAscii(allBytes, '/Encrypt');
  }

  static bool _bytesContainAscii(Uint8List data, String needle) {
    if (data.isEmpty || needle.isEmpty) return false;
    final pattern = needle.codeUnits;
    final pLen = pattern.length;
    final dLen = data.length;
    if (pLen > dLen) return false;
    outer:
    for (int i = 0; i <= dLen - pLen; i++) {
      for (int j = 0; j < pLen; j++) {
        if (data[i + j] != pattern[j]) continue outer;
      }
      return true;
    }
    return false;
  }

  /// Returns the password needed to open the PDF with PDFium, or empty string if it opens without a user password.
  /// Returns null if the user cancelled or the file could not be unlocked.
  Future<String?> _resolvePanPdfPasswordIfNeeded({
    required bool headerSuggestsEncrypt,
    required String localOrBlobPath,
    required Uint8List? webBytes,
  }) async {
    if (!headerSuggestsEncrypt) {
      return '';
    }
    // Many encrypted PDFs still open with an empty user password — no dialog.
    if (await _tryOpenPanPdf(localOrBlobPath, webBytes, '')) {
      return '';
    }
    if (!mounted) return null;
    return _showPanPdfPasswordDialog(localOrBlobPath, webBytes);
  }

  Future<bool> _tryOpenPanPdf(String localOrBlobPath, Uint8List? webBytes, String password) async {
    PdfDocument? doc;
    try {
      if (kIsWeb && webBytes != null) {
        doc = await PdfDocument.openData(
          webBytes,
          passwordProvider: password.isEmpty
              ? () async => null
              : createSimplePasswordProvider(password),
          firstAttemptByEmptyPassword: true,
          sourceName: 'pan_unlock_try',
        );
      } else if (!kIsWeb &&
          localOrBlobPath.isNotEmpty &&
          !localOrBlobPath.startsWith('blob:')) {
        doc = await PdfDocument.openFile(
          localOrBlobPath,
          passwordProvider: password.isEmpty
              ? () async => null
              : createSimplePasswordProvider(password),
          firstAttemptByEmptyPassword: true,
        );
      } else {
        return false;
      }
      await doc.dispose();
      return true;
    } catch (_) {
      try {
        await doc?.dispose();
      } catch (_) {}
      return false;
    }
  }

  /// Returns null if cancelled. Otherwise the validated password (non-empty).
  Future<String?> _showPanPdfPasswordDialog(String localOrBlobPath, Uint8List? webBytes) async {
    final passwordController = TextEditingController();

    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> trySubmit() async {
              final pwd = passwordController.text;
              if (pwd.isEmpty) {
                if (dialogContext.mounted) {
                  setDialogState(() => errorText = 'Enter the PDF password.');
                }
                return;
              }
              bool ok;
              try {
                ok = await _tryOpenPanPdf(localOrBlobPath, webBytes, pwd);
              } catch (_) {
                ok = false;
              }
              if (!dialogContext.mounted) return;
              if (!ok) {
                setDialogState(() => errorText = 'Incorrect password. Try again.');
                return;
              }
              Navigator.of(dialogContext).pop(pwd);
            }

            return AlertDialog(
              title: const Text('PDF Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'This PDF is password-protected. Enter the password to unlock it for verification and OCR.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'PDF password',
                      errorText: errorText,
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      floatingLabelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    obscureText: true,
                    onSubmitted: (_) => trySubmit(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => trySubmit(),
                  child: const Text('Unlock'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
    return result;
  }

  Future<void> _uploadPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        String path;
        Uint8List? bytesForCheck;
        String? pathForCheck;

        if (kIsWeb) {
          final bytes = result.files.single.bytes;
          if (bytes == null) {
            if (mounted) {
              PremiumToast.showError(context, 'Unable to read PDF file');
            }
            return;
          }
          bytesForCheck = bytes;
          path = createBlobUrl(bytes, mimeType: 'application/pdf');
        } else {
          if (result.files.single.path == null) {
            if (mounted) {
              PremiumToast.showError(context, 'Unable to access file');
            }
            return;
          }
          pathForCheck = result.files.single.path;
          path = await persistLocalPathIfNeeded(
            result.files.single.path!,
            preferredExtension: 'pdf',
            subdir: 'lcc_pan',
            prefix: 'pan_pdf',
          );
        }

        final isEncrypted = await _isPdfEncrypted(pathForCheck, bytesForCheck);
        if (!mounted) return;
        final resolvedPassword = await _resolvePanPdfPasswordIfNeeded(
          headerSuggestsEncrypt: isEncrypted,
          localOrBlobPath: path,
          webBytes: bytesForCheck,
        );
        if (resolvedPassword == null || !mounted) return;

        setState(() {
          _frontPath = path;
          _isPdf = true;
          _rotation = 0.0;
          _panOcrComplete = false;
          _pdfPassword = resolvedPassword.isEmpty ? null : resolvedPassword;
        });
        if (widget.isSpouse) {
          context.read<SubmissionProvider>().setSpousePan(path, isPdf: true);
        } else {
          context.read<SubmissionProvider>().setPanFront(path, isPdf: true);
        }
        if (isEncrypted) {
          await _performPanOcrFromPdfWithPdfrx(path, bytesForCheck, resolvedPassword);
        } else {
          await _performPanOcrFromPdf(path);
        }
      }
    } catch (e) {
      debugPrint('[PAN] _uploadPdf error: $e');
      if (mounted) {
        PremiumToast.showError(
          context,
          'Unable to process PDF. Please try again.',
        );
      }
    }
  }

  Future<void> _performPanOcrFromPdf(String pdfPath) async {
    if (!mounted) return;

    if (!OcrPdf.isSupported) {
      PremiumToast.showWarning(
        context,
        'PDF OCR is not supported on this platform. Please upload PAN photo.',
        duration: const Duration(seconds: 3),
      );
      setState(() {
        _panOcrComplete = false;
        _panOcrIssue = 'PDF OCR not supported';
      });
      return;
    }

    if (pdfPath.startsWith('http') || pdfPath.startsWith('blob:')) {
      PremiumToast.showWarning(
        context,
        'PDF OCR requires a local PDF file. Please re-upload the PDF from this device or upload a photo.',
        duration: const Duration(seconds: 4),
      );
      setState(() {
        _panOcrComplete = false;
        _panOcrIssue = 'Remote PDF not supported for OCR';
      });
      return;
    }

    try {
      PremiumToast.showInfo(
        context,
        'Extracting PAN details from PDF...',
        duration: const Duration(seconds: 2),
      );
      final jpg = await OcrPdf.renderPageToJpegBytes(pdfPath, pageIndex: 0);
      await _performPanOCR('pdf://pan', imageBytes: jpg);
    } catch (e, st) {
      debugPrint('PAN PDF OCR failed: $e');
      debugPrint('PAN PDF OCR stack: $st');
      if (!mounted) return;
      PremiumToast.showWarning(
        context,
        'Unable to OCR this PDF (password-protected PDFs are not supported). Please upload a PAN photo.',
        duration: const Duration(seconds: 4),
      );
      setState(() {
        _panOcrComplete = false;
        _panOcrIssue = 'PDF OCR failed';
      });
    }
  }

  /// Encrypted PDFs: render first page via PDFium (pdfrx), then run the same PAN OCR as for images.
  Future<void> _performPanOcrFromPdfWithPdfrx(
    String pdfPath,
    Uint8List? webBytes,
    String password,
  ) async {
    if (!mounted) return;
    PdfDocument? doc;
    PdfImage? pdfImage;
    try {
      PremiumToast.showInfo(
        context,
        'Extracting PAN details from PDF...',
        duration: const Duration(seconds: 2),
      );
      if (kIsWeb && webBytes != null) {
        doc = await PdfDocument.openData(
          webBytes,
          passwordProvider: password.isEmpty
              ? () async => null
              : createSimplePasswordProvider(password),
          firstAttemptByEmptyPassword: true,
          sourceName: 'pan_ocr_enc',
        );
      } else if (!kIsWeb &&
          pdfPath.isNotEmpty &&
          !pdfPath.startsWith('blob:')) {
        doc = await PdfDocument.openFile(
          pdfPath,
          passwordProvider: password.isEmpty
              ? () async => null
              : createSimplePasswordProvider(password),
          firstAttemptByEmptyPassword: true,
        );
      } else {
        if (!mounted) return;
        PremiumToast.showWarning(
          context,
          'Unable to read this PDF for OCR. Please upload a PAN photo (JPG/PNG).',
          duration: const Duration(seconds: 4),
        );
        setState(() {
          _panOcrComplete = false;
          _panOcrIssue = 'PDF OCR failed';
        });
        return;
      }

      if (doc.pages.isEmpty) {
        await doc.dispose();
        if (!mounted) return;
        PremiumToast.showWarning(
          context,
          'This PDF has no pages. Please upload a valid PAN document.',
          duration: const Duration(seconds: 3),
        );
        setState(() {
          _panOcrComplete = false;
          _panOcrIssue = 'PDF OCR failed';
        });
        return;
      }

      final page = await doc.pages.first.ensureLoaded();
      final fullW = (page.width * 2).round().clamp(1, 8192);
      final fullH = (page.height * 2).round().clamp(1, 8192);
      pdfImage = await page.render(
        fullWidth: fullW.toDouble(),
        fullHeight: fullH.toDouble(),
      );
      if (pdfImage == null) {
        await doc.dispose();
        if (!mounted) return;
        setState(() {
          _panOcrComplete = false;
          _panOcrIssue = 'PDF OCR failed';
        });
        return;
      }

      final px = pdfImage.pixels;
      final rgbaImage = img.Image.fromBytes(
        width: pdfImage.width,
        height: pdfImage.height,
        bytes: px.buffer,
        bytesOffset: px.offsetInBytes,
        rowStride: pdfImage.width * 4,
        numChannels: 4,
        order: img.ChannelOrder.bgra,
      );
      final jpegBytes = Uint8List.fromList(img.encodeJpg(rgbaImage, quality: 92));
      pdfImage.dispose();
      pdfImage = null;
      await doc.dispose();
      doc = null;

      await _performPanOCR('pdf://pan', imageBytes: jpegBytes);
    } catch (e, st) {
      debugPrint('PAN encrypted PDF OCR failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      PremiumToast.showWarning(
        context,
        'Unable to OCR this PDF. Please upload a clear PAN photo (JPG/PNG).',
        duration: const Duration(seconds: 4),
      );
      setState(() {
        _panOcrComplete = false;
        _panOcrIssue = 'PDF OCR failed';
      });
    } finally {
      pdfImage?.dispose();
      if (doc != null) {
        try {
          await doc.dispose();
        } catch (_) {}
      }
    }
  }

  /// Normalize name for comparison (remove extra spaces, convert to uppercase)
  String _normalizeName(String name) {
    return name.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
  
  /// Check if two names are similar enough (handles minor OCR variations)
  bool _areNamesSimilar(String name1, String name2) {
    final normalized1 = _normalizeName(name1);
    final normalized2 = _normalizeName(name2);
    
    // Exact match
    if (normalized1 == normalized2) return true;
    
    // Check if one contains the other (handles partial name extraction)
    if (normalized1.contains(normalized2) || normalized2.contains(normalized1)) return true;
    
    // Check word overlap (at least 2 common words should match)
    final words1 = normalized1.split(' ').where((w) => w.length > 1).toSet();
    final words2 = normalized2.split(' ').where((w) => w.length > 1).toSet();
    final commonWords = words1.intersection(words2);
    
    // At least 1 word match is enough (OCR often drops/misreads tokens).
    return commonWords.isNotEmpty;
  }

  void _refreshAadhaarValidationContextFromProvider() {
    // Applicant PAN uses applicant Aadhaar name; co-applicant PAN must use
    // co-applicant Aadhaar OCR name to avoid cross-person validation.
    final provider = context.read<SubmissionProvider>();
    final providerName = widget.isCoApplicant
        ? provider.submission.coApplicantExtractedNameFromAadhaar
        : provider.submission.personalData?.nameAsPerAadhaar;
    if ((_aadhaarName == null || _aadhaarName!.trim().isEmpty) &&
        providerName != null &&
        providerName.trim().isNotEmpty) {
      _aadhaarName = providerName.trim();
    }
  }

  /// Show validation error dialog - user cannot proceed until fixed
  void _showValidationErrorDialog({
    required String title,
    required String message,
    required String instruction,
    required IconData icon,
    String? aadhaarName,
    String? panName,
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
            if (aadhaarName != null || panName != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (aadhaarName != null)
                      Row(
                        children: [
                          const Icon(Icons.badge, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Aadhaar: $aadhaarName',
                              textAlign: TextAlign.left,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    if (aadhaarName != null && panName != null) const SizedBox(height: 8),
                    if (panName != null)
                      Row(
                        children: [
                          const Icon(Icons.credit_card, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'PAN: $panName',
                              textAlign: TextAlign.left,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFBBF24)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      instruction,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF92400E),
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
    if (_frontPath == null) {
      _showValidationErrorDialog(
        title: 'Missing PAN Card',
        message: 'You need to upload your PAN card to continue with the submission.',
        instruction: 'Please capture or upload a clear image of your PAN card.',
        icon: Icons.credit_card_off,
      );
      return;
    }

    // Applicant-only strict OCR gating. Spouse/Partner flows should be simple.
    if (!widget.isSpouse && !widget.isPartner && !_panOcrComplete) {
      _showValidationErrorDialog(
        title: 'PAN OCR Incomplete',
        message: 'Please fix PAN OCR before continuing.\n\n${_panOcrIssue ?? 'Missing required fields'}',
        instruction: 'Re-capture / re-upload with better lighting and crop tightly.',
        icon: Icons.document_scanner_outlined,
      );
      return;
    }
    
    // STRICT: Never continue if Aadhaar name doesn't match PAN user name.
    // For co-applicant flow this must compare against co-applicant Aadhaar context.
    // Spouse/Partner flows are excluded from this check.
    if (!widget.isSpouse && !widget.isPartner) {
      // Also handle short forms like "M ESWAR KUMAR" vs "MARKAPURAM ESWAR KUMAR".
      _refreshAadhaarValidationContextFromProvider();
      _maybeSwapPanNameAndFatherNameUsingAadhaar();

      final aadhaarName = _aadhaarName;
      final panName = _extractedName;
      if (aadhaarName != null &&
          aadhaarName.trim().isNotEmpty &&
          panName != null &&
          panName.trim().isNotEmpty) {
        final ok = _isAadhaarPanNameMatch(aadhaarName, panName);
        final mode = widget.isCoApplicant ? 'co-applicant' : 'applicant';
        debugPrint('PAN name validation ($mode Aadhaar vs PAN): match=$ok');
        if (!ok) {
          _showValidationErrorDialog(
            title: 'Name Mismatch Detected',
            message:
                'The name on your Aadhaar card does not match the name on your PAN card.',
            instruction:
                'Please re-upload correct documents. If Aadhaar shows initials (e.g., "M ESWAR KUMAR"), re-capture with better crop/clarity.',
            icon: Icons.person_off,
            aadhaarName: aadhaarName,
            panName: panName,
          );
          return;
        }
      } else if (widget.isCoApplicant) {
        // Defensive: if co-applicant Aadhaar name context is unavailable,
        // do not fall back to applicant context; skip mismatch block.
        debugPrint(
          'PAN name validation skipped: missing co-applicant Aadhaar name context.',
        );
      }
    }
    
    if (_isSaving) return;
    final saved = await _saveToBackend();
    if (mounted && saved) {
      final appProvider = context.read<ApplicationProvider>();
      final submissionProvider = context.read<SubmissionProvider>();
      final loanType = (appProvider.currentApplication?.loanType ?? '').toLowerCase();
      final businessLoanType =
          (submissionProvider.submission.businessLoanType ?? '').toLowerCase();
      final isBusinessProprietor = loanType.contains('business') && businessLoanType == 'proprietor';

      if (widget.isSpouse || widget.isPartner) {
        context.go(widget.nextRouteOverride ?? AppRoutes.step4BankStatement);
      } else if (widget.isCoApplicant) {
        context.go(widget.nextRouteOverride ?? AppRoutes.step5_1SalarySlips);
      } else {
        context.go(isBusinessProprietor ? AppRoutes.step4SpouseAadhaar : AppRoutes.step4BankStatement);
      }
    }
  }

  void _removeImage() {
    setState(() {
      _frontPath = null;
      _isPdf = false;
      _rotation = 0.0;
      _pdfPassword = null;
      _extractedPanNumber = null;
      _extractedName = null;
      _extractedFatherName = null;
      _internalDocumentValid = true;
    });
    final provider = context.read<SubmissionProvider>();
    if (widget.isSpouse) {
      provider.clearSpousePan();
    } else if (widget.isPartner) {
      provider.clearPartnerPan(widget.partnerIndex ?? 1);
    } else if (widget.isCoApplicant) {
      provider.clearCoApplicantPan();
    } else {
      provider.clearPan();
    }
  }

  void _removePdf() {
    setState(() {
      _frontPath = null;
      _isPdf = false;
      _pdfPassword = null;
      _extractedPanNumber = null;
      _extractedName = null;
      _extractedFatherName = null;
      _internalDocumentValid = true;
    });
    final provider = context.read<SubmissionProvider>();
    if (widget.isSpouse) {
      provider.clearSpousePan();
    } else if (widget.isPartner) {
      provider.clearPartnerPan(widget.partnerIndex ?? 1);
    } else if (widget.isCoApplicant) {
      provider.clearCoApplicantPan();
    } else {
      provider.clearPan();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PreventCloseOnBack(
      onBack: () {
        final back = widget.backRouteOverride ??
            (widget.isCoApplicant ? AppRoutes.coApplicantAadhaar : AppRoutes.step2Aadhaar);
        context.go(back);
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Blue Header
            AppHeader(
              title: widget.titleOverride ??
                  (widget.isSpouse
                      ? 'Co-applicant PAN'
                      : widget.isCoApplicant
                          ? 'Co-applicant PAN'
                          : (widget.isPartner ? 'Partner PAN' : 'PAN Card')),
              icon: Icons.credit_card,
              showBackButton: true,
              onBackPressed: () {
                final back = widget.backRouteOverride ??
                    (widget.isCoApplicant ? AppRoutes.coApplicantAadhaar : AppRoutes.step2Aadhaar);
                context.go(back);
              },
              showHomeButton: true,
              actions: [
                PreviewHeaderAction(
                  backRoute:
                      widget.isCoApplicant
                          ? AppRoutes.coApplicantPan
                          : (widget.isSpouse
                              ? AppRoutes.step5SpousePan
                              : (widget.isPartner
                                  ? '${AppRoutes.partnerPan}?i=${widget.partnerIndex ?? 1}'
                                  : AppRoutes.step3Pan)),
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
                  currentStep: widget.progressStepOverride ?? 3,
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
                    const SizedBox(height: 24),
                    
                    // Show PDF card if PDF mode, otherwise show photo section
                    if (_isPdf && _frontPath != null)
                      _buildPdfCardSection(context)
                    else ...[
                      // Front Side Section
                      _buildFrontSideSection(context),
                      
                      // Single Switch to PDF Button (only show if not in PDF mode)
                      const SizedBox(height: 24),
                      _buildPdfSwitchButton(context),
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
        color: const Color(0xFFEFF6FF), // blue-50
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFDBEAFE), // blue-100
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
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
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.badge,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PAN Card Requirements',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF1E293B), // slate-800
                  ),
                ),
                const SizedBox(height: 12),
                _buildRequirementItem(Icons.visibility, 'Must be clear and readable'),
                const SizedBox(height: 8),
                _buildRequirementItem(Icons.image, 'Front side only (PAN has only front)'),
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
        Icon(icon, color: AppTheme.primaryColor, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 14,
              color: const Color(0xFF475569), // slate-600
            ),
          ),
        ),
      ],
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
                color: const Color(0xFF1E293B),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _frontPath != null
                    ? const Color(0xFFF0FDF4) // green-50
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _frontPath != null ? 'UPLOADED' : 'PENDING',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _frontPath != null
                      ? const Color(0xFF22C55E) // green-500
                      : Colors.grey.shade400,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_frontPath != null)
          _buildImagePreview(context)
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
                  onPressed: _captureFromCamera,
                  isOutlined: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.file_upload,
                  label: 'Re-upload',
                  onPressed: _selectFromGallery,
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
                  onPressed: _captureFromCamera,
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.upload,
                  label: 'Upload',
                  onPressed: _selectFromGallery,
                  isOutlined: true,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    final canPreview = !_isPdf &&
        !(_frontPath!.startsWith('http') && (_authToken == null || _imageFailed));

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              _isPdf
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.picture_as_pdf,
                            size: 60,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'PDF',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ((_frontPath!.startsWith('http') && (_authToken == null || _imageFailed))
                      ? Center(
                          child: _imageFailed
                              ? const Icon(Icons.broken_image, color: Colors.grey, size: 64)
                              : const CircularProgressIndicator())
                      : Transform.rotate(
                          angle: _rotation * 3.14159 / 180,
                          child: PlatformImage(
                            imagePath: _frontPath!,
                            imageBytes: _frontBytes,
                            fit: BoxFit.cover,
                            headers: _authToken != null ? {'Authorization': 'Bearer $_authToken'} : null,
                          ),
                        )),
              if (canPreview) ...[
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openPanPreviewDialog(context),
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

  Future<void> _openPanPreviewDialog(BuildContext context) async {
    if (_frontPath == null || _frontPath!.isEmpty) return;
    if (_isPdf) return;

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
                        angle: _rotation * 3.14159 / 180,
                        child: PlatformImage(
                          imagePath: _frontPath!,
                          imageBytes: _frontBytes,
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
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_a_photo,
                color: Colors.grey,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade400,
                fontSize: 14,
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
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOutlined
                  ? AppTheme.primaryColor.withValues(alpha: 0.2)
                  : Colors.grey.shade200,
              width: 2,
            ),
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
              'PAN Card PDF',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: const Color(0xFF1E293B),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF22C55E), // green-500
                    const Color(0xFF16A34A), // green-600
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.3),
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
                  const Color(0xFFEFF6FF), // blue-50
                  const Color(0xFFDBEAFE), // blue-100
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
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          if (_frontPath != null) {
            _removeImage();
          }
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
                const Color(0xFFDC2626).withValues(alpha: 0.1), // red-600
                AppTheme.errorColor.withValues(alpha: 0.05), // red-500
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFDC2626).withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withValues(alpha: 0.15),
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
                color: const Color(0xFFDC2626), // red-600
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Switch to PDF Upload',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFDC2626), // red-600
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
      _isPdf = false;
      _pdfPassword = null;
      _rotation = 0.0;
      _extractedPanNumber = null;
      _extractedName = null;
      _extractedFatherName = null;
      _internalDocumentValid = true;
    });
    // Clear from provider
    final provider = context.read<SubmissionProvider>();
    if (provider.submission.pan != null) {
      provider.submission.pan = null;
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Continue to next
        Material(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: _proceedToNext,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
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

