import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_bodega/core/di/app_providers.dart';
import 'package:mi_bodega/features/auth/domain/entities/auth.dart';
import 'package:mi_bodega/features/auth/presentation/session_controller.dart';

/// Usuarios de la tienda activa (stream reactivo).
final usersProvider = StreamProvider<List<AppUser>>((ref) {
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return const Stream.empty();
  return ref.watch(authRepositoryProvider).watchUsers(storeId);
});

/// Roles del sistema (stream reactivo).
final rolesProvider = StreamProvider<List<Role>>((ref) {
  return ref.watch(authRepositoryProvider).watchRoles();
});
