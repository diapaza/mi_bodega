import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';

/// Pantalla inicial mientras se restaura la sesión.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.store, size: 72, color: colors.primary),
            const SizedBox(height: 16),
            Text(
              'MiBodega',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: colors.primary),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
