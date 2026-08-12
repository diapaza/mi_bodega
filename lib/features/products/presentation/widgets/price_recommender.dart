import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/money/money.dart';
import '../../domain/services/pricing_calculator.dart';

/// Recomendador de precio: margen o markup objetivo → precio sugerido.
class PriceRecommender extends StatefulWidget {
  final Money initialCost;
  final Money initialSalePrice;
  final ValueChanged<Money> onApply;

  const PriceRecommender({
    super.key,
    required this.initialCost,
    required this.initialSalePrice,
    required this.onApply,
  });

  @override
  State<PriceRecommender> createState() => _PriceRecommenderState();
}

enum _Mode { margin, markup }

class _PriceRecommenderState extends State<PriceRecommender> {
  static const _calculator = PricingCalculator();
  late Money _cost = widget.initialCost;
  late final TextEditingController _costCtrl =
      TextEditingController(text: (widget.initialCost.cents / 100).toStringAsFixed(2));
  late final TextEditingController _targetCtrl = TextEditingController(text: '30');
  _Mode _mode = _Mode.margin;

  double get _target => (double.tryParse(_targetCtrl.text) ?? 0) / 100;

  Money get _recommended {
    return _mode == _Mode.margin
        ? _calculator.recommendedFromMargin(_cost, _target)
        : _calculator.recommendedFromMarkup(_cost, _target);
  }

  @override
  void dispose() {
    _costCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final recommended = _recommended;

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
          TextField(
            controller: _costCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            decoration: const InputDecoration(labelText: 'Costo unitario (S/)', isDense: true),
            onChanged: (v) => setState(() {
              _cost = Money.fromSoles(double.tryParse(v) ?? 0);
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<_Mode>(
                  segments: const [
                    ButtonSegment(value: _Mode.margin, label: Text('Margen')),
                    ButtonSegment(value: _Mode.markup, label: Text('Markup')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _mode == _Mode.margin
                  ? 'Margen objetivo (%)'
                  : 'Markup objetivo (%)',
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Precio recomendado', style: theme.textTheme.labelMedium),
                    Text(
                      recommended.format(),
                      style: theme.textTheme.headlineMedium?.copyWith(color: colors.primary),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () => widget.onApply(recommended),
                child: const Text('Aplicar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
