// DOCS: docs/features/delivery.md — update that file when you edit this one.

import 'package:flutter/material.dart';

import 'package:signature/signature.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

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
        ? DSColors.error
        : isDark
        ? DSColors.white.withValues(alpha: DSStyles.alphaSubtle)
        : DSColors.separatorLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: DSColors.white,
            borderRadius: DSStyles.cardRadius,
            border: Border.all(color: borderColor, width: DSStyles.borderWidth * 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Signature(
                controller: controller,
                height: 160,
                backgroundColor: DSColors.white,
              ),
              Positioned(
                left: 12,
                bottom: 10,
                right: 60,
                child: IgnorePointer(
                  child: Text(
                    'Sign above',
                    style: TextStyle(
                      fontSize: DSTypography.sizeSm,
                      color: DSColors.labelTertiary,
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
            padding: EdgeInsets.only(top: DSSpacing.sm),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: DSColors.error,
                fontSize: DSTypography.sizeSm,
              ),
            ),
          ),
        DSSpacing.hXs,
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.refresh_rounded, size: DSTypography.sizeSm),
            label: const Text(
              'CLEAR SIGNATURE',
              style: TextStyle(
                fontSize: DSTypography.sizeSm,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: DSColors.labelTertiary,
              padding: EdgeInsets.symmetric(
                horizontal: DSSpacing.sm,
                vertical: DSSpacing.xs,
              ),
              minimumSize: Size.zero,
            ),
          ),
        ),
      ],
    );
  }
}
