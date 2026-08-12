import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/money/money.dart';
import '../../domain/services/pricing_calculator.dart';

/// Recomendador de precio automático.
///
/// Muestra el costo por unidad de venta (label), calcula un precio sugerido
/// según margen/markup objetivo, y permite ajustar el precio de venta manual.
/// Notifica el precio de venta final vía [onPriceChanged].
class PriceRecommender extends StatefulWidget {
  /// Costo por unidad de venta (base). Viene calculado del form.
  final Money cost;

  /// Unidades de venta por unidad de compra.
  final double unitsPerPkg;

  /// Nombre de la unidad de compra para la etiqueta de ganancia.
  final String? purchaseUnitName;

  /// Margen/markup inicial en porcentaje (ej: 30 = 30%).
  final double initialTarget;

  /// Precio de venta guardado (al editar). Si se proporciona, se usa en vez
  /// del precio sugerido al iniciar.
  final Money? initialSalePrice;

  /// Llamado cuando el precio de venta cambia (sugerido o manual).
  final ValueChanged<Money> onPriceChanged;

  const PriceRecommender({
    super.key,
    required this.cost,
    this.unitsPerPkg = 1,
    this.purchaseUnitName,
    this.initialTarget = 30,
    this.initialSalePrice,
    required this.onPriceChanged,
  });

  @override
  State<PriceRecommender> createState() => _PriceRecommenderState();
}

enum _Mode { margin, markup }

class _PriceRecommenderState extends State<PriceRecommender> {
  static const _calculator = PricingCalculator();
  late Money _cost = widget.cost;
  late final TextEditingController _targetCtrl =
      TextEditingController(text: widget.initialTarget.toInt().toString());
  late final TextEditingController _salePriceCtrl = TextEditingController(
    text: (widget.cost.cents / 100).toStringAsFixed(2),
  );
  _Mode _mode = _Mode.margin;

  double get _target => (double.tryParse(_targetCtrl.text) ?? 0) / 100;

  Money get _suggested {
    return _mode == _Mode.margin
        ? _calculator.recommendedFromMargin(_cost, _target)
        : _calculator.recommendedFromMarkup(_cost, _target);
  }

  Money get _currentSalePrice =>
      Money.fromSoles(double.tryParse(_salePriceCtrl.text) ?? 0);

  /// Ganancia por unidad de compra = (precio_venta - costo/ud) × unidades_por_paquete.
  Money get _profitPerPackage {
    final profitPerUnit = _currentSalePrice.cents - _cost.cents;
    return Money((profitPerUnit * widget.unitsPerPkg).round());
  }

  bool get _isProfitPositive => _profitPerPackage.cents > 0;

  @override
  void didUpdateWidget(covariant PriceRecommender oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cost.cents != widget.cost.cents) {
      setState(() => _cost = widget.cost);
      // Recalcular precio sugerido con el nuevo costo.
      _applySuggested();
    }
  }

  @override
  void initState() {
    super.initState();
    // Si hay precio guardado (edición), usarlo. Si no, calcular el sugerido.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialSalePrice != null && widget.initialSalePrice!.cents > 0) {
        _salePriceCtrl.text = (widget.initialSalePrice!.cents / 100).toStringAsFixed(2);
        widget.onPriceChanged(widget.initialSalePrice!);
        setState(() {});
      } else {
        _applySuggested();
      }
    });
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    _salePriceCtrl.dispose();
    super.dispose();
  }

  void _applySuggested() {
    final suggested = _suggested;
    final text = (suggested.cents / 100).toStringAsFixed(2);
    if (_salePriceCtrl.text != text) {
      _salePriceCtrl.text = text;
    }
    widget.onPriceChanged(suggested);
    setState(() {});
  }

  void _onSalePriceChanged(String value) {
    setState(() {});
    widget.onPriceChanged(_currentSalePrice);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final suggested = _suggested;
    final profit = _profitPerPackage;
    final unitLabel = widget.purchaseUnitName ?? 'ud de compra';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recomendador de precio', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          // Costo por unidad de venta (label, no editable).
          Text(
            'Costo por unidad de venta: ${_cost.format()}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          // Modo margen/markup.
          SegmentedButton<_Mode>(
            segments: const [
              ButtonSegment(value: _Mode.margin, label: Text('Margen')),
              ButtonSegment(value: _Mode.markup, label: Text('Markup')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) {
              setState(() => _mode = s.first);
              _applySuggested();
            },
          ),
          const SizedBox(height: 12),
          // Objetivo editable.
          TextField(
            controller: _targetCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: _mode == _Mode.margin
                  ? 'Margen objetivo (%)'
                  : 'Markup objetivo (%)',
              isDense: true,
              suffixText: '%',
            ),
            onChanged: (_) => _applySuggested(),
          ),
          const SizedBox(height: 12),
          // Precio sugerido + botón aplicar.
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Precio sugerido', style: theme.textTheme.labelMedium),
                    Text(
                      suggested.format(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: _applySuggested,
                child: const Text('Aplicar'),
              ),
            ],
          ),
          const Divider(height: 24),
          // Precio de venta editable.
          TextField(
            controller: _salePriceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            decoration: InputDecoration(
              labelText: 'Precio de venta por unidad (S/)',
              isDense: true,
            ),
            onChanged: _onSalePriceChanged,
          ),
          const SizedBox(height: 8),
          // Ganancia calculada.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isProfitPositive
                  ? colors.primaryContainer
                  : colors.errorContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  _isProfitPositive ? Icons.trending_up : Icons.trending_down,
                  size: 16,
                  color: _isProfitPositive
                      ? colors.primary
                      : colors.error,
                ),
                const SizedBox(width: 6),
                Text(
                  'Ganancia: ${profit.format()} por $unitLabel',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _isProfitPositive
                        ? colors.primary
                        : colors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
