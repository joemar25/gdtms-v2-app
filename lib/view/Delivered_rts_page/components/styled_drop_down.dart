import 'package:flutter/material.dart';

class StyledDropDown extends StatefulWidget {
  final String label; // placeholder text
  final String? activeLabel; // text shown when focused or has input
  final Color? labelColor;

  /// Dropdown items
  final List<String> items;
  final void Function(String)? onChanged;

  /// Optional: whether the dropdown is enabled
  final bool enabled;

  const StyledDropDown({
    super.key,
    required this.label,
    this.activeLabel,
    this.labelColor,
    required this.items,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<StyledDropDown> createState() => _StyledDropDownState();
}

class _StyledDropDownState extends State<StyledDropDown> {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  String? _selectedItem;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _toggleDropdown() {
    if (!widget.enabled) return;
    if (_isOpen) {
      _removeOverlay();
    } else {
      FocusScope.of(context).unfocus();
      _showOverlay();
    }
  }

  void _showOverlay() {
    // 🛡️ Safety check: ensure context is still valid
    if (!mounted) return;

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    // 🛡️ Safely get render box
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;

    final renderBox = renderObject;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = _createOverlayEntry(size, offset);
    overlay.insert(_overlayEntry!);

    // Scroll to selected item after showing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selectedItem != null) {
        final index = widget.items.indexOf(_selectedItem!);
        if (index >= 0) {
          _scrollController.animateTo(
            index * 48.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }
    });

    if (mounted) setState(() => _isOpen = true);
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
    if (mounted) setState(() => _isOpen = false);
  }

  OverlayEntry _createOverlayEntry(Size size, Offset offset) {
    final dropdownTop = offset.dy + size.height + 4;

    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Transparent fullscreen background to catch taps
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
                child: const SizedBox.expand(),
              ),
            ),

            // Dropdown positioned below
            Positioned(
              left: offset.dx,
              top: dropdownTop,
              width: size.width,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: Scrollbar(
                      radius: const Radius.circular(12),
                      thumbVisibility: true,
                      thickness: 4,
                      controller: _scrollController,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: widget.items.length,
                        itemBuilder: (context, index) {
                          final item = widget.items[index];
                          final isSelected = item == _selectedItem;

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedItem = item;
                                _controller.text = item;
                              });
                              widget.onChanged?.call(item);
                              _removeOverlay();
                            },
                            child: Container(
                              color: isSelected
                                  ? Colors.grey.shade100
                                  : Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _selectedItem != null && _selectedItem!.isNotEmpty;

    return GestureDetector(
      onTap: _toggleDropdown,
      child: AbsorbPointer(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            readOnly: true,
            enabled: widget.enabled,
            decoration: InputDecoration(
              labelText: isActive
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
              suffixIcon: Icon(
                _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: Colors.black45,
              ),
            ),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
