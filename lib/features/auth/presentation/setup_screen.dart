import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mb_button.dart';
import '../../../shared/widgets/mb_section.dart';
import '../../../shared/widgets/mb_snackbar.dart';
import '../../../shared/widgets/mb_step_indicator.dart';
import '../../../shared/widgets/mb_text_field.dart';
import 'session_controller.dart';

/// Primer arranque: configura la tienda y crea al propietario (wizard de 2 pasos).
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

  int _currentStep = 0;
  static const _totalSteps = 2;

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

  bool _validateStep0() {
    if (_store.text.trim().isEmpty) {
      showMbSnack(context, 'Ingresa el nombre de la tienda.');
      return false;
    }
    return true;
  }

  bool _validateStep1() {
    if (_ownerName.text.trim().isEmpty) {
      showMbSnack(context, 'Ingresa tu nombre completo.');
      return false;
    }
    if (_ownerUser.text.trim().isEmpty) {
      showMbSnack(context, 'Ingresa un nombre de usuario.');
      return false;
    }
    if (_ownerPin.text.length < 4) {
      showMbSnack(context, 'El PIN debe tener al menos 4 dígitos.');
      return false;
    }
    if (_recoveryPin.text.length < 4) {
      showMbSnack(context, 'El PIN de recuperación debe tener al menos 4 dígitos.');
      return false;
    }
    return true;
  }

  void _next() {
    if (_currentStep == 0 && _validateStep0()) {
      setState(() => _currentStep = 1);
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submit() async {
    if (!_validateStep1()) return;
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
    final theme = Theme.of(context);
    final session = ref.watch(sessionControllerProvider);
    final loading = session.isLoading;
    final error = session.valueOrNull?.errorMessage;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar MiBodega')),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MbStepIndicator(
                        currentStep: _currentStep,
                        totalSteps: _totalSteps,
                      ),
                      const SizedBox(height: 24),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _currentStep == 0
                            ? _buildStep0(colors)
                            : _buildStep1(colors),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(error, style: TextStyle(color: colors.error)),
                      ],
                      const SizedBox(height: 24),
                      if (_currentStep == 0)
                        MbButton(
                          label: 'Siguiente',
                          icon: Icons.arrow_forward,
                          onPressed: _next,
                        )
                      else ...[
                        MbButton(
                          label: 'Crear tienda',
                          icon: Icons.check,
                          loading: loading,
                          onPressed: loading ? null : _submit,
                        ),
                        const SizedBox(height: 8),
                        MbButton(
                          label: 'Atrás',
                          variant: MbButtonVariant.text,
                          onPressed: loading ? null : _back,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (loading)
            Container(
              color: colors.background.withValues(alpha: 0.7),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Creando tu tienda...',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Esto puede tomar unos segundos',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep0(AppColors colors) {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MbSection(
          title: 'Datos de la tienda',
          child: Column(
            children: [
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep1(AppColors colors) {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MbSection(
          title: 'Propietario / administrador',
          child: Column(
            children: [
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
            ],
          ),
        ),
      ],
    );
  }
}
