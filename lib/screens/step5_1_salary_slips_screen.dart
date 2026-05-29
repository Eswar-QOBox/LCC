import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:file_picker/file_picker.dart';
import '../services/ocr_service.dart';
import '../utils/ocr_pdf.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/submission_provider.dart';
import '../providers/application_provider.dart';
import '../providers/auth_provider.dart';
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
import '../widgets/prevent_close_on_back.dart';
import '../widgets/premium_progress_indicator.dart';
import '../utils/debug_log.dart';
import '../utils/step4_merge.dart';
import '../utils/business_loan_flow.dart';
import '../utils/home_mortgage_loan_flow.dart';

// Conditional import for file operations - only on non-web platforms
import 'dart:io' if (dart.library.html) '../services/file_helper_stub.dart' as io;

class Step5_1SalarySlipsScreen extends StatefulWidget {
  const Step5_1SalarySlipsScreen({
    super.key,
    this.fromPreview = false,
    this.isCoApplicant = false,
  });

  /// When true, Back and Continue return to Preview (opened via Edit from Preview).
  final bool fromPreview;

  /// When true, uploads apply to the co-applicant (joint personal loan).
  final bool isCoApplicant;

  @override
  State<Step5_1SalarySlipsScreen> createState() =>
      _Step5_1SalarySlipsScreenState();
}

class _Step5_1SalarySlipsScreenState extends State<Step5_1SalarySlipsScreen> {
  static const int _requiredSlipCount = SalarySlips.requiredSlipCount;

  /// ML Kit often throws `InputImageConverterError` on Android after crop/picker URIs.
  /// Salary slips still upload to the server; eligibility prefill parses PDFs on the backend.
  static const bool _enableSalarySlipOcr = false;

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
  /// When [_enableSalarySlipOcr] is true, each local slip must pass ML Kit before Continue.
  final Map<int, bool> _ocrCompleteBySlot = {};
  final Map<int, String?> _ocrIssueBySlot = {};

  static const Map<String, int> _monthNameToNumber = {
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };

  String _monthKey(DateTime dt) => '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}';

  int? _parseYearFlexible(String rawYear) {
    final value = int.tryParse(rawYear);
    if (value == null) return null;
    if (value >= 1000) return value;
    if (value >= 0 && value <= 99) return 2000 + value;
    return null;
  }

  Set<String> _extractMonthKeysFromText(String fullText) {
    final keys = <String>{};

    void addKey(int? month, int? year) {
      if (month == null || year == null) return;
      if (month < 1 || month > 12) return;
      if (year < 2000 || year > 2100) return;
      keys.add('${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}');
    }

    final monthNamePattern =
        r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)';

    final normalizedLines = fullText
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    // Prioritize lines that are likely to contain salary period details.
    final payPeriodLines = normalizedLines.where((line) {
      final u = line.toUpperCase();
      return u.contains('PAY PERIOD') ||
          u.contains('SALARY MONTH') ||
          u.contains('WAGE MONTH') ||
          u.contains('MONTH OF') ||
          u.contains('PAYSLIP') ||
          u.contains('PAY SLIP');
    }).toList();

    final scanBuckets = <String>[
      ...payPeriodLines,
      fullText,
    ];

    for (final bucket in scanBuckets) {
      for (final m in RegExp('\\b$monthNamePattern\\s*[-/,\\s]\\s*(\\d{2,4})\\b', caseSensitive: false)
          .allMatches(bucket)) {
        final monthName = (m.group(1) ?? '').toLowerCase();
        addKey(_monthNameToNumber[monthName], _parseYearFlexible(m.group(2) ?? ''));
      }

      for (final m in RegExp('\\b(\\d{2,4})\\s*[-/,\\s]\\s*$monthNamePattern\\b', caseSensitive: false)
          .allMatches(bucket)) {
        final monthName = (m.group(2) ?? '').toLowerCase();
        addKey(_monthNameToNumber[monthName], _parseYearFlexible(m.group(1) ?? ''));
      }

      for (final m in RegExp(r'\b(0?[1-9]|1[0-2])\s*[-/]\s*(\d{4})\b').allMatches(bucket)) {
        addKey(int.tryParse(m.group(1) ?? ''), int.tryParse(m.group(2) ?? ''));
      }

      for (final m in RegExp(r'\b(\d{4})\s*[-/]\s*(0?[1-9]|1[0-2])\b').allMatches(bucket)) {
        addKey(int.tryParse(m.group(2) ?? ''), int.tryParse(m.group(1) ?? ''));
      }
    }

