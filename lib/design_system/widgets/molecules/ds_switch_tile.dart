// DOCS: docs/development-standards.md
import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// A specialized version of [DSDetailTile] specifically for boolean preferences.
///
/// It encapsulates the [Switch.adaptive] logic and ensures consistent colors
/// and layout for preference toggles across the application.
class DSSwitchTile extends StatelessWidget {
  const DSSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.isDestructive = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return DSDetailTile(
      title: title,
      subtitle: subtitle,
      icon: icon ?? Icons.settings_rounded,
      iconColor: iconColor,
      isDestructive: isDestructive,
      trailing: Switch.adaptive(
        value: value,
        activeTrackColor: DSColors.primary,
        activeThumbColor: DSColors.white,
        onChanged: onChanged,
      ),
    );
  }
}
