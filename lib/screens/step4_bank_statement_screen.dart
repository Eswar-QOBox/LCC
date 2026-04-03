import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/submission_provider.dart';
import '../providers/application_provider.dart';
import '../services/file_upload_service.dart';
import '../services/ocr_service.dart';
import '../utils/app_routes.dart';
import '../utils/blob_helper.dart';
import '../utils/ocr_pdf.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:io' if (dart.library.html) '../services/file_helper_stub.dart' as io;
import 'package:pdfrx/pdfrx.dart';
import '../widgets/premium_toast.dart';
import '../utils/app_theme.dart';
import '../widgets/app_header.dart';
import '../services/storage_service.dart';
import '../utils/api_config.dart';
import '../widgets/premium_progress_indicator.dart';
import '../widgets/preview_header_action.dart';
import '../widgets/prevent_close_on_back.dart';
import '../utils/debug_log.dart';
import '../utils/step4_merge.dart';

class Step4BankStatementScreen extends StatefulWidget {
  const Step4BankStatementScreen({
    super.key,
    this.fromPreview = false,
    this.isCoApplicant = false,
  });

  /// When true, Back and Continue return to Preview (opened via Edit from Preview).
  final bool fromPreview;

  /// When true, uploads apply to the co-applicant (joint personal loan).
  final bool isCoApplicant;

  @override
  State<Step4BankStatementScreen> createState() =>
      _Step4BankStatementScreenState();
}

class _Step4BankStatementScreenState extends State<Step4BankStatementScreen> {
  final FileUploadService _fileUploadService = FileUploadService();
  List<String> _pages = [];
  String? _pdfPassword;
  bool _isPdf = false;
  bool _isSaving = false;
  DateTime? _statementEndDate;
  DateTime? _calculatedStartDate;
  List<bool> _pageFailures = [];
  List<Uint8List?> _pageBytes = [];
  /// When true, do not overwrite _pages from backend (user has removed/replaced pages).
  bool _userHasModifiedPages = false;

