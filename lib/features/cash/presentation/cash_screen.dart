import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/security/permission_guard.dart';
import '../../../core/theme/app_colors.dart';
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
        leading: context.canPop()
            ? const BackButton()
            : IconButton(
                tooltip: 'Inicio',
                icon: const Icon(Icons.home),
                onPressed: () => context.go('/'),
              ),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.success.withValues(alpha: 0.12),
                        colors.success.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.success.withValues(alpha: 0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: colors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Caja abierta · Turno activo',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            fmtDate(session.openingDate),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EFECTIVO ESPERADO',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                expected.format(),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: colors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            LucideIcons.banknote,
                            size: 38,
                            color: colors.success.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Responsable',
                                  style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  opener?.fullName ?? '—',
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 24, color: colors.outlineVariant),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Monto Apertura',
                                  style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  session.openingAmount.format(),
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (canManage)
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _manualMovement(context, ref, CashMovementType.cashIn),
                          icon: const Icon(LucideIcons.arrow_down_left, size: 18),
                          label: const Text('Ingreso'),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.successContainer,
                            foregroundColor: colors.onSuccessContainer,
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _manualMovement(context, ref, CashMovementType.cashOut),
                          icon: const Icon(LucideIcons.arrow_up_right, size: 18),
                          label: const Text('Retiro'),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.errorContainer,
                            foregroundColor: colors.onErrorContainer,
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (canClose) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => CashCloseDialog(
                          sessionId: session.id!,
                          summary: summaryAsync.valueOrNull,
                          canAuthorize: canAuthorize,
                        ),
                      ),
                      icon: const Icon(LucideIcons.lock, size: 18),
                      label: const Text('Cerrar Caja'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        side: BorderSide(color: colors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
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
    final colors = context.colors;
    final byMethod = ref.watch(salesByMethodProvider).valueOrNull ?? const {};
    if (byMethod.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen por método de pago',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in byMethod.entries) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        entry.key == PaymentMethod.cash
                            ? LucideIcons.banknote
                            : entry.key == PaymentMethod.card
                                ? LucideIcons.credit_card
                                : LucideIcons.wallet,
                        color: colors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.key.label,
                            style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                          ),
                          Text(
                            entry.value.format(),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
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
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final entry = movements[i];
        final m = entry.movement;
        final isIn = !m.amount.isNegative;
        final dateStr = '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}';

        return Card(
          margin: EdgeInsets.zero,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isIn ? colors.success.withValues(alpha: 0.1) : colors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isIn ? LucideIcons.arrow_down_left : LucideIcons.arrow_up_right,
                    color: isIn ? colors.success : colors.error,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            m.type.label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${isIn ? '+' : ''}${m.amount.format()}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: isIn ? colors.success : colors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (m.note != null && m.note!.isNotEmpty) ...[
                        Text(
                          m.note!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurface,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Row(
                        children: [
                          Icon(LucideIcons.user, size: 12, color: colors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            entry.userName ?? '—',
                            style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                          ),
                          const SizedBox(width: 8),
                          Icon(LucideIcons.clock, size: 12, color: colors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            dateStr,
                            style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
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
    final colors = context.colors;
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
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final s = sales[i];
        final timeStr = '${s.saleDate.hour.toString().padLeft(2, '0')}:${s.saleDate.minute.toString().padLeft(2, '0')}';
        return Card(
          margin: EdgeInsets.zero,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.shopping_bag,
                    color: colors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            s.saleNumber,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            s.total.format(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(LucideIcons.credit_card, size: 12, color: colors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            s.paymentMethod.label,
                            style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                          ),
                          const SizedBox(width: 12),
                          Icon(LucideIcons.clock, size: 12, color: colors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            timeStr,
                            style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
