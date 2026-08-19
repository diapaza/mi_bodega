import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/mb_badge.dart';
import '../../../shared/widgets/mb_empty_state.dart';
import '../../../shared/widgets/mb_loading.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../products/domain/entities/product.dart';
import 'inventory_providers.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final canRestock = session?.can('purchases.create') ?? false;
    final canAdjust = session?.can('inventory.adjust') ?? false;

    final filter = ref.watch(inventoryFilterProvider);
    final searchText = ref.watch(inventorySearchProvider);
    final productsAsync = ref.watch(inventoryProductsProvider);
    final valueAsync = ref.watch(inventoryValueProvider);
    final low = ref.watch(lowStockProvider).valueOrNull ?? const [];
    final out = ref.watch(outOfStockProvider).valueOrNull ?? const [];
    final excess = ref.watch(excessStockProvider).valueOrNull ?? const [];
    final units = ref.watch(unitsProvider).valueOrNull ?? const [];

    String unitSymbol(int? id) =>
        units.where((u) => u.id == id).map((u) => u.symbol).firstOrNull ?? 'ud';

    final value = Money((valueAsync.valueOrNull ?? 0).round());

    List<ProductStock> filtered(List<ProductStock> all) {
      List<ProductStock> result = switch (filter) {
        InventoryFilter.low => low,
        InventoryFilter.out => out,
        InventoryFilter.excess => excess,
        InventoryFilter.all => all,
      };
      if (searchText.isNotEmpty) {
        final query = searchText.toLowerCase();
        result = result.where((p) =>
          p.product.name.toLowerCase().contains(query) ||
          (p.product.sku?.toLowerCase().contains(query) ?? false) ||
          (p.product.barcode?.toLowerCase().contains(query) ?? false)
        ).toList();
      }
      return result;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          IconButton(
            tooltip: 'Historial de movimientos',
            icon: const Icon(LucideIcons.clock),
            onPressed: () => context.push('/inventory/movements'),
          ),
        ],
      ),
      floatingActionButton: canRestock
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'shopping-list-fab',
                  onPressed: () => context.push('/shopping-list'),
                  icon: const Icon(LucideIcons.shopping_bag),
                  label: const Text('Lista de compras'),
                ),
                const Gap(8),
                FloatingActionButton.extended(
                  heroTag: 'inventory-fab',
                  onPressed: () => context.push('/purchases/new'),
                  icon: const Icon(LucideIcons.package_plus),
                  label: const Text('Reabastecer'),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(LucideIcons.banknote, color: colors.primary, size: 34),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Valor del inventario',
                              style: theme.textTheme.bodySmall),
                          Text(
                            value.format(),
                            style: theme.textTheme.headlineMedium
                                ?.copyWith(color: colors.primary),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _CountBadge(label: 'Bajo', count: low.length, tone: MbBadgeTone.warning),
                        const Gap(4),
                        _CountBadge(label: 'Agotados', count: out.length, tone: MbBadgeTone.error),
                        const Gap(4),
                        _CountBadge(label: 'Exceso', count: excess.length, tone: MbBadgeTone.info),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              onChanged: (v) => ref.read(inventorySearchProvider.notifier).state = v.trim(),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, SKU o código',
                prefixIcon: const Icon(LucideIcons.search),
                suffixIcon: searchText.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x),
                        onPressed: () => ref.read(inventorySearchProvider.notifier).state = '',
                      )
                    : null,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in InventoryFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(switch (f) {
                        InventoryFilter.all => 'Todos',
                        InventoryFilter.low => 'Stock bajo',
                        InventoryFilter.out => 'Agotados',
                        InventoryFilter.excess => 'Exceso',
                      }),
                      selected: filter == f,
                      onSelected: (_) => ref
                          .read(inventoryFilterProvider.notifier)
                          .state = f,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(inventoryProductsProvider);
                ref.invalidate(inventoryValueProvider);
                ref.invalidate(lowStockProvider);
                ref.invalidate(outOfStockProvider);
                ref.invalidate(excessStockProvider);
              },
              child: productsAsync.when(
              loading: () => const Center(child: MbLoading()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (all) {
                final items = filtered(all);
                if (items.isEmpty) {
                  return MbEmptyState(
                    icon: LucideIcons.package,
                    title: filter == InventoryFilter.all
                        ? 'Sin productos en inventario'
                        : 'Sin productos en esta categoría',
                    message: 'Ajusta el filtro o registra una compra.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Gap(8),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    final p = item.product;
                    final lineValue = Money((item.stock * p.costPrice.cents).round());
                    final stockBadge = item.outOfStock
                        ? const MbBadge('Agotado', tone: MbBadgeTone.error)
                        : item.lowStock
                            ? const MbBadge('Stock bajo', tone: MbBadgeTone.warning)
                            : null;
                    final minMaxText = 'min ${fmtQty(p.stockMin)}'
                        '${p.stockMax != null ? ' · max ${fmtQty(p.stockMax!)}' : ''}';
                    return Card(
                      child: InkWell(
                        onTap: () => context.push('/products/${p.id}'),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.name,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ),
                                  if (stockBadge != null) ...[
                                    const Gap(8),
                                    stockBadge,
                                  ],
                                ],
                              ),
                              const Gap(4),
                              Text(
                                '${fmtQty(item.stock)} ${unitSymbol(p.baseUnitId)}',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Divider(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: _DataColumn(
                                      label: 'Costo unitario',
                                      value: Money(p.costPrice.cents).format(),
                                    ),
                                  ),
                                  Expanded(
                                    child: _DataColumn(
                                      label: 'Valor inventario',
                                      value: lineValue.format(),
                                      valueColor: colors.success,
                                    ),
                                  ),
                                ],
                              ),
                              const Gap(8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _DataColumn(
                                      label: 'Límites',
                                      value: minMaxText,
                                      valueColor: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  if (canAdjust)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _InventoryActionChip(
                                          icon: LucideIcons.clock,
                                          label: 'Historial',
                                          onTap: () => context.push('/inventory/${p.id}/movements'),
                                        ),
                                        const Gap(8),
                                        _InventoryActionChip(
                                          icon: LucideIcons.wrench,
                                          label: 'Ajustar',
                                          onTap: () => context.push('/inventory/${p.id}/adjust'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05);
                  },
                );
              },
            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String label;
  final int count;
  final MbBadgeTone tone;

  const _CountBadge({
    required this.label,
    required this.count,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const Gap(4),
        MbBadge('$count', tone: tone),
      ],
    );
  }
}

class _DataColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DataColumn({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
        ),
        const Gap(2),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: valueColor ?? colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _InventoryActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _InventoryActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: colors.primary),
            const Gap(4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
