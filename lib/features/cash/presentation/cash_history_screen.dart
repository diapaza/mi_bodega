import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/mb_badge.dart';
import '../../../shared/widgets/mb_empty_state.dart';
import '../../auth/domain/entities/auth.dart';
import '../../users/presentation/users_providers.dart';
import 'cash_providers.dart';

/// Historial de turnos de caja cerrados.
class CashHistoryScreen extends ConsumerWidget {
  const CashHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final users = ref.watch(usersProvider).valueOrNull ?? const <AppUser>[];
    final historyAsync = ref.watch(sessionHistoryProvider);

    String userName(int? id) =>
        users.where((u) => u.id == id).map((u) => u.fullName).firstOrNull ?? '—';

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de turnos')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => MbEmptyState(
          icon: Icons.error_outline,
          title: 'Error al cargar',
          message: '$e',
        ),
        data: (sessions) => sessions.isEmpty
            ? const MbEmptyState(
                icon: Icons.history,
                title: 'Sin turnos cerrados',
                message: 'Los turnos de caja cerrados aparecerán aquí.',
              )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final s = sessions[i];
                final diff = s.difference;
                final tone = diff == null || diff.isZero
                    ? MbBadgeTone.success
                    : diff.isNegative
                        ? MbBadgeTone.error
                        : MbBadgeTone.warning;
                return Card(
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    title: Text(
                      '${s.openingDate.day}/${s.openingDate.month}'
                      ' · ${userName(s.userId)}',
                    ),
                    subtitle: Text(
                      'Esperado ${s.expectedAmount?.format() ?? '—'} · '
                      'Contado ${s.countedAmount?.format() ?? '—'}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MbBadge(
                          diff == null ? '—' : diff.format(),
                          tone: tone,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cierre ${s.closingDate?.day}/${s.closingDate?.month}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }
}
