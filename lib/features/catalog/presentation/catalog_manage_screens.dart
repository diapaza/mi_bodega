import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_bodega/core/error/result.dart';

import '../../../core/di/app_providers.dart';
import '../../../shared/widgets/mb_badge.dart';
import '../../../shared/widgets/mb_empty_state.dart';
import '../../../shared/widgets/mb_snackbar.dart';
import '../../../shared/widgets/mb_text_field.dart';
import '../../catalog/domain/entities/catalog.dart';
import 'catalog_providers.dart';

/// Pantallas de gestión de categorías, marcas y unidades.
///
/// Acceso condicionado por `categories.manage` (guards del router).

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ManageListScreen<Category>(
      title: 'Categorías',
      emptyIcon: Icons.category_outlined,
      itemsStream: (ref) => ref.watch(categoriesProvider),
      subtitle: (c) => c.active ? 'Activa' : 'Inactiva',
      create: (ref, name) async => ref.read(catalogRepositoryProvider).createCategory(name),
      update: (ref, c, name) async => ref
          .read(catalogRepositoryProvider)
          .updateCategory(Category(
            id: c.id,
            name: name,
            active: c.active,
            createdAt: c.createdAt,
            updatedAt: c.updatedAt,
          )),
      deactivate: (ref, c, active) async =>
          ref.read(catalogRepositoryProvider).setCategoryActive(c.id!, active),
    );
  }
}

class BrandsScreen extends StatelessWidget {
  const BrandsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ManageListScreen<Brand>(
      title: 'Marcas',
      emptyIcon: Icons.branding_watermark_outlined,
      itemsStream: (ref) => ref.watch(brandsProvider),
      subtitle: (b) => b.active ? 'Activa' : 'Inactiva',
      create: (ref, name) async => ref.read(catalogRepositoryProvider).createBrand(name),
      update: (ref, b, name) async => ref.read(catalogRepositoryProvider).updateBrand(
            Brand(
              id: b.id,
              name: name,
              active: b.active,
              createdAt: b.createdAt,
              updatedAt: b.updatedAt,
            ),
          ),
      deactivate: (ref, b, active) async =>
          ref.read(catalogRepositoryProvider).setBrandActive(b.id!, active),
    );
  }
}

class UnitsScreen extends StatelessWidget {
  const UnitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ManageListScreen<Unit>(
      title: 'Unidades',
      emptyIcon: Icons.straighten_outlined,
      itemsStream: (ref) => ref.watch(unitsProvider),
      subtitle: (u) => '${u.symbol} · ${u.unitType.name}',
      create: (ref, name) async {
        final symbol = await _promptUnitSymbol(context, name);
        if (symbol == null) return const Ok(null);
        return ref
            .read(catalogRepositoryProvider)
            .createUnit(name, symbol, UnitType.unit);
      },
      update: (ref, u, name) async {
        final symbol = await _promptUnitSymbol(context, name, initial: u.symbol);
        if (symbol == null) return const Ok(null);
        return ref.read(catalogRepositoryProvider).updateUnit(
              Unit(
                id: u.id,
                name: name,
                symbol: symbol,
                unitType: u.unitType,
                active: u.active,
                createdAt: u.createdAt,
                updatedAt: u.updatedAt,
              ),
            );
      },
      deactivate: (ref, u, active) async =>
          ref.read(catalogRepositoryProvider).setUnitActive(u.id!, active),
    );
  }
}

class _ManageListScreen<T> extends ConsumerWidget {
  final String title;
  final IconData emptyIcon;
  final AsyncValue<List<T>> Function(WidgetRef ref) itemsStream;
  final String Function(T item) subtitle;
  final Future<Result<Object?>> Function(WidgetRef ref, String name) create;
  final Future<Result<Object?>> Function(WidgetRef ref, T item, String name) update;
  final Future<Result<Object?>> Function(WidgetRef ref, T item, bool active) deactivate;

  const _ManageListScreen({
    required this.title,
    required this.emptyIcon,
    required this.itemsStream,
    required this.subtitle,
    required this.create,
    required this.update,
    required this.deactivate,
  });

  String _name(T item) => switch (item) {
        Category c => c.name,
        Brand b => b.name,
        Unit u => u.name,
        _ => '',
      };

  bool _active(T item) => switch (item) {
        Category c => c.active,
        Brand b => b.active,
        Unit u => u.active,
        _ => true,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = itemsStream(ref).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'catalog-fab',
        onPressed: () async {
          final name = await _promptName(context, 'Nueva $title');
          if (name == null || name.trim().isEmpty) return;
          final result = await create(ref, name.trim());
          if (!context.mounted) return;
          showMbSnack(
            context,
            result.isOk ? '$title creada' : result.failure!.message,
            variant: result.isOk ? MbSnackVariant.success : MbSnackVariant.error,
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: items.isEmpty
          ? MbEmptyState(
              icon: emptyIcon,
              title: 'Sin $title',
              message: 'Agrega la primera.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = items[i];
                return Card(
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    title: Text(_name(item)),
                    subtitle: Text(subtitle(item)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_active(item))
                          const MbBadge('Inactivo', tone: MbBadgeTone.warning),
                        PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') {
                              final name =
                                  await _promptName(context, 'Editar', initial: _name(item));
                              if (name == null || name.trim().isEmpty) return;
                              final r = await update(ref, item, name.trim());
                              if (!context.mounted) return;
                              showMbSnack(context,
                                  r.isOk ? 'Guardado' : r.failure!.message,
                                  variant: r.isOk ? MbSnackVariant.success : MbSnackVariant.error);
                            } else if (v == 'toggle') {
                              final r = await deactivate(ref, item, !_active(item));
                              if (!context.mounted) return;
                              showMbSnack(context,
                                  r.isOk ? 'Estado actualizado' : r.failure!.message,
                                  variant: r.isOk ? MbSnackVariant.success : MbSnackVariant.error);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'edit', child: Text('Editar')),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(_active(item) ? 'Desactivar' : 'Activar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

Future<String?> _promptName(
  BuildContext context,
  String title, {
  String? initial,
}) {
  final controller = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: MbTextField(
        controller: controller,
        label: 'Nombre',
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

Future<String?> _promptUnitSymbol(
  BuildContext context,
  String name, {
  String? initial,
}) {
  final controller = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Símbolo de $name'),
      content: MbTextField(
        controller: controller,
        label: 'Símbolo (ej. kg, caja)',
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}
