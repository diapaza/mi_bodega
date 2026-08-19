import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../shared/widgets/mb_button.dart';

class ProductFormNavBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final bool isEditing;
  final bool saving;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onSave;

  const ProductFormNavBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.isEditing,
    required this.saving,
    this.onPrevious,
    required this.onNext,
    this.onSave,
  });

  bool get _isLastStep => currentStep == totalSteps - 1;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (currentStep > 0)
              Expanded(
                child: MbButton(
                  label: 'Anterior',
                  variant: MbButtonVariant.outlined,
                  icon: LucideIcons.arrow_left,
                  onPressed: saving ? null : onPrevious,
                ),
              ),
            if (currentStep > 0) const SizedBox(width: 12),
            if (_isLastStep)
              Expanded(
                child: MbButton(
                  label: isEditing ? 'Guardar cambios' : 'Crear producto',
icon: LucideIcons.check,
                   loading: saving,
                  onPressed: saving ? null : onSave,
                ),
              )
            else
              Expanded(
                child: MbButton(
                  label: 'Siguiente',
                  icon: LucideIcons.arrow_right,
                  onPressed: saving ? null : onNext,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
