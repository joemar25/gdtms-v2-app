import 'package:flutter/material.dart';
import 'styled_text_box.dart';
import 'styled_drop_down.dart';

class ReceiverDetailsSection extends StatefulWidget {
  final TextEditingController receiverController;
  final TextEditingController codeController;
  final TextEditingController remarksController;
  final String? selectedAttempt;
  final String? selectedReason;
  final Function(String?) onAttemptChanged;
  final Function(String?) onReasonChanged;

  const ReceiverDetailsSection({
    super.key,
    required this.receiverController,
    required this.codeController,
    required this.remarksController,
    required this.selectedAttempt,
    required this.selectedReason,
    required this.onAttemptChanged,
    required this.onReasonChanged,
  });

  @override
  State<ReceiverDetailsSection> createState() => _ReceiverDetailsSectionState();
}

class _ReceiverDetailsSectionState extends State<ReceiverDetailsSection> {
  late String? _selectedAttempt;
  late String? _selectedReason;

  @override
  void initState() {
    super.initState();
    _selectedAttempt = widget.selectedAttempt;
    _selectedReason = widget.selectedReason;
  }

  @override
  void didUpdateWidget(covariant ReceiverDetailsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedAttempt != widget.selectedAttempt) {
      _selectedAttempt = widget.selectedAttempt;
    }
    if (oldWidget.selectedReason != widget.selectedReason) {
      _selectedReason = widget.selectedReason;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StyledDropDown(
            label: "1st Attempt",
            activeLabel: "Attempt",
            items: const ["1st Attempt", "2nd Attempt", "3rd Attempt"],
            onChanged: (value) {
              setState(() => _selectedAttempt = value);
              widget.onAttemptChanged(value);
            },
          ),
          const SizedBox(height: 12),
          StyledDropDown(
            label: "Reason",
            activeLabel: "Reason",
            items: const [
              "Receiver not available",
              "Address not found",
              "Customer refused",
              "Other",
            ],
            onChanged: (value) {
              setState(() => _selectedReason = value);
              widget.onReasonChanged(value);
            },
          ),
          const SizedBox(height: 12),
          StyledTextBox(
            label: "Remarks",
            activeLabel: "Remarks",
            keyboardType: TextInputType.multiline,
          ),
        ],
      ),
    );
  }
}
