import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mb_button.dart';
import '../../../shared/widgets/mb_text_field.dart';
import 'session_controller.dart';

/// Primer arranque: configura la tienda y crea al propietario.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _store = TextEditingController();
  final _ruc = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _ownerName = TextEditingController();
  final _ownerUser = TextEditingController();
  final _ownerPin = TextEditingController();
  final _recoveryPin = TextEditingController();

  @override
  void dispose() {
    _store.dispose();
    _ruc.dispose();
    _address.dispose();
    _phone.dispose();
    _ownerName.dispose();
    _ownerUser.dispose();
    _ownerPin.dispose();
    _recoveryPin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_store.text.trim().isEmpty ||
        _ownerName.text.trim().isEmpty ||
        _ownerUser.text.trim().isEmpty ||
        _ownerPin.text.length < 4 ||
        _recoveryPin.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos obligatorios.')),
      );
      return;
    }
    await ref.read(sessionControllerProvider.notifier).completeSetup(
          storeName: _store.text.trim(),
          rucDni: _ruc.text.trim().isEmpty ? null : _ruc.text.trim(),
          address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          ownerFullName: _ownerName.text.trim(),
          ownerUsername: _ownerUser.text.trim(),
          ownerPin: _ownerPin.text,
          ownerRecoveryPin: _recoveryPin.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final session = ref.watch(sessionControllerProvider);
    final loading = session.isLoading;
    final error = session.valueOrNull?.errorMessage;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar MiBodega')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Datos de la tienda',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  MbTextField(
                    controller: _store,
                    label: 'Nombre de la tienda *',
                    prefixIcon: Icon(Icons.storefront, color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  MbTextField(
                    controller: _ruc,
                    label: 'RUC / DNI (opcional)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  MbTextField(controller: _address, label: 'Dirección (opcional)'),
                  const SizedBox(height: 12),
                  MbTextField(controller: _phone, label: 'Teléfono (opcional)'),
                  const SizedBox(height: 24),
                  Text('Propietario / administrador',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  MbTextField(
                    controller: _ownerName,
                    label: 'Nombre completo *',
                    prefixIcon: Icon(Icons.person_outline, color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  MbTextField(
                    controller: _ownerUser,
                    label: 'Usuario *',
                    textCapitalization: TextCapitalization.none,
                  ),
                  const SizedBox(height: 12),
                  MbTextField(
                    controller: _ownerPin,
                    label: 'PIN de ingreso (4-6 dígitos) *',
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                  ),
                  const SizedBox(height: 12),
                  MbTextField(
                    controller: _recoveryPin,
                    label: 'PIN de recuperación (4-6 dígitos) *',
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    helperText: 'Te permite recuperar el acceso si olvidas tu PIN.',
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error,
                      style: TextStyle(color: colors.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  MbButton(
                    label: 'Crear tienda',
                    icon: Icons.check,
                    loading: loading,
                    onPressed: loading ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
