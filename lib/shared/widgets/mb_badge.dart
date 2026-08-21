import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum MbBadgeTone { neutral, primary, success, warning, error, info }

/// Badge/etiqueta de estado.
class MbBadge extends StatelessWidget {
  final String label;
  final MbBadgeTone tone;

  const MbBadge(this.label, {super.key, this.tone = MbBadgeTone.neutral});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (bg, fg) = switch (tone) {
      MbBadgeTone.neutral => (colors.surfaceVariant, colors.onSurfaceVariant),
      MbBadgeTone.primary => (colors.primaryContainer, colors.onPrimaryContainer),
      MbBadgeTone.success => (colors.successContainer, colors.onSuccessContainer),
      MbBadgeTone.warning => (colors.warningContainer, colors.onWarningContainer),
      MbBadgeTone.error => (colors.errorContainer, colors.onErrorContainer),
      MbBadgeTone.info => (colors.infoContainer, colors.onInfoContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}
