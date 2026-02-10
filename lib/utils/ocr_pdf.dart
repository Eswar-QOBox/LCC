import 'dart:typed_data';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

/// PDF -> image bytes helper for OCR.
///
/// - **Does not affect image OCR flow**.
/// - Implemented via an Android native `PdfRenderer` MethodChannel.
/// - Not supported on web/iOS in this implementation.
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
}

