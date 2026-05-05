// DOCS: docs/development-standards.md
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class DSInput extends StatefulWidget {
  final String label;
  final String? activeLabel;
  final bool obscureText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextEditingController? controller;
  final bool enabled;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? hintText;
  final void Function(String)? onChanged;

  const DSInput({
    super.key,
    required this.label,
    this.activeLabel,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.controller,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.hintText,
    this.onChanged,
  });

  @override
  State<DSInput> createState() => _DSInputState();
}

class _DSInputState extends State<DSInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late bool _isObscured;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = FocusNode();
    _isObscured = widget.obscureText;

    _controller.addListener(() => setState(() {}));
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(vertical: DSSpacing.sm),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        obscureText: _isObscured,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        enabled: widget.enabled,
        onChanged: widget.onChanged,
        style: DSTypography.body(
          color: isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          hintStyle: DSTypography.body().copyWith(
            color: isDark ? DSColors.labelTertiaryDark : DSColors.labelTertiary,
            fontWeight: FontWeight.w900,
          ),
          labelStyle: DSTypography.body().copyWith(
            color: _focusNode.hasFocus
                ? DSColors.primary
                : (isDark
                      ? DSColors.labelSecondaryDark
                      : DSColors.labelSecondary),
            fontWeight: FontWeight.w900,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          prefixIcon: widget.prefixIcon != null
              ? Icon(
                  widget.prefixIcon,
                  size: DSIconSize.md,
                  color: _focusNode.hasFocus ? DSColors.primary : null,
                )
              : null,
          suffixIcon: widget.obscureText
              ? IconButton(
                  icon: Icon(
                    _isObscured
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: _focusNode.hasFocus ? DSColors.primary : null,
                  ),
                  onPressed: () => setState(() => _isObscured = !_isObscured),
                )
              : widget.suffixIcon,
          filled: true,
          fillColor: isDark
              ? DSColors.secondarySurfaceDark
              : DSColors.secondarySurfaceLight,
          border: OutlineInputBorder(
            borderRadius: DSStyles.cardRadius,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: DSStyles.cardRadius,
            borderSide: const BorderSide(
              color: DSColors.primary,
              width: DSStyles.borderWidth * 1.5,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
