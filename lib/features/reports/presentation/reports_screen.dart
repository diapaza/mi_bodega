import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/domain/entities/auth.dart';
import '../../users/presentation/users_providers.dart';
import '../../sales/domain/entities/sale.dart';
import '../domain/entities/report.dart';
import 'reports_providers.dart';

/// Reportes: ventas por periodo, márgenes, más vendidos y desgloses.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final summaryAsync = ref.watch(reportSummaryProvider);
    final topAsync = ref.watch(reportTopProductsProvider);
    final dailyAsync = ref.watch(reportDailyProvider);
    final users = ref.watch(usersProvider).valueOrNull ?? const <AppUser>[];

    String userName(int? id) =>
        users.where((u) => u.id == id).map((u) => u.fullName).firstOrNull ?? '—';

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final p in ReportPeriod.values)
                ChoiceChip(
                  label: Text(switch (p) {
                    ReportPeriod.today => 'Hoy',
                    ReportPeriod.yesterday => 'Ayer',
                    ReportPeriod.last7 => 'Últimos 7 días',
                    ReportPeriod.thisMonth => 'Este mes',
                  }),
                  selected: period == p,
                  onSelected: (_) =>
                      ref.read(reportPeriodProvider.notifier).state = p,
                ),
            ],
          ),
          const SizedBox(height: 16),
          summaryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (summary) {
              if (summary == null) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SummaryCard(summary: summary),
                  const SizedBox(height: 16),
                  Text('Métodos de pago',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final e in summary.byMethod.entries)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.key.label),
                      trailing: Text(e.value.format()),
                    ),
                  if (summary.byUser.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Por vendedor',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final e in summary.byUser.entries)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(userName(e.key)),
                        trailing: Text(e.value.format()),
                      ),
                  ],
                  const SizedBox(height: 16),
                  Text('Más vendidos',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
          topAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (top) => top.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      for (final t in top)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.trending_up, size: 20),
                          title: Text(t.productStock.product.name),
                          subtitle: Text(
                              '${t.quantity.toStringAsFixed(0)} vendidos · '
                              '${t.revenue.format()}'),
                          trailing: Text(t.profit.format(),
                              style: TextStyle(
                                color: context.colors.success,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          Text('Serie diaria (7 días)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          dailyAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (daily) => daily.isEmpty
                ? const SizedBox.shrink()
                : _DailyChart(points: daily),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final SalesSummary summary;

  const _SummaryCard({required this.summary});

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
            Text('Ingresos', style: theme.textTheme.bodySmall),
            Text(
              summary.revenue.format(),
              style: theme.textTheme.headlineMedium?.copyWith(color: colors.primary),
            ),
            Text('${summary.count} venta${summary.count == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall),
            const Divider(),
            _row(context, 'Costo de lo vendido', summary.cogs.format()),
            _row(
              context,
              'Ganancia bruta estimada',
              summary.grossProfit.format(),
              highlight: true,
            ),
            _row(context, 'Margen', '${(summary.margin * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            Text(
              'Ganancia bruta estimada = ingresos − costo de lo vendido '
              '(sin gastos operativos).',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool highlight = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: highlight
                ? theme.textTheme.titleSmall
                    ?.copyWith(color: context.colors.primary)
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _DailyChart extends StatelessWidget {
  final List<DailySalesPoint> points;

  const _DailyChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final max = points
        .fold<int>(0, (m, p) => p.revenue.cents > m ? p.revenue.cents : m);
    return Column(
      children: [
        for (final p in points.reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    '${p.day.day}/${p.day.month}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 16,
                      color: colors.surfaceVariant,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: max == 0 ? 0 : p.revenue.cents / max,
                        child: Container(
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: Text(
                    p.revenue.format(),
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
