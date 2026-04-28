import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class DSSectionHeader extends StatelessWidget {
  const DSSectionHeader({
    super.key,
    required this.title,
    this.padding,
    this.trailing,
  });

  final String title;
  final EdgeInsetsGeometry? padding;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final effectivePadding =
        padding ??
        EdgeInsets.fromLTRB(
          DSSpacing.md,
          DSSpacing.lg,
          DSSpacing.md,
          DSSpacing.sm,
        );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: effectivePadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: DSTypography.caption(color: DSColors.primary).copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              fontSize: DSTypography.sizeXs,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
