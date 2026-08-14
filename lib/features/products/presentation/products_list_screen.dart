import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mb_empty_state.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../domain/entities/product.dart';
import 'products_providers.dart';
import 'widgets/product_card.dart';
import 'widgets/product_list_tile.dart';

class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key});

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(productListFilterProvider.notifier).state = ref
          .read(productListFilterProvider)
          .copyWith(search: value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final canCreate = session?.can('products.create') ?? false;
    final canManageCatalog = session?.can('categories.manage') ?? false;

    final filter = ref.watch(productListFilterProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final brands = ref.watch(brandsProvider).valueOrNull ?? const [];
    final viewMode = ref.watch(productViewModeProvider);
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          if (canManageCatalog)
            PopupMenuButton<String>(
              onSelected: (v) => context.push('/$v'),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'categories', child: Text('Categorías')),
                PopupMenuItem(value: 'brands', child: Text('Marcas')),
                PopupMenuItem(value: 'units', child: Text('Unidades')),
              ],
            ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              heroTag: 'products-fab',
              onPressed: () => context.push('/products/new'),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, código o barras',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _onSearch('');
                        },
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
                _FilterDropdown<int?>(
                  value: filter.categoryId,
                  hint: 'Categoría',
                  items: [
                    for (final c in categories)
                      (c.id, c.name),
                  ],
                  onChanged: (v) => ref
                      .read(productListFilterProvider.notifier)
                      .state = filter.copyWith(categoryId: () => v),
                ),
                const SizedBox(width: 8),
                _FilterDropdown<int?>(
                  value: filter.brandId,
                  hint: 'Marca',
                  items: [
                    for (final b in brands)
                      (b.id, b.name),
                  ],
                  onChanged: (v) => ref
                      .read(productListFilterProvider.notifier)
                      .state = filter.copyWith(brandId: () => v),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Solo activos'),
                  selected: filter.onlyActive,
                  onSelected: (v) => ref
                      .read(productListFilterProvider.notifier)
                      .state = filter.copyWith(onlyActive: v),
                ),
                const SizedBox(width: 8),
                _SortDropdown(
                  sort: filter.sort,
                  onChanged: (s) => ref
                      .read(productListFilterProvider.notifier)
                      .state = filter.copyWith(sort: s),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: viewMode == ProductViewMode.grid ? 'Vista lista' : 'Vista cards',
                  icon: Icon(viewMode == ProductViewMode.grid
                      ? Icons.view_list_outlined
                      : Icons.grid_view_outlined),
                  onPressed: () => ref.read(productViewModeProvider.notifier).state =
                      viewMode == ProductViewMode.grid
                          ? ProductViewMode.list
                          : ProductViewMode.grid,
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(productsProvider);
                ref.invalidate(categoriesProvider);
                ref.invalidate(brandsProvider);
              },
              child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (products) {
                if (products.isEmpty) {
                  return const MbEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Sin productos',
                    message: 'Crea tu primer producto para empezar.',
                  );
                }
                if (viewMode == ProductViewMode.grid) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, i) {
                      final item = products[i];
                      return ProductCard(
                        item: item,
                        onTap: () => context.push('/products/${item.product.id}'),
                        onFavorite: item.product.id != null
                            ? () => ref.read(productRepositoryProvider).setFavorite(
                                item.product.id!,
                                !item.product.isFavorite,
                              )
                            : null,
                      );
                    },
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = products[i];
                      return ProductListTile(
                        item: item,
                        onTap: () => context.push('/products/${item.product.id}'),
                        onFavorite: item.product.id != null
                            ? () => ref.read(productRepositoryProvider).setFavorite(
                                item.product.id!,
                                !item.product.isFavorite,
                              )
                            : null,
                      );
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

class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final String hint;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DropdownButton<T>(
      value: value,
      hint: Text(hint),
      underline: const SizedBox.shrink(),
      icon: Icon(Icons.arrow_drop_down, color: colors.onSurfaceVariant),
      items: [
        DropdownMenuItem(value: null as T, child: Text('Todas las $hint')),
        for (final (id, name) in items)
          DropdownMenuItem(value: id, child: Text(name)),
      ],
      onChanged: (v) => onChanged(v as T),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  final ProductSort sort;
  final ValueChanged<ProductSort> onChanged;

  const _SortDropdown({required this.sort, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<ProductSort>(
      value: sort,
      underline: const SizedBox.shrink(),
      items: const [
        DropdownMenuItem(value: ProductSort.nameAsc, child: Text('Nombre')),
        DropdownMenuItem(value: ProductSort.priceAsc, child: Text('Precio ↑')),
        DropdownMenuItem(value: ProductSort.priceDesc, child: Text('Precio ↓')),
        DropdownMenuItem(value: ProductSort.stockAsc, child: Text('Stock ↑')),
        DropdownMenuItem(value: ProductSort.stockDesc, child: Text('Stock ↓')),
      ],
      onChanged: (v) => onChanged(v ?? ProductSort.nameAsc),
    );
  }
}
