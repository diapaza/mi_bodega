import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/security/permission_guard.dart';
import '../../../shared/widgets/mb_button.dart';
import '../../../shared/widgets/mb_empty_state.dart';
import '../../../shared/widgets/mb_snackbar.dart';
import '../../../shared/widgets/mb_text_field.dart';
import '../../auth/presentation/session_controller.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../products/domain/entities/product.dart';
import '../../products/presentation/widgets/product_image.dart';
import '../domain/entities/purchase.dart';
import '../domain/repositories/shopping_list_repository.dart';
import 'purchases_providers.dart';

class _RestockDraft {
  final TextEditingController quantity;
  final TextEditingController cost;

  _RestockDraft({required double quantity, required int costCents})
      : quantity = TextEditingController(text: _fmt(quantity)),
        cost = TextEditingController(text: (costCents / 100).toStringAsFixed(2));

  static String _fmt(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(2);

  void dispose() {
    quantity.dispose();
    cost.dispose();
  }
}

/// Flujo de reabastecimiento: detectar → seleccionar → cantidades/costo →
/// proveedor → confirmar compra.
class RestockScreen extends ConsumerStatefulWidget {
  const RestockScreen({super.key});

  @override
  ConsumerState<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends ConsumerState<RestockScreen> {
  final Map<int, _RestockDraft> _selected = {};
  int? _supplierId;
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    for (final d in _selected.values) {
      d.dispose();
    }
    super.dispose();
  }

  double _suggestion(ProductStock item) {
    final stock = item.stock;
    final min = item.product.stockMin;
    final max = item.product.stockMax;
    final unitsPerPkg = item.product.saleUnitsPerPurchaseUnit;

    final targetSaleUnits = max != null ? max - stock : (min * 2) - stock;

    if (unitsPerPkg > 1) {
      final targetPurchaseUnits = targetSaleUnits / unitsPerPkg;
      final rounded = targetPurchaseUnits.ceilToDouble();
      return rounded < 1 ? 1 : rounded;
    }

    return targetSaleUnits < 1 ? 1 : targetSaleUnits;
  }

