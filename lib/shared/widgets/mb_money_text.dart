import 'package:flutter/material.dart';
import '../../core/money/money.dart';

/// Widget reutilizable para mostrar montos monetarios con jerarquía visual,
/// separando el estilo del símbolo de moneda (S/) del valor numérico.
class MbMoneyText extends StatelessWidget {
  final Money money;
  final TextStyle? style;
  final TextStyle? currencyStyle;

  const MbMoneyText(
    this.money, {
    super.key,
    this.style,
    this.currencyStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = money.format(); // e.g. "S/ 1,234.56" or "-S/ 1,234.56"
    final hasMinus = formatted.startsWith('-');
    final cleanValue = hasMinus ? formatted.substring(1) : formatted;

    if (cleanValue.startsWith('S/ ')) {
      final valuePart = cleanValue.substring(3);
      final defaultStyle = style ??
          theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          );
      final defaultCurrencyStyle = currencyStyle ??
          defaultStyle?.copyWith(
            fontWeight: FontWeight.w400,
            fontSize: (defaultStyle.fontSize ?? 16) * 0.85,
            color: defaultStyle.color?.withOpacity(0.6) ??
                theme.colorScheme.onSurface.withOpacity(0.6),
          );

      return RichText(
        text: TextSpan(
          style: defaultStyle,
          children: [
            if (hasMinus) TextSpan(text: '-', style: defaultStyle),
            TextSpan(text: 'S/ ', style: defaultCurrencyStyle),
            TextSpan(text: valuePart, style: defaultStyle),
          ],
        ),
      );
    }

    return Text(formatted, style: style);
  }
}
