import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/mb_empty_state.dart';
import '../domain/entities/customer.dart';
import 'customers_providers.dart';

/// Lista y búsqueda de clientes.
class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final customers = ref.watch(customersProvider).valueOrNull ?? const <Customer>[];
    final search = ref.watch(customersSearchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => ref.read(customersSearchProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o DNI',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: customers.isEmpty && search.isEmpty
                ? const MbEmptyState(
                    icon: Icons.people_outline,
                    title: 'Sin clientes',
                    message: 'Los clientes registrados en las ventas aparecerán aquí.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: customers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final c = customers[i];
                      return Card(
                        child: ListTile(
                          onTap: () =>
                              context.push('/customers/${c.id}'),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          title: Text(c.name),
                          subtitle: Text(
                            c.dni != null && c.dni!.isNotEmpty
                                ? 'DNI: ${c.dni}'
                                : 'Sin DNI',
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
