import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gal/gal.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:gap/gap.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/mb_confirm_dialog.dart';
import '../../../shared/widgets/mb_empty_state.dart';
import '../../../shared/widgets/mb_loading.dart';
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
              icon: const Icon(LucideIcons.image),
              onPressed: _saveAsImage,
            ),
            IconButton(
              tooltip: 'Mover a reabastecer',
              icon: const Icon(LucideIcons.shopping_cart),
              onPressed: () => _moveToRestock(items),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'shopping-list-fab',
        onPressed: () => _addProduct(context),
icon: const Icon(LucideIcons.plus),
         label: const Text('Agregar'),
      ),
      body: listAsync.isLoading
          ? const Center(child: MbLoading())
          : items.isEmpty
              ? const MbEmptyState(
                  icon: LucideIcons.shopping_bag,
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

                    final status = _stockStatus(p, stock, context.colors);

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
                                          Flexible(child: Text(
                                            status.label,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(color: status.color),
                                          )),
                                          const SizedBox(width: 8),
                                          Flexible(child: Text(
                                            'Stock: ${fmtQty(stock)}',
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall,
                                          )),
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
icon: Icon(LucideIcons.circle_plus,
                                           size: 22, color: colorScheme.primary),
                                      onPressed: () => _addPurchaseUnit(entry),
                                    ),
                                    IconButton(
                                      tooltip: 'Editar',
                                      icon: const Icon(LucideIcons.pencil, size: 20),
                                      onPressed: () => _editItem(context, entry),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar',
icon: Icon(LucideIcons.trash_2,
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
                               Flexible(child: Text(
                                     '${fmtQty(item.quantity!)} × ${p.purchasePrice.format()}',
                                     overflow: TextOverflow.ellipsis,
                                     style: theme.textTheme.bodySmall?.copyWith(
                                       fontWeight: FontWeight.w600,
                                     ),
                                   )),
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
                                      '(${fmtQty(item.quantity! * p.saleUnitsPerPurchaseUnit)} uds)',
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

  _StockStatus _stockStatus(Product p, double stock, AppColors appColors) {
    if (stock < 0.0001) {
      return _StockStatus(appColors.error, 'Agotado');
    }
    if (stock <= p.stockMin) {
      return _StockStatus(appColors.warning, 'Stock bajo');
    }
    if (p.stockMax != null && stock > p.stockMax!) {
      return _StockStatus(appColors.info, 'Sobrestock');
    }
    return _StockStatus(appColors.success, 'Normal');
  }

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

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _AddProductSheet(products: available),
    );
    if (result == null || !mounted) return;

    final productId = result['productId'] as int;
    final quantity = result['quantity'] as double?;
    final notes = result['notes'] as String?;

    final res = await ref.read(shoppingListRepositoryProvider).addItem(
          ShoppingListItem(
            storeId: storeId,
            productId: productId,
            quantity: quantity,
            notes: notes?.isEmpty == true ? null : notes,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
    if (!mounted) return;
    if (res.isErr) {
      showMbSnack(context, res.failure!.message,
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
    final confirmed = await showMbConfirm(
      context,
      title: 'Eliminar de la lista',
      message: '¿Eliminar este producto de la lista de compras?',
      confirmLabel: 'Eliminar',
      isDestructive: true,
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

class _AddProductSheet extends StatefulWidget {
  final List<ProductStock> products;
  const _AddProductSheet({required this.products});

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  String _search = '';
  ProductStock? _selected;
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final filtered = widget.products
        .where((ps) =>
            ps.product.name.toLowerCase().contains(_search.toLowerCase()))
        .toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: colors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Agregar producto',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MbTextField(
                  hint: 'Buscar producto...',
                  prefixIcon: const Icon(LucideIcons.search, size: 20),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const Gap(8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final ps = filtered[i];
                    final p = ps.product;
                    final isSelected = _selected?.product.id == p.id;
                    final stockStatus = _getStockStatus(ps.stock, p, colors);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: isSelected
                            ? colors.primaryContainer.withValues(alpha: 0.3)
                            : colors.surface,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() {
                            _selected = isSelected ? null : ps;
                            _quantityController.clear();
                            _notesController.clear();
                          }),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                ProductImage(
                                  photoPath: p.photoPath,
                                  width: 44,
                                  height: 44,
                                  borderRadius: 8,
                                ),
                                const Gap(10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall,
                                      ),
                                      const Gap(2),
                                      Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: stockStatus.color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const Gap(4),
                                          Text(
                                            stockStatus.label,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                    color: stockStatus.color),
                                          ),
                                          const Gap(8),
                                          Text(
                                            'Stock: ${fmtQty(ps.stock)}',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  p.purchasePrice.format(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const Gap(8),
                                  Icon(LucideIcons.circle_check,
                                      size: 20, color: colors.primary),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_selected != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(
                      top: BorderSide(color: colors.outlineVariant),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.circle_check,
                              size: 16, color: colors.primary),
                          const Gap(6),
                          Expanded(
                            child: Text(
                              _selected!.product.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Gap(10),
                      MbTextField(
                        controller: _quantityController,
                        label: 'Cantidad (opcional)',
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const Gap(8),
                      MbTextField(
                        controller: _notesController,
                        label: 'Notas (opcional)',
                      ),
                      const Gap(12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                Navigator.pop(context, {
                                  'productId': _selected!.product.id,
                                  'quantity': double.tryParse(
                                      _quantityController.text),
                                  'notes': _notesController.text,
                                });
                              },
                              child: const Text('Agregar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  _StockStatus _getStockStatus(double stock, Product p, AppColors colors) {
    if (stock < 0.0001) {
      return _StockStatus(colors.error, 'Agotado');
    }
    if (stock <= p.stockMin) {
      return _StockStatus(colors.warning, 'Stock bajo');
    }
    if (p.stockMax != null && stock > p.stockMax!) {
      return _StockStatus(colors.info, 'Sobrestock');
    }
    return _StockStatus(colors.success, 'Normal');
  }
}
