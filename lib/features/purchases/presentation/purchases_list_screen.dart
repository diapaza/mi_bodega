import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/mb_empty_state.dart';
import '../../../shared/widgets/mb_loading.dart';
import '../../products/presentation/products_providers.dart';
import '../domain/entities/purchase.dart';
import 'purchases_providers.dart';

/// Historial de compras/abastecimientos con detalle.
class PurchasesListScreen extends ConsumerWidget {
  const PurchasesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(purchasesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Compras')),
      body: purchasesAsync.when(
loading: () => const Center(child: MbLoading()),
        error: (e, _) => MbEmptyState(
icon: LucideIcons.circle_alert,
           title: 'Error al cargar',
          message: '$e',
        ),
        data: (purchases) {
          if (purchases.isEmpty) {
            return const MbEmptyState(
              icon: LucideIcons.shopping_cart,
              title: 'Sin compras',
              message: 'Registra un abastecimiento desde Inventario.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: purchases.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = purchases[i];
              return _PurchaseCard(purchase: p);
            },
          );
        },
      ),
    );
  }
}

class _PurchaseCard extends ConsumerWidget {
  final Purchase purchase;

  const _PurchaseCard({required this.purchase});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final itemsAsync = ref.watch(purchaseItemsProvider(purchase.id!));

    return Card(
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(LucideIcons.shopping_cart, color: colors.primary),
        title: Text('Compra #${purchase.id}'),
        subtitle: Text(
          fmtDate(purchase.purchaseDate) +
              (purchase.note != null ? ' · ${purchase.note}' : ''),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              purchase.total.format(),
              style: theme.textTheme.titleSmall?.copyWith(color: colors.primary),
            ),
            const SizedBox(width: 4),
            const Icon(LucideIcons.chevron_down),
          ],
        ),
        children: [
          itemsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: MbLoading()),
            ),
            error: (e, _) => MbEmptyState(
icon: LucideIcons.circle_alert,
               title: 'Error al cargar',
              message: '$e',
            ),
            data: (items) => Column(
              children: [
                for (final item in items)
                  _PurchaseItemTile(item: item),
                const Divider(),
                ListTile(
                  dense: true,
                  title: const Text('Total'),
                  trailing: Text(
                    purchase.total.format(),
                    style: theme.textTheme.titleSmall,
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

class _PurchaseItemTile extends ConsumerWidget {
  final PurchaseItem item;

  const _PurchaseItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product =
        ref.watch(productByIdProvider(item.productId)).valueOrNull?.product;
    return ListTile(
      dense: true,
      title: Text(product?.name ?? 'Producto #${item.productId}'),
      subtitle: Text('${fmtQty(item.quantity)} × ${item.unitPrice.format()}'),
      trailing: Text(item.subtotal.format()),
    );
  }
}
