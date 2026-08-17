import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/money/money.dart';
import '../../../catalog/domain/entities/catalog.dart';
import '../../domain/services/pricing_calculator.dart';

/// Conversión editable en el formulario de producto.
class ConversionDraft {
  final int? id;
  int unitId;
  double factor;
  Money? purchasePrice;
  Money? salePrice;

  ConversionDraft({
    this.id,
    required this.unitId,
    this.factor = 1,
    this.purchasePrice,
    this.salePrice,
  });
}

/// Editor de conversiones de unidad con análisis en vivo.
///
/// Ejemplo: caja = 24 uds, compra caja S/57, venta ud S/3.50 → muestra costo
/// unitario, ingreso potencial, ganancia, margen y markup.
class ConversionsEditor extends StatefulWidget {
  final List<Unit> units;
  final List<ConversionDraft> initial;
  final Money unitSalePrice;
  final ValueChanged<List<ConversionDraft>> onChanged;

  const ConversionsEditor({
    super.key,
    required this.units,
    required this.initial,
    required this.unitSalePrice,
    required this.onChanged,
  });

  @override
  State<ConversionsEditor> createState() => _ConversionsEditorState();
}

class _ConversionsEditorState extends State<ConversionsEditor> {
  late final List<ConversionDraft> _drafts = [
    for (final d in widget.initial) d,
  ];

  void _notify() => widget.onChanged(List.unmodifiable(_drafts));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Conversiones', style: theme.textTheme.titleMedium)),
            TextButton.icon(
              onPressed: widget.units.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _drafts.add(ConversionDraft(unitId: widget.units.first.id ?? 0));
                      });
                      _notify();
                    },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar'),
            ),
          ],
        ),
        if (_drafts.isEmpty)
          Text(
            'Sin conversiones. La unidad base es la del producto.',
            style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        for (var i = 0; i < _drafts.length; i++) ...[
          const SizedBox(height: 8),
          _ConversionRow(
            draft: _drafts[i],
            units: widget.units,
            unitSalePrice: widget.unitSalePrice,
            onDelete: () {
              setState(() => _drafts.removeAt(i));
              _notify();
            },
            onChanged: (d) {
              setState(() => _drafts[i] = d);
              _notify();
            },
          ),
        ],
      ],
    );
  }
}

class _ConversionRow extends StatelessWidget {
  final ConversionDraft draft;
  final List<Unit> units;
  final Money unitSalePrice;
  final VoidCallback onDelete;
  final ValueChanged<ConversionDraft> onChanged;

  const _ConversionRow({
    required this.draft,
    required this.units,
    required this.unitSalePrice,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final purchase = draft.purchasePrice;
    final hasAnalysis =
        purchase != null && draft.factor > 0 && unitSalePrice.cents > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: draft.unitId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Unidad', isDense: true),
                  items: [
                    for (final u in units)
                      DropdownMenuItem(value: u.id, child: Text('${u.name} (${u.symbol})')),
                  ],
                  onChanged: (v) => onChanged(ConversionDraft(
                    id: draft.id,
                    unitId: v ?? draft.unitId,
                    factor: draft.factor,
                    purchasePrice: draft.purchasePrice,
                    salePrice: draft.salePrice,
                  )),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: colors.error),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  decoration: const InputDecoration(
                    labelText: 'Unidades base (factor)',
                    isDense: true,
                  ),
                  onChanged: (v) => onChanged(ConversionDraft(
                    id: draft.id,
                    unitId: draft.unitId,
                    factor: double.tryParse(v) ?? 0,
                    purchasePrice: draft.purchasePrice,
                    salePrice: draft.salePrice,
                  )),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precio compra (S/)',
                    isDense: true,
                  ),
                  onChanged: (v) => onChanged(ConversionDraft(
                    id: draft.id,
                    unitId: draft.unitId,
                    factor: draft.factor,
                    purchasePrice: v.isEmpty ? null : Money.fromSoles(double.parse(v)),
                    salePrice: draft.salePrice,
                  )),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio venta por esta unidad (S/, opcional)',
              isDense: true,
            ),
            onChanged: (v) => onChanged(ConversionDraft(
              id: draft.id,
              unitId: draft.unitId,
              factor: draft.factor,
              purchasePrice: draft.purchasePrice,
              salePrice: v.isEmpty ? null : Money.fromSoles(double.parse(v)),
            )),
          ),
          if (hasAnalysis) ...[
            const SizedBox(height: 8),
            _Analysis(purchase, draft.factor, unitSalePrice),
          ],
        ],
      ),
    );
  }
}

class _Analysis extends StatelessWidget {
  final Money packageCost;
  final double unitsInPackage;
  final Money unitSalePrice;

  const _Analysis(this.packageCost, this.unitsInPackage, this.unitSalePrice);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final result = PricingCalculator().analyzePackage(
      packageCost: packageCost,
      unitsInPackage: unitsInPackage,
      unitSalePrice: unitSalePrice,
    );

    Widget cell(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant)),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Análisis del paquete', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Row(children: [
            cell('Costo/ud', result.unitCost.format()),
            cell('Ingreso', result.potentialRevenue.format()),
            cell('Ganancia', result.grossProfit.format()),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            cell('Margen', result.marginPercent),
            cell('Markup', result.markupPercent),
          ]),
        ],
      ),
    );
  }
}
