import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

class PremiumProgressIndicator extends StatelessWidget {
  const PremiumProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.maxVisibleSteps = 7,
  });

  final int currentStep;
  final int totalSteps;
  final int maxVisibleSteps;

  List<int> _visibleSteps(int current, int total, int maxVisible) {
    if (total <= maxVisible) {
      return List<int>.generate(total, (i) => i + 1);
    }

    final c = current.clamp(1, total);

    // Always show: first, last, and a window around current.
    // Keep exactly maxVisible items (no ellipsis), with real step numbers.
    if (c <= 4) {
      // Near start: show 1..(maxVisible-1) plus last.
      final headCount = maxVisible - 1;
      final head = List<int>.generate(headCount, (i) => i + 1); // 1..headCount
      return [...head, total];
    }

    if (c >= total - 3) {
      // Near end: show first plus last (maxVisible-1) steps.
      final tailCount = maxVisible - 1;
      final start = (total - tailCount + 1).clamp(1, total);
      final tail = List<int>.generate(tailCount, (i) => start + i);
      return [1, ...tail];
    }

    // Middle: show first, (c-2..c+2), last  => 1 + 5 + 1 = 7
    final mid = <int>[c - 2, c - 1, c, c + 1, c + 2];
    final set = <int>{1, ...mid, total}..removeWhere((x) => x < 1 || x > total);
    final list = set.toList()..sort();

    // Ensure we return exactly maxVisible items (should be already).
    if (list.length > maxVisible) {
      // If trimming is needed, prefer keeping first/last/current and closest neighbors.
      final keep = <int>[1, c - 1, c, c + 1, total]
        ..removeWhere((x) => x < 1 || x > total);
      final keepSet = <int>{...keep};
      final candidates = list.where((x) => keepSet.contains(x)).toList()..sort();
      // Fill remaining from nearest to current.
      final remaining = list.where((x) => !keepSet.contains(x)).toList()
        ..sort((a, b) => (a - c).abs().compareTo((b - c).abs()));
      while (candidates.length < maxVisible && remaining.isNotEmpty) {
        candidates.add(remaining.removeAt(0));
        candidates.sort();
      }
      return candidates.take(maxVisible).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final safeTotal = totalSteps < 1 ? 1 : totalSteps;
    final step = currentStep.clamp(1, safeTotal);
    final visible = _visibleSteps(step, safeTotal, maxVisibleSteps);

    Widget buildCircle(int n) {
      final isCompleted = n < step;
      final isCurrent = n == step;

      if (isCompleted) {
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.check,
            color: Colors.white,
            size: 16,
          ),
        );
      }

      if (isCurrent) {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryColor,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                blurRadius: 12,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$n',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        );
      }

      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$n',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    Color connectorColor(int a, int b) {
      // If we are skipping steps (e.g. 6 -> 10), keep connector neutral.
      if ((b - a).abs() > 1) {
        return Colors.grey.shade200;
      }
      // Only mark connector as completed when BOTH ends are completed.
      if (a < step && b < step) {
        return AppTheme.primaryColor.withValues(alpha: 0.3);
      }
      return Colors.grey.shade200;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      color: Colors.white,
      child: Row(
        children: [
          for (int idx = 0; idx < visible.length; idx++) ...[
            if (idx < visible.length - 1)
              Expanded(
                child: Row(
                  children: [
                    buildCircle(visible[idx]),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final a = visible[idx];
                          final b = visible[idx + 1];
                          final isGap = (b - a).abs() > 1;
                          final lineColor = connectorColor(a, b);

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(height: 2, color: lineColor),
                                if (isGap)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '…',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            else
              buildCircle(visible[idx]),
          ],
        ],
      ),
    );
  }
}

