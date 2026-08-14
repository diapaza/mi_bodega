import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gal/gal.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/money/money.dart';
import '../../../shared/widgets/mb_empty_state.dart';
import '../../../shared/widgets/mb_snackbar.dart';
import '../../../shared/widgets/mb_text_field.dart';
import '../../auth/presentation/session_controller.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../products/domain/entities/product.dart';
import '../../products/presentation/widgets/product_image.dart';
import '../domain/entities/shopping_list.dart';
import '../domain/repositories/shopping_list_repository.dart';
import 'purchases_providers.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  final _listKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final listAsync = ref.watch(shoppingListProvider);
    final items = listAsync.valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de compras'),
        actions: [
          if (items.isNotEmpty) ...[
            IconButton(
              tooltip: 'Guardar como imagen',
              icon: const Icon(Icons.image_outlined),
              onPressed: _saveAsImage,
            ),
            IconButton(
              tooltip: 'Mover a reabastecer',
              icon: const Icon(Icons.shopping_cart_checkout),
              onPressed: () => _moveToRestock(items),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'shopping-list-fab',
        onPressed: () => _addProduct(context),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: listAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const MbEmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Lista vacía',
                  message:
                      'Agrega productos que necesites comprar. La lista se guarda automáticamente.',
                )
              : RepaintBoundary(
                  key: _listKey,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                    final entry = items[i];
                    final item = entry.item;
                    final product = entry.product;
                    final p = product.product;
                    final stock = product.stock;

                    final status = _stockStatus(p, stock, colorScheme);

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                ProductImage(
                                  photoPath: item.photoPath ?? p.photoPath,
                                  width: 48,
                                  height: 48,
                                  borderRadius: 8,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: theme.textTheme.titleSmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: status.color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            status.label,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(color: status.color),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Stock: ${_fmtQty(stock)}',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Costo: ${p.purchasePrice.format()}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: '+1 unidad de compra',
                                      icon: Icon(Icons.add_circle_outline,
                                          size: 22, color: colorScheme.primary),
                                      onPressed: () => _addPurchaseUnit(entry),
                                    ),
                                    IconButton(
                                      tooltip: 'Editar',
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      onPressed: () => _editItem(context, entry),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar',
                                      icon: Icon(Icons.delete_outline,
                                          size: 20, color: colorScheme.error),
                                      onPressed: () => _removeItem(item),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (item.quantity != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    '${_fmtQty(item.quantity!)} × ${p.purchasePrice.format()}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '= ${Money((item.quantity! * p.purchasePrice.cents).round()).format()}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (p.saleUnitsPerPurchaseUnit > 1) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${_fmtQty(item.quantity! * p.saleUnitsPerPurchaseUnit)} uds)',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                            if (item.notes != null && item.notes!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.notes!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                ),
    );
  }

  _StockStatus _stockStatus(Product p, double stock, ColorScheme colors) {
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

  Future<void> _saveAsImage() async {
    try {
      final boundary = _listKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final buffer = byteData.buffer.asUint8List();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await Gal.putImageBytes(
        buffer,
        name: 'lista_compras_$timestamp',
      );

      if (!mounted) return;
      showMbSnack(
        context,
        'Imagen guardada en la galería',
        variant: MbSnackVariant.success,
      );
    } catch (e) {
      if (!mounted) return;
      showMbSnack(
        context,
        'Error al guardar imagen: $e',
        variant: MbSnackVariant.error,
      );
    }
  }

  Future<void> _addPurchaseUnit(ShoppingListItemWithProduct entry) async {
    final currentQty = entry.item.quantity ?? 0;
    final newQty = currentQty + 1;

    final updated = entry.item.copyWith(
      quantity: newQty,
      updatedAt: DateTime.now(),
    );

    final res =
        await ref.read(shoppingListRepositoryProvider).updateItem(updated);
    if (!mounted) return;
    if (res.isErr) {
      showMbSnack(context, res.failure!.message,
          variant: MbSnackVariant.error);
    }
  }

  Future<void> _addProduct(BuildContext context) async {
    final storeId =
        ref.read(sessionControllerProvider).valueOrNull?.store?.id;
    if (storeId == null) return;

    final products =
        ref.read(inventoryProductsProvider).valueOrNull ?? const [];
    if (products.isEmpty) {
      if (mounted) {
        showMbSnack(context, 'No hay productos disponibles.',
            variant: MbSnackVariant.warning);
      }
      return;
    }

    final existingIds = ref
            .read(shoppingListProvider)
            .valueOrNull
            ?.map((e) => e.item.productId)
            .toSet() ??
        {};

    final available =
        products.where((p) => !existingIds.contains(p.product.id)).toList();
    if (available.isEmpty) {
      if (mounted) {
        showMbSnack(context, 'Todos los productos ya están en la lista.',
            variant: MbSnackVariant.warning);
      }
      return;
    }

    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => _ProductPickerDialog(products: available),
    );
    if (selected == null || !mounted) return;

    final result = await ref.read(shoppingListRepositoryProvider).addItem(
          ShoppingListItem(
            storeId: storeId,
            productId: selected,
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

  Future<void> _editItem(
      BuildContext context, ShoppingListItemWithProduct entry) async {
    final controller = TextEditingController(
      text: entry.item.quantity?.toString() ?? '',
    );
    final notesController = TextEditingController(
      text: entry.item.notes ?? '',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry.product.product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MbTextField(
              controller: controller,
              label: 'Cantidad',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            MbTextField(
              controller: notesController,
              label: 'Notas (opcional)',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'quantity': double.tryParse(controller.text),
              'notes': notesController.text.isEmpty
                  ? null
                  : notesController.text,
            }),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    final updated = entry.item.copyWith(
      quantity: result['quantity'] as double?,
      notes: result['notes'] as String?,
      updatedAt: DateTime.now(),
    );

    final res =
        await ref.read(shoppingListRepositoryProvider).updateItem(updated);
    if (!mounted) return;
    if (res.isErr) {
      showMbSnack(context, res.failure!.message,
          variant: MbSnackVariant.error);
    }
  }

  Future<void> _removeItem(ShoppingListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar de la lista'),
        content: const Text('¿Eliminar este producto de la lista de compras?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final res =
        await ref.read(shoppingListRepositoryProvider).removeItem(item.id!);
    if (!mounted) return;
    if (res.isErr) {
      showMbSnack(context, res.failure!.message,
          variant: MbSnackVariant.error);
    }
  }

  void _moveToRestock(List<ShoppingListItemWithProduct> items) {
    context.push('/purchases/new');
  }
}

class _StockStatus {
  final Color color;
  final String label;
  const _StockStatus(this.color, this.label);
}

class _ProductPickerDialog extends StatefulWidget {
  final List<ProductStock> products;
  const _ProductPickerDialog({required this.products});

  @override
  State<_ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<_ProductPickerDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products
        .where((ps) =>
            ps.product.name.toLowerCase().contains(_search.toLowerCase()))
        .toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));

    return AlertDialog(
      title: const Text('Agregar producto'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar...',
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 20),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final ps = filtered[i];
                  return ListTile(
                    leading: ProductImage(
                      photoPath: ps.product.photoPath,
                      width: 40,
                      height: 40,
                      borderRadius: 6,
                    ),
                    title: Text(ps.product.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('Stock: ${ps.stock.toInt()}'),
                    onTap: () => Navigator.pop(context, ps.product.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
