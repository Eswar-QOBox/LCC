import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A lightweight "slide to confirm" control (similar to slide-to-pay).
///
/// - Drag the thumb to the end to trigger [onSubmitted]
/// - Shows a loading spinner while the callback is running
/// - Resets back to start after completion (success or error)
class SlideToConfirm extends StatefulWidget {
  final String label;
  final bool enabled;
  final Future<void> Function()? onSubmitted;
  final double height;
  final BorderRadius borderRadius;

  const SlideToConfirm({
    super.key,
    required this.label,
    this.enabled = true,
    this.onSubmitted,
    this.height = 56,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm>
    with SingleTickerProviderStateMixin {
  static const double _thumbPadding = 6;
  static const double _completeThreshold = 0.92; // percent of track

  double _dragX = 0; // pixels
  bool _isSubmitting = false;

  late final AnimationController _snapController;
  Animation<double>? _snapAnimation;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() {
        final anim = _snapAnimation;
        if (anim != null) {
          setState(() => _dragX = anim.value);
        }
      });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _snapController.stop();
    _snapController.reset();
    _snapAnimation = Tween<double>(begin: _dragX, end: target).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    );
    _snapController.forward();
  }

  Future<void> _triggerSubmit() async {
    if (_isSubmitting) return;
    if (!widget.enabled) return;
    final cb = widget.onSubmitted;
    if (cb == null) return;

    setState(() => _isSubmitting = true);
    try {
      await cb();
    } finally {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _animateTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = widget.height;
        final thumbSize = h - (_thumbPadding * 2);
        final maxX = math.max(0.0, w - thumbSize - (_thumbPadding * 2));
        final clampedX = _dragX.clamp(0.0, maxX);
        final progress = maxX == 0 ? 0.0 : (clampedX / maxX);
        final isEnabled = widget.enabled && !_isSubmitting && widget.onSubmitted != null;

        final bgGradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.enabled
              ? [colorScheme.primary, colorScheme.secondary]
              : [
                  colorScheme.surfaceContainerHighest,
                  colorScheme.surfaceContainerHighest,
                ],
        );

        return Semantics(
          label: widget.label,
          button: true,
          enabled: isEnabled,
          child: Container(
            height: h,
            decoration: BoxDecoration(
              gradient: bgGradient,
              borderRadius: widget.borderRadius,
              boxShadow: widget.enabled
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Label (fade out as user drags)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  opacity: 1 - (progress * 0.7),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: h),
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: widget.enabled
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                // Subtle arrow hint on the right
                Positioned(
                  right: 14,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: widget.enabled ? (0.9 - progress).clamp(0.0, 0.9) : 0.0,
                      child: Icon(
                        Icons.double_arrow_rounded,
                        color: colorScheme.onPrimary.withValues(alpha: 0.85),
                        size: 20,
                      ),
                    ),
                  ),
                ),

                // Thumb
                Positioned(
                  left: _thumbPadding + clampedX,
                  child: GestureDetector(
                    onHorizontalDragStart: isEnabled ? (_) => _snapController.stop() : null,
                    onHorizontalDragUpdate: isEnabled
                        ? (details) {
                            setState(() {
                              _dragX = (_dragX + details.delta.dx).clamp(0.0, maxX);
                            });
                          }
                        : null,
                    onHorizontalDragEnd: isEnabled
                        ? (_) async {
                            if (progress >= _completeThreshold) {
                              _animateTo(maxX);
                              await _triggerSubmit();
                            } else {
                              _animateTo(0);
                            }
                          }
                        : null,
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        color: widget.enabled ? Colors.white : colorScheme.surface,
                        borderRadius: BorderRadius.circular(thumbSize / 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isSubmitting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.primary,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.arrow_forward_rounded,
                                color: widget.enabled
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

