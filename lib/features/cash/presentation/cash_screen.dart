import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/security/permission_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mb_badge.dart';
import '../../../shared/widgets/mb_empty_state.dart';
import '../../../shared/widgets/mb_snackbar.dart';
import '../../../shared/widgets/mb_text_field.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/domain/entities/auth.dart';
import '../../auth/presentation/session_controller.dart';
import '../../pos/presentation/pos_providers.dart';
import '../../sales/domain/entities/sale.dart';
import '../../users/presentation/users_providers.dart';
import '../domain/entities/cash.dart';
import 'cash_close_dialog.dart';
import 'cash_providers.dart';

/// Pantalla de caja: apertura, movimientos, ventas, cierre e historial.
class CashScreen extends ConsumerWidget {
  const CashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final canOpen = session?.can('cash.open') ?? false;
    final canClose = session?.can('cash.close') ?? false;
    final canManage = session?.can('cash.manage') ?? false;
    final canAuthorize = session?.can('cash.authorize') ?? false;

    final openSession = ref.watch(openCashSessionProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caja'),
        actions: [
          IconButton(
            tooltip: 'Historial de turnos',
            icon: const Icon(LucideIcons.clock),
            onPressed: () => context.push('/cash/history'),
          ),
        ],
      ),
      body: openSession == null
          ? _ClosedState(canOpen: canOpen)
          : _OpenState(
              session: openSession,
              canClose: canClose,
              canManage: canManage,
              canAuthorize: canAuthorize,
            ),
    );
  }
}

class _ClosedState extends ConsumerWidget {
  final bool canOpen;

  const _ClosedState({required this.canOpen});

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final guard =
        ensureAllowed(ref.read(sessionPermissionsProvider), 'cash.open');
    if (guard.isErr) {
      if (context.mounted) {
        showMbSnack(context, guard.failure!.message);
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
    final registerId = ref.read(defaultRegisterProvider).valueOrNull;
    final userId = ref.read(sessionControllerProvider).valueOrNull?.user?.id;
    if (registerId == null || userId == null) return;
    final result = await ref.read(cashRepositoryProvider).openSession(
          registerId: registerId,
          userId: userId,
          openingAmount: Money.fromSoles(double.tryParse(amount) ?? 0),
        );
    if (!context.mounted) return;
    if (result.isErr) {
      showMbSnack(context, result.failure!.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MbEmptyState(
      icon: LucideIcons.lock,
      title: 'Caja cerrada',
      message: 'Abre la caja para iniciar el turno.',
      action: canOpen
          ? FilledButton.icon(
              onPressed: () => _open(context, ref),
              icon: const Icon(LucideIcons.lock_open),
              label: const Text('Abrir caja'),
            )
          : null,
    );
  }
}

class _OpenState extends ConsumerWidget {
  final CashSession session;
  final bool canClose;
  final bool canManage;
  final bool canAuthorize;

  const _OpenState({
    required this.session,
    required this.canClose,
    required this.canManage,
    required this.canAuthorize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final users = ref.watch(usersProvider).valueOrNull ?? const <AppUser>[];
    final opener = users.where((u) => u.id == session.userId).firstOrNull;
    final summaryAsync = ref.watch(cashSessionSummaryProvider);
    final expected =
        summaryAsync.valueOrNull?.expected ?? session.expectedAmount ?? session.openingAmount;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const MbBadge('Caja abierta', tone: MbBadgeTone.success),
                        const Spacer(),
                        Text(
                          fmtDate(session.openingDate),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const Gap(8),
                    Text('Responsable: ${opener?.fullName ?? '—'}'),
                    Text('Apertura: ${session.openingAmount.format()}'),
                    const Gap(8),
                    Text('Efectivo esperado', style: theme.textTheme.bodySmall),
                    Text(
                      expected.format(),
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(color: colors.primary),
                    ),
                    const Gap(12),
                    if (canManage)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _manualMovement(context, ref, CashMovementType.cashIn),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.success,
                                minimumSize: const Size(0, 44),
                              ),
                              child: const Text('Ingreso'),
                            ),
                          ),
                          const Gap(8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _manualMovement(context, ref, CashMovementType.cashOut),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.error,
                                minimumSize: const Size(0, 44),
                              ),
                              child: const Text('Retiro'),
                            ),
                          ),
                        ],
                      ),
                    if (canClose) ...[
                      const Gap(8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => CashCloseDialog(
                              sessionId: session.id!,
                              summary: summaryAsync.valueOrNull,
                              canAuthorize: canAuthorize,
                            ),
                          ),
                          icon: const Icon(LucideIcons.lock, size: 18),
                          label: const Text('Cerrar caja'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          _ByMethodBreakdown(),
          const TabBar(
            tabs: [Tab(text: 'Movimientos'), Tab(text: 'Ventas del turno')],
          ),
          const Expanded(
            child: TabBarView(
              children: [_MovementsTab(), _SalesTab()],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _manualMovement(
    BuildContext context,
    WidgetRef ref,
    CashMovementType type,
  ) async {
    final guard =
        ensureAllowed(ref.read(sessionPermissionsProvider), 'cash.manage');
    if (guard.isErr) {
      if (context.mounted) {
        showMbSnack(context, guard.failure!.message);
      }
      return;
    }
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == CashMovementType.cashIn ? 'Ingreso manual' : 'Retiro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MbTextField(
              controller: amountCtrl,
              label: 'Monto (S/)',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const Gap(8),
            MbTextField(controller: noteCtrl, label: 'Motivo *'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final amount = Money.fromSoles(double.tryParse(amountCtrl.text) ?? 0);
    final note = noteCtrl.text.trim();
    if (note.isEmpty) {
      if (!context.mounted) return;
      showMbSnack(context, 'El motivo es obligatorio.');
      return;
    }
    final userId = ref.read(sessionControllerProvider).valueOrNull?.user?.id;
    final result = await ref.read(cashRepositoryProvider).addManualMovement(
          sessionId: session.id!,
          type: type,
          amount: amount,
          userId: userId,
          note: note,
        );
    if (!context.mounted) return;
    showMbSnack(context, result.isOk ? 'Movimiento registrado' : result.failure!.message);
  }
}

class _ByMethodBreakdown extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final byMethod = ref.watch(salesByMethodProvider).valueOrNull ?? const {};
    if (byMethod.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in byMethod.entries)
            Chip(
              label: Text(
                '${entry.key.label}: ${entry.value.format()}',
                style: theme.textTheme.labelMedium,
              ),
            ),
        ],
      ),
    );
  }
}

