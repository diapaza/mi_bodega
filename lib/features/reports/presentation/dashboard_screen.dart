import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mb_badge.dart';
import '../../../shared/widgets/mb_empty_state.dart';
import '../../auth/presentation/session_controller.dart';
import '../../cash/presentation/cash_providers.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../pos/presentation/pos_providers.dart';
import '../../sales/domain/entities/sale.dart';
import 'reports_providers.dart';

/// Dashboard del propietario: ingresos, ganancia estimada, caja y alertas.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final todayAsync = ref.watch(todaySummaryProvider);
    final monthAsync = ref.watch(monthSummaryProvider);
    final today = todayAsync.valueOrNull;
    final month = monthAsync.valueOrNull;
    final cashOpen = ref.watch(openCashSessionProvider).valueOrNull;
    final cashSummary = ref.watch(cashSessionSummaryProvider).valueOrNull;
    final low = ref.watch(lowStockProvider).valueOrNull ?? const [];
    final out = ref.watch(outOfStockProvider).valueOrNull ?? const [];
    final top = ref.watch(topSoldProvider).valueOrNull ?? const [];
    final recent = ref.watch(recentSalesProvider).valueOrNull ?? const <Sale>[];

    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${session?.user?.fullName.split(' ').first ?? ''}'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todaySummaryProvider);
          ref.invalidate(monthSummaryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Ventas hoy',
                    value: today?.revenue.format(),
                    loading: todayAsync.isLoading,
                    caption:
                        '${today?.count ?? 0} venta${today?.count == 1 ? '' : 's'}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Ganancia bruta hoy',
                    value: today?.grossProfit.format(),
                    loading: todayAsync.isLoading,
                    caption: 'ingresos − costo',
                    highlight: true,
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05),
            const SizedBox(height: 12),
            _MetricCard(
              label: 'Ventas del mes',
              value: month?.revenue.format(),
              loading: monthAsync.isLoading,
              caption:
                  '${month?.count ?? 0} venta${month?.count == 1 ? '' : 's'}'
                  ' · ganancia ${month?.grossProfit.format() ?? 'S/ 0.00'}',
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.05),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(
                  cashOpen == null ? Icons.lock_outline : Icons.check_circle,
                  color: cashOpen == null ? colors.warning : colors.success,
                ),
                title: Text(cashOpen == null ? 'Caja cerrada' : 'Caja abierta'),
                subtitle: Text(cashOpen == null
                    ? 'Abre la caja para iniciar el turno.'
                    : 'Efectivo esperado: '
                        '${(cashSummary?.expected ?? cashOpen.openingAmount).format()}'),
                trailing: TextButton(
                  onPressed: () => context.push('/cash'),
                  child: const Text('Ver caja'),
                ),
              ),
            ),
            if (low.isNotEmpty || out.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (low.isNotEmpty)
                    _AlertChip(
                      label: '${low.length} con stock bajo',
                      tone: MbBadgeTone.warning,
                      onTap: () => context.push('/inventory'),
                    ),
                  if (out.isNotEmpty)
                    _AlertChip(
                      label: '${out.length} agotados',
                      tone: MbBadgeTone.error,
                      onTap: () => context.push('/inventory'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text('Más vendidos', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (top.isEmpty)
              const Text('Aún no hay ventas.')
            else
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: top.length > 5 ? 5 : top.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final t = top[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, color: colors.primary),
                            const SizedBox(height: 4),
                            Text(
                              t.productStock.product.name,
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              '${t.soldQuantity.toStringAsFixed(0)} uds',
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: 100 * i)).slideY(begin: 0.05);
                  },
                ),
              ),
            const SizedBox(height: 16),
            Text('Actividad reciente', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (recent.isEmpty)
              const MbEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Sin ventas',
                message: 'Las ventas del día aparecerán aquí.',
              )
            else
              for (final s in recent)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: s.status == SaleStatus.cancelled
                      ? const MbBadge('Anulada', tone: MbBadgeTone.error)
                      : const MbBadge('Venta', tone: MbBadgeTone.success),
                  title: Text(s.saleNumber),
                  subtitle: Text(
                    '${s.saleDate.hour.toString().padLeft(2, '0')}:'
                    '${s.saleDate.minute.toString().padLeft(2, '0')} · '
                    '${s.paymentMethod.label}',
                  ),
                  trailing: Text(
                    s.total.format(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: s.status == SaleStatus.cancelled
                          ? colors.onSurfaceVariant
                          : colors.primary,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String? value;
  final String caption;
  final bool highlight;
  final bool loading;

  const _MetricCard({
    required this.label,
    this.value,
    required this.caption,
    this.highlight = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            if (loading)
              Container(
                width: 80,
                height: 28,
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
              )
            else
            Text(
              value ?? '—',
              style: theme.textTheme.titleLarge?.copyWith(
                color: highlight ? colors.success : colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              caption,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  final String label;
  final MbBadgeTone tone;
  final VoidCallback onTap;

  const _AlertChip({
    required this.label,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (bg, fg) = switch (tone) {
      MbBadgeTone.warning => (colors.warningContainer, colors.warning),
      MbBadgeTone.error => (colors.errorContainer, colors.error),
      _ => (colors.surfaceVariant, colors.onSurfaceVariant),
    };
    return ActionChip(
      avatar: Icon(Icons.warning_amber_rounded, size: 16, color: fg),
      label: Text(label),
      backgroundColor: bg,
      onPressed: onTap,
    );
  }
}
