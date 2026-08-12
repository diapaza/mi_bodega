import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/security/permission_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mb_badge.dart';
import '../../../shared/widgets/mb_empty_state.dart';
import '../../auth/domain/entities/auth.dart';
import '../../auth/presentation/session_controller.dart';
import 'users_providers.dart';

/// Lista de usuarios de la tienda (administración).
class UsersListScreen extends ConsumerWidget {
  const UsersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final canCreate = session?.can('users.create') ?? false;
    final canDisable = session?.can('users.disable') ?? false;

    final usersAsync = ref.watch(usersProvider);
    final rolesAsync = ref.watch(rolesProvider);

    final roles = rolesAsync.valueOrNull ?? const <Role>[];
    String roleName(int? id) =>
        roles.where((r) => r.id == id).map((r) => r.name).firstOrNull ?? '—';

    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/users/new'),
              icon: const Icon(Icons.person_add),
              label: const Text('Nuevo'),
            )
          : null,
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (users) {
          if (users.isEmpty) {
            return MbEmptyState(
              icon: Icons.people_outline,
              title: 'Sin usuarios',
              message: 'Crea el primer vendedor para tu tienda.',
              action: canCreate
                  ? FilledButton.icon(
                      onPressed: () => context.push('/users/new'),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Crear usuario'),
                    )
                  : null,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final u = users[i];
              return MbUserCard(
                user: u,
                roleName: roleName(u.roleId),
                canDisable: canDisable,
                onTap: () => context.push('/users/${u.id}'),
              );
            },
          );
        },
      ),
    );
  }
}

class MbUserCard extends ConsumerWidget {
  final AppUser user;
  final String roleName;
  final bool canDisable;
  final VoidCallback onTap;

  const MbUserCard({
    super.key,
    required this.user,
    required this.roleName,
    required this.canDisable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Card(
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          child: Text(
            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
            style: TextStyle(color: colors.onPrimaryContainer),
          ),
        ),
        title: Text(user.fullName),
        subtitle: Text('@${user.username} · $roleName'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!user.active)
              const MbBadge('Inactivo', tone: MbBadgeTone.warning),
            if (user.isOwner) ...[
              const SizedBox(width: 6),
              const MbBadge('Dueño', tone: MbBadgeTone.info),
            ],
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              enabled: canDisable,
              onSelected: (value) async {
                if (value == 'toggle') {
                  final guard = ensureAllowed(
                      ref.read(sessionPermissionsProvider), 'users.disable');
                  if (guard.isErr) {
                    _showSnack(context, guard.failure!.message);
                    return;
                  }
                  final repo = ref.read(authRepositoryProvider);
                  final res = await repo.setActive(user.id!, !user.active);
                  res.fold(
                    (_) => _showSnack(context,
                        user.active ? 'Usuario desactivado' : 'Usuario activado'),
                    (f) => _showSnack(context, f.message),
                  );
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(user.active ? 'Desactivar' : 'Activar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
