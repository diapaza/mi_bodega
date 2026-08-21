import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../shared/widgets/mb_badge.dart';
import '../../../shared/widgets/mb_empty_state.dart';
import '../../../shared/widgets/mb_card.dart';
import '../../../shared/widgets/mb_money_text.dart';
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
            _MetricCard(
              label: 'VENTAS HOY',
              money: today?.revenue,
              value: today?.revenue.format(),
              loading: todayAsync.isLoading,
              caption: '${today?.count ?? 0} venta${today?.count == 1 ? '' : 's'} concretada${today?.count == 1 ? '' : 's'}',
              isHero: true,
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05),
            const Gap(12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Ganancia hoy',
                    money: today?.grossProfit,
                    value: today?.grossProfit.format(),
                    loading: todayAsync.isLoading,
                    caption: 'Ingresos − Costos',
                    highlight: true,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: _MetricCard(
                    label: 'Ventas del mes',
                    money: month?.revenue,
                    value: month?.revenue.format(),
                    loading: monthAsync.isLoading,
                    caption: '${month?.count ?? 0} ventas',
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.05),
            Gap(12),
            Card(
              child: ListTile(
                leading: Icon(
                  cashOpen == null ? LucideIcons.lock : LucideIcons.circle_check,
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
              Gap(12),
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
            Gap(16),
            Text('Más vendidos', style: theme.textTheme.titleMedium),
            Gap(8),
            if (top.isEmpty)
              const Text('Aún no hay ventas.')
            else
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: top.length > 5 ? 5 : top.length,
                  separatorBuilder: (_, _) => const Gap(8),
                  itemBuilder: (context, i) {
                    final t = top[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.package, color: colors.primary),
                            Gap(4),
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
            Gap(16),
            Text('Actividad reciente', style: theme.textTheme.titleMedium),
            Gap(8),
            if (recent.isEmpty)
              const MbEmptyState(
                icon: LucideIcons.receipt,
                title: 'Sin ventas',
                message: 'Las ventas del día aparecerán aquí.',
              )
            else
              MbCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < recent.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: recent[i].status == SaleStatus.cancelled
                            ? const MbBadge('Anulada', tone: MbBadgeTone.error)
                            : const MbBadge('Venta', tone: MbBadgeTone.success),
                        title: Text(recent[i].saleNumber),
                        subtitle: Text(
                          '${recent[i].saleDate.hour.toString().padLeft(2, '0')}:'
                          '${recent[i].saleDate.minute.toString().padLeft(2, '0')} · '
                          '${recent[i].paymentMethod.label}',
                        ),
                        trailing: Text(
                          recent[i].total.format(),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: recent[i].status == SaleStatus.cancelled
                                ? colors.onSurfaceVariant
                                : colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
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
  final Money? money;
  final String caption;
  final bool highlight;
  final bool loading;
  final bool isHero;

  const _MetricCard({
    required this.label,
    this.value,
    this.money,
    required this.caption,
    this.highlight = false,
    this.loading = false,
    this.isHero = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    if (isHero) {
      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B00), Color(0xFFFF8800)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B00).withOpacity(0.25),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: const Color(0xFFF1F5F9),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const Gap(8),
            if (loading)
              Container(
                width: 80,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(6),
                ),
              )
            else if (money != null)
              MbMoneyText(
                money!,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                currencyStyle: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFF1F5F9),
                  fontWeight: FontWeight.w400,
                ),
              )
            else
              Text(
                value ?? '—',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            const Gap(6),
            Text(
              caption,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFFF1F5F9),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      color: highlight
          ? colors.primaryContainer.withOpacity(0.2)
          : colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: const Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(6),
            if (loading)
              Container(
                width: 80,
                height: 24,
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
              )
            else if (money != null)
              MbMoneyText(
                money!,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              Text(
                value ?? '—',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                ),
              ),
            const Gap(4),
            Text(
              caption,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF64748B),
                fontSize: 12,
              ),
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
      avatar: Icon(LucideIcons.triangle_alert, size: 16, color: fg),
      label: Text(label),
      backgroundColor: bg,
      onPressed: onTap,
    );
  }
}
