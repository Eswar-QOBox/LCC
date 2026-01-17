import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../utils/aadhaar_ocr_parser.dart';

/// Service for performing OCR on Aadhaar card images
class AadhaarOCRService {
  final TextRecognizer _textRecognizer;
  
  AadhaarOCRService() : _textRecognizer = TextRecognizer();
  
  /// Process image and extract Aadhaar fields
  /// Returns a map with raw text and parsed fields
  Future<Map<String, dynamic>> processAadhaarImage(File imageFile) async {
    try {
      // Check if file exists
      if (!await imageFile.exists()) {
        return {
          'rawText': '',
          'parsedFields': <String, dynamic>{},
          'success': false,
          'error': 'Image file does not exist at path: ${imageFile.path}',
        };
      }
      
      // Debug: Print file info
      final fileSize = await imageFile.length();
      print('OCR Service: Processing image at ${imageFile.path}');
      print('OCR Service: File size: $fileSize bytes');
      
      if (fileSize == 0) {
        return {
          'rawText': '',
          'parsedFields': <String, dynamic>{},
          'success': false,
          'error': 'Image file is empty (0 bytes)',
        };
      }
      
      // Create InputImage from file path
      print('OCR Service: Creating InputImage...');
      final inputImage = InputImage.fromFilePath(imageFile.path);
      
      // Process image with ML Kit
      print('OCR Service: Starting ML Kit text recognition...');
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      // Extract raw text
      final rawText = recognizedText.text;
      print('OCR Service: Extracted text length: ${rawText.length}');
      
      if (rawText.isEmpty) {
        return {
          'rawText': '',
          'parsedFields': <String, dynamic>{},
          'success': false,
          'error': 'No text detected in image. Please ensure the image is clear and contains text.',
        };
      }
      
      // Parse Aadhaar fields from text
      final parsedFields = AadhaarOCRParser.parseAadhaarFields(rawText);
      print('OCR Service: Parsed ${parsedFields.length} fields');
      
      return {
        'rawText': rawText,
        'parsedFields': parsedFields,
        'success': true,
      };
    } catch (e, stackTrace) {
      print('OCR Service Error: $e');
      print('OCR Service Stack Trace: $stackTrace');
      return {
        'rawText': '',
        'parsedFields': <String, dynamic>{},
        'success': false,
        'error': 'OCR processing failed: ${e.toString()}',
      };
    }
  }
  
  /// Process image and return only parsed fields
  Future<Map<String, dynamic>> extractAadhaarFields(File imageFile) async {
    final result = await processAadhaarImage(imageFile);
    return result['parsedFields'] as Map<String, dynamic>;
  }
  
  /// Dispose the text recognizer
  void dispose() {
    _textRecognizer.close();
  }
}
