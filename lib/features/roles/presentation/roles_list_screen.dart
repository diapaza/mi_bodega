import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/mb_badge.dart';
import '../../../shared/widgets/mb_empty_state.dart';
import '../../auth/domain/entities/auth.dart';
import '../../auth/presentation/session_controller.dart';
import '../../users/presentation/users_providers.dart';

/// Lista de roles del sistema.
class RolesListScreen extends ConsumerWidget {
  const RolesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final canManage = session?.can('roles.manage') ?? false;

    final rolesAsync = ref.watch(rolesProvider);
    final usersAsync = ref.watch(usersProvider);
    final users = usersAsync.valueOrNull ?? const <AppUser>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Roles y permisos')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/roles/new'),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo rol'),
            )
          : null,
      body: rolesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (roles) {
          if (roles.isEmpty) {
            return const MbEmptyState(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Sin roles',
              message: 'No hay roles configurados.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: roles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = roles[i];
              final count = users.where((u) => u.roleId == r.id).length;
              return Card(
                child: ListTile(
                  onTap: () => context.push('/roles/${r.id}'),
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text(r.name),
                  subtitle: Text(
                    r.description ??
                        '$count usuario${count == 1 ? '' : 's'} asignado${count == 1 ? '' : 's'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (r.isSystem)
                        const MbBadge('Sistema', tone: MbBadgeTone.info),
                      if (!r.active) ...[
                        const SizedBox(width: 6),
                        const MbBadge('Inactivo', tone: MbBadgeTone.warning),
                      ],
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
