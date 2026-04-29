// DOCS: docs/development-standards.md
// DOCS: docs/features/delivery.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/core/models/photo_entry.dart';
import 'package:fsi_courier_app/features/delivery/delivery_update_components.dart';

/// Single-slot photo section used for MAILPACK (OSA) and SELFIE (failed delivery).
///
/// Renders one [DeliveryPhotoSlot] inside a [Row]. All state mutations are
/// dispatched via callbacks so the parent retains ownership of [photo].
class DeliverySinglePhotoSection extends StatelessWidget {
  const DeliverySinglePhotoSection({
    super.key,
    required this.photo,
    required this.label,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.hasError,
    required this.onTap,
    required this.onClear,
  });

  final PhotoEntry? photo;
  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;
  final bool hasError;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DeliveryPhotoSlot(
          label: label,
          photo: photo,
          icon: icon,
          color: color,
          isDark: isDark,
          hasError: hasError,
          onTap: onTap,
          onClear: onClear,
        ),
      ],
    );
  }
}
