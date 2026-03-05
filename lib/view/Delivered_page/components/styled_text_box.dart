import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StyledTextBox extends StatefulWidget {
  final String label; // placeholder text
  final String? activeLabel; // text shown when focused or has input
  final bool obscureText;
  final TextInputType keyboardType;
  final Color? labelColor;
  final List<TextInputFormatter>? inputFormatters;

  const StyledTextBox({
    super.key,
    required this.label,
    this.activeLabel,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.labelColor,
    this.inputFormatters,
  });

  @override
  State<StyledTextBox> createState() => _StyledTextBoxState();
}

class _StyledTextBoxState extends State<StyledTextBox> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late bool _isObscured;

  bool get _isActive => _focusNode.hasFocus || _controller.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _isObscured = widget.obscureText;

    _controller.addListener(() => setState(() {}));
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        obscureText: _isObscured,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        decoration: InputDecoration(
          labelText: _isActive
              ? widget.activeLabel ?? widget.label
              : widget.label,
          labelStyle: TextStyle(
            color: widget.labelColor ?? const Color(0xFFA6A7AE),
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),

          // 👁️ Corrected visibility toggle logic
          suffixIcon: widget.obscureText
              ? IconButton(
                  icon: Icon(
                    _isObscured
                        ? Icons
                              .visibility // 👁️ show eye when text is hidden
                        : Icons.visibility_off, // 🙈 hide eye when visible
                    color: const Color(0xFF2E7D32),
                  ),
                  onPressed: () {
                    setState(() {
                      _isObscured = !_isObscured;
                    });
                  },
                )
              : null,
        ),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
