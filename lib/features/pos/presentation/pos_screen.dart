import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/security/permission_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mb_text_field.dart';
import '../../auth/presentation/session_controller.dart';
import '../../cash/domain/entities/cash.dart';
import '../../cash/presentation/cash_providers.dart';
import '../../products/domain/entities/product.dart';
import '../../products/presentation/widgets/product_image.dart';
import 'cart_controller.dart';
import 'cart_sheet.dart';
import 'pos_providers.dart';

/// Punto de venta: pantalla única (búsqueda + grid + carrito + cobro).
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
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
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(posSearchProvider.notifier).state = value.trim();
    });
  }

  void _addToCart(ProductStock item) {
    final added = ref.read(cartProvider.notifier).add(item);
    if (added) HapticFeedback.selectionClick();
    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Stock insuficiente de ${item.product.name}'),
      ));
    }
  }

  Future<void> _openCash(int registerId, int userId) async {
    final guard =
        ensureAllowed(ref.read(sessionPermissionsProvider), 'cash.open');
    if (guard.isErr) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(guard.failure!.message)),
        );
      }
      return;
    }
    final controller = TextEditingController(text: '0.00');
    final amount = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abrir caja'),
        content: MbTextField(
          controller: controller,
          label: 'Monto inicial (S/)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
    if (amount == null) return;
    final result = await ref.read(cashRepositoryProvider).openSession(
          registerId: registerId,
          userId: userId,
          openingAmount: Money.fromSoles(double.tryParse(amount) ?? 0),
        );
    if (!mounted) return;
    if (result.isErr) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.failure!.message)),
      );
    }
  }

  Future<void> _closeCash(CashSession session, int userId) async {
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
    final controller = TextEditingController();
    final expected = session.expectedAmount ?? Money.zero();
    final counted = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar caja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Efectivo esperado: ${expected.format()}'),
            const SizedBox(height: 12),
            MbTextField(
              controller: controller,
              label: 'Dinero contado (S/)',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    if (counted == null) return;
    final result = await ref.read(cashRepositoryProvider).closeSession(
          sessionId: session.id!,
          closedBy: userId,
          countedAmount: Money.fromSoles(double.tryParse(counted) ?? 0),
          authorizeDifference: false,
        );
    if (!mounted) return;
    final r = result.orNull;
    if (r != null && r.difference != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Caja cerrada · diferencia ${r.difference!.format()}'),
      ));
    } else if (result.isErr) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.failure!.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final userId = session?.user?.id ?? 0;
    final canOpenCash = session?.can('cash.open') ?? false;
    final canCloseCash = session?.can('cash.close') ?? false;

    final cart = ref.watch(cartProvider);
    final cashSessionAsync = ref.watch(openCashSessionProvider);
    final registerId = ref.watch(defaultRegisterProvider).valueOrNull;

    final productsAsync = ref.watch(posProductsProvider);
    final favorites = ref.watch(favoriteProductsProvider).valueOrNull ?? const [];
    final topSold = ref.watch(topSoldProvider).valueOrNull ?? const [];

    final frequent = <ProductStock>{...favorites};
    for (final t in topSold) {
      if (frequent.length >= 8) break;
      frequent.add(t.productStock);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _CashBanner(
              session: cashSessionAsync.valueOrNull,
              canOpen: canOpenCash,
              canClose: canCloseCash,
              onOpen: () => _openCash(registerId ?? 0, userId),
              onClose: () {
                final session = cashSessionAsync.valueOrNull;
                if (session != null) _closeCash(session, userId);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: _onSearch,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Buscar producto…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _search.clear();
                            ref.read(posSearchProvider.notifier).state = '';
                          },
                        )
                      : null,
                ),
              ),
            ),
            if (frequent.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final item in frequent)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: Icon(item.product.isFavorite ? Icons.star : Icons.trending_up,
                              size: 16, color: colors.secondary),
                          label: Text(item.product.name),
                          onPressed: () => _addToCart(item),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: productsAsync.when(
                loading: () => const _PosSkeletonGrid(),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (products) {
                  if (products.isEmpty) {
                    return const Center(child: Text('Sin resultados'));
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 160,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, i) {
                      final item = products[i];
                      return _PosProductCard(item: item, onTap: () => _addToCart(item));
                    },
                  );
                },
              ),
            ),
            _CartBar(
              cart: cart,
              hasCashSession: cashSessionAsync.valueOrNull != null,
              enabled: !cart.isEmpty && cashSessionAsync.valueOrNull != null,
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => const CartSheet(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashBanner extends ConsumerWidget {
  final CashSession? session;
  final bool canOpen;
  final bool canClose;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  const _CashBanner({
    required this.session,
    required this.canOpen,
    required this.canClose,
    required this.onOpen,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = session;
    final theme = Theme.of(context);
    final colors = context.colors;
    final summaryAsync = ref.watch(cashSessionSummaryProvider);
    final liveExpected =
        summaryAsync.valueOrNull?.expected ?? s?.expectedAmount ?? s?.openingAmount;
    if (s == null) {
      return Container(
        width: double.infinity,
        color: colors.warningContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: colors.warning, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('Caja cerrada. Abre la caja para vender.')),
            if (canOpen)
              FilledButton(
                onPressed: onOpen,
                child: const Text('Abrir caja'),
              ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      color: colors.successContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: colors.success, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Caja abierta · ${(liveExpected ?? s.openingAmount).format()}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (canClose)
            TextButton(
              onPressed: onClose,
              child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _PosSkeletonGrid extends StatelessWidget {
  const _PosSkeletonGrid();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.9,
      ),
      itemCount: 8,
      itemBuilder: (context, i) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              height: 10,
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 50,
              height: 12,
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosProductCard extends StatelessWidget {
  final ProductStock item;
  final VoidCallback onTap;

  const _PosProductCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final p = item.product;
    final disabled = item.outOfStock;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.outlineVariant),
            color: disabled ? colors.surfaceVariant : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ProductImage(
                  photoPath: p.photoPath,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Text(
                p.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: disabled ? colors.outline : null,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.salePrice.format(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: disabled ? colors.outline : colors.primary,
                      ),
                    ),
                  ),
                  if (item.outOfStock)
                    Icon(Icons.block, color: colors.error, size: 16)
                  else if (item.lowStock)
                    Icon(Icons.warning_amber_rounded,
                        color: colors.warning, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  final CartState cart;
  final bool enabled;
  final bool hasCashSession;
  final VoidCallback onTap;

  const _CartBar({
    required this.cart,
    required this.enabled,
    required this.hasCashSession,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${cart.totalQuantity.toInt()} artículos',
                    style: theme.textTheme.bodySmall),
                Text(
                  cart.total.format(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: !hasCashSession
                ? 'Abre la caja para vender'
                : cart.isEmpty
                    ? 'Agrega productos al carrito'
                    : '',
            child: FilledButton.icon(
              onPressed: enabled ? onTap : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(150, 52),
              ),
              icon: const Icon(Icons.shopping_cart_checkout),
              label: Text(!hasCashSession ? 'Abrir caja' : 'Cobrar'),
            ),
          ),
        ],
      ),
    );
  }
}
