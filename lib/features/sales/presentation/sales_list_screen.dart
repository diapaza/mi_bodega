import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/security/permission_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/mb_badge.dart';
import '../../../shared/widgets/mb_empty_state.dart';
import '../../../shared/widgets/mb_loading.dart';
import '../../../shared/widgets/mb_snackbar.dart';
import '../../../shared/widgets/mb_text_field.dart';
import '../../auth/domain/entities/auth.dart';
import '../../auth/presentation/session_controller.dart';
import '../../customers/presentation/customers_providers.dart';
import '../../products/presentation/products_providers.dart';
import '../../users/presentation/users_providers.dart';
import '../domain/entities/sale.dart';
import 'sales_providers.dart';

/// Historial de ventas con filtros, detalle y anulación.
class SalesListScreen extends ConsumerWidget {
  const SalesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersProvider).valueOrNull ?? const <AppUser>[];
    final filter = ref.watch(salesFilterProvider);

    String sellerName(int? id) =>
        users.where((u) => u.id == id).map((u) => u.fullName).firstOrNull ?? '—';

    final hasFilters = filter.from != null ||
        filter.to != null ||
        filter.userId != null ||
        filter.method != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas'),
        actions: [
          IconButton(
            tooltip: 'Filtros',
            icon: Badge(
              isLabelVisible: hasFilters,
              label: const Text(''),
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => _showFilters(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              onChanged: (v) => ref
                  .read(salesFilterProvider.notifier)
                  .state = filter.copyWith(search: v.trim()),
              decoration: const InputDecoration(
                hintText: 'Buscar por nº de venta o cliente',
                prefixIcon: Icon(LucideIcons.search),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _QuickFilterChip(
                  label: 'Hoy',
                  selected: filter.from != null &&
                      filter.from == DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day) &&
                      filter.to == null,
                  onTap: () {
                    final now = DateTime.now();
                    ref.read(salesFilterProvider.notifier).state = filter.copyWith(
                      from: () => DateTime(now.year, now.month, now.day),
                      to: () => null,
                    );
                  },
                ),
                const SizedBox(width: 8),
                _QuickFilterChip(
                  label: 'Esta semana',
                  selected: filter.from != null &&
                      filter.from == DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)),
                  onTap: () {
                    final now = DateTime.now();
                    final weekStart = now.subtract(Duration(days: now.weekday - 1));
                    ref.read(salesFilterProvider.notifier).state = filter.copyWith(
                      from: () => DateTime(weekStart.year, weekStart.month, weekStart.day),
                      to: () => null,
                    );
                  },
                ),
                const SizedBox(width: 8),
                _QuickFilterChip(
                  label: 'Este mes',
                  selected: filter.from != null &&
                      filter.from!.month == DateTime.now().month &&
                      filter.from!.year == DateTime.now().year,
                  onTap: () {
                    final now = DateTime.now();
                    ref.read(salesFilterProvider.notifier).state = filter.copyWith(
                      from: () => DateTime(now.year, now.month, 1),
                      to: () => null,
                    );
                  },
                ),
                const SizedBox(width: 8),
                _QuickFilterChip(
                  label: 'Filtros avanzados',
                  selected: hasFilters,
                  onTap: () => _showFilters(context, ref),
                  icon: LucideIcons.sliders_horizontal,
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(filteredSalesProvider);
              },
              child: ref.watch(filteredSalesProvider).when(
              loading: () => const Center(child: MbLoading()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (sales) {
                if (sales.isEmpty) {
                  return const MbEmptyState(
                    icon: LucideIcons.receipt,
                    title: 'Sin ventas',
                    message: 'Las ventas del POS aparecerán aquí.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: sales.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final s = sales[i];
                    return _SaleCard(sale: s, sellerName: sellerName(s.userId));
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

  void _showFilters(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SalesFilterSheet(),
    );
  }
}

class _SalesFilterSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SalesFilterSheet> createState() => _SalesFilterSheetState();
}

class _SalesFilterSheetState extends ConsumerState<_SalesFilterSheet> {
  final _search = TextEditingController();
  DateTime? _from;
  DateTime? _to;
  int? _userId;
  String? _method;

  @override
  void initState() {
    super.initState();
    final f = ref.read(salesFilterProvider);
    _from = f.from;
    _to = f.to;
    _userId = f.userId;
    _method = f.method;
    _search.text = f.search ?? '';
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _apply() {
    final notifier = ref.read(salesFilterProvider.notifier);
    notifier.state = SalesFilter(
      from: _from,
      to: _to,
      userId: _userId,
      method: _method,
      search: _search.text.trim(),
    );
    Navigator.pop(context);
  }

  void _clear() {
    ref.read(salesFilterProvider.notifier).state = const SalesFilter();
    Navigator.pop(context);
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => _from = DateTime(d.year, d.month, d.day));
    }
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => _to = DateTime(d.year, d.month, d.day).add(const Duration(days: 1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersProvider).valueOrNull ?? const <AppUser>[];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filtros', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickFrom,
                    child: Text(_from == null
                        ? 'Desde'
                        : 'Desde ${_from!.day}/${_from!.month}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickTo,
                    child: Text(_to == null
                        ? 'Hasta'
                        : 'Hasta ${_to!.day}/${_to!.month}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MbTextField(
              controller: _search,
              label: 'Nº de venta o cliente',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _userId,
              decoration: const InputDecoration(labelText: 'Vendedor'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                for (final u in users)
                  DropdownMenuItem(value: u.id, child: Text(u.fullName)),
              ],
              onChanged: (v) => setState(() => _userId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Método de pago'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                for (final m in PaymentMethod.values)
                  DropdownMenuItem(value: m.dbName, child: Text(m.label)),
              ],
              onChanged: (v) => setState(() => _method = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clear,
                    child: const Text('Limpiar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _apply,
                    child: const Text('Aplicar'),
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

class _SaleCard extends ConsumerWidget {
  final Sale sale;
  final String sellerName;

  const _SaleCard({required this.sale, required this.sellerName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return Card(
      child: ListTile(
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => _SaleDetailSheet(saleId: sale.id!),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Text(sale.saleNumber, style: theme.textTheme.titleSmall),
            if (sale.status == SaleStatus.cancelled) ...[
              const SizedBox(width: 8),
              const MbBadge('Anulada', tone: MbBadgeTone.error),
            ],
          ],
        ),
        subtitle: Text(
          '${fmtDate(sale.saleDate)} · $sellerName · ${sale.paymentMethod.label}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              sale.total.format(),
              style: theme.textTheme.titleSmall?.copyWith(color: colors.primary),
            ),
            if (sale.discount.cents > 0)
              Text(
                'Desc. ${sale.discount.format()}',
                style: theme.textTheme.bodySmall?.copyWith(color: colors.warning),
              ),
          ],
        ),
      ),
    );
  }
}

class _SaleDetailSheet extends ConsumerWidget {
  final int saleId;

  const _SaleDetailSheet({required this.saleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final detailAsync = ref.watch(saleDetailProvider(saleId));
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final canCancel = session?.can('sales.cancel') ?? false;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: detailAsync.when(
        loading: () => const Center(child: MbLoading()),
        error: (e, _) => Text('Error: $e'),
        data: (detail) {
          if (detail == null) return const Text('Venta no encontrada');
          final sale = detail.sale;
          final customerId = sale.customerId;
          final customerName = customerId == null
              ? null
              : ref.watch(customerDetailProvider(customerId)).valueOrNull?.name;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(sale.saleNumber, style: theme.textTheme.titleLarge),
                  if (sale.status == SaleStatus.cancelled) ...[
                    const SizedBox(width: 8),
                    const MbBadge('Anulada', tone: MbBadgeTone.error),
                  ],
                ],
              ),
              Text(
                fmtDate(sale.saleDate),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              if (customerName != null)
                Text('Cliente: $customerName', style: theme.textTheme.bodyMedium),
              const Divider(),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in detail.items) _ItemRow(item: item),
                  ],
                ),
              ),
              const Divider(),
              _InfoRow(label: 'Subtotal', value: sale.subtotal.format()),
              if (sale.discount.cents > 0)
                _InfoRow(label: 'Descuento', value: '-${sale.discount.format()}'),
              _InfoRow(label: 'Total', value: sale.total.format(), bold: true),
              _InfoRow(label: 'Método', value: sale.paymentMethod.label),
              if (sale.amountReceived != null) ...[
                _InfoRow(label: 'Recibido', value: sale.amountReceived!.format()),
                _InfoRow(label: 'Vuelto', value: sale.changeDue!.format(), bold: true),
              ],
              if (sale.status == SaleStatus.cancelled &&
                  sale.cancelReason != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Motivo de anulación: ${sale.cancelReason}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: colors.error),
                ),
              ],
              if (canCancel && sale.status == SaleStatus.completed) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  ),
                  onPressed: () => _cancel(context, ref, sale),
                  icon: const Icon(LucideIcons.circle_x),
                  label: const Text('Anular venta'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Sale sale) async {
    final guard =
        ensureAllowed(ref.read(sessionPermissionsProvider), 'sales.cancel');
    if (guard.isErr) {
      if (context.mounted) {
        showMbSnack(context, guard.failure!.message);
      }
      return;
    }
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular venta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Se repondrá el stock por ${sale.total.format()}.'),
            const SizedBox(height: 12),
            MbTextField(controller: reasonCtrl, label: 'Motivo de anulación *', maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) {
                showMbSnack(ctx, 'El motivo es obligatorio.');
                return;
              }
              Navigator.pop(ctx, reasonCtrl.text.trim());
            },
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (confirmed == null) return;
    final userId = ref.read(sessionControllerProvider).valueOrNull?.user?.id ?? 0;
    final result = await ref
        .read(saleRepositoryProvider)
        .cancelSale(sale.id!, userId, reason: confirmed);
    if (!context.mounted) return;
    showMbSnack(context, result.isOk ? 'Venta anulada' : result.failure!.message);
    if (result.isOk) Navigator.pop(context);
  }
}

class _ItemRow extends ConsumerWidget {
  final SaleItem item;

  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product =
        ref.watch(productByIdProvider(item.productId)).valueOrNull?.product;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(product?.name ?? 'Producto #${item.productId}'),
      subtitle: Text('${fmtQty(item.quantity)} × ${item.unitPrice.format()}'),
      trailing: Text(item.subtotal.format()),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _InfoRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value,
              style: bold ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _QuickFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: icon != null ? Icon(icon, size: 16) : null,
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
