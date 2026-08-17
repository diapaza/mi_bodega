import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Indicador de progreso para formularios multi-paso.
class MbStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String>? labels;

  const MbStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: List.generate(totalSteps, (i) {
        final isActive = i == currentStep;
        final isCompleted = i < currentStep;
        return Expanded(
          child: Row(
            children: [
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isCompleted
                        ? colors.primary
                        : colors.outlineVariant,
                  ),
                ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? colors.primary
                      : isCompleted
                          ? colors.primaryContainer
                          : colors.surfaceContainer,
                  border: Border.all(
                    color: isActive
                        ? colors.primary
                        : isCompleted
                            ? colors.primary
                            : colors.outlineVariant,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check, size: 16, color: colors.primary)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? colors.onPrimary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              if (i < totalSteps - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isCompleted
                        ? colors.primary
                        : colors.outlineVariant,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
