import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Widget raíz de MiBodega.
class MiBodegaApp extends ConsumerWidget {
  const MiBodegaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return ToastificationWrapper(
      child: MaterialApp.router(
        title: 'MiBodega',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: router,
      ),
    );
  }
}
