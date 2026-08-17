import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/security/permission_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mb_button.dart';
import '../../../shared/widgets/mb_snackbar.dart';
import '../../../shared/widgets/mb_text_field.dart';
import '../../auth/domain/entities/auth.dart';
import '../../auth/domain/entities/permission_catalog.dart';
import '../../auth/presentation/session_controller.dart';
import '../../users/presentation/users_providers.dart';

/// Crear o editar un rol y asignar permisos por módulo.
class RoleEditScreen extends ConsumerStatefulWidget {
  final int? roleId;

  const RoleEditScreen({super.key, this.roleId});

  @override
  ConsumerState<RoleEditScreen> createState() => _RoleEditScreenState();
}

class _RoleEditScreenState extends ConsumerState<RoleEditScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _active = true;
  bool _isSystem = false;
  bool _saving = false;
  Set<int> _selected = {};
  Map<String, List<Permission>> _byModule = {};
  bool _loaded = false;

  bool get _isEditing => widget.roleId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(authRepositoryProvider);
    final permissions = await repo.allPermissions();
    final all = permissions.orNull ?? const <Permission>[];
    _byModule = {
      for (final m in PermissionCatalog.modules)
        m: all.where((p) => p.module == m).toList(),
    };

    if (_isEditing) {
      final role = (ref.read(rolesProvider).valueOrNull ?? const <Role>[])
          .where((r) => r.id == widget.roleId)
          .firstOrNull;
      if (role != null) {
        _name.text = role.name;
        _description.text = role.description ?? '';
        _active = role.active;
        _isSystem = role.isSystem;
        final current = await repo.permissionsForRole(role.id!);
        _selected = current.orNull?.map((p) => p.id!).toSet() ?? {};
      }
    } else {
      _selected = all.map((p) => p.id!).toSet();
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final guard =
        ensureAllowed(ref.read(sessionPermissionsProvider), 'roles.manage');
    if (guard.isErr) {
      if (mounted) {
        showMbSnack(context, guard.failure!.message);
      }
      return;
    }
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final repo = ref.read(authRepositoryProvider);
    final result = _isEditing
        ? await repo.updateRole(
            Role(
              id: widget.roleId,
              name: name,
              description: _description.text.trim().isEmpty
                  ? null
                  : _description.text.trim(),
              isSystem: _isSystem,
              active: _active,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            permissionIds: _selected.toList(),
          )
        : await repo.createRole(RoleDraft(
            name: name,
            description:
                _description.text.trim().isEmpty ? null : _description.text.trim(),
            permissionIds: _selected.toList(),
          ));
    if (!mounted) return;
    if (result.isErr) {
      setState(() => _saving = false);
      showMbSnack(context, result.failure!.message);
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final canManage = session?.can('roles.manage') ?? false;
    final readOnly = _isSystem || !canManage;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar rol' : 'Nuevo rol')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (readOnly)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _Notice(text: _isSystem
                            ? 'Rol del sistema: no se puede modificar.'
                            : 'No tienes permiso para editar roles.'),
                      ),
                    MbTextField(
                      controller: _name,
                      label: 'Nombre *',
                      enabled: !readOnly,
                    ),
                    const SizedBox(height: 12),
                    MbTextField(
                      controller: _description,
                      label: 'Descripción',
                      maxLines: 2,
                      enabled: !readOnly,
                    ),
                    if (_isEditing) ...[
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Activo'),
                        value: _active,
                        onChanged: readOnly
                            ? null
                              : (v) async {
                                final guard = ensureAllowed(ref
                                    .read(sessionPermissionsProvider), 'roles.manage');
                                if (guard.isErr) {
                                  if (context.mounted) {
                                    showMbSnack(context, guard.failure!.message);
                                  }
                                  return;
                                }
                                setState(() => _active = v);
                                await ref
                                    .read(authRepositoryProvider)
                                    .setRoleActive(widget.roleId!, v);
                              },
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text('Permisos', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final module in PermissionCatalog.modules) ...[
                      _ModulePermissions(
                        module: module,
                        permissions: _byModule[module] ?? const [],
                        selected: _selected,
                        enabled: !readOnly,
                        onToggle: (id, checked) {
                          setState(() {
                            if (checked) {
                              _selected.add(id);
                            } else {
                              _selected.remove(id);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!readOnly) ...[
                      const SizedBox(height: 16),
                      MbButton(
                        label: _isEditing ? 'Guardar cambios' : 'Crear rol',
                        icon: Icons.check,
                        loading: _saving,
                        onPressed: _saving ? null : _save,
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _ModulePermissions extends StatelessWidget {
  final String module;
  final List<Permission> permissions;
  final Set<int> selected;
  final bool enabled;
  final void Function(int id, bool checked) onToggle;

  const _ModulePermissions({
    required this.module,
    required this.permissions,
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            module.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          for (final p in permissions)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(p.name),
              subtitle: Text(p.code),
              value: selected.contains(p.id),
              onChanged: enabled
                  ? (v) => onToggle(p.id!, v ?? false)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;

  const _Notice({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.warningContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colors.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: colors.onWarning)),
          ),
        ],
      ),
    );
  }
}
