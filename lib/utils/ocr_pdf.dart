import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

/// PDF -> image bytes helper for OCR.
///
/// Two rendering paths:
/// 1. **Native** (Android only, fast, no password support) via MethodChannel.
/// 2. **pdfrx** (cross-platform, supports password-protected PDFs) as fallback.
class OcrPdf {
  static const MethodChannel _channel = MethodChannel('lcc_pdf_renderer');

  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  static Future<int> getPageCount(String pdfPath) async {
    if (!isSupported) {
      throw UnsupportedError('PDF OCR rendering is only supported on Android (non-web).');
    }
    final count = await _channel.invokeMethod<int>('pageCount', {'path': pdfPath});
    return count ?? 0;
  }

  /// Renders a PDF page to JPEG bytes suitable for ML Kit OCR.
  ///
  /// [pageIndex] is 0-based.
  static Future<Uint8List> renderPageToJpegBytes(
    String pdfPath, {
    required int pageIndex,
    double scale = 2.0,
    int jpegQuality = 92,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('PDF OCR rendering is only supported on Android (non-web).');
    }
    final bytes = await _channel.invokeMethod<Uint8List>('renderPage', {
      'path': pdfPath,
      'pageIndex': pageIndex,
      'scale': scale,
      'jpegQuality': jpegQuality,
    });
    if (bytes == null || bytes.isEmpty) {
      throw StateError('PDF page render returned empty bytes');
    }
    return bytes;
  }

  /// Renders a PDF page to JPEG using pdfrx — works with password-protected
  /// PDFs and on all platforms (Android, iOS, desktop).
  ///
  /// Falls back to this when [renderPageToJpegBytes] fails (encrypted PDF)
  /// or when a [password] is known ahead of time.
  static Future<Uint8List?> renderPageWithPassword(
    String pdfPath, {
    required int pageIndex,
    String? password,
    double scale = 2.0,
    int jpegQuality = 92,
  }) async {
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openFile(
        pdfPath,
        passwordProvider: (password != null && password.isNotEmpty)
            ? createSimplePasswordProvider(password)
            : () async => null,
        firstAttemptByEmptyPassword: true,
      );

      if (pageIndex < 0 || pageIndex >= doc.pages.length) return null;
      final page = doc.pages[pageIndex];

      final renderW = (page.width * scale).round();
      final renderH = (page.height * scale).round();
      if (renderW <= 0 || renderH <= 0) return null;

      final pdfImage = await page.render(
        width: renderW,
        height: renderH,
        fullWidth: renderW.toDouble(),
        fullHeight: renderH.toDouble(),
        backgroundColor: 0xFFFFFFFF,
      );
      if (pdfImage == null) return null;

      // Convert BGRA8888 pixel data to JPEG via the image package.
      final decoded = img.Image.fromBytes(
        width: pdfImage.width,
        height: pdfImage.height,
        bytes: pdfImage.pixels.buffer,
        order: img.ChannelOrder.bgra,
      );
      pdfImage.dispose();

      final jpegBytes = Uint8List.fromList(
        img.encodeJpg(decoded, quality: jpegQuality),
      );
      return jpegBytes;
    } catch (e) {
      debugPrint('[OcrPdf] renderPageWithPassword failed: $e');
      return null;
    } finally {
      await doc?.dispose();
    }
  }

  /// Returns the page count using pdfrx (supports passwords).
  static Future<int> getPageCountWithPassword(
    String pdfPath, {
    String? password,
  }) async {
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openFile(
        pdfPath,
        passwordProvider: (password != null && password.isNotEmpty)
            ? createSimplePasswordProvider(password)
            : () async => null,
        firstAttemptByEmptyPassword: true,
      );
      return doc.pages.length;
    } catch (e) {
      debugPrint('[OcrPdf] getPageCountWithPassword failed: $e');
      return 0;
    } finally {
      await doc?.dispose();
    }
  }
}

