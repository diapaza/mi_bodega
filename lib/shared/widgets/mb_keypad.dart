import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Teclado numérico reutilizable para ingreso de montos.
class MbKeypad extends StatelessWidget {
  final String receivedText;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const MbKeypad({
    super.key,
    required this.receivedText,
    required this.onKey,
    required this.onBackspace,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', '⌫'];
    return Column(
      children: [
        Text(
          receivedText.isEmpty ? '—' : 'S/$receivedText',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.8,
          children: [
            for (final k in keys)
              Material(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    if (k == 'C') {
                      onClear();
                    } else if (k == '⌫') {
                      onBackspace();
                    } else {
                      onKey(k);
                    }
                  },
                  child: Center(
                    child: k == '⌫'
                        ? const Icon(Icons.backspace_outlined)
                        : Text(
                            k,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