  Future<void> _toggle(ProductStock item) async {
    final id = item.product.id!;
    if (_selected.containsKey(id)) {
      _selected.remove(id)?.dispose();
      setState(() {});
      return;
    }

    // Alerta de sobrestock.
    final p = item.product;
    if (p.stockMax != null && item.stock >= p.stockMax!) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¡Atención!'),
          content: Text(
            'Este producto ya tiene stock (${_fmtQty(item.stock)}) igual o mayor '
            'al máximo (${_fmtQty(p.stockMax!)}). Al agregar más stock habrá '
            'sobrestock. ¿Desea agregar de todos modos?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Agregar de todos modos'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final hasPurchaseUnit =
        p.purchaseUnitId != null && p.saleUnitsPerPurchaseUnit > 1;
    final lastCost = hasPurchaseUnit
        ? p.purchasePrice.cents
        : (await ref.read(lastPurchaseCostProvider(id).future)) ??
            p.costPrice.cents;
    setState(() {
      _selected[id] = _RestockDraft(
        quantity: _suggestion(item),
        costCents: lastCost,
      );
    });
  }

  Future<void> _toggleWithQuantity(
      ProductStock item, double? listQuantity) async {
    final id = item.product.id!;
    if (_selected.containsKey(id)) {
      _selected.remove(id)?.dispose();
      setState(() {});
      return;
    }

    final p = item.product;
    if (p.stockMax != null && item.stock >= p.stockMax!) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¡Atención!'),
          content: Text(
            'Este producto ya tiene stock (${_fmtQty(item.stock)}) igual o mayor '
            'al máximo (${_fmtQty(p.stockMax!)}). Al agregar más stock habrá '
            'sobrestock. ¿Desea agregar de todos modos?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Agregar de todos modos'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final hasPurchaseUnit =
        p.purchaseUnitId != null && p.saleUnitsPerPurchaseUnit > 1;
    final lastCost = hasPurchaseUnit
        ? p.purchasePrice.cents
        : (await ref.read(lastPurchaseCostProvider(id).future)) ??
            p.costPrice.cents;
    setState(() {
      _selected[id] = _RestockDraft(
        quantity: listQuantity ?? _suggestion(item),
        costCents: lastCost,
      );
    });
  }

  Future<void> _quickSupplier() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo proveedor'),
        content: MbTextField(controller: controller, label: 'Nombre'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    final storeId =
        ref.read(sessionControllerProvider).valueOrNull?.store?.id;
    if (storeId == null) return;
    final result = await ref.read(supplierRepositoryProvider).createSupplier(
          Supplier(
            storeId: storeId,
            name: name.trim(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
    if (!mounted) return;
    if (result.isErr) {
      showMbSnack(context, result.failure!.message,
          variant: MbSnackVariant.error);
    }
  }

  Future<void> _confirm() async {
    final guard =
        ensureAllowed(ref.read(sessionPermissionsProvider), 'purchases.create');
    if (guard.isErr) {
      if (mounted) {
        showMbSnack(context, guard.failure!.message,
            variant: MbSnackVariant.error);
      }
      return;
    }
    final session = ref.read(sessionControllerProvider).valueOrNull;
    if (session == null || session.store == null || session.user == null) return;
    final storeId = session.store!.id!;
    final userId = session.user!.id!;

    final items = <PurchaseItemInput>[];
    for (final entry in _selected.entries) {
      final draft = entry.value;
      final qty = double.tryParse(draft.quantity.text) ?? 0;
      if (qty <= 0) continue;
      items.add(PurchaseItemInput(
        productId: entry.key,
        quantity: qty,
        unitPrice: Money.fromSoles(double.tryParse(draft.cost.text) ?? 0),
      ));
    }
    if (items.isEmpty) {
      showMbSnack(context, 'Selecciona productos con cantidad válida.',
          variant: MbSnackVariant.warning);
      return;
    }
    setState(() => _saving = true);
    final result = await ref.read(purchaseRepositoryProvider).createPurchase(
          PurchaseRequest(
            storeId: storeId,
            userId: userId,
            supplierId: _supplierId,
            items: items,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isErr) {
      showMbSnack(context, result.failure!.message,
          variant: MbSnackVariant.error);
      return;
    }

    // Eliminar productos reabastecidos de la lista de compras.
    final shoppingRepo = ref.read(shoppingListRepositoryProvider);
    for (final entry in _selected.entries) {
      await shoppingRepo.removeByProductId(storeId, entry.key);
    }

    for (final d in _selected.values) {
      d.dispose();
    }
    _selected.clear();
    showMbSnack(context,
        'Compra registrada · ${Money(result.orNull!.total.cents).format()}',
        variant: MbSnackVariant.success);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = Theme.of(context).colorScheme;
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final productsAsync = ref.watch(inventoryProductsProvider);
    final allProducts = productsAsync.valueOrNull ?? const <ProductStock>[];
    final suppliers =
        ref.watch(suppliersProvider).valueOrNull ?? const <Supplier>[];
    final canManageSuppliers = session?.can('suppliers.manage') ?? false;
    final shoppingList =
        ref.watch(shoppingListProvider).valueOrNull ?? const [];

    // Auto-importar productos de la lista de compras al abrir.
    if (!_initialized && allProducts.isNotEmpty) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoImportFromList(shoppingList, allProducts);
      });
    }

    // Ordenar por stock ascendente (menor a mayor).
    final products = allProducts.toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));

    final total = Money(_selected.entries.fold<int>(0, (sum, entry) {
      final qty = double.tryParse(entry.value.quantity.text) ?? 0;
      final cost = double.tryParse(entry.value.cost.text) ?? 0;
      return sum + (qty * cost * 100).round();
    }));

    return Scaffold(
      appBar: AppBar(title: const Text('Reabastecer')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_selected.length} productos · ${total.format()}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Expanded(
                child: MbButton(
                  label: 'Registrar compra',
                  loading: _saving,
                  onPressed: _saving || _selected.isEmpty ? null : _confirm,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: _supplierId,
                    decoration: const InputDecoration(
                      labelText: 'Proveedor (opcional)',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Sin proveedor')),
                      for (final s in suppliers)
                        DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (v) => setState(() => _supplierId = v),
                  ),
                ),
                if (canManageSuppliers) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Nuevo proveedor',
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    onPressed: _quickSupplier,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: productsAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : productsAsync.hasError
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 48, color: colors.error),
                              const SizedBox(height: 16),
                              Text('Error al cargar productos',
                                  style: theme.textTheme.titleMedium),
                              const SizedBox(height: 16),
                              MbButton(
                                label: 'Reintentar',
                                variant: MbButtonVariant.outlined,
                                onPressed: () =>
                                    ref.invalidate(inventoryProductsProvider),
                              ),
                            ],
                          ),
                        ),
                      )
                    : products.isEmpty
                        ? const MbEmptyState(
                            icon: Icons.check_circle_outline,
                            title: 'Todo en stock',
                            message:
                                'No hay productos con stock bajo o agotados.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: products.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final item = products[i];
                              final draft = _selected[item.product.id];
                              final selected = draft != null;
                              final p = item.product;
                              final status =
                                  _stockStatus(p, item.stock, colors);

                              return Card(
                                color: selected
                                    ? status.color.withValues(alpha: 0.08)
                                    : null,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _toggle(item),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Checkbox(
                                              value: selected,
                                              onChanged: (_) => _toggle(item),
                                            ),
                                            ProductImage(
                                              photoPath: p.photoPath,
                                              width: 40,
                                              height: 40,
                                              borderRadius: 6,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(p.name,
                                                      style: theme
                                                          .textTheme.titleSmall),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        width: 8,
                                                        height: 8,
                                                        decoration: BoxDecoration(
                                                          color: status.color,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        '${status.label} · '
                                                        'Stock ${_fmtQty(item.stock)}'
                                                        '${item.outOfStock ? ' · AGOTADO' : ''}'
                                                        ' · mín ${_fmtQty(p.stockMin)}',
                                                        style: theme.textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                          color: status.color,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (selected) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: MbTextField(
                                                  controller: draft.quantity,
                                                  label: 'Cantidad',
                                                  keyboardType:
                                                      TextInputType.number,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: MbTextField(
                                                  controller: draft.cost,
                                                  label: 'Costo por ud (S/)',
                                                  keyboardType:
                                                      const TextInputType
                                                          .numberWithOptions(
                                                          decimal: true),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  _StockStatus _stockStatus(
      Product p, double stock, ColorScheme colors) {
    if (stock < 0.0001) {
      return _StockStatus(colors.error, 'Agotado');
    }
    if (stock <= p.stockMin) {
      return _StockStatus(const Color(0xFFF57C00), 'Stock bajo');
    }
    if (p.stockMax != null && stock > p.stockMax!) {
      return _StockStatus(const Color(0xFF1976D2), 'Sobrestock');
    }
    return _StockStatus(const Color(0xFF388E3C), 'Normal');
  }

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(2);

  void _autoImportFromList(
      List<ShoppingListItemWithProduct> shoppingList,
      List<ProductStock> allProducts) {
    for (final entry in shoppingList) {
      final id = entry.item.productId;
      final ps = allProducts.where((p) => p.product.id == id).firstOrNull;
      if (ps != null && !_selected.containsKey(id)) {
        _toggleWithQuantity(ps, entry.item.quantity);
      }
    }
  }
}

class _StockStatus {
  final Color color;
  final String label;
  const _StockStatus(this.color, this.label);
}
