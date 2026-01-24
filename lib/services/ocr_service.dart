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

      if (isFront) {
        // Basic validation for front side: Check for "GOVERNMENT OF INDIA" text (case-insensitive)
        final fullText = recognizedText.text.toUpperCase();
        final hasGovernmentOfIndia = fullText.contains('GOVERNMENT OF INDIA') || 
                                     fullText.contains('GOVT OF INDIA') ||
                                     fullText.contains('GOVT. OF INDIA');
        
        if (!hasGovernmentOfIndia) {
          debugPrint('Aadhaar validation failed: "GOVERNMENT OF INDIA" text not found');
          return AadhaarOcrResult(
            success: false,
            errorMessage: 'Invalid Aadhaar card. "GOVERNMENT OF INDIA" text not found.',
            fullText: recognizedText.text,
          );
        }
        
        // Front side: Extract Aadhaar number and DOB only
        // Extract Aadhaar number (12 digits)
        final aadhaarRegex = RegExp(r'\b\d{4}\s?\d{4}\s?\d{4}\b');
        
        for (final textBlock in recognizedText.blocks) {
          final match = aadhaarRegex.firstMatch(textBlock.text);
          if (match != null) {
            aadhaarNumber = match.group(0)?.replaceAll(' ', '');
            break;
          }
        }

        // Extract DOB (DD/MM/YYYY format)
        final dobRegex = RegExp(r'\b\d{2}/\d{2}/\d{4}\b');
        
        for (final textBlock in recognizedText.blocks) {
          final match = dobRegex.firstMatch(textBlock.text);
          if (match != null) {
            dateOfBirth = match.group(0);
            break;
          }
        }

        debugPrint('OCR Results (Aadhaar Front) - Aadhaar: $aadhaarNumber, DOB: $dateOfBirth');
      } else {
        // Back side: Extract address only
        // Address is typically in multiple lines, look for longer text blocks
        final addressLines = <String>[];
        
        // Filter out "Unique Identification Authority of India" and "UIDAI" text
        final filteredText = recognizedText.text
            .replaceAll(RegExp(r'Unique Identification Authority of India', caseSensitive: false), '')
            .replaceAll(RegExp(r'UIDAI', caseSensitive: false), '')
            .replaceAll(RegExp(r'UNIQUE IDENTIFICATION AUTHORITY OF INDIA', caseSensitive: false), '');
        
        // Find pin code (6 digits) - this marks the end of address
        final pinCodeRegex = RegExp(r'\b\d{6}\b');
        final pinCodeMatch = pinCodeRegex.firstMatch(filteredText);
        int? stopIndex;
        
        if (pinCodeMatch != null) {
          // Find the position after pin code (including pin code itself)
          stopIndex = pinCodeMatch.end;
        }
        
        // Extract text blocks up to pin code
        for (final block in recognizedText.blocks) {
          final text = block.text.trim();
          
          // Skip if this block is beyond the pin code
          if (stopIndex != null) {
            final blockStart = recognizedText.text.indexOf(block.text);
            if (blockStart > stopIndex) {
              break; // Stop processing blocks after pin code
            }
          }
          
          // Look for text that might be part of an address
          // Address typically contains numbers (house numbers, pincodes) and longer text
          if (text.length > 5 && 
              (text.contains(RegExp(r'\d')) || 
               text.contains(RegExp(r'[A-Za-z]')))) {
            // Filter out common non-address text
            final textUpper = text.toUpperCase();
            if (!textUpper.contains('GOVERNMENT OF INDIA') &&
                !textUpper.contains('AADHAAR') &&
                !textUpper.contains('UIDAI') &&
                !textUpper.contains('UNIQUE IDENTIFICATION AUTHORITY') &&
                !textUpper.contains('DOB') &&
                !textUpper.contains('YOB') &&
                !textUpper.contains('MALE') &&
                !textUpper.contains('FEMALE') &&
                textUpper.trim().isNotEmpty) {
              addressLines.add(text);
            }
          }
        }
        
        // Combine address lines
        if (addressLines.isNotEmpty) {
          address = addressLines.join(', ');
          
          // Clean up the address - remove extra spaces
          address = address.replaceAll(RegExp(r'\s+'), ' ').trim();
          
          // Ensure we stop at pin code if found
          if (pinCodeMatch != null) {
            final pinCode = pinCodeMatch.group(0)!;
            // Find pin code position in final address and truncate after it
            final pinCodePos = address.indexOf(pinCode);
            if (pinCodePos != -1) {
              address = address.substring(0, pinCodePos + pinCode.length).trim();
            }
          }
        }

        debugPrint('OCR Results (Aadhaar Back) - Address: $address');
      }

      return AadhaarOcrResult(
        success: true,
        aadhaarNumber: aadhaarNumber,
        dateOfBirth: dateOfBirth,
        address: address,
        fullText: recognizedText.text,
      );
    } catch (e) {
      debugPrint('Aadhaar OCR Error: $e');
      return AadhaarOcrResult(
        success: false,
        errorMessage: 'Failed to extract text: ${e.toString()}',
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

      // Basic validation: Check for "INCOME TAX DEPARTMENT" text (case-insensitive)
      final fullText = recognizedText.text.toUpperCase();
      final hasIncomeTaxDepartment = fullText.contains('INCOME TAX DEPARTMENT') || 
                                     fullText.contains('INCOME TAX DEPT') ||
                                     fullText.contains('INCOME TAX DEPT.');
      
      if (!hasIncomeTaxDepartment) {
        debugPrint('PAN validation failed: "INCOME TAX DEPARTMENT" text not found');
        return PanOcrResult(
          success: false,
          errorMessage: 'Invalid PAN card. "INCOME TAX DEPARTMENT" text not found.',
          fullText: recognizedText.text,
        );
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

      debugPrint('OCR Results - PAN: $panNumber, Name: $name');

      return PanOcrResult(
        success: true,
        panNumber: panNumber,
        name: name,
        fullText: recognizedText.text,
      );
    } catch (e) {
      debugPrint('PAN OCR Error: $e');
      return PanOcrResult(
        success: false,
        errorMessage: 'Failed to extract text: ${e.toString()}',
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
  final String? fullText;
  final String? errorMessage;

  AadhaarOcrResult({
    required this.success,
    this.aadhaarNumber,
    this.dateOfBirth,
    this.address,
    this.fullText,
    this.errorMessage,
  });

  bool get hasAadhaarNumber => aadhaarNumber != null && aadhaarNumber!.isNotEmpty;
  bool get hasDateOfBirth => dateOfBirth != null && dateOfBirth!.isNotEmpty;
  bool get hasAddress => address != null && address!.isNotEmpty;
}

/// Result class for PAN OCR
class PanOcrResult {
  final bool success;
  final String? panNumber;
  final String? name;
  final String? fullText;
  final String? errorMessage;

  PanOcrResult({
    required this.success,
    this.panNumber,
    this.name,
    this.fullText,
    this.errorMessage,
  });

  bool get hasPanNumber => panNumber != null && panNumber!.isNotEmpty;
  bool get hasName => name != null && name!.isNotEmpty;
}