class _MovementsTab extends ConsumerWidget {
  const _MovementsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final movements = ref.watch(sessionMovementsProvider).valueOrNull ?? const [];
    if (movements.isEmpty) {
      return const MbEmptyState(
        icon: LucideIcons.arrow_up_down,
        title: 'Sin movimientos',
        message: 'Las entradas y salidas del turno aparecerán aquí.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: movements.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final entry = movements[i];
        final m = entry.movement;
        final isIn = !m.amount.isNegative;
        return ListTile(
          dense: true,
          leading: Icon(
            isIn ? LucideIcons.arrow_down_left : LucideIcons.arrow_up_right,
            color: isIn ? colors.success : colors.error,
          ),
          title: Text(m.type.label),
          subtitle: Text(
            [if (m.note != null && m.note!.isNotEmpty) m.note, entry.userName]
                .whereType<String>()
                .join(' · '),
          ),
          trailing: Text(
            '${isIn ? '+' : ''}${m.amount.format()}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: isIn ? colors.success : colors.error,
            ),
          ),
        );
      },
    );
  }
}

class _SalesTab extends ConsumerWidget {
  const _SalesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sales = ref.watch(sessionSalesProvider).valueOrNull ?? const <Sale>[];
    if (sales.isEmpty) {
      return const MbEmptyState(
        icon: LucideIcons.receipt,
        title: 'Sin ventas en el turno',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sales.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final s = sales[i];
        return ListTile(
          dense: true,
          title: Text(s.saleNumber),
          subtitle: Text(s.paymentMethod.label),
          trailing: Text(
            s.total.format(),
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
          ),
        );
      },
    );
  }
}
