// DOCS: docs/features/delivery.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/styles/ui_styles.dart';

import 'package:fsi_courier_app/styles/color_styles.dart';

// ─── Theme-aware field decoration ───────────────────────────────────────────
InputDecoration deliveryFieldDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  String? errorText,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final fill = isDark ? ColorStyles.grabCardElevatedDark : Colors.white;
  final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    errorText: errorText,
    filled: true,
    fillColor: fill,
    border: OutlineInputBorder(
      borderRadius: UIStyles.cardRadius,
      borderSide: BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: UIStyles.cardRadius,
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: UIStyles.cardRadius,
      borderSide: const BorderSide(color: ColorStyles.grabGreen, width: 1.5),
    ),
  );
}

// ─── Section header ──────────────────────────────────────────────────────────
class DeliverySectionHeader extends StatelessWidget {
  const DeliverySectionHeader({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: Colors.grey.shade600,
      ),
    );
  }
}

// ─── Photo source button ──────────────────────────────────────────────────────
class DeliveryPhotoSourceButton extends StatelessWidget {
  const DeliveryPhotoSourceButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: enabled
              ? color.withValues(alpha: UIStyles.alphaSoft)
              : ColorStyles.grabCardElevatedDark,
          borderRadius: UIStyles.cardRadius,
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: UIStyles.alphaBorder)
                : ColorStyles.grabCardDark,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: enabled ? color : Colors.grey.shade400, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: enabled ? color : Colors.grey.shade400,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
