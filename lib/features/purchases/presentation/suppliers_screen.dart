import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';
import '../../../shared/widgets/mb_badge.dart';
import '../../../shared/widgets/mb_confirm_dialog.dart';
import '../../../shared/widgets/mb_empty_state.dart';
import '../../../shared/widgets/mb_snackbar.dart';
import '../../../shared/widgets/mb_text_field.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/entities/purchase.dart';
import 'purchases_providers.dart';

/// Gestión de proveedores.
class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  Future<void> _addOrEdit(BuildContext context, WidgetRef ref, {Supplier? supplier}) async {
    final nameController = TextEditingController(text: supplier?.name ?? '');
    final rucController = TextEditingController(text: supplier?.rucDni ?? '');
    final phoneController = TextEditingController(text: supplier?.phone ?? '');
    final isEditing = supplier != null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Editar proveedor' : 'Nuevo proveedor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MbTextField(controller: nameController, label: 'Nombre *'),
              const SizedBox(height: 12),
              MbTextField(controller: rucController, label: 'RUC / DNI'),
              const SizedBox(height: 12),
              MbTextField(controller: phoneController, label: 'Teléfono'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) {
      showMbSnack(context, 'El nombre es obligatorio.');
      return;
    }

    final storeId = ref.read(sessionControllerProvider).valueOrNull?.store?.id;
    if (storeId == null) return;
    final repo = ref.read(supplierRepositoryProvider);

    final ruc = rucController.text.trim();
    final phone = phoneController.text.trim();

    if (isEditing) {
      await repo.updateSupplier(supplier.copyWith(
        name: name,
        rucDni: ruc.isEmpty ? null : ruc,
        phone: phone.isEmpty ? null : phone,
        updatedAt: DateTime.now(),
      ));
    } else {
      await repo.createSupplier(Supplier(
        storeId: storeId,
        name: name,
        rucDni: ruc.isEmpty ? null : ruc,
        phone: phone.isEmpty ? null : phone,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    if (context.mounted) {
      showMbSnack(context, isEditing ? 'Proveedor actualizado' : 'Proveedor creado',
          variant: MbSnackVariant.success);
    }
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref, Supplier supplier) async {
    final confirmed = await showMbConfirm(
      context,
      title: supplier.active ? 'Desactivar proveedor' : 'Activar proveedor',
      message: supplier.active
          ? '¿Deseas desactivar "${supplier.name}"?'
          : '¿Deseas activar "${supplier.name}"?',
      confirmLabel: supplier.active ? 'Desactivar' : 'Activar',
      isDestructive: supplier.active,
    );
    if (confirmed != true) return;
    await ref.read(supplierRepositoryProvider).updateSupplier(
          supplier.copyWith(active: !supplier.active, updatedAt: DateTime.now()),
        );
    if (context.mounted) {
      showMbSnack(context, supplier.active ? 'Proveedor desactivado' : 'Proveedor activado',
          variant: MbSnackVariant.success);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Proveedores')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'suppliers-fab',
        onPressed: () => _addOrEdit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: suppliersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => MbEmptyState(
          icon: Icons.error_outline,
          title: 'Error al cargar',
          message: '$e',
        ),
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!s.active)
                        const MbBadge('Inactivo', tone: MbBadgeTone.warning),
                      PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'edit') {
                            _addOrEdit(context, ref, supplier: s);
                          } else if (action == 'toggle') {
                            _toggleActive(context, ref, s);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('Editar')),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(s.active ? 'Desactivar' : 'Activar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
