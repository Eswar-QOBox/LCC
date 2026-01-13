import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/submission_provider.dart';
import '../utils/app_routes.dart';
import '../widgets/platform_image.dart';
import '../widgets/step_progress_indicator.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_toast.dart';
import '../utils/app_theme.dart';

class Step2AadhaarScreen extends StatefulWidget {
  const Step2AadhaarScreen({super.key});

  @override
  State<Step2AadhaarScreen> createState() => _Step2AadhaarScreenState();
}

class _Step2AadhaarScreenState extends State<Step2AadhaarScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  String? _frontPath;
  String? _backPath;
  bool _isDraftSaved = false;
  bool _isSavingDraft = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SubmissionProvider>();
    _frontPath = provider.submission.aadhaar?.frontPath;
    _backPath = provider.submission.aadhaar?.backPath;
  }

  void _resetDraftState() {
    if (_isDraftSaved) {
      setState(() {
        _isDraftSaved = false;
      });
    }
  }

  Future<void> _captureFront() async {
    final image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image != null && mounted) {
      setState(() {
        _frontPath = image.path;
        _resetDraftState();
      });
      context.read<SubmissionProvider>().setAadhaarFront(image.path);
    }
  }

  Future<void> _selectFrontFromGallery() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() {
        _frontPath = image.path;
        _resetDraftState();
      });
      context.read<SubmissionProvider>().setAadhaarFront(image.path);
    }
  }

  Future<void> _captureBack() async {
    final image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image != null && mounted) {
      setState(() {
        _backPath = image.path;
        _resetDraftState();
      });
      context.read<SubmissionProvider>().setAadhaarBack(image.path);
    }
  }

  Future<void> _selectBackFromGallery() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() {
        _backPath = image.path;
        _resetDraftState();
      });
      context.read<SubmissionProvider>().setAadhaarBack(image.path);
    }
  }

  void _proceedToNext() {
    if (_frontPath != null && _backPath != null) {
      context.go(AppRoutes.step3Pan);
    } else {
      PremiumToast.showWarning(
        context,
        'Please upload both front and back sides of Aadhaar card',
      );
    }
  }

  Future<void> _saveDraft() async {
    if (_isSavingDraft || _isDraftSaved) return;

    setState(() {
      _isSavingDraft = true;
    });

    final provider = context.read<SubmissionProvider>();
    
    // Save current state to provider
    if (_frontPath != null) {
      provider.setAadhaarFront(_frontPath!);
    }
    if (_backPath != null) {
      provider.setAadhaarBack(_backPath!);
    }

    try {
      final success = await provider.saveDraft();
      
      if (mounted) {
        if (success) {
          setState(() {
            _isDraftSaved = true;
            _isSavingDraft = false;
          });
          PremiumToast.showSuccess(
            context,
            'Draft saved successfully!',
            duration: const Duration(seconds: 2),
          );
        } else {
          setState(() {
            _isSavingDraft = false;
          });
          PremiumToast.showError(
            context,
            'Failed to save draft. Please try again.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingDraft = false;
        });
        PremiumToast.showError(
          context,
          'Error saving draft: $e',
        );
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
        child: Column(
          children: [
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
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.credit_card,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Aadhaar Card',
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
                    onPressed: () => context.go(AppRoutes.step1Selfie),
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
            StepProgressIndicator(currentStep: 2, totalSteps: 6),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primary,
                                      colorScheme.secondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.badge,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Aadhaar Card Requirements',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Both sides required for verification',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildPremiumRequirement(context, Icons.photo_camera, 'Must include Front & Back'),
                          const SizedBox(height: 12),
                          _buildPremiumRequirement(context, Icons.visibility_off, 'No blur or glare'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Front & Back Side Preview
                    if (_frontPath != null && _backPath != null) ...[
                      // Use LayoutBuilder to handle overflow on small screens
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // On small screens, stack vertically; on larger screens, show side by side
                          if (constraints.maxWidth < 600) {
                            return Column(
                              children: [
                                _buildSidePreview(
                                  context,
                                  'Front',
                                  _frontPath!,
                                  onTap: _captureFront,
                                ),
                                const SizedBox(height: 16),
                                _buildSidePreview(
                                  context,
                                  'Back',
                                  _backPath!,
                                  onTap: _captureBack,
                                ),
                              ],
                            );
                          } else {
                            return Row(
                              children: [
                                Expanded(
                                  child: _buildSidePreview(
                                    context,
                                    'Front',
                                    _frontPath!,
                                    onTap: _captureFront,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildSidePreview(
                                    context,
                                    'Back',
                                    _backPath!,
                                    onTap: _captureBack,
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ] else ...[
                      // Front Side
                      Text(
                        'Front Side',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_frontPath != null)
                        _buildSidePreview(context, 'Front', _frontPath!, onTap: _captureFront)
                      else
                        _buildUploadCard(
                          context,
                          'Front Side',
                          Icons.credit_card,
                          onCamera: _captureFront,
                          onGallery: _selectFrontFromGallery,
                        ),
                      const SizedBox(height: 24),
                      // Back Side
                      Text(
                        'Back Side',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_backPath != null)
                        _buildSidePreview(context, 'Back', _backPath!, onTap: _captureBack)
                      else
                        _buildUploadCard(
                          context,
                          'Back Side',
                          Icons.credit_card,
                          onCamera: _captureBack,
                          onGallery: _selectBackFromGallery,
                        ),
                    ],
                    const SizedBox(height: 40),
                    // Save as Draft button
                    OutlinedButton.icon(
                      onPressed: _isDraftSaved ? null : _saveDraft,
                      icon: _isDraftSaved
                          ? const Icon(Icons.check_circle)
                          : (_isSavingDraft
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined)),
                      label: Text(_isDraftSaved
                          ? 'Draft Saved'
                          : (_isSavingDraft ? 'Saving...' : 'Save as Draft')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: _isDraftSaved
                            ? AppTheme.successColor
                            : null,
                        side: BorderSide(
                          color: _isDraftSaved
                              ? AppTheme.successColor
                              : colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    PremiumButton(
                      label: 'Continue to PAN Card',
                      icon: Icons.arrow_forward_rounded,
                      isPrimary: true,
                      onPressed: _proceedToNext,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumRequirement(BuildContext context, IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildSidePreview(
    BuildContext context,
    String label,
    String path,
    {required VoidCallback onTap}
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              PlatformImage(imagePath: path, fit: BoxFit.cover),
              Positioned(
                top: 12,
                left: 12,
                right: 60, // Reserve space for camera button to prevent overflow
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  constraints: const BoxConstraints(
                    maxWidth: double.infinity,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              // Camera icon button overlay
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.white, size: 24),
                    onPressed: onTap,
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.1),
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

  Widget _buildUploadCard(
    BuildContext context,
    String title,
    IconData icon, {
    required VoidCallback onCamera,
    required VoidCallback onGallery,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return PremiumCard(
      gradientColors: [
        Colors.white,
        colorScheme.primary.withValues(alpha: 0.02),
      ],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.1),
                  colorScheme.secondary.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Icon(icon, size: 48, color: colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          // Use Flexible/Expanded with proper constraints to prevent overflow
          LayoutBuilder(
            builder: (context, constraints) {
              // On very small screens, stack buttons vertically
              if (constraints.maxWidth < 300) {
                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: PremiumButton(
                        label: 'Camera',
                        icon: Icons.camera_alt,
                        isPrimary: false,
                        onPressed: onCamera,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: PremiumButton(
                        label: 'Gallery',
                        icon: Icons.photo_library,
                        isPrimary: false,
                        onPressed: onGallery,
                      ),
                    ),
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(
                      child: PremiumButton(
                        label: 'Camera',
                        icon: Icons.camera_alt,
                        isPrimary: false,
                        onPressed: onCamera,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PremiumButton(
                        label: 'Gallery',
                        icon: Icons.photo_library,
                        isPrimary: false,
                        onPressed: onGallery,
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

