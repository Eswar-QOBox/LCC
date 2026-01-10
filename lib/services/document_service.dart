import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/document_submission.dart';

// Conditional import - only import dart:io on non-web platforms
import 'dart:io' if (dart.library.html) 'file_helper_stub.dart' as io;

class DocumentService {
  // Validation constants
  static const int minWidth = 400;
  static const int minHeight = 400;
  static const int maxFileSizeMB = 10;
  static const int minFileSizeKB = 50; // Too small might be corrupted
  // More lenient aspect ratio for live selfies - allows portrait, square, and slight landscape
  static const double minAspectRatio =
      0.5; // Very tall portrait (2:1 height:width)
  static const double maxAspectRatio =
      2.0; // Slight landscape (2:1 width:height)

  /// Validates selfie based on requirements
  static Future<SelfieValidationResult> validateSelfie(
    String imagePath, {
    Uint8List? imageBytes,
  }) async {
    final List<String> errors = [];

    // Check if image exists
    if (imagePath.isEmpty && (imageBytes == null || imageBytes.isEmpty)) {
      return SelfieValidationResult(
        isValid: false,
        errors: ['Please select an image'],
      );
    }

    try {
      // Read image bytes
      Uint8List bytes;
      if (imageBytes != null) {
        bytes = imageBytes;
      } else {
        if (kIsWeb) {
          // On web, we can't read files directly from path
          // Return a helpful error message
          return SelfieValidationResult(
            isValid: false,
            errors: [
              'Image validation on web requires image data. Please ensure the image was properly selected.',
            ],
          );
        } else {
          // On mobile/desktop, read from file path
          // Note: This code path should not execute on web due to kIsWeb check above
          if (kIsWeb) {
            // This should never happen due to check above, but just in case
            return SelfieValidationResult(
              isValid: false,
              errors: ['Image validation on web requires image bytes'],
            );
          }
          try {
            // File is only available on non-web platforms
            // Use io.File to work with conditional import
            final file = io.File(imagePath);
            if (!await file.exists()) {
              return SelfieValidationResult(
                isValid: false,
                errors: ['Image file not found'],
              );
            }
            bytes = await file.readAsBytes();
          } catch (e) {
            return SelfieValidationResult(
              isValid: false,
              errors: ['Failed to read image file: ${e.toString()}'],
            );
          }
        }
      }

      // Validate file size
      final fileSizeKB = bytes.length / 1024;
      final fileSizeMB = fileSizeKB / 1024;

      if (fileSizeKB < minFileSizeKB) {
        errors.add('Image file is too small (may be corrupted)');
      }
      if (fileSizeMB > maxFileSizeMB) {
        errors.add('Image file is too large (max ${maxFileSizeMB}MB)');
      }

      // Decode and validate image
      img.Image? image;
      try {
        image = img.decodeImage(bytes);
      } catch (e) {
        return SelfieValidationResult(
          isValid: false,
          errors: [
            'Failed to decode image. Please ensure it is a valid image file',
          ],
        );
      }

      if (image == null) {
        return SelfieValidationResult(
          isValid: false,
          errors: ['Invalid image format. Please use JPEG or PNG'],
        );
      }

      // Automatically resize to standard portrait aspect ratio (3:4) for selfies
      // This ensures consistent orientation regardless of how the photo was taken
      try {
        image = _resizeToPortraitRatio(image);
      } catch (e) {
        // If resizing fails, continue with original image
        // Log error but don't block validation
      }

      // Ensure image is still valid after resize
      if (image == null) {
        return SelfieValidationResult(
          isValid: false,
          errors: ['Failed to process image. Please try again.'],
        );
      }

      // Validate dimensions
      final width = image.width;
      final height = image.height;

      if (width < minWidth || height < minHeight) {
        errors.add(
          'Image resolution too low. Minimum size: ${minWidth}x${minHeight}px (Current: ${width}x${height}px)',
        );
      }

      // Check image quality (basic checks)
      final qualityIssues = _checkImageQuality(image);
      errors.addAll(qualityIssues);

      // Check for potential filters/editing (basic check via color variance)
      final colorVariance = _calculateColorVariance(image);
      if (colorVariance < 500) {
        // Very low variance might indicate filters or poor quality
        errors.add('Image may have filters applied or poor quality');
      }

      // Background check (check if background is relatively uniform/light)
      final (isValid, errorMessage, debugInfo) = _checkBackground(image);
      if (!isValid && errorMessage != null) {
        errors.add(errorMessage);
      }

      // Lighting check (check overall brightness)
      final lightingCheck = _checkLighting(image);
      if (!lightingCheck.isValid) {
        errors.addAll(lightingCheck.errors);
      }

      // Face detection check (only on mobile platforms, skip on web)
      // Add timeout to prevent hanging
      if (!kIsWeb) {
        try {
          final faceCheck = await _checkFacePresence(bytes, width, height)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  // Return valid result if timeout - don't block validation
                  return SelfieValidationResult(isValid: true, errors: []);
                },
              );
          if (!faceCheck.isValid) {
            errors.addAll(faceCheck.errors);
          }
        } catch (e) {
          // If face detection fails, don't block validation
          // Log error but allow other validations to proceed
          // In production, you might want to log this to analytics
        }
      }

