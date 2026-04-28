import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class DSSectionHeader extends StatelessWidget {
  const DSSectionHeader({
    super.key,
    required this.title,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 12),
    this.trailing,
  });

  final String title;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: DSTypography.caption(color: DSColors.primary).copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              fontSize: 12,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
