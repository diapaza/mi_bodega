import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';
import '../../../shared/widgets/mb_button.dart';
import '../../../shared/widgets/mb_snackbar.dart';
import '../../../shared/widgets/mb_text_field.dart';
import '../../store/domain/entities/store.dart';

/// Estado del tema (claro/oscuro/sistema).
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _storeName = TextEditingController();
  final _ruc = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  bool _requirePin = false;
  bool _autoBackup = false;
  bool _encrypt = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final coordinator = ref.read(backupCoordinatorProvider);
    final repo = ref.read(storeRepositoryProvider);
    final store = (await repo.getStore()).orNull;
    final values = await Future.wait([
      coordinator.getSetting(SettingKeys.requirePinOnStart),
      coordinator.getSetting(SettingKeys.autoBackup),
      coordinator.getSetting(SettingKeys.backupEncryption),
    ]);
    if (!mounted) return;
    setState(() {
      _storeName.text = store?.name ?? '';
      _ruc.text = store?.rucDni ?? '';
      _address.text = store?.address ?? '';
      _phone.text = store?.phone ?? '';
      _requirePin = values[0] == 'true';
      _autoBackup = values[1] == 'true';
      _encrypt = values[2] == 'true';
      _loaded = true;
    });
  }

  Future<void> _saveStore() async {
    final repo = ref.read(storeRepositoryProvider);
    final current = (await repo.getStore()).orNull;
    if (current == null) return;
    await repo.updateStore(Store(
      id: current.id,
      name: _storeName.text.trim().isNotEmpty ? _storeName.text.trim() : current.name,
      rucDni: _ruc.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      currency: current.currency,
      active: current.active,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    ));
    if (mounted) {
      showMbSnack(context, 'Tienda actualizada');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);

    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configuración')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Datos de la tienda', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  MbTextField(controller: _storeName, label: 'Nombre *'),
                  const SizedBox(height: 12),
                  MbTextField(controller: _ruc, label: 'RUC / DNI'),
                  const SizedBox(height: 12),
                  MbTextField(controller: _address, label: 'Dirección'),
                  const SizedBox(height: 12),
                  MbTextField(controller: _phone, label: 'Teléfono'),
                  const SizedBox(height: 12),
                  MbButton(
                    label: 'Guardar datos',
                    icon: Icons.save,
                    onPressed: _saveStore,
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
                  Text('Apariencia', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro')),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (s) {
                      ref.read(themeModeProvider.notifier).state = s.first;
                    },
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
                  Text('Seguridad', style: theme.textTheme.titleMedium),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pedir PIN al abrir la app'),
                    subtitle: Text(
                      'Si está activado, la app pedirá PIN en cada apertura.',
                      style: theme.textTheme.bodySmall,
                    ),
                    value: _requirePin,
                    onChanged: (v) async {
                      setState(() => _requirePin = v);
                      await ref.read(backupCoordinatorProvider)
                          .putSetting(SettingKeys.requirePinOnStart, '$v');
                      if (mounted) {
                        showMbSnack(context, 'Configuración guardada');
                      }
                    },
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
                  Text('Respaldo', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Backup automático'),
                    value: _autoBackup,
                    onChanged: (v) async {
                      setState(() => _autoBackup = v);
                      await ref.read(backupCoordinatorProvider)
                          .putSetting(SettingKeys.autoBackup, '$v');
                      if (mounted) {
                        showMbSnack(context, 'Configuración guardada');
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cifrar respaldos'),
                    value: _encrypt,
                    onChanged: (v) async {
                      setState(() => _encrypt = v);
                      await ref.read(backupCoordinatorProvider)
                          .putSetting(SettingKeys.backupEncryption, '$v');
                      if (mounted) {
                        showMbSnack(context, 'Configuración guardada');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Versión'),
              subtitle: const Text('MiBodega v1.0.0'),
              leading: const Icon(Icons.info_outline),
            ),
          ),
        ],
      ),
    );
  }
}