      return SelfieValidationResult(isValid: errors.isEmpty, errors: errors);
    } catch (e) {
      return SelfieValidationResult(
        isValid: false,
        errors: ['Error validating image: ${e.toString()}'],
      );
    }
  }

  /// Check image quality (blur, contrast, etc.)
  static List<String> _checkImageQuality(img.Image image) {
    final List<String> issues = [];

    // Validate image dimensions
    if (image.width <= 0 || image.height <= 0) {
      return issues;
    }

    // Calculate average brightness
    int totalBrightness = 0;
    int pixelCount = 0;

    // Sample pixels for performance (check every 10th pixel)
    // Add bounds checking to prevent crashes
    for (int y = 0; y < image.height; y += 10) {
      if (y >= image.height) break;
      for (int x = 0; x < image.width; x += 10) {
        if (x >= image.width) break;
        try {
          final pixel = image.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          final brightness = (r + g + b) ~/ 3;
          totalBrightness += brightness;
          pixelCount++;
        } catch (e) {
          // Skip invalid pixels
          continue;
        }
      }
    }

    // Prevent division by zero
    if (pixelCount == 0) {
      return issues;
    }

    final avgBrightness = totalBrightness / pixelCount;

    // Check if image is too dark
    if (avgBrightness < 80) {
      issues.add('Image is too dark. Please use better lighting');
    }

    // Check if image is too bright (overexposed)
    if (avgBrightness > 220) {
      issues.add('Image is overexposed. Please reduce lighting');
    }

    // Calculate contrast (difference between light and dark areas)
    final contrast = _calculateContrast(image);
    if (contrast < 30) {
      issues.add('Image has low contrast. May be blurry or low quality');
    }

    return issues;
  }

  /// Calculate color variance to detect filters
  static double _calculateColorVariance(img.Image image) {
    // Validate image dimensions
    if (image.width <= 0 || image.height <= 0) {
      return 0.0;
    }

    final List<int> redValues = [];
    final List<int> greenValues = [];
    final List<int> blueValues = [];

    // Sample pixels with bounds checking
    for (int y = 0; y < image.height; y += 20) {
      if (y >= image.height) break;
      for (int x = 0; x < image.width; x += 20) {
        if (x >= image.width) break;
        try {
          final pixel = image.getPixel(x, y);
          redValues.add(pixel.r.toInt());
          greenValues.add(pixel.g.toInt());
          blueValues.add(pixel.b.toInt());
        } catch (e) {
          // Skip invalid pixels
          continue;
        }
      }
    }

    // Prevent empty list operations
    if (redValues.isEmpty || greenValues.isEmpty || blueValues.isEmpty) {
      return 0.0;
    }

    final redMean = redValues.reduce((a, b) => a + b) / redValues.length;
    final greenMean = greenValues.reduce((a, b) => a + b) / greenValues.length;
    final blueMean = blueValues.reduce((a, b) => a + b) / blueValues.length;

    final redVariance = _calculateVariance(redValues, redMean);
    final greenVariance = _calculateVariance(greenValues, greenMean);
    final blueVariance = _calculateVariance(blueValues, blueMean);

    return (redVariance + greenVariance + blueVariance) / 3;
  }

  /// Calculate variance of a list of values (with pre-calculated mean for efficiency)
  /// Matches user's snippet signature: _calculateVariance(List values, double mean)
  static double _calculateVariance(List<int> values, double mean) {
    if (values.isEmpty) return 0.0;

    double sum = 0.0;
    for (final value in values) {
      final diff = value - mean;
      sum += diff * diff;
    }

    return sum / values.length;
  }

  /// Helper function to get brightness from a pixel
  static int _getBrightness(img.Pixel pixel) {
    return ((pixel.r.toInt() + pixel.g.toInt() + pixel.b.toInt()) / 3).round();
  }

  /// Resize image to standard portrait aspect ratio (3:4) for selfies
  /// This automatically handles any orientation and crops/resizes to center
  static img.Image _resizeToPortraitRatio(img.Image image) {
    // Validate image dimensions
    if (image.width <= 0 || image.height <= 0) {
      return image; // Return original if invalid
    }

    const double targetAspectRatio = 3.0 / 4.0; // Portrait: width:height = 3:4
    final int originalWidth = image.width;
    final int originalHeight = image.height;

    // Prevent division by zero
    if (originalHeight == 0) {
      return image;
    }

    final double originalAspectRatio = originalWidth / originalHeight;

    int targetWidth;
    int targetHeight;

    // Calculate target dimensions maintaining minimum size
    try {
      if (originalAspectRatio > targetAspectRatio) {
        // Image is wider than target - crop width (center crop)
        targetHeight = math.max(originalHeight, minHeight);
        targetWidth = (targetHeight * targetAspectRatio).round();

        // Validate dimensions
        if (targetWidth <= 0 || targetHeight <= 0) {
          return image;
        }

        // Center crop horizontally
        final int cropX = ((originalWidth - targetWidth) / 2).round();
        final int cropY = 0;

        if (cropX >= 0 &&
            cropX + targetWidth <= originalWidth &&
            targetWidth > 0 &&
            targetHeight > 0) {
          image = img.copyCrop(
            image,
            x: cropX,
            y: cropY,
            width: targetWidth,
            height: targetHeight,
          );
        } else {
          // If crop would go out of bounds, just resize
          targetWidth = (targetHeight * targetAspectRatio).round();
          if (targetWidth > 0 && targetHeight > 0) {
            image = img.copyResize(
              image,
              width: targetWidth,
              height: targetHeight,
            );
          }
        }
      } else {
        // Image is taller than target - crop height (center crop)
        targetWidth = math.max(originalWidth, minWidth);
        targetHeight = (targetWidth / targetAspectRatio).round();

        // Validate dimensions
        if (targetWidth <= 0 || targetHeight <= 0) {
          return image;
        }

        // Center crop vertically
        final int cropX = 0;
        final int cropY = ((originalHeight - targetHeight) / 2).round();

        if (cropY >= 0 &&
            cropY + targetHeight <= originalHeight &&
            targetWidth > 0 &&
            targetHeight > 0) {
          image = img.copyCrop(
            image,
            x: cropX,
            y: cropY,
            width: targetWidth,
            height: targetHeight,
          );
        } else {
          // If crop would go out of bounds, just resize
          targetHeight = (targetWidth / targetAspectRatio).round();
          if (targetWidth > 0 && targetHeight > 0) {
            image = img.copyResize(
              image,
              width: targetWidth,
              height: targetHeight,
            );
          }
        }
      }

      // Ensure minimum dimensions
      if (image.width > 0 && image.height > 0) {
        if (image.width < minWidth || image.height < minHeight) {
          final double scale = math.max(
            minWidth / image.width,
            minHeight / image.height,
          );
          targetWidth = (image.width * scale).round();
          targetHeight = (image.height * scale).round();
          if (targetWidth > 0 && targetHeight > 0) {
            image = img.copyResize(
              image,
              width: targetWidth,
              height: targetHeight,
            );
          }
        }
      }
    } catch (e) {
      // If resize/crop fails, return original image
      return image;
    }

    return image;
  }

  /// Validates background with relaxed rules suitable for live selfie capture
  /// Returns: (isValid, errorMessage, debugInfo)
  static (bool, String?, Map<String, dynamic>) _checkBackground(
    img.Image image,
  ) {
    // Validate image dimensions
    if (image.width <= 0 || image.height <= 0) {
      return (true, null, {'error': 'invalid_dimensions'});
    }

    // Relaxed configuration for live selfies
    const double brightnessThreshold = 100.0; // Allow darker backgrounds
    const double coefficientVariationThreshold =
        80.0; // Very lenient - 80% (allows most backgrounds)
    const int sampleInterval = 50;

    final List<int> backgroundSamples = [];
    final debugInfo = <String, dynamic>{};

    // Simple edge sampling (avoiding center where face likely is)
    const edgeMargin = 20; // Only sample outer 20 pixels

    // Top edge
    for (int x = 0; x < image.width; x += sampleInterval) {
      if (x >= image.width) break;
      for (int y = 0; y < edgeMargin && y < image.height; y += 10) {
        if (y >= image.height) break;
        try {
          final pixel = image.getPixel(x, y);
          backgroundSamples.add(_getBrightness(pixel));
        } catch (e) {
          continue;
        }
      }
    }

    // Bottom edge
    for (int x = 0; x < image.width; x += sampleInterval) {
      if (x >= image.width) break;
      for (
        int y = math.max(0, image.height - edgeMargin);
        y < image.height;
        y += 10
      ) {
        if (y >= image.height) break;
        try {
          final pixel = image.getPixel(x, y);
          backgroundSamples.add(_getBrightness(pixel));
        } catch (e) {
          continue;
        }
      }
    }

    // Left edge
    for (int y = 0; y < image.height; y += sampleInterval) {
      if (y >= image.height) break;
      for (int x = 0; x < edgeMargin && x < image.width; x += 10) {
        if (x >= image.width) break;
        try {
          final pixel = image.getPixel(x, y);
          backgroundSamples.add(_getBrightness(pixel));
        } catch (e) {
          continue;
        }
      }
    }

    // Right edge
    for (int y = 0; y < image.height; y += sampleInterval) {
      if (y >= image.height) break;
      for (
        int x = math.max(0, image.width - edgeMargin);
        x < image.width;
        x += 10
      ) {
        if (x >= image.width) break;
        try {
          final pixel = image.getPixel(x, y);
          backgroundSamples.add(_getBrightness(pixel));
        } catch (e) {
          continue;
        }
      }
    }

    if (backgroundSamples.isEmpty || backgroundSamples.length < 10) {
      return (
        false,
        'Unable to analyze background',
        {'error': 'insufficient_samples'},
      );
    }

    // Calculate basic statistics
    final avgBrightness =
        backgroundSamples.reduce((a, b) => a + b) / backgroundSamples.length;
    final variance = _calculateVariance(backgroundSamples, avgBrightness);
    final stdDev = math.sqrt(variance);
    final coefficientOfVariation = avgBrightness > 0
        ? (stdDev / avgBrightness) * 100
        : 0;

    // Debug info (optional - can remove in production)
    debugInfo['avg_brightness'] = avgBrightness.toStringAsFixed(1);
    debugInfo['coefficient_variation'] = coefficientOfVariation.toStringAsFixed(
      1,
    );
    debugInfo['sample_count'] = backgroundSamples.length;

    // Only fail on obviously problematic backgrounds

    // Check 1: Extremely dark background (likely poor lighting)
    if (avgBrightness < brightnessThreshold) {
      return (
        false,
        'Background is too dark. Please ensure better lighting.',
        debugInfo,
      );
    }

    // Check 2: Extremely varied background (busy patterns, multiple colors)
    if (coefficientOfVariation > coefficientVariationThreshold) {
      return (
        false,
        'Background is too busy. Please use a simpler background.',
        debugInfo,
      );
    }

    // All good - accept the selfie
    return (true, null, debugInfo);
  }

  /// Check lighting conditions
  static SelfieValidationResult _checkLighting(img.Image image) {
    final List<String> errors = [];

    // Calculate overall brightness
    int totalBrightness = 0;
    int pixelCount = 0;

    // Sample center area (face area typically)
    final centerX = image.width ~/ 2;
    final centerY = image.height ~/ 2;
    final sampleRadius = math.min(image.width, image.height) ~/ 4;

    for (int y = centerY - sampleRadius; y < centerY + sampleRadius; y += 5) {
      if (y < 0 || y >= image.height) continue;
      for (int x = centerX - sampleRadius; x < centerX + sampleRadius; x += 5) {
        if (x < 0 || x >= image.width) continue;
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        totalBrightness += (r + g + b) ~/ 3;
        pixelCount++;
      }
    }

    if (pixelCount > 0) {
      final avgBrightness = totalBrightness ~/ pixelCount;

      if (avgBrightness < 100) {
        errors.add('Face area is too dark. Please use better lighting');
      }

      if (avgBrightness > 240) {
        errors.add('Face area is overexposed. Please reduce lighting');
      }
    }

    return SelfieValidationResult(isValid: errors.isEmpty, errors: errors);
  }

  /// Calculate contrast of the image
  static double _calculateContrast(img.Image image) {
    // Validate image dimensions
    if (image.width <= 0 || image.height <= 0) {
      return 0.0;
    }

    final List<int> brightnessValues = [];

    // Sample pixels with bounds checking
    for (int y = 0; y < image.height; y += 15) {
      if (y >= image.height) break;
      for (int x = 0; x < image.width; x += 15) {
        if (x >= image.width) break;
        try {
          final pixel = image.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          brightnessValues.add((r + g + b) ~/ 3);
        } catch (e) {
          // Skip invalid pixels
          continue;
        }
      }
    }

    if (brightnessValues.isEmpty) return 0.0;

    final minBrightness = brightnessValues.reduce(math.min);
    final maxBrightness = brightnessValues.reduce(math.max);

    return (maxBrightness - minBrightness).toDouble();
  }

  /// Validates document clarity
  /// Skeleton implementation - proper validation will be added in next cycle
  static Future<bool> validateDocumentClarity(String imagePath) async {
    // Skeleton validation - just return true for now
    // TODO: Add proper clarity checks in next cycle:
    // - Blur detection
    // - Glare detection
    // - Resolution validation
    // - OCR readability

    return true;
  }

  /// Checks if PDF is password protected
  /// Skeleton implementation - proper check will be added in next cycle
  static Future<bool> isPdfPasswordProtected(String pdfPath) async {
    // Skeleton implementation
    // TODO: Add proper PDF password detection in next cycle
    return false;
  }

  /// Check if a face is present in the image using ML Kit Face Detection
  /// Returns validation result with errors if no face is detected
  static Future<SelfieValidationResult> _checkFacePresence(
    Uint8List imageBytes,
    int width,
    int height,
  ) async {
    io.File? tempFile;
    io.Directory? tempDir;

    try {
      // Validate inputs
      if (imageBytes.isEmpty || width <= 0 || height <= 0) {
        return SelfieValidationResult(
          isValid: true, // Don't block on invalid inputs
          errors: [],
        );
      }

      // Limit image size to prevent memory issues (max 5MB for face detection)
      if (imageBytes.length > 5 * 1024 * 1024) {
        // Image too large for face detection - skip it
        return SelfieValidationResult(
          isValid: true, // Don't block on large images
          errors: [],
        );
      }

      // Create temporary file for ML Kit (it requires file path for static images)
      tempDir = await io.Directory.systemTemp.createTemp('selfie_validation_');
      tempFile = io.File('${tempDir.path}/temp_image.jpg');
      await tempFile.writeAsBytes(imageBytes);

      // Verify file was created
      if (!await tempFile.exists()) {
        return SelfieValidationResult(
          isValid: true, // Don't block on file creation failure
          errors: [],
        );
      }

      final inputImage = InputImage.fromFilePath(tempFile.path);

      // Configure face detector options - lenient settings for better detection
      final options = FaceDetectorOptions(
        enableClassification: false,
        enableLandmarks: false,
        enableContours: false,
        enableTracking: false,
        minFaceSize: 0.1, // Minimum face size (10% of image) - very lenient
        performanceMode: FaceDetectorMode.fast,
      );

      // Create face detector with error handling
      FaceDetector faceDetector;
      try {
        faceDetector = FaceDetector(options: options);
      } catch (e) {
        // If detector creation fails, don't block
        return SelfieValidationResult(isValid: true, errors: []);
      }

      // Detect faces with error handling
      List<Face> faces = [];
      try {
        faces = await faceDetector.processImage(inputImage);
      } catch (e) {
        // If detection fails, close detector and return
        try {
          await faceDetector.close();
        } catch (_) {}
        return SelfieValidationResult(
          isValid: true, // Don't block on detection failure
          errors: [],
        );
      }

      // Close the detector to free resources
      try {
        await faceDetector.close();
      } catch (e) {
        // Ignore close errors
      }

      // Check if at least one face was detected
      if (faces.isEmpty) {
        return SelfieValidationResult(
          isValid: false,
          errors: [
            'No face detected in the image. Please ensure your face is clearly visible and centered in the photo.',
          ],
        );
      }

      // Use the first/largest face - validate face data
      if (faces.isEmpty) {
        return SelfieValidationResult(
          isValid: false,
          errors: [
            'No face detected in the image. Please ensure your face is clearly visible and centered in the photo.',
          ],
        );
      }

      final face = faces.first;

      // Validate face bounding box
      if (face.boundingBox.width <= 0 || face.boundingBox.height <= 0) {
        return SelfieValidationResult(
          isValid: false,
          errors: ['Invalid face detection result. Please try again.'],
        );
      }

      final faceWidth = face.boundingBox.width;
      final faceHeight = face.boundingBox.height;
      final faceArea = faceWidth * faceHeight;
      final imageArea = width * height;

      // Prevent division by zero
      if (imageArea == 0) {
        return SelfieValidationResult(
          isValid: false,
          errors: ['Invalid image dimensions'],
        );
      }

      final facePercentage = (faceArea / imageArea) * 100;

      // Check if face is reasonably sized (at least 3% of image)
      if (facePercentage < 3) {
        return SelfieValidationResult(
          isValid: false,
          errors: [
            'Face is too small in the image. Please move closer to the camera so your face is clearly visible.',
          ],
        );
      }

      // Check if face is reasonably centered (within 50% of center - lenient)
      // Prevent division by zero
      if (width == 0 || height == 0) {
        return SelfieValidationResult(
          isValid: false,
          errors: ['Invalid image dimensions'],
        );
      }

      final faceCenterX = face.boundingBox.left + (faceWidth / 2);
      final faceCenterY = face.boundingBox.top + (faceHeight / 2);
      final imageCenterX = width / 2;
      final imageCenterY = height / 2;

      final offsetX = (faceCenterX - imageCenterX).abs() / width;
      final offsetY = (faceCenterY - imageCenterY).abs() / height;

      if (offsetX > 0.5 || offsetY > 0.5) {
        return SelfieValidationResult(
          isValid: false,
          errors: [
            'Face is not centered in the image. Please position your face in the center of the frame.',
          ],
        );
      }

      // Face detected and meets requirements
      return SelfieValidationResult(isValid: true, errors: []);
    } catch (e) {
      // If face detection fails, don't block validation
      // Return valid result so other validations can proceed
      return SelfieValidationResult(isValid: true, errors: []);
    } finally {
      // Clean up temporary files
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
        if (tempDir != null && await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    }
  }
}
