import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../core/theme/app_colors.dart';

/// Campo de texto reutilizable de MiBodega.
class MbTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final Widget? prefixIcon;
  final Widget? suffix;
  final int maxLines;
  final int? maxLength;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final void Function(String)? onSubmitted;
  /// Si es true, al recibir foco se limpia el contenido del controller.
  final bool clearOnFocus;
  /// Si es true y obscureText es true, muestra un botón de toggle de visibilidad.
  final bool showPasswordToggle;

  const MbTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.helperText,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.prefixIcon,
    this.suffix,
    this.maxLines = 1,
    this.maxLength,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.clearOnFocus = false,
    this.showPasswordToggle = true,
  });

  @override
  State<MbTextField> createState() => _MbTextFieldState();
}

class _MbTextFieldState extends State<MbTextField> {
  late final FocusNode _focusNode;
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    _obscured = widget.obscureText;
  }

  @override
  void didUpdateWidget(MbTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.obscureText != oldWidget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && widget.clearOnFocus) {
      final text = widget.controller?.text ?? '';
      if (text.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.controller?.clear();
          widget.onChanged?.call('');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>() ?? AppColors.light;
    final showToggle = widget.obscureText && widget.showPasswordToggle;

    Widget? suffixIcon;
    if (showToggle) {
      suffixIcon = IconButton(
        icon: Icon(
          _obscured ? LucideIcons.eye_off : LucideIcons.eye,
          color: _focusNode.hasFocus ? colors.primary : colors.outline,
        ),
        onPressed: () => setState(() => _obscured = !_obscured),
      );
    } else if (widget.errorText != null) {
      suffixIcon = Icon(
        LucideIcons.circle_alert,
        color: colors.error,
      );
    } else {
      suffixIcon = widget.suffix;
    }

    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      obscureText: _obscured,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: widget.enabled ? colors.onSurface : colors.outline,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(
          color: widget.errorText != null
              ? colors.error
              : (_focusNode.hasFocus ? colors.primary : colors.onSurfaceVariant),
          fontWeight: _focusNode.hasFocus ? FontWeight.w600 : FontWeight.normal,
        ),
        hintText: widget.hint,
        errorText: widget.errorText,
        helperText: widget.helperText,
        prefixIcon: widget.prefixIcon != null
            ? IconTheme.merge(
                data: IconThemeData(
                  color: widget.errorText != null
                      ? colors.error
                      : (_focusNode.hasFocus ? colors.primary : colors.onSurfaceVariant),
                ),
                child: widget.prefixIcon!,
              )
            : null,
        suffixIcon: suffixIcon,
        counterText: widget.maxLength == null ? '' : null,
      ),
    );
  }
}
