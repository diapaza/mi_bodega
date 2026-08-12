import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/security/permission_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mb_button.dart';
import '../../../shared/widgets/mb_text_field.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/entities/inventory.dart';
import '../../products/presentation/products_providers.dart';

/// Ajuste manual de stock (entrada, merma, corrección, etc.).
class AdjustmentScreen extends ConsumerStatefulWidget {
  final int productId;

  const AdjustmentScreen({super.key, required this.productId});

  @override
  ConsumerState<AdjustmentScreen> createState() => _AdjustmentScreenState();
}

class _AdjustmentScreenState extends ConsumerState<AdjustmentScreen> {
  final _quantity = TextEditingController(text: '1');
  final _reason = TextEditingController();
  MovementType _type = MovementType.adjustment;
  bool _positive = true;
  bool _saving = false;

  static const _manualTypes = [
    MovementType.adjustment,
    MovementType.correction,
    MovementType.loss,
    MovementType.manualIn,
    MovementType.manualOut,
    MovementType.returnIn,
    MovementType.returnOut,
  ];

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  double get _signedQuantity {
    final qty = double.tryParse(_quantity.text) ?? 0;
    final sign = switch (_type) {
      MovementType.loss ||
      MovementType.manualOut ||
      MovementType.returnOut => -1,
      MovementType.manualIn || MovementType.returnIn => 1,
      _ => _positive ? 1 : -1, // ajuste/corrección: signo editable
    };
    return qty * sign;
  }

  Future<void> _save() async {
    final guard =
        ensureAllowed(ref.read(sessionPermissionsProvider), 'inventory.adjust');
    if (guard.isErr) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(guard.failure!.message)),
        );
      }
      return;
    }
    final qty = double.tryParse(_quantity.text) ?? 0;
    if (qty <= 0 || _reason.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa la cantidad y el motivo.')),
      );
      return;
    }
    setState(() => _saving = true);
    final userId = ref.read(sessionControllerProvider).valueOrNull?.user?.id;
    final repo = ref.read(inventoryRepositoryProvider);
    final result = await repo.adjustStock(StockAdjustment(
      productId: widget.productId,
      type: _type,
      quantity: _signedQuantity,
      reason: _reason.text.trim(),
      userId: userId,
    ));
    if (!mounted) return;
    if (result.isErr) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.failure!.message)),
      );
      return;
    }
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Stock ajustado: ${result.orNull!.afterQty}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final productAsync = ref.watch(productByIdProvider(widget.productId));
    final product = productAsync.valueOrNull?.product;
    final stock = productAsync.valueOrNull?.stock ?? 0;
    final after = stock + _signedQuantity;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustar stock')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (product != null) ...[
                Text(product.name, style: theme.textTheme.titleMedium),
                Text(
                  'Stock actual: ${_fmtQty(stock)}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Stock posterior: ${_fmtQty(after)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: after < 0 ? colors.error : colors.success,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<MovementType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tipo de movimiento'),
                items: [
                  for (final t in _manualTypes)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 12),
              MbTextField(
                controller: _quantity,
                label: 'Cantidad',
                keyboardType: TextInputType.number,
              ),
              if (_type == MovementType.adjustment ||
                  _type == MovementType.correction) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_positive ? 'Entrada (+)' : 'Salida (−)'),
                  value: _positive,
                  onChanged: (v) => setState(() => _positive = v),
                ),
              ],
              const SizedBox(height: 12),
              MbTextField(
                controller: _reason,
                label: 'Motivo *',
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              MbButton(
                label: 'Guardar ajuste',
                icon: Icons.check,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(2);
}
