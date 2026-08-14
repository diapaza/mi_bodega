import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/security/permission_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mb_button.dart';
import '../../../shared/widgets/mb_empty_state.dart';
import '../../../shared/widgets/mb_text_field.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../products/presentation/products_providers.dart';
import '../../sales/domain/entities/sale.dart';
import 'cart_controller.dart';
import 'pos_providers.dart';

/// Sheet unificado de carrito + pago del POS.
class CartSheet extends ConsumerStatefulWidget {
  const CartSheet({super.key});

  @override
  ConsumerState<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends ConsumerState<CartSheet> {
  bool _showPayment = false;
  bool _saving = false;

  // Payment fields
  bool _showCustomer = false;
  final _dni = TextEditingController();
  final _name = TextEditingController();
  final _discount = TextEditingController(text: '0');
  String _receivedText = '';

  @override
  void dispose() {
    _dni.dispose();
    _name.dispose();
    _discount.dispose();
    super.dispose();
  }

  void _key(String digit) {
    if (_receivedText.length >= 6) return;
    setState(() => _receivedText += digit);
    _applyReceived();
  }

  void _backspace() {
    if (_receivedText.isEmpty) return;
    setState(() => _receivedText = _receivedText.substring(0, _receivedText.length - 1));
    _applyReceived();
  }

  void _quick(int amount) {
    setState(() => _receivedText = '$amount');
    _applyReceived();
  }

  void _applyReceived() {
    ref.read(cartProvider.notifier).setReceived(Money.fromSoles(double.tryParse(_receivedText) ?? 0));
  }

  Future<void> _confirm() async {
    final session = ref.read(sessionControllerProvider).valueOrNull;
    final cart = ref.read(cartProvider);
    if (session == null || session.user == null) return;
    setState(() => _saving = true);

    final storeId = session.store!.id!;
    final openSessionId = ref.read(openCashSessionProvider).valueOrNull?.id;

    int? customerId = cart.customerId;
    if (_name.text.trim().isNotEmpty) {
      final res = await ref.read(customerRepositoryProvider).findOrCreate(
            storeId: storeId,
            name: _name.text.trim(),
            dni: _dni.text.trim().isEmpty ? null : _dni.text.trim(),
          );
      customerId = res.orNull ?? cart.customerId;
    }

    final result = await ref.read(saleRepositoryProvider).registerSale(
          SaleRequest(
            storeId: storeId,
            userId: session.user!.id!,
            cashSessionId: openSessionId,
            customerId: customerId,
            items: [
              for (final l in cart.lines)
                SaleItemInput(
                  productId: l.productId,
                  quantity: l.quantity,
                  unitId: l.unitId,
                  factor: l.factor,
                  unitPrice: l.unitPrice,
                ),
            ],
            paymentMethod: cart.method,
            discount: Money.fromSoles(double.tryParse(_discount.text) ?? 0),
            amountReceived: cart.method == PaymentMethod.cash
                ? cart.received
                : null,
          ),
        );

    if (!mounted) return;
    if (result.isErr) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.failure!.message)),
      );
      return;
    }

    final detail = result.orNull!;
    HapticFeedback.heavyImpact();
    ref.read(cartProvider.notifier).clear();
    Navigator.of(context).pop(detail);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final cart = ref.watch(cartProvider);
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final canEditPrice = session?.can('sales.price_override') ?? false;
    final units = ref.watch(unitsProvider).valueOrNull ?? const [];
    final isCash = cart.method == PaymentMethod.cash;
    final missing = cart.missing;
    final canConfirm = !cart.isEmpty && (!isCash || missing.isZero);

    String unitName(int? id) =>
        units.where((u) => u.id == id).map((u) => u.symbol).firstOrNull ?? 'ud';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: colors.outline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  if (_showPayment)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      onPressed: () => setState(() => _showPayment = false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (_showPayment) const SizedBox(width: 8),
                  Text(_showPayment ? 'Cobrar' : 'Carrito', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  if (!_showPayment)
                    TextButton(
                      onPressed: () => _confirmClear(context),
                      child: const Text('Vaciar'),
                    ),
                ],
              ),
            ),
            // Content
            if (cart.isEmpty && !_showPayment)
              const MbEmptyState(
                icon: Icons.remove_shopping_cart_outlined,
                title: 'Carrito vacío',
              )
            else if (_showPayment)
              Flexible(
                child: _buildPaymentSection(context, cart, isCash, missing, canConfirm, theme, colors),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: cart.lines.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final line = cart.lines[i];
                    return _CartLineRow(
                      line: line,
                      unitName: unitName(line.unitId),
                      canEditPrice: canEditPrice,
                    );
                  },
                ),
              ),
            // Footer
            if (!cart.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total', style: theme.textTheme.bodySmall),
                          Text(
                            cart.total.format(),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_showPayment)
                      Expanded(
                        child: MbButton(
                          label: 'Cobrar',
                          icon: Icons.point_of_sale,
                          onPressed: cart.isEmpty ? null : () => setState(() => _showPayment = true),
                        ),
                      )
                    else
                      Expanded(
                        child: MbButton(
                          label: missing.isZero ? 'Confirmar venta' : 'Faltan ${missing.format()}',
                          icon: Icons.check_circle_outline,
                          loading: _saving,
                          onPressed: canConfirm && !_saving ? _confirm : null,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vaciar carrito'),
        content: Text('Se eliminarán ${cart.lines.length} producto${cart.lines.length == 1 ? '' : 's'} del carrito.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        ref.read(cartProvider.notifier).clear();
      }
    });
  }

  Widget _buildPaymentSection(
    BuildContext context,
    CartState cart,
    bool isCash,
    Money missing,
    bool canConfirm,
    ThemeData theme,
    AppColors colors,
  ) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Descuento
            MbTextField(
              controller: _discount,
              label: 'Descuento (S/)',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            // Cliente opcional
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Registrar cliente (opcional)'),
              value: _showCustomer,
              onChanged: (v) => setState(() => _showCustomer = v),
            ),
            if (_showCustomer) ...[
              MbTextField(controller: _dni, label: 'DNI', keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              MbTextField(controller: _name, label: 'Nombre'),
              const SizedBox(height: 8),
            ],
            // Método de pago
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in PaymentMethod.values)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: cart.method == m,
                    onSelected: (_) {
                      ref.read(cartProvider.notifier).setMethod(m);
                      if (m != PaymentMethod.cash) {
                        ref.read(cartProvider.notifier).setReceived(Money.zero());
                        _receivedText = '';
                      }
                    },
                  ),
              ],
            ),
            if (isCash) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recibido', style: theme.textTheme.bodySmall),
                        Text(
                          cart.received.format(),
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Vuelto', style: theme.textTheme.bodySmall),
                        Text(
                          missing.isZero
                              ? cart.change.format()
                              : 'Faltan ${missing.format()}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: missing.isZero ? colors.success : colors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final q in [5, 10, 20, 50, 100])
                    ActionChip(
                      label: Text('S/$q'),
                      onPressed: () => _quick(q),
                    ),
                  ActionChip(
                    label: const Text('Exacto'),
                    onPressed: () => _quick((cart.total.cents / 100).ceil()),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Keypad(
                onKey: _key,
                onBackspace: _backspace,
                onClear: () => setState(() {
                  _receivedText = '';
                  ref.read(cartProvider.notifier).setReceived(Money.zero());
                }),
                receivedText: _receivedText,
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// --- Keypad ---
class _Keypad extends StatelessWidget {
  final String receivedText;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const _Keypad({
    required this.receivedText,
    required this.onKey,
    required this.onBackspace,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', '⌫'];
    return Column(
      children: [
        Text(
          receivedText.isEmpty ? '—' : 'S/$receivedText',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.8,
          children: [
            for (final k in keys)
              Material(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    if (k == 'C') {
                      onClear();
                    } else if (k == '⌫') {
                      onBackspace();
                    } else {
                      onKey(k);
                    }
                  },
                  child: Center(
                    child: k == '⌫'
                        ? const Icon(Icons.backspace_outlined)
                        : Text(
                            k,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// --- Cart Line Row ---
class _CartLineRow extends ConsumerWidget {
  final CartLine line;
  final String unitName;
  final bool canEditPrice;

  const _CartLineRow({
    required this.line,
    required this.unitName,
    required this.canEditPrice,
  });

  Future<void> _editPrice(BuildContext context, WidgetRef ref) async {
    final guard = ensureAllowed(
      ref.read(sessionPermissionsProvider),
      'sales.price_override',
    );
    if (guard.isErr) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(guard.failure!.message)),
        );
      }
      return;
    }
    final controller = TextEditingController(
      text: (line.unitPrice.cents / 100).toStringAsFixed(2),
    );
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar precio'),
        content: MbTextField(
          controller: controller,
          label: 'Precio (S/)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
    if (value == null) return;
    ref
        .read(cartProvider.notifier)
        .setPrice(line.productId, Money.fromSoles(double.tryParse(value) ?? 0));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final controller = ref.read(cartProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                _UnitSelector(line: line),
                Row(
                  children: [
                    Text(
                      '${line.unitPrice.format()} / $unitName',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (canEditPrice) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _editPrice(context, ref),
                        child: Icon(Icons.edit, size: 14, color: colors.primary),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          _Stepper(
            line: line,
            onDec: () => controller.decrement(line.productId),
            onInc: () => controller.increment(line.productId),
            onSet: (q) => controller.setQuantity(line.productId, q),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: () => controller.remove(line.productId),
            icon: Icon(Icons.delete_outline, color: colors.error),
          ),
        ],
      ),
    );
  }
}

// --- Stepper ---
class _Stepper extends StatelessWidget {
  final CartLine line;
  final VoidCallback onDec;
  final VoidCallback onInc;
  final ValueChanged<double> onSet;

  const _Stepper({
    required this.line,
    required this.onDec,
    required this.onInc,
    required this.onSet,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final qtyText = line.quantity == line.quantity.roundToDouble()
        ? '${line.quantity.toInt()}'
        : line.quantity.toStringAsFixed(2);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(icon: Icons.remove, onTap: onDec),
        GestureDetector(
          onTap: () => _editQuantity(context),
          child: Container(
            width: 44,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              qtyText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
        _RoundButton(icon: Icons.add, onTap: onInc),
      ],
    );
  }

  Future<void> _editQuantity(BuildContext context) async {
    final controller = TextEditingController(text: _fmt(line.quantity));
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cantidad'),
        content: MbTextField(
          controller: controller,
          label: 'Cantidad',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (value == null) return;
    onSet(double.tryParse(value) ?? 1);
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(2);
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: colors.onPrimaryContainer),
      ),
    );
  }
}

// --- Unit Selector ---
class _UnitSelector extends ConsumerWidget {
  final CartLine line;

  const _UnitSelector({required this.line});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitsProvider).valueOrNull ?? const [];
    final conversions =
        ref.watch(productConversionsProvider(line.productId)).valueOrNull ?? const [];
    final baseUnit = units.where((u) => u.id == line.unitId).firstOrNull;
    final basePrice = ref
            .read(productByIdProvider(line.productId))
            .valueOrNull
            ?.product
            .salePrice ??
        line.unitPrice;

    if (baseUnit == null) return const SizedBox.shrink();

    return DropdownButton<int>(
      value: line.unitId,
      isDense: true,
      underline: const SizedBox.shrink(),
      items: [
        DropdownMenuItem(value: baseUnit.id, child: Text(baseUnit.symbol)),
        for (final c in conversions)
          DropdownMenuItem(
            value: c.unitId,
            child: Text(
              '${units.where((u) => u.id == c.unitId).map((u) => u.symbol).firstOrNull ?? '?'} '
              '(×${c.factor.toInt()})',
            ),
          ),
      ],
      onChanged: (v) {
        if (v == null) return;
        if (v == baseUnit.id) {
          ref
              .read(cartProvider.notifier)
              .setUnit(line.productId, baseUnit.id, 1, basePrice);
          return;
        }
        final conversion = conversions.where((c) => c.unitId == v).firstOrNull;
        if (conversion == null) return;
        final price = conversion.salePrice ??
            Money((basePrice.cents * conversion.factor).round());
        ref.read(cartProvider.notifier).setUnit(
              line.productId,
              v,
              conversion.factor,
              price,
            );
      },
    );
  }
}
