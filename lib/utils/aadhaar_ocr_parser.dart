/// Utility class for parsing Aadhaar card **front side** fields from OCR text
/// Optimized for physical PVC card (credit card size)
class AadhaarOCRParser {
  /// Parse Aadhaar front-side fields from OCR text
  /// Returns a map with extracted fields + optional confidence notes
  static Map<String, dynamic> parseAadhaarFields(String rawText) {
    final Map<String, dynamic> data = {
      'confidence': <String, double>{}, // 0.0–1.0 rough confidence
    };

    if (rawText.trim().isEmpty) return data;

    // Normalize text
    final text = rawText
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('  ', ' ')
        .trim();

    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.length > 1)
        .toList();

    // ──────────────────────────────────────────────
    // 1. Aadhaar Number (most important - do first)
    // ──────────────────────────────────────────────
    String? aadhaar = _extractAadhaarNumber(text, lines);
    if (aadhaar != null) {
      data['aadhaar_number'] = aadhaar;
      data['confidence']['aadhaar_number'] = 0.95;
    }

    // Masked variant (very common on newer cards)
    if (aadhaar == null) {
      final masked = _extractMaskedAadhaar(text);
      if (masked != null) {
        data['masked_aadhaar'] = masked;
        data['confidence']['masked_aadhaar'] = 0.90;
      }
    }

    // ──────────────────────────────────────────────
    // 2. Name - usually right after header, before DOB/Gender
    // ──────────────────────────────────────────────
    String? name = _extractName(lines);
    if (name != null && name.trim().isNotEmpty) {
      // Accept name even if single word (might be OCR issue)
      final nameWords = name.trim().split(RegExp(r'\s+'));
      if (nameWords.length >= 1 && nameWords[0].length >= 3) {
        data['name'] = name.trim();
        data['confidence']['name'] = nameWords.length >= 2 ? (name.length > 12 ? 0.85 : 0.70) : 0.60;
      }
    }

    // ──────────────────────────────────────────────
    // 3. DOB / Year of Birth
    // ──────────────────────────────────────────────
    String? dob = _extractDOB(text);
    if (dob != null) {
      data['dob'] = dob;
      data['confidence']['dob'] = 0.90;
    }

    // ──────────────────────────────────────────────
    // 4. Gender
    // ──────────────────────────────────────────────
    String? gender = _extractGender(text, lines);
    if (gender != null) {
      data['gender'] = gender;
      data['confidence']['gender'] = 0.95;
    }

    // Optional: Pincode (sometimes appears near bottom)
    final pin = _extractPincode(text);
    if (pin != null) {
      data['pincode'] = pin;
    }

    // Quick front-side sanity check
    if (data.containsKey('aadhaar_number') || data.containsKey('masked_aadhaar')) {
      data['likely_front_side'] = true;
    }

    // Remove confidence map if empty, otherwise keep it
    if ((data['confidence'] as Map).isEmpty) {
      data.remove('confidence');
    }

