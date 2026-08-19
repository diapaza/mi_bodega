import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../sales/domain/entities/sale.dart';

/// Muestra la confirmación de venta exitosa.
Future<void> showSaleSuccess(BuildContext context, SaleDetail detail) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _SaleSuccessDialog(detail: detail),
  );
}

class _SaleSuccessDialog extends StatelessWidget {
  final SaleDetail detail;

  const _SaleSuccessDialog({required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final sale = detail.sale;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.successContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.circle_check, size: 48, color: colors.success),
            ),
            const SizedBox(height: 12),
            Text('Venta completada', style: theme.textTheme.titleLarge),
            Text(
              sale.saleNumber,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _Row(label: 'Total', value: sale.total.format()),
            _Row(label: 'Método', value: sale.paymentMethod.label),
            if (sale.amountReceived != null) ...[
              _Row(label: 'Recibido', value: sale.amountReceived!.format()),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: colors.successContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text('Vuelto', style: theme.textTheme.bodySmall),
                    Text(
                      sale.changeDue!.format(),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colors.success,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/sales');
                    },
                    child: const Text('Ver ventas'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Nueva venta'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
