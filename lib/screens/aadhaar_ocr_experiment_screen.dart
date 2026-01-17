import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/aadhaar_ocr_service.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_toast.dart';
import '../utils/app_theme.dart';
import '../widgets/platform_image.dart';

/// Experimental screen for testing Aadhaar OCR functionality
class AadhaarOCRExperimentScreen extends StatefulWidget {
  const AadhaarOCRExperimentScreen({super.key});

  @override
  State<AadhaarOCRExperimentScreen> createState() => _AadhaarOCRExperimentScreenState();
}

class _AadhaarOCRExperimentScreenState extends State<AadhaarOCRExperimentScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final AadhaarOCRService _ocrService = AadhaarOCRService();
  
  File? _image;
  String _rawText = '';
  Map<String, dynamic> _parsedFields = {};
  bool _isProcessing = false;
  bool _hasResults = false;

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (pickedFile != null && mounted) {
        setState(() {
          _image = File(pickedFile.path);
          _rawText = '';
          _parsedFields = {};
          _hasResults = false;
        });
      }
    } catch (e) {
      if (mounted) {
        PremiumToast.showError(
          context,
          'Failed to pick image: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _captureImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (pickedFile != null && mounted) {
        setState(() {
          _image = File(pickedFile.path);
          _rawText = '';
          _parsedFields = {};
          _hasResults = false;
        });
      }
    } catch (e) {
      if (mounted) {
        PremiumToast.showError(
          context,
          'Failed to capture image: ${e.toString()}\n\nPlease check camera permissions in app settings.',
        );
      }
    }
  }

  Future<void> _runOCR() async {
    if (_image == null) {
      PremiumToast.showWarning(
        context,
        'Please select an image first',
      );
      return;
    }

    // Check if file exists
    if (!await _image!.exists()) {
      PremiumToast.showError(
        context,
        'Image file not found. Please select the image again.',
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _hasResults = false;
    });

    try {
      final result = await _ocrService.processAadhaarImage(_image!);
      
      if (mounted) {
        final rawText = result['rawText'] ?? '';
        final parsedFields = result['parsedFields'] ?? <String, dynamic>{};
        
        // Debug output
        debugPrint('OCR Result - Success: ${result['success']}');
        debugPrint('OCR Result - Raw Text Length: ${rawText.length}');
        debugPrint('OCR Result - Parsed Fields Count: ${parsedFields.length}');
        if (result['error'] != null) {
          debugPrint('OCR Result - Error: ${result['error']}');
        }
        if (rawText.isNotEmpty) {
          debugPrint('OCR Result - Raw Text Preview: ${rawText.substring(0, rawText.length > 100 ? 100 : rawText.length)}...');
        }
        
        setState(() {
          _rawText = rawText;
          _parsedFields = parsedFields;
          _hasResults = true;
          _isProcessing = false;
        });

        if (result['success'] == true) {
          if (rawText.isEmpty) {
            PremiumToast.showWarning(
              context,
              'OCR completed but no text was detected. Try a clearer image.',
            );
          } else {
            PremiumToast.showSuccess(
              context,
              'OCR completed! Found ${parsedFields.length} fields.',
            );
          }
        } else {
          final errorMsg = result['error'] ?? 'Unknown error';
          debugPrint('OCR Error Details: $errorMsg');
          PremiumToast.showError(
            context,
            'OCR failed: ${errorMsg.length > 100 ? errorMsg.substring(0, 100) + "..." : errorMsg}',
          );
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        PremiumToast.showError(
          context,
          'Error processing image: ${e.toString()}',
        );
        // Print stack trace for debugging
        debugPrint('OCR Error: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.08),
              colorScheme.secondary.withValues(alpha: 0.04),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      colorScheme.primary.withValues(alpha: 0.03),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: AppBar(
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary,
                              colorScheme.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.text_fields,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Aadhaar OCR Experiment',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  leading: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Info Card
                      PremiumCard(
                        gradientColors: [
                          Colors.white,
                          colorScheme.primary.withValues(alpha: 0.03),
                        ],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        colorScheme.primary,
                                        colorScheme.secondary,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.info_outline,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'ML Kit OCR Experiment',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'This is an experimental screen for testing Aadhaar card OCR using Google ML Kit. Pick or capture an Aadhaar card image to extract text and parse fields.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Image Selection Buttons
                      Row(
                        children: [
                          Expanded(
                            child: PremiumButton(
                              label: 'Pick from Gallery',
                              icon: Icons.photo_library,
                              isPrimary: false,
                              onPressed: _pickImage,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PremiumButton(
                              label: 'Capture',
                              icon: Icons.camera_alt,
                              isPrimary: false,
                              onPressed: _captureImage,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Image Preview
                      if (_image != null) ...[
                        PremiumCard(
                          gradientColors: [
                            Colors.white,
                            colorScheme.primary.withValues(alpha: 0.03),
                          ],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Image',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                height: 300,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.outline.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: PlatformImage(
                                    imagePath: _image!.path,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              PremiumButton(
                                label: _isProcessing ? 'Processing...' : 'Run OCR',
                                icon: _isProcessing ? Icons.hourglass_empty : Icons.text_fields,
                                isPrimary: true,
                                onPressed: _isProcessing ? null : _runOCR,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Results Section
                      if (_hasResults) ...[
                        // Parsed Fields
                        if (_parsedFields.isNotEmpty) ...[
                          PremiumCard(
                            gradientColors: [
                              Colors.white,
                              AppTheme.successColor.withValues(alpha: 0.05),
                            ],
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: AppTheme.successColor,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Extracted Fields',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ..._parsedFields.entries.map((entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildFieldRow(
                                    context,
                                    entry.key,
                                    entry.value?.toString() ?? '',
                                  ),
                                )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ] else ...[
                          // Show message if no fields extracted
                          PremiumCard(
                            gradientColors: [
                              Colors.white,
                              AppTheme.warningColor.withValues(alpha: 0.05),
                            ],
                            child: Column(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: AppTheme.warningColor,
                                  size: 32,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No Fields Extracted',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Could not extract structured fields from the image. Check the raw text below.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        
                        // Raw Text - Always show
                        PremiumCard(
                          gradientColors: [
                            Colors.white,
                            colorScheme.primary.withValues(alpha: 0.03),
                          ],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.code,
                                    color: colorScheme.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Raw OCR Text',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: SelectableText(
                                  _rawText.isEmpty ? 'No text detected' : _rawText,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              _formatFieldLabel(label),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFieldLabel(String key) {
    // Convert snake_case to Title Case
    return key
        .split('_')
        .map((word) => word.isEmpty
            ? ''
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}
