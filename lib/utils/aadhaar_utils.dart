/// Aadhaar masking for RBI compliance: never persist full 12 digits.
/// Masked format: xxxx-xxxx-<last4>. Obscured: ••••-••••-<last4> for preview toggle.
class AadhaarUtils {
  AadhaarUtils._();

  static final RegExp _digitsOnly = RegExp(r'[^\d]');

  /// Matches masked form: xxxx-xxxx-1234 or XXXX-XXXX-1234 (case-insensitive x, optional spaces).
  static final RegExp _maskedPattern = RegExp(
    r'^\s*[xX]{4}\s*[- ]?\s*[xX]{4}\s*[- ]?\s*\d{4}\s*$',
    caseSensitive: false,
  );

  /// Returns masked Aadhaar: xxxx-xxxx-<last4>. Never returns full 12 digits.
  /// Input can be 12 digits, with spaces/dashes, or already masked; output is always masked.
  static String maskAadhaar(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final trimmed = raw.trim();
    // Already in masked form: normalize to xxxx-xxxx-1234 and return
    if (isMasked(trimmed)) {
      final digits = trimmed.replaceAll(_digitsOnly, '');
      return 'xxxx-xxxx-$digits';
    }
    final digits = trimmed.replaceAll(_digitsOnly, '');
    if (digits.length >= 4) {
      final last4 = digits.length > 4 ? digits.substring(digits.length - 4) : digits;
      return 'xxxx-xxxx-$last4';
    }
    return 'xxxx-xxxx-xxxx';
  }

  /// Whether [value] is already in masked form (xxxx-xxxx-1234 or XXXX-XXXX-1234).
  static bool isMasked(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    return _maskedPattern.hasMatch(value.trim());
  }

  /// Returns the last 4 digits from [value] (whether full 12-digit or masked xxxx-xxxx-1234).
  /// Use for comparison (e.g. duplicate check) without exposing full number.
  static String getLast4Digits(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    final digits = value.trim().replaceAll(_digitsOnly, '');
    if (digits.length >= 4) {
      return digits.substring(digits.length - 4);
    }
    return digits;
  }

  /// For preview: first 8 digits obscured, last 4 visible (••••-••••-1234).
  static String obscureAadhaar(String? masked) {
    if (masked == null || masked.trim().isEmpty) return '—';
    final last4 = getLast4Digits(masked);
    if (last4.isEmpty) return '••••-••••-••••';
    return '••••-••••-$last4';
  }

  /// Display value for preview: masked (xxxx-xxxx-1234) or obscured based on [visible].
  static String displayAadhaar(String? value, {required bool visible}) {
    if (value == null || value.trim().isEmpty) return '—';
    final masked = isMasked(value) ? value : maskAadhaar(value);
    return visible ? masked : obscureAadhaar(masked);
  }

  /// Clamp each Aadhaar digit-group rect so overlay covers only that group,
  /// never the whole card. Returns null if all rects are invalid/too large.
  /// Accepts either a single Map (legacy) or a List of Maps (new format).
  static List<Map<String, double>>? clampNumberRectsForOverlay(dynamic rects) {
    if (rects == null) return null;
    final List<Map<String, double>> input;
    if (rects is List) {
      input = rects
          .whereType<Map>()
          .map((m) => m.map<String, double>(
              (k, v) => MapEntry(k.toString(), (v is num) ? v.toDouble() : 0.0)))
          .toList();
    } else if (rects is Map) {
      input = [
        rects.map<String, double>(
            (k, v) => MapEntry(k.toString(), (v is num) ? v.toDouble() : 0.0))
      ];
    } else {
      return null;
    }

    final result = <Map<String, double>>[];
    for (final rect in input) {
      final clamped = _clampSingleRect(rect);
      if (clamped != null) result.add(clamped);
    }
    return result.isEmpty ? null : result;
  }

  static Map<String, double>? _clampSingleRect(Map<String, double> rect) {
    if (rect.isEmpty) return null;
    final l = rect['left'] ?? 0.0;
    final t = rect['top'] ?? 0.0;
    final r = rect['right'] ?? 1.0;
    final b = rect['bottom'] ?? 1.0;
    double w = r - l;
    double h = b - t;
    if (w >= 0.95 || h >= 0.95 || w > 0.5 || h > 0.5) return null;
    const maxW = 0.4;
    const maxH = 0.25;
    if (w > maxW || h > maxH) {
      w = w > maxW ? maxW : w;
      h = h > maxH ? maxH : h;
      final cx = (l + r) * 0.5;
      final cy = (t + b) * 0.5;
      return {
        'left': (cx - w * 0.5).clamp(0.0, 1.0),
        'top': (cy - h * 0.5).clamp(0.0, 1.0),
        'right': (cx + w * 0.5).clamp(0.0, 1.0),
        'bottom': (cy + h * 0.5).clamp(0.0, 1.0),
      };
    }
    return rect;
  }
}
