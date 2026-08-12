import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/security/permission_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mb_text_field.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/entities/cash.dart';
import 'cash_providers.dart';

/// Diálogo de cierre de caja: desglose, contado, diferencia y autorización.
class CashCloseDialog extends ConsumerStatefulWidget {
  final int sessionId;
  final CashSessionSummary? summary;
  final bool canAuthorize;

  const CashCloseDialog({
    super.key,
    required this.sessionId,
    required this.summary,
    required this.canAuthorize,
  });

  @override
  ConsumerState<CashCloseDialog> createState() => _CashCloseDialogState();
}

class _CashCloseDialogState extends ConsumerState<CashCloseDialog> {
  final _counted = TextEditingController();
  bool _authorize = false;
  bool _saving = false;

  @override
  void dispose() {
    _counted.dispose();
    super.dispose();
  }

  Money get _countedMoney =>
      Money.fromSoles(double.tryParse(_counted.text) ?? 0);

  Future<void> _confirm() async {
    final guard =
        ensureAllowed(ref.read(sessionPermissionsProvider), 'cash.close');
    if (guard.isErr) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(guard.failure!.message)),
        );
      }
      return;
    }
    if (_authorize) {
      final authGuard =
          ensureAllowed(ref.read(sessionPermissionsProvider), 'cash.authorize');
      if (authGuard.isErr) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(authGuard.failure!.message)),
          );
        }
        return;
      }
    }
    setState(() => _saving = true);
    final closedBy = ref.read(sessionControllerProvider).valueOrNull?.user?.id ?? 0;
    final result = await ref.read(cashRepositoryProvider).closeSession(
          sessionId: widget.sessionId,
          closedBy: closedBy,
          countedAmount: _countedMoney,
          authorizeDifference: _authorize,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isErr) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.failure!.message)),
      );
      return;
    }
    final s = result.orNull!;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        'Caja cerrada · diferencia ${s.difference?.format() ?? '—'}',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final summary = widget.summary;
    final expected = summary?.expected ?? const Money.zero();
    final difference = _countedMoney - expected;
    final threshold = ref.watch(cashThresholdProvider).valueOrNull ?? 500;
    final needsAuth = difference.abs.cents > threshold;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        );

    return AlertDialog(
      title: const Text('Cerrar caja'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (summary != null) ...[
              row('Apertura', summary.opening.format()),
              row('Ventas en efectivo', summary.cashSales.format()),
              row('Ingresos', summary.cashIn.format()),
              row('Retiros', summary.cashOut.format()),
              if (!summary.adjustments.isZero)
                row('Ajustes', summary.adjustments.format()),
              const Divider(),
              row('Efectivo esperado', expected.format()),
            ],
            const SizedBox(height: 12),
            MbTextField(
              controller: _counted,
              label: 'Dinero contado (S/)',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Diferencia', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(
                  difference.format(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: difference.isZero
                        ? colors.success
                        : (difference.isNegative ? colors.error : colors.warning),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (needsAuth) ...[
              const SizedBox(height: 8),
              if (widget.canAuthorize)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Autorizar diferencia (${difference.format()})',
                    style: theme.textTheme.bodyMedium,
                  ),
                  value: _authorize,
                  onChanged: (v) => setState(() => _authorize = v),
                )
              else
                Text(
                  'La diferencia supera el umbral y requiere autorización del '
                  'propietario para cerrar.',
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving || (needsAuth && !_authorize) ? null : _confirm,
          child: Text(_saving ? 'Cerrando…' : 'Cerrar caja'),
        ),
      ],
    );
  }
}