    return keys;
  }

  static bool _isNameLike(String s) {
    final t = s.trim();
    if (t.length < 3 || t.length > 50) return false;
    if (RegExp(r'\d').hasMatch(t)) return false;
    // Avoid common non-name tokens that may appear near names.
    final upper = t.toUpperCase();
    const banned = <String>[
      'GOVERNMENT',
      'INDIA',
      'UIDAI',
      'AADHAAR',
      'UNIQUE',
      'IDENTIFICATION',
      'PAN',
      'GST',
      'IFSC',
      'BANK',
      'ACCOUNT',
      'STATEMENT',
      'DATE',
      'BIRTH',
      'DOB',
      'EMPLOYEE',
      'EMP',
      'DESIGNATION',
      'COMPANY',
      'SALARY',
      'PAYSLIP',
      'PAY',
      'NET',
      'GROSS',
    ];
    for (final b in banned) {
      if (upper.contains(b)) return false;
    }
    // Allow letters, spaces and dots (initials).
    return RegExp(r'^[A-Za-z.\s]+$').hasMatch(t);
  }

  String _normalizePersonName(String name) {
    return name
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z.\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _nameTokens(String name) {
    final normalized = _normalizePersonName(name);
    return normalized
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .where((t) => RegExp(r'^[A-Z]+\.?$').hasMatch(t))
        .map((t) => t.replaceAll('.', ''))
        .where((t) => t.length >= 2 || t.length == 1)
        .toList();
  }

  Set<String> _extractEmployeeNameCandidatesFromText(String fullText) {
    final lines = fullText
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final candidates = <String>{};

    final labelValueRegexes = <RegExp>[
      RegExp(r'(?:EMPLOYEE\s*NAME|EMP\s*NAME|NAME)\s*[:\-]\s*(.+)',
          caseSensitive: false),
      RegExp(r'(?:EMPLOYEE)\s*[:\-]\s*(.+)', caseSensitive: false),
      RegExp(r'(?:SALARIED|SALARIED\s+EMPLOYEE)\s*[:\-]\s*(.+)',
          caseSensitive: false),
    ];

    for (final line in lines) {
      // Extract "label: value" parts if present.
      for (final r in labelValueRegexes) {
        final m = r.firstMatch(line);
        if (m != null) {
          final extracted = (m.group(1) ?? '').trim();
          if (_isNameLike(extracted)) candidates.add(extracted);
        }
      }

      // If line is like "S/O John Doe" or "FATHER: John Doe"
      final slashRegex = RegExp(r'(?:S\s*/\s*O|S\/O|W\s*/\s*O|W\/O|D\s*/\s*O|D\/O)\s*(.+)',
          caseSensitive: false);
      final m2 = slashRegex.firstMatch(line);
      if (m2 != null) {
        final extracted = (m2.group(1) ?? '').trim();
        if (_isNameLike(extracted)) candidates.add(extracted);
      }

      // Otherwise, try using the whole line if it looks name-like.
      if (_isNameLike(line)) {
        candidates.add(line);
      }
    }

    // If nothing found, do a softer heuristic:
    if (candidates.isEmpty) {
      for (final line in lines) {
        if (!_isNameLike(line)) continue;
        final words = line.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).length;
        if (words >= 2 && words <= 5) {
          candidates.add(line);
        }
      }
    }

    // Limit to a small set to keep matching stable.
    return candidates.take(6).toSet();
  }

  int _levenshteinDistance(String a, String b, {int maxDist = 2}) {
    // Early-exit Levenshtein distance for short name tokens.
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    if ((a.length - b.length).abs() > maxDist) return maxDist + 1;

    final m = a.length;
    final n = b.length;
    final dp = List<int>.generate(n + 1, (j) => j);

    for (int i = 1; i <= m; i++) {
      int prev = dp[0];
      dp[0] = i;
      int rowMin = dp[0];
      for (int j = 1; j <= n; j++) {
        final temp = dp[j];
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        dp[j] = [
          dp[j] + 1, // deletion
          dp[j - 1] + 1, // insertion
          prev + cost, // substitution
        ].reduce((x, y) => x < y ? x : y);
        rowMin = dp[j] < rowMin ? dp[j] : rowMin;
        prev = temp;
      }
      if (rowMin > maxDist) return maxDist + 1;
    }
    return dp[n];
  }

  bool _fuzzyTokenMatch(String aadhaarToken, String candidateToken) {
    if (aadhaarToken == candidateToken) return true;
    if (aadhaarToken.length == 1 || candidateToken.length == 1) {
      // Initials: allow prefix match.
      return aadhaarToken.startsWith(candidateToken) || candidateToken.startsWith(aadhaarToken);
    }
    final a = aadhaarToken;
    final b = candidateToken;
    // Prefix match catches common OCR token splits.
    final minLen = a.length < b.length ? a.length : b.length;
    if (minLen >= 3) {
      if (a.startsWith(b) || b.startsWith(a)) return true;
      // Minor typo tolerance.
      final dist = _levenshteinDistance(a, b, maxDist: 2);
      if (dist <= 1) return true;
    }
    return false;
  }

  bool _fuzzyNameMatchesAadhaar({
    required String aadhaarName,
    required String slipText,
    String? debugBestCandidate,
  }) {
    final aadhaarTokens = _nameTokens(aadhaarName);
    if (aadhaarTokens.isEmpty) return false;

    final candidates = _extractEmployeeNameCandidatesFromText(slipText);
    if (candidates.isEmpty) return false;

    int bestScore = -1;
    String? bestCandidate;

    for (final cand in candidates) {
      final candTokens = _nameTokens(cand);
      if (candTokens.isEmpty) continue;
      final matched = <String>{};
      for (final aTok in aadhaarTokens) {
        for (final cTok in candTokens) {
          if (_fuzzyTokenMatch(aTok, cTok)) {
            matched.add(aTok);
            break;
          }
        }
      }
      final score = matched.length;
      if (score > bestScore) {
        bestScore = score;
        bestCandidate = cand;
      }
    }

    // Thresholds: allow some mismatch, but require at least 2 tokens to align.
    final tokenCount = aadhaarTokens.length;
    final requiredMatches = tokenCount <= 3 ? 2 : 3;
    if (bestScore >= requiredMatches) return true;

    // Fallback: allow 2-token match when OCR is noisy.
    if (bestScore >= 2 && (tokenCount >= 4)) return true;

    if (debugBestCandidate != null && bestCandidate != null) {
      debugPrint('Salary slip name fuzzy mismatch. Aadhaar="$aadhaarName" best="$bestCandidate" matches=$bestScore');
    }
    return false;
  }

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

  void _markSalarySlipOcrSkipped(int slotIndex) {
    if (!mounted) return;
    setState(() {
      _ocrCompleteBySlot[slotIndex] = true;
      _ocrIssueBySlot[slotIndex] = null;
    });
  }

  /// Run OCR on salary slip (image or PDF first page). Skips on web and for remote/blob paths.
  Future<void> _performDocumentOcrForSlot(int slotIndex, String path, bool isPdf) async {
    if (kIsWeb) return;
    if (_isServerStoredPath(path)) return;
    if (path.startsWith('blob:')) return;

    if (!_enableSalarySlipOcr) {
      _markSalarySlipOcrSkipped(slotIndex);
      return;
    }

    try {
      Uint8List? imageBytes;
      if (isPdf && path.toLowerCase().endsWith('.pdf') && OcrPdf.isSupported) {
        try {
          final count = await OcrPdf.getPageCount(path);
          if (count > 0) {
            imageBytes = await OcrPdf.renderPageToJpegBytes(path, pageIndex: 0);
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[SalarySlips] PDF render for OCR failed: $e');
        }
      } else {
        imageBytes = await OcrService.readLocalImageBytes(path);
        if (imageBytes == null) {
          try {
            imageBytes = await XFile(path).readAsBytes();
          } catch (e) {
            if (kDebugMode) debugPrint('[SalarySlips] readAsBytes failed: $e');
          }
        }
      }
      if (imageBytes == null || imageBytes.isEmpty) {
        setState(() {
          _ocrCompleteBySlot[slotIndex] = false;
          _ocrIssueBySlot[slotIndex] = 'Could not read image file';
        });
        return;
      }
      final result = await OcrService.extractDocumentText(path, imageBytes: imageBytes);
      if (!mounted) return;
      if (result.success) {
        final text = result.fullText?.trim() ?? '';
        if (text.isEmpty) {
          setState(() {
            _ocrCompleteBySlot[slotIndex] = false;
            _ocrIssueBySlot[slotIndex] = 'No readable text detected';
          });
          PremiumToast.showWarning(
            context,
            'Slip text not readable. Re-capture clearly and try again.',
            duration: const Duration(seconds: 4),
          );
          return;
        }

        final expectedMonth = _requiredMonths[slotIndex];
        final expectedKey = _monthKey(expectedMonth);
        final detectedKeys = _extractMonthKeysFromText(text);
        if (!detectedKeys.contains(expectedKey)) {
          final expectedLabel = DateFormat('MMM yyyy').format(expectedMonth);
          final detectedLabels = detectedKeys
              .map((key) {
                final parts = key.split('-');
                if (parts.length != 2) return key;
                final y = int.tryParse(parts[0]);
                final m = int.tryParse(parts[1]);
                if (y == null || m == null) return key;
                return DateFormat('MMM yyyy').format(DateTime(y, m));
              })
              .toSet()
              .toList()
            ..sort();
          final detectedText = detectedLabels.isEmpty
              ? 'No salary month detected'
              : 'Detected: ${detectedLabels.join(', ')}';
          setState(() {
            _ocrCompleteBySlot[slotIndex] = false;
            _ocrIssueBySlot[slotIndex] = 'Expected $expectedLabel. $detectedText';
          });
          PremiumToast.showWarning(
            context,
            'Month mismatch. Expected $expectedLabel payslip for this slot.',
            duration: const Duration(seconds: 4),
          );
          return;
        }

        // Optional: verify employee name is fuzzy-matching with Aadhaar name.
        final sub = context.read<SubmissionProvider>().submission;
        final aadhaarName = widget.isCoApplicant
            ? ((sub.coApplicantPersonalData?.nameAsPerAadhaar?.trim().isNotEmpty ?? false)
                ? sub.coApplicantPersonalData!.nameAsPerAadhaar
                : sub.coApplicantExtractedNameFromAadhaar)
            : sub.personalData?.nameAsPerAadhaar;
        if (aadhaarName != null && aadhaarName.trim().isNotEmpty) {
          final matches = _fuzzyNameMatchesAadhaar(
            aadhaarName: aadhaarName.trim(),
            slipText: text,
          );
          if (!matches) {
            setState(() {
              _ocrCompleteBySlot[slotIndex] = false;
              _ocrIssueBySlot[slotIndex] =
                  'Employee name does not match Aadhaar name (fuzzy).';
            });
            PremiumToast.showWarning(
              context,
              'Employee name mismatch. Please upload a clearer slip for this month.',
              duration: const Duration(seconds: 4),
            );
            return;
          }
        }

        setState(() {
          _ocrCompleteBySlot[slotIndex] = true;
          _ocrIssueBySlot[slotIndex] = null;
        });
        PremiumToast.showSuccess(
          context,
          'Salary slip scanned and month verified.',
        );
      } else {
        setState(() {
          _ocrCompleteBySlot[slotIndex] = false;
          _ocrIssueBySlot[slotIndex] = result.errorMessage;
        });
        PremiumToast.showWarning(
          context,
          'Could not read slip. Re-capture with better lighting or replace to continue.',
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SalarySlips] OCR failed: $e');
      if (mounted) {
        setState(() {
          _ocrCompleteBySlot[slotIndex] = false;
          _ocrIssueBySlot[slotIndex] = e.toString();
        });
        PremiumToast.showWarning(
          context,
          'Could not scan slip. Re-capture or replace to continue.',
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  void _showSalarySlipOcrDialog(List<String> issues) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.document_scanner_outlined, color: AppTheme.errorColor, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Salary Slip OCR Incomplete',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Each salary slip must be scanned successfully before you can continue.',
              style: TextStyle(height: 1.3),
            ),
            const SizedBox(height: 12),
            ...issues.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $e', style: const TextStyle(height: 1.25)),
            )),
            const SizedBox(height: 12),
            Text(
              'Re-capture or re-upload with better lighting and ensure the slip is clearly visible.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.3),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
    // Reject same document used for multiple months (user requirement: same payslip in 3 months should not be accepted)
    final normalizedPath = path.trim();
    for (int i = 0; i < _requiredSlipCount; i++) {
      if (i != slotIndex && _slipItems[i].path.trim() == normalizedPath) {
        if (mounted) {
          PremiumToast.showWarning(
            context,
            'This document is already used for another month. Please upload a different payslip for ${DateFormat('MMM yyyy').format(_requiredMonths[slotIndex])}.',
            duration: const Duration(seconds: 4),
          );
        }
        // #region agent log
        debugAgentLog(
          location: 'step5_1_salary_slips_screen.dart:_setSlipForSlot',
          message: 'Payslip duplicate rejected',
          data: {'slotIndex': slotIndex, 'pathLen': path.length, 'duplicateDetected': true},
          hypothesisId: 'H-D',
        );
        // #endregion
        return;
      }
    }
    // #region agent log
    debugAgentLog(
      location: 'step5_1_salary_slips_screen.dart:_setSlipForSlot',
      message: 'Payslip set',
      data: {
        'slotIndex': slotIndex,
        'pathLen': path.length,
        'otherPaths': _slipItems.map((s) => s.path.length).toList(),
        'duplicateDetected': false,
      },
      hypothesisId: 'H-D',
    );
    // #endregion
    final slotMonth = _requiredMonths[slotIndex];

    final provider = context.read<SubmissionProvider>();

    setState(() {
      _slipItems[slotIndex] =
          SalarySlipItem(path: path, slipDate: slotMonth, isPdf: isPdf);

      // Ensure lists are sized correctly
      if (slotIndex < _slipFailures.length) _slipFailures[slotIndex] = false;
      if (slotIndex < _slipBytes.length) _slipBytes[slotIndex] = null;
    });

    if (widget.isCoApplicant) {
      provider.setCoApplicantSalarySlipAt(slotIndex, path, slipDate: slotMonth, isPdf: isPdf);
      provider.updateCoApplicantSalarySlipDate(slotIndex, slotMonth);
    } else {
      provider.setSalarySlipAt(slotIndex, path, slipDate: slotMonth, isPdf: isPdf);
      provider.updateSalarySlipDate(slotIndex, slotMonth);
    }
    await _performDocumentOcrForSlot(slotIndex, path, isPdf);
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
      if (!mounted) return;
      final appProvider = context.read<ApplicationProvider>();
      final submissionProvider = context.read<SubmissionProvider>();
      final loanType = (appProvider.currentApplication?.loanType ??
              submissionProvider.submission.loanType ??
              '')
          .toLowerCase();
      final appBusinessType = appProvider.currentApplication?.businessLoanType;
      if (appBusinessType != null &&
          appBusinessType.isNotEmpty &&
          submissionProvider.submission.businessLoanType != appBusinessType) {
        submissionProvider.setBusinessLoanType(appBusinessType);
      }
      if (!BusinessLoanFlow.requiresSalarySlips(
        loanType: loanType,
        businessLoanType: submissionProvider.submission.businessLoanType ??
            appBusinessType,
        submission: submissionProvider.submission,
      )) {
        context.go(
          BusinessLoanFlow.routeIfBusinessLoanOnSalarySlipsScreen(
            loanType: loanType,
            businessLoanType: submissionProvider.submission.businessLoanType ??
                appBusinessType,
            submission: submissionProvider.submission,
            fromPreview: widget.fromPreview,
          ),
        );
        return;
      }
      _loadExistingData();
      // Sync with provider after draft loads (in case it loads after initState)
      _syncWithProvider();
      // When coming back from preview (or loading with existing slips), run OCR for any local paths so gating works.
      _runOcrForExistingLocalSlips();
    });
  }

  /// Run OCR for salary slips that already have a local path (e.g. after coming back from preview or draft with local files).
  Future<void> _runOcrForExistingLocalSlips() async {
    if (kIsWeb) return;
    if (!mounted) return;
    if (!_enableSalarySlipOcr) {
      setState(() {
        for (int i = 0; i < _requiredSlipCount && i < _slipItems.length; i++) {
          if (_slipItems[i].hasFile) {
            _ocrCompleteBySlot[i] = true;
            _ocrIssueBySlot[i] = null;
          }
        }
      });
      return;
    }
    for (int i = 0; i < _requiredSlipCount && i < _slipItems.length; i++) {
      final item = _slipItems[i];
      if (!item.hasFile) continue;
      if (_isServerStoredPath(item.path) || item.path.startsWith('blob:')) continue;
      if (_ocrCompleteBySlot[i] == true) continue; // already done
      await _performDocumentOcrForSlot(i, item.path, item.isPdf);
      if (!mounted) return;
    }
  }

  void _loadDraftData() {
    final provider = context.read<SubmissionProvider>();
    final slips = widget.isCoApplicant
        ? provider.submission.coApplicantSalarySlips
        : provider.submission.salarySlips;
    final existing = List<SalarySlipItem>.from(
      slips?.slipItems ?? const [],
    );
    _pdfPassword = slips?.pdfPassword;

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
    final salarySlips = widget.isCoApplicant
        ? provider.submission.coApplicantSalarySlips
        : provider.submission.salarySlips;
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
      final slipItemsKey =
          widget.isCoApplicant ? 'coApplicantSalarySlipItems' : 'salarySlipItems';
      final slipIsPdfKey =
          widget.isCoApplicant ? 'coApplicantSalarySlipsIsPdf' : 'salarySlipsIsPdf';
      final slipPwdKey =
          widget.isCoApplicant ? 'coApplicantSalarySlipsPassword' : 'salarySlipsPassword';

      if (stepData[slipItemsKey] != null) {
        
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

        final itemsList = stepData[slipItemsKey] as List;
        final loadedItemsRaw = itemsList.map((item) {
          final map = item as Map<String, dynamic>;
          final rawPath = map['path'] as String?;
          final fullPath = buildFullUrl(rawPath) ?? rawPath ?? '';
          return SalarySlipItem(
            path: fullPath,
            slipDate: map['slipDate'] != null ? DateTime.parse(map['slipDate']) : null,
            isPdf: fullPath.toLowerCase().endsWith('.pdf') || (stepData[slipIsPdfKey] == true),
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
            _pdfPassword = stepData[slipPwdKey] as String?;
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
          if (widget.isCoApplicant) {
            provider.setCoApplicantSalarySlipItems(_slipItems);
            if (_pdfPassword != null) {
              provider.setCoApplicantSalarySlipsPassword(_pdfPassword!);
            }
            for (int i = 0; i < _slipItems.length; i++) {
              if (_slipItems[i].slipDate != null) {
                provider.updateCoApplicantSalarySlipDate(i, _slipItems[i].slipDate!);
              }
            }
          } else {
            provider.setSalarySlipItems(_slipItems);
            if (_pdfPassword != null) {
              provider.setSalarySlipsPassword(_pdfPassword!);
            }
            for (int i = 0; i < _slipItems.length; i++) {
              if (_slipItems[i].slipDate != null) {
                provider.updateSalarySlipDate(i, _slipItems[i].slipDate!);
              }
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
          final uploadKey = widget.isCoApplicant
              ? 'coApplicantSalarySlipsUploaded'
              : 'salarySlipsUploaded';
          final existingUploads = (stepData[uploadKey] as List<dynamic>?)
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
        final newUploadResults = await _fileUploadService.uploadSalarySlips(
          files,
          leadId: context.read<AuthProvider>().leadId,
        );
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
      if (widget.isCoApplicant) {
        provider.setCoApplicantSalarySlipItems(updatedSlipItems);
        for (int i = 0; i < updatedSlipItems.length; i++) {
          provider.updateCoApplicantSalarySlipDate(i, updatedSlipItems[i].slipDate);
        }
      } else {
        provider.setSalarySlipItems(updatedSlipItems);
        for (int i = 0; i < updatedSlipItems.length; i++) {
          provider.updateSalarySlipDate(i, updatedSlipItems[i].slipDate);
        }
      }

      final finalIsPdf = updatedSlipItems.any((i) => i.isPdf);

      final existingStep4 = appProvider.currentApplication?.step4BankStatement;
      if (widget.isCoApplicant) {
        final merged = mergeStep4BankStatement(existingStep4, {
          'coApplicantSalarySlips': updatedSlipItems.map((item) => item.path).toList(),
          'coApplicantSalarySlipItems': updatedSlipItems.map((item) => {
            'path': item.path,
            'slipDate': item.slipDate?.toIso8601String(),
          }).toList(),
          'coApplicantSalarySlipsIsPdf': finalIsPdf,
          'coApplicantSalarySlipsPassword': _pdfPassword,
          'coApplicantSalarySlipsUploaded': finalUploadedFiles,
        });
        await appProvider.updateApplication(step4BankStatement: merged);
      } else {
        final merged = mergeStep4BankStatement(existingStep4, {
          'salarySlips': updatedSlipItems.map((item) => item.path).toList(),
          'salarySlipItems': updatedSlipItems.map((item) => {
            'path': item.path,
            'slipDate': item.slipDate?.toIso8601String(),
          }).toList(),
          'salarySlipsIsPdf': finalIsPdf,
          'salarySlipsPassword': _pdfPassword,
          'salarySlipsUploaded': finalUploadedFiles,
        });
        await appProvider.updateApplication(step4BankStatement: merged);
      }

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
    final p = context.read<SubmissionProvider>();
    if (widget.isCoApplicant) {
      p.removeCoApplicantSalarySlip(index);
    } else {
      p.removeSalarySlip(index);
    }
    setState(() {
      final slotMonth = _requiredMonths[index];
      _slipItems[index] = SalarySlipItem(
        path: '',
        slipDate: slotMonth,
        isPdf: false,
      );
      if (index < _slipFailures.length) _slipFailures[index] = false;
      if (index < _slipBytes.length) _slipBytes[index] = null;
      _ocrCompleteBySlot.remove(index);
      _ocrIssueBySlot.remove(index);
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
                final p = context.read<SubmissionProvider>();
                if (widget.isCoApplicant) {
                  p.setCoApplicantSalarySlipsPassword(password);
                } else {
                  p.setSalarySlipsPassword(password);
                }
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
    final appProvider = context.read<ApplicationProvider>();
    final loanType = (appProvider.currentApplication?.loanType ?? '').toLowerCase();
    final isStudentLoan = loanType.contains('student');
    if (isStudentLoan && !widget.isCoApplicant) {
      context.go(AppRoutes.step5StudentDocs);
      return;
    }
    if (!_hasAllRequiredSlips) {
      PremiumToast.showError(
        context,
        'Please upload $_requiredSlipCount salary slips (last 3 months) to continue.',
      );
      return;
    }
    // On mobile: optional ML Kit month/name check per slip (disabled — see [_enableSalarySlipOcr]).
    if (_enableSalarySlipOcr && !kIsWeb) {
      final issues = <String>[];
      for (int i = 0; i < _requiredSlipCount; i++) {
        final item = _slipItems[i];
        if (!item.hasFile) continue;
        if (_isServerStoredPath(item.path) || item.path.startsWith('blob:')) continue;
        if (_ocrCompleteBySlot[i] != true) {
          final monthLabel = DateFormat('MMM yyyy').format(_requiredMonths[i]);
          final issue = _ocrIssueBySlot[i] != null
              ? 'Slip $monthLabel: ${_ocrIssueBySlot[i]}'
              : 'Slip $monthLabel: OCR not run or failed';
          issues.add(issue);
        }
      }
      if (issues.isNotEmpty) {
        _showSalarySlipOcrDialog(issues);
        return;
      }
    }
    final saved = await _saveToBackend();
    if (mounted && saved) {
      if (widget.fromPreview) {
        context.go(AppRoutes.step6Preview);
        return;
      }
      final submissionProvider = context.read<SubmissionProvider>();

      if (widget.isCoApplicant) {
        // After co-applicant salary slips: go to firm docs if firm co-applicant,
        // else property details (Mortgage) or personal data.
        final firmType = submissionProvider.submission.coApplicantFirmType;
        if (firmType != null) {
          context.go('${AppRoutes.coApplicantFirmDocs}?firmType=$firmType');
        } else {
          final coLoanType =
              context.read<ApplicationProvider>().currentApplication?.loanType;
          if (HomeMortgageLoanFlow.needsPropertyDetails(
            loanType: coLoanType,
            submission: submissionProvider.submission,
          )) {
            context.go(AppRoutes.step5PropertyDetails);
          } else {
            context.go(AppRoutes.step5PersonalData);
          }
        }
        return;
      }

      // New order for co-applicant flow:
      // Main salary slips -> co Aadhaar -> co PAN -> co bank -> co salary -> (firm docs) -> personal details.
      if (submissionProvider.submission.hasCoApplicant) {
        final coAadhaarComplete =
            submissionProvider.submission.coApplicantAadhaar?.isComplete ?? false;
        final coPanComplete =
            submissionProvider.submission.coApplicantPan?.isComplete ?? false;
        final coBankComplete =
            submissionProvider.submission.coApplicantBankStatement?.isComplete ?? false;
        final coSalaryComplete =
            submissionProvider.submission.coApplicantSalarySlips?.isComplete ?? false;

        if (!coAadhaarComplete) {
          context.go(AppRoutes.coApplicantAadhaar);
          return;
        }
        if (!coPanComplete) {
          context.go(AppRoutes.coApplicantPan);
          return;
        }
        if (!coBankComplete) {
          context.go(AppRoutes.coApplicantBankStatement);
          return;
        }
        if (!coSalaryComplete) {
          context.go(AppRoutes.coApplicantSalarySlips);
          return;
        }
        // After all co-applicant KYC steps, go to firm docs if firm co-applicant
        final firmType = submissionProvider.submission.coApplicantFirmType;
        if (firmType != null) {
          context.go('${AppRoutes.coApplicantFirmDocs}?firmType=$firmType');
          return;
        }
      }

      final appProvider = context.read<ApplicationProvider>();
      final loanType = (appProvider.currentApplication?.loanType ?? '').toLowerCase();
      final professionalType =
          (submissionProvider.submission.professionalLoanType ?? '').toLowerCase();
      final isProfessionalLoan = loanType.contains('professional') &&
          (professionalType == 'doctor' || professionalType == 'ca');
      final fromSubmission =
          submissionProvider.submission.personalData?.isComplete ?? false;
      final step5 = appProvider.currentApplication?.step5PersonalData;
      final fromBackend = step5 != null &&
          (step5['nameAsPerAadhaar'] as String?)?.trim().isNotEmpty == true &&
          (step5['panNo'] as String?)?.trim().isNotEmpty == true &&
          (step5['mobileNumber'] as String?)?.trim().isNotEmpty == true &&
          (step5['personalEmailId'] as String?)?.trim().isNotEmpty == true &&
          (step5['residenceAddress'] as String?)?.trim().isNotEmpty == true;
      final personalDataComplete = fromSubmission || fromBackend;
      if (isProfessionalLoan) {
        context.go(AppRoutes.step6Preview);
      } else {
        context.go(
          HomeMortgageLoanFlow.routeAfterIncomeDocs(
            loanType: appProvider.currentApplication?.loanType,
            submission: submissionProvider.submission,
            personalDataComplete: personalDataComplete,
          ),
        );
      }
    }
  }

  /// Label for the continue button: "Continue to Preview" when next step is preview, else "Continue to Personal Data".
  String _getContinueButtonLabel(BuildContext context) {
    final submissionProvider = context.read<SubmissionProvider>();
    final appProvider = context.read<ApplicationProvider>();
    final loanType = (appProvider.currentApplication?.loanType ?? '').toLowerCase();
    final isStudentLoan = loanType.contains('student');
    final professionalType =
        (submissionProvider.submission.professionalLoanType ?? '').toLowerCase();
    final isProfessionalLoan = loanType.contains('professional') &&
        (professionalType == 'doctor' || professionalType == 'ca');
    final needsProperty = HomeMortgageLoanFlow.needsPropertyDetails(
      loanType: appProvider.currentApplication?.loanType,
      submission: submissionProvider.submission,
    );
    if (isProfessionalLoan) return 'Continue to Preview';
    if (isStudentLoan && !widget.isCoApplicant) return 'Continue to Student Documents';
    if (widget.isCoApplicant) {
      return needsProperty
          ? 'Continue to Property Details'
          : 'Continue to Personal Data';
    }
    if (submissionProvider.submission.hasCoApplicant) {
      final coAadhaarComplete =
          submissionProvider.submission.coApplicantAadhaar?.isComplete ?? false;
      final coPanComplete =
          submissionProvider.submission.coApplicantPan?.isComplete ?? false;
      final coBankComplete =
          submissionProvider.submission.coApplicantBankStatement?.isComplete ?? false;
      final coSalaryComplete =
          submissionProvider.submission.coApplicantSalarySlips?.isComplete ?? false;
      if (!coAadhaarComplete) return 'Continue to Co-applicant Aadhaar';
      if (!coPanComplete) return 'Continue to Co-applicant PAN';
      if (!coBankComplete) return 'Continue to Co-applicant Bank Statement';
      if (!coSalaryComplete) return 'Continue to Co-applicant Salary Slips';
    }
    final fromSubmission =
        submissionProvider.submission.personalData?.isComplete ?? false;
    final step5 = appProvider.currentApplication?.step5PersonalData;
    final fromBackend = step5 != null &&
        (step5['nameAsPerAadhaar'] as String?)?.trim().isNotEmpty == true &&
        (step5['panNo'] as String?)?.trim().isNotEmpty == true &&
        (step5['mobileNumber'] as String?)?.trim().isNotEmpty == true &&
        (step5['personalEmailId'] as String?)?.trim().isNotEmpty == true &&
        (step5['residenceAddress'] as String?)?.trim().isNotEmpty == true;
    if (needsProperty) return 'Continue to Property Details';
    final personalDataComplete = fromSubmission || fromBackend;
    return personalDataComplete ? 'Continue to Preview' : 'Continue to Personal Data';
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider to trigger rebuilds when draft loads
    context.watch<SubmissionProvider>();
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appProvider = context.read<ApplicationProvider>();
    final loanType = (appProvider.currentApplication?.loanType ?? '').toLowerCase();
    final isStudentLoan = loanType.contains('student');

    return PreventCloseOnBack(
      onBack: () {
        if (widget.fromPreview) {
          context.go(AppRoutes.step6Preview);
          return;
        }
        final appProvider = context.read<ApplicationProvider>();
        final submissionProvider = context.read<SubmissionProvider>();
        final loanType = (appProvider.currentApplication?.loanType ?? '').toLowerCase();
        final professionalType =
            (submissionProvider.submission.professionalLoanType ?? '').toLowerCase();
        final isProfessionalLoan = loanType.contains('professional') &&
            (professionalType == 'doctor' || professionalType == 'ca');
        if (widget.isCoApplicant) {
          context.go(AppRoutes.coApplicantBankStatement);
          return;
        }
        context.go(
          isProfessionalLoan ? AppRoutes.step5PersonalData : AppRoutes.step4BankStatement,
        );
      },
      child: Scaffold(
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
          child: ((isStudentLoan && !widget.isCoApplicant) || _hasAllRequiredSlips)
              ? PremiumButton(
                  label: _getContinueButtonLabel(context),
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
              onBackPressed: () {
                if (widget.fromPreview) {
                  context.go(AppRoutes.step6Preview);
                  return;
                }
                final appProvider = context.read<ApplicationProvider>();
                final submissionProvider = context.read<SubmissionProvider>();
                final loanType = (appProvider.currentApplication?.loanType ?? '').toLowerCase();
                final professionalType =
                    (submissionProvider.submission.professionalLoanType ?? '').toLowerCase();
                final isProfessionalLoan = loanType.contains('professional') &&
                    (professionalType == 'doctor' || professionalType == 'ca');
                context.go(
                  isProfessionalLoan ? AppRoutes.step5PersonalData : AppRoutes.step4BankStatement,
                );
              },
              showHomeButton: true,
              actions: [
                PreviewHeaderAction(
                  backRoute: widget.isCoApplicant
                      ? AppRoutes.coApplicantSalarySlips
                      : AppRoutes.step5_1SalarySlips,
                ),
              ],
            ),
            Builder(
              builder: (context) {
                final hasCoApplicant = context.watch<SubmissionProvider>().submission.hasCoApplicant;
                return PremiumProgressIndicator(
                  currentStep: widget.isCoApplicant
                      ? 9
                      : (hasCoApplicant ? 5 : 5),
                  totalSteps: (widget.isCoApplicant || hasCoApplicant) ? 12 : 7,
                  maxVisibleSteps: 7,
                );
              },
            ),
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
                                      widget.isCoApplicant
                                          ? 'Upload Co-applicant Salary Slips'
                                          : 'Upload Salary Slips',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.isCoApplicant
                                          ? 'Upload the co-applicant\'s salary slips for income verification'
                                          : 'Upload your salary slips for income verification',
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

}
