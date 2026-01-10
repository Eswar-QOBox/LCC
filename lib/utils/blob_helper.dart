import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional imports - use relative paths
import 'blob_helper_stub.dart' if (dart.library.html) 'blob_helper_web.dart' as blob_impl;

/// Creates a blob URL from bytes (web only)
/// On web, creates a proper blob URL using dart:html
/// Falls back to data URI if blob URL creation fails
String createBlobUrl(Uint8List bytes, {String mimeType = 'application/pdf'}) {
  if (!kIsWeb) {
    throw UnsupportedError('Blob URL creation only supported on web');
  }
  
  return blob_impl.createBlobUrlWebImpl(bytes, mimeType);
}

