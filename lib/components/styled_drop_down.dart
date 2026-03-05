import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StyledDropDown extends StatefulWidget {
  final String label; // placeholder text
  final String? activeLabel; // text shown when focused or has input
  final bool obscureText;
  final TextInputType keyboardType;
  final Color? labelColor;
  final List<TextInputFormatter>? inputFormatters;

  /// Optional: dropdown items for searchable selection
  final List<String>? items;
  final void Function(String)? onChanged;

  /// Added: whether the text field is enabled or disabled
  final bool enabled;

  const StyledDropDown({
    super.key,
    required this.label,
    this.activeLabel,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.labelColor,
    this.inputFormatters,
    this.items,
    this.onChanged,
    this.enabled = true, // ✅ default enabled
  });

  @override
  State<StyledDropDown> createState() => _StyledDropDownState();
}

class _StyledDropDownState extends State<StyledDropDown> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  OverlayEntry? _overlayEntry;
  List<String> _filteredItems = [];

  bool get _isActive => _focusNode.hasFocus || _controller.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();

    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    if (widget.items != null) {
      setState(() {
        _filteredItems = widget.items!
            .where(
              (item) =>
                  item.toLowerCase().contains(_controller.text.toLowerCase()),
            )
            .toList();
      });
      _updateOverlay();
    }
    widget.onChanged?.call(_controller.text);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && widget.items != null) {
      _filteredItems = widget.items!;
      _showOverlay();
    } else {
      _removeOverlay();
    }
    setState(() {});
  }

  void _showOverlay() {
    final overlay = Overlay.of(context);
    _overlayEntry = _createOverlayEntry();
    overlay.insert(_overlayEntry!);
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) {
        return Positioned(
          left: offset.dx,
          top: offset.dy + size.height + 4,
          width: size.width,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  return InkWell(
                    onTap: () {
                      _controller.text = item;
                      widget.onChanged?.call(item);
                      _focusNode.unfocus();
                      _removeOverlay();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      child: Text(item, style: const TextStyle(fontSize: 16)),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
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
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        enabled: widget.enabled, // ✅ added here
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
          suffixIcon: widget.items != null
              ? const Icon(Icons.arrow_drop_down, color: Colors.black45)
              : null,
        ),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
