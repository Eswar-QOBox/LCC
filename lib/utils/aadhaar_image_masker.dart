import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:image/image.dart' as img;

/// Burns black masks over the first two 4-digit groups of every Aadhaar number
/// occurrence directly into the image bytes. On a single big card (e-Aadhaar),
/// the number appears twice — all instances are masked so only the last 4
/// digits remain visible.
class AadhaarImageMasker {
  AadhaarImageMasker._();

  /// [imageBytes]  — original image (JPEG/PNG).
  /// [rects]       — list of normalized (0-1) bounding boxes, one per digit
  ///                 group to mask (typically 2).
  ///
  /// Returns masked JPEG bytes, or null if decoding/masking fails.
  static Future<Uint8List?> maskAadhaarInImage(
    Uint8List imageBytes,
    List<Map<String, double>> rects,
  ) async {
    if (rects.isEmpty) return null;
    try {
      return await compute(_maskSync, _MaskPayload(imageBytes, rects));
    } catch (e) {
      debugPrint('[AadhaarImageMasker] maskAadhaarInImage error: $e');
      return null;
    }
  }

  static Uint8List? _maskSync(_MaskPayload payload) {
    final decoded = img.decodeImage(payload.imageBytes);
    if (decoded == null) return null;

    final w = decoded.width;
    final h = decoded.height;
    final black = img.ColorRgb8(0, 0, 0);

    for (final rect in payload.rects) {
      final l = ((rect['left'] ?? 0.0) * w).round().clamp(0, w - 1);
      final t = ((rect['top'] ?? 0.0) * h).round().clamp(0, h - 1);
      final r = ((rect['right'] ?? 1.0) * w).round().clamp(l + 1, w);
      final b = ((rect['bottom'] ?? 1.0) * h).round().clamp(t + 1, h);

      if (r - l <= 0 || b - t <= 0) continue;

      // Pad left/top/bottom for edge noise; zero right padding to avoid
      // bleeding into the next visible digit group.
      final padLeft = ((r - l) * 0.05).round();
      final padY = ((b - t) * 0.08).round();
      final ml = (l - padLeft).clamp(0, w - 1);
      final mt = (t - padY).clamp(0, h - 1);
      final mr = r.clamp(1, w);
      final mb = (b + padY).clamp(1, h);

      img.fillRect(decoded, x1: ml, y1: mt, x2: mr, y2: mb, color: black);
    }

    return Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
  }
}

class _MaskPayload {
  final Uint8List imageBytes;
  final List<Map<String, double>> rects;
  const _MaskPayload(this.imageBytes, this.rects);
}
