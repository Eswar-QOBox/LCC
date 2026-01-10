import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert';

/// Web implementation using dart:html for proper blob URLs
String createBlobUrlWebImpl(Uint8List bytes, String mimeType) {
  try {
    // Create a Blob from bytes
    final blob = html.Blob([bytes], mimeType);
    // Create object URL from blob
    final url = html.Url.createObjectUrlFromBlob(blob);
    return url.toString();
  } catch (e) {
    // Fallback to data URI if blob URL creation fails
    final base64 = base64Encode(bytes);
    return 'data:$mimeType;base64,$base64';
  }
}

