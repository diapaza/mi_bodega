import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mb_button.dart';
import '../../../shared/widgets/mb_text_field.dart';
import '../../auth/presentation/session_controller.dart';
import '../../sales/domain/entities/sale.dart';
import 'cart_controller.dart';
import 'pos_providers.dart';
import 'sale_success_overlay.dart';

/// Cobro: cliente opcional, método de pago, recibido y vuelto.
class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({super.key});

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  bool _showCustomer = false;
  final _dni = TextEditingController();
  final _name = TextEditingController();
  final _discount = TextEditingController(text: '0');
  String _receivedText = '';
  bool _saving = false;

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
    final cart = ref.read(cartProvider.notifier);
    cart.setReceived(Money.fromSoles(double.tryParse(_receivedText) ?? 0));
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
    Navigator.of(context).popUntil((r) => r.isFirst);
    showSaleSuccess(context, detail);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final cart = ref.watch(cartProvider);
    final isCash = cart.method == PaymentMethod.cash;
    final missing = cart.missing;
    final canConfirm = !cart.isEmpty &&
        (!isCash || missing.isZero);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Total a cobrar', style: theme.textTheme.bodySmall),
              Text(
                cart.total.format(),
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              MbTextField(
                controller: _discount,
                label: 'Descuento (S/)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
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
                      label: Text('Exacto'),
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
              const SizedBox(height: 16),
              MbButton(
                label: missing.isZero ? 'Confirmar venta' : 'Faltan ${missing.format()}',
                icon: Icons.check_circle_outline,
                loading: _saving,
                onPressed: canConfirm && !_saving ? _confirm : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
