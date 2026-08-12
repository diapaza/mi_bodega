import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/session_controller.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mb_badge.dart';
import '../../../shared/widgets/mb_empty_state.dart';
import '../domain/entities/inventory.dart';
import 'inventory_providers.dart';

/// Historial de movimientos (de un producto o global).
///
/// Con `productId` nulo muestra el historial global de la tienda.
class MovementsHistoryScreen extends ConsumerWidget {
  final int? productId;

  const MovementsHistoryScreen({super.key, this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final global = productId == null;

    final async = global
        ? ref.watch(movementsGlobalProvider)
        : ref.watch(productMovementsProvider(productId!));

    return Scaffold(
      appBar: AppBar(
        title: Text(global ? 'Historial de movimientos' : 'Movimientos'),
        actions: [
          if (!global && (ref.watch(sessionControllerProvider).valueOrNull?.can('inventory.adjust') ?? false))
            IconButton(
              tooltip: 'Ajustar stock',
              icon: const Icon(Icons.tune),
              onPressed: () => context.push('/inventory/$productId/adjust'),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (movements) {
          if (movements.isEmpty) {
            return const MbEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Sin movimientos',
              message: 'Las entradas y salidas de stock aparecerán aquí.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: movements.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final entry = movements[i];
              return _MovementTile(entry: entry, showProduct: global);
            },
          );
        },
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final MovementWithUser entry;
  final bool showProduct;

  const _MovementTile({required this.entry, required this.showProduct});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final m = entry.movement;
    final isIn = m.quantity >= 0;

    final tone = switch (m.type) {
      MovementType.purchaseIn || MovementType.manualIn || MovementType.returnIn => MbBadgeTone.success,
      MovementType.saleOut => MbBadgeTone.primary,
      MovementType.loss => MbBadgeTone.error,
      MovementType.adjustment || MovementType.correction => MbBadgeTone.warning,
      _ => MbBadgeTone.info,
    };

    final refText = switch (m.referenceType) {
      'sale' => 'Venta ref. #${m.referenceId}',
      'purchase' => 'Compra ref. #${m.referenceId}',
      _ => m.referenceType ?? '',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MbBadge(m.type.label, tone: tone),
                const Spacer(),
                Text(
                  _fmtDateTime(m.createdAt),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (showProduct && entry.productName != null) ...[
              Text(entry.productName!, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${isIn ? '+' : ''}${_fmtQty(m.quantity)} '
                    '→ ${_fmtQty(m.afterQty)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isIn ? colors.success : colors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  'antes ${_fmtQty(m.beforeQty)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (m.note != null && m.note!.isNotEmpty)
              Text(m.note!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 2),
            Text(
              [if (entry.userName != null) entry.userName!, if (refText.isNotEmpty) refText]
                  .join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(2);

  String _fmtDateTime(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} $hh:$mm';
  }
}
