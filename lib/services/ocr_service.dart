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
    try {
      // Create InputImage from path or bytes
      InputImage inputImage;
      
      if (imageBytes != null) {
        // Use bytes directly (works on all platforms)
        final tempFile = await _createTempFile(imageBytes);
        inputImage = InputImage.fromFilePath(tempFile.path);
      } else {
        if (kIsWeb) {
          return AadhaarOcrResult(
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
      
      // Step 1: Find VID (16 digits with spaces: XXXX XXXX XXXX XXXX)
      final vidRegex = RegExp(r'(\d{4})\s+(\d{4})\s+(\d{4})\s+(\d{4})');
      final vidMatch = vidRegex.firstMatch(fullText);
      String? vidNumber;
      if (vidMatch != null) {
        vidNumber = '${vidMatch.group(1)}${vidMatch.group(2)}${vidMatch.group(3)}${vidMatch.group(4)}';
        debugPrint('VID found: $vidNumber');
      }
      
      // Step 2: Find Aadhaar number - EXACTLY 4 digits + space + 4 digits + space + 4 digits
      // This is the standard format printed on Aadhaar cards
      final aadhaarRegex = RegExp(r'([2-9]\d{3})\s+(\d{4})\s+(\d{4})');
      
      final aadhaarMatches = aadhaarRegex.allMatches(fullText).toList();
      debugPrint('Found ${aadhaarMatches.length} potential Aadhaar patterns');
      
      for (final match in aadhaarMatches) {
        final part1 = match.group(1) ?? '';
        final part2 = match.group(2) ?? '';
        final part3 = match.group(3) ?? '';
        final extracted = '$part1$part2$part3';
        
        debugPrint('Checking potential Aadhaar: $extracted');
        
        // Skip if this is part of VID
        if (vidNumber != null && vidNumber.contains(extracted)) {
          debugPrint('Skipping - part of VID');
          continue;
        }
        
        // Skip if this looks like a date (part3 might be year like 1990, 2000)
        final part3Int = int.tryParse(part3) ?? 0;
        if (part3Int >= 1950 && part3Int <= 2030) {
          debugPrint('Skipping - looks like a date (year: $part3Int)');
          continue;
        }
        
        // Valid Aadhaar found!
        aadhaarNumber = extracted;
        debugPrint('Found Aadhaar number: $aadhaarNumber');
        break;
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
          
          aadhaarNumber = extracted;
          debugPrint('Found Aadhaar number (fallback): $aadhaarNumber');
          break;
        }
      }

      if (isFront) {
        // SECRET validation for front side: Check for "GOVERNMENT OF INDIA" text (case-insensitive)
        // This is for internal use only - we don't show this error to users
        final hasGovernmentOfIndia = fullTextUpper.contains('GOVERNMENT OF INDIA') || 
                                     fullTextUpper.contains('GOVT OF INDIA') ||
                                     fullTextUpper.contains('GOVT. OF INDIA');
        
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
        
        // Front side: Extract Name (typically appears as capitalized text, 2-4 words, no numbers)
        for (final block in recognizedText.blocks) {
          final text = block.text.trim();
          // Look for capitalized name (typically 2-4 words)
          if (text.length > 3 && 
              text == text.toUpperCase() && 
              !text.contains(RegExp(r'\d')) &&
              text.split(' ').length >= 2 &&
              text.split(' ').length <= 5 &&
              !text.contains('GOVERNMENT') &&
              !text.contains('INDIA') &&
              !text.contains('AADHAAR') &&
              !text.contains('UNIQUE') &&
              !text.contains('IDENTIFICATION') &&
              !text.contains('AUTHORITY') &&
              !text.contains('UIDAI') &&
              !text.contains('DOB') &&
              !text.contains('MALE') &&
              !text.contains('FEMALE') &&
              !text.contains('ENROLMENT') &&
              !text.contains('VID') &&
              !text.contains('VIRTUAL')) {
            name = text;
            break;
          }
        }

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
        
        // Find marker position
        final markerMatch = markerRegex.firstMatch(rawText);
        int addressStart = 0;
        
        if (markerMatch != null) {
          addressStart = markerMatch.end;
          debugPrint('Found marker "${markerMatch.group(0)}" - address starts at position $addressStart');
        } else {
          debugPrint('No C/O marker found, will look for address differently');
        }
        
        // Find ALL pincodes in text
        final allPincodes = pincodeRegex.allMatches(rawText).toList();
        debugPrint('Found ${allPincodes.length} potential pincodes');
        
        String? pinCode;
        int? addressEnd;
        
        if (allPincodes.isNotEmpty) {
          // If we have a marker, find the first pincode AFTER the marker
          if (addressStart > 0) {
            for (final pm in allPincodes) {
              if (pm.start >= addressStart) {
                pinCode = pm.group(1);
                addressEnd = pm.end;
                debugPrint('Using pincode $pinCode after marker (position ${pm.start}-${pm.end})');
                break;
              }
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
        
        // Step 3: Extract address - ALL text between marker and pincode
        if (addressEnd != null && addressStart < addressEnd) {
          // Get all text from marker to pincode (includes all 3-4 lines)
          String rawAddress = rawText.substring(addressStart, addressEnd);
          debugPrint('Raw address (${rawAddress.length} chars): $rawAddress');
          
          // Clean up: join lines with comma, clean spaces
          address = rawAddress
              // Replace newlines with comma and space
              .replaceAll(RegExp(r'[\r\n]+'), ', ')
              // Replace multiple spaces/tabs with single space
              .replaceAll(RegExp(r'[ \t]+'), ' ')
              // Clean up multiple commas
              .replaceAll(RegExp(r',\s*,'), ', ')
              // Remove leading punctuation/spaces
              .replaceAll(RegExp(r'^[\s,:\-]+'), '')
              // Remove trailing punctuation before pincode (keep pincode)
              .trim();
          
          // Ensure address ends with pincode
          if (pinCode != null && !address.endsWith(pinCode)) {
            final pincodePos = address.lastIndexOf(pinCode);
            if (pincodePos != -1) {
              address = address.substring(0, pincodePos + pinCode.length);
            }
          }
          
          debugPrint('Final address: $address');
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
              .replaceAll(RegExp(r'^[\s,:\-]+'), '')
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
    } catch (e) {
      debugPrint('Aadhaar OCR Error: $e');
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

      // Extract name (usually below PAN number)
      String? name;
      for (final block in recognizedText.blocks) {
        final text = block.text.trim();
        // Look for capitalized name (typically 2-4 words)
        if (text.length > 5 && 
            text == text.toUpperCase() && 
            !text.contains(RegExp(r'\d')) &&
            text.split(' ').length >= 2 &&
            text.split(' ').length <= 4 &&
            !text.contains('INCOME') &&
            !text.contains('TAX') &&
            !text.contains('DEPARTMENT') &&
            !text.contains('GOVT')) {
          name = text;
          break;
        }
      }

      debugPrint('OCR Results - PAN: $panNumber, Name: $name, InternalValid: $internalDocumentValid');

      return PanOcrResult(
        success: true,
        panNumber: panNumber,
        name: name,
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
  final String? fullText;
  final String? errorMessage;
  
  /// Internal flag - true if document validation passed (e.g., "INCOME TAX DEPARTMENT" text found)
  /// This is for internal use only - don't expose to user
  final bool _internalDocumentValid;

  PanOcrResult({
    required this.success,
    this.panNumber,
    this.name,
    this.fullText,
    this.errorMessage,
    bool internalDocumentValid = true,
  }) : _internalDocumentValid = internalDocumentValid;

  bool get hasPanNumber => panNumber != null && panNumber!.isNotEmpty;
  bool get hasName => name != null && name!.isNotEmpty;
  
  /// Internal validation status - for backend/admin use only
  bool get isInternallyValid => _internalDocumentValid;
}
