import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';
import '../../../shared/widgets/mb_badge.dart';
import '../../../shared/widgets/mb_empty_state.dart';
import '../../../shared/widgets/mb_text_field.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/entities/purchase.dart';
import 'purchases_providers.dart';

/// Gestión de proveedores.
class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo proveedor'),
        content: MbTextField(controller: controller, label: 'Nombre'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    final storeId = ref.read(sessionControllerProvider).valueOrNull?.store?.id;
    if (storeId == null) return;
    await ref.read(supplierRepositoryProvider).createSupplier(
      Supplier(
        storeId: storeId,
        name: name.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Proveedores')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'suppliers-fab',
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: suppliersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return const MbEmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'Sin proveedores',
              message: 'Agrega proveedores para tus compras.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: suppliers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final s = suppliers[i];
              return Card(
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  title: Text(s.name),
                  subtitle: Text(
                    [s.rucDni, s.phone].where((e) => e != null && e.isNotEmpty).join(' · '),
                  ),
                  trailing: s.active
                      ? null
                      : const MbBadge('Inactivo', tone: MbBadgeTone.warning),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
