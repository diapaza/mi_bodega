import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Campo de PIN (4-6 dígitos), con enmascarado y teclado numérico.
class MbPinField extends StatelessWidget {
  final TextEditingController? controller;
  final int length;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final void Function(String)? onCompleted;
  final bool autofocus;

  const MbPinField({
    super.key,
    this.controller,
    this.length = 4,
    this.errorText,
    this.onChanged,
    this.onCompleted,
    this.autofocus = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: true,
      obscuringCharacter: '•',
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: length,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        fontSize: 28,
        letterSpacing: 18,
        fontWeight: FontWeight.w700,
      ),
      onChanged: (value) {
        onChanged?.call(value);
        if (value.length == length) {
          onCompleted?.call(value);
        }
      },
      decoration: InputDecoration(
        hintText: '·' * length,
        hintStyle: TextStyle(letterSpacing: 18, color: colors.outlineVariant),
        errorText: errorText,
        counterText: '',
      ),
    );
  }
}
