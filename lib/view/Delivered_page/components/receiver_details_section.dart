import 'package:flutter/material.dart';
import 'styled_text_box.dart';
import 'styled_drop_down.dart';

class ReceiverDetailsSection extends StatefulWidget {
  final TextEditingController receiverController;
  final TextEditingController codeController;
  final TextEditingController remarksController;
  final String? selectedRelationship;
  final Function(String?) onRelationshipChanged;

  const ReceiverDetailsSection({
    super.key,
    required this.receiverController,
    required this.codeController,
    required this.remarksController,
    required this.selectedRelationship,
    required this.onRelationshipChanged,
  });

  @override
  State<ReceiverDetailsSection> createState() => _ReceiverDetailsSectionState();
}

class _ReceiverDetailsSectionState extends State<ReceiverDetailsSection> {
  late String? _selectedRelationship;

  @override
  void initState() {
    super.initState();
    _selectedRelationship = widget.selectedRelationship;
  }

  @override
  void didUpdateWidget(covariant ReceiverDetailsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRelationship != widget.selectedRelationship) {
      _selectedRelationship = widget.selectedRelationship;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Receiver Details",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          "Enter receiver information for delivery.",
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 16),

        // ✅ Receiver name
        StyledTextBox(
          label: "Enter receiver name",
          activeLabel: "Receiver Name",
        ),

        const SizedBox(height: 12),

        // ✅ Relationship using StyledDropDown
        StyledDropDown(
          label: "Relationship",
          activeLabel: "Relationship",
          items: const ["Family", "Friend", "Neighbor", "Colleague"],
          onChanged: (value) {
            setState(() => _selectedRelationship = value);
            widget.onRelationshipChanged(value);
          },
        ),

        const SizedBox(height: 12),

        // ✅ Delivery code
        // StyledTextBox(label: "Delivery Code", activeLabel: "Delivery Code"),

        // const SizedBox(height: 12),

        // ✅ Remarks
        StyledTextBox(label: "Remarks", activeLabel: "Remarks"),
      ],
    );
  }
}
