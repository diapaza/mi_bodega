import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mb_badge.dart';
import '../../../shared/widgets/mb_empty_state.dart';
import '../../sales/domain/entities/sale.dart';
import '../../../core/utils/formatters.dart';
import 'customers_providers.dart';

/// Detalle de cliente: datos, total comprado y historial de compras.
class CustomerDetailScreen extends ConsumerWidget {
  final int customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final customerAsync = ref.watch(customerDetailProvider(customerId));
    final statsAsync = ref.watch(customerStatsProvider(customerId));
    final salesAsync = ref.watch(customerSalesProvider(customerId));
    final customer = customerAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(customer?.name ?? 'Cliente')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer?.name ?? '—', style: theme.textTheme.titleLarge),
                  if (customer?.dni != null && customer!.dni!.isNotEmpty)
                    Text('DNI: ${customer.dni}',
                        style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total comprado', style: theme.textTheme.bodySmall),
                            Text(
                              statsAsync.valueOrNull?.totalSpent.format() ?? 'S/ 0.00',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(color: colors.primary),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Compras', style: theme.textTheme.bodySmall),
                            Text(
                              '${statsAsync.valueOrNull?.purchaseCount ?? 0}',
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Última compra: ${statsAsync.valueOrNull?.lastPurchaseAt != null ? fmtDate(statsAsync.valueOrNull!.lastPurchaseAt!) : '—'}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Historial de compras', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          salesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => MbEmptyState(
              icon: Icons.error_outline,
              title: 'Error al cargar',
              message: '$e',
            ),
            data: (sales) => sales.isEmpty
                ? const MbEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Sin compras',
                  )
                : Column(
                    children: [
                      for (final s in sales)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: s.status == SaleStatus.cancelled
                              ? const MbBadge('Anulada', tone: MbBadgeTone.error)
                              : const MbBadge('Venta', tone: MbBadgeTone.success),
                          title: Text(s.saleNumber),
                          subtitle: Text(
                            '${s.saleDate.day}/${s.saleDate.month}/${s.saleDate.year}'
                            ' · ${s.paymentMethod.label}',
                          ),
                          trailing: Text(
                            s.total.format(),
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: colors.primary),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

}
