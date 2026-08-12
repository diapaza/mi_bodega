import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/security/permission_guard.dart';
import '../../../shared/widgets/mb_badge.dart';
import '../../../shared/widgets/mb_snackbar.dart';
import '../../../shared/widgets/mb_text_field.dart';
import '../../auth/presentation/session_controller.dart';
import '../../store/domain/entities/store.dart';
import '../data/services/drive_client.dart';
import '../domain/entities/backup.dart';
import 'backup_providers.dart';

/// Copia de seguridad: cuenta de Google, backup, restore y configuración.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _working = false;
  bool _autoBackup = false;
  bool _includePhotos = true;
  bool _encrypt = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final coordinator = ref.read(backupCoordinatorProvider);
    final values = await Future.wait([
      coordinator.getSetting(SettingKeys.autoBackup),
      coordinator.getSetting(SettingKeys.backupIncludePhotos),
      coordinator.getSetting(SettingKeys.backupEncryption),
    ]);
    if (!mounted) return;
    setState(() {
      _autoBackup = values[0] == 'true';
      _includePhotos = values[1] != 'false';
      _encrypt = values[2] == 'true';
    });
  }

  Future<void> _set(String key, String value) async {
    await ref.read(backupCoordinatorProvider).putSetting(key, value);
  }

  Future<void> _connect() async {
    setState(() => _working = true);
    final coordinator = ref.read(backupCoordinatorProvider);
    final result = await coordinator.connectDrive();
    if (!mounted) return;
    setState(() => _working = false);
    showMbSnack(context,
        result.isOk && result.orNull != null
            ? 'Conectado como ${result.orNull}'
            : (result.failure?.message ?? 'No se pudo conectar'),
        variant: result.isOk && result.orNull != null
            ? MbSnackVariant.success
            : MbSnackVariant.error);
    ref.invalidate(driveEmailProvider);
  }

  Future<void> _disconnect() async {
    await ref.read(backupCoordinatorProvider).disconnectDrive();
    ref.invalidate(driveEmailProvider);
  }

  Future<void> _createBackup() async {
    final guard =
        ensureAllowed(ref.read(sessionPermissionsProvider), 'backup.create');
    if (guard.isErr) {
      if (mounted) {
        showMbSnack(context, guard.failure!.message, variant: MbSnackVariant.error);
      }
      return;
    }
    setState(() => _working = true);
    final storeId = ref.read(sessionControllerProvider).valueOrNull?.store?.id;
    if (storeId == null) {
      setState(() => _working = false);
      return;
    }
    final deviceId = ref.read(deviceIdProvider);
    final coordinator = ref.read(backupCoordinatorProvider);
    final result = await coordinator.backupToDrive(
      storeId: storeId,
      deviceId: deviceId,
      appVersion: '1.0.0',
    );
    if (!mounted) return;
    setState(() => _working = false);
    showMbSnack(context,
        result.isOk ? 'Backup subido a Drive' : (result.failure?.message ?? 'Error'),
        variant: result.isOk ? MbSnackVariant.success : MbSnackVariant.error);
    ref.invalidate(driveBackupsProvider);
    ref.invalidate(localBackupsProvider);
  }

  Future<void> _restore(DriveBackupFile file) async {
    final guard =
        ensureAllowed(ref.read(sessionPermissionsProvider), 'backup.restore');
    if (guard.isErr) {
      if (mounted) {
        showMbSnack(context, guard.failure!.message, variant: MbSnackVariant.error);
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar respaldo'),
        content: Text(
          'Se reemplazarán TODOS los datos locales actuales con el respaldo '
          '«${file.name}». Se creará un respaldo de seguridad antes. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _working = true);
    final coordinator = ref.read(backupCoordinatorProvider);
    final result = await coordinator.restoreFromDrive(file.id);
    if (!mounted) return;
    setState(() => _working = false);
    if (result.isErr) {
      showMbSnack(context, result.failure!.message, variant: MbSnackVariant.error);
      return;
    }
    showMbSnack(context, 'Restauración exitosa', variant: MbSnackVariant.success);
    ref.invalidate(databaseProvider);
    ref.invalidate(sessionControllerProvider);
    context.go('/splash');
  }

  Future<void> _setPassphrase() async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final mismatch = confirmController.text.isNotEmpty &&
              controller.text != confirmController.text;
          return AlertDialog(
            title: const Text('Contraseña de cifrado'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Los respaldos se cifrarán con esta contraseña (AES-256). '
                    'Guárdala: la necesitarás para restaurar en otro dispositivo.'),
                const SizedBox(height: 12),
                MbTextField(
                  controller: controller,
                  label: 'Contraseña',
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                MbTextField(
                  controller: confirmController,
                  label: 'Confirmar contraseña',
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  errorText: mismatch ? 'Las contraseñas no coinciden' : null,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(
                onPressed: controller.text.isEmpty ||
                        confirmController.text.isEmpty ||
                        controller.text != confirmController.text
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true || controller.text.isEmpty) return;
    await ref
        .read(backupCoordinatorProvider)
        .savePassphrase(controller.text);
    if (mounted) {
      showMbSnack(context, 'Contraseña guardada', variant: MbSnackVariant.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emailAsync = ref.watch(driveEmailProvider);
    final driveAsync = ref.watch(driveBackupsProvider);
    final localAsync = ref.watch(localBackupsProvider);
    final email = emailAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Copia de seguridad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Google Drive', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  if (email != null && email.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Conectado: $email')),
                      ],
                    )
                  else
                    const Text(
                        'Asocia tu correo para guardar los respaldos en tu Drive.'),
                  const SizedBox(height: 8),
                  if (email == null || email.isEmpty)
                    FilledButton.icon(
                      onPressed: _working ? null : _connect,
                      icon: const Icon(Icons.login),
                      label: Text(_working ? 'Conectando…' : 'Conectar con Google'),
                    )
                  else
                    OutlinedButton(
                      onPressed: _disconnect,
                      child: const Text('Desconectar'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Crear respaldo', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _working ? null : _createBackup,
                    icon: const Icon(Icons.backup_outlined),
                    label: Text(_working ? 'Trabajando…' : 'Subir respaldo a Drive'),
                  ),
                  if (_working) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Backup automático (al abrir)'),
                    value: _autoBackup,
                    onChanged: (v) async {
                      setState(() => _autoBackup = v);
                      await _set(SettingKeys.autoBackup, '$v');
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Incluir fotos de productos'),
                    value: _includePhotos,
                    onChanged: (v) async {
                      setState(() => _includePhotos = v);
                      await _set(SettingKeys.backupIncludePhotos, '$v');
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cifrar respaldos (contraseña)'),
                    value: _encrypt,
                    onChanged: (v) async {
                      setState(() => _encrypt = v);
                      await _set(SettingKeys.backupEncryption, '$v');
                      if (v) await _setPassphrase();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Respaldos en Drive', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          driveAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (files) => files.isEmpty
                ? const Text('Sin respaldos en Drive aún.')
                : Column(
                    children: [
                      for (final f in files)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.cloud_done_outlined),
                          title: Text(f.name),
                          subtitle: Text(_fmtSize(f.size)),
                          trailing: IconButton(
                            tooltip: 'Restaurar',
                            icon: const Icon(Icons.restore),
                            onPressed: _working ? null : () => _restore(f),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Text('Respaldos locales', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          localAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (list) => list.isEmpty
                ? const Text('Sin respaldos locales.')
                : Column(
                    children: [
                      for (final b in list.take(10))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(b.filename),
                          subtitle: Text(b.createdAt.toIso8601String()),
                          trailing: MbBadge(b.status.dbName),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _fmtSize(int size) {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