  bool _isValidImageBytes(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // Check for common image headers
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true; // JPEG
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true; // PNG
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) return true; // GIF
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return true; // WebP
    return false;
  }

  /// Checks whether a PDF is encrypted by scanning the full file for the
  /// `/Encrypt` dictionary reference. The xref/trailer lives at the *end* of
  /// the file, so we must search the whole thing — not just the first few KB.
  ///
  /// We search the raw bytes directly (ASCII pattern match) instead of
  /// converting to a String, which would be slow and memory-heavy for large
  /// PDFs.
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

  /// Searches [data] for the ASCII-encoded [needle] without allocating a
  /// full String copy of the PDF.
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

  Future<bool> _tryOpenBankPdf(
    String localOrBlobPath,
    Uint8List? webBytes,
    String password,
  ) async {
    PdfDocument? doc;
    try {
      if (kIsWeb && webBytes != null) {
        doc = await PdfDocument.openData(
          webBytes,
          passwordProvider: password.isEmpty
              ? () async => null
              : createSimplePasswordProvider(password),
          firstAttemptByEmptyPassword: true,
          sourceName: 'bank_unlock_try',
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

  Future<String?> _showBankPdfPasswordDialog(
    String localOrBlobPath,
    Uint8List? webBytes,
  ) async {
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
                ok = await _tryOpenBankPdf(localOrBlobPath, webBytes, pwd);
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
                    'This bank statement PDF is password-protected. Enter the password to unlock it for verification.',
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

  Future<String?> _resolveBankPdfPasswordIfNeeded({
    required bool headerSuggestsEncrypt,
    required String localOrBlobPath,
    required Uint8List? webBytes,
  }) async {
    if (!headerSuggestsEncrypt) return '';
    if (await _tryOpenBankPdf(localOrBlobPath, webBytes, '')) return '';
    if (!mounted) return null;
    return _showBankPdfPasswordDialog(localOrBlobPath, webBytes);
  }

  /// True if path is from backend (uploaded previously) — includes relative API paths.
  bool _isFromBackend(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return true;
    final p = path.trim();
    if (p.startsWith('/api/') || p.startsWith('/uploads/')) return true;
    return false;
  }

  void _syncPagesToProvider() {
    final provider = context.read<SubmissionProvider>();
    if (widget.isCoApplicant) {
      provider.setCoApplicantBankStatementPages(_pages, isPdf: _isPdf);
    } else {
      provider.setBankStatementPages(_pages, isPdf: _isPdf);
    }
  }

  String? _referenceNameForOcr(SubmissionProvider provider) {
    if (widget.isCoApplicant) {
      final fromPersonal =
          provider.submission.coApplicantPersonalData?.nameAsPerAadhaar?.trim();
      if (fromPersonal != null && fromPersonal.isNotEmpty) return fromPersonal;
      return provider.submission.coApplicantExtractedNameFromAadhaar?.trim();
    }
    return provider.submission.personalData?.nameAsPerAadhaar?.trim();
  }

  /// Run OCR on bank statement to extract account holder name.
  /// Skips if pages are from backend. Uses Aadhaar name as approx reference.
  /// For password-protected PDFs, uses pdfrx-based renderer that supports decryption.
  Future<void> _runBankStatementOcrIfNeeded() async {
    final firstLocal = _pages.where((p) => !_isFromBackend(p)).firstOrNull;
    if (firstLocal == null) return;
    if (kIsWeb || firstLocal.startsWith('blob:')) return;
    final provider = context.read<SubmissionProvider>();
    final aadhaarName = _referenceNameForOcr(provider);
    try {
      Uint8List? imageBytes;
      if (_isPdf && firstLocal.toLowerCase().endsWith('.pdf')) {
        imageBytes = await _renderPdfPageForOcr(firstLocal, pageIndex: 0);
      }
      final periodStart = _calculatedStartDate;
      final periodEnd = _statementEndDate;
      final result = imageBytes != null
          ? await OcrService.extractBankStatementName(
              firstLocal,
              imageBytes: imageBytes,
              aadhaarNameReference: aadhaarName,
              statementPeriodStart: periodStart,
              statementPeriodEnd: periodEnd,
            )
          : await OcrService.extractBankStatementName(
              firstLocal,
              aadhaarNameReference: aadhaarName,
              statementPeriodStart: periodStart,
              statementPeriodEnd: periodEnd,
            );
      if (mounted && result.success) {
        if (widget.isCoApplicant) {
          provider.setCoApplicantBankStatementExtractedAccountHolderName(result.accountHolderName);
          provider.setCoApplicantBankStatementNameMatchesAadhaar(result.nameMatchesAadhaar);
        } else {
          provider.setBankStatementExtractedAccountHolderName(result.accountHolderName);
          provider.setBankStatementNameMatchesAadhaar(result.nameMatchesAadhaar);
        }
        if (kDebugMode) {
          debugPrint('[BankStatement] OCR extracted: ${result.accountHolderName}, nameMatchesAadhaar: ${result.nameMatchesAadhaar}');
        }
        if (aadhaarName != null && aadhaarName.trim().isNotEmpty) {
          if (result.nameMatchesAadhaar) {
            PremiumToast.showSuccess(context, 'Name on statement verified with Aadhaar.');
          } else {
            PremiumToast.showWarning(
              context,
              'Name on bank statement could not be verified with Aadhaar name. Please upload a statement in the account holder\'s name.',
              duration: const Duration(seconds: 4),
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[BankStatement] OCR failed: $e');
    }
  }

  /// Renders a single PDF page to JPEG for OCR.
  /// If a password is known, goes straight to pdfrx (which supports decryption).
  /// Otherwise tries the fast native renderer first, falling back to pdfrx on failure.
  Future<Uint8List?> _renderPdfPageForOcr(String pdfPath, {required int pageIndex}) async {
    final hasPassword = _pdfPassword != null && _pdfPassword!.isNotEmpty;

    // Fast path: native renderer (no password support).
    if (!hasPassword && OcrPdf.isSupported) {
      try {
        final count = await OcrPdf.getPageCount(pdfPath);
        if (count > pageIndex) {
          return await OcrPdf.renderPageToJpegBytes(pdfPath, pageIndex: pageIndex);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[BankStatement] Native PDF render failed, trying pdfrx: $e');
      }
    }

    // Fallback / password path: pdfrx-based renderer.
    return OcrPdf.renderPageWithPassword(
      pdfPath,
      pageIndex: pageIndex,
      password: _pdfPassword,
    );
  }

  @override
  void initState() {
    super.initState();
    final provider = context.read<SubmissionProvider>();
    final bs = widget.isCoApplicant
        ? provider.submission.coApplicantBankStatement
        : provider.submission.bankStatement;
    _pages = List.from(bs?.pages ?? []);
    _isPdf = bs?.isPdf ?? false;
    _pdfPassword = bs?.pdfPassword;
    
    // Automatically use today's date
    _statementEndDate = DateTime.now();
    _calculateStartDate();
    
    // Load existing data from backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingData();
    });
  }

  Future<void> _loadExistingData() async {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication) return;

    final application = appProvider.currentApplication!;
    if (application.step4BankStatement != null) {
      final stepData = application.step4BankStatement as Map<String, dynamic>;
      final coNested = stepData['coApplicantBankStatement'];
      final Map<String, dynamic>? coData =
          coNested is Map<String, dynamic> ? coNested : null;

      if (widget.isCoApplicant && coData == null) return;

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
        

        if (!mounted) return;
        if (_userHasModifiedPages) return;

        // Prefer in-memory submission over the application snapshot:
        // - If user cleared all pages, do not refill from server.
        // - If user has any pages in provider (including after partial removal), do not
        //   overwrite — otherwise returning to this screen restores stale server URLs.
        final submissionProvider = context.read<SubmissionProvider>();
        final existingBs = widget.isCoApplicant
            ? submissionProvider.submission.coApplicantBankStatement
            : submissionProvider.submission.bankStatement;
        if (existingBs != null) {
          if (existingBs.pages.isEmpty) {
            return;
          }
          // Submission already has pages (e.g. from draft / resume). Do not replace the
          // list, but normalize relative URLs and merge metadata from the application.
          if (!_userHasModifiedPages) {
            final src = widget.isCoApplicant ? coData! : stepData;
            final normalized = <String>[];
            var urlsChanged = false;
            for (final p in _pages) {
              if (p.startsWith('http://') ||
                  p.startsWith('https://') ||
                  p.startsWith('blob:')) {
                normalized.add(p);
                continue;
              }
              final u = buildFullUrl(p);
              if (u != null && u != p) urlsChanged = true;
              normalized.add(u ?? p);
            }
            if (mounted) {
              setState(() {
                if (urlsChanged) {
                  _pages = normalized;
                }
                final remoteIsPdf = src['isPdf'] as bool?;
                if (remoteIsPdf != null) _isPdf = remoteIsPdf;
                if (src['pdfPassword'] != null) {
                  _pdfPassword = src['pdfPassword'] as String?;
                }
                if (src['statementEndDate'] != null) {
                  _statementEndDate =
                      DateTime.parse(src['statementEndDate'] as String);
                  _calculateStartDate();
                } else if (src['calculatedStartDate'] != null) {
                  _calculatedStartDate =
                      DateTime.parse(src['calculatedStartDate'] as String);
                }
                while (_pageFailures.length < _pages.length) {
                  _pageFailures.add(false);
                }
                while (_pageBytes.length < _pages.length) {
                  _pageBytes.add(null);
                }
                while (_pageFailures.length > _pages.length) {
                  _pageFailures.removeLast();
                }
                while (_pageBytes.length > _pages.length) {
                  _pageBytes.removeLast();
                }
              });
              _syncPagesToProvider();
              if (accessToken != null &&
                  !_isPdf &&
                  normalized.any((page) =>
                      page.startsWith('http://') ||
                      page.startsWith('https://'))) {
                for (int i = 0; i < _pages.length; i++) {
                  final page = _pages[i];
                  if (page.startsWith('http')) {
                    _verifyPage(page, i, accessToken);
                  }
                }
              }
            }
          }
          return;
        }

        setState(() {
          final src = widget.isCoApplicant ? coData! : stepData;
          final rawPages = List<String>.from((src['pages'] as List?) ?? []);
          _pages = rawPages.map((p) => buildFullUrl(p) ?? p).toList();
          _isPdf = src['isPdf'] as bool? ?? false;
          // Initialize failure/bytes lists
          _pageFailures = List.filled(_pages.length, false);
          _pageBytes = List.filled(_pages.length, null);

          _pdfPassword = src['pdfPassword'] as String?;
          if (src['statementEndDate'] != null) {
            _statementEndDate = DateTime.parse(src['statementEndDate'] as String);
            _calculateStartDate();
          } else if (src['calculatedStartDate'] != null) {
            _calculatedStartDate = DateTime.parse(src['calculatedStartDate'] as String);
          }
        });

        // Verify images asynchronously if auth token is available
        if (accessToken != null && !_isPdf) {
          for (int i = 0; i < _pages.length; i++) {
            final page = _pages[i];
            if (page.startsWith('http')) {
              _verifyPage(page, i, accessToken);
            }
          }
        }
    }
  }

  Future<void> _verifyPage(String url, int index, String token) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (index >= _pageFailures.length) return; // Bounds check

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';
        final isLikelyImage = contentType.startsWith('image/');
        final bytes = response.bodyBytes;
        if (isLikelyImage && _isValidImageBytes(bytes)) {
          setState(() {
            _pageBytes[index] = bytes;
            _pageFailures[index] = false;
          });
        } else {
          setState(() { _pageFailures[index] = true; });
        }
      } else {
        setState(() { _pageFailures[index] = true; });
      }
    } catch (e) {
      if (mounted && index < _pageFailures.length) {
        setState(() { _pageFailures[index] = true; });
      }
    }
  }

  void _calculateStartDate() {
    if (_statementEndDate == null) {
      _calculatedStartDate = null;
      return;
    }

    // Calculate 6 months back, always starting from the 1st of that month
    // This ensures the date range is >= 6 months and < 7 months
    // Example: If user gives July 5, calculate to January 1 (6 months back, 1st of month)
    //          Range: Jan 1 to Jul 5 = 6 months and 4 days (>= 6 months, < 7 months)
    // Example: If user gives July 25, calculate to January 1 (6 months back, 1st of month)
    //          Range: Jan 1 to Jul 25 = 6 months and 24 days (>= 6 months, < 7 months)
    final endDate = _statementEndDate!;
    
    // Subtract 6 months and set to 1st of that month
    DateTime startDate;
    if (endDate.month > 6) {
      // Same year, just subtract 6 months
      startDate = DateTime(
        endDate.year,
        endDate.month - 6,
        1, // Always use 1st of the month
      );
    } else {
      // Previous year, add 6 months to get to previous year
      startDate = DateTime(
        endDate.year - 1,
        endDate.month + 6,
        1, // Always use 1st of the month
      );
    }
    
    // Verify the range is >= 6 months and < 7 months
    final monthsDifference = (endDate.year - startDate.year) * 12 + (endDate.month - startDate.month);
    if (monthsDifference < 6 || monthsDifference >= 7) {
      // Adjust if needed to ensure >= 6 and < 7 months
      if (monthsDifference < 6) {
        // Need to go back one more month
        if (startDate.month == 1) {
          startDate = DateTime(startDate.year - 1, 12, 1);
        } else {
          startDate = DateTime(startDate.year, startDate.month - 1, 1);
        }
      } else if (monthsDifference >= 7) {
        // Need to go forward one month
        if (startDate.month == 12) {
          startDate = DateTime(startDate.year + 1, 1, 1);
        } else {
          startDate = DateTime(startDate.year, startDate.month + 1, 1);
        }
      }
    }
    
    setState(() {
      _calculatedStartDate = startDate;
    });
  }

  /// Saves draft to DB. Returns true only if save succeeded; then safe to go to next step.
  Future<bool> _saveToBackend() async {
    final appProvider = context.read<ApplicationProvider>();
    if (!appProvider.hasApplication || _pages.isEmpty) return false;

    final submissionProvider = context.read<SubmissionProvider>();
    final loanType = (appProvider.currentApplication?.loanType ?? '').toLowerCase();
    final businessLoanType =
        (submissionProvider.submission.businessLoanType ?? '').toLowerCase();
    final isBusinessProprietor = loanType.contains('business') && businessLoanType == 'proprietor';

    setState(() {
      _isSaving = true;
    });

    try {
      final localPaths = _pages.where((p) => !_isFromBackend(p)).toList();
      final remoteUrls = _pages.where((p) => _isFromBackend(p)).toList();
      List<Map<String, dynamic>> finalUploadedFiles = [];

      if (remoteUrls.isNotEmpty) {
        final currentApp = appProvider.currentApplication;
        if (currentApp?.step4BankStatement != null) {
          final stepData = currentApp!.step4BankStatement as Map<String, dynamic>;
          final List<Map<String, dynamic>> existingUploads;
          if (widget.isCoApplicant) {
            final co = stepData['coApplicantBankStatement'];
            existingUploads = (co is Map<String, dynamic>
                    ? (co['uploadedFiles'] as List<dynamic>?)
                    : null)
                ?.cast<Map<String, dynamic>>() ??
                [];
          } else {
            existingUploads = (stepData['uploadedFiles'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [];
          }
          for (final upload in existingUploads) {
            final url = upload['url'] as String?;
            if (url != null &&
                remoteUrls.any((r) => r.contains(url) || url.contains(r)) &&
                !finalUploadedFiles.any((f) => f['url'] == url)) {
              finalUploadedFiles.add(upload);
            }
          }
        }
      }

      if (localPaths.isNotEmpty) {
        final files = localPaths.map((path) => XFile(path)).toList();
        final newUploadResults = await _fileUploadService.uploadBankStatements(files);
        finalUploadedFiles.addAll(newUploadResults);
      }

      final existingStep4 = appProvider.currentApplication?.step4BankStatement;
      if (widget.isCoApplicant) {
        final merged = mergeStep4BankStatement(existingStep4, {
          'coApplicantBankStatement': {
            'pages': _pages.toSet().toList(),
            'isPdf': _isPdf,
            'pdfPassword': _pdfPassword,
            'uploadedFiles': finalUploadedFiles,
            'statementEndDate': _statementEndDate?.toIso8601String(),
            'calculatedStartDate': _calculatedStartDate?.toIso8601String(),
            'savedAt': DateTime.now().toIso8601String(),
          },
        });
        await appProvider.updateApplication(
          currentStep: isBusinessProprietor ? 7 : 5,
          step4BankStatement: merged,
        );
      } else {
        final merged = mergeStep4BankStatement(existingStep4, {
          'pages': _pages.toSet().toList(),
          'isPdf': _isPdf,
          'pdfPassword': _pdfPassword,
          'uploadedFiles': finalUploadedFiles,
          'statementEndDate': _statementEndDate?.toIso8601String(),
          'calculatedStartDate': _calculatedStartDate?.toIso8601String(),
          'savedAt': DateTime.now().toIso8601String(),
        });
        await appProvider.updateApplication(
          currentStep: isBusinessProprietor ? 7 : 5,
          step4BankStatement: merged,
        );
      }

      if (mounted) {
        PremiumToast.showSuccess(context, 'Bank statement saved successfully!');
      }
      return true;
    } catch (e) {
      if (mounted) {
        PremiumToast.showError(
          context,
          'Failed to save bank statement: ${e.toString()}',
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
              PremiumToast.showError(
                context,
                'Unable to read PDF file. Please try again.',
                actionLabel: 'Retry',
                onAction: _uploadPdf,
              );
            }
            return;
          }
          bytesForCheck = bytes;
          path = createBlobUrl(bytes, mimeType: 'application/pdf');
        } else {
          if (result.files.single.path == null) {
            if (mounted) {
              PremiumToast.showError(
                context,
                'Unable to access file. Please try again.',
                actionLabel: 'Retry',
                onAction: _uploadPdf,
              );
            }
            return;
          }
          pathForCheck = result.files.single.path!;
          path = result.files.single.path!;
        }

        final isEncrypted = await _isPdfEncrypted(pathForCheck, bytesForCheck);
        if (!mounted) return;
        final resolvedPassword = await _resolveBankPdfPasswordIfNeeded(
          headerSuggestsEncrypt: isEncrypted,
          localOrBlobPath: path,
          webBytes: bytesForCheck,
        );
        if (resolvedPassword == null || !mounted) return;

        setState(() {
          _pages = [..._pages, path];
          _isPdf = true;
          _pdfPassword = resolvedPassword.isEmpty ? null : resolvedPassword;
          _pageFailures = [..._pageFailures, false];
          _pageBytes = [..._pageBytes, null];
        });
        _syncPagesToProvider();
        final p = context.read<SubmissionProvider>();
        if (_pdfPassword != null && _pdfPassword!.isNotEmpty) {
          if (widget.isCoApplicant) {
            p.setCoApplicantBankStatementPassword(_pdfPassword!);
          } else {
            p.setBankStatementPassword(_pdfPassword!);
          }
        }
        unawaited(_runBankStatementOcrIfNeeded());
      }
    } catch (e) {
      debugPrint('[BankStatement] _uploadPdf error: $e');
      if (mounted) {
        PremiumToast.showError(
          context,
          'Unable to process PDF. Please try again.',
          actionLabel: 'Retry',
          onAction: _uploadPdf,
        );
      }
    }
  }




  void _removePage(int index) {
    if (index < 0 || index >= _pages.length) return;
    setState(() {
      _userHasModifiedPages = true;
      _pages.removeAt(index);
      if (index < _pageFailures.length) {
        _pageFailures.removeAt(index);
      }
      if (index < _pageBytes.length) {
        _pageBytes.removeAt(index);
      }
      while (_pageFailures.length > _pages.length) {
        _pageFailures.removeLast();
      }
      while (_pageBytes.length > _pages.length) {
        _pageBytes.removeLast();
      }
      while (_pageFailures.length < _pages.length) {
        _pageFailures.add(false);
      }
      while (_pageBytes.length < _pages.length) {
        _pageBytes.add(null);
      }
    });
    _syncPagesToProvider();
  }

  Future<void> _proceedToNext() async {
    if (_pages.isEmpty) {
      PremiumToast.showWarning(
        context,
        'Please upload bank statement (last 6 months)',
      );
      return;
    }
    // When multiple files: ensure user confirms they are from same period (not different months)
    // #region agent log
    debugAgentLog(
      location: 'step4_bank_statement_screen.dart:_proceedToNext',
      message: 'Bank statement proceed',
      data: {'pagesLength': _pages.length, 'isPdf': _isPdf, 'willShowDialog': _pages.length > 1},
      hypothesisId: 'H-C',
    );
    // #endregion
    // Server-only statements (resume from backend) are allowed: OCR / hard validation
    // apply only when the user has local uploads (see below).

    if (_pages.length > 1 && mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Confirm statement period'),
          content: const Text(
            'All uploaded pages/PDFs must be from the same 6-month period (same account). '
            'Statements from different months are not accepted.\n\n'
            'Confirm that all statements are from the required period?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No, I\'ll fix it'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes, confirm'),
            ),
          ],
        ),
      );
      // #region agent log
      if (mounted) {
        debugAgentLog(
          location: 'step4_bank_statement_screen.dart:dialogResult',
          message: 'Bank statement dialog',
          data: {'confirmed': confirmed},
          hypothesisId: 'H-C',
        );
      }
      // #endregion
      if (confirmed != true || !mounted) return;
    }

    // Hard validation: uploaded statements must be from the same account and
    // represent a consistent 6-month period. We validate only local uploads
    // (newly added in this session/device), because remote files may not be
    // readable for OCR here.
    final localPages = _pages.where((p) => !_isFromBackend(p)).toList();
    if (!kIsWeb && localPages.isNotEmpty) {
      final validation = await _validateBankStatementConsistency(localPages);
      if (!mounted) return;
      if (!validation.isValid) {
        PremiumToast.showError(
          context,
          validation.errorMessage ??
              'Bank statements failed consistency validation. Please re-upload.',
          duration: const Duration(seconds: 5),
        );
        return;
      }
    }

    if (!mounted) return;
    final provider = context.read<SubmissionProvider>();
    final refName = _referenceNameForOcr(provider);
    final hasLocalPages = _pages.any((p) => !_isFromBackend(p));
    final nameMatches = widget.isCoApplicant
        ? provider.submission.coApplicantBankStatement?.nameMatchesAadhaar
        : provider.submission.bankStatement?.nameMatchesAadhaar;
    if (hasLocalPages &&
        refName != null &&
        refName.isNotEmpty &&
        nameMatches == false) {
      PremiumToast.showError(
        context,
        'Name on bank statement could not be verified with Aadhaar name. Please upload a statement in the account holder\'s name.',
        duration: const Duration(seconds: 4),
      );
      return;
    }
    if (_isSaving) return;
    final saved = await _saveToBackend();
    if (mounted && saved) {
    final appProvider = context.read<ApplicationProvider>();
    final submissionProvider = context.read<SubmissionProvider>();
    final loanType = (appProvider.currentApplication?.loanType ??
            submissionProvider.submission.loanType ??
            '')
        .toLowerCase();
      final businessLoanType =
          (submissionProvider.submission.businessLoanType ?? '').toLowerCase();

      final isBusiness = loanType.contains('business');
      final isBusinessProprietor = isBusiness && businessLoanType == 'proprietor';
      final isBusinessPartnership = isBusiness && businessLoanType == 'partnership';
      final isBusinessPvtLimited = isBusiness && businessLoanType == 'pvt_limited';
      final isProfessional = loanType.contains('professional');
      final professionalType = (submissionProvider.submission.professionalLoanType ?? '').toLowerCase();
      final isProfessionalDoctorOrCa = isProfessional && (professionalType == 'doctor' || professionalType == 'ca');
      final isStudent = loanType.contains('student');
      if (widget.fromPreview) {
        context.go(AppRoutes.step6Preview);
        return;
      }
      if (widget.isCoApplicant) {
        context.go(AppRoutes.coApplicantSalarySlips);
        return;
      }
      final isPersonalLoan = !isBusiness && !isProfessionalDoctorOrCa && !isStudent;
      context.go(
        isBusinessProprietor
            ? AppRoutes.step5BusinessDocs
            : (isBusinessPartnership || isBusinessPvtLimited
                ? AppRoutes.partnerCount
                : isProfessionalDoctorOrCa
                    ? AppRoutes.step5ProfessionalDocs
                    : isStudent
                        ? AppRoutes.step5StudentDocs
                        : isPersonalLoan
                            ? AppRoutes.step5_1SalarySlips
                            : AppRoutes.step5_1SalarySlips),
      );
    }
  }

  Future<({bool isValid, String? errorMessage})> _validateBankStatementConsistency(
    List<String> localPages,
  ) async {
    final accountTokens = <String>[];
    final allMonths = <int>{};

    for (final path in localPages) {
      final text = await _extractStatementText(path);
      if (text == null || text.trim().isEmpty) {
        if (_isPdfPath(path)) {
          final encrypted = await _isPdfEncrypted(path, null);
          if (encrypted) {
            return (
              isValid: false,
              errorMessage:
                  'This PDF is password-protected. Please re-upload and enter the correct password when prompted.',
            );
          }
        }
        return (
          isValid: false,
          errorMessage:
              'Could not read one of the bank statements. Please upload clearer files.',
        );
      }

      final account = _extractAccountToken(text);
      if (account == null || account.isEmpty) {
        return (
          isValid: false,
          errorMessage:
              'Could not detect account number on one statement. Please upload clearer files from the same account.',
        );
      }
      accountTokens.add(account);

      final months = _extractMonthKeysFromText(text);
      if (months.isEmpty) {
        return (
          isValid: false,
          errorMessage:
              'Could not detect statement month(s) from one file. Please upload readable statements.',
        );
      }
      allMonths.addAll(months);
    }

    // All statements must belong to the same account (masked forms normalize to same token).
    final uniqueAccounts = accountTokens.toSet();
    if (uniqueAccounts.length > 1) {
      return (
        isValid: false,
        errorMessage:
            'Statements appear to be from different accounts. Please upload statements for a single account only.',
      );
    }

    if (allMonths.length < 6) {
      return (
        isValid: false,
        errorMessage:
            'At least 6 statement months are required. Current upload does not cover full 6 months.',
      );
    }

    final sorted = allMonths.toList()..sort();
    final minKey = sorted.first;
    final maxKey = sorted.last;
    final span = _monthDiff(minKey, maxKey) + 1;

    // Accept a tight range only. If the spread is too large, user likely mixed periods.
    if (span > 7) {
      return (
        isValid: false,
        errorMessage:
            'Statement months are inconsistent. Please upload documents from one continuous 6-month period.',
      );
    }

    return (isValid: true, errorMessage: null);
  }

  Future<String?> _extractStatementText(String path) async {
    try {
      if (_isPdfPath(path)) {
        final hasPassword = _pdfPassword != null && _pdfPassword!.isNotEmpty;

        int count;
        if (hasPassword || !OcrPdf.isSupported) {
          count = await OcrPdf.getPageCountWithPassword(path, password: _pdfPassword);
        } else {
          count = await OcrPdf.getPageCount(path);
          if (count <= 0) {
            count = await OcrPdf.getPageCountWithPassword(path, password: _pdfPassword);
          }
        }
        if (count <= 0) return null;

        // Read up to first 6 pages to capture month range + account details.
        final pagesToRead = count > 6 ? 6 : count;
        final parts = <String>[];
        for (int i = 0; i < pagesToRead; i++) {
          final imgBytes = await _renderPdfPageForOcr(path, pageIndex: i);
          if (imgBytes == null) continue;
          final result = await OcrService.extractDocumentText(
            path,
            imageBytes: imgBytes,
          );
          if (result.success && (result.fullText ?? '').trim().isNotEmpty) {
            parts.add(result.fullText!.trim());
          }
        }
        return parts.join('\n');
      }

      final result = await OcrService.extractDocumentText(path);
      if (!result.success) return null;
      return result.fullText;
    } catch (_) {
      return null;
    }
  }

  bool _isPdfPath(String path) => path.toLowerCase().endsWith('.pdf');

  String? _extractAccountToken(String text) {
    final upper = text.toUpperCase();
    final patterns = <RegExp>[
      RegExp(
        r'(?:A\/?C(?:COUNT)?(?:\s*(?:NO|NUMBER))?|ACCOUNT(?:\s*(?:NO|NUMBER))?)\s*[:\-]?\s*([0-9X\*]{6,20})',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:ACCT|ACCOUNT)\s*[:\-]?\s*([0-9X\*]{6,20})',
        caseSensitive: false,
      ),
    ];

    for (final re in patterns) {
      final m = re.firstMatch(upper);
      final raw = m?.group(1);
      if (raw == null) continue;
      final normalized = raw.replaceAll(RegExp(r'[^0-9X\*]'), '');
      if (normalized.length >= 6) return normalized;
    }
    return null;
  }

  Set<int> _extractMonthKeysFromText(String text) {
    final out = <int>{};
    final upper = text.toUpperCase();

    const monthMap = <String, int>{
      'JAN': 1,
      'FEB': 2,
      'MAR': 3,
      'APR': 4,
      'MAY': 5,
      'JUN': 6,
      'JUL': 7,
      'AUG': 8,
      'SEP': 9,
      'OCT': 10,
      'NOV': 11,
      'DEC': 12,
    };

    final monthNameRe = RegExp(
      r'\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*[\s\-/.,]*(20\d{2})\b',
      caseSensitive: false,
    );
    for (final m in monthNameRe.allMatches(upper)) {
      final mon = m.group(1)?.substring(0, 3).toUpperCase();
      final yr = int.tryParse(m.group(2) ?? '');
      if (mon == null || yr == null) continue;
      final mm = monthMap[mon];
      if (mm == null) continue;
      out.add(yr * 100 + mm);
    }

    final monthNumRe = RegExp(r'\b(0?[1-9]|1[0-2])[\/\-](20\d{2})\b');
    for (final m in monthNumRe.allMatches(upper)) {
      final mm = int.tryParse(m.group(1) ?? '');
      final yy = int.tryParse(m.group(2) ?? '');
      if (mm == null || yy == null) continue;
      out.add(yy * 100 + mm);
    }

    return out;
  }

  int _monthDiff(int startKey, int endKey) {
    final sy = startKey ~/ 100;
    final sm = startKey % 100;
    final ey = endKey ~/ 100;
    final em = endKey % 100;
    return (ey - sy) * 12 + (em - sm);
  }

  String _formatDateWithYear(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return PreventCloseOnBack(
      onBack: () {
        if (widget.fromPreview) {
          context.go(AppRoutes.step6Preview);
          return;
        }
        if (widget.isCoApplicant) {
          context.go(AppRoutes.coApplicantPan);
          return;
        }
        final appProvider = context.read<ApplicationProvider>();
        final submissionProvider = context.read<SubmissionProvider>();
        final loanType = (appProvider.currentApplication?.loanType ??
                submissionProvider.submission.loanType ??
                '')
            .toLowerCase();
        final businessLoanType =
            (submissionProvider.submission.businessLoanType ?? '').toLowerCase();
        final isBusinessProprietor =
            loanType.contains('business') && businessLoanType == 'proprietor';
        final isProfessional = loanType.contains('professional');
        context.go(isBusinessProprietor
            ? AppRoutes.step5SpousePan
            : (isProfessional ? AppRoutes.step3Pan : AppRoutes.step3Pan));
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Royal Blue Header
            AppHeader(
              title: widget.isCoApplicant
                  ? 'Co-applicant Bank Statement'
                  : 'Bank Statement',
              icon: Icons.account_balance,
              showBackButton: true,
              onBackPressed: () {
                if (widget.fromPreview) {
                  context.go(AppRoutes.step6Preview);
                  return;
                }
                if (widget.isCoApplicant) {
                  context.go(AppRoutes.coApplicantPan);
                  return;
                }
                final appProvider = context.read<ApplicationProvider>();
                final submissionProvider = context.read<SubmissionProvider>();
                final loanType = (appProvider.currentApplication?.loanType ??
                        submissionProvider.submission.loanType ??
                        '')
                    .toLowerCase();
                final businessLoanType =
                    (submissionProvider.submission.businessLoanType ?? '').toLowerCase();
                final isBusinessProprietor =
                    loanType.contains('business') && businessLoanType == 'proprietor';
                final isProfessional = loanType.contains('professional');
                context.go(isBusinessProprietor
                    ? AppRoutes.step5SpousePan
                    : (isProfessional ? AppRoutes.step3Pan : AppRoutes.step3Pan));
              },
              showHomeButton: true,
              actions: [
                PreviewHeaderAction(
                  backRoute: widget.isCoApplicant
                      ? AppRoutes.coApplicantBankStatement
                      : AppRoutes.step4BankStatement,
                ),
              ],
            ),
            
            // Progress Indicator
            Builder(
              builder: (context) {
                final appProvider = context.read<ApplicationProvider>();
                final submissionProvider = context.read<SubmissionProvider>();
                final loanType =
                    (appProvider.currentApplication?.loanType ?? '').toLowerCase();
                final businessLoanType =
                    (submissionProvider.submission.businessLoanType ?? '').toLowerCase();
                final isBusinessProprietor =
                    loanType.contains('business') && businessLoanType == 'proprietor';
                final isBusinessPartnership =
                    loanType.contains('business') && businessLoanType == 'partnership';
                final isBusinessPvtLimited =
                    loanType.contains('business') && businessLoanType == 'pvt_limited';
                final partnerCount = submissionProvider.submission.businessDocuments?.partnerCount ?? 0;
                final totalStepsPartnerFlow = partnerCount > 0 ? (10 + 2 * partnerCount) : 10;
                final hasCoApplicant = submissionProvider.submission.hasCoApplicant;

                if (widget.isCoApplicant) {
                  return _buildProgressIndicator(
                    context,
                    currentStep: 8,
                    totalSteps: 12,
                  );
                }

                return _buildProgressIndicator(
                  context,
                  currentStep: isBusinessProprietor ? 6 : (isBusinessPartnership || isBusinessPvtLimited ? 4 : 4),
                  totalSteps: isBusinessProprietor
                      ? 10
                      : (isBusinessPartnership || isBusinessPvtLimited
                          ? totalStepsPartnerFlow
                          : (hasCoApplicant ? 12 : 7)),
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
                    const SizedBox(height: 20),
                    
                    // Required Statement Period Card
                    if (_statementEndDate != null && _calculatedStartDate != null)
                      _buildRequiredPeriodCard(context),
                    const SizedBox(height: 20),
                    
                    // Uploaded Pages Section
                    if (_pages.isNotEmpty)
                      _buildUploadedPagesSection(context)
                    else
                      _buildEmptyUploadState(context),
                    const SizedBox(height: 100), // Space for footer
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildFooter(context),
    )
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEFF6FF), // blue-50
            Color(0xFFDBEAFE), // blue-100/50
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFDBEAFE).withValues(alpha: 0.5),
          width: 1,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance,
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
                      'Bank Statement Requirements',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last 6 months from today',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildRequirementItem(Icons.calendar_today, 'Must be last 6 months'),
          const SizedBox(height: 8),
          _buildRequirementItem(Icons.warning_amber_rounded, 'All pages/PDFs must be from the same 6-month period (do not mix different months)'),
          const SizedBox(height: 16),
          _buildRequirementItem(Icons.lock, 'PDF password supported'),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE), // blue-100
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF334155), // slate-700
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequiredPeriodCard(BuildContext context) {
    final theme = Theme.of(context);
    final days = _statementEndDate!.difference(_calculatedStartDate!).inDays.abs();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE).withValues(alpha: 0.3), // red-50/30
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFCDD2).withValues(alpha: 0.3), // red-200/30
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F), // red-600
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.event,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Required Statement Period',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFFB71C1C), // red-700
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFCDD2).withValues(alpha: 0.2),
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
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning,
                      color: Color(0xFFD32F2F),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'IMPORTANT',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD32F2F),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: const Color(0xFF475569),
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'From '),
                      TextSpan(
                        text: _formatDateWithYear(_calculatedStartDate!),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const TextSpan(text: ' to '),
                      TextSpan(
                        text: _formatDateWithYear(_statementEndDate!),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'you need to submit your bank statement',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFD32F2F),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE), // red-50
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule,
                        color: Color(0xFFD32F2F),
                        size: 12,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$days DAYS (≈6 MONTHS)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD32F2F),
                          letterSpacing: 0.5,
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
    );
  }

  Widget _buildUploadedPagesSection(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey.shade100,
          width: 1,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isPdf ? 'Uploaded loan PDFs' : 'Uploaded Pages',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isPdf
                        ? '${_pages.length} ${_pages.length == 1 ? 'PDF' : 'PDFs'}'
                        : '${_pages.length} ${_pages.length == 1 ? 'page' : 'pages'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4), // emerald-50
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF22C55E), // emerald-600
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'READY',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF22C55E),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // PDF Preview Cards
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: List.generate(_pages.length, (index) {
              return _buildPdfCard(context, index);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfCard(BuildContext context, int index) {
    final theme = Theme.of(context);

    return Container(
      width: 160,
      height: 213, // aspect ratio 3:4
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // blue-50
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFDBEAFE), // blue-100
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.picture_as_pdf,
                  size: 60,
                  color: Color(0xFF3B82F6), // blue-500
                ),
                const SizedBox(height: 8),
                Text(
                  'PDF',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2563EB), // blue-600
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
          // Delete button - fully inside card with larger tap target for reliability
          Positioned(
            top: 6,
            right: 6,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _removePage(index),
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444), // red-500
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
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // PDF/page number badge
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade800.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _isPdf ? 'PDF ${index + 1}' : 'Page ${index + 1}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade100, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Add another PDF / Change PDF Button
          if (_pages.isNotEmpty)
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: _uploadPdf,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _isPdf ? 'Add another PDF' : 'Add page',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_pages.isNotEmpty) const SizedBox(height: 12),
          // Continue Button
          Material(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: _proceedToNext,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      const Color(0xFF0052CC), // royal-blue
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
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
          const SizedBox(height: 16),
          // Indicator bar
          Container(
            width: 128,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyUploadState(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'Upload Bank Statement',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload one or more PDF files (last 6 months)',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          Material(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: _uploadPdf,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Upload PDF',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