    return data;
  }

  static String? _extractAadhaarNumber(String text, List<String> lines) {
    // Pattern 1: Classic 4-4-4 with spaces
    var match = RegExp(r'\b\d{4}\s{1,3}\d{4}\s{1,3}\d{4}\b').firstMatch(text);
    if (match != null) {
      final candidate = match.group(0)!;
      if (!_isLikelyVIDOrFake(candidate, text)) {
        return candidate;
      }
    }

    // Pattern 2: 12 continuous digits
    match = RegExp(r'\b\d{12}\b').firstMatch(text);
    if (match != null) {
      final digits = match.group(0)!;
      if (!_isLikelyVIDOrFake(digits, text)) {
        return '${digits.substring(0,4)} ${digits.substring(4,8)} ${digits.substring(8)}';
      }
    }

    // Last resort: look near bottom of card
    for (var line in lines.reversed.take(8)) {
      final m = RegExp(r'\d{4}.?\d{4}.?\d{4}').firstMatch(line);
      if (m != null) {
        final cand = m.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
        if (cand.length == 12 && !_isLikelyVIDOrFake(cand, text)) {
          return '${cand.substring(0,4)} ${cand.substring(4,8)} ${cand.substring(8)}';
        }
      }
    }

    return null;
  }

  static bool _isLikelyVIDOrFake(String numStr, String context) {
    final lowerContext = context.toLowerCase();
    final numLower = numStr.toLowerCase();
    
    // Find position of number in context
    final numPos = lowerContext.indexOf(numLower.substring(0, numLower.length > 6 ? 6 : numLower.length));
    if (numPos < 0) return false;
    
    // VID usually has "VID :" within ~40 chars before
    final vidPos = lowerContext.indexOf(RegExp(r'vid\s*[:=]?\s*'));
    if (vidPos >= 0 && vidPos < numPos && (numPos - vidPos) < 50) {
      return true;
    }

    // Often appears near "Issue Date", "Enrollment No", mobile numbers
    final issueDatePos = lowerContext.indexOf('issue date');
    if (issueDatePos >= 0 && issueDatePos < numPos && (numPos - issueDatePos) < 30) {
      return true;
    }
    
    if (lowerContext.contains('enroll') && 
        lowerContext.indexOf('enroll') < numPos && 
        (numPos - lowerContext.indexOf('enroll')) < 50) {
      return true;
    }
    
    if (lowerContext.contains(RegExp(r'mob|phone|mobile\s*[:=]?\s*\d{10}'))) {
      return true;
    }

    return false;
  }

  static String? _extractMaskedAadhaar(String text) {
    var match = RegExp(r'\bX{4}\s{1,3}X{4}\s{1,3}\d{4}\b', caseSensitive: false)
        .firstMatch(text);
    if (match != null) return match.group(0);

    match = RegExp(r'\bX{8,10}\d{4}\b', caseSensitive: false).firstMatch(text);
    return match?.group(0);
  }

  static String? _extractDOB(String text) {
    // Most common formats
    final patterns = [
      r'(?:DOB|Date\s+of\s+Birth|Birth|DoB)[:\s-]*(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})',
      r'(?:YOB|Year\s+of\s+Birth)[:\s-]*(\d{4})',
      r'\b(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})\b',
    ];

    for (var pat in patterns) {
      final match = RegExp(pat, caseSensitive: false).firstMatch(text);
      if (match != null) {
        if (match.groupCount == 3) {
          // DD/MM/YYYY
          var d = match.group(1)!.padLeft(2, '0');
          var m = match.group(2)!.padLeft(2, '0');
          var y = match.group(3)!;
          
          // Basic validation
          final dayInt = int.tryParse(d);
          final monthInt = int.tryParse(m);
          if (dayInt == null || monthInt == null || dayInt > 31 || monthInt > 12) {
            continue;
          }
          
          return '$d/$m/$y';
        } else if (match.groupCount == 1) {
          // Only year
          return match.group(1);
        }
      }
    }
    return null;
  }

  static String? _extractGender(String text, List<String> lines) {
    final genderPatterns = [
      r'\b(MALE|FEMALE|M|F)\b',
      r'(?:Gender|Sex)[:\s-]*(MALE|FEMALE|M|F)',
      r'\b(M|F)\s*/\s*(MALE|FEMALE)',
    ];

    for (var pat in genderPatterns) {
      final match = RegExp(pat, caseSensitive: false).firstMatch(text);
      if (match != null) {
        var g = match.group(1)?.toUpperCase() ?? match.group(0)!.toUpperCase();
        if (g == 'M' || g.contains('MALE')) return 'MALE';
        if (g == 'F' || g.contains('FEMALE')) return 'FEMALE';
      }
    }

    // Fallback: standalone in last 10 lines
    for (var line in lines.reversed.take(10)) {
      final clean = line.toUpperCase().trim();
      if (clean == 'MALE' || clean == 'FEMALE') return clean;
      if (clean.contains('MALE') && !clean.contains('SAO') && !clean.contains('3SO')) {
        return 'MALE';
      }
      if (clean.contains('FEMALE')) return 'FEMALE';
    }

    return null;
  }

  static String? _extractName(List<String> lines) {
    final nameCandidates = <String>[];

    // Find the first line with VID, DOB, or Aadhaar number - name is BEFORE this
    int firstDataLine = -1;
    for (int i = 0; i < lines.length; i++) {
      final upper = lines[i].toUpperCase();
      final line = lines[i];
      if (upper.contains('VID') && RegExp(r'\d{4}').hasMatch(line)) {
        firstDataLine = i;
        break;
      }
      if (upper.contains('DOB') && RegExp(r'\d').hasMatch(line)) {
        firstDataLine = i;
        break;
      }
      if (RegExp(r'\d{4}\s*\d{4}\s*\d{4}').hasMatch(line) || RegExp(r'\d{12}').hasMatch(line)) {
        firstDataLine = i;
        break;
      }
    }

    // If no data line found, search all lines
    int searchEnd = firstDataLine > 0 ? firstDataLine : lines.length;

    // Search all lines BEFORE the first data line
    for (int i = 0; i < searchEnd; i++) {
      final line = lines[i];
      final upper = line.toUpperCase();
      final clean = line.trim();

      // Skip if it's clearly a header, label, or data field
      if (upper.contains('GOVERNMENT') || upper.contains('INDIA') || 
          upper.contains('UIDAI') || 
          (upper.contains('VID') && RegExp(r'\d').hasMatch(line)) ||
          (upper.contains('DOB') && RegExp(r'\d').hasMatch(line)) ||
          upper.contains('GENDER') ||
          (upper.contains('ISSUE') && upper.contains('DATE')) ||
          RegExp(r'\d{4}\s*\d{4}\s*\d{4}').hasMatch(line) ||
          RegExp(r'\d{12}').hasMatch(line)) {
        continue;
      }

      // Skip common patterns
      if (clean.contains('SAO/') || clean.contains('3SO/') || clean.contains('AO/') ||
          clean.contains('5AO/') || clean.contains('BJ/') ||
          clean.contains('SAO /') || clean.contains('3SO /') || clean.contains('AO /')) {
        continue;
      }

      // Skip very short or very long lines
      if (clean.length < 3 || clean.length > 40) continue;

      // Skip lines with long number sequences (but allow short numbers like "S5")
      if (RegExp(r'\d{4,}').hasMatch(clean)) continue;

      // Split into words (allow single character words for now)
      final words = clean.split(RegExp(r'[\s\/]+')).where((w) => w.isNotEmpty).toList();
      if (words.isEmpty) continue;

      // Skip if contains common abbreviations as whole words
      bool hasAbbreviation = false;
      for (var word in words) {
        final wordUpper = word.toUpperCase();
        if ((wordUpper == 'VID' || wordUpper == 'UID' || wordUpper == 'DOB' || 
            wordUpper == 'PIN' || wordUpper == 'MALE' || wordUpper == 'FEMALE') && 
            words.length == 1) {
          hasAbbreviation = true;
          break;
        }
      }
      if (hasAbbreviation) continue;

      // Check letter ratio - be lenient
      final letterCount = clean.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
      if (letterCount < 3) continue; // At least 3 letters
      final letterRatio = letterCount / clean.length;
      if (letterRatio < 0.4) continue; // At least 40% letters

      // Filter words to meaningful ones (length > 1)
      final meaningfulWords = words.where((w) => w.length > 1).toList();
      if (meaningfulWords.isEmpty) continue;

      // Check title case - be lenient
      final titleCaseCount = meaningfulWords.where((w) => 
        w.isNotEmpty && w.length > 1 && 
        (w[0] == w[0].toUpperCase() || w == w.toUpperCase())
      ).length;

      // Accept if:
      // 1. At least 30% of meaningful words are title case AND at least 2 words, OR
      // 2. Single word with 4+ letters and 70%+ letters (might be OCR issue splitting name)
      if ((titleCaseCount >= (meaningfulWords.length * 0.3).ceil() && meaningfulWords.length >= 1) ||
          (meaningfulWords.length == 1 && meaningfulWords[0].length >= 4 && letterRatio > 0.7)) {
        nameCandidates.add(clean);
        // Don't break - collect all potential name lines
      }
    }

    if (nameCandidates.isEmpty) {
      // Debug: print first few lines
      print('Name extraction: No candidates found. First ${searchEnd > 5 ? 5 : searchEnd} lines:');
      for (int i = 0; i < searchEnd && i < 5; i++) {
        print('  Line $i: "${lines[i]}"');
      }
      return null;
    }

    var fullName = nameCandidates.join(' ');
    fullName = fullName
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s*/\s*'), ' ')
        .trim();

    // Final cleanup - remove trailing gender/relations and common prefixes
    fullName = fullName.replaceAll(RegExp(r'^\d+\s*[-.]?\s*', caseSensitive: false), ''); // Remove leading "S5 -" type patterns
    fullName = fullName.replaceAll(RegExp(r'\s+(MALE|FEMALE|SON|DAUGHTER|WIFE|OF)$', caseSensitive: false), '').trim();

    print('Name extraction: Found "${fullName}" from ${nameCandidates.length} candidate(s)');
    return fullName.isNotEmpty ? fullName : null;
  }

  static String? _extractPincode(String text) {
    // Try labeled first
    final labeled = RegExp(r'(?:PIN|Pincode|Pin|Code)[\s:-]*(\d{6})', caseSensitive: false).firstMatch(text);
    if (labeled != null) return labeled.group(1);
    
    // Fallback - last 6-digit in whole text
    final allPins = RegExp(r'\b\d{6}\b').allMatches(text).map((m) => m.group(0)!).toList();
    return allPins.isNotEmpty ? allPins.last : null;
  }

  // ──────────────────────────────────────────────
  // Utility methods
  // ──────────────────────────────────────────────
  static bool isValidAadhaarFormat(String? aadhaar) {
    if (aadhaar == null || aadhaar.isEmpty) return false;
    final digits = aadhaar.replaceAll(RegExp(r'\D'), '');
    return digits.length == 12 && RegExp(r'^\d{12}$').hasMatch(digits);
  }

  static String formatAadhaarNumber(String aadhaar) {
    final digits = aadhaar.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 12) return aadhaar;
    return '${digits.substring(0, 4)} ${digits.substring(4, 8)} ${digits.substring(8, 12)}';
  }
}
