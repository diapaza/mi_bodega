import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/security/permission_guard.dart';
import '../../../shared/widgets/mb_button.dart';
import '../../../shared/widgets/mb_confirm_dialog.dart';
import '../../../shared/widgets/mb_snackbar.dart';
import '../../../shared/widgets/mb_text_field.dart';
import '../../auth/domain/entities/auth.dart';
import '../../auth/presentation/session_controller.dart';
import 'users_providers.dart';

/// Crear o editar un usuario. Con `userId` nulo crea, si no edita.
class UserFormScreen extends ConsumerStatefulWidget {
  final int? userId;

  const UserFormScreen({super.key, this.userId});

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _pin = TextEditingController();
  int? _roleId;
  int? _originalRoleId;
  bool _active = true;
  bool _saving = false;
  bool _dirty = false;

  bool get _isEditing => widget.userId != null;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void initState() {
    super.initState();
    _fullName.addListener(_markDirty);
    _username.addListener(_markDirty);
    _pin.addListener(_markDirty);
    if (_isEditing) {
      final users = ref.read(usersProvider).valueOrNull ?? const <AppUser>[];
      final user = users.where((u) => u.id == widget.userId).firstOrNull;
      if (user != null) {
        _fullName.text = user.fullName;
        _username.text = user.username;
        _roleId = user.roleId;
        _originalRoleId = user.roleId;
        _active = user.active;
      }
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final guard = ensureAllowed(
      ref.read(sessionPermissionsProvider),
      _isEditing ? 'users.edit' : 'users.create',
    );
    if (guard.isErr) {
      if (mounted) {
        showMbSnack(context, guard.failure!.message);
      }
      return;
    }
    final fullName = _fullName.text.trim();
    final username = _username.text.trim();
    if (fullName.isEmpty || username.isEmpty || _roleId == null) {
      showMbSnack(context, 'Completa los campos obligatorios.');
      return;
    }
    if (!_isEditing && _pin.text.length < 4) {
      showMbSnack(context, 'El PIN debe tener al menos 4 dígitos.');
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(authRepositoryProvider);
    // Si el rol cambió, persistir.
    if (_isEditing && _roleId != null && _originalRoleId != null && _roleId != _originalRoleId) {
      await ref.read(authRepositoryProvider).changeRole(widget.userId!, _roleId!);
    }
    final result = _isEditing
        ? await repo.updateUserDetails(
            widget.userId!,
            fullName: fullName,
            username: username,
          )
        : await repo.createUser(UserDraft(
            storeId: ref.read(sessionControllerProvider).valueOrNull?.store?.id ?? 0,
            fullName: fullName,
            username: username,
            pin: _pin.text,
            roleId: _roleId!,
          ));
    if (result.isErr) {
      setState(() => _saving = false);
      if (mounted) {
        showMbSnack(context, result.failure!.message);
      }
      return;
    }
    if (!mounted) return;
    context.pop();
  }

  Future<void> _resetPin() async {
    final guard =
        ensureAllowed(ref.read(sessionPermissionsProvider), 'users.reset_pin');
    if (guard.isErr) {
      if (mounted) {
        showMbSnack(context, guard.failure!.message);
      }
      return;
    }
    final controller = TextEditingController();
    final newPin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restablecer PIN'),
        content: MbTextField(
          controller: controller,
          label: 'Nuevo PIN (4-6 dígitos)',
          keyboardType: TextInputType.number,
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (newPin == null || newPin.length < 4) return;
    final repo = ref.read(authRepositoryProvider);
    final res = await repo.resetPin(widget.userId!, newPin);
    if (!mounted) return;
    showMbSnack(context, res.isOk ? 'PIN actualizado' : res.failure!.message);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final canResetPin = session?.can('users.reset_pin') ?? false;
    final canDisable = session?.can('users.disable') ?? false;
    final roles = ref.watch(rolesProvider).valueOrNull ?? const <Role>[];

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_dirty) return;
        final confirmed = await showMbConfirm(
          context,
          title: 'Cambios sin guardar',
          message: 'Tienes cambios sin guardar. ¿Deseas salir?',
          confirmLabel: 'Salir',
          cancelLabel: 'Quedarme',
        );
        if (confirmed == true && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Editar usuario' : 'Nuevo usuario'),
          actions: [
            if (_isEditing && canResetPin)
              IconButton(
                tooltip: 'Restablecer PIN',
                icon: const Icon(LucideIcons.key_round),
                onPressed: _resetPin,
              ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MbTextField(
                  controller: _fullName,
                  label: 'Nombre completo *',
                ),
                const SizedBox(height: 12),
                MbTextField(
                  controller: _username,
                  label: 'Usuario *',
                  textCapitalization: TextCapitalization.none,
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: 12),
                  MbTextField(
                    controller: _pin,
                    label: 'PIN (4-6 dígitos) *',
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _roleId,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: [
                    for (final r in roles.where((r) => r.active))
                      DropdownMenuItem(value: r.id, child: Text(r.name)),
                  ],
                  onChanged: (v) => setState(() => _roleId = v),
                ),
                if (_isEditing && canDisable) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activo'),
                    value: _active,
                    onChanged: (v) async {
                      setState(() => _active = v);
                      await ref
                          .read(authRepositoryProvider)
                          .setActive(widget.userId!, v);
                    },
                  ),
                ],
                const SizedBox(height: 24),
                MbButton(
                  label: _isEditing ? 'Guardar cambios' : 'Crear usuario',
icon: LucideIcons.check,
                   loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
