import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// Conditional import - only import dart:io on non-web platforms
import 'dart:io' if (dart.library.html) 'file_helper_stub.dart' as io;

class OcrService {
  /// Extract text from Aadhaar card image
  /// isFront: true for front side (extract DOB and Aadhaar number), false for back side (extract address)
  static Future<AadhaarOcrResult> extractAadhaarText(
    String imagePath, {
    Uint8List? imageBytes,
    bool isFront = true,
  }) async {
    debugPrint('[OcrService] extractAadhaarText ENTER imagePath=$imagePath isFront=$isFront hasBytes=${imageBytes != null}');
    try {
      // Create InputImage from path or bytes
      InputImage inputImage;

      if (imageBytes != null) {
        debugPrint('[OcrService] extractAadhaarText creating temp file from bytes');
        // Use bytes directly (works on all platforms)
        final tempFile = await _createTempFile(imageBytes);
        debugPrint('[OcrService] extractAadhaarText InputImage.fromFilePath(temp) path=${tempFile.path}');
        inputImage = InputImage.fromFilePath(tempFile.path);
      } else {
        if (kIsWeb) {
          return AadhaarOcrResult(
            success: false,
            errorMessage: 'Web platform requires image bytes',
          );
        }
        debugPrint('[OcrService] extractAadhaarText InputImage.fromFilePath(imagePath)');
        inputImage = InputImage.fromFilePath(imagePath);
      }

      debugPrint('[OcrService] extractAadhaarText creating TextRecognizer');
      // Initialize text recognizer
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      debugPrint('[OcrService] extractAadhaarText calling processImage');
      // Process image
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      debugPrint('[OcrService] extractAadhaarText processImage returned');

      // Close recognizer
      textRecognizer.close();

      String? aadhaarNumber;
      String? dateOfBirth;
      String? address;
      String? name;
      bool internalDocumentValid = true;
      
      final fullText = recognizedText.text;
      final fullTextUpper = fullText.toUpperCase();
      
      debugPrint('=== OCR Full Text ===');
      debugPrint(fullText);
      debugPrint('=== End OCR Text ===');

      // Extract Aadhaar number - MUST be in format XXXX XXXX XXXX (with spaces)
      // Aadhaar numbers: 12 digits, start with 2-9
      // VID numbers: 16 digits - must exclude
      // Also exclude: dates (DD/MM/YYYY), enrollment numbers, phone numbers
      
      // IMPORTANT: OCR often splits numbers across lines. We must NOT allow matching across newlines,
      // otherwise we can accidentally mix VID tail + Aadhaar head into a fake 12-digit number.
      final lines = fullText
          .split(RegExp(r'[\r\n]+'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      // Step 1: Find VID (16 digits with spaces: XXXX XXXX XXXX XXXX) within a single line.
      final vidLineRegex = RegExp(r'(\d{4})[ ]+(\d{4})[ ]+(\d{4})[ ]+(\d{4})');
      String? vidNumber;
      for (final line in lines) {
        if (!line.toUpperCase().contains('VID')) continue;
        final m = vidLineRegex.firstMatch(line);
        if (m != null) {
          vidNumber = '${m.group(1)}${m.group(2)}${m.group(3)}${m.group(4)}';
          debugPrint('VID found (line): $vidNumber');
          break;
        }
      }

      // Step 2: Find Aadhaar number within a single line: XXXX XXXX XXXX
      // Use [ ]+ (spaces) instead of \s+ so we don't match across lines.
      final aadhaarLineRegex = RegExp(r'\b([2-9]\d{3})[ ]+(\d{4})[ ]+(\d{4})\b');

      // Scan lines first (most reliable for the Aadhaar-number line).
      for (final line in lines) {
        final m = aadhaarLineRegex.firstMatch(line);
        if (m == null) continue;
        final part1 = m.group(1) ?? '';
        final part2 = m.group(2) ?? '';
        final part3 = m.group(3) ?? '';
        final extracted = '$part1$part2$part3';

        debugPrint('Checking Aadhaar candidate (line): $extracted');

        // Skip if same line mentions VID.
        if (line.toUpperCase().contains('VID')) continue;

        // Skip if this is part of VID digits we detected.
        if (vidNumber != null && vidNumber.contains(extracted)) {
          debugPrint('Skipping - part of VID');
          continue;
        }

        // Skip if this looks like a year in the last group (rare false-positive).
        final part3Int = int.tryParse(part3) ?? 0;
        if (part3Int >= 1950 && part3Int <= 2030) {
          debugPrint('Skipping - looks like a date (year: $part3Int)');
          continue;
        }

        if (_isUidaiHelplineNumber(extracted)) {
          debugPrint('Skipping - UIDAI helpline number: $extracted');
          continue;
        }

        aadhaarNumber = extracted;
        debugPrint('Found Aadhaar number (line): $aadhaarNumber');
        break;
      }

      // If still not found, try block-by-block as a secondary source.
      if (aadhaarNumber == null) {
        for (final block in recognizedText.blocks) {
          final blockLine = block.text.replaceAll('\n', ' ').trim();
          final m = aadhaarLineRegex.firstMatch(blockLine);
          if (m == null) continue;
          final extracted = '${m.group(1) ?? ''}${m.group(2) ?? ''}${m.group(3) ?? ''}';
          debugPrint('Checking Aadhaar candidate (block): $extracted');
          if (_isUidaiHelplineNumber(extracted)) continue;
          aadhaarNumber = extracted;
          debugPrint('Found Aadhaar number (block): $aadhaarNumber');
          break;
        }
      }
      
      // Step 3: Fallback - look for 12 digits starting with 2-9, but be careful
      if (aadhaarNumber == null) {
        debugPrint('Primary pattern not found, trying fallback...');
        
        // Look for any 12-digit sequence starting with 2-9
        final fallbackRegex = RegExp(r'[2-9]\d{11}');
        final textNoSpaces = fullText.replaceAll(RegExp(r'\s+'), '');
        
        final fallbackMatches = fallbackRegex.allMatches(textNoSpaces).toList();
        for (final match in fallbackMatches) {
          final extracted = match.group(0) ?? '';
          
          // Skip if part of VID
          if (vidNumber != null && vidNumber.contains(extracted)) {
            continue;
          }
          
          // Skip if it contains date-like patterns
          // Enrollment numbers often have dates embedded
          if (extracted.contains(RegExp(r'(19|20)\d{2}(0[1-9]|1[0-2])'))) {
            debugPrint('Skipping fallback - contains date pattern: $extracted');
            continue;
          }
          
          // Skip UIDAI helpline (1947 / 1800 180 1947)
          if (_isUidaiHelplineNumber(extracted)) {
            debugPrint('Skipping fallback - UIDAI helpline number: $extracted');
            continue;
          }
          
          aadhaarNumber = extracted;
          debugPrint('Found Aadhaar number (fallback): $aadhaarNumber');
          break;
        }
      }

      if (isFront) {
        // SECRET validation for front side: Check for "GOVERNMENT OF INDIA" text (case-insensitive)
        // This is for internal use only - we don't show this error to users
        // OCR may split this across lines (e.g., "GOVERNMENT OF" + "INDIA"), so don't require exact phrase.
        final hasGovernmentOfIndia =
            fullTextUpper.contains('GOVERNMENT OF INDIA') ||
            fullTextUpper.contains('GOVT OF INDIA') ||
            fullTextUpper.contains('GOVT. OF INDIA') ||
            (fullTextUpper.contains('GOVERNMENT') && fullTextUpper.contains('INDIA'));
        
        if (!hasGovernmentOfIndia) {
          debugPrint('Aadhaar internal validation: "GOVERNMENT OF INDIA" text not found');
          internalDocumentValid = false;
          // Don't return error to user - just flag internally
        }
        
        // Front side: Extract DOB - Look specifically for date after "DOB" or "Date of Birth" label
        // This prevents picking up enrollment dates or other dates
        
        // Pattern 1: DOB: DD/MM/YYYY or DOB : DD/MM/YYYY
        final dobLabelRegex = RegExp(r'(?:DOB|Date\s*of\s*Birth|D\.O\.B|Birth)\s*[:\-]?\s*(\d{2}[/\-\.]\d{2}[/\-\.]\d{4})', caseSensitive: false);
        final dobLabelMatch = dobLabelRegex.firstMatch(fullText);
        
        if (dobLabelMatch != null) {
          dateOfBirth = dobLabelMatch.group(1)?.replaceAll(RegExp(r'[\-\.]'), '/');
          debugPrint('Found DOB with label: $dateOfBirth');
        } else {
          // Fallback: Look for date in DD/MM/YYYY format, but validate it's a reasonable DOB
          final dobRegex = RegExp(r'\b(\d{2})[/\-\.](\d{2})[/\-\.](\d{4})\b');
          
          for (final textBlock in recognizedText.blocks) {
            final blockTextUpper = textBlock.text.toUpperCase();
            // Skip blocks that contain "VID", "ENROLMENT", "ENROLLMENT", "GENERATED"
            if (blockTextUpper.contains('VID') || 
                blockTextUpper.contains('ENROL') || 
                blockTextUpper.contains('GENERATED') ||
                blockTextUpper.contains('VALID')) {
              continue;
            }
            
            final match = dobRegex.firstMatch(textBlock.text);
            if (match != null) {
              final day = int.tryParse(match.group(1) ?? '') ?? 0;
              final month = int.tryParse(match.group(2) ?? '') ?? 0;
              final year = int.tryParse(match.group(3) ?? '') ?? 0;
              
              // Validate: reasonable DOB (year between 1920-2020, valid day/month)
              if (year >= 1920 && year <= 2020 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
                dateOfBirth = '${match.group(1)}/${match.group(2)}/${match.group(3)}';
                debugPrint('Found DOB (fallback): $dateOfBirth');
                break;
              }
            }
          }
        }
        
        // Front side: Extract Name.
        // Current logic was too strict (required ALL CAPS); many cards produce Title Case in OCR.
        final bannedUpper = <String>[
          'GOVERNMENT',
          'GOVT',
          'INDIA',
          'AADHAAR',
          'UNIQUE',
          'IDENTIFICATION',
          'AUTHORITY',
          'UIDAI',
          'DOB',
          'DATE OF BIRTH',
          'MALE',
          'FEMALE',
          'ENROL',
          'ENROLL',
          'VID',
          'VIRTUAL',
          'ISSUE',
          'DATE',
        ];

        bool looksLikePersonName(String s) {
          final t = s.trim();
          if (t.length < 4 || t.length > 40) return false;
          if (t.contains(RegExp(r'\d'))) return false;
          // Allow letters, spaces, dots (initials).
          if (!RegExp(r'^[A-Za-z.\s]+$').hasMatch(t)) return false;
          final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
          if (words.length < 2 || words.length > 5) return false;
          final upper = t.toUpperCase();
          for (final b in bannedUpper) {
            if (upper.contains(b)) return false;
          }
          return true;
        }

        int scoreNameCandidate(String s) {
          final t = s.trim();
          final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
          int score = 0;
          // Prefer 3-4 words, common for full names.
          if (words.length == 3) score += 4;
          if (words.length == 4) score += 3;
          if (words.length == 2) score += 2;
          // Prefer Title Case / all caps (both can happen).
          final isAllCaps = t == t.toUpperCase();
          if (isAllCaps) score += 2;
          final titleCaseWords = words.where((w) => w.isNotEmpty && RegExp(r'^[A-Z]').hasMatch(w)).length;
          if (titleCaseWords >= 2) score += 2;
          // Penalize too many dots/initials.
          score -= '.'.allMatches(t).length;
          return score;
        }

        // 1) Try per-line candidates from the full OCR text (most reliable for single-line names).
        final lines = recognizedText.text
            .split(RegExp(r'[\r\n]+'))
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        String? best;
        int bestScore = -999;
        for (final line in lines) {
          if (!looksLikePersonName(line)) continue;
          final s = scoreNameCandidate(line);
          if (s > bestScore) {
            bestScore = s;
            best = line;
          }
        }

        // 2) Fallback to block-based candidates.
        if (best == null) {
          for (final block in recognizedText.blocks) {
            final text = block.text.trim();
            if (!looksLikePersonName(text)) continue;
            final s = scoreNameCandidate(text);
            if (s > bestScore) {
              bestScore = s;
              best = text;
            }
          }
        }

        name = best;

        debugPrint('OCR Results (Aadhaar Front) - Aadhaar: $aadhaarNumber, DOB: $dateOfBirth, Name: $name, InternalValid: $internalDocumentValid');
      } else {
        // Back side: Extract address (3-4 lines from C/O marker to pincode)
        
        final rawText = recognizedText.text;
        debugPrint('=== Back Side Raw Text ===');
        debugPrint(rawText);
        debugPrint('=== End Back Side Text ===');
        
        // Step 1: Find address start marker (C/O, S/O, D/O, W/O)
        // Handle OCR variations: C/O, C/0, C/ O, c/o, S/O, etc.
        final markerRegex = RegExp(
          r'([CcSsDdWw])\s*[/\\]\s*[Oo0]\s*[:\-]?\s*',
        );
        
        // Step 2: Find pincode (6 digits)
        final pincodeRegex = RegExp(r'(\d{6})');
        
        // Extra debug: print OCR lines with indices (helps understand why address truncates).
        final debugLines = rawText
            .split(RegExp(r'[\r\n]+'))
            .map((l) => l.trimRight())
            .toList();
        debugPrint('=== Back Side Lines (indexed) ===');
        for (int i = 0; i < debugLines.length; i++) {
          final l = debugLines[i].trim();
          if (l.isEmpty) continue;
          debugPrint('[$i] $l');
        }
        debugPrint('=== End Back Side Lines ===');

        // Find marker position (character offset, for substring fallback)
        final markerMatch = markerRegex.firstMatch(rawText);
        int addressStart = 0;
        
        if (markerMatch != null) {
          addressStart = markerMatch.end;
          debugPrint('Found marker "${markerMatch.group(0)}" - address starts at position $addressStart');
          final startPreview = (addressStart - 30).clamp(0, rawText.length);
          final endPreview = (addressStart + 60).clamp(0, rawText.length);
          debugPrint('Marker context: "${rawText.substring(startPreview, endPreview).replaceAll('\n', '\\n')}"');
        } else {
          debugPrint('No C/O marker found, will look for address differently');
        }
        
        // Find ALL pincodes in text
        final allPincodes = pincodeRegex.allMatches(rawText).toList();
        debugPrint('Found ${allPincodes.length} potential pincodes');
        for (final pm in allPincodes) {
          debugPrint('Pincode candidate: ${pm.group(1)} at ${pm.start}-${pm.end}');
        }
        
        String? pinCode;
        int? addressEnd;
        
        if (allPincodes.isNotEmpty) {
          // If we have a marker, prefer the LAST pincode AFTER the marker
          // (address often contains other 6-digit sequences; pincode is usually the last one).
          if (addressStart > 0) {
            RegExpMatch? chosen;
            for (final pm in allPincodes) {
              if (pm.start >= addressStart) {
                chosen = pm; // keep last
              }
            }
            if (chosen != null) {
              pinCode = chosen.group(1);
              addressEnd = chosen.end;
              debugPrint('Using last pincode $pinCode after marker (position ${chosen.start}-${chosen.end})');
            }
          }
          
          // If no pincode after marker, or no marker found, use last pincode
          if (addressEnd == null) {
            final lastPincode = allPincodes.last;
            pinCode = lastPincode.group(1);
            addressEnd = lastPincode.end;
            debugPrint('Using last pincode $pinCode (position ${lastPincode.start}-${lastPincode.end})');
            
            // If no marker, try to find start point before pincode
            if (addressStart == 0) {
              // Look for marker before this pincode
              final textBeforePincode = rawText.substring(0, lastPincode.start);
              final markerInText = markerRegex.firstMatch(textBeforePincode);
              if (markerInText != null) {
                addressStart = markerInText.end;
                debugPrint('Found marker before pincode at position $addressStart');
              }
            }
          }
        }
        
        String? cleanAddressFromLines() {
          // Prefer line-based extraction: marker-line -> pincode-line
          final lines2 = rawText
              .split(RegExp(r'[\r\n]+'))
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList();
          if (lines2.isEmpty) return null;

          bool isNoiseLine(String line) {
            final u = line.toUpperCase();
            if (u.contains('GOVERNMENT') ||
                u.contains('INDIA') ||
                u.contains('UIDAI') ||
                u.contains('AADHAAR') ||
                u.contains('UNIQUE IDENTIFICATION') ||
                u.contains('HELPLINE') ||
                u.contains('VID') ||
                u.contains('BORDER') ||
                u.contains('HTTP') ||
                u.contains('WWW.')) {
              return true;
            }
            // Skip pure digits or short fragments
            if (RegExp(r'^\d+$').hasMatch(line.trim())) return true;
            // Very short OCR garbage like "soS", "Se", etc.
            final trimmed = line.trim();
            final alphaOnly = trimmed.replaceAll(RegExp(r'[^A-Za-z]'), '');
            if (trimmed.length <= 3 && alphaOnly.length == trimmed.length) {
              return true;
            }
            // Common Aadhaar back-side label fragments that OCR breaks into tiny tokens.
            final upperAlpha = alphaOnly.toUpperCase();
            if (upperAlpha == 'SOS' || upperAlpha == 'SO' || upperAlpha == 'SS') {
              return true;
            }
            return false;
          }

          String normalizeAddressLine(String line) {
            var t = line.trim();
            // Common OCR variants: C/0, C\0, C/O
            t = t.replaceAll(RegExp(r'\b([Cc])\s*[/\\]\s*[Oo0]\b'), 'C/O');
            // Normalize relation markers when OCR partially reads them.
            // (We still drop standalone garbage like "soS" in isNoiseLine above.)
            t = t.replaceAll(
              RegExp(r'\bS\s*[/\\]\s*[Oo0]\b', caseSensitive: false),
              'S/O',
            );
            t = t.replaceAll(
              RegExp(r'\bD\s*[/\\]\s*[Oo0]\b', caseSensitive: false),
              'D/O',
            );
            t = t.replaceAll(
              RegExp(r'\bW\s*[/\\]\s*[Oo0]\b', caseSensitive: false),
              'W/O',
            );
            // Address label noise
            t = t.replaceAll(
              RegExp(r'^\s*ADDRESS\s*[:\-]?\s*$', caseSensitive: false),
              '',
            );
            return t.trim();
          }

          bool looksLikeAddressLine(String line) {
            final t = line.trim();
            if (t.isEmpty) return false;
            if (isNoiseLine(t)) return false;
            // Heuristics: address lines often contain comma or words like ROAD/RESIDENCY.
            final u = t.toUpperCase();
            if (t.contains(',')) return true;
            if (u.contains('ROAD') ||
                u.contains('RD') ||
                u.contains('RESIDENCY') ||
                u.contains('BLOCK') ||
                u.contains('NAGAR') ||
                u.contains('COLONY') ||
                u.contains('STREET') ||
                u.contains('TOWN') ||
                u.contains('DIST') ||
                u.contains('MANDAL') ||
                u.contains('VILL') ||
                u.contains('CITY')) {
              return true;
            }
            // Line with pincode is usually part of address.
            if (pincodeRegex.hasMatch(t)) return true;
            return false;
          }

          // Find marker line (C/O, S/O, D/O, W/O). If present, include a few lines above it too.
          int? markerIdx;
          for (int i = 0; i < lines2.length; i++) {
            if (markerRegex.hasMatch(lines2[i])) {
              markerIdx = i;
              break;
            }
          }

          int startIdx;
          if (markerIdx != null) {
            // Include meaningful lines above marker:
            // - locality/road lines often appear above C/O
            // - sometimes the "State - PINCODE" line is above those (and must be included)
            startIdx = markerIdx;

            // 1) If there's a pincode line above the marker, include the closest one.
            for (int j = markerIdx - 1; j >= 0; j--) {
              if (isNoiseLine(lines2[j])) continue;
              if (pincodeRegex.hasMatch(lines2[j])) {
                startIdx = j;
                break;
              }
            }

            // 2) Also include up to 5 other good address lines above (locality/road).
            int included = 0;
            for (int j = markerIdx - 1; j >= 0 && included < 5; j--) {
              if (!looksLikeAddressLine(lines2[j])) continue;
              startIdx = j;
              included++;
            }
          } else {
            // No marker: start from first likely address line.
            startIdx = 0;
            for (int i = 0; i < lines2.length; i++) {
              if (looksLikeAddressLine(lines2[i])) {
                startIdx = i;
                break;
              }
            }
          }

          int? endIdx;
          for (int i = startIdx; i < lines2.length; i++) {
            if (pincodeRegex.hasMatch(lines2[i])) {
              endIdx = i; // keep last pincode line after start
            }
          }
          if (endIdx == null) return null;

          // Build address lines.
          // Desired order:
          //   C/O..., <locality/road/city...>, <State - PINCODE> (at the end).
          final markerAndAfter = <String>[];
          final beforeMarker = <String>[];

          for (int i = startIdx; i <= endIdx; i++) {
            final l0 = normalizeAddressLine(lines2[i]);
            if (l0.isEmpty) continue;
            if (isNoiseLine(l0)) continue;

            if (markerIdx != null && i < markerIdx) {
              beforeMarker.add(l0);
            } else {
              markerAndAfter.add(l0);
            }
          }

          final addrLines = <String>[];
          // De-dupe while preserving intended order.
          final seen = <String>{};

          void addUnique(String line) {
            final key = line.toUpperCase();
            if (seen.contains(key)) return;
            seen.add(key);
            addrLines.add(line);
          }

          if (markerIdx != null && markerAndAfter.isNotEmpty) {
            // 1) Start with the marker line itself (C/O...), if present.
            final markerLine = markerAndAfter.firstWhere(
              (l) => markerRegex.hasMatch(l),
              orElse: () => '',
            );
            if (markerLine.isNotEmpty) addUnique(markerLine);

            // 2) Add locality/road lines above marker (closest first).
            for (int i = beforeMarker.length - 1; i >= 0; i--) {
              // Skip state/pincode for now; we want it at the end.
              final u = beforeMarker[i].toUpperCase();
              if (pincodeRegex.hasMatch(beforeMarker[i]) &&
                  u.contains(RegExp(r'[A-Z]'))) {
                continue;
              }
              addUnique(beforeMarker[i]);
            }

            // 3) Add lines after marker (city etc), excluding pincode lines for now.
            for (final l in markerAndAfter) {
              if (l == markerLine) continue;
              if (pincodeRegex.hasMatch(l)) continue;
              addUnique(l);
            }

            // 4) Add the best "State - PINCODE" line at the end if we have it.
            String? statePincodeLine;
            for (final l in [...beforeMarker, ...markerAndAfter]) {
              if (!pincodeRegex.hasMatch(l)) continue;
              final u = l.toUpperCase();
              // Prefer lines with letters (e.g., "Andhra Pradesh - 517503") over numeric-only.
              if (u.contains(RegExp(r'[A-Z]'))) {
                statePincodeLine = l;
              }
            }
            if (statePincodeLine != null && statePincodeLine.isNotEmpty) {
              addUnique(statePincodeLine);
            } else {
              // Fallback: add last pincode line.
              String? lastPincodeLine;
              for (final l in [...beforeMarker, ...markerAndAfter]) {
                if (pincodeRegex.hasMatch(l)) lastPincodeLine = l;
              }
              if (lastPincodeLine != null) addUnique(lastPincodeLine);
            }
          } else {
            // No marker: keep natural order.
            for (final l in [...beforeMarker, ...markerAndAfter]) {
              addUnique(l);
            }
          }

          if (addrLines.isEmpty) return null;

          debugPrint('Address lines chosen (idx $startIdx..$endIdx): ${addrLines.join(' | ')}');

          var joined = addrLines.join(', ')
              .replaceAll(RegExp(r',\s*,'), ', ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .replaceAll(RegExp(r'^[\s,:\-]+'), '')
              .trim();

          // Remove stray "Address:" tokens inside
          joined = joined.replaceAll(RegExp(r'\bADDRESS\s*[:\-]?\b', caseSensitive: false), '').replaceAll(RegExp(r'\s+'), ' ').trim();

          // Ensure we end at the chosen pincode if we know it.
          if (pinCode != null && joined.contains(pinCode)) {
            final pos = joined.lastIndexOf(pinCode);
            joined = joined.substring(0, pos + pinCode.length).trim();
          }

          return joined;
        }

        // Step 3: Extract address
        // Prefer line-based extraction; keep substring-based as fallback.
        final fromLines = cleanAddressFromLines();
        if (fromLines != null && fromLines.isNotEmpty) {
          address = fromLines;
          debugPrint('Final address (line-based): $address');
        } else if (addressEnd != null && addressStart < addressEnd) {
          // Fallback: get all text from marker to pincode using character offsets.
          String rawAddress = rawText.substring(addressStart, addressEnd);
          debugPrint('Raw address (${rawAddress.length} chars): $rawAddress');
          
          address = rawAddress
              .replaceAll(RegExp(r'[\r\n]+'), ', ')
              .replaceAll(RegExp(r'[ \t]+'), ' ')
              .replaceAll(RegExp(r',\s*,'), ', ')
              .replaceAll(RegExp(r'\bADDRESS\s*[:\-]?\b', caseSensitive: false), '')
              .replaceAll(RegExp(r'^[\s,:\-]+'), '')
              .trim();

          if (pinCode != null && address.contains(pinCode)) {
            final pincodePos = address.lastIndexOf(pinCode);
            address = address.substring(0, pincodePos + pinCode.length).trim();
          }
          
          debugPrint('Final address (substring fallback): $address');
        } else if (addressEnd != null) {
          // We have pincode but marker is after pincode - just take text ending at pincode
          // This handles case where text is not in expected order
          String rawAddress = rawText.substring(0, addressEnd);
          
          // Try to find a reasonable start (skip header lines)
          final lines = rawAddress.split(RegExp(r'[\r\n]+'));
          final addressLines = <String>[];
          bool startCapturing = false;
          
          for (final line in lines) {
            final lineUpper = line.toUpperCase();
            // Skip header lines
            if (lineUpper.contains('GOVERNMENT') || 
                lineUpper.contains('INDIA') ||
                lineUpper.contains('UIDAI') ||
                lineUpper.contains('AADHAAR') ||
                lineUpper.contains('UNIQUE IDENTIFICATION')) {
              continue;
            }
            // Start capturing after C/O line or any substantial text
            if (markerRegex.hasMatch(line) || line.trim().length > 5) {
              startCapturing = true;
            }
            if (startCapturing && line.trim().isNotEmpty) {
              addressLines.add(line.trim());
            }
          }
          
          address = addressLines.join(', ')
              .replaceAll(RegExp(r',\s*,'), ', ')
              .replaceAll(RegExp(r'\bADDRESS\s*[:\-]?\b', caseSensitive: false), '')
              .replaceAll(RegExp(r'^[\s,:\-]+'), '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          
          debugPrint('Reconstructed address: $address');
        } else {
          debugPrint('Could not extract address - no pincode found');
        }

        debugPrint('OCR Results (Aadhaar Back) - Address: $address, Aadhaar: $aadhaarNumber');
      }

      return AadhaarOcrResult(
        success: true,
        aadhaarNumber: aadhaarNumber,
        dateOfBirth: dateOfBirth,
        address: address,
        name: name,
        fullText: recognizedText.text,
        internalDocumentValid: internalDocumentValid,
      );
    } catch (e, st) {
      debugPrint('[OcrService] extractAadhaarText CAUGHT: $e');
      debugPrint('[OcrService] extractAadhaarText STACK: $st');
      return AadhaarOcrResult(
        success: false,
        errorMessage: 'Failed to extract text: ${e.toString()}',
        internalDocumentValid: false,
      );
    }
  }

  /// Extract text from PAN card image
  static Future<PanOcrResult> extractPanText(
    String imagePath, {
    Uint8List? imageBytes,
  }) async {
    try {
      // Create InputImage from path or bytes
      InputImage inputImage;
      
      if (imageBytes != null) {
        final tempFile = await _createTempFile(imageBytes);
        inputImage = InputImage.fromFilePath(tempFile.path);
      } else {
        if (kIsWeb) {
          return PanOcrResult(
            success: false,
            errorMessage: 'Web platform requires image bytes',
          );
        }
        inputImage = InputImage.fromFilePath(imagePath);
      }

      // Initialize text recognizer
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      // Process image
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      // Close recognizer
      textRecognizer.close();

      debugPrint('=== PAN OCR Full Text ===');
      debugPrint(recognizedText.text);
      debugPrint('=== End PAN OCR Text ===');

      // SECRET validation: Check for "INCOME TAX DEPARTMENT" text (case-insensitive)
      // This is for internal use only - we don't show this error to users
      final fullText = recognizedText.text.toUpperCase();
      final hasIncomeTaxDepartment = fullText.contains('INCOME TAX DEPARTMENT') || 
                                     fullText.contains('INCOME TAX DEPT') ||
                                     fullText.contains('INCOME TAX DEPT.');
      
      bool internalDocumentValid = true;
      if (!hasIncomeTaxDepartment) {
        debugPrint('PAN internal validation: "INCOME TAX DEPARTMENT" text not found');
        internalDocumentValid = false;
        // Don't return error to user - just flag internally
      }

      // Extract PAN number (format: ABCDE1234F)
      String? panNumber;
      final panRegex = RegExp(r'\b[A-Z]{5}\d{4}[A-Z]\b');
      
      for (final textBlock in recognizedText.blocks) {
        final match = panRegex.firstMatch(textBlock.text.replaceAll(' ', '').toUpperCase());
        if (match != null) {
          panNumber = match.group(0);
          break;
        }
      }

      // Extract Name + Father's/Parent name from OCR lines (label-based, more reliable than "first uppercase block")
      final parsed = _extractPanPersonDetails(recognizedText.text);
      final String? name = parsed.name;
      final String? fatherName = parsed.fatherName;

      debugPrint('OCR Results - PAN: $panNumber, Name: $name, Father: $fatherName, InternalValid: $internalDocumentValid');

      return PanOcrResult(
        success: true,
        panNumber: panNumber,
        name: name,
        fatherName: fatherName,
        fullText: recognizedText.text,
        internalDocumentValid: internalDocumentValid,
      );
    } catch (e) {
      debugPrint('PAN OCR Error: $e');
      return PanOcrResult(
        success: false,
        errorMessage: 'Failed to extract text: ${e.toString()}',
        internalDocumentValid: false,
      );
    }
  }

  /// Create temporary file from bytes for ML Kit processing
  static Future<io.File> _createTempFile(Uint8List bytes) async {
    if (kIsWeb) {
      throw UnsupportedError('File creation not supported on web');
    }
    
    final tempDir = await io.Directory.systemTemp.createTemp('ocr_temp_');
    final tempFile = io.File('${tempDir.path}/temp_image.jpg');
    await tempFile.writeAsBytes(bytes);
    return tempFile;
  }

  /// True if the digit string looks like UIDAI helpline (1947 / 1800-180-1947), not Aadhaar.
  static bool _isUidaiHelplineNumber(String digits) {
    if (digits.length < 4) return false;
    // Aadhaar never starts with 0 or 1
    if (digits.startsWith('1800') || digits.startsWith('1947')) return true;
    // UIDAI toll-free 1800 180 1947 (digits: 18001801947)
    if (digits.contains('18001801947')) return true;
    // Variant 1947 1800 180 (digits: 19471800180)
    if (digits.contains('19471800180')) return true;
    // "1947 1800 180 1947" as digits = 194718001801947; any 12-digit slice is helpline, not Aadhaar
    const helplineDigits = '194718001801947';
    if (digits.length >= 12 && helplineDigits.contains(digits)) return true;
    return false;
  }

  /// Validate Aadhaar format
  static bool isValidAadhaarFormat(String aadhaar) {
    final cleaned = aadhaar.replaceAll(' ', '').replaceAll('-', '');
    return RegExp(r'^\d{12}$').hasMatch(cleaned);
  }

  /// Validate PAN format
  static bool isValidPanFormat(String pan) {
    final cleaned = pan.replaceAll(' ', '').toUpperCase();
    return RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(cleaned);
  }

  /// Extract PAN card "Name" and "Father's/Parent name" from OCR text.
  ///
  /// PAN cards typically have the following labels:
  /// - NAME
  /// - FATHER'S NAME / FATHERS NAME / FATHER NAME
  ///
  /// OCR often returns these as separate lines; sometimes as "LABEL: VALUE".
  static _PanPersonDetails _extractPanPersonDetails(String rawText) {
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final upperLines = lines.map((l) => l.toUpperCase()).toList();

    String? name;
    String? fatherName;

    final panRegex = RegExp(r'\b[A-Z]{5}\d{4}[A-Z]\b');

    // 1) Try "LABEL: VALUE" patterns (most reliable)
    for (int i = 0; i < upperLines.length; i++) {
      final nameInline = RegExp(
        // Covers: "NAME: X", "H/ Name: X", and OCR with garbage before label.
        r'^\s*.*(?:\bH\s*/\s*)?\bNAME\b\s*[:\-]?\s*(.+)\s*$',
        caseSensitive: false,
      ).firstMatch(lines[i]);
      if (name == null && nameInline != null) {
        final candidate = nameInline.group(1) ?? '';
        final cleaned = _cleanPanNameCandidate(candidate);
        if (_looksLikePanPersonName(cleaned)) name = cleaned;
      }

      final fatherInline = RegExp(
        // Covers: "FATHER'S NAME: X" and OCR with garbage before label.
        r"^\s*.*\bFATHER\b.*\bNAME\b\s*[:\-]?\s*(.+)\s*$",
        caseSensitive: false,
      ).firstMatch(lines[i]);
      if (fatherName == null && fatherInline != null) {
        final candidate = fatherInline.group(1) ?? '';
        final cleaned = _cleanPanNameCandidate(candidate);
        if (_looksLikePanPersonName(cleaned)) fatherName = cleaned;
      }
    }

    // 2) Try label-on-one-line, value-on-next-line patterns
    if (name == null) {
      name = _extractValueAfterLabel(
        lines,
        upperLines,
        // Match label variants like "H/ Name" and avoid the father's label.
        labelRegex: RegExp(
          r'^(?!.*\bFATHER\b).*\b(?:H\s*/\s*)?NAME\b',
          caseSensitive: false,
        ),
      );
    }

    if (fatherName == null) {
      fatherName = _extractValueAfterLabel(
        lines,
        upperLines,
        labelRegex: RegExp(
          r"\bFATHER\b.*\bNAME\b",
          caseSensitive: false,
        ),
      );
    }

    // 3) Fallback (most common PAN layout):
    // Lines are typically:
    //   INCOME TAX DEPARTMENT
    //   GOVT OF INDIA
    //   <NAME>
    //   <FATHER NAME>
    //   <DOB>
    //   <PAN>
    //
    // OCR often misses the NAME/FATHER labels, so infer by position near DOB/PAN.
    if (name == null || fatherName == null) {
      final dobRegex = RegExp(r'\b(\d{2})[/\-\.](\d{2})[/\-\.](\d{4})\b');

      bool looksLikeCandidateLine(String line) {
        final upper = line.toUpperCase();
        final compactRaw = upper.replaceAll(' ', '');
        // Never allow PAN-number lines to become names (e.g. "LTOPK9856Q" -> "LTOPK Q").
        if (panRegex.hasMatch(compactRaw)) return false;
        // Also avoid date-like / ID-like lines that contain many digits.
        final digitCount = upper.replaceAll(RegExp(r'[^0-9]'), '').length;
        if (digitCount >= 4) return false;
        final cleaned = _cleanPanNameCandidate(line);
        return _looksLikePanPersonName(cleaned);
      }

      int? panIdx;
      int? dobIdx;
      for (int i = 0; i < upperLines.length; i++) {
        final compact = upperLines[i].replaceAll(' ', '');
        if (panIdx == null && panRegex.hasMatch(compact)) panIdx = i;
        if (dobIdx == null && dobRegex.hasMatch(upperLines[i])) dobIdx = i;
      }

      int anchor = panIdx ?? dobIdx ?? (upperLines.length - 1);
      // Walk backwards from anchor and pick the last two "name-looking" lines.
      final found = <String>[];
      for (int i = anchor - 1; i >= 0 && found.length < 2; i--) {
        final line = lines[i].trim();
        if (!looksLikeCandidateLine(line)) continue;
        found.add(_cleanPanNameCandidate(line));
      }

      if (found.isNotEmpty) {
        // Closest line above PAN/DOB is usually Father name, then Name above it.
        if (fatherName == null && found.length >= 1) fatherName = found[0];
        if (name == null && found.length >= 2) name = found[1];
      }

      // Last fallback: if still missing, take first two candidate lines in the entire doc.
      if (name == null || fatherName == null) {
        final allCandidates = <String>[];
        for (final line in lines) {
          final upper = line.toUpperCase();
          final compactRaw = upper.replaceAll(' ', '');
          if (panRegex.hasMatch(compactRaw)) continue;
          final digitCount = upper.replaceAll(RegExp(r'[^0-9]'), '').length;
          if (digitCount >= 4) continue;
          if (!looksLikeCandidateLine(line)) continue;
          allCandidates.add(_cleanPanNameCandidate(line));
        }
        if (name == null && allCandidates.isNotEmpty) {
          name = allCandidates.first;
        }
        if (fatherName == null && allCandidates.length >= 2) {
          fatherName = allCandidates[1];
        }
      }
    }

    return _PanPersonDetails(name: name, fatherName: fatherName);
  }

  static String? _extractValueAfterLabel(
    List<String> lines,
    List<String> upperLines, {
    required RegExp labelRegex,
  }) {
    final panRegex = RegExp(r'\b[A-Z]{5}\d{4}[A-Z]\b');
    for (int i = 0; i < upperLines.length; i++) {
      if (!labelRegex.hasMatch(upperLines[i])) continue;

      // Scan a few lines after the label; OCR sometimes inserts blank/extra lines.
      for (int j = i + 1; j < upperLines.length && j <= i + 3; j++) {
        final compactRaw = upperLines[j].replaceAll(' ', '');
        if (panRegex.hasMatch(compactRaw)) continue;
        final candidate = _cleanPanNameCandidate(lines[j]);
        if (_looksLikePanPersonName(candidate)) return candidate;
      }
    }
    return null;
  }

  static String _cleanPanNameCandidate(String input) {
    // Keep letters, spaces, and dots (some names contain initials like "R.K.").
    final cleaned = input
        .replaceAll(RegExp(r'[^A-Za-z.\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? '' : cleaned.toUpperCase();
  }

  static bool _looksLikePanPersonName(String candidateUpper) {
    final c = candidateUpper.trim();
    if (c.isEmpty) return false;
    if (c.length < 3) return false;
    if (c.contains(RegExp(r'\d'))) return false;

    final banned = <String>[
      'INCOME',
      'TAX',
      'DEPARTMENT',
      'GOVERNMENT',
      'GOVT',
      'INDIA',
      'PERMANENT',
      'ACCOUNT',
      'NUMBER',
      'SIGNATURE',
      'DATE',
      'BIRTH',
      'DOB',
      'FATHER',
      'NAME',
    ];
    for (final word in banned) {
      if (c.contains(word)) return false;
    }

    final words = c.split(' ').where((w) => w.trim().isNotEmpty).toList();
    if (words.length < 1 || words.length > 6) return false;

    // Require at least 2 alphabetic characters overall.
    final alphaCount = c.replaceAll(RegExp(r'[^A-Z]'), '').length;
    if (alphaCount < 2) return false;
    return true;
  }
}

/// Result class for Aadhaar OCR
class AadhaarOcrResult {
  final bool success;
  final String? aadhaarNumber;
  final String? dateOfBirth;
  final String? address;
  final String? name;
  final String? fullText;
  final String? errorMessage;
  
  /// Internal flag - true if document validation passed (e.g., "GOVERNMENT OF INDIA" text found)
  /// This is for internal use only - don't expose to user
  final bool _internalDocumentValid;

  AadhaarOcrResult({
    required this.success,
    this.aadhaarNumber,
    this.dateOfBirth,
    this.address,
    this.name,
    this.fullText,
    this.errorMessage,
    bool internalDocumentValid = true,
  }) : _internalDocumentValid = internalDocumentValid;

  bool get hasAadhaarNumber => aadhaarNumber != null && aadhaarNumber!.isNotEmpty;
  bool get hasDateOfBirth => dateOfBirth != null && dateOfBirth!.isNotEmpty;
  bool get hasAddress => address != null && address!.isNotEmpty;
  bool get hasName => name != null && name!.isNotEmpty;
  
  /// Internal validation status - for backend/admin use only
  bool get isInternallyValid => _internalDocumentValid;
}

/// Result class for PAN OCR
class PanOcrResult {
  final bool success;
  final String? panNumber;
  final String? name;
  final String? fatherName;
  final String? fullText;
  final String? errorMessage;
  
  /// Internal flag - true if document validation passed (e.g., "INCOME TAX DEPARTMENT" text found)
  /// This is for internal use only - don't expose to user
  final bool _internalDocumentValid;

  PanOcrResult({
    required this.success,
    this.panNumber,
    this.name,
    this.fatherName,
    this.fullText,
    this.errorMessage,
    bool internalDocumentValid = true,
  }) : _internalDocumentValid = internalDocumentValid;

  bool get hasPanNumber => panNumber != null && panNumber!.isNotEmpty;
  bool get hasName => name != null && name!.isNotEmpty;
  bool get hasFatherName => fatherName != null && fatherName!.isNotEmpty;
  
  /// Internal validation status - for backend/admin use only
  bool get isInternallyValid => _internalDocumentValid;
}

class _PanPersonDetails {
  final String? name;
  final String? fatherName;

  const _PanPersonDetails({this.name, this.fatherName});
}
