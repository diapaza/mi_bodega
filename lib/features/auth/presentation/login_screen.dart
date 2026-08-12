import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mb_button.dart';
import '../../../shared/widgets/mb_pin_field.dart';
import '../../../shared/widgets/mb_text_field.dart';
import 'session_controller.dart';

/// Inicio de sesión con usuario + PIN.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _pin = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _username.text.trim();
    final pin = _pin.text;
    if (username.isEmpty || pin.isEmpty) return;
    await ref.read(sessionControllerProvider.notifier).login(username, pin);
  }

  Future<void> _recover() async {
    final recoveryPin = await showDialog<String>(
      context: context,
      builder: (ctx) => _RecoveryDialog(username: _username.text.trim()),
    );
    if (recoveryPin == null || recoveryPin.isEmpty) return;
    await ref
        .read(sessionControllerProvider.notifier)
        .loginWithRecovery(_username.text.trim(), recoveryPin);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final session = ref.watch(sessionControllerProvider);
    final error = session.valueOrNull?.errorMessage;
    final loading = session.isLoading;
    final isLockoutError = error != null && error.contains('Intenta de nuevo en');

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.storefront, size: 64, color: colors.primary),
                  const SizedBox(height: 12),
                  Text(
                    'MiBodega',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(color: colors.primary),
                  ),
                  if (session.valueOrNull?.store != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      session.valueOrNull!.store!.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (error != null) ...[
                    _ErrorBanner(message: error, isLockout: isLockoutError),
                    const SizedBox(height: 16),
                  ],
                  MbTextField(
                    controller: _username,
                    label: 'Usuario',
                    prefixIcon: Icon(Icons.person_outline, color: colors.onSurfaceVariant),
                    textCapitalization: TextCapitalization.none,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  MbPinField(
                    controller: _pin,
                    length: 6,
                    onCompleted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  MbButton(
                    label: 'Ingresar',
                    loading: loading,
                    onPressed: loading ? null : _submit,
                    icon: Icons.login,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _recover,
                    child: const Text('¿Olvidaste tu PIN?'),
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

class _ErrorBanner extends StatelessWidget {
  final String message;
  final bool isLockout;

  const _ErrorBanner({required this.message, this.isLockout = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLockout ? colors.warningContainer : colors.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isLockout ? Icons.lock_outline : Icons.error_outline,
            color: isLockout ? colors.warning : colors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isLockout ? colors.onWarning : colors.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoveryDialog extends StatefulWidget {
  final String username;

  const _RecoveryDialog({required this.username});

  @override
  State<_RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<_RecoveryDialog> {
  final _pin = TextEditingController();
  final _username = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.username.isNotEmpty) {
      _username.text = widget.username;
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    _username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Recuperar acceso'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Ingresa tu PIN de recuperación (el que definiste al configurar '
            'la tienda). Esto abrirá la sesión del propietario.',
          ),
          const SizedBox(height: 16),
          MbTextField(
            controller: _username,
            label: 'Usuario',
            textCapitalization: TextCapitalization.none,
          ),
          const SizedBox(height: 12),
          MbPinField(
            controller: _pin,
            length: 6,
            autofocus: false,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _pin.text),
          child: const Text('Recuperar'),
        ),
      ],
    );
  }
}
