// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.subtitle,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
  });

  final String title;
  final String subtitle;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  /// Shows the dialog and returns `true` (confirm) or `false`/`null` (cancel).
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: title,
        subtitle: subtitle,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmColor = isDestructive ? DSColors.error : DSColors.primary;

    return Dialog(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: DSSpacing.xl,
          vertical: DSSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: DSTypography.sizeMd,
              ),
            ),
            DSSpacing.hSm,
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? DSColors.labelSecondaryDark
                    : DSColors.labelSecondary,
                height: DSStyles.heightRelaxed,
              ),
            ),
            DSSpacing.hXl,
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: confirmColor,
                minimumSize: const Size(double.infinity, 52),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
            DSSpacing.hSm,
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                side: BorderSide(
                  color: isDark
                      ? DSColors.separatorDark
                      : DSColors.separatorLight,
                ),
              ),
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelLabel),
            ),
          ],
        ),
      ),
    );
  }
}
