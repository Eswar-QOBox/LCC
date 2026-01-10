import 'dart:typed_data';
import 'dart:convert';

/// Stub implementation for non-web platforms
/// This should never be called as kIsWeb check happens before
String createBlobUrlWebImpl(Uint8List bytes, String mimeType) {
  // Fallback: use data URI (works but less efficient for large files)
  final base64 = base64Encode(bytes);
  return 'data:$mimeType;base64,$base64';
}

