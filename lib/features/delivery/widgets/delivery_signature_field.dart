import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class DeliverySignatureField extends StatelessWidget {
  const DeliverySignatureField({
    super.key,
    required this.controller,
    required this.onClear,
    this.errorText,
  });

  final SignatureController controller;
  final VoidCallback onClear;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = errorText != null
        ? Colors.red
        : isDark
        ? Colors.white10
        : Colors.grey.shade300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Signature(
                controller: controller,
                height: 160,
                backgroundColor: Colors.white,
              ),
              Positioned(
                left: 12,
                bottom: 10,
                right: 60,
                child: IgnorePointer(
                  child: Text(
                    'Sign above',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade300,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              errorText!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text(
              'CLEAR SIGNATURE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade500,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
          ),
        ),
      ],
    );
  }
}
